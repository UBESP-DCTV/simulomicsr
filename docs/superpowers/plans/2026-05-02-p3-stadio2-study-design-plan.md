# P3 — Stadio 2 study_design + comparability_anchor + GEO fetch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trasformare un GSE (`series_id` + i `sample_facts.stage1.v3` validati di P2 + `study_summary` da NCBI) in un record `study_design.stage2.v1` JSON con `replicate_groups`, `comparisons` e `comparability_anchor` v3 calcolato deterministicamente da una funzione R pura. P3 consegna: (1) lo schema strict Stadio 2; (2) `R/llm-stage2.R` con `build_prompt_stage2()`/`parse_stage2_response()`/`classify_study()`; (3) `R/geo-fetch.R` con `fetch_study_summary()` cacheable; (4) `R/anchors.R` con `make_anchor()` (13 segmenti) + `make_inducer_log()`; (5) target `study_summaries` → `study_designs_raw` → `study_designs_validated`/`invalid` → `comparisons_table` in `analysis/_targets.R`; (6) vignette + bump versione. P3 NON include eval contro gold design-aware né benchmark RummaGEO — quelli sono P3.5 (vedi ADR-0006).

**Architecture:** Quattro strati. (a) Schema JSON Schema draft-07 strict-friendly (additionalProperties:false ovunque, tutti `required`, optionals come union null) per OpenAI Structured Outputs su gpt-5.5. (b) Funzioni pure in `R/llm-stage2.R` che costruiscono il prompt (system con vocab §4.1-§4.2 + 1 esempio few-shot, user con `series_id`+`sample_facts_list`+`study_summary`), invocano `llm_call_structured()`, fanno enrichment deterministico post-parse (series_id forzato da input, `extraction.input_sample_count` calcolato qui, `extraction.model` settato qui). (c) `R/geo-fetch.R` thin wrapper su `rentrez::entrez_summary(db="gds")` con cache JSONL on disk per evitare hammering di NCBI EUtils. (d) `R/anchors.R` puro R (no LLM): selezione perturbazione di interesse, applicazione regole R8 (mediated_effect)/R9 (variant)/R24 (phase)/R25 (subcellular)/R31 (cell_state), produce anchor a 13 segmenti `kind|agent|variant|dose|duration|phase|cell_id|context|state|subcell|tissue|disease|engineered`. Pipeline `analysis/_targets.R` con dynamic branching `pattern = map(study_groups)` su unique GSE. Modello di default Stadio 2: **`gpt-5.5`** (spec §5.3.1). Test pattern: tutto on-disk con fixture pre-classificate stage1 + un solo smoke E2E reale gated su `OPENAI_API_KEY`.

**Tech Stack:** R 4.5+, P1+P2 stack (`httr2`, `jsonlite`, `jsonvalidate`, `DBI`+`RSQLite`, `digest`, `dplyr`, `tibble`, `targets`, `tarchetypes`, `readxl`, `tidyr`), in più `rentrez` (NCBI EUtils per study_summary). `rmarkdown`/`knitr` per vignette.

---

## File Structure

| File | Responsabilità | LOC stimato |
|---|---|---|
| `inst/schemas/study_design.stage2.v1.json` | JSON Schema strict per Stadio 2 (spec §4). additionalProperties:false ovunque; tutti i campi required; optionals come `["<type>","null"]`; enum `design_kind` (§4.1) e `design_role` (§4.2) | ~280 |
| `inst/extdata/stage2-fixtures-mini/` | 3 GSE fixture stratificati (1 time_course, 1 treatment_vs_vehicle, 1 knockdown_panel). Per ciascuno: `<GSE>-sample-facts.json` (lista validated stage1), `<GSE>-study-summary.json` (mock GEO meta), `<GSE>-study-design.json` (expected stage2 output) | ~200/GSE × 3 |
| `data-raw/build-stage2-fixtures.R` | Script idempotente: estrae 3 GSE dal P2 dev set, invoca `classify_sample()` su ognuno (cached), salva sample_facts validati in `inst/extdata/stage2-fixtures-mini/` | ~80 |
| `tests/testthat/fixtures/stage2-valid-vegf-huvec.json` | Esempio Stage 2 valido (spec §4 example) | ~80 |
| `tests/testthat/fixtures/stage2-invalid-bad-design-kind.json` | Esempio non-conforme (`design_kind` fuori vocab) | ~30 |
| `tests/testthat/fixtures/stage2-invalid-missing-required.json` | Esempio non-conforme (manca `replicate_groups`) | ~25 |
| `R/geo-fetch.R` | `fetch_study_summary(series_id, cache_dir = NULL)` (export). Wrapper su `rentrez::entrez_summary(db="gds")`. Cache file-system JSONL append-only chiavato `series_id`. Retry exponential backoff su 429/5xx. Ritorna lista `list(series_id, title, summary, overall_design)` | ~140 |
| `R/llm-stage2.R` | `build_prompt_stage2(series_id, sample_facts_list, study_summary, model = "gpt-5.5")` (internal), `parse_stage2_response(raw, series_id, sample_count, model)` (internal), `classify_study_row(group_tibble, sample_facts_list, study_summary, ..., provider, model, cache)` (internal target binding), **`classify_study(series_id, sample_facts_list, study_summary, ..., provider, model, cache)`** (export) | ~320 |
| `R/anchors.R` | Helpers privati `.normalize_dose()`, `.normalize_duration()`, `.normalize_cell_id()`, `.select_primary_perturbation()`. Pubblici: `make_anchor(stage1_facts, stage2_role)`, `make_inducer_log(stage1_facts)`. 13 segmenti in ordine fisso. Default applicati per R24/R25/R31 | ~280 |
| `analysis/_targets.R` | Aggiunta target: `study_groups` (group_by series_id su `sample_facts_validated`), `study_summary_cache_dir`, `study_summaries` (dynamic, fetch per GSE), `study_designs_raw` (dynamic, classify per GSE), `study_designs_validator` (file path schema), `study_designs_validated`/`invalid` (partition), `comparisons_table` (flatten + anchor per row) | ~80 (estende 134→210) |
| `tests/testthat/test-stage2-schema.R` | Schema accetta esempio v1 spec; rifiuta bad_design_kind / missing_required / additionalProperties violation | ~120 |
| `tests/testthat/test-geo-fetch.R` | `fetch_study_summary()`: shape ritornata, cache hit/miss su disco, mock `rentrez::entrez_summary` con `withr::local_mocked_bindings` | ~140 |
| `tests/testthat/test-anchors.R` | `make_anchor()` su 5 fixture sample_facts (uno per esempio dalla spec §4.3); `.normalize_dose()`, `.normalize_duration()`, `.normalize_cell_id()` su input edge case; `make_inducer_log()` su sample con `mediated_effect != null` | ~280 |
| `tests/testthat/test-llm-stage2.R` | `build_prompt_stage2()`: ritorna list di messages OpenAI-shape; `parse_stage2_response()`: enrichment deterministico (series_id overwrite, sample_count); `classify_study()`: orchestratore con mock adapter, cache hit, error pass-through | ~240 |
| `tests/testthat/test-smoke-e2e-stage2.R` | Smoke E2E reale gated `OPENAI_API_KEY`, classifica 1 GSE fixture (VEGF time_course) e verifica shape | ~80 |
| `vignettes/stage2-classify.Rmd` | Vignette: come classificare un GSE con `classify_study()`, dalla fetch di `study_summary` al `make_anchor()` finale, con fixture mini | ~140 |

File tagliati e tenuti separati per responsabilità: schema (dato), llm-stage2 (logica LLM), geo-fetch (I/O esterno), anchors (logica deterministica), targets (orchestrazione). Ogni file ha test dedicato. `make_anchor()` è puro R e testabile in isolamento.

Sono **NON** in scope di P3:
- Eval contro gold "design-aware" — P3.5
- Benchmark vs RummaGEO — P3.5 (vedi ADR-0006 §"Deliverable integrale")
- Vocabolari extra (Cellosaurus full, DrugBank, ChEMBL, MeSH normalization completo) — plan separato post-P3
- Stadio 3-5 (clustering cross-studio, DE, meta-analisi) — P4+
- Migrazione a `ellmer` — ADR separato post-P3
- Re-processing Stadio 2 con modello arbitro su `confidence < 0.5` — P3.5 dopo eval baseline

---

## Task 1: Branch + DESCRIPTION + rentrez + targets_packages

**Files:**
- Modifica: `DESCRIPTION`
- Modifica: `analysis/_targets_packages.R`
- Modifica: `renv.lock` (via `renv::snapshot()`)

- [ ] **Step 1.1: Verifica master pulito e tag P2 presente**

Run:
```bash
git status
git tag --list 'p2-*'
git rev-parse HEAD
```

Expected: `working tree clean`, `p2-stage1-complete` presente, HEAD su master (commit ADR-0006 `6c95a23` o successivo).

- [ ] **Step 1.2: Crea branch `p3-stage2`**

Run:
```bash
git checkout -b p3-stage2
```

Expected: `Switched to a new branch 'p3-stage2'`.

- [ ] **Step 1.3: Aggiorna `DESCRIPTION` con `rentrez` in Imports**

Apri `DESCRIPTION` e nella sezione `Imports:` aggiungi `rentrez,` in ordine alfabetico (subito dopo `purrr,`). `rentrez` è runtime perché `fetch_study_summary()` è export pubblico, non solo applicativo.

- [ ] **Step 1.4: Aggiorna `analysis/_targets_packages.R`**

Aggiungi `library(rentrez)` dopo `library(readxl)`. Risultato finale del file:

```r
# Pacchetti caricati nei worker `targets`.
#
# Allineato con `Imports`/`Suggests` di ../DESCRIPTION (vedi
# docs/decisions/0002-struttura-research-compendium.md).

library(tibble)
library(dplyr)
library(tidyr)
library(readxl)
library(rentrez)
library(rmarkdown)
library(tarchetypes)
library(simulomicsr)
```

- [ ] **Step 1.5: Installa rentrez in renv**

Run da R (root del repo):
```r
renv::install("rentrez")
```

Expected: nessun errore, `rentrez` installato.

- [ ] **Step 1.6: Snapshot renv**

Run da R:
```r
renv::snapshot(type = "implicit", prompt = FALSE)
```

Expected: `renv.lock` aggiornato. Verifica:
```bash
grep -E '"rentrez"' renv.lock | head
```

Expected: `"rentrez": { ... }` presente.

- [ ] **Step 1.7: Commit**

```bash
git add DESCRIPTION analysis/_targets_packages.R renv.lock
git commit -m "P3 Task 1: rentrez aggiunto a Imports + targets_packages popolato"
```

---

## Task 2: Schema `study_design.stage2.v1.json` strict + fixture + test

**Files:**
- Crea: `inst/schemas/study_design.stage2.v1.json`
- Crea: `tests/testthat/fixtures/stage2-valid-vegf-huvec.json`
- Crea: `tests/testthat/fixtures/stage2-invalid-bad-design-kind.json`
- Crea: `tests/testthat/fixtures/stage2-invalid-missing-required.json`
- Crea: `tests/testthat/test-stage2-schema.R`

> **Vincoli OpenAI Structured Outputs strict** (stessi di P2 Task 2, ripetuti per chiarezza):
> 1. `additionalProperties: false` su **ogni** oggetto.
> 2. **Tutti** i campi devono essere in `required`. Optionals come `"type": ["<base>", "null"]`.
> 3. Niente `$ref`, niente `oneOf`/`anyOf` con discriminator.
> 4. Profondità annidamento ≤ 5 — schema Stadio 2 è profondo 4.
> 5. Enum totali ≤ 100 — schema Stadio 2 ha ~25 (design_kind 10 + design_role 13 + factor.type ~6).

