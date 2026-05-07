#' Costruisce un bundle locale per un run P4 sulla DGX
#'
#' Un bundle e' una directory autocontenuta che raccoglie tutto cio' che
#' serve a un job SLURM remoto: manifest, input records, prompt template
#' (system message), schema JSON, parametri di generazione, status iniziale.
#' Verra' rsync-ato sul login node da \code{dgx_p4_submit()}.
#'
#' @param input_jsonl path locale a un file JSONL (una riga per record).
#'   Per stage1: campi \code{record_id}, \code{geo_accession}, \code{series_id},
#'   \code{string}.
#'   Per stage2: campi \code{record_id}, \code{study_summary}, \code{samples}
#'   (lista).
#' @param stage \code{"stage1"} o \code{"stage2"}.
#' @param config \code{simulomicsr_dgx_config} da \code{dgx_config()}.
#' @param metadata list opzionale con \code{slug} (default: stage), aggiunta al
#'   manifest e usata per costruire il \code{run_id}.
#' @param bundle_dir_root directory parent in cui creare il bundle. Default
#'   \code{"analysis/p4-bundles/"}.
#' @return oggetto \code{simulomicsr_dgx_bundle} con campi \code{run_id},
#'   \code{bundle_dir}, \code{stage}, \code{config}, \code{record_count}.
#' @export
dgx_p4_build_bundle <- function(input_jsonl,
                                stage,
                                config,
                                metadata        = list(),
                                bundle_dir_root = "analysis/p4-bundles") {

  # --- Validazione argomenti ---
  if (!stage %in% c("stage1", "stage2"))
    cli::cli_abort(
      "stage deve essere {.val stage1} o {.val stage2}, ricevuto {.val {stage}}.",
      class = "simulomicsr_dgx_unknown_stage"
    )

  if (!fs::file_exists(input_jsonl))
    cli::cli_abort(
      "Input JSONL non trovato: {.path {input_jsonl}}",
      class = "simulomicsr_dgx_input_missing"
    )

  stopifnot(inherits(config, "simulomicsr_dgx_config"))

  # --- Carica p4-defaults.yml ---
  defaults_path <- system.file("extdata", "p4-defaults.yml", package = "simulomicsr")
  if (!nzchar(defaults_path))
    cli::cli_abort(
      paste0("inst/extdata/p4-defaults.yml non trovato ",
             "(devtools::load_all() necessario in dev?)"),
      class = "simulomicsr_dgx_defaults_missing"
    )
  defaults    <- yaml::read_yaml(defaults_path)
  stage_def   <- defaults$stages[[stage]]

  # --- run_id e directory bundle ---
  slug       <- metadata[["slug"]] %||% stage
  run_id     <- .dgx_run_id(slug)
  bundle_dir <- fs::path(bundle_dir_root, run_id)
  fs::dir_create(bundle_dir, recurse = TRUE)

  # --- 1. Copia input JSONL e conta record ---
  dest_input <- fs::path(bundle_dir, "input.jsonl")
  fs::file_copy(input_jsonl, dest_input)
  record_count <- length(readLines(dest_input, warn = FALSE))

  # --- 2. System prompt ---
  # .stage1_system_prompt() non ha argomenti.
  # .stage2_system_prompt(model) richiede il nome modello (informativo).
  prompt_text <- if (stage == "stage1") {
    simulomicsr:::.stage1_system_prompt()
  } else {
    simulomicsr:::.stage2_system_prompt(defaults$model_id)
  }
  writeLines(prompt_text, fs::path(bundle_dir, "prompt.txt"))

  # --- 3. Schema JSON dal pacchetto ---
  schema_src <- system.file("schemas", stage_def$schema_file,
                            package = "simulomicsr")
  if (!nzchar(schema_src))
    cli::cli_abort(
      "Schema {.val {stage_def$schema_file}} non trovato in inst/schemas/.",
      class = "simulomicsr_dgx_schema_missing"
    )
  fs::file_copy(schema_src, fs::path(bundle_dir, "schema.json"))

  # --- 4. Generation config ---
  gen <- list(
    model_id               = defaults$model_id,
    dtype                  = defaults$dtype,
    tokenizer_mode         = defaults$tokenizer_mode,
    config_format          = defaults$config_format,
    load_format            = defaults$load_format,
    max_tokens             = as.integer(stage_def$max_tokens),
    max_model_len          = as.integer(stage_def$max_model_len),
    temperature            = as.double(stage_def$temperature),
    gpu_memory_utilization = defaults$gpu_memory_utilization,
    tensor_parallel_size   = defaults$tensor_parallel_size,
    workers                = defaults$data_parallel_workers
  )
  .dgx_write_generation_json(gen, fs::path(bundle_dir, "generation.json"))

  # --- 5. Manifest ---
  manifest <- list(
    run_id         = run_id,
    stage          = stage,
    schema_file    = stage_def$schema_file,
    schema_version = stage_def$schema_version,
    model_id       = defaults$model_id,
    record_count   = record_count,
    created_at     = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    metadata       = metadata
  )
  jsonlite::write_json(manifest,
                       fs::path(bundle_dir, "manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE)

  # --- 6. Status iniziale ---
  status <- list(
    run_id     = run_id,
    state      = "created",
    message    = "Bundle creato localmente",
    updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  jsonlite::write_json(status,
                       fs::path(bundle_dir, "status.json"),
                       auto_unbox = TRUE, pretty = TRUE)

  structure(
    list(
      run_id       = run_id,
      bundle_dir   = bundle_dir,
      stage        = stage,
      config       = config,
      record_count = record_count
    ),
    class = "simulomicsr_dgx_bundle"
  )
}

#' @export
print.simulomicsr_dgx_bundle <- function(x, ...) {
  cli::cli_h2("simulomicsr DGX bundle")
  cli::cli_text("run_id:  {.val {x$run_id}}")
  cli::cli_text("stage:   {.val {x$stage}}")
  cli::cli_text("records: {.val {x$record_count}}")
  cli::cli_text("dir:     {.path {x$bundle_dir}}")
  invisible(x)
}

# --- Helper privati ---

# Serializza generation.json garantendo che temperature sia un float JSON
# (es. 0.0) e non un intero (es. 0), in modo che jsonlite::read_json() lo
# rilegga come double R invece di integer.
.dgx_write_generation_json <- function(gen, path) {
  json_txt <- jsonlite::toJSON(gen, auto_unbox = TRUE, pretty = TRUE)
  # Sostituisce pattern "temperature": <intero> con "temperature": <intero>.0
  # per garantire notazione float nel file JSON.
  json_txt <- gsub(
    '("temperature"\\s*:\\s*)(\\d+)(\\s*[,\\n}])',
    "\\1\\2.0\\3",
    json_txt
  )
  writeLines(json_txt, path)
  invisible(path)
}
