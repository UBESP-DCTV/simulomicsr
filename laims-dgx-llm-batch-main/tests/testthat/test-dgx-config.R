test_that("dgx_config bootstraps state and registry", {
  skip_if_not_installed("checkmate")

  config <- local_test_config()

  checkmate::assert_class(config, "laims_dgx_config")
  checkmate::assert_directory_exists(config$state_dir)
  checkmate::assert_directory_exists(config$results_dir)
  checkmate::assert_file_exists(config$registry_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), config$registry_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  expect_true(DBI::dbExistsTable(con, "runs"))
  expect_true(DBI::dbExistsTable(con, "run_events"))
  expect_identical(
    DBI::dbGetQuery(con, "SELECT value FROM metadata WHERE key = 'schema_version'")$value[[1]],
    "2"
  )
})

test_that("dgx_config defaults to managed runtime and can store external sif/mail config", {
  default_cfg <- local_test_config()
  expect_identical(default_cfg$runtime_mode, "managed")
  expect_identical(default_cfg$mail_user, "")

  explicit <- local_test_config(
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif",
    mail_user = "alice@example.org"
  )
  expect_identical(explicit$sif_path, "/containers/from-config.sif")
  expect_identical(explicit$runtime_mode, "external")
  expect_identical(explicit$mail_user, "alice@example.org")
  expect_identical(explicit$job_resources$mail_user, "alice@example.org")

  withr::local_envvar(
    LAIMS_DGX_SIF_PATH = "/containers/from-env.sif",
    LAIMS_DGX_RUNTIME_MODE = "external",
    LAIMS_DGX_MAIL_USER = "env@example.org"
  )
  env_cfg <- laimsdgxllm::dgx_config(state_dir = test_state_dir())
  withr::defer(unlink(env_cfg$state_dir, recursive = TRUE, force = TRUE), testthat::teardown_env())

  expect_identical(env_cfg$sif_path, "/containers/from-env.sif")
  expect_identical(env_cfg$runtime_mode, "external")
  expect_identical(env_cfg$mail_user, "env@example.org")
})

test_that("dgx_config hardcodes the DGX host and derives SSH defaults cleanly", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed",
    sif_path = "",
    cpus = 8,
    mem = "64G"
  )

  expect_identical(config$login_host, "logindgx.hpc.ict.unipd.it")
  expect_identical(config$login_user, "alice")
  expect_match(config$ssh_key_path, "alice\\.key$")
  expect_identical(config$ssh_key_source, "explicit")
  expect_true(config$ssh_key_exists)
  expect_identical(config$user_root, "/mnt/projects/dctv/dgx/alice")
  expect_identical(config$remote_base_dir, "/mnt/projects/dctv/dgx/alice/runs")
  expect_identical(config$runtime_mode, "managed")
  expect_identical(config$runtime$root, "/mnt/projects/dctv/dgx/alice/runtime")
  expect_identical(config$apptainer_bin, "/cm/shared/apps/singularity/4.2.0/bin/singularity")
  expect_identical(config$hardware$gpu_type, "H100")
  expect_identical(config$hardware$gpu_vram_gb, 80L)
  expect_identical(config$hardware$total_vram_gb, 80L)
  expect_identical(config$job_resources$gpus, 1L)
  expect_identical(config$job_resources$cpus, 8L)
  expect_identical(config$job_resources$mem, "64G")
  expect_identical(config$job_resources$partition, "dgx12cluster")
  expect_identical(config$job_resources$account, "dctv_dgx")
  expect_identical(config$job_resources$nodelist, "poddgx02")
  expect_identical(config$job_resources$nodes, 1L)
})

test_that("dgx_config rejects non-default node counts", {
  expect_error(
    local_test_config(nodes = 2),
    "fixed to 1|single DGX node"
  )
})

test_that("dgx_config derives the default SSH key path from login_user", {
  withr::local_tempdir()
  fake_home <- fs::path(tempdir(), paste0("fake-home-", sample.int(1e6, 1)))
  fs::dir_create(fs::path(fake_home, ".ssh"))
  withr::local_envvar(HOME = fake_home)

  config <- laimsdgxllm::dgx_config(
    login_user = "alice",
    state_dir = test_state_dir()
  )
  withr::defer(unlink(config$state_dir, recursive = TRUE, force = TRUE), testthat::teardown_env())

  expect_identical(as.character(config$ssh_key_path), as.character(fs::path(fake_home, ".ssh", "alice.key")))
  expect_identical(config$ssh_key_source, "derived")
  expect_false(config$ssh_key_exists)
})

test_that("dgx_config derives remote_base_dir from user_root when needed", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed",
    user_root = "/remote/alice/work",
    remote_base_dir = ""
  )

  expect_identical(config$user_root, "/remote/alice/work")
  expect_identical(config$remote_base_dir, "/remote/alice/work/runs")
})

test_that("dgx_config derives the shared-storage root from login_user by default", {
  config <- local_test_config(
    login_user = "u0043",
    runtime_mode = "managed",
    sif_path = "",
    remote_base_dir = ""
  )

  expect_identical(config$user_root, "/mnt/projects/dctv/dgx/u0043")
  expect_identical(config$remote_base_dir, "/mnt/projects/dctv/dgx/u0043/runs")
  expect_identical(config$runtime$root, "/mnt/projects/dctv/dgx/u0043/runtime")
})


test_that("dgx_config validates mail_user when provided", {
  expect_error(
    local_test_config(mail_user = "not-an-email"),
    "mail_user.*email"
  )
})
