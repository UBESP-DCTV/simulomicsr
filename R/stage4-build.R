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
#' @param stage3_assignments tibble \code{assignments.parquet} Stadio 3
#'   (richiesto quando \code{dry_run_inputs_only = FALSE} per costruire i
#'   dispatch per-cluster).
#' @param stage2_master list di study records (output di
#'   \code{.load_stage2_master} o equivalente). Richiesto quando
#'   \code{dry_run_inputs_only = FALSE}.
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
                                 stage3_assignments = NULL,
                                 stage2_master = NULL,
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

  # Step 4b: dispatch builders (stage3_assignments + stage2_master richiesti)
  # Senza dispatch, .run_per_study_de_all stoppa con "attr 'study_dispatch'
  # mancante". Esponi un messaggio piu' utile + attacca i dispatch come
  # attributes di eligible_clusters.
  if (is.null(stage3_assignments) || is.null(stage2_master)) {
    stop("stage3_assignments + stage2_master sono richiesti quando ",
         "dry_run_inputs_only = FALSE")
  }
  study_dispatch <- .build_study_dispatch_from_stage3(
    qc$eligible_clusters, stage3_assignments, stage2_master
  )
  group_dispatch <- .build_group_dispatch_from_stage3(
    qc$eligible_clusters, stage3_assignments, stage2_master
  )
  attr(qc$eligible_clusters, "study_dispatch") <- study_dispatch
  attr(qc$eligible_clusters, "group_dispatch") <- group_dispatch

  # Step 4c: arricchisce stage3_clusters con sample_ids list-column (necessario
  # per il match MEGA-AUG baseline pool in .assemble_mega_aug_metadata)
  stage3_clusters_enriched <- .enrich_group_baseline_sample_ids(
    stage3_clusters, stage3_assignments, stage2_master
  )

  # Step 5: DE per-studio (limma-voom) su tutti i cluster eligible
  per_study_de <- .run_per_study_de_all(
    eligible_clusters = qc$eligible_clusters,
    fetch_fn          = fetch_fn,
    workers           = 1L
  )

  # Step 6: pooling cluster-level (REM metafor o MEGA-AUG dream).
  # Workers risolti via .resolve_dream_workers (auto-detect availableCores -
  # offset, cap a dream_workers_cap). Per workers > 1, .run_dream_mega usa
  # BiocParallel::MulticoreParam. NOTE: OPENBLAS_NUM_THREADS=1 raccomandato
  # nell'ambiente prima di lanciare R, per evitare oversubscription dei worker
  # forkati (vedi ADR-0015).
  dream_workers <- .resolve_dream_workers(config)
  cluster_pooled <- .pool_all_clusters(
    per_study_de      = per_study_de,
    eligible_clusters = qc$eligible_clusters,
    fetch_fn          = fetch_fn,
    stage3_clusters   = stage3_clusters_enriched,
    workers           = dream_workers,
    dream_workers_cap = config$compute$dream_workers_cap
  )

  # Step 7: QC report aggregato. Merge cluster non_processable da QC + dal
  # pool stage (cluster MEGA rank-deficient skippati per scientific validity).
  qc_report <- .build_qc_report(qc$eligible_clusters, per_study_de,
                                 cluster_pooled)
  pool_non_proc <- attr(cluster_pooled, "non_processable_in_pool")
  if (!is.null(pool_non_proc) && nrow(pool_non_proc) > 0L) {
    qc$qc_drops_cluster <- rbind(qc$qc_drops_cluster, pool_non_proc)
    qc_report$qc_drops_cluster <- qc$qc_drops_cluster
  }

  structure(list(
    per_study_de      = per_study_de,
    cluster_pooled    = cluster_pooled,
    eligible_clusters = qc$eligible_clusters,
    qc_report         = qc_report,
    non_processable   = qc_report$qc_drops_cluster,
    config            = config,
    run_metadata      = list(run_id = run_id, timestamp = Sys.time())
  ), class = "stage4_result")
}
