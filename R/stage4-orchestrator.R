#' Run limma-voom DE per-study per tutti gli eligible cluster REM + MEGA-AUG
#'
#' Itera su (cluster_id, study_id) dispatch dell'attributo "study_dispatch"
#' di \code{eligible_clusters}, fetch counts via fetch_fn (cache-backed),
#' applica direction flip per cluster con \code{direction_check == "swapped"}
#' e concatena i tibble per-study in un unico output con schema
#' \code{per_study_de.parquet}.
#'
#' MEGA pure (non MEGA-AUG) e' escluso: usa raw counts cross-study senza
#' per-study DE, viene gestito direttamente da \code{.pool_all_clusters}.
#'
#' @param eligible_clusters tibble post-QC + \code{attr(., "study_dispatch")}
#'   list nested per cluster_id.
#' @param fetch_fn function \code{(gse, sample_ids) -> matrix}. Default NULL
#'   richiede iniezione esplicita (mock o cache-backed da chiamante).
#' @param workers integer numero di worker per future_map (default 1L, serial).
#' @return tibble \code{per_study_de.parquet} schema; vuoto se nessun cluster
#'   eleggibile.
#' @keywords internal
.run_per_study_de_all <- function(eligible_clusters, fetch_fn = NULL,
                                   metadata_extra = NULL,
                                   de_covariates = character(0),
                                    workers = 1L) {
  dispatch <- attr(eligible_clusters, "study_dispatch")
  if (is.null(dispatch)) {
    stop("eligible_clusters deve avere attr 'study_dispatch'")
  }
  if (is.null(fetch_fn)) {
    stop("fetch_fn deve essere fornita (cache-backed o mock)")
  }

  # Filtra solo REM + MEGA-AUG + REM_GROUP (MEGA puro non fa per-study DE).
  per_study_clusters <- eligible_clusters[
    eligible_clusters$method %in% c("rem", "mega_aug", "rem_group"),
  ]

  out_list <- vector("list", 0L)
  for (i in seq_len(nrow(per_study_clusters))) {
    cid <- per_study_clusters$cluster_id[i]
    dispatch_i <- dispatch[[cid]]
    if (is.null(dispatch_i)) next

    # direction_check e' NA per i cluster group-mode (concetto pair-only): NA
    # nel confronto propagherebbe a if(NA) -> errore. isTRUE coerce NA/NULL a FALSE
    # (nessun flip di direzione per i group: la direzione e' gia' treated-vs-control).
    dir_flip <- isTRUE(per_study_clusters$direction_check[i] == "swapped")

    for (j in seq_along(dispatch_i)) {
      d <- dispatch_i[[j]]
      study_id <- d$study_id
      samples <- c(d$treated, d$control)
      treatment <- factor(
        c(rep("treated", length(d$treated)),
          rep("control", length(d$control))),
        levels = c("control", "treated")
      )

      counts <- fetch_fn(study_id, samples)
      # Rete di sicurezza (bug 2026-06-27, Task 15 v4): un singolo fit per-studio
      # in errore (es. 0 df residui, voom su 0 geni post-filter, ...) NON deve
      # mai abortire l'intero run da centinaia di cluster. Skip+warning, prosegui.
      row_res <- tryCatch(
        .run_limma_voom_de(counts, treatment, study_id, cid,
                            direction_flip = dir_flip,
                            metadata_extra = metadata_extra,
                            covariates = de_covariates),
        error = function(e) {
          warning(sprintf(
            "per_study DE FALLITO (skip, non fatale): cluster=%s study=%s: %s",
            cid, study_id, conditionMessage(e)))
          .empty_per_study_de()
        }
      )
      out_list[[length(out_list) + 1L]] <- row_res
    }
  }

  if (length(out_list) == 0L) return(.empty_per_study_de())
  do.call(rbind, out_list)
}

