# analysis/p5-stage4-layer-a-fullrun.R
# Layer A full run Stadio 4 — Stage 3 build 20260519T055547Z-stage3-2153addc
#
# Cluster eleggibili Layer A (vedi .identify_layer_a_clusters):
#   - rem proper (usable_rem_strict & k in [3,9] & mode=pair)   = 0 (in
#     questo Stage 3; usable_rem_strict e' 0 sull'intero dataset)
#   - mega strict (usable_mega_strict & n_studies>=5 & mode=group) = 312
#   - mega_aug (mode=pair & k==2 & usable_rem_relaxed)           = 310
# Totale Layer A: ~622 cluster.
#
# Wall budget atteso: ~17-28h overnight su dgx 128-core con dream parallel
# (ADR-0015, workers auto-detect ~100). Bench smoke 5-pick = 820 sec → media
# 164 sec/cluster × 622 = ~28h. Stima conservativa.
#
# Peak RAM atteso: ~10-20 GB (fork COW di ~3 GB RSS × 100 worker; pagine
# modificate). Verificato non OOM su DGX 251 GB.
#
# Pre-requisiti env (lancio):
#   export OPENBLAS_NUM_THREADS=1
#   export OMP_NUM_THREADS=1
#
# Usage:
#   nohup Rscript analysis/p5-stage4-layer-a-fullrun.R \
#     2>&1 | tee analysis/p5-stage4-layer-a-fullrun.log &
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

cli_h1("Stadio 4 Layer A full run")

stage3_dir  <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

stopifnot(dir.exists(stage3_dir), file.exists(h5_path), file.exists(stage2_path))

cli_alert_info("Loading stage3 + stage2_master...")
t0 <- Sys.time()
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success(
  "Loaded: {nrow(s3$clusters)} clusters / {nrow(s3$assignments)} assignments / {length(stage2_master)} stage2 studies (wall {round(as.numeric(difftime(Sys.time(), t0, units='secs')), 1)} sec)"
)

# ---- h5_metadata: placeholder lib_size ------------------------------------
# Stage 4 QC richiede colonne (sample_id, gsm, gse, lib_size). load_archs4_metadata
# non calcola lib_size (richiederebbe colSums sull'intero H5 47 GB). Per Layer A
# usiamo lib_size = 1e7 (placeholder sopra soglia QC 5e5) per TUTTI i sample
# Layer A. filterByExpr a livello gene in voom/dream applica filtri equivalenti
# downstream. TODO future: pre-computare lib_size cache come target separato.
cli_alert_info("Building h5_metadata (placeholder lib_size for Layer A samples)...")

# Identifica Layer A clusters + i sample referenziati via assignments+stage2.
config <- stage4_default_config()
# Override per Task 21: MEGA-AUG bidirezionale attivato (default conservativo
# resta legacy_monodirectional=TRUE, sara' flipped a FALSE come default solo
# post-fullrun verde). Coverage analysis 2026-05-20 ha confermato: 92% dei
# pair Layer A hanno augmentation effettiva (median 143 extra sample, vedi
# docs/findings/2026-05-20-mega-aug-bidirectional-method.md sez. 6.2).
config$mega_aug$legacy_monodirectional <- FALSE
cli_alert_info(
  "MEGA-AUG mode: BIDIREZIONALE (anchor_policy={config$mega_aug$anchor_policy}, direction={config$mega_aug$direction}, disjoint_policy={config$mega_aug$disjoint_policy})"
)
layer_a <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, config)
cli_alert_info(
  "Layer A: {nrow(layer_a)} clusters (rem={sum(layer_a$method=='rem')}, mega={sum(layer_a$method=='mega')}, mega_aug={sum(layer_a$method=='mega_aug')})"
)

# Per il baseline pool MEGA-AUG dobbiamo includere TUTTI i group cluster i cui
# anchor_key matchano i control_anchor_key dei mega_aug pair picks. Espandiamo
# il set di cluster_id rilevanti per la dispatch.
pair_aug <- layer_a[layer_a$method == "mega_aug", ]
parse_ck <- function(ak, lv) {
  s <- ak
  if (lv %in% c(0L, 1L)) s <- sub("__CT_[^_].*$", "", s)
  p <- strsplit(s, "__VS__", fixed = TRUE)[[1L]]
  if (length(p) != 2L) NA_character_ else p[2L]
}
baseline_cids <- character(0L)
for (i in seq_len(nrow(pair_aug))) {
  ck <- parse_ck(pair_aug$anchor_key[i], pair_aug$level[i])
  if (is.na(ck)) next
  matches <- s3$clusters$cluster_id[
    s3$clusters$mode == "group" &
    s3$clusters$level == pair_aug$level[i] &
    s3$clusters$anchor_key == ck
  ]
  baseline_cids <- unique(c(baseline_cids, matches))
}
cli_alert_info("MEGA-AUG baseline cluster matchati: {length(baseline_cids)}")

