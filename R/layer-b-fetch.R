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

#' Assembla counts + metadata per un cluster
#'
#' Combina counts matrix recuperate via `fetch_counts_fn` per ogni studio del
#' cluster + metadata tibble con sample_id, study_id, treatment.
#'
#' Allineato al pattern Layer A (dependency injection): Layer A invoca
#' `.fetch_counts_cached(g, s, h5_path = h5_path)` che usa cache keyed
#' su xxhash32(gse + sorted(sample_ids)). Layer B riusa lo stesso contratto
#' via `fetch_counts_fn(study_id, sample_ids) -> integer matrix`.
#'
#' @param cluster_id character (1).
#' @param per_cluster_samples tibble con `sample_id, study_id, treatment` per
#'   il cluster (assemblata upstream dal caller, tipicamente dal join di Stage 3
#'   assignment + Stage 2 design_role).
#' @param fetch_counts_fn function(study_id, sample_ids) -> integer matrix
#'   (genes x samples_of_study) con rownames HGNC symbol e colnames GSM
#'   accession. Tipicamente wrappa \code{.fetch_counts_cached()}.
#'
#' @return list con `counts` (integer matrix genes x all_samples) e `metadata`
#'   (tibble sample_id, study_id, treatment in colonna-order).
#' @keywords internal
.assemble_cluster_counts <- function(cluster_id, per_cluster_samples, fetch_counts_fn) {
  if (!is.function(fetch_counts_fn)) {
    cli::cli_abort(
      "fetch_counts_fn deve essere una funzione per cluster {.field {cluster_id}}"
    )
  }

  studies <- unique(per_cluster_samples$study_id)
  counts_list <- lapply(studies, function(s) {
    sample_ids_s <- per_cluster_samples$sample_id[per_cluster_samples$study_id == s]
    m <- tryCatch(
      fetch_counts_fn(s, sample_ids_s),
      error = function(e) {
        cli::cli_abort(c(
          "Counts fetch failed for cluster {.field {cluster_id}} / study {.field {s}}",
          "i" = "{conditionMessage(e)}"
        ))
      }
    )
    m
  })
  names(counts_list) <- studies

  # Rownames consistency check
  ref_genes <- rownames(counts_list[[1L]])
  for (s in studies[-1L]) {
    if (!identical(rownames(counts_list[[s]]), ref_genes)) {
      cli::cli_abort(
        "Gene axis mismatch between studies {.field {studies[1L]}} and {.field {s}} for cluster {.field {cluster_id}}"
      )
    }
  }

  # Combine cbind in study order, ensure column order matches per_cluster_samples
  combined <- do.call(cbind, counts_list)

  # Reorder columns to match per_cluster_samples$sample_id
  missing_in_fetch <- setdiff(per_cluster_samples$sample_id, colnames(combined))
  if (length(missing_in_fetch) > 0L) {
    cli::cli_abort(
      "Samples missing from fetch for cluster {.field {cluster_id}}: {.field {missing_in_fetch}}"
    )
  }
  combined <- combined[, per_cluster_samples$sample_id, drop = FALSE]

  list(
    counts = combined,
    metadata = per_cluster_samples
  )
}
