# analysis/p4-fase-f5-stage4-layer-a-rebuild-v3.R --- RED ALERT FASE F5.
# Layer A full run Stadio 4 sul NUOVO Stadio 3 v3 (opzione C) + master v3.
#
# Differenze vs p5-stage4-layer-a-fullrun.R (96c43acb):
#   - stage3_dir  = 20260611T171555Z-stage3-v3-364547a7 (master v3, completeness
#     guard, anchor v3.1.1)
#   - stage2_path = p4-fase-f4-stage2-master-v3.jsonl (24.394 studi, 1 record/studio)
#   - FASE E gia' DEFAULT in build_stage4_results: gene axis Ensembl (E1), biotype
#     filter protein_coding (E2), covariate batch instrument_model+aligner_class (E3).
#
# Config invariata vs 96c43acb (uniformity): MEGA-AUG bidirezionale,
# max_baseline_per_arm=350, dream_workers_cap=16, de_engine mega/mega_aug=dream.
#
# DRY_RUN=1 -> si ferma dopo identificazione Layer A + conteggio sample (no DE).
#
# Usage (full): nohup Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v3.R \
#   2>&1 | tee analysis/p4-fase-f5-stage4-layer-a-rebuild-v3.log &

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
DRY_RUN <- nzchar(Sys.getenv("DRY_RUN"))

cli_h1(paste0("Stadio 4 Layer A rebuild v3", if (DRY_RUN) " [DRY_RUN]" else ""))

stage3_dir  <- "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
stopifnot(dir.exists(stage3_dir), file.exists(h5_path), file.exists(stage2_path))

cli_alert_info("Loading stage3 + stage2_master...")
t0 <- Sys.time()
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success(
  "Loaded: {nrow(s3$clusters)} clusters / {nrow(s3$assignments)} assignments / {length(stage2_master)} stage2 studies (wall {round(as.numeric(difftime(Sys.time(), t0, units='secs')), 1)} sec)"
)

# ---- Pre-filter stage2_master vs ARCHS4 H5 sample axis (fix 2026-05-20) ----
cli_alert_info("Pre-filter stage2_master vs ARCHS4 H5 sample axis...")
t_filt <- Sys.time()
h5_samples_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
cli_alert_info("H5 sample axis: {.val {length(h5_samples_axis)}} sample")
.filter_stage2_master_to_h5 <- function(stage2_master, h5_samples) {
  h5_set <- new.env(hash = TRUE, parent = emptyenv())
  for (s in h5_samples) assign(s, TRUE, envir = h5_set)
  n_dropped <- 0L; n_total <- 0L
  for (st_i in seq_along(stage2_master)) {
    rgs <- stage2_master[[st_i]]$replicate_groups
    for (rg_i in seq_along(rgs)) {
      sids <- as.character(unlist(rgs[[rg_i]]$sample_ids))
      n_total <- n_total + length(sids)
      valid <- sids[vapply(sids, exists, logical(1L), envir = h5_set, inherits = FALSE)]
      n_dropped <- n_dropped + (length(sids) - length(valid))
      stage2_master[[st_i]]$replicate_groups[[rg_i]]$sample_ids <- as.list(valid)
    }
  }
  attr(stage2_master, "h5_filter_stats") <- list(
    n_total = n_total, n_dropped = n_dropped,
    pct_dropped = 100 * n_dropped / max(1L, n_total))
  stage2_master
}
stage2_master <- .filter_stage2_master_to_h5(stage2_master, h5_samples_axis)
filt_stats <- attr(stage2_master, "h5_filter_stats")
cli_alert_success(
  "Pre-filter done in {round(as.numeric(difftime(Sys.time(), t_filt, units='secs')), 1)} sec: {.val {filt_stats$n_dropped}}/{.val {filt_stats$n_total}} sample droppati ({.val {sprintf('%.3f%%', filt_stats$pct_dropped)}}) — non in ARCHS4 H5 v2.5"
)
rm(h5_samples_axis); gc(verbose = FALSE)

# ---- Layer A identification + sample collection ---------------------------
config <- stage4_default_config()
config$mega_aug$legacy_monodirectional <- FALSE  # bidirezionale (= 96c43acb)
cli_alert_info(
  "MEGA-AUG mode: BIDIREZIONALE (anchor_policy={config$mega_aug$anchor_policy}, direction={config$mega_aug$direction})"
)
layer_a <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, config)
cli_alert_info(
  "Layer A: {nrow(layer_a)} clusters (rem={sum(layer_a$method=='rem')}, mega={sum(layer_a$method=='mega')}, mega_aug={sum(layer_a$method=='mega_aug')})"
)

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
    s3$clusters$mode == "group" & s3$clusters$level == pair_aug$level[i] &
    s3$clusters$anchor_key == ck]
  baseline_cids <- unique(c(baseline_cids, matches))
}
cli_alert_info("MEGA-AUG baseline cluster matchati: {length(baseline_cids)}")