- [ ] **Step 2.1: Crea fixture VALID `tests/testthat/fixtures/stage2-valid-vegf-huvec.json`**

Esempio v1 dalla spec §4 con tutti i campi optional esplicitamente messi:

```json
{
  "series_id": "GSE41166",
  "design_summary": "Time-course of VEGF stimulation in primary HUVEC: t=0h baseline followed by 1h, 6h, 24h post-VEGF (50 ng/ml). 3 biological replicates per timepoint.",
  "design_kind": "time_course",
  "factors": [
    {"name": "VEGF stimulation", "type": "stimulation", "levels": ["unstimulated", "VEGF"]},
    {"name": "time", "type": "time", "levels": ["0h", "1h", "6h", "24h"]}
  ],
  "replicate_groups": [
    {
      "group_id": "baseline_t0",
      "label_human": "HUVEC, t=0h baseline",
      "sample_ids": ["GSM1009635"],
      "design_role": "baseline_t0",
      "factor_levels": {"VEGF stimulation": "VEGF", "time": "0h"}
    },
    {
      "group_id": "VEGF_1h",
      "label_human": "HUVEC + VEGF, 1h",
      "sample_ids": ["GSM1009636", "GSM1009637", "GSM1009638"],
      "design_role": "perturbed",
      "factor_levels": {"VEGF stimulation": "VEGF", "time": "1h"}
    }
  ],
  "comparisons": [
    {
      "comparison_id": "GSE41166__VEGF_1h_vs_baseline",
      "treated_group": "VEGF_1h",
      "control_group": "baseline_t0",
      "varying_factor": "time",
      "fixed_factors": {"VEGF stimulation": "VEGF", "cell": "HUVEC"},
      "study_internal_score": 0.84
    }
  ],
  "extraction": {
    "schema_version": "stage2.v1",
    "model": "openai:gpt-5.5",
    "confidence": 0.81,
    "ambiguity_flags": ["nonstandard_baseline_choice"],
    "input_sample_count": 4,
    "input_truncated": false
  }
}
```

Note: `comparability_anchor` e `anchor_version` NON sono nello schema dell'LLM — vengono calcolati post-LLM da `make_anchor()` in R (Task 5). L'LLM produce `comparisons` senza il campo anchor; il target `comparisons_table` lo aggiunge come colonna a valle.

- [ ] **Step 2.2: Crea fixture INVALID `tests/testthat/fixtures/stage2-invalid-bad-design-kind.json`**

Stesso payload del valid ma con `"design_kind": "drug_screen"` (non in vocab §4.1). Resto identico.

- [ ] **Step 2.3: Crea fixture INVALID `tests/testthat/fixtures/stage2-invalid-missing-required.json`**

Stesso payload del valid ma con `replicate_groups` rimosso completamente.

- [ ] **Step 2.4: Crea schema `inst/schemas/study_design.stage2.v1.json`**

JSON Schema draft-07 strict per OpenAI Structured Outputs. La struttura completa:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://simulomicsr/schemas/study_design.stage2.v1.json",
  "type": "object",
  "additionalProperties": false,
  "required": ["series_id", "design_summary", "design_kind", "factors", "replicate_groups", "comparisons", "extraction"],
  "properties": {
    "series_id": {"type": "string", "pattern": "^GSE[0-9]+$"},
    "design_summary": {"type": "string", "minLength": 10},
    "design_kind": {
      "type": "string",
      "enum": [
        "case_control_disease",
        "treatment_vs_vehicle",
        "treatment_vs_untreated",
        "time_course",
        "dose_response",
        "knockdown_panel",
        "factorial",
        "differentiation_course",
        "multi_arm_treatment",
        "unclear"
      ]
    },
    "factors": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["name", "type", "levels"],
        "properties": {
          "name": {"type": "string"},
          "type": {
            "type": "string",
            "enum": ["stimulation", "small_molecule", "genetic", "time", "dose", "cell_line", "donor", "condition", "other"]
          },
          "levels": {"type": "array", "items": {"type": "string"}, "minItems": 1}
        }
      }
    },
    "replicate_groups": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["group_id", "label_human", "sample_ids", "design_role", "factor_levels"],
        "properties": {
          "group_id": {"type": "string"},
          "label_human": {"type": "string"},
          "sample_ids": {"type": "array", "items": {"type": "string"}, "minItems": 1},
          "design_role": {
            "type": "string",
            "enum": [
              "perturbed",
              "vehicle_control",
              "untreated_control",
              "negative_genetic_control",
              "negative_inducer_control",
              "positive_control",
              "baseline_t0",
              "case",
              "comparison",
              "bystander",
              "secondary_arm",
              "excluded",
              "unclear"
            ]
          },
          "factor_levels": {
            "type": "object",
            "additionalProperties": {"type": "string"}
          }
        }
      }
    },
    "comparisons": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["comparison_id", "treated_group", "control_group", "varying_factor", "fixed_factors", "study_internal_score"],
        "properties": {
          "comparison_id": {"type": "string"},
          "treated_group": {"type": "string"},
          "control_group": {"type": "string"},
          "varying_factor": {"type": "string"},
          "fixed_factors": {
            "type": "object",
            "additionalProperties": {"type": "string"}
          },
          "study_internal_score": {"type": "number", "minimum": 0, "maximum": 1}
        }
      }
    },
    "extraction": {
      "type": "object",
      "additionalProperties": false,
      "required": ["schema_version", "model", "confidence", "ambiguity_flags", "input_sample_count", "input_truncated"],
      "properties": {
        "schema_version": {"type": "string", "const": "stage2.v1"},
        "model": {"type": "string"},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "ambiguity_flags": {"type": "array", "items": {"type": "string"}},
        "input_sample_count": {"type": "integer", "minimum": 1},
        "input_truncated": {"type": "boolean"}
      }
    }
  }
}
```

Nota strict-mode: `factor_levels` (un dictionary stringa→stringa) usa `additionalProperties: {"type": "string"}` invece di `false`. È accettato da OpenAI Structured Outputs perché il valore è un tipo primitivo, non un oggetto annidato.

- [ ] **Step 2.5: Crea test `tests/testthat/test-stage2-schema.R`**

```r
test_that("schema stage2.v1 accetta esempio valido VEGF HUVEC", {
  skip_if_not_installed("jsonvalidate")
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  expect_true(nzchar(schema_path))
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-valid-vegf-huvec.json")
  )
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_true(result$valid, info = paste(result$errors, collapse = "\n"))
})

test_that("schema stage2.v1 rifiuta design_kind fuori vocab", {
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-invalid-bad-design-kind.json")
  )
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_false(result$valid)
  expect_match(paste(result$errors, collapse = " "), "design_kind|enum",
               ignore.case = TRUE)
})

test_that("schema stage2.v1 rifiuta missing required (replicate_groups)", {
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-invalid-missing-required.json")
  )
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_false(result$valid)
  expect_match(paste(result$errors, collapse = " "), "replicate_groups|required",
               ignore.case = TRUE)
})

test_that("schema stage2.v1 rifiuta additionalProperties (campo extra in factors[])", {
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-valid-vegf-huvec.json")
  )
  fixture$factors[[1]]$extra_field <- "not allowed"
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_false(result$valid)
})
```

- [ ] **Step 2.6: Run test, vedi fallire (schema non ancora installato)**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "stage2-schema")'
```

Expected: tutti i 4 test FAIL — `system.file()` ritorna stringa vuota perché il pacchetto non è ancora rebuildato.

- [ ] **Step 2.7: Reinstalla il pacchetto e ri-run il test**

Run:
```bash
Rscript --vanilla -e 'devtools::install(upgrade = "never", quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "stage2-schema")'
```

Expected: 4 PASS (schema accetta valid, rifiuta i 3 invalid).

- [ ] **Step 2.8: Commit**

```bash
git add inst/schemas/study_design.stage2.v1.json \
        tests/testthat/fixtures/stage2-valid-vegf-huvec.json \
        tests/testthat/fixtures/stage2-invalid-bad-design-kind.json \
        tests/testthat/fixtures/stage2-invalid-missing-required.json \
        tests/testthat/test-stage2-schema.R
git commit -m "P3 Task 2: schema study_design.stage2.v1.json strict + fixture + 4 test"
```

---

## Task 3: `R/geo-fetch.R` — `fetch_study_summary()` con cache

**Files:**
- Crea: `R/geo-fetch.R`
- Crea: `tests/testthat/test-geo-fetch.R`

