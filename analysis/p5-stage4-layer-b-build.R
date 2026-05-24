# analysis/p5-stage4-layer-b-build.R
# Layer B batch build: legge analysis/layer-b-selection.csv,
# esegue build_layer_b_results, render report aggregato.
#
# Pre-requisiti:
#   - analysis/layer-b-selection.csv compilato (10-20 cluster_id)
#   - Layer A output esistente in
#     analysis/p4-output/20260523T032601Z-stage4-96c43acb/
#   - Stage 4 counts cache in
#     tools::R_user_dir("simulomicsr","cache")/stage4-counts/
#     (pattern file: <cluster_id>__<study_id>.rds)
#
# Usage:
#   nohup Rscript analysis/p5-stage4-layer-b-build.R \
#     2>&1 | tee analysis/p5-stage4-layer-b-build.log &
# (NB: NO --vanilla su R 4.6.0 + renv 1.1.4 nel project — vedi CLAUDE.md.)

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L)
  RhpcBLASctl::omp_set_num_threads(1L)
}

cli_h1("Stadio 4 Layer B batch build")

stage4_dir    <- "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
stage3_dir    <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
stage2_path   <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"
selection_csv <- "analysis/layer-b-selection.csv"
h5_path       <- "analysis/input/human_gene_v2.5.h5"

stopifnot(
  dir.exists(stage4_dir),
  dir.exists(stage3_dir),
  file.exists(stage2_path),
  file.exists(selection_csv),
  file.exists(h5_path)
)

# -----------------------------------------------------------------------------
# Pre-validation della selection contro Stage 4
# -----------------------------------------------------------------------------
cli_alert_info("Pre-validation della selection...")
val <- layer_b_validate_selection(selection_csv, stage4_dir)
print(val)
if (any(!val$exists_in_stage4)) {
  cli_abort("Alcuni cluster_id sono assenti dal Layer A — interrompo.")
}

# -----------------------------------------------------------------------------
# Stage 3 metadata (per summary card) + Stage 2 master (per design_role)
# -----------------------------------------------------------------------------
cli_alert_info("Loading Stage 3 metadata + Stage 2 master...")
t_load <- Sys.time()
s3 <- load_stage3(stage3_dir)
stage3_metadata <- s3$clusters[, c(
  "cluster_id", "kind_effective", "agent_id", "tissue", "safety_min"
)]
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
assignments <- s3$assignments
cli_alert_success(sprintf(
  "Loaded in %.1fs (clusters=%d, assignments=%d, stage2_master=%d).",
  as.numeric(difftime(Sys.time(), t_load, units = "secs")),
  nrow(s3$clusters), nrow(assignments), nrow(stage2_master)
))

# -----------------------------------------------------------------------------
# Counts cache manifest (riusato dal Layer A)
# Pattern: <cache_dir>/<cluster_id>__<study_id>.rds
# -----------------------------------------------------------------------------
counts_cache_dir <- file.path(
  tools::R_user_dir("simulomicsr", "cache"), "stage4-counts"
)
if (!dir.exists(counts_cache_dir)) {
  cli_abort("Stage 4 counts cache mancante: {.path {counts_cache_dir}}")
}

build_manifest <- function(cache_dir, cluster_ids) {
  out <- list()
  for (cl_id in cluster_ids) {
    pat <- sprintf("^%s__.+\\.rds$", cl_id)
    files <- list.files(cache_dir, pattern = pat, full.names = TRUE)
    studies <- sub(sprintf("^%s__", cl_id), "",
                   sub("\\.rds$", "", basename(files)))
    out[[cl_id]] <- setNames(as.list(files), studies)
  }
  out
}
counts_cache_manifest <- build_manifest(counts_cache_dir, val$cluster_id)

# -----------------------------------------------------------------------------
# per_cluster_samples_provider: join Stage 3 assignment + Stage 2 design_role
# (signature contrattuale: function(cluster_id) -> tibble {sample_id, study_id, treatment})
# -----------------------------------------------------------------------------
per_cluster_samples_provider <- function(cluster_id) {
  asg <- assignments[
    assignments$cluster_id == cluster_id,
    c("sample_id", "study_id"),
    drop = FALSE
  ]
  s2_rows <- stage2_master[
    stage2_master$gsm %in% asg$sample_id,
    c("gsm", "design_role"),
    drop = FALSE
  ]
  role <- s2_rows$design_role[match(asg$sample_id, s2_rows$gsm)]
  asg$treatment <- ifelse(
    role %in% c("control", "vehicle", "untreated"),
    "control",
    "treated"
  )
  asg
}

# -----------------------------------------------------------------------------
# Batch build
# -----------------------------------------------------------------------------
cli_alert_info("Build Layer B...")
t0 <- Sys.time()
result <- build_layer_b_results(
  stage4_dir                   = stage4_dir,
  selection                    = selection_csv,
  counts_cache_manifest        = counts_cache_manifest,
  per_cluster_samples_provider = per_cluster_samples_provider,
  stage3_metadata              = stage3_metadata,
  config                       = layer_b_default_config(),
  h5_path                      = h5_path
)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

# -----------------------------------------------------------------------------
# Render aggregate report
# -----------------------------------------------------------------------------
cli_alert_info("Render aggregate report...")
render_layer_b_report(result, file.path(result$dir, "layer_b_report.html"))

cli_alert_success(
  "Layer B batch OK in {.field {round(wall/60, 1)} min}: {.path {result$dir}}"
)
