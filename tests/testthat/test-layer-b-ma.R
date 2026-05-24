test_that(".build_ma_plot writes PNG with loess smooth", {
  cp <- make_fake_cluster_pooled(n_genes = 200, n_sig = 30)
  # Synthetic counts per il calcolo del baseMean (genes x samples)
  counts <- matrix(rpois(200 * 6, lambda = 100), nrow = 200,
                   dimnames = list(cp$gene, paste0("GSM", 1:6)))

  out_dir <- tempfile("ma_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_ma_plot(cp, counts = counts, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "MA plot")
  expect_match(result$caption, "loess")
})
