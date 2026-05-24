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
# Stage 3 metadata: clusters.rds tiene `anchor_key` pipe-delimited (13 segmenti
# canonical anchor v3, vedi R/stage3-anchor-levels.R::.extract_anchor_segments)
# invece di colonne kind_effective/agent_id/tissue separate. parse_anchor_key()
# e' level-aware: ricostruisce i 13 segmenti canonical da anchor_key + level +
# tier_assignment (default stage3_default_config()$tier_assignment), restituendo
# NA_character_ per i segmenti droppati a quel livello. Vedi R/anchor-parse.R.
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
# parse_anchor_segments: per pair-mode cluster l'anchor_key e'
# <treated>__VS__<control>[__CT_<type>]; per group-mode e' un singolo set.
# Auto-dispatch via mode + estrae kind_effective/agent_id/tissue dal lato
# treated (rilevante per il summary card del case study).
parse_anchor_segments <- function(key, level, mode) {
  res <- tryCatch(
    parse_anchor_key(key, level, mode = mode),
    error = function(e) list()
  )
  # Per pair-mode, l'output e' list(treated, control, comparison_type)
  # con treated = named list 13 segmenti. Per group-mode, output piatto.
  flat <- if (!is.null(res$treated)) res$treated else res
  list(
    kind_effective = flat$kind_effective %||% NA_character_,
    agent_id       = flat$agent_id %||% NA_character_,
    tissue         = flat$tissue %||% NA_character_
  )
}
parsed_segs <- Map(
  parse_anchor_segments,
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

# Counts cache: accesso via .fetch_counts_cached (xxhash32 key), wrappata
# internamente da build_layer_b_results a partire da h5_path.
#
# per_cluster_samples_provider: riusa i dispatch builder di Layer A
# (.build_study_dispatch_from_stage3 + .build_group_dispatch_from_stage3) per
# risolvere cluster_id -> {sample_id, study_id, treatment}. Stage 3 assignments
# tiene record_id (formato <series>_<suffix>) non sample_id direttamente: i
# dispatch builder fanno il join con stage2_master per estrarre i sample_ids
# dei replicate_group treated/control per ogni studio del cluster.
#
# NOTA (limitazione MEGA-AUG): per cluster mega_aug, study_dispatch contiene
# solo i sample del pair (2 studi); il baseline pool augmentation samples non
# sono inclusi. La heatmap del case study mostrera' pair-only samples
# (acceptable per smoke; nel volcano/forest/top-gene-table usiamo cluster_pooled
# che e' il risultato POST-pooling con augmentation, quindi e' completo).

# Costruisci selected_cluster_meta con la colonna method da cluster_pooled
selected_cluster_meta <- s3$clusters[s3$clusters$cluster_id %in% selection$cluster_id, ]
# Arrow non gestisce first()/dplyr verbs lazily al 100%: collect prima poi summarise
cp_sub_meta <- cp |>
  filter(cluster_id %in% selection$cluster_id) |>
  select(cluster_id, method) |>
  collect() |>
  distinct(cluster_id, method)
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
    # pair (rem o mega_aug): pair samples solo
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
    # group (mega): tutti i sample cross-study
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
