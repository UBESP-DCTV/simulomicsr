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
