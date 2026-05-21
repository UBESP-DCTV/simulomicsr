# analysis/p5-stage4-debug-scan-all-mega-aug.R
# DEBUGGING Problema A — quantificazione impatto.
# Scansiona TUTTI i 310 cluster mega_aug Layer A: per ciascuno chiama
# .assemble_mega_aug_metadata_bidir (stesso path orchestrator) e classifica:
#   - dup_free            : metadata senza sample_id duplicati (OK)
#   - same_pool_both_arms : top_control == top_treated (root cause confermato)
#   - other_dup           : duplicati di altra origine (da investigare)
#
# Salva anche un checkpoint RDS (elig + dispatch + enriched + config) per
# riusare il prep costoso (~11 min QC) negli script successivi.
#
# Usage: Rscript analysis/p5-stage4-debug-scan-all-mega-aug.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
})
`%||%` <- function(x, y) if (is.null(x)) y else x

cli_h1("Problema A — scan completo 310 mega_aug")

stage3_dir  <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"
ckpt_path   <- "analysis/p5-stage4-debug-checkpoint.rds"

# ---- 1. Load + prep (con checkpoint) --------------------------------------
if (file.exists(ckpt_path)) {
  cli_alert_info("Checkpoint trovato, carico {ckpt_path}")
  ck <- readRDS(ckpt_path)
  elig <- ck$elig; study_dispatch <- ck$study_dispatch
  stage3_enriched <- ck$stage3_enriched; config <- ck$config
} else {
  cli_alert_info("Loading stage3 + stage2_master...")
  s3 <- load_stage3(stage3_dir)
  stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
  cli_alert_success("Loaded: {nrow(s3$clusters)} clusters / {length(stage2_master)} stage2")

  cli_alert_info("Pre-filter stage2_master vs H5...")
  h5_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
  h5_set <- new.env(hash = TRUE, parent = emptyenv())
  for (s in h5_axis) assign(s, TRUE, envir = h5_set)
  for (st_i in seq_along(stage2_master)) {
    rgs <- stage2_master[[st_i]]$replicate_groups
    for (rg_i in seq_along(rgs)) {
      sids <- as.character(unlist(rgs[[rg_i]]$sample_ids))
      valid <- sids[vapply(sids, exists, logical(1L), envir = h5_set, inherits = FALSE)]
      stage2_master[[st_i]]$replicate_groups[[rg_i]]$sample_ids <- as.list(valid)
    }
  }
  rm(h5_axis, h5_set); gc(verbose = FALSE)

  config <- stage4_default_config()
  config$mega_aug$legacy_monodirectional <- FALSE

  # h5_metadata: replica fullrun
  layer_a <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, config)
  pair_aug <- layer_a[layer_a$method == "mega_aug", ]
  parse_ck <- function(ak, lv) {
    s <- ak
    if (lv %in% c(0L, 1L)) s <- sub("__CT_[^_].*$", "", s)
    p <- strsplit(s, "__VS__", fixed = TRUE)[[1L]]
    if (length(p) != 2L) NA_character_ else p[2L]
  }
  baseline_cids <- character(0L)
  for (i in seq_len(nrow(pair_aug))) {
    ck2 <- parse_ck(pair_aug$anchor_key[i], pair_aug$level[i])
    if (is.na(ck2)) next
    m <- s3$clusters$cluster_id[s3$clusters$mode == "group" &
      s3$clusters$level == pair_aug$level[i] & s3$clusters$anchor_key == ck2]
    baseline_cids <- unique(c(baseline_cids, m))
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
  for (st in stage2_master) for (rg in st$replicate_groups) {
    sids <- as.character(unlist(rg$sample_ids))
    hit <- intersect(sids, all_samples)
    if (length(hit) > 0L) gse_for_sid[hit] <- st$series_id
  }
  ok <- !(gse_for_sid == "" | is.na(gse_for_sid))
  all_samples <- all_samples[ok]; gse_for_sid <- gse_for_sid[ok]
  h5_metadata <- tibble::tibble(sample_id = all_samples, gsm = all_samples,
                                 gse = unname(gse_for_sid), lib_size = 1e7L)

  cli_alert_info("QC + dispatch builders...")
  qc <- simulomicsr:::.qc_filter_samples_and_studies(s3$clusters, h5_metadata, config)
  study_dispatch <- simulomicsr:::.build_study_dispatch_from_stage3(
    qc$eligible_clusters, s3$assignments, stage2_master)
  stage3_enriched <- simulomicsr:::.enrich_group_baseline_sample_ids(
    s3$clusters, s3$assignments, stage2_master)
  elig <- qc$eligible_clusters

  saveRDS(list(elig = elig, study_dispatch = study_dispatch,
               stage3_enriched = stage3_enriched, config = config),
          ckpt_path)
  cli_alert_success("Checkpoint salvato: {ckpt_path}")
}

# ---- 2. Scan tutti i mega_aug ---------------------------------------------
matcher <- make_anchor_matcher(policy = config$mega_aug$anchor_policy,
                                relaxed_segments = config$mega_aug$relaxed_segments)
