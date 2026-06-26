# Stage 3 Name-Recovery + Reclustering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recuperare deterministicamente il nome di malattia/composto (e correggere i tipi palesemente sbagliati) dai metadati GEO grezzi, innestarlo nell'anchor Stadio 3 dove oggi è `UNK`, e ri-raggruppare così che solo stessa-malattia/stesso-composto finiscano insieme.

**Architecture:** Un modulo puro (`R/stage3-name-recovery.R`) estrae+normalizza identità da testo metadati; un builder costruisce un lookup `GSM → identità` dall'H5; `.extract_anchor_segments` consulta il lookup quando l'agente è `UNK`. Poi re-cluster Stadio 3 → ri-pooling Stadio 4 (solo cluster cambiati) → gate di omogeneità. Benchmark LLM in parallelo (eval, fuori produzione).

**Tech Stack:** R, testthat (TDD), rhdf5 (lettura H5), dizionari ontologici esistenti (MeSH/ChEBI via `.load_ontology_dicts`).

**Spec:** `docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md`.

## Global Constraints

- Italiano in commenti, docstring, messaggi di commit, error messages. ASCII nei `.Rd` (`§`/`--`).
- Funzioni interne: `@keywords internal`. TDD bite-sized (test → fail → impl → pass → commit).
- Commit atomici prefisso `P5 audit RED_ALERT F6: `. MAI `git push`, MAI `--no-verify`. Master git invariato.
- Retrocompatibilità: ogni nuovo parametro ha default che riproduce il comportamento attuale (`recovery_lookup = NULL` = Stadio 3 odierno).
- Le run pesanti (re-cluster Stadio 3, ri-pooling Stadio 4) sono **gate utente separati**, non si lanciano dentro un task di codice.
- Test runner: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("<file>")'` (sul laptop; su DGX senza `--vanilla`).

---

## File Structure

- Create `R/stage3-name-recovery.R` — modulo puro: parsing characteristics, estrazione malattia/agente, rilevamento tipo genetico (K2), normalizzazione ontologica, orchestratore `recover_identity()`.
- Create `tests/testthat/test-stage3-name-recovery.R` — TDD del modulo.
- Create `R/stage3-name-recovery-lookup.R` — `build_name_recovery_lookup()` (legge H5, costruisce env `GSM → identità`).
- Create `tests/testthat/test-stage3-name-recovery-lookup.R` — TDD del builder con H5 mock.
- Modify `R/stage3-anchor-levels.R` — `.extract_anchor_segments()` consulta il lookup quando agente `UNK` + applica kind corretto.
- Modify `R/stage3-build.R` — `.precompute_anchor_cache()` + builder records passano il lookup; `build_stage3_clusters()` accetta `name_recovery_lookup`.
- Create `analysis/audit/stage3-homogeneity-check.R` — gate di omogeneità productionizzato.
- Create `analysis/audit/name-recovery-llm-benchmark.R` — benchmark LLM vs deterministico vs gold.
- Create `analysis/p4-fase-f6-stage3-reclustering.R` — orchestrazione re-cluster (run gated).

---

## Phase 1 — Modulo di recupero (puro, TDD)

### Task 1: `.parse_characteristics_kv` — parse "key: value, key: value"

**Files:** Create `R/stage3-name-recovery.R`; Test `tests/testthat/test-stage3-name-recovery.R`

**Interfaces:**
- Produces: `.parse_characteristics_kv(text) -> named character vector` (nomi = chiavi lowercased trimmed, valori = lowercased trimmed). `character(0)` su input vuoto/NA.

- [ ] **Step 1: Write the failing test**

```r
test_that(".parse_characteristics_kv: estrae coppie chiave:valore", {
  kv <- .parse_characteristics_kv("tissue: Blood, disease state: AD, cell type: PBMC")
  expect_equal(unname(kv[["disease state"]]), "ad")
  expect_equal(unname(kv[["tissue"]]), "blood")
  expect_equal(length(kv), 3L)
})

test_that(".parse_characteristics_kv: input vuoto/NA -> character(0)", {
  expect_length(.parse_characteristics_kv(NA_character_), 0L)
  expect_length(.parse_characteristics_kv(""), 0L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage3-name-recovery.R")'`
