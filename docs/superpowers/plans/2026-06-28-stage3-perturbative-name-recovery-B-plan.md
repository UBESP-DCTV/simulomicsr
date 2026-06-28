# Recupero nomi farmaci con ChEMBL → Stadio 3 v5 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggiungere ChEMBL come 2ª sorgente di nomi-composto (oltre ChEBI) nel recupero identità dello Stadio 3, con estrazione tollerante al rumore, così da de-minestronare i cluster `small_molecule`; poi ri-clusterizzare (v5) e ri-poolare (Stadio 4 v5).

**Architecture:** Clone 1:1 del rework malattie/MeSH (loader → accessor → ramo composto di `recover_identity`), cambiando solo il DB (ChEMBL al posto di MeSH) e aggiungendo l'unico pezzo nuovo richiesto dai dati: l'estrazione del nome-farmaco da termini rumorosi (dose/tempo/combo). Risoluzione precisione-prima: ChEBI → ChEMBL → ri-mappa il `pref_name` ChEMBL su ChEBI (de-frammentazione) → CHEMBL nativo → STR.

**Tech Stack:** R, testthat (TDD), hash-environment per lookup O(1), DBI/RSQLite (già presenti sotto renv) per leggere il dump SQLite ChEMBL.

## Global Constraints

- Branch `review-scientific-consistency-2026-06-10`. **Master invariato, no push, no `--no-verify`, no `--no-gpg-sign`.**
- Commit italiani formato `P5 audit RED_ALERT F6: <azione>`. Commenti/docstring/messaggi in italiano. ASCII (`§`/`--`) nei roxygen.
- TDD bite-sized: test → fail → impl → pass → commit, per ogni task.
- Funzioni interne `@keywords internal` / `@noRd`; solo i veri entry point `@export`.
- **Nessuna nuova dipendenza R** (DBI/RSQLite/readr/data.table già presenti sotto renv).
- Comando test: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/<file>.R")'` (renv, **senza** `--vanilla` su questa macchina). Suite intera Stadio 3: `testthat::test_dir("tests/testthat", filter="stage3|ontology|anchor")`.
- **Gate precisione (C1):** un candidato emette un ID solo su match ESATTO di alias controllato, lunghezza ≥3, non puramente numerico. Niente fuzzy/substring.
- **Separatore combo = `+`** (l'anchor key splitta su `|` e `__VS__`, mai su `+` — verificato).
- Output pesanti su `/mnt/wwn-0x5000039d58caca35` (`/sda`, 4TB liberi), non su NVMe.
- Il fix df-residui Stadio 4 è **già committato** (`0c41848`) → il re-pool v5 non ri-crasha.

---

## File Structure

| File | Responsabilità | Task |
|---|---|---|
| `inst/extdata/ontology-fixtures-mini/chembl-mini.rds` | mini-fixture raw ChEMBL (test) | 1 |
| `analysis/p5-audit-chembl-mini-fixture.R` (nuovo) | genera la mini-fixture | 1 |
| `R/ontology-lookup.R` (modifica) | `.build_chembl_index` + accessor + wiring loader + release meta | 1 |
| `R/stage3-name-recovery.R` (modifica) | `.extract_compound_candidates` + `.resolve_one_compound` + estensione `.normalize_compound_to_chebi` | 2,3 |
| `R/stage3-name-recovery-lookup.R` (modifica) | bump cache version `v1`→`v2` | 4 |
| `analysis/p5-audit-chembl-build-dict.R` (nuovo) | dump SQLite reale → `cache/chembl/chembl-lookup.rds` | 5 |
| `tests/testthat/test-ontology-lookup.R` (modifica) | test ChEMBL index/accessor | 1 |
| `tests/testthat/test-stage3-name-recovery.R` (modifica) | test estrazione + risoluzione + integrazione | 2,3,4 |
| `analysis/p4-fase-f6-stage3-reclustering.R` (riuso) | re-cluster v5 (token v5) | 9 |
| `analysis/p4-fase-f5-stage4-layer-a-rebuild-v5.R` (nuovo, copia -v4) | re-pool v5 | 10 |
| `analysis/audit/stage3-homogeneity-check.R` (riuso) | re-gate v5 | 11 |

---

## FASE 1 — Codice (TDD, testato con mini-fixture, NESSUN run pesante)

### Task 1: Dizionario ChEMBL — mini-fixture + index + accessor + loader

**Files:**
- Create: `inst/extdata/ontology-fixtures-mini/chembl-mini.rds`
- Create: `analysis/p5-audit-chembl-mini-fixture.R`
- Modify: `R/ontology-lookup.R` (aggiungi `.build_chembl_index`, `.chembl_lookup_alias`, `.chembl_lookup_id`, wiring in `.load_ontology_dicts`, `chembl` in `.ontology_release_meta`)
- Test: `tests/testthat/test-ontology-lookup.R`

**Interfaces:**
- Produces:
  - `.build_chembl_index(chembl_raw) -> list(by_id=<env>, aliases=<env>, meta=<list>)`
  - `.chembl_lookup_alias(alias, env) -> list(chembl_id=chr, type=chr) | NULL`
  - `.chembl_lookup_id(chembl_id, env) -> list(chembl_id=chr, pref_name=chr) | NULL`
  - `.load_ontology_dicts(...)$chembl` popolato; mini-fixture `chembl-mini.rds` = `list(by_id=tibble(chembl_id,pref_name), aliases=tibble(alias_lower,chembl_id,type), meta=list(...))`
- Consumes: pattern esistente `.normalize_key_chr`, `.build_chebi_index`.

- [ ] **Step 1: Genera la mini-fixture ChEMBL**

Crea `analysis/p5-audit-chembl-mini-fixture.R`:

```r
# Mini-fixture ChEMBL per i test (raw, stessa forma di chebi-mini: by_id+aliases+meta).
# ID chembl illustrativi (fixture sintetica, fixture_subset=TRUE); la dict reale
# (analysis/p5-audit-chembl-build-dict.R) usa gli ID veri dal dump.
suppressPackageStartupMessages(library(tibble))
by_id <- tibble::tribble(
  ~chembl_id,        ~pref_name,
  "CHEMBL_ICOTINIB", "Icotinib",
  "CHEMBL_COBI",     "Cobimetinib",
  "CHEMBL_ENZA",     "Enzalutamide",
  "CHEMBL_ONVA",     "Onvansertib",
  "CHEMBL_DOX",      "Doxorubicin"
)
aliases <- tibble::tribble(
  ~alias_lower,    ~chembl_id,        ~type,
  "icotinib",      "CHEMBL_ICOTINIB", "SYNONYM",
  "bpi-2009h",     "CHEMBL_ICOTINIB", "RESEARCH_CODE",
  "cobimetinib",   "CHEMBL_COBI",     "SYNONYM",
  "gdc-0973",      "CHEMBL_COBI",     "RESEARCH_CODE",
  "gdc0973",       "CHEMBL_COBI",     "RESEARCH_CODE",
  "enzalutamide",  "CHEMBL_ENZA",     "SYNONYM",
  "mdv3100",       "CHEMBL_ENZA",     "RESEARCH_CODE",
  "onvansertib",   "CHEMBL_ONVA",     "SYNONYM",
  "nms-1286937",   "CHEMBL_ONVA",     "RESEARCH_CODE",
  "doxorubicin",   "CHEMBL_DOX",      "SYNONYM",
  "nsc-123127",    "CHEMBL_DOX",      "RESEARCH_CODE"
)
meta <- list(chembl_release = "ChEMBL_37 (fixture subset)",
             n_molecules = nrow(by_id), n_synonyms = nrow(aliases),
             fixture_subset = TRUE)
out <- file.path("inst", "extdata", "ontology-fixtures-mini", "chembl-mini.rds")
saveRDS(list(by_id = by_id, aliases = aliases, meta = meta), out)
cat("scritto:", out, "\n")
```

Esegui: `Rscript analysis/p5-audit-chembl-mini-fixture.R`
Atteso: `scritto: inst/extdata/ontology-fixtures-mini/chembl-mini.rds`

- [ ] **Step 2: Scrivi il test (FAIL atteso)**

In `tests/testthat/test-ontology-lookup.R`, in fondo:

```r
test_that(".load_ontology_dicts carica ChEMBL + accessor alias/id O(1)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_true(!is.null(env$chembl))
  # alias diretto -> molecola
  hit <- .chembl_lookup_alias("icotinib", env = env)
  expect_equal(hit$chembl_id, "CHEMBL_ICOTINIB")
  # case-insensitive
  expect_equal(.chembl_lookup_alias("ICOTINIB", env = env)$chembl_id, "CHEMBL_ICOTINIB")
  # research code -> stessa molecola
  expect_equal(.chembl_lookup_alias("gdc0973", env = env)$chembl_id, "CHEMBL_COBI")
  # by_id -> pref_name
  expect_equal(.chembl_lookup_id("CHEMBL_COBI", env = env)$pref_name, "Cobimetinib")
  # miss -> NULL
  expect_null(.chembl_lookup_alias("nonesiste_xyz", env = env))
  expect_null(.chembl_lookup_id("CHEMBL_ZZZ", env = env))
  # input degenere -> NULL (difensivo)
  expect_null(.chembl_lookup_alias(NA_character_, env = env))
  expect_null(.chembl_lookup_alias(character(0), env = env))
})

test_that(".ontology_release_meta include chembl", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  rel <- .ontology_release_meta(env)
  expect_true(!is.null(rel$chembl))
  expect_true(isTRUE(rel$chembl$fixture_subset))
})
```

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-ontology-lookup.R")'`
Atteso: FAIL (`env$chembl` NULL / `.chembl_lookup_alias` non trovata).

- [ ] **Step 3: Implementa index + accessor + wiring**

In `R/ontology-lookup.R`:

(a) dopo `.build_chebi_index`, aggiungi:

```r
#' @noRd
.build_chembl_index <- function(chembl_raw) {
  by_id_env <- new.env(hash = TRUE, parent = emptyenv(),
                       size = max(nrow(chembl_raw$by_id), 1L))
  if (nrow(chembl_raw$by_id) > 0L) {
    bi <- chembl_raw$by_id
    cid <- as.character(bi$chembl_id); pn <- bi$pref_name
    for (i in seq_along(cid)) {
      assign(cid[i], list(chembl_id = cid[i], pref_name = pn[i]), envir = by_id_env)
    }
  }
  aliases_env <- new.env(hash = TRUE, parent = emptyenv(),
                         size = max(nrow(chembl_raw$aliases), 1L))
  if (nrow(chembl_raw$aliases) > 0L) {
    al <- chembl_raw$aliases; keys <- al$alias_lower
    cids <- as.character(al$chembl_id); types <- al$type
    for (i in seq_along(keys)) {
      k <- keys[i]
      if (!exists(k, envir = aliases_env, inherits = FALSE)) {
        assign(k, list(chembl_id = cids[i], type = types[i]), envir = aliases_env)
      }
    }
  }
  list(by_id = by_id_env, aliases = aliases_env, meta = chembl_raw$meta)
}
```

(b) in `.load_ontology_dicts`, ramo fixture aggiungi:
```r
    chembl_raw <- readRDS(file.path(fixture_dir, "chembl-mini.rds"))
```
ramo reale aggiungi (dopo i path chebi/hgnc/mesh):
```r
    chembl_path <- file.path(cache_dir, "chembl", "chembl-lookup.rds")
    if (!file.exists(chembl_path)) {
      stop(sprintf(
        "ChEMBL dictionary missing at %s.\nRebuild via: Rscript analysis/p5-audit-chembl-build-dict.R",
        chembl_path))
    }
    chembl_raw <- readRDS(chembl_path)
```
e dopo `.ontology_env$mesh <- ...`:
```r
  .ontology_env$chembl <- .build_chembl_index(chembl_raw)
```

(c) accessor (dopo gli accessor ChEBI):
```r
#' @noRd
.chembl_lookup_alias <- function(alias, env = .load_ontology_dicts()) {
  raw <- .normalize_key_chr(alias)
  if (is.na(raw)) return(NULL)
  key <- tolower(raw)
  if (!exists(key, envir = env$chembl$aliases, inherits = FALSE)) return(NULL)
  get(key, envir = env$chembl$aliases, inherits = FALSE)
}

#' @noRd
.chembl_lookup_id <- function(chembl_id, env = .load_ontology_dicts()) {
  key <- .normalize_key_chr(chembl_id)
  if (is.na(key)) return(NULL)
  if (!exists(key, envir = env$chembl$by_id, inherits = FALSE)) return(NULL)
  get(key, envir = env$chembl$by_id, inherits = FALSE)
}
```

(d) in `.ontology_release_meta`, aggiungi `chembl = env$chembl$meta` alla list.

- [ ] **Step 4: Run test (PASS atteso)**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-ontology-lookup.R")'`
Atteso: tutti PASS (inclusi i test ChEBI/HGNC/MeSH preesistenti — nessuna regressione).

- [ ] **Step 5: Commit**

```bash
git add inst/extdata/ontology-fixtures-mini/chembl-mini.rds analysis/p5-audit-chembl-mini-fixture.R R/ontology-lookup.R tests/testthat/test-ontology-lookup.R
git commit -m "P5 audit RED_ALERT F6: dizionario ChEMBL (index + accessor + loader + mini-fixture)"
```

---

### Task 2: Estrazione tollerante — `.extract_compound_candidates`

**Files:**
- Modify: `R/stage3-name-recovery.R` (nuova `.extract_compound_candidates`)
- Test: `tests/testthat/test-stage3-name-recovery.R`

**Interfaces:**
- Produces: `.extract_compound_candidates(term) -> character()` (vettore ordinato di candidati: stringa intera, versione spogliata da dose/tempo, sotto-stringhe da split congiunzioni; dedup, ordine preservato).
- Consumes: nessuna (funzione pura).

- [ ] **Step 1: Scrivi il test (FAIL atteso)**

In `tests/testthat/test-stage3-name-recovery.R`:

```r
test_that(".extract_compound_candidates: termine pulito -> se stesso", {
  cs <- .extract_compound_candidates("icotinib")
  expect_true("icotinib" %in% cs)
})

test_that(".extract_compound_candidates: spoglia dose/tempo", {
  cs <- .extract_compound_candidates("osimertinib 2 um 9d")
  expect_true("osimertinib" %in% cs)
})

test_that(".extract_compound_candidates: combo -> sotto-candidati separati", {
  cs <- .extract_compound_candidates("10 um enzalutamide and 30 nm onvansertib")
  expect_true("enzalutamide" %in% cs)
  expect_true("onvansertib" %in% cs)
})

test_that(".extract_compound_candidates: nome con underscore/numero interno preservato intero", {
  cs <- .extract_compound_candidates("kj pyr 9")
  expect_true("kj pyr 9" %in% cs)   # la stringa intera resta un candidato
})

test_that(".extract_compound_candidates: name+code separati -> token singoli candidati", {
  cs <- .extract_compound_candidates("cobimetinib gdc0973")
  expect_true("cobimetinib gdc0973" %in% cs)  # frase intera
  expect_true("cobimetinib" %in% cs)          # token
  expect_true("gdc0973" %in% cs)              # token
})

test_that(".extract_compound_candidates: input vuoto/NA -> character(0)", {
  expect_length(.extract_compound_candidates(NA_character_), 0L)
  expect_length(.extract_compound_candidates(""), 0L)
})
```

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage3-name-recovery.R")'`
Atteso: FAIL (`.extract_compound_candidates` non definita).

- [ ] **Step 2: Implementa**

In `R/stage3-name-recovery.R` (prima di `.normalize_compound_to_chebi`):

```r
#' Estrae candidati-composto da un termine rumoroso (dose/tempo/combo).
#' Restituisce un vettore ordinato di stringhe da provare contro le ontologie.
#' Conservativo: prova prima la stringa intera (cosi' i nomi con separatori
#' interni come "kj pyr 9" non si frantumano), poi la versione spogliata da
#' dose/tempo, poi le sotto-stringhe spezzate sulle congiunzioni.
#' @keywords internal
.extract_compound_candidates <- function(term) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) return(character(0))
  base <- tolower(trimws(gsub("\\s+", " ", term)))
  cands <- base
  stripped <- base
  stripped <- gsub("\\b[0-9]+(\\.[0-9]+)?\\s*(µm|um|nm|mm|ng/?ml|ng|mg|ug|iu|u|m)\\b", " ", stripped, perl = TRUE)
  stripped <- gsub("\\bfor\\s+[0-9]+\\s*(h|hr|hrs|hours|d|days|min|minutes)\\b", " ", stripped, perl = TRUE)
  stripped <- gsub("\\b[0-9]+\\s*(h|hr|hrs|d|days|min)\\b", " ", stripped, perl = TRUE)
  stripped <- gsub("\\b(treated|treatment|exposed|exposure|stimulated|stimulation|condition|induction|induced|of)\\b", " ", stripped, perl = TRUE)
  stripped <- trimws(gsub("\\s+", " ", stripped))
  if (nzchar(stripped) && stripped != base) cands <- c(cands, stripped)
  # sotto-stringhe da congiunzioni (combo "A and B" / "A + B")
  parts <- unlist(strsplit(stripped, "\\s+(and|plus|with)\\s+|\\s*[+&]\\s*", perl = TRUE))
  parts <- trimws(gsub("\\s+", " ", parts))
  parts <- parts[nzchar(parts) & !(parts %in% c(base, stripped))]
  cands <- c(cands, parts)
  # token whitespace singoli (cattura name+code "cobimetinib gdc0973" e combo
  # separati da spazi). Il gate di precisione vive in .resolve_one_compound:
  # len>=3 + non-numerico + match esatto -> token spuri/corti/numerici non risolvono.
  toks <- unlist(strsplit(stripped, "\\s+"))
  toks <- trimws(toks)
  cands <- c(cands, toks[nzchar(toks)])
  unique(cands[nzchar(cands)])
}
```

- [ ] **Step 3: Run test (PASS atteso)**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage3-name-recovery.R")'`
Atteso: i 5 nuovi PASS + tutti i preesistenti PASS.

- [ ] **Step 4: Commit**

```bash
git add R/stage3-name-recovery.R tests/testthat/test-stage3-name-recovery.R
git commit -m "P5 audit RED_ALERT F6: estrazione candidati-composto tollerante a dose/tempo/combo"
```

---

### Task 3: Risoluzione composto con ChEMBL + de-frammentazione + combo

**Files:**
- Modify: `R/stage3-name-recovery.R` (nuova `.resolve_one_compound`, estensione `.normalize_compound_to_chebi`)
- Test: `tests/testthat/test-stage3-name-recovery.R`

**Interfaces:**
- Produces:
  - `.resolve_one_compound(cand, ontology_env) -> list(id, name, source) | NULL` (gate precisione + catena ChEBI→ChEMBL→ChEBI-via-pref_name→CHEMBL nativo).
  - `.normalize_compound_to_chebi(term, ontology_env) -> list(id, name, source)` esteso: 0 risolti→STR; 1→quell'ID; ≥2 distinti→combo `paste(sort(ids),collapse="+")`, source `COMPOUND_COMBO`.
- Consumes: `.extract_compound_candidates` (Task 2), `.chebi_lookup_alias`/`.chebi_lookup_id`/`.chembl_lookup_alias`/`.chembl_lookup_id` (Task 1), `.slugify`, `%||%`.

- [ ] **Step 1: Scrivi il test (FAIL atteso)**

In `tests/testthat/test-stage3-name-recovery.R`:

```r
.ont <- function() .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())

test_that(".normalize_compound_to_chebi: ChEBI diretto invariato (retrocompat)", {
  r <- .normalize_compound_to_chebi("doxorubicin", .ont())
  expect_equal(r$id, "CHEBI:28748")
  expect_equal(r$source, "CHEBI_ALIAS")
})

test_that(".normalize_compound_to_chebi: ChEMBL nativo per composto non-ChEBI", {
  r <- .normalize_compound_to_chebi("icotinib", .ont())
  expect_equal(r$id, "CHEMBL:CHEMBL_ICOTINIB")
  expect_equal(r$source, "CHEMBL_ALIAS")
})

test_that(".normalize_compound_to_chebi: de-frammentazione code->pref_name->ChEBI", {
  # 'nsc-123127' (codice) -> ChEMBL -> pref 'doxorubicin' -> ChEBI:28748
  r <- .normalize_compound_to_chebi("nsc-123127", .ont())
  expect_equal(r$id, "CHEBI:28748")
  expect_equal(r$source, "CHEMBL_VIA_CHEBI")
})

test_that(".normalize_compound_to_chebi: estrae nome da termine rumoroso (dose/tempo)", {
  r <- .normalize_compound_to_chebi("enzalutamide 10 um for 48 hours", .ont())
  expect_equal(r$id, "CHEMBL:CHEMBL_ENZA")
  expect_equal(r$source, "CHEMBL_ALIAS")
})

test_that(".normalize_compound_to_chebi: combo 2 farmaci -> ID-combo ordinato", {
  r <- .normalize_compound_to_chebi("10 um enzalutamide and 30 nm onvansertib", .ont())
  expect_equal(r$source, "COMPOUND_COMBO")
  expect_equal(r$id, "CHEMBL:CHEMBL_ENZA+CHEMBL:CHEMBL_ONVA")  # ordinato
  expect_true(grepl("\\+", r$id))
})

test_that(".normalize_compound_to_chebi: name+code stesso farmaco NON e' combo", {
  r <- .normalize_compound_to_chebi("cobimetinib gdc0973", .ont())
  # entrambi -> CHEMBL_COBI -> 1 solo id distinto
  expect_false(identical(r$source, "COMPOUND_COMBO"))
  expect_equal(r$id, "CHEMBL:CHEMBL_COBI")
})

test_that(".normalize_compound_to_chebi: canary precisione - numeri/token corti -> STR", {
  expect_equal(.normalize_compound_to_chebi("10 nm 1", .ont())$source, "STR_FALLBACK")
  expect_equal(.normalize_compound_to_chebi("1 so", .ont())$source, "STR_FALLBACK")
})
```

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage3-name-recovery.R")'`
Atteso: FAIL (catena ChEMBL/combo non implementata; `icotinib` oggi darebbe STR).

- [ ] **Step 2: Implementa**

In `R/stage3-name-recovery.R`, SOSTITUISCI il corpo di `.normalize_compound_to_chebi` e aggiungi `.resolve_one_compound`:

```r
#' Risolve UN candidato-composto: gate precisione + catena ChEBI -> ChEMBL ->
#' ChEBI-via-pref_name (de-frammentazione) -> CHEMBL nativo. NULL se non risolve.
#' @keywords internal
.resolve_one_compound <- function(cand, ontology_env) {
  c2 <- trimws(cand)
  alnum <- gsub("[^a-z0-9]", "", tolower(c2))
  if (nchar(alnum) < 3L) return(NULL)            # gate: troppo corto
  if (grepl("^[0-9]+$", alnum)) return(NULL)     # gate: puramente numerico
  # 1. ChEBI diretto
  hit <- .chebi_lookup_alias(c2, env = ontology_env)
  if (!is.null(hit) && !is.null(hit$chebi_id)) {
    full <- .chebi_lookup_id(hit$chebi_id, env = ontology_env)
    return(list(id = paste0("CHEBI:", hit$chebi_id),
                name = if (!is.null(full) && !is.null(full$primary_name)) full$primary_name else c2,
                source = "CHEBI_ALIAS"))
  }
  # 2. ChEMBL -> pref_name -> ChEBI (de-frag) oppure CHEMBL nativo
  ch <- .chembl_lookup_alias(c2, env = ontology_env)
  if (!is.null(ch) && !is.null(ch$chembl_id)) {
    mol  <- .chembl_lookup_id(ch$chembl_id, env = ontology_env)
    pref <- if (!is.null(mol) && !is.null(mol$pref_name)) mol$pref_name else NA_character_
    if (!is.na(pref) && nzchar(pref)) {
      chebi2 <- .chebi_lookup_alias(pref, env = ontology_env)
      if (!is.null(chebi2) && !is.null(chebi2$chebi_id)) {
        full <- .chebi_lookup_id(chebi2$chebi_id, env = ontology_env)
        return(list(id = paste0("CHEBI:", chebi2$chebi_id),
                    name = if (!is.null(full) && !is.null(full$primary_name)) full$primary_name else pref,
                    source = "CHEMBL_VIA_CHEBI"))
      }
    }
    return(list(id = paste0("CHEMBL:", ch$chembl_id),
                name = pref %||% c2, source = "CHEMBL_ALIAS"))
  }
  NULL
}

#' (riscritta) Normalizza un termine-composto a ChEBI/ChEMBL (o STR/combo).
#' @keywords internal
.normalize_compound_to_chebi <- function(term, ontology_env) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) {
    return(list(id = NA_character_, name = NA_character_, source = "NO_TERM"))
  }
  cands <- .extract_compound_candidates(term)
  resolved <- list()
  for (cand in cands) {
    r <- .resolve_one_compound(cand, ontology_env)
    if (!is.null(r)) resolved[[r$id]] <- r   # dedup per id
  }
  ids <- names(resolved)
  if (length(ids) == 0L) {
    return(list(id = paste0("STR:", .slugify(term)), name = term, source = "STR_FALLBACK"))
  }
  if (length(ids) == 1L) {
    r <- resolved[[1L]]
    return(list(id = r$id, name = r$name, source = r$source))
  }
  ord <- sort(ids)
  list(id     = paste(ord, collapse = "+"),
       name   = paste(vapply(ord, function(i) resolved[[i]]$name %||% i, character(1)), collapse = " + "),
       source = "COMPOUND_COMBO")
}
```

- [ ] **Step 3: Run test (PASS atteso)**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage3-name-recovery.R")'`
Atteso: tutti PASS (nuovi + preesistenti).

- [ ] **Step 4: Commit**

```bash
git add R/stage3-name-recovery.R tests/testthat/test-stage3-name-recovery.R
git commit -m "P5 audit RED_ALERT F6: risoluzione composto ChEMBL + de-frammentazione + combo"
```

---

### Task 4: Integrazione `recover_identity` + bump cache + anchor round-trip

**Files:**
- Modify: `R/stage3-name-recovery-lookup.R:11` (`.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` `"v1"`→`"v2"`)
- Test: `tests/testthat/test-stage3-name-recovery.R`, `tests/testthat/test-stage3-anchor-name-recovery.R`

**Interfaces:**
- Consumes: `recover_identity(source, characteristics, title, llm_kind, ontology_env)` (invariato nello scheletro; ramo perturbativo ora eredita ChEMBL/combo via `.normalize_compound_to_chebi`).
- Produces: nessuna nuova firma; nuovi valori `recovery_source` ∈ {`CHEBI_ALIAS`,`CHEMBL_VIA_CHEBI`,`CHEMBL_ALIAS`,`COMPOUND_COMBO`,`STR_FALLBACK`,`NO_RECOVERY`}.

- [ ] **Step 1: Scrivi il test (FAIL atteso per cache version + integrazione)**

In `tests/testthat/test-stage3-name-recovery.R`:

```r
test_that("recover_identity: ramo composto usa ChEMBL (integrazione)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  r <- recover_identity("cells", "treatment: icotinib, time: 24h", "rep1",
                        "small_molecule", env)
  expect_equal(r$agent_id, "CHEMBL:CHEMBL_ICOTINIB")
  expect_equal(r$recovery_source, "CHEMBL_ALIAS")
  expect_equal(r$kind, "small_molecule")
})

test_that("recover_identity: combo via metadati", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  r <- recover_identity("cells",
        "treatment: 10 um enzalutamide and 30 nm onvansertib", "rep1",
        "small_molecule", env)
  expect_equal(r$recovery_source, "COMPOUND_COMBO")
  expect_true(grepl("\\+", r$agent_id))
})

test_that("recover_identity: malattia/genetico INVARIATI (retrocompat)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  rd <- recover_identity("Blood", "disease: ethanol", "x", "disease_vs_normal", env)
  expect_equal(rd$kind, "disease_vs_normal")  # ramo disease, non composto
  rg <- recover_identity("HCT116", "cell line: HCT116", "XRN2-dTAG rep1",
                         "small_molecule", env)
  expect_match(rg$kind, "genetic_")           # K2 ancora prevale
})

test_that("cache version bumpata a v2 (invalida lookup v4)", {
  expect_equal(.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION, "v2")
})
```

In `tests/testthat/test-stage3-anchor-name-recovery.R` (round-trip separatore combo):

```r
test_that("anchor key con agent_id combo round-trip: split su '|' integro", {
  ak <- "small_molecule|CHEBI:111+CHEBI:222|none|none|none"
  segs <- strsplit(ak, "|", fixed = TRUE)[[1L]]
  expect_equal(segs[2L], "CHEBI:111+CHEBI:222")  # il '+' non e' separatore
  expect_length(segs, 5L)
})
```

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage3-name-recovery.R"); testthat::test_file("tests/testthat/test-stage3-anchor-name-recovery.R")'`
Atteso: FAIL sul test cache version (ancora "v1").

- [ ] **Step 2: Bump cache version**

In `R/stage3-name-recovery-lookup.R:11`:
```r
.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION <- "v2"
```

- [ ] **Step 3: Run test (PASS atteso)**

Run: come Step 1.
Atteso: tutti PASS. (L'integrazione `recover_identity` passa già grazie a Task 3; il bump chiude il test cache.)

- [ ] **Step 4: Suite intera Stadio 3 — nessuna regressione**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_dir("tests/testthat", filter="stage3|ontology|anchor")'`
Atteso: 0 FAIL. (Atteso ~ suite 283 + nuovi test ChEMBL.)

- [ ] **Step 5: Rigenera Rd + Commit**

```bash
Rscript -e 'devtools::document()'
git add R/stage3-name-recovery-lookup.R tests/testthat/test-stage3-name-recovery.R tests/testthat/test-stage3-anchor-name-recovery.R man/ NAMESPACE
git commit -m "P5 audit RED_ALERT F6: integra ChEMBL in recover_identity + bump cache lookup v2 + anchor combo round-trip"
```

---

### Task 5: Script build dizionario ChEMBL reale (codice, NON eseguito qui)

**Files:**
- Create: `analysis/p5-audit-chembl-build-dict.R`

**Interfaces:**
- Produces: file `cache/chembl/chembl-lookup.rds` = `list(by_id=tibble(chembl_id,pref_name), aliases=tibble(alias_lower,chembl_id,type), meta=list(...))` — stessa forma della mini-fixture, consumato da `.load_ontology_dicts` (ramo reale, Task 1).
- Consumes: dump SQLite ChEMBL estratto (path via env `CHEMBL_SQLITE`); DBI/RSQLite.

- [ ] **Step 1: Scrivi lo script**

```r
# analysis/p5-audit-chembl-build-dict.R
# Build dizionario ChEMBL nome->ID (clone di p5-audit-chebi-build-dict.R).
# Input:  dump SQLite ChEMBL estratto (env CHEMBL_SQLITE = path al .db).
# Output: cache/chembl/chembl-lookup.rds (by_id + aliases + meta).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(DBI); library(dplyr); library(tibble); library(cli) })

db_path <- Sys.getenv("CHEMBL_SQLITE", "")
stopifnot("env CHEMBL_SQLITE non impostata" = nzchar(db_path), file.exists(db_path))
out_dir <- file.path(tools::R_user_dir("simulomicsr","cache"), "chembl")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cli_h1("ChEMBL lookup dictionary build")
con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
on.exit(DBI::dbDisconnect(con), add = TRUE)

cli_alert_info("molecule_dictionary ...")
md <- DBI::dbGetQuery(con,
  "SELECT molregno, chembl_id, pref_name FROM molecule_dictionary WHERE pref_name IS NOT NULL")
cli_alert_success(sprintf("molecole con pref_name: %d", nrow(md)))

cli_alert_info("molecule_synonyms ...")
syn <- DBI::dbGetQuery(con,
  "SELECT molregno, synonyms, syn_type FROM molecule_synonyms WHERE synonyms IS NOT NULL")

by_id <- md |>
  transmute(chembl_id = chembl_id, pref_name = pref_name) |>
  filter(!is.na(chembl_id), !is.na(pref_name)) |>
  distinct(chembl_id, .keep_all = TRUE)

mol2chembl <- md |> select(molregno, chembl_id)
# aliases = sinonimi + pref_name, lowercased, joinati su chembl_id
syn_al <- syn |>
  inner_join(mol2chembl, by = "molregno") |>
  transmute(alias_lower = tolower(trimws(synonyms)), chembl_id, type = syn_type)
pref_al <- by_id |>
  transmute(alias_lower = tolower(trimws(pref_name)), chembl_id, type = "PREF_NAME")
aliases <- bind_rows(pref_al, syn_al) |>
  filter(nzchar(alias_lower)) |>
  distinct(alias_lower, chembl_id, .keep_all = TRUE)

meta <- list(
  chembl_release = basename(db_path),
  built_at = Sys.time(),
  n_molecules = nrow(by_id),
  n_synonyms = nrow(aliases),
  fixture_subset = FALSE
)
out <- file.path(out_dir, "chembl-lookup.rds")
saveRDS(list(by_id = by_id, aliases = aliases, meta = meta), out)
cli_alert_success(sprintf("scritto %s (by_id=%d, aliases=%d)", out, nrow(by_id), nrow(aliases)))
```

- [ ] **Step 2: Lint sintattico (NON esegue le query)**

Run: `Rscript -e 'invisible(parse("analysis/p5-audit-chembl-build-dict.R")); cat("parse OK\n")'`
Atteso: `parse OK`.

- [ ] **Step 3: Commit**

```bash
git add analysis/p5-audit-chembl-build-dict.R
git commit -m "P5 audit RED_ALERT F6: script build dizionario ChEMBL reale (SQLite -> rds)"
```

---

## FASE 2 — RUN GATED (gate utente per ogni run pesante; NON TDD)

> Ogni task qui sotto è un **gate utente**: l'agente prepara/lancia e si ferma a riportare. Run pesanti detached (`setsid nohup`), monitoraggio orario session-only.

### Task 6 (GATED): Scarica + costruisci il dizionario ChEMBL reale

- [ ] Download su `/sda`: `wget -c https://ftp.ebi.ac.uk/pub/databases/chembl/ChEMBLdb/latest/chembl_37_sqlite.tar.gz` (5.4G). Registra SHA256 + URL (provenienza paper-grade).
- [ ] Estrai il `.tar.gz` su `/sda` (~25G) → individua `chembl_37/chembl_37_sqlite/chembl_37.db`.
- [ ] `CHEMBL_SQLITE=/sda/.../chembl_37.db Rscript analysis/p5-audit-chembl-build-dict.R` → `cache/chembl/chembl-lookup.rds`.
- [ ] **Verifica**: `.load_ontology_dicts(refresh=TRUE)` non-fixture carica chembl; spot-check 5 alias noti (cobimetinib, gdc-0973, icotinib, enzalutamide, osimertinib) risolvono. Poi **scarta il `.db` da 25G**.
- [ ] (Opzionale, paper-grade) Rigenera `chembl-mini.rds` come subset REALE del dump (sostituendo gli ID illustrativi con quelli veri) e ri-gira i test Task 1-4: devono restare verdi. Commit fixture aggiornata se rigenerata.

### Task 7 (GATED): Smoke di copertura PRE-fullrun (validate-before-fullrun)

- [ ] Script scratchpad: campiona gli STR perturbativi del gate v4 (`stage3-homogeneity-check-v4-full-out.csv`), per ciascuno ricostruisci il `term` dai metadati H5 e gira `recover_identity` con la dict reale. Misura: % recuperati via ChEMBL/de-frag, # combo, **0 falsi sui canary** (`10_nm_1`, numeri, token <3).
- [ ] **Gate**: recupero atteso ≫0 sui ~265 nomi-farmaco; nessun match spurio. Riporta la tabella all'utente PRIMA del re-cluster da 6h. Se deludente → rivedere `.extract_compound_candidates` (NON lanciare il fullrun).

> **AMENDMENT 2026-06-28 (loader graceful, commit 83e1238):** il loader NON fa più `stop()`
> se ChEMBL manca — carica `chembl=NULL` + `has_chembl=FALSE` (retrocompat v4). Il fail-loud è
> spostato QUI: prima di girare il re-cluster/re-pool v5, **assertire** che ChEMBL sia caricato,
> altrimenti si produrrebbe v5 in qualità-v4 silenziosamente.

### Task 8 (GATED): Re-cluster Stadio 3 → v5

- [ ] **Assert ChEMBL caricato (fail-loud):** all'inizio dello script, dopo aver costruito/caricato
      le ontologie, `stopifnot("ChEMBL dict mancante: esegui Task 6" = isTRUE(.load_ontology_dicts()$has_chembl))`.
- [ ] Pre-flight: input 5/5 presenti, dict ChEMBL caricabile (`has_chembl=TRUE`), env R OK (`Rscript` semplice).
- [ ] `SMOKE=1 Rscript analysis/p4-fase-f6-stage3-reclustering.R` (smoke ~2-3 min) → sanity scomposizione.
- [ ] **GATE UTENTE** → `SMOKE=0 Rscript analysis/p4-fase-f6-stage3-reclustering.R` detached (~6h). Output `…-stage3-v5-<id>/` (token v5). Verifica `run_metadata` registra `ontology_releases$chembl` + cache lookup `v2`.
- [ ] Sanity: `agent_id_resolved` mostra CHEMBL:/CHEBI: nuovi; `small_molecule|UNK` scomposto.

### Task 9 (GATED): Re-pool Stadio 4 → v5

- [ ] **Assert ChEMBL caricato** anche qui se lo script ricarica l'ontologia (`stopifnot(... has_chembl ...)`), per coerenza fail-loud.
- [ ] Crea `analysis/p4-fase-f5-stage4-layer-a-rebuild-v5.R` = copia del `-v4` con `stage3_dir`→dir v5 + token output `v5`. Output su `/sda`.
- [ ] Smoke gate pre-fullrun (pattern F5): poche cluster, gene axis Ensembl OK.
- [ ] **GATE UTENTE** → run detached (~11h). Verifica exit pulito (il fix df-residui `0c41848` regge). Backup protettivo su `/sda`.

### Task 10 (GATED): Re-gate omogeneità v5 + closeout

- [ ] `Rscript analysis/audit/stage3-homogeneity-check.R <dir-v5> <h5> Inf Inf <stage2-master-v3>` → confronto apples-to-apples v4→v5.
- [ ] **Criterio**: `small_molecule` scende nettamente sotto il 49% v4; gli altri kind perturbativi non peggiorano. Riporta la tabella v4→v5.
- [ ] Closeout: aggiorna `CLAUDE.md` + `docs/RED_ALERT.md` + `.superpowers/sdd/progress.md` + memoria `[[project_stage3_minestrone_rework]]`. Commit doc.

---

## Self-Review (esito)

- **Spec coverage**: §3.1 acquisizione→Task 5/6; §3.2 loader/accessor→Task 1; §3.3 risoluzione+de-frag+combo→Task 3; §3.4 estrazione→Task 2; §3.5 lookup/cache→Task 4; §3.6 cascata→Task 8/9/10; §5 validazione (canary+smoke copertura)→Task 3/7; §8 TODO biologici→registrato nel closeout. ✓
- **Placeholder scan**: nessun TBD; ogni step ha codice/comando reale. ✓
- **Type consistency**: `.chembl_lookup_alias`→`{chembl_id,type}`, `.chembl_lookup_id`→`{chembl_id,pref_name}`, `.resolve_one_compound`→`{id,name,source}|NULL`, `.normalize_compound_to_chebi`→`{id,name,source}` coerenti tra Task 1/3/4. Separatore combo `+` coerente (Task 3 impl, Task 4 round-trip). ✓
- **Rischio noto**: la mini-fixture usa ID `CHEMBL_*` illustrativi; i test asseriscono quei valori. Task 6 step opzionale rigenera la fixture dal dump reale (allora gli `expect_equal` sugli ID vanno aggiornati ai valori veri, oppure restare con la fixture sintetica e asserire solo prefisso/source). Annotato.
