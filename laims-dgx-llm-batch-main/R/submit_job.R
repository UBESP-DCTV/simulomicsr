#' Submit a SLURM batch job for DGX LLM inference
#'
#' Render a generic SLURM submission script from the package template, stage a
#' bundle to the remote environment, and call `sbatch`.
#'
#' The goal is to keep the user-facing interface in R while using the cluster's
#' native batch workflow underneath.
#'
#' @param bundle Bundle object or local bundle path created by
#'   [create_bundle()].
#' @param submit Logical; if `TRUE`, run `sbatch`. If `FALSE`, only render the
#'   script and return the command preview.
#' @param slurm Named list with scheduler parameters such as `partition`,
#'   `account`, `nodelist`, `nodes`, `mail_user`, `cpus`, `mem`, and `time`.
#'   GPU count is fixed to 1 and is not user-configurable. `nodes` defaults to
#'   1 and is enforced so every job stays on a single DGX node. `mail_user`
#'   inherits from `dgx_config(mail_user = ...)` unless overridden here; it is
#'   optional for dry runs but required for real submission.
#' @param remote_bundle_dir Remote path where the bundle should be staged.
#' @param remote_output_dir Remote path where outputs should be written.
#' @param sif_path Optional path to the Singularity/Apptainer image on the
#'   remote side. An explicit value always wins and is treated as an external
#'   runtime override. Otherwise runtime resolution follows `dgx_config()`
#'   (`managed` or `external`). For `submit = FALSE`, managed mode reports
#'   whether the runtime still needs an `ensure_runtime()` step.
#' @param template Path to a SLURM template. Defaults to the installed package
#'   template under `inst/templates/submit_slurm.sh`.
#' @param stage_fun Optional function responsible for copying the bundle to the
#'   remote environment.
#' @param config A `laims_dgx_config` object. If `NULL`, uses [dgx_config()].
#'
#' @return A `laims_dgx_job` object if submitted, otherwise a
#'   `laims_dgx_submit_plan` object.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' bundle <- create_bundle(
#'   records         = data.frame(id = "r1", text = "Hello world."),
#'   id_col          = "id",
#'   text_col        = "text",
#'   prompt_template = "Summarise.",
#'   schema          = list(
#'     type = "object",
#'     properties = list(result = list(type = "string")),
#'     required = I("result")
#'   ),
#'   model  = "20B",
#'   config = cfg
#' )
#'
#' # Dry run: render the SLURM script without submitting
#' plan <- submit_job(bundle, submit = FALSE, config = cfg)
#' cat(plan$rendered_script)
#'
#' # Real submission
#' job <- submit_job(bundle, config = cfg)
#' print(job)
#'
#' # Override time limit for a larger run
#' job <- submit_job(
#'   bundle,
#'   slurm  = list(time = "02:00:00"),
#'   config = cfg
#' )
#' }
#' @export
submit_job <- function(bundle,
                       submit = TRUE,
                       slurm = list(),
                       remote_bundle_dir = NULL,
                       remote_output_dir = NULL,
                       sif_path = NULL,
                       template = NULL,
                       stage_fun = NULL,
                       config = NULL) {
  bundle_info <- .as_bundle_info(bundle, config = config)
  config <- bundle_info$config

  if (is.null(template)) {
    template <- .package_file("templates", "submit_slurm.sh")
  }

  remote_run_dir <- .remote_run_dir_for(bundle_info$run_id, remote_bundle_dir = remote_bundle_dir, config = config)
  remote_bundle_dir <- .absolute_remote_path(
    remote_bundle_dir %||% paste(remote_run_dir, "bundle", sep = "/"),
    base_dir = remote_run_dir
  )
  remote_output_dir <- .absolute_remote_path(
    remote_output_dir %||% paste(remote_run_dir, "output", sep = "/"),
    base_dir = remote_run_dir
  )

  model_spec <- .model_spec(bundle_info$model %||% bundle_info$model_profile)
  runtime <- .resolve_runtime_for_submit(
    sif_path = sif_path,
    config = config,
    model = model_spec$model,
    submit = isTRUE(submit)
  )
  slurm_merged <- .merge_slurm_defaults(
    model_slurm = model_spec$recommended_slurm %||% list(),
    config_slurm = config$job_resources %||% list(),
    slurm = slurm
  )
  slurm_merged <- .normalize_slurm_args(slurm_merged)
  slurm_merged$job_name <- slurm_merged$job_name %||% .make_slurm_job_name(bundle_info$run_id, bundle_info$slug)
  time_preflight <- .estimate_job_time_preflight(
    bundle = bundle_info$bundle,
    requested_time = slurm_merged$time,
    model = model_spec$model
  )
  slurm_stdout_path <- paste(remote_run_dir, "slurm-%j.out", sep = "/")
  slurm_stderr_path <- paste(remote_run_dir, "slurm-%j.err", sep = "/")
  launch_paths <- .derive_submit_launch_paths(config)

  rendered_script <- .render_slurm_script(
    template = template,
    values = list(
      job_name = slurm_merged$job_name,
      partition = slurm_merged$partition,
      account = slurm_merged$account,
      nodelist = slurm_merged$nodelist,
      nodes = slurm_merged$nodes,
      mail_user = slurm_merged$mail_user,
      gpus = slurm_merged$gpus,
      cpus = slurm_merged$cpus,
      mem = slurm_merged$mem,
      time = slurm_merged$time,
      mail_type = slurm_merged$mail_type,
      run_path = remote_run_dir,
      bundle_path = remote_bundle_dir,
      output_path = remote_output_dir,
      home_path = launch_paths$home_path,
      hf_cache_path = launch_paths$hf_cache_path,
      container_home = launch_paths$container_home,
      container_hf_cache = launch_paths$container_hf_cache,
      slurm_output_path = slurm_stdout_path,
      slurm_error_path = slurm_stderr_path,
      sif_path = runtime$sif_path,
      apptainer_bin = config$apptainer_bin %||% "/cm/shared/apps/singularity/4.2.0/bin/singularity"
    )
  )

  local_script_path <- fs::path(bundle_info$bundle_dir, "submit_slurm.sh")
  writeLines(rendered_script, local_script_path, useBytes = TRUE)

  preflight <- structure(
    list(
      run_id = bundle_info$run_id,
      slug = bundle_info$slug,
      model = model_spec$model,
      state = if (isTRUE(submit)) "prepared" else "created",
      bundle = bundle_info$bundle,
      bundle_dir = bundle_info$bundle_dir,
      local_script_path = local_script_path,
      rendered_script = rendered_script,
      remote_run_dir = remote_run_dir,
      remote_bundle_dir = remote_bundle_dir,
      remote_output_dir = remote_output_dir,
      remote_home_dir = launch_paths$home_path,
      remote_hf_cache_dir = launch_paths$hf_cache_path,
      remote_slurm_stdout_path = slurm_stdout_path,
      remote_slurm_stderr_path = slurm_stderr_path,
      remote_status_path = paste(remote_run_dir, "status.json", sep = "/"),
      remote_predictions_path = paste(remote_output_dir, "predictions.jsonl", sep = "/"),
      remote_errors_path = paste(remote_output_dir, "errors.jsonl", sep = "/"),
      remote_summary_path = paste(remote_output_dir, "run_summary.json", sep = "/"),
      sif_path = runtime$sif_path,
      sif_path_source = runtime$source,
      sif_path_required = isTRUE(submit),
      runtime = runtime,
      runtime_mode = runtime$mode,
      runtime_ready = runtime$ready,
      runtime_action = runtime$action,
      runtime_stale = runtime$stale,
      slurm = slurm_merged,
      time_preflight = time_preflight,
      submit = isTRUE(submit),
      config = config,
      submit_command = sprintf(
        "%s %s %s %s",
        config$ssh_bin,
        paste(shQuote(.ssh_cli_args_preview(config)), collapse = " "),
        shQuote(.ssh_destination(config)),
        shQuote(.ssh_login_shell_command(sprintf("cd %s && sbatch submit_slurm.sh", remote_run_dir)))
      )
    ),
    class = "laims_dgx_submit_plan"
  )

  if (length(time_preflight$warnings) > 0L) {
    warning_lines <- time_preflight$warnings
    names(warning_lines) <- rep("!", length(warning_lines))
    cli::cli_warn(c(
      "SLURM time preflight produced warnings.",
      warning_lines
    ))
  }

  if (!isTRUE(submit)) {
    return(preflight)
  }

  .ensure_submit_ready(config = config, sif_path = runtime$sif_path, slurm = slurm_merged)

  if (is.function(stage_fun)) {
    stage_result <- stage_fun(preflight)
  } else {
    stage_result <- .stage_bundle_remote(preflight)
  }

  submit_result <- .ssh_capture(
    config,
    paste("cd", shQuote(remote_run_dir), "&& sbatch submit_slurm.sh")
  )

  if (!isTRUE(submit_result$ok)) {
    .registry_upsert_run(
      list(
        run_id = bundle_info$run_id,
        state = "failed",
        state_source = "submit",
        state_detail = submit_result$stderr %||% submit_result$stdout,
        failed_at = .timestamp_utc(),
        local_run_dir = bundle_info$bundle_dir,
        remote_run_dir = remote_run_dir,
        remote_bundle_dir = remote_bundle_dir,
        remote_status_path = preflight$remote_status_path,
        remote_predictions_path = preflight$remote_predictions_path,
        remote_errors_path = preflight$remote_errors_path,
        remote_summary_path = preflight$remote_summary_path,
        model_profile = bundle_info$model_profile,
        slurm_job_name = slurm_merged$job_name
      ),
      config = config
    )
    cli::cli_abort(c(
      "SLURM submission failed.",
      "x" = submit_result$stderr %||% submit_result$stdout
    ))
  }

  slurm_job_id <- .parse_sbatch_job_id(submit_result$stdout)
  now <- .timestamp_utc()

  .registry_upsert_run(
    list(
      run_id = bundle_info$run_id,
      slug = bundle_info$slug,
      state = if (is.na(slurm_job_id)) "staged" else "submitted",
      state_source = "submit",
      state_detail = submit_result$stdout %||% "Bundle staged remotely",
      created_at = bundle_info$created_at,
      submitted_at = if (is.na(slurm_job_id)) NA_character_ else now,
      updated_at = now,
      login_host = config$login_host,
      login_user = config$login_user,
      remote_run_dir = remote_run_dir,
      remote_bundle_dir = remote_bundle_dir,
      remote_status_path = preflight$remote_status_path,
      remote_predictions_path = preflight$remote_predictions_path,
      remote_errors_path = preflight$remote_errors_path,
      remote_summary_path = preflight$remote_summary_path,
      local_run_dir = bundle_info$bundle_dir,
      model_profile = bundle_info$model_profile,
      container_image = runtime$sif_path,
      slurm_job_id = slurm_job_id,
      slurm_job_name = slurm_merged$job_name,
      slurm_partition = slurm_merged$partition,
      slurm_account = slurm_merged$account,
      total_records = bundle_info$record_count,
      total_chunks = bundle_info$chunk_count
    ),
    config = config
  )

  .registry_append_event(
    run_id = bundle_info$run_id,
    event_type = "submitted",
    state = if (is.na(slurm_job_id)) "staged" else "submitted",
    details = list(
      stage = stage_result,
      sbatch_stdout = submit_result$stdout,
      sbatch_stderr = submit_result$stderr,
      slurm_job_id = slurm_job_id
    ),
    config = config
  )

  recover_job(bundle_info$run_id, config = config)
}

