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

make_fake_per_study_de <- function(cluster_id = "cl_aug", n_genes = 50, n_studies = 2) {
  set.seed(42)
  studies <- paste0("GSE", seq_len(n_studies))
  expand.grid(study_id = studies, gene = paste0("G", seq_len(n_genes)),
              KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      cluster_id = cluster_id,
      logFC = rnorm(dplyr::n(), 0, 1),
      SE = abs(rnorm(dplyr::n(), 0.3, 0.1)),
      p_value = runif(dplyr::n(), 0, 1),
      t_stat = logFC / SE,
      n_treated = 3L, n_control = 3L,
      direction_applied = "none"
    ) |>
    dplyr::select(cluster_id, study_id, gene, logFC, SE, p_value, t_stat,
                  n_treated, n_control, direction_applied)
}

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
