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
                                    workers = 1L) {
  dispatch <- attr(eligible_clusters, "study_dispatch")
  if (is.null(dispatch)) {
    stop("eligible_clusters deve avere attr 'study_dispatch'")
  }
  if (is.null(fetch_fn)) {
    stop("fetch_fn deve essere fornita (cache-backed o mock)")
  }

  # Filtra solo REM + MEGA-AUG (MEGA puro non fa per-study DE).
  per_study_clusters <- eligible_clusters[
    eligible_clusters$method %in% c("rem", "mega_aug"),
  ]

  out_list <- vector("list", 0L)
  for (i in seq_len(nrow(per_study_clusters))) {
    cid <- per_study_clusters$cluster_id[i]
    dispatch_i <- dispatch[[cid]]
    if (is.null(dispatch_i)) next

    dir_flip <- per_study_clusters$direction_check[i] == "swapped"

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
      row_res <- .run_limma_voom_de(counts, treatment, study_id, cid,
                                      direction_flip = dir_flip)
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
  tibble::tibble(
    cluster_id = character(),
    study_id = character(),
    gene = character(),
    logFC = double(),
    SE = double(),
    p_value = double(),
    t_stat = double(),
    n_treated = integer(),
    n_control = integer(),
    direction_applied = character()
  )
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
                                mega_aug_config = NULL) {
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

    } else if (method == "mega") {
      # group_dispatch[[cid]]: list di {study_id, sample_ids, treatment}.
      grp <- group_dispatch[[cid]]
      if (is.null(grp)) next

      # Safe metadata: dedup + role-conflict detection.
      # Conflicts: stesso GSM con ruoli divergenti tra rg -> sample droppato
      # (paper-grade: non assumere ruolo arbitrario). Cross-study same-role:
      # tenuto una sola volta + flagged.
      safe <- .build_mega_metadata_safe(grp, cid)
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

      # Reorder metadata per matchare colnames(counts) (dream/voom check rigido)
      metadata <- metadata[match(colnames(counts), metadata$sample_id), ,
                            drop = FALSE]

      pool <- .run_dream_mega(counts, metadata, cid,
                               workers = min(workers, dream_workers_cap))
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
          max_baseline_per_arm = bidir_max_baseline
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

      # Riallinea metadata all'ordine di colnames(counts) per coerenza dream
      # (variancePartition::filterInputData richiede ordine + nomi identici).
      meta_ord <- assembled$metadata[
        match(colnames(counts), assembled$metadata$sample_id), , drop = FALSE
      ]

      pool <- .run_dream_mega(
        counts, meta_ord, cid,
        workers = min(workers, dream_workers_cap),
        n_baseline_studies_augmented = assembled$n_baseline_studies_augmented,
        method_label = "mega_aug"
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