`fetch_study_summary(series_id, cache_dir = NULL)`: ritorna `list(series_id, title, summary, overall_design)` per un GSE. Se `cache_dir` è non-NULL, scrive/legge JSONL `<cache_dir>/<series_id>.json` per evitare hammering NCBI EUtils. Retry exponential backoff su 429/5xx. Il vero call a NCBI è un solo `rentrez::entrez_summary(db = "gds", id = ..., rettype = "summary")` che ritorna un record con campi `title`, `summary`, `gpl`, `bioproject_id`, `gse`, `n_samples`. Il campo `overall_design` non è esposto direttamente da `entrez_summary` per `gds` — lo prendiamo da una seconda call a `rentrez::entrez_fetch(db = "gds", rettype = "xml")` parsato per `<Overall-Design>`. Per ora, semplifichiamo: passiamo `overall_design = NA_character_` se non disponibile, e lo Stadio 2 prompt funziona anche senza (la maggior parte dell'info è in `summary`).

- [ ] **Step 3.1: Scrivi i test (failing) `tests/testthat/test-geo-fetch.R`**

```r
test_that("fetch_study_summary ritorna shape attesa", {
  skip_if_not_installed("rentrez")
  # Mock rentrez per evitare network in unit test
  mock_summary <- list(
    uids = "200041166",
    `200041166` = list(
      title = "VEGF stimulation time course in HUVEC",
      summary = "Primary HUVEC stimulated with VEGF; t=0,1,6,24h; n=3 per group.",
      gpl = "GPL11154",
      bioproject_id = "PRJNA168145",
      gse = "41166",
      n_samples = "12"
    )
  )
  withr::local_envvar(SIMULOMICSR_GEO_FETCH_TEST_OFFLINE = "1")
  withr::local_mocked_bindings(
    entrez_search = function(db, term, ...) list(ids = "200041166"),
    entrez_summary = function(db, id, ...) mock_summary,
    .package = "rentrez"
  )
  out <- fetch_study_summary("GSE41166")
  expect_named(out, c("series_id", "title", "summary", "overall_design"))
  expect_equal(out$series_id, "GSE41166")
  expect_match(out$title, "VEGF")
  expect_match(out$summary, "HUVEC")
  expect_true(is.na(out$overall_design) || is.character(out$overall_design))
})

test_that("fetch_study_summary cache hit non chiama rentrez", {
  skip_if_not_installed("rentrez")
  cache_dir <- withr::local_tempdir()
  cached <- list(
    series_id = "GSE41166",
    title = "Cached title",
    summary = "Cached summary",
    overall_design = NA_character_
  )
  jsonlite::write_json(
    cached,
    fs::path(cache_dir, "GSE41166.json"),
    auto_unbox = TRUE,
    null = "null"
  )
  # Mock fail-loud: se il codice tenta entrez_search/entrez_summary, fallisce
  withr::local_mocked_bindings(
    entrez_search = function(...) stop("should not be called"),
    entrez_summary = function(...) stop("should not be called"),
    .package = "rentrez"
  )
  out <- fetch_study_summary("GSE41166", cache_dir = cache_dir)
  expect_equal(out$title, "Cached title")
})

test_that("fetch_study_summary cache miss scrive su disco", {
  skip_if_not_installed("rentrez")
  cache_dir <- withr::local_tempdir()
  mock_summary <- list(
    uids = "200041166",
    `200041166` = list(
      title = "Fresh fetch",
      summary = "From rentrez",
      gpl = "GPL11154",
      bioproject_id = "PRJNA168145",
      gse = "41166",
      n_samples = "12"
    )
  )
  withr::local_mocked_bindings(
    entrez_search = function(db, term, ...) list(ids = "200041166"),
    entrez_summary = function(db, id, ...) mock_summary,
    .package = "rentrez"
  )
  out <- fetch_study_summary("GSE41166", cache_dir = cache_dir)
  cached_path <- fs::path(cache_dir, "GSE41166.json")
  expect_true(fs::file_exists(cached_path))
  reread <- jsonlite::read_json(cached_path)
  expect_equal(reread$title, "Fresh fetch")
})

test_that("fetch_study_summary errors on input invalido", {
  expect_error(
    fetch_study_summary("not-a-gse"),
    class = "simulomicsr_invalid_series_id"
  )
})
```

- [ ] **Step 3.2: Run test, vedi fallire (funzione non esiste)**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "geo-fetch")'
```

Expected: 4 FAIL — `could not find function "fetch_study_summary"`.

- [ ] **Step 3.3: Implementa `R/geo-fetch.R`**

```r
#' Fetch GEO study summary for a GSE
#'
#' Wrapper su rentrez::entrez_summary(db="gds", ...) con cache filesystem
#' opzionale. Ritorna i campi title, summary, overall_design utilizzati
#' come input dello Stadio 2 (vedi spec sec.4 e sec.5.2).
#'
#' Cache su disco (JSONL per GSE) e' raccomandata in produzione per
#' evitare hammering di NCBI EUtils (rate limit 3 req/sec senza API key).
#'
#' @param series_id GSE accession (es. "GSE41166"). Validato contro pattern.
#' @param cache_dir Directory di cache (NULL = disattivata). Se esiste un
#'   file <cache_dir>/<series_id>.json, viene letto senza chiamata di rete.
#'
#' @return list con campi `series_id`, `title`, `summary`, `overall_design`.
#'   `overall_design` puo' essere NA se non parsabile dall'XML EUtils.
#' @export
fetch_study_summary <- function(series_id, cache_dir = NULL) {
  if (!grepl("^GSE[0-9]+$", series_id)) {
    rlang::abort(
      sprintf("series_id non valido: '%s' (atteso pattern '^GSE[0-9]+$')", series_id),
      class = "simulomicsr_invalid_series_id"
    )
  }

  if (!is.null(cache_dir)) {
    cache_path <- fs::path(cache_dir, paste0(series_id, ".json"))
    if (fs::file_exists(cache_path)) {
      cached <- jsonlite::read_json(cache_path, simplifyVector = FALSE)
      return(.geo_normalize_cached(cached))
    }
  }

  # Cerca l'UID GDS per questo GSE
  search_term <- sprintf("%s[ACCN] AND gse[ETYP]", series_id)
  search_res <- .geo_call_with_retry(
    rentrez::entrez_search,
    db = "gds", term = search_term, retmax = 1
  )
  if (length(search_res$ids) == 0L) {
    rlang::abort(
      sprintf("Nessun record GDS trovato per %s", series_id),
      class = "simulomicsr_geo_not_found"
    )
  }
  uid <- search_res$ids[[1L]]

  # Fetch summary
  summary_res <- .geo_call_with_retry(
    rentrez::entrez_summary,
    db = "gds", id = uid
  )
  rec <- summary_res[[as.character(uid)]]
  if (is.null(rec)) {
    rec <- summary_res
  }

  out <- list(
    series_id = series_id,
    title = rec$title %||% NA_character_,
    summary = rec$summary %||% NA_character_,
    overall_design = NA_character_  # entrez_summary GDS non lo espone in summary form
  )

  if (!is.null(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
    jsonlite::write_json(
      out,
      cache_path,
      auto_unbox = TRUE,
      null = "null"
    )
  }

  out
}

#' @noRd
.geo_normalize_cached <- function(cached) {
  list(
    series_id = cached$series_id,
    title = cached$title %||% NA_character_,
    summary = cached$summary %||% NA_character_,
    overall_design = cached$overall_design %||% NA_character_
  )
}

#' @noRd
.geo_call_with_retry <- function(fn, ..., max_attempts = 3L,
                                 base_delay_sec = 1.0) {
  for (attempt in seq_len(max_attempts)) {
    res <- tryCatch(fn(...), error = function(e) e)
    if (!inherits(res, "error")) return(res)
    msg <- conditionMessage(res)
    is_transient <- grepl("429|500|502|503|504|timeout|temporarily",
                          msg, ignore.case = TRUE)
    if (attempt == max_attempts || !is_transient) {
      rlang::abort(
        sprintf("rentrez call failed after %d attempts: %s", attempt, msg),
        class = "simulomicsr_geo_fetch_error"
      )
    }
    Sys.sleep(base_delay_sec * (2L ^ (attempt - 1L)))
  }
}

`%||%` <- function(x, y) if (is.null(x) || (length(x) == 1L && is.na(x))) y else x
```

- [ ] **Step 3.4: Reinstalla pacchetto e ri-run test**

Run:
```bash
Rscript --vanilla -e 'devtools::install(upgrade = "never", quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "geo-fetch")'
```

Expected: 4 PASS.

- [ ] **Step 3.5: Genera Rd via roxygen**

Run:
```bash
Rscript --vanilla -e 'devtools::document()'
```

Expected: nuovo `man/fetch_study_summary.Rd`. Verifica:
```bash
ls man/fetch_study_summary.Rd
```

- [ ] **Step 3.6: Commit**

```bash
git add R/geo-fetch.R tests/testthat/test-geo-fetch.R man/fetch_study_summary.Rd NAMESPACE
git commit -m "P3 Task 3: fetch_study_summary() con cache filesystem + 4 test"
```

---

## Task 4: `R/anchors.R` — helpers `.normalize_dose()`, `.normalize_duration()`, `.normalize_cell_id()`

**Files:**
- Crea: `R/anchors.R`
- Crea: `tests/testthat/test-anchors.R`

Tre helper privati che normalizzano i campi grezzi degli `stage1_facts` in segmenti canonici dell'anchor. Idempotenti, deterministici, no-LLM.

- [ ] **Step 4.1: Scrivi i test (failing) — sezione "helpers normalizzazione" in `tests/testthat/test-anchors.R`**

```r
# .normalize_dose ----------------------------------------------------------

test_that(".normalize_dose canonicalizza unita' SI", {
  expect_equal(simulomicsr:::.normalize_dose("10 nM"), "10nM")
  expect_equal(simulomicsr:::.normalize_dose("100 ng/ml"), "100ng/ml")
  expect_equal(simulomicsr:::.normalize_dose("1 uM"), "1uM")
  expect_equal(simulomicsr:::.normalize_dose("1 µM"), "1uM")  # micro symbol
  expect_equal(simulomicsr:::.normalize_dose("0.5 mM"), "0.5mM")
})

test_that(".normalize_dose mappa NULL/NA a 'nodose'", {
  expect_equal(simulomicsr:::.normalize_dose(NULL), "nodose")
  expect_equal(simulomicsr:::.normalize_dose(NA_character_), "nodose")
  expect_equal(simulomicsr:::.normalize_dose(""), "nodose")
})

test_that(".normalize_dose preserva 'standard' come placeholder", {
  expect_equal(simulomicsr:::.normalize_dose("standard"), "standard")
})

# .normalize_duration ------------------------------------------------------

test_that(".normalize_duration canonicalizza ore", {
  expect_equal(simulomicsr:::.normalize_duration("1 h"), "1h")
  expect_equal(simulomicsr:::.normalize_duration("24h"), "24h")
  expect_equal(simulomicsr:::.normalize_duration("3 hours"), "3h")
  expect_equal(simulomicsr:::.normalize_duration("90 min"), "1.5h")
  expect_equal(simulomicsr:::.normalize_duration("2 days"), "48h")
  expect_equal(simulomicsr:::.normalize_duration("6d"), "6d")  # giorni preservati per coltura lunga
})

test_that(".normalize_duration mappa NULL/NA a 'na'", {
  expect_equal(simulomicsr:::.normalize_duration(NULL), "na")
  expect_equal(simulomicsr:::.normalize_duration(NA_character_), "na")
  expect_equal(simulomicsr:::.normalize_duration(""), "na")
})

# .normalize_cell_id -------------------------------------------------------

test_that(".normalize_cell_id passa through Cellosaurus IDs", {
  expect_equal(simulomicsr:::.normalize_cell_id("CVCL_0030", "MCF-7"), "CVCL_0030")
})

test_that(".normalize_cell_id usa label_raw se Cellosaurus assente", {
  expect_equal(simulomicsr:::.normalize_cell_id(NULL, "HUVEC"), "HUVEC")
  expect_equal(simulomicsr:::.normalize_cell_id(NA_character_, "HEK293T"), "HEK293T")
})

test_that(".normalize_cell_id ritorna 'unclear' se entrambi vuoti", {
  expect_equal(simulomicsr:::.normalize_cell_id(NULL, NULL), "unclear")
  expect_equal(simulomicsr:::.normalize_cell_id("", ""), "unclear")
})
```

- [ ] **Step 4.2: Run test, vedi fallire**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "anchors")'
```

Expected: tutti FAIL — funzioni non definite.

- [ ] **Step 4.3: Implementa helpers in `R/anchors.R` (parziale, solo helpers)**

```r
#' Normalizza un valore di dose nella forma canonica dell'anchor
#'
#' Rimuove spazi, normalizza simboli micro, mappa null/NA/"" -> "nodose".
#' Preserva il valore "standard" come placeholder per dosaggi non specificati
#' ma noti dal protocollo.
#'
#' @param dose stringa o NULL/NA
#' @return stringa canonica (es. "10nM", "100ng/ml", "nodose", "standard")
#' @keywords internal
.normalize_dose <- function(dose) {
  if (is.null(dose) || length(dose) == 0L) return("nodose")
  if (is.na(dose) || !nzchar(dose)) return("nodose")
  d <- gsub("\\s+", "", dose)
  d <- gsub("µ", "u", d)  # micro symbol -> u
  d
}

#' Normalizza una durata nella forma canonica dell'anchor (ore/giorni)
#'
#' Converte minuti -> ore (1.5h per 90 min), days -> ore (48h per 2 days)
#' tranne per durate >= 6 giorni dove preserva "Nd" (es. 6d, 14d).
#' Mappa null/NA/"" -> "na".
#'
#' @param duration stringa o NULL/NA
#' @return stringa canonica
#' @keywords internal
.normalize_duration <- function(duration) {
  if (is.null(duration) || length(duration) == 0L) return("na")
  if (is.na(duration) || !nzchar(duration)) return("na")
  s <- tolower(gsub("\\s+", "", duration))

  # Pattern: <num><unit>
  m <- regmatches(s, regexec("^([0-9.]+)([a-z]+)$", s))[[1L]]
  if (length(m) != 3L) return(s)
  num <- as.numeric(m[2L])
  unit <- m[3L]

  if (unit %in% c("min", "minute", "minutes", "m")) {
    return(paste0(format(num / 60, drop0trailing = TRUE), "h"))
  }
  if (unit %in% c("h", "hr", "hour", "hours")) {
    return(paste0(format(num, drop0trailing = TRUE), "h"))
  }
  if (unit %in% c("d", "day", "days")) {
    if (num >= 6) {
      return(paste0(format(num, drop0trailing = TRUE), "d"))
    }
    return(paste0(format(num * 24, drop0trailing = TRUE), "h"))
  }
  s  # fallback
}

#' Normalizza un cell identifier per l'anchor
#'
#' Preferenza: Cellosaurus ID. Fallback: label_raw. Default: "unclear".
#'
#' @param cellosaurus_id stringa o NULL/NA
#' @param label_raw stringa o NULL/NA
#' @return stringa canonica
#' @keywords internal
.normalize_cell_id <- function(cellosaurus_id, label_raw) {
  if (.nzchar_safe(cellosaurus_id)) return(cellosaurus_id)
  if (.nzchar_safe(label_raw)) return(label_raw)
  "unclear"
}

#' @noRd
.nzchar_safe <- function(x) {
  !is.null(x) && length(x) > 0L && !is.na(x) && nzchar(x)
}
```

- [ ] **Step 4.4: Reinstalla e ri-run test**

Run:
```bash
Rscript --vanilla -e 'devtools::install(upgrade = "never", quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "anchors")'
```

Expected: tutti PASS (~13 test sui 3 helper).

- [ ] **Step 4.5: Commit**

```bash
git add R/anchors.R tests/testthat/test-anchors.R
git commit -m "P3 Task 4: helpers .normalize_dose/duration/cell_id + 13 test"
```

---

## Task 5: `R/anchors.R` — `make_anchor()` (13 segmenti, regole R8/R9/R24/R25/R31)

**Files:**
- Modifica: `R/anchors.R`
- Modifica: `tests/testthat/test-anchors.R`
- Crea: `tests/testthat/fixtures/sample-facts-vegf-huvec.json`
- Crea: `tests/testthat/fixtures/sample-facts-knockdown-ocily1.json`
- Crea: `tests/testthat/fixtures/sample-facts-dox-tetO-sox17.json` (R8 mediated_effect)
- Crea: `tests/testthat/fixtures/sample-facts-apobec1-mut.json` (R9 variant)
- Crea: `tests/testthat/fixtures/sample-facts-pd-ipsc-neurons.json` (disease_vs_normal)

L'anchor a 13 segmenti, separati da `|`:

```
{kind_effective}|{agent_id_or_name}|{variant_label_or_wt}|{dose_canonical}|{duration_or_na}|{phase_or_default}|{cell_id}|{context_kind}|{cell_state_or_default}|{subcellular_or_default}|{tissue_canonical}|{disease_status_or_none}|{has_engineered_baseline:bool}
```

Regole (spec §4.3):
- **R8 mediated_effect:** se `perturbation$mediated_effect != null`, allora `kind_effective = mediated_effect.kind`, `agent = mediated_effect.target`. Inducente perso (sarà in `make_inducer_log` Task 6).
- **R9 variant:** se `perturbation$variant != null`, segmento 3 = `variant`; altrimenti `wt`.
- **R24 phase:** default `exposure`; altri valori entrano se dichiarati nel sample.
- **R25 subcellular:** default `whole_cell` se `subcellular_fraction == null`.
- **R31 cell_state:** default `proliferating` se non dichiarato.
- **disease_vs_normal:** segmento 12 (disease_status) prende `case` o `comparison` da `stage2_role`.
- **has_engineered_baseline:** true se `engineered_modifications` non vuoto.

- [ ] **Step 5.1: Crea le 5 fixture JSON in `tests/testthat/fixtures/`**

Per ogni fixture, costruisci un sample_fact stage1.v3 valido che produca l'anchor target dalla spec §4.3.

`sample-facts-vegf-huvec.json` (target anchor: `cytokine_stim|HGNC:12680|wt|nodose|1h|exposure|HUVEC|primary_culture|proliferating|whole_cell|vascular_endothelium|none|false`):

```json
{
  "geo_accession": "GSM1009636",
  "series_id": "GSE41166",
  "organism": "Homo sapiens",
  "host_organism": null,
  "cell_context": {
    "cell_type_or_line_raw": "HUVEC",
    "cell_line_cellosaurus_candidate": null,
    "tissue": "vascular_endothelium",
    "tissue_segment": null,
    "passage_or_state": null,
    "context_kind": "primary_culture",
    "developmental_stage": null,
    "cell_state": null,
    "subcellular_fraction": null,
    "engineered_modifications": [],
    "co_culture_partners": [],
    "sort_markers": [],
    "cell_composition_estimates": []
  },
  "disease_state": {
    "term_raw": null, "mesh_id_candidate": null, "status": "none"
  },
  "perturbations": [
    {
      "kind": "cytokine_stimulation",
      "agent_raw": "VEGF",
      "agent_normalized": {
        "preferred_name": "VEGFA",
        "type": "gene",
        "id_database": "HGNC",
        "id_candidate": "HGNC:12680"
      },
      "variant": null,
      "dose": null,
      "dose_unit": null,
      "duration": "1h",
      "phase": null,
      "vehicle": null,
      "mediated_effect": null
    }
  ],
  "technical_treatments": [],
  "patient_metadata": null,
  "ambiguity_flags": [],
  "extraction": {
    "schema_version": "stage1.v3",
    "model": "openai:gpt-5.5",
    "confidence": 0.9,
    "raw_input_hash": "deadbeef"
  }
}
```

(Le altre 4 fixture seguono lo stesso pattern. Per `sample-facts-knockdown-ocily1.json` usa `kind=genetic_knockdown`, agent KMT2A `HGNC:7132`... wait, KMT2A è HGNC:7132? Verifica con lookup. In ogni caso il test confronta il segmento risultante dell'anchor, non l'ID specifico. Se l'esempio della spec usa `HGNC:1001` per BAGE2 nel segmento, replica esattamente.)

Nota: per le fixture con `variant != null` (R9), `mediated_effect != null` (R8), e `disease_state.status != none` usa i valori esatti che producono gli anchor della spec §4.3.

- [ ] **Step 5.2: Estendi `tests/testthat/test-anchors.R` con i test su `make_anchor()`**

```r
# make_anchor: casi base spec sec.4.3 ---------------------------------------

read_fact <- function(name) {
  jsonlite::read_json(testthat::test_path(paste0("fixtures/sample-facts-", name, ".json")))
}

test_that("make_anchor produce anchor canonico v3 per VEGF cytokine HUVEC 1h", {
  facts <- read_fact("vegf-huvec")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  expect_equal(
    anchor,
    "cytokine_stim|HGNC:12680|wt|nodose|1h|exposure|HUVEC|primary_culture|proliferating|whole_cell|vascular_endothelium|none|false"
  )
})

test_that("make_anchor R8 mediated_effect: agente di interesse = mediated_effect.target", {
  facts <- read_fact("dox-teto-sox17")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  # Atteso: kind_effective = genetic_overexpression, agent = HGNC:SOX17
  expect_match(anchor, "^genetic_overexpression\\|HGNC:")
  expect_match(anchor, "SOX17")
  # NON contiene "Dox" ne' "small_molecule"
  expect_false(grepl("Dox|small_molecule", anchor))
})

test_that("make_anchor R9 variant: segmento 3 espone label mutante", {
  facts <- read_fact("apobec1-mut")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_length(segments, 13L)
  expect_equal(segments[[3L]], "YTHmut")
})

test_that("make_anchor disease_vs_normal: disease_status segmento 12 = 'case' per stage2_role='case'", {
  facts <- read_fact("pd-ipsc-neurons")
  anchor <- make_anchor(facts, stage2_role = "case")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[1L]], "disease_vs_normal")
  expect_equal(segments[[12L]], "case")
})

test_that("make_anchor R24 phase=washout entra nell'anchor se dichiarato", {
  # Fixture artificiale: small_molecule GSI con phase="washout"
  facts <- read_fact("vegf-huvec")  # base
  facts$perturbations[[1L]]$kind <- "small_molecule"
  facts$perturbations[[1L]]$phase <- "washout"
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[6L]], "washout")
})

test_that("make_anchor R25 subcellular: default 'whole_cell' se NULL", {
  facts <- read_fact("vegf-huvec")  # subcellular_fraction = null
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[10L]], "whole_cell")
})

test_that("make_anchor R31 cell_state: default 'proliferating' se NULL", {
  facts <- read_fact("vegf-huvec")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[9L]], "proliferating")
})

test_that("make_anchor has_engineered_baseline=true se engineered_modifications non vuoto", {
  facts <- read_fact("vegf-huvec")
  facts$cell_context$engineered_modifications <- list(
    list(kind = "stable_overexpression", target = "MYC")
  )
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[13L]], "true")
})

test_that("make_anchor anchor ha sempre 13 segmenti", {
  for (name in c("vegf-huvec", "knockdown-ocily1", "dox-teto-sox17",
                 "apobec1-mut", "pd-ipsc-neurons")) {
    facts <- read_fact(name)
    role <- if (name == "pd-ipsc-neurons") "case" else "perturbed"
    anchor <- make_anchor(facts, stage2_role = role)
    segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
    expect_length(segments, 13L)
  }
})
```

- [ ] **Step 5.3: Run test, vedi fallire**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "anchors")'
```

Expected: 8 nuovi test FAIL — `make_anchor` non definita.

- [ ] **Step 5.4: Implementa `make_anchor()` in `R/anchors.R`**

Aggiungi al fondo del file esistente:

```r
#' Costruisci comparability_anchor v3 (13 segmenti) per un sample fact
#'
#' L'anchor e' una chiave canonica deterministica per cross-studio matching
#' (vedi spec sec.4.3). Selezionata la perturbazione di interesse dal sample,
#' applica le regole R8 (mediated_effect), R9 (variant), R24 (phase), R25
#' (subcellular default whole_cell), R31 (cell_state default proliferating).
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @param stage2_role string: design_role assegnato dallo Stadio 2 al sample
#'   (es. "perturbed", "case", "comparison"). Influenza il segmento 12.
#' @return string a 13 segmenti separati da "|"
#' @export
make_anchor <- function(stage1_facts, stage2_role) {
  pert <- .select_primary_perturbation(stage1_facts$perturbations, stage2_role)

  # R8: mediated_effect ridirige kind_effective + agent
  if (!is.null(pert$mediated_effect) && length(pert$mediated_effect) > 0L) {
    kind_effective <- pert$mediated_effect$kind %||% pert$kind
    agent_id <- pert$mediated_effect$target_id %||%
                paste0("HGNC:", pert$mediated_effect$target %||% "unknown")
  } else {
    kind_effective <- .map_kind_to_anchor(pert$kind %||% "unclear")
    agent_id <- .resolve_agent_id(pert$agent_normalized)
  }

  variant_label <- if (.nzchar_safe(pert$variant)) pert$variant else "wt"
  dose_canonical <- .normalize_dose(pert$dose)
  duration_canonical <- .normalize_duration(pert$duration)
  phase_canonical <- pert$phase %||% "exposure"

  cell_id <- .normalize_cell_id(
    stage1_facts$cell_context$cell_line_cellosaurus_candidate,
    stage1_facts$cell_context$cell_type_or_line_raw
  )
  context_kind <- stage1_facts$cell_context$context_kind %||% "unclear"
  cell_state <- stage1_facts$cell_context$cell_state %||% "proliferating"
  subcellular <- stage1_facts$cell_context$subcellular_fraction %||% "whole_cell"
  tissue <- stage1_facts$cell_context$tissue %||% "na"

  disease_status <- .resolve_disease_status(stage1_facts$disease_state, stage2_role)
  has_engineered <- length(stage1_facts$cell_context$engineered_modifications) > 0L

  paste(
    kind_effective,
    agent_id,
    variant_label,
    dose_canonical,
    duration_canonical,
    phase_canonical,
    cell_id,
    context_kind,
    cell_state,
    subcellular,
    tissue,
    disease_status,
    tolower(as.character(has_engineered)),
    sep = "|"
  )
}

#' @noRd
.select_primary_perturbation <- function(perturbations, stage2_role) {
  if (length(perturbations) == 0L) {
    return(list(kind = "none", agent_normalized = NULL, mediated_effect = NULL))
  }
  # Per ora: prima perturbazione non-tecnica. Future iterazioni potrebbero usare
  # stage2_role per disambiguare in factorial.
  perturbations[[1L]]
}

#' @noRd
.map_kind_to_anchor <- function(stage1_kind) {
  switch(
    stage1_kind,
    cytokine_stimulation = "cytokine_stim",
    small_molecule = "small_molecule",
    genetic_knockdown = "genetic_knockdown",
    genetic_knockout = "genetic_knockout",
    genetic_overexpression = "genetic_overexpression",
    crispra_activation = "crispra_activation",
    crispri_repression = "crispri_repression",
    pathogen_or_aggregate_exposure = "pathogen_or_aggregate_exposure",
    environmental_or_behavioral = "environmental",
    differentiation = "differentiation",
    mechanical_or_physical = "mechanical",
    vehicle_only = "vehicle_only",
    none = "none",
    stage1_kind  # passthrough per "unclear" e altri
  )
}

#' @noRd
.resolve_agent_id <- function(agent_normalized) {
  if (is.null(agent_normalized)) return("unknown")
  id_db <- agent_normalized$id_database %||% NA_character_
  id_cand <- agent_normalized$id_candidate %||% NA_character_
  if (.nzchar_safe(id_cand)) {
    return(id_cand)
  }
  pref <- agent_normalized$preferred_name %||% "unknown"
  if (.nzchar_safe(id_db) && .nzchar_safe(pref)) {
    return(paste0(id_db, ":", pref))
  }
  pref
}

#' @noRd
.resolve_disease_status <- function(disease_state, stage2_role) {
  # Per design_role case/comparison: usa direttamente
  if (stage2_role %in% c("case", "comparison")) return(stage2_role)
  # Altrimenti: heuristic sui campi disease_state
  status <- disease_state$status %||% "none"
  if (status == "disease_model") return("disease_model")
  if (status == "case") return("case")
  if (status == "comparison") return("comparison")
  "none"
}
```

- [ ] **Step 5.5: Reinstalla pacchetto e ri-run test**

Run:
```bash
Rscript --vanilla -e 'devtools::install(upgrade = "never", quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "anchors")'
```

Expected: tutti 21 test PASS (13 helpers + 8 make_anchor).

- [ ] **Step 5.6: Genera Rd**

Run:
```bash
Rscript --vanilla -e 'devtools::document()'
```

Expected: `man/make_anchor.Rd` creato.

- [ ] **Step 5.7: Commit**

```bash
git add R/anchors.R tests/testthat/test-anchors.R \
        tests/testthat/fixtures/sample-facts-*.json \
        man/make_anchor.Rd NAMESPACE
git commit -m "P3 Task 5: make_anchor() v3 13-segmenti + 8 test (R8/R9/R24/R25/R31)"
```

---

## Task 6: `R/anchors.R` — `make_inducer_log()` per audit Dox-inducibili

**Files:**
- Modifica: `R/anchors.R`
- Modifica: `tests/testthat/test-anchors.R`

`make_inducer_log()` è un complemento di `make_anchor()` quando R8 si applica: l'inducente (Dox, IPTG, 4-OHT) viene perso dall'anchor; questa funzione lo registra per audit downstream.

- [ ] **Step 6.1: Aggiungi test in `tests/testthat/test-anchors.R`**

```r
test_that("make_inducer_log: ritorna lista vuota se nessun mediated_effect", {
  facts <- read_fact("vegf-huvec")
  log <- make_inducer_log(facts)
  expect_length(log, 0L)
})

test_that("make_inducer_log: cattura inducente Dox per Tet-On", {
  facts <- read_fact("dox-teto-sox17")
  log <- make_inducer_log(facts)
  expect_length(log, 1L)
  expect_equal(log[[1L]]$inducer_kind, "small_molecule")
  expect_match(log[[1L]]$inducer_name, "Dox|doxycycline", ignore.case = TRUE)
  expect_equal(log[[1L]]$mediated_kind, "genetic_overexpression")
  expect_match(log[[1L]]$mediated_target, "SOX17")
})
```

- [ ] **Step 6.2: Run test, vedi fallire**

Expected: 2 FAIL — `make_inducer_log` non definita.

- [ ] **Step 6.3: Implementa `make_inducer_log()` in `R/anchors.R`**

Aggiungi:

```r
#' Audit log degli inducenti per perturbazioni mediated_effect (R8)
#'
#' Per ogni perturbazione con mediated_effect != null, registra l'inducente
#' che make_anchor() perde (es. Dox per sistemi Tet-On). Utile per audit
#' a valle e per QC manuale.
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @return list di entries, una per perturbazione mediated. Vuota se nessuna.
#'   Ogni entry ha campi: inducer_kind, inducer_name, mediated_kind, mediated_target.
#' @export
make_inducer_log <- function(stage1_facts) {
  perts <- stage1_facts$perturbations %||% list()
  out <- list()
  for (p in perts) {
    if (is.null(p$mediated_effect) || length(p$mediated_effect) == 0L) next
    out[[length(out) + 1L]] <- list(
      inducer_kind = p$kind %||% "unknown",
      inducer_name = p$agent_normalized$preferred_name %||% (p$agent_raw %||% "unknown"),
      mediated_kind = p$mediated_effect$kind %||% "unknown",
      mediated_target = p$mediated_effect$target %||% "unknown"
    )
  }
  out
}
```

- [ ] **Step 6.4: Reinstalla e ri-run test**

Expected: 2 PASS; totale anchors test 23 PASS.

- [ ] **Step 6.5: Document + commit**

```bash
Rscript --vanilla -e 'devtools::document()'
git add R/anchors.R tests/testthat/test-anchors.R man/make_inducer_log.Rd NAMESPACE
git commit -m "P3 Task 6: make_inducer_log() audit per perturbazioni R8 + 2 test"
```

---

## Task 7: `R/llm-stage2.R` — `build_prompt_stage2()`

**Files:**
- Crea: `R/llm-stage2.R`
- Crea: `tests/testthat/test-llm-stage2.R`

`build_prompt_stage2(series_id, sample_facts_list, study_summary, model)`: ritorna `list(messages = list(...), schema_path = ...)` pronto per `llm_call_structured()`.

- [ ] **Step 7.1: Scrivi i test (failing) `tests/testthat/test-llm-stage2.R`**

```r
test_that("build_prompt_stage2 ritorna shape messages OpenAI", {
  facts_list <- list(
    jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  )
  study_summary <- list(
    series_id = "GSE41166",
    title = "VEGF time course HUVEC",
    summary = "Primary HUVEC stimulated with VEGF; t=0,1,6,24h.",
    overall_design = NA_character_
  )
  out <- simulomicsr:::build_prompt_stage2(
    series_id = "GSE41166",
    sample_facts_list = facts_list,
    study_summary = study_summary,
    model = "openai:gpt-5.5"
  )
  expect_type(out, "list")
  expect_named(out, c("messages", "schema_path"))
  expect_length(out$messages, 2L)
  expect_equal(out$messages[[1L]]$role, "system")
  expect_equal(out$messages[[2L]]$role, "user")
  expect_match(out$messages[[1L]]$content, "study_design", ignore.case = TRUE)
  expect_match(out$messages[[1L]]$content, "design_kind", ignore.case = TRUE)
  expect_match(out$messages[[2L]]$content, "GSE41166")
  expect_match(out$messages[[2L]]$content, "GSM1009636")
})

test_that("build_prompt_stage2 system prompt contiene vocabolari sec.4.1+sec.4.2", {
  facts_list <- list(jsonlite::read_json(
    testthat::test_path("fixtures/sample-facts-vegf-huvec.json")))
  study_summary <- list(series_id = "GSE41166", title = "x", summary = "y",
                       overall_design = NA_character_)
  out <- simulomicsr:::build_prompt_stage2("GSE41166", facts_list, study_summary,
                                           "openai:gpt-5.5")
  sys <- out$messages[[1L]]$content
  for (kind in c("treatment_vs_vehicle", "time_course", "knockdown_panel",
                 "factorial", "case_control_disease")) {
    expect_match(sys, kind, fixed = TRUE)
  }
  for (role in c("perturbed", "vehicle_control", "baseline_t0", "case", "comparison")) {
    expect_match(sys, role, fixed = TRUE)
  }
})

test_that("build_prompt_stage2 user prompt contiene tutti i sample_ids forniti", {
  facts_a <- jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  facts_b <- facts_a
  facts_b$geo_accession <- "GSM1009638"
  out <- simulomicsr:::build_prompt_stage2(
    "GSE41166", list(facts_a, facts_b),
    list(series_id = "GSE41166", title = "t", summary = "s", overall_design = NA),
    "openai:gpt-5.5"
  )
  expect_match(out$messages[[2L]]$content, "GSM1009636")
  expect_match(out$messages[[2L]]$content, "GSM1009638")
})
```

- [ ] **Step 7.2: Run test, vedi fallire**

Expected: 3 FAIL — `build_prompt_stage2` non definita.

- [ ] **Step 7.3: Implementa `build_prompt_stage2()` in `R/llm-stage2.R`**

```r
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
    "- input_truncated: true se hai dovuto omettere sample_facts per limiti di token.\n\n",
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
```

- [ ] **Step 7.4: Reinstalla e ri-run test**

Expected: 3 PASS.

- [ ] **Step 7.5: Commit**

```bash
git add R/llm-stage2.R tests/testthat/test-llm-stage2.R
git commit -m "P3 Task 7: build_prompt_stage2() con vocab + 3 test"
```

---

## Task 8: `R/llm-stage2.R` — `parse_stage2_response()` con enrichment

**Files:**
- Modifica: `R/llm-stage2.R`
- Modifica: `tests/testthat/test-llm-stage2.R`

`parse_stage2_response(raw, series_id, sample_count, model)`: enrichment deterministico post-LLM. (a) forza `series_id` da input (no trust LLM su questo campo); (b) imposta `extraction.input_sample_count = sample_count` da chiamante; (c) imposta `extraction.model = model`; (d) garantisce `extraction.schema_version = "stage2.v1"`.

- [ ] **Step 8.1: Scrivi test in `tests/testthat/test-llm-stage2.R`**

```r
test_that("parse_stage2_response forza series_id da input (no trust LLM)", {
  raw <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))
  raw$series_id <- "GSE99999"  # LLM ha sbagliato
  parsed <- simulomicsr:::parse_stage2_response(
    raw, series_id = "GSE41166", sample_count = 4L,
    model = "openai:gpt-5.5"
  )
  expect_equal(parsed$series_id, "GSE41166")  # forzato dal chiamante
})

