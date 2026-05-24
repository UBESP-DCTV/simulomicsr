# Test integration end-to-end per build_layer_b_results().
# Helper make_fake_layer_a_dir() / make_fake_counts_cache() vivono in
# tests/testthat/helper-layer-b-fixtures.R (auto-caricato da testthat).

test_that("build_layer_b_results end-to-end on mini fixture", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))

  # Build per_cluster_samples: 2 study x 3 sample per study x 2 treatment
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }

  selection <- tibble::tibble(
    cluster_id = c("cl_mega_1", "cl_aug_1"),
    label_paper = c("MegaTest", "AugTest"),
    priority = c(1L, 2L),
    notes = c("", "")
  )

  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE  # skip in test (slow + needs real symbols)

  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("lb_out_")
  )

  expect_s3_class(result, "layer_b_result")
  expect_equal(length(result$cluster_bundles), 2L)
  expect_true(file.exists(file.path(result$dir, "selection_resolved.csv")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "volcano.png")))
  expect_true(file.exists(file.path(result$dir, "cl_aug_1", "forest.png")))
  # mega should NOT have forest png (skip-graceful)
  expect_false(file.exists(file.path(result$dir, "cl_mega_1", "forest.png")))
  expect_match(result$run_metadata$run_id, "^[a-f0-9]{8}$")
})
