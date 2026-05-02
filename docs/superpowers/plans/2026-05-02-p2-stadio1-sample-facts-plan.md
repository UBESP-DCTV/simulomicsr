# P2 — Stadio 1 sample_facts (prompt + schema v3 + targets + eval) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trasformare un sample RNAseq (riga del xlsx con `string`+`geo_accession`+`series_id`) in un record `sample_facts` JSON conforme allo schema `stage1.v3` definito nella spec v5 §3, sopra l'infrastruttura LLM consegnata da P1 (`llm_call_structured()`, cache JSONL+SQLite, `validate_json()`, `normalize_gene()`). P2 consegna: (1) lo schema strict; (2) `R/llm-stage1.R` con `build_prompt_stage1()`/`parse_stage1_response()`/`classify_sample()`; (3) i primi target di `analysis/_targets.R` (samples_input → dev_set → sample_facts → eval); (4) un eval iniziale (schema-validity rate + recall di campi chiave) su 100 sample stratificati.

**Architecture:** Tre strati. (a) Schema JSON Schema draft-07 strict-friendly per OpenAI Structured Outputs (additionalProperties:false ovunque, tutti i campi `required`, optionals modellati come `["<type>", "null"]`). (b) Funzioni pure in `R/llm-stage1.R` che costruiscono il prompt (system con vocabolari §3.1-§3.12 + 1 esempio few-shot, user con `sample_string`+`geo_accession`+`series_id`), invocano `llm_call_structured()`, e fanno enrichment deterministico post-parse (geo_accession/series_id forzati da input, `extraction.raw_input_hash` calcolato qui, `extraction.model` settato qui). (c) Pipeline `analysis/_targets.R` con dynamic branching `pattern = map(samples_dev_set)` su 100 sample, partition validated/invalid, eval metrics aggregate. Il modello di default in P2 è **`gpt-5.5`** (spec §5.3.1: "Sviluppo iniziale: gpt-5.5 ANCHE per Stadio 1 nei primi 100-200 sample del dev set"). Test pattern: tutto on-disk con `httptest2` cassette o `provider="mock"`; un solo smoke E2E reale gated su `OPENAI_API_KEY`.

**Tech Stack:** R 4.5+, P1 stack (`httr2`, `jsonlite`, `jsonvalidate`, `DBI`+`RSQLite`, `digest`), in più `readxl` (lettura xlsx), `dplyr` (stratificazione dev set), `tibble`, `targets` + `tarchetypes` (pipeline applicativa). `rmarkdown`/`knitr` per la vignette.

---

## File Structure

