# simulomicsr 0.0.0.9005

## P3.5-B — eval benchmark Stadio 2 sui 15 GSE (prototipo)

- `R/eval-stage2.R`: `design_role_to_binary()` (mapping 13->3 esteso vs spec
  v5 §6.2), `eval_binary_accuracy()`, `eval_per_design_kind()`,
  `flag_granularity_disagreement()`. Tutti export pubblici.
- `R/eval-rummageo.R`: `fetch_rummageo_signatures()` (cache filesystem JSONL,
  retry exponential backoff, abort `simulomicsr_rummageo_unavailable` se
  GSE non in RummaGEO), `parse_rummageo_labels()`,
  `rummageo_baseline_internal()` (replica K-means+keyword, fallback per
  GSE non indicizzati).
- `analysis/_targets.R`: 7 nuovi target (gold_table_subset,
  eval_stage2_gold_join, eval_stage2_metrics, rummageo_cache_dir,
  rummageo_signatures, rummageo_metrics, eval_p35_report).
- `analysis/eval/p35-benchmark.Rmd`: Quarto report 4 sezioni (binary
  accuracy, granularity, anchor coverage, RummaGEO head-to-head).

## Risultati run reale 15 GSE (197 sample)

| Metrica | Valore |
|---|---|
| Stage 2 binary accuracy globale | 75.1% (n=197) |
| time_course / treatment_vs_vehicle / knockdown_panel | 100% |
| dose_response | 85.7% |
| factorial | 78.1% |
| treatment_vs_untreated | 41.7% (sotto casuale, da investigare in P3.5-A) |
| multi_arm_treatment | 66.0% |
| Granularity flagged | 22 sample |
| simulomicsr vs gold | 0.751 (n=197) |
| RummaGEO vs gold | 0.696 (n=184) |
| **Delta simulomicsr - RummaGEO** | **+5.5 pp** |

Costo P3.5-B: $0 (riuso totale cache P3, no LLM call).

## Discoveries Task 5 (RummaGEO API)

- GraphQL endpoint /graphql funzionante; REST /api/signatures non usabile
- 12/15 GSE NON indicizzati in RummaGEO official -> fallback interno
  K-means+keyword. 39/197 sample hanno match RummaGEO ufficiale.
- RummaGEO `sampleGroups` schema: titles {1: "ko label", 2: "control label"},
  samples {1: [...], 2: [...]}. Indice numerico minore = trattato.

# simulomicsr 0.0.0.9004

## Stadio 2 (P3) — study_design + comparability_anchor + benchmark robusto

- Schema strict `inst/schemas/study_design.stage2.v1.json` per OpenAI Structured
  Outputs (vocab `design_kind` 10 valori, `design_role` 13 valori). Strict-mode
  fix: `factor_levels`/`fixed_factors` come array di `{key, value}` invece di
  dict (OpenAI rifiuta `additionalProperties:{type:string}` nested).
- `R/llm-stage2.R`: `build_prompt_stage2()` (internal), `parse_stage2_response()`
  (internal), **`classify_study()`** (export pubblico).
- `R/geo-fetch.R`: **`fetch_study_summary()`** (export) wrapper su
  `rentrez::entrez_summary(db="gds")` con cache filesystem JSONL.
- `R/anchors.R`: helpers privati `.normalize_dose()`, `.normalize_duration()`,
  `.normalize_cell_id()`; **`make_anchor()`** (export, 13 segmenti v3, regole
  R8/R9/R24/R25/R31 + disease_vs_normal override solo se NO perturbazione
  attiva); **`make_inducer_log()`** (export, audit per perturbazioni
  mediated_effect).
- `analysis/_targets.R`: target `geo_summary_cache_dir`, `study_series_ids`,
  `study_summaries`, `curated_stage2_gse`, `stage2_cache_dir`,
  `study_designs_raw`, `study_designs_validator`, `study_designs_validated`,
  `study_designs_invalid`, `comparisons_table`. Stadio 2 driven da 15 fixture
  curate (non dal P2 dev set, che ha 1 sample/GSE).
- `vignettes/stage2-classify.Rmd`: vignette utente con esempio GSE145941
  end-to-end + fixture mini (offline buildable).
- `inst/extdata/stage2-fixtures-mini/`: 15 GSE benchmark stratificati per
  diversita design_kind + edge case (R8 Dox-inducible KD, factorial
  multi-axis, tumor+drug disease conflict, metadata povero, large N n=30/40,
  multi-donor batch). 197/197 sample stage1-validated.

## Run reale Task 13 (15 GSE x gpt-5.5 Stadio 2)

