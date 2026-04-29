# P1 — Infrastruttura LLM (cache + validator + client OpenAI + lookup minimal) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Costruire l'infrastruttura LLM riusabile del pacchetto `simulomicsr` — un client `llm_call_structured()` provider-agnostic con adapter OpenAI Structured Outputs, una cache locale JSONL+SQLite, un validator JSON Schema, e una utility `normalize_gene()` deterministica via HGNC. Questa è la base che P2 (Stadio 1) e P3 (Stadio 2 + pipeline) consumeranno.

**Architecture:** Tre strati orizzontali. (1) `cache` + `hash` + `validate` sono utility pure, testabili senza rete. (2) `llm-client.R` è un'interfaccia sottile che dispatcha su adapter per provider; oggi solo `openai`. (3) `llm-client-openai.R` traduce la chiamata in HTTP via `httr2`, sfrutta Structured Outputs (`response_format = json_schema, strict = true`) e applica la cache. `lookup.R` è separato (deterministico, no LLM) e gestisce solo geni umani in P1 (Cellosaurus/DrugBank rinviati). Tutti i test che toccano la rete usano `httptest2` con cassette registrate; un solo smoke E2E reale è gated su `OPENAI_API_KEY`.

**Tech Stack:** R 4.5+, `httr2` (HTTP + retry), `jsonlite` (JSON), `jsonvalidate` (Ajv-backed JSON Schema), `DBI` + `RSQLite` (cache index), `digest` (sha256), `cli` + `rlang` (errori e messaggi), `testthat` (>= 3.0.0), `withr` (env in test), `httptest2` (mock httr2). Gestione dipendenze via `renv`.

---

## File Structure

Ogni file ha una responsabilità precisa, file piccoli e focalizzati:

| File | Responsabilità | LOC stimato |
|---|---|---|
| `R/hash.R` | `sha256_text()`, `cache_key_for()` — solo hashing deterministico | ~30 |
| `R/cache.R` | Cache append-only JSONL + indice SQLite. API: `cache_init()`, `cache_get()`, `cache_put()`, `cache_has()`, `cache_stats()` | ~150 |
| `R/validate.R` | Wrapper su `jsonvalidate`. API: `compile_schema()`, `validate_json()`. Schema bundled in `inst/schemas/` | ~60 |
| `R/llm-client.R` | Interfaccia pubblica `llm_call_structured()`. Dispatch su provider, integra cache, gestisce errori standardizzati | ~120 |
| `R/llm-client-openai.R` | Adapter privato `.openai_chat_structured()`. HTTP via `httr2`, gestione retry, Structured Outputs | ~140 |
| `R/lookup.R` | `normalize_gene()` con dump HGNC. Carica dump on-demand in `tools::R_user_dir()` cache. Gli altri vocabolari sono out-of-scope P1 | ~100 |
| `inst/schemas/llm-call-envelope.v1.json` | JSON Schema della response usata nei test (envelope minimo: `{question, answer, confidence}`) | ~25 |
| `inst/extdata/hgnc-fixture-mini.tsv` | 20 righe HGNC per i test (no download nei test) | ~22 |

I file `R/llm-stage1.R`, `R/llm-stage2.R`, `R/anchors.R`, `R/geo-fetch.R`, `R/eval-metrics.R`, `R/migrate.R` sono **NON** in scope di P1 — vengono creati in P2 e P3.

`R/utils.R` esistente non viene toccato (contiene helper legacy non collegati alla pipeline LLM).

---

## Task 0: Riconciliazione renv + DESCRIPTION runtime imports + .Renviron template

**Files:**
- Modifica: `DESCRIPTION`
- Modifica: `.Renviron`
- Modifica: `.gitignore`
- Crea: `docs/decisions/0004-renv-riconciliato.md`
- Modifica: `renv.lock` (via `renv::snapshot()`)

- [ ] **Step 0.1: Verifica versione R attiva**

Run: `R --version | head -1`
Expected: `R version 4.5.2 (2025-10-31)` (o successiva 4.5.x). Se diversa, FERMARE e segnalare.

- [ ] **Step 0.2: Aggiorna DESCRIPTION con Imports runtime e Suggests test**

Sostituire il blocco `Imports:` e `Suggests:` con:

```
Depends:
    R (>= 4.4)
Imports:
    cli,
    DBI,
    digest,
    fs,
    glue,
    httr2,
    jsonlite,
    jsonvalidate,
    purrr,
    readr,
    rlang,
    RSQLite,
    stringr,
    tibble
Suggests:
    checkmate,
    covr,
    devtools,
    here,
    httptest2,
    knitr,
    lintr,
    qs,
    rmarkdown,
    spelling,
    tarchetypes,
    targets,
    testthat (>= 3.0.0),
    usethis,
    withr
```

Lasciare invariato il resto (`Title`, `Authors@R`, `License`, `Config/testthat/edition`, `Encoding`, `Language`, `Roxygen`, `RoxygenNote`).

Aggiornare anche `Title` a `Title: Pipeline di classificazione LLM per RNAseq da repository pubblici`
e `Description` a `Description: Pipeline R per scaricare metadati di sample RNAseq da GEO/ARCHS4, classificarli via LLM in fatti strutturati e ruoli di design study-level, e produrre confronti per meta-analisi cross-studio.`

- [ ] **Step 0.3: Installa pacchetti runtime nella libreria renv**

Run da R (in `~/Documents/Projects/simulomicsr`):

```r
renv::install(c(
  "cli", "DBI", "digest", "fs", "glue", "httr2", "jsonlite",
  "jsonvalidate", "purrr", "readr", "rlang", "RSQLite",
  "stringr", "tibble"
))
renv::install(c(
  "checkmate", "covr", "devtools", "here", "httptest2",
  "knitr", "rmarkdown", "testthat", "withr"
))
```

Expected: nessun errore, conferma installazione di ciascun pacchetto. Se `renv` segnala "lockfile is from R 4.2.2", procedere comunque — il prossimo step rifa lo snapshot.

- [ ] **Step 0.4: Rifare snapshot renv per R 4.5**

Run da R:

```r
renv::snapshot(type = "implicit", prompt = FALSE)
```

Verifica:

```r
jsonlite::read_json("renv.lock")$R$Version
```

Expected: `"4.5.2"` (o la 4.5.x corrente).

- [ ] **Step 0.5: Aggiorna `.Renviron` con template per OPENAI_API_KEY**

Sostituire il file `.Renviron` con:

```
PATH="${RTOOLS40_HOME}\usr\bin;${PATH}"

# Project's information
PROJ_TITLE="simulomicsr — RNAseq → LLM → meta-analisi"
PROJ_DESCRIPTION="Pipeline di classificazione LLM per sample RNAseq da repository pubblici."
PROJ_URL="https://github.com/UBESP-DCTV/simulomicsr"

# LLM provider keys.
# IMPORTANTE: la chiave NON va committata. Per uso reale duplicare questo file
# in `.Renviron.local` (gitignored) e impostarla lì, oppure exportarla nella
# shell prima di lanciare R.
OPENAI_API_KEY=""

# Shared folders local locations (legacy)
PRJ_SHARED_PATH=""
INPUT_DATA_FOLDER="data-raw"
OUTPUT_DATA_FOLDER="output"
```

- [ ] **Step 0.6: Aggiorna `.gitignore`**

Aggiungere alla fine del file `.gitignore`:

```
# Local secrets — NEVER commit API keys
.Renviron.local

# LLM cache locale del progetto
analysis/cache/
inst/cache-test/
```

- [ ] **Step 0.7: Crea ADR-0004**

File `docs/decisions/0004-renv-riconciliato.md`:

