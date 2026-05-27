#' Assembla metadata sample-rows per MEGA-augmentation
#'
#' Combina sample del pair cluster (treated + control) con sample del baseline
#' pool (cluster group con stesso `control_anchor_key` allo stesso `level`),
#' deduplicando per `sample_id` per evitare double-counting di sample gia'
#' presenti nel pair, e usando mapping sample->study esplicito (NO rep ciclica
#' su `studies_in_cluster` — bug fix 2026-05-20 fullrun crash GSM4556584).
#'
#' Dedup priority: pair_treated > pair_control > baseline. Se un sample appare
#' in piu' contesti, vince il piu' alto in lista (treated > control > baseline).
#'
#' @param pair_cluster list con `cluster_id`, `treated_anchor_key`,
#'   `control_anchor_key`, `level`, `studies_in_cluster`, `treated_samples`,
#'   `control_samples`, `treated_sample_studies`, `control_sample_studies`.
#'   Le due `*_sample_studies` sono vettori paralleli ai rispettivi
#'   `*_samples` (per ogni sample il suo `series_id` reale).
#' @param group_baseline tibble di s3$clusters filtrato `mode = "group"`; deve
#'   avere colonne `mode`, `anchor_key`, `level`, `studies_in_cluster`,
#'   `sample_ids`, `sample_studies` (list-columns parallele).
#' @return list con `metadata` (tibble `sample_id`, `study`, `treatment`) e
#'   `n_baseline_studies_augmented` (integer).
#' @keywords internal
.assemble_mega_aug_metadata <- function(pair_cluster, group_baseline) {
  # Filtra matching group baseline (string equality mode/anchor + level integer)
  matching <- group_baseline[
    group_baseline$mode == "group" &
      group_baseline$level == pair_cluster$level &
      group_baseline$anchor_key == pair_cluster$control_anchor_key,
  ]

  # --- Pair sample rows: dedup + study map esplicita ----------------------
  raw_treated <- pair_cluster$treated_samples[[1L]]
  raw_control <- pair_cluster$control_samples[[1L]]
  raw_treated_studies <- pair_cluster$treated_sample_studies[[1L]]
  raw_control_studies <- pair_cluster$control_sample_studies[[1L]]
  if (length(raw_treated) != length(raw_treated_studies) ||
      length(raw_control) != length(raw_control_studies)) {
    stop("pair_cluster$*_samples e *_sample_studies devono essere paralleli")
  }

  # Dedup treated (first wins)
  keep_t <- !duplicated(raw_treated)
  pair_treated         <- raw_treated[keep_t]
  pair_treated_studies <- raw_treated_studies[keep_t]
  # Dedup control + escludi sample gia' in treated
  keep_c <- !duplicated(raw_control) & !(raw_control %in% pair_treated)
  pair_control         <- raw_control[keep_c]
  pair_control_studies <- raw_control_studies[keep_c]

  pair_rows <- tibble::tibble(
    sample_id = c(pair_treated, pair_control),
    study     = c(pair_treated_studies, pair_control_studies),
    treatment = factor(
      c(rep("treated", length(pair_treated)),
        rep("control", length(pair_control))),
      levels = c("control", "treated")
    )
  )

  # --- Baseline rows: usa sample_studies list-col parallela a sample_ids --
  all_baseline_sids    <- unlist(matching$sample_ids)
  all_baseline_studies <- unlist(matching$sample_studies)
  if (length(all_baseline_sids) != length(all_baseline_studies)) {
    stop("group_baseline$sample_ids e sample_studies devono essere parallele")
  }
  # Dedup baseline + escludi sample del pair
  pair_all <- c(pair_treated, pair_control)
  keep_b <- !duplicated(all_baseline_sids) & !(all_baseline_sids %in% pair_all)
  baseline_samples <- all_baseline_sids[keep_b]
  baseline_studies <- all_baseline_studies[keep_b]

  baseline_rows <- tibble::tibble(
    sample_id = baseline_samples,
    study     = baseline_studies,
    treatment = factor(
      rep("control", length(baseline_samples)),
      levels = c("control", "treated")
    )
  )

  # Concat base R (evita dipendenza dplyr Suggests)
  metadata <- rbind(pair_rows, baseline_rows)
  metadata$study <- as.factor(metadata$study)

  # Conta studi baseline aggiuntivi (esclusi quelli gia' nel pair)
  baseline_study_set <- unique(unlist(matching$studies_in_cluster))
  pair_study_set     <- pair_cluster$studies_in_cluster
  n_baseline_studies_augmented <- length(setdiff(baseline_study_set,
                                                  pair_study_set))

  list(
    metadata = metadata,
    n_baseline_studies_augmented = as.integer(n_baseline_studies_augmented)
  )
}