test_that("parse_stage2_response imposta input_sample_count e model", {
  raw <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))
  raw$extraction$input_sample_count <- 0L  # LLM ha sbagliato
  raw$extraction$model <- "wrong-model"
  parsed <- simulomicsr:::parse_stage2_response(
    raw, series_id = "GSE41166", sample_count = 12L,
    model = "openai:gpt-5.5"
  )
  expect_equal(parsed$extraction$input_sample_count, 12L)
  expect_equal(parsed$extraction$model, "openai:gpt-5.5")
})

test_that("parse_stage2_response garantisce schema_version='stage2.v1'", {
  raw <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))
  raw$extraction$schema_version <- "stage2.v0"
  parsed <- simulomicsr:::parse_stage2_response(
    raw, series_id = "GSE41166", sample_count = 4L,
    model = "openai:gpt-5.5"
  )
  expect_equal(parsed$extraction$schema_version, "stage2.v1")
})
```

- [ ] **Step 8.2: Run test, vedi fallire**

Expected: 3 FAIL.

- [ ] **Step 8.3: Implementa `parse_stage2_response()` in `R/llm-stage2.R`**

```r
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
```

- [ ] **Step 8.4: Reinstalla e ri-run test**

Expected: 3 PASS; totale llm-stage2 6 PASS.

- [ ] **Step 8.5: Commit**

```bash
git add R/llm-stage2.R tests/testthat/test-llm-stage2.R
git commit -m "P3 Task 8: parse_stage2_response() con enrichment deterministico + 3 test"
```

---

## Task 9: `R/llm-stage2.R` — `classify_study()` orchestratore (export)

**Files:**
- Modifica: `R/llm-stage2.R`
- Modifica: `tests/testthat/test-llm-stage2.R`

`classify_study()` è il punto di ingresso pubblico. Orchestratore: build_prompt → llm_call_structured → parse_response. Cache via P1 (chiave include messages, quindi separa Stadio 1 da Stadio 2 naturalmente).

- [ ] **Step 9.1: Scrivi test in `tests/testthat/test-llm-stage2.R`**

```r
test_that("classify_study orchestratore: chiama llm_call_structured con messages stage2", {
  facts_a <- jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  expected_design <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))

  cache <- cache_init(withr::local_tempdir(), namespace = "stage2")

  # Mock llm_call_structured: cattura input, ritorna fixture
  captured <- list(messages = NULL)
  out <- withr::with_envvar(
    c(SIMULOMICSR_LLM_PROVIDER_FORCE_MOCK = "1"),
    {
      withr::local_mocked_bindings(
        llm_call_structured = function(messages, schema, ..., provider, model, cache) {
          captured$messages <<- messages
          list(
            ok = TRUE,
            content = expected_design,
            provider = provider,
            model = model,
            cache_hit = FALSE
          )
        },
        .package = "simulomicsr"
      )
      classify_study(
        series_id = "GSE41166",
        sample_facts_list = list(facts_a),
        study_summary = list(series_id = "GSE41166", title = "t", summary = "s",
                             overall_design = NA),
        provider = "openai",
        model = "gpt-5.5",
        cache = cache
      )
    }
  )
  expect_equal(out$series_id, "GSE41166")
  expect_equal(out$extraction$schema_version, "stage2.v1")
  expect_equal(out$extraction$input_sample_count, 1L)
  expect_match(out$extraction$model, "gpt-5.5")
  expect_equal(captured$messages[[1L]]$role, "system")
})

