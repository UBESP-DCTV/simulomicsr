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
