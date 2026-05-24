# Replication test: run twice on same input -> identico run_id +
# byte-equal selection_resolved.csv.
# Helper make_fake_layer_a_dir() / make_fake_counts_cache() in
# tests/testthat/helper-layer-b-fixtures.R.

test_that("build_layer_b_results twice on same input yields same run_id", {
  skip_if_not_installed("ComplexHeatmap")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1"))
  on.exit(unlink(cache$dir, recursive = TRUE), add = TRUE)

  per_cluster_samples_provider <- function(cluster_id) {
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }

  selection <- tibble::tibble(
    cluster_id = "cl_mega_1", label_paper = "X",
    priority = 1L, notes = ""
  )

  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  r1 <- build_layer_b_results(
    stage4_dir = stage4_dir, selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg, out_dir = tempfile("lb_rep1_")
  )
  r2 <- build_layer_b_results(
    stage4_dir = stage4_dir, selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg, out_dir = tempfile("lb_rep2_")
  )

  expect_equal(r1$run_metadata$run_id, r2$run_metadata$run_id)

  # selection_resolved should be byte-equal
  s1 <- readr::read_csv(file.path(r1$dir, "selection_resolved.csv"), show_col_types = FALSE)
  s2 <- readr::read_csv(file.path(r2$dir, "selection_resolved.csv"), show_col_types = FALSE)
  expect_equal(s1, s2)
})