```markdown
# ADR-0004: Riconciliazione renv per R 4.5 e dipendenze runtime LLM

- **Status:** Accepted
- **Date:** 2026-04-29
- **Deciders:** Luca Vedovelli
- **Supersedes:** —

## Context

Il `renv.lock` precedente era generato con R 4.2.2 mentre il sistema usa R 4.5.2.
La libreria locale del progetto era praticamente vuota (`installed.packages()`
nella libreria attiva ritornava `named character(0)`). Inoltre il `DESCRIPTION`
precedente aveva un set di dipendenze (`fs`, `purrr`, `readr`, `stringr`)
allineato a un template, non ai bisogni reali della pipeline LLM definita
nella spec del classificatore (v5).

## Decision

Procediamo con un singolo profilo renv allineato a R 4.5.x, con il set di
dipendenze runtime richieste da P1 dichiarate in `Imports:` del `DESCRIPTION`.
Il lockfile viene rigenerato con `renv::snapshot(type = "implicit")`.

Imports runtime aggiunti per P1:
`cli`, `DBI`, `digest`, `fs`, `glue`, `httr2`, `jsonlite`, `jsonvalidate`,
`purrr`, `readr`, `rlang`, `RSQLite`, `stringr`, `tibble`.

Suggests aggiunti per test/dev:
`httptest2` (mock httr2), `withr` (env vars in test), oltre al pre-esistente
testthat/devtools/knitr/rmarkdown.

`Depends: R (>= 4.4)` — compromesso fra modernità (httr2 e jsonvalidate
recenti funzionano bene su 4.4+) e portabilità.

## Consequences

- **Positive:** la pipeline è installabile/eseguibile localmente; CI può
  ricostruire un ambiente coerente da `renv.lock`.
- **Negative:** chi clona oggi deve eseguire `renv::restore()` (dipendenze
  binarie consistenti).
- **Neutral:** non sono introdotti profili `library` vs `analysis`; lockfile
  unico al livello di repo come da ADR-0002.

## Links

- ADR-0002 (struttura research compendium)
- Spec classificatore LLM v5 §5 (pipeline tecnica)
```

- [ ] **Step 0.8: Sanity check libreria**

Run da R:

```r
suppressPackageStartupMessages({
  library(httr2); library(jsonlite); library(jsonvalidate)
  library(DBI); library(RSQLite); library(digest); library(cli); library(rlang)
})
sessionInfo()$otherPkgs |> names() |> sort()
```

Expected: vede tutti i pacchetti caricati senza errori.

- [ ] **Step 0.9: Commit**

```bash
git add DESCRIPTION .Renviron .gitignore renv.lock docs/decisions/0004-renv-riconciliato.md
git commit -m "P1 Task 0: riconcilio renv per R 4.5 + DESCRIPTION runtime LLM (ADR-0004)"
```

---

## Task 1: hash utility (`R/hash.R`)

**Files:**
- Crea: `R/hash.R`
- Crea: `tests/testthat/test-hash.R`

- [ ] **Step 1.1: Scrivi il test fallente**

File `tests/testthat/test-hash.R`:

```r
test_that("sha256_text produce hash deterministico esadecimale di 64 caratteri", {
  h1 <- sha256_text("hello world")
  expect_type(h1, "character")
  expect_length(h1, 1L)
  expect_match(h1, "^[0-9a-f]{64}$")

  # Determinismo
  expect_identical(sha256_text("hello world"), h1)

  # Sensibilità a un singolo carattere
  expect_false(identical(sha256_text("hello world"), sha256_text("hello world!")))
})

test_that("cache_key_for compone una chiave canonica con prefisso schema_version", {
  k <- cache_key_for(schema_version = "stage1.v3", payload = "VEGF stim 0h HUVEC")
  expect_match(k, "^stage1\\.v3:[0-9a-f]{64}$")

  # Stesso schema + stesso payload → stessa chiave
  expect_identical(
    cache_key_for("stage1.v3", "VEGF stim 0h HUVEC"),
    cache_key_for("stage1.v3", "VEGF stim 0h HUVEC")
  )

  # Bump schema → chiave diversa
  expect_false(identical(
    cache_key_for("stage1.v3", "x"),
    cache_key_for("stage1.v4", "x")
  ))
})
```

- [ ] **Step 1.2: Run test, verifica che fallisca**

Run: `R -e 'devtools::test(filter = "hash")'`
Expected: FAIL con `could not find function "sha256_text"` (e per `cache_key_for`).

- [ ] **Step 1.3: Implementa il minimo**

File `R/hash.R`:

```r
#' Calcola lo SHA-256 di una stringa testuale UTF-8
#'
#' @param x stringa di lunghezza 1
#' @return stringa esadecimale di 64 caratteri
#' @keywords internal
sha256_text <- function(x) {
  stopifnot(is.character(x), length(x) == 1L, !is.na(x))
  digest::digest(x, algo = "sha256", serialize = FALSE)
}

#' Costruisce una cache key canonica `<schema_version>:<sha256(payload)>`
#'
#' La presenza dello schema_version come prefisso garantisce che un bump
#' di schema invalidi automaticamente la cache esistente (vedi spec v5 §5.4).
#'
#' @param schema_version es. `"stage1.v3"`
#' @param payload stringa che identifica il contenuto da cacheare
#' @return stringa `"<schema_version>:<sha256>"`
#' @keywords internal
cache_key_for <- function(schema_version, payload) {
  stopifnot(is.character(schema_version), length(schema_version) == 1L)
  stopifnot(is.character(payload), length(payload) == 1L)
  paste0(schema_version, ":", sha256_text(payload))
}
```

- [ ] **Step 1.4: Run test, verifica PASS**

Run: `R -e 'devtools::test(filter = "hash")'`
Expected: PASS — `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 5 ]`.

- [ ] **Step 1.5: Genera roxygen + check**

Run: `R -e 'devtools::document()'`
Expected: aggiorna `man/sha256_text.Rd` e `man/cache_key_for.Rd`. Nessun warning.

- [ ] **Step 1.6: Commit**

```bash
git add R/hash.R tests/testthat/test-hash.R man/sha256_text.Rd man/cache_key_for.Rd NAMESPACE
git commit -m "P1 Task 1: sha256_text() + cache_key_for() con TDD"
```

---

## Task 2: cache layer (`R/cache.R`)

Cache append-only su JSONL + indice SQLite per lookup rapido. Nessuna invalidazione: bump di `schema_version` invalida implicitamente perché la chiave cambia.

**Files:**
- Crea: `R/cache.R`
- Crea: `tests/testthat/test-cache.R`
- Modifica: `tests/testthat/setup.R` (helper temp dir)

- [ ] **Step 2.1: Aggiungi helper di setup ai test**

Modifica `tests/testthat/setup.R` per aggiungere (preservando il contenuto esistente):

```r
# Helper: crea una directory temporanea cache per il test corrente,
# pulita automaticamente da withr::defer_parent.
new_cache_dir <- function(env = parent.frame()) {
  d <- fs::path(tempfile(pattern = "cache-test-"))
  fs::dir_create(d)
  withr::defer(fs::dir_delete(d), envir = env)
  d
}
```

Se il file `tests/testthat/setup.R` esiste già, leggerlo prima e fare append. Se contiene già `library(...)` chiamate, lasciarle invariate.

- [ ] **Step 2.2: Scrivi i test fallenti**

File `tests/testthat/test-cache.R`:

```r
test_that("cache_init crea jsonl e sqlite vuoti idempotentemente", {
  d <- new_cache_dir()
  c1 <- cache_init(d, namespace = "stage1")

  expect_true(fs::file_exists(c1$jsonl_path))
  expect_true(fs::file_exists(c1$sqlite_path))
  expect_equal(cache_stats(c1)$n_entries, 0L)

  # Idempotente: secondo init sulla stessa dir non rompe e non resetta
  cache_put(c1, key = "a", value = list(x = 1))
  c2 <- cache_init(d, namespace = "stage1")
  expect_equal(cache_stats(c2)$n_entries, 1L)
})

test_that("cache_put + cache_get fanno round-trip su strutture R complesse", {
  c <- cache_init(new_cache_dir(), namespace = "stage1")

  payload <- list(
    geo_accession = "GSM1009635",
    perturbations = list(
      list(kind = "cytokine_stimulation", agent = "VEGFA", dose = NA)
    ),
    confidence = 0.81
  )

  cache_put(c, key = "k1", value = payload, metadata = list(model = "gpt-5.4-mini"))

  expect_true(cache_has(c, "k1"))
  got <- cache_get(c, "k1")
  expect_equal(got$value, payload)
  expect_equal(got$metadata$model, "gpt-5.4-mini")
})

test_that("cache_get ritorna NULL su miss e cache_has è coerente", {
  c <- cache_init(new_cache_dir(), namespace = "stage1")
  expect_false(cache_has(c, "nope"))
  expect_null(cache_get(c, "nope"))
})

test_that("la cache sopravvive a una riapertura su nuovo processo (riapertura sqlite)", {
  d <- new_cache_dir()
  c1 <- cache_init(d, namespace = "stage1")
  cache_put(c1, "persist", list(answer = 42))

  c2 <- cache_init(d, namespace = "stage1")
  expect_true(cache_has(c2, "persist"))
  expect_equal(cache_get(c2, "persist")$value$answer, 42)
})

test_that("namespace separa entries dello stesso path", {
  d <- new_cache_dir()
  c_a <- cache_init(d, namespace = "stage1")
  c_b <- cache_init(d, namespace = "stage2")

  cache_put(c_a, "k", list(v = "in_stage1"))
  expect_false(cache_has(c_b, "k"))
  expect_true(cache_has(c_a, "k"))
})

test_that("cache_put append-only: due put su stessa key tengono ENTRAMBI in jsonl ma get ritorna l'ultimo", {
  c <- cache_init(new_cache_dir(), namespace = "stage1")
  cache_put(c, "k", list(v = 1))
  cache_put(c, "k", list(v = 2))

  expect_equal(cache_get(c, "k")$value$v, 2)
  # Append-only: il jsonl ha 2 righe
  jsonl_lines <- readr::read_lines(c$jsonl_path)
  expect_equal(length(jsonl_lines), 2L)
})
```

