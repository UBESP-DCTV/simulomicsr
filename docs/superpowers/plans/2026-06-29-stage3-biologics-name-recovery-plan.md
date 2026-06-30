# Recupero-nome BIOLOGICI (citochine + patogeni) → Stadio 3 v6 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dare un ID canonico deterministico alle menzioni di citochine (→`HGNC:n`) e patogeni (→`NCBITaxon:taxid`), con confine PAMP (→`CHEBI:n`) e fix-tipo K3, per de-minestronare i kind `cytokine_stim` (61%) e `pathogen` (33%) in uno Stadio 3 v6.

**Architecture:** Clone del pattern `ontology-lookup` esistente (ChEMBL/MeSH): una fonte = un `.build_*_index` + accessor O(1) hash-env + flag `has_*` graceful nel loader. Estrazione+risoluzione clonano `.resolve_one_compound`/`.normalize_compound_to_chebi`. K3 esteso dentro `recover_identity` (dove vive il K2) + innesto in `.extract_anchor_segments`. Catena run gated identica alla sessione 21 (build → smoke → re-cluster → re-pool → re-gate).

**Tech Stack:** R, testthat, hash-environment (O(1) lookup), readxl (build ImmPort xls), jsonlite (API ImmPort), digest (cache key), rhdf5 (lookup GSM→identità).

## Global Constraints

- **Italiano** in commenti/docstring/messaggi-commit/error-message. ASCII per accentate nei Rd roxygen (`§`→`sec.`, `—`→`--`).
- Funzioni interne `@keywords internal`/`@noRd`; solo i veri entry-point `@export`.
- **TDD bite-sized** (test→fail→impl→pass→commit) per ogni step.
- **Retrocompat byte-identica**: ogni nuovo flag/parametro default `NULL`/`FALSE`; nessuna regressione su disease/genetico/compound.
- **ID canonici**: citochina `HGNC:<symbol>`, organismo `NCBITaxon:<taxid>`, PAMP `CHEBI:<int>`, fallback `STR:<slug>`.
- **Precision-first**: meglio `STR:`/NO_RECOVERY che un merge a bassa confidenza. Stoplist anti-generici + gate whitelist obbligatori.
- **No push** salvo richiesta esplicita; master invariato; branch `review-scientific-consistency-2026-06-10`.
- **BASE commit (pre-Task-1):** `4ac57e8`.
- **Normalizzazione canonica condivisa**: le chiavi dei NUOVI dizionari (taxonomy/immport/uniprot) si costruiscono al build con `.normalize_biological_mention()`; a runtime la menzione passa per la STESSA funzione → match canonico. HGNC esistente resta interrogato con la sua convenzione (`tolower`).

---

## File Structure

**Modify:**
- `R/ontology-lookup.R` — +`.build_taxonomy_index`/`.build_immport_index`/`.build_uniprot_index`, +accessor, +flag `has_taxonomy`/`has_immport`/`has_uniprot`/`has_go_cytokine` in `.load_ontology_dicts`, +`.ontology_release_meta`.
- `R/stage3-name-recovery.R` — +`.normalize_biological_mention`, +`.GENERIC_BIOLOGICAL_STOPLIST`, +`.normalize_cytokine_to_hgnc`, +`.PAMP_WHITELIST`/`.resolve_pamp`, +`.normalize_pathogen_to_taxid`, +`.detect_biological_mistype` (K3), dispatch in `recover_identity`.
- `R/stage3-anchor-levels.R` — innesto `recovery` (b) esteso ai kind biologici (oggi solo `genetic_`).
- `R/stage3-name-recovery-lookup.R` — cache key bump `v2→v3` + `biologics_axis`.
- `DESCRIPTION` — `readxl` in Suggests (build ImmPort).

**Create (R):** nessun nuovo file R (tutto nei moduli esistenti, coerenza pattern).

**Create (build scripts, gated):** `analysis/p5-audit-taxonomy-build-dict.R`, `analysis/p5-audit-go-cytokine-build-dict.R`, `analysis/p5-audit-immport-build-dict.R`, `analysis/p5-audit-uniprot-build-dict.R`.

**Create (run scripts):** `analysis/p4-fase-f5-stage4-layer-a-rebuild-v6.R` (copia -v5, 4 cambi). Modify `analysis/p4-fase-f6-stage3-reclustering.R` (assert nuovi flag + token v6).

**Create (fixtures):** `inst/extdata/ontology-fixtures-mini/{taxonomy,immport,uniprot}-mini.rds`.

**Test:** `tests/testthat/test-ontology-lookup-biologics.R`, `test-stage3-name-recovery-biologics.R`, `test-stage3-anchor-biologics.R`, delta su `test-anchor-parse.R` + `test-stage3-name-recovery-lookup.R`.

---

# FASE 1 — Dizionari, accessor, loader (R/ontology-lookup.R)

### Task 1: Indice + accessor NCBI Taxonomy

**Files:**
- Modify: `R/ontology-lookup.R` (dopo `.build_chembl_index`)
- Create: `inst/extdata/ontology-fixtures-mini/taxonomy-mini.rds`
- Test: `tests/testthat/test-ontology-lookup-biologics.R`

