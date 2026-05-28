#' Scrive stage4 result in directory con 5 file convenzionali
#'
#' Serializza un oggetto \code{stage4_result} (output di
#' \code{build_stage4_results}) su disco usando il layout canonico Stage 4:
#' due parquet (per_study_de + cluster_pooled, zstd level 9), due rds xz
#' (qc_report + non_processable) e un JSON pretty (run_metadata).
#'
#' @param s4 stage4_result list (output di \code{build_stage4_results}).
#' @param dir target directory; creata se non esiste.
#' @return invisible(character) paths dei file scritti.
#' @export
write_stage4_to_dir <- function(s4, dir) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

  paths <- list(
    per_study_de    = file.path(dir, "per_study_de.parquet"),
    cluster_pooled  = file.path(dir, "cluster_pooled.parquet"),
    qc_report       = file.path(dir, "qc_report.rds"),
    non_processable = file.path(dir, "non_processable.rds"),
    run_metadata    = file.path(dir, "run_metadata.json")
  )

  arrow::write_parquet(s4$per_study_de, paths$per_study_de,
                       compression = "zstd", compression_level = 9L)
  arrow::write_parquet(s4$cluster_pooled, paths$cluster_pooled,
                       compression = "zstd", compression_level = 9L)
  saveRDS(s4$qc_report, paths$qc_report, compress = "xz")
  non_proc <- s4$non_processable
  if (is.null(non_proc)) non_proc <- tibble::tibble()
  saveRDS(non_proc, paths$non_processable, compress = "xz")

  # Timestamp: format() su POSIXct, altrimenti as.character() (la string
  # passata dal chiamante e' gia' ISO-8601). format.default su character
  # fallisce perche' interpreta il secondo arg come 'trim'.
  ts_raw <- s4$run_metadata$timestamp
  ts_str <- if (inherits(ts_raw, "POSIXt")) {
    format(ts_raw, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  } else {
    as.character(ts_raw)
  }

  meta <- list(
    run_id = s4$run_metadata$run_id,
    timestamp = ts_str,
    schema_versions = s4$config$schema_versions,
    # FASE E2 ADR-0019 D7: filter biotype effettivamente applicato in
    # questo run. NULL/missing = no filter (~67k geni); default
    # 'protein_coding' = ~23k geni. Override possibile a vector
    # multi-valore (es. c('protein_coding','lncRNA')).
    gene_biotype_filter = s4$run_metadata$gene_biotype_filter %||%
      "(missing: pre-E2 result)",
    # T7b Fix 2 paper-grade audit trace (post Codex review): summary
    # cardinalita' osservata del gene axis post-filter. Documenta
    # l'EFFETTO del filter (n_total H5, n_post_filter, n_biotype_na
    # droppati, biotypes_kept). NULL se fetch_fn esterno con h5_path
    # NULL (non possiamo introspettare).
    gene_axis_summary = s4$run_metadata$gene_axis_summary,
    package_version = as.character(utils::packageVersion("simulomicsr")),
    r_version = R.version.string,
    config = s4$config,
    output_counts = list(
      n_per_study_de_rows   = nrow(s4$per_study_de),
      n_cluster_pooled_rows = nrow(s4$cluster_pooled),
      by_method = if (nrow(s4$cluster_pooled) > 0L) {
        as.list(table(s4$cluster_pooled$method))
      } else list()
    )
  )
  writeLines(
    jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, na = "null"),
    paths$run_metadata
  )

  invisible(unlist(paths))
}

#' Carica stage4 result da directory
#'
#' Ricostruisce un oggetto \code{stage4_result} dai 5 file scritti da
#' \code{write_stage4_to_dir}. Round-trip preserva per_study_de,
#' cluster_pooled, qc_report, non_processable, config e run_metadata
#' (run_id + timestamp).
#'
#' @param dir directory contenente i 5 file Stage 4.
#' @return list stage4_result.
#' @export
load_stage4 <- function(dir) {
  stopifnot(dir.exists(dir))

  meta <- jsonlite::fromJSON(file.path(dir, "run_metadata.json"),
                             simplifyVector = FALSE)

  list(
    per_study_de    = arrow::read_parquet(file.path(dir, "per_study_de.parquet")),
    cluster_pooled  = arrow::read_parquet(file.path(dir, "cluster_pooled.parquet")),
    qc_report       = readRDS(file.path(dir, "qc_report.rds")),
    non_processable = readRDS(file.path(dir, "non_processable.rds")),
    config          = meta$config,
    run_metadata    = list(
      run_id    = meta$run_id,
      timestamp = meta$timestamp
    )
  )
}
