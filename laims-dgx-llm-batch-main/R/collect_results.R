#' Collect structured results from a completed batch run
#'
#' Read output artifacts produced by the remote job and convert them into
#' analyst-friendly R objects.
#'
#' Typical artifacts include `predictions.jsonl`, `errors.jsonl`, run summary
#' metadata, and raw scheduler logs.
#'
#' @param job A job handle returned by [submit_job()] or a `run_id`.
#' @param remote_output_dir Optional explicit remote output directory.
#' @param local_dir Optional local directory where outputs should be copied.
#' @param parse Logical; if `TRUE`, parse JSONL into R objects. If `FALSE`,
#'   return file paths only.
#' @param collect_fun Optional function used to retrieve files from the remote
#'   system.
#' @param config A `laims_dgx_config` object. If `NULL`, uses [dgx_config()].
#'
#' @return An object of class `laims_dgx_results`.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' # Typical workflow: submit → wait → collect
#' job <- extract_batch(
#'   records         = my_records,
#'   id_col          = "id",
#'   text_col        = "note",
#'   prompt_template = "Summarise this clinical note in one sentence.",
#'   schema          = list(
#'     type       = "object",
#'     properties = list(summary = list(type = "string")),
#'     required   = I("summary")
#'   ),
#'   model  = "20B",
#'   config = cfg
#' )
#'
#' # Poll until done, then collect
#' progress(job, watch = TRUE, config = cfg)
#' results <- collect_results(job, config = cfg)
#' print(results)
#'
#' # Access predictions as a data frame
#' preds <- results$parsed$predictions
#' head(preds[, c("record_id", "parsed_json")])
#'
#' # Recover and collect an old run by id
#' job2 <- recover_job("run-20240101-abcd1234", config = cfg)
#' results2 <- collect_results(job2, config = cfg)
#' }
#' @export
collect_results <- function(job,
                            remote_output_dir = NULL,
                            local_dir = NULL,
                            parse = TRUE,
                            collect_fun = NULL,
                            config = NULL) {
  job_info <- .collect_job_info(job, config = config)
  config <- job_info$config
  local_dir <- fs::path_abs(local_dir %||% fs::path(config$results_dir, job_info$run_id))
  fs::dir_create(local_dir)

  remote_output_dir <- remote_output_dir %||% job_info$remote_output_dir
  remote_files <- list(
    status = job_info$remote_status_path,
    predictions = if (!is.na(remote_output_dir)) paste(remote_output_dir, "predictions.jsonl", sep = "/") else job_info$remote_predictions_path,
    errors = if (!is.na(remote_output_dir)) paste(remote_output_dir, "errors.jsonl", sep = "/") else job_info$remote_errors_path,
    summary = if (!is.na(remote_output_dir)) paste(remote_output_dir, "run_summary.json", sep = "/") else job_info$remote_summary_path
  )

  local_files <- list(
    status = .prefer_existing_file(c(
      fs::path(local_dir, "status.json"),
      fs::path(job_info$local_run_dir, "status.json")
    )),
    predictions = .prefer_existing_file(c(fs::path(local_dir, "predictions.jsonl"))),
    errors = .prefer_existing_file(c(fs::path(local_dir, "errors.jsonl"))),
    summary = .prefer_existing_file(c(fs::path(local_dir, "run_summary.json")))
  )

  if (is.function(collect_fun)) {
    collected <- collect_fun(job_info, remote_files, local_dir)
    if (is.list(collected)) {
      local_files <- utils::modifyList(local_files, collected)
    }
  } else {
    local_files <- .collect_remote_files_if_needed(
      local_files = local_files,
      remote_files = remote_files,
      local_dir = local_dir,
      config = config
    )
  }

  exists <- vapply(local_files, function(path) !is.null(path) && !is.na(path) && file.exists(path), logical(1))

  parsed <- if (isTRUE(parse)) {
    list(
      status = if (exists[["status"]]) jsonlite::read_json(local_files$status, simplifyVector = FALSE) else NULL,
      predictions = if (exists[["predictions"]]) .parse_jsonl_file(local_files$predictions) else NULL,
      errors = if (exists[["errors"]]) .parse_jsonl_file(local_files$errors) else NULL,
      summary = if (exists[["summary"]]) jsonlite::read_json(local_files$summary, simplifyVector = FALSE) else NULL
    )
  } else {
    NULL
  }

  status_state <- .deep_get(parsed$status, "state", default = job_info$state)
  summary_state <- .deep_get(parsed$summary, "state", default = status_state)
  should_mark_collected <- any(exists[c("predictions", "errors", "summary")]) &&
    (summary_state %in% c("completed", "collected") || status_state %in% c("completed", "collected") || job_info$state %in% c("completed", "collected"))

  .registry_upsert_run(
    list(
      run_id = job_info$run_id,
      state = if (isTRUE(should_mark_collected)) "collected" else job_info$state,
      collected_at = if (isTRUE(should_mark_collected)) .timestamp_utc() else NA_character_,
      local_results_dir = local_dir,
      state_source = if (isTRUE(should_mark_collected)) "collect" else job_info$state_source,
      remote_status_path = remote_files$status,
      remote_predictions_path = remote_files$predictions,
      remote_errors_path = remote_files$errors,
      remote_summary_path = remote_files$summary
    ),
    config = config
  )

  .registry_append_event(
    run_id = job_info$run_id,
    event_type = "collect_results",
    state = if (isTRUE(should_mark_collected)) "collected" else job_info$state,
    details = list(
      local_results_dir = local_dir,
      files_present = as.list(exists)
    ),
    config = config
  )

  structure(
    list(
      run_id = job_info$run_id,
      state = if (isTRUE(should_mark_collected)) "collected" else job_info$state,
      local_dir = local_dir,
      files = local_files,
      exists = exists,
      parsed = parsed,
      parse = isTRUE(parse),
      config = config
    ),
    class = "laims_dgx_results"
  )
}

