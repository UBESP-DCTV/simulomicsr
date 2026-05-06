test_state_dir <- function() {
  fs::path(tempdir(), paste0("laimsdgxllm-test-", Sys.getpid(), "-", sample.int(1e6, 1)))
}

local_test_key <- function(login_user = "alice") {
  ssh_dir <- fs::path(tempdir(), paste0("laimsdgxllm-ssh-", Sys.getpid(), "-", sample.int(1e6, 1)))
  fs::dir_create(ssh_dir)
  key_path <- fs::path(ssh_dir, paste0(login_user, ".key"))
  writeLines("dummy-test-key", key_path)
  withr::defer(unlink(ssh_dir, recursive = TRUE, force = TRUE), testthat::teardown_env())
  key_path
}

local_test_config <- function(
    login_user = "",
    ssh_key_path = NULL,
    sif_path = "",
    runtime_mode = "managed",
    user_root = "",
    remote_base_dir = "",
    mail_user = "",
    cpus = 4,
    mem = "32G",
    partition = "dgx12cluster",
    account = "dctv_dgx",
    nodelist = "poddgx02",
    nodes = 1) {
  state_dir <- test_state_dir()
  if (!identical(trimws(login_user), "") && is.null(ssh_key_path)) {
    ssh_key_path <- local_test_key(login_user)
  }

  config <- laimsdgxllm::dgx_config(
    login_user = login_user,
    ssh_key_path = ssh_key_path %||% "",
    user_root = user_root,
    remote_base_dir = remote_base_dir,
    state_dir = state_dir,
    runtime_mode = runtime_mode,
    sif_path = sif_path,
    mail_user = mail_user,
    cpus = cpus,
    mem = mem,
    partition = partition,
    account = account,
    nodelist = nodelist,
    nodes = nodes,
    poll_interval = 0.01
  )
  withr::defer(unlink(state_dir, recursive = TRUE, force = TRUE), testthat::teardown_env())
  config
}

sample_records <- function() {
  data.frame(
    id = c("r1", "r2", "r3"),
    text = c(
      "Short note about the first patient.",
      "A slightly longer second note with a few more details.",
      "Third note."
    ),
    stringsAsFactors = FALSE
  )
}

sample_schema <- function() {
  list(
    type = "object",
    properties = list(
      label = list(type = "string"),
      confidence = list(type = "number")
    ),
    required = c("label")
  )
}

create_test_bundle <- function(config = local_test_config(), metadata = list(project = "CI smoke"), model = "20B", ...) {
  laimsdgxllm::create_bundle(
    records = sample_records(),
    id_col = "id",
    text_col = "text",
    prompt_template = "Extract the label and confidence as JSON.",
    schema = sample_schema(),
    model = model,
    metadata = metadata,
    config = config,
    ...
  )
}

local_runtime_transport <- function(responder = NULL, copier = NULL) {
  if (!is.function(responder)) {
    responder <- function(config, command) {
      list(ok = TRUE, status = 0L, stdout = "", stderr = "")
    }
  }
  if (!is.function(copier)) {
    copier <- function(config, local_dir, remote_dir) {
      list(ok = TRUE, status = 0L, stdout = "", stderr = "")
    }
  }

  withr::local_options(
    list(
      laimsdgxllm.runtime_ssh_capture = responder,
      laimsdgxllm.runtime_copy_dir = copier
    ),
    .local_envir = parent.frame()
  )
}