.as_bundle_info <- function(bundle, config = NULL) {
  if (inherits(bundle, "laims_dgx_bundle")) {
    config <- .resolve_config(config %||% bundle$config)
    return(list(
      bundle = bundle,
      run_id = bundle$run_id,
      slug = bundle$slug,
      bundle_dir = bundle$bundle_dir,
      model = bundle$model %||% bundle$model_profile,
      model_profile = bundle$model %||% bundle$model_profile,
      created_at = bundle$run_meta$created_at %||% .timestamp_utc(),
      record_count = bundle$manifest$record_count %||% NA_integer_,
      chunk_count = bundle$manifest$chunk_count %||% NA_integer_,
      config = config
    ))
  }

  bundle_dir <- fs::path_abs(as.character(bundle)[1])
  manifest_path <- fs::path(bundle_dir, "manifest.json")
  run_meta_path <- fs::path(bundle_dir, "run_meta.json")

  if (!file.exists(manifest_path) || !file.exists(run_meta_path)) {
    cli::cli_abort(c(
      "Cannot resolve bundle directory.",
      "x" = "Expected {.file manifest.json} and {.file run_meta.json} under {.file {bundle_dir}}"
    ))
  }

  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  run_meta <- jsonlite::read_json(run_meta_path, simplifyVector = FALSE)
  config <- .resolve_config(config)

  bundle_obj <- structure(
    list(
      run_id = manifest$run_id,
      slug = manifest$slug,
      state = run_meta$state %||% "created",
      bundle_dir = bundle_dir,
      local_run_dir = bundle_dir,
      manifest = manifest,
      run_meta = run_meta,
      model = manifest$model %||% run_meta$model %||% manifest$model_profile %||% run_meta$model_profile,
      model_profile = manifest$model %||% run_meta$model %||% manifest$model_profile %||% run_meta$model_profile,
      generation = run_meta$generation %||% list(),
      metadata = run_meta$metadata %||% list(),
      chunk_plan = .read_chunk_plan(fs::path(bundle_dir, "chunk_plan.jsonl")),
      files = list(
        records = fs::path(bundle_dir, "records.jsonl"),
        prompt = fs::path(bundle_dir, "prompt.txt"),
        schema = fs::path(bundle_dir, "schema.json"),
        generation = fs::path(bundle_dir, "generation.json"),
        manifest = manifest_path,
        run_meta = run_meta_path,
        chunk_plan = fs::path(bundle_dir, "chunk_plan.jsonl"),
        status = fs::path(bundle_dir, "status.json")
      ),
      config = config
    ),
    class = "laims_dgx_bundle"
  )

  list(
    bundle = bundle_obj,
    run_id = bundle_obj$run_id,
    slug = bundle_obj$slug,
    bundle_dir = bundle_dir,
    model = bundle_obj$model %||% bundle_obj$model_profile,
    model_profile = bundle_obj$model %||% bundle_obj$model_profile,
    created_at = run_meta$created_at %||% .timestamp_utc(),
    record_count = manifest$record_count %||% NA_integer_,
    chunk_count = manifest$chunk_count %||% NA_integer_,
    config = config
  )
}

