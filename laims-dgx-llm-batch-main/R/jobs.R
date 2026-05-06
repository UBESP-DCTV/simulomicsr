# Internal helpers ---------------------------------------------------------

.row1 <- function(df) {
  if (nrow(df) < 1L) {
    return(NULL)
  }
  df[1, , drop = FALSE]
}

.scalar <- function(x, default = NA) {
  if (is.null(x) || length(x) == 0L) {
    return(default)
  }

  value <- x[[1]]
  if (length(value) == 0L || (length(value) == 1L && (is.na(value) || identical(value, "")))) {
    return(default)
  }

  value
}

.int_scalar <- function(x, default = NA_integer_) {
  val <- .scalar(x, default = default)
  if (is.na(val) || identical(val, "")) {
    return(default)
  }
  as.integer(val)
}

.deep_get <- function(x, path, default = NULL) {
  value <- x
  for (name in path) {
    if (is.null(value) || is.atomic(value)) {
      return(default)
    }
    if (!name %in% names(value)) {
      return(default)
    }
    value <- value[[name]]
  }
  value %||% default
}

.is_terminal_state <- function(state) {
  state %in% c("completed", "failed", "cancelled", "collected")
}

.map_slurm_state <- function(state) {
  raw <- tolower(trimws(as.character(state %||% "")))
  raw <- sub("\\+.*$", "", raw)

  if (identical(raw, "")) {
    return(NA_character_)
  }

  if (raw %in% c("pending", "configuring", "resv_del_hold", "requeue_hold", "suspended")) {
    return("queued")
  }

  if (raw %in% c("running", "completing", "stage_out")) {
    return("running")
  }

  if (identical(raw, "completed")) {
    return("completed")
  }

  if (startsWith(raw, "cancelled")) {
    return("cancelled")
  }

  if (raw %in% c(
    "failed", "timeout", "out_of_memory", "preempted", "node_fail",
    "boot_fail", "deadline", "revoked"
  )) {
    return("failed")
  }

  "submitted"
}

.stabilize_state <- function(current, candidate) {
  current <- current %||% NA_character_
  candidate <- candidate %||% current

  if (is.na(candidate) || identical(candidate, "")) {
    return(current)
  }

  if (identical(current, "collected") && identical(candidate, "completed")) {
    return("collected")
  }

  if (.is_terminal_state(current) && !.is_terminal_state(candidate)) {
    return(current)
  }

  candidate
}

.as_job <- function(row, config) {
  structure(
    list(
      run_id = .scalar(row$run_id),
      slug = .scalar(row$slug),
      state = .scalar(row$state),
      slurm_job_id = .scalar(row$slurm_job_id),
      slurm_job_name = .scalar(row$slurm_job_name),
      remote_run_dir = .scalar(row$remote_run_dir),
      remote_status_path = .scalar(row$remote_status_path),
      model_profile = .scalar(row$model_profile),
      config = config
    ),
    class = "laims_dgx_job"
  )
}

#' @export
print.laims_dgx_job <- function(x, ...) {
  cat("<laims_dgx_job>\n", sep = "")
  cat("  run_id       : ", x$run_id, "\n", sep = "")
  cat("  slug         : ", x$slug %||% "<none>", "\n", sep = "")
  cat("  state        : ", x$state %||% "<unknown>", "\n", sep = "")
  cat("  slurm_job_id : ", x$slurm_job_id %||% "<unknown>", "\n", sep = "")
  cat("  remote_run   : ", x$remote_run_dir %||% "<unset>", "\n", sep = "")
  invisible(x)
}

.ssh_destination <- function(config) {
  host <- config$login_host %||% ""
  user <- config$login_user %||% ""

  if (identical(host, "")) {
    return("")
  }

  if (identical(user, "")) host else paste0(user, "@", host)
}

.ssh_login_shell_command <- function(command) {
  paste("bash -lc", shQuote(command))
}