- [ ] **Step 2.3: Run test, verifica fallimento**

Run: `R -e 'devtools::test(filter = "cache")'`
Expected: FAIL con `could not find function "cache_init"` (e simili).

- [ ] **Step 2.4: Implementa `R/cache.R`**

File `R/cache.R`:

```r
#' Inizializza una cache locale append-only (JSONL + indice SQLite)
#'
#' La cache vive in una directory `dir`. Per ogni `namespace` (es.
#' `"stage1"`, `"stage2"`) crea due file: `<namespace>.jsonl` (record
#' append-only, una riga JSON per put) e `<namespace>.sqlite` (indice
#' chiave → offset/byte_size dell'ultima versione).
#'
#' Idempotente: chiamarla ripetutamente sulla stessa dir non altera lo stato.
#'
#' @param dir directory esistente o creabile dove vivono i file di cache
#' @param namespace nome corto della partizione di cache (es. `"stage1"`)
#' @return oggetto `cache` (list opaca) usato dalle altre funzioni `cache_*`
#' @keywords internal
cache_init <- function(dir, namespace = "default") {
  stopifnot(is.character(namespace), length(namespace) == 1L,
            grepl("^[A-Za-z0-9_-]+$", namespace))
  fs::dir_create(dir)

  jsonl_path  <- fs::path(dir, paste0(namespace, ".jsonl"))
  sqlite_path <- fs::path(dir, paste0(namespace, ".sqlite"))

  if (!fs::file_exists(jsonl_path))  fs::file_create(jsonl_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS entries (
      key        TEXT PRIMARY KEY,
      offset     INTEGER NOT NULL,
      byte_size  INTEGER NOT NULL,
      put_at     TEXT NOT NULL
    )
  ")
  DBI::dbDisconnect(con)

  structure(
    list(
      dir         = fs::path_abs(dir),
      namespace   = namespace,
      jsonl_path  = jsonl_path,
      sqlite_path = sqlite_path
    ),
    class = "simulomicsr_cache"
  )
}

#' @keywords internal
cache_put <- function(cache, key, value, metadata = list()) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  stopifnot(is.character(key), length(key) == 1L)

  record <- list(
    key      = key,
    value    = value,
    metadata = metadata,
    put_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  )
  line <- jsonlite::toJSON(record, auto_unbox = TRUE, null = "null", na = "null")
  line <- paste0(line, "\n")

  # Determina offset e size PRIMA di scrivere
  offset <- if (fs::file_exists(cache$jsonl_path)) fs::file_size(cache$jsonl_path) else 0L
  byte_size <- nchar(line, type = "bytes")

  con <- file(cache$jsonl_path, open = "ab")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(line), con)

  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  DBI::dbExecute(db,
    "INSERT INTO entries (key, offset, byte_size, put_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(key) DO UPDATE SET
       offset = excluded.offset,
       byte_size = excluded.byte_size,
       put_at = excluded.put_at",
    params = list(key, as.integer(offset), as.integer(byte_size), record$put_at)
  )

  invisible(cache)
}

#' @keywords internal
cache_has <- function(cache, key) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  res <- DBI::dbGetQuery(db,
    "SELECT 1 FROM entries WHERE key = ? LIMIT 1",
    params = list(key)
  )
  nrow(res) > 0L
}

#' @keywords internal
cache_get <- function(cache, key) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  res <- DBI::dbGetQuery(db,
    "SELECT offset, byte_size FROM entries WHERE key = ? LIMIT 1",
    params = list(key)
  )
  if (nrow(res) == 0L) return(NULL)

  con <- file(cache$jsonl_path, open = "rb")
  on.exit(close(con), add = TRUE)
  seek(con, where = res$offset, origin = "start")
  raw <- readBin(con, what = "raw", n = res$byte_size)
  json_line <- rawToChar(raw)
  jsonlite::fromJSON(json_line, simplifyVector = FALSE)
}

#' @keywords internal
cache_stats <- function(cache) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  n <- DBI::dbGetQuery(db, "SELECT COUNT(*) AS n FROM entries")$n
  list(
    n_entries  = as.integer(n),
    jsonl_size = fs::file_size(cache$jsonl_path),
    sqlite_size = fs::file_size(cache$sqlite_path)
  )
}
```

- [ ] **Step 2.5: Run test, verifica PASS**

Run: `R -e 'devtools::test(filter = "cache")'`
Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 6 ]`.

- [ ] **Step 2.6: Run TUTTI i test per non-regressione**

Run: `R -e 'devtools::test()'`
Expected: tutti pass (hash + cache).

- [ ] **Step 2.7: Genera roxygen**

Run: `R -e 'devtools::document()'`
Expected: aggiorna man pages, nessun warning.

- [ ] **Step 2.8: Commit**

```bash
git add R/cache.R tests/testthat/test-cache.R tests/testthat/setup.R man/cache_init.Rd man/cache_put.Rd man/cache_has.Rd man/cache_get.Rd man/cache_stats.Rd NAMESPACE
git commit -m "P1 Task 2: cache JSONL+SQLite con namespace, append-only e round-trip"
```

---

## Task 3: JSON Schema validator (`R/validate.R`)

**Files:**
- Crea: `R/validate.R`
- Crea: `inst/schemas/llm-call-envelope.v1.json`
- Crea: `tests/testthat/test-validate.R`

- [ ] **Step 3.1: Crea lo schema bundled**

File `inst/schemas/llm-call-envelope.v1.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "llm-call-envelope.v1",
  "description": "Envelope minimo usato dai test della Task 5 e 6: una risposta LLM strutturata con question, answer, confidence.",
  "type": "object",
  "required": ["question", "answer", "confidence"],
  "additionalProperties": false,
  "properties": {
    "question":   { "type": "string", "minLength": 1 },
    "answer":     { "type": "string", "minLength": 1 },
    "confidence": { "type": "number", "minimum": 0, "maximum": 1 }
  }
}
```

- [ ] **Step 3.2: Scrivi i test fallenti**

File `tests/testthat/test-validate.R`:

```r
test_that("compile_schema legge un file e ritorna un validatore richiamabile", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  expect_true(nzchar(path))

  v <- compile_schema(path)
  expect_type(v, "closure")
})

test_that("validate_json passa su input conforme", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  v <- compile_schema(path)

  ok <- list(question = "Q?", answer = "A.", confidence = 0.5)
  res <- validate_json(ok, validator = v)
  expect_true(res$valid)
  expect_equal(length(res$errors), 0L)
})

test_that("validate_json fallisce su confidence > 1 con messaggio leggibile", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  v <- compile_schema(path)

  bad <- list(question = "Q?", answer = "A.", confidence = 1.5)
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_gte(length(res$errors), 1L)
  expect_match(paste(res$errors, collapse = " | "), "confidence", ignore.case = TRUE)
})

