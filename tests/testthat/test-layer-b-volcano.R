test_that(".build_volcano writes PNG + SVG with expected content", {
  cp <- make_fake_cluster_pooled()
  out_dir <- tempfile("volcano_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()

  result <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = cfg)

  expect_named(result, c("png_path", "svg_path", "titolo", "caption"), ignore.order = TRUE)
  expect_true(file.exists(result$png_path))
  expect_true(file.exists(result$svg_path))
  expect_match(basename(result$png_path), "^volcano\\.png$")
  expect_match(basename(result$svg_path), "^volcano\\.svg$")
  expect_match(result$caption, "Volcano plot")
  expect_match(result$caption, "FDR<0\\.05")
  # PNG file should be non-empty
  expect_gt(file.info(result$png_path)$size, 1000L)
})

test_that(".build_volcano handles 0 sig genes gracefully", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 0)
  out_dir <- tempfile("volcano_zero_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "0 of 50")
})