| File | Responsabilità | LOC stimato |
|---|---|---|
| `inst/schemas/sample_facts.stage1.v3.json` | JSON Schema strict per Stadio 1 (spec §3). additionalProperties:false ovunque; tutti i campi required; optionals come `["<type>","null"]`; enum citati da §3.1-§3.12 | ~340 |
| `inst/extdata/sample-fixtures-mini.tsv` | 8 sample (2 control easy, 2 treated easy, 2 disagree EP-vs-shallow, 2 ambigui) estratti dal xlsx come fixtures stabili. Test e vignette consumano solo questo file, mai il xlsx | ~10 |
| `tests/testthat/fixtures/stage1-valid-vegf-huvec.json` | Esempio valido v3 (l'esempio mostrato in spec §3) | ~80 |
| `tests/testthat/fixtures/stage1-invalid-bad-kind.json` | Esempio non-conforme (perturbations[].kind fuori vocab) | ~30 |
| `tests/testthat/fixtures/stage1-invalid-missing-required.json` | Esempio non-conforme (manca `extraction.confidence`) | ~25 |
| `R/llm-stage1.R` | `build_prompt_stage1(sample_string, geo_accession, series_id, organism_hint = NULL, model = "gpt-5.5")` (internal), `parse_stage1_response(raw, sample_string, geo_accession, series_id, model)` (internal), `classify_sample(sample_string, geo_accession, series_id, ..., provider, model, cache, organism_hint)` (export), `read_sample_fixtures_mini()` (internal helper test/vignette) | ~280 |
| `R/eval-sampling.R` | `read_samples_input(path, n_max=NULL)`, `build_dev_set(samples, n=100, seed=1812)` con stratificazione 60/30/10 (spec §6.1) | ~120 |
| `R/eval-metrics.R` (P2 subset) | `stage1_schema_validity_rate(facts_validated, facts_invalid)`, `stage1_recall_key_fields(facts_validated)` — solo metriche P2; lo Stadio 2 le aggiungerà in P3 | ~80 |
| `analysis/_targets.R` | Aggiunta target: `samples_input_path` (file), `samples_input`, `samples_dev_set`, `sample_facts_raw` (dynamic), `sample_facts_validated` (dynamic), `sample_facts_invalid` (dynamic), `eval_stage1_metrics`, `eval_stage1_report` | ~100 (sostituisce lo skeleton attuale) |
| `analysis/_targets_packages.R` | `tibble`, `dplyr`, `readxl`, `tarchetypes`, `simulomicsr` | ~6 |
| `tests/testthat/test-stage1-schema.R` | Schema accetta esempio v3 della spec; rifiuta bad_kind / missing_required / additionalProperties violation | ~120 |
| `tests/testthat/test-llm-stage1.R` | `build_prompt_stage1()`: ritorna list di messages OpenAI-shape; `parse_stage1_response()`: enrichment deterministico (geo_accession overwrite, raw_input_hash); `classify_sample()`: orchestratore con mock adapter, cache hit, error pass-through | ~220 |
| `tests/testthat/test-eval-sampling.R` | `read_samples_input()` legge xlsx; `build_dev_set()` stratifica 60/30/10 con seed deterministico | ~110 |
| `tests/testthat/test-eval-metrics.R` | `stage1_schema_validity_rate` e `stage1_recall_key_fields` su esempi minimi | ~80 |
| `tests/testthat/test-smoke-e2e-stage1.R` | Smoke E2E reale gated `OPENAI_API_KEY`, classifica 1 sample fixture e verifica shape | ~70 |
| `vignettes/stage1-classify.Rmd` | Vignette: come classificare un sample con `classify_sample()`, con fixture e dump fittizio HGNC per `normalize_gene()` opzionale | ~120 |
| `data-raw/dev-set-sampling-decision.md` | Decisione operativa: come è stato campionato il dev set 100, quali strati, seed, riproducibilità | ~40 |

File tagliati e tenuti separati per responsabilità: schema (dato), prompt-funzioni (logica LLM), eval-sampling (dato → strati), eval-metrics (numeri), targets (orchestrazione). Ogni file ha test dedicato.

Sono **NON** in scope di P2:
- `R/llm-stage2.R`, `R/anchors.R`, `R/geo-fetch.R`, `R/migrate.R` (P3)
- Batch API OpenAI (P3, vedi memory note `Batch API`)
- Vocabolari extra (Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI) — P3 o plan separato (memory `Decisioni rinviate`)
- Gold "design-aware" — P3 mid-stage

---

## Task 1: Branch + DESCRIPTION + dev deps + renv snapshot

**Files:**
- Modifica: `DESCRIPTION`
- Modifica: `analysis/_targets_packages.R`
- Modifica: `renv.lock` (via `renv::snapshot()`)

- [ ] **Step 1.1: Verifica master pulito e aggiornato a `p1-infra-llm-complete`**

Run:
```bash
git status
git tag --list 'p1-*'
git rev-parse HEAD
```

Expected: `working tree clean`, `p1-infra-llm-complete` presente, HEAD uguale al commit del tag (oppure ahead se c'è già stato un commit di housekeeping post-P1; in tal caso continuare).

- [ ] **Step 1.2: Crea branch `p2-stage1`**

Run:
```bash
git checkout -b p2-stage1
```

Expected: `Switched to a new branch 'p2-stage1'`.

- [ ] **Step 1.3: Aggiorna `DESCRIPTION` con i nuovi Suggests**

Apri `DESCRIPTION` e nella sezione `Suggests:` aggiungi (in ordine alfabetico) le righe `dplyr,`, `readxl,`, `tidyr,`. Risultato finale del blocco `Suggests:`:

```
Suggests:
    checkmate,
    covr,
    devtools,
    dplyr,
    here,
    httptest2,
    knitr,
    lintr,
    qs,
    readxl,
    rmarkdown,
    spelling,
    tarchetypes,
    targets,
    testthat (>= 3.0.0),
    tidyr,
    usethis,
    withr
```

(Tutte le righe `Imports:` restano invariate. `dplyr`/`readxl`/`tidyr` finiscono in Suggests perché servono ad `analysis/` e ai test, non al runtime della libreria — coerente con la policy P1.)

- [ ] **Step 1.4: Aggiorna `analysis/_targets_packages.R`**

Sovrascrivi il contenuto del file con:

```r
# Pacchetti caricati nei worker `targets`.
#
# Allineato con `Imports`/`Suggests` di ../DESCRIPTION (vedi
# docs/decisions/0002-struttura-research-compendium.md).

library(tibble)
library(dplyr)
library(tidyr)
library(readxl)
library(rmarkdown)
library(tarchetypes)
library(simulomicsr)
```

- [ ] **Step 1.5: Installa nuove dipendenze in renv**

Run da R (root del repo):

```r
renv::install(c("readxl", "dplyr", "tidyr"))
```

Expected: nessun errore, `readxl`, `dplyr` e `tidyr` installati.

- [ ] **Step 1.6: Snapshot renv**

Run da R:

```r
renv::snapshot(type = "implicit", prompt = FALSE)
```

Expected: `renv.lock` aggiornato con `readxl` e `dplyr`. Verifica:

```bash
grep -E '"readxl"|"dplyr"' renv.lock | head
```

Expected: due pacchetti presenti.

- [ ] **Step 1.7: Commit**

```bash
git add DESCRIPTION analysis/_targets_packages.R renv.lock
git commit -m "P2 Task 1: dipendenze readxl + dplyr + tidyr + targets_packages popolato"
```

---

## Task 2: Schema `sample_facts.stage1.v3.json`

**Files:**
- Crea: `inst/schemas/sample_facts.stage1.v3.json`
- Crea: `tests/testthat/fixtures/stage1-valid-vegf-huvec.json`
- Crea: `tests/testthat/fixtures/stage1-invalid-bad-kind.json`
- Crea: `tests/testthat/fixtures/stage1-invalid-missing-required.json`
- Crea: `tests/testthat/test-stage1-schema.R`

> **Vincoli OpenAI Structured Outputs strict:**
> 1. `additionalProperties: false` su **ogni** oggetto.
> 2. **Tutti** i campi devono essere in `required` (gli "optional" si modellano con union null: `"type": ["string", "null"]` o equivalente).
> 3. Niente `$ref`, niente `oneOf`/`anyOf` con discriminator complessi (li teniamo flat).
> 4. Profondità annidamento ≤ 5 — il nostro schema è profondo 4.
> 5. Enum totali ≤ 100 — il nostro è ~80.
>
> Non rilassare questi vincoli senza riaprire la spec; sono un contratto con il provider.

- [ ] **Step 2.1: Crea fixture VALID `tests/testthat/fixtures/stage1-valid-vegf-huvec.json`**

(Esempio v3 dalla spec §3, con tutti i campi optional esplicitamente messi a `null`/array vuoto, hash placeholder.)

```json
{
  "geo_accession": "GSM1009635",
  "series_id": "GSE41166",
  "organism": "Homo sapiens",
  "host_organism": null,
  "cell_context": {
    "cell_type_or_line_raw": "Primary Human Umbilical Vein Endothelial Cells",
    "cell_line_cellosaurus_candidate": null,
    "tissue": "vascular endothelium",
    "tissue_segment": null,
    "passage_or_state": "P3-6",
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
    "term_raw": null,
    "mesh_id_candidate": null,
    "status": "none"
  },
  "perturbations": [
    {
      "kind": "cytokine_stimulation",
      "agent_raw": "VEGF",
      "agent_normalized": {
        "type": "gene_or_protein",
        "id_database": "HGNC",
        "id": "HGNC:12680",
        "preferred_name": "VEGFA",
        "collection": null
      },
      "dose": { "value_raw": null, "value_numeric": null, "unit": null },
      "duration": { "value_raw": "0h", "value_hours": 0, "is_zero_timepoint": true },
      "phase": null,
      "temporal_order": null,
      "is_negative_control": false,
      "mediated_effect": null
    }
  ],
  "technical_treatments": [],
  "patient_metadata": null,
  "extraction": {
    "schema_version": "stage1.v3",
    "model": "openai:gpt-5.5",
    "confidence": 0.78,
    "ambiguity_flags": [],
    "raw_input_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }
}
```

- [ ] **Step 2.2: Crea fixture INVALID `tests/testthat/fixtures/stage1-invalid-bad-kind.json`**

(Identica alla valid, ma `perturbations[0].kind = "weird_kind_not_in_vocab"`.)

```json
{
  "geo_accession": "GSM_X",
  "series_id": "GSE_X",
  "organism": "Homo sapiens",
  "host_organism": null,
  "cell_context": {
    "cell_type_or_line_raw": null,
    "cell_line_cellosaurus_candidate": null,
    "tissue": null,
    "tissue_segment": null,
    "passage_or_state": null,
    "context_kind": "unclear",
    "developmental_stage": null,
    "cell_state": null,
    "subcellular_fraction": null,
    "engineered_modifications": [],
    "co_culture_partners": [],
    "sort_markers": [],
    "cell_composition_estimates": []
  },
  "disease_state": { "term_raw": null, "mesh_id_candidate": null, "status": "none" },
  "perturbations": [
    {
      "kind": "weird_kind_not_in_vocab",
      "agent_raw": null,
      "agent_normalized": {
        "type": "none", "id_database": null, "id": null,
        "preferred_name": null, "collection": null
      },
      "dose":     { "value_raw": null, "value_numeric": null, "unit": null },
      "duration": { "value_raw": null, "value_hours": null, "is_zero_timepoint": false },
      "phase": null, "temporal_order": null,
      "is_negative_control": false, "mediated_effect": null
    }
  ],
  "technical_treatments": [],
  "patient_metadata": null,
  "extraction": {
    "schema_version": "stage1.v3", "model": "openai:gpt-5.5",
    "confidence": 0.5, "ambiguity_flags": [],
    "raw_input_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }
}
```

- [ ] **Step 2.3: Crea fixture INVALID `tests/testthat/fixtures/stage1-invalid-missing-required.json`**

(Mancano `extraction.confidence` e `extraction.ambiguity_flags`.)

```json
{
  "geo_accession": "GSM_X",
  "series_id": "GSE_X",
  "organism": "Homo sapiens",
  "host_organism": null,
  "cell_context": {
    "cell_type_or_line_raw": null, "cell_line_cellosaurus_candidate": null,
    "tissue": null, "tissue_segment": null, "passage_or_state": null,
    "context_kind": "unclear", "developmental_stage": null, "cell_state": null,
    "subcellular_fraction": null, "engineered_modifications": [],
    "co_culture_partners": [], "sort_markers": [], "cell_composition_estimates": []
  },
  "disease_state": { "term_raw": null, "mesh_id_candidate": null, "status": "none" },
  "perturbations": [],
  "technical_treatments": [],
  "patient_metadata": null,
  "extraction": {
    "schema_version": "stage1.v3", "model": "openai:gpt-5.5",
    "raw_input_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }
}
```

- [ ] **Step 2.4: Scrivi i test failing in `tests/testthat/test-stage1-schema.R`**

```r
schema_path <- function() {
  system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr")
}

read_fixture <- function(name) {
  path <- testthat::test_path("fixtures", name)
  jsonlite::fromJSON(readr::read_file(path), simplifyVector = FALSE)
}

test_that("schema sample_facts.stage1.v3 esiste come file bundled", {
  expect_true(nzchar(schema_path()))
  expect_true(fs::file_exists(schema_path()))
})

test_that("schema accetta l'esempio v3 della spec (HUVEC + VEGF)", {
  v <- compile_schema(schema_path())
  ex <- read_fixture("stage1-valid-vegf-huvec.json")
  res <- validate_json(ex, validator = v)
  expect_true(res$valid, info = paste(res$errors, collapse = " | "))
})

test_that("schema rifiuta perturbations[].kind fuori vocab", {
  v <- compile_schema(schema_path())
  bad <- read_fixture("stage1-invalid-bad-kind.json")
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "), "kind", ignore.case = TRUE)
})

test_that("schema rifiuta extraction senza required (confidence + ambiguity_flags)", {
  v <- compile_schema(schema_path())
  bad <- read_fixture("stage1-invalid-missing-required.json")
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "),
               "confidence|ambiguity_flags", ignore.case = TRUE)
})

test_that("schema rifiuta additionalProperties al top level", {
  v <- compile_schema(schema_path())
  ex <- read_fixture("stage1-valid-vegf-huvec.json")
  ex$rogue_field <- "this should not be accepted"
  res <- validate_json(ex, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "),
               "additional|rogue_field", ignore.case = TRUE)
})
```

- [ ] **Step 2.5: Run tests, verifica che falliscono per "schema not found"**

Run:
```bash
Rscript -e 'devtools::test(filter = "stage1-schema")'
```

Expected: i 5 test falliscono perché `system.file(...)` ritorna `""` (lo schema non esiste ancora).

- [ ] **Step 2.6: Crea `inst/schemas/sample_facts.stage1.v3.json`**

Schema completo strict-friendly per OpenAI Structured Outputs. Tutti i campi sono in `required`; gli optional sono modellati come union con `null`. Vocabolari da spec §3.1-§3.12.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "sample_facts.stage1.v3",
  "description": "Output JSON per ogni sample RNAseq dello Stadio 1 — spec v5 §3 (post 4 dry-run, 190 sample). Strict-friendly per OpenAI Structured Outputs: additionalProperties:false ovunque, tutti i campi required, optionals come union null.",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "geo_accession", "series_id", "organism", "host_organism",
    "cell_context", "disease_state", "perturbations",
    "technical_treatments", "patient_metadata", "extraction"
  ],
  "properties": {
    "geo_accession": { "type": "string", "minLength": 1 },
    "series_id":     { "type": "string", "minLength": 1 },
    "organism":      { "type": ["string", "null"] },
    "host_organism": { "type": ["string", "null"] },
    "cell_context": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "cell_type_or_line_raw", "cell_line_cellosaurus_candidate",
        "tissue", "tissue_segment", "passage_or_state",
        "context_kind", "developmental_stage", "cell_state",
        "subcellular_fraction", "engineered_modifications",
        "co_culture_partners", "sort_markers", "cell_composition_estimates"
      ],
      "properties": {
        "cell_type_or_line_raw":           { "type": ["string", "null"] },
        "cell_line_cellosaurus_candidate": { "type": ["string", "null"] },
        "tissue":                          { "type": ["string", "null"] },
        "tissue_segment":                  { "type": ["string", "null"] },
        "passage_or_state":                { "type": ["string", "null"] },
        "context_kind": {
          "type": "string",
          "enum": [
            "cell_line_in_vitro", "primary_culture", "iPSC_derived",
            "organoid", "xenograft", "primary_tissue",
            "pdx_derived_cell_line", "co_culture",
            "tumor_extracted_cells", "unclear"
          ]
        },
        "developmental_stage": { "type": ["string", "null"] },
        "cell_state": {
          "type": ["string", "null"],
          "enum": [
            "proliferating", "senescent", "quiescent", "dormant",
            "activated", "anergic", "exhausted", "naive", "memory",
            "differentiated", "dedifferentiated", "undifferentiated",
            "transitional", "apoptotic", "stressed", "recovering",
            "unclear", "none", null
          ]
        },
        "subcellular_fraction": {
          "type": ["object", "null"],
          "additionalProperties": false,
          "required": ["kind", "raw"],
          "properties": {
            "kind": {
              "type": "string",
              "enum": [
                "ER", "nuclear", "cytoplasmic", "chromatin",
                "mitochondrial", "membrane", "polysome", "monosome",
                "ribosome_associated", "exosome", "total_rna", "other"
              ]
            },
            "raw": { "type": "string" }
          }
        },
        "engineered_modifications": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["kind", "label", "variant"],
            "properties": {
              "kind": {
                "type": "string",
                "enum": [
                  "germline_genotype", "crispr_stable",
                  "transgene_stable", "inducible_transgene",
                  "drug_adapted", "reporter_stable", "other"
                ]
              },
              "label": { "type": ["string", "null"] },
              "variant": {
                "type": ["object", "null"],
                "additionalProperties": false,
                "required": ["label", "description", "is_wildtype"],
                "properties": {
                  "label":        { "type": ["string", "null"] },
                  "description":  { "type": ["string", "null"] },
                  "is_wildtype":  { "type": "boolean" }
                }
              }
            }
          }
        },
        "co_culture_partners": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["cell_type", "source_organism", "modifications", "role"],
            "properties": {
              "cell_type":       { "type": "string" },
              "source_organism": { "type": ["string", "null"] },
              "modifications":   { "type": "array", "items": { "type": "string" } },
              "role": {
                "type": "string",
                "enum": ["feeder", "partner", "target", "stromal"]
              }
            }
          }
        },
        "sort_markers": {
          "type": "array",
          "items": { "type": "string" }
        },
        "cell_composition_estimates": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["marker", "proportion", "method"],
            "properties": {
              "marker":     { "type": "string" },
              "proportion": { "type": ["number", "null"], "minimum": 0, "maximum": 1 },
              "method":     { "type": ["string", "null"] }
            }
          }
        }
      }
    },
    "disease_state": {
      "type": "object",
      "additionalProperties": false,
      "required": ["term_raw", "mesh_id_candidate", "status"],
      "properties": {
        "term_raw":          { "type": ["string", "null"] },
        "mesh_id_candidate": { "type": ["string", "null"] },
        "status": {
          "type": "string",
          "enum": ["case", "comparison", "disease_model", "none"]
        }
      }
    },
    "perturbations": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "kind", "agent_raw", "agent_normalized",
          "dose", "duration", "phase", "temporal_order",
          "is_negative_control", "mediated_effect"
        ],
        "properties": {
          "kind": {
            "type": "string",
            "enum": [
              "small_molecule", "vehicle_only",
              "genetic_knockdown", "genetic_knockout",
              "genetic_overexpression",
              "crispra_activation", "crispri_repression",
              "cytokine_stimulation",
              "pathogen_or_aggregate_exposure",
              "environmental_or_behavioral",
              "differentiation",
              "mechanical_or_physical",
              "none", "unclear"
            ]
          },
          "agent_raw": { "type": ["string", "null"] },
          "agent_normalized": {
            "type": "object",
            "additionalProperties": false,
            "required": ["type", "id_database", "id", "preferred_name", "collection"],
            "properties": {
              "type": {
                "type": "string",
                "enum": [
                  "gene_or_protein", "small_molecule", "vehicle",
                  "disease_term", "genotype", "none", "other"
                ]
              },
              "id_database": {
                "type": ["string", "null"],
                "enum": [
                  "HGNC", "MGI", "UniProt", "DrugBank", "ChEMBL",
                  "CHEBI", "MeSH", "CAS", "Cellosaurus",
                  "Ensembl", "NCBITaxonomy", null
                ]
              },
              "id":             { "type": ["string", "null"] },
              "preferred_name": { "type": ["string", "null"] },
              "collection": {
                "type": ["object", "null"],
                "additionalProperties": false,
                "required": ["name", "id_in_collection"],
                "properties": {
                  "name":             { "type": "string" },
                  "id_in_collection": { "type": "string" }
                }
              }
            }
          },
          "dose": {
            "type": "object",
            "additionalProperties": false,
            "required": ["value_raw", "value_numeric", "unit"],
            "properties": {
              "value_raw":     { "type": ["string", "null"] },
              "value_numeric": { "type": ["number", "null"] },
              "unit":          { "type": ["string", "null"] }
            }
          },
          "duration": {
            "type": "object",
            "additionalProperties": false,
            "required": ["value_raw", "value_hours", "is_zero_timepoint"],
            "properties": {
              "value_raw":         { "type": ["string", "null"] },
              "value_hours":       { "type": ["number", "null"] },
              "is_zero_timepoint": { "type": "boolean" }
            }
          },
          "phase": {
            "type": ["string", "null"],
            "enum": ["exposure", "washout", "recovery", "persistence", "rebound", null]
          },
          "temporal_order":      { "type": ["integer", "null"], "minimum": 1 },
          "is_negative_control": { "type": "boolean" },
          "mediated_effect": {
            "type": ["object", "null"],
            "additionalProperties": false,
            "required": ["kind", "targets"],
            "properties": {
              "kind": {
                "type": "string",
                "enum": [
                  "genetic_overexpression", "genetic_knockdown",
                  "genetic_knockout", "crispra_activation",
                  "crispri_repression", "small_molecule", "other"
                ]
              },
              "targets": { "type": "array", "items": { "type": "string" } }
            }
          }
        }
      }
    },
    "technical_treatments": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["kind", "agent_raw"],
        "properties": {
          "kind": {
            "type": "string",
            "enum": [
              "culture_matrix", "culture_media",
              "electroporation_method", "rna_fractionation",
              "subcellular_isolation", "cell_synchronization",
              "chip_or_clip_setup", "batch_or_processing",
              "other_technical"
            ]
          },
          "agent_raw": { "type": ["string", "null"] }
        }
      }
    },
    "patient_metadata": {
      "type": ["object", "null"],
      "additionalProperties": false,
      "required": [
        "donor_id", "age", "sex", "ancestry_or_population",
        "ancestry_admixture", "clinical_response", "survival_group",
        "stage", "condition", "visit_or_timepoint"
      ],
      "properties": {
        "donor_id":              { "type": ["string", "null"] },
        "age":                   { "type": ["number", "null"] },
        "sex":                   { "type": ["string", "null"], "enum": ["M", "F", "other", null] },
        "ancestry_or_population":{ "type": ["string", "null"] },
        "ancestry_admixture":    { "type": ["number", "null"], "minimum": 0, "maximum": 1 },
        "clinical_response":     { "type": ["string", "null"] },
        "survival_group":        { "type": ["string", "null"] },
        "stage":                 { "type": ["string", "null"] },
        "condition":             { "type": ["string", "null"] },
        "visit_or_timepoint":    { "type": ["string", "null"] }
      }
    },
    "extraction": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version", "model", "confidence",
        "ambiguity_flags", "raw_input_hash"
      ],
      "properties": {
        "schema_version": { "type": "string", "const": "stage1.v3" },
        "model":          { "type": "string", "minLength": 1 },
        "confidence":     { "type": "number", "minimum": 0, "maximum": 1 },
        "ambiguity_flags": {
          "type": "array",
          "items": {
            "type": "string",
            "enum": [
              "missing_dose", "missing_duration", "time_zero_timepoint",
              "multi_factor_in_string", "compound_unmapped",
              "cell_line_ambiguous", "vehicle_only",
              "description_too_short", "mixed_organism_terms",
              "study_specific_jargon", "multiple_perturbations",
              "engineered_cell_line", "technical_treatment_only",
              "disease_state_present", "control_unspecified",
              "post_treatment_ambiguous", "protocol_only_no_perturbation",
              "metadata_inconsistency", "opaque_compound_code"
            ]
          }
        },
        "raw_input_hash": {
          "type": "string",
          "pattern": "^sha256:[0-9a-f]{64}$"
        }
      }
    }
  }
}
```

> Nota implementativa: alcuni JSON Schema engine non accettano `null` dentro `enum` quando il `type` è una union — Ajv (engine usato da `jsonvalidate`) lo accetta. La fixture VALID con `cell_state: null` validerà correttamente. Il test 2.7 lo verifica.

- [ ] **Step 2.7: Run tests, verifica che passano**

Run:
```bash
Rscript -e 'devtools::test(filter = "stage1-schema")'
```

Expected: 5/5 PASS. Se uno fallisce, leggere il messaggio di Ajv ed aggiustare lo schema (NON il test). I bug più probabili sono: dimenticare un campo in `required`, dimenticare `additionalProperties: false` su un sotto-oggetto.

- [ ] **Step 2.8: Verifica che `R CMD check` non si rompa con il nuovo file**

Run:
```bash
Rscript -e 'devtools::check(args = c("--no-manual", "--no-build-vignettes"))'
```

Expected: 0E/0W (note accettabili).

- [ ] **Step 2.9: Commit**

```bash
git add inst/schemas/sample_facts.stage1.v3.json \
        tests/testthat/fixtures/stage1-valid-vegf-huvec.json \
        tests/testthat/fixtures/stage1-invalid-bad-kind.json \
        tests/testthat/fixtures/stage1-invalid-missing-required.json \
        tests/testthat/test-stage1-schema.R