test_that("validate_json fallisce se manca un required field", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  v <- compile_schema(path)

  bad <- list(question = "Q?", answer = "A.")
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "), "confidence", ignore.case = TRUE)
})
```

- [ ] **Step 3.3: Run test fallente**

Run: `R -e 'devtools::test(filter = "validate")'`
Expected: FAIL con `could not find function "compile_schema"`.

- [ ] **Step 3.4: Implementa `R/validate.R`**

File `R/validate.R`:

```r
#' Compila uno schema JSON Schema (draft-07) in un validatore richiamabile
#'
#' Wrapper su `jsonvalidate::json_validator()` con backend Ajv. Il validatore
#' ritornato è una funzione che accetta una stringa JSON e ritorna TRUE/FALSE
#' (con attribute `errors` se invalido).
#'
#' @param schema_path path a un file `.json` con lo schema
#' @return funzione validatrice
#' @keywords internal
compile_schema <- function(schema_path) {
  stopifnot(fs::file_exists(schema_path))
  jsonvalidate::json_validator(
    schema = readr::read_file(schema_path),
    engine = "ajv"
  )
}

#' Valida un oggetto R o una stringa JSON contro un validatore compilato
#'
#' @param x lista R (verrà serializzata) oppure stringa JSON
#' @param validator funzione ritornata da `compile_schema()`
#' @return lista con `valid` (logico) e `errors` (character vector, vuoto se valid)
#' @keywords internal
validate_json <- function(x, validator) {
  stopifnot(is.function(validator))
  json <- if (is.character(x) && length(x) == 1L) {
    x
  } else {
    jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null")
  }

  res <- validator(json, verbose = TRUE, greedy = TRUE)
  if (isTRUE(res)) {
    list(valid = TRUE, errors = character())
  } else {
    err_df <- attr(res, "errors")
    msgs <- if (is.data.frame(err_df) && nrow(err_df) > 0L) {
      vapply(seq_len(nrow(err_df)), function(i) {
        paste0(err_df$instancePath[i] %||% err_df$dataPath[i] %||% "",
               " ", err_df$message[i] %||% "(no message)")
      }, character(1))
    } else {
      "validation failed without structured errors"
    }
    list(valid = FALSE, errors = msgs)
  }
}

# Operatore null-coalescing privato (evita dipendenza da rlang::%||% pubblico)
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
```

- [ ] **Step 3.5: Installa il pacchetto in dev mode (per `system.file`)**

Run: `R -e 'devtools::load_all()'`
Expected: messaggio `Loading simulomicsr`. Nessun warning bloccante.

- [ ] **Step 3.6: Run test, verifica PASS**

Run: `R -e 'devtools::test(filter = "validate")'`
Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 4 ]`.

- [ ] **Step 3.7: Run TUTTI i test**

Run: `R -e 'devtools::test()'`
Expected: hash + cache + validate tutti pass.

- [ ] **Step 3.8: Commit**

```bash
git add R/validate.R inst/schemas/llm-call-envelope.v1.json tests/testthat/test-validate.R man/compile_schema.Rd man/validate_json.Rd NAMESPACE
git commit -m "P1 Task 3: validatore JSON Schema (jsonvalidate/Ajv) con schema envelope di test"
```

---

## Task 4: interfaccia LLM client astratta (`R/llm-client.R`)

L'interfaccia pubblica del pacchetto. Riceve provider/model/messages/schema, integra cache, dispatcha sull'adapter. In Task 5 collegheremo l'adapter OpenAI; qui creiamo un adapter `mock` per testare il dispatch in isolamento.

**Files:**
- Crea: `R/llm-client.R`
- Crea: `tests/testthat/test-llm-client.R`

- [ ] **Step 4.1: Scrivi i test fallenti**

File `tests/testthat/test-llm-client.R`:

```r
test_that("llm_call_structured chiama l'adapter del provider e ritorna il risultato parsed", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")

  res <- llm_call_structured(
    provider        = "mock",
    model           = "mock-1",
    messages        = list(list(role = "user", content = "ping")),
    response_schema = schema,
    cache           = NULL,
    .mock_response  = list(question = "ping", answer = "pong", confidence = 0.9)
  )

  expect_equal(res$value$answer, "pong")
  expect_equal(res$provider, "mock")
  expect_equal(res$model, "mock-1")
  expect_true(res$validated)
  expect_false(res$cache_hit)
})

test_that("llm_call_structured FALLISCE se la risposta non rispetta lo schema", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")

  expect_error(
    llm_call_structured(
      provider        = "mock",
      model           = "mock-1",
      messages        = list(list(role = "user", content = "ping")),
      response_schema = schema,
      cache           = NULL,
      .mock_response  = list(question = "ping", answer = "pong", confidence = 99) # > 1
    ),
    class = "simulomicsr_schema_error"
  )
})

test_that("llm_call_structured usa la cache: hit non chiama l'adapter", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  cache  <- cache_init(new_cache_dir(), namespace = "stage1")

  call_count <- 0L
  fake_adapter <- function(...) {
    call_count <<- call_count + 1L
    list(question = "ping", answer = "pong", confidence = 0.9)
  }

  args <- list(
    provider        = "mock",
    model           = "mock-1",
    messages        = list(list(role = "user", content = "ping")),
    response_schema = schema,
    cache           = cache,
    cache_namespace_version = "stage1.v3",
    .mock_adapter   = fake_adapter
  )

  r1 <- do.call(llm_call_structured, args)
  expect_false(r1$cache_hit)
  expect_equal(call_count, 1L)

  r2 <- do.call(llm_call_structured, args)
  expect_true(r2$cache_hit)
  expect_equal(call_count, 1L)  # adapter NON richiamato
  expect_equal(r2$value, r1$value)
})

test_that("llm_call_structured rifiuta provider sconosciuti con errore tipizzato", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  expect_error(
    llm_call_structured(
      provider = "ollama-not-supported",
      model    = "x",
      messages = list(list(role = "user", content = "?")),
      response_schema = schema
    ),
    class = "simulomicsr_unknown_provider"
  )
})
```

- [ ] **Step 4.2: Run test, verifica fallimento**

Run: `R -e 'devtools::test(filter = "llm-client")'`
Expected: FAIL — `could not find function "llm_call_structured"`.

- [ ] **Step 4.3: Implementa `R/llm-client.R`**

File `R/llm-client.R`:

```r
#' Chiama un LLM con output strutturato validato e cache opzionale
#'
#' Punto d'ingresso pubblico del client LLM. Dispatcha sul provider corretto,
#' valida la risposta contro `response_schema`, e (se `cache` è fornita)
#' serve dalla cache su hit.
#'
#' @param provider stringa: `"openai"` o `"mock"` (per i test). Altri provider
#'   in plan futuri.
#' @param model nome del modello (es. `"gpt-5.4-mini"`)
#' @param messages lista di messaggi nello schema OpenAI (`role` + `content`)
#' @param response_schema path a un file JSON Schema; la risposta dell'LLM
#'   viene validata contro questo schema
#' @param cache oggetto ritornato da `cache_init()`, o `NULL` per bypass
#' @param cache_namespace_version stringa che entra nella cache key (es.
#'   `"stage1.v3"`); cambiare questo invalida la cache
#' @param ... parametri provider-specifici inoltrati all'adapter
#' @param .mock_response (test only) risposta da iniettare se `provider="mock"`
#' @param .mock_adapter (test only) function da chiamare al posto dell'adapter
#'   reale; ha precedenza su `.mock_response`
#'
#' @return lista con: `value` (oggetto R parsed dal JSON), `provider`, `model`,
#'   `validated` (logico), `cache_hit` (logico), `raw_response` (lista grezza).
#' @export
llm_call_structured <- function(provider,
                                model,
                                messages,
                                response_schema,
                                cache = NULL,
                                cache_namespace_version = "v0",
                                ...,
                                .mock_response = NULL,
                                .mock_adapter  = NULL) {
  stopifnot(is.character(provider), length(provider) == 1L)
  stopifnot(is.character(model),    length(model)    == 1L)
  stopifnot(is.list(messages), length(messages) >= 1L)

  # 1) Compila lo schema una volta sola
  validator <- compile_schema(response_schema)

  # 2) Costruisci la cache key se la cache è attiva
  cache_key <- NULL
  if (!is.null(cache)) {
    payload <- jsonlite::toJSON(
      list(provider = provider, model = model, messages = messages),
      auto_unbox = TRUE
    )
    cache_key <- cache_key_for(cache_namespace_version, as.character(payload))

    if (cache_has(cache, cache_key)) {
      hit <- cache_get(cache, cache_key)
      return(list(
        value        = hit$value,
        provider     = provider,
        model        = model,
        validated    = TRUE,
        cache_hit    = TRUE,
        raw_response = hit$metadata$raw_response %||% NULL
      ))
    }
  }

  # 3) Dispatch
  raw <- if (!is.null(.mock_adapter)) {
    .mock_adapter(model = model, messages = messages, response_schema = response_schema, ...)
  } else if (provider == "mock") {
    if (is.null(.mock_response)) {
      rlang::abort(
        "provider='mock' richiede `.mock_response` o `.mock_adapter`",
        class = "simulomicsr_mock_error"
      )
    }
    .mock_response
  } else if (provider == "openai") {
    .openai_chat_structured(model = model, messages = messages,
                            response_schema = response_schema, ...)
  } else {
    rlang::abort(
      glue::glue("Provider sconosciuto: '{provider}'. Supportati: 'openai', 'mock'."),
      class = "simulomicsr_unknown_provider"
    )
  }

  # 4) Valida
  vres <- validate_json(raw, validator = validator)
  if (!vres$valid) {
    rlang::abort(
      glue::glue(
        "Risposta LLM NON conforme allo schema. Errori: {paste(vres$errors, collapse = ' | ')}"
      ),
      class = "simulomicsr_schema_error",
      errors = vres$errors,
      raw_response = raw
    )
  }

  # 5) Persisti in cache
  if (!is.null(cache)) {
    cache_put(cache, cache_key, value = raw,
              metadata = list(provider = provider, model = model))
  }

  list(
    value        = raw,
    provider     = provider,
    model        = model,
    validated    = TRUE,
    cache_hit    = FALSE,
    raw_response = raw
  )
}
```

