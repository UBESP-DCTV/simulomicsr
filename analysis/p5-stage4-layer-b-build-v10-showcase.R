# analysis/p5-stage4-layer-b-build-v10.R
# RE-SELECTION Layer B sul rework END-TO-END v7. Legge
# analysis/layer-b-selection-v10.csv (8 case study a label forte), esegue
# build_layer_b_results su Layer A v7, render report aggregato.
#
# Pre-requisiti:
#   - analysis/layer-b-selection-v10.csv compilato
#   - Layer A output v7 in
#     /mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032/
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

# v7 re-selection: Layer A/Stage 3 v7 + master Stadio 2 v3 (24.394 studi, 1
# record/serie — LO STESSO master su cui e' stato costruito lo Stadio 3 v7).
stage4_dir    <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"
stage3_dir    <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"
stage2_path   <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
selection_csv <- "analysis/layer-b-selection-v10-showcase.csv"
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
# invece di colonne kind_effective/agent_id/tissue separate.
# extract_anchor_summary() (R/anchor-parse.R) e' wrapper public di
# parse_anchor_key() che ritorna i 3 segmenti chiave per summary card
# (kind_effective, agent_id, tissue), skip-graceful + auto-dispatch pair-mode
# (estrae lato treated).
parsed_segs <- Map(
  extract_anchor_summary,
  s3$clusters$anchor_key, s3$clusters$level, s3$clusters$mode
)
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
# FASE F6 2026-07-05 (ADR-0022): i cluster group NOMINATI (rem_group, mode=group,
# method=rem_group) usano un dispatch dedicato con lo STESSO schema
# {study_id, treated, control} dei pair, quindi si fondono nello study_dispatch
# (esattamente come in R/stage4-build.R:158-171). La selection Layer B v10 e'
# TUTTA rem_group: senza questo merge il per_cluster_samples_provider non
# risolveva alcun cluster (bug scoperto nel run notturno v10, 2026-07-23).
group_rem_dispatch <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
  selected_cluster_meta, assignments, stage2_master,
  n_min = 2L
)
.dup_disp <- intersect(names(study_dispatch), names(group_rem_dispatch))
if (length(.dup_disp) > 0L) {
  cli_abort("cluster_id sovrapposti study/group_rem dispatch: {.dup_disp}")
}
study_dispatch <- c(study_dispatch, group_rem_dispatch)
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
# Render aggregate report (NON-FATALE: i bundle per-cluster + plot sono il
# deliverable; se il render Quarto casca — come i dashboard v9/v10 — il run deve
# completare comunque. Essenziale per il run notturno autonomo.)
# -----------------------------------------------------------------------------
# SHOWCASE: render SKIPPATO qui di proposito. I bundle (PNG + top_genes.csv nel
# nuovo formato ranked-by-significance) sono il deliverable di questo step; il
# render col template restyled avviene in un passo separato a valle.
cli_alert_info("Render SKIPPATO (showcase: render separato col template restyled).")
report_ok <- FALSE

cli_alert_success(
  "Layer B batch OK in {.field {round(wall/60, 1)} min}: {.path {result$dir}} (report_html={report_ok})"
)