git commit -m "P2 Task 2: schema sample_facts.stage1.v3.json strict + fixture + 5 test"
```

---

## Task 3: Fixture mini di sample reali (8 sample dal xlsx)

**Files:**
- Crea: `inst/extdata/sample-fixtures-mini.tsv`
- Crea: `data-raw/build-sample-fixtures-mini.R`
- Modifica: `R/llm-stage1.R` (creazione, primo helper)
- Modifica: `tests/testthat/test-llm-stage1.R` (creazione, primo test)

> **Razionale:** i test e la vignette devono essere riproducibili senza il xlsx (ed eseguibili in CI dove il xlsx potrebbe non essere). Estraiamo 8 sample dal xlsx **una volta sola** in `data-raw/build-sample-fixtures-mini.R` e committiamo l'output TSV in `inst/extdata/`.

- [ ] **Step 3.1: Scrivi script di build `data-raw/build-sample-fixtures-mini.R`**

```r
# Script idempotente: estrae 8 sample stratificati dal xlsx come fixture
# stabili. Eseguito una sola volta (alla prima creazione del file); rieseguire
# solo se cambiano i criteri di selezione e si vuole riallineare.
#
# Selezione (8 sample):
#   - 2 EASY treated  (trtctr_EP=="treated"  & trtctr=="treated")
#   - 2 EASY control  (trtctr_EP=="control"  & trtctr=="control")
#   - 2 DISAGREE      (trtctr_EP != trtctr)  — qui sta il valore del classificatore LLM
#   - 2 SHORT/AMBIG   (nchar(string) <= 60)  — eval qualitativa di robustezza
#
# Seed = 20260502 (data del plan).

set.seed(20260502)
library(dplyr)
xlsx <- "data-raw/relevant_sample_classified.xlsx"
all <- readxl::read_excel(xlsx) |>
  dplyr::transmute(
    geo_accession = as.character(geo_accession),
    series_id     = as.character(series_id),
    string        = as.character(string),
    trtctr_EP     = as.character(trtctr_EP),
    trtctr        = as.character(trtctr),
    treat         = as.character(treat),
    gold          = as.character(gold)
  )

pick <- function(df, n) df[sample.int(nrow(df), n, replace = FALSE), , drop = FALSE]

easy_t  <- all |> filter(trtctr_EP == "treated", trtctr == "treated") |> pick(2)
easy_c  <- all |> filter(trtctr_EP == "control", trtctr == "control") |> pick(2)
disagr  <- all |> filter(trtctr_EP != trtctr) |> pick(2)
short_a <- all |> filter(nchar(string) <= 60) |> pick(2)

fix <- bind_rows(
  easy_t  |> mutate(stratum = "easy_treated"),
  easy_c  |> mutate(stratum = "easy_control"),
  disagr  |> mutate(stratum = "disagree_ep_vs_shallow"),
  short_a |> mutate(stratum = "short_ambiguous")
)

stopifnot(nrow(fix) == 8L, !any(duplicated(fix$geo_accession)))

