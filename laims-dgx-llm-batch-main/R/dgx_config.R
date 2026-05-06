# Shared helpers ------------------------------------------------------------

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) {
    return(y)
  }

  if (length(x) == 1L && (is.na(x) || identical(x, ""))) {
    return(y)
  }

  x
}

.timestamp_utc <- function(x = Sys.time()) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

.compact_stamp <- function(x = Sys.time()) {
  format(as.POSIXct(x, tz = "UTC"), "%y%m%d%H%M", tz = "UTC")
}

.rand_hex <- function(n = 6L) {
  paste(sample(c(letters[1:6], 0:9), size = n, replace = TRUE), collapse = "")
}

.sanitize_slug <- function(slug, max_chars = 24L) {
  slug <- slug %||% ""
  slug <- tolower(trimws(as.character(slug)[1]))
  slug <- gsub("[^a-z0-9]+", "-", slug)
  slug <- gsub("^-+|-+$", "", slug)
  slug <- gsub("-{2,}", "-", slug)

  if (identical(slug, "")) {
    return(NA_character_)
  }

  substr(slug, 1L, max_chars)
}

.make_run_id <- function(slug = NULL, time = Sys.time(), rand = .rand_hex(6L)) {
  slug <- .sanitize_slug(slug)
  stamp <- format(as.POSIXct(time, tz = "UTC"), "%Y%m%dT%H%M%SZ", tz = "UTC")

  if (is.na(slug)) {
    paste("run", stamp, rand, sep = "-")
  } else {
    paste("run", stamp, slug, rand, sep = "-")
  }
}

.make_slurm_job_name <- function(run_id = NULL, slug = NULL, time = Sys.time()) {
  slug_short <- .sanitize_slug(slug, max_chars = 16L)
  prefix <- if (is.na(slug_short)) "batch" else slug_short
  paste("ldl", prefix, .compact_stamp(time), .rand_hex(4L), sep = "-")
}

.resolve_config <- function(config = NULL) {
  if (inherits(config, "laims_dgx_config")) {
    return(config)
  }

  opt <- getOption("laimsdgxllm.config", default = NULL)
  if (inherits(opt, "laims_dgx_config")) {
    return(opt)
  }

  dgx_config()
}

.trim_scalar_value <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return("")
  }

  value <- trimws(as.character(x)[1])
  if (is.na(value)) {
    return("")
  }

  value
}

.default_login_host <- function() {
  "logindgx.hpc.ict.unipd.it"
}

.normalize_local_path <- function(x) {
  value <- .trim_scalar_value(x)
  if (identical(value, "")) {
    return(NA_character_)
  }

  path.expand(value)
}

.default_ssh_key_path <- function(login_user) {
  login_user <- .trim_scalar_value(login_user)
  if (identical(login_user, "")) {
    return(NA_character_)
  }

  path.expand(fs::path("~", ".ssh", paste0(login_user, ".key")))
}

.resolve_ssh_key_path <- function(login_user, ssh_key_path = NA_character_) {
  explicit <- .normalize_local_path(ssh_key_path)
  if (!is.na(explicit)) {
    return(list(path = explicit, source = "explicit"))
  }

  derived <- .default_ssh_key_path(login_user)
  if (!is.na(derived)) {
    return(list(path = derived, source = "derived"))
  }

  list(path = NA_character_, source = "unset")
}

.ssh_key_exists <- function(path) {
  !is.na(path) && file.exists(path)
}

.ssh_key_error_message <- function(config, action = "use SSH") {
  key_path <- config$ssh_key_path %||% NA_character_
  display_path <- if (is.na(key_path)) "<unset>" else key_path
  login_user <- .trim_scalar_value(config$login_user)

  bullets <- c(
    paste0("Cannot ", action, " because the SSH key file was not found."),
    "x" = paste0("Missing key: ", display_path),
    "i" = "Provide the key explicitly via `ssh_key_path = ...`.",
    "i" = "If you do not know which key to use, obtain the correct key from the relevant DGX admin."
  )

  if (identical(login_user, "")) {
    bullets <- c(
      paste0("Cannot ", action, " because `login_user` is not configured."),
      "i" = "Set `dgx_config(login_user = ...)` so the default SSH key path can be derived."
    )
  }

  bullets
}

