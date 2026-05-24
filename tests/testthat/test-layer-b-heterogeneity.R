test_that(".build_heterogeneity_panel skip non-REM with explanatory caption", {
  cp <- make_fake_cluster_pooled(n_genes = 100, n_sig = 30, cluster_id = "cl_mega")
  cp$method <- "mega"

  out_dir <- tempfile("het_mega_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heterogeneity_panel(cp, out_dir = out_dir, config = cfg)
  expect_match(result$caption, "N/A for non-REM")
})

test_that(".build_heterogeneity_panel runs on REM cluster", {
  set.seed(42)
  cp <- make_fake_cluster_pooled(n_genes = 200, n_sig = 50, cluster_id = "cl_rem")
  cp$method <- "rem"
  cp$tau2 <- abs(rnorm(nrow(cp), 0.05, 0.1))  # mix di REM-amenable e REM-resisted
  cp$I2 <- pmin(100, abs(rnorm(nrow(cp), 30, 25)))

  out_dir <- tempfile("het_rem_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heterogeneity_panel(cp, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "REM-amenable")
})