readr::write_tsv(fix, "inst/extdata/sample-fixtures-mini.tsv")
```

- [ ] **Step 3.2: Esegui lo script e verifica l'output**

Run:
```bash
Rscript data-raw/build-sample-fixtures-mini.R
ls -la inst/extdata/sample-fixtures-mini.tsv
head -3 inst/extdata/sample-fixtures-mini.tsv
```

Expected: file creato, 9 righe (header + 8). Le colonne sono `geo_accession	series_id	string	trtctr_EP	trtctr	treat	gold	stratum`.

- [ ] **Step 3.3: Scrivi il test failing per `read_sample_fixtures_mini()`**

Aggiungi a `tests/testthat/test-llm-stage1.R` (file nuovo):

```r
test_that("read_sample_fixtures_mini ritorna tibble con 8 sample stratificati", {
  df <- read_sample_fixtures_mini()
  expect_s3_class(df, "tbl_df")
  expect_equal(nrow(df), 8L)
  expect_setequal(
    df$stratum,
    c("easy_treated", "easy_control",
      "disagree_ep_vs_shallow", "short_ambiguous")
  )
  expect_setequal(
    names(df),
    c("geo_accession", "series_id", "string",
      "trtctr_EP", "trtctr", "treat", "gold", "stratum")
  )
  expect_true(all(nzchar(df$geo_accession)))
  expect_true(all(nzchar(df$string)))
})
```

- [ ] **Step 3.4: Run test, verifica fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "llm-stage1")'
```

Expected: FAIL `could not find function "read_sample_fixtures_mini"`.

- [ ] **Step 3.5: Crea `R/llm-stage1.R` con il primo helper**

```r
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
```

- [ ] **Step 3.6: Run test, verifica pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "llm-stage1")'
```

Expected: 1/1 PASS.

- [ ] **Step 3.7: Commit**

```bash
git add data-raw/build-sample-fixtures-mini.R \
        inst/extdata/sample-fixtures-mini.tsv \
        R/llm-stage1.R \
        tests/testthat/test-llm-stage1.R
git commit -m "P2 Task 3: fixture mini 8 sample stratificati + read_sample_fixtures_mini()"
```

---

## Task 4: `build_prompt_stage1()` — costruisce messages OpenAI

**Files:**
- Modifica: `R/llm-stage1.R` (aggiunge funzione + costanti)
- Modifica: `tests/testthat/test-llm-stage1.R` (test)

> **Razionale del prompt:** Structured Outputs forza la conformità allo schema, ma il modello deve comunque scegliere bene gli **enum**. Il system prompt deve quindi: (a) spiegare il task; (b) elencare i vocabolari controllati con un esempio per ciascun valore poco ovvio; (c) dare 1 esempio few-shot completo (sample → output JSON valido); (d) ripetere le regole di copiatura verbatim per `geo_accession`/`series_id`. Il prompt è > 1024 token → soddisfa la soglia di automatic prompt caching di OpenAI (sconto sui token cachati).

- [ ] **Step 4.1: Scrivi i test failing**

Aggiungi a `tests/testthat/test-llm-stage1.R`:

```r
test_that("build_prompt_stage1 ritorna list di messages OpenAI-shape (system + user)", {
  msgs <- build_prompt_stage1(
    sample_string = "treatment: VEGF, time: 1h, cell line: HUVEC",
    geo_accession = "GSM1009636",
    series_id     = "GSE41166"
  )
  expect_type(msgs, "list")
  expect_length(msgs, 2L)
  expect_equal(msgs[[1]]$role, "system")
  expect_equal(msgs[[2]]$role, "user")
  expect_true(nchar(msgs[[1]]$content) > 1500L,
              info = "system prompt deve superare 1024 char per beneficiare di prompt caching")
})

test_that("build_prompt_stage1 inserisce geo_accession e series_id nello user message", {
  msgs <- build_prompt_stage1(
    sample_string = "siBCL6, OCI-LY1",
    geo_accession = "GSM999000",
    series_id     = "GSE777111"
  )
  user_content <- msgs[[2]]$content
  expect_match(user_content, "GSM999000", fixed = TRUE)
  expect_match(user_content, "GSE777111", fixed = TRUE)
  expect_match(user_content, "siBCL6, OCI-LY1", fixed = TRUE)
})

test_that("build_prompt_stage1 ricorda all'LLM di copiare verbatim geo_accession e series_id", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1"
  )
  sys_content <- msgs[[1]]$content
  expect_match(sys_content, "geo_accession", fixed = TRUE)
  expect_match(sys_content, "series_id", fixed = TRUE)
  expect_match(sys_content, "verbatim|copy|copia", ignore.case = TRUE)
})

test_that("build_prompt_stage1 cita gli enum di kind perturbation nel system prompt", {
  msgs <- build_prompt_stage1(sample_string = "x", geo_accession = "GSM1", series_id = "GSE1")
  sys <- msgs[[1]]$content
  for (k in c("small_molecule", "genetic_knockdown", "cytokine_stimulation",
              "differentiation", "none", "unclear")) {
    expect_match(sys, k, fixed = TRUE)
  }
})

test_that("build_prompt_stage1 con organism_hint non NULL lo passa allo user message", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
    organism_hint = "Homo sapiens"
  )
  expect_match(msgs[[2]]$content, "Homo sapiens", fixed = TRUE)
})
```

- [ ] **Step 4.2: Run, verifica fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "llm-stage1")'
```

Expected: 5 fail (build_prompt_stage1 non esiste).

- [ ] **Step 4.3: Aggiungi le costanti + funzione in `R/llm-stage1.R`**

Aggiungi sotto `read_sample_fixtures_mini()`:

```r
# Vocabolari controllati elencati nel system prompt (spec §3.1, §3.5, §3.6,
# §3.8, §3.9). Tenuti come stringhe esplicite per facilitare audit/diff
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
    "7. Leave `extraction.raw_input_hash` as 'sha256:0000000000000000000000000000000000000000000000000000000000000000' — the R caller will overwrite it deterministically.\n",
    "8. Leave `extraction.model` as the empty-meaningful default '__unset__' — the R caller will overwrite it.\n\n",
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
```

- [ ] **Step 4.4: Run test, verifica pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "llm-stage1")'
```

Expected: 6/6 PASS (1 read_sample_fixtures_mini + 5 build_prompt_stage1).

- [ ] **Step 4.5: Commit**

```bash
git add R/llm-stage1.R tests/testthat/test-llm-stage1.R
git commit -m "P2 Task 4: build_prompt_stage1() con vocab + few-shot + 5 test"
```

---

## Task 5: `parse_stage1_response()` + `classify_sample()` (orchestratore con mock)

**Files:**
- Modifica: `R/llm-stage1.R`
- Modifica: `tests/testthat/test-llm-stage1.R`
- Modifica: `NAMESPACE` (auto via roxygen)

> **Deviazione consapevole dalla spec §5.4 sulla cache key.** La spec prescrive `chiave = sha256(schema_version_stage1 + sample_string)`. P1 implementa invece `cache_key_for(version, payload)` dove `payload = JSON({provider, model, messages})`. Questo significa che la cache è partizionata anche per modello e per provider: un cache hit richiede stesso provider + stesso modello + stesso prompt + stesso sample_string. Conseguenze:
> 1. **Pro:** se l'utente cambia modello (gpt-5.5 → gpt-5.4-mini per il batch P3), non riusa per sbaglio risposte di un modello diverso — più safe.
> 2. **Pro:** se cambiamo il prompt (revisione del system message), la cache si invalida automaticamente — niente "stale prompt cache" silenziosa.
> 3. **Contro:** non possiamo riutilizzare risposte cross-modello come la spec immaginava.
>
> Per P2 questa deviazione è accettabile (dev set di 100 sample, costo trascurabile). Se P3 vorrà cache cross-modello, sarà un ADR separato; per ora il comportamento conservativo previene confusione.

- [ ] **Step 5.1: Scrivi i test failing per `parse_stage1_response()`**

Aggiungi a `tests/testthat/test-llm-stage1.R`:

```r
.fake_raw_v3 <- function() {
  jsonlite::fromJSON(
    readr::read_file(testthat::test_path("fixtures", "stage1-valid-vegf-huvec.json")),
    simplifyVector = FALSE
  )
}

test_that("parse_stage1_response forza geo_accession e series_id da input (anti-allucinazione)", {
  raw <- .fake_raw_v3()
  raw$geo_accession <- "GSM_HALLUCINATED"  # LLM ha allucinato
  raw$series_id     <- "GSE_HALLUCINATED"

  out <- parse_stage1_response(
    raw,
    sample_string = "treatment: VEGF, cell line: HUVEC",
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    model         = "gpt-5.5"
  )
  expect_equal(out$geo_accession, "GSM1009635")
  expect_equal(out$series_id,     "GSE41166")
})

test_that("parse_stage1_response calcola raw_input_hash deterministicamente", {
  raw <- .fake_raw_v3()
  s   <- "treatment: VEGF, cell line: HUVEC"
  out1 <- parse_stage1_response(raw, s, "GSM1", "GSE1", "gpt-5.5")
  out2 <- parse_stage1_response(raw, s, "GSM1", "GSE1", "gpt-5.5")
  expect_equal(out1$extraction$raw_input_hash, out2$extraction$raw_input_hash)
  expect_match(out1$extraction$raw_input_hash, "^sha256:[0-9a-f]{64}$")
})

test_that("parse_stage1_response setta extraction.model col valore richiesto", {
  raw <- .fake_raw_v3()
  out <- parse_stage1_response(raw, "x", "GSM1", "GSE1", model = "gpt-5.5")
  expect_equal(out$extraction$model, "openai:gpt-5.5")
})

test_that("parse_stage1_response setta schema_version a stage1.v3 anche se LLM lo lascia diverso", {
  raw <- .fake_raw_v3()
  raw$extraction$schema_version <- "wrong"
  out <- parse_stage1_response(raw, "x", "GSM1", "GSE1", "gpt-5.5")
  expect_equal(out$extraction$schema_version, "stage1.v3")
})
```

- [ ] **Step 5.2: Run, verifica fail**

Expected: 4 fail.

- [ ] **Step 5.3: Aggiungi `parse_stage1_response()` in `R/llm-stage1.R`**

```r
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
```

- [ ] **Step 5.4: Run, verifica pass dei 4 test parse**

Expected: 4/4 PASS.

- [ ] **Step 5.5: Scrivi i test failing per `classify_sample()`**

Aggiungi a `tests/testthat/test-llm-stage1.R`:

```r
test_that("classify_sample con provider mock ritorna sample_fact valido contro lo schema", {
  schema <- system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr")
  validator <- compile_schema(schema)

  fake <- .fake_raw_v3()
  fake_adapter <- function(model, messages, response_schema, ...) fake

  res <- classify_sample(
    sample_string = "treatment: VEGF, cell line: HUVEC, time: 0h",
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    provider      = "mock",
    model         = "gpt-5.5",
    cache         = NULL,
    .mock_adapter = fake_adapter
  )

  expect_true(res$validated)
  expect_equal(res$value$geo_accession, "GSM1009635")
  expect_equal(res$value$extraction$model, "openai:gpt-5.5")
  v <- validate_json(res$value, validator = validator)
  expect_true(v$valid, info = paste(v$errors, collapse = " | "))
})