- [ ] **Step 4.4: Run test, verifica PASS**

Run: `R -e 'devtools::load_all(); devtools::test(filter = "llm-client")'`
Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 4 ]`.

- [ ] **Step 4.5: Genera roxygen + verifica NAMESPACE export**

Run: `R -e 'devtools::document()'`

Verifica che `NAMESPACE` contenga `export(llm_call_structured)`.

Run: `grep llm_call_structured NAMESPACE`
Expected: una riga `export(llm_call_structured)`.

- [ ] **Step 4.6: Run TUTTI i test**

Run: `R -e 'devtools::test()'`
Expected: 19+ pass, 0 fail.

- [ ] **Step 4.7: Commit**

```bash
git add R/llm-client.R tests/testthat/test-llm-client.R man/llm_call_structured.Rd NAMESPACE
git commit -m "P1 Task 4: interfaccia llm_call_structured() con dispatch + cache + validation"
```

---

## Task 5: adapter OpenAI Structured Outputs (`R/llm-client-openai.R`)

L'adapter HTTP via `httr2`. Test isolati con `httptest2` (registrazione/replay di chiamate). NESSUNA chiamata reale in questa task: lo smoke E2E è in Task 7.

**Files:**
- Crea: `R/llm-client-openai.R`
- Crea: `tests/testthat/test-llm-client-openai.R`
- Crea: `tests/testthat/_httptest2/` (auto-popolata da httptest2)

- [ ] **Step 5.1: Scrivi i test fallenti con httptest2**

File `tests/testthat/test-llm-client-openai.R`:

```r
withr::local_envvar(OPENAI_API_KEY = "sk-fake-for-tests")

test_that(".openai_chat_structured costruisce request con body json_schema strict=true", {
  # Captura la request senza colpire la rete
  req <- .openai_build_request(
    model = "gpt-5.4-mini",
    messages = list(list(role = "user", content = "Say pong as JSON.")),
    response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
    schema_name = "llm_call_envelope_v1"
  )

  # url
  expect_match(req$url, "^https://api\\.openai\\.com/v1/chat/completions$")
  # auth header presente
  auth <- req$headers[["Authorization"]]
  expect_match(auth, "^Bearer sk-fake-for-tests$")

  # body
  body <- jsonlite::fromJSON(rawToChar(req$body$data), simplifyVector = FALSE)
  expect_equal(body$model, "gpt-5.4-mini")
  expect_equal(body$response_format$type, "json_schema")
  expect_true(isTRUE(body$response_format$json_schema$strict))
  expect_equal(body$response_format$json_schema$name, "llm_call_envelope_v1")
  expect_equal(body$messages[[1]]$role, "user")
})

test_that(".openai_chat_structured parsifica una risposta finta in oggetto R", {
  # Risposta OpenAI tipica: choices[[1]]$message$content è la stringa JSON
  fake_response <- list(
    choices = list(list(
      message = list(
        role = "assistant",
        content = '{"question":"ping","answer":"pong","confidence":0.9}'
      ),
      finish_reason = "stop"
    )),
    model = "gpt-5.4-mini-2026"
  )
  parsed <- .openai_parse_response(fake_response)

  expect_equal(parsed$question, "ping")
  expect_equal(parsed$answer,   "pong")
  expect_equal(parsed$confidence, 0.9)
})

test_that(".openai_parse_response solleva errore tipizzato se finish_reason != 'stop'", {
  bad <- list(
    choices = list(list(
      message = list(content = "{}"),
      finish_reason = "length"
    ))
  )
  expect_error(
    .openai_parse_response(bad),
    class = "simulomicsr_openai_truncated"
  )
})

test_that(".openai_parse_response solleva errore tipizzato se manca content", {
  bad <- list(choices = list(list(message = list(role = "assistant"), finish_reason = "stop")))
  expect_error(
    .openai_parse_response(bad),
    class = "simulomicsr_openai_no_content"
  )
})

test_that("missing OPENAI_API_KEY → errore tipizzato", {
  withr::local_envvar(OPENAI_API_KEY = "")
  expect_error(
    .openai_build_request(
      model = "gpt-5.4-mini",
      messages = list(list(role = "user", content = "x")),
      response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
      schema_name = "x"
    ),
    class = "simulomicsr_openai_missing_key"
  )
})
```

- [ ] **Step 5.2: Run test, verifica fallimento**

Run: `R -e 'devtools::test(filter = "llm-client-openai")'`
Expected: FAIL — `.openai_build_request` non esiste.

- [ ] **Step 5.3: Implementa `R/llm-client-openai.R`**

File `R/llm-client-openai.R`:

```r
# Endpoint costante
.OPENAI_CHAT_URL <- "https://api.openai.com/v1/chat/completions"

#' Costruisce (senza inviare) la `httr2` request per chat/completions con
#' Structured Outputs (strict json_schema).
#'
#' @keywords internal
.openai_build_request <- function(model,
                                  messages,
                                  response_schema,
                                  schema_name,
                                  temperature = 0,
                                  max_tokens = NULL,
                                  api_key = NULL) {
  api_key <- api_key %||% Sys.getenv("OPENAI_API_KEY", unset = "")
  if (!nzchar(api_key)) {
    rlang::abort(
      "OPENAI_API_KEY non impostata. Vedi `.Renviron.local` (gitignored) o `Sys.setenv()`.",
      class = "simulomicsr_openai_missing_key"
    )
  }

  schema_json <- jsonlite::fromJSON(
    readr::read_file(response_schema),
    simplifyVector = FALSE
  )

  body <- list(
    model = model,
    messages = messages,
    temperature = temperature,
    response_format = list(
      type = "json_schema",
      json_schema = list(
        name   = schema_name,
        strict = TRUE,
        schema = schema_json
      )
    )
  )
  if (!is.null(max_tokens)) body$max_tokens <- max_tokens

  httr2::request(.OPENAI_CHAT_URL) |>
    httr2::req_method("POST") |>
    httr2::req_headers(
      Authorization  = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ) |>
    httr2::req_body_raw(
      jsonlite::toJSON(body, auto_unbox = TRUE, null = "null"),
      type = "application/json"
    ) |>
    httr2::req_user_agent("simulomicsr (https://github.com/UBESP-DCTV/simulomicsr)") |>
    httr2::req_timeout(seconds = 120) |>
    httr2::req_retry(
      max_tries = 3L,
      backoff = function(i) min(60, 2 ^ i),
      is_transient = function(resp) {
        s <- httr2::resp_status(resp)
        s == 429L || s >= 500L
      }
    )
}

