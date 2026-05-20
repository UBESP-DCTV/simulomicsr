# analysis/p5-stage4-bench-k11.R
# Validazione k=11: M1par(w=100) vs M3 vs M2par(w=100) su group_L0_c5aacc5f
# (MCF7, k=11, mega strict, 30 sample). Conferma che ρ M3-vs-M1par >0.99
# anche con maggiore eterogeneita' study prima di scegliere il default.
#
# Output: analysis/p4-output/p5-stage4-bench-k11-<ts>/
#
# Usage: Rscript analysis/p5-stage4-bench-k11.R 2>&1 | tee /tmp/bench-k11.log

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".")
  library(dplyr); library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
set.seed(42)

WORKERS <- 100L

stage3_dir  <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

cli_h1("Bench k=11 (workers={WORKERS})")
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)

out_dir <- file.path("analysis/p4-output",
                      sprintf("p5-stage4-bench-k11-%s",
                              format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cli_alert_info("Output dir: {.path {out_dir}}")

# ---- Prep cluster k=11 ----------------------------------------------------
cid <- "group_L0_c5aacc5f"
cl <- s3$clusters[s3$clusters$cluster_id == cid, ][1L, ]
assignments <- s3$assignments[s3$assignments$cluster_id == cid, ]

el <- cl; el$method <- "mega"
dispatch <- simulomicsr:::.build_group_dispatch_from_stage3(
  el, assignments, stage2_master)[[cid]]
metadata <- data.frame(
  sample_id = unlist(lapply(dispatch, `[[`, "sample_ids")),
  study = factor(unlist(lapply(dispatch, function(d) {
    rep(d$study_id, length(d$sample_ids))
  }))),
  treatment = factor(
    unlist(lapply(dispatch, `[[`, "treatment")),
    levels = c("control", "treated")),
  stringsAsFactors = FALSE
)
all_studies <- unique(as.character(metadata$study))
fetch_fn <- function(g, s) simulomicsr:::.fetch_counts_cached(
  g, s, h5_path = h5_path)
counts_list <- lapply(all_studies, function(s) {
  sids <- metadata$sample_id[metadata$study == s]
  fetch_fn(s, sids)
})
common_genes <- Reduce(intersect, lapply(counts_list, rownames))
counts <- do.call(cbind, lapply(counts_list, function(m) {
  m[common_genes, , drop = FALSE]
}))
metadata <- as.data.frame(metadata, stringsAsFactors = FALSE)
metadata <- metadata[match(colnames(counts), metadata$sample_id), , drop = FALSE]
rownames(metadata) <- metadata$sample_id

cli_alert_info("k=11 cluster: samples={ncol(counts)}, studies={nlevels(droplevels(metadata$study))}")
cli_alert_info("treatment distrib: {paste(names(table(metadata$treatment)),'=',unname(table(metadata$treatment)), collapse=', ')}")

# ---- filterByExpr + TMM ---------------------------------------------------
dge <- edgeR::DGEList(counts = counts)
keep <- edgeR::filterByExpr(dge, group = metadata$treatment)
dge <- dge[keep, , keep.lib.sizes = FALSE]
dge <- edgeR::normLibSizes(dge, method = "TMM")
cli_alert_info("n_genes post-filter: {nrow(dge)}")

# ---- Method runners --------------------------------------------------------
time_phase <- function(label, expr) {
  t0 <- Sys.time(); val <- force(expr)
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cli_alert_info("  {label}: {round(wall, 2)} sec")
  list(value = val, wall = wall)
}

# M1par (reference)
cli_alert("Running M1par voomWithDreamWeights+dream (w={WORKERS})...")
bpparam <- BiocParallel::MulticoreParam(WORKERS)
voom_t <- time_phase("M1par.voomWithDreamWeights",
  variancePartition::voomWithDreamWeights(
    dge, formula = ~ treatment + (1 | study), data = metadata,
    BPPARAM = bpparam, quiet = TRUE))
dream_t <- time_phase("M1par.dream",
  variancePartition::dream(
    voom_t$value, formula = ~ treatment + (1 | study), data = metadata,
    BPPARAM = bpparam, quiet = TRUE))
ebayes_t <- time_phase("M1par.eBayes",
  variancePartition::eBayes(dream_t$value))
fit1 <- ebayes_t$value
M1par <- list(
  logFC = fit1$coefficients[, "treatmenttreated"],
  SE    = sqrt(fit1$s2.post) * fit1$stdev.unscaled[, "treatmenttreated"],
  p_val = fit1$p.value[, "treatmenttreated"],
  wall_voom = voom_t$wall, wall_dream = dream_t$wall,
  wall_ebayes = ebayes_t$wall
)

# M2par
cli_alert("Running M2par voom+dream (w={WORKERS})...")
design <- stats::model.matrix(~ treatment, data = metadata)
voom2_t <- time_phase("M2par.voom", limma::voom(dge, design))
dream2_t <- time_phase("M2par.dream",
  variancePartition::dream(
    voom2_t$value, formula = ~ treatment + (1 | study), data = metadata,
    BPPARAM = bpparam, quiet = TRUE))
ebayes2_t <- time_phase("M2par.eBayes",
  variancePartition::eBayes(dream2_t$value))
fit2 <- ebayes2_t$value
M2par <- list(
  logFC = fit2$coefficients[, "treatmenttreated"],
  SE    = sqrt(fit2$s2.post) * fit2$stdev.unscaled[, "treatmenttreated"],
  p_val = fit2$p.value[, "treatmenttreated"],
  wall_voom = voom2_t$wall, wall_dream = dream2_t$wall,
  wall_ebayes = ebayes2_t$wall
)

# M3
cli_alert("Running M3 voom+duplicateCorrelation+lmFit...")
voom3a_t <- time_phase("M3.voom1", limma::voom(dge, design))
cor1_t  <- time_phase("M3.dupCor1",
  limma::duplicateCorrelation(voom3a_t$value, design, block = metadata$study))
voom3b_t <- time_phase("M3.voom2",
  limma::voom(dge, design, block = metadata$study,
              correlation = cor1_t$value$consensus.correlation))
cor2_t  <- time_phase("M3.dupCor2",
  limma::duplicateCorrelation(voom3b_t$value, design, block = metadata$study))
fit3_t <- time_phase("M3.lmFit",
  limma::lmFit(voom3b_t$value, design, block = metadata$study,
                correlation = cor2_t$value$consensus.correlation))
ebayes3_t <- time_phase("M3.eBayes", limma::eBayes(fit3_t$value))
fit3 <- ebayes3_t$value
M3 <- list(
  logFC = fit3$coefficients[, "treatmenttreated"],
  SE    = sqrt(fit3$s2.post) * fit3$stdev.unscaled[, "treatmenttreated"],
  p_val = fit3$p.value[, "treatmenttreated"],
  wall_voom = voom3a_t$wall + voom3b_t$wall,
  wall_model = cor1_t$wall + cor2_t$wall + fit3_t$wall,
  wall_ebayes = ebayes3_t$wall
)

# ---- Summary --------------------------------------------------------------
cli_h1("Comparison k=11")
all_results <- list(M1par = M1par, M2par = M2par, M3 = M3)
saveRDS(list(cid = cid, n_samples = ncol(counts),
              n_studies = nlevels(droplevels(metadata$study)),
              n_genes = nrow(dge), workers = WORKERS,
              results = all_results),
        file.path(out_dir, "bench_k11_results.rds"))

summary_rows <- list()
ref <- M1par
for (m in c("M1par", "M2par", "M3")) {
  Mx <- all_results[[m]]
  wall <- Mx$wall_voom + (Mx$wall_dream %||% Mx$wall_model %||% 0) +
            Mx$wall_ebayes
  rho <- NA_real_; sa <- NA_real_
  if (m != "M1par") {
    g <- intersect(names(ref$logFC), names(Mx$logFC))
    if (length(g) > 50L) {
      rho <- suppressWarnings(cor(ref$logFC[g], Mx$logFC[g],
                                    use = "complete.obs",
                                    method = "spearman"))
      top100 <- names(sort(abs(ref$logFC), decreasing = TRUE))[1:min(100L, length(g))]
      top100 <- intersect(top100, g)
      sa <- mean(sign(ref$logFC[top100]) == sign(Mx$logFC[top100]),
                  na.rm = TRUE)
    }
  } else {
    rho <- 1; sa <- 1
  }
  pv <- Mx$p_val
  medp <- median(pv, na.rm = TRUE)
  pct05 <- mean(pv < 0.05, na.rm = TRUE)
  chisq <- qchisq(1 - pv, df = 1)
  lambda <- median(chisq, na.rm = TRUE) / qchisq(0.5, df = 1)

  summary_rows[[length(summary_rows) + 1L]] <- tibble::tibble(
    method = m, wall_total = wall,
    rho_logFC_vs_M1par = rho, sign_agree_top100 = sa,
    median_p = medp, pct_p_lt_05 = pct05, lambda = lambda
  )
}
summary_df <- do.call(rbind, summary_rows)
print(summary_df, n = Inf)
write.csv(summary_df, file.path(out_dir, "bench_k11_summary.csv"),
          row.names = FALSE)
cli_alert_success("k=11 bench summary: {.path {file.path(out_dir, 'bench_k11_summary.csv')}}")
