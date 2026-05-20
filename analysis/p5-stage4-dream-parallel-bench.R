# analysis/p5-stage4-dream-parallel-bench.R
# Re-bench M1 + M2 con BiocParallel::MulticoreParam(workers) — risposta
# all'opzione 2 (parallelizzare dream). Stessi cluster del bench seriale
# (analysis/p5-stage4-dream-perf-bench.R).
#
# Setup:
#   - OPENBLAS_NUM_THREADS=1 per evitare oversubscription dei worker
#     forkati (ognuno fa proprio BLAS interno se BLAS-thread > 1).
#   - workers = 100 (utente ha 128 core dgx).
#
# Output: analysis/p4-output/p5-stage4-bench-parallel-<timestamp>/
#   - bench_parallel_results.rds
#   - bench_parallel_summary.csv
#
# Usage: Rscript analysis/p5-stage4-dream-parallel-bench.R 2>&1 | tee /tmp/bench-par.log

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(dplyr)
  library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L)
  RhpcBLASctl::omp_set_num_threads(1L)
}

set.seed(42)

WORKERS <- 100L

stage3_dir  <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

cli_h1("Parallel DE bench (workers={WORKERS})")
cli_alert_info("Loading stage3 + stage2_master...")
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success("Loaded: {.val {nrow(s3$clusters)}} clusters / {.val {length(stage2_master)}} stage2 studies")

