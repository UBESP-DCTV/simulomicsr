test_that("write_layer_b_to_dir + load_layer_b round-trip", {
  # Build a minimal layer_b_result object
  lb <- structure(
    list(
      cluster_bundles = list(
        cl_a = list(
          cluster_id = "cl_a",
          plots = list(
            volcano = list(png_path = "cl_a/volcano.png", svg_path = "cl_a/volcano.svg", caption = "volcano A"),
            ma = list(png_path = "cl_a/ma.png", svg_path = "cl_a/ma.svg", caption = "ma A")
          ),
          summary_card_path = "cl_a/summary_card.md",
          narrative_path = "cl_a/narrative.qmd"
        )
      ),
      selection_resolved = tibble::tibble(
        cluster_id = "cl_a", label_paper = "A", priority = 1L, notes = "",
        exists_in_stage4 = TRUE, method = "mega", k_effective = 5L, n_sig_FDR05 = 10L
      ),
      run_metadata = list(
        run_id = "abcd1234",
        timestamp = "2026-05-24T12:00:00Z",
        config = layer_b_default_config(),
        schema_versions = list(layer_b_algorithm = "v1")
      )
    ),
    class = "layer_b_result"
  )

  d <- tempfile("lb_write_")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))

  # Create the per-cluster dir + dummy files so write_layer_b_to_dir succeeds
  dir.create(file.path(d, "cl_a"))
  file.create(file.path(d, "cl_a", "volcano.png"))
  file.create(file.path(d, "cl_a", "summary_card.md"))
  file.create(file.path(d, "cl_a", "narrative.qmd"))

  write_layer_b_to_dir(lb, d)

  expect_true(file.exists(file.path(d, "selection_resolved.csv")))
  expect_true(file.exists(file.path(d, "run_metadata.json")))

  lb2 <- load_layer_b(d)
  expect_s3_class(lb2, "layer_b_result")
  expect_equal(lb2$run_metadata$run_id, "abcd1234")
  expect_equal(nrow(lb2$selection_resolved), 1L)
})
