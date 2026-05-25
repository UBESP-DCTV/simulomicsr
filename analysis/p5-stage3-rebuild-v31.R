#!/usr/bin/env Rscript
# analysis/p5-stage3-rebuild-v31.R
#
# Stage 3 rebuild full con anchor v3.1 + post-hoc ontology override
# (ADR-0018, plan 2026-05-25 Sessione S2 Task 6).
#
# Input:
#   - analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl (879k record)
#   - analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds (39247 record)
#   - analysis/input/human_gene_v2.5.h5 (per gpl_platforms via load_archs4_metadata cache)
#
# Output: analysis/p4-output/<UTC-timestamp>-stage3-v31-<run_id>/
#   - assignments.parquet
#   - clusters.rds (con 11 tracking columns nuove)
#   - record_summary.rds
#   - non_clusterable.rds
#   - run_metadata.json (schema_versions.anchor=v3.1 + resolver=v1.0.0 + ontology_releases)
#
# Wall stima: ~30-60 min su laptop 251GB.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

# Force-load ontology dicts so .ontology_release_meta() restituisce metadati
# completi quando build_stage3_clusters chiama .build_run_metadata().
invisible(simulomicsr:::.load_ontology_dicts())

stage1_path <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"
h5_path     <- "analysis/input/human_gene_v2.5.h5"

stopifnot(file.exists(stage1_path), file.exists(stage2_path))

archs4_meta <- if (file.exists(h5_path)) {
  cli::cli_alert_info("Loading ARCHS4 metadata (cache lookup)")
  load_archs4_metadata(h5_path)
} else {
  cli::cli_alert_warning("H5 non presente: archs4_metadata = NULL (gpl_platforms vuoto)")
  NULL
}
if (!is.null(archs4_meta)) {
  cli::cli_alert_success("ARCHS4 metadata: {nrow(archs4_meta)} sample")
}

config <- stage3_default_config()
cli::cli_inform("schema_versions: anchor={config$schema_versions$anchor}, resolver={config$schema_versions$resolver}")

start <- Sys.time()
s3 <- build_stage3_clusters(
  stage1_master   = stage1_path,
  stage2_master   = stage2_path,
  config          = config,
  archs4_metadata = archs4_meta
)
wall_min <- as.numeric(difftime(Sys.time(), start, units = "mins"))
cli::cli_alert_success("build_stage3_clusters wall: {round(wall_min, 1)} min")

ts      <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_id  <- s3$run_metadata$run_id
out_dir <- sprintf("analysis/p4-output/%s-stage3-v31-%s", ts, run_id)

cli::cli_alert_info("Scrivo output in {out_dir}")
write_stage3_to_dir(s3, out_dir)

cli::cli_h1("Summary")
cli::cli_alert_info("run_id={run_id}")
cli::cli_alert_info("n_clusters     = {nrow(s3$clusters)}")
cli::cli_alert_info("n_assignments  = {nrow(s3$assignments)}")
cli::cli_alert_info("n_non_clust    = {nrow(s3$non_clusterable)}")

if ("kind_overridden" %in% names(s3$clusters)) {
  n_over <- sum(s3$clusters$kind_overridden, na.rm = TRUE)
  pct <- 100 * n_over / nrow(s3$clusters)
  cli::cli_alert_info("kind_overridden: {n_over} ({sprintf('%.2f%%', pct)})")
}
if ("resolution_source" %in% names(s3$clusters)) {
  tbl <- sort(table(s3$clusters$resolution_source, useNA = "ifany"), decreasing = TRUE)
  cli::cli_alert_info("resolution_source top-10:")
  print(head(tbl, 10))
}
