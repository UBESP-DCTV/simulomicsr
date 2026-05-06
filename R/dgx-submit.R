#' Submit di un bundle P4 al cluster DGX via SSH+SLURM
#'
#' Esegue:
#' \enumerate{
#'   \item Render del template \code{inst/dgx/slurm/run_p4.sh} con \code{run_id},
#'     \code{time}, \code{mail_user}, \code{user} sostituiti.
#'   \item rsync del bundle locale -> remoto in
#'     \code{<remote_root>/bundles/<run_id>/}.
#'   \item rsync del SLURM script renderizzato -> remoto.
#'   \item SSH \code{sbatch} sul login node (con env \code{HF_TOKEN} se presente).
#'   \item Parse della jobid dallo stdout di sbatch.
#' }
#'
#' Se \code{dry_run = TRUE}, scrive solo lo script renderizzato in
#' \code{<bundle_dir>/run_p4.rendered.sh} e ritorna senza toccare il cluster.
#'
#' @param bundle output di \code{dgx_p4_build_bundle()}.
#' @param time time limit SLURM (HH:MM:SS o D-HH:MM:SS). Default
#'   \code{"12:00:00"}.
#' @param config \code{simulomicsr_dgx_config}. Default = \code{bundle$config}.
#' @param dry_run logical: se TRUE, non chiama ssh/rsync.
#' @return oggetto \code{simulomicsr_dgx_job} con campi \code{run_id},
#'   \code{slurm_job_id}, \code{stage}, \code{bundle_dir},
#'   \code{rendered_slurm}, \code{submitted_at}, \code{config}.
#' @export
dgx_p4_submit <- function(bundle,
                          time = "12:00:00",
                          config = NULL,
                          dry_run = FALSE) {

  stopifnot(inherits(bundle, "simulomicsr_dgx_bundle"))
  if (is.null(config)) config <- bundle$config
  stopifnot(inherits(config, "simulomicsr_dgx_config"))

  # 1. Render template SLURM
  tmpl_path <- system.file("dgx", "slurm", "run_p4.sh", package = "simulomicsr")
  if (!nzchar(tmpl_path))
    cli::cli_abort(
      "Template SLURM non trovato (devtools::load_all() necessario in dev?)",
      class = "simulomicsr_dgx_template_missing"
    )

  tmpl <- paste(readLines(tmpl_path, warn = FALSE), collapse = "\n")
  rendered <- .dgx_render_slurm_template(
    tmpl,
    run_id       = bundle$run_id,
    run_id_short = .dgx_run_id_short(bundle$run_id),
    user         = config$login_user,
    time         = time,
    mail_user    = config$mail_user
  )
  rendered_path <- fs::path(bundle$bundle_dir, "run_p4.rendered.sh")
  writeLines(rendered, rendered_path)

  if (dry_run) {
    return(structure(
      list(run_id        = bundle$run_id,
           slurm_job_id  = NA_character_,
           stage         = bundle$stage,
           bundle_dir    = bundle$bundle_dir,
           rendered_slurm = rendered_path,
           submitted_at  = NA_character_,
           config        = config),
      class = "simulomicsr_dgx_job"
    ))
  }

  # 2. rsync bundle -> remoto
  remote_bundle <- paste0(config$remote_root, "/bundles/", bundle$run_id, "/")
  .dgx_ssh(config, paste0("mkdir -p ", shQuote(remote_bundle)))
  .dgx_rsync(config,
             local_path  = paste0(bundle$bundle_dir, "/"),
             remote_path = remote_bundle,
             direction   = "push")

  # 3. sbatch via SSH (HF_TOKEN viene letto da .simulomicsr-dgx.env nel login)
  remote_script <- paste0(remote_bundle, "run_p4.rendered.sh")
  sbatch_cmd <- paste0(
    "set -e; ",
    "if [ -f ~/.simulomicsr-dgx.env ]; then . ~/.simulomicsr-dgx.env; fi; ",
    "sbatch --export=HF_TOKEN ", shQuote(remote_script)
  )
  ssh_res <- .dgx_ssh(config, sbatch_cmd)
  if (ssh_res$status != 0L)
    cli::cli_abort(
      c("sbatch fallito (status={ssh_res$status})",
        "x" = "{ssh_res$stderr}"),
      class = "simulomicsr_dgx_sbatch_failed"
    )

  m <- regmatches(ssh_res$stdout,
                  regexpr("Submitted batch job (\\d+)", ssh_res$stdout))
  if (length(m) == 0L)
    cli::cli_abort(
      c("Impossibile trovare il job id nello stdout di sbatch",
        "i" = "stdout: {ssh_res$stdout}"),
      class = "simulomicsr_dgx_sbatch_parse_failed"
    )
  slurm_job_id <- sub("Submitted batch job ", "", m)

  cli::cli_alert_success(
    "Submitted: run_id={bundle$run_id} slurm={slurm_job_id}"
  )

  structure(
    list(run_id        = bundle$run_id,
         slurm_job_id  = slurm_job_id,
         stage         = bundle$stage,
         bundle_dir    = bundle$bundle_dir,
         rendered_slurm = rendered_path,
         submitted_at  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
         config        = config),
    class = "simulomicsr_dgx_job"
  )
}

