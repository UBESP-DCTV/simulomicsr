# Name-cleanup Mistral (scope A) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ripulire le etichette dei cluster omogenei ma mal-nominati (LPS→"carnitine", …) via Mistral self-hosted + risoluzione ontologica deterministica, producendo una side-table di relabel sul pooled v8 (scope A, nessun re-pool) e la misura di frammentazione per decidere scope B.

**Architecture:** Nuovo adapter R `llm-client-vllm` instradato in `llm_call_structured` (cache R, namespace `nameclean.v1`) verso l'endpoint Mistral self-hosted. Modulo puro `R/name-cleanup.R`: pre-clean markup → carica candidati dal triage → costruisce metadati membri → prompt → chiamata LLM → **risoluzione deterministica nome→ID** (accessor ontologici) → **policy override precision-gated** → side-table. Uno script d'analisi gated orchestra gold+smoke poi il run sui 125.

**Tech Stack:** R (testthat, httr2, jsonlite, arrow, cli, digest), ontologie ChEBI/MeSH/HGNC/taxonomy già in `R/ontology-lookup.R`, Mistral-Small-3.2 self-hosted via endpoint vLLM OpenAI-compatible.

## Global Constraints

- **Precision gate (D2):** Mistral propone SOLO `canonical_name`; l'ID è risolto deterministicamente dagli accessor pipeline; Mistral non è MAI autorità sull'ID.
- **Scope A (D1):** relabel post-hoc, NESSUN re-pool. La misura di frammentazione è sottoprodotto per decidere B; B è fuori da questo piano.
- **Config Mistral uniforme:** `temperature=0`, `repetition_penalty=1.1`, stesso modello `mistralai/Mistral-Small-3.2-24B-Instruct-2506`; cache keyed `cache_namespace_version="nameclean.v1"`.
- **Comandi R su questa macchina:** `Rscript -e ...` **SENZA** `--vanilla` (devtools nel renv cache). Vale anche per gli script.
- **Convenzioni codice:** italiano in commenti/docstring/messaggi; funzioni interne `@keywords internal`/`@noRd`; accessor defensivi (NULL/NA/character(0)); TDD bite-sized + commit atomici `P5 audit RED_ALERT F6: <azione>`.
- **Suite di riferimento:** `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-<x>.R")'`. NON toccare i 2 FAIL pre-esistenti (`test-stage4-dashboard.R` quarto CLI + `test-stage4-gene-axis.R:313`).
- **Gate run (validate-before-fullrun):** i Task 10-11 (gold/smoke poi run sui 125) sono GATE UTENTE separati; l'endpoint vLLM va raggiunto via SSH port-forward verso la DGX.

---

### Task 1: Adapter vLLM cachato + dispatcher

**Files:**
- Create: `R/llm-client-vllm.R`
- Modify: `R/llm-client.R:72-86` (aggiungere il ramo `provider == "vllm"` nel dispatcher)
- Test: `tests/testthat/test-llm-client-vllm.R`

**Interfaces:**
- Consumes: `compile_schema()`, `validate_json()` (già in pacchetto), `httr2`.
- Produces: `.vllm_chat_structured(model, messages, response_schema, schema_name = "response", temperature = 0, max_tokens = 256L, repetition_penalty = 1.1, base_url = NULL, api_key = NULL, timeout = 60L, ...)` → `list(content_json = <parsed list>, raw = <chr>)`. Dispatcher: `llm_call_structured(provider = "vllm", model, messages, response_schema, cache, cache_namespace_version, ...)` ritorna la stessa shape degli altri provider (`list(value, provider, model, validated, cache_hit, raw_response)`).

- [ ] **Step 1: Write the failing test** (mock httr2 perform, no network)

```r
# tests/testthat/test-llm-client-vllm.R
test_that(".vllm_chat_structured posta il body giusto e parsa il content", {
  captured <- NULL
  fake_perform <- function(req) {
    captured <<- req
    structure(list(), class = "httr2_response")
  }
  fake_body <- function(resp, simplifyVector = FALSE) {
    list(choices = list(list(message = list(
      content = '{"canonical_name":"lipopolysaccharide","kind":"pathogen_or_aggregate_exposure","confidence":"high","evidence":"lps in characteristics"}'))))
  }
  msgs <- list(list(role = "system", content = "sys"),
               list(role = "user", content = "usr"))
  out <- testthat::with_mocked_bindings(
    .vllm_chat_structured(model = "m", messages = msgs,
                          response_schema = NULL, base_url = "http://x/v1/chat/completions",
                          api_key = "k"),
    req_perform = fake_perform,
    resp_body_json = fake_body,
    .package = "httr2"
  )
  expect_equal(out$content_json$canonical_name, "lipopolysaccharide")
  # il body deve includere temperature=0 e repetition_penalty=1.1
  body_txt <- rawToChar(captured$body$data)
  expect_match(body_txt, '"temperature":0')
  expect_match(body_txt, '"repetition_penalty":1.1')
})

test_that("llm_call_structured instrada provider vllm", {
  msgs <- list(list(role = "user", content = "x"))
  res <- llm_call_structured(
    provider = "vllm", model = "m", messages = msgs, response_schema = NULL,
    .mock_response = list(canonical_name = "aspirin", kind = "small_molecule",
                          confidence = "high", evidence = "e"))
  expect_equal(res$provider, "vllm")
  expect_equal(res$value$canonical_name, "aspirin")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-llm-client-vllm.R")'`
Expected: FAIL — `.vllm_chat_structured` non esiste / provider `vllm` non gestito.

- [ ] **Step 3: Write minimal implementation**