.remote_run_dir_for <- function(run_id, remote_bundle_dir = NULL, config) {
  if (!is.null(remote_bundle_dir) && nzchar(remote_bundle_dir)) {
    parent <- fs::path_dir(remote_bundle_dir)
    if (!identical(parent, ".")) {
      return(.absolute_remote_path(parent, base_dir = config$remote_base_dir))
    }
  }

  .absolute_remote_path(paste(config$remote_base_dir, run_id, sep = "/"))
}

.normalize_sif_path <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }

  value <- trimws(as.character(x)[1])
  if (identical(value, "") || is.na(value)) {
    return(NA_character_)
  }

  value
}

.absolute_remote_path <- function(path, base_dir = NULL) {
  path <- .trim_scalar(path)
  base_dir <- .trim_scalar(base_dir)

  if (identical(path, "")) {
    return(path)
  }
  if (startsWith(path, "/")) {
    return(sub("/+$", "", path))
  }
  if (!identical(base_dir, "")) {
    return(sub("/+$", "", paste(base_dir, path, sep = "/")))
  }

  path
}

.resolve_runtime_for_submit <- function(sif_path = NULL, config, model = "20B", submit = FALSE) {
  explicit <- .normalize_sif_path(sif_path)
  if (!is.na(explicit)) {
    return(ensure_runtime(model = model, sif_path = explicit, dry_run = !isTRUE(submit), config = config))
  }

  if (identical(config$runtime$mode, "external")) {
    return(ensure_runtime(model = model, dry_run = !isTRUE(submit), config = config))
  }

  ensure_runtime(model = model, dry_run = !isTRUE(submit), config = config)
}