#' Estrae l'oggetto R dalla risposta OpenAI.
#'
#' Errori tipizzati:
#' - `simulomicsr_openai_truncated` se finish_reason != "stop"
#' - `simulomicsr_openai_no_content` se manca message.content
#' - `simulomicsr_openai_bad_json` se content non è JSON parsabile
#'
#' @keywords internal
.openai_parse_response <- function(resp_body) {
  stopifnot(is.list(resp_body), length(resp_body$choices) >= 1L)
  ch <- resp_body$choices[[1]]

  fr <- ch$finish_reason %||% "unknown"
  if (!identical(fr, "stop")) {
    rlang::abort(
      glue::glue("OpenAI ha terminato con finish_reason='{fr}', non 'stop'."),
      class = "simulomicsr_openai_truncated",
      finish_reason = fr
    )
  }

  content <- ch$message$content
  if (is.null(content) || !nzchar(content)) {
    rlang::abort(
      "Risposta OpenAI senza message.content.",
      class = "simulomicsr_openai_no_content"
    )
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(content, simplifyVector = TRUE),
    error = function(e) {
      rlang::abort(
        glue::glue("OpenAI ha ritornato content non-JSON: {conditionMessage(e)}"),
        class = "simulomicsr_openai_bad_json",
        raw_content = content
      )
    }
  )
  parsed
}

#' Esegue la chiamata HTTP completa e ritorna l'oggetto R parsed.
#'
#' Chiamato da `llm_call_structured()` quando `provider == "openai"`.
#'
#' @keywords internal
.openai_chat_structured <- function(model,
                                    messages,
                                    response_schema,
                                    schema_name = "response",
                                    temperature = 0,
                                    max_tokens = NULL,
                                    api_key = NULL,
                                    ...) {
  req <- .openai_build_request(
    model = model,
    messages = messages,
    response_schema = response_schema,
    schema_name = schema_name,
    temperature = temperature,
    max_tokens = max_tokens,
    api_key = api_key
  )
  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  .openai_parse_response(body)
}
```

- [ ] **Step 5.4: Run test, verifica PASS**

Run: `R -e 'devtools::load_all(); devtools::test(filter = "llm-client-openai")'`
Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 5 ]`.

- [ ] **Step 5.5: Aggiungi un test integrato dispatch→adapter senza HTTP**

Aggiungi al fondo di `tests/testthat/test-llm-client-openai.R`:

```r
test_that("llm_call_structured(provider='openai') intercetta tramite .mock_adapter", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  withr::local_envvar(OPENAI_API_KEY = "sk-fake")

  res <- llm_call_structured(
    provider = "openai",
    model = "gpt-5.4-mini",
    messages = list(list(role = "user", content = "Say pong.")),
    response_schema = schema,
    .mock_adapter = function(model, messages, response_schema, ...) {
      list(question = "Say pong.", answer = "pong", confidence = 0.95)
    }
  )

  expect_true(res$validated)
  expect_equal(res$value$answer, "pong")
})
```

Run: `R -e 'devtools::test(filter = "llm-client-openai")'`
Expected: 6 pass.

- [ ] **Step 5.6: Run TUTTI i test**

Run: `R -e 'devtools::test()'`
Expected: 25+ pass, 0 fail.

- [ ] **Step 5.7: Commit**

```bash
git add R/llm-client-openai.R tests/testthat/test-llm-client-openai.R
git commit -m "P1 Task 5: adapter OpenAI Structured Outputs (httr2) con errori tipizzati"
```

---

## Task 6: lookup minimal — `normalize_gene()` con dump HGNC

Strategia in P1: solo geni umani via dump HGNC TSV. La funzione carica dump on-demand in `tools::R_user_dir("simulomicsr", "cache")`. Per i test usiamo una fixture mini in `inst/extdata/` (no rete).

Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI: **fuori scope P1** — saranno argomento di un plan separato (`PX — lookup-extra`).

**Files:**
- Crea: `R/lookup.R`
- Crea: `inst/extdata/hgnc-fixture-mini.tsv`
- Crea: `tests/testthat/test-lookup.R`

- [ ] **Step 6.1: Crea la fixture HGNC mini**

File `inst/extdata/hgnc-fixture-mini.tsv` (TAB-separated, 11 righe inclusa header — formato semplificato dal dump ufficiale HGNC):

```
hgnc_id	symbol	name	alias_symbol	prev_symbol	status
HGNC:12680	VEGFA	vascular endothelial growth factor A	VEGF|VPF	VEGF	Approved
HGNC:1100	BRCA1	BRCA1 DNA repair associated		BRCC1|RNF53|PPP1R53	Approved
HGNC:1101	BRCA2	BRCA2 DNA repair associated	FACD|FAD|FAD1		Approved
HGNC:7794	MYC	MYC proto-oncogene, bHLH transcription factor	bHLHe39|MRTL	c-Myc	Approved
HGNC:11998	TP53	tumor protein p53	BCC7|LFS1|p53		Approved
HGNC:6407	KRAS	KRAS proto-oncogene, GTPase	C-K-RAS|K-RAS2A		Approved
HGNC:11138	SNCA	synuclein alpha	NACP|PARK1|PD1		Approved
HGNC:1001	BCL6	BCL6 transcription repressor	LAZ3|ZBTB27		Approved
HGNC:11892	TNF	tumor necrosis factor	DIF|TNF-alpha|TNFA|TNFSF2		Approved
HGNC:6018	IL6	interleukin 6	BSF2|HGF|HSF|IFNB2		Approved
```

- [ ] **Step 6.2: Scrivi i test fallenti**

File `tests/testthat/test-lookup.R`:

```r
test_that("normalize_gene risolve un symbol canonico human a HGNC ID", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("VEGFA", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:12680")
  expect_equal(res$preferred_name, "VEGFA")
  expect_equal(res$resolved_via, "symbol")
})

test_that("normalize_gene risolve un alias e segnala il path di risoluzione", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("VEGF", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:12680")
  expect_equal(res$preferred_name, "VEGFA")
  expect_equal(res$resolved_via, "alias_symbol")
})

test_that("normalize_gene risolve un prev_symbol", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("c-Myc", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:7794")
  expect_equal(res$resolved_via, "prev_symbol")
})

test_that("normalize_gene è case-insensitive ma preserva il preferred_name canonico", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("vegfa", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:12680")
  expect_equal(res$preferred_name, "VEGFA")
})

test_that("normalize_gene ritorna NULL su gene NON trovato (no allucinazione)", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("NOTAGENE", organism = "human", source_path = src)

  expect_null(res)
})

test_that("normalize_gene rifiuta organism diversi da 'human' in P1 con errore tipizzato", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  expect_error(
    normalize_gene("Brca1", organism = "mouse", source_path = src),
    class = "simulomicsr_lookup_unsupported_organism"
  )
})

test_that("hgnc_dump_path ritorna un path nella user cache dir e segnala se assente", {
  withr::local_envvar(R_USER_CACHE_DIR = tempfile())
  p <- hgnc_dump_path()
  expect_match(p, "simulomicsr.+hgnc_complete_set\\.tsv$")
  expect_false(fs::file_exists(p))  # non scarica nulla automaticamente
})
```

- [ ] **Step 6.3: Run test, verifica fallimento**

Run: `R -e 'devtools::test(filter = "lookup")'`
Expected: FAIL — `normalize_gene` non esiste.

- [ ] **Step 6.4: Implementa `R/lookup.R`**

File `R/lookup.R`:

```r
# Cache in-memory del dump HGNC (chiave = source_path)
.hgnc_cache <- new.env(parent = emptyenv())

#' Path canonico al dump HGNC nella cache utente
#'
#' Il dump completo si scarica da `https://www.genenames.org/download/archive/`
#' (nome file: `hgnc_complete_set.txt`, ~10 MB). In P1 NON scarichiamo
#' automaticamente: l'utente o il futuro plan di setup popola questo path.
#'
#' @return path (non garantito esistente)
#' @export
hgnc_dump_path <- function() {
  fs::path(tools::R_user_dir("simulomicsr", which = "cache"),
           "hgnc_complete_set.tsv")
}