```r
# R/llm-client-vllm.R
#' Client structured-output verso l'endpoint Mistral self-hosted (vLLM OpenAI-compatible).
#'
#' Riusa il pattern httr2 di `analysis/audit/name-recovery-llm-benchmark.R` ma come
#' adapter di pacchetto, cosi' passa per la cache di `llm_call_structured`. Lo schema
#' e' iniettato via `response_format=json_object` + validazione client-side (lo strict
#' StructuredOutputsParams del path DGX non serve: il precision gate risolve l'ID a valle).
#'
#' @keywords internal
#' @noRd
.vllm_chat_structured <- function(model, messages, response_schema,
                                  schema_name = "response",
                                  temperature = 0, max_tokens = 256L,
                                  repetition_penalty = 1.1,
                                  base_url = NULL, api_key = NULL,
                                  timeout = 60L, ...) {
  base_url <- base_url %||% Sys.getenv("VLLM_BASE_URL",
                                       "http://localhost:8000/v1/chat/completions")
  api_key  <- api_key  %||% Sys.getenv("VLLM_API_KEY", "EMPTY")
  body <- list(model = model, messages = messages,
               response_format = list(type = "json_object"),
               temperature = temperature, max_tokens = max_tokens,
               repetition_penalty = repetition_penalty)
  req <- httr2::request(base_url) |>
    httr2::req_method("POST") |>
    httr2::req_headers(Authorization = paste("Bearer", api_key),
                       `Content-Type` = "application/json") |>
    httr2::req_body_raw(
      charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")),
      type = "application/json") |>
    httr2::req_timeout(seconds = timeout) |>
    httr2::req_retry(max_tries = 2L, backoff = function(i) 5)
  resp <- httr2::req_perform(req)
  content <- httr2::resp_body_json(resp, simplifyVector = FALSE)$choices[[1L]]$message$content
  list(content_json = jsonlite::fromJSON(content, simplifyVector = FALSE),
       raw = content)
}
```

Poi nel dispatcher `R/llm-client.R`, dopo il ramo `openrouter` (intorno a `:72-86`), aggiungere:

```r
    vllm = {
      if (!is.null(.mock_response)) {
        list(content_json = .mock_response, raw = jsonlite::toJSON(.mock_response, auto_unbox = TRUE))
      } else {
        .vllm_chat_structured(model = model, messages = messages,
                              response_schema = response_schema, ...)
      }
    },
```

e assicurarsi che il valore ritornato al chiamante sia `list(value = adapter_out$content_json, provider = provider, model = model, validated = <bool>, cache_hit = <bool>, raw_response = adapter_out$raw)` (stessa costruzione degli altri rami; se `response_schema` non-NULL, `validate_json()` come per gli altri provider, altrimenti `validated = NA`).

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-llm-client-vllm.R")'`
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add R/llm-client-vllm.R R/llm-client.R tests/testthat/test-llm-client-vllm.R
git commit -m "P5 audit RED_ALERT F6: adapter vLLM cachato per llm_call_structured"
```

---

### Task 2: Pre-clean markup deterministico

**Files:**
- Create: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-markup.R`

