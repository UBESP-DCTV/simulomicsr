test_that("render_stage4_dashboard skip gracefully se quarto non disponibile", {
  skip_if(requireNamespace("quarto", quietly = TRUE),
          "quarto installato; questo test verifica solo fallback path")

  expect_warning(
    res <- render_stage4_dashboard(s4_dir = tempdir(), out_path = tempfile()),
    "quarto"
  )
  expect_null(res)
})

test_that("render_stage4_dashboard usa template default se quarto disponibile", {
  skip_if_not_installed("quarto")
  skip_on_ci()

  tmp <- withr::local_tempdir()
  s4 <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                     qc_drops_study = tibble::tibble(),
                     qc_drops_cluster = tibble::tibble(),
                     pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "test1234",
                        timestamp = "2026-05-19T12:00:00Z")
  )
  write_stage4_to_dir(s4, tmp)

  out_path <- file.path(tmp, "dashboard.html")
  result <- render_stage4_dashboard(s4_dir = tmp, out_path = out_path)

  expect_true(file.exists(out_path))
})