Expected: FAIL — `could not find function ".parse_characteristics_kv"`.

- [ ] **Step 3: Write minimal implementation**

```r
# R/stage3-name-recovery.R
# Recupero deterministico di identita' (malattia/composto/gene) dai metadati GEO
# grezzi + correzione tipi palesemente sbagliati (K2). Spec:
# docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md

#' Parsa "key: value, key: value" in vettore nominato (chiavi/valori lowercased)
#' @keywords internal
.parse_characteristics_kv <- function(text) {
  if (length(text) != 1L || is.na(text) || !nzchar(text)) return(character(0))
  pairs <- strsplit(text, ",", fixed = TRUE)[[1L]]
  out <- character(0)
  for (p in pairs) {
    kv <- strsplit(p, ":", fixed = TRUE)[[1L]]
    if (length(kv) >= 2L) {
      k <- tolower(trimws(kv[1L]))
      v <- tolower(trimws(paste(kv[-1L], collapse = ":")))
      if (nzchar(k) && nzchar(v)) out[[k]] <- v
    }
  }
  out
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage3-name-recovery.R tests/testthat/test-stage3-name-recovery.R
git commit -m "P5 audit RED_ALERT F6: .parse_characteristics_kv (TDD)"
```

---

### Task 2: `.extract_disease_term` — candidato malattia dal testo

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso file.

**Interfaces:**
- Consumes: `.parse_characteristics_kv`.
- Produces: `.extract_disease_term(source, characteristics, title) -> character(1)` (testo malattia lowercased) o `NA_character_`. Chiavi malattia: `disease|disease state|diagnosis|condition|histology|tumor type|cancer type|subtype|group|patient group`. Esclude valori di controllo (`healthy|normal|control|non-malignant|baseline|unaffected`).

- [ ] **Step 1: Write the failing test**

```r
test_that(".extract_disease_term: prende la malattia dalle characteristics", {
  d <- .extract_disease_term("Blood", "tissue: Blood, disease: Juvenile Dermatomyositis", "sample 1")
  expect_equal(d, "juvenile dermatomyositis")
})

test_that(".extract_disease_term: valori di controllo -> NA", {
  expect_true(is.na(.extract_disease_term("PBMC", "disease state: healthy", "ctrl")))
})

test_that(".extract_disease_term: fallback su source/title se niente chiave", {
  d <- .extract_disease_term("breast tumor", "tissue id: BRB123", "FFPE breast tumor sample")
  expect_true(grepl("breast", d))
})
```

- [ ] **Step 2: Run** — Expected: FAIL (function not found).

- [ ] **Step 3: Write minimal implementation**

```r
.DISEASE_KEYS <- "^(disease|disease state|diagnosis|condition|histology|tumor type|cancer type|subtype|group|patient group)$"
.CONTROL_VALS <- "healthy|normal|control|non-?malignant|baseline|unaffected|^na$|^none$"

#' Estrae il termine-malattia dai metadati (chiavi malattia + fallback source/title)
#' @keywords internal
.extract_disease_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.DISEASE_KEYS, names(kv))]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.CONTROL_VALS, v)) return(v)
    }
  }
  # fallback: source_name/title se contengono un marcatore tumore/malattia esplicito
  blob <- tolower(paste(source %||% "", title %||% ""))
  if (grepl("tumou?r|cancer|carcinoma|neoplas|leukemia|lymphoma", blob) &&
      !grepl(.CONTROL_VALS, blob)) {
    return(trimws(gsub("\\s+", " ", source %||% title)))
  }
  NA_character_
}
```
(Assicurarsi che `%||%` sia disponibile: il pacchetto lo definisce già in `R/anchors.R`; se il check fallisce, aggiungere `\`%||%\` <- function(a,b) if (is.null(a)||length(a)==0L) b else a` in testa al file.)

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage3-name-recovery.R tests/testthat/test-stage3-name-recovery.R
git commit -m "P5 audit RED_ALERT F6: .extract_disease_term (TDD)"
```

---

### Task 3: `.extract_agent_term` — candidato composto/agente dal testo

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso file.

**Interfaces:**
- Produces: `.extract_agent_term(source, characteristics, title) -> character(1)` o `NA`. Chiavi: `treatment|agent|compound|drug|chemical|stimulus|stimulation|ligand|exposure|reagent`. Esclude controlli (riusa `.CONTROL_VALS` + `vehicle|dmso|pbs|untreated|mock|scramble|vector`).

- [ ] **Step 1: Write the failing test**

```r
test_that(".extract_agent_term: prende il composto dal trattamento", {
  a <- .extract_agent_term("cells", "treatment: Bleomycin, time: 24h", "rep1")
  expect_equal(a, "bleomycin")
})
test_that(".extract_agent_term: veicolo/controllo -> NA", {
  expect_true(is.na(.extract_agent_term("cells", "treatment: DMSO", "vehicle 1")))
  expect_true(is.na(.extract_agent_term("cells", "treatment: control", "ctrl")))
})
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