**Interfaces:**
- Produces: `.strip_name_markup(x)` → character(1). Rimuove tag HTML (`<i>`,`<em>`,`<sub>`,`<sup>`,`<small>`,…), entità (`&alpha;`, `&#946;`), e trim. Defensivo su NA/character(0)/multi (usa `.normalize_key_chr` per la guardia).

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-name-cleanup-markup.R
test_that(".strip_name_markup rimuove tag e entita' preservando il nome", {
  expect_equal(.strip_name_markup("(<i>S</i>)-laudanosine(1+)"), "(S)-laudanosine(1+)")
  expect_equal(.strip_name_markup("17&beta;-estradiol"), "17β-estradiol")
  expect_equal(.strip_name_markup("2-hydroxy-6-oxohexa-2,4-dienoic acid"),
               "2-hydroxy-6-oxohexa-2,4-dienoic acid")
  expect_equal(.strip_name_markup(NA_character_), NA_character_)
  expect_equal(.strip_name_markup(character(0)), NA_character_)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-markup.R")'`
Expected: FAIL — `.strip_name_markup` non esiste.

- [ ] **Step 3: Write minimal implementation**

```r
# R/name-cleanup.R  (inizio file)
# Pulizia-nomi (scope A): relabel della coda mal-etichettata via Mistral +
# risoluzione ontologica deterministica. Vedi
# docs/superpowers/specs/2026-07-06-name-cleanup-mistral-design.md.

.NAME_CLEANUP_CACHE_VERSION <- "nameclean.v1"

# Entità HTML comuni nei nomi ChEBI -> unicode.
.NAME_MARKUP_ENTITIES <- c(
  "&alpha;" = "α", "&beta;" = "β", "&gamma;" = "γ", "&delta;" = "δ",
  "&#945;" = "α", "&#946;" = "β", "&#947;" = "γ", "&middot;" = "·", "&amp;" = "&")

#' @keywords internal
#' @noRd
.strip_name_markup <- function(x) {
  s <- .normalize_key_chr(x)
  if (is.na(s)) return(NA_character_)
  s <- gsub("<[^>]+>", "", s)                    # tag HTML
  for (e in names(.NAME_MARKUP_ENTITIES)) s <- gsub(e, .NAME_MARKUP_ENTITIES[[e]], s, fixed = TRUE)
  s <- gsub("&#[0-9]+;", "", s)                  # entità numeriche residue
  s <- trimws(s)
  if (!nzchar(s)) NA_character_ else s
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-markup.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-markup.R
git commit -m "P5 audit RED_ALERT F6: pre-clean markup nomi (name-cleanup)"
```

---

### Task 3: Loader candidati dal triage

**Files:**
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-candidates.R`
- Fixture: `tests/testthat/fixtures/name-cleanup-triage-mini.csv`

**Interfaces:**
- Consumes: triage CSV `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv` (colonne `cluster_id,name,kind,k,n_studies,homog,top_theme,name_ok,cls`).
- Produces: `.load_name_cleanup_candidates(triage_csv_path)` → tibble `cluster_id, name, kind, k, top_theme, role` con `role ∈ {"candidate","canary"}`; `candidate` = `cls` in {`OMOGENEO+MAL_nominato`,`ETEROGENEO(sospetto)`}, `canary` = `OMOGENEO+ben_nominato`; `vehicle/none` escluso.

- [ ] **Step 1: Write the failing test**

```r
# fixture: tests/testthat/fixtures/name-cleanup-triage-mini.csv
# "cluster_id","name","kind","k","n_studies","homog","top_theme","name_ok","cls"
# "c1","carnitine","small_molecule",4,4,1,"lps",0,"OMOGENEO+MAL_nominato"
# "c2","17β-estradiol","small_molecule",12,10,1,"breast",1,"OMOGENEO+ben_nominato"
# "c3","Interleukin-17","cytokine_stim",3,3,0.7,"il17",0,"ETEROGENEO(sospetto)"
# "c4","DMSO","vehicle_only",5,5,1,"dmso",1,"vehicle/none"

test_that(".load_name_cleanup_candidates classifica role ed esclude vehicle", {
  f <- testthat::test_path("fixtures", "name-cleanup-triage-mini.csv")
  d <- .load_name_cleanup_candidates(f)
  expect_equal(nrow(d), 3L)                          # c4 escluso
  expect_setequal(d$cluster_id, c("c1","c2","c3"))
  expect_equal(d$role[d$cluster_id == "c1"], "candidate")
  expect_equal(d$role[d$cluster_id == "c3"], "candidate")
  expect_equal(d$role[d$cluster_id == "c2"], "canary")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-candidates.R")'`
Expected: FAIL — funzione assente.

- [ ] **Step 3: Write minimal implementation**

```r
# R/name-cleanup.R  (append)
#' @keywords internal
#' @noRd
.load_name_cleanup_candidates <- function(triage_csv_path) {
  d <- utils::read.csv(triage_csv_path, stringsAsFactors = FALSE, check.names = FALSE)
  d <- d[d$cls != "vehicle/none", , drop = FALSE]
  d$role <- ifelse(d$cls == "OMOGENEO+ben_nominato", "canary", "candidate")
  tibble::tibble(cluster_id = as.character(d$cluster_id), name = as.character(d$name),
                 kind = as.character(d$kind), k = as.integer(d$k),
                 top_theme = as.character(d$top_theme), role = d$role)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-candidates.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-candidates.R tests/testthat/fixtures/name-cleanup-triage-mini.csv
git commit -m "P5 audit RED_ALERT F6: loader candidati name-cleanup dal triage"
```

---

### Task 4: Builder metadati membri per cluster

**Files:**
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-member-metadata.R`

**Interfaces:**
- Consumes: `build_record_gsm_lookup(stage2_master_path)` (da `analysis/audit/_gsm-lookup-helper.R`) — env `record_id → GSM treated/case`; assignments (`record_id, cluster_id`); un lookup `GSM → stringa metadati grezza` (dal jsonl input Stadio 1: chiavi `geo_accession`,`string`).
- Produces: `.build_cluster_member_metadata(cluster_ids, assignments, rec_env, gsm_text, char_budget = 6000L)` → named list `cluster_id → character(1)` (stringhe membri deduplicate, troncate a budget). `rec_env` = output di `build_record_gsm_lookup`; `gsm_text` = named chr `GSM → testo`.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-name-cleanup-member-metadata.R
test_that(".build_cluster_member_metadata aggrega e tronca i metadati membri", {
  assignments <- tibble::tibble(
    record_id = c("GSE1__cmp1", "GSE1__cmp1", "GSE2__g1"),
    cluster_id = c("c1", "c1", "c1"))
  rec_env <- new.env(parent = emptyenv())
  assign("GSE1__cmp1", c("GSM1", "GSM2"), envir = rec_env)
  assign("GSE2__g1",  c("GSM3"), envir = rec_env)
  gsm_text <- c(GSM1 = "lps treated 24h", GSM2 = "lps treated 24h", GSM3 = "control pbmc")
  out <- .build_cluster_member_metadata("c1", assignments, rec_env, gsm_text, char_budget = 1000L)
  expect_named(out, "c1")
  expect_match(out[["c1"]], "lps treated")
  expect_match(out[["c1"]], "control pbmc")
  # dedup: "lps treated 24h" appare una sola volta
  expect_equal(lengths(regmatches(out[["c1"]], gregexpr("lps treated 24h", out[["c1"]]))), 1L)
})

test_that(".build_cluster_member_metadata rispetta il char_budget", {
  assignments <- tibble::tibble(record_id = "GSE1__g1", cluster_id = "c1")
  rec_env <- new.env(parent = emptyenv()); assign("GSE1__g1", c("GSM1"), envir = rec_env)
  gsm_text <- c(GSM1 = strrep("x", 5000))
  out <- .build_cluster_member_metadata("c1", assignments, rec_env, gsm_text, char_budget = 100L)
  expect_lte(nchar(out[["c1"]]), 100L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-member-metadata.R")'`
Expected: FAIL — funzione assente.

- [ ] **Step 3: Write minimal implementation**

```r
# R/name-cleanup.R  (append)
#' @keywords internal
#' @noRd
.build_cluster_member_metadata <- function(cluster_ids, assignments, rec_env,
                                           gsm_text, char_budget = 6000L) {
  out <- vector("list", length(cluster_ids)); names(out) <- cluster_ids
  for (cid in cluster_ids) {
    recs <- assignments$record_id[assignments$cluster_id == cid]
    gsms <- unique(unlist(lapply(recs, function(r)
      get0(r, envir = rec_env, inherits = FALSE)), use.names = FALSE))
    txt <- unique(gsm_text[intersect(gsms, names(gsm_text))])
    joined <- paste(txt, collapse = " | ")
    if (nchar(joined) > char_budget) joined <- substr(joined, 1L, char_budget)
    out[[cid]] <- joined
  }
  out
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-member-metadata.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-member-metadata.R
git commit -m "P5 audit RED_ALERT F6: builder metadati membri per cluster (name-cleanup)"
```

---

### Task 5: Schema output + prompt builder

**Files:**
- Create: `inst/schemas/name_cleanup.v1.json`
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-prompt.R`

**Interfaces:**
- Produces: file schema `inst/schemas/name_cleanup.v1.json` (draft-07, `additionalProperties:false`, required `canonical_name,kind,confidence,evidence`; `confidence` enum `high|medium|low`). `.build_name_cleanup_messages(current_label, kind, member_metadata)` → `list(list(role="system",content=...), list(role="user",content=...))`.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-name-cleanup-prompt.R
test_that("lo schema name_cleanup.v1 compila", {
  path <- system.file("schemas", "name_cleanup.v1.json", package = "simulomicsr")
  expect_true(nzchar(path))
  expect_silent(compile_schema(path))
})

test_that(".build_name_cleanup_messages incapsula label+kind+metadati e NON il top_theme", {
  msgs <- .build_name_cleanup_messages("carnitine", "small_molecule", "lps treated 24h pbmc")
  expect_equal(msgs[[1]]$role, "system")
  expect_equal(msgs[[2]]$role, "user")
  expect_match(msgs[[2]]$content, "carnitine")
  expect_match(msgs[[2]]$content, "lps treated")
  expect_match(msgs[[2]]$content, "small_molecule")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-prompt.R")'`
Expected: FAIL — schema e funzione assenti.

- [ ] **Step 3: Write minimal implementation**

```json
// inst/schemas/name_cleanup.v1.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "additionalProperties": false,
  "required": ["canonical_name", "kind", "confidence", "evidence"],
  "properties": {
    "canonical_name": {"type": "string"},
    "kind": {"type": "string"},
    "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
    "evidence": {"type": "string"}
  }
}
```

```r
# R/name-cleanup.R  (append)
#' @keywords internal
#' @noRd
.name_cleanup_system_prompt <- function() {
  paste0(
    "Sei un curatore esperto di metadati GEO/RNA-seq. Ricevi l'etichetta ATTUALE ",
    "(potenzialmente sbagliata) di un gruppo di campioni e i loro metadati grezzi. ",
    "Identifica l'entita' biologica REALE (composto, citochina, patogeno, malattia) ",
    "che accomuna i campioni trattati/caso. Rispondi SOLO con un JSON: ",
    "{canonical_name, kind, confidence(high|medium|low), evidence}. ",
    "canonical_name = nome canonico piu' riconoscibile (es. 'lipopolysaccharide', ",
    "non una sigla ambigua). Se i metadati non bastano, confidence='low'.")
}

#' @keywords internal
#' @noRd
.build_name_cleanup_messages <- function(current_label, kind, member_metadata) {
  user <- paste0(
    "Etichetta attuale (sospetta): ", current_label, "\n",
    "Kind atteso: ", kind, "\n",
    "Metadati grezzi dei campioni membri:\n", member_metadata)
  list(list(role = "system", content = .name_cleanup_system_prompt()),
       list(role = "user",   content = user))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-prompt.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add inst/schemas/name_cleanup.v1.json R/name-cleanup.R tests/testthat/test-name-cleanup-prompt.R
git commit -m "P5 audit RED_ALERT F6: schema + prompt builder name-cleanup"
```

---

### Task 6: Risoluzione deterministica nome→ID (precision gate)

**Files:**
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-resolve.R`

**Interfaces:**
- Consumes: accessor `R/ontology-lookup.R` — `.chebi_lookup_alias(alias)`→`list(chebi_id,type)`, `.hgnc_lookup_symbol(sym)`, `.mesh_lookup_term(term)`→`list(ui,…)`, `.taxonomy_lookup_name(term)`→`list(taxid,…)`; env `.load_ontology_dicts()`.
- Produces: `.resolve_canonical_to_id(canonical_name, kind, env = .load_ontology_dicts())` → `list(resolved_id = chr|NA, resolved_name = chr|NA, match_strength = "STRONG"|"NONE")`. Dispatch per kind: `small_molecule`/`vehicle_only`→ChEBI (`CHEBI:<n>`); `disease_vs_normal`→MeSH (`MeSH:<ui>`); `cytokine_stim`→HGNC (`HGNC:<symbol>`) con fallback ChEBI (PAMP); `pathogen_or_aggregate_exposure`→taxonomy (`NCBITaxon:<taxid>`) con fallback ChEBI. STRONG = hit esatto dell'accessor; altrimenti NONE.

- [ ] **Step 1: Write the failing test** (mock accessor via `with_mocked_bindings`)

```r
# tests/testthat/test-name-cleanup-resolve.R
test_that(".resolve_canonical_to_id risolve small_molecule via ChEBI", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("aspirin", "small_molecule", env = list()),
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "aspirin"))
      list(chebi_id = 15365L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "CHEBI:15365")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id ritorna NONE su miss", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("qwerty", "small_molecule", env = list()),
    .chebi_lookup_alias = function(alias, env) NULL, .package = "simulomicsr")
  expect_true(is.na(res$resolved_id))
  expect_equal(res$match_strength, "NONE")
})

