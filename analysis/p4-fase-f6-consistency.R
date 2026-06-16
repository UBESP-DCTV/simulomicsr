# analysis/p4-fase-f6-consistency.R --- RED ALERT FASE F6 (Fase A).
# Metrica di consistenza cross-studio per-cluster (ADR-0021). Asse [0,1]:
#   mega     = 1 - VPC(study)      (variancePartition::fitExtractVarPartModel)
#   rem      = 1 - median(I2)      (+ prediction interval 95% REML+HKSJ, metafor)
#   mega_aug = sign-concordance    (2 studi, k=2)
# Sempre sui geni FDR-significativi. Vedi
# docs/superpowers/specs/2026-06-15-f6-reproducibility-consistency-metric-design.md
#
# Il mega ricalcola la VPC ricostruendo l'input per-cluster con gli helper Stadio 4
# e lo STESSO preprocessing del fullrun (DGEList->filterByExpr->TMM->.augment_de_design->
# voomWithDreamWeights). NB: nel fullrun le covariate batch erano inerti (h5_metadata
# senza instrument_model/aligner_class) -> formula ~ treatment + (1|study); qui replico
# identico. rem/mega_aug non toccano l'H5 (usano per_study_de + cluster_pooled).
#
# SMOKE=N -> processa solo N cluster per metodo (gate pre-run-pieno).
# Output (dir del run Stadio 4): cluster_reproducibility_v2.rds + cluster_vpc_per_gene.parquet
# (mega) + cluster_pi_per_gene.parquet (rem).

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE)
  library(arrow); library(dplyr); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
SMOKE <- as.integer(Sys.getenv("SMOKE", unset = "0"))   # 0 = run pieno
VPC_WORKERS <- as.integer(Sys.getenv("VPC_WORKERS", unset = "24"))  # MulticoreParam VPC
bpp <- if (VPC_WORKERS > 1L) BiocParallel::MulticoreParam(VPC_WORKERS) else BiocParallel::SerialParam()
S4_DIR  <- "analysis/p4-output/20260613T051637Z-stage4-4f7ea215"
S3_DIR  <- "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
S2_PATH <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
H5_PATH <- "analysis/input/human_gene_v2.5.h5"
stopifnot(dir.exists(S4_DIR), dir.exists(S3_DIR), file.exists(S2_PATH), file.exists(H5_PATH))
cli_h1(sprintf("F6 consistenza%s", if (SMOKE > 0) sprintf(" [SMOKE=%d/metodo]", SMOKE) else ""))

# --- cluster_pooled: FDR + I2 per-gene + method per cluster ---
cli_alert_info("Carico cluster_pooled...")
cp <- arrow::read_parquet(file.path(S4_DIR, "cluster_pooled.parquet"),
  col_select = c("cluster_id","gene_id","method","I2","FDR_BH_within_cluster"))
methods_by_cid <- cp %>% distinct(cluster_id, method)
pick <- function(m) {
  ids <- methods_by_cid$cluster_id[methods_by_cid$method == m]
  if (SMOKE > 0) head(sort(ids), SMOKE) else ids
}
mega_ids <- pick("mega"); rem_ids <- pick("rem"); maug_ids <- pick("mega_aug")
cli_alert_info("cluster: mega={length(mega_ids)} rem={length(rem_ids)} mega_aug={length(maug_ids)}")

rows <- list()          # per-cluster summary
vpc_pg <- list()        # per-gene VPC (mega)
pi_pg  <- list()        # per-gene PI (rem)