.assert_ssh_ready <- function(config, action = "use SSH") {
  host <- .trim_scalar_value(config$login_host)
  user <- .trim_scalar_value(config$login_user)

  if (identical(host, "")) {
    cli::cli_abort(c(
      paste0("Cannot ", action, " without a configured login host."),
      "i" = paste0("The package host is expected to be `", .default_login_host(), "`.")
    ))
  }

  if (identical(user, "")) {
    cli::cli_abort(c(
      paste0("Cannot ", action, " without `login_user` in `dgx_config()`."),
      "i" = "Set `dgx_config(login_user = ...)` so the SSH destination and default key path can be derived."
    ))
  }

  if (!.ssh_key_exists(config$ssh_key_path)) {
    cli::cli_abort(.ssh_key_error_message(config, action = action))
  }

  invisible(config)
}

.ssh_cli_args <- function(config) {
  .assert_ssh_ready(config)
  c(config$ssh_args, "-o", "IdentitiesOnly=yes", "-i", config$ssh_key_path)
}

.ssh_cli_args_preview <- function(config) {
  args <- config$ssh_args
  if (!is.na(config$ssh_key_path %||% NA_character_)) {
    args <- c(args, "-o", "IdentitiesOnly=yes", "-i", config$ssh_key_path)
  }
  args
}

# Registry schema -----------------------------------------------------------

.registry_schema_version <- "2"

.registry_schema_statements <- function() {
  c(
    paste(
      "CREATE TABLE IF NOT EXISTS metadata (",
      "key TEXT PRIMARY KEY,",
      "value TEXT NOT NULL",
      ");"
    ),
    paste(
      "CREATE TABLE IF NOT EXISTS runs (",
      "run_id TEXT PRIMARY KEY,",
      "slug TEXT,",
      "state TEXT NOT NULL,",
      "state_source TEXT,",
      "state_detail TEXT,",
      "created_at TEXT NOT NULL,",
      "submitted_at TEXT,",
      "queued_at TEXT,",
      "running_at TEXT,",
      "completed_at TEXT,",
      "failed_at TEXT,",
      "cancelled_at TEXT,",
      "collected_at TEXT,",
      "updated_at TEXT NOT NULL,",
      "last_synced_at TEXT,",
      "remote_updated_at TEXT,",
      "login_host TEXT,",
      "login_user TEXT,",
      "remote_run_dir TEXT,",
      "remote_bundle_dir TEXT,",
      "remote_status_path TEXT,",
      "remote_predictions_path TEXT,",
      "remote_errors_path TEXT,",
      "remote_summary_path TEXT,",
      "local_run_dir TEXT,",
      "local_results_dir TEXT,",
      "bundle_hash TEXT,",
      "model_profile TEXT,",
      "container_image TEXT,",
      "slurm_job_id TEXT,",
      "slurm_job_name TEXT,",
      "slurm_partition TEXT,",
      "slurm_account TEXT,",
      "scheduler_state TEXT,",
      "scheduler_source TEXT,",
      "slurm_exit_code TEXT,",
      "total_records INTEGER,",
      "completed_records INTEGER DEFAULT 0,",
      "failed_records INTEGER DEFAULT 0,",
      "total_chunks INTEGER,",
      "completed_chunks INTEGER DEFAULT 0,",
      "running_chunks INTEGER DEFAULT 0,",
      "status_cache_json TEXT",
      ");"
    ),
    paste(
      "CREATE TABLE IF NOT EXISTS run_events (",
      "id INTEGER PRIMARY KEY AUTOINCREMENT,",
      "run_id TEXT NOT NULL,",
      "event_time TEXT NOT NULL,",
      "event_type TEXT NOT NULL,",
      "state TEXT,",
      "details_json TEXT,",
      "FOREIGN KEY(run_id) REFERENCES runs(run_id)",
      ");"
    ),
    "CREATE INDEX IF NOT EXISTS idx_runs_state ON runs(state);",
    "CREATE INDEX IF NOT EXISTS idx_runs_slug ON runs(slug);",
    "CREATE INDEX IF NOT EXISTS idx_runs_updated_at ON runs(updated_at);",
    "CREATE INDEX IF NOT EXISTS idx_run_events_run_id ON run_events(run_id);"
  )
}