relevant_cids <- unique(c(layer_a$cluster_id, baseline_cids))
relevant_asg <- s3$assignments[s3$assignments$cluster_id %in% relevant_cids, ]
cli_alert_info("Assignments rilevanti: {nrow(relevant_asg)}")

s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
collect_sids <- function(record_id) {
  parts <- regmatches(record_id, regexpr("__", record_id), invert = TRUE)[[1L]]
  if (length(parts) < 2L) return(character(0L))
  ser <- parts[1L]; suf <- parts[2L]
  if (!exists(ser, envir = s2_idx, inherits = FALSE)) return(character(0L))
  st <- get(ser, envir = s2_idx, inherits = FALSE)
  rg_lookup <- setNames(st$replicate_groups,
                        vapply(st$replicate_groups, `[[`, character(1L), "group_id"))
  cmp <- NULL
  for (c in st$comparisons) if (identical(c$comparison_id, suf)) { cmp <- c; break }
  if (!is.null(cmp)) {
    tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
    return(c(as.character(unlist(tg$sample_ids)), as.character(unlist(cg$sample_ids))))
  }
  rg <- rg_lookup[[suf]]
  if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
  character(0L)
}
all_samples <- unique(unlist(lapply(relevant_asg$record_id, collect_sids)))
cli_alert_info("Sample IDs totali Layer A: {length(all_samples)}")

gse_for_sid <- character(length(all_samples)); names(gse_for_sid) <- all_samples
for (st in stage2_master) for (rg in st$replicate_groups) {
  sids <- as.character(unlist(rg$sample_ids)); hit <- intersect(sids, all_samples)
  if (length(hit) > 0L) gse_for_sid[hit] <- st$series_id
}
missing_gse <- sum(gse_for_sid == "" | is.na(gse_for_sid))
if (missing_gse > 0L) {
  cli_alert_warning("{.val {missing_gse}} sample senza GSE — dropped")
  ok <- !(gse_for_sid == "" | is.na(gse_for_sid))
  all_samples <- all_samples[ok]; gse_for_sid <- gse_for_sid[ok]
}
h5_metadata <- tibble::tibble(
  sample_id = all_samples, gsm = all_samples,
  gse = unname(gse_for_sid), lib_size = 1e7L)  # placeholder lib_size (vedi 96c43acb)
cli_alert_success("h5_metadata: {nrow(h5_metadata)} sample")

if (DRY_RUN) {
  est_h <- round(nrow(layer_a) * 164 / 3600, 1)
  cli_h2("DRY_RUN — stop pre-DE")
  cli_dl(list(
    "Layer A clusters" = nrow(layer_a),
    "  rem"     = sum(layer_a$method == "rem"),
    "  mega"    = sum(layer_a$method == "mega"),
    "  mega_aug"= sum(layer_a$method == "mega_aug"),
    "baseline pool clusters" = length(baseline_cids),
    "sample totali" = nrow(h5_metadata),
    "wall stimato (164s/cluster)" = sprintf("%.1f h", est_h)
  ))
  quit(save = "no")
}

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
cli_alert_success("Build complete in {round(wall_sec/60, 1)} min — run_id {result$run_metadata$run_id}")

out_dir <- file.path("analysis/p4-output",
  sprintf("%s-stage4-%s", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
          result$run_metadata$run_id))
cli_alert_info("Writing to {.path {out_dir}}...")
write_stage4_to_dir(result, out_dir)
# Render dashboard NON-fatale: i deliverable DE sono gia' scritti sopra; un
# errore quarto (template/render) non deve invalidare il run. Ri-renderizzabile
# a parte con render_stage4_dashboard(out_dir).
cli_alert_info("Rendering dashboard...")
tryCatch(render_stage4_dashboard(out_dir),
         error = function(e) cli_alert_warning("Dashboard render FALLITO (non-fatale): {conditionMessage(e)}"))

cli_h2("Layer A summary")
cli_dl(list(
  "Cluster processed"       = length(unique(result$cluster_pooled$cluster_id)),
  "Cluster non-processable" = nrow(result$non_processable),
  "Per-study DE rows"       = nrow(result$per_study_de),
  "Cluster pooled rows"     = nrow(result$cluster_pooled),
  "Significant (FDR<0.05)"  = sum(result$cluster_pooled$FDR_BH_within_cluster < 0.05, na.rm = TRUE),
  "Methods"                 = paste(sort(unique(result$cluster_pooled$method)), collapse = ", "),
  "Run id"                  = result$run_metadata$run_id,
  "Wall total"              = sprintf("%.1f min", wall_sec / 60),
  "Output dir"              = out_dir
))
cli_alert_success("Layer A rebuild v3 OK")