.merge_slurm_defaults <- function(model_slurm = list(), config_slurm = list(), slurm = list()) {
  defaults <- list(
    partition = "dgx12cluster",
    account = "dctv_dgx",
    nodelist = "poddgx02",
    nodes = 1,
    mail_type = "ALL",
    gpus = 1,
    cpus = 4,
    mem = "32G",
    time = "00:05:00"
  )

  out <- utils::modifyList(defaults, model_slurm %||% list())
  out <- utils::modifyList(out, config_slurm %||% list())
  out <- utils::modifyList(out, slurm %||% list())
  .normalize_slurm_args(out)
}

.normalize_slurm_args <- function(slurm) {
  out <- slurm
  requested_gpus <- out$gpus %||% 1L
  out$partition <- .trim_scalar_value(out$partition %||% "dgx12cluster")
  out$account <- .trim_scalar_value(out$account %||% "dctv_dgx")
  out$nodelist <- .trim_scalar_value(out$nodelist %||% "poddgx02")
  out$nodes <- as.integer(out$nodes %||% 1L)
  out$mail_user <- .trim_scalar_value(out$mail_user %||% "")
  out$mail_type <- .trim_scalar_value(out$mail_type %||% "ALL")
  out$gpus <- 1L
  out$cpus <- as.integer(out$cpus %||% 4L)
  out$mem <- as.character(out$mem %||% "32G")
  out$time <- .trim_scalar_value(out$time %||% "00:05:00")

  if (!is.null(requested_gpus) && !is.na(suppressWarnings(as.integer(requested_gpus))) && as.integer(requested_gpus) != 1L) {
    cli::cli_abort("`slurm$gpus` is not user-configurable; GPU count is fixed to 1.")
  }
  if (identical(out$partition, "")) {
    cli::cli_abort("`slurm$partition` must be a non-empty string.")
  }
  if (identical(out$account, "")) {
    cli::cli_abort("`slurm$account` must be a non-empty string.")
  }
  if (identical(out$nodelist, "")) {
    cli::cli_abort("`slurm$nodelist` must be a non-empty string.")
  }
  if (is.na(out$nodes) || out$nodes != 1L) {
    cli::cli_abort("`slurm$nodes` is fixed to 1 so jobs stay on a single DGX node.")
  }
  if (!identical(out$mail_user, "") && !grepl("@", out$mail_user, fixed = TRUE)) {
    cli::cli_abort("`slurm$mail_user` must look like an email address when provided.")
  }
  if (identical(out$mail_type, "")) {
    cli::cli_abort("`slurm$mail_type` must be a non-empty string.")
  }
  if (is.na(out$cpus) || out$cpus < 1L) {
    cli::cli_abort("`slurm$cpus` must be a positive integer.")
  }
  if (identical(trimws(out$mem), "")) {
    cli::cli_abort("`slurm$mem` must be a non-empty memory string.")
  }
  if (identical(out$time, "")) {
    cli::cli_abort("`slurm$time` must always be set.")
  }
  if (!grepl("^[0-9]{2,}:[0-9]{2}:[0-9]{2}$", out$time)) {
    cli::cli_abort("`slurm$time` must use `HH:MM:SS` format.")
  }

  out
}

