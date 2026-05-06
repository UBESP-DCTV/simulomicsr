#' Run an end-to-end extraction batch workflow
#'
#' High-level convenience wrapper that orchestrates bundle creation, optional
#' remote submission, status handling, and result collection for the standard
#' many-records / one-schema extraction use case.
#'
#' This function is intentionally opinionated: it treats structured JSON output
#' as the target artifact and assumes batch execution on a DGX reachable only
#' via SLURM and Singularity/Apptainer.
#'
#' @param records A `data.frame`/tibble with one row per record.
#' @param id_col Column containing unique record ids.
#' @param text_col Column containing source text.
#' @param prompt_template Prompt template or prompt file path.
#' @param schema Output schema expected from the model.
#' @param model Canonical model size to use: `"20B"` or `"120B"`.
#' @param model_profile Deprecated alias for `model`. Still accepted for
#'   backward compatibility.
#' @param bundle Optional prebuilt bundle created by [create_bundle()]. Supply
#'   either `bundle` or the raw `records` + creation arguments, not both.
#' @param generation Named list of generation parameters.
#' @param submit Logical; if `TRUE`, submit immediately. If `FALSE`, return the
#'   bundle and rendered job assets without launching the job.
#' @param wait Logical; if `TRUE`, poll until a terminal state when possible.
#' @param config A `laims_dgx_config` object. If `NULL`, uses [dgx_config()].
#' @param ... Additional arguments forwarded to [create_bundle()] and
#'   [submit_job()].
#'
#' @return Depending on mode, a bundle object, submit plan, job handle, or
#'   collected results object.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' records <- data.frame(
#'   id   = c("pt001", "pt002"),
#'   note = c(
#'     "Patient has fever, cough, fatigue.",
#'     "Post-op check: wound healing well, no complications."
#'   ),
#'   stringsAsFactors = FALSE
#' )
#'
#' schema <- list(
#'   type       = "object",
#'   properties = list(
#'     conditions = list(type = "array", items = list(type = "string")),
#'     urgency    = list(type = "string", enum = I(c("low", "medium", "high")))
#'   ),
#'   required = I(c("conditions", "urgency"))
#' )
#'
#' # Submit and return job handle immediately (default)
#' job <- extract_batch(
#'   records         = records,
#'   id_col          = "id",
#'   text_col        = "note",
#'   prompt_template = "Extract conditions and urgency from this clinical note.",
#'   schema          = schema,
#'   model           = "20B",
#'   metadata        = list(slug = "clinical-demo"),
#'   config          = cfg
#' )
#'
#' # Dry run: inspect bundle and rendered script without submitting
#' plan <- extract_batch(
#'   records         = records,
#'   id_col          = "id",
#'   text_col        = "note",
#'   prompt_template = "Extract conditions and urgency from this clinical note.",
#'   schema          = schema,
#'   model           = "20B",
#'   submit          = FALSE,
#'   config          = cfg
#' )
#' cat(plan$rendered_script)
#' }
#' @export
extract_batch <- function(records = NULL,
                          id_col = NULL,
                          text_col = NULL,
                          prompt_template = NULL,
                          schema = NULL,
                          model = NULL,
                          model_profile = NULL,
                          bundle = NULL,
                          generation = list(
                            temperature = 0,
                            max_tokens = 1024
                          ),
                          submit = TRUE,
                          wait = FALSE,
                          config = NULL,
                          ...) {
  config <- .resolve_config(config)
  dots <- list(...)

  create_arg_names <- intersect(names(dots), c("bundle_dir", "metadata", "config"))
  submit_arg_names <- setdiff(names(dots), create_arg_names)

  create_args <- dots[create_arg_names]
  submit_args <- dots[submit_arg_names]

  has_bundle <- !is.null(bundle)
  has_records <- !is.null(records)

  if (has_bundle && (has_records || !is.null(id_col) || !is.null(text_col) || !is.null(prompt_template) || !is.null(schema) || !is.null(model) || !is.null(model_profile))) {
    cli::cli_abort(c(
      "`extract_batch()` accepts either `bundle` or raw bundle-creation inputs, not both.",
      "i" = "Use `extract_batch(bundle = existing_bundle, ...)` to reuse a prepared bundle.",
      "i" = "Or omit `bundle` and supply `records`, `id_col`, `text_col`, `prompt_template`, `schema`, and `model` (or legacy `model_profile`)."
    ))
  }

  if (has_bundle) {
    bundle <- .as_bundle_info(bundle, config = config)$bundle
  } else {
    missing_args <- c(
      records = is.null(records),
      id_col = is.null(id_col),
      text_col = is.null(text_col),
      prompt_template = is.null(prompt_template),
      schema = is.null(schema),
      model = is.null(model) && is.null(model_profile)
    )

    if (any(missing_args)) {
      cli::cli_abort(c(
        "Missing inputs for bundle creation.",
        "x" = paste("Required when `bundle` is not supplied:", paste(names(missing_args)[missing_args], collapse = ", "))
      ))
    }

    bundle <- do.call(
      create_bundle,
      c(
        list(
          records = records,
          id_col = id_col,
          text_col = text_col,
          prompt_template = prompt_template,
          schema = schema,
          model = model %||% model_profile,
          model_profile = model_profile,
          generation = generation,
          config = config
        ),
        create_args
      )
    )
  }

  if (!isTRUE(submit)) {
    preflight <- do.call(
      submit_job,
      c(
        list(
          bundle = bundle,
          submit = FALSE,
          config = config
        ),
        submit_args
      )
    )
    return(preflight)
  }

  job <- do.call(
    submit_job,
    c(
      list(
        bundle = bundle,
        submit = TRUE,
        config = config
      ),
      submit_args
    )
  )

  if (!isTRUE(wait)) {
    return(job)
  }

  status <- progress(job, watch = TRUE, config = config)
  if (status$state %in% c("completed", "collected")) {
    return(collect_results(job, config = config))
  }

  invisible(status)
}
