#' Fetch subset Layer A per i cluster_id selezionati
#'
#' Read-only fetch da `stage4_dir`: filtra `cluster_pooled.parquet`,
#' `per_study_de.parquet`, `qc_report.rds` per i `cluster_ids` richiesti.
#' Estrae anche il `run_id` di Stage 4 da `run_metadata.json` per
#' provenance del `run_id` Layer B.
#'
#' @param stage4_dir character path al dir di Layer A output.
#' @param cluster_ids character vector di cluster_id da filtrare.
#'
#' @return list con `cluster_pooled` (tibble), `per_study_de` (tibble, may have
#'   0 rows for mega-strict clusters), `qc_report_subset` (list filtered da qc_report.rds),
#'   `mega_aug_diagnostics` (tibble subset, may be 0 rows), `stage4_run_id` (character).
#' @keywords internal
.fetch_layer_a_subset <- function(stage4_dir, cluster_ids) {
  cp_path <- file.path(stage4_dir, "cluster_pooled.parquet")
  ps_path <- file.path(stage4_dir, "per_study_de.parquet")
  qc_path <- file.path(stage4_dir, "qc_report.rds")
  meta_path <- file.path(stage4_dir, "run_metadata.json")

  for (p in c(cp_path, ps_path, qc_path, meta_path)) {
    if (!file.exists(p)) {
      cli::cli_abort("{basename(p)} not found in stage4_dir: {.path {p}}")
    }
  }

  cp <- arrow::open_dataset(cp_path) |>
    dplyr::filter(cluster_id %in% cluster_ids) |>
    dplyr::collect()

  ps <- arrow::open_dataset(ps_path) |>
    dplyr::filter(cluster_id %in% cluster_ids) |>
    dplyr::collect()

  qc_full <- readRDS(qc_path)
  qc_sub <- list(
    qc_drops_sample = qc_full$qc_drops_sample,  # global, no filter
    qc_drops_study = qc_full$qc_drops_study[qc_full$qc_drops_study$cluster_id %in% cluster_ids, , drop = FALSE],
    qc_drops_cluster = qc_full$qc_drops_cluster[qc_full$qc_drops_cluster$cluster_id %in% cluster_ids, , drop = FALSE],
    pooling_warnings = qc_full$pooling_warnings[qc_full$pooling_warnings$cluster_id %in% cluster_ids, , drop = FALSE]
  )

  mega_aug_diag <- if (!is.null(qc_full$mega_aug_diagnostics) && nrow(qc_full$mega_aug_diagnostics) > 0L) {
    qc_full$mega_aug_diagnostics[qc_full$mega_aug_diagnostics$cluster_id %in% cluster_ids, , drop = FALSE]
  } else {
    tibble::tibble()
  }

  meta <- jsonlite::read_json(meta_path)
  stage4_run_id <- meta$run_id %||% NA_character_

  list(
    cluster_pooled = cp,
    per_study_de = ps,
    qc_report_subset = qc_sub,
    mega_aug_diagnostics = mega_aug_diag,
    stage4_run_id = stage4_run_id
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
