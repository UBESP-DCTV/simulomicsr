# Test per .run_dream_mega: dream MEGA `~ treatment + (1|study)` su
# 4 studi x 6 sample (3 treated + 3 control) x 50 geni.
test_that(".run_dream_mega produce tibble gene-level con logFC_pool + SE_pool", {
  skip_if_not_installed("variancePartition")

  # Fixture: 50 geni x 24 sample (4 studi x 6 sample, 3 treated + 3 control)
  set.seed(42)
  n_genes <- 50
  n_samples <- 24
  counts <- matrix(
    rnbinom(n_genes * n_samples, size = 5, mu = 200),
    nrow = n_genes, ncol = n_samples
  )
  rownames(counts) <- paste0("GENE_", sprintf("%03d", seq_len(n_genes)))
  colnames(counts) <- paste0("GSM", sprintf("%06d", seq_len(n_samples)))

  metadata <- data.frame(
    sample_id = colnames(counts),
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(
      rep(c("treated", "treated", "treated",
            "control", "control", "control"), 4),
      levels = c("control", "treated")
    )
  )

  res <- .run_dream_mega(counts, metadata, cluster_id = "TEST_MEGA",
                          workers = 1L)

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("cluster_id", "gene", "method", "logFC_pool", "SE_pool",
                       "p_value_pool", "tau2", "I2", "Q", "Q_pval",
                       "k_effective", "n_baseline_studies_augmented",
                       "FDR_BH_within_cluster", "direction_applied"),
                ignore.order = TRUE)
  expect_equal(unique(res$method), "mega")
  expect_equal(unique(res$k_effective), 4L)
  expect_true(all(is.na(res$tau2)))
  expect_true(all(is.finite(res$logFC_pool)))
})