test_that("classify_study propaga errore LLM con .invalid_reason", {
  facts_a <- jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  cache <- cache_init(withr::local_tempdir(), namespace = "stage2")
  out <- withr::with_envvar(
    c(SIMULOMICSR_LLM_PROVIDER_FORCE_MOCK = "1"),
    {
      withr::local_mocked_bindings(
        llm_call_structured = function(...) {
          list(ok = FALSE, error = "schema_validation_failed",
               error_detail = "design_kind not in enum")
        },
        .package = "simulomicsr"
      )
      classify_study(
        series_id = "GSE41166",
        sample_facts_list = list(facts_a),
        study_summary = list(series_id = "GSE41166", title = "t", summary = "s",
                             overall_design = NA),
        provider = "openai", model = "gpt-5.5", cache = cache
      )
    }
  )
  expect_equal(out$series_id, "GSE41166")
  expect_match(out$.invalid_reason, "schema_validation_failed|llm_call_failed")
})
```

- [ ] **Step 9.2: Run test, vedi fallire**

Expected: 2 FAIL — `classify_study` non definita (e non esportata).

- [ ] **Step 9.3: Implementa `classify_study()` in `R/llm-stage2.R`**

```r
#' Classifica il design di uno studio GSE in study_design.stage2.v1
#'
#' Pipeline: build_prompt_stage2() -> llm_call_structured() -> parse_stage2_response().
#' Cache trasparente via P1 (chiave include i messages, separa naturalmente
#' invocations Stadio 1 da Stadio 2). In caso di errore LLM, ritorna un
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

  res <- llm_call_structured(
    messages = prompt$messages,
    schema = prompt$schema_path,
    provider = provider,
    model = model,
    cache = cache,
    ...
  )

  if (isFALSE(res$ok)) {
    return(.stage2_invalid_record(
      series_id = series_id,
      reason = res$error %||% "llm_call_failed",
      detail = res$error_detail %||% NA_character_,
      sample_count = length(sample_facts_list),
      provider = provider, model = model
    ))
  }

  parse_stage2_response(
    raw = res$content,
    series_id = series_id,
    sample_count = length(sample_facts_list),
    model = paste0(provider, ":", model)
  )
}