.ssh_capture <- function(config, command) {
  destination <- .ssh_destination(config)
  remote_command <- .ssh_login_shell_command(command)

  if (identical(destination, "")) {
    return(list(ok = FALSE, status = 1L, stdout = "", stderr = "login destination is not configured"))
  }

  if (!.ssh_key_exists(config$ssh_key_path)) {
    return(list(
      ok = FALSE,
      status = 1L,
      stdout = "",
      stderr = paste(unname(.ssh_key_error_message(config, action = "use SSH")), collapse = " ")
    ))
  }

  result <- tryCatch(
    processx::run(
      command = config$ssh_bin,
      args = c(.ssh_cli_args(config), destination, remote_command),
      error_on_status = FALSE,
      echo = FALSE
    ),
    error = function(e) {
      list(status = 1L, stdout = "", stderr = conditionMessage(e))
    }
  )

  list(
    ok = identical(result$status, 0L),
    status = result$status,
    stdout = trimws(result$stdout %||% ""),
    stderr = trimws(result$stderr %||% "")
  )
}

.probe_remote_status <- function(row, config) {
  status_path <- .scalar(row$remote_status_path)
  remote_run_dir <- .scalar(row$remote_run_dir)

  if (is.na(status_path) || identical(status_path, "")) {
    if (is.na(remote_run_dir) || identical(remote_run_dir, "")) {
      return(list())
    }
    status_path <- paste(remote_run_dir, "status.json", sep = "/")
  }

  command <- paste(
    "if [ -f", shQuote(status_path), "]; then",
    "cat", shQuote(status_path), ";",
    "fi"
  )

  capture <- .ssh_capture(config, command)
  if (!isTRUE(capture$ok) || identical(capture$stdout, "")) {
    return(list())
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(capture$stdout, simplifyVector = FALSE),
    error = function(e) NULL
  )

  if (is.null(parsed)) {
    return(list())
  }

  list(
    source = "status.json",
    state = .deep_get(parsed, "state", default = NA_character_),
    message = .deep_get(parsed, "message", default = NA_character_),
    updated_at = .deep_get(parsed, "updated_at", default = NA_character_),
    submitted_at = .deep_get(parsed, "submitted_at", default = NA_character_),
    started_at = .deep_get(parsed, "started_at", default = NA_character_),
    finished_at = .deep_get(parsed, "finished_at", default = NA_character_),
    slurm_job_id = .deep_get(parsed, "slurm_job_id", default = NA_character_),
    total_records = .deep_get(parsed, c("records", "total"), default = NA_integer_),
    completed_records = .deep_get(parsed, c("records", "completed"), default = NA_integer_),
    failed_records = .deep_get(parsed, c("records", "failed"), default = NA_integer_),
    total_chunks = .deep_get(parsed, c("chunks", "total"), default = NA_integer_),
    completed_chunks = .deep_get(parsed, c("chunks", "completed"), default = NA_integer_),
    running_chunks = .deep_get(parsed, c("chunks", "running"), default = NA_integer_),
    raw = parsed
  )
}

.probe_scheduler_status <- function(row, config) {
  job_id <- .scalar(row$slurm_job_id)
  if (is.na(job_id) || identical(job_id, "")) {
    return(list())
  }

  squeue_cmd <- paste(
    "if command -v", config$squeue_bin, ">/dev/null 2>&1; then",
    config$squeue_bin,
    "-h -j", shQuote(job_id),
    "-o '%T|%M|%D'; fi"
  )
  squeue <- .ssh_capture(config, squeue_cmd)

  if (isTRUE(squeue$ok) && !identical(squeue$stdout, "")) {
    fields <- strsplit(squeue$stdout, "\\|")[[1]]
    raw_state <- .scalar(fields[1], default = NA_character_)
    return(list(
      source = "squeue",
      state = .map_slurm_state(raw_state),
      raw_state = raw_state,
      elapsed = .scalar(fields[2], default = NA_character_),
      nodes = .scalar(fields[3], default = NA_character_)
    ))
  }

  sacct_cmd <- paste(
    "if command -v", config$sacct_bin, ">/dev/null 2>&1; then",
    config$sacct_bin,
    "-n -X -j", shQuote(job_id),
    "--format=State,ExitCode -P | head -n 1; fi"
  )
  sacct <- .ssh_capture(config, sacct_cmd)

  if (isTRUE(sacct$ok) && !identical(sacct$stdout, "")) {
    fields <- strsplit(sacct$stdout, "\\|")[[1]]
    raw_state <- .scalar(fields[1], default = NA_character_)
    return(list(
      source = "sacct",
      state = .map_slurm_state(raw_state),
      raw_state = raw_state,
      exit_code = .scalar(fields[2], default = NA_character_)
    ))
  }

  list()
}

