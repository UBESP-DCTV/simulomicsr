# Test per .pool_rem_cluster: pooling REM via metafor::rma con REML + DL fallback.

test_that(".pool_rem_cluster ritorna tibble gene-level con tau2 + I2 + Q", {
  skip_if_not_installed("metafor")

  # Fixture: 5 geni x 3 studi
  per_study <- tibble::tibble(
    cluster_id = "TEST",
    study_id = rep(c("GSE001", "GSE002", "GSE003"), each = 5),
    gene_id = rep(paste0("ENSG", 1:5), 3),
    gene_symbol = rep(paste0("SYM_", 1:5), 3),
    logFC = c( 2.0, 1.0, 0.5, -0.5, -1.0,
               2.2, 1.1, 0.5, -0.4, -1.1,
               1.8, 0.9, 0.6, -0.5, -0.9),
    SE    = rep(c(0.3, 0.4, 0.3, 0.3, 0.4), 3),
    p_value = 0.01,
    t_stat = NA_real_,
    n_treated = 3L,
    n_control = 3L,
    direction_applied = "none"
  )

  res <- .pool_rem_cluster(per_study, method = "REML", fallback = "DL")

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("cluster_id", "gene_id", "gene_symbol", "method",
                       "logFC_pool", "SE_pool",
                       "p_value_pool", "tau2", "I2", "Q", "Q_pval",
                       "k_effective", "n_baseline_studies_augmented",
                       "FDR_BH_within_cluster", "direction_applied"),
               ignore.order = TRUE)
  expect_equal(nrow(res), 5L)
  expect_equal(unique(res$method), "rem")
  expect_true(all(res$k_effective == 3L))
  expect_true(all(is.na(res$n_baseline_studies_augmented)))
})

test_that(".pool_rem_cluster fallback a DL se REML fail", {
  skip_if_not_installed("metafor")

  # Fixture: scenario degenerato (SE quasi nulli) per verificare path fallback.
  per_study <- tibble::tibble(
    cluster_id = "TEST_DEG",
    study_id = rep(c("GSE001", "GSE002"), each = 2),
    gene_id = rep(c("ENSG1", "ENSG2"), 2),
    gene_symbol = rep(c("SYM1", "SYM2"), 2),
    logFC = c(2, 1, 2, 1),
    SE = c(0.0001, 0.0001, 0.0001, 0.0001),
    p_value = 0.001,
    t_stat = NA_real_,
    n_treated = 3L,
    n_control = 3L,
    direction_applied = "none"
  )

  res <- .pool_rem_cluster(per_study, method = "REML", fallback = "DL")
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 2L)
  # Output deve essere finito anche con SE problematici.
  expect_true(all(is.finite(res$logFC_pool)))
})