```r
.AGENT_KEYS    <- "^(treatment|agent|compound|drug|chemical|stimulus|stimulation|ligand|exposure|reagent)$"
.AGENT_CONTROL <- paste0(.CONTROL_VALS, "|vehicle|dmso|\\bpbs\\b|untreated|mock|scramble|vector|water")

#' Estrae il termine-agente (composto) dai metadati
#' @keywords internal
.extract_agent_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.AGENT_KEYS, names(kv))]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.AGENT_CONTROL, v)) return(v)
    }
  }
  NA_character_
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage3-name-recovery.R tests/testthat/test-stage3-name-recovery.R
git commit -m "P5 audit RED_ALERT F6: .extract_agent_term (TDD)"
```

---

### Task 4: `.detect_genetic_perturbation` — K2 (correzione tipo)

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso file.

**Interfaces:**
- Produces: `.detect_genetic_perturbation(source, characteristics, title) -> list(is_genetic, genetic_kind, target)`. `is_genetic=TRUE` solo su segnali inequivocabili (degron/RNAi/CRISPR). `genetic_kind` ∈ {`genetic_knockdown`,`genetic_knockout`,`genetic_overexpression`}. `target` = simbolo gene se estraibile, altrimenti `NA`.

- [ ] **Step 1: Write the failing test**

```r
test_that(".detect_genetic_perturbation: dTAG/degron -> genetico, non small_molecule", {
  r <- .detect_genetic_perturbation("HCT116", "cell line: HCT116", "POINT-Seq XRN2-dTAG minus dTAG rep1")
  expect_true(r$is_genetic)
  expect_match(r$genetic_kind, "genetic_")
  expect_equal(toupper(r$target), "XRN2")
})
test_that(".detect_genetic_perturbation: shRNA knockdown", {
  r <- .detect_genetic_perturbation("cells", "treatment: shTP53", "shRNA knockdown TP53")
  expect_true(r$is_genetic); expect_equal(r$genetic_kind, "genetic_knockdown")
})
test_that(".detect_genetic_perturbation: farmaco normale -> non genetico", {
  r <- .detect_genetic_perturbation("cells", "treatment: bleomycin", "Bleomycin 24h")
  expect_false(r$is_genetic)
})
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

```r
.GENETIC_SIGNALS <- c(
  knockout       = "knock-?out|\\bko\\b|crispr|\\bcas9\\b|sgrna|gene deletion",
  knockdown      = "knock-?down|\\bshrna\\b|\\bsirna\\b|sh[A-Z][A-Z0-9]+|si[A-Z][A-Z0-9]+|dtag|\\baid\\b|auxin|\\biaa\\b|degron|fkbp12|depletion",
  overexpression = "over-?expression|overexpress|\\boe\\b|ectopic expression")

