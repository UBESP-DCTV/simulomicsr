library(targets)
library(tarchetypes)

# Carica tutte le funzioni della libreria simulomicsr
list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE) |>
  lapply(source) |>
  invisible()

tar_option_set(
  packages = c("tibble", "dplyr", "readxl"),
  format   = "rds",
  error    = "continue",
  workspace_on_error = TRUE
)

list(
  tar_target(
    samples_input_path,
    here::here("data-raw", "relevant_sample_classified.xlsx"),
    format = "file"
  ),

  tar_target(
    samples_input,
    read_samples_input(samples_input_path)
  ),

  tar_target(
    samples_dev_set,
    build_dev_set(samples_input, n = 100L, seed = 1812L)
  ),

  # Cache LLM persistente per Stadio 1 (stessa cache tra run; idempotente).
  # Nota: `targets` traccia questo path come file; la dir e' creata se mancante.
  tar_target(
    stage1_cache_dir,
    fs::dir_create(here::here("analysis", "cache")),
    format = "file"
  ),

  # Dynamic branching: una invocazione per riga di samples_dev_set.
  # `targets` con `pattern = map(samples_dev_set)` su una tibble passa
  # **una riga alla volta** alla funzione. `classify_sample_row()` riceve
  # quindi un tibble di 1 riga per branch e ritorna il sample_fact.
  tar_target(
    sample_facts_raw,
    classify_sample_row(
      samples_dev_set,
      provider = "openai",
      model    = "gpt-5.5",
      cache    = cache_init(stage1_cache_dir, namespace = "stage1")
    ),
    pattern   = map(samples_dev_set),
    iteration = "list"
  ),

  # Validazione schema; partition pass/fail.
  # `sample_facts_validator` conserva il PATH dello schema (stringa), non il
  # validatore compilato: i validatori jsonvalidate/V8 non sono serializzabili
  # in RDS (il contesto V8 viene distrutto alla deserializzazione). Il PATH e'
  # un target stabile che garantisce un'unica sorgente di verita' per lo schema.
  tar_target(
    sample_facts_validator,
    system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr"),
    format = "file"
  ),

  tar_target(
    sample_facts_validated,
    {
      # Un record finisce in `validated` se e solo se:
      #   (a) NON e' un record di failure (no `.invalid_reason`)
      #   (b) supera la validazione schema dopo aver rimosso eventuali
      #       campi extra di debug.
      # Importante: i record di .stage1_invalid_record sono schema-conformanti
      # (modulo i campi extra), quindi (a) e' il check primario; (b) e' una
      # safety net in caso un sample_fact "ok" abbia campi inattesi.
      validator <- compile_schema(sample_facts_validator)
      keep <- vapply(sample_facts_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(FALSE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        validate_json(f, validator = validator)$valid
      }, logical(1))
      sample_facts_raw[keep]
    }
  ),

  tar_target(
    sample_facts_invalid,
    {
      validator <- compile_schema(sample_facts_validator)
      drop <- vapply(sample_facts_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(TRUE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        !validate_json(f, validator = validator)$valid
      }, logical(1))
      sample_facts_raw[drop]
    }
  ),

  tar_target(
    eval_stage1_metrics,
    {
      validity <- stage1_schema_validity_rate(
        sample_facts_validated, sample_facts_invalid
      )
      recall <- stage1_recall_key_fields(sample_facts_validated)
      tibble::tibble(
        n_total              = validity$n_total,
        n_validated          = validity$n_validated,
        n_invalid            = validity$n_invalid,
        validity_rate        = validity$validity_rate,
        n_with_perturbation  = recall$n_with_perturbation,
        n_with_cell_type     = recall$n_with_cell_type,
        recall_perturbation  = recall$recall_perturbation,
        recall_cell_type     = recall$recall_cell_type
      )
    }
  ),

  tarchetypes::tar_render(
    eval_stage1_report,
    here::here("analysis", "eval", "stage1-eval.Rmd"),
    output_dir = here::here("analysis", "eval"),
    params = list(
      metrics   = eval_stage1_metrics,
      validated = sample_facts_validated,
      invalid   = sample_facts_invalid
    )
  )
)
