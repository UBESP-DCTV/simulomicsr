#' Create a reproducible batch bundle for DGX inference
#'
#' Prepare a local bundle directory containing records, prompt template,
#' schema, model selection, and run metadata for a one-shot SLURM batch job.
#'
#' The public interface is intentionally simple: for now users choose only
#' `"20B"` or `"120B"`, while the package resolves the official model/runtime
#' details internally.
#'
#' @param records A `data.frame` or tibble with one row per input record.
#' @param id_col Name of the column containing unique record identifiers.
#' @param text_col Name of the column containing the text to process.
#' @param prompt_template Length-1 character string or path to a prompt file.
#' @param schema A list or JSON schema-like object describing the expected
#'   structured output.
#' @param model Canonical model size to use: `"20B"` or `"120B"`.
#' @param model_profile Deprecated alias for `model`. Still accepted for
#'   backward compatibility.
#' @param generation Named list of generation parameters.
#' @param bundle_dir Optional output directory. If `NULL`, a timestamped
#'   directory is created under the local state directory.
#' @param metadata Optional named list with project/use-case metadata.
#' @param config A `laims_dgx_config` object. If `NULL`, uses [dgx_config()].
#'
#' @return An object of class `laims_dgx_bundle`.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' records <- data.frame(
#'   id   = c("r01", "r02"),
#'   text = c(
#'     "Patient reports fever and cough.",
#'     "Follow-up: diabetes stable, no new symptoms."
#'   ),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Structured extraction
#' schema <- list(
#'   type       = "object",
#'   properties = list(
#'     conditions = list(type = "array", items = list(type = "string")),
#'     severity   = list(type = "string")
#'   ),
#'   required = I(c("conditions", "severity"))
#' )
#'
#' bundle <- create_bundle(
#'   records         = records,
#'   id_col          = "id",
#'   text_col        = "text",
#'   prompt_template = "Extract medical conditions and overall severity.",
#'   schema          = schema,
#'   model           = "20B",
#'   metadata        = list(slug = "extract-demo"),
#'   config          = cfg
#' )
#' print(bundle)
#'
#' # Plain text response (single result field)
#' schema_text <- list(
#'   type       = "object",
#'   properties = list(result = list(type = "string")),
#'   required   = I("result")
#' )
#'
#' bundle_text <- create_bundle(
#'   records         = records,
#'   id_col          = "id",
#'   text_col        = "text",
#'   prompt_template = "Summarise this clinical note in one sentence.",
#'   schema          = schema_text,
#'   model           = "20B",
#'   config          = cfg
#' )
#' }
#' @export
create_bundle <- function(records,
                          id_col,
                          text_col,
                          prompt_template,
                          schema,
                          model = "20B",
                          model_profile = NULL,
                          generation = list(
                            temperature = 0,
                            max_tokens = 1024
                          ),
                          bundle_dir = NULL,
                          metadata = list(),
                          config = NULL) {
  config <- .resolve_config(config)

  records <- .validate_records_input(records, id_col = id_col, text_col = text_col)
  prompt_text <- .resolve_prompt_template(prompt_template)
  schema_obj <- .normalize_schema(schema)
  model_key <- .resolve_model_key(model = model, model_profile = model_profile)
  spec <- .model_spec(model_key)

  slug <- .bundle_slug_from_metadata(metadata)
  run_id <- .make_run_id(slug = slug)
  bundle_dir <- .default_bundle_dir(bundle_dir = bundle_dir, run_id = run_id, config = config)
  fs::dir_create(bundle_dir)

  chunking <- spec$chunking %||% list()
  runtime <- spec$runtime %||% list()
  chunk_plan <- .plan_chunks_greedy(
    text = records[[text_col]],
    max_context_tokens = runtime$max_context_tokens %||% 8192,
    prompt_overhead_tokens = chunking$prompt_overhead_tokens %||% 700,
    output_reserve_per_record = chunking$output_reserve_per_record %||% 350,
    target_context_fraction = chunking$target_context_fraction %||% 0.70,
    max_records_per_chunk = chunking$max_records_per_chunk %||% Inf,
    chars_per_token = chunking$chars_per_token_fallback %||% 4
  )

  records_lines <- .records_to_jsonl(records)
  chunk_lines <- .chunk_plan_to_jsonl(chunk_plan, records = records, id_col = id_col)

  generation <- utils::modifyList(
    list(
      temperature = 0,
      max_tokens = 1024
    ),
    generation
  )

  manifest <- list(
    format_version = "0.1",
    run_id = run_id,
    slug = slug,
    created_at = .timestamp_utc(),
    bundle_dir = bundle_dir,
    files = list(
      records = "records.jsonl",
      prompt = "prompt.txt",
      schema = "schema.json",
      generation = "generation.json",
      manifest = "manifest.json",
      run_meta = "run_meta.json",
      chunk_plan = "chunk_plan.jsonl",
      status = "status.json"
    ),
    record_count = nrow(records),
    chunk_count = nrow(chunk_plan),
    id_col = id_col,
    text_col = text_col,
    model = model_key,
    model_profile = model_key,
    model_id = spec$model_id %||% NA_character_
  )

  run_meta <- list(
    run_id = run_id,
    slug = slug,
    created_at = manifest$created_at,
    state = "created",
    model = model_key,
    model_profile = model_key,
    model_spec = spec,
    generation = generation,
    metadata = metadata,
    input = list(
      id_col = id_col,
      text_col = text_col,
      total_records = nrow(records)
    )
  )

  initial_status <- list(
    run_id = run_id,
    state = "created",
    message = "Bundle created locally",
    updated_at = manifest$created_at,
    records = list(
      total = nrow(records),
      completed = 0,
      failed = 0
    ),
    chunks = list(
      total = nrow(chunk_plan),
      completed = 0,
      running = 0
    )
  )

  .write_lines(fs::path(bundle_dir, "records.jsonl"), records_lines)
  writeLines(prompt_text, fs::path(bundle_dir, "prompt.txt"), useBytes = TRUE)
  .write_schema_json(fs::path(bundle_dir, "schema.json"), schema_obj)
  .write_json(fs::path(bundle_dir, "generation.json"), generation)
  .write_json(fs::path(bundle_dir, "manifest.json"), manifest)
  .write_json(fs::path(bundle_dir, "run_meta.json"), run_meta)
  .write_lines(fs::path(bundle_dir, "chunk_plan.jsonl"), chunk_lines)
  .write_json(fs::path(bundle_dir, "status.json"), initial_status)

  .registry_upsert_run(
    list(
      run_id = run_id,
      slug = slug,
      state = "created",
      state_source = "local",
      state_detail = "Bundle created locally",
      created_at = manifest$created_at,
      updated_at = manifest$created_at,
      local_run_dir = bundle_dir,
      model_profile = model_key,
      total_records = nrow(records),
      total_chunks = nrow(chunk_plan),
      completed_records = 0L,
      failed_records = 0L,
      completed_chunks = 0L,
      running_chunks = 0L,
      status_cache_json = jsonlite::toJSON(
        list(status = initial_status),
        auto_unbox = TRUE,
        null = "null"
      )
    ),
    config = config
  )

  .registry_append_event(
    run_id = run_id,
    event_type = "bundle_created",
    state = "created",
    details = list(
      local_run_dir = bundle_dir,
      total_records = nrow(records),
      total_chunks = nrow(chunk_plan),
      model = model_key
    ),
    config = config
  )

  structure(
    list(
      run_id = run_id,
      slug = slug,
      state = "created",
      bundle_dir = bundle_dir,
      local_run_dir = bundle_dir,
      manifest = manifest,
      run_meta = run_meta,
      model = model_key,
      model_profile = model_key,
      model_spec = spec,
      generation = generation,
      metadata = metadata,
      chunk_plan = chunk_plan,
      files = list(
        records = fs::path(bundle_dir, "records.jsonl"),
        prompt = fs::path(bundle_dir, "prompt.txt"),
        schema = fs::path(bundle_dir, "schema.json"),
        generation = fs::path(bundle_dir, "generation.json"),
        manifest = fs::path(bundle_dir, "manifest.json"),
        run_meta = fs::path(bundle_dir, "run_meta.json"),
        chunk_plan = fs::path(bundle_dir, "chunk_plan.jsonl"),
        status = fs::path(bundle_dir, "status.json")
      ),
      config = config
    ),
    class = "laims_dgx_bundle"
  )
}