test_that(".resolve_canonical_to_id risolve disease via MeSH e pathogen via taxonomy", {
  d <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("Breast Neoplasms", "disease_vs_normal", env = list()),
    .mesh_lookup_term = function(term, env) list(ui = "D001943"), .package = "simulomicsr")
  expect_equal(d$resolved_id, "MeSH:D001943")
  p <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("SARS-CoV-2", "pathogen_or_aggregate_exposure", env = list()),
    .taxonomy_lookup_name = function(term, env) list(taxid = 2697049L), .package = "simulomicsr")
  expect_equal(p$resolved_id, "NCBITaxon:2697049")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-resolve.R")'`
Expected: FAIL — funzione assente.

- [ ] **Step 3: Write minimal implementation**

```r
# R/name-cleanup.R  (append)
.none_resolution <- function() list(resolved_id = NA_character_,
                                    resolved_name = NA_character_, match_strength = "NONE")

#' @keywords internal
#' @noRd
.resolve_canonical_to_id <- function(canonical_name, kind, env = .load_ontology_dicts()) {
  nm <- .strip_name_markup(canonical_name)
  if (is.na(nm)) return(.none_resolution())
  try_chebi <- function() {
    hit <- .chebi_lookup_alias(nm, env); if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("CHEBI:", hit$chebi_id), resolved_name = nm, match_strength = "STRONG")
  }
  try_mesh <- function() {
    hit <- .mesh_lookup_term(nm, env); if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("MeSH:", hit$ui), resolved_name = nm, match_strength = "STRONG")
  }
  try_hgnc <- function() {
    hit <- .hgnc_lookup_symbol(nm, env); if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("HGNC:", toupper(nm)), resolved_name = nm, match_strength = "STRONG")
  }
  try_taxon <- function() {
    hit <- .taxonomy_lookup_name(nm, env); if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("NCBITaxon:", hit$taxid), resolved_name = nm, match_strength = "STRONG")
  }
  chain <- switch(kind,
    small_molecule = list(try_chebi),
    vehicle_only   = list(try_chebi),
    disease_vs_normal = list(try_mesh),
    cytokine_stim  = list(try_hgnc, try_chebi),
    pathogen_or_aggregate_exposure = list(try_taxon, try_chebi),
    list(try_chebi, try_mesh, try_hgnc, try_taxon))  # kind ignoto: prova tutto
  for (f in chain) { r <- f(); if (!is.null(r)) return(r) }
  .none_resolution()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-resolve.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-resolve.R
git commit -m "P5 audit RED_ALERT F6: risoluzione deterministica nome->ID (precision gate)"
```