#' Tibble vuota schema \code{per_study_de.parquet}
#'
#' Costruisce uno scheletro tipato usato come fallback edge case quando
#' nessun cluster eleggibile fornisce DE per-study.
#'
#' @keywords internal
.empty_per_study_de <- function() {
  # FASE E1 ADR-0019 D6: 'gene' (HGNC symbol con make.unique pre-E1)
  # rinominato 'gene_id' (Ensembl, univoco per costruzione) + nuova
  # colonna 'gene_symbol' (HGNC label, possibili duplicati cross-paralogi + NA).
  tibble::tibble(
    cluster_id = character(),
    study_id = character(),
    gene_id = character(),
    gene_symbol = character(),
    logFC = double(),
    SE = double(),
    p_value = double(),
    t_stat = double(),
    n_treated = integer(),
    n_control = integer(),
    direction_applied = character()
  )
}

#' Collassa i bracci multipli intra-studio in un valore per studio (inverse-variance FE)
#'
#' Un cluster rem_group puo' avere piu' bracci trattati dello stesso studio (es.
#' dosi diverse), ognuno con una riga per gene in per_study_de. Per non contarli
#' come studi indipendenti nel REM (pseudo-replicazione), si combinano le stime
#' dei bracci dello stesso (cluster, study, gene) in un'unica stima via
#' meta-analisi fixed-effect inverse-variance:
#'   w_i = 1/SE_i^2 ; logFC = sum(w_i logFC_i)/sum(w_i) ; SE = sqrt(1/sum(w_i)).
#' LIMITE NOTO: assume indipendenza tra bracci; i bracci condividono il control
#' in-study (correlazione non modellata) -> SE combinata lievemente ottimistica.
#' La correzione per shared-baseline (Franchini) e' un raffinamento futuro.
#'
#' @param per_study_de_subset tibble per-studio di UN cluster (schema
#'   per_study_de: cluster_id, study_id, gene_id, gene_symbol, logFC, SE,
#'   p_value, t_stat, n_treated, n_control, direction_applied).
#' @return tibble stesso schema, con 1 riga per (study_id, gene_id).
#' @keywords internal
.collapse_arms_by_study <- function(per_study_de_subset) {
  if (nrow(per_study_de_subset) == 0L) return(per_study_de_subset)

  # Chiave composta per identificare i gruppi (study_id, gene_id).
  # Separatore improbabile negli ID reali (GSE + ENSEMBL) per evitare collisioni.
  key <- paste(per_study_de_subset$study_id, per_study_de_subset$gene_id,
               sep = "|||")

  # Fast path: nessun (study_id, gene_id) duplicato -> ogni studio ha al
  # piu' 1 braccio per gene. Ritorna l'input invariato senza overhead.
  if (!anyDuplicated(key)) return(per_study_de_subset)

  # Split per gruppo e combina i bracci multipli via inverse-variance FE.
  groups <- split(per_study_de_subset, key)

  collapsed <- lapply(groups, function(g) {
    if (nrow(g) == 1L) return(g)

    # Filtra bracci con SE finita e > 0 E logFC finito (validi per la media pesata).
    # Un braccio con SE valida ma logFC NA/Inf propagherebbe NA nel risultato combinato.
    validi <- is.finite(g$SE) & g$SE > 0 & is.finite(g$logFC)
    if (!any(validi)) return(NULL)  # nessun braccio valido -> scarta gruppo

    gv <- g[validi, , drop = FALSE]
    if (nrow(gv) == 1L) return(gv)  # 1 solo braccio valido -> passa invariato

    # Meta-analisi fixed-effect inverse-variance:
    #   w_i = 1/SE_i^2 ; logFC = sum(w_i * logFC_i) / sum(w_i)
    #   SE_comb = sqrt(1 / sum(w_i))
    w     <- 1 / gv$SE^2
    w_sum <- sum(w)
    lfc   <- sum(w * gv$logFC) / w_sum
    se    <- sqrt(1 / w_sum)

    tibble::tibble(
      cluster_id        = gv$cluster_id[1L],
      study_id          = gv$study_id[1L],
      gene_id           = gv$gene_id[1L],
      gene_symbol       = gv$gene_symbol[1L],
      logFC             = lfc,
      SE                = se,
      p_value           = 2 * stats::pnorm(-abs(lfc / se)),
      t_stat            = lfc / se,
      # n_treated: somma dei bracci (campioni trattati distinti per braccio)
      # n_control: max (il control e' condiviso tra i bracci -> NON sommare)
      # na.rm = TRUE: difesa se upstream produce un conteggio NA inatteso.
      n_treated         = as.integer(sum(gv$n_treated, na.rm = TRUE)),
      n_control         = max(gv$n_control, na.rm = TRUE),
      direction_applied = gv$direction_applied[1L]
    )
  })

  # Scarta i NULL (gruppi senza bracci validi), combina e ordina deterministicamente
  collapsed <- Filter(Negate(is.null), collapsed)
  if (length(collapsed) == 0L) return(.empty_per_study_de())

  result <- do.call(rbind, collapsed)
  result[order(result$study_id, result$gene_id), , drop = FALSE]
}