out_dir <- file.path("analysis/p4-output",
                      sprintf("p5-stage4-bench-parallel-%s",
                              format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cli_alert_info("Output dir: {.path {out_dir}}")

bench_clusters <- tibble::tibble(
  cid    = c("pair_L0_96ddb249",  "group_L0_c62104eb"),
  method = c("mega_aug",          "mega"             )
)

# ---- Cluster prep (replica orchestrator) ----------------------------------
prepare_cluster_data <- function(cid, method, s3, stage2_master, h5_path) {
  cl <- s3$clusters[s3$clusters$cluster_id == cid, ][1L, ]
  assignments <- s3$assignments[s3$assignments$cluster_id == cid, ]
  if (method == "mega_aug") {
    el <- cl; el$method <- "mega_aug"
    dispatch <- simulomicsr:::.build_study_dispatch_from_stage3(
      el, assignments, stage2_master)[[cid]]
    pair_treated <- unlist(lapply(dispatch, `[[`, "treated"))
    pair_control <- unlist(lapply(dispatch, `[[`, "control"))
    parsed <- simulomicsr:::.parse_pair_anchor_key(cl$anchor_key, cl$level)
    group_baseline <- s3$clusters[
      s3$clusters$mode == "group" &
      s3$clusters$level == cl$level &
      s3$clusters$anchor_key == parsed$control, ]
    if (nrow(group_baseline) > 0L) {
      group_baseline_enriched <- simulomicsr:::.enrich_group_baseline_sample_ids(
        group_baseline,
        s3$assignments[s3$assignments$cluster_id %in% group_baseline$cluster_id, ],
        stage2_master)
    } else {
      group_baseline_enriched <- group_baseline
      group_baseline_enriched$sample_ids <- list()
    }
    pair_cluster_struct <- list(
      cluster_id = cid, level = cl$level,
      treated_anchor_key = parsed$treated,
      control_anchor_key = parsed$control,
      studies_in_cluster = cl$studies_in_cluster[[1L]],
      treated_samples = list(pair_treated),
      control_samples = list(pair_control)
    )
    assembled <- simulomicsr:::.assemble_mega_aug_metadata(
      pair_cluster_struct, group_baseline_enriched)
    metadata <- assembled$metadata
  } else if (method == "mega") {
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
  }
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
  list(counts = counts, metadata = metadata)
}

prep_dge <- function(counts, metadata) {
  dge <- edgeR::DGEList(counts = counts)
  keep <- edgeR::filterByExpr(dge, group = metadata$treatment)
  dge <- dge[keep, , keep.lib.sizes = FALSE]
  edgeR::normLibSizes(dge, method = "TMM")
}

time_phase <- function(label, expr) {
  t0 <- Sys.time(); val <- force(expr)
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cli_alert_info("  {label}: {round(wall, 2)} sec")
  list(value = val, wall = wall)
}

run_M1_parallel <- function(dge, metadata, workers) {
  bpparam <- BiocParallel::MulticoreParam(workers)
  voom_t <- time_phase(sprintf("M1par(w=%d).voomWithDreamWeights", workers), {
    variancePartition::voomWithDreamWeights(
      dge, formula = ~ treatment + (1 | study),
      data = metadata, BPPARAM = bpparam, quiet = TRUE)
  })
  dream_t <- time_phase(sprintf("M1par(w=%d).dream", workers), {
    variancePartition::dream(
      voom_t$value, formula = ~ treatment + (1 | study),
      data = metadata, BPPARAM = bpparam, quiet = TRUE)
  })
  ebayes_t <- time_phase("M1par.eBayes",
    variancePartition::eBayes(dream_t$value))
  fit <- ebayes_t$value
  list(
    logFC = fit$coefficients[, "treatmenttreated"],
    SE    = sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"],
    p_val = fit$p.value[, "treatmenttreated"],
    wall_voom = voom_t$wall, wall_dream = dream_t$wall,
    wall_ebayes = ebayes_t$wall
  )
}

run_M2_parallel <- function(dge, metadata, workers) {
  bpparam <- BiocParallel::MulticoreParam(workers)
  design <- stats::model.matrix(~ treatment, data = metadata)
  voom_t <- time_phase("M2par.voom", limma::voom(dge, design))
  dream_t <- time_phase(sprintf("M2par(w=%d).dream", workers), {
    variancePartition::dream(
      voom_t$value, formula = ~ treatment + (1 | study),
      data = metadata, BPPARAM = bpparam, quiet = TRUE)
  })
  ebayes_t <- time_phase("M2par.eBayes",
    variancePartition::eBayes(dream_t$value))
  fit <- ebayes_t$value
  list(
    logFC = fit$coefficients[, "treatmenttreated"],
    SE    = sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"],
    p_val = fit$p.value[, "treatmenttreated"],
    wall_voom = voom_t$wall, wall_dream = dream_t$wall,
    wall_ebayes = ebayes_t$wall
  )
}

all_results <- list()
for (i in seq_len(nrow(bench_clusters))) {
  cid <- bench_clusters$cid[i]
  meth <- bench_clusters$method[i]
  cli_h2("Cluster: {cid} ({meth})")
  data <- prepare_cluster_data(cid, meth, s3, stage2_master, h5_path)
  cli_alert_info("samples: {ncol(data$counts)}; studies: {nlevels(droplevels(data$metadata$study))}")
  dge_t <- time_phase("filterByExpr+TMM", prep_dge(data$counts, data$metadata))
  dge <- dge_t$value
  cli_alert_info("n_genes post-filter: {nrow(dge)}")

  cluster_results <- list(
    cid = cid, method = meth,
    n_samples = ncol(data$counts),
    n_studies = nlevels(droplevels(data$metadata$study)),
    n_genes_post_filter = nrow(dge),
    workers = WORKERS,
    methods = list()
  )

  cli_alert("M1 parallel voomWithDreamWeights+dream w={WORKERS}...")
  M1 <- tryCatch(run_M1_parallel(dge, data$metadata, WORKERS),
                  error = function(e) list(error = conditionMessage(e), ok = FALSE))
  cluster_results$methods$M1par <- M1

  cli_alert("M2 parallel voom+dream w={WORKERS}...")
  M2 <- tryCatch(run_M2_parallel(dge, data$metadata, WORKERS),
                  error = function(e) list(error = conditionMessage(e), ok = FALSE))
  cluster_results$methods$M2par <- M2

  all_results[[cid]] <- cluster_results
  saveRDS(all_results, file.path(out_dir, "bench_parallel_results.rds"))
}

cli_h1("Parallel comparison summary")
summary_rows <- list()
for (cid in names(all_results)) {
  cr <- all_results[[cid]]
  for (m in c("M1par", "M2par")) {
    Mx <- cr$methods[[m]]
    if (!is.null(Mx$error)) {
      summary_rows[[length(summary_rows) + 1L]] <- tibble::tibble(
        cluster_id = cid, method = m, status = "error",
        reason = Mx$error, wall_total = NA_real_,
        wall_voom = NA_real_, wall_dream = NA_real_, wall_ebayes = NA_real_,
        median_p = NA_real_, pct_p_lt_05 = NA_real_, lambda = NA_real_)
      next
    }
    wall <- Mx$wall_voom + Mx$wall_dream + Mx$wall_ebayes
    pv <- Mx$p_val
    medp <- median(pv, na.rm = TRUE)
    pct05 <- mean(pv < 0.05, na.rm = TRUE)
    chisq <- qchisq(1 - pv, df = 1)
    lambda <- median(chisq, na.rm = TRUE) / qchisq(0.5, df = 1)
    summary_rows[[length(summary_rows) + 1L]] <- tibble::tibble(
      cluster_id = cid, method = m, status = "ok", reason = "",
      wall_total = wall,
      wall_voom = Mx$wall_voom, wall_dream = Mx$wall_dream,
      wall_ebayes = Mx$wall_ebayes,
      median_p = medp, pct_p_lt_05 = pct05, lambda = lambda)
  }
}
summary_df <- do.call(rbind, summary_rows)
print(summary_df, n = Inf)
write.csv(summary_df, file.path(out_dir, "bench_parallel_summary.csv"),
          row.names = FALSE)
cli_alert_success("Parallel summary: {.path {file.path(out_dir, 'bench_parallel_summary.csv')}}")