**Interfaces:**
- Consumes: pattern `.build_chembl_index` (`ontology-lookup.R:336`), `new.env(hash=TRUE, parent=emptyenv())`, `.normalize_key_chr` (`:380`).
- Produces:
  - `.build_taxonomy_index(taxonomy_raw)` → `list(by_name=<env>, by_taxid=<env>, meta=<list>)`. Raw: `taxonomy_raw$names` cols `name_norm,taxid,name_class`; `taxonomy_raw$nodes` cols `taxid,parent_taxid,rank`; `taxonomy_raw$meta` (as-is).
  - `.taxonomy_lookup_name(term, env=.load_ontology_dicts())` → `list(taxid,scientific_name,name_class)` o `NULL`.
  - `.taxonomy_rollup_to_species(taxid, env)` → `integer(1)` taxid (sale i parent finché `rank=="species"`; se sopra-specie ritorna `taxid` invariato).

- [ ] **Step 1: Fixture mini taxonomy.** Crea `taxonomy-mini.rds` con poche entità (SARS-CoV-2, M.tuberculosis, Influenza A + un ceppo figlio).

```r
# script una-tantum (eseguito a mano, non parte della suite)
taxonomy_raw <- list(
  names = data.frame(
    name_norm = c("severeacuterespiratorysyndromecoronavirus2","sarscov2",
                  "mycobacteriumtuberculosis","influenzaavirus",
                  "influenzaavirusapr834h1n1"),
    taxid     = c(2697049L, 2697049L, 1773L, 11320L, 211044L),
    name_class= c("scientific name","synonym","scientific name","scientific name","synonym"),
    stringsAsFactors = FALSE),
  nodes = data.frame(
    taxid       = c(2697049L,1773L,11320L,211044L),
    parent_taxid= c(694009L, 1763L,11308L,11320L),
    rank        = c("species","species","species","serotype"),
    stringsAsFactors = FALSE),
  meta = list(source="taxdump", release="mini"))
saveRDS(taxonomy_raw, "inst/extdata/ontology-fixtures-mini/taxonomy-mini.rds")
```

- [ ] **Step 2: Write failing test.**

```r
# tests/testthat/test-ontology-lookup-biologics.R
fx <- system.file("extdata","ontology-fixtures-mini", package="simulomicsr")
test_that(".build_taxonomy_index lookup per nome e rollup a specie", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  env <- new.env(); env$taxonomy <- idx
  hit <- .taxonomy_lookup_name("SARS-CoV-2", env = env)  # normalizzato internamente
  expect_equal(hit$taxid, 2697049L)
  expect_null(.taxonomy_lookup_name("definitely-not-an-organism", env = env))
  # ceppo serotype -> rollup a specie
  expect_equal(.taxonomy_rollup_to_species(211044L, env = env), 11320L)
  expect_equal(.taxonomy_rollup_to_species(1773L, env = env), 1773L)  # già specie
})
```

- [ ] **Step 3: Run test → FAIL** (`.build_taxonomy_index` non definita).

Run: `Rscript -e 'devtools::test(filter="ontology-lookup-biologics")'`
Expected: FAIL "could not find function .build_taxonomy_index".

- [ ] **Step 4: Implementa.** In `R/ontology-lookup.R`:

```r
#' @noRd
.build_taxonomy_index <- function(taxonomy_raw) {
  by_name <- new.env(hash = TRUE, parent = emptyenv(),
                     size = max(nrow(taxonomy_raw$names), 1L))
  nm <- taxonomy_raw$names
  for (i in seq_len(nrow(nm))) {
    k <- nm$name_norm[i]
    if (!exists(k, envir = by_name, inherits = FALSE))  # first-wins
      assign(k, list(taxid = as.integer(nm$taxid[i]),
                     name_class = nm$name_class[i]), envir = by_name)
  }
  by_taxid <- new.env(hash = TRUE, parent = emptyenv(),
                      size = max(nrow(taxonomy_raw$nodes), 1L))
  nd <- taxonomy_raw$nodes
  # scientific name per taxid (per ritorno leggibile)
  sci <- nm[nm$name_class == "scientific name", ]
  sci_by <- stats::setNames(sci$name_norm, as.character(sci$taxid))
  for (i in seq_len(nrow(nd))) {
    assign(as.character(nd$taxid[i]),
           list(parent_taxid = as.integer(nd$parent_taxid[i]),
                rank = nd$rank[i],
                scientific_name = unname(sci_by[as.character(nd$taxid[i])])),
           envir = by_taxid)
  }
  list(by_name = by_name, by_taxid = by_taxid, meta = taxonomy_raw$meta)
}

#' @noRd
.taxonomy_lookup_name <- function(term, env = .load_ontology_dicts()) {
  tax <- env$taxonomy; if (is.null(tax)) return(NULL)
  k <- .normalize_biological_mention(term)
  if (!nzchar(k) || !exists(k, envir = tax$by_name, inherits = FALSE)) return(NULL)
  hit <- get(k, envir = tax$by_name, inherits = FALSE)
  node <- if (exists(as.character(hit$taxid), envir = tax$by_taxid, inherits = FALSE))
            get(as.character(hit$taxid), envir = tax$by_taxid, inherits = FALSE) else NULL
  list(taxid = hit$taxid,
       scientific_name = if (!is.null(node)) node$scientific_name else NA_character_,
       name_class = hit$name_class)
}

#' @noRd
.taxonomy_rollup_to_species <- function(taxid, env = .load_ontology_dicts()) {
  tax <- env$taxonomy; if (is.null(tax)) return(taxid)
  cur <- as.integer(taxid); guard <- 0L
  while (guard < 50L && exists(as.character(cur), envir = tax$by_taxid, inherits = FALSE)) {
    node <- get(as.character(cur), envir = tax$by_taxid, inherits = FALSE)
    if (identical(node$rank, "species")) return(cur)
    if (is.na(node$parent_taxid) || node$parent_taxid == cur) break
    cur <- node$parent_taxid; guard <- guard + 1L
  }
  as.integer(taxid)  # nessuna specie trovata salendo: ritorna invariato
}
```