---

### Task 7: Policy override precision-gated

**Files:**
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-policy.R`

**Interfaces:**
- Produces: `.apply_name_cleanup_policy(current_id, mistral_confidence, resolution, role)` → `list(action, new_id, new_name, name_recovery_source, name_llm_unvalidatable)`. Regole: STRONG + `confidence != "low"` → se `role=="canary"` e `resolved_id != current_id` → `action="flag_review"` (no override); se `resolved_id == current_id` → `action="noop"`; altrimenti `action="override"` (source `"mistral_fallback"`). NONE / `confidence=="low"` → `action="keep"`, `name_llm_unvalidatable=TRUE`.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-name-cleanup-policy.R
strong <- function(id) list(resolved_id = id, resolved_name = "x", match_strength = "STRONG")
none_r <- list(resolved_id = NA_character_, resolved_name = NA_character_, match_strength = "NONE")

test_that("STRONG diverso su candidate -> override", {
  p <- .apply_name_cleanup_policy("CHEBI:17126", "high", strong("CHEBI:16412"), "candidate")
  expect_equal(p$action, "override"); expect_equal(p$new_id, "CHEBI:16412")
  expect_equal(p$name_recovery_source, "mistral_fallback")
  expect_false(p$name_llm_unvalidatable)
})
test_that("STRONG diverso su canary -> flag_review (no override)", {
  p <- .apply_name_cleanup_policy("CHEBI:16236", "high", strong("CHEBI:99999"), "canary")
  expect_equal(p$action, "flag_review"); expect_true(is.na(p$new_id))
})
test_that("STRONG uguale -> noop", {
  p <- .apply_name_cleanup_policy("CHEBI:16412", "high", strong("CHEBI:16412"), "candidate")
  expect_equal(p$action, "noop")
})
test_that("NONE o low -> keep + unvalidatable", {
  expect_equal(.apply_name_cleanup_policy("CHEBI:1", "high", none_r, "candidate")$action, "keep")
  expect_true(.apply_name_cleanup_policy("CHEBI:1", "high", none_r, "candidate")$name_llm_unvalidatable)
  expect_equal(.apply_name_cleanup_policy("CHEBI:1", "low", strong("CHEBI:2"), "candidate")$action, "keep")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-policy.R")'`
Expected: FAIL — funzione assente.

- [ ] **Step 3: Write minimal implementation**

```r
# R/name-cleanup.R  (append)
#' @keywords internal
#' @noRd
.apply_name_cleanup_policy <- function(current_id, mistral_confidence, resolution, role) {
  keep <- list(action = "keep", new_id = NA_character_, new_name = NA_character_,
               name_recovery_source = NA_character_, name_llm_unvalidatable = TRUE)
  if (!identical(resolution$match_strength, "STRONG") || identical(mistral_confidence, "low"))
    return(keep)
  if (identical(resolution$resolved_id, current_id))
    return(list(action = "noop", new_id = resolution$resolved_id,
                new_name = resolution$resolved_name,
                name_recovery_source = NA_character_, name_llm_unvalidatable = FALSE))
  if (identical(role, "canary"))
    return(list(action = "flag_review", new_id = NA_character_, new_name = NA_character_,
                name_recovery_source = NA_character_, name_llm_unvalidatable = FALSE))
  list(action = "override", new_id = resolution$resolved_id,
       new_name = resolution$resolved_name,
       name_recovery_source = "mistral_fallback", name_llm_unvalidatable = FALSE)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-policy.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-policy.R
git commit -m "P5 audit RED_ALERT F6: policy override precision-gated (name-cleanup)"
```