# ============================ MEGA — VPC(study) ============================
if (length(mega_ids) > 0) {
  cli_h2("mega — VPC(study) via variancePartition")
  # bootstrap H5 (identico a p4-fase-f5-stage4-layer-a-rebuild-v3.R)
  s3 <- load_stage3(S3_DIR)
  stage2_master <- simulomicsr:::.load_stage2_master(S2_PATH)
  h5_axis <- as.character(rhdf5::h5read(H5_PATH, "meta/samples/geo_accession"))
  h5set <- new.env(hash = TRUE, parent = emptyenv()); for (s in h5_axis) assign(s, TRUE, envir = h5set)
  for (i in seq_along(stage2_master)) { rgs <- stage2_master[[i]]$replicate_groups
    for (j in seq_along(rgs)) { sids <- as.character(unlist(rgs[[j]]$sample_ids))
      stage2_master[[i]]$replicate_groups[[j]]$sample_ids <-
        as.list(sids[vapply(sids, exists, logical(1L), envir = h5set, inherits = FALSE)]) } }
  rm(h5_axis, h5set); invisible(gc(verbose = FALSE))
  config <- stage4_default_config(); config$mega_aug$legacy_monodirectional <- FALSE
  stage2_master <- simulomicsr:::.assert_stage2_one_record_per_series(stage2_master)
  # h5_metadata su TUTTI i sample dei cluster mega (per dispatch + QC)
  asg_mega <- s3$assignments[s3$assignments$cluster_id %in% mega_ids, ]
  s2_idx <- new.env(hash = TRUE, parent = emptyenv())
  for (st in stage2_master) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
  collect_sids <- function(record_id) {
    parts <- regmatches(record_id, regexpr("__", record_id), invert = TRUE)[[1L]]
    if (length(parts) < 2L) return(character(0L))
    ser <- parts[1L]; suf <- parts[2L]
    if (!exists(ser, envir = s2_idx, inherits = FALSE)) return(character(0L))
    st <- get(ser, envir = s2_idx)
    rgl <- setNames(st$replicate_groups, vapply(st$replicate_groups, `[[`, character(1L), "group_id"))
    cmp <- NULL; for (c in st$comparisons) if (identical(c$comparison_id, suf)) { cmp <- c; break }
    if (!is.null(cmp)) return(c(as.character(unlist(rgl[[cmp$treated_group]]$sample_ids)),
                                as.character(unlist(rgl[[cmp$control_group]]$sample_ids))))
    rg <- rgl[[suf]]; if (!is.null(rg)) return(as.character(unlist(rg$sample_ids))); character(0L)
  }
  all_s <- unique(unlist(lapply(asg_mega$record_id, collect_sids)))
  gse <- character(length(all_s)); names(gse) <- all_s
  for (st in stage2_master) for (rg in st$replicate_groups) {
    hit <- intersect(as.character(unlist(rg$sample_ids)), all_s)
    if (length(hit) > 0L) gse[hit] <- st$series_id }
  keep <- !(gse == "" | is.na(gse)); all_s <- all_s[keep]; gse <- gse[keep]
  h5_metadata <- tibble::tibble(sample_id = all_s, gsm = all_s, gse = unname(gse), lib_size = 1e7L)
  qc <- simulomicsr:::.qc_filter_samples_and_studies(s3$clusters, h5_metadata, config)
  group_dispatch <- simulomicsr:::.build_group_dispatch_from_stage3(
    qc$eligible_clusters, s3$assignments, stage2_master)
  samn <- simulomicsr:::.build_samn_dedupe_lookups(h5_metadata)  # NULL lookups (no biosample_id) = come fullrun
  fetch_fn <- function(g, s) simulomicsr:::.fetch_counts_cached(g, s, h5_path = H5_PATH,
                                                                gene_biotype_filter = "protein_coding")
  de_cov <- c("instrument_model", "aligner_class")  # inerti (assenti da h5_metadata) come fullrun

  for (ii in seq_along(mega_ids)) {
    cid <- mega_ids[ii]
    t0 <- Sys.time()
    res <- tryCatch({
      grp <- group_dispatch[[cid]]; if (is.null(grp)) stop("no_group_dispatch")
      safe <- simulomicsr:::.build_mega_metadata_safe(grp, cid,
        biosample_lookup = samn$biosample_lookup, libsize_lookup = samn$libsize_lookup)
      metadata <- safe$metadata
      rc <- simulomicsr:::.check_mega_rank(metadata); if (rc$rank_deficient) stop(paste0("rank_deficient:", rc$reason))
      all_studies <- unique(as.character(metadata$study))
      cl <- lapply(all_studies, function(s) fetch_fn(s, metadata$sample_id[metadata$study == s]))
      common <- Reduce(intersect, lapply(cl, rownames))
      counts <- do.call(cbind, lapply(cl, function(m) m[common, , drop = FALSE]))
      gs <- attr(cl[[1]], "gene_symbol"); if (!is.null(gs)) attr(counts, "gene_symbol") <- gs[common]
      metadata <- metadata[match(colnames(counts), metadata$sample_id), , drop = FALSE]
      joined <- simulomicsr:::.join_covariates_to_metadata(metadata, h5_metadata, de_cov, cid)
      metadata <- joined$metadata
      gene_symbol_lookup <- attr(counts, "gene_symbol") %||% setNames(rep(NA_character_, nrow(counts)), rownames(counts))
      metadata <- as.data.frame(metadata, stringsAsFactors = FALSE); rownames(metadata) <- metadata$sample_id
      dge <- edgeR::DGEList(counts = counts)
      keepg <- edgeR::filterByExpr(dge, group = metadata$treatment)
      dge <- edgeR::normLibSizes(dge[keepg, , keep.lib.sizes = FALSE], method = "TMM")
      aug <- simulomicsr:::.augment_de_design(metadata, de_cov, cid); metadata <- aug$metadata_aug
      # VPC: variancePartition richiede le categoriche come effetti RANDOM (standard
      # Hoffman & Schadt 2016) -> treatment + eventuali covariate come (1|...). Stesso
      # preprocessing del DE; differisce solo la formula (treatment random vs fisso).
      cov_terms <- if (aug$formula_terms == "") character(0) else
        trimws(strsplit(aug$formula_terms, "\\+")[[1L]])
      rand <- c("(1 | treatment)", "(1 | study)",
                if (length(cov_terms)) paste0("(1 | ", cov_terms, ")"))
      form <- stats::as.formula(paste("~", paste(rand, collapse = " + ")))
      vobj <- variancePartition::voomWithDreamWeights(dge, formula = form, data = metadata, BPPARAM = bpp, quiet = TRUE)
      vp <- variancePartition::fitExtractVarPartModel(vobj, formula = form, data = metadata, BPPARAM = bpp, quiet = TRUE)
      vp <- as.data.frame(vp)
      gid <- rownames(vp)
      sub <- cp[cp$cluster_id == cid, c("gene_id","FDR_BH_within_cluster")]
      fdr <- sub$FDR_BH_within_cluster[match(gid, sub$gene_id)]
      summ <- .summarize_consistency_over_sig(vp$study, fdr)
      vpc_pg[[cid]] <- tibble::tibble(cluster_id = cid, gene_id = gid,
        gene_symbol = unname(gene_symbol_lookup[gid]), vpc_study = vp$study,
        vpc_treatment = vp$treatment, vpc_residual = vp$Residuals)
      list(consistency = .consistency_score("mega", median_heterogeneity = summ$median),
           median_vpc_study = summ$median, n_sig_used = summ$n_used,
           k = length(all_studies), note = NA_character_)
    }, error = function(e) list(consistency = NA_real_, median_vpc_study = NA_real_,
      n_sig_used = 0L, k = NA_integer_, note = conditionMessage(e)))
    rows[[cid]] <- tibble::tibble(cluster_id = cid, method = "mega", k_studies = res$k,
      n_sig_used = res$n_sig_used, consistency_score = res$consistency,
      median_vpc_study = res$median_vpc_study, median_I2 = NA_real_, tau2_median = NA_real_,
      pi_frac_excl0 = NA_real_, sign_concordance = NA_real_, note = res$note)
    cli_alert_info(sprintf("[mega %d/%d] %s cons=%.3f (%.0fs)%s", ii, length(mega_ids), cid,
      res$consistency %||% NA, as.numeric(difftime(Sys.time(), t0, units = "secs")),
      if (!is.na(res$note)) paste0(" SKIP:", res$note) else ""))
  }
}

