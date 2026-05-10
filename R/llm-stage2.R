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
#' @param extra_instruction string opzionale (default NULL) appesa al messaggio
#'   user come paragrafo finale. Usata p.es. per investigation verbose-reasoning.
#'
#' @return list con campi `messages` (list di 2 messages role=system/user)
#'   e `schema_path` (path al JSON Schema stage2.v1)
#' @keywords internal
build_prompt_stage2 <- function(series_id, sample_facts_list, study_summary,
                                model = "openai:gpt-5.5",
                                extra_instruction = NULL) {
  schema_path <- system.file("schemas/study_design.stage2.v2.json",
                             package = "simulomicsr")
  if (!nzchar(schema_path)) {
    rlang::abort(
      "Schema study_design.stage2.v2.json non trovato",
      class = "simulomicsr_schema_missing"
    )
  }

  user_content <- .stage2_user_prompt(
    series_id = series_id,
    sample_facts_list = sample_facts_list,
    study_summary = study_summary
  )
  if (!is.null(extra_instruction) && nzchar(extra_instruction)) {
    user_content <- paste0(user_content, "\n\n", extra_instruction)
  }

  list(
    messages = list(
      list(role = "system", content = .stage2_system_prompt(model)),
      list(role = "user", content = user_content)
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
.STAGE2_PRIMARY_ROLES <- paste(
  "- treated  (riceve trattamento/perturbazione attiva nel confronto MAIN dello studio)",
  "- control  (gruppo di riferimento del confronto MAIN; il TIPO di controllo va su comparisons[].control_type)",
  "- bystander  (cellule non-direttamente perturbed che condividono coltura/tessuto)",
  "- excluded  (sample inadatto: QC fallito, outlier dichiarato)",
  "- unclear  (ruolo non ricostruibile dai metadati)",
  sep = "\n"
)

#' @noRd
.STAGE2_CONTROL_TYPES <- paste(
  "- vehicle           (DMSO, PBS, mock - solo veicolo del trattamento)",
  "- untreated         (nessun trattamento e nessun vehicle dichiarato)",
  "- genetic_negative  (siNT, scrambled, empty vector, non-targeting)",
  "- inducer_off       (sistema inducibile NON indotto: no-Dox, no-IPTG, no-4OHT)",
  "- disease_normal    (sample sano in un disegno disease vs normal)",
  "- time_zero         (t=0 in time-course usato come riferimento)",
  "- secondary_arm     (controllo = altro braccio del trattamento, non assenza)",
  sep = "\n"
)

#' @noRd
.stage2_system_prompt <- function(model) {
  paste0(
    "Sei un esperto di design sperimentale RNA-seq. Devi ricostruire il design ",
    "di uno studio GSE a partire da: (a) i sample_facts gia' classificati di ",
    "tutti i GSM dello studio, (b) il titolo + summary GEO. Produci un oggetto ",
    "JSON conforme allo schema study_design.stage2.v2 (strict).\n\n",
    "OUTPUT FORMAT (CRITICAL): rispondi con il SOLO oggetto JSON nudo, senza ",
    "alcun testo prima o dopo, senza commenti, senza markdown code fences ",
    "(```json ... ```). La risposta deve iniziare con `{` e finire con `}`.\n\n",
    "## Filosofia v2 (importante)\n",
    "Un controllo NON esiste come categoria autonoma: esiste solo IN RELAZIONE ",
    "al trattato di cui e' riferimento. Quindi:\n",
    "- Sul replicate_group: assegna SOLO un primary_role tra 5 valori semplici ",
    "(treated/control/bystander/excluded/unclear). Il primary_role descrive il ",
    "ruolo del gruppo nel confronto MAIN dello studio.\n",
    "- Sul comparison: il TIPO di controllo (vehicle, untreated, genetic_negative, ",
    "inducer_off, disease_normal, time_zero, secondary_arm) e' una property della ",
    "RELAZIONE, non del sample. Lo stesso sample puo' avere control_type diversi ",
    "in comparisons diverse.\n\n",
    "## design_kind dello studio (scegli UNO; per multi_arm_treatment e' OK ",
    "che i singoli comparison abbiano design_kind specifico diverso)\n",
    .STAGE2_DESIGN_KINDS, "\n\n",
    "## primary_role del replicate_group (5 valori)\n",
    .STAGE2_PRIMARY_ROLES, "\n\n",
    "## control_type del comparison (7 valori)\n",
    .STAGE2_CONTROL_TYPES, "\n\n",
    "## Linee guida raggruppamento (rigoroso)\n",
    "- Raggruppa nello STESSO replicate_group SOLO sample con condizioni ",
    "IDENTICHE (stesso trattamento, dose, tempo, linea cellulare, genotype). ",
    "Sample con anche una sola differenza vanno in gruppi distinti.\n",
    "- Replicati biologici/tecnici stesso gruppo. Non perdere granularita': ",
    "se due sample sembrano identici, mettili nello stesso group con ",
    "n_replicates >= 2 (la lunghezza di sample_ids).\n\n",
    "## Linee guida comparisons (importante per la meta-analisi)\n",
    "- Crea comparisons solo dove c'e' un control_group ben identificabile.\n",
    "- Ogni comparison ha treated_group + control_group + control_type + ",
    "design_kind specifico. Il control_type e' DEDOTTO dalla natura del ",
    "control_group: se i sample del control_group hanno perturbation kind=vehicle, ",
    "control_type=vehicle; se kind=null e nessuna perturbation, control_type=untreated; ",
    "se l'unica differenza dal treated e' il timepoint=0, control_type=time_zero; ecc.\n",
    "- LO STESSO replicate_group puo' apparire come control_group in piu' ",
    "comparisons con control_type diversi (es. uno studio factoriale).\n",
    "- Per design factorial: una comparison per ogni varying_factor.\n",
    "- Se nessun confronto e' ricostruibile, comparisons=[], design_kind='unclear', ",
    "ambiguity_flags spiega il motivo.\n",
    "- comparison_id formato: '<series_id>__<treated>_vs_<control>'.\n",
    "- study_internal_score: 0..1, qualita' del confronto (n_replicates, balance).\n",
    "- input_truncated: true se l'input contiene una riga 'chunk: X/Y' (sub-set ",
    "del totale) o 'study_total_samples: N' con N maggiore del numero di sample ",
    "in 'samples', oppure se hai dovuto omettere sample_facts per limiti di token. ",
    "Quando vedi 'chunk: X/Y', inferisci il design SOLO dai sample visibili e ",
    "marca input_truncated=true; la riconciliazione cross-chunk avviene a ",
    "valle in eval. ambiguity_flags puo' includere 'partial_chunk' in questi casi.\n",
    "- factor_levels e fixed_factors sono ARRAY di oggetti ",
    "{\"key\": \"...\", \"value\": \"...\"} (NON oggetti con chiavi libere \u2014 ",
    "schema strict lo richiede).\n\n",
    "## Regole RIGIDE per primary_role (importanti \u2014 eval mini-gold v5 ha ",
    "mostrato che il modello sbaglia spesso questi casi)\n",
    "REGOLA 1 (vehicle/baseline = control): se il sample ha 'treatment' ",
    "uguale a uno dei seguenti baseline letterali, primary_role = 'control' ",
    "(NON 'treated'):\n",
    "  - DMSO, PBS, saline, water, ethanol, vehicle, vehicle_only\n",
    "  - untreated, no treatment, none, mock, control\n",
    "  - mock infection, mock-infection, mock infected, scrambled\n",
    "  - non-targeting siRNA (siNT), non targeting, NT control\n",
    "  - empty vector, EV, vector only, EGFP control, GFP control\n",
    "Sul comparison sara' control_type = vehicle/untreated/genetic_negative ",
    "secondo natura.\n",
    "REGOLA 2 (time-zero = control): in design time_course, i sample con ",
    "tempo=0 (es. 'time(hours): 0', 't0', 'baseline') sono primary_role='control' ",
    "anche se hanno 'treatment: X induced' o simili. Il treatment e' presente ",
    "ma a t=0 non ha ancora avuto effetto. control_type=time_zero.\n",
    "REGOLA 3 (genotype baseline in factorial): se il design e' factoriale ",
    "genotype \u00d7 treatment, e c'e' una combinazione 'WT + untreated' o ",
    "'WT + DMSO' o equivalente baseline-baseline, quei sample sono ",
    "primary_role='control'. I sample 'WT + drug' sono treated dell'asse drug. ",
    "I sample 'KO + untreated' sono control per l'asse drug nel sub-design KO.\n",
    "REGOLA 4 (NON OMETTERE): OGNI sample dell'input DEVE comparire in un ",
    "replicate_group (treated, control, bystander, excluded, o unclear). ",
    "NON omettere sample dall'output. Se un sample non si capisce, mettilo ",
    "in un gruppo con primary_role='unclear' invece che escluderlo.\n\n",
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
#' @param extra_instruction string opzionale (default NULL) appesa al prompt
#'   user. Usata da reclassify_verbose() per richiedere chain-of-thought.
#' @param ... args passati a llm_call_structured
#'
#' @return list (study_design valido stage2.v1) oppure list con
#'   campi .invalid_reason/.invalid_detail in caso di failure LLM.
#' @export
classify_study <- function(series_id, sample_facts_list, study_summary,
                           provider = "openai",
                           model = "gpt-5.5",
                           cache,
                           extra_instruction = NULL,
                           ...) {
  prompt <- build_prompt_stage2(
    series_id = series_id,
    sample_facts_list = sample_facts_list,
    study_summary = study_summary,
    model = paste0(provider, ":", model),
    extra_instruction = extra_instruction
  )

  res <- tryCatch(
    llm_call_structured(
      provider                = provider,
      model                   = model,
      messages                = prompt$messages,
      response_schema         = prompt$schema_path,
      cache                   = cache,
      cache_namespace_version = "stage2.v2",
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
      schema_version    = "stage2.v2",
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
#' @param raw Risposta parsed JSON (list), gia' validata contro stage2.v1
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
  raw$extraction$schema_version <- "stage2.v2"
  raw$extraction$model <- model
  raw$extraction$input_sample_count <- as.integer(sample_count)
  if (is.null(raw$extraction$input_truncated)) {
    raw$extraction$input_truncated <- FALSE
  }
  raw
}

#' Recovery heuristic per output stage2 JSON-parse fallito
#'
#' Tenta di parsare un raw_output stage2 che inizialmente ha fallito
#' \code{json.loads} applicando patch noti del modello Mistral-3.2:
#'
#' 1. **markdown fence strip**: rimuove ` ```json ... ``` ` wrapper se presente.
#' 2. **missing "value": patch**: regex re-inserisce il token \code{"value":}
#'    nei pattern \code{\{"key": "X", "RAWVAL"\}} -> \code{\{"key": "X", "value": "RAWVAL"\}}.
#'    Mistral-3.2 occasionalmente droppa quel token nei \code{factor_levels}
#'    array; pattern identificato 2026-05-10 nei 17 residual α stage2 (3/17
#'    recoverable lossless con questo patch).
#'
#' Heuristic safe: applica il patch SOLO dove il pattern e' inequivocabile
#' (key+scalar value, niente nested objects). Se il parse continua a
#' fallire, ritorna NULL.
#'
#' @param raw_output stringa raw output dal modello.
#' @return list con \code{parsed_json} (NULL se irrecuperabile),
#'   \code{applied_patches} (character vector dei patch applicati).
#' @keywords internal
.try_recover_stage2_json <- function(raw_output) {
  if (is.null(raw_output) || !nzchar(raw_output))
    return(list(parsed_json = NULL, applied_patches = character(0)))
  s <- raw_output
  # Markdown fence strip
  s <- sub("^```(json)?\\s*", "", s)
  s <- sub("\\s*```\\s*$", "", s)
  # Tentativo 1: parse diretto post-strip
  parsed <- tryCatch(
    jsonlite::fromJSON(s, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (!is.null(parsed))
    return(list(parsed_json = parsed, applied_patches = character(0)))
  # Tentativo 2: missing-value patch
  s2 <- gsub(
    '(\\{\\s*"key"\\s*:\\s*"[^"]+"\\s*,\\s*)("[^"]+")(\\s*\\})',
    '\\1"value": \\2\\3', s, perl = TRUE
  )
  if (!identical(s2, s)) {
    parsed <- tryCatch(
      jsonlite::fromJSON(s2, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (!is.null(parsed))
      return(list(parsed_json = parsed,
                  applied_patches = "missing_value"))
  }
  list(parsed_json = NULL, applied_patches = character(0))
}
