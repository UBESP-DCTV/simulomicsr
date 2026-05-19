#' Assembla metadata sample-rows per MEGA-augmentation
#'
#' Combina sample del pair cluster (treated + control) con sample del baseline
#' pool (cluster group con stesso `control_anchor_key` allo stesso `level`),
#' deduplicando per `sample_id` per evitare double-counting di sample gia'
#' presenti nel pair.
#'
#' @param pair_cluster list con `cluster_id`, `treated_anchor_key`,
#'   `control_anchor_key`, `level`, `studies_in_cluster`, `treated_samples`,
#'   `control_samples`.
#' @param group_baseline tibble di s3$clusters filtrato `mode = "group"`; deve
#'   avere colonne `mode`, `anchor_key`, `level`, `studies_in_cluster`,
#'   `sample_ids`.
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

  # Pair sample rows
  pair_treated <- pair_cluster$treated_samples[[1]]
  pair_control <- pair_cluster$control_samples[[1]]

  pair_rows <- tibble::tibble(
    sample_id = c(pair_treated, pair_control),
    study     = c(
      rep(pair_cluster$studies_in_cluster, length.out = length(pair_treated)),
      rep(pair_cluster$studies_in_cluster, length.out = length(pair_control))
    ),
    treatment = factor(
      c(rep("treated", length(pair_treated)),
        rep("control", length(pair_control))),
      levels = c("control", "treated")
    )
  )

  # Baseline rows: union dei sample_ids dei matching group, deduplicati,
  # escludendo overlap con i sample del pair (no double-counting)
  baseline_samples <- unique(unlist(matching$sample_ids))
  baseline_samples <- setdiff(baseline_samples, c(pair_treated, pair_control))

  # Baseline study identification: lookup back attraverso matching
  # v1 assumption: per baseline cluster c'e' 1 studio per sample (mapping
  # preciso dipende dallo schema Stage 3; questo e' un sample-major heuristic
  # adeguato per il smoke / paper-grade v1)
  baseline_study <- character(length(baseline_samples))
  for (i in seq_len(nrow(matching))) {
    ids <- matching$sample_ids[[i]]
    studies <- matching$studies_in_cluster[[i]]
    matching_idx <- match(ids, baseline_samples)
    matching_idx <- matching_idx[!is.na(matching_idx)]
    if (length(matching_idx) > 0L && length(studies) >= 1L) {
      baseline_study[matching_idx] <- studies[1]
    }
  }

  baseline_rows <- tibble::tibble(
    sample_id = baseline_samples,
    study = baseline_study,
    treatment = factor(
      rep("control", length(baseline_samples)),
      levels = c("control", "treated")
    )
  )

  # Concat base R (evita dipendenza dplyr Suggests)
  metadata <- rbind(pair_rows, baseline_rows)
  metadata$study <- as.factor(metadata$study)

  # Conta studi baseline aggiuntivi (esclusi quelli gia' nel pair)
  baseline_studies <- unique(unlist(matching$studies_in_cluster))
  pair_studies <- pair_cluster$studies_in_cluster
  n_baseline_studies_augmented <- length(setdiff(baseline_studies, pair_studies))

  list(
    metadata = metadata,
    n_baseline_studies_augmented = as.integer(n_baseline_studies_augmented)
  )
}
