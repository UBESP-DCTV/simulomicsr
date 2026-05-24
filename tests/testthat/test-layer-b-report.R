test_that("render_layer_b_report produces HTML standalone", {
  skip_if_not_installed("quarto")
  skip_if(Sys.which("quarto") == "")

  # Create a minimal layer_b dir
  d <- tempfile("lb_rep_")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))

  sel <- tibble::tibble(
    cluster_id = "cl_test", label_paper = "Test", priority = 1L, notes = "",
    exists_in_stage4 = TRUE, method = "mega", k_effective = 5L, n_sig_FDR05 = 10L
  )
  readr::write_csv(sel, file.path(d, "selection_resolved.csv"))

  meta <- list(run_id = "rep01234", timestamp = "2026-05-24T00:00:00Z",
               package_version = "0.0.0.9020", config = list())
  jsonlite::write_json(meta, file.path(d, "run_metadata.json"), auto_unbox = TRUE)

  cl_dir <- file.path(d, "cl_test"); dir.create(cl_dir)
  writeLines("# Test summary", file.path(cl_dir, "summary_card.md"))
  writeLines("# Test narrative\n_TODO_", file.path(cl_dir, "narrative.qmd"))
  jsonlite::write_json(list(volcano = "test caption"), file.path(cl_dir, "captions.json"),
                       auto_unbox = TRUE)

  lb <- load_layer_b(d)
  out_html <- file.path(d, "layer_b_report.html")

  result <- render_layer_b_report(lb, out_html)
  expect_true(file.exists(out_html))
  expect_gt(file.info(out_html)$size, 1000L)
})
