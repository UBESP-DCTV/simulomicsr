test_that(".build_forest produces PNG for mega_aug cluster", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 15, cluster_id = "cl_aug")
  cp$method <- "mega_aug"
  cp$n_baseline_studies_augmented <- 8L
  ps <- make_fake_per_study_de(cluster_id = "cl_aug", n_genes = 50, n_studies = 2)

  out_dir <- tempfile("forest_aug_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "mega_aug",
    out_dir = out_dir,
    config = cfg
  )
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "Forest plot")
  expect_match(result$caption, "k=2 pair")
})

test_that(".build_forest REM branch produces PNG with k panels respecting top_n_forest", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("png")
  set.seed(42)
  # Fixture REM: 5 studi, 10 geni sig
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 15, cluster_id = "cl_rem")
  cp$method <- "rem"
  cp$k_effective <- 5L
  cp$tau2 <- abs(rnorm(nrow(cp), 0.02, 0.05))
  cp$n_baseline_studies_augmented <- NA_integer_

  studies <- paste0("GSE", 1:5)
  ps <- expand.grid(study_id = studies, gene = cp$gene,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      cluster_id = "cl_rem",
      logFC = rnorm(dplyr::n(), 0, 1),
      SE = abs(rnorm(dplyr::n(), 0.3, 0.1)),
      p_value = runif(dplyr::n(), 0, 1),
      t_stat = logFC / SE, n_treated = 3L, n_control = 3L,
      direction_applied = "none"
    )

  out_dir <- tempfile("forest_rem_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  cfg$top_n_forest <- 10L
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem", out_dir = out_dir, config = cfg
  )

  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "Forest plots for top \\d+ significantly DE genes")
  expect_match(result$caption, "k=5")
  # Verify PNG dimensions: 8 inch wide x at least 3 inch tall @ 300 DPI
  png_info <- png::readPNG(result$png_path, native = FALSE)
  expect_gte(dim(png_info)[2], 2400L)  # >= 8 inch * 300 dpi
})

test_that(".build_forest skip mega-strict with explanatory caption", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 10, cluster_id = "cl_mega")
  cp$method <- "mega"
  ps <- tibble::tibble()  # mega strict has no per_study_de

  out_dir <- tempfile("forest_mega_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "mega",
    out_dir = out_dir,
    config = cfg
  )
  expect_true(is.na(result$png_path) || is.null(result$png_path))
  expect_match(result$caption, "Forest plot N/A for mega-strict")
})
