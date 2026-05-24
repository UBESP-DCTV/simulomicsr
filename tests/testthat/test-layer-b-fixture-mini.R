# Integration test end-to-end + round-trip + per-method file expectations
# (forest solo per mega_aug, skip per mega) + selection_resolved + run_metadata.
# Helper make_fake_layer_a_dir() / make_fake_counts_cache() in
# tests/testthat/helper-layer-b-fixtures.R.

test_that("build + write + load + report end-to-end on mini fixture", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))
  on.exit(unlink(cache$dir, recursive = TRUE), add = TRUE)

  per_cluster_samples_provider <- function(cluster_id) {
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 6L),
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
  cfg$go_enrichment <- FALSE

  result <- build_layer_b_results(
    stage4_dir = stage4_dir, selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("lb_mini_")
  )

  # Round-trip
  result2 <- load_layer_b(result$dir)
  expect_equal(result2$run_metadata$run_id, result$run_metadata$run_id)
  expect_equal(length(result2$cluster_bundles), 2L)

  # Files attesi per cluster mega (no forest)
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "volcano.png")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "ma.png")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "heatmap.png")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "summary_card.md")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "narrative.qmd")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "top_genes.csv")))
  # mega skip forest
  expect_false(file.exists(file.path(result$dir, "cl_mega_1", "forest.png")))

  # Files attesi per cluster mega_aug (forest YES)
  expect_true(file.exists(file.path(result$dir, "cl_aug_1", "forest.png")))

  # selection_resolved + run_metadata committed
  expect_true(file.exists(file.path(result$dir, "selection_resolved.csv")))
  expect_true(file.exists(file.path(result$dir, "run_metadata.json")))
})