.default_bundle_dir <- function(bundle_dir, run_id, config) {
  if (!is.null(bundle_dir)) {
    return(fs::path_abs(bundle_dir))
  }

  fs::path(config$state_dir, "bundles", run_id)
}

.validate_records_input <- function(records, id_col, text_col) {
  if (!inherits(records, "data.frame")) {
    cli::cli_abort("`records` must be a data.frame or tibble.")
  }

  id_col <- as.character(id_col)[1]
  text_col <- as.character(text_col)[1]

  if (!id_col %in% names(records)) {
    cli::cli_abort("Unknown `id_col`: {.val {id_col}}")
  }
  if (!text_col %in% names(records)) {
    cli::cli_abort("Unknown `text_col`: {.val {text_col}}")
  }

  ids <- records[[id_col]]
  if (any(is.na(ids) | trimws(as.character(ids)) == "")) {
    cli::cli_abort("`records[[id_col]]` must not contain missing or empty identifiers.")
  }
  if (anyDuplicated(as.character(ids))) {
    cli::cli_abort("`records[[id_col]]` must contain unique identifiers.")
  }

  records[[id_col]] <- as.character(records[[id_col]])
  records[[text_col]] <- as.character(records[[text_col]] %||% "")
  records[[text_col]][is.na(records[[text_col]])] <- ""
  records
}