test_that("classify_sample sfrutta la cache: 2a chiamata = hit, adapter NON richiamato", {
  cache <- cache_init(new_cache_dir(), namespace = "stage1")
  fake  <- .fake_raw_v3()
  call_count <- 0L
  fake_adapter <- function(...) { call_count <<- call_count + 1L; fake }

  args <- list(
    sample_string = "treatment: VEGF, cell line: HUVEC, time: 0h",
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    provider      = "mock",
    model         = "gpt-5.5",
    cache         = cache,
    .mock_adapter = fake_adapter
  )

  r1 <- do.call(classify_sample, args)
  expect_false(r1$cache_hit)
  expect_equal(call_count, 1L)

  r2 <- do.call(classify_sample, args)
  expect_true(r2$cache_hit)
  expect_equal(call_count, 1L)
})

test_that("classify_sample propaga simulomicsr_schema_error se LLM ritorna risposta non-conforme", {
  bad <- jsonlite::fromJSON(
    readr::read_file(testthat::test_path("fixtures", "stage1-invalid-bad-kind.json")),
    simplifyVector = FALSE
  )
  fake_adapter <- function(...) bad
  expect_error(
    classify_sample(
      sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
      provider = "mock", model = "gpt-5.5", cache = NULL,
      .mock_adapter = fake_adapter
    ),
    class = "simulomicsr_schema_error"
  )
})
```

- [ ] **Step 5.6: Run, verifica fail**

Expected: 3 fail (classify_sample non esiste).

- [ ] **Step 5.7: Aggiungi `classify_sample()` in `R/llm-stage1.R`**

```r
#' Classifica un sample RNAseq nello Stadio 1 (sample_facts schema v3)
#'
#' Orchestra: build_prompt_stage1 -> llm_call_structured (con cache + Structured
#' Outputs strict) -> parse_stage1_response (enrichment deterministico).
#'
#' @param sample_string stringa di metadati GEO concatenati (input)
#' @param geo_accession GSM id
#' @param series_id GSE id
#' @param provider `"openai"` (default) o `"mock"` (test)
#' @param model nome del modello (default `"gpt-5.5"` — spec §5.3.1 dev set)
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
```

- [ ] **Step 5.8: Rigenera roxygen (NAMESPACE)**

Run:
```bash
Rscript -e 'devtools::document()'
```

Expected: `NAMESPACE` aggiornato con `export(classify_sample)`.

- [ ] **Step 5.9: Run test, verifica pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "llm-stage1")'
```

Expected: 13/13 PASS (1 fixture + 5 prompt + 4 parse + 3 classify).

- [ ] **Step 5.10: Commit**

```bash
git add R/llm-stage1.R tests/testthat/test-llm-stage1.R NAMESPACE man/
git commit -m "P2 Task 5: parse_stage1_response + classify_sample() orchestratore + 7 test"
```

---

## Task 6: Smoke E2E reale (gated `OPENAI_API_KEY`)

**Files:**
- Crea: `tests/testthat/test-smoke-e2e-stage1.R`

> **Razionale:** validare end-to-end che `classify_sample()` funzioni davvero contro l'API OpenAI. Replica il pattern del test smoke P1 (`test-smoke-e2e.R`) — gated su API key, scrive cache temporanea, verifica cache hit.

- [ ] **Step 6.1: Crea il test**

```r
test_that("smoke E2E: classify_sample con gpt-5.5 produce sample_fact schema-valido (gated OPENAI_API_KEY)", {
  testthat::skip_if(!nzchar(Sys.getenv("OPENAI_API_KEY")),
                    "OPENAI_API_KEY non impostata")

  schema    <- system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr")
  validator <- compile_schema(schema)
  cache     <- cache_init(new_cache_dir(), namespace = "stage1")

  fix <- read_sample_fixtures_mini()
  row <- fix[fix$stratum == "easy_treated", , drop = FALSE][1, , drop = FALSE]

  res1 <- classify_sample(
    sample_string = row$string,
    geo_accession = row$geo_accession,
    series_id     = row$series_id,
    provider = "openai", model = "gpt-5.5",
    cache = cache
  )

  expect_true(res1$validated)
  expect_false(res1$cache_hit)
  expect_equal(res1$value$geo_accession, row$geo_accession)
  expect_equal(res1$value$series_id,     row$series_id)
  expect_equal(res1$value$extraction$schema_version, "stage1.v3")
  expect_match(res1$value$extraction$model, "^openai:gpt-5\\.5$")
  expect_match(res1$value$extraction$raw_input_hash, "^sha256:[0-9a-f]{64}$")

  v <- validate_json(res1$value, validator = validator)
  expect_true(v$valid, info = paste(v$errors, collapse = " | "))

  res2 <- classify_sample(
    sample_string = row$string,
    geo_accession = row$geo_accession,
    series_id     = row$series_id,
    provider = "openai", model = "gpt-5.5",
    cache = cache
  )
  expect_true(res2$cache_hit)
  expect_equal(res2$value, res1$value)
})
```

- [ ] **Step 6.2: Run con OPENAI_API_KEY impostata**

L'utente esegue (la API key vive in `.Renviron.local`, gitignored):

Run:
```bash
Rscript -e 'devtools::test(filter = "smoke-e2e-stage1")'
```

Expected: 1 PASS, 0 FAIL. Se la chiamata all'API fallisce con `simulomicsr_openai_truncated` o `simulomicsr_schema_error`, fermarsi e riportarlo all'utente: significa che il prompt o lo schema vanno raffinati prima di proseguire (questa è la prima vera validazione del prompt sul modello reale — accetta 1 ciclo di iterazione qui se il modello non rispetta lo schema).

- [ ] **Step 6.3: Run senza API key per verificare il gating**

Run (in shell senza `.Renviron.local` caricato):
```bash
unset OPENAI_API_KEY
Rscript -e 'devtools::test(filter = "smoke-e2e-stage1")'
```

Expected: 1 SKIP (`OPENAI_API_KEY non impostata`).

- [ ] **Step 6.4: Commit**

```bash
git add tests/testthat/test-smoke-e2e-stage1.R
git commit -m "P2 Task 6: smoke E2E stage1 contro gpt-5.5 (gated OPENAI_API_KEY)"
```

---

## Task 7: `read_samples_input()` + target `samples_input`

**Files:**
- Crea: `R/eval-sampling.R`
- Crea: `tests/testthat/test-eval-sampling.R`
- Modifica: `analysis/_targets.R`

- [ ] **Step 7.1: Scrivi il test failing**

Crea `tests/testthat/test-eval-sampling.R`:

```r
test_that("read_samples_input legge il xlsx e ritorna tibble con colonne required", {
  testthat::skip_if_not_installed("readxl")
  path <- testthat::test_path("..", "..", "data-raw", "relevant_sample_classified.xlsx")
  testthat::skip_if(!fs::file_exists(path),
                    "data-raw/relevant_sample_classified.xlsx non disponibile")

  df <- read_samples_input(path, n_max = 50L)
  expect_s3_class(df, "tbl_df")
  expect_lte(nrow(df), 50L)
  expect_gte(nrow(df), 1L)
  for (col in c("geo_accession", "series_id", "string",
                "trtctr_EP", "trtctr", "treat", "gold")) {
    expect_true(col %in% names(df), info = paste("colonna mancante:", col))
  }
  expect_true(is.character(df$geo_accession))
  expect_true(is.character(df$string))
})

test_that("read_samples_input fallisce con errore tipizzato se il file non esiste", {
  expect_error(
    read_samples_input("/path/che/non/esiste.xlsx"),
    class = "simulomicsr_eval_sampling_missing_file"
  )
})
```

- [ ] **Step 7.2: Run, verifica fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "eval-sampling")'
```

Expected: 2 fail.

- [ ] **Step 7.3: Crea `R/eval-sampling.R`**

```r
#' Legge il xlsx classificato in un tibble normalizzato
#'
#' Le colonne attese sono quelle documentate in `data-raw/README.md`.
#' Tutto viene letto come `character` (stabile), il caller converte se serve.
#'
#' @param path path al file xlsx
#' @param n_max numero massimo di righe da leggere (default `Inf`)
#' @return tibble con colonne `geo_accession`, `series_id`, `string`,
#'   `trtctr_EP`, `trtctr`, `treat`, `gold`
#' @keywords internal
read_samples_input <- function(path, n_max = Inf) {
  if (!fs::file_exists(path)) {
    rlang::abort(
      glue::glue("File non trovato: {path}"),
      class = "simulomicsr_eval_sampling_missing_file",
      path = path
    )
  }

  df <- readxl::read_excel(path, n_max = n_max)
  required <- c("geo_accession", "series_id", "string",
                "trtctr_EP", "trtctr", "treat", "gold")
  missing  <- setdiff(required, names(df))
  if (length(missing) > 0L) {
    rlang::abort(
      glue::glue("xlsx manca colonne attese: {paste(missing, collapse = ', ')}"),
      class = "simulomicsr_eval_sampling_bad_schema",
      missing = missing
    )
  }

  tibble::tibble(
    geo_accession = as.character(df$geo_accession),
    series_id     = as.character(df$series_id),
    string        = as.character(df$string),
    trtctr_EP     = as.character(df$trtctr_EP),
    trtctr        = as.character(df$trtctr),
    treat         = as.character(df$treat),
    gold          = as.character(df$gold)
  )
}
```

- [ ] **Step 7.4: Run, verifica pass**

Expected: 2/2 PASS.

- [ ] **Step 7.5: Aggiorna `analysis/_targets.R` con i primi target**

Sovrascrivi `analysis/_targets.R`:

```r
library(targets)
library(tarchetypes)

# Carica tutte le funzioni della libreria simulomicsr
list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE) |>
  lapply(source) |>
  invisible()

tar_option_set(
  packages = c("tibble", "dplyr", "readxl"),
  format   = "qs",
  error    = "continue",
  workspace_on_error = TRUE
)

list(
  # Path al xlsx come file-tracked target (re-trigger se il file cambia)
  tar_target(
    samples_input_path,
    here::here("data-raw", "relevant_sample_classified.xlsx"),
    format = "file"
  ),

  tar_target(
    samples_input,
    read_samples_input(samples_input_path)
  )
)
```

- [ ] **Step 7.6: Smoke test pipeline targets**

Run da R nella root:

```r
targets::tar_make(
  script = "analysis/_targets.R",
  store  = "analysis/_targets",
  reporter = "summary"
)
```

Expected: target `samples_input_path` e `samples_input` completati. Verifica:

```r
df <- targets::tar_read(samples_input,
                        store = "analysis/_targets")
