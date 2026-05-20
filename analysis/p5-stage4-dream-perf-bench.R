# analysis/p5-stage4-dream-perf-bench.R
# Benchmark DE methods Stadio 4 — debugging approach
#
# Domanda: il path corrente voomWithDreamWeights + dream + eBayes prende
# 10-12 min wall per cluster mega_aug (8+4 sample) su dati reali. Indaghiamo:
#
#   1. DOVE finisce il tempo? (filterByExpr, voomWithDreamWeights, dream,
#      eBayes — quale fase domina?)
#   2. Metodi alternativi danno risultati comparabili e quanto sono piu'
#      veloci?
#
# Metodi confrontati (stesso filterByExpr + TMM upstream):
#   M1 voomWithDreamWeights + dream + eBayes       (current, REFERENCE)
#   M2 limma::voom            + dream + eBayes     (1 pass LMM invece di 2)
#   M3 limma::voom + duplicateCorrelation(study) + lmFit + eBayes
#                                                   (limma classic, no LMM)
#   M4 limma::voom + study fixed-effect + lmFit + eBayes
#                                                   (no random effect)
#
# Cluster picks: pair_L0_96ddb249 (mega_aug, 12 sample, 3 studi) +
#                group_L0_c62104eb (mega k=5, 33 sample, 5 studi)
#
# Output: analysis/p4-output/p5-stage4-bench-<timestamp>/
#   - bench_results.rds: per-method per-cluster timings + coef vectors
#   - bench_summary.csv: tabella comparativa per decisione
#   - bench.log: log testuale
#
# Usage: Rscript analysis/p5-stage4-dream-perf-bench.R 2>&1 | tee /tmp/bench.log

# Thread cap (evita oversubscription OpenBLAS su 32-core dgx)
Sys.setenv(OPENBLAS_NUM_THREADS = "4", OMP_NUM_THREADS = "4")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(dplyr)
  library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(4L)
  RhpcBLASctl::omp_set_num_threads(4L)
}

set.seed(42)

# ---- Input paths ----------------------------------------------------------
stage3_dir  <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

cli_h1("Setup bench")
cli_alert_info("Loading stage3 + stage2_master...")
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success("Loaded: {.val {nrow(s3$clusters)}} clusters / {.val {nrow(s3$assignments)}} assignments / {.val {length(stage2_master)}} stage2 studies")

