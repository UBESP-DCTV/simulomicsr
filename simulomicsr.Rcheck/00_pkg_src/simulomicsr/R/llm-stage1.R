#' Legge il TSV di fixture sample mini bundled nel pacchetto
#'
#' Per test e vignette: 8 sample stratificati estratti dal xlsx
#' (script in `data-raw/build-sample-fixtures-mini.R`).
#'
#' @return tibble con colonne `geo_accession`, `series_id`, `string`,
#'   `trtctr_EP`, `trtctr`, `treat`, `gold`, `stratum`
#' @keywords internal
read_sample_fixtures_mini <- function() {
  path <- system.file("extdata/sample-fixtures-mini.tsv",
                      package = "simulomicsr")
  if (!nzchar(path) || !fs::file_exists(path)) {
    rlang::abort(
      "Fixture sample-fixtures-mini.tsv non trovato. Run data-raw/build-sample-fixtures-mini.R",
      class = "simulomicsr_fixtures_missing"
    )
  }
  readr::read_tsv(
    path,
    show_col_types = FALSE,
    progress = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
}

# Vocabolari controllati elencati nel system prompt (spec \u00a73.1, \u00a73.5, \u00a73.6,
# \u00a73.8, \u00a73.9). Tenuti come stringhe esplicite per facilitare audit/diff
# rispetto alla spec.
.STAGE1_KINDS <- paste(
  "- small_molecule",
  "- vehicle_only",
  "- genetic_knockdown",
  "- genetic_knockout",
  "- genetic_overexpression",
  "- crispra_activation",
  "- crispri_repression",
  "- cytokine_stimulation",
  "- pathogen_or_aggregate_exposure",
  "- environmental_or_behavioral",
  "- differentiation",
  "- mechanical_or_physical",
  "- none",
  "- unclear",
  sep = "\n"
)

.STAGE1_CONTEXT_KINDS <- paste(
  "cell_line_in_vitro, primary_culture, iPSC_derived, organoid, xenograft,",
  "primary_tissue, pdx_derived_cell_line, co_culture, tumor_extracted_cells,",
  "unclear"
)

.STAGE1_DISEASE_STATUS <- "case, comparison, disease_model, none"

.STAGE1_AMBIGUITY_FLAGS <- paste(
  "missing_dose, missing_duration, time_zero_timepoint,",
  "multi_factor_in_string, compound_unmapped, cell_line_ambiguous,",
  "vehicle_only, description_too_short, mixed_organism_terms,",
  "study_specific_jargon, multiple_perturbations, engineered_cell_line,",
  "technical_treatment_only, disease_state_present, control_unspecified,",
  "post_treatment_ambiguous, protocol_only_no_perturbation,",
  "metadata_inconsistency, opaque_compound_code"
)

.stage1_system_prompt <- function() {
  glue::glue(
    "You are an extraction agent for RNAseq sample metadata. Your task is to ",
    "produce a strictly schema-conformant JSON record (schema sample_facts.stage1.v3) ",
    "from a free-text concatenation of GEO sample fields.\n\n",
    "GROUND RULES (read carefully):\n",
    "1. Copy `geo_accession` and `series_id` VERBATIM from the user message. ",
    "Do not invent or modify them.\n",
    "2. Use ONLY values from the controlled vocabularies listed below for fields ",
    "that have an enum constraint. Never coin new values.\n",
    "3. When a fact is not present in the input string, set the field to null ",
    "(or empty array for list-valued fields). Do NOT guess.\n",
    "4. The schema enforces additionalProperties:false at every level: do not ",
    "add fields that are not in the schema.\n",
    "5. Set `extraction.confidence` to your honest 0..1 estimate that the ",
    "extracted facts faithfully reflect the input string.\n",
    "6. Set `extraction.schema_version` to exactly the string 'stage1.v3'.\n",
    "7. Leave `extraction.raw_input_hash` as 'sha256:0000000000000000000000000000000000000000000000000000000000000000' \u2014 the R caller will overwrite it deterministically.\n",
    "8. Leave `extraction.model` as the empty-meaningful default '__unset__' \u2014 the R caller will overwrite it.\n\n",
    "PERTURBATION KINDS (`perturbations[].kind`):\n{.STAGE1_KINDS}\n\n",
    "CELL CONTEXT KINDS (`cell_context.context_kind`):\n{.STAGE1_CONTEXT_KINDS}\n\n",
    "DISEASE STATE STATUS (`disease_state.status`):\n{.STAGE1_DISEASE_STATUS}\n\n",
    "AMBIGUITY FLAGS (`extraction.ambiguity_flags[]`, choose 0+):\n{.STAGE1_AMBIGUITY_FLAGS}\n\n",
    "FEW-SHOT EXAMPLE (input -> output):\n",
    "INPUT: 'sample: HUVEC, treatment: VEGF, time: 1h'\n",
    "geo_accession=GSM1009636, series_id=GSE41166\n",
    "EXPECTED `perturbations[0].kind` = 'cytokine_stimulation', ",
    "`agent_normalized.preferred_name` = 'VEGFA' (HGNC alias resolution), ",
    "`duration.value_hours` = 1, `cell_context.context_kind` = 'primary_culture', ",
    "`cell_context.cell_type_or_line_raw` = 'HUVEC', ",
    "`extraction.ambiguity_flags` = ['missing_dose'].",
    .open = "{", .close = "}"
  )
}

#' Enrichment deterministico della risposta LLM Stadio 1
#'
#' Forza i campi che NON devono dipendere dall'LLM:
#' - `geo_accession` e `series_id` ricopiati dall'input (anti-allucinazione)
#' - `extraction.schema_version = "stage1.v3"`
#' - `extraction.model` settato dal caller R (non dal contenuto LLM)
#' - `extraction.raw_input_hash` calcolato deterministicamente da
#'   sha256(sample_string)
#'
#' Tutti gli altri campi sono lasciati al modello (Structured Outputs ne ha
#' gia' verificato la conformita' allo schema).
#'
#' @param raw lista R parsed dal JSON di risposta LLM
#' @param sample_string testo originale del sample
#' @param geo_accession GSM id originale
#' @param series_id GSE id originale
#' @param model nome del modello (es. "gpt-5.5"); verra' prefissato con
#'   "openai:" nell'output
#' @return lista R con i campi forzati
#' @keywords internal
parse_stage1_response <- function(raw,
                                  sample_string,
                                  geo_accession,
                                  series_id,
                                  model) {
  stopifnot(is.list(raw), is.list(raw$extraction))

  raw$geo_accession <- geo_accession
  raw$series_id     <- series_id

  raw$extraction$schema_version <- "stage1.v3"
  raw$extraction$model          <- paste0("openai:", model)
  raw$extraction$raw_input_hash <- paste0("sha256:", sha256_text(sample_string))

  raw
}

#' Costruisce i messages per la chiamata Stadio 1
#'
#' @param sample_string testo concatenato dei metadati del sample
#' @param geo_accession GSM id (verra' copiato verbatim nell'output dall'LLM)
#' @param series_id GSE id (idem)
#' @param organism_hint hint opzionale (es. "Homo sapiens"); incluso nello user
#'   message solo se non NULL
#' @return list di 2 messages (`system`, `user`) nel formato OpenAI Chat
#' @keywords internal
build_prompt_stage1 <- function(sample_string,
                                geo_accession,
                                series_id,
                                organism_hint = NULL) {
  stopifnot(
    is.character(sample_string), length(sample_string) == 1L, nzchar(sample_string),
    is.character(geo_accession), length(geo_accession) == 1L, nzchar(geo_accession),
    is.character(series_id),     length(series_id)     == 1L, nzchar(series_id)
  )

  user_lines <- c(
    paste0("geo_accession: ", geo_accession),
    paste0("series_id: ", series_id),
    if (!is.null(organism_hint)) paste0("organism_hint: ", organism_hint),
    "sample_string:",
    sample_string
  )

  list(
    list(role = "system", content = .stage1_system_prompt()),
    list(role = "user",   content = paste(user_lines, collapse = "\n"))
  )
}

#' Classifica un sample RNAseq nello Stadio 1 (sample_facts schema v3)
#'
#' Orchestra: build_prompt_stage1 -> llm_call_structured (con cache + Structured
#' Outputs strict) -> parse_stage1_response (enrichment deterministico).
#'
#' @param sample_string stringa di metadati GEO concatenati (input)
#' @param geo_accession GSM id
#' @param series_id GSE id
#' @param provider `"openai"` (default) o `"mock"` (test)
#' @param model nome del modello (default `"gpt-5.5"` -- spec sec.5.3.1 dev set)
#' @param cache oggetto `cache` (`cache_init()`), oppure `NULL` per bypass
#' @param organism_hint hint opzionale per lo user message
#' @param ... inoltrato all'adapter (es. `temperature`, `max_tokens`,
#'   `.mock_adapter` per test)
#'
#' @return lista come da `llm_call_structured()`: `value` (sample_fact post
#'   enrichment), `provider`, `model`, `validated`, `cache_hit`, `raw_response`.
#' @export
classify_sample <- function(sample_string,
                            geo_accession,
                            series_id,
                            provider = "openai",
                            model    = "gpt-5.5",
                            cache    = NULL,
                            organism_hint = NULL,
                            ...) {
  schema_path <- system.file(
    "schemas/sample_facts.stage1.v3.json",
    package = "simulomicsr"
  )
  if (!nzchar(schema_path)) {
    rlang::abort(
      "Schema sample_facts.stage1.v3.json non trovato nel pacchetto installato.",
      class = "simulomicsr_schema_missing"
    )
  }

  messages <- build_prompt_stage1(
    sample_string = sample_string,
    geo_accession = geo_accession,
    series_id     = series_id,
    organism_hint = organism_hint
  )

  res <- llm_call_structured(
    provider                = provider,
    model                   = model,
    messages                = messages,
    response_schema         = schema_path,
    cache                   = cache,
    cache_namespace_version = "stage1.v3",
    ...
  )

  res$value <- parse_stage1_response(
    res$value,
    sample_string = sample_string,
    geo_accession = geo_accession,
    series_id     = series_id,
    model         = model
  )
  res
}

#' Wrapper per dynamic branching `targets`: prende una riga tibble e ritorna
#' direttamente il `sample_fact` (senza l'envelope di `classify_sample()`).
#'
#' Errori (`simulomicsr_schema_error`, `simulomicsr_openai_*`) sono catturati
#' e tradotti in un sample_fact "minimo invalido" con `extraction.confidence=0`
#' e `ambiguity_flags = ["metadata_inconsistency"]` -- il filtro di validazione
#' a valle li separera' in `sample_facts_invalid`.
#'
#' @keywords internal
classify_sample_row <- function(row,
                                provider = "openai",
                                model    = "gpt-5.5",
                                cache    = NULL,
                                ...) {
  stopifnot(nrow(row) == 1L)

  tryCatch(
    {
      res <- classify_sample(
        sample_string = row$string,
        geo_accession = row$geo_accession,
        series_id     = row$series_id,
        provider      = provider,
        model         = model,
        cache         = cache,
        ...
      )
      res$value
    },
    simulomicsr_schema_error = function(e) {
      .stage1_invalid_record(row, model, reason = "schema_error",
                             detail = paste(e$errors, collapse = " | "))
    },
    simulomicsr_openai_truncated = function(e) {
      .stage1_invalid_record(row, model, reason = "openai_truncated",
                             detail = e$finish_reason)
    },
    simulomicsr_openai_bad_json = function(e) {
      .stage1_invalid_record(row, model, reason = "openai_bad_json",
                             detail = "")
    }
  )
}

#' Sample fact "scheletro" usato per registrare un fallimento del classificatore
#' senza rompere la pipeline. Schema-conforme (passa il validator) ma con
#' segnali chiari nei campi `extraction` e `ambiguity_flags`.
#' @keywords internal
.stage1_invalid_record <- function(row, model, reason, detail) {
  list(
    geo_accession = row$geo_accession,
    series_id     = row$series_id,
    organism      = NULL,
    host_organism = NULL,
    cell_context  = list(
      cell_type_or_line_raw = NULL, cell_line_cellosaurus_candidate = NULL,
      tissue = NULL, tissue_segment = NULL, passage_or_state = NULL,
      context_kind = "unclear", developmental_stage = NULL, cell_state = NULL,
      subcellular_fraction = NULL, engineered_modifications = list(),
      co_culture_partners = list(), sort_markers = list(),
      cell_composition_estimates = list()
    ),
    disease_state = list(term_raw = NULL, mesh_id_candidate = NULL, status = "none"),
    perturbations = list(),
    technical_treatments = list(),
    patient_metadata = NULL,
    extraction = list(
      schema_version = "stage1.v3",
      model          = paste0("openai:", model),
      confidence     = 0,
      ambiguity_flags = list("metadata_inconsistency"),
      raw_input_hash = paste0("sha256:", sha256_text(row$string))
    ),
    .invalid_reason = reason,   # campo extra non in schema; usato dal partition
    .invalid_detail = detail
  )
}