.collect_job_info <- function(job, config = NULL) {
  if (inherits(job, "laims_dgx_job")) {
    config <- .resolve_config(config %||% job$config)
    row <- .registry_get_run(job$run_id, config)
  } else if (is.character(job) && length(job) == 1L && !dir.exists(job)) {
    config <- .resolve_config(config)
    row <- .registry_get_run(job, config)
  } else {
    bundle_info <- .as_bundle_info(job, config = config)
    row <- .registry_get_run(bundle_info$run_id, bundle_info$config)
    config <- bundle_info$config
  }

  if (nrow(row) < 1L) {
    cli::cli_abort("Cannot collect results for an unknown run.")
  }

  list(
    run_id = .scalar(row$run_id),
    state = .scalar(row$state),
    state_source = .scalar(row$state_source),
    remote_run_dir = .scalar(row$remote_run_dir),
    remote_output_dir = if (is.na(.scalar(row$remote_run_dir))) NA_character_ else paste(.scalar(row$remote_run_dir), "output", sep = "/"),
    remote_status_path = .scalar(row$remote_status_path),
    remote_predictions_path = .scalar(row$remote_predictions_path),
    remote_errors_path = .scalar(row$remote_errors_path),
    remote_summary_path = .scalar(row$remote_summary_path),
    local_run_dir = .scalar(row$local_run_dir),
    local_results_dir = .scalar(row$local_results_dir),
    config = config
  )
}

.prefer_existing_file <- function(paths) {
  paths <- paths[!is.na(paths) & !is.null(paths)]
  hit <- paths[file.exists(paths)][1]
  if (length(hit) < 1L || is.na(hit)) {
    return(fs::path_abs(paths[[1]]))
  }
  fs::path_abs(hit)
}

.collect_remote_files_if_needed <- function(local_files, remote_files, local_dir, config) {
  for (name in names(local_files)) {
    if (file.exists(local_files[[name]])) {
      next
    }

    remote_path <- remote_files[[name]]
    if (is.null(remote_path) || is.na(remote_path) || identical(trimws(remote_path), "") || identical(.ssh_destination(config), "")) {
      next
    }

    local_path <- fs::path(local_dir, basename(remote_path))
    copied <- .scp_fetch_file(config, remote_path = remote_path, local_path = local_path)
    local_files[[name]] <- if (isTRUE(copied)) local_path else local_files[[name]]
  }

  local_files
}

.scp_fetch_file <- function(config, remote_path, local_path) {
  destination <- .ssh_destination(config)
  result <- tryCatch(
    processx::run(
      command = config$scp_bin,
      args = c(.ssh_cli_args(config), paste0(destination, ":", remote_path), local_path),
      error_on_status = FALSE,
      echo = FALSE
    ),
    error = function(e) {
      list(status = 1L, stdout = "", stderr = conditionMessage(e))
    }
  )

  identical(result$status, 0L) && file.exists(local_path)
}

.read_jsonl <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }

  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  if (length(lines) < 1L) {
    return(list())
  }

  lapply(lines, function(line) jsonlite::fromJSON(line, simplifyVector = FALSE))
}

.parse_jsonl_file <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  if (length(lines) < 1L) {
    return(data.frame())
  }

  streamed <- tryCatch(
    jsonlite::stream_in(textConnection(paste(lines, collapse = "\n")), verbose = FALSE),
    error = function(e) NULL
  )
  if (!is.null(streamed)) {
    return(streamed)
  }

  .read_jsonl(path)
}

#' @export
print.laims_dgx_results <- function(x, ...) {
  cat("<laims_dgx_results>\n", sep = "")
  cat("  run_id    : ", x$run_id, "\n", sep = "")
  cat("  state     : ", x$state, "\n", sep = "")
  cat("  local_dir : ", x$local_dir, "\n", sep = "")
  present <- names(x$exists)[x$exists]
  cat("  files     : ", if (length(present) < 1L) "<none>" else paste(present, collapse = ", "), "\n", sep = "")
  invisible(x)
}