---

### Task 8: Orchestrator → side-table

**Files:**
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-orchestrator.R`

**Interfaces:**
- Consumes: tutte le funzioni Task 2-7 + un `llm_fn(messages) -> list(canonical_name, kind, confidence, evidence)` iniettabile (in produzione = wrapper su `llm_call_structured(provider="vllm", …, cache=…, cache_namespace_version=.NAME_CLEANUP_CACHE_VERSION)`).
- Produces: `run_name_cleanup(candidates, current_ids, member_metadata, llm_fn, env = .load_ontology_dicts())` → tibble side-table `cluster_id, old_id, old_label, new_canonical, new_id, new_kind, match_strength, confidence, action, name_recovery_source, name_llm_unvalidatable, evidence`. `current_ids` = named chr `cluster_id → old_id` (l'anchor_key attuale).

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-name-cleanup-orchestrator.R
test_that("run_name_cleanup produce la side-table con override e flag", {
  cand <- tibble::tibble(cluster_id = c("c1","c2"), name = c("carnitine","ethanol"),
                         kind = c("small_molecule","small_molecule"),
                         k = c(4L,5L), top_theme = c("lps","etoh"),
                         role = c("candidate","canary"))
  member <- list(c1 = "lps treated", c2 = "ethanol vehicle")
  current_ids <- c(c1 = "CHEBI:17126", c2 = "CHEBI:16236")
  llm_fn <- function(messages) {
    if (grepl("carnitine", messages[[2]]$content))
      list(canonical_name = "lipopolysaccharide", kind = "pathogen_or_aggregate_exposure",
           confidence = "high", evidence = "lps")
    else list(canonical_name = "ethanol", kind = "small_molecule", confidence = "high", evidence = "etoh")
  }
  st <- testthat::with_mocked_bindings(
    run_name_cleanup(cand, current_ids, member, llm_fn, env = list()),
    .resolve_canonical_to_id = function(canonical_name, kind, env) {
      if (canonical_name == "lipopolysaccharide")
        list(resolved_id = "CHEBI:16412", resolved_name = canonical_name, match_strength = "STRONG")
      else list(resolved_id = "CHEBI:16236", resolved_name = canonical_name, match_strength = "STRONG")
    }, .package = "simulomicsr")
  expect_equal(st$action[st$cluster_id == "c1"], "override")
  expect_equal(st$new_id[st$cluster_id == "c1"], "CHEBI:16412")
  expect_equal(st$action[st$cluster_id == "c2"], "noop")  # canary risolve allo stesso ID
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-orchestrator.R")'`
Expected: FAIL — funzione assente.

- [ ] **Step 3: Write minimal implementation**

```r
# R/name-cleanup.R  (append)
#' Orchestratore pulizia-nomi: per ogni candidato chiama l'LLM, risolve l'ID
#' deterministicamente, applica la policy, ritorna la side-table.
#' @keywords internal
#' @noRd
run_name_cleanup <- function(candidates, current_ids, member_metadata, llm_fn,
                             env = .load_ontology_dicts()) {
  rows <- lapply(seq_len(nrow(candidates)), function(i) {
    cid <- candidates$cluster_id[i]
    msgs <- .build_name_cleanup_messages(candidates$name[i], candidates$kind[i],
                                         member_metadata[[cid]] %||% "")
    out <- tryCatch(llm_fn(msgs), error = function(e) NULL)
    if (is.null(out) || is.null(out$canonical_name)) {
      res <- .none_resolution(); conf <- "low"; cname <- NA_character_; ckind <- NA_character_; ev <- NA_character_
    } else {
      cname <- out$canonical_name; ckind <- out$kind %||% candidates$kind[i]
      conf <- out$confidence %||% "low"; ev <- out$evidence %||% NA_character_
      res <- .resolve_canonical_to_id(cname, ckind, env)
    }
    pol <- .apply_name_cleanup_policy(unname(current_ids[cid]), conf, res, candidates$role[i])
    tibble::tibble(
      cluster_id = cid, old_id = unname(current_ids[cid]), old_label = candidates$name[i],
      new_canonical = res$resolved_name, new_id = pol$new_id, new_kind = ckind,
      match_strength = res$match_strength, confidence = conf, action = pol$action,
      name_recovery_source = pol$name_recovery_source,
      name_llm_unvalidatable = pol$name_llm_unvalidatable, evidence = ev)
  })
  dplyr::bind_rows(rows)
}
```

