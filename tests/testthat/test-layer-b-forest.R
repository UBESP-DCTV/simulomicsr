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