| Metrica | Risultato |
|---|---|
| Validity rate | 15/15 = 100% (0 schema violation) |
| design_kind diversity | 7/10 (treatment_vs_untreated, treatment_vs_vehicle, dose_response, time_course, multi_arm_treatment, factorial, knockdown_panel) |
| Confidence range | 0.72-0.93 (mediana ~0.87) |
| Comparisons cross-GSE | 55 in `comparisons_table` |
| Anchor v3 ben formati | 55/55 = 100% (tutti 13 segmenti) |
| Anchor unici | 44 (11 collisioni intra-studio == match attesi) |

## Hotfix correlati

- `R/validate.R`: `compile_schema()` e `validate_json()` re-esportati (P1
  oversight; CLAUDE.md li dichiarava esportati ma erano `@keywords internal`).
- `data-raw/build-stage2-fixtures.R`: unwrap `res$value` da
  `classify_sample()` envelope (Task 10 hotfix).
- `inst/schemas/study_design.stage2.v1.json`: dict -> array di key/value
  per `factor_levels`/`fixed_factors` (Task 11 hotfix per OpenAI strict).
- `R/anchors.R` `make_anchor()`: disease_vs_normal override fires solo
  quando NO perturbazione attiva (Task 14 fix; ridotto disease anchor
  da 36/55 a 2/55).

## Convenzioni

- Cache LLM partizionata per Stadio: namespace `stage2` (separato da `stage1`).
- Anchor v3 versionato: future iterazioni (v4+) richiedono solo ricalcolo
  deterministico (no re-LLM).
- `comparability_anchor` NON e' nello schema LLM: viene calcolato a valle
  da `make_anchor()` e aggiunto come colonna a `comparisons_table`.
- Stadio 2 P3 driven da 15 fixture curate, non dal P2 dev set.

# simulomicsr 0.0.0.9003

* P2 — Stadio 1 sample_facts:
  * Schema `inst/schemas/sample_facts.stage1.v3.json` strict-friendly per
    OpenAI Structured Outputs (spec v5 §3, vocabolari §3.1-§3.12).
  * `classify_sample()` orchestratore (export pubblico) sopra
    `llm_call_structured()` con cache, prompt v1, enrichment deterministico
    (anti-allucinazione su `geo_accession`/`series_id`, `raw_input_hash` da
    `sha256(sample_string)`).
  * `build_dev_set()` stratificato 60/30/10 (spec v5 §6.1, seed=1812).
  * Pipeline `analysis/_targets.R`: `samples_input_path` → `samples_input` →
    `samples_dev_set` → `sample_facts_raw` (dynamic branching su 100 sample) →
    `sample_facts_validated`/`sample_facts_invalid` → `eval_stage1_metrics` →
    `eval_stage1_report` (HTML via `tar_render`).
  * Eval iniziale su 100 sample del xlsx con `gpt-5.5`: `validity_rate = 1.000`,
    `recall_perturbation = 0.700`, `recall_cell_type = 0.800`. Costo run: ~$2.78.
  * Vignette `stage1-classify.Rmd`.
* P1 hotfix (necessari per supportare gpt-5.5):
  * `.openai_build_request()` rende `temperature` opzionale (default `NULL`):
    i modelli reasoning (gpt-5.5+) accettano solo il default API e ritornano
    400 su qualunque valore esplicito.
  * `.openai_parse_response()` usa `simplifyVector = FALSE` per preservare
    gli array JSON (un campo array di 1 elemento veniva collassato a scalare,
    facendo fallire la validazione schema).

# simulomicsr 0.0.0.9002 (in development)

## P1 — Infrastruttura LLM

- ADR-0004: riconciliazione renv per R 4.5 + dipendenze runtime LLM in DESCRIPTION
- `R/hash.R` — `sha256_text()`, `cache_key_for()`
- `R/cache.R` — cache locale append-only JSONL + indice SQLite (per-namespace)
- `R/validate.R` — JSON Schema validator (Ajv via `jsonvalidate`)
- `R/llm-client.R` — `llm_call_structured()` con dispatch provider, cache, schema validation
- `R/llm-client-openai.R` — adapter OpenAI Structured Outputs (`response_format = json_schema, strict = true`)
- `R/lookup.R` — `normalize_gene()` con dump HGNC (symbol/alias/prev resolution)
- Smoke test E2E gated su `OPENAI_API_KEY`
- Vignette `01-llm-client`

# simulomicsr 0.0.0.9000

* Setup dev environment
* Added a `NEWS.md` file to track changes to the package.
