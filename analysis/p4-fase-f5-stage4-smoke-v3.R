# analysis/p4-fase-f5-stage4-smoke-v3.R --- RED ALERT FASE F5.
# Smoke pre-fullrun Stadio 4 sul NUOVO Stadio 3 v3 + master v3. Gate del Layer A.
#
# Picks (smallest-n_total per categoria, deterministico):
#   1. REM strict (pair, usable_rem_strict, k in [3,9])   <- NUOVO in v3 (era 0)
#   2-3. MEGA strict (group, k=5 / n_studies>=10)
#   4-6. MEGA-AUG pair k=2 (usable_rem_relaxed)
# Valida: ogni pick processato (cluster_pooled rows>0) o skip con reason valida;
# methods esercitati = rem + mega + mega_aug; output + dashboard scritti.
#
# Config = full run (uniformity): MEGA-AUG bidirezionale + FASE E default
# (ensembl axis, biotype protein_coding, covariate batch).
#
# Usage: Rscript analysis/p4-fase-f5-stage4-smoke-v3.R 2>&1 | tee \
#   analysis/p4-fase-f5-stage4-smoke-v3.log

Sys.setenv(OPENBLAS_NUM_THREADS = "4", OMP_NUM_THREADS = "4")
suppressPackageStartupMessages({ devtools::load_all("."); library(dplyr); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(4L); RhpcBLASctl::omp_set_num_threads(4L)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

stage3_dir  <- "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
stopifnot(dir.exists(stage3_dir), file.exists(h5_path), file.exists(stage2_path))

cli_alert_info("Loading stage3 + stage2_master...")
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success("stage3: {.val {nrow(s3$clusters)}} clusters; stage2_master: {.val {length(stage2_master)}} studies")

# Pre-filter stage2_master vs ARCHS4 H5 sample axis
cli_alert_info("Pre-filter stage2_master vs ARCHS4 H5 sample axis...")
h5_samples_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_set <- new.env(hash = TRUE, parent = emptyenv())
for (s in h5_samples_axis) assign(s, TRUE, envir = h5_set)
n_dropped <- 0L; n_total <- 0L
for (st_i in seq_along(stage2_master)) {
  rgs <- stage2_master[[st_i]]$replicate_groups
  for (rg_i in seq_along(rgs)) {
    sids <- as.character(unlist(rgs[[rg_i]]$sample_ids)); n_total <- n_total + length(sids)
    valid <- sids[vapply(sids, exists, logical(1L), envir = h5_set, inherits = FALSE)]
    n_dropped <- n_dropped + (length(sids) - length(valid))
    stage2_master[[st_i]]$replicate_groups[[rg_i]]$sample_ids <- as.list(valid)
  }
}
cli_alert_info("Pre-filter: {n_dropped}/{n_total} sample droppati non in ARCHS4 H5")
rm(h5_samples_axis, h5_set); invisible(gc(verbose = FALSE))

cl <- s3$clusters
# Pick rem: REM strict pair k in [3,9], smallest n_total
pick_rem <- cl |> dplyr::filter(mode == "pair", usable_rem_strict, k >= 3L, k <= 9L) |>
  dplyr::arrange(n_total) |> dplyr::slice(1L) |> dplyr::pull(cluster_id)
# Pick mega: strict k=5 e n_studies>=10
pick1 <- cl |> dplyr::filter(mode == "group", usable_mega_strict, n_studies == 5L, n_total >= 10L) |>
  dplyr::arrange(n_total) |> dplyr::slice(1L) |> dplyr::pull(cluster_id)
pick2 <- cl |> dplyr::filter(mode == "group", usable_mega_strict, n_studies >= 10L) |>
  dplyr::arrange(n_total) |> dplyr::slice(1L) |> dplyr::pull(cluster_id)
# Pick mega_aug: pair k=2 usable_rem_relaxed, 3 smallest
pick345 <- cl |> dplyr::filter(mode == "pair", k == 2L, usable_rem_relaxed) |>
  dplyr::arrange(n_total, cluster_id) |> dplyr::slice(1:3) |> dplyr::pull(cluster_id)

pick_ids <- c(pick_rem, pick345, pick1, pick2)
pick_ids <- pick_ids[!is.na(pick_ids)]
cli_alert_info("Picks ({length(pick_ids)}): {paste(pick_ids, collapse=', ')}")
stopifnot(length(pick_ids) >= 4L)

# sample IDs dai picks + baseline pool (per MEGA-AUG)
s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
collect_sids <- function(record_id) {
  parts <- regmatches(record_id, regexpr("__", record_id), invert = TRUE)[[1L]]
  if (length(parts) < 2L) return(character(0L))
  ser <- parts[1L]; suf <- parts[2L]
  if (!exists(ser, envir = s2_idx, inherits = FALSE)) return(character(0L))
  st <- get(ser, envir = s2_idx, inherits = FALSE)
  rg_lookup <- setNames(st$replicate_groups, vapply(st$replicate_groups, `[[`, character(1L), "group_id"))
  cmp <- NULL
  for (c in st$comparisons) if (identical(c$comparison_id, suf)) { cmp <- c; break }
  if (!is.null(cmp)) {
    tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
    return(c(as.character(unlist(tg$sample_ids)), as.character(unlist(cg$sample_ids))))
  }
  rg <- rg_lookup[[suf]]; if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
  character(0L)
}
parse_ck <- function(anchor_key, level) {
  s <- anchor_key
  if (level %in% c(0L, 1L)) s <- sub("__CT_[^_].*$", "", s)
  p <- strsplit(s, "__VS__", fixed = TRUE)[[1L]]
  if (length(p) != 2L) NA_character_ else p[2L]
}
pair_picks <- cl[cl$cluster_id %in% pick_ids & cl$mode == "pair", ]
baseline_cids <- character(0L)
for (i in seq_len(nrow(pair_picks))) {
  ck <- parse_ck(pair_picks$anchor_key[i], pair_picks$level[i]); if (is.na(ck)) next
  mr <- cl[cl$mode == "group" & cl$level == pair_picks$level[i] & cl$anchor_key == ck, ]
  baseline_cids <- unique(c(baseline_cids, mr$cluster_id))
}
cli_alert_info("Baseline group cluster matchati: {length(baseline_cids)}")

clusters_subset <- s3$clusters[s3$clusters$cluster_id %in% c(pick_ids, baseline_cids), ]
assignments_subset <- s3$assignments[s3$assignments$cluster_id %in% c(pick_ids, baseline_cids), ]
all_samples <- unique(unlist(lapply(assignments_subset$record_id, collect_sids)))
cli_alert_info("Subset: {nrow(clusters_subset)} clusters / {nrow(assignments_subset)} assignments / {length(all_samples)} sample")

gse_for_sid <- character(length(all_samples)); names(gse_for_sid) <- all_samples
for (st in stage2_master) for (rg in st$replicate_groups) {
  hit <- intersect(as.character(unlist(rg$sample_ids)), all_samples)
  if (length(hit) > 0L) gse_for_sid[hit] <- st$series_id
}
keep <- !(gse_for_sid == "" | is.na(gse_for_sid))
all_samples <- all_samples[keep]; gse_for_sid <- gse_for_sid[keep]
h5_metadata <- tibble::tibble(sample_id = all_samples, gsm = all_samples,
                              gse = unname(gse_for_sid), lib_size = 1e7L)
cli_alert_info("h5_metadata: {nrow(h5_metadata)} sample")

config <- stage4_default_config()
config$mega_aug$legacy_monodirectional <- FALSE
cli_alert_info("Building Stage 4 results (smoke)...")
t0 <- Sys.time()
result <- build_stage4_results(
  stage3_clusters = clusters_subset, h5_metadata = h5_metadata, config = config,
  h5_path = h5_path, stage3_run_id = s3$run_metadata$run_id, h5_path_for_hash = h5_path,
  stage3_assignments = assignments_subset, stage2_master = stage2_master)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cli_alert_success("build_stage4_results done in {round(wall, 1)} sec")

cli_h2("Smoke gate")
stopifnot(nchar(result$run_metadata$run_id) == 8L)
cli_li("cluster_pooled rows: {nrow(result$cluster_pooled)}")
stopifnot(nrow(result$cluster_pooled) > 0L)
methods_observed <- sort(unique(result$cluster_pooled$method))
cli_li("methods observed: {paste(methods_observed, collapse=', ')}")
qc_drops <- result$qc_report$qc_drops_cluster %||% tibble::tibble()
n_proc <- 0L; n_skip <- 0L
for (cid in pick_ids) {
  nr <- sum(result$cluster_pooled$cluster_id == cid)
  if (nr > 0L) { cli_li("{cid}: {nr} gene rows (processed)"); n_proc <- n_proc + 1L }
  else {
    dr <- qc_drops[qc_drops$cluster_id == cid, ]
    if (nrow(dr) >= 1L) { cli_li("{cid}: SKIPPED '{dr$reason[1L]}'"); n_skip <- n_skip + 1L }
    else stop(sprintf("Pick %s NON in cluster_pooled NE qc_drops", cid))
  }
}
cli_alert_info("processed={n_proc} / skipped={n_skip} / total={length(pick_ids)}")
stopifnot(n_proc >= 1L)

# verifica gene axis Ensembl + biotype filter (FASE E) sull'output
if ("gene_id" %in% names(result$cluster_pooled)) {
  ng <- length(unique(result$cluster_pooled$gene_id))
  ens <- mean(grepl("^ENSG", unique(result$cluster_pooled$gene_id)))
  cli_li("gene_id Ensembl: {ng} geni distinti, {sprintf('%.1f%%', 100*ens)} ENSG-prefixed")
}

smoke_dir <- file.path("analysis/p4-output",
  sprintf("%s-stage4-smoke-v3-%s", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
          result$run_metadata$run_id))
cli_alert_info("Writing to {smoke_dir}")
write_stage4_to_dir(result, smoke_dir)
render_stage4_dashboard(smoke_dir)
cli_alert_success("Smoke v3 OK — output in {.path {smoke_dir}} (wall {round(wall,1)}s)")
