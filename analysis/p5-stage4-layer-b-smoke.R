# analysis/p5-stage4-layer-b-smoke.R
# Smoke 3-cluster pre-batch: validazione visuale di tutta la pipeline Layer B
# senza compilare il CSV utente. Selezione deterministica dei 3 pick dal
# run beta `96c43acb`:
#   - 1 mega strict con n_studies >= 10            (coverage MEGA grande)
#   - 1 mega_aug pair con n_baseline_studies_augmented >= 10 (coverage MEGA-AUG)
#   - 1 mega strict con n_studies 5-6              (coverage borderline)
#
# Wall budget: <=5 min.
#
# Usage:
#   Rscript analysis/p5-stage4-layer-b-smoke.R
# (NB: NO --vanilla su R 4.6.0 + renv 1.1.4 nel project — vedi CLAUDE.md.)

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
  library(dplyr)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L)
  RhpcBLASctl::omp_set_num_threads(1L)
}

cli_h1("Layer B smoke 3-cluster")

stage4_dir       <- "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
stage3_dir       <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
stage2_path      <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"
h5_path          <- "analysis/input/human_gene_v2.5.h5"
counts_cache_dir <- file.path(
  tools::R_user_dir("simulomicsr", "cache"), "stage4-counts"
)

stopifnot(
  dir.exists(stage4_dir),
  dir.exists(stage3_dir),
  file.exists(stage2_path),
  file.exists(h5_path),
  dir.exists(counts_cache_dir)
)

# -----------------------------------------------------------------------------
# Pick 3 cluster deterministici dal cluster_pooled.parquet
# -----------------------------------------------------------------------------
cli_alert_info("Scanning cluster_pooled.parquet per i 3 pick deterministici...")
cp <- arrow::open_dataset(file.path(stage4_dir, "cluster_pooled.parquet"))
meta <- cp |>
  group_by(cluster_id, method, k_effective) |>
  summarise(
    n_sig = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
    n_aug = max(n_baseline_studies_augmented, na.rm = TRUE),
    .groups = "drop"
  ) |>
  collect()

pick <- bind_rows(
  meta |> filter(method == "mega", k_effective >= 10) |>
    arrange(desc(n_sig)) |> slice(1),
  meta |> filter(method == "mega_aug", n_aug >= 10) |>
    arrange(desc(n_sig)) |> slice(1),
  meta |> filter(method == "mega", k_effective %in% 5:6) |>
    arrange(desc(n_sig)) |> slice(1)
)

if (nrow(pick) < 3) {
  cli_abort("Selezione smoke incompleta: trovati solo {nrow(pick)} pick su 3 attesi.")
}

selection <- pick |>
  transmute(
    cluster_id,
    label_paper = paste0("smoke_", c("mega_big", "mega_aug", "mega_small")),
    priority    = 1:3,
    notes       = ""
  )
print(selection)

# -----------------------------------------------------------------------------
# Stage 3 metadata + Stage 2 master + counts cache manifest
# -----------------------------------------------------------------------------
cli_alert_info("Loading Stage 3 metadata + Stage 2 master...")
s3 <- load_stage3(stage3_dir)
stage3_metadata <- s3$clusters[, c(
  "cluster_id", "kind_effective", "agent_id", "tissue", "safety_min"
)]
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
assignments <- s3$assignments

# Counts cache: accesso via .fetch_counts_cached (xxhash32 key), wrappata
# internamente da build_layer_b_results a partire da h5_path.
per_cluster_samples_provider <- function(cluster_id) {
  asg <- assignments[
    assignments$cluster_id == cluster_id,
    c("sample_id", "study_id"),
    drop = FALSE
  ]
  s2 <- stage2_master[
    stage2_master$gsm %in% asg$sample_id,
    c("gsm", "design_role"),
    drop = FALSE
  ]
  role <- s2$design_role[match(asg$sample_id, s2$gsm)]
  asg$treatment <- ifelse(
    role %in% c("control", "vehicle", "untreated"),
    "control",
    "treated"
  )
  asg
}

# -----------------------------------------------------------------------------
# Build smoke + render
# -----------------------------------------------------------------------------
cli_alert_info("Build Layer B smoke...")
t0 <- Sys.time()
out_dir <- file.path(
  "analysis/p4-output",
  sprintf(
    "%s-layer-b-smoke-%s",
    format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
    substr(digest::digest(selection$cluster_id), 1, 8)
  )
)
result <- build_layer_b_results(
  stage4_dir                   = stage4_dir,
  selection                    = selection,
  h5_path                      = h5_path,
  per_cluster_samples_provider = per_cluster_samples_provider,
  stage3_metadata              = stage3_metadata,
  config                       = layer_b_default_config(),
  out_dir                      = out_dir
)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

render_layer_b_report(result, file.path(result$dir, "layer_b_report.html"))

cli_alert_success(
  "Smoke OK in {.field {round(wall/60, 1)} min}: {.path {result$dir}}"
)
cli_alert("Open report: {.path {file.path(result$dir, 'layer_b_report.html')}}")
cli_alert("VALIDATE manualmente:")
cli_alert("  - 3 cluster bundle generati (mega_big, mega_aug, mega_small)")
cli_alert("  - Volcano + heatmap + GO + summary card presenti per ogni cluster")
cli_alert("  - forest.png solo per mega_aug")
cli_alert("  - heterogeneity caption esplicativa 'N/A non-REM' per tutti (0 REM nel run beta)")
