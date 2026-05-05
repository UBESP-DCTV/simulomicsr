# simulomicsr 0.0.0.9007

## P3.5-C — Confidence-aware classification (multi-model + mini-gold design-aware)

### Funzionalita' nuove

* `R/llm-client-anthropic.R` — adapter Anthropic Messages API con structured
  output via tool_use forzato. Supporta `claude-haiku-4-5` e `claude-sonnet-4-6`.
  Funzioni private: `.anthropic_build_request()`, `.anthropic_parse_response()`,
  `.anthropic_chat_structured()`. Errori tipizzati:
  `simulomicsr_anthropic_missing_key`, `simulomicsr_anthropic_truncated`,
  `simulomicsr_anthropic_no_tool_use`, `simulomicsr_anthropic_bad_system_content`.
* Dispatch `provider="anthropic"` in `llm_call_structured()`.
* `multi_classify_study()` — wrapper su `classify_study()` che itera su una
  lista di `model_specs` e ritorna una lista nominata per modello.
* `compute_pairwise_agreement()` — agreement cross-modello su `design_kind`,
  `primary_role` (per sample), `control_type|design_kind|varying_factor`
  (per comparison).
* `aggregate_confidence_score()` — media pesata 0.3/0.5/0.2 sulle coppie.
* `assign_difficulty_tier()` — tier `easy` (>=0.60), `medium` (>=0.45), `hard`
  (calibrato empiricamente sul sub-set v5).
* `sample_minigold_stratified()` — sampling stratificato 50/50 easy/hard
  con almeno K GSE distinti per tier.
* `export_minigold_csv()` — pre-popolazione CSV per review umana, ordinata
  per `series_id` e con colonna `study_overview` (riassunto multi-line dei
  sample dello studio + ruoli proposti dai N modelli).
* `import_minigold_reviewed()` — import + validazione vocabolari design_role/kind.
* `eval_against_minigold()` — accuracy per modello x tier (overall/easy/hard).

### Pipeline targets

* `analysis/_targets.R` esteso con suffisso `_p35c`: `curated_p35c_gse`,
  `model_specs_p35c`, `study_summaries_p35c`, `multi_classify_outputs_p35c`,
  `confidence_scores_p35c`, `samples_table_p35c`, `minigold_pool_p35c`,
  `minigold_template_csv_p35c`, `minigold_reviewed_p35c`, `eval_p35c_metrics`,
  `eval_p35c_report`.

### Schema v5 — design-aware-relational (insight chiave del progetto)

Il salto a vocabolario v5 e' stato scelto sulla base degli insights della
review umana (16 commenti utente su 100 sample): un controllo non e' una
categoria autonoma, esiste solo IN RELAZIONE a un trattato.

* **Sample-level `primary_role`** (5 valori, era 13 in v3):
  `treated`, `control`, `bystander`, `excluded`, `unclear`. Solo informativo
  ("ruolo nel confronto MAIN dello studio"); il vero ruolo per DE e
  meta-analisi sta sui comparisons.
* **Comparison-level `control_type`** (7 valori, NUOVO in v5): property
  RELAZIONALE del confronto. `vehicle`, `untreated`, `genetic_negative`,
  `inducer_off`, `disease_normal`, `time_zero`, `secondary_arm`. Lo stesso
  sample puo' apparire come `control` con `control_type` diversi in
  comparisons differenti (factoriali, multi-design, time-course).
* **Comparison-level `design_kind`**: design specifico del comparison
  (per studi `multi_arm_treatment` con sub-experiments eterogenei).
* Nuovo schema `inst/schemas/study_design.stage2.v2.json`.
* Mini-gold v3 reviewato dall'utente riconvertito DETERMINISTICAMENTE a v5
  (mapping 1:1, ZERO re-review umana richiesta).

### Risultati P3.5-C v5 (50 GSE x 5 modelli, mini-gold n=100)

| Modello              | Easy | Hard | Overall | vs v3 |
|----------------------|------|------|---------|-------|
| **gpt-5.5**          | 96%  | **92%** | **94%** |  +3pp |
| **gpt-5.4-mini**     | 96%  |  90% |    93%  | **+30pp** |
| claude-sonnet-4-6    | 96%  |  86% |    91%  | +11pp |
| claude-haiku-4-5     | 100% |  60% |    80%  |  +1pp |
| gpt-5.4-nano         | 42%  |   6% |    24%  | -24pp |

* Distribuzione tier 50 GSE: 14 easy / 17 medium / 19 hard (soglie v5
  ricalibrate: easy>=0.60, medium 0.45-0.60, hard<0.45).
* `gpt-5.4-mini sblocca` un saving radicale: da 63% (v3, 13 valori) a
  93% (v5, 5 valori). Drop-in candidate per P4.
* Invalid rate: 3/250 (1.2%) - principalmente Anthropic Haiku per
  truncation max_tokens (hard limit 8192) o schema validation.
* Costo run cumulativo P3.5-C: ~$50-60 (run v3 + run v5 dopo cache miss).

### Decisione P4 + P5

* **gpt-5.4-mini come modello cheap-mid principale** (P4 stimato ~$5-7k
  vs $32k full-gpt-5.5, saving ~80%).
