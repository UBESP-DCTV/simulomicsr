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
#' @param tiered_max_tokens se TRUE (default FALSE), assegna `max_tokens`
#'   per-record in base alla dimensione in byte dell input JSONL line via
#'   `.dgx_tier_max_tokens()`. Tier S/M/L/XL → 4096/8192/16384/32768. Il
#'   `gen$max_tokens` globale resta il fallback default (max_tokens dello
#'   yaml stage2). Il `gen$max_model_len` viene auto-bumpato a 65536 se
#'   qualche record è L/XL. Strategy mira a single-pass coverage senza
#'   rescue cycles. Solo per stage2.
#' @return oggetto \code{simulomicsr_dgx_bundle} con campi \code{run_id},
#'   \code{bundle_dir}, \code{stage}, \code{config}, \code{record_count},
#'   e (se `tiered_max_tokens=TRUE`) \code{tier_summary} con count per tier.
#' @export
dgx_p4_build_bundle <- function(input_jsonl,
                                stage,
                                config,
                                metadata           = list(),
                                bundle_dir_root    = "analysis/p4-bundles",
                                tiered_max_tokens  = FALSE) {

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

  # --- 1b. Tiered max_tokens (solo stage2): annota per-record max_tokens nel
  # JSONL in base alla dimensione bytes della riga. Default OFF.
  tier_summary <- NULL
  if (isTRUE(tiered_max_tokens)) {
    if (stage != "stage2")
      cli::cli_abort(
        "tiered_max_tokens=TRUE supportato solo per stage2 (stage1 record sono uniformemente piccoli).",
        class = "simulomicsr_dgx_tiered_stage1_unsupported"
      )
    in_lines <- readLines(dest_input, warn = FALSE)
    line_bytes <- nchar(in_lines, type = "bytes")
    tier_info  <- .dgx_tier_max_tokens(line_bytes)
    out_lines  <- vapply(seq_along(in_lines), function(i) {
      rec <- jsonlite::fromJSON(in_lines[i], simplifyVector = FALSE)
      rec$max_tokens <- tier_info$max_tokens[i]
      jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null")
    }, character(1))
    writeLines(out_lines, dest_input)
    tier_summary <- as.list(table(factor(tier_info$tier,
                                         levels = c("S", "M", "L", "XL"))))
    cli::cli_alert_info(
      paste0("tiered_max_tokens: S=", tier_summary$S,
             " M=", tier_summary$M,
             " L=", tier_summary$L,
             " XL=", tier_summary$XL,
             " (max=", max(tier_info$max_tokens), ")")
    )
  }

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
  # max_tokens globale = fallback per record privi del field per-record.
  # Quando tiered_max_tokens=TRUE alziamo a max(tier_max) cosi vLLM accetta
  # request con quel max_tokens. max_model_len va bumpato a 65536 se ci sono
  # record L/XL (max_tokens >= 16384) per fare spazio a input grandi + output.
  yaml_max_tokens    <- as.integer(stage_def$max_tokens)
  yaml_max_model_len <- as.integer(stage_def$max_model_len)
  if (isTRUE(tiered_max_tokens) && !is.null(tier_summary)) {
    tier_max <- max(c(
      if (tier_summary$S  > 0) 4096L,
      if (tier_summary$M  > 0) 8192L,
      if (tier_summary$L  > 0) 16384L,
      if (tier_summary$XL > 0) 32768L
    ))
    yaml_max_tokens <- max(yaml_max_tokens, tier_max)
    if (tier_max >= 16384L) yaml_max_model_len <- max(yaml_max_model_len, 65536L)
  }
  gen <- list(
    model_id               = defaults$model_id,
    dtype                  = defaults$dtype,
    tokenizer_mode         = defaults$tokenizer_mode,
    config_format          = defaults$config_format,
    load_format            = defaults$load_format,
    max_tokens             = yaml_max_tokens,
    max_model_len          = yaml_max_model_len,
    temperature            = as.double(stage_def$temperature),
    gpu_memory_utilization = defaults$gpu_memory_utilization,
    tensor_parallel_size   = defaults$tensor_parallel_size,
    workers                = defaults$data_parallel_workers
  )
  # Param opzionali sampling (passati al runner Python solo se presenti
  # nel yaml; vedi inst/dgx/python/run_p4_vllm.py worker_main).
  for (opt in c("repetition_penalty", "top_p", "min_p")) {
    if (!is.null(stage_def[[opt]])) {
      gen[[opt]] <- as.double(stage_def[[opt]])
    }
  }
  # Flag opzionale per disabilitare guided decoding (es. stage2 alpha
  # 2026-05-08 dopo stall xgrammar). Se assente, default = guided abilitato.
  if (!is.null(stage_def$disable_guided_decoding)) {
    gen$disable_guided_decoding <- as.logical(stage_def$disable_guided_decoding)
  }
  # microbatch opzionale: numero di record per llm.chat() chiamata; default
  # batch unico (None lato Python) = stage1; stage2 usa 25 per evitare KV
  # cache slot leak (vedi p4-defaults.yml stage2.microbatch e job 19801).
  if (!is.null(stage_def$microbatch)) {
    gen$microbatch <- as.integer(stage_def$microbatch)
  }
  # enforce_eager (Task 22 stage2 v5 mitigazione 2026-05-08).
  # enable_prefix_caching / enable_chunked_prefill / scheduler_reserve_full_isl:
  # flag aggiunti durante investigation Task 22 (resolved 2026-05-08). Vedi
  # p4-defaults.yml + run_p4_vllm.py per dettagli.
  for (opt in c("enforce_eager", "enable_prefix_caching",
                "enable_chunked_prefill", "scheduler_reserve_full_isl")) {
    if (!is.null(stage_def[[opt]])) gen[[opt]] <- as.logical(stage_def[[opt]])
  }
  if (!is.null(stage_def$max_num_seqs)) {
    gen$max_num_seqs <- as.integer(stage_def$max_num_seqs)
  }
  .dgx_write_generation_json(gen, fs::path(bundle_dir, "generation.json"))

  # --- 5. Manifest ---
  manifest <- list(
    run_id         = run_id,
    stage          = stage,
    schema_file    = stage_def$schema_file,
    schema_version = stage_def$schema_version,
    model_id       = defaults$model_id,
    record_count   = record_count,
    tiered_max_tokens = isTRUE(tiered_max_tokens),
    tier_summary   = tier_summary,
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
      record_count = record_count,
      tier_summary = tier_summary
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