(Se `%||%` non è già definito nel pacchetto, usare `rlang::%||%` importato; verificare con `grep "%||%" R/`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-orchestrator.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-orchestrator.R
git commit -m "P5 audit RED_ALERT F6: orchestrator name-cleanup -> side-table"
```

---

### Task 9: Misura frammentazione (sottoprodotto per scope B)

**Files:**
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-fragmentation.R`

**Interfaces:**
- Produces: `.measure_fragmentation(side_table, k_by_cluster)` → tibble `resolved_entity_id, n_clusters, cluster_ids, k_merged_est` per le entità con ≥2 cluster distinti che risolvono allo stesso ID (frammenti). `k_by_cluster` = named int `cluster_id → k`. Usa `new_id` dove presente, altrimenti `old_id`.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-name-cleanup-fragmentation.R
test_that(".measure_fragmentation individua i frammenti e somma k", {
  st <- tibble::tibble(
    cluster_id = c("c1","c2","c3"),
    old_id = c("CHEBI:17126","CHEBI:99","CHEBI:50"),
    new_id = c("CHEBI:16412","CHEBI:16412", NA_character_))  # c1,c2 -> stessa entità
  k_by <- c(c1 = 4L, c2 = 3L, c3 = 5L)
  fr <- .measure_fragmentation(st, k_by)
  expect_equal(nrow(fr), 1L)
  expect_equal(fr$resolved_entity_id, "CHEBI:16412")
  expect_equal(fr$n_clusters, 2L)
  expect_equal(fr$k_merged_est, 7L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-fragmentation.R")'`
Expected: FAIL — funzione assente.

- [ ] **Step 3: Write minimal implementation**

```r
# R/name-cleanup.R  (append)
#' @keywords internal
#' @noRd
.measure_fragmentation <- function(side_table, k_by_cluster) {
  eff_id <- ifelse(!is.na(side_table$new_id), side_table$new_id, side_table$old_id)
  df <- tibble::tibble(cluster_id = side_table$cluster_id, eid = eff_id,
                       k = as.integer(k_by_cluster[side_table$cluster_id]))
  df <- df[!is.na(df$eid), , drop = FALSE]
  g <- dplyr::group_by(df, eid)
  s <- dplyr::summarise(g, n_clusters = dplyr::n(),
                        cluster_ids = paste(sort(cluster_id), collapse = ";"),
                        k_merged_est = sum(k, na.rm = TRUE), .groups = "drop")
  s <- s[s$n_clusters >= 2L, , drop = FALSE]
  dplyr::rename(dplyr::arrange(s, dplyr::desc(n_clusters)), resolved_entity_id = eid)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-name-cleanup-fragmentation.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-fragmentation.R
git commit -m "P5 audit RED_ALERT F6: misura frammentazione (sottoprodotto scope B)"
```

---

> **REVISIONE 2026-07-06 (decisione utente):** i job Mistral girano via **path batch DGX**
> (`bundle → submit → collect`, come Stadio 1/2), NON via adapter/endpoint (non esiste un vLLM
> server persistente in questo setup). L'adapter `.vllm_chat_structured` (Task 1) resta come
> capacità generale ma non è il meccanismo del run. StructuredOutputsParams strict del batch
> risolve la preoccupazione blast-radius del final review. I Task 10-13 sostituiscono i vecchi 10-11.

### Task 10: Integrazione stage `name_cleanup` nel bundle/runner DGX

**Files:**
- Modify: `inst/dgx/python/prompts.py` (aggiungi `render_user_message_name_cleanup`)
- Modify: `inst/dgx/python/run_p4_vllm.py:35,79-84` (import + branch in `render_user_for_stage`)
- Modify: `R/dgx-bundle.R:38,106-111` (accetta stage `name_cleanup` + system prompt via `.name_cleanup_system_prompt()`)
- Modify: `inst/extdata/p4-defaults.yml` (blocco `stages.name_cleanup`)
- Test: `inst/dgx/python/test_prompts.py` (renderer) + `tests/testthat/test-dgx-bundle-name-cleanup.R` (bundle)

**Interfaces:**
- Input jsonl record (name_cleanup): `{record_id, current_label, kind, member_metadata}`.
- `render_user_message_name_cleanup(record)` produce lo stesso user-message di `.build_name_cleanup_messages` (label + kind + member_metadata; NIENTE top_theme). System prompt = testo di `.name_cleanup_system_prompt()`. Schema = `inst/schemas/name_cleanup.v1.json`.
- `dgx_p4_build_bundle(input_jsonl, stage="name_cleanup", config)` → bundle con `prompt.txt` (name-cleanup) + `schema.json` (name_cleanup.v1) + `generation.json` (temp=0, rep_pen=1.1, max_tokens=1024).

- [ ] **Step 1 (python):** `render_user_message_name_cleanup(record)` in `prompts.py` (mirror del testo di `.build_name_cleanup_messages`); aggiungi il branch `name_cleanup` in `run_p4_vllm.py:render_user_for_stage` + l'import a riga 35. Aggiungi un test in `test_prompts.py` che verifica label/kind/member_metadata presenti e `top_theme` assente. Esegui: `python -m pytest inst/dgx/python/test_prompts.py -q` (o il runner python del repo).
- [ ] **Step 2 (yaml):** blocco `stages.name_cleanup` in `p4-defaults.yml`: `schema_file: "name_cleanup.v1.json"`, `max_tokens: 1024`, `max_model_len: 8192`, `microbatch: 50`.
- [ ] **Step 3 (R, TDD):** in `R/dgx-bundle.R` estendi la guardia stage (`:38`) a `name_cleanup` e il ramo system-prompt (`:106-111`) → `simulomicsr:::.name_cleanup_system_prompt()`. Test RED→GREEN in `tests/testthat/test-dgx-bundle-name-cleanup.R`: `dgx_p4_build_bundle(<jsonl 2 record>, stage="name_cleanup", config=dgx_config())` scrive `prompt.txt` che contiene il testo name-cleanup + `schema.json` == `name_cleanup.v1.json` + `manifest.json$stage=="name_cleanup"`. (Config solo per build locale, nessun submit.)
- [ ] **Step 4:** run test R focalizzato (foreground) + python test. Commit.

```bash
git add inst/dgx/python/prompts.py inst/dgx/python/run_p4_vllm.py inst/dgx/python/test_prompts.py R/dgx-bundle.R inst/extdata/p4-defaults.yml tests/testthat/test-dgx-bundle-name-cleanup.R
git commit -m "P5 audit RED_ALERT F6: stage name_cleanup nel bundle/runner DGX"
```

### Task 11: Builder input jsonl + assembler side-table da predictions (TDD)

**Files:**
- Modify: `R/name-cleanup.R`
- Test: `tests/testthat/test-name-cleanup-batch.R`

**Interfaces:**
- Produces: `.build_name_cleanup_input_jsonl(candidates, member_metadata, out_path)` → scrive jsonl `{record_id=cluster_id, current_label, kind, member_metadata}` (1 riga/candidato).
- Produces: `.assemble_side_table_from_predictions(candidates, current_ids, predictions_by_id, env = .load_ontology_dicts())` → side-table (stesse 12 colonne di `run_name_cleanup`) + **2 colonne audit** (final review): `conflicting_id` (l'id risolto su `flag_review`) e `llm_proposed_name` (il nome grezzo proposto dall'LLM, anche su NONE/keep). `predictions_by_id` = named list `cluster_id → list(canonical_name, kind, confidence, evidence)` (da `dgx_p4_collect$predictions$parsed_json`). Riusa `.resolve_canonical_to_id` + `.apply_name_cleanup_policy`.

- [ ] **Step 1:** test RED per entrambe (jsonl scritto con le 4 chiavi giuste; assembler: un override + un canary flag_review con `conflicting_id` popolato + un NONE con `llm_proposed_name` preservato).
- [ ] **Step 2:** implementa; usa `.resolve_canonical_to_id`/`.apply_name_cleanup_policy` come `run_name_cleanup` ma sourcing l'output LLM da `predictions_by_id[[cluster_id]]` invece che live; su predizione assente → riga NONE/keep.
- [ ] **Step 3:** run test focalizzato (foreground). Commit.

```bash
git add R/name-cleanup.R tests/testthat/test-name-cleanup-batch.R
git commit -m "P5 audit RED_ALERT F6: builder input jsonl + assembler side-table da predictions batch"
```

### Task 12: Gold ~20 + smoke gate batch (GATE UTENTE — submit DGX)

**Files:**
- Create: `analysis/audit/name-cleanup-gold.csv` (~20 mislabel noti + ~5 canary, colonne `record_id,current_label,kind,member_metadata,expected_id,is_canary`)
- Create: `analysis/audit/2026-07-06-name-cleanup-smoke.R`

- [ ] **Step 1:** costruisci il gold dai casi del finding §3 (carnitine→LPS/CHEBI:16412, Antistreptolysin→AML, Netherlands Antilles→NSCLC, Pemphigoid Gestationis→HCC, Genes-Viral→GBM, …) + ~5 canary ben-nominati.
- [ ] **Step 2:** smoke script: gold → `.build_name_cleanup_input_jsonl` → `dgx_p4_build_bundle(stage="name_cleanup")` → `dgx_p4_submit(config=dgx_config())` → `dgx_p4_collect` → `.assemble_side_table_from_predictions` → precision (override corretti/override) + recall (mislabel recuperati/gold) + **0 override sui canary**.
- [ ] **Step 3 (GATE UTENTE):** `Rscript analysis/audit/2026-07-06-name-cleanup-smoke.R`. Se precision bassa o canary toccati → STOP, iterare prompt/policy PRIMA del run pieno. Report `analysis/audit/2026-07-06-name-cleanup-smoke.md`. Commit.

### Task 13: Run pieno (submit 125+ bundle) + side-table + misura-B + closeout (GATE UTENTE)

**Files:**
- Create: `analysis/p5-name-cleanup-run.R`
- Output (gitignored): `analysis/p4-output/name-cleanup-side-table-v1.rds` + `name-cleanup-fragmentation-v1.csv` + bundle/collect dirs
- Create: `docs/findings/2026-07-06-name-cleanup-results.md`

- [ ] **Step 1:** script che assembla: `cand <- .load_name_cleanup_candidates(<triage csv>)`; `s3 <- load_stage3(<stage3 v7>)`; `current_ids <- setNames(s3$clusters$anchor_key, s3$clusters$cluster_id)[cand$cluster_id]`; `rec_env <- build_record_gsm_lookup(<master v3>)` (source `_gsm-lookup-helper.R`); `gsm_text` = named chr GSM→string via `jsonlite::stream_in` sul jsonl input Stadio 1 (`geo_accession`→`string`); `member <- .build_cluster_member_metadata(cand$cluster_id, s3$assignments, rec_env, gsm_text)`; `.build_name_cleanup_input_jsonl(cand, member, <path>)`.
- [ ] **Step 2 (GATE UTENTE):** `dgx_p4_build_bundle(stage="name_cleanup")` → `dgx_p4_submit(config=dgx_config(), time="04:00:00")` → poll → `dgx_p4_collect`; `predictions_by_id` da `collect$predictions` (`record_id→parsed_json`); `side <- .assemble_side_table_from_predictions(cand, current_ids, predictions_by_id)`; `saveRDS`. `k_by <- setNames(s3$clusters$k, s3$clusters$cluster_id)`; `fr <- .measure_fragmentation(side, k_by)`; `write.csv`.
- [ ] **Step 3:** review umana del diff (override before→after + flag_review), no-fretta paper-grade.
- [ ] **Step 4:** closeout — finding (n corretti/flaggati + misura-B: quante entità frammentano e k_merged → GO/NO-GO scope B) + CLAUDE.md header + memoria `project_stage3_minestrone_rework` + ledger. Commit.

---

## Note per l'esecuzione

- **Ordine:** Task 1-9 (moduli) + Task 10-11 (integrazione stage DGX + builder/assembler) sono TDD e indipendenti dalla DGX (mock/build locale) → eseguibili subito. Task 12-13 sono GATE UTENTE (richiedono `dgx_p4_submit` alla DGX: bundle→submit→collect, path batch — NON un endpoint persistente).
- **Verifica `%||%`:** prima del Task 8, `grep -rn "\`%||%\`" R/` per confermare la disponibilità (rlang o helper locale); se assente, definirlo `@noRd`.
- **Scope B è fuori piano:** la misura-B produce solo il *dato* per decidere; l'eventuale re-cluster→re-pool sarà spec/plan separati.