nrow(df)   # ~130000
names(df)  # 7 colonne
```

- [ ] **Step 7.7: Commit**

```bash
git add R/eval-sampling.R tests/testthat/test-eval-sampling.R analysis/_targets.R
git commit -m "P2 Task 7: read_samples_input + target samples_input (con file-tracking)"
```

---

## Task 8: `build_dev_set()` stratificato 60/30/10 + target `samples_dev_set`

**Files:**
- Modifica: `R/eval-sampling.R`
- Modifica: `tests/testthat/test-eval-sampling.R`
- Modifica: `analysis/_targets.R`
- Crea: `data-raw/dev-set-sampling-decision.md`

> **Razionale (spec §6.1):** dev set di 100 sample stratificati: 60 facili (EP==shallow), 30 disagree (EP!=shallow), 10 short/ambigui (`nchar(string) <= 60`).

- [ ] **Step 8.1: Scrivi il test failing**

Aggiungi a `tests/testthat/test-eval-sampling.R`:

```r
test_that("build_dev_set produce 100 sample stratificati 60/30/10 con seed deterministico", {
  set.seed(NULL)
  df <- tibble::tibble(
    geo_accession = sprintf("GSM%05d", 1:5000),
    series_id     = sprintf("GSE%04d", rep(1:500, each = 10)),
    string        = c(
      rep("treatment: drugA, time: 24h", 3000),
      rep("treatment: drugB, time: 24h", 1500),
      rep("ctrl",                          500)  # short/ambigui (nchar <= 60)
    ),
    trtctr_EP = c(rep("treated", 3000), rep("control", 1500), rep("treated", 500)),
    trtctr    = c(rep("treated", 2500), rep("control", 1000),
                  rep("treated", 1000), rep("control",  500)),
    treat = NA_character_, gold = NA_character_
  )

  out1 <- build_dev_set(df, n = 100, seed = 1812)
  out2 <- build_dev_set(df, n = 100, seed = 1812)

  expect_equal(nrow(out1), 100L)
  expect_equal(out1$geo_accession, out2$geo_accession)  # deterministico
  expect_setequal(out1$stratum,
                  c("easy_agree", "disagree_ep_vs_shallow", "short_ambiguous"))

  counts <- table(out1$stratum)
  expect_equal(unname(counts["easy_agree"]),              60L)
  expect_equal(unname(counts["disagree_ep_vs_shallow"]),  30L)
  expect_equal(unname(counts["short_ambiguous"]),         10L)
})

test_that("build_dev_set seed diversi producono dev set diversi", {
  df <- tibble::tibble(
    geo_accession = sprintf("GSM%05d", 1:2000),
    series_id     = sprintf("GSE%04d", rep(1:200, each = 10)),
    string        = rep("treatment: x, time: 6h", 2000),
    trtctr_EP = rep(c("treated", "control"), each = 1000),
    trtctr    = rep(c("treated", "control"), times = 1000),
    treat = NA_character_, gold = NA_character_
  )
  a <- build_dev_set(df, n = 50, seed = 1)
  b <- build_dev_set(df, n = 50, seed = 2)
  expect_false(identical(a$geo_accession, b$geo_accession))
})
```

- [ ] **Step 8.2: Run, verifica fail**

Expected: 2 fail.

- [ ] **Step 8.3: Aggiungi `build_dev_set()` in `R/eval-sampling.R`**

```r
#' Costruisce un dev set stratificato per la valutazione iniziale dello Stadio 1
#'
#' Stratificazione (spec §6.1):
#' - 60% `easy_agree`: `trtctr_EP == trtctr` (baseline shallow d'accordo con
#'   gold manuale) — controlla regressioni
#' - 30% `disagree_ep_vs_shallow`: `trtctr_EP != trtctr` — qui sta il valore
#'   del classificatore LLM
#' - 10% `short_ambiguous`: `nchar(string) <= 60` — robustezza su input poveri
#'
#' Quando uno strato non ha abbastanza candidati, la funzione fallisce con
#' errore tipizzato (preferiamo failure esplicito a un dev set sbilanciato).
#'
#' @param samples tibble da `read_samples_input()`
#' @param n dimensione del dev set (default 100; ratio 60/30/10)
#' @param seed seed deterministico (default 1812)
#' @return tibble di `n` sample con colonna aggiuntiva `stratum`
#' @keywords internal
build_dev_set <- function(samples, n = 100L, seed = 1812L) {
  stopifnot(
    inherits(samples, "data.frame"),
    is.numeric(n), n > 0L,
    all(c("geo_accession", "string", "trtctr_EP", "trtctr") %in% names(samples))
  )

  n_easy  <- round(n * 0.60)
  n_disag <- round(n * 0.30)
  n_short <- n - n_easy - n_disag  # garantisce somma = n

  pool_easy  <- samples[samples$trtctr_EP == samples$trtctr, , drop = FALSE]
  pool_disag <- samples[samples$trtctr_EP != samples$trtctr, , drop = FALSE]
  pool_short <- samples[nchar(samples$string) <= 60L, , drop = FALSE]

  if (nrow(pool_easy)  < n_easy)  rlang::abort(
    glue::glue("Strato easy_agree insufficiente: {nrow(pool_easy)} < {n_easy}"),
    class = "simulomicsr_eval_sampling_thin_stratum", stratum = "easy_agree"
  )
  if (nrow(pool_disag) < n_disag) rlang::abort(
    glue::glue("Strato disagree_ep_vs_shallow insufficiente: {nrow(pool_disag)} < {n_disag}"),
    class = "simulomicsr_eval_sampling_thin_stratum", stratum = "disagree"
  )
  if (nrow(pool_short) < n_short) rlang::abort(
    glue::glue("Strato short_ambiguous insufficiente: {nrow(pool_short)} < {n_short}"),
    class = "simulomicsr_eval_sampling_thin_stratum", stratum = "short_ambiguous"
  )

  pick <- function(df, n, label) {
    idx <- withr::with_seed(seed + match(label, c("easy_agree","disagree","short_ambiguous")),
                            sample.int(nrow(df), n, replace = FALSE))
    df  <- df[idx, , drop = FALSE]
    df$stratum <- label
    df
  }

  out <- dplyr::bind_rows(
    pick(pool_easy,  n_easy,  "easy_agree"),
    pick(pool_disag, n_disag, "disagree_ep_vs_shallow"),
    pick(pool_short, n_short, "short_ambiguous")
  )
  tibble::as_tibble(out)
}
```

- [ ] **Step 8.4: Run, verifica pass**

Expected: 4/4 PASS (2 vecchi + 2 nuovi).

- [ ] **Step 8.5: Aggiungi target `samples_dev_set` in `analysis/_targets.R`**

Aggiungi alla lista dei target (dopo `samples_input`):

```r
  tar_target(
    samples_dev_set,
    build_dev_set(samples_input, n = 100L, seed = 1812L)
  ),
```

- [ ] **Step 8.6: Documenta la decisione in `data-raw/dev-set-sampling-decision.md`**

```markdown
# Dev set sampling — decisione operativa P2

**Data:** 2026-05-02 (Task 8 del plan P2).

## Strategia

Spec v5 §6.1 prescrive un eval set stratificato:
- 60% sample dove `trtctr_EP == trtctr` (baseline shallow d'accordo con gold manuale)
- 30% sample dove `trtctr_EP != trtctr`
- 10% sample con stringhe ambigue/corte (`nchar(string) <= 60`)

P2 implementa questo come **dev set di 100 sample** (60/30/10). Funzione:
`build_dev_set()` in `R/eval-sampling.R`, target `samples_dev_set` in
`analysis/_targets.R`.

## Riproducibilita'

- Seed default = 1812 (scelto dall'utente).
- Per ciascuno strato la funzione fa un `withr::with_seed(seed + offset)` con
  offset deterministico per strato (1/2/3) — così gli strati sono indipendenti
  e cambiare uno strato non muove gli altri.
- Il target `samples_dev_set` è invalidato automaticamente da `targets` se
  `samples_input` cambia, garantendo coerenza tra dev set e fonte.

## Espansione futura

- P3: passare a `n = 1000` per l'eval set vero (sempre 60/30/10, oppure
  ricalibrato sulle frequenze osservate).
- P3 mid-stage: introdurre il **gold design-aware** (spec §6.2), un secondo
  target `samples_gold_design_aware` che sostituisce/affianca questo dev set
  per la valutazione dello Stadio 2.
```

- [ ] **Step 8.7: Smoke pipeline**

Run da R:

```r
targets::tar_make(script = "analysis/_targets.R",
                  store  = "analysis/_targets",
                  reporter = "summary")
df <- targets::tar_read(samples_dev_set, store = "analysis/_targets")
nrow(df)            # 100
table(df$stratum)   # 60 / 30 / 10
```

Expected: 100 sample, conteggi 60/30/10. Se uno strato è insufficiente nel
xlsx reale, il target fallisce con `simulomicsr_eval_sampling_thin_stratum`
e occorre rivedere `n` (improbabile dato che il xlsx ha 130k righe).

- [ ] **Step 8.8: Commit**

```bash
git add R/eval-sampling.R tests/testthat/test-eval-sampling.R \
        analysis/_targets.R data-raw/dev-set-sampling-decision.md
git commit -m "P2 Task 8: build_dev_set 60/30/10 + target samples_dev_set"
```

---

## Task 9: Target `sample_facts_*` (dynamic branching su 100 sample)

**Files:**
- Modifica: `R/llm-stage1.R`
- Modifica: `analysis/_targets.R`
- Modifica: `tests/testthat/test-llm-stage1.R`

> **Razionale:** invocare `classify_sample()` su ogni riga del dev set, in parallelo, con cache su disco; partition dei risultati in `sample_facts_validated` vs `sample_facts_invalid`. P2 usa real-time API; il batch arriverà in P3.

- [ ] **Step 9.1: Scrivi test failing per `classify_sample_row()` (wrapper per dynamic branching)**

Aggiungi a `tests/testthat/test-llm-stage1.R`:

```r
test_that("classify_sample_row accetta una riga tibble e ritorna sample_fact valido", {
  fake <- .fake_raw_v3()
  fake_adapter <- function(...) fake

  row <- tibble::tibble(
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    string        = "treatment: VEGF, cell line: HUVEC, time: 0h",
    trtctr_EP     = "control",
    trtctr        = "control",
    treat         = NA_character_,
    gold          = NA_character_,
    stratum       = "easy_agree"
  )

  fact <- classify_sample_row(
    row,
    provider = "mock", model = "gpt-5.5", cache = NULL,
    .mock_adapter = fake_adapter
  )

  expect_type(fact, "list")
  expect_equal(fact$geo_accession, "GSM1009635")
  expect_equal(fact$extraction$schema_version, "stage1.v3")
})
```

- [ ] **Step 9.2: Run, verifica fail**

Expected: 1 fail.

- [ ] **Step 9.3: Aggiungi `classify_sample_row()` in `R/llm-stage1.R`**

```r
#' Wrapper per dynamic branching `targets`: prende una riga tibble e ritorna
#' direttamente il `sample_fact` (senza l'envelope di `classify_sample()`).
#'
#' Errori (`simulomicsr_schema_error`, `simulomicsr_openai_*`) sono catturati
#' e tradotti in un sample_fact "minimo invalido" con `extraction.confidence=0`
#' e `ambiguity_flags = ["metadata_inconsistency"]` — il filtro di validazione
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
```

- [ ] **Step 9.4: Run, verifica pass**

Expected: 14/14 PASS.

- [ ] **Step 9.5: Aggiungi target dinamici in `analysis/_targets.R`**

Aggiungi alla lista (dopo `samples_dev_set`):

```r
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
  # Compiliamo lo schema una sola volta in un target dedicato per evitare
  # ricompilazione a ogni branch.
  tar_target(
    sample_facts_validator,
    compile_schema(system.file(
      "schemas/sample_facts.stage1.v3.json", package = "simulomicsr"
    ))
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
      keep <- vapply(sample_facts_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(FALSE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        validate_json(f, validator = sample_facts_validator)$valid
      }, logical(1))
      sample_facts_raw[keep]
    }
  ),

  tar_target(
    sample_facts_invalid,
    {
      drop <- vapply(sample_facts_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(TRUE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        !validate_json(f, validator = sample_facts_validator)$valid
      }, logical(1))
      sample_facts_raw[drop]
    }
  )