.registry_connect <- function(config) {
  con <- DBI::dbConnect(RSQLite::SQLite(), config$registry_path)
  DBI::dbExecute(con, "PRAGMA journal_mode = WAL;")
  DBI::dbExecute(con, "PRAGMA busy_timeout = 5000;")
  con
}

.registry_run_column_specs <- function() {
  c(
    remote_updated_at = "TEXT",
    scheduler_state = "TEXT",
    scheduler_source = "TEXT",
    slurm_exit_code = "TEXT"
  )
}

.ensure_registry <- function(config) {
  fs::dir_create(fs::path_dir(config$registry_path))

  con <- .registry_connect(config)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  for (statement in .registry_schema_statements()) {
    DBI::dbExecute(con, statement)
  }

  existing_run_cols <- DBI::dbListFields(con, "runs")
  for (col in names(.registry_run_column_specs())) {
    if (!col %in% existing_run_cols) {
      DBI::dbExecute(
        con,
        paste("ALTER TABLE runs ADD COLUMN", col, .registry_run_column_specs()[[col]])
      )
    }
  }

  DBI::dbExecute(
    con,
    "INSERT OR REPLACE INTO metadata(key, value) VALUES('schema_version', ?);",
    params = list(.registry_schema_version)
  )

  invisible(config)
}

.registry_read_runs <- function(config) {
  con <- .registry_connect(config)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  if (!DBI::dbExistsTable(con, "runs")) {
    return(data.frame())
  }

  DBI::dbReadTable(con, "runs")
}

.registry_get_run <- function(run_id, config) {
  con <- .registry_connect(config)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbGetQuery(
    con,
    "SELECT * FROM runs WHERE run_id = ? LIMIT 1;",
    params = list(as.character(run_id)[1])
  )
}

.registry_upsert_run <- function(values, config) {
  con <- .registry_connect(config)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  cols <- DBI::dbListFields(con, "runs")
  vals <- values[names(values) %in% cols]

  if (is.null(vals$run_id) || length(vals$run_id) == 0L) {
    cli::cli_abort("`.registry_upsert_run()` requires a `run_id`.")
  }

  vals$updated_at <- vals$updated_at %||% .timestamp_utc()

  exists <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM runs WHERE run_id = ?;",
    params = list(vals$run_id)
  )$n[[1]] > 0

  if (exists) {
    update_cols <- setdiff(names(vals), "run_id")

    if (length(update_cols) > 0L) {
      sql <- paste0(
        "UPDATE runs SET ",
        paste(paste0(update_cols, " = ?"), collapse = ", "),
        " WHERE run_id = ?;"
      )
      params <- c(unname(as.list(vals[update_cols])), list(vals$run_id))
      DBI::dbExecute(con, sql, params = params)
    }
  } else {
    insert_cols <- names(vals)
    sql <- paste0(
      "INSERT INTO runs (",
      paste(insert_cols, collapse = ", "),
      ") VALUES (",
      paste(rep("?", length(insert_cols)), collapse = ", "),
      ");"
    )
    DBI::dbExecute(con, sql, params = unname(as.list(vals[insert_cols])))
  }

  invisible(vals$run_id)
}

.registry_append_event <- function(run_id, event_type, state = NULL, details = NULL, config) {
  con <- .registry_connect(config)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbExecute(
    con,
    paste(
      "INSERT INTO run_events(run_id, event_time, event_type, state, details_json)",
      "VALUES (?, ?, ?, ?, ?);"
    ),
    params = list(
      as.character(run_id)[1],
      .timestamp_utc(),
      as.character(event_type)[1],
      state %||% NA_character_,
      if (is.null(details)) NA_character_ else jsonlite::toJSON(details, auto_unbox = TRUE, null = "null")
    )
  )

  invisible(run_id)
}