.merge_status_row <- function(row, remote_status, scheduler_status) {
  current_state <- .scalar(row$state, default = "created")
  candidate_state <- remote_status$state %||% scheduler_status$state %||% current_state
  next_state <- .stabilize_state(current_state, candidate_state)
  now <- .timestamp_utc()

  values <- list(
    run_id = .scalar(row$run_id),
    state = next_state,
    state_source = remote_status$source %||% scheduler_status$source %||% .scalar(row$state_source),
    state_detail = remote_status$message %||% .scalar(row$state_detail),
    submitted_at = remote_status$submitted_at %||% .scalar(row$submitted_at),
    queued_at = if (identical(next_state, "queued")) .scalar(row$queued_at, default = now) else .scalar(row$queued_at),
    running_at = remote_status$started_at %||% if (identical(next_state, "running")) .scalar(row$running_at, default = now) else .scalar(row$running_at),
    completed_at = if (identical(next_state, "completed")) remote_status$finished_at %||% .scalar(row$completed_at, default = now) else .scalar(row$completed_at),
    failed_at = if (identical(next_state, "failed")) .scalar(row$failed_at, default = now) else .scalar(row$failed_at),
    cancelled_at = if (identical(next_state, "cancelled")) .scalar(row$cancelled_at, default = now) else .scalar(row$cancelled_at),
    updated_at = now,
    last_synced_at = now,
    remote_updated_at = remote_status$updated_at %||% .scalar(row$remote_updated_at),
    slurm_job_id = remote_status$slurm_job_id %||% .scalar(row$slurm_job_id),
    scheduler_state = scheduler_status$state %||% .scalar(row$scheduler_state),
    scheduler_source = scheduler_status$source %||% .scalar(row$scheduler_source),
    slurm_exit_code = scheduler_status$exit_code %||% .scalar(row$slurm_exit_code),
    total_records = remote_status$total_records %||% .scalar(row$total_records),
    completed_records = remote_status$completed_records %||% .scalar(row$completed_records, default = 0L),
    failed_records = remote_status$failed_records %||% .scalar(row$failed_records, default = 0L),
    total_chunks = remote_status$total_chunks %||% .scalar(row$total_chunks),
    completed_chunks = remote_status$completed_chunks %||% .scalar(row$completed_chunks, default = 0L),
    running_chunks = remote_status$running_chunks %||% .scalar(row$running_chunks, default = 0L),
    status_cache_json = jsonlite::toJSON(
      list(
        remote_status = remote_status,
        scheduler_status = scheduler_status,
        synced_at = now
      ),
      auto_unbox = TRUE,
      null = "null"
    )
  )

  list(
    values = values,
    state_changed = !identical(current_state, next_state),
    previous_state = current_state,
    next_state = next_state
  )
}