#' Pool tutti i cluster eligible (REM + MEGA + MEGA-AUG)
#'
#' Dispatch per method:
#' \itemize{
#'   \item \code{"rem"} -> subset per_study_de + \code{.pool_rem_cluster}.
#'   \item \code{"mega"} -> assembla counts da \code{group_dispatch[[cid]]}
#'         + \code{.run_dream_mega(method_label="mega")}.
#'   \item \code{"mega_aug"} -> \code{.assemble_mega_aug_metadata} per metadata,
#'         fetch counts per all_studies, \code{.run_dream_mega(..., method_label="mega_aug")}.
#' }
#'
#' @param per_study_de tibble output di \code{.run_per_study_de_all}.
#' @param eligible_clusters tibble post-QC.
#' @param fetch_fn function \code{(gse, sample_ids) -> matrix}.
#' @param stage3_clusters tibble Stage 3 originale per baseline pool lookup
#'   (MEGA-AUG only).
#' @param workers integer numero di worker (default 1L).
#' @param dream_workers_cap integer cap workers BiocParallel passato a dream
#'   (default 8L).
#' @param mega_aug_config list (default NULL = legacy monodirectional). Se
#'   non-NULL e \code{legacy_monodirectional = FALSE}, attiva il dispatch
#'   bidirezionale via \code{.assemble_mega_aug_metadata_bidir} con anchor
#'   policy + direction + disjoint_policy specificati (vedi
#'   \code{stage4_default_config()$mega_aug}).
#' @return tibble \code{cluster_pooled.parquet} schema; vuoto se nessun
#'   cluster.
#' @keywords internal
.pool_all_clusters <- function(per_study_de, eligible_clusters, fetch_fn,
                                stage3_clusters, workers = 1L,
                                dream_workers_cap = 8L,
                                mega_aug_config = NULL,
                                rem_group_config = NULL,
                                biosample_lookup = NULL,
                                libsize_lookup = NULL,
                                metadata_extra = NULL,
                                de_covariates = character(0)) {
  out_list <- vector("list", 0L)
  pooling_warnings_list <- vector("list", 0L)
  non_processable_list  <- vector("list", 0L)
  mega_aug_diagnostics_list <- vector("list", 0L)

  # Risolvi bidir mode + matcher una volta sola
  use_bidir <- !is.null(mega_aug_config) &&
    isFALSE(mega_aug_config$legacy_monodirectional)
  bidir_matcher <- if (use_bidir) {
    make_anchor_matcher(
      policy            = mega_aug_config$anchor_policy %||% "relaxed",
      relaxed_segments  = mega_aug_config$relaxed_segments %||%
        c("dose_canonical", "duration_canonical", "has_engineered")
    )
  } else NULL
  bidir_direction <- mega_aug_config$direction %||% "both"
  bidir_disjoint  <- mega_aug_config$disjoint_policy %||% "permissive"
  bidir_min_baseline <- mega_aug_config$min_baseline_studies %||% 2L
  bidir_max_baseline <- mega_aug_config$max_baseline_per_arm %||% NA_integer_

  dispatch <- attr(eligible_clusters, "study_dispatch")
  group_dispatch <- attr(eligible_clusters, "group_dispatch")
  rem_group_k_eff_min <- rem_group_config$k_eff_min %||% 3L

  n_clusters <- nrow(eligible_clusters)
  for (i in seq_len(n_clusters)) {
    cid <- eligible_clusters$cluster_id[i]
    method <- eligible_clusters$method[i]

    # Progress logging per-cluster (Problema B): senza, un fullrun da centinaia
    # di cluster non dice QUALE cluster e' lento/pesante o ha ucciso il run.
    # message() -> stderr, finisce nel log via `2>&1 | tee`, innocuo ai test.
    t_cluster <- Sys.time()
    message(sprintf("[cluster %d/%d] %s (method=%s)", i, n_clusters, cid, method))

    # Wrap intero body con tryCatch: cluster failed -> registrato in
    # non_processable + continue al successivo, invece di crashare l'intero
    # pool. Discovery 2026-05-20 fullrun #2 (END=06:03:44, EXIT=1):
    # "duplicate 'row.names' are not allowed" da un cluster non coperto
    # dai fix #1+#2. Hotfix difensivo per produrre output parziale + diagnose
    # in post-mortem invece di total fail.
    crashed_in_cluster <- FALSE
    tryCatch({
    if (method == "rem") {
      subset <- per_study_de[per_study_de$cluster_id == cid, ]
      pool <- .pool_rem_cluster(subset)
      out_list[[length(out_list) + 1L]] <- pool

    } else if (method == "rem_group") {
      # REM_GROUP: pooling random-effects su cluster group (non pair), con
      # per-study DE accumulato in per_study_de + gate k_eff minimo.
      disp_i <- dispatch[[cid]]
      # k_eff = numero di STUDI distinti (spec §4.2), non di entry: un singolo
      # studio con piu' bracci trattati (stesso farmaco a piu' dosi/tempi) genera
      # piu' entry con lo stesso study_id; contarle come studi indipendenti
      # gonfierebbe il gate (pseudo-replicazione). Nota: l'aggregazione dei bracci
      # intra-studio nel REM e' un passo successivo (misurato nello smoke gate).
      study_ids_i <- if (length(disp_i)) {
        vapply(disp_i, function(d) d$study_id, character(1))
      } else character(0)
      k_eff  <- length(unique(study_ids_i))
      if (k_eff < rem_group_k_eff_min) {
        non_processable_list[[length(non_processable_list) + 1L]] <-
          tibble::tibble(
            cluster_id         = cid,
            original_k         = NA_integer_,
            qc_final_k         = k_eff,
            original_n_studies = NA_integer_,
            qc_final_n_studies = k_eff,
            reason = sprintf("rem_group_insufficient_in_study_controls: k_eff=%d",
                             k_eff)
          )
        next
      }
      subset <- per_study_de[per_study_de$cluster_id == cid, ]
      # Opzione C: collassa i bracci multipli dello stesso studio in un unico
      # valore per studio (inverse-variance FE) PRIMA del REM. Senza questo
      # passo, uno studio con k bracci trattati contribuisce k righe per gene
      # a metafor -> pseudo-replicazione -> I^2/tau^2 gonfiati, k_effective
      # conta bracci invece di studi (trovato: 70% cluster affetti, fino a 97
      # bracci extra). Vedi .collapse_arms_by_study per il dettaglio.
      subset <- .collapse_arms_by_study(subset)
      pool <- .pool_rem_cluster(subset, method_label = "rem_group")
      out_list[[length(out_list) + 1L]] <- pool

    } else if (method == "mega") {
      # group_dispatch[[cid]]: list di {study_id, sample_ids, treatment}.
      grp <- group_dispatch[[cid]]
      if (is.null(grp)) next

      # Safe metadata: dedup + role-conflict detection.
      # Conflicts: stesso GSM con ruoli divergenti tra rg -> sample droppato
      # (paper-grade: non assumere ruolo arbitrario). Cross-study same-role:
      # tenuto una sola volta + flagged.
      safe <- .build_mega_metadata_safe(grp, cid,
                                          biosample_lookup = biosample_lookup,
                                          libsize_lookup   = libsize_lookup)
      metadata <- safe$metadata
      if (nrow(safe$conflicts) > 0L) {
        pooling_warnings_list[[length(pooling_warnings_list) + 1L]] <-
          safe$conflicts
      }

      # Skip cluster rank-deficient (< 2 treatment levels o < n_min per livello)
      rank_check <- .check_mega_rank(metadata)
      if (rank_check$rank_deficient) {
        non_processable_list[[length(non_processable_list) + 1L]] <-
          tibble::tibble(
            cluster_id         = cid,
            original_k         = NA_integer_,
            qc_final_k         = NA_integer_,
            original_n_studies = NA_integer_,
            qc_final_n_studies = NA_integer_,
            reason             = paste0("mega_rank_deficient: ", rank_check$reason)
          )
        next
      }

      # Fetch counts per studio, in ordine deterministico
      all_studies <- unique(as.character(metadata$study))
      counts_list <- lapply(all_studies, function(s) {
        sids_s <- metadata$sample_id[metadata$study == s]
        fetch_fn(s, sids_s)
      })
      common_genes <- Reduce(intersect, lapply(counts_list, rownames))
      counts <- do.call(cbind, lapply(counts_list, function(m) {
        m[common_genes, , drop = FALSE]
      }))

      # FASE E1: cbind() + matrix subscripting perdono attr custom.
      # Riattacca gene_symbol prendendolo dal primo counts_list (coerente
      # cross-study: stesso ensembl_gene -> stesso HGNC symbol per
      # definizione). Filter ai common_genes presenti.
      first_gs <- attr(counts_list[[1]], "gene_symbol")
      if (!is.null(first_gs)) {
        attr(counts, "gene_symbol") <- first_gs[common_genes]
      }

      # Reorder metadata per matchare colnames(counts) (dream/voom check rigido)
      metadata <- metadata[match(colnames(counts), metadata$sample_id), ,
                            drop = FALSE]

      # FASE E3 ADR-0019 D8 + T6b Fix C2: helper join con warning
      # join_incomplete distinto dal warning NA biologico.
      joined <- .join_covariates_to_metadata(
        metadata, metadata_extra, de_covariates, cid
      )
      metadata <- joined$metadata
      pool <- .run_dream_mega(counts, metadata, cid,
                               workers = min(workers, dream_workers_cap),
                               covariates = de_covariates)
      out_list[[length(out_list) + 1L]] <- pool

    } else if (method == "mega_aug") {
      # Guardia: un cluster mega_aug (mode=pair) senza study_dispatch non ha
      # record di comparison risolvibili in stage2_master -> nessun pair reale.
      # Processarlo produrrebbe metadata baseline-only (contrasto spurio
      # baseline-vs-baseline). Skippato esplicitamente in non_processable.
      # Discovery scan 2026-05-21: 5 cluster (es. pair_L0_95117985). La causa
      # upstream (record_id non risolvibili in Stage 2/3) e' un follow-up.
      if (is.null(dispatch[[cid]]) || length(dispatch[[cid]]) == 0L) {
        non_processable_list[[length(non_processable_list) + 1L]] <-
          tibble::tibble(
            cluster_id         = cid,
            original_k         = NA_integer_,
            qc_final_k         = NA_integer_,
            original_n_studies = NA_integer_,
            qc_final_n_studies = NA_integer_,
            reason             = "mega_aug_no_study_dispatch"
          )
        next
      }

      # Parsa anchor_key del pair-cluster in treated/control (vedi
      # .parse_pair_anchor_key + Stage 3 encoding "<tk>__VS__<ck>__CT_<ct>")
      parsed_key <- .parse_pair_anchor_key(
        eligible_clusters$anchor_key[i],
        level = eligible_clusters$level[i]
      )

      # Costruisci vettori paralleli (sample, study) iterando dispatch entries.
      # Ogni dispatch entry e' un record_id = (series_id, comparison_id) e
      # carica i sample_ids del replicate_group dello stesso studio. Se piu'
      # comparison-record nello stesso cluster condividono treated_group o
      # control_group, i sample appaiono in piu' entry: dedup downstream in
      # .assemble_mega_aug_metadata mantenendo la prima occorrenza.
      dispatch_entries <- dispatch[[cid]]
      treated_samples_flat <- unlist(lapply(dispatch_entries,
                                              function(d) d$treated))
      control_samples_flat <- unlist(lapply(dispatch_entries,
                                              function(d) d$control))
      treated_studies_flat <- unlist(lapply(dispatch_entries, function(d) {
        rep(d$study_id, length(d$treated))
      }))
      control_studies_flat <- unlist(lapply(dispatch_entries, function(d) {
        rep(d$study_id, length(d$control))
      }))

      pair_cluster_struct <- list(
        cluster_id = cid,
        level = eligible_clusters$level[i],
        # anchor_key originale: necessario al bidir flow (parse interno).
        anchor_key = eligible_clusters$anchor_key[i],
        treated_anchor_key = parsed_key$treated,
        control_anchor_key = parsed_key$control,
        studies_in_cluster = eligible_clusters$studies_in_cluster[[i]],
        treated_samples = list(treated_samples_flat),
        control_samples = list(control_samples_flat),
        treated_sample_studies = list(treated_studies_flat),
        control_sample_studies = list(control_studies_flat)
      )

      # Subset Stage 3 group clusters allo stesso level.
      group_baseline <- stage3_clusters[
        stage3_clusters$mode == "group" &
        stage3_clusters$level == eligible_clusters$level[i],
      ]

      # Dispatch legacy vs bidirezionale
      if (use_bidir) {
        assembled <- .assemble_mega_aug_metadata_bidir(
          pair_cluster_struct, group_baseline,
          matcher = bidir_matcher,
          direction = bidir_direction,
          min_baseline_studies = bidir_min_baseline,
          max_baseline_per_arm = bidir_max_baseline,
          biosample_lookup = biosample_lookup,
          libsize_lookup   = libsize_lookup
        )

        # disjoint_policy = "strict": scarta cluster con
        # comparison_kind_overall = "indirect_disjoint".
        if (identical(bidir_disjoint, "strict") &&
            isTRUE(assembled$comparison_kind_overall == "indirect_disjoint")) {
          non_processable_list[[length(non_processable_list) + 1L]] <-
            tibble::tibble(
              cluster_id         = cid,
              original_k         = NA_integer_,
              qc_final_k         = NA_integer_,
              original_n_studies = NA_integer_,
              qc_final_n_studies = NA_integer_,
              reason             = "mega_aug_disjoint_strict_skipped"
            )
          next
        }

        # Diagnostic row per cluster bidir
        mega_aug_diagnostics_list[[length(mega_aug_diagnostics_list) + 1L]] <-
          tibble::tibble(
            cluster_id                          = cid,
            comparison_kind_control             = assembled$comparison_kind_control,
            comparison_kind_treated             = assembled$comparison_kind_treated,
            comparison_kind_overall             = assembled$comparison_kind_overall,
            n_baseline_studies_augmented_control = assembled$n_baseline_studies_augmented_control,
            n_baseline_studies_augmented_treated = assembled$n_baseline_studies_augmented_treated,
            baseline_pool_id_control            = assembled$baseline_pool_ids$control %||% NA_character_,
            baseline_pool_id_treated            = assembled$baseline_pool_ids$treated %||% NA_character_,
            bidir_collapsed_to_mono             = isTRUE(assembled$bidir_collapsed_to_mono)
          )

        # FASE E0b: propaga i drop SAMN dedupe del baseline pool nei
        # pooling_warnings. Senza questo passaggio i GSM rimossi cross-GSE
        # in MEGA-AUG sarebbero persi silenziosamente dal log finale (MEGA
        # pure invece propaga via safe$conflicts a riga ~179). Il
        # samn_dedupe_log di .assemble_mega_aug_metadata_bidir ha schema
        # ricco (libsize_dropped/kept, arm) -> traduco nel formato standard
        # conflicts (cluster_id, sample_id, studies, roles, conflict_type)
        # mantenendo il GSM_kept linkato nel conflict_type e l'arm in roles.
        # excluded_samn = drop perche' SAMN gia' nel pair (no kept counterpart
        # in baseline) -> conflict_type dedicato cross_gse_samn_excluded_pair.
        if (nrow(assembled$samn_dedupe_log) > 0L) {
          sd_log <- assembled$samn_dedupe_log
          conflict_type_vec <- ifelse(
            sd_log$reason == "excluded_samn",
            "cross_gse_samn_excluded_pair_overlap",
            sprintf("cross_gse_samn_dedupe_kept_%s", sd_log$gsm_kept)
          )
          pooling_warnings_list[[length(pooling_warnings_list) + 1L]] <-
            tibble::tibble(
              cluster_id    = cid,
              sample_id     = sd_log$gsm_dropped,
              studies       = NA_character_,   # studio specifico non tracciato MEGA-AUG
              roles         = sd_log$arm,
              conflict_type = conflict_type_vec
            )
        }

        # Backward-compat per .run_dream_mega: somma dei n augmented totali.
        n_aug_total <- assembled$n_baseline_studies_augmented_control +
          assembled$n_baseline_studies_augmented_treated
        assembled$n_baseline_studies_augmented <- n_aug_total
      } else {
        # Legacy monodirectional flow (invariato).
        assembled <- .assemble_mega_aug_metadata(pair_cluster_struct,
                                                   group_baseline)
      }

      # Fetch counts per ciascuno studio coinvolto + intersect rownames.
      all_studies <- unique(as.character(assembled$metadata$study))
      counts_list <- lapply(all_studies, function(s) {
        samples_s <- assembled$metadata$sample_id[
          assembled$metadata$study == s
        ]
        fetch_fn(s, samples_s)
      })
      common_genes <- Reduce(intersect, lapply(counts_list, rownames))
      counts <- do.call(cbind, lapply(counts_list, function(m) {
        m[common_genes, , drop = FALSE]
      }))

      # FASE E1: stessa preservation di attr come MEGA pure sopra. Vedi
      # commento omonimo al callsite mega.
      first_gs <- attr(counts_list[[1]], "gene_symbol")
      if (!is.null(first_gs)) {
        attr(counts, "gene_symbol") <- first_gs[common_genes]
      }

      # Riallinea metadata all'ordine di colnames(counts) per coerenza dream
      # (variancePartition::filterInputData richiede ordine + nomi identici).
      meta_ord <- assembled$metadata[
        match(colnames(counts), assembled$metadata$sample_id), , drop = FALSE
      ]

      # FASE E3 + T6b Fix C2: helper join (vedi MEGA pure sopra).
      joined_aug <- .join_covariates_to_metadata(
        meta_ord, metadata_extra, de_covariates, cid
      )
      meta_ord <- joined_aug$metadata
      pool <- .run_dream_mega(
        counts, meta_ord, cid,
        workers = min(workers, dream_workers_cap),
        n_baseline_studies_augmented = assembled$n_baseline_studies_augmented,
        method_label = "mega_aug",
        covariates = de_covariates
      )
      # Propaga metadata bidir come attributi (aggregati post-loop in
      # qc_report e in cluster_pooled). Solo se bidir mode.
      if (use_bidir) {
        attr(pool, "mega_aug_bidir") <- list(
          comparison_kind_control              = assembled$comparison_kind_control,
          comparison_kind_treated              = assembled$comparison_kind_treated,
          comparison_kind_overall              = assembled$comparison_kind_overall,
          n_baseline_studies_augmented_control = assembled$n_baseline_studies_augmented_control,
          n_baseline_studies_augmented_treated = assembled$n_baseline_studies_augmented_treated,
          baseline_pool_ids                    = assembled$baseline_pool_ids,
          bidir_collapsed_to_mono              = isTRUE(assembled$bidir_collapsed_to_mono)
        )
      }
      out_list[[length(out_list) + 1L]] <- pool
    }
    }, error = function(e) {
      msg <- conditionMessage(e)
      message(sprintf("[pool_runtime_error] cluster %s (method=%s): %s",
                       cid, method, msg))
      non_processable_list[[length(non_processable_list) + 1L]] <<- tibble::tibble(
        cluster_id         = cid,
        original_k         = NA_integer_,
        qc_final_k         = NA_integer_,
        original_n_studies = NA_integer_,
        qc_final_n_studies = NA_integer_,
        reason             = sprintf("pool_runtime_error: %s",
                                      substr(msg, 1L, 200L))
      )
      crashed_in_cluster <<- TRUE
    })
    # Progress: wall + RSS per-cluster. Permette di individuare nel log il
    # cluster lento o memory-heavy senza dover ispezionare l'intero run.
    message(sprintf("  -> %s %s | wall %.1fs | RSS %.1f GB",
                     cid, if (crashed_in_cluster) "FALLITO" else "ok",
                     as.numeric(difftime(Sys.time(), t_cluster, units = "secs")),
                     .proc_rss_gb()))
  }

  # Aggrega pooling_warnings (sample droppati per conflict/cross-study dup)
  pooling_warnings <- if (length(pooling_warnings_list) > 0L) {
    do.call(rbind, pooling_warnings_list)
  } else {
    tibble::tibble(cluster_id = character(0L), sample_id = character(0L),
                    studies = character(0L), roles = character(0L),
                    conflict_type = character(0L))
  }
  non_processable <- if (length(non_processable_list) > 0L) {
    do.call(rbind, non_processable_list)
  } else {
    tibble::tibble(cluster_id = character(0L), original_k = integer(0L),
                    qc_final_k = integer(0L), original_n_studies = integer(0L),
                    qc_final_n_studies = integer(0L), reason = character(0L))
  }

  cluster_pooled <- if (length(out_list) == 0L) {
    .empty_pooled_rem()
  } else {
    do.call(rbind, out_list)
  }

  # Aggrega mega_aug_diagnostics (vuoto se legacy / nessun cluster bidir)
  mega_aug_diagnostics <- if (length(mega_aug_diagnostics_list) > 0L) {
    do.call(rbind, mega_aug_diagnostics_list)
  } else {
    tibble::tibble(
      cluster_id                          = character(0L),
      comparison_kind_control             = character(0L),
      comparison_kind_treated             = character(0L),
      comparison_kind_overall             = character(0L),
      n_baseline_studies_augmented_control = integer(0L),
      n_baseline_studies_augmented_treated = integer(0L),
      baseline_pool_id_control            = character(0L),
      baseline_pool_id_treated            = character(0L),
      bidir_collapsed_to_mono             = logical(0L)
    )
  }

  attr(cluster_pooled, "pooling_warnings")          <- pooling_warnings
  attr(cluster_pooled, "non_processable_in_pool")   <- non_processable
  attr(cluster_pooled, "mega_aug_diagnostics")      <- mega_aug_diagnostics
  cluster_pooled
}

