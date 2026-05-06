# Mock helper per simulare processx::run senza chiamare ssh/rsync veri.
# Usa testthat::local_mocked_bindings (disponibile in testthat >= 3.1.2;
# withr::local_mocked_bindings e' disponibile solo da withr >= 3.1.0).
local_mock_processx <- function(stdout = "", stderr = "", status = 0L,
                                env = parent.frame()) {
  fake <- function(command, args = NULL, ...) {
    list(stdout = stdout, stderr = stderr, status = status)
  }
  testthat::local_mocked_bindings(run = fake, .package = "processx", .env = env)
}

test_that("dgx_p4_submit() costruisce e rendera SLURM script + sbatch", {
  skip_if_not_installed("withr")
  cfg <- dgx_config()
  td <- withr::local_tempdir()

  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1",
    config = cfg,
    bundle_dir_root = td
  )

  # Mock: rsync ritorna 0, ssh sbatch ritorna "Submitted batch job 123456"
  local_mock_processx(stdout = "Submitted batch job 123456\n", status = 0L)

  job <- dgx_p4_submit(bundle, time = "12:00:00", config = cfg, dry_run = FALSE)

  expect_s3_class(job, "simulomicsr_dgx_job")
  expect_identical(job$run_id, bundle$run_id)
  expect_identical(job$slurm_job_id, "123456")
  expect_identical(job$stage, "stage1")
})

test_that("dgx_p4_submit() dry_run produce slurm script ma non chiama ssh", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1",
    config = cfg,
    bundle_dir_root = td
  )

  job <- dgx_p4_submit(bundle, time = "12:00:00", config = cfg, dry_run = TRUE)

  expect_s3_class(job, "simulomicsr_dgx_job")
  expect_identical(job$slurm_job_id, NA_character_)
  expect_true(fs::file_exists(fs::path(bundle$bundle_dir, "run_p4.rendered.sh")))
  rendered <- readLines(fs::path(bundle$bundle_dir, "run_p4.rendered.sh"))
  expect_true(any(grepl("--time=12:00:00", rendered, fixed = TRUE)))
  expect_true(any(grepl("dctv_dgx", rendered, fixed = TRUE)))
  expect_false(any(grepl("__[A-Z_]+__", rendered)))
})

test_that("dgx_p4_submit() abort se sbatch parse non trova job id", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1",
    config = cfg,
    bundle_dir_root = td
  )

  local_mock_processx(stdout = "weird unexpected output", status = 0L)

  expect_error(
    dgx_p4_submit(bundle, time = "12:00:00", config = cfg),
    class = "simulomicsr_dgx_sbatch_parse_failed"
  )
})

test_that("dgx_p4_status() ritorna struttura con campi required", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1", config = cfg, bundle_dir_root = td
  )
  job <- structure(
    list(run_id = bundle$run_id, slurm_job_id = "999",
         stage = "stage1", bundle_dir = bundle$bundle_dir,
         submitted_at = "2026-05-07T09:00:00Z", config = cfg),
    class = "simulomicsr_dgx_job"
  )

  # Mock: squeue ritorna RUNNING, status.json scaricato (simuliamo con local file)
  local_mock_processx(
    stdout = "RUNNING\n",
    status = 0L
  )

  st <- dgx_p4_status(job, fetch_status_json = FALSE)
  expect_named(st, c("slurm_state", "remote_status_present", "snapshot"),
               ignore.order = TRUE)
  expect_identical(st$slurm_state, "RUNNING")
})

test_that("dgx_p4_recover() ricostruisce job da bundle locale", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1", config = cfg, bundle_dir_root = td
  )

  job <- dgx_p4_recover(run_id = bundle$run_id,
                       config = cfg,
                       bundle_dir_root = td)
  expect_s3_class(job, "simulomicsr_dgx_job")
  expect_identical(job$run_id, bundle$run_id)
  expect_true(is.na(job$slurm_job_id))
})

test_that("dgx_p4_collect() rsync e parse roundtrip (mocked)", {
  skip_if_not_installed("withr")
  cfg <- dgx_config()
  td <- withr::local_tempdir()

  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1", config = cfg, bundle_dir_root = td
  )
  dest_root <- fs::path(td, "p4-output")
  fs::dir_create(dest_root)

  # Pre-popoliamo manualmente la dir di destinazione come se rsync l'avesse
  # gia' fatto (evitiamo di mockare il filesystem completo).
  dst_run <- fs::path(dest_root, bundle$run_id)
  fs::dir_create(dst_run)
  writeLines(c(
    '{"record_id":"GSM1009636","raw_output":"{\\"x\\":1}","parsed_json":{"x":1},"valid_schema":true,"worker_id":0,"ts":"2026-05-07T09:00:00Z"}',
    '{"record_id":"GSM1009637","raw_output":"bad","parsed_json":null,"valid_schema":false,"worker_id":0,"ts":"2026-05-07T09:00:01Z"}'
  ), fs::path(dst_run, "predictions.jsonl"))
  jsonlite::write_json(
    list(run_id = bundle$run_id, model_id = "mistral", stage = "stage1",
         records_total = 2, records_completed_total = 1, records_failed_schema = 1),
    fs::path(dst_run, "run_summary.json"), auto_unbox = TRUE)

  # Mock rsync no-op (la dir e' gia' popolata)
  local_mock_processx(stdout = "", status = 0L)

  job <- structure(
    list(run_id = bundle$run_id, slurm_job_id = "999",
         stage = "stage1", bundle_dir = bundle$bundle_dir,
         submitted_at = "2026-05-07T09:00:00Z", config = cfg),
    class = "simulomicsr_dgx_job"
  )

  res <- dgx_p4_collect(job, dest = dest_root)
  expect_named(res, c("predictions", "errors", "summary", "run_dir"),
               ignore.order = TRUE)
  expect_s3_class(res$predictions, "data.frame")
  expect_identical(nrow(res$predictions), 1L)
  expect_identical(nrow(res$errors), 1L)
})