# Public config -------------------------------------------------------------

.normalize_job_resources <- function(
  cpus = 4L,
  mem = "32G",
  partition = "dgx12cluster",
  account = "dctv_dgx",
  nodelist = "poddgx02",
  nodes = 1L
) {
  cpus <- as.integer(cpus %||% 4L)
  mem <- trimws(as.character(mem %||% "32G")[1])
  partition <- .trim_scalar_value(partition %||% "dgx12cluster")
  account <- .trim_scalar_value(account %||% "dctv_dgx")
  nodelist <- .trim_scalar_value(nodelist %||% "poddgx02")
  nodes <- as.integer(nodes %||% 1L)

  if (is.na(cpus) || cpus < 1L) {
    cli::cli_abort("`cpus` must be a positive integer.")
  }
  if (is.na(mem) || identical(mem, "")) {
    cli::cli_abort("`mem` must be a non-empty memory string like '32G'.")
  }
  if (identical(partition, "")) {
    cli::cli_abort("`partition` must be a non-empty string.")
  }
  if (identical(account, "")) {
    cli::cli_abort("`account` must be a non-empty string.")
  }
  if (identical(nodelist, "")) {
    cli::cli_abort("`nodelist` must be a non-empty string.")
  }
  if (is.na(nodes) || nodes != 1L) {
    cli::cli_abort("`nodes` is fixed to 1 so jobs stay on a single DGX node.")
  }

  list(
    gpus = 1L,
    cpus = cpus,
    mem = mem,
    partition = partition,
    account = account,
    nodelist = nodelist,
    nodes = nodes,
    total_vram_gb = 80L
  )
}

#' Create or retrieve DGX client configuration
#'
#' `dgx_config()` bootstraps the local state directory and the SQLite registry
#' used to recover submitted runs across R sessions and laptop restarts.
#'
#' The package hardcodes the stable DGX login host
#' `logindgx.hpc.ict.unipd.it`; users only need to provide the SSH username and,
#' optionally, an explicit key path. When `ssh_key_path` is omitted, the package
#' derives `~/.ssh/<login_user>.key`.
#'
#' @param login_user SSH username used to reach the DGX login host.
#' @param ssh_key_path Optional path to the local SSH private key. When omitted,
#'   the package derives `~/.ssh/<login_user>.key`.
#' @param state_dir Local persistent state directory.
#' @param user_root Remote per-user root directory. When unset, it is derived
#'   from `remote_base_dir` when possible, otherwise defaults to
#'   `/mnt/projects/dctv/dgx/<login_user>`.
#' @param remote_base_dir Base directory for remote runs. When unset, it is
#'   derived as `<user_root>/runs`.
#' @param mail_user Optional default notification email for SLURM jobs. This
#'   stays user-supplied (no package personal default), but can be configured
#'   once here so `submit_job()`/`extract_batch()` inherit it automatically.
#' @param cpus Default CPU count for submitted jobs.
#' @param mem Default host RAM request for submitted jobs.
#' @param partition Default SLURM partition for submitted jobs.
#' @param account Default SLURM account for submitted jobs.
#' @param nodelist Default SLURM nodelist for submitted jobs.
#' @param nodes Default SLURM node count for submitted jobs. Fixed to 1 so
#'   submitted jobs remain on a single DGX node.
#' @param runtime_mode Runtime resolution strategy: `"managed"` or
#'   `"external"`. Defaults to `"managed"`; set `"external"` when you want
#'   `dgx_config()` to validate and reuse a pre-existing remote `.sif`.
#' @param sif_path Optional default path to an externally managed runtime SIF on
#'   the remote cluster. Used when `runtime_mode = "external"` or when an
#'   explicit `sif_path` override is supplied to [ensure_runtime()] or
#'   [submit_job()]. Defaults to `Sys.getenv("LAIMS_DGX_SIF_PATH")`.
#' @param runtime_name Optional basename used for package-managed runtime assets
#'   and SIF versions on the remote side. Advanced/backward-compatible knob;
#'   most users should ignore it.
#' @param poll_interval Default polling interval for live progress.
#' @param connect_timeout SSH connect timeout in seconds.
#' @param ssh_args Extra SSH CLI arguments.
#' @param registry_path Path to the local SQLite registry.
#' @param ssh_bin SSH binary.
#' @param scp_bin SCP binary.
#' @param squeue_bin `squeue` command available on the remote login node.
#' @param sacct_bin `sacct` command available on the remote login node.
#' @param apptainer_bin Apptainer/Singularity binary path or command name.
#'   Defaults to the cluster-specific Singularity binary known to work on the
#'   target DGX SLURM environment.
#'
#' @return An object of class `laims_dgx_config`.
#'
#' @examples
#' \dontrun{
#' # Minimal — SSH key derived from ~/.ssh/u0043.key
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#' print(cfg)
#'
#' # Override resources and nodelist
#' cfg <- dgx_config(
#'   login_user = "u0043",
#'   mail_user  = "you@example.org",
#'   cpus       = 8,
#'   mem        = "64G",
#'   nodelist   = "poddgx02"
#' )
#'
#' # Explicit SSH key path
#' cfg <- dgx_config(
#'   login_user   = "u0043",
#'   ssh_key_path = "~/.ssh/my_dgx_key",
#'   mail_user    = "you@example.org"
#' )
#' }
#' @export