#' Costruisce qc_report list per output write
#'
#' Estrae i quattro tibble di drop/warning attaccati come attributi a
#' \code{eligible_clusters} (sample/study/cluster) e \code{cluster_pooled}
#' (pooling_warnings). In assenza, fallback su tibble vuoti.
#'
#' @param eligible_clusters tibble post-QC.
#' @param per_study_de tibble per-study DE (riservato per estensioni future).
#' @param cluster_pooled tibble cluster-level pooled.
#' @return list con i campi \code{qc_drops_sample}, \code{qc_drops_study},
#'   \code{qc_drops_cluster}, \code{pooling_warnings}.
#' @keywords internal
.build_qc_report <- function(eligible_clusters, per_study_de, cluster_pooled) {
  list(
    qc_drops_sample = attr(eligible_clusters, "qc_drops_sample") %||%
      tibble::tibble(),
    qc_drops_study  = attr(eligible_clusters, "qc_drops_study") %||%
      tibble::tibble(),
    qc_drops_cluster = attr(eligible_clusters, "qc_drops_cluster") %||%
      tibble::tibble(),
    pooling_warnings = attr(cluster_pooled, "pooling_warnings") %||%
      tibble::tibble(),
    mega_aug_diagnostics = attr(cluster_pooled, "mega_aug_diagnostics") %||%
      tibble::tibble()
  )
}

#' Default-value operator (null-coalescing)
#'
#' Restituisce \code{x} se non-NULL, altrimenti \code{y}.
#'
#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x

#' RSS del processo corrente in GB (Linux)
#'
#' Legge \code{VmRSS} da \code{/proc/self/status}. Usato dal progress logging
#' per-cluster di \code{.pool_all_clusters} (Problema B). Ritorna \code{NA}
#' su piattaforme senza \code{/proc} (la pipeline gira su Linux).
#'
#' @return numeric(1) RSS in GB, o \code{NA_real_}.
#' @keywords internal
.proc_rss_gb <- function() {
  st <- tryCatch(readLines("/proc/self/status", warn = FALSE),
                  error = function(e) character(0L))
  ln <- grep("^VmRSS:", st, value = TRUE)
  if (length(ln) == 0L) return(NA_real_)
  kb <- suppressWarnings(as.numeric(sub("^VmRSS:\\s*(\\d+).*$", "\\1", ln[1L])))
  kb / 1048576
}
