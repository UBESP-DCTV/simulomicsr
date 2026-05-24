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

test_that(".build_heterogeneity_panel REM PNG ha full 2-panel dimensioni 8x4 (patchwork attivo)", {
  # Regression test: pre-fix (requireNamespace fallback) il PNG era
  # degradato a 1-panel se patchwork non installato. Post-fix (patchwork
  # hard dep) il PNG deve essere full 8x4 con due pannelli affiancati.
  set.seed(42)
  cp <- make_fake_cluster_pooled(n_genes = 200, n_sig = 50, cluster_id = "cl_rem_dim")
  cp$method <- "rem"
  cp$tau2 <- abs(rnorm(nrow(cp), 0.05, 0.1))
  cp$I2 <- pmin(100, abs(rnorm(nrow(cp), 30, 25)))

  out_dir <- tempfile("het_rem_dim_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heterogeneity_panel(cp, out_dir = out_dir, config = cfg)

  # PNG header inspection: i primi 24 byte contengono width/height in big-endian
  # offset 16-19 = width, 20-23 = height (in pixel)
  png_bytes <- readBin(result$png_path, what = "raw", n = 24L)
  width_px  <- readBin(png_bytes[17:20], what = "integer", n = 1L,
                       size = 4L, endian = "big")
  height_px <- readBin(png_bytes[21:24], what = "integer", n = 1L,
                       size = 4L, endian = "big")

  # 8 inch * dpi (default 300) = 2400 px wide; 4 * 300 = 1200 px tall
  expected_w <- 8 * cfg$dpi
  expected_h <- 4 * cfg$dpi
  expect_equal(width_px,  expected_w,
               info = sprintf("Expected width %dpx (8in @ %d dpi)", expected_w, cfg$dpi))
  expect_equal(height_px, expected_h,
               info = sprintf("Expected height %dpx (4in @ %d dpi)", expected_h, cfg$dpi))
})