dgx_config <- function(
  login_user = Sys.getenv("LAIMS_DGX_LOGIN_USER", unset = ""),
  state_dir = Sys.getenv(
    "LAIMS_DGX_STATE_DIR",
    unset = tools::R_user_dir("laimsdgxllm", which = "data")
  ),
  ssh_key_path = Sys.getenv("LAIMS_DGX_SSH_KEY_PATH", unset = ""),
  user_root = Sys.getenv("LAIMS_DGX_USER_ROOT", unset = ""),
  remote_base_dir = Sys.getenv("LAIMS_DGX_REMOTE_BASE_DIR", unset = ""),
  mail_user = Sys.getenv("LAIMS_DGX_MAIL_USER", unset = ""),
  cpus = as.integer(Sys.getenv("LAIMS_DGX_CPUS", unset = "4")),
  mem = Sys.getenv("LAIMS_DGX_MEM", unset = "32G"),
  partition = Sys.getenv("LAIMS_DGX_PARTITION", unset = "dgx12cluster"),
  account = Sys.getenv("LAIMS_DGX_ACCOUNT", unset = "dctv_dgx"),
  nodelist = Sys.getenv("LAIMS_DGX_NODELIST", unset = "poddgx02"),
  nodes = as.integer(Sys.getenv("LAIMS_DGX_NODES", unset = "1")),
  runtime_mode = Sys.getenv("LAIMS_DGX_RUNTIME_MODE", unset = "managed"),
  sif_path = Sys.getenv("LAIMS_DGX_SIF_PATH", unset = ""),
  runtime_name = Sys.getenv("LAIMS_DGX_RUNTIME_NAME", unset = "laims-runtime"),
  poll_interval = 5,
  connect_timeout = 10,
  ssh_args = c("-o", "BatchMode=yes", "-o", paste0("ConnectTimeout=", connect_timeout)),
  registry_path = fs::path(state_dir, "registry.sqlite"),
  ssh_bin = Sys.getenv("LAIMS_DGX_SSH_BIN", unset = "ssh"),
  scp_bin = Sys.getenv("LAIMS_DGX_SCP_BIN", unset = "scp"),
  squeue_bin = Sys.getenv("LAIMS_DGX_SQUEUE_BIN", unset = "squeue"),
  sacct_bin = Sys.getenv("LAIMS_DGX_SACCT_BIN", unset = "sacct"),
  apptainer_bin = Sys.getenv("LAIMS_DGX_APPTAINER_BIN", unset = "/cm/shared/apps/singularity/4.2.0/bin/singularity")
) {
  login_user <- .trim_scalar_value(login_user)
  ssh_key <- .resolve_ssh_key_path(login_user = login_user, ssh_key_path = ssh_key_path)
  derived_runtime <- .derive_runtime_config(
    login_user = login_user,
    user_root = user_root,
    remote_base_dir = remote_base_dir,
    runtime_mode = runtime_mode,
    runtime_name = runtime_name,
    sif_path = sif_path
  )
  job_resources <- .normalize_job_resources(
    cpus = cpus,
    mem = mem,
    partition = partition,
    account = account,
    nodelist = nodelist,
    nodes = nodes
  )
  mail_user <- .trim_scalar_value(mail_user)
  if (!identical(mail_user, "") && !grepl("@", mail_user, fixed = TRUE)) {
    cli::cli_abort("`mail_user` must look like an email address when provided.")
  }
  job_resources$mail_user <- mail_user
  state_dir <- fs::path_abs(state_dir)
  registry_path <- fs::path_abs(registry_path)

  fs::dir_create(state_dir)
  fs::dir_create(fs::path(state_dir, "results"))

  config <- structure(
    list(
      login_host = .default_login_host(),
      login_user = login_user,
      ssh_key_path = ssh_key$path,
      ssh_key_source = ssh_key$source,
      ssh_key_exists = .ssh_key_exists(ssh_key$path),
      user_root = derived_runtime$user_root,
      remote_base_dir = derived_runtime$remote_base_dir,
      state_dir = state_dir,
      registry_path = registry_path,
      results_dir = fs::path(state_dir, "results"),
      ssh_bin = ssh_bin,
      scp_bin = scp_bin,
      squeue_bin = squeue_bin,
      sacct_bin = sacct_bin,
      apptainer_bin = apptainer_bin,
      sif_path = sif_path,
      mail_user = mail_user,
      runtime_mode = derived_runtime$runtime$mode,
      runtime = derived_runtime$runtime,
      hardware = list(
        gpu_type = "H100",
        gpu_vram_gb = 80L,
        total_vram_gb = 80L
      ),
      job_resources = job_resources,
      poll_interval = poll_interval,
      connect_timeout = connect_timeout,
      ssh_args = ssh_args
    ),
    class = "laims_dgx_config"
  )

  .ensure_registry(config)
  options(laimsdgxllm.config = config)
  config
}