> NB: `.normalize_biological_mention` è definita in Task 6 (modulo name-recovery). Per testare Task 1 in isolamento, definiscila come stub minimale ora in name-recovery.R (Task 6 la completa) oppure ordina l'esecuzione Task 6 prima. **Esegui Task 6 (normalize) PRIMA di Task 1** se il subagent procede in ordine di dipendenza.

- [ ] **Step 5: Run test → PASS.** `Rscript -e 'devtools::test(filter="ontology-lookup-biologics")'`
- [ ] **Step 6: Commit.** `git add R/ontology-lookup.R inst/extdata/ontology-fixtures-mini/taxonomy-mini.rds tests/testthat/test-ontology-lookup-biologics.R && git commit -m "P5 biologici Task 1: indice+accessor NCBI Taxonomy"`

---

### Task 2: Indice + accessor ImmPort (registry sinonimi + whitelist citochine)

**Files:**
- Modify: `R/ontology-lookup.R`
- Create: `inst/extdata/ontology-fixtures-mini/immport-mini.rds`
- Test: `tests/testthat/test-ontology-lookup-biologics.R`

**Interfaces:**
- Produces:
  - `.build_immport_index(immport_raw)` → `list(by_synonym=<env>, cytokine_symbols=<env set>, meta=<list>)`. Raw: `immport_raw$synonyms` cols `syn_norm,hgnc_int,primary_symbol,reference_name`; `immport_raw$cytokine_hgnc_int` (integer vector = whitelist registry∪lkProteinName∪GO).
  - `.immport_lookup_synonym(term, env)` → `list(hgnc_int,primary_symbol,reference_name)` o `NULL`.
  - `.is_cytokine_symbol(hgnc_int, env)` → `logical(1)` (TRUE se `hgnc_int` ∈ whitelist).

- [ ] **Step 1: Fixture immport-mini.rds** (IFN-β, IL-6, TNF con alcuni alias normalizzati).

```r
immport_raw <- list(
  synonyms = data.frame(
    syn_norm = c("ifnbeta","interferonbeta","ifnb1","betainterferon",
                 "il6","interleukin6","tnf","tnfalpha","tumornecrosisfactor"),
    hgnc_int = c(5434L,5434L,5434L,5434L, 6018L,6018L, 11892L,11892L,11892L),
    primary_symbol = c(rep("IFNB1",4), rep("IL6",2), rep("TNF",3)),
    reference_name = c(rep("Interferon-beta",4), rep("Interleukin-6",2), rep("Tumor necrosis factor",3)),
    stringsAsFactors = FALSE),
  cytokine_hgnc_int = c(5434L, 6018L, 11892L),
  meta = list(source="immport-registry-2015+lkProteinName+GO", release="mini"))
saveRDS(immport_raw, "inst/extdata/ontology-fixtures-mini/immport-mini.rds")
```

- [ ] **Step 2: Write failing test.**

```r
test_that(".immport_lookup_synonym + .is_cytokine_symbol", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  env <- new.env(); env$immport <- .build_immport_index(raw)
  hit <- .immport_lookup_synonym("IFN-β", env = env)
  expect_equal(hit$hgnc_int, 5434L); expect_equal(hit$primary_symbol, "IFNB1")
  expect_null(.immport_lookup_synonym("aspirin", env = env))
  expect_true(.is_cytokine_symbol(5434L, env = env))
  expect_false(.is_cytokine_symbol(99999L, env = env))
})
```

- [ ] **Step 3: Run → FAIL.**
- [ ] **Step 4: Implementa** (`.build_immport_index` con `by_synonym` env + `cytokine_symbols` env-set `assign(as.character(hgnc_int), TRUE)`; `.immport_lookup_synonym` normalizza con `.normalize_biological_mention`; `.is_cytokine_symbol` via `exists`). Tutti con guard `if (is.null(env$immport)) return(NULL/FALSE)`.
- [ ] **Step 5: Run → PASS.**
- [ ] **Step 6: Commit.** `"P5 biologici Task 2: indice+accessor ImmPort (sinonimi+whitelist)"`

---

### Task 3: Indice + accessor UniProt (sinonimi proteina → HGNC)

**Files:** Modify `R/ontology-lookup.R`; Create `inst/extdata/ontology-fixtures-mini/uniprot-mini.rds`; Test stesso file.

**Interfaces:**
- Produces: `.build_uniprot_index(uniprot_raw)` → `list(by_name=<env>, meta)`. Raw: `uniprot_raw$names` cols `name_norm,accession,hgnc_int`. `.uniprot_lookup_name(term, env)` → `list(accession,hgnc_int)` o `NULL`.

- [ ] **Step 1:** Fixture `uniprot-mini.rds` (es. `name_norm="interferonbeta", accession="P01574", hgnc_int=5434`).
- [ ] **Step 2:** Test `.uniprot_lookup_name("interferon beta")$hgnc_int == 5434L`; miss → NULL.
- [ ] **Step 3:** FAIL.
- [ ] **Step 4:** Implementa (clone di `.build_immport_index` per la sola `by_name`; guard `is.null(env$uniprot)`).
- [ ] **Step 5:** PASS.
- [ ] **Step 6:** Commit `"P5 biologici Task 3: indice+accessor UniProt"`

