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
  "- treated  (receives active treatment/perturbation in the study's MAIN comparison)",
  "- control  (reference group of the MAIN comparison; the TYPE of control goes on comparisons[].control_type)",
  "- bystander  (cells not directly perturbed that share culture/tissue)",
  "- excluded  (unsuitable sample: failed QC, declared outlier)",
  "- unclear  (role not reconstructible from metadata)",
  sep = "\n"
)

#' @noRd
.STAGE2_CONTROL_TYPES <- paste(
  "- vehicle           (DMSO, PBS, mock - treatment vehicle only)",
  "- untreated         (no treatment and no vehicle declared)",
  "- genetic_negative  (siNT, scrambled, empty vector, non-targeting)",
  "- inducer_off       (inducible system NOT induced: no-Dox, no-IPTG, no-4OHT)",
  "- disease_normal    (healthy sample in a disease vs normal design)",
  "- time_zero         (t=0 in time-course used as reference)",
  "- secondary_arm     (control = another treatment arm, not absence)",
  sep = "\n"
)

#' @noRd
.stage2_system_prompt <- function(model) {
  paste0(
    "You are an expert in RNA-seq experimental design. You must reconstruct ",
    "the design of a GSE study from: (a) the already-classified sample_facts ",
    "for every GSM in the study, (b) the GEO title + summary. Produce a JSON ",
    "object conforming to the study_design.stage2.v2 schema (strict).\n\n",
    "OUTPUT FORMAT (CRITICAL): respond with the JSON object ONLY, with no ",
    "text before or after, no comments, no markdown code fences ",
    "(```json ... ```). The response must start with `{` and end with `}`.\n\n",
    "## v2 Philosophy (important)\n",
    "A control is NOT a standalone category: it exists only IN RELATION to ",
    "the treated group it references. Therefore:\n",
    "- On the replicate_group: assign ONLY a primary_role from 5 simple ",
    "values (treated/control/bystander/excluded/unclear). The primary_role ",
    "describes the group's role in the study's MAIN comparison.\n",
    "- On the comparison: the TYPE of control (vehicle, untreated, ",
    "genetic_negative, inducer_off, disease_normal, time_zero, secondary_arm) ",
    "is a property of the RELATION, not of the sample. The same sample can ",
    "have different control_type values across different comparisons.\n\n",
    "## study design_kind (pick ONE; for multi_arm_treatment it is OK that ",
    "individual comparisons have a different specific design_kind)\n",
    .STAGE2_DESIGN_KINDS, "\n\n",
    "## replicate_group primary_role (5 values)\n",
    .STAGE2_PRIMARY_ROLES, "\n\n",
    "## comparison control_type (7 values)\n",
    .STAGE2_CONTROL_TYPES, "\n\n",
    "## Input format: pre-deduplicated design conditions (IMPORTANT)\n",
    "Each entry in `samples:` is NOT an individual GSM but a DISTINCT ",
    "experimental condition, already deduplicated across replicates upstream. ",
    "For each entry: `geo_accession` is a REPRESENTATIVE sample of the ",
    "condition; `n_replicates` is how many biologically-equivalent replicate ",
    "samples the condition stands for; `sample_facts` are the facts of the ",
    "representative.\n",
    "Treat each entry as ONE condition that is ALREADY a replicate set of size ",
    "`n_replicates`. Therefore:\n",
    "- Put the representative `geo_accession` (one per entry) into sample_ids; ",
    "do NOT split an entry. Each entry is typically its own replicate_group.\n",
    "- Use `n_replicates` as the replicate count of that group (for quality / ",
    "study_internal_score), even though sample_ids lists a single ",
    "representative.\n",
    "- Merge two entries into the same group ONLY if they are truly the same ",
    "condition.\n",
    "- RULE 4 (do not omit) applies to every entry/condition.\n\n",
    "## Grouping guidelines (strict)\n",
    "- Group into the SAME replicate_group ONLY samples with IDENTICAL ",
    "conditions (same treatment, dose, time, cell line, genotype). Samples ",
    "differing in even a single condition go in distinct groups.\n",
    "- Replicates are already merged upstream into one entry with ",
    "`n_replicates` (see Input format). Do NOT re-split an entry into multiple ",
    "groups, and do NOT merge distinct entries unless they are truly identical ",
    "conditions.\n\n",
    "## Comparison guidelines (important for the meta-analysis)\n",
    "- Create comparisons only where a control_group is clearly identifiable.\n",
    "- Each comparison has treated_group + control_group + control_type + ",
    "specific design_kind. control_type is DERIVED from the nature of the ",
    "control_group: if the control_group samples have perturbation kind=vehicle, ",
    "control_type=vehicle; if kind=null and no perturbation, control_type=untreated; ",
    "if the only difference from the treated is timepoint=0, control_type=time_zero; etc.\n",
    "- THE SAME replicate_group can appear as control_group in multiple ",
    "comparisons with different control_type (e.g. a factorial study).\n",
    "- For factorial designs: one comparison per varying_factor.\n",
    "- If no comparison is reconstructible, comparisons=[], design_kind='unclear', ",
    "ambiguity_flags explains the reason.\n",
    "- comparison_id format: '<series_id>__<treated>_vs_<control>'.\n",
    "- study_internal_score: 0..1, quality of the comparison (n_replicates, balance).\n",
    "- input_truncated: true if the input contains a 'chunk: X/Y' line (subset ",
    "of the total) or 'study_total_samples: N' with N greater than the number ",
    "of samples in 'samples', or if you had to omit sample_facts due to token ",
    "limits. When you see 'chunk: X/Y', infer the design ONLY from the visible ",
    "samples and mark input_truncated=true; cross-chunk reconciliation happens ",
    "downstream in eval. ambiguity_flags may include 'partial_chunk' in these cases.\n",
    "- factor_levels and fixed_factors are ARRAYS of objects ",
    "{\"key\": \"...\", \"value\": \"...\"} (NOT objects with free keys \u2014 ",
    "the strict schema requires this).\n\n",
    "## STRICT rules for primary_role (important \u2014 mini-gold v5 evaluation ",
    "showed the model frequently misclassifies these cases)\n",
    "RULE 1 (vehicle/baseline = control): if the sample has 'treatment' equal ",
    "to one of the following literal baselines, primary_role = 'control' ",
    "(NOT 'treated'):\n",
    "  - DMSO, PBS, saline, water, ethanol, vehicle, vehicle_only\n",
    "  - untreated, no treatment, none, mock, control\n",
    "  - mock infection, mock-infection, mock infected, scrambled\n",
    "  - non-targeting siRNA (siNT), non targeting, NT control\n",
    "  - empty vector, EV, vector only, EGFP control, GFP control\n",
    "On the comparison this becomes control_type = ",
    "vehicle/untreated/genetic_negative according to nature.\n",
    "RULE 2 (time-zero = control): in time_course designs, samples with ",
    "time=0 (e.g. 'time(hours): 0', 't0', 'baseline') are primary_role='control' ",
    "even if they carry 'treatment: X induced' or similar. The treatment is ",
    "present but at t=0 has not yet taken effect. control_type=time_zero.\n",
    "RULE 3 (genotype baseline in factorial): if the design is factorial ",
    "genotype \u00d7 treatment, and there is a combination 'WT + untreated' or ",
    "'WT + DMSO' or an equivalent baseline-baseline, those samples are ",
    "primary_role='control'. 'WT + drug' samples are treated on the drug ",
    "axis. 'KO + untreated' samples are control for the drug axis within the ",
    "KO sub-design.\n",
    "RULE 4 (DO NOT OMIT): EVERY sample in the input MUST appear in a ",
    "replicate_group (treated, control, bystander, excluded, or unclear). ",
    "DO NOT omit samples from the output. If a sample is unclear, put it ",
    "in a group with primary_role='unclear' instead of excluding it.\n\n",
    "Model: ", model
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

