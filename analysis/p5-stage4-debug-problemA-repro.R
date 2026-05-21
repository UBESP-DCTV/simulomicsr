# analysis/p5-stage4-debug-problemA-repro.R
# DEBUGGING Problema A — "duplicate 'row.names' are not allowed" su 3 cluster
# mega_aug bidir (pair_L0_e45151a4, pair_L1_37c75531, pair_L2_a28b250f).
#
# Riproduzione MINIMALE e deterministica: NO fullrun, NO dream, NO H5 reads.
# Carica i dati reali (s3 + stage2_master), ricostruisce il QC + dispatch
# esattamente come build_stage4_results, poi per i 3 cluster noti chiama
# .assemble_mega_aug_metadata_bidir (lo stesso path dell'orchestrator) e
# ispeziona se metadata$sample_id contiene duplicati e da dove vengono.
#
# Usage: Rscript analysis/p5-stage4-debug-problemA-repro.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
})

cli_h1("Problema A — repro 3 cluster mega_aug bidir")

stage3_dir  <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"
stopifnot(dir.exists(stage3_dir), file.exists(h5_path), file.exists(stage2_path))

targets <- c("pair_L0_e45151a4", "pair_L1_37c75531", "pair_L2_a28b250f")

# ---- 1. Load (identico al fullrun) ----------------------------------------
cli_alert_info("Loading stage3 + stage2_master...")
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success("Loaded: {nrow(s3$clusters)} clusters / {nrow(s3$assignments)} assignments / {length(stage2_master)} stage2 studies")

# ---- 2. Pre-filter stage2_master vs H5 (hotfix #1, identico al fullrun) ----
cli_alert_info("Pre-filter stage2_master vs H5 sample axis...")
h5_samples_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
.filter_stage2_master_to_h5 <- function(stage2_master, h5_samples) {
  h5_set <- new.env(hash = TRUE, parent = emptyenv())
  for (s in h5_samples) assign(s, TRUE, envir = h5_set)
  for (st_i in seq_along(stage2_master)) {
    rgs <- stage2_master[[st_i]]$replicate_groups
    for (rg_i in seq_along(rgs)) {
      sids <- as.character(unlist(rgs[[rg_i]]$sample_ids))
      valid <- sids[vapply(sids, exists, logical(1L), envir = h5_set,
                            inherits = FALSE)]
      stage2_master[[st_i]]$replicate_groups[[rg_i]]$sample_ids <- as.list(valid)
    }
  }
  stage2_master
}
stage2_master <- .filter_stage2_master_to_h5(stage2_master, h5_samples_axis)
rm(h5_samples_axis); gc(verbose = FALSE)

# ---- 3. Config bidir + Layer A + h5_metadata (identico al fullrun) --------
config <- stage4_default_config()
config$mega_aug$legacy_monodirectional <- FALSE
layer_a <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, config)
cli_alert_info("Layer A: {nrow(layer_a)} clusters")

# Sanity: i 3 target sono in Layer A?
miss <- setdiff(targets, layer_a$cluster_id)
if (length(miss) > 0L) cli_alert_danger("Target NON in layer_a: {miss}")
tg_rows <- layer_a[layer_a$cluster_id %in% targets, ]
cli_alert_info("Target trovati in layer_a: {nrow(tg_rows)} (method: {paste(unique(tg_rows$method), collapse=',')})")

# Costruisci h5_metadata come il fullrun (serve al QC)
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
    s3$clusters$anchor_key == ck]
  baseline_cids <- unique(c(baseline_cids, matches))
}
relevant_cids <- unique(c(layer_a$cluster_id, baseline_cids))
relevant_asg <- s3$assignments[s3$assignments$cluster_id %in% relevant_cids, ]
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
gse_for_sid <- character(length(all_samples)); names(gse_for_sid) <- all_samples
for (st in stage2_master) {
  for (rg in st$replicate_groups) {
    sids <- as.character(unlist(rg$sample_ids))
    hit <- intersect(sids, all_samples)
    if (length(hit) > 0L) gse_for_sid[hit] <- st$series_id
  }
}
ok <- !(gse_for_sid == "" | is.na(gse_for_sid))
all_samples <- all_samples[ok]; gse_for_sid <- gse_for_sid[ok]
h5_metadata <- tibble::tibble(sample_id = all_samples, gsm = all_samples,
                               gse = unname(gse_for_sid), lib_size = 1e7L)
cli_alert_success("h5_metadata: {nrow(h5_metadata)} sample")