# Output dir
out_dir <- file.path("analysis/p4-output",
                      sprintf("p5-stage4-bench-%s",
                              format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cli_alert_info("Output dir: {.path {out_dir}}")

# ---- Cluster picks --------------------------------------------------------
bench_clusters <- tibble::tibble(
  cid    = c("pair_L0_96ddb249",  "group_L0_c62104eb"),
  method = c("mega_aug",          "mega"             )
)

# ---- Helpers --------------------------------------------------------------

# Replica l'estrazione orchestrator per (counts, metadata) di un cluster.
# Restituisce list(counts, metadata, n_baseline_studies_augmented).
prepare_cluster_data <- function(cid, method, s3, stage2_master, h5_path) {
  cl <- s3$clusters[s3$clusters$cluster_id == cid, ][1L, ]
  assignments <- s3$assignments[s3$assignments$cluster_id == cid, ]

  # Build dispatch via funzioni package
  if (method == "mega_aug") {
    el <- cl
    el$method <- "mega_aug"
    dispatch <- simulomicsr:::.build_study_dispatch_from_stage3(
      el, assignments, stage2_master
    )[[cid]]

    # Pair samples
    pair_treated <- unlist(lapply(dispatch, `[[`, "treated"))
    pair_control <- unlist(lapply(dispatch, `[[`, "control"))

    # Baseline pool: parsa control_anchor_key dal cluster + lookup group baseline
    parsed <- simulomicsr:::.parse_pair_anchor_key(cl$anchor_key, cl$level)
    group_baseline <- s3$clusters[
      s3$clusters$mode == "group" &
      s3$clusters$level == cl$level &
      s3$clusters$anchor_key == parsed$control, ]
    if (nrow(group_baseline) > 0L) {
      group_baseline_enriched <- simulomicsr:::.enrich_group_baseline_sample_ids(
        group_baseline,
        s3$assignments[s3$assignments$cluster_id %in% group_baseline$cluster_id, ],
        stage2_master
      )
    } else {
      group_baseline_enriched <- group_baseline
      group_baseline_enriched$sample_ids <- list()
    }

    pair_cluster_struct <- list(
      cluster_id = cid,
      level = cl$level,
      treated_anchor_key = parsed$treated,
      control_anchor_key = parsed$control,
      studies_in_cluster = cl$studies_in_cluster[[1L]],
      treated_samples = list(pair_treated),
      control_samples = list(pair_control)
    )
    assembled <- simulomicsr:::.assemble_mega_aug_metadata(
      pair_cluster_struct, group_baseline_enriched
    )
    metadata <- assembled$metadata
    n_baseline_studies_augmented <- assembled$n_baseline_studies_augmented

  } else if (method == "mega") {
    el <- cl
    el$method <- "mega"
    dispatch <- simulomicsr:::.build_group_dispatch_from_stage3(
      el, assignments, stage2_master
    )[[cid]]
    metadata <- data.frame(
      sample_id = unlist(lapply(dispatch, `[[`, "sample_ids")),
      study = factor(unlist(lapply(dispatch, function(d) {
        rep(d$study_id, length(d$sample_ids))
      }))),
      treatment = factor(
        unlist(lapply(dispatch, `[[`, "treatment")),
        levels = c("control", "treated")
      ),
      stringsAsFactors = FALSE
    )
    n_baseline_studies_augmented <- 0L
  }

  # Fetch counts per sample
  all_studies <- unique(as.character(metadata$study))
  fetch_fn <- function(g, s) simulomicsr:::.fetch_counts_cached(
    g, s, h5_path = h5_path
  )
  counts_list <- lapply(all_studies, function(s) {
    sids <- metadata$sample_id[metadata$study == s]
    fetch_fn(s, sids)
  })
  common_genes <- Reduce(intersect, lapply(counts_list, rownames))
  counts <- do.call(cbind, lapply(counts_list, function(m) {
    m[common_genes, , drop = FALSE]
  }))

  # Riallinea metadata all'ordine di colnames(counts)
  metadata <- as.data.frame(metadata, stringsAsFactors = FALSE)
  metadata <- metadata[match(colnames(counts), metadata$sample_id), , drop = FALSE]
  rownames(metadata) <- metadata$sample_id

  list(counts = counts, metadata = metadata,
       n_baseline_studies_augmented = n_baseline_studies_augmented)
}

# Apply filterByExpr + TMM (shared upstream)
prep_dge <- function(counts, metadata) {
  dge <- edgeR::DGEList(counts = counts)
  keep <- edgeR::filterByExpr(dge, group = metadata$treatment)
  dge <- dge[keep, , keep.lib.sizes = FALSE]
  dge <- edgeR::normLibSizes(dge, method = "TMM")
  dge
}

# Timing helper
time_phase <- function(label, expr) {
  t0 <- Sys.time()
  val <- force(expr)
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cli_alert_info("  {label}: {round(wall, 2)} sec")
  list(value = val, wall = wall)
}

# ---- Method runners -------------------------------------------------------

run_M1_voomDream <- function(dge, metadata) {
  bpparam <- BiocParallel::SerialParam()
  voom_t <- time_phase("M1.voomWithDreamWeights", {
    variancePartition::voomWithDreamWeights(
      dge, formula = ~ treatment + (1 | study),
      data = metadata, BPPARAM = bpparam, quiet = TRUE
    )
  })
  dream_t <- time_phase("M1.dream", {
    variancePartition::dream(
      voom_t$value, formula = ~ treatment + (1 | study),
      data = metadata, BPPARAM = bpparam, quiet = TRUE
    )
  })
  ebayes_t <- time_phase("M1.eBayes", variancePartition::eBayes(dream_t$value))
  fit <- ebayes_t$value
  list(
    logFC = fit$coefficients[, "treatmenttreated"],
    SE    = sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"],
    p_val = fit$p.value[, "treatmenttreated"],
    wall_voom = voom_t$wall, wall_dream = dream_t$wall,
    wall_ebayes = ebayes_t$wall
  )
}

run_M2_voomLimma_dream <- function(dge, metadata) {
  design <- stats::model.matrix(~ treatment, data = metadata)
  voom_t <- time_phase("M2.voom", limma::voom(dge, design))
  dream_t <- time_phase("M2.dream", {
    variancePartition::dream(
      voom_t$value, formula = ~ treatment + (1 | study),
      data = metadata, BPPARAM = BiocParallel::SerialParam(), quiet = TRUE
    )
  })
  ebayes_t <- time_phase("M2.eBayes", variancePartition::eBayes(dream_t$value))
  fit <- ebayes_t$value
  list(
    logFC = fit$coefficients[, "treatmenttreated"],
    SE    = sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"],
    p_val = fit$p.value[, "treatmenttreated"],
    wall_voom = voom_t$wall, wall_dream = dream_t$wall,
    wall_ebayes = ebayes_t$wall
  )
}

run_M3_voomLimma_dupCor <- function(dge, metadata) {
  design <- stats::model.matrix(~ treatment, data = metadata)
  voom1_t <- time_phase("M3.voom1", limma::voom(dge, design))
  cor1_t  <- time_phase("M3.dupCor1",
    limma::duplicateCorrelation(voom1_t$value, design, block = metadata$study))
  voom2_t <- time_phase("M3.voom2",
    limma::voom(dge, design, block = metadata$study,
                correlation = cor1_t$value$consensus.correlation))
  cor2_t  <- time_phase("M3.dupCor2",
    limma::duplicateCorrelation(voom2_t$value, design, block = metadata$study))
  fit_t <- time_phase("M3.lmFit",
    limma::lmFit(voom2_t$value, design, block = metadata$study,
                  correlation = cor2_t$value$consensus.correlation))
  ebayes_t <- time_phase("M3.eBayes", limma::eBayes(fit_t$value))
  fit <- ebayes_t$value
  list(
    logFC = fit$coefficients[, "treatmenttreated"],
    SE    = sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"],
    p_val = fit$p.value[, "treatmenttreated"],
    wall_voom = voom1_t$wall + voom2_t$wall,
    wall_dream = cor1_t$wall + cor2_t$wall + fit_t$wall,  # "modelling" surrogate
    wall_ebayes = ebayes_t$wall
  )
}

run_M4_voomLimma_fixed <- function(dge, metadata) {
  # Se study ha solo 1 livello, fixed-effect non e' fattibile; skip
  if (nlevels(droplevels(metadata$study)) <= 1L) {
    return(list(skipped = TRUE,
                reason = "single study level: fixed-effect not identifiable"))
  }
  design <- stats::model.matrix(~ treatment + study, data = metadata)
  voom_t <- time_phase("M4.voom", limma::voom(dge, design))
  fit_t  <- time_phase("M4.lmFit", limma::lmFit(voom_t$value, design))
  ebayes_t <- time_phase("M4.eBayes", limma::eBayes(fit_t$value))
  fit <- ebayes_t$value
  list(
    logFC = fit$coefficients[, "treatmenttreated"],
    SE    = sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"],
    p_val = fit$p.value[, "treatmenttreated"],
    wall_voom = voom_t$wall, wall_dream = fit_t$wall,
    wall_ebayes = ebayes_t$wall
  )
}

# ---- Bench loop -----------------------------------------------------------

all_results <- list()
for (i in seq_len(nrow(bench_clusters))) {
  cid <- bench_clusters$cid[i]
  meth <- bench_clusters$method[i]
  cli_h2("Cluster: {cid} ({meth})")

  data <- prepare_cluster_data(cid, meth, s3, stage2_master, h5_path)
  cli_alert_info("samples: {ncol(data$counts)}; studies: {nlevels(droplevels(data$metadata$study))}")
  cli_alert_info("baseline_studies_augmented: {data$n_baseline_studies_augmented}")

  dge_t <- time_phase("filterByExpr+TMM", prep_dge(data$counts, data$metadata))
  dge <- dge_t$value
  cli_alert_info("n_genes post-filter: {nrow(dge)}")

  cluster_results <- list(
    cid = cid, method = meth,
    n_samples = ncol(data$counts),
    n_studies = nlevels(droplevels(data$metadata$study)),
    n_genes_post_filter = nrow(dge),
    wall_prep = dge_t$wall,
    methods = list()
  )

  cli_alert("Running M1 voomWithDreamWeights+dream (reference)...")
  M1 <- tryCatch(run_M1_voomDream(dge, data$metadata),
                  error = function(e) list(error = conditionMessage(e), ok = FALSE))
  cluster_results$methods$M1 <- M1

  cli_alert("Running M2 voom+dream...")
  M2 <- tryCatch(run_M2_voomLimma_dream(dge, data$metadata),
                  error = function(e) list(error = conditionMessage(e), ok = FALSE))
  cluster_results$methods$M2 <- M2

  cli_alert("Running M3 voom+duplicateCorrelation+lmFit...")
  M3 <- tryCatch(run_M3_voomLimma_dupCor(dge, data$metadata),
                  error = function(e) list(error = conditionMessage(e), ok = FALSE))
  cluster_results$methods$M3 <- M3

  cli_alert("Running M4 voom+study(fixed)+lmFit...")
  M4 <- tryCatch(run_M4_voomLimma_fixed(dge, data$metadata),
                  error = function(e) list(error = conditionMessage(e), ok = FALSE))
  cluster_results$methods$M4 <- M4

  all_results[[cid]] <- cluster_results

  saveRDS(all_results, file.path(out_dir, "bench_results.rds"))
}

# ---- Comparison table -----------------------------------------------------

cli_h1("Comparison summary")

summary_rows <- list()
for (cid in names(all_results)) {
  cr <- all_results[[cid]]
  M1 <- cr$methods$M1
  for (m in c("M1", "M2", "M3", "M4")) {
    Mx <- cr$methods[[m]]
    if (isTRUE(Mx$skipped)) {
      summary_rows[[length(summary_rows) + 1L]] <- tibble::tibble(
        cluster_id = cid, method = m, status = "skipped",
        reason = Mx$reason, wall_total = NA_real_,
        rho_logFC_vs_M1 = NA_real_, sign_agree_top100 = NA_real_,
        median_p = NA_real_, pct_p_lt_05 = NA_real_, lambda = NA_real_
      )
      next
    }
    if (!is.null(Mx$error)) {
      summary_rows[[length(summary_rows) + 1L]] <- tibble::tibble(
        cluster_id = cid, method = m, status = "error",
        reason = Mx$error, wall_total = NA_real_,
        rho_logFC_vs_M1 = NA_real_, sign_agree_top100 = NA_real_,
        median_p = NA_real_, pct_p_lt_05 = NA_real_, lambda = NA_real_
      )
      next
    }
    wall <- Mx$wall_voom + Mx$wall_dream + Mx$wall_ebayes
    # Concordanza vs M1
    rho <- NA_real_; sa <- NA_real_
    if (!is.null(M1$logFC) && !is.null(Mx$logFC)) {
      g <- intersect(names(M1$logFC), names(Mx$logFC))
      if (length(g) > 50L) {
        rho <- suppressWarnings(cor(M1$logFC[g], Mx$logFC[g],
                                      use = "complete.obs",
                                      method = "spearman"))
        # sign agreement on top 100 by |logFC| of M1
        top100 <- names(sort(abs(M1$logFC), decreasing = TRUE))[1:min(100L, length(g))]
        top100 <- intersect(top100, g)
        sa <- mean(sign(M1$logFC[top100]) == sign(Mx$logFC[top100]),
                    na.rm = TRUE)
      }
    }
    # p-value health
    pv <- Mx$p_val
    medp <- median(pv, na.rm = TRUE)
    pct05 <- mean(pv < 0.05, na.rm = TRUE)
    # lambda inflation (genomic control): median chi-square / 0.455
    chisq <- qchisq(1 - pv, df = 1)
    lambda <- median(chisq, na.rm = TRUE) / qchisq(0.5, df = 1)

    summary_rows[[length(summary_rows) + 1L]] <- tibble::tibble(
      cluster_id = cid, method = m, status = "ok", reason = "",
      wall_total = wall,
      rho_logFC_vs_M1 = rho,
      sign_agree_top100 = sa,
      median_p = medp,
      pct_p_lt_05 = pct05,
      lambda = lambda
    )
  }
}
summary_df <- do.call(rbind, summary_rows)
print(summary_df, n = Inf)
write.csv(summary_df, file.path(out_dir, "bench_summary.csv"), row.names = FALSE)
cli_alert_success("Bench summary written: {.path {file.path(out_dir, 'bench_summary.csv')}}")