#' Assembla metadata sample-rows per MEGA-augmentation bidirezionale
#'
#' Generalizzazione di \code{.assemble_mega_aug_metadata}: augmenta il
#' braccio control e/o treated del pair cluster con baseline pool
#' compatibili (matching anchor via \code{matcher}). Per ogni arm
#' richiesto da \code{direction}, seleziona il TOP candidate via
#' \code{find_baseline_for_pair} (ranking: n_studies desc tiebreak
#' n_total desc) e ne aggiunge i sample come righe della matching arm.
#'
#' Dedup priority: pair_treated > pair_control > baseline_*. Sample del
#' pair che apparissero anche in un baseline pool sono mantenuti SOLO
#' nella loro identita' pair (treated o control), mai duplicati.
#'
#' La funzione legacy \code{.assemble_mega_aug_metadata} resta callable
#' (backward compat); l'orchestrator dispatch in base a
#' \code{config$mega_aug$legacy_monodirectional}.
#'
#' @param pair_cluster list con \code{cluster_id}, \code{level},
#'   \code{anchor_key} (composto __VS__), \code{studies_in_cluster},
#'   \code{treated_samples}, \code{control_samples},
#'   \code{treated_sample_studies}, \code{control_sample_studies}.
#' @param group_baseline tibble dei group baseline pool (mode=group) con
#'   \code{cluster_id}, \code{level}, \code{anchor_key}, \code{n_studies},
#'   \code{n_total}, \code{studies_in_cluster}, \code{sample_ids},
#'   \code{sample_studies} (list-columns).
#' @param matcher chiusura prodotta da \code{make_anchor_matcher()}.
#' @param direction character(1): \code{"control"}, \code{"treated"} o
#'   \code{"both"}. Default \code{"both"}.
#' @param min_baseline_studies integer(1): default \code{2L}. Forwarded a
#'   \code{find_baseline_for_pair}.
#' @param max_baseline_per_arm integer(1) o \code{NA}: cap sul numero di
#'   sample baseline aggiunti per braccio (Problema B). Se un baseline pool
#'   augmenterebbe il braccio con piu' di N sample, viene sotto-campionato a
#'   N (deterministico). \code{NA} (default) = nessun cap.
#' @param biosample_lookup environment o named char vec \code{GSM -> SAMN}.
#'   FASE E0b: se fornito insieme a \code{libsize_lookup}, i baseline pool
#'   subiscono SAMN dedupe cross-GSE (drop max lib_size, tie-break alfabetico)
#'   + esclusione dei GSM il cui SAMN e' gia' presente nel pair. NULL
#'   (default) = no dedupe (retrocompat).
#' @param libsize_lookup environment o named numeric vec
#'   \code{GSM -> lib_size}. Vedi \code{biosample_lookup}.
#' @return list con 9 componenti:
#'   \itemize{
#'     \item \code{metadata}: tibble \code{sample_id|study|treatment}.
#'     \item \code{n_baseline_studies_augmented_control}: integer.
#'     \item \code{n_baseline_studies_augmented_treated}: integer.
#'     \item \code{comparison_kind_control}: character(1) o \code{NA}.
#'     \item \code{comparison_kind_treated}: character(1) o \code{NA}.
#'     \item \code{comparison_kind_overall}: character(1) \emph{least
#'           severe} dei due lati (direct_overlap > indirect_partial >
#'           indirect_disjoint), \code{NA} se nessun augmentation.
#'     \item \code{baseline_pool_ids}: named list con \code{control} e
#'           \code{treated}, ciascuno cluster_id (character) o \code{NULL}.
#'     \item \code{bidir_collapsed_to_mono}: logical(1). \code{TRUE} se lo
#'           stesso group baseline pool matchava entrambi i bracci e il
#'           dispatch e' stato collassato a monodirezionale (augmenta solo
#'           \code{control}). Vedi sez. 3b del corpo funzione.
#'     \item \code{samn_dedupe_log}: tibble del log SAMN dedupe baseline
#'           (FASE E0b). Colonne \code{gsm_dropped, samn, gsm_kept,
#'           libsize_dropped, libsize_kept, reason, arm}. Empty tibble se
#'           nessun lookup fornito.
#'   }
#' @keywords internal
.assemble_mega_aug_metadata_bidir <- function(pair_cluster, group_baseline,
                                                matcher,
                                                direction = c("both", "control", "treated"),
                                                min_baseline_studies = 2L,
                                                max_baseline_per_arm = NA_integer_,
                                                biosample_lookup = NULL,
                                                libsize_lookup = NULL) {
  direction <- match.arg(direction)

  # 1. Pair rows con dedup (logica identica al legacy: vedi
  #    .assemble_mega_aug_metadata).
  raw_treated         <- pair_cluster$treated_samples[[1L]]
  raw_control         <- pair_cluster$control_samples[[1L]]
  raw_treated_studies <- pair_cluster$treated_sample_studies[[1L]]
  raw_control_studies <- pair_cluster$control_sample_studies[[1L]]
  if (length(raw_treated) != length(raw_treated_studies) ||
      length(raw_control) != length(raw_control_studies)) {
    stop("pair_cluster$*_samples e *_sample_studies devono essere paralleli")
  }
  keep_t <- !duplicated(raw_treated)
  pair_treated         <- raw_treated[keep_t]
  pair_treated_studies <- raw_treated_studies[keep_t]
  keep_c <- !duplicated(raw_control) & !(raw_control %in% pair_treated)
  pair_control         <- raw_control[keep_c]
  pair_control_studies <- raw_control_studies[keep_c]

  pair_rows <- tibble::tibble(
    sample_id = c(pair_treated, pair_control),
    study     = c(pair_treated_studies, pair_control_studies),
    treatment = factor(
      c(rep("treated", length(pair_treated)),
        rep("control", length(pair_control))),
      levels = c("control", "treated")
    )
  )
  pair_all <- c(pair_treated, pair_control)

  # FASE E0b: SAMN del pair, calcolato una volta. Usato come exclude_samn
  # nel SAMN dedupe del baseline pool: un baseline GSM che condivide SAMN
  # con un sample del pair e' la stessa entita' biologica gia' nel pair
  # -> rimosso completamente dal baseline (cross pair-baseline dedupe).
  # NULL se lookup non fornito (retrocompat: nessun dedupe SAMN attivo).
  pair_samn_set <- if (!is.null(biosample_lookup) && length(pair_all) > 0L) {
    s <- .lookup_chr(pair_all, biosample_lookup)
    unique(s[!is.na(s)])
  } else NULL

  # Accumulator log SAMN dedupe (chiusura sopra ai build_baseline_rows arm).
  samn_dedupe_rows <- list()

  # 2. Cerca baseline candidate via find_baseline_for_pair.
  # find_baseline_for_pair vuole un tibble per pair_cluster, ma di fatto
  # lavora indicizzando con [1L]; passiamo una tibble 1-riga ad hoc.
  pair_tbl <- tibble::tibble(
    cluster_id = pair_cluster$cluster_id,
    level      = pair_cluster$level,
    anchor_key = pair_cluster$anchor_key
  )
  candidates <- find_baseline_for_pair(
    pair_tbl, group_baseline, matcher,
    direction = direction,
    min_baseline_studies = min_baseline_studies
  )

  # 3. Selezione TOP candidate per arm (ranking gia' applicato).
  top_control <- NULL
  top_treated <- NULL
  for (cnd in candidates) {
    if (cnd$arm == "control" && is.null(top_control)) top_control <- cnd
    if (cnd$arm == "treated" && is.null(top_treated)) top_treated <- cnd
  }

  # 3b. Collision guard: se lo STESSO group baseline pool e' selezionato per
  # entrambi i bracci, aggiungerlo sia a control sia a treated duplica i
  # sample_id (crash "duplicate 'row.names'" in .run_dream_mega) e produce un
  # contrasto scientificamente nullo (gli stessi sample come reference E come
  # treated). Accade quando treated_anchor e control_anchor del pair sono
  # indistinguibili: identici ai level >= 2 (dove i tier C/D sono gia'
  # droppati), oppure differenti solo nei relaxed_segments (dose/duration/
  # has_engineered) a L0/L1 -> ogni pool che matcha un braccio matcha anche
  # l'altro. Fix Opzione 1 (decisione utente 2026-05-21): collassa a
  # monodirezionale augmentando SOLO il braccio control (= comportamento
  # legacy validato, bias eventuale conservativo verso il nulla) e marca il
  # cluster con bidir_collapsed_to_mono. Discovery: fullrun #4 2026-05-21,
  # cluster pair_L0_e45151a4 / pair_L1_37c75531 / pair_L2_a28b250f (vedi
  # docs/superpowers/specs/2026-05-21-p5-stadio4-debugging-handoff.md).
  bidir_collapsed_to_mono <- FALSE
  if (!is.null(top_control) && !is.null(top_treated) &&
      identical(top_control$baseline_cluster_id,
                top_treated$baseline_cluster_id)) {
    top_treated <- NULL
    bidir_collapsed_to_mono <- TRUE
  }

  # Helper interno: estrae baseline rows dedup-late da un cluster_id.
  build_baseline_rows <- function(top, treatment_label) {
    if (is.null(top)) {
      return(list(rows = NULL, n_studies_augmented = 0L,
                   baseline_studies = character(0L)))
    }
    grp <- group_baseline[group_baseline$cluster_id == top$baseline_cluster_id, ]
    sids    <- unlist(grp$sample_ids)
    sstudies <- unlist(grp$sample_studies)
    if (length(sids) != length(sstudies)) {
      stop(sprintf(
        "group_baseline$sample_ids e sample_studies non parallele per cluster %s",
        top$baseline_cluster_id
      ))
    }
    keep <- !duplicated(sids) & !(sids %in% pair_all)
    sids     <- sids[keep]
    sstudies <- sstudies[keep]
    if (length(sids) == 0L) {
      return(list(rows = NULL, n_studies_augmented = 0L,
                   baseline_studies = character(0L)))
    }

    # FASE E0b: SAMN dedupe del baseline pool (decisione utente 2026-05-27
    # su evidence A7b). Applicato DOPO il dedup per GSM literal + exclude
    # pair_all. exclude_samn = pair_samn_set rimuove baseline GSM che
    # rappresentano la stessa entita' biologica gia' presente nel pair.
    # Tra baseline GSM cross-GSE che condividono SAMN, tenuto quello con
    # lib_size max (tie-break alfabetico). Lookup NULL = no-op (retrocompat).
    if (!is.null(biosample_lookup) && !is.null(libsize_lookup) &&
        length(sids) > 0L) {
      sd <- .dedupe_gsm_by_samn(
        sids, biosample_lookup, libsize_lookup,
        exclude_samn = pair_samn_set
      )
      if (nrow(sd$dropped) > 0L) {
        # Filtra sids/sstudies ai soli kept; preserva ordine originale.
        keep_mask <- sids %in% sd$kept
        sids     <- sids[keep_mask]
        sstudies <- sstudies[keep_mask]
        # Annota il braccio nel log accumulator (chiusura).
        log_chunk <- sd$dropped
        log_chunk$arm <- treatment_label
        samn_dedupe_rows[[length(samn_dedupe_rows) + 1L]] <<- log_chunk
      }
    }

    if (length(sids) == 0L) {
      return(list(rows = NULL, n_studies_augmented = 0L,
                   baseline_studies = character(0L)))
    }

    rows <- tibble::tibble(
      sample_id = sids,
      study     = sstudies,
      treatment = factor(rep(treatment_label, length(sids)),
                          levels = c("control", "treated"))
    )
    bs_set <- unique(unlist(grp$studies_in_cluster))
    augmented <- setdiff(bs_set, pair_cluster$studies_in_cluster)

    # Cap dimensione baseline pool (Problema B). Se questo braccio verrebbe
    # augmentato con piu' di max_baseline_per_arm sample, sotto-campiona: oltre
    # il punto di saturazione l'augmentation non aggiunge potenza (rendimenti
    # decrescenti — il contrasto e' limitato dal braccio del pair) ma fa
    # esplodere memoria/tempo della DE. Subsample deterministico (seed dal
    # cluster_id del pool) + ricalcolo di baseline_studies/n_studies_augmented
    # dal set effettivamente tenuto, cosi' i diagnostics restano onesti.
    if (!is.na(max_baseline_per_arm) &&
        nrow(rows) > as.integer(max_baseline_per_arm)) {
      keep_idx <- .seeded_subsample(nrow(rows), as.integer(max_baseline_per_arm),
                                     seed_key = top$baseline_cluster_id)
      rows <- rows[keep_idx, , drop = FALSE]
      bs_set <- unique(as.character(rows$study))
      augmented <- setdiff(bs_set, pair_cluster$studies_in_cluster)
    }

    list(
      rows = rows,
      n_studies_augmented = length(augmented),
      baseline_studies = bs_set
    )
  }

  control_block <- build_baseline_rows(top_control, "control")
  treated_block <- build_baseline_rows(top_treated, "treated")

  # 3c. Cross-pool conflict drop. Anche con due baseline pool DIVERSI
  # (cluster_id distinti), uno stesso GSM puo' comparire in entrambi quando e'
  # presente in replicate_group assegnati a group cluster diversi (duplicazione
  # ARCHS4 super-series: identico GSM in piu' GSE). Comparire come control E
  # treated lo duplicherebbe (crash) + gli assegnerebbe un ruolo ambiguo. Il
  # sample condiviso e' rimosso da ENTRAMBI i blocchi baseline — coerente con
  # .build_mega_metadata_safe (role_conflict_dropped): paper-grade, non si
  # assume un ruolo arbitrario. I sample del pair sono gia' esclusi a monte
  # (pair_all) e hanno priorita'. Discovery: scan 2026-05-21, 7 cluster (es.
  # pair_L3_9e9a4909 13 sample, pair_L4_6155f541 13 sample).
  if (!is.null(control_block$rows) && !is.null(treated_block$rows)) {
    shared_baseline <- intersect(control_block$rows$sample_id,
                                  treated_block$rows$sample_id)
    if (length(shared_baseline) > 0L) {
      control_block$rows <- control_block$rows[
        !control_block$rows$sample_id %in% shared_baseline, , drop = FALSE]
      treated_block$rows <- treated_block$rows[
        !treated_block$rows$sample_id %in% shared_baseline, , drop = FALSE]
      if (nrow(control_block$rows) == 0L) control_block$rows <- NULL
      if (nrow(treated_block$rows) == 0L) treated_block$rows <- NULL
    }
  }

  # 4. Assemble metadata
  metadata <- pair_rows
  if (!is.null(control_block$rows)) metadata <- rbind(metadata, control_block$rows)
  if (!is.null(treated_block$rows)) metadata <- rbind(metadata, treated_block$rows)
  metadata$study <- as.factor(metadata$study)

  # 5. Effective augmentation flags: se il baseline pool e' completamente
  #    sovrapposto al pair (tutti i sample erano gia' nel pair_all e la dedup
  #    li ha rimossi), baseline_studies post-dedup e' vuoto -> trattiamo come
  #    "no augmentation effettivo" (kind = NA, baseline_pool_id = NULL).
  #    Discovery 2026-05-20 smoke 5-pick: pair piccoli (k=2 entro 2 studi) hanno
  #    spesso baseline pool group derivato dallo stesso replicate_group del
  #    pair stesso -> 100% overlap sample-level.
  ctrl_effective <- !is.null(top_control) &&
    length(control_block$baseline_studies) > 0L
  trt_effective  <- !is.null(top_treated) &&
    length(treated_block$baseline_studies) > 0L

  # 6. Classify comparison_kind per arm (solo se augmentation effettiva)
  kind_ctrl <- if (ctrl_effective) {
    .classify_comparison_kind(pair_cluster$studies_in_cluster,
                                control_block$baseline_studies)
  } else NA_character_
  kind_trt <- if (trt_effective) {
    .classify_comparison_kind(pair_cluster$studies_in_cluster,
                                treated_block$baseline_studies)
  } else NA_character_

  # Overall: least severe (best) dei due — direct_overlap > indirect_partial >
  # indirect_disjoint. NA se entrambi NA.
  kind_levels <- c("indirect_disjoint", "indirect_partial", "direct_overlap")
  kinds_present <- c(kind_ctrl, kind_trt)
  kinds_present <- kinds_present[!is.na(kinds_present)]
  kind_overall <- if (length(kinds_present) == 0L) {
    NA_character_
  } else {
    kind_levels[max(match(kinds_present, kind_levels))]
  }

  # FASE E0b: aggrega log SAMN dedupe baseline (vuoto se lookup NULL).
  samn_dedupe_log <- if (length(samn_dedupe_rows) > 0L) {
    dplyr::bind_rows(samn_dedupe_rows)
  } else {
    log_empty <- .empty_samn_dedupe_dropped()
    log_empty$arm <- character(0)
    log_empty
  }

  list(
    metadata                              = metadata,
    n_baseline_studies_augmented_control  = as.integer(control_block$n_studies_augmented),
    n_baseline_studies_augmented_treated  = as.integer(treated_block$n_studies_augmented),
    comparison_kind_control               = kind_ctrl,
    comparison_kind_treated               = kind_trt,
    comparison_kind_overall               = kind_overall,
    baseline_pool_ids                     = list(
      control = if (ctrl_effective) top_control$baseline_cluster_id else NULL,
      treated = if (trt_effective) top_treated$baseline_cluster_id else NULL
    ),
    bidir_collapsed_to_mono               = bidir_collapsed_to_mono,
    samn_dedupe_log                       = samn_dedupe_log
  )
}

#' Sotto-campiona k indici da n in modo deterministico
#'
#' Helper del cap dimensione baseline pool (Problema B,
#' \code{.assemble_mega_aug_metadata_bidir}). Il seed e' derivato da
#' \code{seed_key} (il \code{cluster_id} del pool): lo stesso pool produce
#' sempre lo stesso sotto-campione (riproducibilita'). Lo stato RNG globale
#' del chiamante e' salvato e ripristinato \emph{via} \code{on.exit}, cosi'
#' la funzione non altera la sequenza RNG esterna.
#'
#' @param n integer: dimensione della popolazione.
#' @param k integer: dimensione campione desiderata. Se \code{k >= n}
#'   ritorna tutti gli indici.
#' @param seed_key character/atomic: chiave da cui derivare il seed.
#' @return integer vector ordinato di indici, lunghezza \code{min(k, n)}.
#' @keywords internal
.seeded_subsample <- function(n, k, seed_key) {
  if (k >= n) return(seq_len(n))
  has_old <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old <- if (has_old) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    if (has_old) {
      assign(".Random.seed", old, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  })
  seed <- sum(utf8ToInt(as.character(seed_key))) %% 2147483647L
  set.seed(seed)
  sort(sample.int(n, k))
}
