test_that("ssh_capture wraps remote commands in bash login shell mode", {
  ssh_log <- fs::path(tempdir(), paste0("laimsdgxllm-ssh-log-", Sys.getpid(), "-", sample.int(1e6, 1), ".txt"))
  ssh_bin <- fs::path(tempdir(), paste0("laimsdgxllm-fake-ssh-", Sys.getpid(), "-", sample.int(1e6, 1), ".sh"))

  writeLines(
    c(
      "#!/bin/sh",
      sprintf("for arg in \"$@\"; do printf '%s\\n' \"$arg\"; done > %s", "%s", shQuote(ssh_log)),
      "printf 'remote-ok'"
    ),
    ssh_bin
  )
  Sys.chmod(ssh_bin, mode = "700")
  withr::defer(unlink(c(ssh_bin, ssh_log), force = TRUE), testthat::teardown_env())

  config <- local_test_config(login_user = "alice", runtime_mode = "external", sif_path = "/containers/from-config.sif")
  config$ssh_bin <- ssh_bin

  command <- "printf '%s\\n' \"alpha beta\""
  result <- laimsdgxllm:::.ssh_capture(config, command)

  expect_true(result$ok)
  expect_identical(result$stdout, "remote-ok")

  args <- readLines(ssh_log, warn = FALSE)
  expect_true(length(args) >= 2L)
  expect_identical(args[[length(args) - 1L]], laimsdgxllm:::.ssh_destination(config))
  expect_identical(args[[length(args)]], laimsdgxllm:::.ssh_login_shell_command(command))
})

test_that("submit plan preview shows bash login shell submission command", {
  config <- local_test_config(login_user = "alice", runtime_mode = "external", sif_path = "/containers/from-config.sif")
  bundle <- create_test_bundle(config = config)

  plan <- laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, config = config)

  expect_match(plan$submit_command, "bash -lc")
  expect_match(plan$submit_command, "sbatch submit_slurm\\.sh")
})
