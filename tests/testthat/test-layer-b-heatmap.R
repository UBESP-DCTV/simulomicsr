test_that(".build_heatmap writes PNG with vst+ComBat + annotation rows", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(42)
  n_genes <- 200
  n_samples_per_study <- 8
  n_studies <- 2
  n_samples <- n_samples_per_study * n_studies

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 50)
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", seq_len(n_studies)), each = n_samples_per_study),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "vst", ignore.case = TRUE)
})

test_that(".build_heatmap subsamples to max_heatmap_samples", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(1)
  n_genes <- 100
  n_samples <- 150  # > max_heatmap_samples default (100)

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 30, cluster_id = "cl_big")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:3), each = 50),
    treatment = rep(c("control", "treated"), length.out = n_samples)
  )

  out_dir <- tempfile("hm_big_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_match(result$caption, "subsampled to")
})