---

### Task 4: Loader graceful + flag has_* + fixture_dir

**Files:** Modify `R/ontology-lookup.R` (`.load_ontology_dicts`, `.ontology_release_meta`); Test stesso file.

**Interfaces:**
- Consumes: pattern `has_chembl` (`ontology-lookup.R:77-99`).
- Produces: `.ontology_env$taxonomy`/`$immport`/`$uniprot` (NULL se assenti), `$has_taxonomy`/`$has_immport`/`$has_uniprot`/`$has_go_cytokine` (logical). `fixture_dir` carica `taxonomy-mini.rds`/`immport-mini.rds`/`uniprot-mini.rds` (has_*=TRUE). Cache file reali: `cache_dir/taxonomy/taxonomy-lookup.rds`, `cache_dir/immport/immport-lookup.rds`, `cache_dir/uniprot/uniprot-lookup.rds`.

> NB GO: la whitelist GO cytokine-activity NON è un dizionario a sé a runtime — confluisce in `immport_raw$cytokine_hgnc_int` al build (Task 16/17). `has_go_cytokine` traccia solo se il build ha incluso GO (registrato in `immport_raw$meta`). A runtime esiste solo `env$immport`.

- [ ] **Step 1: Write failing test.**

```r
test_that("loader carica le fonti biologiche da fixture_dir con flag has_*", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = fx)
  expect_true(env$has_taxonomy); expect_true(env$has_immport); expect_true(env$has_uniprot)
  expect_false(is.null(env$taxonomy)); expect_false(is.null(env$immport))
})
test_that("loader graceful: fonti biologiche assenti -> has_*=FALSE, retrocompat", {
  td <- tempfile(); dir.create(td)
  for (f in c("chebi-mini.rds","hgnc-mini.rds","mesh-mini.rds","chembl-mini.rds"))
    file.copy(file.path(fx, f), file.path(td, f))   # solo le 4 obbligatorie/chembl
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = td)
  expect_false(env$has_taxonomy); expect_null(env$taxonomy)
})
```

> NB: il secondo test richiede che `fixture_dir` tolleri l'assenza dei mini biologici (graceful), non `stop`. Implementare con `file.exists` come per chembl.

- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implementa in `.load_ontology_dicts`: nei due rami (fixture/reale) aggiungi blocchi `if (file.exists(<path>)) {raw<-readRDS; has_X<-TRUE} else {raw<-NULL; has_X<-FALSE}` per taxonomy/immport/uniprot; poi `.ontology_env$taxonomy <- if (has_taxonomy) .build_taxonomy_index(raw) else NULL` ecc.; set i 4 flag. `has_go_cytokine <- isTRUE(immport_raw$meta$has_go)` (default FALSE). Estendi `.ontology_release_meta` con le nuove release.
- [ ] **Step 4:** Run → PASS + suite ontologia intera verde (`devtools::test(filter="ontology")`).
- [ ] **Step 5:** Commit `"P5 biologici Task 4: loader graceful has_taxonomy/immport/uniprot/go"`

---

# FASE 2 — Estrazione + risoluzione (R/stage3-name-recovery.R)

### Task 5: `.normalize_biological_mention` (forma canonica greco-aware)

**Files:** Modify `R/stage3-name-recovery.R`; Test `tests/testthat/test-stage3-name-recovery-biologics.R`.

**Interfaces:** `.normalize_biological_mention(x)` → `character(1)` (lower, NFKC, greco→latino, solo `[a-z0-9]`). `character(1)==""` su input vuoto/NA.

- [ ] **Step 1: Write failing test.**

```r
test_that(".normalize_biological_mention collassa grafie greco/trattino/spazio", {
  expect_equal(.normalize_biological_mention("IFN-β"), "ifnbeta")
  expect_equal(.normalize_biological_mention("interferon beta"), "interferonbeta")
  expect_equal(.normalize_biological_mention("TNF-α"), "tnfalpha")
  expect_equal(.normalize_biological_mention("poly(I:C)"), "polyic")
  expect_equal(.normalize_biological_mention(NA_character_), "")
})
```

- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa:

```r
#' @keywords internal
.normalize_biological_mention <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(x)) return("")
  s <- tolower(trimws(x))
  greci <- c("α"="alpha","β"="beta","γ"="gamma","δ"="delta",
             "κ"="kappa","ω"="omega")
  for (g in names(greci)) s <- gsub(g, greci[[g]], s, fixed = TRUE)
  gsub("[^a-z0-9]+", "", s)
}
```
> NB: lettere greche scritte come escape Unicode (`β`=β) per robustezza di encoding del sorgente R.

- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `"P5 biologici Task 5: .normalize_biological_mention greco-aware"`

---

### Task 6: Stoplist biologici + gate alias-corti

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso.

**Interfaces:** `.GENERIC_BIOLOGICAL_STOPLIST` (character vector). `.is_generic_biological(term)` → logical (TRUE se la forma normalizzata ∈ stoplist o `<3` alnum).

