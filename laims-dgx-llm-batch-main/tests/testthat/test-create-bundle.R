test_that("create_bundle writes bundle artifacts and registry metadata", {
  skip_if_not_installed("checkmate")

  config <- local_test_config()
  bundle <- create_test_bundle(config = config, metadata = list(project = "Alpha Study"))

  checkmate::assert_class(bundle, "laims_dgx_bundle")
  checkmate::assert_directory_exists(bundle$bundle_dir)
  expect_match(bundle$run_id, "^run-")
  expect_identical(bundle$state, "created")
  expect_identical(bundle$slug, "alpha-study")
  expect_identical(bundle$model, "20B")

  expected_files <- c(
    "records.jsonl",
    "prompt.txt",
    "schema.json",
    "generation.json",
    "manifest.json",
    "run_meta.json",
    "chunk_plan.jsonl",
    "status.json"
  )
  expect_true(all(file.exists(fs::path(bundle$bundle_dir, expected_files))))

  manifest <- jsonlite::read_json(bundle$files$manifest, simplifyVector = FALSE)
  status <- jsonlite::read_json(bundle$files$status, simplifyVector = FALSE)
  chunk_lines <- readLines(bundle$files$chunk_plan, warn = FALSE)

  expect_identical(manifest$record_count, 3L)
  expect_identical(manifest$model, "20B")
  expect_identical(manifest$model_profile, "20B")
  expect_identical(status$state, "created")
  expect_length(chunk_lines, bundle$manifest$chunk_count)

  jobs <- laimsdgxllm::jobs_list(config = config)
  expect_equal(nrow(jobs), 1)
  expect_identical(jobs$run_id[[1]], bundle$run_id)
  expect_identical(jobs$state[[1]], "created")
  expect_identical(jobs$total_records[[1]], 3L)

  recovered <- laimsdgxllm::recover_job(bundle$run_id, config = config)
  checkmate::assert_class(recovered, "laims_dgx_job")
  expect_identical(recovered$run_id, bundle$run_id)
})