#' @export
print.laims_dgx_config <- function(x, ...) {
  cat("<laims_dgx_config>\n", sep = "")
  cat("  login_host   : ", x$login_host %||% "<unset>", "\n", sep = "")
  cat("  login_user   : ", x$login_user %||% "<unset>", "\n", sep = "")
  cat("  ssh_key_path : ", x$ssh_key_path %||% "<unset>", "\n", sep = "")
  cat("  ssh_key_src  : ", x$ssh_key_source %||% "<unset>", "\n", sep = "")
  cat("  user_root    : ", x$user_root %||% "<unset>", "\n", sep = "")
  cat("  remote_base  : ", x$remote_base_dir, "\n", sep = "")
  cat("  runtime_mode : ", x$runtime_mode %||% "<unset>", "\n", sep = "")
  cat("  sif_path     : ", x$sif_path %||% "<unset>", "\n", sep = "")
  cat("  mail_user    : ", x$mail_user %||% "<unset>", "\n", sep = "")
  cat("  resources    : 1x H100 | ", x$job_resources$cpus, " CPU | ", x$job_resources$mem, " RAM", "\n", sep = "")
  cat("  total_vram   : ", x$hardware$total_vram_gb, "GB\n", sep = "")
  cat("  state_dir    : ", x$state_dir, "\n", sep = "")
  cat("  registry     : ", x$registry_path, "\n", sep = "")
  cat("  poll_interval: ", x$poll_interval, "s\n", sep = "")
  invisible(x)
}