#' Carica e indicizza il dump HGNC (TSV) in memoria
#' @keywords internal
.load_hgnc <- function(source_path) {
  if (!is.null(.hgnc_cache[[source_path]])) {
    return(.hgnc_cache[[source_path]])
  }
  stopifnot(fs::file_exists(source_path))

  raw <- readr::read_tsv(
    source_path,
    show_col_types = FALSE,
    progress = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )

  required <- c("hgnc_id", "symbol", "alias_symbol", "prev_symbol")
  missing  <- setdiff(required, names(raw))
  if (length(missing) > 0L) {
    rlang::abort(
      glue::glue("Dump HGNC manca colonne: {paste(missing, collapse = ', ')}"),
      class = "simulomicsr_lookup_bad_dump"
    )
  }

  raw$symbol_lower <- tolower(raw$symbol)

  # Aliases: split by `|` e long-format
  aliases <- raw[, c("hgnc_id", "symbol", "alias_symbol")]
  aliases <- aliases[!is.na(aliases$alias_symbol) & nzchar(aliases$alias_symbol), ]
  if (nrow(aliases) > 0L) {
    aliases <- do.call(rbind, lapply(seq_len(nrow(aliases)), function(i) {
      parts <- strsplit(aliases$alias_symbol[i], "|", fixed = TRUE)[[1]]
      data.frame(
        hgnc_id = aliases$hgnc_id[i],
        symbol  = aliases$symbol[i],
        alias   = parts,
        alias_lower = tolower(parts),
        stringsAsFactors = FALSE
      )
    }))
  } else {
    aliases <- data.frame(hgnc_id = character(), symbol = character(),
                          alias = character(), alias_lower = character())
  }

  prev <- raw[, c("hgnc_id", "symbol", "prev_symbol")]
  prev <- prev[!is.na(prev$prev_symbol) & nzchar(prev$prev_symbol), ]
  if (nrow(prev) > 0L) {
    prev <- do.call(rbind, lapply(seq_len(nrow(prev)), function(i) {
      parts <- strsplit(prev$prev_symbol[i], "|", fixed = TRUE)[[1]]
      data.frame(
        hgnc_id = prev$hgnc_id[i],
        symbol  = prev$symbol[i],
        prev    = parts,
        prev_lower = tolower(parts),
        stringsAsFactors = FALSE
      )
    }))
  } else {
    prev <- data.frame(hgnc_id = character(), symbol = character(),
                       prev = character(), prev_lower = character())
  }

  out <- list(symbols = raw, aliases = aliases, prev = prev)
  .hgnc_cache[[source_path]] <- out
  out
}

#' Normalizza un nome di gene human a un record canonico HGNC
#'
#' Strategia di matching (in ordine, primo match vince):
#' 1. `symbol` esatto case-insensitive
#' 2. `alias_symbol` esatto case-insensitive
#' 3. `prev_symbol` esatto case-insensitive
#'
#' @param name nome di gene da normalizzare (es. "VEGF", "vegfa", "c-Myc")
#' @param organism in P1 solo `"human"` è supportato
#' @param source_path path al dump HGNC TSV. Default: `hgnc_dump_path()`
#'
#' @return lista con `id`, `preferred_name`, `resolved_via`
#'   (`"symbol"|"alias_symbol"|"prev_symbol"`), oppure `NULL` se non trovato
#' @export
normalize_gene <- function(name,
                           organism = "human",
                           source_path = hgnc_dump_path()) {
  stopifnot(is.character(name), length(name) == 1L, !is.na(name), nzchar(name))

  if (!identical(organism, "human")) {
    rlang::abort(
      glue::glue("In P1 normalize_gene supporta solo organism='human', ricevuto '{organism}'."),
      class = "simulomicsr_lookup_unsupported_organism",
      organism = organism
    )
  }

  hgnc <- .load_hgnc(source_path)
  needle <- tolower(name)

  hit <- hgnc$symbols[hgnc$symbols$symbol_lower == needle, , drop = FALSE]
  if (nrow(hit) >= 1L) {
    return(list(
      id             = hit$hgnc_id[1],
      preferred_name = hit$symbol[1],
      resolved_via   = "symbol"
    ))
  }

  hit <- hgnc$aliases[hgnc$aliases$alias_lower == needle, , drop = FALSE]
  if (nrow(hit) >= 1L) {
    return(list(
      id             = hit$hgnc_id[1],
      preferred_name = hit$symbol[1],
      resolved_via   = "alias_symbol"
    ))
  }

  hit <- hgnc$prev[hgnc$prev$prev_lower == needle, , drop = FALSE]
  if (nrow(hit) >= 1L) {
    return(list(
      id             = hit$hgnc_id[1],
      preferred_name = hit$symbol[1],
      resolved_via   = "prev_symbol"
    ))
  }

  NULL
}
```

- [ ] **Step 6.5: Run test, verifica PASS**

Run: `R -e 'devtools::load_all(); devtools::test(filter = "lookup")'`
Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]`.

- [ ] **Step 6.6: Run TUTTI i test**

Run: `R -e 'devtools::test()'`
Expected: tutti pass.

- [ ] **Step 6.7: Genera roxygen**

Run: `R -e 'devtools::document()'`

- [ ] **Step 6.8: Commit**

```bash
git add R/lookup.R inst/extdata/hgnc-fixture-mini.tsv tests/testthat/test-lookup.R man/normalize_gene.Rd man/hgnc_dump_path.Rd NAMESPACE
git commit -m "P1 Task 6: normalize_gene() HGNC con symbol/alias/prev resolution + fixture mini"
```

---

## Task 7: smoke E2E reale (gated su `OPENAI_API_KEY`)

Una sola chiamata reale a OpenAI, skippata se la chiave manca. Verifica end-to-end: build request → HTTP → parse → schema validate → cache hit alla seconda chiamata.

**Files:**
- Crea: `tests/testthat/test-smoke-e2e.R`

- [ ] **Step 7.1: Scrivi il test smoke**

File `tests/testthat/test-smoke-e2e.R`:

```r
test_that("E2E reale: llm_call_structured contro OpenAI con cache", {
  skip_on_cran()
  skip_if(
    !nzchar(Sys.getenv("OPENAI_API_KEY")),
    "OPENAI_API_KEY non impostata, skip smoke E2E."
  )

  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  cache  <- cache_init(new_cache_dir(), namespace = "smoke")

  call_spec <- list(
    provider        = "openai",
    model           = "gpt-5.4-mini",
    messages        = list(
      list(role = "system",
           content = "Rispondi in JSON conforme allo schema. Tieni answer breve."),
      list(role = "user",
           content = "Domanda: 'qual è la capitale d'Italia?'. Rispondi e dichiara confidenza 0..1.")
    ),
    response_schema = schema,
    schema_name     = "llm_call_envelope_v1",
    cache           = cache,
    cache_namespace_version = "smoke.v1"
  )

  r1 <- do.call(llm_call_structured, call_spec)
  expect_true(r1$validated)
  expect_false(r1$cache_hit)
  expect_match(r1$value$answer, "roma", ignore.case = TRUE)
  expect_gte(r1$value$confidence, 0)
  expect_lte(r1$value$confidence, 1)

  r2 <- do.call(llm_call_structured, call_spec)
  expect_true(r2$cache_hit)
  expect_equal(r2$value, r1$value)
})
```

- [ ] **Step 7.2: Run test (skipped se KEY assente)**

Run senza KEY: `R -e 'devtools::test(filter = "smoke-e2e")'`
Expected: `[ FAIL 0 | WARN 0 | SKIP 1 | PASS 0 ]`.