#' @keywords internal
.stage2_invalid_record <- function(series_id, reason, detail, sample_count,
                                   provider, model) {
  list(
    series_id = series_id,
    .invalid_reason = reason,
    .invalid_detail = detail,
    extraction = list(
      schema_version = "stage2.v1",
      model = paste0(provider, ":", model),
      confidence = 0,
      ambiguity_flags = list(),
      input_sample_count = as.integer(sample_count),
      input_truncated = FALSE
    )
  )
}
```

- [ ] **Step 9.4: Reinstalla e ri-run test**

Expected: 2 PASS; totale llm-stage2 8 PASS.

- [ ] **Step 9.5: Document + commit**

```bash
Rscript --vanilla -e 'devtools::document()'
git add R/llm-stage2.R tests/testthat/test-llm-stage2.R \
        man/classify_study.Rd NAMESPACE
git commit -m "P3 Task 9: classify_study() orchestratore export + 2 test"
```

---

## Task 10: Stage 2 fixture mini — 3 GSE stratificati

**Files:**
- Crea: `data-raw/build-stage2-fixtures.R`
- Crea: `inst/extdata/stage2-fixtures-mini/GSE41166-sample-facts.json` (time_course)
- Crea: `inst/extdata/stage2-fixtures-mini/GSE41166-study-summary.json`
- Crea: `inst/extdata/stage2-fixtures-mini/<GSE-A>-sample-facts.json` (treatment_vs_vehicle)
- Crea: `inst/extdata/stage2-fixtures-mini/<GSE-A>-study-summary.json`
- Crea: `inst/extdata/stage2-fixtures-mini/<GSE-B>-sample-facts.json` (knockdown_panel)
- Crea: `inst/extdata/stage2-fixtures-mini/<GSE-B>-study-summary.json`

I 3 GSE sono scelti dal P2 dev set. Lo script idempotente li estrae, classifica via stage1 (cached), salva i sample_facts validati.

- [ ] **Step 10.1: Identifica i 3 GSE candidati**

Run da R, leggendo il dev set P2:
```r
dev_set <- targets::tar_read(samples_dev_set)
table(dev_set$series_id)[1:30]
```

Cerca un GSE per ognuno: time_course (multipli timepoint condivisi), treatment_vs_vehicle (drug + DMSO), knockdown_panel (siRNA target + siCtrl). Annota i 3 GSE scelti in un commento dello script.

- [ ] **Step 10.2: Crea `data-raw/build-stage2-fixtures.R`**

```r
# Build fixture mini Stadio 2: 3 GSE stratificati per design_kind.
# Idempotente: legge dev set P2, per ogni GSE classifica i sample con
# classify_sample() (cached), salva in inst/extdata/stage2-fixtures-mini/.
# I sample_facts qui sono lo *snapshot* dei sample_facts validati di P2.
#
# Run: source("data-raw/build-stage2-fixtures.R")

library(simulomicsr)
library(targets)
library(dplyr)
library(here)

dev_set <- tar_read(samples_dev_set)

# 3 GSE scelti (compila dopo Step 10.1 con i veri GSE):
candidate_gse <- c(
  GSE41166_time_course      = "GSE41166",  # PLACEHOLDER da sostituire
  GSE_treat_vehicle         = "GSEXXXXX",  # PLACEHOLDER
  GSE_knockdown_panel       = "GSEYYYYY"   # PLACEHOLDER
)

cache <- cache_init(here("analysis", "cache"), namespace = "stage1")
out_dir <- here("inst", "extdata", "stage2-fixtures-mini")
fs::dir_create(out_dir, recurse = TRUE)

for (gse in candidate_gse) {
  rows <- dev_set |> filter(series_id == gse)
  if (nrow(rows) < 2L) {
    message("skipping ", gse, " (n_samples=", nrow(rows), ")")
    next
  }
  facts_list <- lapply(seq_len(nrow(rows)), function(i) {
    classify_sample(
      sample_string = rows$string[[i]],
      geo_accession = rows$geo_accession[[i]],
      series_id = rows$series_id[[i]],
      provider = "openai", model = "gpt-5.5",
      cache = cache
    )
  })
  # Filtra invalid
  validity <- vapply(facts_list, function(f) is.null(f$.invalid_reason), logical(1))
  facts_list <- facts_list[validity]

  facts_path <- fs::path(out_dir, paste0(gse, "-sample-facts.json"))
  jsonlite::write_json(facts_list, facts_path, auto_unbox = TRUE,
                       null = "null", pretty = TRUE)

  # Study summary (cached): fetch o mock se offline
  summary_obj <- tryCatch(
    fetch_study_summary(gse, cache_dir = fs::path(out_dir, ".geo-cache")),
    error = function(e) {
      message("fetch_study_summary failed for ", gse, ": ", conditionMessage(e))
      list(series_id = gse, title = "(unfetched)", summary = "(unfetched)",
           overall_design = NA_character_)
    }
  )
  summary_path <- fs::path(out_dir, paste0(gse, "-study-summary.json"))
  jsonlite::write_json(summary_obj, summary_path, auto_unbox = TRUE,
                       null = "null", pretty = TRUE)
  message("done: ", gse, " (n=", length(facts_list), ")")
}
```

- [ ] **Step 10.3: Esegui lo script**

Pre-requisito: `OPENAI_API_KEY` in `.Renviron.local`. Run:
```bash
OPENAI_API_KEY="$(grep OPENAI_API_KEY .Renviron.local | cut -d= -f2 | tr -d '\"')" \
  Rscript --vanilla -e 'source("data-raw/build-stage2-fixtures.R")'