- [ ] **Step 1: Test:** `interferon`/`cytokine`/`virus`/`infection` nudi → TRUE; `ifnbeta`/`sarscov2` → FALSE; `il`/`fc` (corti) → TRUE.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa `.GENERIC_BIOLOGICAL_STOPLIST <- c("cytokine","cytokines","interferon","interleukin","chemokine","growthfactor","virus","viral","bacteria","bacterium","bacterial","pathogen","infection","stimulation","stimulus","exposure","ligand","tlr","agonist")` + `.is_generic_biological` (normalizza, controlla `nchar<3` su alnum o appartenenza).
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `"P5 biologici Task 6: stoplist biologici + gate alias-corti"`

---

### Task 7: `.normalize_cytokine_to_hgnc`

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso.

**Interfaces:**
- Consumes: `.immport_lookup_synonym`, `.hgnc_lookup_symbol` (`ontology-lookup.R:444`→`{hgnc_int,primary_symbol,match_type}`), `.hgnc_lookup_hgnc` (`:428`→`{...,symbol,...}`), `.uniprot_lookup_name`, `.is_cytokine_symbol`, `.is_generic_biological`, `.slugify`.
- Produces: `.normalize_cytokine_to_hgnc(term, ontology_env)` → `list(id,name,source)`. `id` ∈ `HGNC:<symbol>` | `STR:<slug>`. `source` ∈ `CYTOKINE_IMMPORT|CYTOKINE_HGNC|CYTOKINE_UNIPROT|STR_FALLBACK|NO_TERM`.

- [ ] **Step 1: Write failing test.**

```r
test_that(".normalize_cytokine_to_hgnc risolve IFN-beta a HGNC e gatekeepa i generici", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = fx)
  r <- .normalize_cytokine_to_hgnc("IFN-β 10 ng/ml", env)
  expect_equal(r$id, "HGNC:IFNB1"); expect_equal(r$source, "CYTOKINE_IMMPORT")
  expect_equal(.normalize_cytokine_to_hgnc("interferon", env)$source, "STR_FALLBACK")  # generico
  expect_equal(.normalize_cytokine_to_hgnc("", env)$source, "NO_TERM")
})
```

- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa: input vuoto→NO_TERM; `.is_generic_biological`→STR; estrai i candidati via `.extract_compound_candidates(term)` (riuso, spoglia dose/tempo); per ogni candidato: ImmPort→`.hgnc_lookup_hgnc(hgnc_int)$symbol`; else HGNC `.hgnc_lookup_symbol(tolower(cand))`; else UniProt; **gate** `.is_cytokine_symbol(hgnc_int)` (altrimenti scarta); primo hit valido → `HGNC:<symbol>`. Nessun hit → `STR:<slugify(term)>`.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `"P5 biologici Task 7: .normalize_cytokine_to_hgnc"`

---

### Task 8: `.PAMP_WHITELIST` + `.normalize_pathogen_to_taxid`

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso.

**Interfaces:**
- Consumes: `.taxonomy_lookup_name`, `.taxonomy_rollup_to_species`, `.taxonomy lookup`→scientific_name, `.is_generic_biological`, `.slugify`. Whitelist PAMP costante (slug-norm → ChEBI int) + vernacolo costante (slug-norm → taxid).
- Produces: `.PAMP_WHITELIST` (named int: chiavi `.normalize_biological_mention`, valori chebi_int). `.normalize_pathogen_to_taxid(term, ontology_env)` → `list(id,name,source)`. `id` ∈ `CHEBI:<int>`(PAMP) | `NCBITaxon:<taxid>` | `STR:<slug>`. `source` ∈ `PAMP_WHITELIST|PATHOGEN_VERNACULAR|PATHOGEN_TAXID|STR_FALLBACK|NO_TERM`.

- [ ] **Step 1: Write failing test.**

```r
test_that(".normalize_pathogen_to_taxid: PAMP->ChEBI, organismo->taxid, generico->STR", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = fx)
  expect_equal(.normalize_pathogen_to_taxid("LPS")$id, "CHEBI:16412")            # whitelist (env opzionale)
  expect_equal(.normalize_pathogen_to_taxid("SARS-CoV-2", env)$id, "NCBITaxon:2697049")
  expect_equal(.normalize_pathogen_to_taxid("virus", env)$source, "STR_FALLBACK") # generico
})
```

- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa: `.PAMP_WHITELIST <- c(lps=16412L, lipopolysaccharide=16412L, polyic=..., r848=..., resiquimod=..., imiquimod=..., pam3csk4=..., cpgodn=..., flagellin=..., mpla=..., mdp=..., zymosan=..., betaglucan=...)` (chiavi già normalizzate; ID ChEBI esatti riempiti al build Task 17 sanity-check). Catena: vuoto→NO_TERM; generico→STR; normalizza→whitelist PAMP→`CHEBI:`; vernacolo→`NCBITaxon:`; `.taxonomy_lookup_name`→`.taxonomy_rollup_to_species`→`NCBITaxon:`; miss→`STR:`.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `"P5 biologici Task 8: PAMP whitelist + .normalize_pathogen_to_taxid"`

---

### Task 9: K3 + dispatch biologico in `recover_identity`

**Files:** Modify `R/stage3-name-recovery.R` (`recover_identity:301`, ramo perturbativo `:357`); Test stesso.