.status_from_row <- function(row, config) {
  total_records <- .int_scalar(row$total_records)
  completed_records <- .int_scalar(row$completed_records, default = 0L)
  failed_records <- .int_scalar(row$failed_records, default = 0L)
  total_chunks <- .int_scalar(row$total_chunks)
  completed_chunks <- .int_scalar(row$completed_chunks, default = 0L)
  running_chunks <- .int_scalar(row$running_chunks, default = 0L)

  processed_records <- if (is.na(total_records)) {
    NA_integer_
  } else {
    completed_records + failed_records
  }

  pending_records <- if (is.na(total_records)) NA_integer_ else max(total_records - processed_records, 0L)
  pending_chunks <- if (is.na(total_chunks)) NA_integer_ else max(total_chunks - completed_chunks - running_chunks, 0L)
  fraction_records <- if (is.na(total_records) || total_records == 0L) NA_real_ else processed_records / total_records
  fraction_chunks <- if (is.na(total_chunks) || total_chunks == 0L) NA_real_ else completed_chunks / total_chunks

  structure(
    list(
      run_id = .scalar(row$run_id),
      slug = .scalar(row$slug),
      state = .scalar(row$state),
      terminal = .is_terminal_state(.scalar(row$state)),
      state_source = .scalar(row$state_source),
      scheduler_state = .scalar(row$scheduler_state),
      scheduler_source = .scalar(row$scheduler_source),
      message = .scalar(row$state_detail),
      slurm_job_id = .scalar(row$slurm_job_id),
      slurm_job_name = .scalar(row$slurm_job_name),
      remote_run_dir = .scalar(row$remote_run_dir),
      model_profile = .scalar(row$model_profile),
      submitted_at = .scalar(row$submitted_at),
      last_synced_at = .scalar(row$last_synced_at),
      remote_updated_at = .scalar(row$remote_updated_at),
      progress = list(
        total_records = total_records,
        completed_records = completed_records,
        failed_records = failed_records,
        pending_records = pending_records,
        total_chunks = total_chunks,
        completed_chunks = completed_chunks,
        running_chunks = running_chunks,
        pending_chunks = pending_chunks,
        fraction_records = fraction_records,
        fraction_chunks = fraction_chunks
      ),
      config = config
    ),
    class = "laims_dgx_status"
  )
}

.format_progress_summary <- function(status) {
  p <- status$progress

  records <- if (is.na(p$total_records)) {
    "records ?"
  } else {
    paste0("records ", p$completed_records, "/", p$total_records, " ok, ", p$failed_records, " failed")
  }

  chunks <- if (is.na(p$total_chunks)) {
    "chunks ?"
  } else {
    paste0("chunks ", p$completed_chunks, "/", p$total_chunks, " done, ", p$running_chunks, " running")
  }

  paste(records, chunks, sep = " | ")
}

#' List known runs from the local registry
#'
#' @param state Optional state filter.
#' @param slug Optional slug filter.
#' @param limit Optional maximum number of rows.
#' @param sync Should active jobs be synced with the remote cluster before listing?
#' @param config A `laims_dgx_config` object.
#'
#' @return A `data.frame` of known runs.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' # All runs
#' jobs_list(config = cfg)
#'
#' # Only active runs, synced with the cluster
#' jobs_list(state = c("submitted", "queued", "running"), sync = TRUE, config = cfg)
#'
#' # Filter by slug
#' jobs_list(slug = "clinical-demo", config = cfg)
#' }
#' @export
jobs_list <- function(state = NULL, slug = NULL, limit = NULL, sync = FALSE, config = NULL) {
  config <- .resolve_config(config)

  if (isTRUE(sync)) {
    sync_jobs(state = state %||% c("submitted", "queued", "running"), config = config)
  }

  runs <- .registry_read_runs(config)
  if (nrow(runs) < 1L) {
    return(runs)
  }

  if (!is.null(state)) {
    runs <- runs[runs$state %in% state, , drop = FALSE]
  }

  if (!is.null(slug)) {
    slug <- .sanitize_slug(slug)
    runs <- runs[runs$slug %in% slug, , drop = FALSE]
  }

  ord <- order(runs$created_at, decreasing = TRUE, na.last = TRUE)
  runs <- runs[ord, , drop = FALSE]

  if (!is.null(limit) && nrow(runs) > limit) {
    runs <- utils::head(runs, limit)
  }

  rownames(runs) <- NULL
  runs
}

#' Recover a job handle from the local registry
#'
#' @param run_id Canonical run identifier.
#' @param config A `laims_dgx_config` object.
#'
#' @return An object of class `laims_dgx_job`.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' # List runs to find an id
#' runs <- jobs_list(config = cfg)
#' run_id <- runs$run_id[1]
#'
#' # Recover the job handle (no network call; reads local registry)
#' job <- recover_job(run_id, config = cfg)
#' print(job)
#' }
#' @export
recover_job <- function(run_id, config = NULL) {
  config <- .resolve_config(config)
  row <- .registry_get_run(run_id, config)

  if (nrow(row) < 1L) {
    cli::cli_abort(c(
      "Run not found in local registry.",
      "x" = "Unknown run_id: {.val {run_id}}",
      "i" = "Registry path: {.file {config$registry_path}}"
    ))
  }

  .as_job(row, config)
}