.resolve_prompt_template <- function(prompt_template) {
  prompt_template <- as.character(prompt_template)
  if (length(prompt_template) != 1L || is.na(prompt_template)) {
    cli::cli_abort("`prompt_template` must be a length-1 character string or file path.")
  }

  if (file.exists(prompt_template)) {
    paste(readLines(prompt_template, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  } else {
    prompt_template
  }
}

.normalize_schema <- function(schema) {
  if (is.character(schema) && length(schema) == 1L && !is.na(schema) && file.exists(schema)) {
    ext <- tolower(fs::path_ext(schema))
    if (ext %in% c("yml", "yaml")) {
      return(yaml::read_yaml(schema))
    }

    text <- paste(readLines(schema, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    return(jsonlite::fromJSON(text, simplifyVector = FALSE))
  }

  if (is.character(schema) && length(schema) == 1L && !is.na(schema)) {
    parsed <- tryCatch(
      jsonlite::fromJSON(schema, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (!is.null(parsed)) {
      return(parsed)
    }
  }

  schema
}

.bundle_slug_from_metadata <- function(metadata) {
  if (is.null(metadata) || length(metadata) < 1L) {
    return(NA_character_)
  }

  candidates <- c("slug", "project", "project_slug", "name", "label")
  hit <- candidates[candidates %in% names(metadata)][1]
  if (is.na(hit) || length(hit) == 0L) {
    return(NA_character_)
  }

  .sanitize_slug(metadata[[hit]])
}

.package_file <- function(...) {
  rel <- fs::path(...)
  candidates <- c(
    fs::path(getwd(), rel),
    fs::path(getwd(), "inst", rel),
    fs::path(getwd(), "..", rel),
    fs::path(getwd(), "..", "inst", rel)
  )
  candidates <- unique(fs::path_abs(candidates))
  hit <- candidates[file.exists(candidates)][1]

  if (is.na(hit) || length(hit) == 0L) {
    installed <- system.file(rel, package = "laimsdgxllm")
    if (!identical(installed, "") && file.exists(installed)) {
      return(installed)
    }

    cli::cli_abort("Cannot locate package file: {.file {rel}}")
  }

  hit
}

.load_model_catalog <- function() {
  models_path <- .package_file("config", "models.yml")
  catalog <- yaml::read_yaml(models_path) %||% list()

  if (!is.null(catalog$models)) {
    return(catalog)
  }

  # Backward compatibility with older `profiles:` layout.
  list(models = catalog$profiles %||% list(), aliases = list())
}

.known_models <- function() {
  names(.load_model_catalog()$models %||% list())
}

.resolve_model_key <- function(model = NULL, model_profile = NULL, default = "20B") {
  catalog <- .load_model_catalog()
  models <- catalog$models %||% list()
  aliases <- catalog$aliases %||% list()

  candidate <- if (!is.null(model_profile) && length(model_profile) > 0L && !all(is.na(model_profile))) {
    as.character(model_profile)[1]
  } else if (!is.null(model) && length(model) > 0L && !all(is.na(model))) {
    as.character(model)[1]
  } else {
    default
  }

  candidate <- trimws(candidate)
  if (identical(candidate, "") || is.na(candidate)) {
    candidate <- default
  }

  if (candidate %in% names(models)) {
    return(candidate)
  }

  alias_names <- names(aliases)
  if (length(alias_names) > 0L) {
    alias_hits <- alias_names[tolower(alias_names) == tolower(candidate)]
    if (length(alias_hits) > 0L) {
      canonical <- aliases[[alias_hits[[1]]]]
      if (canonical %in% names(models)) {
        return(canonical)
      }
    }
  }

  model_hits <- names(models)[tolower(names(models)) == tolower(candidate)]
  if (length(model_hits) > 0L) {
    return(model_hits[[1]])
  }

  cli::cli_abort(c(
    "Unknown model selection.",
    "x" = "Model {.val {candidate}} is not supported.",
    "i" = "Use one of: {.val {paste(names(models), collapse = ', ')}}"
  ))
}

.model_spec <- function(model = NULL, model_profile = NULL) {
  model_key <- .resolve_model_key(model = model, model_profile = model_profile)
  spec <- .load_model_catalog()$models[[model_key]]

  if (is.null(spec)) {
    cli::cli_abort("Cannot resolve model spec for {.val {model_key}}.")
  }

  spec$model <- model_key
  spec
}

.records_to_jsonl <- function(records) {
  rows <- vector("character", nrow(records))
  for (i in seq_len(nrow(records))) {
    rows[[i]] <- jsonlite::toJSON(
      as.list(records[i, , drop = FALSE]),
      auto_unbox = TRUE,
      null = "null",
      na = "null"
    )
  }
  rows
}

.chunk_plan_to_jsonl <- function(chunk_plan, records, id_col) {
  if (nrow(chunk_plan) < 1L) {
    return(character())
  }

  lines <- vector("character", nrow(chunk_plan))
  ids <- as.character(records[[id_col]])

  for (i in seq_len(nrow(chunk_plan))) {
    row <- chunk_plan[i, , drop = FALSE]
    idx <- seq.int(row$start_index[[1]], row$end_index[[1]])
    payload <- list(
      chunk_id = row$chunk_id[[1]],
      start_index = row$start_index[[1]],
      end_index = row$end_index[[1]],
      record_count = row$record_count[[1]],
      estimated_tokens = row$estimated_tokens[[1]],
      oversize = row$oversize[[1]],
      record_ids = I(ids[idx])
    )
    lines[[i]] <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
  }

  lines
}

.write_json <- function(path, x) {
  jsonlite::write_json(x, path = path, pretty = TRUE, auto_unbox = TRUE, null = "null", na = "null")
}

.write_schema_json <- function(path, x) {
  jsonlite::write_json(x, path = path, pretty = TRUE, auto_unbox = FALSE, null = "null", na = "null")
}

.write_lines <- function(path, lines) {
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  if (length(lines) > 0L) {
    writeLines(enc2utf8(lines), con = con, sep = "\n", useBytes = TRUE)
  }
}

#' @export
print.laims_dgx_bundle <- function(x, ...) {
  cat("<laims_dgx_bundle>\n", sep = "")
  cat("  run_id     : ", x$run_id, "\n", sep = "")
  cat("  slug       : ", x$slug %||% "<none>", "\n", sep = "")
  cat("  state      : ", x$state %||% "<unknown>", "\n", sep = "")
  cat("  bundle_dir : ", x$bundle_dir, "\n", sep = "")
  cat("  records    : ", x$manifest$record_count %||% NA_integer_, "\n", sep = "")
  cat("  chunks     : ", x$manifest$chunk_count %||% NA_integer_, "\n", sep = "")
  cat("  model      : ", x$model %||% x$model_profile, "\n", sep = "")
  invisible(x)
}