# ============================ REM — I2 + PI ============================
if (length(rem_ids) > 0) {
  cli_h2("rem — I2 + prediction interval")
  psde <- arrow::read_parquet(file.path(S4_DIR, "per_study_de.parquet"),
    col_select = c("cluster_id","study_id","gene_id","logFC","SE"))
  for (cid in rem_ids) {
    sub <- cp[cp$cluster_id == cid, c("gene_id","I2","FDR_BH_within_cluster")]
    summ_i2 <- .summarize_consistency_over_sig(sub$I2, sub$FDR_BH_within_cluster)
    sig_genes <- sub$gene_id[!is.na(sub$FDR_BH_within_cluster) & sub$FDR_BH_within_cluster < 0.05]
    pd <- psde[psde$cluster_id == cid & psde$gene_id %in% sig_genes, ]
    pis <- lapply(split(pd, pd$gene_id), function(g) .rem_prediction_interval(g$logFC, g$SE))
    if (length(pis) > 0) {
      pg <- tibble::tibble(cluster_id = cid, gene_id = names(pis),
        pi_lower = vapply(pis, `[[`, numeric(1), "pi_lower"),
        pi_upper = vapply(pis, `[[`, numeric(1), "pi_upper"),
        tau2     = vapply(pis, `[[`, numeric(1), "tau2"),
        excl0    = vapply(pis, function(x) isTRUE(x$excl0), logical(1)))
      pi_pg[[cid]] <- pg
      frac_excl0 <- mean(pg$excl0, na.rm = TRUE); tau2_med <- stats::median(pg$tau2, na.rm = TRUE)
    } else { frac_excl0 <- NA_real_; tau2_med <- NA_real_ }
    k <- length(unique(psde$study_id[psde$cluster_id == cid]))
    rows[[cid]] <- tibble::tibble(cluster_id = cid, method = "rem", k_studies = k,
      n_sig_used = summ_i2$n_used,
      consistency_score = .consistency_score("rem", median_heterogeneity = summ_i2$median),
      median_vpc_study = NA_real_, median_I2 = summ_i2$median, tau2_median = tau2_med,
      pi_frac_excl0 = frac_excl0, sign_concordance = NA_real_, note = NA_character_)
    cli_alert_info(sprintf("[rem] %s cons=%.3f pi_excl0=%.2f", cid,
      rows[[cid]]$consistency_score, frac_excl0))
  }
}