#' Synchronize one run with remote status sources
#'
#' Queries the remote `status.json` and SLURM scheduler (`squeue`/`sacct`) and
#' updates the local registry accordingly.
#'
#' @param job A `run_id` or `laims_dgx_job` object.
#' @param config A `laims_dgx_config` object.
#'
#' @return A refreshed `laims_dgx_job` object.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' job <- recover_job("run-20240101-abcd1234", config = cfg)
#' job <- sync_job(job)
#' print(job)
#' }
#' @export
sync_job <- function(job, config = NULL) {
  if (inherits(job, "laims_dgx_job")) {
    config <- .resolve_config(config %||% job$config)
    run_id <- job$run_id
  } else {
    config <- .resolve_config(config)
    run_id <- as.character(job)[1]
  }

  row <- .registry_get_run(run_id, config)
  if (nrow(row) < 1L) {
    cli::cli_abort("Cannot sync unknown run_id: {.val {run_id}}")
  }

  remote_status <- .probe_remote_status(row, config)
  scheduler_status <- .probe_scheduler_status(row, config)
  merged <- .merge_status_row(row, remote_status, scheduler_status)

  .registry_upsert_run(merged$values, config)

  if (isTRUE(merged$state_changed)) {
    .registry_append_event(
      run_id = run_id,
      event_type = "state_transition",
      state = merged$next_state,
      details = list(
        previous_state = merged$previous_state,
        next_state = merged$next_state,
        source = merged$values$state_source
      ),
      config = config
    )
  } else {
    .registry_append_event(
      run_id = run_id,
      event_type = "sync",
      state = merged$next_state,
      details = list(
        state_source = merged$values$state_source,
        scheduler_state = merged$values$scheduler_state,
        remote_updated_at = merged$values$remote_updated_at
      ),
      config = config
    )
  }

  recover_job(run_id, config = config)
}

#' Synchronize multiple runs
#'
#' Calls [sync_job()] for each run in the given list. When called without
#' `run_ids`, syncs all runs currently in the specified `state` (default:
#' non-terminal active states).
#'
#' @param run_ids Optional explicit vector of run ids.
#' @param state If `run_ids` is missing, sync only runs in these states.
#' @param config A `laims_dgx_config` object.
#'
#' @return A `data.frame` with the refreshed local registry rows.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' # Sync all active runs (submitted / queued / running)
#' sync_jobs(config = cfg)
#'
#' # Sync a specific set of run ids
#' sync_jobs(run_ids = c("run-20240101-abcd1234", "run-20240102-efgh5678"), config = cfg)
#' }
#' @export
sync_jobs <- function(run_ids = NULL, state = c("submitted", "queued", "running"), config = NULL) {
  config <- .resolve_config(config)

  if (is.null(run_ids)) {
    runs <- jobs_list(state = state, sync = FALSE, config = config)
    run_ids <- runs$run_id
  }

  if (length(run_ids) < 1L) {
    return(.registry_read_runs(config))
  }

  for (run_id in unique(as.character(run_ids))) {
    try(sync_job(run_id, config = config), silent = TRUE)
  }

  .registry_read_runs(config)
}

#' Get the current status of a run
#'
#' Returns a `laims_dgx_status` object with state, progress counters, SLURM
#' info, and timestamps. By default it refreshes from the cluster first;
#' pass `refresh = FALSE` for a fast local-only read.
#'
#' @param job A `run_id` or `laims_dgx_job` object.
#' @param refresh Should the function sync against the remote sources first?
#' @param config A `laims_dgx_config` object.
#'
#' @return An object of class `laims_dgx_status`.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' job <- recover_job("run-20240101-abcd1234", config = cfg)
#'
#' # Sync and print status
#' st <- job_status(job)
#' print(st)
#'
#' # Local-only read (no SSH)
#' st <- job_status(job, refresh = FALSE)
#' st$state
#' st$progress$completed_records
#' }
#' @export
job_status <- function(job, refresh = TRUE, config = NULL) {
  if (inherits(job, "laims_dgx_job")) {
    config <- .resolve_config(config %||% job$config)
    run_id <- job$run_id
  } else {
    config <- .resolve_config(config)
    run_id <- as.character(job)[1]
  }

  if (isTRUE(refresh)) {
    sync_job(run_id, config = config)
  }

  row <- .registry_get_run(run_id, config)
  if (nrow(row) < 1L) {
    cli::cli_abort("Unknown run_id: {.val {run_id}}")
  }

  .status_from_row(row, config)
}