#' @export
print.simulomicsr_dgx_job <- function(x, ...) {
  cli::cli_h2("simulomicsr DGX job")
  cli::cli_text("run_id:       {.val {x$run_id}}")
  cli::cli_text("slurm:        {.val {x$slurm_job_id}}")
  cli::cli_text("stage:        {.val {x$stage}}")
  cli::cli_text("submitted_at: {.val {x$submitted_at}}")
  invisible(x)
}

#' Stato corrente di un job P4
#'
#' Esegue \code{squeue -j <slurm_job_id> -h -o "\%T"} via SSH e (opzionalmente)
#' scarica \code{status.json} dal cluster.
#'
#' @param job \code{simulomicsr_dgx_job}.
#' @param fetch_status_json se TRUE, rsync di status.json dal remoto e
#'   ritorna anche il contenuto.
#' @param watch se TRUE, polling ogni \code{interval} secondi fino a stato
#'   terminale (COMPLETED, FAILED, CANCELLED, TIMEOUT, TERMINATED).
#'   Stampa progress via cli.
#' @param interval secondi tra polling (default 30).
#' @return list con \code{slurm_state}, \code{remote_status_present},
#'   \code{snapshot} (contenuto status.json se fetched, altrimenti NULL).
#' @export
dgx_p4_status <- function(job,
                          fetch_status_json = TRUE,
                          watch = FALSE,
                          interval = 30L) {
  stopifnot(inherits(job, "simulomicsr_dgx_job"))
  cfg <- job$config
  if (is.na(job$slurm_job_id))
    cli::cli_abort("Job senza slurm_job_id (dry_run o recover non submitted).",
                   class = "simulomicsr_dgx_status_no_jobid")

  poll_once <- function() {
    cmd <- paste0("squeue -j ", job$slurm_job_id,
                  " -h -o '%T' 2>/dev/null || echo TERMINATED")
    res <- .dgx_ssh(cfg, cmd)
    state <- trimws(res$stdout)
    if (!nzchar(state)) state <- "TERMINATED"

    snapshot <- NULL
    remote_status_present <- FALSE
    if (fetch_status_json) {
      remote_status <- paste0(cfg$remote_root, "/runs/", job$run_id, "/status.json")
      ssh_check <- .dgx_ssh(cfg, paste0("test -f ", shQuote(remote_status),
                                        " && echo present || echo absent"))
      if (trimws(ssh_check$stdout) == "present") {
        tmpfile <- fs::file_temp(ext = ".json")
        try({
          .dgx_rsync(cfg, local_path = tmpfile,
                     remote_path = remote_status, direction = "pull")
          snapshot <- jsonlite::read_json(tmpfile)
          remote_status_present <- TRUE
        }, silent = TRUE)
      }
    }

    list(slurm_state           = state,
         remote_status_present = remote_status_present,
         snapshot              = snapshot)
  }

  if (!watch) return(poll_once())

  cli::cli_alert_info(
    "Watching {job$run_id} (slurm={job$slurm_job_id}). Ctrl-C per interrompere."
  )
  terminal <- c("COMPLETED", "FAILED", "CANCELLED", "TIMEOUT", "TERMINATED")
  repeat {
    st <- poll_once()
    snap <- st$snapshot
    msg <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] state=", st$slurm_state)
    if (!is.null(snap)) {
      pct <- snap$records_completed %||% snap$records_completed_total %||% 0L
      msg <- paste0(msg, " | runtime=", snap$state %||% "?",
                    " (", pct, "/", snap$records_total %||% "?", ")")
    }
    cli::cli_text(msg)
    if (st$slurm_state %in% terminal) return(invisible(st))
    Sys.sleep(interval)
  }
}