# ============================ MEGA_AUG — sign-concordance ============================
if (length(maug_ids) > 0) {
  cli_h2("mega_aug — sign-concordance (k=2)")
  if (!exists("psde")) psde <- arrow::read_parquet(file.path(S4_DIR, "per_study_de.parquet"),
    col_select = c("cluster_id","study_id","gene_id","logFC","SE"))
  for (cid in maug_ids) {
    pd <- psde[psde$cluster_id == cid, ]
    studies <- unique(pd$study_id)
    sub <- cp[cp$cluster_id == cid, c("gene_id","FDR_BH_within_cluster")]
    if (length(studies) == 2L) {
      w <- tidyr::pivot_wider(pd[, c("gene_id","study_id","logFC")],
        names_from = study_id, values_from = logFC, values_fn = mean)
      fdr <- sub$FDR_BH_within_cluster[match(w$gene_id, sub$gene_id)]
      sig_mask <- !is.na(fdr) & fdr < 0.05
      sc <- .sign_concordance(w[[studies[1]]], w[[studies[2]]], sig_mask)
    } else sc <- list(concordance = NA_real_, n_used = 0L)
    rows[[cid]] <- tibble::tibble(cluster_id = cid, method = "mega_aug",
      k_studies = length(studies), n_sig_used = sc$n_used,
      consistency_score = .consistency_score("mega_aug", sign_concordance = sc$concordance),
      median_vpc_study = NA_real_, median_I2 = NA_real_, tau2_median = NA_real_,
      pi_frac_excl0 = NA_real_, sign_concordance = sc$concordance, note = NA_character_)
  }
  cli_alert_info("mega_aug processati: {length(maug_ids)}")
}

# ============================ assembla + scrivi ============================
repro <- dplyr::bind_rows(rows)
repro$conc_confidence <- dplyr::case_when(
  is.na(repro$k_studies) ~ "no_pairs", repro$k_studies >= 3L ~ "trusted",
  repro$k_studies == 2L ~ "low_conf_k2", TRUE ~ "no_pairs")
out_rds <- file.path(S4_DIR, if (SMOKE > 0) "cluster_reproducibility_v2_smoke.rds" else "cluster_reproducibility_v2.rds")
saveRDS(repro, out_rds)
if (length(vpc_pg) > 0) arrow::write_parquet(dplyr::bind_rows(vpc_pg),
  file.path(S4_DIR, if (SMOKE > 0) "cluster_vpc_per_gene_smoke.parquet" else "cluster_vpc_per_gene.parquet"))
if (length(pi_pg) > 0) arrow::write_parquet(dplyr::bind_rows(pi_pg),
  file.path(S4_DIR, if (SMOKE > 0) "cluster_pi_per_gene_smoke.parquet" else "cluster_pi_per_gene.parquet"))

cli_h2("Summary")
cli_alert_success("scritto {out_rds} ({nrow(repro)} cluster)")
print(as.data.frame(repro %>% group_by(method) %>% summarise(n = n(),
  cons_med = round(median(consistency_score, na.rm = TRUE), 3),
  cons_min = round(min(consistency_score, na.rm = TRUE), 3),
  cons_max = round(max(consistency_score, na.rm = TRUE), 3),
  n_NA = sum(is.na(consistency_score)), .groups = "drop")))