#' @export
print.laims_dgx_status <- function(x, ...) {
  cat("<laims_dgx_status>\n", sep = "")
  cat("  run_id  : ", x$run_id, "\n", sep = "")
  cat("  slug    : ", x$slug %||% "<none>", "\n", sep = "")
  cat(
    "  state   : ",
    x$state,
    if (!is.null(x$state_source) && !is.na(x$state_source)) paste0(" (source: ", x$state_source, ")") else "",
    "\n",
    sep = ""
  )
  cat(
    "  slurm   : ",
    x$slurm_job_id %||% "<unknown>",
    if (!is.null(x$slurm_job_name) && !is.na(x$slurm_job_name)) paste0(" [", x$slurm_job_name, "]") else "",
    "\n",
    sep = ""
  )
  cat("  progress: ", .format_progress_summary(x), "\n", sep = "")
  cat("  synced  : ", x$last_synced_at %||% "<never>", "\n", sep = "")
  if (!is.null(x$remote_updated_at) && !is.na(x$remote_updated_at) && !identical(x$remote_updated_at, "")) {
    cat("  remote  : ", x$remote_updated_at, "\n", sep = "")
  }
  if (!is.null(x$message) && !is.na(x$message) && !identical(x$message, "")) {
    cat("  message : ", x$message, "\n", sep = "")
  }
  invisible(x)
}

#' Show static or live progress for a run
#'
#' Prints a formatted status line. When `watch = TRUE`, polls the cluster until
#' the run reaches a terminal state (completed, failed, cancelled), printing a
#' timestamped update on each iteration.
#'
#' @param job A `run_id` or `laims_dgx_job` object.
#' @param watch If `TRUE`, keep polling until the run reaches a terminal state.
#' @param interval Polling interval in seconds when `watch = TRUE`.
#' @param refresh Should each update resync against remote sources?
#' @param max_updates Optional cap for watch iterations.
#' @param config A `laims_dgx_config` object.
#'
#' @return Invisibly returns the latest `laims_dgx_status` object.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' job <- submit_job(bundle, config = cfg)
#'
#' # Single status print
#' progress(job)
#'
#' # Poll every 30 seconds until done
#' status <- progress(job, watch = TRUE, interval = 30, config = cfg)
#' if (status$state == "completed") {
#'   results <- collect_results(job, config = cfg)
#' }
#' }
#' @export
progress <- function(job, watch = FALSE, interval = NULL, refresh = TRUE, max_updates = Inf, config = NULL) {
  if (!isTRUE(watch)) {
    status <- job_status(job, refresh = refresh, config = config)
    print(status)
    return(invisible(status))
  }

  if (inherits(job, "laims_dgx_job")) {
    config <- .resolve_config(config %||% job$config)
  } else {
    config <- .resolve_config(config)
  }

  interval <- interval %||% config$poll_interval
  iteration <- 0L

  repeat {
    status <- job_status(job, refresh = refresh, config = config)
    line <- paste0(
      "[", .timestamp_utc(), "] ",
      status$run_id, " | ",
      status$state, " | ",
      .format_progress_summary(status),
      if (!is.null(status$message) && !is.na(status$message) && !identical(status$message, "")) paste0(" | ", status$message) else ""
    )
    cat(line, "\n", sep = "")
    utils::flush.console()

    iteration <- iteration + 1L
    if (isTRUE(status$terminal) || iteration >= max_updates) {
      break
    }

    Sys.sleep(interval)
  }

  invisible(status)
}
