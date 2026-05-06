test_that("submit_job(submit = FALSE) renders a dry-run submission plan", {
  skip_if_not_installed("checkmate")

  config <- local_test_config(login_user = "alice", mail_user = "config@example.org")
  bundle <- create_test_bundle(config = config, model = "120B")

  plan <- laimsdgxllm::submit_job(
    bundle = bundle,
    submit = FALSE,
    sif_path = "/containers/llm.sif",
    slurm = list(partition = "gpu-a100", nodelist = "poddgx99", mail_user = "alice@example.org"),
    config = config
  )

  checkmate::assert_class(plan, "laims_dgx_submit_plan")
  checkmate::assert_file_exists(plan$local_script_path)
  expect_identical(plan$run_id, bundle$run_id)
  expect_identical(plan$model, "120B")
  expect_identical(plan$submit, FALSE)
  expect_identical(plan$remote_run_dir, paste(config$remote_base_dir, bundle$run_id, sep = "/"))
  expect_identical(plan$remote_bundle_dir, paste(plan$remote_run_dir, "bundle", sep = "/"))
  expect_identical(plan$remote_output_dir, paste(plan$remote_run_dir, "output", sep = "/"))
  expect_identical(plan$remote_home_dir, paste(config$user_root, "runtime/home", sep = "/"))
  expect_identical(plan$remote_hf_cache_dir, paste(config$user_root, "runtime/cache/huggingface", sep = "/"))
  expect_identical(plan$remote_slurm_stdout_path, paste(plan$remote_run_dir, "slurm-%j.out", sep = "/"))
  expect_identical(plan$remote_slurm_stderr_path, paste(plan$remote_run_dir, "slurm-%j.err", sep = "/"))
  expect_match(plan$submit_command, "alice@logindgx\\.hpc\\.ict\\.unipd\\.it")
  expect_match(plan$submit_command, "alice\\.key")
  expect_identical(plan$sif_path, "/containers/llm.sif")
  expect_identical(plan$sif_path_source, "explicit")
  expect_identical(plan$runtime_mode, "external")
  expect_false(plan$runtime_ready)
  expect_identical(plan$runtime_action, "validate_pending")

  script <- paste(readLines(plan$local_script_path, warn = FALSE), collapse = "\n")
  expect_match(script, "#SBATCH --partition=gpu-a100")
  expect_match(script, "#SBATCH --account=dctv_dgx")
  expect_match(script, "#SBATCH --nodelist=poddgx99")
  expect_match(script, "#SBATCH --nodes=1")
  expect_match(script, "#SBATCH --mail-user=alice@example\\.org")
  expect_match(script, "#SBATCH --mail-type=ALL")
  expect_match(script, "#SBATCH --gres=gpu:1")
  expect_match(script, "#SBATCH --ntasks=1")
  expect_match(script, "#SBATCH --cpus-per-task=4")
  expect_match(script, "#SBATCH --mem=32G")
  expect_match(script, paste0("#SBATCH --output=", plan$remote_run_dir, "/slurm-%j\\.out"))
  expect_match(script, paste0("#SBATCH --error=", plan$remote_run_dir, "/slurm-%j\\.err"))
  expect_match(script, "(^|\\n)module load singularity/4\\.2\\.0")
  expect_match(script, "(^|\\n)module load slurm/slurm/23\\.02\\.7")
  expect_match(script, "(^|\\n)srun /cm/shared/apps/singularity/4\\.2\\.0/bin/singularity exec")
  expect_match(script, "--nv")
  expect_match(script, "--pwd \"/home/alice\"")
  expect_match(script, "--env \"HF_HOME=/opt/laims/cache/huggingface,TRANSFORMERS_CACHE=/opt/laims/cache/huggingface\"")
  expect_no_match(script, '--env \"HOME=')
  expect_match(script, paste0("--bind \"", config$user_root, "/runtime/home:/home/alice\""))
  expect_match(script, paste0("--bind \"", plan$remote_run_dir, ":/work/run\""))
  expect_match(script, paste0("--bind \"", config$user_root, "/runtime/cache/huggingface:/opt/laims/cache/huggingface\""))
  expect_match(script, paste0("mkdir -p \"", config$user_root, "/runtime/home\""))
  expect_match(script, paste0("mkdir -p \"", config$user_root, "/runtime/cache/huggingface\""))
  expect_match(script, "/bin/sh /opt/laims/runtime/bin/run-batch")
  expect_no_match(script, "python /opt/laims/runtime/python/laims_runtime/run_batch\\.py")
  expect_match(script, "--status-path /work/run/status\\.json")
  expect_match(script, "/containers/llm\\.sif")

  row <- laimsdgxllm:::.registry_get_run(bundle$run_id, config)
  expect_equal(nrow(row), 1)
  expect_identical(row$state[[1]], "created")
})