# ---- 4. QC + dispatch (internals identici a build_stage4_results) ---------
cli_alert_info("QC + dispatch builders...")
qc <- simulomicsr:::.qc_filter_samples_and_studies(s3$clusters, h5_metadata, config)
study_dispatch <- simulomicsr:::.build_study_dispatch_from_stage3(
  qc$eligible_clusters, s3$assignments, stage2_master)
stage3_enriched <- simulomicsr:::.enrich_group_baseline_sample_ids(
  s3$clusters, s3$assignments, stage2_master)
elig <- qc$eligible_clusters
cli_alert_success("eligible_clusters: {nrow(elig)} | study_dispatch keys: {length(study_dispatch)}")

# ---- 5. Matcher bidir (identico all'orchestrator) -------------------------
bidir_matcher <- make_anchor_matcher(
  policy           = config$mega_aug$anchor_policy,
  relaxed_segments = config$mega_aug$relaxed_segments)

# ---- 6. Per ogni target: ricostruisci pair_cluster_struct + assemble ------
inspect_one <- function(cid) {
  cli_h2("Cluster {cid}")
  i <- which(elig$cluster_id == cid)
  if (length(i) != 1L) { cli_alert_danger("non in eligible_clusters (i={length(i)})"); return(invisible()) }

  parsed_key <- simulomicsr:::.parse_pair_anchor_key(elig$anchor_key[i], level = elig$level[i])
  dispatch_entries <- study_dispatch[[cid]]
  if (is.null(dispatch_entries)) { cli_alert_danger("study_dispatch[[cid]] NULL"); return(invisible()) }

  treated_samples_flat <- unlist(lapply(dispatch_entries, function(d) d$treated))
  control_samples_flat <- unlist(lapply(dispatch_entries, function(d) d$control))
  treated_studies_flat <- unlist(lapply(dispatch_entries, function(d) rep(d$study_id, length(d$treated))))
  control_studies_flat <- unlist(lapply(dispatch_entries, function(d) rep(d$study_id, length(d$control))))

  pair_cluster_struct <- list(
    cluster_id = cid, level = elig$level[i], anchor_key = elig$anchor_key[i],
    treated_anchor_key = parsed_key$treated, control_anchor_key = parsed_key$control,
    studies_in_cluster = elig$studies_in_cluster[[i]],
    treated_samples = list(treated_samples_flat),
    control_samples = list(control_samples_flat),
    treated_sample_studies = list(treated_studies_flat),
    control_sample_studies = list(control_studies_flat))

  group_baseline <- stage3_enriched[
    stage3_enriched$mode == "group" & stage3_enriched$level == elig$level[i], ]

  assembled <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
    pair_cluster_struct, group_baseline, matcher = bidir_matcher,
    direction = config$mega_aug$direction,
    min_baseline_studies = config$mega_aug$min_baseline_studies)

  md <- assembled$metadata
  dup_ids <- unique(md$sample_id[duplicated(md$sample_id)])
  cli_alert_info("metadata rows: {nrow(md)} | unique sample_id: {length(unique(md$sample_id))} | DUPLICATI: {length(dup_ids)}")
  cli_alert_info("baseline_pool_ids: control={assembled$baseline_pool_ids$control %||% 'NULL'} treated={assembled$baseline_pool_ids$treated %||% 'NULL'}")
  cli_alert_info("comparison_kind: ctrl={assembled$comparison_kind_control} trt={assembled$comparison_kind_treated}")

  if (length(dup_ids) > 0L) {
    cli_alert_danger("DUPLICATE sample_id confermati ({length(dup_ids)}). Dettaglio primi 5:")
    for (s in head(dup_ids, 5L)) {
      rows <- md[md$sample_id == s, ]
      cat(sprintf("  %s -> treatment=[%s] study=[%s]\n", s,
                  paste(as.character(rows$treatment), collapse = ","),
                  paste(as.character(rows$study), collapse = ",")))
    }
    # Trace: i duplicati provengono da overlap control-baseline vs treated-baseline?
    md$treatment <- as.character(md$treatment)
    by_t <- split(md$sample_id, md$treatment)
    overlap_ct <- intersect(unique(by_t[["control"]]), unique(by_t[["treated"]]))
    cli_alert_info("sample_id presenti SIA come control SIA come treated: {length(overlap_ct)}")
  } else {
    cli_alert_success("nessun duplicato sample_id per questo cluster")
  }
  invisible(assembled)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
for (cid in targets) inspect_one(cid)

cli_h1("Repro completata")