#' Collect dei risultati di un job P4 (rsync + parse + post-processing)
#'
#' Scarica \code{runs/<run_id>/} dal cluster in \code{<dest>/<run_id>/},
#' parsa \code{predictions.jsonl} in un tibble, applica il post-processing
#' R-side (\code{parse_stage1_response()} o \code{parse_stage2_response()})
#' sui \code{parsed_json} validi.
#'
#' @param job \code{simulomicsr_dgx_job}.
#' @param dest path locale di destinazione. Default \code{"analysis/p4-output"}.
#' @return list con \code{predictions} (data.frame, solo \code{valid_schema=TRUE}),
#'   \code{errors} (data.frame, \code{valid_schema=FALSE}),
#'   \code{summary} (contenuto run_summary.json), \code{run_dir} (path locale).
#' @export
dgx_p4_collect <- function(job, dest = "analysis/p4-output") {
  stopifnot(inherits(job, "simulomicsr_dgx_job"))
  cfg <- job$config

  fs::dir_create(dest, recurse = TRUE)
  remote_run <- paste0(cfg$remote_root, "/runs/", job$run_id, "/")
  local_run  <- fs::path(dest, job$run_id)
  fs::dir_create(local_run, recurse = TRUE)

  .dgx_rsync(cfg, local_path = paste0(local_run, "/"),
             remote_path = remote_run, direction = "pull")

  pred_path <- fs::path(local_run, "predictions.jsonl")
  summ_path <- fs::path(local_run, "run_summary.json")

  if (!fs::file_exists(pred_path))
    cli::cli_abort(
      "predictions.jsonl non presente in {.path {local_run}}",
      class = "simulomicsr_dgx_collect_no_predictions"
    )

  lines <- readLines(pred_path)
  rows  <- lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)

  df <- tibble::tibble(
    record_id    = vapply(rows, function(r) r$record_id  %||% NA_character_, character(1)),
    raw_output   = vapply(rows, function(r) r$raw_output %||% NA_character_, character(1)),
    parsed_json  = lapply(rows, function(r) r$parsed_json),
    valid_schema = vapply(rows, function(r) isTRUE(r$valid_schema),          logical(1)),
    worker_id    = vapply(rows, function(r) as.integer(r$worker_id %||% NA), integer(1)),
    ts           = vapply(rows, function(r) r$ts         %||% NA_character_, character(1))
  )

  # Post-processing R-side: arricchimento deterministico del JSON parsed
  # recuperando i campi originali da input.jsonl del bundle.
  if (job$stage == "stage1") {
    inp_lines  <- readLines(fs::path(job$bundle_dir, "input.jsonl"))
    inp        <- lapply(inp_lines, jsonlite::fromJSON, simplifyVector = FALSE)
    inp_lookup <- setNames(inp, vapply(inp, function(r) r$record_id, character(1)))
    df$parsed_json <- mapply(function(parsed, rid) {
      if (is.null(parsed)) return(NULL)
      orig <- inp_lookup[[rid]]
      if (is.null(orig)) return(parsed)
      tryCatch(
        simulomicsr:::parse_stage1_response(
          raw           = parsed,
          sample_string = orig$string,
          geo_accession = orig$geo_accession,
          series_id     = orig$series_id,
          model         = "vllm-mistral-3.2-24b"
        ),
        error = function(e) parsed
      )
    }, df$parsed_json, df$record_id, SIMPLIFY = FALSE)
  } else if (job$stage == "stage2") {
    # parse_stage2_response richiede argomenti diversi (series_id, sample_count).
    # Applicato in modo condizionale sulla disponibilita' della funzione.
    if (exists("parse_stage2_response", envir = asNamespace("simulomicsr"))) {
      inp_lines  <- readLines(fs::path(job$bundle_dir, "input.jsonl"))
      inp        <- lapply(inp_lines, jsonlite::fromJSON, simplifyVector = FALSE)
      inp_lookup <- setNames(inp, vapply(inp, function(r) r$record_id, character(1)))
      df$parsed_json <- mapply(function(parsed, rid) {
        if (is.null(parsed)) return(NULL)
        orig <- inp_lookup[[rid]]
        tryCatch(
          simulomicsr:::parse_stage2_response(
            raw          = parsed,
            series_id    = rid,
            sample_count = if (!is.null(orig)) length(orig) else 1L,
            model        = "vllm-mistral-3.2-24b"
          ),
          error = function(e) parsed
        )
      }, df$parsed_json, df$record_id, SIMPLIFY = FALSE)
    }
  }

  predictions <- df[df$valid_schema,  , drop = FALSE]
  errors      <- df[!df$valid_schema, , drop = FALSE]
  summary     <- if (fs::file_exists(summ_path)) jsonlite::read_json(summ_path) else list()

  list(predictions = predictions,
       errors      = errors,
       summary     = summary,
       run_dir     = local_run)
}