#' Rileva perturbazione genetica inequivocabile (K2) + gene bersaglio se possibile
#' @keywords internal
.detect_genetic_perturbation <- function(source, characteristics, title) {
  blob <- paste(source %||% "", characteristics %||% "", title %||% "")
  none <- list(is_genetic = FALSE, genetic_kind = NA_character_, target = NA_character_)
  kind <- NA_character_
  for (nm in names(.GENETIC_SIGNALS)) {
    if (grepl(.GENETIC_SIGNALS[[nm]], blob, perl = TRUE, ignore.case = TRUE)) {
      kind <- paste0("genetic_", nm); break
    }
  }
  if (is.na(kind)) return(none)
  # estrai gene bersaglio: token in MAIUSCOLO adiacente a un segnale (es. XRN2-dTAG, shTP53)
  m <- regmatches(blob, regexpr("\\b[A-Z][A-Z0-9]{1,6}(?=[- ]?(dTAG|AID|degron|KO|KD))", blob, perl = TRUE))
  m2 <- regmatches(blob, regexpr("(?<=\\b(sh|si))[A-Z][A-Z0-9]{1,6}", blob, perl = TRUE))
  target <- c(m, m2)
  list(is_genetic = TRUE, genetic_kind = kind,
       target = if (length(target)) target[[1L]] else NA_character_)
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage3-name-recovery.R tests/testthat/test-stage3-name-recovery.R
git commit -m "P5 audit RED_ALERT F6: .detect_genetic_perturbation K2 (TDD)"
```

---

### Task 5: `.normalize_disease_to_mesh` — termine → MeSH / STR / NA

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso file.

**Interfaces:**
- Consumes: ontology env (`.load_ontology_dicts()`) + accessor esistente `.mesh_lookup_term(name, env)` (nome/sinonimo → `list(ui)`, indice `by_entry_lower`; usato in `R/anchors.R:455`) e `.mesh_lookup_ui(ui, env)` (UI → record con `$mh`). Nessun indice nuovo da costruire.
- Produces: `.normalize_disease_to_mesh(term, ontology_env) -> list(id, name, source)`. `id` = `MeSH:Dxxxxxx` | `STR:<slug>` | `NA`.

- [ ] **Step 1: Write the failing test** (usa fixture ontologia minima esistente nei test anchor)

```r
test_that(".normalize_disease_to_mesh: sinonimi mappano allo stesso MeSH (G2)", {
  env <- .test_ontology_env_min()  # helper gia' usato in test-ontology-lookup / anchor v31
  a <- .normalize_disease_to_mesh("breast cancer", env)
  b <- .normalize_disease_to_mesh("breast tumor", env)
  expect_equal(a$id, b$id)             # stesso MeSH per sinonimi
  expect_true(startsWith(a$id, "MeSH:"))
})
test_that(".normalize_disease_to_mesh: termine ignoto -> STR slug", {
  env <- .test_ontology_env_min()
  r <- .normalize_disease_to_mesh("xyzzy nonexistent disease", env)
  expect_true(startsWith(r$id, "STR:"))
})
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Write minimal implementation** (slug + lookup nome→UI; usare l'accessor verificato)

```r
.slugify <- function(x) {
  s <- tolower(trimws(gsub("[^a-z0-9]+", "_", tolower(x))))
  gsub("^_+|_+$", "", s)
}

#' Normalizza un termine-malattia su MeSH (sinonimi -> stesso UI) o STR fallback
#' @keywords internal
.normalize_disease_to_mesh <- function(term, ontology_env) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) {
    return(list(id = NA_character_, name = NA_character_, source = "NO_TERM"))
  }
  hit <- .mesh_lookup_term(term, env = ontology_env)   # nome/sinonimo -> list(ui)
  if (!is.null(hit) && !is.null(hit$ui)) {
    full <- .mesh_lookup_ui(hit$ui, env = ontology_env)
    return(list(id = paste0("MeSH:", hit$ui),
                name = if (!is.null(full)) full$mh else term, source = "MESH_NAME"))
  }
  list(id = paste0("STR:", .slugify(term)), name = term, source = "STR_FALLBACK")
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage3-name-recovery.R tests/testthat/test-stage3-name-recovery.R
git commit -m "P5 audit RED_ALERT F6: .normalize_disease_to_mesh (TDD)"
```

---

### Task 6: `.normalize_compound_to_chebi` — termine → ChEBI / STR / NA

Stessa struttura del Task 5 ma su ChEBI. `.normalize_compound_to_chebi(term, ontology_env) -> list(id,name,source)`, `id` = `CHEBI:xxxxx` | `STR:<slug>` | `NA`. Usa l'accessor esistente `.chebi_lookup_alias(name, env)` (alias_lower → `list(chebi_id)`, usato in `R/anchors.R:468`) + `.chebi_lookup_id(chebi_id, env)` per il nome leggibile. Test: "bleomycin" e "mitoxantrone" → due ChEBI diversi; termine ignoto → STR. Commit `P5 audit RED_ALERT F6: .normalize_compound_to_chebi (TDD)`.

---

### Task 7: `recover_identity` — orchestratore puro

**Files:** Modify `R/stage3-name-recovery.R`; Test stesso file.

**Interfaces:**
- Consumes: tutte le funzioni Task 1-6.
- Produces: `recover_identity(source, characteristics, title, llm_kind, ontology_env) -> list(kind, agent_id, canonical_name, recovery_source)`. Logica: (1) K2 — se `.detect_genetic_perturbation` is_genetic e `llm_kind` ∈ {small_molecule,cytokine_stim,pathogen_*} → `kind=genetic_*`, agent = `HGNC:<target>` (o STR); (2) altrimenti se `llm_kind=="disease_vs_normal"` → `.extract_disease_term` → `.normalize_disease_to_mesh`; (3) se kind perturbativo (small_molecule/cytokine/pathogen) → `.extract_agent_term` → `.normalize_compound_to_chebi`; (4) niente estratto → `agent_id=NA` (regime U1). `kind` restituito = corretto o invariato.

- [ ] **Step 1: Write the failing test**

```r
test_that("recover_identity: disease_vs_normal -> MeSH", {
  env <- .test_ontology_env_min()
  r <- recover_identity("breast tumor", "tissue: breast tumor, metastasis: yes", "S1", "disease_vs_normal", env)
  expect_true(startsWith(r$agent_id, "MeSH:") || startsWith(r$agent_id, "STR:"))
  expect_equal(r$kind, "disease_vs_normal")
})
test_that("recover_identity: degron mal-etichettato small_molecule -> kind corretto a genetic", {
  env <- .test_ontology_env_min()
  r <- recover_identity("HCT116", "cell line: HCT116", "XRN2-dTAG minus dTAG", "small_molecule", env)
  expect_match(r$kind, "genetic_")
  expect_match(r$agent_id, "HGNC:|STR:")
})
test_that("recover_identity: niente estraibile -> agent_id NA (U1)", {
  env <- .test_ontology_env_min()
  r <- recover_identity("blood", "tissue: blood", "sample", "disease_vs_normal", env)
  expect_true(is.na(r$agent_id))
})
```

- [ ] **Step 2-4:** implementare l'orchestratore secondo la logica Interfaces; far passare i test.

- [ ] **Step 5: Commit** `P5 audit RED_ALERT F6: recover_identity orchestratore (TDD)`.

---

## Phase 2 — Lookup builder

### Task 8: `build_name_recovery_lookup` — `GSM → identità` dall'H5

**Files:** Create `R/stage3-name-recovery-lookup.R`; Test `tests/testthat/test-stage3-name-recovery-lookup.R`.

**Interfaces:**
- Consumes: `recover_identity`; H5 fields `meta/samples/{geo_accession,series_id,source_name_ch1,characteristics_ch1,title}`; `stage1_master` (per GSM → `llm_kind`).
- Produces: `build_name_recovery_lookup(h5_path, gsms, kind_by_gsm, ontology_env) -> environment` (key = GSM, value = `list(kind, agent_id, canonical_name, recovery_source)`). Match serie comma-joined gestito a monte (qui si lavora per-GSM diretto su `geo_accession`, che è univoco → niente problema series).

- [ ] **Step 1: Write the failing test** (H5 mock via `rhdf5` su file temporaneo o mock dei reader; usare un piccolo helper che inietta i vettori). Verifica: per un GSM "malattia seno" → agent MeSH/STR; per un GSM degron → kind genetic; GSM povero → NA.

- [ ] **Step 2-4:** implementare. Lettura H5 una volta dei 5 vettori; per ogni `gsm` in `gsms`: indice via `match(gsm, geo_accession)`; `recover_identity(source[i], char[i], title[i], kind_by_gsm[[gsm]], env)`; `assign(gsm, res, lookup)`. Cache su disco opzionale (RDS) con chiave su `h5_path` mtime + schema_version.

- [ ] **Step 5: Commit** `P5 audit RED_ALERT F6: build_name_recovery_lookup (TDD)`.

---

## Phase 3 — Innesto nell'anchor

### Task 9: `.extract_anchor_segments` consulta il lookup

**Files:** Modify `R/stage3-anchor-levels.R`; Test `tests/testthat/test-stage3-anchor-name-recovery.R` (nuovo).

**Interfaces:**
- Modifica firma: `.extract_anchor_segments(stage1_facts, stage2_role, ontology_env = NULL, recovery = NULL)` dove `recovery` = `list(kind, agent_id, canonical_name, recovery_source)` già risolto per il GSM rappresentante (NULL = comportamento attuale).
- Comportamento: **dopo** il calcolo attuale dei segmenti, se `!is.null(recovery)`: (a) se il segmento `agent_id` è `"UNK"` e `recovery$agent_id` non-NA → sostituisci `agent_id` + `canonical_name` in `tracking_meta`; (b) se `recovery$kind` differisce dal kind LLM e indica genetico (K2) → sostituisci il segmento `kind_effective`. Tracciare gli originali in `tracking_meta` (`agent_id_recovered`, `kind_recovered`, `recovery_source`).

- [ ] **Step 1: failing test** — costruire `stage1_facts` minimale che produce `UNK`, passare `recovery` con `agent_id="MeSH:D001943"` → l'anchor segment `agent_id` diventa `MeSH:D001943`; senza `recovery` resta `UNK` (retrocompat).
- [ ] **Step 2-4:** implementare; far passare; verificare che i ~30 test anchor esistenti restino verdi (retrocompat con default NULL).
- [ ] **Step 5: Commit** `P5 audit RED_ALERT F6: anchor consulta recovery lookup (TDD)`.

### Task 10: thread del lookup nel build Stadio 3

**Files:** Modify `R/stage3-build.R` (`.precompute_anchor_cache` righe ~358-365 + `.build_pair_records`/`.build_group_records` + `build_stage3_clusters`); Test esistenti stage3 (mocked).

**Interfaces:**
- `.precompute_anchor_cache(..., recovery_lookup = NULL)`: nel loop `for (key ...)` (`:358`), `sid <- parts[1L]`; `rec <- if (!is.null(recovery_lookup)) recovery_lookup[[sid]] else NULL`; `assign(key, .extract_anchor_segments(facts, stage2_role = role, recovery = rec), envir = anchors)`.
- `build_stage3_clusters(..., name_recovery_lookup = NULL)`: propaga a `.precompute_anchor_cache`. Default NULL = comportamento odierno.

- [ ] **Step 1-4:** modifica + test che con `recovery_lookup` non-NULL un sample UNK ottiene l'agente recuperato nell'anchor cache; con NULL invariato. Far girare la suite stage3 (mocked) — nessuna regressione.
- [ ] **Step 5: Commit** `P5 audit RED_ALERT F6: thread recovery lookup nel build Stadio 3 (TDD)`.

---

## Phase 4 — Gate di omogeneità (productionizzato)

### Task 11: `analysis/audit/stage3-homogeneity-check.R`

Productionizza il prototipo scratchpad sessione 17. Input: una dir Stadio 3 + H5. Output: tabella per-cluster `cluster_id, kind, n_studies, n_named_diseases, n_named_compounds, is_minestrone` + summary (% minestroni provati, split per metodo). Riusa il dizionario malattie/composti del modulo recovery (DRY: estrai il dizionario in una costante condivisa importata sia dal modulo sia da qui). **Match serie per token** (comma-joined). Smoke su una dir esistente. Commit `P5 audit RED_ALERT F6: gate omogeneita' Stadio 3 (script)`.

---

## Phase 5 — Benchmark LLM (eval, fuori produzione)

### Task 12: `analysis/audit/name-recovery-llm-benchmark.R`

Su un campione di record `UNK` (es. 200): (1) estrazione deterministica (`recover_identity`); (2) estrazione LLM mirata (prompt che chiede SOLO malattia/composto dato il blob metadati); (3) gold a mano su ~50. Output: accuratezza LLM vs gold, accuratezza deterministico vs gold, copertura LLM sui casi `NA` del deterministico. **Decisione C** (LLM fallback) presa con l'utente solo se l'LLM supera la soglia concordata. Non entra in produzione qui. Commit `P5 audit RED_ALERT F6: benchmark LLM recupero nome (script)`.

---

## Phase 6 — Esecuzione a cascata (GATE UTENTE separati)

> Questi NON sono task di codice: sono run gated. Ognuno = STOP + ok utente.

### Task 13: Smoke recovery sui 3 cluster-esempio
Lookup builder sui GSM di breast/blood/HCT116 → verifica che seno→MeSH seno, sangue→malattie separate, HCT116→genetic+gene. Niente re-cluster ancora.

### Task 14: Re-cluster Stadio 3 (run gated)
`analysis/p4-fase-f6-stage3-reclustering.R`: costruisce il lookup pieno + `build_stage3_clusters(..., name_recovery_lookup=lookup)`. Output nuova dir `…stage3-v4-<id>/`. Sanity: conteggi cluster/assignment, copertura campioni, quanti `UNK` residui (regime U1), quanti `STR:` (frammentazione).

### Task 15: Ri-pooling Stadio 4 (run gated)
Solo sui cluster con membership cambiata vs `…stage4-4f7ea215`. Riusa `analysis/p4-fase-f5-stage4-layer-a-rebuild-v3.R` puntato alla nuova dir Stadio 3.

### Task 16: Gate omogeneità sui cluster nuovi
`stage3-homogeneity-check.R` sulla dir v4 → **criterio: ~0 minestroni provati nel set poolabile**. Se passa → si riprende F6 Fase B (shortlist) sui cluster nuovi. Se no → iterare il recovery prima di accettare.

---

## Self-Review

- **Spec coverage:** modulo deterministico (Task 1-7 ✓), normalizzazione ontologica come cuore (Task 5-6 ✓), K2 correzione tipi (Task 4 + 7 + 9 ✓), lookup precalcolato (Task 8 ✓), innesto anchor con UNK→recuperato + U1 (Task 9-10 ✓), benchmark LLM (Task 12 ✓), gate omogeneità (Task 11 + 16 ✓), cascata re-cluster/Stadio 4 (Task 14-15 ✓), G2 via MeSH sinonimi→stesso UI (Task 5 ✓). 
- **Placeholder scan:** nessun placeholder silenzioso. Gli accessor ontologici nome→id esistono e sono citati con file:linea (`.mesh_lookup_term` / `.chebi_lookup_alias`, `R/anchors.R:455,468`).
- **Type consistency:** `recover_identity` ritorna `list(kind, agent_id, canonical_name, recovery_source)`; `build_name_recovery_lookup` ne fa i valori dell'env; `.extract_anchor_segments(recovery=...)` consuma quegli stessi campi; `.precompute_anchor_cache(recovery_lookup=)` passa `recovery_lookup[[sid]]`. Coerenti.
- **Incognite di codice:** nessuna bloccante — tutti i call site (anchor cache `stage3-build.R:358-364`, rappresentante `:405`) e gli accessor ontologici sono verificati. Da validare in esecuzione solo la qualità empirica (quanti `STR:` residui = frammentazione, quanti `UNK` residui = regime U1), che è proprio ciò che misura il gate Task 16.