```

- [ ] **Step 9.6: Smoke pipeline (DRY-RUN: 5 sample)**

Per evitare di spendere API call su 100 sample mentre si verifica la pipeline, modifica TEMPORANEAMENTE `samples_dev_set` a `n = 5L`, esegui, poi ripristina `n = 100L`.

```r
# In analysis/_targets.R modifica n = 5L (commit NON fatto per questo)
targets::tar_make(script = "analysis/_targets.R",
                  store  = "analysis/_targets",
                  reporter = "summary")
```

Expected: 5 chiamate `classify_sample_row` eseguite (visibili nei log), `sample_facts_raw` lista di 5 elementi, `sample_facts_validated` + `sample_facts_invalid` partition somma 5.

```r
length(targets::tar_read(sample_facts_raw, store = "analysis/_targets"))       # 5
length(targets::tar_read(sample_facts_validated, store = "analysis/_targets")) # <= 5
length(targets::tar_read(sample_facts_invalid,  store = "analysis/_targets"))  # >= 0
```

Ripristina `n = 100L` prima del commit. NON eseguire ancora il run completo: lo faremo in Task 10/11 dopo l'eval logic.

- [ ] **Step 9.7: Commit (con `n = 100L` ripristinato)**

```bash
git add R/llm-stage1.R analysis/_targets.R tests/testthat/test-llm-stage1.R
git commit -m "P2 Task 9: classify_sample_row + target sample_facts_raw/validated/invalid (dynamic branching)"
```

---

## Task 10: Eval metrics — `stage1_schema_validity_rate` + `stage1_recall_key_fields`

**Files:**
- Crea: `R/eval-metrics.R`
- Crea: `tests/testthat/test-eval-metrics.R`
- Modifica: `analysis/_targets.R`

- [ ] **Step 10.1: Scrivi test failing**

Crea `tests/testthat/test-eval-metrics.R`:

```r
.fact_with <- function(perturbation_kind = "small_molecule",
                      cell_type_or_line_raw = "MCF-7") {
  list(
    cell_context = list(cell_type_or_line_raw = cell_type_or_line_raw),
    perturbations = list(list(kind = perturbation_kind))
  )
}

test_that("stage1_schema_validity_rate ritorna n_valid / (n_valid + n_invalid)", {
  res <- stage1_schema_validity_rate(
    facts_validated = list(.fact_with(), .fact_with(), .fact_with(), .fact_with()),
    facts_invalid   = list(.fact_with())
  )
  expect_equal(res$n_validated, 4L)
  expect_equal(res$n_invalid,    1L)
  expect_equal(res$n_total,      5L)
  expect_equal(res$validity_rate, 0.8)
})

test_that("stage1_schema_validity_rate gestisce zero invalidi", {
  res <- stage1_schema_validity_rate(
    facts_validated = list(.fact_with()),
    facts_invalid   = list()
  )
  expect_equal(res$validity_rate, 1.0)
})

test_that("stage1_schema_validity_rate fallisce su zero totali", {
  expect_error(
    stage1_schema_validity_rate(facts_validated = list(),
                                 facts_invalid   = list()),
    class = "simulomicsr_eval_metrics_empty"
  )
})

test_that("stage1_recall_key_fields conta sample con perturbations.kind != none/unclear/null e cell_type non null", {
  facts <- list(
    .fact_with(perturbation_kind = "small_molecule"),
    .fact_with(perturbation_kind = "none"),
    .fact_with(perturbation_kind = "unclear"),
    .fact_with(perturbation_kind = "cytokine_stimulation",
               cell_type_or_line_raw = NULL)
  )
  res <- stage1_recall_key_fields(facts)
  expect_equal(res$n_samples, 4L)
  expect_equal(res$n_with_perturbation,    2L)  # small_molecule, cytokine_stim
  expect_equal(res$n_with_cell_type,       3L)  # solo l'ultimo ha NULL
  expect_equal(res$recall_perturbation, 0.5)
  expect_equal(res$recall_cell_type,    0.75)
})
```

- [ ] **Step 10.2: Run, verifica fail**

Expected: 4 fail.

- [ ] **Step 10.3: Crea `R/eval-metrics.R`**

```r
#' Metriche di base dello Stadio 1 sul dev set
#'
#' Tutte le funzioni accettano una lista di `sample_fact` (oggetti R parsed
#' dal JSON) e ritornano una lista flat di numeri/conteggi adatta a essere
#' impacchettata in tibble per il report.

#' Rate di sample_facts che superano la validazione schema
#'
#' @param facts_validated lista di sample_fact validati
#' @param facts_invalid lista di sample_fact invalidati (post catch in
#'   `classify_sample_row`)
#' @return list(n_validated, n_invalid, n_total, validity_rate)
#' @keywords internal
stage1_schema_validity_rate <- function(facts_validated, facts_invalid) {
  n_v <- length(facts_validated)
  n_i <- length(facts_invalid)
  n_t <- n_v + n_i
  if (n_t == 0L) {
    rlang::abort(
      "Eval metrics su zero sample: dev set vuoto.",
      class = "simulomicsr_eval_metrics_empty"
    )
  }
  list(
    n_validated   = as.integer(n_v),
    n_invalid     = as.integer(n_i),
    n_total       = as.integer(n_t),
    validity_rate = n_v / n_t
  )
}

#' Recall di campi chiave nei sample_fact validati
#'
#' - "with_perturbation" = `perturbations[1].kind` non in {none, unclear, NA}
#' - "with_cell_type"    = `cell_context.cell_type_or_line_raw` non NULL
#'
#' @param facts_validated lista di sample_fact validati
#' @return list(n_samples, n_with_perturbation, n_with_cell_type,
#'   recall_perturbation, recall_cell_type)
#' @keywords internal
stage1_recall_key_fields <- function(facts_validated) {
  n <- length(facts_validated)
  if (n == 0L) {
    return(list(
      n_samples = 0L, n_with_perturbation = 0L, n_with_cell_type = 0L,
      recall_perturbation = NA_real_, recall_cell_type = NA_real_
    ))
  }

  has_perturbation <- vapply(facts_validated, function(f) {
    p <- f$perturbations
    if (length(p) == 0L) return(FALSE)
    k <- p[[1]]$kind
    !is.null(k) && !(k %in% c("none", "unclear"))
  }, logical(1))

  has_cell_type <- vapply(facts_validated, function(f) {
    ct <- f$cell_context$cell_type_or_line_raw
    !is.null(ct) && nzchar(ct)
  }, logical(1))

  list(
    n_samples            = as.integer(n),
    n_with_perturbation  = as.integer(sum(has_perturbation)),
    n_with_cell_type     = as.integer(sum(has_cell_type)),
    recall_perturbation  = mean(has_perturbation),
    recall_cell_type     = mean(has_cell_type)
  )
}
```

- [ ] **Step 10.4: Run, verifica pass**

Expected: 4/4 PASS.

- [ ] **Step 10.5: Aggiungi target `eval_stage1_metrics`**

Aggiungi alla lista in `analysis/_targets.R`:

```r
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
  )
```

- [ ] **Step 10.6: Commit (senza ancora invocare l'API reale)**

```bash
git add R/eval-metrics.R tests/testthat/test-eval-metrics.R analysis/_targets.R
git commit -m "P2 Task 10: stage1_schema_validity_rate + recall_key_fields + target eval_stage1_metrics"
```

---

## Task 11: Eval report (RMarkdown via `tar_render`)

**Files:**
- Crea: `analysis/eval/stage1-eval.Rmd`
- Modifica: `analysis/_targets.R` (aggiunge `tar_render`)
- Modifica: `analysis/_targets_packages.R` (aggiunge `rmarkdown`)
- Modifica: `.gitignore` (ignora `analysis/eval/_files/`)

- [ ] **Step 11.1: Crea `analysis/eval/stage1-eval.Rmd`**

```rmarkdown
---
title: "Stage 1 — Eval su dev set"
output: html_document
params:
  metrics: !r NULL
  validated: !r NULL
  invalid: !r NULL
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = FALSE)
library(dplyr)
library(tibble)
library(knitr)
# %||% non e' esportato dal pacchetto: lo ridefiniamo in scope locale
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
metrics    <- params$metrics
validated  <- params$validated
invalid    <- params$invalid
```

# Sintesi numerica

```{r}
metrics |>
  tidyr::pivot_longer(everything(), names_to = "metric", values_to = "value") |>
  knitr::kable(digits = 3)
```

# Sample invalidati (motivo)

```{r}
if (length(invalid) == 0L) {
  cat("_Nessun sample invalidato._")
} else {
  tibble(
    geo_accession = vapply(invalid, function(f) f$geo_accession %||% NA_character_, character(1)),
    series_id     = vapply(invalid, function(f) f$series_id     %||% NA_character_, character(1)),
    reason        = vapply(invalid, function(f) f$.invalid_reason %||% NA_character_, character(1)),
    detail        = vapply(invalid, function(f) f$.invalid_detail %||% NA_character_, character(1))
  ) |>
    head(50) |>
    knitr::kable()
}
```

# Distribuzione `perturbations[1].kind` nei validati

```{r}
kinds <- vapply(validated, function(f) {
  p <- f$perturbations
  if (length(p) == 0L) return("(none-array)")
  p[[1]]$kind %||% "(null)"
}, character(1))

tibble(kind = kinds) |>
  count(kind, sort = TRUE) |>
  knitr::kable()