#' Recupera un job P4 dal bundle locale dopo restart R
#'
#' Cerca \code{bundles/<run_id>/manifest.json}, ricostruisce un oggetto
#' \code{simulomicsr_dgx_job} senza chiamare il cluster. Lo
#' \code{slurm_job_id} resta \code{NA} finche' non viene recuperato
#' manualmente da \code{squeue --me} o si rilancia \code{dgx_p4_submit()}.
#'
#' @param run_id stringa identificativa del run.
#' @param config \code{simulomicsr_dgx_config}.
#' @param bundle_dir_root directory parent dei bundle. Default
#'   \code{"analysis/p4-bundles"}.
#' @return \code{simulomicsr_dgx_job}.
#' @export
dgx_p4_recover <- function(run_id,
                           config,
                           bundle_dir_root = "analysis/p4-bundles") {
  stopifnot(is.character(run_id), length(run_id) == 1L, nzchar(run_id))
  stopifnot(inherits(config, "simulomicsr_dgx_config"))

  bundle_dir    <- fs::path(bundle_dir_root, run_id)
  manifest_path <- fs::path(bundle_dir, "manifest.json")

  if (!fs::file_exists(manifest_path))
    cli::cli_abort(
      "Bundle non trovato per run_id={run_id} in {.path {bundle_dir}}",
      class = "simulomicsr_dgx_recover_no_bundle"
    )

  m <- jsonlite::read_json(manifest_path)

  structure(
    list(run_id        = m$run_id,
         slurm_job_id  = NA_character_,
         stage         = m$stage,
         bundle_dir    = bundle_dir,
         rendered_slurm = fs::path(bundle_dir, "run_p4.rendered.sh"),
         submitted_at  = NA_character_,
         config        = config),
    class = "simulomicsr_dgx_job"
  )
}