**Interfaces:**
- Consumes: `recover_identity` esistente (ritorno `list(kind,agent_id,canonical_name,recovery_source)`), `.perturbative_kinds`.
- Produces (modifica): nel ramo perturbativo (`:357`), dispatch per `llm_kind`:
  - `cytokine_stim` → `.normalize_cytokine_to_hgnc` → `agent_id=r$id`, `kind=llm_kind`, `recovery_source=r$source`.
  - `pathogen_or_aggregate_exposure` → `.normalize_pathogen_to_taxid` (idem).
  - `small_molecule` → **K3 check** `.detect_biological_mistype(term, env)`: se ritorna un kind biologico forte (non STR) → `kind=<biologico>`, `agent_id=<id>`, `recovery_source="K3_MISTYPE_<...>"`; altrimenti `.normalize_compound_to_chebi` come oggi.
  - `.detect_biological_mistype(term, env)` → `list(kind,id,name,source)` o `NULL` (NULL = non biologico).

- [ ] **Step 1: Write failing test.**

```r
test_that("recover_identity dispatcha cytokine/pathogen e fa K3 su small_molecule", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = fx)
  rc <- recover_identity("", "agent: IFN-beta", "", "cytokine_stim", env)
  expect_equal(rc$agent_id, "HGNC:IFNB1"); expect_equal(rc$kind, "cytokine_stim")
  rp <- recover_identity("", "agent: SARS-CoV-2", "", "pathogen_or_aggregate_exposure", env)
  expect_equal(rp$agent_id, "NCBITaxon:2697049")
  # K3: LPS etichettato small_molecule -> ri-tipizzato pathogen
  rk <- recover_identity("", "treatment: LPS", "", "small_molecule", env)
  expect_equal(rk$kind, "pathogen_or_aggregate_exposure")
  expect_equal(rk$agent_id, "CHEBI:16412")
  expect_true(startsWith(rk$recovery_source, "K3_MISTYPE"))
  # small_molecule vero NON flippato
  rs <- recover_identity("", "compound: osimertinib", "", "small_molecule", env)
  expect_equal(rs$kind, "small_molecule")
})
```

- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa il dispatch + `.detect_biological_mistype` (prova cytokine poi pathogen; ritorna NULL se entrambi STR/NO_TERM → precision-first, nessun flip).
- [ ] **Step 4:** PASS + suite name-recovery intera verde + **canary retrocompat**: disease/genetico/compound invariati (`devtools::test(filter="name-recovery")`).
- [ ] **Step 5:** Commit `"P5 biologici Task 9: K3 + dispatch biologico in recover_identity"`

---

# FASE 3 — Integrazione anchor + cache

### Task 10: innesto `recovery` esteso ai kind biologici (`.extract_anchor_segments`)

**Files:** Modify `R/stage3-anchor-levels.R` (`:255-291`); Test `tests/testthat/test-stage3-anchor-biologics.R`.

**Interfaces:**
- Consumes: blocco innesto `recovery` (`stage3-anchor-levels.R:255`). Oggi (b) accetta override kind solo se `startsWith(recovery$kind,"genetic_")`.
- Produces (modifica): estendi la condizione (b) ad accettare anche `recovery$kind %in% c("cytokine_stim","pathogen_or_aggregate_exposure")` quando `!= segs$kind_effective`. Stessa semantica trace (`kind_recovered=TRUE`, `tm$kind_effective_resolved`).

- [ ] **Step 1: Write failing test.** Con un `recovery` list `kind="pathogen_or_aggregate_exposure"`, `agent_id="CHEBI:16412"` su segmenti con `kind_effective="small_molecule"` → atteso `segs$kind_effective=="pathogen_or_aggregate_exposure"`, `agent_id` riscritto, `tracking_meta$kind_recovered==TRUE`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa: cambia la guardia da `startsWith(recovery$kind,"genetic_")` a `(startsWith(recovery$kind,"genetic_") || recovery$kind %in% .biological_override_kinds)` con `.biological_override_kinds <- c("cytokine_stim","pathogen_or_aggregate_exposure")`.
- [ ] **Step 4:** PASS + `devtools::test(filter="anchor")` verde (retrocompat genetic_ intatta).
- [ ] **Step 5:** Commit `"P5 biologici Task 10: innesto recovery esteso ai kind biologici"`

---

### Task 11: anchor round-trip namespace `NCBITaxon:`

**Files:** Test `tests/testthat/test-anchor-parse.R` (delta); eventuale Modify `R/anchor-parse.R`/`R/stage4-anchor-matching.R` solo se il parse assume un set chiuso di prefissi.

**Interfaces:** Consumes `make_anchor`/`parse_anchor_key`/`parse_anchor_canonical`. `NCBITaxon:<taxid>` vive nel segmento `agent_id` (separatore `|`), non contiene `|`/`__VS__` → atteso pass byte-identico.

- [ ] **Step 1: Write test:** costruisci un anchor con `agent_id="NCBITaxon:2697049"`, round-trip `make_anchor`→`parse_anchor_key` → il campo `agent_id` ritorna `"NCBITaxon:2697049"` intatto.
- [ ] **Step 2:** Run → se PASS (atteso, nessun parse prefix-aware) → documenta e salta impl; se FAIL → fixa il parse.
- [ ] **Step 3:** (se servì) impl minimale.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `"P5 biologici Task 11: anchor round-trip NCBITaxon"`

---

### Task 12: cache key `v3` + biologics_axis

**Files:** Modify `R/stage3-name-recovery-lookup.R` (`.name_recovery_lookup_cache_key:68`, `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`); Test `tests/testthat/test-stage3-name-recovery-lookup.R`.