```

Expected: 3 file `<GSE>-sample-facts.json` + 3 file `<GSE>-study-summary.json` in `inst/extdata/stage2-fixtures-mini/`. Cache stage1 e geo riusata.

Verifica:
```bash
ls inst/extdata/stage2-fixtures-mini/
```

Expected: 6 file json.

- [ ] **Step 10.4: Commit**

```bash
git add data-raw/build-stage2-fixtures.R \
        inst/extdata/stage2-fixtures-mini/*.json
git commit -m "P3 Task 10: fixture mini Stadio 2 - 3 GSE stratificati (time_course / vehicle / knockdown)"
```

---

## Task 11: Smoke E2E gated test su gpt-5.5

**Files:**
- Crea: `tests/testthat/test-smoke-e2e-stage2.R`

Un solo test E2E reale gated su `OPENAI_API_KEY`. Usa una fixture mini stage1 e fa una chiamata vera a gpt-5.5; verifica che la risposta sia valid contro lo schema.

- [ ] **Step 11.1: Crea `tests/testthat/test-smoke-e2e-stage2.R`**

```r
test_that("smoke E2E classify_study contro gpt-5.5 produce study_design valido (gated OPENAI_API_KEY)", {
  skip_if(Sys.getenv("OPENAI_API_KEY") == "")
  skip_if_not_installed("rentrez")

  # Carica fixture stage 2: GSE41166 sample_facts pre-classificati
  facts_path <- system.file(
    "extdata/stage2-fixtures-mini/GSE41166-sample-facts.json",
    package = "simulomicsr"
  )
  summary_path <- system.file(
    "extdata/stage2-fixtures-mini/GSE41166-study-summary.json",
    package = "simulomicsr"
  )
  skip_if(!nzchar(facts_path) || !nzchar(summary_path),
          "fixture stage2-fixtures-mini non trovate (rebuild pacchetto?)")

  facts_list <- jsonlite::read_json(facts_path, simplifyVector = FALSE)
  study_summary <- jsonlite::read_json(summary_path, simplifyVector = FALSE)

  cache <- cache_init(withr::local_tempdir(), namespace = "stage2-smoke")
  result <- classify_study(
    series_id = "GSE41166",
    sample_facts_list = facts_list,
    study_summary = study_summary,
    provider = "openai", model = "gpt-5.5",
    cache = cache
  )

  expect_null(result$.invalid_reason)
  expect_equal(result$series_id, "GSE41166")
  expect_equal(result$extraction$schema_version, "stage2.v1")
  expect_true(result$extraction$confidence >= 0 & result$extraction$confidence <= 1)
  expect_true(length(result$replicate_groups) >= 1L)

  # Validazione schema esplicita
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  validator <- compile_schema(schema_path)
  validation <- validate_json(result, validator = validator)
  expect_true(validation$valid,
              info = paste(validation$errors, collapse = "\n"))
})
```

- [ ] **Step 11.2: Esegui il test (con API key)**

Run:
```bash
OPENAI_API_KEY="$(grep OPENAI_API_KEY .Renviron.local | cut -d= -f2 | tr -d '\"')" \
  Rscript --vanilla -e 'devtools::test(filter = "smoke-e2e-stage2")'
```

Expected: 1 PASS (chiamata reale a gpt-5.5; ~10-20 sec; costo ~$0.01-0.05). Se il test fallisce, ispeziona `result$.invalid_reason` (se llm_call_failed → controllare auth/payload; se schema_validation_failed → controllare prompt).

- [ ] **Step 11.3: Verifica che il test SKIP senza API key**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "smoke-e2e-stage2")'
```

Expected: 1 SKIP — "Empty test (skipped before any expectations were run)".

- [ ] **Step 11.4: Commit**

```bash
git add tests/testthat/test-smoke-e2e-stage2.R
git commit -m "P3 Task 11: smoke E2E stage2 contro gpt-5.5 (gated OPENAI_API_KEY)"
```

---

## Task 12: Target `study_summaries` in `_targets.R`

**Files:**
- Modifica: `analysis/_targets.R`

Aggiunge target che fetch `study_summary` per ogni unique `series_id` presente in `sample_facts_validated`. File-tracked: cache su disco evita re-fetch.

- [ ] **Step 12.1: Aggiungi target in `analysis/_targets.R`**

Dopo il target `sample_facts_invalid` esistente, aggiungi:

```r
  # Cache filesystem dei summary GEO (uno per GSE)
  tar_target(
    geo_summary_cache_dir,
    fs::dir_create(here::here("analysis", "cache", "geo-summary")),
    format = "file"
  ),

  # Estrai gli unique series_id dei sample_facts validati
  tar_target(
    study_series_ids,
    {
      ids <- vapply(sample_facts_validated, function(f) f$series_id %||% NA_character_,
                    character(1))
      unique(ids[!is.na(ids)])
    }
  ),

  # Dynamic branching: una invocazione per series_id
  tar_target(
    study_summaries,
    fetch_study_summary(study_series_ids, cache_dir = geo_summary_cache_dir),
    pattern = map(study_series_ids),
    iteration = "list"
  ),
```

- [ ] **Step 12.2: Run targets per popolare i summary**

Run:
```bash
OPENAI_API_KEY="$(grep OPENAI_API_KEY .Renviron.local | cut -d= -f2 | tr -d '\"')" \
  Rscript --vanilla -e '
    setwd("analysis")
    targets::tar_make(c(geo_summary_cache_dir, study_series_ids, study_summaries),
                       callr_function = NULL)
  '
```

Expected: `study_series_ids` popolato (~30-40 GSE da P2 dev set 100), `study_summaries` lista con un summary per GSE; cache JSONL su disco in `analysis/cache/geo-summary/`.

Verifica:
```bash
ls analysis/cache/geo-summary/ | head
```

Expected: file `GSEXXXXX.json`.

- [ ] **Step 12.3: Commit**

```bash
git add analysis/_targets.R
git commit -m "P3 Task 12: target study_summaries (dynamic, cached) in _targets.R"
```

---

## Task 13: Target `study_designs_raw` + `study_designs_validated`/`invalid`

**Files:**
- Modifica: `analysis/_targets.R`

Dynamic branching `pattern = map(study_series_ids, study_summaries)`: una invocazione di `classify_study()` per GSE. Partition validated/invalid via schema check.

- [ ] **Step 13.1: Aggiungi target dopo `study_summaries`**

```r
  tar_target(
    stage2_cache_dir,
    fs::dir_create(here::here("analysis", "cache")),
    format = "file"
  ),

  tar_target(
    study_designs_raw,
    {
      gse <- study_series_ids
      summary_obj <- study_summaries
      # Filtra sample_facts_validated per questo GSE
      facts_for_gse <- Filter(
        function(f) identical(f$series_id, gse),
        sample_facts_validated
      )
      classify_study(
        series_id = gse,
        sample_facts_list = facts_for_gse,
        study_summary = summary_obj,
        provider = "openai", model = "gpt-5.5",
        cache = cache_init(stage2_cache_dir, namespace = "stage2")
      )
    },
    pattern = map(study_series_ids, study_summaries),
    iteration = "list"
  ),

  tar_target(
    study_designs_validator,
    system.file("schemas/study_design.stage2.v1.json", package = "simulomicsr"),
    format = "file"
  ),

  tar_target(
    study_designs_validated,
    {
      validator <- compile_schema(study_designs_validator)
      keep <- vapply(study_designs_raw, function(d) {
        if (!is.null(d$.invalid_reason)) return(FALSE)
        d$.invalid_reason <- NULL
        d$.invalid_detail <- NULL
        validate_json(d, validator = validator)$valid
      }, logical(1))
      study_designs_raw[keep]
    }
  ),

  tar_target(
    study_designs_invalid,
    {
      validator <- compile_schema(study_designs_validator)
      drop <- vapply(study_designs_raw, function(d) {
        if (!is.null(d$.invalid_reason)) return(TRUE)
        d$.invalid_reason <- NULL
        d$.invalid_detail <- NULL
        !validate_json(d, validator = validator)$valid
      }, logical(1))
      study_designs_raw[drop]
    }
  ),
```

- [ ] **Step 13.2: Run targets per popolare gli study_designs**

Run:
```bash
OPENAI_API_KEY="$(grep OPENAI_API_KEY .Renviron.local | cut -d= -f2 | tr -d '\"')" \
  Rscript --vanilla -e '
    setwd("analysis")
    targets::tar_make(c(study_designs_raw, study_designs_validated,
                         study_designs_invalid), callr_function = NULL)
  '
```

Expected: `study_designs_raw` popolato (1 invocazione gpt-5.5 per GSE; ~30-40 chiamate; ~5-10 min; ~$0.50-1.50). `study_designs_validated` filtra schema-valid; `study_designs_invalid` raccoglie i fallimenti per ispezione.

Verifica:
```bash
Rscript --vanilla -e '
  setwd("analysis")
  v <- targets::tar_read(study_designs_validated)
  i <- targets::tar_read(study_designs_invalid)
  cat("validated:", length(v), "\n")
  cat("invalid:", length(i), "\n")
  if (length(v) > 0) print(v[[1]]$design_kind)
'
```

- [ ] **Step 13.3: Commit**

```bash
git add analysis/_targets.R
git commit -m "P3 Task 13: target study_designs_raw + validated/invalid (dynamic per GSE)"
```

---

## Task 14: Target `comparisons_table` flatten + `make_anchor()` precalcolato

**Files:**
- Modifica: `analysis/_targets.R`

Flat table con una riga per (study, comparison), arricchita con `comparability_anchor` calcolato a partire dal sample_facts del treated group.

- [ ] **Step 14.1: Aggiungi target dopo `study_designs_invalid`**

```r
  tar_target(
    comparisons_table,
    {
      rows <- list()
      for (design in study_designs_validated) {
        sid <- design$series_id
        # Indicizza i sample_facts per geo_accession dentro questo GSE
        facts_idx <- list()
        for (f in sample_facts_validated) {
          if (identical(f$series_id, sid)) {
            facts_idx[[f$geo_accession]] <- f
          }
        }
        # Indicizza replicate_groups per group_id -> design_role + sample_ids
        groups_idx <- list()
        for (g in design$replicate_groups) {
          groups_idx[[g$group_id]] <- g
        }
        # Per ogni comparison: prendi treated group, scegli un sample_fact rappresentativo
        for (cmp in design$comparisons) {
          treated_grp <- groups_idx[[cmp$treated_group]]
          if (is.null(treated_grp) || length(treated_grp$sample_ids) == 0L) next
          repr_id <- treated_grp$sample_ids[[1L]]
          repr_facts <- facts_idx[[repr_id]]
          if (is.null(repr_facts)) next
          anchor <- tryCatch(
            make_anchor(repr_facts, stage2_role = treated_grp$design_role),
            error = function(e) NA_character_
          )
          rows[[length(rows) + 1L]] <- tibble::tibble(
            series_id = sid,
            comparison_id = cmp$comparison_id,
            treated_group = cmp$treated_group,
            control_group = cmp$control_group,
            varying_factor = cmp$varying_factor,
            study_internal_score = cmp$study_internal_score %||% NA_real_,
            comparability_anchor = anchor,
            anchor_version = "v3",
            design_kind = design$design_kind,
            n_samples_treated = length(treated_grp$sample_ids),
            n_samples_control = length(groups_idx[[cmp$control_group]]$sample_ids %||% character(0))
          )
        }
      }
      if (length(rows) == 0L) {
        return(tibble::tibble(
          series_id = character(0), comparison_id = character(0),
          treated_group = character(0), control_group = character(0),
          varying_factor = character(0),
          study_internal_score = numeric(0),
          comparability_anchor = character(0), anchor_version = character(0),
          design_kind = character(0),
          n_samples_treated = integer(0), n_samples_control = integer(0)
        ))
      }
      dplyr::bind_rows(rows)
    }
  ),
```

- [ ] **Step 14.2: Run target**

Run:
```bash
Rscript --vanilla -e '
  setwd("analysis")
  targets::tar_make(comparisons_table, callr_function = NULL)
  ct <- targets::tar_read(comparisons_table)
  cat("nrow:", nrow(ct), "\n")
  cat("unique anchors:", length(unique(ct$comparability_anchor)), "\n")
  print(head(ct))
'
```

Expected: tibble con N righe (1 per comparison cross-studio), colonne incluse `comparability_anchor` v3 ben formato (13 segmenti).

- [ ] **Step 14.3: Commit**

```bash
git add analysis/_targets.R
git commit -m "P3 Task 14: target comparisons_table con make_anchor() precalcolato"
```

---

## Task 15: Vignette `vignettes/stage2-classify.Rmd`

**Files:**
- Crea: `vignettes/stage2-classify.Rmd`

Vignette utente-facing: come classificare un GSE end-to-end con `fetch_study_summary()` + `classify_study()` + `make_anchor()`. Eseguibile offline con fixture mini.

- [ ] **Step 15.1: Crea `vignettes/stage2-classify.Rmd`**

```rmd
---
title: "Stage 2: study_design + comparability_anchor"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Stage 2: study_design + comparability_anchor}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r, include = FALSE}
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
```

Lo Stadio 2 di simulomicsr trasforma una lista di `sample_facts.stage1.v3`
(prodotti dallo Stadio 1 sulle stringhe di metadati GEO) in un record
`study_design.stage2.v1` per ogni GSE: replicate groups, design_role,
factor matrix, comparisons appaiate, e — cruciale per la meta-analisi
cross-studio — `comparability_anchor` v3 calcolato deterministicamente.

## Setup

```{r setup, eval = FALSE}
library(simulomicsr)
library(jsonlite)

facts_list <- read_json(
  system.file("extdata/stage2-fixtures-mini/GSE41166-sample-facts.json",
              package = "simulomicsr"),
  simplifyVector = FALSE
)
study_summary <- read_json(
  system.file("extdata/stage2-fixtures-mini/GSE41166-study-summary.json",
              package = "simulomicsr"),
  simplifyVector = FALSE
)
cache <- cache_init(tempfile(), namespace = "stage2-vignette")
```

## Classifica lo studio (richiede `OPENAI_API_KEY`)

```{r classify, eval = FALSE}
design <- classify_study(
  series_id = "GSE41166",
  sample_facts_list = facts_list,
  study_summary = study_summary,
  provider = "openai", model = "gpt-5.5",
  cache = cache
)
str(design, max.level = 2)
```

Output atteso: oggetto `study_design.stage2.v1` con `design_kind`,
`replicate_groups`, `comparisons` e `extraction` arricchita
deterministicamente.

## Calcola l'anchor per una comparison

`make_anchor()` e' R puro (no LLM): prende il sample_facts del gruppo
treated e ritorna l'anchor canonico v3 a 13 segmenti.

```{r anchor, eval = FALSE}
treated_facts <- facts_list[[2]]  # primo sample treated
anchor <- make_anchor(treated_facts, stage2_role = "perturbed")
anchor
```

Output esempio:
`cytokine_stim|HGNC:12680|wt|nodose|1h|exposure|HUVEC|primary_culture|proliferating|whole_cell|vascular_endothelium|none|false`

I 13 segmenti permettono il cross-studio matching: due studi diversi che
misurano "VEGF stim 1h HUVEC" producono lo stesso anchor → si poolia con
metafor REM (Stadio 5).

## Audit log per perturbazioni mediated_effect (R8)

Per perturbazioni inducibili (Tet-On, AID, 4-OHT), `make_anchor()` perde
l'inducente (es. Dox) per privilegiare il target biologico
(`mediated_effect.target`). L'inducente sopravvive in `make_inducer_log()`
per audit:

```{r inducer, eval = FALSE}
make_inducer_log(treated_facts)  # vuoto se nessun mediated_effect
```

## Pipeline targets

Nel `analysis/_targets.R`, lo Stadio 2 e' orchestrato da:
`study_summaries` → `study_designs_raw` → `study_designs_validated` →
`comparisons_table` (con anchor precalcolato per ogni comparison).

Vedi `targets::tar_visnetwork()` per il DAG.
```

- [ ] **Step 15.2: Build vignette**

Run:
```bash
Rscript --vanilla -e 'devtools::build_vignettes()'
```

Expected: nessun errore (vignette ha `eval = FALSE` su tutti i chunk LLM-bound, quindi non richiede API key per build).

- [ ] **Step 15.3: Commit**

```bash
git add vignettes/stage2-classify.Rmd
git commit -m "P3 Task 15: vignette stage2-classify (esempio + anchor + inducer log)"
```

---

## Task 16: NEWS + DESCRIPTION bump 0.0.0.9004

**Files:**
- Modifica: `NEWS.md`
- Modifica: `DESCRIPTION`

- [ ] **Step 16.1: Aggiorna NEWS.md**

Aggiungi sezione in cima:

```markdown
# simulomicsr 0.0.0.9004

## Stadio 2 (P3) — study_design + comparability_anchor

- Schema strict `inst/schemas/study_design.stage2.v1.json` per OpenAI Structured Outputs (vocab `design_kind` 10 valori, `design_role` 13 valori).
- `R/llm-stage2.R`: `build_prompt_stage2()` (internal), `parse_stage2_response()` (internal), **`classify_study()`** (export pubblico).
- `R/geo-fetch.R`: **`fetch_study_summary()`** (export pubblico) wrapper su `rentrez::entrez_summary(db="gds")` con cache filesystem JSONL.
- `R/anchors.R`: helpers privati `.normalize_dose()`, `.normalize_duration()`, `.normalize_cell_id()`; **`make_anchor()`** (export, 13 segmenti v3, regole R8/R9/R24/R25/R31); **`make_inducer_log()`** (export, audit per perturbazioni mediated_effect).
- `analysis/_targets.R`: target `study_summaries`, `study_designs_raw`, `study_designs_validated`, `study_designs_invalid`, `comparisons_table`. Dynamic branching su unique GSE.
- `vignettes/stage2-classify.Rmd`: vignette utente con esempio end-to-end e fixture mini.

## Convenzioni

- Cache LLM partizionata per Stadio: namespace `stage2` (separato da `stage1`).
- Anchor v3 versionato: future iterazioni (v4+) richiedono solo ricalcolo deterministico (no re-LLM).
- `comparability_anchor` NON è nello schema LLM: viene calcolato a valle da `make_anchor()` e aggiunto come colonna a `comparisons_table`.
```

- [ ] **Step 16.2: Bump DESCRIPTION**

In `DESCRIPTION` cambia:
```
Version: 0.0.0.9003
```
in:
```
Version: 0.0.0.9004
```

- [ ] **Step 16.3: Commit**

```bash
git add NEWS.md DESCRIPTION
git commit -m "P3 Task 16: bump 0.0.0.9004 + NEWS aggiornato"
```

---

## Task 17: R CMD check + final tests + merge + tag

**Files:** nessuno modificato in questo task; check finale e cerimonie chiusura.

- [ ] **Step 17.1: Run R CMD check**

Run:
```bash
Rscript --vanilla -e 'devtools::check(error_on = "error")'
```

Expected: 0 errors. Note pre-esistenti (es. spelling) accettabili. Warning NUOVI da affrontare.

- [ ] **Step 17.2: Run full test suite**

Run:
```bash
OPENAI_API_KEY="$(grep OPENAI_API_KEY .Renviron.local | cut -d= -f2 | tr -d '\"')" \
  Rscript --vanilla -e 'devtools::test()'
```

Expected: tutti PASS, 0 FAIL. SKIP solo i 2 smoke E2E senza key (~3 ora con key).

- [ ] **Step 17.3: Pulizia working tree pre-commit**

Per la convenzione (CLAUDE.md): rimuovi file untracked autogenerati che non vanno committati.

```bash
git status
```

Se vedi:
- `renv/settings.json` untracked → `git checkout -- renv/settings.json` o lascia se gitignored
- `analysis/_targets/.gitignore` rimosso → ripristina con `git checkout HEAD -- analysis/_targets/.gitignore` (o ricrea il contenuto standard `*\n!.gitignore`)
- `analysis/_targets/meta/meta` rimosso → ripristina

Verifica finale:
```bash
git status
```

Expected: working tree clean.

- [ ] **Step 17.4: Merge fast-forward su master**

Run:
```bash
git checkout master
git merge --ff-only p3-stage2
```

Expected: fast-forward riuscito. Master ora ha tutti i commit P3.

- [ ] **Step 17.5: Tag `p3-stage2-complete`**

Run:
```bash
git tag -a p3-stage2-complete -m "P3 — Stadio 2 study_design + comparability_anchor + GEO fetch (engineering)"
git tag --list 'p3-*'
```

Expected: tag creato.

- [ ] **Step 17.6: Aggiorna CLAUDE.md "Stato corrente"**

Apri `CLAUDE.md` e aggiorna la sezione "Stato corrente" con:
- nuovo `Master HEAD` (commit hash dopo merge)
- `Tag` aggiunto: `p3-stage2-complete`
- aggiungi sezione "Cosa P3 ha consegnato" con bullet point dei deliverable
- aggiorna i risultati run reale Stadio 2 se disponibili (n_GSE classificati, validity_rate, design_kind distribution, costo cumulativo P3)

Commit:
```bash
git add CLAUDE.md
git commit -m "P3 chiusura: aggiorna CLAUDE.md Stato corrente con HEAD + tag + deliverable"
```

- [ ] **Step 17.7: Verifica finale**

Run:
```bash
git log --oneline -20
git tag --list
```

Expected:
- 17 commit P3 (Task 1..17) + commit chiusura
- tag `p1-infra-llm-complete`, `p2-stage1-complete`, `p3-stage2-complete`

P3 chiuso. NON fare push (utente fa lui). Pronti per: brainstorm + plan P3.5 (gold design-aware + benchmark RummaGEO) come fase successiva.

---

## Self-review notes (compilato dall'autore del plan)

**Spec coverage check:** ogni section/requisito di spec v5 §4-§5 ha un task corrispondente:
- §4 schema → Task 2
- §4.1 vocab design_kind → Task 2 (enum nello schema)
- §4.2 vocab design_role → Task 2 (enum nello schema)
- §4.3 anchor v3 13 segmenti + regole R8/R9/R24/R25/R31 → Task 5
- §5.1 R/llm-stage2.R → Task 7-9
- §5.1 R/anchors.R → Task 4-6
- §5.1 R/geo-fetch.R → Task 3
- §5.2 target study_designs/comparisons_table → Task 12-14
- §5.3 modello gpt-5.5 → Task 11 (smoke E2E)
- §5.4 cache key Stadio 2 → P1 cache esistente (chiave include messages, partition naturale stage1 vs stage2 via namespace)
- ADR-0006 deliverable P3.5 (gold + benchmark RummaGEO) → esplicitamente OUT of scope di P3 (vedi §"NON in scope")

**Type consistency check:**
- `make_anchor(stage1_facts, stage2_role)` — firma identica in Task 4-5-6, test, e _targets.R Task 14.
- `classify_study(series_id, sample_facts_list, study_summary, ..., provider, model, cache)` — firma identica in Task 9, smoke test Task 11, vignette Task 15, target Task 13.
- `fetch_study_summary(series_id, cache_dir = NULL)` — firma identica in Task 3, build-stage2-fixtures.R Task 10, target Task 12.
- 13 segmenti dell'anchor enumerati identicamente in spec §4.3, Task 5 implementazione, e test fixture nella spec stessa. Match verificato.

**Placeholder scan:** `data-raw/build-stage2-fixtures.R` Task 10 ha 3 PLACEHOLDER GSE intenzionali — vanno sostituiti dall'esecutore al momento dello Step 10.1 dopo aver ispezionato il dev set P2 reale. È un placeholder controllato (con istruzioni esplicite nel commento), non TBD.

**Fixed-in-flight:** se `entrez_summary(db="gds")` non espone `overall_design`, accettiamo `NA_character_` per quel campo. Lo Stadio 2 prompt usa `summary` come fonte primaria; `overall_design` è secondario. Decisione presa qui per evitare scope-creep su parsing XML EUtils.