- [ ] **Step 7.3: Run test CON chiave reale (azione manuale dell'utente)**

Da terminale (l'utente ha la chiave nella propria shell):

```bash
OPENAI_API_KEY="sk-..." R -e 'devtools::test(filter = "smoke-e2e")'
```

Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]` (7 = expectations dentro il `test_that`).

Se fallisce con HTTP 401 → la chiave non è valida; se fallisce con `simulomicsr_schema_error` → il modello non ha rispettato strict json_schema, allora aggiungere `temperature = 0` e ripetere; se fallisce con HTTP 404 sul model → `gpt-5.4-mini` non disponibile sull'account, sostituire con `gpt-4o-mini` come fallback (la spec accetta entrambi come "modello mini OpenAI", la decisione finale del modello è in ADR successivo).

**Se il modello `gpt-5.4-mini` non esiste sull'account dell'utente:** fare downgrade a `gpt-4o-mini` SOLO in questo test, lasciando `gpt-5.4-mini` come default documentato. Annotare in commit.

- [ ] **Step 7.4: Run TUTTI i test (con o senza KEY)**

Run: `R -e 'devtools::test()'`
Expected: 30+ pass, 0 fail, 0-1 skip.

- [ ] **Step 7.5: Commit**

```bash
git add tests/testthat/test-smoke-e2e.R
git commit -m "P1 Task 7: smoke E2E OpenAI (gated su OPENAI_API_KEY)"
```

---

## Task 8: documentazione (vignette + README + check pacchetto)

**Files:**
- Crea: `vignettes/01-llm-client.Rmd`
- Modifica: `README.Rmd`
- Modifica: `NEWS.md`

- [ ] **Step 8.1: Crea la vignette**

File `vignettes/01-llm-client.Rmd`:

````markdown
---
title: "01 — Client LLM strutturato"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{01 — Client LLM strutturato}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r, include = FALSE}
knitr::opts_chunk$set(eval = FALSE, collapse = TRUE, comment = "#>")
```

Questa vignette mostra come usare `llm_call_structured()` per ottenere
output JSON validato da un LLM, con cache locale.

## Setup

Imposta la chiave (in `.Renviron.local`, NON committata):

```r
Sys.setenv(OPENAI_API_KEY = "sk-...")
```

## Chiamata base

```{r}
library(simulomicsr)

schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")

res <- llm_call_structured(
  provider = "openai",
  model    = "gpt-5.4-mini",
  messages = list(
    list(role = "system", content = "Rispondi in JSON conforme allo schema."),
    list(role = "user",   content = "Capitale d'Italia, con confidence 0..1.")
  ),
  response_schema = schema,
  schema_name     = "llm_call_envelope_v1"
)

res$value
#> $question  ...
#> $answer    "Roma"
#> $confidence 0.99
```

## Cache locale

```{r}
cache <- cache_init("analysis/cache", namespace = "stage1")

res1 <- llm_call_structured(
  provider = "openai", model = "gpt-5.4-mini",
  messages = list(list(role = "user", content = "ping")),
  response_schema = schema,
  cache = cache,
  cache_namespace_version = "stage1.v3"
)
res1$cache_hit  # FALSE

res2 <- llm_call_structured(
  provider = "openai", model = "gpt-5.4-mini",
  messages = list(list(role = "user", content = "ping")),
  response_schema = schema,
  cache = cache,
  cache_namespace_version = "stage1.v3"
)
res2$cache_hit  # TRUE
```

## Normalizzazione gene HGNC

```{r}
normalize_gene("VEGF", organism = "human")
#> $id            "HGNC:12680"
#> $preferred_name "VEGFA"
#> $resolved_via  "alias_symbol"
```

In P1 il dump HGNC va piazzato manualmente in `tools::R_user_dir("simulomicsr", "cache")`
come `hgnc_complete_set.tsv`. Un futuro plan automatizzerà il download.
````

- [ ] **Step 8.2: Aggiorna `README.Rmd`**

Leggere prima `README.Rmd` esistente. Sostituire la sezione introduttiva (preservando la sintassi `pkgdown` e la sezione `output:`) per riflettere la visione attuale:

Aggiungere all'inizio della sezione di descrizione:

```markdown
## Stato

simulomicsr è una pipeline R per:

1. scaricare metadati di sample RNAseq da repository pubblici (GEO, ARCHS4)
2. classificarli via LLM in fatti strutturati a livello sample (Stadio 1)
3. ricostruire il design dello studio e i confronti meta-analizzabili (Stadio 2)
4. produrre tabelle di confronto cross-studio per `metafor` / `DESeq2` / `limma`

**Plan attivo (2026-04-29):** P1 — Infrastruttura LLM (cache, validator,
client OpenAI Structured Outputs, lookup gene HGNC).
Vedi `docs/superpowers/plans/`.

## Quickstart developer

```r
# 1) Restore environment
renv::restore()

# 2) Set OpenAI key (in .Renviron.local — gitignored)
# OPENAI_API_KEY=sk-...

# 3) Run tests
devtools::test()
```
```

Rigenerare il README.md:

Run: `R -e 'devtools::build_readme()'`
Expected: `README.md` aggiornato.

- [ ] **Step 8.3: Aggiorna `NEWS.md`**

In testa al file aggiungere:

```markdown
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
```

- [ ] **Step 8.4: Rigenera doc + R CMD check leggero**

Run: `R -e 'devtools::document()'`
Expected: nessun warning.

Run: `R -e 'devtools::check(args = "--no-manual", error_on = "error")'`
Expected: 0 errors. Warning accettabili (nessun warning critico). Note su URL ammesse.

- [ ] **Step 8.5: Commit finale**

```bash
git add vignettes/01-llm-client.Rmd README.Rmd README.md NEWS.md
git commit -m "P1 Task 8: vignette llm-client + README + NEWS aggiornati"
```

- [ ] **Step 8.6: Tag di completamento P1**

```bash
git tag -a p1-infra-llm-complete -m "P1 — infrastruttura LLM completa: client + cache + validator + HGNC lookup"
```

---

## Acceptance criteria di P1

P1 è completo quando TUTTE queste condizioni sono vere:

1. `devtools::test()` ritorna 0 fail (con `OPENAI_API_KEY` presente: 0 skip; senza: 1 skip).
2. `devtools::check(args = "--no-manual")` ritorna 0 errors.
3. Lo smoke E2E (Task 7) passa con chiave reale, e il secondo run hit cache.
4. La vignette `01-llm-client` builds senza errori (`devtools::build_vignettes()` o `pkgdown::build_site()` parziale).
5. `renv.lock` ha `R$Version >= 4.5.0`.
6. `git log --oneline` mostra 9 commit P1 (Task 0..8).
7. ADR-0004 esiste e è committato.
8. Le funzioni esportate sono almeno: `llm_call_structured`, `cache_init`, `cache_get`, `cache_put`, `cache_has`, `cache_stats`, `compile_schema`, `validate_json`, `normalize_gene`, `hgnc_dump_path`.

Cosa **non** è in P1 (per evitare scope creep):
- Schema `stage1.v3` JSON completo per i `sample_facts` — è P2
- Costruzione prompt LLM Stadio 1 — è P2
- Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI — plan separato
- Anchor generation `make_anchor()` — è P3
- GEO fetch — è P3
- Pipeline `analysis/_targets.R` reale — è P3
- Eval metrics vs xlsx gold — è P3

---

## Self-review (eseguito dall'autore del plan)

**1. Spec coverage di P1:**

| Sezione spec v5 | Coperta in P1? | Task |
|---|---|---|
| §5.1 — `R/llm-client.R` | Sì | Task 4-5 |
| §5.1 — `R/cache.R` | Sì | Task 2 |
| §5.1 — `R/validate.R` | Sì | Task 3 |
| §5.1 — `R/lookup.R` (parziale) | Sì, solo HGNC | Task 6 |
| §5.1 — `R/llm-stage1.R`, `llm-stage2.R`, `anchors.R`, `geo-fetch.R`, `eval-metrics.R` | NO — out of scope P1 | rinviati P2/P3 |
| §5.3.4 — astrazione client provider-agnostic | Sì | Task 4 |
| §5.3.2 — Structured Outputs (json_schema strict) | Sì | Task 5 |
| §5.4 — cache key con `schema_version` prefix | Sì | Task 1 |
| §9.A — vocabolari controllati: HGNC | Sì | Task 6 |
| §9.A — Cellosaurus/DrugBank/ChEMBL/MeSH/CAS/NCBITaxonomy/MGI | NO — plan separato | esplicito in §Acceptance |

**2. Placeholder scan:** zero "TBD" / "implementare in seguito" / "fill in details" nel plan. Ogni step ha codice eseguibile o comando concreto. Le uniche eccezioni esplicite sono i commenti nei file (es. "Cellosaurus/DrugBank... fuori scope P1") che sono documentazione di scope, non placeholder di lavoro.

**3. Type consistency:**
- `cache_init()` → ritorna oggetto `simulomicsr_cache` → consumato da `cache_get/put/has/stats` con `inherits()` check. Coerente.
- `compile_schema()` → ritorna closure → consumato da `validate_json(validator = ...)`. Coerente.
- `validate_json()` → ritorna `list(valid, errors)`. Usato in Task 4 con `vres$valid` e `vres$errors`. Coerente.
- `llm_call_structured()` → ritorna `list(value, provider, model, validated, cache_hit, raw_response)`. Tutti i test Task 4-5-7 usano questi nomi. Coerente.
- `normalize_gene()` → ritorna `list(id, preferred_name, resolved_via)` o `NULL`. Test in Task 6 e vignette in Task 8 coerenti.
- `cache_key_for(schema_version, payload)` (Task 1) → usato in `llm_call_structured` con `cache_key_for(cache_namespace_version, ...)`. Argomento posizionale, coerente.

Nessuna deriva di tipo rilevata.