**Interfaces:** Consumes `chembl_axis` (`:82-87`). Produces: bump `SCHEMA_VERSION "v2"→"v3"`; `biologics_axis <- paste0("tax=",isTRUE(env$has_taxonomy),":imm=",isTRUE(env$has_immport),":uni=",isTRUE(env$has_uniprot),":go=",isTRUE(env$has_go_cytokine))` appeso al payload.

- [ ] **Step 1: Test:** stesso `(h5,gsms,kinds)` ma `has_taxonomy` TRUE vs FALSE → chiavi DIVERSE (anti-poisoning); + test che la versione è `v3`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementa (append `biologics_axis` al payload, bump versione).
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `"P5 biologici Task 12: cache key v3 + biologics_axis"`

---

### Task 13: FINAL whole-branch review (opus)

- [ ] Esegui `superpowers:requesting-code-review` sul range `4ac57e8..HEAD`. Focus: retrocompat byte-identica (disease/genetico/compound), data-flow recover_identity→anchor→cache, gate precisione (stoplist+whitelist), nessun flip K3 su composti generici (canary), coerenza firme cross-task. Fixa i finding bloccanti prima della FASE 4. Suite intera verde.

---

# FASE 4 — Build scripts dizionari reali (GATED)

> Eseguiti dal subagent/utente con autorizzazione; producono i `.rds` in `cache_dir`. Schema verificato sui dati reali (come ChEMBL Task 6). `readxl` in DESCRIPTION Suggests (Task 14).

### Task 14: `DESCRIPTION` Suggests readxl + build NCBI taxdump

**Files:** Modify `DESCRIPTION`; Create `analysis/p5-audit-taxonomy-build-dict.R`.

- [ ] **Step 1:** Aggiungi `readxl` a `Suggests` in `DESCRIPTION`; bump versione.
- [ ] **Step 2:** Scrivi `analysis/p5-audit-taxonomy-build-dict.R`: scarica `taxdump.tar.gz` (FTP `ftp.ncbi.nlm.nih.gov/pub/taxonomy/`), parse `names.dmp` (filtra name_class ∈ {scientific name,synonym,equivalent name,genbank common name,common name}; `name_norm=.normalize_biological_mention(name)`) + `nodes.dmp` (taxid,parent,rank); filtra rank a specie/sotto + ancestor; salva `cache_dir/taxonomy/taxonomy-lookup.rds` nella forma `list(names=...,nodes=...,meta=list(source,release=<date>,sha256))`. Provenienza in `analysis/p4-output/taxonomy-source-provenance.json`.
- [ ] **Step 3:** Commit `"P5 biologici Task 14: DESCRIPTION readxl + build taxdump (gated)"`

### Task 15: build GO cytokine-activity whitelist

- [ ] Crea `analysis/p5-audit-go-cytokine-build-dict.R`: scarica GAF umano (`goa_human.gaf.gz`) + `go-basic.obo`; raccogli i geni annotati a `GO:0005125` (cytokine activity) e discendenti (+ `cytokine receptor binding`); mappa symbol→`hgnc_int` via `.hgnc_lookup_symbol`; output vettore `go_cytokine_hgnc_int` (intermedio consumato da Task 16). Commit `"P5 biologici Task 15: build GO cytokine-activity whitelist (gated)"`.

### Task 16: build ImmPort (registry xls + API lkProteinName + unione whitelist)

