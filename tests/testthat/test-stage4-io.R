test_that("write_stage4_to_dir produce i 5 file attesi", {
  skip_if_not_installed("arrow")

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
    run_metadata = list(run_id = "abc12345", timestamp = Sys.time())
  )

  paths <- write_stage4_to_dir(s4, tmp)

  expect_true(file.exists(file.path(tmp, "per_study_de.parquet")))
  expect_true(file.exists(file.path(tmp, "cluster_pooled.parquet")))
  expect_true(file.exists(file.path(tmp, "qc_report.rds")))
  expect_true(file.exists(file.path(tmp, "non_processable.rds")))
  expect_true(file.exists(file.path(tmp, "run_metadata.json")))
})

test_that("load_stage4 round-trip preserva contenuto", {
  skip_if_not_installed("arrow")

  tmp <- withr::local_tempdir()
  s4_orig <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "test1234", timestamp = "2026-05-19T12:00:00Z")
  )

  write_stage4_to_dir(s4_orig, tmp)
  s4_back <- load_stage4(tmp)

  expect_equal(s4_back$run_metadata$run_id, "test1234")
  expect_equal(s4_back$config$qc$lib_size_min, 500000L)
})
