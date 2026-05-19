test_that(".run_limma_voom_de produce tibble per-gene con logFC + SE + p", {
  skip_if_not_installed("limma")
  skip_if_not_installed("edgeR")

  # Fixture: 100 geni x 6 sample (3 treated + 3 control)
  set.seed(42)
  counts <- matrix(rnbinom(600, size = 5, mu = 100), nrow = 100, ncol = 6)
  rownames(counts) <- paste0("GENE_", sprintf("%03d", 1:100))
  colnames(counts) <- paste0("GSM", sprintf("%06d", 1:6))
  # Induci differenziale su primi 10 geni (treated up)
  counts[1:10, 1:3] <- counts[1:10, 1:3] * 5

  treatment_vec <- factor(rep(c("treated", "control"), each = 3),
                          levels = c("control", "treated"))

  res <- .run_limma_voom_de(counts, treatment_vec, study_id = "GSE001",
                             cluster_id = "TEST", direction_flip = FALSE)

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("cluster_id", "study_id", "gene", "logFC", "SE",
                       "p_value", "t_stat", "n_treated", "n_control",
                       "direction_applied"),
               ignore.order = TRUE)
  expect_equal(unique(res$study_id), "GSE001")
  expect_equal(unique(res$n_treated), 3L)
  expect_equal(unique(res$n_control), 3L)
  expect_true(all(res$SE > 0))
  expect_true(all(res$p_value >= 0 & res$p_value <= 1))
})

test_that(".run_limma_voom_de applica direction_flip negando logFC", {
  skip_if_not_installed("limma")

  set.seed(42)
  counts <- matrix(rnbinom(600, size = 5, mu = 100), nrow = 100, ncol = 6)
  rownames(counts) <- paste0("GENE_", sprintf("%03d", 1:100))
  colnames(counts) <- paste0("GSM", sprintf("%06d", 1:6))
  treatment_vec <- factor(rep(c("treated", "control"), each = 3),
                          levels = c("control", "treated"))

  res_canon <- .run_limma_voom_de(counts, treatment_vec, "GSE001",
                                    cluster_id = "TEST",
                                    direction_flip = FALSE)
  res_flip  <- .run_limma_voom_de(counts, treatment_vec, "GSE001",
                                    cluster_id = "TEST",
                                    direction_flip = TRUE)

  expect_equal(res_flip$logFC, -res_canon$logFC)
  expect_equal(unique(res_flip$direction_applied), "flipped")
  expect_equal(unique(res_canon$direction_applied), "none")
})