- [ ] Crea `analysis/p5-audit-immport-build-dict.R`:
  - Legge `analysis/p4-output/cytokine-registry-immport-2015.xls` (`readxl`, foglio `Registry`): per ogni riga raccogli tutti gli alias dalle colonne sinonimi (EntrezGene Aliases/Additional Names Human, UniProt protein (alternative) names Human, Typographical variations, IX Synonyms, Protein Ontology synonyms, REFERENCE NAME, EntrezGene Symbol/official name) → `syn_norm=.normalize_biological_mention`, mappa a `hgnc_int` (parse `HGNC ID` col → int) + `primary_symbol` (EntrezGene Symbol Human) + `reference_name`.
  - API `lkProteinName` (`Authorization: Bearer <IMMPORT_API_KEY>`): aggiungi i 207 `uniprot_gene_name`→hgnc come sinonimi+whitelist.
  - `cytokine_hgnc_int = unique(c(registry_hgnc_int, lkProteinName_hgnc_int, go_cytokine_hgnc_int))`; `meta$has_go = TRUE`.
  - Salva `cache_dir/immport/immport-lookup.rds` = `list(synonyms=<df>, cytokine_hgnc_int=<int>, meta=...)`.
  - API key da `Sys.getenv("IMMPORT_API_KEY")` (l'utente la esporta in `.Renviron.local`, gitignored). Provenienza + sha registry in JSON.
- [ ] Commit `"P5 biologici Task 16: build ImmPort registry+API+whitelist (gated)"`.

### Task 17: build UniProt sinonimi → HGNC

- [ ] Crea `analysis/p5-audit-uniprot-build-dict.R`: scarica `uniprot_sprot_human.dat.gz` (o `HUMAN_9606_idmapping.dat.gz`); estrai `DE` RecName/AltName + `GN` synonyms per ogni accession; mappa gene→`hgnc_int` via `.hgnc_lookup_symbol`; `name_norm=.normalize_biological_mention`; salva `cache_dir/uniprot/uniprot-lookup.rds` = `list(names=<df name_norm,accession,hgnc_int>, meta)`. Commit `"P5 biologici Task 17: build UniProt sinonimi (gated)"`.

> **Sanity PAMP**: nel build verifica che ogni `CHEBI:<int>` in `.PAMP_WHITELIST` esista in ChEBI con role adjuvant/immunostimulant ancestry; correggi gli ID nel codice se un placeholder è errato. Documenta in provenienza.

---

# FASE 5 — Run gated (clone sessione 21)

### Task 18: build dizionari reali + verifica schema

- [ ] Esegui i 4 build script (Task 14-17) con autorizzazione utente + `IMMPORT_API_KEY`. Verifica: `.load_ontology_dicts(refresh=TRUE)$has_taxonomy/has_immport/has_uniprot/has_go_cytokine` tutti TRUE; conteggi sani (taxonomy ~milioni nomi, immport ~5k sinonimi/250 HGNC, uniprot ~20k). Smoke accessor su IFN-β/LPS/SARS-CoV-2. Nessun commit dei `.rds` (gitignored).

### Task 19: SMOKE copertura PRE-fullrun (PUNTO-DECISIONE)

- [ ] Adatta `analysis/audit/name-recovery-llm-benchmark.R` (o nuovo smoke) per campionare i `cytokine_stim`/`pathogen` `UNK`/`STR` residui v5 e misurare: **% recupero** (HGNC/NCBITaxon/CHEBI vs STR) + **0 falsi canary** (interferon/virus/cytokine nudi → STR; nessun composto generico flippato dal K3). **GATE UTENTE**: si procede ai run pesanti solo se il guadagno è reale. Report in `docs/findings/`.

### Task 20: re-cluster Stadio 3 v6 (~6-7h)

- [ ] Modify `analysis/p4-fase-f6-stage3-reclustering.R`: assert `has_taxonomy && has_immport && has_uniprot` fail-loud (clone assert `has_chembl`) + token `v6`. Smoke `SMOKE=1` sanity → full `SMOKE=0` detached → dir `…-stage3-v6-<id>/`. Verifica `run_metadata` (ontology_releases biologiche, recovery sources biologiche, sanity agent_id `NCBITaxon:`/`HGNC:`/`CHEBI:` su cytokine/pathogen).

### Task 21: re-pool Stadio 4 v6 (~10h, /sda)

- [ ] Crea `analysis/p4-fase-f5-stage4-layer-a-rebuild-v6.R` (copia -v5: `stage3_dir`→v6, `out_dir`→`/sda`+token v6, 2 log). Smoke `DRY_RUN` → full detached. Fix df-residui già committato (`0c41848`). Output `/sda/simulomicsr-stage4-v6/…`.

### Task 22: re-gate omogeneità v6 + closeout

- [ ] `analysis/audit/stage3-homogeneity-check.R <dir-v6> <h5> Inf Inf <stage2-master-v3>` → confronto v5→v6. **Criterio**: `cytokine_stim` giù dal 61%, `pathogen` giù dal 33%, disease/small_molecule invariati. Output `-v6-full-out.{txt,csv}`. Finding `docs/findings/2026-06-30-stage3-v6-biologics-homogeneity.md`. Aggiorna `CLAUDE.md` header + `.superpowers/sdd/progress.md` + memoria `[[project_stage3_minestrone_rework]]`.

---

## Self-Review (eseguita)

**Spec coverage:** D1 (scope entrambe)→Task 7-9; D2 (HGNC+UniProt+ImmPort+GO)→Task 2-4,7,15-17; D3 (taxdump)→Task 1,8,14; D4 (K3)→Task 9; D5 (PAMP)→Task 8,17; D6 (ImmPort accesso)→Task 16; D7 (clone pattern)→tutta FASE 1. Versioning (anchor v3.2/cache v3/resolver v1.2.0)→Task 11,12,20. Stoplist→Task 6. Catena run gated→FASE 5. ✅ nessuna sezione spec senza task.

**Placeholder scan:** gli ID ChEBI esatti dei PAMP (Task 8) sono il solo dato da fissare al build (sanity Task 17) — esplicitato, non è un TODO di logica. `.normalize_biological_mention` mostra una riga `chartr` ERRATA barrata per evidenza (Task 5 step 3 nota di rimuoverla). Nessun "TBD/implement later".

**Type consistency:** `recover_identity` ritorna sempre `list(kind,agent_id,canonical_name,recovery_source)` (4 campi, verificato vs codice). `.normalize_*` ritornano `list(id,name,source)`. `.taxonomy_lookup_name`→`{taxid,scientific_name,name_class}`. `.immport_lookup_synonym`→`{hgnc_int,primary_symbol,reference_name}`. Accessor HGNC consumati con le firme reali (`.hgnc_lookup_symbol`→`{hgnc_int,primary_symbol,match_type}`, `.hgnc_lookup_hgnc`→`{...symbol...}`). Coerenti cross-task.

---

## Riferimenti
- Spec: `docs/superpowers/specs/2026-06-29-stage3-biologics-name-recovery-design.md` (+ HUMANE).
- Deep research: `docs/findings/2026-06-29-deep-research-biologics-db.md`.
- Pattern: Plan B ChEMBL `docs/superpowers/plans/2026-06-28-stage3-perturbative-name-recovery-B-plan.md`.
- Firme reali: vedi spec §4.1 + commit `4ac57e8`.
