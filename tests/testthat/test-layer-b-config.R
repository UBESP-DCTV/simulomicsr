test_that("layer_b_default_config returns expected schema", {
  config <- layer_b_default_config()

  # Top-level keys
  expect_named(
    config,
    c("top_n_forest", "top_n_heatmap", "top_n_table", "top_n_volcano_labels",
      "fdr_threshold", "palette", "language", "heatmap_normalize",
      "go_enrichment", "save_svg", "dpi", "min_genes_for_go_ora",
      "max_heatmap_samples", "top_genes_min_k_frac"),
    ignore.order = TRUE
  )

  # Default values (consolidati nel brainstorming)
  expect_equal(config$top_n_forest, 10L)
  expect_equal(config$top_n_heatmap, 30L)
  expect_equal(config$top_n_table, 30L)
  expect_equal(config$top_n_volcano_labels, 15L)
  expect_equal(config$fdr_threshold, 0.05)
  expect_equal(config$palette, "viridis")
  expect_equal(config$language, "en")
  expect_true(config$heatmap_normalize)
  expect_true(config$go_enrichment)
  expect_true(config$save_svg)
  expect_equal(config$dpi, 300L)
  expect_equal(config$min_genes_for_go_ora, 200L)
  expect_equal(config$max_heatmap_samples, 100L)
})

test_that("layer_b_default_config returns plain list (serializable to JSON)", {
  config <- layer_b_default_config()
  json <- jsonlite::toJSON(config, auto_unbox = TRUE)
  parsed <- jsonlite::fromJSON(json)
  expect_equal(parsed$top_n_forest, 10L)
  expect_equal(parsed$fdr_threshold, 0.05)
})
