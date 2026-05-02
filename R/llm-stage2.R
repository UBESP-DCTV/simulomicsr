#' Costruisci il prompt Stadio 2 (study_design) per un GSE
#'
#' Crea i messages OpenAI-shape (system + user) e il path allo schema strict.
#' Pronto da passare a llm_call_structured().
#'
#' @param series_id GSE accession
#' @param sample_facts_list lista di sample_facts validati (stage1.v3) per
#'   tutti i GSM dello studio
#' @param study_summary list con campi series_id/title/summary/overall_design
#' @param model string (es. "openai:gpt-5.5"), inserito nel system per audit
#'
#' @return list con campi `messages` (list di 2 messages role=system/user)
#'   e `schema_path` (path al JSON Schema stage2.v1)
#' @keywords internal
build_prompt_stage2 <- function(series_id, sample_facts_list, study_summary,
                                model = "openai:gpt-5.5") {
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  if (!nzchar(schema_path)) {
    rlang::abort(
      "Schema study_design.stage2.v1.json non trovato",
      class = "simulomicsr_schema_missing"
    )
  }

  list(
    messages = list(
      list(role = "system", content = .stage2_system_prompt(model)),
      list(role = "user", content = .stage2_user_prompt(
        series_id = series_id,
        sample_facts_list = sample_facts_list,
        study_summary = study_summary
      ))
    ),
    schema_path = schema_path
  )
}

#' @noRd
.STAGE2_DESIGN_KINDS <- paste(
  "- case_control_disease",
  "- treatment_vs_vehicle",
  "- treatment_vs_untreated",
  "- time_course",
  "- dose_response",
  "- knockdown_panel",
  "- factorial",
  "- differentiation_course",
  "- multi_arm_treatment",
  "- unclear",
  sep = "\n"
)

#' @noRd
.STAGE2_DESIGN_ROLES <- paste(
  "- perturbed",
  "- vehicle_control",
  "- untreated_control",
  "- negative_genetic_control",
  "- negative_inducer_control",
  "- positive_control",
  "- baseline_t0",
  "- case",
  "- comparison",
  "- bystander",
  "- secondary_arm",
  "- excluded",
  "- unclear",
  sep = "\n"
)

#' @noRd
.stage2_system_prompt <- function(model) {
  paste0(
    "Sei un esperto di design sperimentale RNA-seq. Devi ricostruire il design ",
    "di uno studio GSE a partire da: (a) i sample_facts gia' classificati di ",
    "tutti i GSM dello studio, (b) il titolo + summary GEO. Produci un oggetto ",
    "JSON conforme allo schema study_design.stage2.v1 (strict).\n\n",
    "## design_kind (scegli UNO)\n",
    .STAGE2_DESIGN_KINDS, "\n\n",
    "## design_role (per ogni replicate_group)\n",
    .STAGE2_DESIGN_ROLES, "\n\n",
    "## Linee guida\n",
    "- Raggruppa i sample in replicate_groups in base a fattori condivisi ",
    "(stesso trattamento, stessa dose, stesso tempo, stesso controllo).\n",
    "- Identifica ESPLICITAMENTE i fattori manipolati nel design (factors[]).\n",
    "- Costruisci comparisons solo dove c'e' un control_group ben identificabile ",
    "(vehicle_control, baseline_t0, untreated_control, comparison, negative_genetic_control).\n",
    "- Per design factorial: una comparison per ogni varying_factor.\n",
    "- Se il design non e' ricostruibile, design_kind='unclear', comparisons=[], ",
    "ambiguity_flags spiega il motivo.\n",
    "- comparison_id formato: '<series_id>__<treated>_vs_<control>'.\n",
    "- study_internal_score: 0..1, qualita' del confronto (n_replicates, balance).\n",
    "- input_truncated: true se hai dovuto omettere sample_facts per limiti di token.\n",
    "- factor_levels e fixed_factors sono ARRAY di oggetti {\"key\": \"...\", \"value\": \"...\"} ",
    "(NON oggetti con chiavi libere — schema strict lo richiede).\n\n",
    "Modello: ", model
  )
}

#' @noRd
.stage2_user_prompt <- function(series_id, sample_facts_list, study_summary) {
  facts_json <- jsonlite::toJSON(sample_facts_list, auto_unbox = TRUE,
                                 null = "null", pretty = TRUE)
  paste0(
    "## series_id\n", series_id, "\n\n",
    "## study_title\n", study_summary$title %||% "(missing)", "\n\n",
    "## study_summary\n", study_summary$summary %||% "(missing)", "\n\n",
    "## overall_design\n", study_summary$overall_design %||% "(missing)", "\n\n",
    "## sample_facts (n=", length(sample_facts_list), ")\n",
    facts_json
  )
}

