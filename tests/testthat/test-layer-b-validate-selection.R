test_that("layer_b_validate_selection fails fast on missing cluster_id", {
  stage4_dir <- tempfile()
  dir.create(stage4_dir)
  on.exit(unlink(stage4_dir, recursive = TRUE))

  cp <- tibble::tibble(
    cluster_id = rep(c("cl_a", "cl_b"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 2),
    method = "mega",
    logFC_pool = 0.5,
    SE_pool = 0.1,
    p_value_pool = 0.01,
    tau2 = NA_real_,
    I2 = NA_real_,
    Q = NA_real_,
    Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = 0.05,
    direction_applied = "none"
  )
  arrow::write_parquet(cp, file.path(stage4_dir, "cluster_pooled.parquet"))

  selection <- tibble::tibble(
    cluster_id = c("cl_a", "cl_missing"),
    label_paper = c("A", "Missing"),
    priority = c(1L, 2L),
    notes = c("", "")
  )

  expect_error(
    layer_b_validate_selection(selection, stage4_dir),
    "cluster_id not found in stage4 output: cl_missing"
  )
})

test_that("layer_b_validate_selection returns enriched tibble when all OK", {
  stage4_dir <- tempfile()
  dir.create(stage4_dir)
  on.exit(unlink(stage4_dir, recursive = TRUE))

  cp <- tibble::tibble(
    cluster_id = rep(c("cl_a", "cl_b"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 2),
    method = c(rep("mega", 3), rep("mega_aug", 3)),
    logFC_pool = c(0.5, 1.2, -0.8, 2.0, 0.3, -1.5),
    SE_pool = 0.1,
    p_value_pool = c(0.001, 0.5, 0.02, 0.0001, 0.6, 0.005),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = c(5L, 5L, 5L, 2L, 2L, 2L),
    n_baseline_studies_augmented = c(NA, NA, NA, 8L, 8L, 8L),
    FDR_BH_within_cluster = c(0.005, 0.6, 0.04, 0.0003, 0.7, 0.015),
    direction_applied = "none"
  )
  arrow::write_parquet(cp, file.path(stage4_dir, "cluster_pooled.parquet"))

  selection <- tibble::tibble(
    cluster_id = c("cl_a", "cl_b"),
    label_paper = c("A", "B"),
    priority = c(1L, 2L),
    notes = c("", "")
  )

  result <- layer_b_validate_selection(selection, stage4_dir)
  expect_s3_class(result, "tbl_df")
  expect_named(
    result,
    c("cluster_id", "label_paper", "priority", "notes",
      "exists_in_stage4", "method", "k_effective", "n_sig_FDR05"),
    ignore.order = TRUE
  )
  expect_true(all(result$exists_in_stage4))
  expect_equal(result$method, c("mega", "mega_aug"))
  expect_equal(result$k_effective, c(5L, 2L))
  expect_equal(result$n_sig_FDR05, c(2L, 2L))
})