test_that("submit_job(submit = FALSE) resolves sif_path from config", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif"
  )
  bundle <- create_test_bundle(config = config)

  plan <- laimsdgxllm::submit_job(
    bundle = bundle,
    submit = FALSE,
    config = config
  )

  expect_identical(plan$sif_path, "/containers/from-config.sif")
  expect_identical(plan$sif_path_source, "config")
  expect_identical(plan$runtime_mode, "external")

  script <- paste(readLines(plan$local_script_path, warn = FALSE), collapse = "\n")
  expect_match(script, "/containers/from-config\\.sif")
})

test_that("submit_job(submit = FALSE) reports managed runtime ensure requirement", {
  local_runtime_transport(responder = function(config, command) {
    if (grepl("echo manifest=0", command, fixed = TRUE)) {
      return(list(ok = TRUE, status = 0L, stdout = "manifest=0\ncurrent=0", stderr = ""))
    }

    list(ok = TRUE, status = 0L, stdout = "", stderr = "")
  })

  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed",
    sif_path = "",
    cpus = 12,
    mem = "96G"
  )
  bundle <- create_test_bundle(config = config, model = "120B")

  plan <- laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, config = config)

  expect_identical(plan$sif_path, paste(config$runtime$root, "official-120b/current.sif", sep = "/"))
  expect_identical(plan$sif_path_source, "managed")
  expect_identical(plan$runtime_mode, "managed")
  expect_false(plan$runtime_ready)
  expect_true(plan$runtime_stale)
  expect_identical(plan$runtime_action, "ensure_required")
  expect_identical(plan$slurm$gpus, 1L)
  expect_identical(plan$slurm$cpus, 12L)
  expect_identical(plan$slurm$mem, "96G")
  expect_identical(plan$slurm$partition, "dgx12cluster")
  expect_identical(plan$slurm$account, "dctv_dgx")
  expect_identical(plan$slurm$nodelist, "poddgx02")
  expect_identical(plan$slurm$nodes, 1L)
  expect_identical(plan$slurm$mail_user, "")
  expect_identical(plan$slurm$mail_type, "ALL")
  expect_identical(plan$slurm$time, "00:05:00")
})

test_that("submit_job(submit = FALSE) rejects non-default GPU overrides", {
  config <- local_test_config(login_user = "alice", runtime_mode = "external", sif_path = "/containers/from-config.sif")
  bundle <- create_test_bundle(config = config)

  expect_error(
    laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, slurm = list(gpus = 2), config = config),
    "fixed to 1"
  )
})

test_that("submit_job(submit = FALSE) rejects non-default node-count overrides", {
  config <- local_test_config(login_user = "alice", runtime_mode = "external", sif_path = "/containers/from-config.sif")
  bundle <- create_test_bundle(config = config)

  expect_error(
    laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, slurm = list(nodes = 2), config = config),
    "fixed to 1|single DGX node"
  )
})

test_that("submit_job(submit = FALSE) reuses managed runtime when current", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "managed",
    sif_path = ""
  )
  asset_hash <- laimsdgxllm:::.local_runtime_spec(config, model = "20B")$asset_hash
  manifest_json <- jsonlite::toJSON(
    list(
      model = "20B",
      asset_hash = asset_hash,
      current_sif_path = paste(config$runtime$root, "official-20b/current.sif", sep = "/")
    ),
    auto_unbox = TRUE
  )

  local_runtime_transport(responder = function(config, command) {
    if (grepl("echo manifest=0", command, fixed = TRUE)) {
      return(list(ok = TRUE, status = 0L, stdout = "manifest=1\ncurrent=1", stderr = ""))
    }
    if (grepl(paste0("cat '", config$runtime$root, "/official-20b/manifest.json'"), command, fixed = TRUE)) {
      return(list(ok = TRUE, status = 0L, stdout = manifest_json, stderr = ""))
    }

    list(ok = TRUE, status = 0L, stdout = "", stderr = "")
  })

  bundle <- create_test_bundle(config = config, model = "20B")
  plan <- laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, config = config)

  expect_true(plan$runtime_ready)
  expect_false(plan$runtime_stale)
  expect_identical(plan$runtime_action, "reuse")
  expect_identical(plan$sif_path, paste(config$runtime$root, "official-20b/current.sif", sep = "/"))
})

test_that("submit_job(submit = FALSE) accepts a bundle directory path", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif"
  )
  bundle <- create_test_bundle(config = config)

  plan <- laimsdgxllm::submit_job(bundle = bundle$bundle_dir, submit = FALSE, config = config)

  expect_identical(plan$run_id, bundle$run_id)
  expect_identical(plan$bundle_dir, bundle$bundle_dir)
  expect_identical(plan$sif_path, "/containers/from-config.sif")
})