.derive_submit_launch_paths <- function(config) {
  login_user <- .trim_scalar(config$login_user %||% "")
  user_root <- .normalize_remote_path(config$user_root)
  if (is.na(user_root)) {
    user_root <- .default_user_root(login_user = login_user)
  }

  container_home <- if (identical(login_user, "")) "/home/laims" else paste("/home", login_user, sep = "/")

  list(
    home_path = paste(user_root, "runtime/home", sep = "/"),
    hf_cache_path = paste(user_root, "runtime/cache/huggingface", sep = "/"),
    container_home = container_home,
    container_hf_cache = "/opt/laims/cache/huggingface"
  )
}

.render_slurm_script <- function(template, values) {
  script <- paste(readLines(template, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  replacements <- list(
    "__JOB_NAME__" = values$job_name,
    "__PARTITION__" = values$partition,
    "__ACCOUNT__" = values$account %||% "",
    "__NODELIST__" = values$nodelist %||% "",
    "__NODES__" = as.character(values$nodes %||% 1L),
    "__SBATCH_MAIL_USER__" = if (!identical(values$mail_user %||% "", "")) paste0("#SBATCH --mail-user=", values$mail_user) else "",
    "__SBATCH_MAIL_TYPE__" = if (!identical(values$mail_user %||% "", "")) paste0("#SBATCH --mail-type=", values$mail_type %||% "ALL") else "",
    "__GPUS__" = as.character(values$gpus),
    "__CPUS__" = as.character(values$cpus),
    "__MEM__" = values$mem,
    "__TIME__" = values$time,
    "__RUN_PATH__" = values$run_path,
    "__BUNDLE_PATH__" = values$bundle_path,
    "__OUTPUT_PATH__" = values$output_path,
    "__HOME_PATH__" = values$home_path,
    "__HF_CACHE_PATH__" = values$hf_cache_path,
    "__CONTAINER_HOME__" = values$container_home,
    "__CONTAINER_HF_CACHE__" = values$container_hf_cache,
    "__SLURM_OUTPUT_PATH__" = values$slurm_output_path,
    "__SLURM_ERROR_PATH__" = values$slurm_error_path,
    "__SIF_PATH__" = values$sif_path %||% "",
    "__APPTAINER_BIN__" = values$apptainer_bin %||% "/cm/shared/apps/singularity/4.2.0/bin/singularity"
  )

  for (needle in names(replacements)) {
    script <- gsub(needle, replacements[[needle]], script, fixed = TRUE)
  }

  script <- gsub("\n{3,}", "\n\n", script, perl = TRUE)
  paste0(sub("\n+$", "", script), "\n")
}

.slurm_time_to_seconds <- function(x) {
  x <- .trim_scalar_value(x)
  parts <- strsplit(x, ":", fixed = TRUE)[[1]]
  if (length(parts) != 3L) {
    return(NA_real_)
  }

  hours <- suppressWarnings(as.numeric(parts[[1]]))
  minutes <- suppressWarnings(as.numeric(parts[[2]]))
  seconds <- suppressWarnings(as.numeric(parts[[3]]))
  if (any(is.na(c(hours, minutes, seconds)))) {
    return(NA_real_)
  }

  (hours * 3600) + (minutes * 60) + seconds
}

.seconds_to_slurm_time <- function(seconds) {
  seconds <- ceiling(as.numeric(seconds %||% 0))
  seconds <- max(0, seconds)
  hours <- floor(seconds / 3600)
  minutes <- floor((seconds %% 3600) / 60)
  secs <- seconds %% 60
  sprintf("%02d:%02d:%02d", hours, minutes, secs)
}

.estimate_job_time_preflight <- function(bundle, requested_time, model) {
  chunk_plan <- bundle$chunk_plan %||% data.frame()
  record_count <- bundle$manifest$record_count %||% nrow(chunk_plan) %||% NA_integer_
  chunk_count <- if (nrow(chunk_plan) > 0L) nrow(chunk_plan) else NA_integer_
  total_tokens <- if (nrow(chunk_plan) > 0L && "estimated_tokens" %in% names(chunk_plan)) {
    sum(chunk_plan$estimated_tokens, na.rm = TRUE)
  } else {
    NA_real_
  }
  profile <- switch(
    as.character(model %||% "20B"),
    "120B" = list(
      startup_seconds = 120,
      per_chunk_seconds = 30,
      per_record_seconds = 2,
      tokens_per_second = 180
    ),
    list(
      startup_seconds = 90,
      per_chunk_seconds = 20,
      per_record_seconds = 1.5,
      tokens_per_second = 350
    )
  )

  estimated_seconds <- profile$startup_seconds
  if (!is.na(chunk_count)) {
    estimated_seconds <- estimated_seconds + (chunk_count * profile$per_chunk_seconds)
  }
  if (!is.na(record_count)) {
    estimated_seconds <- estimated_seconds + (record_count * profile$per_record_seconds)
  }
  if (!is.na(total_tokens)) {
    estimated_seconds <- estimated_seconds + (total_tokens / profile$tokens_per_second)
  }

  buffered_seconds <- max(300, ceiling((estimated_seconds + 60) * 1.2))
  requested_seconds <- .slurm_time_to_seconds(requested_time)
  suggested_seconds <- ceiling(buffered_seconds / 300) * 300
  warnings <- character()
  status <- "ok"

  if (!is.na(requested_seconds) && requested_seconds < (buffered_seconds * 0.8)) {
    status <- "too_low"
    warnings <- c(
      warnings,
      sprintf(
        "Requested time %s looks too low for a %s run with about %s records, %s chunks, and %s estimated tokens.",
        requested_time,
        model,
        if (is.na(record_count)) "unknown" else format(record_count, trim = TRUE),
        if (is.na(chunk_count)) "unknown" else format(chunk_count, trim = TRUE),
        if (is.na(total_tokens)) "unknown" else format(round(total_tokens), big.mark = ",", trim = TRUE)
      ),
      sprintf("Heuristic estimate is roughly %s; consider requesting at least %s.", .seconds_to_slurm_time(buffered_seconds), .seconds_to_slurm_time(suggested_seconds))
    )
  } else if (!is.na(requested_seconds) && requested_seconds > max(buffered_seconds * 3, buffered_seconds + 7200)) {
    status <- "suspiciously_high"
    warnings <- c(
      warnings,
      sprintf(
        "Requested time %s looks generous relative to the heuristic estimate of about %s.",
        requested_time,
        .seconds_to_slurm_time(buffered_seconds)
      )
    )
  }

  list(
    status = status,
    requested_time = requested_time,
    requested_seconds = requested_seconds,
    estimated_seconds = buffered_seconds,
    estimated_time = .seconds_to_slurm_time(buffered_seconds),
    suggested_time = .seconds_to_slurm_time(suggested_seconds),
    record_count = record_count,
    chunk_count = chunk_count,
    estimated_tokens = if (is.na(total_tokens)) NA_real_ else as.numeric(total_tokens),
    assumptions = list(
      model = model,
      startup_seconds = profile$startup_seconds,
      per_chunk_seconds = profile$per_chunk_seconds,
      per_record_seconds = profile$per_record_seconds,
      tokens_per_second = profile$tokens_per_second,
      heuristic = "coarse pre-submit estimate from model size, records, chunks, and estimated tokens"
    ),
    warnings = warnings
  )
}

.ensure_submit_ready <- function(config, sif_path, slurm) {
  if (identical(.ssh_destination(config), "")) {
    cli::cli_abort("Cannot submit without a DGX login destination in `dgx_config()`. Use `submit = FALSE` for a dry run.")
  }
  .assert_ssh_ready(config, action = "submit the DGX batch job")
  if (identical(trimws(slurm$mail_user %||% ""), "")) {
    cli::cli_abort(c(
      "Cannot submit without a configured mail recipient. Dry runs may omit it, but real submission requires `dgx_config(mail_user = ...)` or an explicit `slurm$mail_user` override.",
      "i" = "Set `dgx_config(mail_user = 'you@example.org')` for the session, or pass `slurm = list(mail_user = 'you@example.org')` to `submit_job()` / `extract_batch()`."
    ))
  }
  if (identical(trimws(sif_path %||% ""), "")) {
    cli::cli_abort("Cannot submit without `sif_path`. Use `submit = FALSE` for a dry run/preflight.")
  }
}

.stage_bundle_remote <- function(plan) {
  config <- plan$config
  destination <- .ssh_destination(config)

  mkdir_result <- .ssh_capture(
    config,
    paste(
      "mkdir -p",
      shQuote(plan$remote_run_dir),
      shQuote(plan$remote_bundle_dir),
      shQuote(plan$remote_output_dir)
    )
  )

  if (!isTRUE(mkdir_result$ok)) {
    cli::cli_abort(c(
      "Remote staging failed during mkdir.",
      "x" = mkdir_result$stderr %||% mkdir_result$stdout
    ))
  }

  copy_bundle <- tryCatch(
    processx::run(
      command = config$scp_bin,
      args = c(
        .ssh_cli_args(config),
        "-r",
        paste0(plan$bundle_dir, "/."),
        paste0(destination, ":", plan$remote_bundle_dir, "/")
      ),
      error_on_status = FALSE,
      echo = FALSE
    ),
    error = function(e) {
      list(status = 1L, stdout = "", stderr = conditionMessage(e))
    }
  )

  if (!identical(copy_bundle$status, 0L)) {
    cli::cli_abort(c(
      "Remote staging failed while copying the bundle.",
      "x" = copy_bundle$stderr %||% copy_bundle$stdout
    ))
  }

  copy_script <- tryCatch(
    processx::run(
      command = config$scp_bin,
      args = c(
        .ssh_cli_args(config),
        plan$local_script_path,
        paste0(destination, ":", plan$remote_run_dir, "/submit_slurm.sh")
      ),
      error_on_status = FALSE,
      echo = FALSE
    ),
    error = function(e) {
      list(status = 1L, stdout = "", stderr = conditionMessage(e))
    }
  )

  if (!identical(copy_script$status, 0L)) {
    cli::cli_abort(c(
      "Remote staging failed while copying the SLURM script.",
      "x" = copy_script$stderr %||% copy_script$stdout
    ))
  }

  chmod_result <- .ssh_capture(
    config,
    paste("chmod +x", shQuote(paste(plan$remote_run_dir, "submit_slurm.sh", sep = "/")))
  )

  if (!isTRUE(chmod_result$ok)) {
    cli::cli_abort(c(
      "Remote staging failed while marking the script executable.",
      "x" = chmod_result$stderr %||% chmod_result$stdout
    ))
  }

  list(
    mkdir = mkdir_result,
    bundle_copy = list(status = copy_bundle$status, stdout = copy_bundle$stdout, stderr = copy_bundle$stderr),
    script_copy = list(status = copy_script$status, stdout = copy_script$stdout, stderr = copy_script$stderr),
    chmod = chmod_result
  )
}

.parse_sbatch_job_id <- function(stdout) {
  text <- stdout %||% ""
  match <- regmatches(text, regexpr("[0-9]+", text))
  if (length(match) < 1L || identical(match, "")) {
    return(NA_character_)
  }
  as.character(match)
}

.read_chunk_plan <- function(path) {
  if (!file.exists(path)) {
    return(data.frame())
  }

  parsed <- .read_jsonl(path)
  if (length(parsed) < 1L) {
    return(data.frame())
  }

  rows <- lapply(parsed, function(x) {
    data.frame(
      chunk_id = x$chunk_id %||% NA_integer_,
      start_index = x$start_index %||% NA_integer_,
      end_index = x$end_index %||% NA_integer_,
      record_count = x$record_count %||% NA_integer_,
      estimated_tokens = x$estimated_tokens %||% NA_integer_,
      oversize = x$oversize %||% FALSE,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' @export
print.laims_dgx_submit_plan <- function(x, ...) {
  cat("<laims_dgx_submit_plan>\n", sep = "")
  cat("  run_id          : ", x$run_id, "\n", sep = "")
  cat("  bundle_dir      : ", x$bundle_dir, "\n", sep = "")
  cat("  remote_run_dir  : ", x$remote_run_dir, "\n", sep = "")
  cat("  remote_bundle   : ", x$remote_bundle_dir, "\n", sep = "")
  cat("  remote_output   : ", x$remote_output_dir, "\n", sep = "")
  cat("  sif_path        : ", x$sif_path %||% "<unresolved>", "\n", sep = "")
  cat("  sif_source      : ", x$sif_path_source %||% "<unknown>", "\n", sep = "")
  cat("  requested_time  : ", x$slurm$time %||% "<unset>", "\n", sep = "")
  cat("  slurm_node      : ", x$slurm$nodelist %||% "<unset>", " (nodes=", x$slurm$nodes %||% "<unset>", ")\n", sep = "")
  cat("  estimated_time  : ", x$time_preflight$estimated_time %||% "<unknown>", "\n", sep = "")
  cat("  local_script    : ", x$local_script_path, "\n", sep = "")
  cat("  would_submit    : ", if (isTRUE(x$submit)) "yes" else "no", "\n", sep = "")
  if (length(x$time_preflight$warnings %||% character()) > 0L) {
    cat("  time_warning    : ", paste(x$time_preflight$warnings, collapse = " | "), "\n", sep = "")
  }
  invisible(x)
}
