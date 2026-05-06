test_that("extract_batch(submit = FALSE) returns a preflight plan without remote calls", {
  config <- local_test_config()

  plan <- laimsdgxllm::extract_batch(
    records = sample_records(),
    id_col = "id",
    text_col = "text",
    prompt_template = "Extract structured data.",
    schema = sample_schema(),
    model = "20B",
    submit = FALSE,
    config = config,
    metadata = list(project = "Dry Run")
  )

  expect_s3_class(plan, "laims_dgx_submit_plan")
  expect_false(plan$submit)
  expect_identical(plan$model, "20B")
  expect_identical(plan$bundle$state, "created")
  expect_identical(plan$bundle$slug, "dry-run")
  expect_true(file.exists(plan$local_script_path))

  status <- laimsdgxllm::job_status(plan$run_id, refresh = FALSE, config = config)
  expect_s3_class(status, "laims_dgx_status")
  expect_identical(status$state, "created")
  expect_identical(status$progress$total_records, 3L)
})

test_that("extract_batch(bundle = existing_bundle, submit = FALSE) reuses the bundle", {
  config <- local_test_config(runtime_mode = "external", sif_path = "/containers/reuse.sif")
  bundle <- create_test_bundle(config = config, metadata = list(project = "Bundle Reuse"), model = "120B")

  plan <- laimsdgxllm::extract_batch(
    bundle = bundle,
    submit = FALSE,
    config = config
  )

  expect_s3_class(plan, "laims_dgx_submit_plan")
  expect_identical(plan$run_id, bundle$run_id)
  expect_identical(plan$model, "120B")
  expect_identical(plan$bundle$bundle_dir, bundle$bundle_dir)
  expect_identical(plan$sif_path, "/containers/reuse.sif")
  expect_identical(plan$sif_path_source, "config")
})

test_that("extract_batch rejects mixed bundle and raw inputs", {
  config <- local_test_config()
  bundle <- create_test_bundle(config = config)

  expect_error(
    laimsdgxllm::extract_batch(
      bundle = bundle,
      records = sample_records(),
      id_col = "id",
      text_col = "text",
      prompt_template = "Extract structured data.",
      schema = sample_schema(),
      model = "20B",
      submit = FALSE,
      config = config
    ),
    "either `bundle` or raw bundle-creation inputs"
  )
})
