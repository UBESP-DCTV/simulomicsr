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
#     (pattern file: <xxhash32_key>.rds, gestito da .fetch_counts_cached)
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
# Stage 3 metadata: clusters.rds tiene `anchor_key` pipe-delimited (13 segmenti
# canonical anchor v3, vedi R/stage3-anchor-levels.R::.extract_anchor_segments)
# invece di colonne kind_effective/agent_id/tissue separate. Parsing positional
# per L0 (13 segmenti completi); per altri level i segmenti vengono droppati e
# il parsing diventa level-aware (TODO v2 — per ora best-effort solo su L0).
parse_anchor_segments <- function(key, level) {
  if (is.na(level) || level != 0L) {
    return(list(kind_effective = NA_character_, agent_id = NA_character_, tissue = NA_character_))
  }
  segs <- strsplit(key, "|", fixed = TRUE)[[1L]]
  if (length(segs) != 13L) {
    return(list(kind_effective = NA_character_, agent_id = NA_character_, tissue = NA_character_))
  }
  list(kind_effective = segs[1L], agent_id = segs[2L], tissue = segs[11L])
}
parsed_segs <- Map(parse_anchor_segments, s3$clusters$anchor_key, s3$clusters$level)
stage3_metadata <- tibble::tibble(
  cluster_id     = s3$clusters$cluster_id,
  kind_effective = vapply(parsed_segs, function(x) x$kind_effective, character(1L)),
  agent_id       = vapply(parsed_segs, function(x) x$agent_id, character(1L)),
  tissue         = vapply(parsed_segs, function(x) x$tissue, character(1L)),
  safety_min     = s3$clusters$safety_min
)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
assignments <- s3$assignments
cli_alert_success(sprintf(
  "Loaded in %.1fs (clusters=%d, assignments=%d, stage2_master=%d).",
  as.numeric(difftime(Sys.time(), t_load, units = "secs")),
  nrow(s3$clusters), nrow(assignments), nrow(stage2_master)
))

# -----------------------------------------------------------------------------
# Counts cache (riusata dal Layer A) — accesso via .fetch_counts_cached,
# keyed su xxhash32(gse + sorted(sample_ids)). build_layer_b_results costruisce
# internamente la fetch_counts_fn default a partire da h5_path.
# -----------------------------------------------------------------------------
counts_cache_dir <- file.path(
  tools::R_user_dir("simulomicsr", "cache"), "stage4-counts"
)
if (!dir.exists(counts_cache_dir)) {
  cli_abort("Stage 4 counts cache mancante: {.path {counts_cache_dir}}")
}

# -----------------------------------------------------------------------------
# per_cluster_samples_provider: usa i dispatch builder di Layer A
# (.build_study_dispatch_from_stage3 + .build_group_dispatch_from_stage3) per
# risolvere cluster_id -> {sample_id, study_id, treatment}. Stage 3 assignments
# tiene record_id (formato <series>_<suffix>) non sample_id direttamente: i
# dispatch builder fanno il join con stage2_master per estrarre i sample_ids
# dei replicate_group treated/control per ogni studio del cluster.
#
# NOTA (limitazione MEGA-AUG): per cluster mega_aug, study_dispatch contiene
# solo i sample del pair (2 studi); il baseline pool augmentation samples non
# sono inclusi. La heatmap del case study mostrera' pair-only samples
# (acceptable: volcano/forest/top-gene-table/GO usano cluster_pooled che e' il
# risultato POST-pooling con augmentation, quindi e' completo).
# -----------------------------------------------------------------------------
cli_alert_info("Building study/group dispatch per la selection...")
selection_csv_loaded <- simulomicsr:::.load_layer_b_selection(selection_csv)
selected_cluster_meta <- s3$clusters[
  s3$clusters$cluster_id %in% selection_csv_loaded$cluster_id, ]
cp_sub_meta <- arrow::open_dataset(file.path(stage4_dir, "cluster_pooled.parquet")) |>
  dplyr::filter(cluster_id %in% selection_csv_loaded$cluster_id) |>
  dplyr::select(cluster_id, method) |>
  dplyr::collect() |>
  dplyr::distinct(cluster_id, method)
selected_cluster_meta$method <- cp_sub_meta$method[
  match(selected_cluster_meta$cluster_id, cp_sub_meta$cluster_id)
]

study_dispatch <- simulomicsr:::.build_study_dispatch_from_stage3(
  selected_cluster_meta, assignments, stage2_master
)
group_dispatch <- simulomicsr:::.build_group_dispatch_from_stage3(
  selected_cluster_meta, assignments, stage2_master
)

per_cluster_samples_provider <- function(cluster_id) {
  if (cluster_id %in% names(study_dispatch)) {
    items <- study_dispatch[[cluster_id]]
    do.call(rbind, lapply(items, function(it) {
      data.frame(
        sample_id = c(it$treated, it$control),
        study_id  = it$study_id,
        treatment = c(rep("treated", length(it$treated)),
                      rep("control", length(it$control))),
        stringsAsFactors = FALSE
      )
    }))
  } else if (cluster_id %in% names(group_dispatch)) {
    items <- group_dispatch[[cluster_id]]
    do.call(rbind, lapply(items, function(it) {
      data.frame(
        sample_id = it$sample_ids,
        study_id  = it$study_id,
        treatment = it$treatment,
        stringsAsFactors = FALSE
      )
    }))
  } else {
    stop(sprintf("Cluster %s non risolto in study/group dispatch", cluster_id))
  }
}

# -----------------------------------------------------------------------------
# Batch build
# -----------------------------------------------------------------------------
cli_alert_info("Build Layer B...")
t0 <- Sys.time()
result <- build_layer_b_results(
  stage4_dir                   = stage4_dir,
  selection                    = selection_csv,
  h5_path                      = h5_path,
  per_cluster_samples_provider = per_cluster_samples_provider,
  stage3_metadata              = stage3_metadata,
  config                       = layer_b_default_config()
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