test_that("submit_job(submit = TRUE) fails clearly when the SSH key is missing", {
  config <- local_test_config(
    login_user = "alice",
    ssh_key_path = fs::path(tempdir(), "missing-alice.key"),
    sif_path = "/containers/from-config.sif"
  )
  bundle <- create_test_bundle(config = config)

  expect_error(
    laimsdgxllm::submit_job(bundle = bundle, submit = TRUE, config = config),
    "SSH key file was not found|ssh_key_path|DGX admin"
  )
})

test_that("submit_job(submit = FALSE) keeps hardened SLURM defaults when not overridden", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif"
  )
  bundle <- create_test_bundle(config = config, model = "20B")

  plan <- laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, config = config)

  expect_identical(plan$remote_run_dir, paste("/mnt/projects/dctv/dgx/alice/runs", bundle$run_id, sep = "/"))
  expect_identical(plan$slurm$partition, "dgx12cluster")
  expect_identical(plan$slurm$account, "dctv_dgx")
  expect_identical(plan$slurm$nodelist, "poddgx02")
  expect_identical(plan$slurm$nodes, 1L)
  expect_identical(plan$slurm$mail_user, "")
  expect_identical(plan$slurm$mail_type, "ALL")
  expect_identical(plan$slurm$time, "00:05:00")
})

test_that("submit_job(submit = FALSE) surfaces heuristic time warnings for clearly too-small requests", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif"
  )
  long_records <- data.frame(
    id = sprintf("r%03d", seq_len(60)),
    text = rep(strrep("Long clinical note segment ", 800), 60),
    stringsAsFactors = FALSE
  )
  bundle <- laimsdgxllm::create_bundle(
    records = long_records,
    id_col = "id",
    text_col = "text",
    prompt_template = "Extract a compact JSON summary.",
    schema = sample_schema(),
    model = "120B",
    config = config
  )

  expect_warning(
    plan <- laimsdgxllm::submit_job(
      bundle = bundle,
      submit = FALSE,
      slurm = list(time = "00:05:00"),
      config = config
    ),
    "time preflight"
  )

  expect_identical(plan$time_preflight$status, "too_low")
  expect_true(length(plan$time_preflight$warnings) > 0L)
  expect_true(plan$time_preflight$estimated_seconds > plan$time_preflight$requested_seconds)
  expect_match(plan$time_preflight$suggested_time, "^[0-9]{2,}:[0-9]{2}:[0-9]{2}$")
})


test_that("submit_job(submit = FALSE) inherits mail_user from dgx_config unless overridden", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif",
    mail_user = "config@example.org"
  )
  bundle <- create_test_bundle(config = config)

  inherited <- laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, config = config)
  inherited_script <- paste(readLines(inherited$local_script_path, warn = FALSE), collapse = "\n")
  expect_identical(inherited$slurm$mail_user, "config@example.org")
  expect_match(inherited_script, "#SBATCH --mail-user=config@example\\.org")

  overridden <- laimsdgxllm::submit_job(
    bundle = bundle,
    submit = FALSE,
    slurm = list(mail_user = "override@example.org"),
    config = config
  )
  overridden_script <- paste(readLines(overridden$local_script_path, warn = FALSE), collapse = "\n")
  expect_identical(overridden$slurm$mail_user, "override@example.org")
  expect_match(overridden_script, "#SBATCH --mail-user=override@example\\.org")
})


test_that("submit_job(submit = FALSE) omits mail directives when no mail_user is provided", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif"
  )
  bundle <- create_test_bundle(config = config)

  plan <- laimsdgxllm::submit_job(bundle = bundle, submit = FALSE, config = config)
  script <- paste(readLines(plan$local_script_path, warn = FALSE), collapse = "\n")

  expect_identical(plan$slurm$mail_user, "")
  expect_match(script, "#SBATCH --nodelist=poddgx02")
  expect_match(script, "#SBATCH --nodes=1")
  expect_no_match(script, "#SBATCH --mail-user=")
  expect_no_match(script, "#SBATCH --mail-type=")
})

test_that("submit_job(submit = TRUE) requires configured mail_user when absent", {
  config <- local_test_config(
    login_user = "alice",
    runtime_mode = "external",
    sif_path = "/containers/from-config.sif"
  )
  bundle <- create_test_bundle(config = config)

  expect_error(
    laimsdgxllm::submit_job(bundle = bundle, submit = TRUE, config = config),
    "configured mail recipient|dgx_config\\(mail_user|slurm\\$mail_user"
  )
})