#' Classifica il design di uno studio GSE in study_design.stage2.v1
#'
#' Pipeline: build_prompt_stage2() -> llm_call_structured() -> parse_stage2_response().
#' Cache trasparente via P1 (la chiave include i messages, separa naturalmente
#' le invocazioni Stadio 1 da Stadio 2). In caso di errore LLM, ritorna un
#' record con .invalid_reason e .invalid_detail (non solleva: il chiamante
#' filtra a valle in study_designs_validated/invalid).
#'
#' @param series_id GSE accession
#' @param sample_facts_list lista di sample_facts validati (stage1.v3)
#' @param study_summary list con title/summary/overall_design (da fetch_study_summary)
#' @param provider "openai" (default) o futuri provider
#' @param model "gpt-5.5" (default), "gpt-5.4-mini" per batch, ecc.
#' @param cache cache object da cache_init()
#' @param ... args passati a llm_call_structured
#'
#' @return list (study_design valido stage2.v1) oppure list con
#'   campi .invalid_reason/.invalid_detail in caso di failure LLM.
#' @export
classify_study <- function(series_id, sample_facts_list, study_summary,
                           provider = "openai",
                           model = "gpt-5.5",
                           cache,
                           ...) {
  prompt <- build_prompt_stage2(
    series_id = series_id,
    sample_facts_list = sample_facts_list,
    study_summary = study_summary,
    model = paste0(provider, ":", model)
  )

  res <- tryCatch(
    llm_call_structured(
      provider                = provider,
      model                   = model,
      messages                = prompt$messages,
      response_schema         = prompt$schema_path,
      cache                   = cache,
      cache_namespace_version = "stage2.v1",
      ...
    ),
    simulomicsr_schema_error = function(e) {
      list(
        .llm_error        = TRUE,
        .error_reason     = "schema_validation_failed",
        .error_detail     = paste(e$errors %||% conditionMessage(e), collapse = " | ")
      )
    },
    error = function(e) {
      list(
        .llm_error    = TRUE,
        .error_reason = "llm_call_failed",
        .error_detail = conditionMessage(e)
      )
    }
  )

  if (isTRUE(res$.llm_error)) {
    return(.stage2_invalid_record(
      series_id    = series_id,
      reason       = res$.error_reason,
      detail       = res$.error_detail %||% NA_character_,
      sample_count = length(sample_facts_list),
      provider     = provider,
      model        = model
    ))
  }

  parse_stage2_response(
    raw          = res$value,
    series_id    = series_id,
    sample_count = length(sample_facts_list),
    model        = paste0(provider, ":", model)
  )
}

#' Crea un record stage2 invalido per segnalare fallimenti LLM senza
#' interrompere la pipeline
#'
#' @keywords internal
.stage2_invalid_record <- function(series_id, reason, detail, sample_count,
                                   provider, model) {
  list(
    series_id = series_id,
    .invalid_reason = reason,
    .invalid_detail = detail,
    extraction = list(
      schema_version    = "stage2.v1",
      model             = paste0(provider, ":", model),
      confidence        = 0,
      ambiguity_flags   = list(),
      input_sample_count = as.integer(sample_count),
      input_truncated   = FALSE
    )
  )
}

#' Enrichi la risposta stage2 con metadata deterministici dal chiamante
#'
#' Forza `series_id`, `schema_version`, `model` e `input_sample_count` dal
#' contesto del caller. Non siamo mai completamente fiduciosi che l'LLM abbia
#' interpretato correttamente questi campi.
#'
#' @param raw Risposta parsed JSON (list), già validata contro stage2.v1
#' @param series_id GSE accession (forzato)
#' @param sample_count numero intero di sample input (forzato come input_sample_count)
#' @param model string modello usato (forzato come model)
#'
#' @return raw (list) con `series_id`, `extraction$schema_version='stage2.v1'`,
#'   `extraction$model`, `extraction$input_sample_count` sovrascritti.
#'   Se `extraction` non esiste, viene creato come lista vuota.
#'
#' @keywords internal
parse_stage2_response <- function(raw, series_id, sample_count, model) {
  if (!is.list(raw)) {
    rlang::abort(
      "parse_stage2_response: raw deve essere lista (parsed JSON)",
      class = "simulomicsr_stage2_parse_error"
    )
  }
  raw$series_id <- series_id
  if (is.null(raw$extraction) || !is.list(raw$extraction)) {
    raw$extraction <- list()
  }
  raw$extraction$schema_version <- "stage2.v1"
  raw$extraction$model <- model
  raw$extraction$input_sample_count <- as.integer(sample_count)
  if (is.null(raw$extraction$input_truncated)) {
    raw$extraction$input_truncated <- FALSE
  }
  raw
}
