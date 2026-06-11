#!/usr/bin/env Rscript
# analysis/p4-fase-f4-stage3-rebuild-v3.R --- RED ALERT FASE F4: Stadio 3 rebuild
# sul master v3 (opzione C) + anchor v3.1.1 + resolver v1.1.0.
#
# Differenze vs p5-stage3-rebuild-v31.R (rebuild β):
#   - stage1_master = master F2 v2 (508.037 record, fullrun Stadio 1 v2)
#   - stage2_master = master Stadio 2 v3 (24.394 studi, 1 record/studio, opzione C)
#   - stage2_input  = input v3 + rescue v3 -> COMPLETENESS GUARD attivo (wirato a
#     F4): i sample non assegnati ai replicate_groups vanno in un gruppo sintetico
#     'unclear' per-studio. .build_stage2_input_lookup legge member_sample_ids
#     (commit c6b9d51), quindi confronta coi GSM reali, non col rappresentante.
#
# Input:
#   analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl
#   analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl
#   analysis/input/archs4-human-stage2-input-v3.jsonl (+ rescue)
#   analysis/input/human_gene_v2.5.h5 (gpl_platforms via cache)
# Output: analysis/p4-output/<UTC>-stage3-v3-<run_id>/ (gitignored)
# Wall stima: ~80 min su laptop 251GB (come i rebuild v3.1.x).

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })
invisible(simulomicsr:::.load_ontology_dicts())

stage1_path   <- "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl"
stage2_path   <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
stage2_inputs <- c("analysis/input/archs4-human-stage2-input-v3.jsonl",
                   "analysis/input/archs4-human-stage2-rescue-v3.jsonl")
h5_path       <- "analysis/input/human_gene_v2.5.h5"
stopifnot(file.exists(stage1_path), file.exists(stage2_path),
          all(file.exists(stage2_inputs)))

archs4_meta <- if (file.exists(h5_path)) {
  cli::cli_alert_info("Loading ARCHS4 metadata (cache lookup)")
  load_archs4_metadata(h5_path)
} else {
  cli::cli_alert_warning("H5 non presente: archs4_metadata = NULL (gpl_platforms vuoto)")
  NULL
}
if (!is.null(archs4_meta)) cli::cli_alert_success("ARCHS4 metadata: {nrow(archs4_meta)} sample")

config <- stage3_default_config()
cli::cli_inform("schema_versions: anchor={config$schema_versions$anchor}, resolver={config$schema_versions$resolver}")

start <- Sys.time()
s3 <- build_stage3_clusters(
  stage1_master   = stage1_path,
  stage2_master   = stage2_path,
  config          = config,
  archs4_metadata = archs4_meta,
  stage2_input    = stage2_inputs
)
wall_min <- as.numeric(difftime(Sys.time(), start, units = "mins"))
cli::cli_alert_success("build_stage3_clusters wall: {round(wall_min, 1)} min")

ts      <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_id  <- s3$run_metadata$run_id
out_dir <- sprintf("analysis/p4-output/%s-stage3-v3-%s", ts, run_id)
cli::cli_alert_info("Scrivo output in {out_dir}")
write_stage3_to_dir(s3, out_dir)

cli::cli_h1("Summary")
cli::cli_alert_info("run_id={run_id}")
cli::cli_alert_info("n_clusters     = {nrow(s3$clusters)}")
cli::cli_alert_info("n_assignments  = {nrow(s3$assignments)}")
cli::cli_alert_info("n_non_clust    = {nrow(s3$non_clusterable)}")
if (!is.null(s3$run_metadata$output_counts$stage2_completeness)) {
  cg <- s3$run_metadata$output_counts$stage2_completeness
  cli::cli_alert_info("completeness guard: {cg$n_uncovered_total} sample -> 'unclear' su {cg$n_records_affected} studi")
}
if ("kind_overridden" %in% names(s3$clusters)) {
  n_over <- sum(s3$clusters$kind_overridden, na.rm = TRUE)
  cli::cli_alert_info("kind_overridden: {n_over} ({sprintf('%.2f%%', 100*n_over/nrow(s3$clusters))})")
}
