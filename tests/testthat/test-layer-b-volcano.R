make_fake_cluster_pooled <- function(n_genes = 100, n_sig = 20, cluster_id = "cl_test") {
  set.seed(42)
  logFC <- c(rnorm(n_sig, mean = 0, sd = 3), rnorm(n_genes - n_sig, mean = 0, sd = 0.3))
  p_value <- c(runif(n_sig, 1e-10, 0.01), runif(n_genes - n_sig, 0.05, 1))
  tibble::tibble(
    cluster_id = cluster_id,
    gene = paste0("G", seq_len(n_genes)),
    method = "mega",
    logFC_pool = logFC,
    SE_pool = abs(logFC) / 5 + 0.1,
    p_value_pool = p_value,
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = p.adjust(p_value, method = "BH"),
    direction_applied = "none"
  )
}

test_that(".build_volcano writes PNG + SVG with expected content", {
  cp <- make_fake_cluster_pooled()
  out_dir <- tempfile("volcano_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()

  result <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = cfg)

  expect_named(result, c("png_path", "svg_path", "caption"), ignore.order = TRUE)
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
