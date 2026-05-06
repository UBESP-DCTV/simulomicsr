test_that("collect_results can mark locally available completed artifacts as collected", {
  config <- local_test_config()
  bundle <- create_test_bundle(config = config)

  plan <- laimsdgxllm::submit_job(
    bundle = bundle,
    submit = FALSE,
    config = config
  )

  laimsdgxllm::: .registry_upsert_run(
    list(
      run_id = bundle$run_id,
      state = "completed",
      state_source = "test",
      local_run_dir = bundle$bundle_dir,
      remote_run_dir = plan$remote_run_dir,
      remote_status_path = plan$remote_status_path,
      remote_predictions_path = plan$remote_predictions_path,
      remote_errors_path = plan$remote_errors_path,
      remote_summary_path = plan$remote_summary_path
    ),
    config = config
  )

  local_dir <- fs::path(config$results_dir, bundle$run_id)
  fs::dir_create(local_dir)
  jsonlite::write_json(list(run_id = bundle$run_id, state = "completed"), fs::path(local_dir, "status.json"), auto_unbox = TRUE)
  writeLines('{"id":"r1","label":"ok"}', fs::path(local_dir, "predictions.jsonl"))
  writeLines(character(), fs::path(local_dir, "errors.jsonl"))
  jsonlite::write_json(list(run_id = bundle$run_id, state = "completed"), fs::path(local_dir, "run_summary.json"), auto_unbox = TRUE)

  results <- laimsdgxllm::collect_results(bundle$run_id, local_dir = local_dir, config = config)

  expect_s3_class(results, "laims_dgx_results")
  expect_identical(results$state, "collected")
  expect_true(all(results$exists[c("status", "predictions", "errors", "summary")]))

  row <- laimsdgxllm:::.registry_get_run(bundle$run_id, config)
  expect_identical(row$state[[1]], "collected")
  expect_identical(fs::path_abs(row$local_results_dir[[1]]), fs::path_abs(local_dir))
})
