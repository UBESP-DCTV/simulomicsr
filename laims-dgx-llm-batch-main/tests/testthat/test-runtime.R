test_that("managed runtime maps 20B and 120B to the canonical remote roots", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed"
  )

  spec_20 <- laimsdgxllm:::.local_runtime_spec(config, model = "20B")
  spec_120 <- laimsdgxllm:::.local_runtime_spec(config, model = "120B")

  expect_identical(spec_20$managed_id, "official-20b")
  expect_identical(spec_120$managed_id, "official-120b")
  expect_identical(spec_20$runtime_root, paste(config$runtime$root, "official-20b", sep = "/"))
  expect_identical(spec_120$runtime_root, paste(config$runtime$root, "official-120b", sep = "/"))
  expect_identical(spec_20$current_sif_path, paste(config$runtime$root, "official-20b/current.sif", sep = "/"))
  expect_identical(spec_120$current_sif_path, paste(config$runtime$root, "official-120b/current.sif", sep = "/"))
})

test_that("ensure_runtime validates explicit external sif override", {
  calls <- character()
  local_runtime_transport(responder = function(config, command) {
    calls <<- c(calls, command)
    list(ok = TRUE, status = 0L, stdout = "", stderr = "")
  })

  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed"
  )

  runtime <- laimsdgxllm::ensure_runtime(
    config = config,
    model = "120B",
    sif_path = "/shared/custom/runtime.sif"
  )

  expect_s3_class(runtime, "laims_dgx_runtime")
  expect_identical(runtime$model, "120B")
  expect_identical(runtime$mode, "external")
  expect_identical(runtime$source, "explicit")
  expect_true(runtime$ready)
  expect_identical(runtime$sif_path, "/shared/custom/runtime.sif")
  expect_true(any(grepl("/shared/custom/runtime\\.sif", calls)))
})

test_that("ensure_runtime builds managed runtime when manifest is missing", {
  calls <- character()
  copied <- character()
  local_runtime_transport(
    responder = function(config, command) {
      calls <<- c(calls, command)

      if (grepl("echo manifest=0", command, fixed = TRUE)) {
        return(list(ok = TRUE, status = 0L, stdout = "manifest=0\ncurrent=0", stderr = ""))
      }

      list(ok = TRUE, status = 0L, stdout = "", stderr = "")
    },
    copier = function(config, local_dir, remote_dir) {
      copied <<- c(copied, remote_dir)
      list(ok = TRUE, status = 0L, stdout = "", stderr = "")
    }
  )

  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed",
    sif_path = ""
  )

  runtime <- laimsdgxllm::ensure_runtime(config = config, model = "120B")

  expect_s3_class(runtime, "laims_dgx_runtime")
  expect_identical(runtime$model, "120B")
  expect_identical(runtime$mode, "managed")
  expect_true(runtime$ready)
  expect_false(runtime$stale)
  expect_identical(runtime$action, "built")
  expect_identical(runtime$sif_path, paste(config$runtime$root, "official-120b/current.sif", sep = "/"))
  expect_length(copied, 1L)
  expect_true(any(grepl("official-120b", copied)))
  build_calls <- calls[grepl("build-runtime\\.sh", calls)]
  expect_true(length(build_calls) >= 1L)
  expect_true(any(grepl("LAIMS_RUNTIME_ASSET_HASH='[0-9a-f]+'", build_calls)))
  expect_false(any(grepl("LAIMS_RUNTIME_ASSET_HASH= '[0-9a-f]+'", build_calls)))
  expect_true(any(grepl("LAIMS_RUNTIME_BUILD_PREFERRED_BIN='apptainer'", build_calls, fixed = TRUE)))
  expect_true(any(grepl("LAIMS_RUNTIME_BUILD_FALLBACK_BIN='/cm/shared/apps/singularity/4.2.0/bin/singularity'", build_calls, fixed = TRUE)))
  expect_true(any(grepl("LAIMS_RUNTIME_BUILD_FALLBACK_ARGS='build --force --fakeroot'", build_calls, fixed = TRUE)))
  expect_false(any(grepl("LAIMS_RUNTIME_APPTAINER_BIN=", build_calls, fixed = TRUE)))
})

test_that("runtime build env prefers apptainer and only adds fakeroot for singularity fallback", {
  default_cfg <- local_test_config(login_user = "alice", runtime_mode = "managed", sif_path = "")
  default_env <- laimsdgxllm:::.runtime_build_env(default_cfg)

  expect_identical(default_env$preferred_bin, "apptainer")
  expect_identical(default_env$preferred_args, "build --force")
  expect_identical(default_env$fallback_bin, "/cm/shared/apps/singularity/4.2.0/bin/singularity")
  expect_identical(default_env$fallback_args, "build --force --fakeroot")

  apptainer_cfg <- default_cfg
  apptainer_cfg$apptainer_bin <- "/usr/bin/apptainer"
  apptainer_env <- laimsdgxllm:::.runtime_build_env(apptainer_cfg)

  expect_identical(apptainer_env$fallback_bin, "/usr/bin/apptainer")
  expect_identical(apptainer_env$fallback_args, "build --force")
})

