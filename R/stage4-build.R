#' Entry-point Stadio 4: end-to-end DE per-studio + MEGA cluster pooling
#'
#' Esegue i 5 sub-stage: QC + filter, calcolo run_id deterministico,
#' DE per-studio (limma-voom), pooling cluster-level (REM via metafor o
#' MEGA-AUG via dream), aggregazione QC report. Il render del dashboard
#' viene gestito separatamente da \code{render_stage4_dashboard}.
#'
#' Output e' un oggetto S3 \code{stage4_result} consumato da
#' \code{write_stage4_to_dir} per la persistenza on-disk.
#'
#' @param stage3_clusters tibble \code{clusters.rds} prodotto da Stadio 3.
#' @param h5_metadata tibble sample-level (\code{sample_id}, \code{gsm},
#'   \code{gse}, \code{lib_size}).
#' @param config output di \code{stage4_default_config()}.
#' @param fetch_fn funzione \code{(gse, sample_ids) -> matrix} per recuperare
#'   counts. Default chiama \code{.fetch_counts_cached} con \code{h5_path}.
#' @param h5_path path al file H5 ARCHS4 (richiesto se \code{fetch_fn=NULL}).
#' @param stage3_run_id stringa run_id Stadio 3 per input_hashes.
#' @param h5_path_for_hash path al H5 per il calcolo sha256 (NULL se non si
#'   vuole hashare il H5; in tal caso usa placeholder "unknown").
#' @param dry_run_inputs_only logical: se TRUE, restituisce solo
#'   eligible_clusters + run_metadata + scaffold vuoti (skip DE/pooling)
#'   per debug rapido o test di integrazione minimi.
#' @return oggetto S3 \code{stage4_result} (list) con campi:
#'   \code{per_study_de}, \code{cluster_pooled}, \code{eligible_clusters},
#'   \code{qc_report}, \code{non_processable}, \code{config},
#'   \code{run_metadata}.
#' @export
build_stage4_results <- function(stage3_clusters, h5_metadata,
                                 config = stage4_default_config(),
                                 fetch_fn = NULL, h5_path = NULL,
                                 stage3_run_id = NULL,
                                 h5_path_for_hash = NULL,
                                 dry_run_inputs_only = FALSE) {

  # Step 1: QC sample + studio + cluster
  qc <- .qc_filter_samples_and_studies(stage3_clusters, h5_metadata, config)

  # Step 2: Calcolo run_id deterministico (hash di input + config + schema)
  stage3_hash <- if (is.null(stage3_run_id)) "unknown" else stage3_run_id
  h5_hash <- if (!is.null(h5_path_for_hash)) {
    substr(digest::digest(h5_path_for_hash, algo = "sha256", file = TRUE),
           1L, 16L)
  } else {
    "unknown"
  }
  hashes <- list(stage3 = stage3_hash, h5 = h5_hash)
  run_id <- .run_id_for_stage4(hashes, config, config$schema_versions)

  # Step 3: short-circuit per dry-run / debug rapido
  if (isTRUE(dry_run_inputs_only)) {
    return(structure(list(
      per_study_de      = .empty_per_study_de(),
      cluster_pooled    = .empty_pooled_rem(),
      eligible_clusters = qc$eligible_clusters,
      qc_report         = qc[c("qc_drops_sample", "qc_drops_study",
                                "qc_drops_cluster")],
      non_processable   = qc$qc_drops_cluster,
      config            = config,
      run_metadata      = list(run_id = run_id, timestamp = Sys.time())
    ), class = "stage4_result"))
  }

  # Step 4: default fetch_fn cacheato su disco se non specificato
  if (is.null(fetch_fn)) {
    if (is.null(h5_path)) {
      stop("h5_path e' richiesto quando fetch_fn e' NULL")
    }
    fetch_fn <- function(g, s) .fetch_counts_cached(g, s, h5_path = h5_path)
  }

  # Step 5: DE per-studio (limma-voom) su tutti i cluster eligible
  per_study_de <- .run_per_study_de_all(
    eligible_clusters = qc$eligible_clusters,
    fetch_fn          = fetch_fn,
    workers           = 1L
  )

  # Step 6: pooling cluster-level (REM metafor o MEGA-AUG dream)
  cluster_pooled <- .pool_all_clusters(
    per_study_de      = per_study_de,
    eligible_clusters = qc$eligible_clusters,
    fetch_fn          = fetch_fn,
    stage3_clusters   = stage3_clusters,
    workers           = 1L,
    dream_workers_cap = config$compute$dream_workers_cap
  )

  # Step 7: QC report aggregato
  qc_report <- .build_qc_report(qc$eligible_clusters, per_study_de,
                                 cluster_pooled)

  structure(list(
    per_study_de      = per_study_de,
    cluster_pooled    = cluster_pooled,
    eligible_clusters = qc$eligible_clusters,
    qc_report         = qc_report,
    non_processable   = qc$qc_drops_cluster,
    config            = config,
    run_metadata      = list(run_id = run_id, timestamp = Sys.time())
  ), class = "stage4_result")
}