# Tutti i sample referenziati dai cluster (Layer A + baseline pool MEGA-AUG)
relevant_cids <- unique(c(layer_a$cluster_id, baseline_cids))
relevant_asg <- s3$assignments[s3$assignments$cluster_id %in% relevant_cids, ]
cli_alert_info("Assignments rilevanti: {nrow(relevant_asg)}")

# Estrai sample IDs via .build_*_dispatch_from_stage3 (riusa il path validato)
s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) {
  if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
}
collect_sids <- function(record_id) {
  parts <- regmatches(record_id, regexpr("__", record_id), invert = TRUE)[[1L]]
  if (length(parts) < 2L) return(character(0L))
  ser <- parts[1L]; suf <- parts[2L]
  if (!exists(ser, envir = s2_idx, inherits = FALSE)) return(character(0L))
  st <- get(ser, envir = s2_idx, inherits = FALSE)
  rg_lookup <- setNames(st$replicate_groups,
                         vapply(st$replicate_groups, `[[`,
                                character(1L), "group_id"))
  cmp <- NULL
  for (c in st$comparisons) if (identical(c$comparison_id, suf)) { cmp <- c; break }
  if (!is.null(cmp)) {
    tg <- rg_lookup[[cmp$treated_group]]
    cg <- rg_lookup[[cmp$control_group]]
    return(c(as.character(unlist(tg$sample_ids)),
             as.character(unlist(cg$sample_ids))))
  }
  rg <- rg_lookup[[suf]]
  if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
  character(0L)
}
all_samples <- unique(unlist(lapply(relevant_asg$record_id, collect_sids)))
cli_alert_info("Sample IDs totali Layer A: {length(all_samples)}")

# Map GSM → GSE via stage2_master scan
gse_for_sid <- character(length(all_samples))
names(gse_for_sid) <- all_samples
for (st in stage2_master) {
  for (rg in st$replicate_groups) {
    sids <- as.character(unlist(rg$sample_ids))
    hit <- intersect(sids, all_samples)
    if (length(hit) > 0L) gse_for_sid[hit] <- st$series_id
  }
}
missing_gse <- sum(gse_for_sid == "" | is.na(gse_for_sid))
if (missing_gse > 0L) {
  cli_alert_warning("{.val {missing_gse}} sample senza GSE — dropped")
  ok <- !(gse_for_sid == "" | is.na(gse_for_sid))
  all_samples <- all_samples[ok]
  gse_for_sid <- gse_for_sid[ok]
}

h5_metadata <- tibble::tibble(
  sample_id = all_samples,
  gsm       = all_samples,
  gse       = unname(gse_for_sid),
  lib_size  = 1e7L  # placeholder; vedi nota sopra
)
cli_alert_success("h5_metadata: {nrow(h5_metadata)} sample")

# ---- Build Stage 4 results ------------------------------------------------
cli_h2("build_stage4_results")
cli_alert_info("dream_workers resolved: {simulomicsr:::.resolve_dream_workers(config)}")
t1 <- Sys.time()
result <- build_stage4_results(
  stage3_clusters    = s3$clusters,
  h5_metadata        = h5_metadata,
  config             = config,
  h5_path            = h5_path,
  stage3_run_id      = s3$run_metadata$run_id,
  h5_path_for_hash   = h5_path,
  stage3_assignments = s3$assignments,
  stage2_master      = stage2_master
)
wall_sec <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
cli_alert_success(
  "Build complete in {round(wall_sec / 60, 1)} min ({round(wall_sec, 1)} sec) — run_id {result$run_metadata$run_id}"
)

# ---- Write output ---------------------------------------------------------
out_dir <- file.path(
  "analysis/p4-output",
  sprintf("%s-stage4-%s",
          format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
          result$run_metadata$run_id)
)
cli_alert_info("Writing to {.path {out_dir}}...")
write_stage4_to_dir(result, out_dir)

# ---- Render dashboard ------------------------------------------------------
cli_alert_info("Rendering dashboard...")
render_stage4_dashboard(out_dir)
cli_alert_success("Dashboard: {.path {file.path(out_dir, 'stage4_dashboard.html')}}")

# ---- Summary --------------------------------------------------------------
cli_h2("Layer A summary")
cli_dl(list(
  "Cluster processed"     = length(unique(result$cluster_pooled$cluster_id)),
  "Cluster non-processable" = nrow(result$non_processable),
  "Per-study DE rows"      = nrow(result$per_study_de),
  "Cluster pooled rows"    = nrow(result$cluster_pooled),
  "Significant (FDR<0.05)" = sum(result$cluster_pooled$FDR_BH_within_cluster < 0.05, na.rm = TRUE),
  "Methods"                = paste(sort(unique(result$cluster_pooled$method)), collapse = ", "),
  "Run id"                 = result$run_metadata$run_id,
  "Wall total"             = sprintf("%.1f min", wall_sec / 60),
  "Output dir"             = out_dir
))

cli_alert_success("Layer A full run OK")