```

# Distribuzione `cell_context.context_kind` nei validati

```{r}
ctx <- vapply(validated, function(f) f$cell_context$context_kind %||% "(null)",
              character(1))
tibble(context_kind = ctx) |>
  count(context_kind, sort = TRUE) |>
  knitr::kable()
```

# Confidence calibration (placeholder testuale)

```{r}
conf <- vapply(validated, function(f) f$extraction$confidence %||% NA_real_,
               numeric(1))
summary(conf)
```
```

(Il file `.Rmd` ha tre back-tick a fine codice — quando lo scrivi assicurati che siano presenti per chiudere correttamente l'ultimo blocco.)

- [ ] **Step 11.2: Aggiungi `tar_render` in `analysis/_targets.R`**

Aggiungi alla lista (dopo `eval_stage1_metrics`):

```r
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
```

- [ ] **Step 11.3: Verifica `_targets_packages.R`**

`tidyr` e `rmarkdown` sono già in `library(...)` dal Task 1 (Step 1.4) e già installati in renv (Step 1.5/1.6). Nessuna azione qui — solo verifica:

```bash
grep -E '^library\(tidyr\)|^library\(rmarkdown\)' analysis/_targets_packages.R
```

Expected: entrambi presenti. Se manca uno, tornare al Task 1 — non patch-and-go qui.

- [ ] **Step 11.4: `.gitignore` per gli artefatti dell'eval**

Aggiungi al `.gitignore` (root o `analysis/.gitignore`):

```
analysis/eval/_files/
analysis/eval/stage1-eval_files/
analysis/eval/stage1-eval.html
analysis/cache/
```

- [ ] **Step 11.5: Smoke con dev set ridotto (5 sample, mock)**

NON ancora chiamare l'API reale: invece, esegui il pipeline DRY contro la cache se gia' popolata, altrimenti lascia il run completo allo step 11.6.

- [ ] **Step 11.6: Run vero su 100 sample con OPENAI_API_KEY (questo e' il punto in cui si spendono token)**

> **Stop di review utente:** prima di lanciare i 100 sample, l'utente conferma. Costo stimato (gpt-5.5, 100 sample, ~2500 token system + ~200 token user + ~600 token output): ~$0.5-2.0 totali. Trascurabile rispetto al budget di $500.

```bash
Rscript -e 'targets::tar_make(script="analysis/_targets.R", store="analysis/_targets", reporter="summary")'
```

Expected: 100 chiamate `classify_sample_row` (visibili nei log), report HTML in `analysis/eval/stage1-eval.html`. Verifica:

```r
m <- targets::tar_read(eval_stage1_metrics, store = "analysis/_targets")
m$validity_rate          # atteso > 0.95 con Structured Outputs strict
m$recall_perturbation    # atteso > 0.7 con dev set 60/30/10
m$recall_cell_type       # atteso > 0.85
```

Soglie d'allarme: se `validity_rate < 0.95` qualcosa non va con lo schema o il provider strict. Se `recall_*` molto bassi rispetto alle attese, rivedere il prompt prima di Task 12.

- [ ] **Step 11.7: Commit**

```bash
git add analysis/eval/stage1-eval.Rmd analysis/_targets.R .gitignore
git commit -m "P2 Task 11: eval_stage1_report (tar_render Rmd) + run su 100 sample"
```

Nota: gli artefatti di output (HTML, eval/_files/, cache/) restano gitignored — non vanno nel commit.

---

## Task 12: Vignette `stage1-classify.Rmd`

**Files:**
- Crea: `vignettes/stage1-classify.Rmd`

- [ ] **Step 12.1: Crea la vignette**

```rmarkdown
---
title: "Classificare un sample RNAseq con `classify_sample()` (Stadio 1)"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Classificare un sample RNAseq con classify_sample() (Stadio 1)}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(simulomicsr)
```

## Cos'e' lo Stadio 1?

Lo Stadio 1 della pipeline `simulomicsr` trasforma la stringa testuale di metadati di un sample RNAseq da GEO in un **record JSON strutturato** (`sample_facts.stage1.v3`). Il record cattura:

- chi e' il sample (tipo cellulare, tessuto, organismo, contesto sperimentale);
- cosa e' stato fatto al sample (perturbazioni: drug, knockdown, citochine, eccetera);
- cosa NON e' ricavabile dalla stringa (campi `null`, flag di ambiguita').

Lo Stadio 1 NON decide treated vs control — quella decisione vive nello Stadio 2 (per studio).

## Esempio: 1 sample dalla fixture mini

```{r}
# Fixture stabile bundled nel pacchetto (8 sample dal xlsx)
fix <- simulomicsr:::read_sample_fixtures_mini()
row <- fix[fix$stratum == "easy_treated", , drop = FALSE][1, ]
str(as.list(row))
```

## Classificazione con provider mock (no API call)

A scopo dimostrativo, usiamo `provider = "mock"` con una risposta finta gia' valida:

```{r}
fake_response <- jsonlite::fromJSON(
  readr::read_file(system.file(
    "schemas/sample_facts.stage1.v3.json", package = "simulomicsr"
  )),
  simplifyVector = FALSE
)
# (in un caso reale, useremmo provider="openai" — vedi sotto)
```

```{r eval=FALSE}
# Esempio reale (richiede OPENAI_API_KEY in .Renviron.local)
res <- classify_sample(
  sample_string = row$string,
  geo_accession = row$geo_accession,
  series_id     = row$series_id,
  provider = "openai",
  model    = "gpt-5.5"
)
str(res$value, max.level = 2)
```

## Cache su disco

Per evitare di pagare due volte la stessa chiamata, passare un oggetto `cache`:

```{r eval=FALSE}
cache <- cache_init(tempfile(), namespace = "stage1")

r1 <- classify_sample(
  sample_string = row$string,
  geo_accession = row$geo_accession,
  series_id     = row$series_id,
  cache         = cache
)
r1$cache_hit  # FALSE — prima chiamata

r2 <- classify_sample(
  sample_string = row$string,
  geo_accession = row$geo_accession,
  series_id     = row$series_id,
  cache         = cache
)
r2$cache_hit  # TRUE — risposta servita dalla cache
```

## Schema di output

Lo schema completo e' in `inst/schemas/sample_facts.stage1.v3.json`. La spec del design vive in `docs/superpowers/specs/2026-04-29-classificatore-llm-design.md` §3.

## Quando lo Stadio 1 NON basta

Lo Stadio 1 non sa:
- Quali sample sono replicate biologiche dello stesso gruppo (e' Stadio 2).
- Qual e' il "control" del confronto (e' Stadio 2).
- Se una lente di trattamento e' veicolo (DMSO/PBS) o farmaco attivo (Stadio 1 lo flagga come `vehicle_only` o `small_molecule`, ma il ruolo nel design e' Stadio 2).
```

(Tre back-tick a fine codice come sopra: assicurati che chiudano l'ultimo blocco.)

- [ ] **Step 12.2: Build vignette**

Run:
```bash
Rscript -e 'devtools::build_vignettes()'
```

Expected: vignette HTML costruita senza errori.

- [ ] **Step 12.3: Commit**

```bash
git add vignettes/stage1-classify.Rmd
git commit -m "P2 Task 12: vignette stage1-classify (esempio + cache + schema)"
```

---

## Task 13: NEWS + R CMD check + merge a master + tag

**Files:**
- Modifica: `NEWS.md`
- Modifica: `DESCRIPTION` (bump version)

- [ ] **Step 13.1: Bump versione in `DESCRIPTION`**

Cambia `Version: 0.0.0.9002` -> `Version: 0.0.0.9003`.

- [ ] **Step 13.2: Aggiungi entry in `NEWS.md`**

In cima al file (sotto eventuale frontmatter):

```markdown
# simulomicsr 0.0.0.9003

* P2 — Stadio 1 sample_facts:
  * Schema `inst/schemas/sample_facts.stage1.v3.json` strict-friendly per
    OpenAI Structured Outputs (spec v5 §3, vocabolari §3.1-§3.12).
  * `classify_sample()` orchestratore (export pubblico) sopra
    `llm_call_structured()` con cache, prompt v1, enrichment deterministico.
  * `build_dev_set()` stratificato 60/30/10 (spec v5 §6.1).
  * Pipeline `analysis/_targets.R`: `samples_input` -> `samples_dev_set` ->
    `sample_facts_validated/invalid` (dynamic branching) -> `eval_stage1_metrics`
    -> `eval_stage1_report` (HTML).
  * Eval iniziale su 100 sample con `gpt-5.5`: schema validity rate +
    recall di campi chiave (`perturbations[1].kind`, `cell_context.cell_type_or_line_raw`).
  * Vignette `stage1-classify.Rmd`.
```

- [ ] **Step 13.3: R CMD check completo**

Run:
```bash
Rscript -e 'devtools::check(args = c("--no-manual"))'
```

Expected: 0E/0W; le note tollerate sono solo quelle gia' presenti in P1 (vedi `NOTE` di P1 nei log del tag `p1-infra-llm-complete`).

- [ ] **Step 13.4: Test suite completa**

Run:
```bash
Rscript -e 'devtools::test()'
```

Expected: tutti i test passano (P1 + P2). Conta attesa: ~80 (P1) + ~25 (P2) = ~105 expectations.

- [ ] **Step 13.5: Merge fast-forward su master**

```bash
git checkout master
git merge --ff-only p2-stage1
git tag p2-stage1-complete
```

Expected: merge fast-forward ok, tag creato.

- [ ] **Step 13.6: Verifica tag e commit**

```bash
git log --oneline -15
git tag --list 'p2-*'
```

Expected: 13 commit P2 visibili, tag `p2-stage1-complete` presente.

- [ ] **Step 13.7: NON fare push**

Non eseguire `git push`. L'utente fa il push lui (memory: "Master locale è 29 commit ahead di origin/master — l'utente farà push lui (mai fatto io)").

- [ ] **Step 13.8: Commit conclusivo (NEWS + DESCRIPTION)**

(Il bump version e NEWS sono in commit dedicato per pulizia git history.)

```bash
git add DESCRIPTION NEWS.md
git commit -m "P2 Task 13: bump 0.0.0.9003 + NEWS aggiornati"
git tag -f p2-stage1-complete  # sposta il tag al commit finale
```

---

## Stop di review utente

Tre checkpoint impliciti dove la sessione si ferma per review:

1. **Dopo Task 6** (smoke E2E): se la chiamata reale fallisce, fermarsi e raffinare il prompt. Non procedere a Task 7+ con un prompt rotto.
2. **Dopo Task 8** (dev set): l'utente verifica che la composizione del dev set 60/30/10 abbia senso operativo (stratum proportions in `targets::tar_read(samples_dev_set)`).
3. **Prima di Task 11.6** (run vero su 100 sample): l'utente conferma il costo stimato (~$0.5-2.0) e l'invocazione effettiva dell'API.
