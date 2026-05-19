#' Identifica cluster Layer A (REM proper + MEGA strict + MEGA-aug)
#'
#' Layer A = i ~412 cluster publishable definiti nel finding scope decision
#' 2026-05-19. Aggiunge colonna \code{method} con il path da seguire.
#'
#' @param stage3_clusters tibble di \code{clusters.rds} Stage 3.
#' @param stage4_config output di \code{stage4_default_config}.
#' @return tibble con colonne originali + \code{method} (\code{rem} \code{mega}
#'   \code{mega_aug}).
#' @keywords internal
.identify_layer_a_clusters <- function(stage3_clusters, stage4_config) {
  rem <- stage3_clusters[
    stage3_clusters$usable_rem_strict &
    stage3_clusters$k >= 3L & stage3_clusters$k <= 9L &
    stage3_clusters$mode == "pair",
  ]
  if (nrow(rem) > 0L) rem$method <- "rem"

  mega <- stage3_clusters[
    stage3_clusters$usable_mega_strict &
    stage3_clusters$n_studies >= 5L &
    stage3_clusters$mode == "group",
  ]
  if (nrow(mega) > 0L) mega$method <- "mega"

  # MEGA-AUG: pair k=2 con baseline pool (vedi mega_aug_pair_with_baseline_pool
  # nello spec; v1 identifica come pair k==2 + usable_rem_relaxed + esiste un
  # group cluster con stesso control_anchor allo stesso L).
  # Implementazione semplificata: derivata dal cluster STAGE3 (s3 ha gia' i
  # candidate); per ora marca tutti i pair k=2 mode=pair usable_rem_relaxed
  # con method=mega_aug e flag baseline_pool_check da verificare a build time.
  mega_aug <- stage3_clusters[
    stage3_clusters$mode == "pair" &
    stage3_clusters$k == 2L &
    stage3_clusters$usable_rem_relaxed,
  ]
  if (nrow(mega_aug) > 0L) mega_aug$method <- "mega_aug"

  do.call(rbind, list(rem, mega, mega_aug))
}

#' Filtra sample, studi e cluster per QC sample-level
#'
#' Applica filtro \code{lib_size_min} sui sample del metadata H5 e propaga i
#' drop a livello studio: per ogni (cluster, study) appartenente a Layer A,
#' conta i sample remaining post drop sample-level; se uno studio resta con
#' zero sample, viene registrato in \code{qc_drops_study}. La decisione finale
#' sul cluster (qc_drops_cluster) e' demandata all'orchestratore quando avra'
#' i counts veri.
#'
#' @param stage3_clusters tibble Stage 3 clusters.
#' @param h5_metadata tibble con (sample_id, gsm, gse, lib_size).
#' @param config stage4 config.
#' @return list con \code{eligible_clusters}, \code{qc_drops_sample},
#'   \code{qc_drops_study}, \code{qc_drops_cluster}.
#' @keywords internal
.qc_filter_samples_and_studies <- function(stage3_clusters, h5_metadata, config) {
  layer_a <- .identify_layer_a_clusters(stage3_clusters, config)

  # Sample drops: lib_size sotto soglia
  qc_drops_sample <- h5_metadata[h5_metadata$lib_size < config$qc$lib_size_min, ]
  qc_drops_sample$reason <- "lib_size_below_500k"

  # Studio per cluster: identificato dai studies_in_cluster
  # Per ogni (cluster_id, study_id), conta sample remaining post lib_size
  dropped_samples <- qc_drops_sample$sample_id
  remaining_meta <- h5_metadata[!(h5_metadata$sample_id %in% dropped_samples), ]

  # Pre-popola qc_drops_study iterando sui cluster Layer A: per ogni studio nel
  # cluster, se non resta alcun sample, segnalalo con reason="all_samples_dropped".
  drops_study_rows <- list()
  if (nrow(layer_a) > 0L) {
    for (i in seq_len(nrow(layer_a))) {
      cid <- layer_a$cluster_id[[i]]
      sids <- layer_a$studies_in_cluster[[i]]
      if (is.null(sids) || length(sids) == 0L) next
      for (sid in sids) {
        n_rem <- sum(remaining_meta$gse == sid)
        if (n_rem == 0L) {
          drops_study_rows[[length(drops_study_rows) + 1L]] <- tibble::tibble(
            cluster_id = cid,
            study_id = sid,
            n_treated_remaining = NA_integer_,
            n_control_remaining = NA_integer_,
            reason = "all_samples_dropped"
          )
        }
      }
    }
  }

  if (length(drops_study_rows) > 0L) {
    qc_drops_study <- do.call(rbind, drops_study_rows)
  } else {
    qc_drops_study <- tibble::tibble(
      cluster_id = character(),
      study_id = character(),
      n_treated_remaining = integer(),
      n_control_remaining = integer(),
      reason = character()
    )
  }

  # Cluster eligible post-QC: stessa tibble layer_a, eventualmente con
  # k_post_qc < k (logica future-prooming; v1 conserva i cluster originali +
  # passa i dropped per filtraggio downstream).
  eligible_clusters <- layer_a

  # qc_drops_cluster: cluster non-processable post QC. v1 empty perche'
  # la decisione finale e' presa in orchestratore con counts veri; flag
  # placeholder per output schema.
  qc_drops_cluster <- tibble::tibble(
    cluster_id = character(),
    original_k = integer(),
    qc_final_k = integer(),
    original_n_studies = integer(),
    qc_final_n_studies = integer(),
    reason = character()
  )

  list(
    eligible_clusters = eligible_clusters,
    qc_drops_sample   = qc_drops_sample,
    qc_drops_study    = qc_drops_study,
    qc_drops_cluster  = qc_drops_cluster
  )
}