mega_aug_ids <- elig$cluster_id[elig$method == "mega_aug"]
cli_alert_info("mega_aug clusters da scansionare: {length(mega_aug_ids)}")

rows <- vector("list", length(mega_aug_ids))
for (k in seq_along(mega_aug_ids)) {
  cid <- mega_aug_ids[k]
  i <- which(elig$cluster_id == cid)
  res <- tryCatch({
    parsed_key <- simulomicsr:::.parse_pair_anchor_key(elig$anchor_key[i], level = elig$level[i])
    de <- study_dispatch[[cid]]
    if (is.null(de)) stop("no_dispatch")
    pcs <- list(
      cluster_id = cid, level = elig$level[i], anchor_key = elig$anchor_key[i],
      treated_anchor_key = parsed_key$treated, control_anchor_key = parsed_key$control,
      studies_in_cluster = elig$studies_in_cluster[[i]],
      treated_samples = list(unlist(lapply(de, function(d) d$treated))),
      control_samples = list(unlist(lapply(de, function(d) d$control))),
      treated_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$treated))))),
      control_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$control))))))
    gb <- stage3_enriched[stage3_enriched$mode == "group" &
                            stage3_enriched$level == elig$level[i], ]
    asm <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
      pcs, gb, matcher = matcher, direction = config$mega_aug$direction,
      min_baseline_studies = config$mega_aug$min_baseline_studies)
    md <- asm$metadata
    n_dup <- sum(duplicated(md$sample_id))
    bp_c <- asm$baseline_pool_ids$control %||% NA_character_
    bp_t <- asm$baseline_pool_ids$treated %||% NA_character_
    md$treatment <- as.character(md$treatment)
    by_t <- split(md$sample_id, md$treatment)
    overlap_ct <- length(intersect(unique(by_t[["control"]] %||% character()),
                                    unique(by_t[["treated"]] %||% character())))
    list(cid = cid, level = elig$level[i], n_meta = nrow(md),
         n_unique = length(unique(md$sample_id)), n_dup = n_dup,
         bp_control = bp_c, bp_treated = bp_t,
         same_pool = !is.na(bp_c) && !is.na(bp_t) && identical(bp_c, bp_t),
         collapsed = isTRUE(asm$bidir_collapsed_to_mono),
         overlap_ct = overlap_ct, err = NA_character_)
  }, error = function(e) list(cid = cid, level = elig$level[i], n_meta = NA,
       n_unique = NA, n_dup = NA, bp_control = NA, bp_treated = NA,
       same_pool = NA, collapsed = NA, overlap_ct = NA,
       err = conditionMessage(e)))
  rows[[k]] <- res
}
df <- do.call(rbind, lapply(rows, function(r) as.data.frame(r, stringsAsFactors = FALSE)))

# ---- 3. Report ------------------------------------------------------------
cli_h2("Risultati scan")
n_err  <- sum(!is.na(df$err))
n_dupc <- sum(df$n_dup > 0L, na.rm = TRUE)
n_same <- sum(df$same_pool, na.rm = TRUE)
n_clean <- sum(df$n_dup == 0L, na.rm = TRUE)
n_collapsed <- sum(df$collapsed, na.rm = TRUE)
cli_alert_info("Totale mega_aug: {nrow(df)}")
cli_alert_info("  dup-free (OK)            : {n_clean}")
cli_alert_danger("  con sample_id duplicati  : {n_dupc}")
cli_alert_info("  same_pool both arms      : {n_same}")
cli_alert_info("  bidir_collapsed_to_mono  : {n_collapsed}")
cli_alert_info("  errori assemble          : {n_err}")
# dup spiegati interamente da same_pool?
dup_rows <- df[which(df$n_dup > 0L), ]
if (nrow(dup_rows) > 0L) {
  not_same <- dup_rows[!isTRUE(dup_rows$same_pool) & !dup_rows$same_pool, ]
  cli_alert_info("  dup-cluster con same_pool=TRUE: {sum(dup_rows$same_pool, na.rm=TRUE)}/{nrow(dup_rows)}")
  if (nrow(not_same) > 0L) {
    cli_alert_danger("  ATTENZIONE: {nrow(not_same)} dup-cluster con same_pool=FALSE (altra origine):")
    print(not_same[, c("cid", "level", "n_dup", "bp_control", "bp_treated", "overlap_ct")])
  }
  cli_alert_info("Distribuzione per level dei dup-cluster:")
  print(table(dup_rows$level))
}
if (n_err > 0L) {
  cli_alert_danger("Cluster con errori assemble:")
  print(df[!is.na(df$err), c("cid", "level", "err")])
}
saveRDS(df, "analysis/p5-stage4-debug-scan-all-mega-aug-result.rds")
cli_alert_success("Risultato salvato in analysis/p5-stage4-debug-scan-all-mega-aug-result.rds")
cli_h1("Scan completato")