test_that("ensure_runtime dry-run reports stale managed runtime honestly", {
  local_runtime_transport(responder = function(config, command) {
    if (grepl("echo manifest=0", command, fixed = TRUE)) {
      return(list(ok = TRUE, status = 0L, stdout = "manifest=0\ncurrent=0", stderr = ""))
    }

    list(ok = TRUE, status = 0L, stdout = "", stderr = "")
  })

  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed",
    sif_path = ""
  )

  runtime <- laimsdgxllm::ensure_runtime(config = config, model = "20B", dry_run = TRUE)

  expect_identical(runtime$model, "20B")
  expect_false(runtime$ready)
  expect_true(runtime$stale)
  expect_identical(runtime$action, "ensure_required")
  expect_identical(runtime$sif_path, paste(config$runtime$root, "official-20b/current.sif", sep = "/"))
})

test_that("ensure_runtime fails clearly when the SSH key is missing", {
  config <- local_test_config(
    login_user = "alice",
    ssh_key_path = fs::path(tempdir(), "missing-alice.key"),
    runtime_mode = "managed",
    sif_path = ""
  )

  expect_error(
    laimsdgxllm::ensure_runtime(config = config, model = "20B"),
    "SSH key file was not found|ssh_key_path|DGX admin"
  )
})

test_that("managed runtime assets expose the first-pass engine contract", {
  assets_dir <- laimsdgxllm:::.package_file("runtime")
  expected <- c(
    "README.md",
    "build-runtime.sh",
    "runtime.def",
    "requirements.txt",
    "bin/run-batch",
    "python/laims_runtime/backend.py",
    "python/laims_runtime/io_utils.py",
    "python/laims_runtime/model_registry.py",
    "python/laims_runtime/run_batch.py"
  )

  for (rel in expected) {
    expect_true(file.exists(file.path(assets_dir, rel)), info = rel)
  }

  runtime_def <- paste(readLines(file.path(assets_dir, "runtime.def"), warn = FALSE), collapse = "\n")
  expect_match(runtime_def, "pytorch/pytorch")
  expect_match(runtime_def, "run-batch")
  expect_match(runtime_def, "chmod 0755 /opt/laims/runtime/bin/run-batch", fixed = TRUE)
  expect_match(runtime_def, "exec python /opt/laims/runtime/python/laims_runtime/run_batch.py", fixed = TRUE)
})

test_that("mock runtime runner processes a bundle and writes the contract files", {
  python_bin <- Sys.which("python3")
  if (identical(python_bin, "")) {
    python_bin <- Sys.which("python")
  }
  skip_if(identical(python_bin, ""), "Python interpreter not available")

  config <- local_test_config(login_user = "alice", runtime_mode = "managed", sif_path = "")
  bundle <- create_test_bundle(config = config, model = "20B")
  output_dir <- fs::path(tempdir(), paste0("laims-runtime-output-", Sys.getpid(), "-", sample.int(1e6, 1)))
  status_path <- fs::path(tempdir(), paste0("laims-runtime-status-", Sys.getpid(), "-", sample.int(1e6, 1)), "status.json")
  script_path <- laimsdgxllm:::.package_file("runtime", "python", "laims_runtime", "run_batch.py")
  runtime_python <- dirname(dirname(script_path))

  result <- processx::run(
    command = python_bin,
    args = c(
      script_path,
      "--bundle", bundle$bundle_dir,
      "--output", output_dir,
      "--status-path", status_path
    ),
    env = c(
      PYTHONPATH = runtime_python,
      LAIMS_RUNTIME_BACKEND = "mock",
      LAIMS_RUNTIME_MOCK_JSON = "1",
      LAIMS_RUNTIME_FAIL_RECORD_IDS = "r2"
    ),
    error_on_status = FALSE,
    echo = FALSE
  )

  expect_identical(result$status, 0L)
  expect_true(file.exists(status_path))
  expect_true(file.exists(fs::path(output_dir, "predictions.jsonl")))
  expect_true(file.exists(fs::path(output_dir, "errors.jsonl")))
  expect_true(file.exists(fs::path(output_dir, "run_summary.json")))

  status <- jsonlite::read_json(status_path, simplifyVector = TRUE)
  summary <- jsonlite::read_json(fs::path(output_dir, "run_summary.json"), simplifyVector = TRUE)
  predictions <- readLines(fs::path(output_dir, "predictions.jsonl"), warn = FALSE)
  errors <- readLines(fs::path(output_dir, "errors.jsonl"), warn = FALSE)

  expect_identical(status$state, "completed_with_errors")
  expect_identical(status$records$completed, 2L)
  expect_identical(status$records$failed, 1L)
  expect_identical(status$chunks$completed, bundle$manifest$chunk_count)
  expect_identical(summary$state, "completed_with_errors")
  expect_identical(summary$backend, "mock")
  expect_length(predictions, 2L)
  expect_length(errors, 1L)
})
