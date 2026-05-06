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