* **Architettura tier-aware ibrida**: Haiku ($0.008/sample, 100% accuracy
  sui easy) per tier `easy`, gpt-5.4-mini per medium/hard. Costo P4
  blended: ~$4-5k (saving ~85% vs full-gpt-5.5).
* Soglia P5 meta-analisi: `confidence_score >= 0.45` (esclude tier hard).
* Stratificazione meta-analisi per `control_type` come nuova dimensione
  per detection vehicle/untreated bias.

### Hotfix

* `R/llm-client-anthropic.R` default `max_tokens` da 4096 a 8192: il run
  iniziale v3 aveva 12/250 invalid (4.8%) per truncation, post-fix 2/250.
* `study_designs_validator` aggiornato a `stage2.v2.json` (era v1, rifiutava
  output v2).
* `curated_p35c_gse` con pin esplicito dei 16 GSE del mini-gold (per
  garantire riusabilita' del gold cross-version).
* Soglie tier ricalibrate empiricamente: 0.60/0.45 (era 0.85/0.60 in v3,
  troppo alte per v5 dove `.anchor_match_rate` ora misura agreement vero
  invece di ritornare sempre 1).

### Insight da review umana (16 commenti su 100 sample)

* Time-series ambiguity: vocabolario v3 non distingueva "trattato a t0"
  vs "controllo a tN" → risolto naturalmente in v5 (control_type=time_zero
  e' una property del comparison, non del sample).
* Multi-design experiments con sub-experiments eterogenei → risolto da
  comparison-level `design_kind` v2.
* Replicati biologici/tecnici: pattern coperto da `replicate_groups`
  esistente, miglior visualizzazione nel CSV (colonna `study_overview`).
* Multi-label ambiguity (stesso sample in piu' ruoli): risolto
  STRUTTURALMENTE in v5 (ruolo come property della relazione, non del
  sample → no scelte forzate).

### Tag: `p3.5c-confidence-complete`

---

# simulomicsr 0.0.0.9006

## P3.5-A — Scaled benchmark Stadio 2 (100 GSE paper-ready)

### Funzionalita' nuove

* `wilson_ci()`, `mcnemar_paired()`, `bootstrap_delta_ci()`, `holm_adjust()` —
  statistica inferenziale paper-grade in `R/eval-stats.R`.
* `load_rummageo_index()` — scarica indice completo GSE da RummaGEO via
  GraphQL paginated con cache filesystem.
* `keyword_design_kind_proxy()` — inferisce design_kind candidato da metadata
  strings via regex per stratificazione del pool di selezione.
* `intersect_with_xlsx_and_archs4()` — intersezione tre-vie GSE.
* `stratified_sample_gse()` — campionamento stratificato deterministico
  (seed 1812) con fallback su categoria abbondante per categorie povere.
* `reclassify_verbose()` — re-classify Stadio 2 con prompt verbose-reasoning
  per investigation casi specifici (introdotto per GSE145941).
* `compare_with_gold()` — tabella side-by-side gold xlsx vs run P3 vs reclassify.
* `classify_study()` e `build_prompt_stage2()` accettano ora il parametro
  opzionale `extra_instruction` (backward compatible).

### Artefatti committati

* `inst/extdata/p35a-gse-selected.csv` — lista 100 GSE finali per
  riproducibilita' del set di test (seed 1812).
* `analysis/eval/p35a-benchmark.html` — report Quarto 5 sezioni
  (binary accuracy + Wilson CI, granularity, anchor coverage,
  RummaGEO head-to-head con McNemar + bootstrap + Holm,
  investigation GSE145941).

### Risultati run live (1507 sample, 100 GSE)

| Metrica | Valore |
|---|---|
| Stadio 1 validity rate | 100% (1507/1507) |
| Stadio 2 validity rate | 100% (100/100) |
| Stage 2 binary accuracy globale | 83.7% (n=1489) |
| RummaGEO vs gold | 71.8% (n=1492) |
| Delta simulomicsr - RummaGEO | +12 pp (in favore di simulomicsr) |
| treatment_vs_vehicle accuracy | 94.6% |
| treatment_vs_untreated accuracy | 77.3% (sotto soglia 85%) |
| case_control_disease accuracy | 49.1% (anomalia, da investigare) |
| dose_response accuracy | 95.6% |
| factorial accuracy | 83.6% |
| multi_arm_treatment accuracy | 87.2% |
| time_course accuracy | 59.3% |
| Granularity flagged | 88 sample |
| RummaGEO official coverage | 209 sample / 1492 paired |

### Cost LLM

* **Totale P3.5-A: ~$68.70** (OpenAI gpt-5.5 cumulativo per Stadio 1 + Stadio 2
  + reclassify GSE145941). Misurato dall'utente sul billing OpenAI 2026-05-03,
  non stimato.
* Implica ~$0.043/call media su 1608 chiamate (1507 Stage 1 + 100 Stage 2 + 1
  reclassify verbose). Estrapolando a P4 run massivo ARCHS4 (~700k+ sample),
  atteso ~$30k a parita' di modello.
* Questa cifra rende **prioritario** il P3.5-A2 cost/quality validation
  (vedi CLAUDE.md "Next step"): se un modello cheaper a parita' di accuracy
  esiste, P4 costerebbe una frazione del proiettato.

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
