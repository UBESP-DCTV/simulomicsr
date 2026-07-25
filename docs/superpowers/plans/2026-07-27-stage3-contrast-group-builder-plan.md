# Innesto dell'anchor derivato-dal-contrasto nel build Stadio 3 — piano di implementazione

> **Per chi esegue:** SUB-SKILL RICHIESTA: `superpowers:executing-plans` (esecuzione in sessione, con
> checkpoint). I passi usano checkbox (`- [ ]`). **Nessun subagent senza richiesta esplicita
> dell'utente.**

**Goal:** far nascere i record di gruppo dello Stadio 3 dal CONTRASTO (delta trattato↔controllo)
invece che dalla perturbazione del primo campione, così che le regole di coerenza già scritte e
testate girino dentro la pipeline e non in una simulazione.

**Architettura:** un modo di record nuovo, `cgroup`, uno per `comparison` dello Stadio 2, con
`anchor_key = <entità del delta> || <verso> || <tipo di controllo composito>`. Le regole del gate
(`.cg_*`) e dell'appaiamento della riga (`.rp_*`) vengono **richiamate, non riscritte**. I rami
`pair`, `group`, `rem`, `mega`, `mega_aug` non vengono toccati.

**Stack:** R (pacchetto), testthat, roxygen2. Dizionari ontologici via `.load_ontology_dicts()`.

## Vincoli globali (valgono per OGNI task)

- **Italiano** in commenti, roxygen, messaggi d'errore e commit. ASCII negli `.Rd` generati (niente
  accenti nel roxygen: usare `e'`, `piu'`, `§`).
- **TDD bite-sized**: test → fallimento → implementazione minima → verde → commit. Un commit per task.
- **Casi di test presi da righe VERE** del corpus (le righe di questo piano sono estratte da
  `fase1-v11-results.rds`), mai inventati.
- Funzioni interne: `@keywords internal`. Nessun `@export` nuovo.
- **Nessun run pesante** (re-cluster, re-pool) senza GO esplicito dell'utente.
- **Nessun `git push`**, master invariato, branch `review-scientific-consistency-2026-06-10`.
- Regressione zero sui rami esistenti: la suite `stage3` + `stage4` deve restare verde (6 fallimenti
  pre-esistenti noti: 4 chiamano OpenAI con chiave scaduta, 1 richiede il CLI quarto, 1 è il
  gene-axis E2).
- **`_` è carattere di parola** per le espressioni regolari: normalizzare i separatori PRIMA di
  qualunque `\\b`.
- Comandi R: `Rscript --vanilla` sul laptop (renv intercetta il libpath); i test si lanciano con
  `Rscript -e 'devtools::test(filter="...")'`.

## Struttura dei file

| file | responsabilità |
|---|---|
| `R/stage3-contrast-anchor.R` **(nuovo)** | delta dai `factor_levels`, risoluzione blindata dell'entità, combinazioni, chiave del contrasto, verdetto per-membro |
| `R/stage3-build.R` **(modifica)** | `.build_contrast_group_records()` + innesto nelle fasi 2/3/5 di `build_stage3_clusters()` |
| `R/stage3-usability.R` **(modifica)** | i cluster `cgroup` non sono né rem né mega usable |
| `R/stage4-qc.R` **(modifica)** | il gate `rem_group` seleziona `mode == "cgroup"`; dedup per (entità, verso) |
| `R/stage4-dispatch.R` **(modifica)** | dispatch dei `cgroup` per comparison |
| `tests/testthat/test-stage3-contrast-anchor.R` **(nuovo)** | Task 1-4 |
| `tests/testthat/test-stage3-contrast-group-records.R` **(nuovo)** | Task 5-6 |
| `tests/testthat/test-stage4-cgroup-branch.R` **(nuovo)** | Task 7 |
| `analysis/audit/2026-07-27-contrast-builder/` **(nuovo)** | equivalenza, smoke bandiera, censimento mega (Task 8-9) |

---

### Task 1: il delta dai `factor_levels`

**Files:**
- Create: `R/stage3-contrast-anchor.R`
- Test: `tests/testthat/test-stage3-contrast-anchor.R`

**Interfaces:**
- Consumes: niente (primo task).
- Produces:
  - `.ca_parse_factor_levels(fl)` → named character vector `valore` con `names()` = chiave in
    minuscolo. Accetta **due forme**: la lista Stadio 2 (`list(list(key=, value=), ...)`) e la
    stringa `"k=v;k=v"` (usata dagli script d'audit sui contrasti già ricostruiti).
  - `.ca_normalize_value(x)` → character(1) minuscolo senza dosi/tempi/numeri/punteggiatura.
  - `.ca_classify_key(key)` → una di `nuisance|genetic|drug|infection|disease|environment|time|other`.
  - `.ca_delta(treated_fl, control_fl)` → `list(keys, classes, treated_values, control_values,
    dominant_class, classes_signature)`. `dominant_class` è `NA_character_` se il delta è vuoto o
    solo `nuisance`.

- [ ] **Step 1: scrivere i test che falliscono**

```r
# tests/testthat/test-stage3-contrast-anchor.R
# Anchor derivato dal contrasto. Ogni caso e' una riga VERA del corpus
# (analysis/audit/2026-07-24-anchor-coherence-sim/fase1-v11-results.rds), mai inventata.

test_that(".ca_parse_factor_levels legge entrambe le forme", {
  lst <- list(list(key = "cell_line", value = "LNCaP"),
              list(key = "treatment", value = "Enzalutamide"))
  expect_equal(.ca_parse_factor_levels(lst),
               c(cell_line = "LNCaP", treatment = "Enzalutamide"))
  expect_equal(.ca_parse_factor_levels("cell_line=LNCaP;treatment=Enzalutamide"),
               c(cell_line = "LNCaP", treatment = "Enzalutamide"))
  expect_length(.ca_parse_factor_levels(NA_character_), 0L)
  expect_length(.ca_parse_factor_levels(list()), 0L)
})

test_that(".ca_normalize_value toglie dosi, tempi e numeri", {
  expect_equal(.ca_normalize_value("SARS-CoV-2 MOI 1 24h"), "sars-cov- moi")
  expect_equal(.ca_normalize_value("Enzalutamide"), "enzalutamide")
  expect_equal(.ca_normalize_value("  "), "")
})

test_that(".ca_classify_key riconosce le classi dal nome della chiave", {
  expect_equal(.ca_classify_key("treatment"), "drug")
  expect_equal(.ca_classify_key("genetic_modification"), "genetic")
  expect_equal(.ca_classify_key("infection"), "infection")
  expect_equal(.ca_classify_key("disease_state"), "disease")
  expect_equal(.ca_classify_key("time"), "time")
  # identitarie: non definiscono un contrasto biologico
  expect_equal(.ca_classify_key("cell_line"), "nuisance")
  expect_equal(.ca_classify_key("donor"), "nuisance")
  expect_equal(.ca_classify_key("tissue"), "nuisance")
})

test_that(".ca_delta isola cio' che cambia fra i due bracci (GSE147876, enzalutamide)", {
  d <- .ca_delta("cell_line=LNCaP;treatment=Enzalutamide",
                 "cell_line=LNCaP;treatment=Vehicle")
  expect_equal(d$dominant_class, "drug")
  expect_equal(d$treated_values, "Enzalutamide")
  expect_equal(d$control_values, "Vehicle")
  expect_equal(d$classes_signature, "drug")   # cell_line non cambia -> non entra
})

test_that(".ca_delta e' vuoto quando i due bracci sono identici (GSE72509)", {
  d <- .ca_delta("disease_state=healthy;treatment=control",
                 "disease_state=healthy;treatment=control")
  expect_true(is.na(d$dominant_class))
  expect_equal(d$classes_signature, "")
})

test_that(".ca_delta ignora le chiavi identitarie che cambiano da sole", {
  d <- .ca_delta("donor=D1;tissue=lung", "donor=D2;tissue=lung")
  expect_true(is.na(d$dominant_class))
})

test_that(".ca_delta sceglie la classe dominante per priorita'", {
  d <- .ca_delta("genetic_modification=shTP53;treatment=DMSO",
                 "genetic_modification=shControl;treatment=Palbociclib")
  expect_equal(d$dominant_class, "genetic")     # genetic > drug
  expect_equal(d$classes_signature, "drug+genetic")
})
```

- [ ] **Step 2: verificare che falliscano**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: FAIL, `could not find function ".ca_parse_factor_levels"`.

- [ ] **Step 3: implementazione minima**

```r
# R/stage3-contrast-anchor.R
# Anchor derivato dal CONTRASTO (ADR-0025).
#
# L'anchor dello Stadio 3 e' comparison-blind: ancora sulla perturbazione del
# campione trattato, non su cio' che il confronto ISOLA. Qui si costruisce
# l'identita' di un confronto a partire dal DELTA fra i factor_levels dei due
# bracci: entita' canonicalizzata + verso + tipo di controllo.

#' Chiavi identitarie: non definiscono un contrasto biologico
#' @keywords internal
.CA_NUISANCE_KEYS <- c("donor","donor_id","patient","subject","individual","age","sex",
  "gender","ancestry","ancestry_or_population","ethnicity","race","population",
  "replicate","batch","rep","biological_replicate","technical_replicate",
  "cell_line","cell_type","cell_type_or_line_raw","cell_context",
  "cell_context.cell_type_or_line_raw","tissue","tissue_type","tissue_segment",
  "tissue_source","cell_source","context_kind","passage","passage_or_state",
  "cell line","cell_state","id","sample_id","geo_accession","name","title")

#' Priorita' della classe dominante del delta
#' @keywords internal
.CA_CLASS_PRIORITY <- c("genetic","drug","infection","disease","environment","time","other")

#' Legge i factor_levels di un braccio in un vettore chiave -> valore
#'
#' Accetta la lista dello Stadio 2 (\code{list(list(key=, value=), ...)}) e la
#' forma stringa \code{"k=v;k=v"} usata dagli script d'audit sui contrasti gia'
#' ricostruiti: la stessa funzione serve il build e la verifica di equivalenza.
#' @keywords internal
.ca_parse_factor_levels <- function(fl) {
  empty <- stats::setNames(character(0), character(0))
  if (length(fl) == 0L) return(empty)
  if (is.character(fl)) {
    if (is.na(fl[1L]) || !nzchar(fl[1L])) return(empty)
    parts <- strsplit(fl[1L], ";", fixed = TRUE)[[1L]]
    keys <- character(0); vals <- character(0)
    for (p in parts) {
      j <- regexpr("=", p, fixed = TRUE)
      if (j > 0L) { keys <- c(keys, substr(p, 1L, j - 1L)); vals <- c(vals, substr(p, j + 1L, nchar(p))) }
      else        { keys <- c(keys, p); vals <- c(vals, "") }
    }
    return(stats::setNames(vals, tolower(trimws(keys))))
  }
  keys <- vapply(fl, function(z) as.character(z$key   %||% ""), character(1L))
  vals <- vapply(fl, function(z) as.character(z$value %||% ""), character(1L))
  stats::setNames(vals, tolower(trimws(keys)))
}

#' Normalizza un valore per il confronto trattato-vs-controllo
#' @keywords internal
.ca_normalize_value <- function(x) {
  if (length(x) == 0L || is.na(x[1L])) return("")
  s <- tolower(trimws(x[1L]))
  s <- gsub("\\b\\d+(\\.\\d+)?\\s?(nm|um|\u00b5m|mm|mg|ng|ug|\u00b5g|%|h|hr|hrs|hpi|dpi|day|days|d|week|weeks|min|moi|pfu|ml)\\b",
            " ", s, perl = TRUE)
  s <- gsub("\\b\\d+(\\.\\d+)?\\b", " ", s)
  s <- gsub("[^a-z ]+", " ", s)
  trimws(gsub("\\s+", " ", s))
}

#' Classe semantica di una chiave dei factor_levels
#' @keywords internal
.ca_classify_key <- function(key) {
  k <- tolower(trimws(key))
  if (k %in% .CA_NUISANCE_KEYS) return("nuisance")
  if (grepl("genet|genotype|transgene|knock|sirna|shrna|sgrna|crispr|mutat|mutant|overexpress|engineer|guide|vector|construct|allele|\\boe\\b|perturbation_type|gene", k)) return("genetic")
  if (grepl("treat|drug|compound|dose|concentr|perturbation|exposure|agent|stimul|ligand|inhibitor|cytokine|small_molecule|molecule|chemical|smallmolecule", k)) return("drug")
  if (grepl("infect|virus|viral|pathogen|bacteri|\\bmoi\\b|inocul|vaccin", k)) return("infection")
  if (grepl("disease|diagnos|clinical|tumor|tumour|cancer|malign|severity|grade|patholog|condition|response|remission|\\bstage\\b|status|phenotype|subtype", k)) return("disease")
  if (grepl("diet|hypox|oxygen|normox|glucose|fasting|temperature|irradiat|radiat|starv|nutrient|media|medium|serum", k)) return("environment")
  if (grepl("time|timepoint|time_point|duration|hour|\\bday\\b|week|developmental|differentiat", k)) return("time")
  "other"
}

#' Delta fra i due bracci: che cosa cambia, di che classe, con quali valori
#' @keywords internal
.ca_delta <- function(treated_fl, control_fl) {
  tv_all <- .ca_parse_factor_levels(treated_fl)
  cv_all <- .ca_parse_factor_levels(control_fl)
  keys <- union(names(tv_all), names(cv_all))
  k_out <- character(0); cls_out <- character(0)
  tval <- character(0); cval <- character(0)
  for (k in keys) {
    a <- if (k %in% names(tv_all)) tv_all[[k]] else ""
    b <- if (k %in% names(cv_all)) cv_all[[k]] else ""
    if (identical(.ca_normalize_value(a), .ca_normalize_value(b))) next
    cls <- .ca_classify_key(k)
    if (identical(cls, "nuisance")) next
    k_out <- c(k_out, k); cls_out <- c(cls_out, cls)
    tval <- c(tval, a); cval <- c(cval, b)
  }
  dominant <- if (length(cls_out) == 0L) NA_character_
              else .CA_CLASS_PRIORITY[.CA_CLASS_PRIORITY %in% cls_out][1L]
  list(
    keys = k_out, classes = cls_out,
    treated_values = tval, control_values = cval,
    dominant_class = dominant,
    classes_signature = paste(sort(unique(cls_out)), collapse = "+")
  )
}
```

- [ ] **Step 4: verificare che passino**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: PASS, 0 FAIL.

- [ ] **Step 5: commit**

```bash
git add R/stage3-contrast-anchor.R tests/testthat/test-stage3-contrast-anchor.R
git commit -m "Delta del contrasto dai factor_levels (TDD)"
```

---

### Task 2: risoluzione blindata dell'entità

**Files:**
- Modify: `R/stage3-contrast-anchor.R`
- Test: `tests/testthat/test-stage3-contrast-anchor.R`

**Interfaces:**
- Consumes: `.ca_delta()` (Task 1).
- Produces:
  - `.ca_strip_units(x)`, `.ca_is_unit_or_nonentity(tok)`, `.ca_sanitize_phrase(x)` → character(1).
  - `.ca_acronym_ok(candidate, name)` → logical(1).
  - `.ca_candidates(values, treated_label, contrast_class)` → character vector di candidati.
  - `.ca_resolve_entity(contrast_class, raw_values, candidates, ontology_env)` →
    `list(id, name, source, candidate)`; `id = NA_character_` se non risolve.

**Perche' "blindata":** passare il `treated_label` intero al resolver produce entita' spurie
(`CD8 T cells` → CD8A) e le unita' di misura collidono coi sinonimi (`ug/ml` → `ML` → THPO). Il
`treated_label` intero e' ammesso solo per `infection`/`disease`/`genetic`, mai per `drug`.

- [ ] **Step 1: scrivere i test che falliscono**

```r
test_that(".ca_strip_units toglie dosi e unita' senza spezzare i nomi", {
  expect_equal(.ca_strip_units("GO 1 ug/ml"), "go")
  expect_equal(.ca_strip_units("SARS-CoV-2 MOI 1 24h"), "sars-cov-2 moi")
  # il numero attaccato al nome NON si tocca: "sars-cov-2" non deve diventare "sars-cov"
  expect_true(grepl("sars-cov-2", .ca_strip_units("SARS-CoV-2 infected")))
  expect_true(grepl("il-6", .ca_strip_units("IL-6 10 ng/ml")))
})

test_that(".ca_is_unit_or_nonentity riconosce cio' che non e' mai un'entita'", {
  expect_true(.ca_is_unit_or_nonentity("ml"))
  expect_true(.ca_is_unit_or_nonentity("untreated"))
  expect_true(.ca_is_unit_or_nonentity("24"))
  expect_true(.ca_is_unit_or_nonentity("go"))     # sotto i 3 caratteri
  expect_false(.ca_is_unit_or_nonentity("enzalutamide"))
})

test_that(".ca_acronym_ok blocca le sigle corte che non coincidono col nome risolto", {
  # "ML" e' sinonimo ImmPort di Thrombopoietin: e' un'unita' di volume
  expect_false(.ca_acronym_ok("ml", "Thrombopoietin"))
  expect_true(.ca_acronym_ok("lps", "LPS"))
  expect_true(.ca_acronym_ok("enzalutamide", "enzalutamide"))
})

test_that(".ca_candidates non passa il label intero per la classe drug", {
  cand <- .ca_candidates("Enzalutamide", "LNCaP CD8 T cells Enzalutamide Treated", "drug")
  expect_true("enzalutamide" %in% cand)
  expect_false(any(grepl("cd8", cand)))
  # per infection il label intero e' ammesso: il nome del patogeno spesso sta solo li'
  cand2 <- .ca_candidates("infected", "Calu-3 infected with SARS-CoV-2", "infection")
  expect_true(any(grepl("sars-cov-2", cand2)))
})

test_that(".ca_resolve_entity risolve le entita' vere (dizionari reali)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_equal(.ca_resolve_entity("drug", "Enzalutamide", .ca_candidates("Enzalutamide", NA, "drug"), oe)$id,
               "CHEBI:68534")
  expect_equal(.ca_resolve_entity("drug", "SARS-CoV-2 MOI 1 24h",
                                  .ca_candidates("SARS-CoV-2 MOI 1 24h", NA, "drug"), oe)$id,
               "NCBITaxon:2697049")
  expect_true(is.na(.ca_resolve_entity("drug", "untreated",
                                       .ca_candidates("untreated", NA, "drug"), oe)$id))
})

test_that(".ca_resolve_entity non trasforma le unita' di misura in entita'", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_resolve_entity("drug", "GO 1 ug/ml", .ca_candidates("GO 1 ug/ml", NA, "drug"), oe)
  expect_false(identical(r$id, "HGNC:11795"))   # THPO
})
```

- [ ] **Step 2: verificare che falliscano**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: FAIL, `could not find function ".ca_strip_units"`.

- [ ] **Step 3: implementazione**

```r
#' Unita' di misura e parole che non sono mai un'entita'
#' @keywords internal
.CA_UNITS <- c("ml","ul","dl","l","ug","mg","ng","pg","kg","g","nm","um","mm","pm","cm","mol",
  "mmol","umol","nmol","moi","pfu","ffu","tcid","iu","hr","hrs","min","sec","h","d",
  "day","days","week","weeks","wk","month","months","hour","hours","hpi","dpi","rpm",
  "per","dose","doses","conc","final","approx","total","fold","percent")

#' @keywords internal
.CA_NONENTITY <- c("none","control","controls","vehicle","untreated","treated","treatment","treatments",
  "mock","naive","baseline","normal","healthy","wildtype","wild","type","sample","samples",
  "patient","patients","case","cases","donor","donors","group","groups","condition",
  "conditions","cells","cell","tissue","line","lines","culture","cultured","medium","media",
  "experiment","replicate","replicates","therapy","therapies","after","before","post","pre",
  "with","without","from","the","and","for","anti","plus","versus","status","state","level",
  "levels","number","stage","grade","score","high","low","early","late","acute","chronic",
  "unknown","other","test","exposure","exposed","stimulated","infected","biopsy","blood",
  "serum","plasma","primary","secondary","human","male","female")

#' Toglie dosi, unita' e tempi senza spezzare i nomi con suffisso numerico
#'
#' I numeri isolati si tolgono SOLO fra spazi: \code{\\b\\d+\\b} distruggeva
#' \code{sars-cov-2} -> \code{sars-cov} (che e' il SARS del 2003, un'altra specie)
#' e ogni nome tipo IL-6, MCF-7.
#' @keywords internal
.ca_strip_units <- function(x) {
  if (length(x) == 0L || is.na(x[1L])) return("")
  s <- tolower(trimws(paste(x, collapse = " ")))
  s <- gsub("\\b\\d+([.,]\\d+)?\\s*(ug|mg|ng|pg|kg|g|ul|ml|dl|l|nm|um|mm|pm|mol|mmol|umol|nmol|iu|moi|pfu|ffu|%)\\s*(/\\s*(ml|l|kg|g|ul))?\\b", " ", s, perl = TRUE)
  s <- gsub("\\b\\d+([.,]\\d+)?\\s*(h|hr|hrs|hour|hours|d|day|days|week|weeks|wk|min|sec|hpi|dpi)\\b", " ", s, perl = TRUE)
  s <- gsub("\\b(ug|mg|ng|pg|kg|ul|ml|dl|nm|um|mm|iu|moi|pfu|ffu)\\s*/\\s*(ml|l|kg|g|ul|min)\\b", " ", s, perl = TRUE)
  s <- gsub("[/\\\\]", " ", s)
  s <- gsub("(^|\\s)\\d+([.,]\\d+)?(?=\\s|$)", " ", s, perl = TRUE)
  trimws(gsub("\\s+", " ", s))
}

#' @keywords internal
.ca_is_unit_or_nonentity <- function(tok) {
  t <- gsub("[^a-z0-9+-]", "", tolower(trimws(tok)))
  if (!nzchar(t)) return(TRUE)
  if (t %in% .CA_UNITS || t %in% .CA_NONENTITY) return(TRUE)
  if (!grepl("[a-z]", t)) return(TRUE)
  nchar(t) < 3L
}

#' Sanitizza una frase tenendo i nomi interi
#'
#' Si tolgono solo i token-unita': tagliare anche i token corti spezzerebbe i
#' nomi veri (\code{SARS CoV 2} -> \code{sars cov}, \code{IL 6} -> \code{il}).
#' @keywords internal
.ca_sanitize_phrase <- function(x) {
  s <- .ca_strip_units(x)
  w <- strsplit(s, "[^a-z0-9+-]+")[[1L]]
  w <- w[nzchar(w) & !(w %in% .CA_UNITS)]
  trimws(paste(w, collapse = " "))
}

#' Guardia sulle sigle: un candidato corto vale solo se coincide col nome risolto
#'
#' \code{ML} (unita' di volume) e' sinonimo ImmPort di Thrombopoietin, \code{HGI}
#' risolve a IL6. Senza questa guardia il resolver battezza le unita' di misura.
#' @keywords internal
.ca_acronym_ok <- function(candidate, name) {
  alnum <- function(z) gsub("[^a-z0-9]", "", tolower(z %||% ""))
  a <- alnum(candidate)
  if (nchar(a) > 4L) return(TRUE)
  !is.na(name) && nzchar(name %||% "") && identical(a, alnum(name))
}

#' Candidati da passare al resolver, in ordine di specificita'
#' @keywords internal
.ca_candidates <- function(values, treated_label = NA_character_, contrast_class = NA_character_) {
  out <- character(0)
  for (v in values) {
    if (is.na(v) || !nzchar(trimws(v))) next
    s <- .ca_sanitize_phrase(v)
    if (nzchar(s) && !.ca_is_unit_or_nonentity(s)) out <- c(out, s)
    for (p in strsplit(s, "[,;+&]| and | plus | with ")[[1L]]) {
      p <- trimws(p)
      if (nzchar(p) && !.ca_is_unit_or_nonentity(p)) out <- c(out, p)
    }
    for (tk in strsplit(s, "[^a-z0-9-]+")[[1L]]) if (!.ca_is_unit_or_nonentity(tk)) out <- c(out, tk)
  }
  # il label intero e' ammesso solo dove il nome sta spesso solo li'
  if (!is.na(contrast_class) && contrast_class %in% c("infection", "disease", "genetic") &&
      !is.na(treated_label)) {
    s <- .ca_sanitize_phrase(treated_label)
    if (nzchar(s) && !.ca_is_unit_or_nonentity(s)) out <- c(out, s)
  }
  unique(out[nzchar(out)])
}

#' Risolve l'entita' del delta con i resolver della classe dominante
#'
#' \code{raw_values} = valori grezzi (servono a ChEBI: gli alias hanno
#' punteggiatura, \code{poly(I:C)} non e' \code{poly i c}); \code{candidates} =
#' sanitizzati.
#' @keywords internal
.ca_resolve_entity <- function(contrast_class, raw_values, candidates, ontology_env) {
  none <- list(id = NA_character_, name = NA_character_, source = "UNRESOLVED", candidate = NA_character_)
  if (is.na(contrast_class)) return(none)
  is_canon <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  hit <- function(r, cand) list(id = r$id, name = r$name, source = r$source %||% "RESOLVER", candidate = cand)
  raw <- trimws(tolower(as.character(raw_values))); raw <- raw[nzchar(raw) & !is.na(raw)]
  both <- unique(c(raw, candidates))
  if (identical(contrast_class, "drug")) {
    for (cand in both) { r <- .normalize_compound_to_chebi(cand, ontology_env); if (is_canon(r$id)) return(hit(r, cand)) }
    for (cand in candidates) {
      r <- .normalize_cytokine_to_hgnc(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
    # la classe viene dal NOME della chiave ("treatment" -> drug): se il valore e'
    # un patogeno (SARS-CoV-2) il ramo drug non lo vedrebbe.
    for (cand in both) {
      r <- .normalize_pathogen_to_taxid(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (identical(contrast_class, "infection")) {
    for (cand in both) {
      r <- .normalize_pathogen_to_taxid(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (identical(contrast_class, "disease")) {
    for (cand in both) {
      r <- .normalize_disease_to_mesh(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (identical(contrast_class, "genetic")) {
    for (cand in candidates) {
      h <- .hgnc_lookup_symbol(cand, env = ontology_env)
      if (!is.null(h) && !is.null(h$hgnc_int))
        return(list(id = paste0("HGNC:", h$hgnc_int), name = h$primary_symbol,
                    source = "HGNC", candidate = cand))
    }
  }
  none
}
```

- [ ] **Step 4: verificare che passino**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: PASS. Se i dizionari reali non sono in cache i 2 test end-to-end vengono saltati
(`skip_if`), non falliscono.

- [ ] **Step 5: commit**

```bash
git add R/stage3-contrast-anchor.R tests/testthat/test-stage3-contrast-anchor.R
git commit -m "Risoluzione blindata dell'entita' del delta (TDD)"
```

---

### Task 3: le combinazioni

**Files:**
- Modify: `R/stage3-contrast-anchor.R`
- Test: `tests/testthat/test-stage3-contrast-anchor.R`

**Interfaces:**
- Consumes: `.ca_sanitize_phrase()`, `.ca_strip_units()` (Task 2).
- Produces:
  - `.ca_agent_id(part, ontology_env, cache = NULL)` → character(1) (`""` se non è un agente).
  - `.ca_combo_parts(treated_values, ontology_env, cache = NULL)` → character vector (≥2 = combo).
  - `.ca_combo_from_labels(treated_label, control_label, ontology_env, cache = NULL)` → character
    vector dei nomi degli agenti presenti nel trattato e assenti dal controllo.

**Decisione utente:** la combo è **un'entità a sé** (`COMBO:a+b`), non si spezza né si scarta. Gli
agenti presenti su **entrambi** i bracci sono tenuti costanti e non contano
(`SARS-CoV-2 + Ruxolitinib vs SARS-CoV-2` resta un contrasto su ruxolitinib).

- [ ] **Step 1: scrivere i test che falliscono**

```r
test_that(".ca_combo_parts vede la combinazione dentro il valore (GSE197602)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_setequal(.ca_combo_parts("Palbociclib+Indisulam", oe), c("palbociclib", "indisulam"))
  expect_length(.ca_combo_parts("Enzalutamide", oe), 0L)
  # "/" e "_" contano solo se >=2 parti sono agenti veri
  expect_length(.ca_combo_parts("SARS-CoV-2_MOI_1", oe), 0L)
})

test_that(".ca_combo_from_labels non conta gli agenti tenuti costanti", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # ruxolitinib e' l'unico agente del delta: SARS sta su entrambi i bracci
  expect_length(.ca_combo_from_labels("SARS-CoV-2 + Ruxolitinib", "SARS-CoV-2", oe), 0L)
})
```

- [ ] **Step 2: verificare che falliscano**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: FAIL, `could not find function ".ca_combo_parts"`.

- [ ] **Step 3: implementazione**

```r
#' Un agente e' "vero" se risolve a un ID canonico
#'
#' Non basta essere informativo: \code{MOI}, \code{Contact}, \code{053} sono
#' informativi e non sono agenti.
#' @keywords internal
.ca_agent_id <- function(part, ontology_env, cache = NULL) {
  p <- trimws(part)
  if (!nzchar(p)) return("")
  if (!is.null(cache) && exists(p, envir = cache, inherits = FALSE)) return(get(p, envir = cache))
  ok <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  res <- ""
  for (cand in unique(c(p, strsplit(p, " ")[[1L]]))) {
    if (nchar(cand) < 3L) next
    r <- .normalize_compound_to_chebi(cand, ontology_env); if (ok(r$id)) { res <- r$id; break }
    r <- .normalize_cytokine_to_hgnc(cand, ontology_env);  if (ok(r$id) && nchar(cand) > 4L) { res <- r$id; break }
    r <- .normalize_pathogen_to_taxid(cand, ontology_env); if (ok(r$id) && nchar(cand) > 4L) { res <- r$id; break }
    h <- .hgnc_lookup_symbol(sub("^(sh|si|sg)", "", cand), env = ontology_env)
    if (!is.null(h) && !is.null(h$hgnc_int) && nchar(cand) > 3L) { res <- paste0("HGNC:", h$hgnc_int); break }
  }
  if (!is.null(cache)) assign(p, res, envir = cache)
  res
}

#' Normalizza una parte di combinazione (soglia sui caratteri della PARTE)
#'
#' La soglia va sui caratteri alfanumerici della parte, non su ogni token:
#' \code{M.tb} e' fatto di token da 1 e 2 caratteri e veniva buttato, per cui la
#' co-infezione \code{M.tb + CMV} non era vista come combinazione.
#' @keywords internal
.ca_normalize_part <- function(p) {
  w <- strsplit(gsub("[^a-z0-9 -]", " ", tolower(p)), "[^a-z0-9-]+")[[1L]]
  w <- w[nzchar(w) & !(w %in% .CA_NONENTITY)]
  s <- paste(w, collapse = " ")
  if (nchar(gsub("[^a-z0-9]", "", s)) >= 3L) s else ""
}

#' Combinazione dentro il valore di UNA chiave
#'
#' \code{+}, \code{and}, \code{plus} bastano da soli; \code{/} e \code{_} solo se
#' >=2 parti sono agenti veri (cosi' \code{Bleomycin/Alpha-Lipoic Acid} passa e
#' \code{SARS-CoV-2_MOI_1} no).
#' @keywords internal
.ca_combo_parts <- function(treated_values, ontology_env, cache = NULL) {
  best <- character(0)
  is_agent <- function(p) nzchar(.ca_agent_id(p, ontology_env, cache))
  for (v in treated_values) {
    s <- .ca_strip_units(v)
    if (!nzchar(s)) next
    strong <- trimws(strsplit(s, "\\s*[+&]\\s*|\\s+and\\s+|\\s+plus\\s+", perl = TRUE)[[1L]])
    ps <- unique(vapply(strong, .ca_normalize_part, character(1L))); ps <- ps[nzchar(ps)]
    if (length(ps) >= 2L && sum(vapply(ps, is_agent, logical(1L))) >= 1L) {
      if (length(ps) > length(best)) best <- ps
      next
    }
    weak <- trimws(strsplit(s, "\\s*[/_]\\s*", perl = TRUE)[[1L]])
    pw <- unique(vapply(weak, .ca_normalize_part, character(1L))); pw <- pw[nzchar(pw)]
    if (length(pw) >= 2L && sum(vapply(pw, is_agent, logical(1L))) >= 2L) {
      if (length(pw) > length(best)) best <- pw
    }
  }
  best
}

#' Agenti nominati nel label trattato e assenti dal controllo
#'
#' Molte combinazioni stanno nel label e non nel delta ("Estradiol and
#' Fulvestrant", "Bleomycin/Alpha-Lipoic Acid"). Non serve un separatore.
#' @keywords internal
.ca_combo_from_labels <- function(treated_label, control_label, ontology_env, cache = NULL) {
  agents_of <- function(lab) {
    s <- .ca_strip_units(lab)
    toks <- strsplit(gsub("[^a-z0-9 -]", " ", s), "[^a-z0-9-]+")[[1L]]
    toks <- toks[nzchar(toks) & nchar(gsub("[^a-z0-9]", "", toks)) >= 3L & !(toks %in% .CA_NONENTITY)]
    ids <- character(0); nms <- character(0)
    for (tk in unique(toks)) {
      a <- .ca_agent_id(tk, ontology_env, cache)
      if (nzchar(a)) { ids <- c(ids, a); nms <- c(nms, tk) }
    }
    stats::setNames(ids, nms)
  }
  at <- agents_of(treated_label); ac <- agents_of(control_label)
  keep <- at[!(at %in% ac)]
  if (length(unique(keep)) >= 2L) unique(names(keep)) else character(0)
}
```

- [ ] **Step 4: verificare che passino**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: PASS.

- [ ] **Step 5: commit**

```bash
git add R/stage3-contrast-anchor.R tests/testthat/test-stage3-contrast-anchor.R
git commit -m "Rilevatore delle combinazioni per l'anchor del contrasto (TDD)"
```

---

### Task 4: il verdetto per-membro (entità + verso + tipo di controllo + regole)

**Files:**
- Modify: `R/stage3-contrast-anchor.R`
- Test: `tests/testthat/test-stage3-contrast-anchor.R`

**Interfaces:**
- Consumes: Task 1-3, più `.cg_*` (`R/stage3-contrast-gate.R`) e `.rp_row_defect`
  (`R/stage3-row-pairing.R`), già esistenti e testati.
- Produces: `.ca_member_contrast(treated_label, control_label, treated_fl, control_fl,
  anchor_name, anchor_id, ontology_env, caches = NULL)` →
  `list(entity, direction, control_key, contrast_class, entity_source, drop_reason)`.
  `drop_reason == ""` ⇔ il membro è tenuto; in tal caso `entity` non è `NA`.

**L'ordine delle regole è quello misurato** in `109-fase1-v11-gate.R` e non va cambiato: un ordine
diverso cambia le ragioni di scarto (e quindi i conteggi) anche a parità di esito.

- [ ] **Step 1: scrivere i test che falliscono**

```r
test_that(".ca_member_contrast tiene un contrasto pulito (GSE147876 enzalutamide)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast(
    treated_label = "LNCaP Enzalutamide Treated", control_label = "LNCaP Vehicle Control",
    treated_fl = "cell_line=LNCaP;treatment=Enzalutamide",
    control_fl = "cell_line=LNCaP;treatment=Vehicle",
    anchor_name = "enzalutamide", anchor_id = "CHEBI:68534", ontology_env = oe)
  expect_equal(r$drop_reason, "")
  expect_equal(r$entity, "CHEBI:68534")
  expect_equal(r$direction, "gain")
  expect_equal(r$control_key, "vehicle_untreated")
})

test_that(".ca_member_contrast ricompone SARS-CoV-2 sotto l'ID del patogeno", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("Calu-3 SARS-CoV-2 infected", "mock",
                           "treatment=SARS-CoV-2 MOI 1 24h", "treatment=mock",
                           NA_character_, NA_character_, oe)
  expect_equal(r$drop_reason, "")
  expect_equal(r$entity, "NCBITaxon:2697049")
})

test_that(".ca_member_contrast marca la combinazione come entita' a se' (GSE197602)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("A549 cells treated with Palbociclib and Indisulam",
                           "Untreated A549 cells",
                           "cell_line=A549;treatment=Palbociclib+Indisulam",
                           "cell_line=A549;treatment=untreated",
                           NA_character_, NA_character_, oe)
  expect_equal(r$entity, "COMBO:indisulam+palbociclib")
  expect_equal(r$entity_source, "COMBO")
})

test_that(".ca_member_contrast scarta il delta vuoto (GSE72509)", {
  oe <- .load_ontology_dicts()
  r <- .ca_member_contrast("Healthy Control", "Healthy Control",
                           "disease_state=healthy;treatment=control",
                           "disease_state=healthy;treatment=control",
                           NA_character_, NA_character_, oe)
  expect_equal(r$drop_reason, "no_delta")
  expect_true(is.na(r$entity))
})

test_that(".ca_member_contrast scarta la riga mal appaiata sul tempo (GSE218827)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("HEK293T treated with siCont for 24 hours",
                           "HEK293T treated with DMSO for 0 hours (control)",
                           "time=24h;treatment=siCont", "time=0h;treatment=DMSO",
                           NA_character_, NA_character_, oe)
  expect_equal(r$drop_reason, "riga_tempo_non_appaiato")
})

test_that(".ca_member_contrast scarta quando l'entita' e' tenuta costante (GSE97326)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("HEK293T_MLL3_G368V_mutation", "HEK293T_wild_type_MLL3",
                           "cell_line=HEK293T;genetic_modification=MLL3 G368V mutation",
                           "cell_line=HEK293T;genetic_modification=wild type MLL3",
                           NA_character_, NA_character_, oe)
  expect_equal(r$drop_reason, "entita_costante")
})

test_that(".ca_member_contrast usa il nome dell'anchor quando il delta lo nomina", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # on-contrast: il delta nomina l'entita' che il resolver ha gia' risolto nell'anchor
  r <- .ca_member_contrast("HUVEC hypoxia 1% O2", "HUVEC normoxia",
                           "oxygen=hypoxia 1% O2", "oxygen=normoxia",
                           anchor_name = "hypoxia", anchor_id = "STR:hypoxia",
                           ontology_env = oe)
  expect_equal(r$entity_source, "anchor")
  expect_equal(r$entity, "STR:hypoxia")
})
```

- [ ] **Step 2: verificare che falliscano**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: FAIL, `could not find function ".ca_member_contrast"`.

- [ ] **Step 3: implementazione**

```r
#' ID ontologici che non identificano una perturbazione (classi-ombrello, veicoli)
#' @keywords internal
.CA_BLACKLIST_ID <- c("MeSH:D009369","MeSH:D009361","MeSH:D002277","MeSH:D004194","MeSH:D007239",
  "MeSH:D007249","MeSH:D009371","CHEBI:17499","CHEBI:24431","CHEBI:23367","CHEBI:33232",
  "CHEBI:50906","CHEBI:50845","CHEBI:28262","CHEBI:25367","CHEBI:35341","CHEBI:33699",
  "CHEBI:84123","CHEBI:16236","CHEBI:197439")

#' Ripulisce il valore del delta per il ripiego STR:
#' @keywords internal
.ca_clean_token <- function(x) {
  s <- tolower(trimws(paste(x, collapse = " ")))
  s <- gsub("[_|]+", " ", s)
  s <- gsub("[^a-z ]+", " ", s)
  s <- gsub(paste0("\\b(patient|patients|case|cases|control|controls|healthy|donor|donors|sample|",
                   "samples|primary|culture|cell|cells|from|the|and|of|with|vs|total|rna|tissue|",
                   "line|human|treated|treatment|stimulated|infected|exposed|day|days|hour|hours|",
                   "hr|hrs)\\b"), " ", s)
  trimws(gsub("\\s+", " ", s))
}

#' Verdetto di contrasto per un singolo membro (un confronto trattato-vs-controllo)
#'
#' Applica, nell'ordine misurato in \code{109-fase1-v11-gate.R}, le regole del
#' gate (\code{.cg_*}) e dell'appaiamento della riga (\code{.rp_row_defect}), e
#' restituisce l'identita' del contrasto oppure la ragione dello scarto.
#'
#' @param anchor_name,anchor_id nome canonico e ID gia' risolti nell'anchor del
#'   campione trattato di QUESTO record (ramo on-contrast). \code{NA} = ramo
#'   disattivato per questo membro.
#' @param caches list opzionale di environment di memoizzazione
#'   (\code{agent}, \code{row}, \code{token}).
#' @return list(entity, direction, control_key, contrast_class, entity_source,
#'   drop_reason). \code{drop_reason == ""} = membro tenuto.
#' @keywords internal
.ca_member_contrast <- function(treated_label, control_label, treated_fl, control_fl,
                                anchor_name = NA_character_, anchor_id = NA_character_,
                                ontology_env = NULL, caches = NULL) {
  out <- function(reason, entity = NA_character_, direction = NA_character_,
                  control_key = NA_character_, cls = NA_character_, src = NA_character_) {
    list(entity = entity, direction = direction, control_key = control_key,
         contrast_class = cls, entity_source = src, drop_reason = reason)
  }
  agent_cache <- caches$agent
  row_cache   <- caches$token

  d <- .ca_delta(treated_fl, control_fl)
  if (is.na(d$dominant_class)) return(out("no_delta"))
  cls <- d$dominant_class
  tval <- d$treated_values; cval <- d$control_values

  if (.cg_broken_contrast(treated_label, control_label, treated_fl, control_fl))
    return(out("contrasto_rotto"))
  if (.cg_is_noncontrol(control_label))            return(out("controllo_non_valido"))
  if (.cg_resistance_mismatch(treated_label, control_label))
    return(out("resistenza_asimmetrica"))
  if (.cg_is_multiclass(d$classes_signature))      return(out("delta_multiclasse"))
  if (identical(tolower(trimws(treated_label)), tolower(trimws(control_label))))
    return(out("label_degenere"))
  if (.cg_is_control_like_treated(paste(tval, collapse = " ")))
    return(out("trattato_e_un_controllo"))

  direction <- .cg_direction(tval)
  if (identical(direction, "ambiguo")) return(out("verso_ambiguo"))

  # entita' del delta (serve anche a decidere l'asse clinico/sperimentale)
  res <- .ca_resolve_entity(cls, tval, .ca_candidates(tval, treated_label, cls), ontology_env)

  # tipo di controllo composito: lato-controllo del delta + materiale + baseline +
  # contesto d'infezione (l'asse clinico/sperimentale vale per OGNI patogeno, non
  # solo quando la chiave si chiama "infection": HIV arriva spesso come cls=drug).
  cvv <- cval[nzchar(trimws(cval))]
  if (!length(cvv)) cvv <- "untreated"
  ct_base <- paste(sort(unique(vapply(cvv, .normalize_control_type, character(1L)))), collapse = "+")
  material <- if (identical(.cg_material_arm(treated_label, treated_fl), "liquid")) "_liquid" else ""
  is_pathogen <- identical(cls, "infection") ||
    (!is.na(res$id) && startsWith(res$id, "NCBITaxon:"))
  control_key <- paste0(ct_base, material, .cg_baseline_kind(control_label),
                        .cg_infection_context(if (is_pathogen) "infection" else cls,
                                              control_label, treated_label))

  entity_tokens <- function(...) {
    s <- tolower(paste(stats::na.omit(c(...)), collapse = " "))
    t <- strsplit(gsub("[^a-z0-9 -]+", " ", s), " +")[[1L]]
    unique(t[nzchar(t)])
  }

  # combinazione: entita' a se'
  combo <- .ca_combo_parts(tval, ontology_env, agent_cache)
  if (length(combo) < 2L) combo <- .ca_combo_from_labels(treated_label, control_label,
                                                          ontology_env, agent_cache)
  if (cls %in% c("drug", "infection") && length(combo) >= 2L) {
    entity <- paste0("COMBO:", paste(sort(combo), collapse = "+"))
    defect <- .rp_row_defect(treated_label, control_label, cls, entity,
                             entity_tokens(anchor_name, res$name, combo), ontology_env, row_cache)
    if (nzchar(defect)) return(out(paste0("riga_", defect)))
    return(out("", entity, direction, control_key, cls, "COMBO"))
  }

  # entita': on-contrast (nome gia' risolto nell'anchor di questo record) ->
  # delta risolto -> ripiego STR:
  entity <- NA_character_; src <- NA_character_
  if (!is.na(anchor_name) && nzchar(anchor_name) && !is.na(anchor_id) &&
      .cg_matches_all_words(.cg_distinctive_tokens(anchor_name), paste(tval, collapse = " "))) {
    entity <- anchor_id; src <- "anchor"
  } else if (!is.na(res$id) && !startsWith(res$id, "STR:")) {
    entity <- res$id; src <- "onto"
  } else {
    tk <- .ca_clean_token(tval)
    if (nzchar(tk)) { entity <- paste0("STR:", gsub(" ", "_", tk)); src <- "STR" }
  }
  if (is.na(entity)) return(out("no_entity"))

  raw <- sub("^STR:", "", entity)
  if (startsWith(entity, "STR:") && .cg_is_generic_token(gsub("_", " ", raw)))
    return(out("str_generico"))
  if (entity %in% .CA_BLACKLIST_ID) return(out("id_blacklist"))
  if (.cg_is_inducer(gsub("_", " ", raw))) return(out("induttore"))
  rn <- tolower(res$name %||% "")
  if (nzchar(rn) && !grepl(" ", rn) &&
      (.cg_is_generic_token(rn) || length(.cg_anatomy(rn)) > 0L)) return(out("nome_generico"))
  if (nzchar(rn) && .cg_is_umbrella_name(rn)) return(out("nome_ombrello"))

  # l'entita' e' TENUTA COSTANTE fra i due bracci: quel membro non la misura
  probe <- if (!is.na(res$candidate) && nzchar(res$candidate)) res$candidate else gsub("_", " ", raw)
  probe <- trimws(gsub("[^a-z0-9 ]+", " ", tolower(probe)))
  if (nzchar(probe) && nchar(gsub("[^a-z0-9]", "", probe)) >= 3L) {
    cl_norm <- gsub("[^a-z0-9]+", " ", tolower(control_label))
    if (grepl(paste0("(^| )", probe, "( |$)"), cl_norm)) return(out("entita_costante"))
  }

  defect <- .rp_row_defect(treated_label, control_label, cls, entity,
                           entity_tokens(anchor_name, res$name, raw), ontology_env, row_cache)
  if (nzchar(defect)) return(out(paste0("riga_", defect)))

  out("", entity, direction, control_key, cls, src)
}
```

- [ ] **Step 4: verificare che passino**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-anchor")'`
Atteso: PASS. Se un test fallisce **non aggiustare la regola**: la regola è già misurata. Verificare
prima di tutto che il caso di test riporti la riga vera (label e `factor_levels` copiati da
`fase1-v11-results.rds`).

- [ ] **Step 5: commit**

```bash
git add R/stage3-contrast-anchor.R tests/testthat/test-stage3-contrast-anchor.R
git commit -m "Verdetto di contrasto per-membro: entita', verso, tipo di controllo (TDD)"
```

---

### Task 5: il builder dei record `cgroup` e l'innesto nel build

**Files:**
- Modify: `R/stage3-build.R` (aggiunta di `.build_contrast_group_records()` dopo
  `.build_group_records()`, riga ~518; innesto nelle fasi 2/3/5 di `build_stage3_clusters()`)
- Test: `tests/testthat/test-stage3-contrast-group-records.R` (nuovo)

**Interfaces:**
- Consumes: `.ca_member_contrast()` (Task 4), `.precompute_anchor_cache()`, `.extract_hard_filters()`.
- Produces: `.build_contrast_group_records(stage2_master, stage1_master, tier_assignment,
  cache = NULL, ontology_env = NULL)` → list di record con
  `mode = "cgroup"`, `record_id = "<series>__<comparison_id>"`, `contrast_key`,
  `contrast_entity`, `contrast_direction`, `contrast_control_key`, `contrast_class`,
  `contrast_entity_source`, `treated_anchor_segments`, `treated_sample_ids`,
  `control_sample_ids`, `n_treated_group`, `n_control_group`, `control_type`,
  `hard_filters`, `stage1_facts`, più `contrast_drop_reason` sui record scartati.

- [ ] **Step 1: scrivere il test che fallisce**

```r
# tests/testthat/test-stage3-contrast-group-records.R
# Il record di gruppo nasce dal CONTRASTO (ADR-0025).

make_study <- function() {
  list(series_id = "GSE147876", design_kind = "treatment_vs_vehicle",
       replicate_groups = list(
         list(group_id = "rg1", primary_role = "treated", label_human = "LNCaP Enzalutamide Treated",
              sample_ids = list("GSM1", "GSM2"),
              factor_levels = list(list(key = "cell_line", value = "LNCaP"),
                                   list(key = "treatment", value = "Enzalutamide"))),
         list(group_id = "rg2", primary_role = "control", label_human = "LNCaP Vehicle Control",
              sample_ids = list("GSM3", "GSM4"),
              factor_levels = list(list(key = "cell_line", value = "LNCaP"),
                                   list(key = "treatment", value = "Vehicle")))),
       comparisons = list(list(comparison_id = "cmp1", treated_group = "rg1",
                               control_group = "rg2", control_type = "vehicle")))
}

test_that(".build_contrast_group_records produce un record per comparison", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  s1 <- list(GSM1 = make_test_sample_fact(), GSM3 = make_test_sample_fact())
  recs <- .build_contrast_group_records(list(make_study()), s1,
                                        stage3_default_config()$tier_assignment,
                                        ontology_env = oe)
  expect_length(recs, 1L)
  r <- recs[[1L]]
  expect_equal(r$mode, "cgroup")
  expect_equal(r$record_id, "GSE147876__cmp1")
  expect_equal(r$contrast_entity, "CHEBI:68534")
  expect_equal(r$contrast_key, "CHEBI:68534||gain||vehicle_untreated")
  expect_equal(r$treated_sample_ids, c("GSM1", "GSM2"))
  expect_equal(r$control_sample_ids, c("GSM3", "GSM4"))
})

test_that(".build_contrast_group_records non emette record per i confronti scartati", {
  oe <- .load_ontology_dicts()
  st <- make_study()
  # i due bracci diventano identici: delta vuoto
  st$replicate_groups[[2L]]$factor_levels <- st$replicate_groups[[1L]]$factor_levels
  st$replicate_groups[[2L]]$label_human   <- st$replicate_groups[[1L]]$label_human
  s1 <- list(GSM1 = make_test_sample_fact(), GSM3 = make_test_sample_fact())
  recs <- .build_contrast_group_records(list(st), s1,
                                        stage3_default_config()$tier_assignment,
                                        ontology_env = oe)
  expect_length(recs, 0L)
})

test_that("i record group e pair NON cambiano (retrocompatibilita')", {
  s1 <- list(GSM1 = make_test_sample_fact(), GSM3 = make_test_sample_fact())
  ta <- stage3_default_config()$tier_assignment
  g <- .build_group_records(list(make_study()), s1, ta)
  p <- .build_pair_records(list(make_study()), s1, ta)
  expect_length(g, 2L)   # un record per replicate_group, come prima
  expect_length(p, 1L)   # un record per comparison, come prima
  expect_equal(g[[1L]]$mode, "group")
  expect_equal(p[[1L]]$mode, "pair")
})
```

Nota: `make_test_sample_fact()` è l'helper già esistente in
`tests/testthat/helper-stage3-fixtures.R` (caricato automaticamente da testthat prima dei file
`test-stage3-*.R`). Non crearne uno nuovo.

- [ ] **Step 2: verificare che fallisca**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-group-records")'`
Atteso: FAIL, `could not find function ".build_contrast_group_records"`.

- [ ] **Step 3: implementazione del builder**

```r
# in R/stage3-build.R, subito dopo .build_group_records()

#' Costruisce i record di gruppo derivati dal CONTRASTO (ADR-0025)
#'
#' Un record per ogni \code{comparison} dello Stadio 2. L'identita' del record
#' non e' la perturbazione del campione trattato ma cio' che il confronto ISOLA:
#' entita' del delta canonicalizzata, verso, tipo di controllo. I confronti che
#' non isolano una perturbazione (delta vuoto, degeneri, regole del gate, righe
#' mal appaiate) NON producono record: la ragione e' nel campo
#' \code{contrast_drop_reason} dei record scartati, restituiti a parte.
#'
#' @return list di record \code{mode = "cgroup"}. I record scartati sono
#'   nell'attributo \code{"dropped"} (list di \code{{record_id, reason}}).
#' @keywords internal
.build_contrast_group_records <- function(stage2_master, stage1_master, tier_assignment,
                                          cache = NULL, ontology_env = NULL) {
  if (is.null(ontology_env)) ontology_env <- .load_ontology_dicts()
  caches <- list(agent = new.env(parent = emptyenv()),
                 token = new.env(parent = emptyenv()))
  fl_of <- function(rg) {
    fl <- rg$factor_levels
    if (length(fl) == 0L) return("")
    paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
  }
  lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid

  records <- list(); dropped <- list()
  for (study in stage2_master) {
    sid <- study$series_id
    rg_lookup <- stats::setNames(
      study$replicate_groups,
      vapply(study$replicate_groups, function(g) g$group_id, character(1L))
    )
    for (cmp in study$comparisons) {
      tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
      if (is.null(tg) || is.null(cg)) next
      if (length(tg$sample_ids) == 0L || length(cg$sample_ids) == 0L) next
      tg_sample <- tg$sample_ids[[1L]]
      tg_facts <- stage1_master[[tg_sample]]
      if (is.null(tg_facts)) next

      segs <- if (!is.null(cache)) cache$anchors[[sprintf("%s|treated", tg_sample)]]
              else .extract_anchor_segments(tg_facts, stage2_role = "treated",
                                            ontology_env = ontology_env)
      tm <- attr(segs, "tracking_meta")

      v <- .ca_member_contrast(
        treated_label = lab_of(tg, cmp$treated_group),
        control_label = lab_of(cg, cmp$control_group),
        treated_fl    = fl_of(tg), control_fl = fl_of(cg),
        anchor_name   = tm$canonical_name %||% NA_character_,
        anchor_id     = tm$agent_id_resolved %||% NA_character_,
        ontology_env  = ontology_env, caches = caches)

      rid <- sprintf("%s__%s", sid, cmp$comparison_id)
      if (nzchar(v$drop_reason)) {
        dropped[[length(dropped) + 1L]] <- list(record_id = rid, mode = "cgroup",
                                                reason = "contrast_gate",
                                                details = v$drop_reason)
        next
      }
      hf <- if (!is.null(cache)) cache$hard_filters[[tg_sample]]
            else .extract_hard_filters(tg_facts, tier_assignment)

      records[[length(records) + 1L]] <- list(
        record_id               = rid,
        mode                    = "cgroup",
        series_id               = sid,
        comparison_id           = cmp$comparison_id,
        treated_anchor_segments = segs,
        n_treated_group         = length(tg$sample_ids),
        n_control_group         = length(cg$sample_ids),
        treated_sample_ids      = as.character(unlist(tg$sample_ids)),
        control_sample_ids      = as.character(unlist(cg$sample_ids)),
        control_type            = cmp$control_type,
        hard_filters            = hf,
        stage1_facts            = tg_facts,
        contrast_key            = paste(v$entity, v$direction, v$control_key, sep = "||"),
        contrast_entity         = v$entity,
        contrast_direction      = v$direction,
        contrast_control_key    = v$control_key,
        contrast_class          = v$contrast_class,
        contrast_entity_source  = v$entity_source
      )
    }
  }
  attr(records, "dropped") <- dropped
  records
}
```

- [ ] **Step 4: innesto in `build_stage3_clusters()`**

In `R/stage3-build.R`, fase 2 (riga ~103), dopo `records_group`:

```r
  records_cgroup <- .build_contrast_group_records(stage2_master, stage1_master, ta, cache)
  cli::cli_inform("[stage3] Phase 2 done: {length(records_pair)} pair + {length(records_group)} group + {length(records_cgroup)} cgroup records")
```

Fase 3 (riga ~109), dopo `group_filt`:

```r
  cgroup_filt <- .filter_eligible_records(records_cgroup)
  # gli scarti del gate di contrasto sono non_clusterable a pieno titolo: la
  # perdita e' auditabile, non silenziosa.
  cgroup_filt$non_clusterable <- c(cgroup_filt$non_clusterable, attr(records_cgroup, "dropped"))
```

Fase 5 (dopo il ciclo `for (mode in c("pair", "group"))`, riga ~168): blocco separato — niente
partizione per hard filter, un solo livello.

```r
  # I cluster derivati dal contrasto hanno UN SOLO livello (la chiave e' gia'
  # l'identita' completa) e nessuna partizione per hard filter: aggiungere
  # subcellular/context_kind frammenterebbe rispetto ai numeri misurati.
  # level = 5 e' un valore nuovo, non un L4 travestito: tiene i cgroup fuori dal
  # ramo mega per costruzione (usable_mega_strict richiede level in {0,1}).
  if (length(cgroup_filt$eligible) > 0L) {
    cg_keyed <- lapply(cgroup_filt$eligible, function(r) { r$anchor_key <- r$contrast_key; r })
    assignments_all[[length(assignments_all) + 1L]] <-
      .assign_records_to_clusters(cg_keyed, "cgroup", .CA_CONTRAST_LEVEL)
    cli::cli_inform("[stage3]   mode=cgroup L{.CA_CONTRAST_LEVEL}: {length(cg_keyed)} record eleggibili")
  }
```

In fase 6 passare i record a `.summarize_clusters()` (parametro nuovo, Task 6) e in fase 8 unire
`cgroup_filt$non_clusterable` a `nc_items`. In `R/stage3-contrast-anchor.R` aggiungere:

```r
#' Livello dei cluster derivati dal contrasto (non e' un L0..L4)
#' @keywords internal
.CA_CONTRAST_LEVEL <- 5L
```

- [ ] **Step 5: verificare i test**

Run: `Rscript -e 'devtools::test(filter="stage3")'`
Atteso: i test nuovi PASS; **tutti i test Stadio 3 preesistenti PASS** (retrocompatibilità).

- [ ] **Step 6: commit**

```bash
git add R/stage3-build.R R/stage3-contrast-anchor.R tests/testthat/test-stage3-contrast-group-records.R
git commit -m "Builder dei record derivati dal contrasto + innesto nel build Stadio 3 (TDD)"
```

---

### Task 6: riepilogo dei cluster e flag di usabilità per il modo `cgroup`

**Files:**
- Modify: `R/stage3-build.R` (`.summarize_clusters`: accettare `eligible_cgroup`)
- Modify: `R/stage3-usability.R` (`.tag_cluster_usability`)
- Test: `tests/testthat/test-stage3-contrast-group-records.R`

**Interfaces:**
- Consumes: record `cgroup` (Task 5).
- Produces: righe di `clusters.rds` con `mode = "cgroup"`, `level = 5`, i quattro flag
  `usable_*` a `FALSE`, e le colonne di contrasto `contrast_entity`, `contrast_direction`,
  `contrast_control_key`, `contrast_entity_source`.

- [ ] **Step 1: scrivere i test che falliscono**

```r
test_that("i cluster cgroup non sono ne' rem ne' mega usable", {
  u <- .tag_cluster_usability(
    list(mode = "cgroup", level = 5L, k = 10L, n_total = 50L, n_studies = 10L, safety_min = 0.9),
    stage3_default_config()$thresholds)
  expect_false(u$usable_rem_strict);  expect_false(u$usable_rem_relaxed)
  expect_false(u$usable_mega_strict); expect_false(u$usable_mega_relaxed)
})
```

- [ ] **Step 2: verificare che fallisca**

Run: `Rscript -e 'devtools::test(filter="stage3-contrast-group-records")'`
Atteso: PASS **già ora** (`is_pair`/`is_group` sono `FALSE` per `cgroup`): il test è una **guardia di
non-regressione**, va comunque scritto e committato. Se fallisce, `.tag_cluster_usability` è stato
modificato da qualcun altro e va indagato prima di procedere.

- [ ] **Step 3: estendere `.summarize_clusters`**

Firma: aggiungere `eligible_cgroup = list()` dopo `eligible_group`. Ovunque il corpo faccia
`if (mode == "pair") eligible_pair else eligible_group`, usare:

```r
  recs_for_mode <- switch(mode, pair = eligible_pair, group = eligible_group,
                          cgroup = eligible_cgroup, eligible_group)
```

Aggiungere al tibble delle colonne (schema vuoto incluso, riga ~547) le quattro colonne di
contrasto, riempite da `NA_character_` per i modi `pair`/`group`:

```r
    contrast_entity        = character(),
    contrast_direction     = character(),
    contrast_control_key   = character(),
    contrast_entity_source = character(),
```

e popolarle dal primo record del cluster quando `mode == "cgroup"`.

In `build_stage3_clusters()` passare `eligible_cgroup = cgroup_filt$eligible`, e aggiungere il conteggio
`n_records_clusterable_cgroup` a `output_counts`.

- [ ] **Step 4: verificare**

Run: `Rscript -e 'devtools::test(filter="stage3")'`
Atteso: tutti PASS.

- [ ] **Step 5: commit**

```bash
git add R/stage3-build.R R/stage3-usability.R tests/testthat/test-stage3-contrast-group-records.R
git commit -m "Riepilogo dei cluster e flag di usabilita' per il modo cgroup"
```

---

### Task 7: Stadio 4 — gate, dispatch e dedup

**Files:**
- Modify: `R/stage4-qc.R` (`.identify_layer_a_clusters` riga ~101; `.dedup_rem_group_by_entity` riga ~27)
- Modify: `R/stage4-dispatch.R` (`.build_group_rem_dispatch_from_stage3` riga ~313)
- Test: `tests/testthat/test-stage4-cgroup-branch.R` (nuovo)

**Interfaces:**
- Consumes: `clusters.rds` con righe `mode = "cgroup"` (Task 6).
- Produces: nessuna funzione nuova; cambia il comportamento di tre funzioni esistenti.

- [ ] **Step 1: scrivere i test che falliscono**

```r
# tests/testthat/test-stage4-cgroup-branch.R
test_that("il gate rem_group seleziona i cluster cgroup e non piu' i group", {
  cl <- tibble::tibble(
    cluster_id = c("cgroup_L5_aaa", "group_L4_bbb"),
    mode = c("cgroup", "group"), level = c(5L, 4L), k = c(5L, 5L),
    n_total = c(20L, 20L), n_studies = c(5L, 5L), safety_min = c(0.2, 0.2),
    usable_rem_strict = FALSE, usable_rem_relaxed = FALSE,
    usable_mega_strict = FALSE, usable_mega_relaxed = FALSE,
    kind_effective_resolved = "small_molecule",
    agent_id_resolved = c("CHEBI:68534", "CHEBI:68534"),
    contrast_direction = c("gain", NA_character_))
  sel <- .identify_layer_a_clusters(cl, stage4_default_config())
  rg <- sel[sel$method == "rem_group", ]
  expect_equal(nrow(rg), 1L)
  expect_equal(rg$cluster_id, "cgroup_L5_aaa")
})

test_that("la dedup per entita' tiene conto del verso", {
  cl <- tibble::tibble(
    cluster_id = c("a", "b", "c"), mode = "cgroup", level = 5L,
    k = c(10L, 4L, 6L), n_total = c(40L, 12L, 20L),
    kind_effective_resolved = "small_molecule",
    agent_id_resolved = "CHEBI:68534",
    contrast_direction = c("gain", "gain", "block"))
  out <- .dedup_rem_group_by_entity(cl)
  # stessa entita': "gain" tiene il k massimo (a), "block" sopravvive a se' (c)
  expect_setequal(out$cluster_id, c("a", "c"))
})
```

- [ ] **Step 2: verificare che falliscano**

Run: `Rscript -e 'devtools::test(filter="stage4-cgroup")'`
Atteso: FAIL (il gate seleziona `group`, la dedup ignora il verso).

- [ ] **Step 3: implementazione**

In `.identify_layer_a_clusters`, sostituire il filtro del ramo `rem_group`:

```r
  # ADR-0025: il deliverable nasce dal CONTRASTO. Il ramo rem_group consuma i
  # cluster cgroup (un record per comparison, chiave = entita'-delta || verso ||
  # tipo di controllo) e non piu' i group, che restavano comparison-blind e
  # producevano l'85% di minestroni. mega e mega_aug non cambiano.
  rem_group <- stage3_clusters[
    stage3_clusters$mode == "cgroup" &
    !(kind_col %in% excl_kinds) &
    !is.na(agent_col) &
    nzchar(agent_col, keepNA = FALSE) &
    stage3_clusters$k >= min_k_raw,
  ]
```

In `.dedup_rem_group_by_entity`, includere il verso nella chiave quando la colonna esiste:

```r
  direction <- .col_or_default(rem_group_clusters, "contrast_direction", NA_character_)
  entity <- paste0(rem_group_clusters$kind_effective_resolved, "||",
                   rem_group_clusters$agent_id_resolved, "||", direction)
```

In `.build_group_rem_dispatch_from_stage3`, il dispatch dei `cgroup` va per comparison:

```r
  group_clusters <- eligible_clusters[
    eligible_clusters$mode %in% c("group", "cgroup") &
      eligible_clusters$method == "rem_group",
  ]
  ...
      # cgroup: il record_id E' la comparison; group (legacy): si cerca la
      # comparison in cui il gruppo e' il trattato.
      cmp <- if (identical(group_clusters$mode[i], "cgroup"))
               .lookup_cmp(study, parsed$suffix)
             else
               .lookup_cmp_by_treated_group(study, parsed$suffix)
```

- [ ] **Step 4: verificare**

Run: `Rscript -e 'devtools::test(filter="stage4")'`
Atteso: i test nuovi PASS; i test Stadio 4 preesistenti PASS (i rami `rem`, `mega`, `mega_aug` non
sono toccati).

- [ ] **Step 5: commit**

```bash
git add R/stage4-qc.R R/stage4-dispatch.R tests/testthat/test-stage4-cgroup-branch.R
git commit -m "Stadio 4: il ramo rem_group consuma i cluster derivati dal contrasto (ADR-0025)"
```

---

### Task 8: equivalenza sui 38.440 contrasti veri

**Files:**
- Create: `analysis/audit/2026-07-27-contrast-builder/10-equivalenza-builder.R`

**Interfaces:**
- Consumes: `.ca_member_contrast()` (Task 4), `fase1-v11-results.rds` (verdetti misurati).
- Produces: `equivalenza-builder.csv` (una riga per differenza) + il conteggio a video.

**Questo non è un test unitario: è la prova che il codice di pacchetto dice la stessa cosa del gate
già misurato, sugli stessi dati.** Le differenze attese sono solo quelle dovute al ramo on-contrast
(che ora usa il nome dell'anchor del record invece del nome del cluster) e vanno **elencate e
spiegate una per una**.

- [ ] **Step 1: scrivere lo script**

```r
# Equivalenza: il verdetto del codice di pacchetto contro il gate misurato
# (109-fase1-v11-gate.R) sugli stessi 38.440 contrasti.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({library(dplyr); devtools::load_all(".", quiet = TRUE)})
SC  <- "analysis/audit/2026-07-24-anchor-coherence-sim"
OUT <- "analysis/audit/2026-07-27-contrast-builder"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
pm <- readRDS(file.path(SC, "fase1-v11-results.rds"))$pm
oe <- .load_ontology_dicts()
caches <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))

n <- nrow(pm)
ent <- rep(NA_character_, n); dr <- character(n); src <- rep(NA_character_, n)
ck  <- rep(NA_character_, n); vs <- rep(NA_character_, n)
t0 <- Sys.time()
for (i in seq_len(n)) {
  v <- .ca_member_contrast(pm$treated_label[i], pm$control_label[i],
                           pm$treated_fl[i], pm$control_fl[i],
                           anchor_name = pm$canonical_name[i],   # proxy: nel build e' l'anchor del record
                           anchor_id   = NA_character_,
                           ontology_env = oe, caches = caches)
  ent[i] <- v$entity; dr[i] <- v$drop_reason; src[i] <- v$entity_source
  ck[i]  <- v$control_key; vs[i] <- v$direction
  if (i %% 5000 == 0) cat(sprintf("  %d/%d (%.0fs)\n", i, n, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
pm$new_entity <- ent; pm$new_dr <- ifelse(nzchar(dr), dr, "ok"); pm$new_src <- src
pm$new_ct <- ck; pm$new_verso <- vs

old_dr <- ifelse(pm$dr %in% c("ok", "ok_combo"), "ok", pm$dr)
tenuti_da_entrambi <- old_dr == "ok" & pm$new_dr == "ok"
cat("\n=== esito per-membro: pacchetto vs gate misurato ===\n")
cat("membri:", n, " | verdetto identico (tenuto/scartato):", sum((old_dr == "ok") == (pm$new_dr == "ok")), "\n")
cat("entita' identica sui membri tenuti da entrambi:",
    sum(tenuti_da_entrambi & pm$entity == pm$new_entity, na.rm = TRUE), "/", sum(tenuti_da_entrambi), "\n")
diff <- pm[(old_dr == "ok") != (pm$new_dr == "ok") |
           (tenuti_da_entrambi & pm$entity != pm$new_entity), ]
cat("differenze:", nrow(diff), "\n")
print(head(sort(table(paste(diff$dr, "->", diff$new_dr)), decreasing = TRUE), 20))
write.csv(diff[, c("study_id","treated_label","control_label","dr","new_dr","entity","new_entity","new_src")],
          file.path(OUT, "equivalenza-builder.csv"), row.names = FALSE)

# ricostruzione dei gruppi con le entita' nuove
el <- pm[pm$new_dr == "ok" & !is.na(pm$new_entity), ]
el$ckey <- paste(el$new_entity, el$new_verso, el$new_ct, sep = "||")
agg <- el |> group_by(ckey) |> summarise(k = n_distinct(study_id), n = n(), .groups = "drop") |> filter(k >= 3)
agg$entita <- sub("\\|\\|.*$", "", agg$ckey)
agg$verso  <- sub("^[^|]*\\|\\|([^|]*)\\|\\|.*$", "\\1", agg$ckey)
agg <- agg |> group_by(entita, verso) |> slice_max(k, n = 1, with_ties = FALSE) |> ungroup()
cat("\n=== gruppi poolabili k>=3 col codice di pacchetto:", nrow(agg), " (gate misurato: 144) ===\n")
saveRDS(list(pm = pm, agg = agg), file.path(OUT, "equivalenza-builder.rds"))
```

- [ ] **Step 2: eseguirlo**

Run: `Rscript --vanilla analysis/audit/2026-07-27-contrast-builder/10-equivalenza-builder.R 2>&1 | tee analysis/audit/2026-07-27-contrast-builder/10.log`
Atteso: ~25-40 min. **Criterio:** ogni classe di differenza deve avere una spiegazione scritta. Le
differenze attese riguardano il ramo on-contrast; **qualunque differenza su una regola del gate o
di riga è un bug e va indagata prima di proseguire** (`superpowers:systematic-debugging`).

- [ ] **Step 3: commit**

```bash
git add analysis/audit/2026-07-27-contrast-builder/10-equivalenza-builder.R
git commit -m "Equivalenza del builder col gate misurato sui 38.440 contrasti"
```

---

### Task 9: smoke sui gruppi bandiera e censimento delle mega

**Files:**
- Create: `analysis/audit/2026-07-27-contrast-builder/20-smoke-bandiera.R`
- Create: `analysis/audit/2026-07-27-contrast-builder/30-censimento-mega.R`

**Interfaces:**
- Consumes: `equivalenza-builder.rds` (Task 8), `.ca_member_contrast()` (Task 4).
- Produces: due tabelle + due esiti a video. Nessun run pesante.

- [ ] **Step 1: smoke sui gruppi bandiera**

```r
# I pavimenti sono MISURATI (109.log, gate v11). Se il k scende, ci si ferma e si
# misura: non si aggiusta la regola per far tornare il numero.
suppressPackageStartupMessages({library(dplyr); devtools::load_all(".", quiet = TRUE)})
OUT <- "analysis/audit/2026-07-27-contrast-builder"
agg <- readRDS(file.path(OUT, "equivalenza-builder.rds"))$agg
PAVIMENTI <- c("NCBITaxon:2697049" = 28, "CHEBI:16412" = 26, "HGNC:11766" = 27,
               "CHEBI:68534" = 21, "CHEBI:63637" = 13)
esito <- lapply(names(PAVIMENTI), function(e) {
  k <- suppressWarnings(max(agg$k[agg$entita == e], -Inf))
  data.frame(entita = e, k_atteso = PAVIMENTI[[e]], k_ottenuto = ifelse(is.finite(k), k, 0),
             esito = ifelse(is.finite(k) && k >= PAVIMENTI[[e]], "OK", "SOTTO IL PAVIMENTO"))
}) |> bind_rows()
print(esito, row.names = FALSE)
write.csv(esito, file.path(OUT, "smoke-bandiera.csv"), row.names = FALSE)
if (any(esito$esito != "OK")) cat("\n>>> FERMARSI: almeno un gruppo bandiera e' sotto il pavimento.\n")
```

Run: `Rscript --vanilla analysis/audit/2026-07-27-contrast-builder/20-smoke-bandiera.R`
Atteso: 5 righe `OK`. JQ1 va aggiunto quando se ne conosce l'ID canonico (nel gate v11 compare come
`k=24`); se non risolve a un ID, va verificato a mano e documentato.

- [ ] **Step 2: censimento di coerenza del ramo mega**

```r
# Le mega non sono mai state verificate: 39 delle 99 poolate in v10 non hanno un
# nome e 28 hanno kind=none. Qui si misura, con lo stesso motore del delta,
# quante entita' DIVERSE misurano i bracci trattati di ogni mega.
# Copertura dichiarata: dei 928 bracci trattati, 459 (49%) sono agganciati a un
# confronto Stadio 2; per gli altri non esiste un contrasto ricostruibile.
suppressPackageStartupMessages({library(arrow); library(dplyr); devtools::load_all(".", quiet = TRUE)})
S4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"
S3 <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"
OUT <- "analysis/audit/2026-07-27-contrast-builder"
oe <- .load_ontology_dicts(); caches <- list(agent = new.env(parent = emptyenv()),
                                             token = new.env(parent = emptyenv()))
cp <- open_dataset(file.path(S4, "cluster_pooled.parquet")) |>
  select(cluster_id, method) |> distinct() |> collect()
mega_ids <- cp$cluster_id[cp$method == "mega"]
cl  <- readRDS(file.path(S3, "clusters.rds"))
asg <- read_parquet(file.path(S3, "assignments.parquet"))
by  <- split(asg$record_id, asg$cluster_id)
s2  <- .load_stage2_master("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
s2i <- .index_stage2_master(s2)
fl_of <- function(rg) { fl <- rg$factor_levels; if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";") }
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid

rows <- list()
for (cid in mega_ids) {
  ents <- character(0); labs <- character(0); n_t <- 0L; n_res <- 0L
  for (rid in by[[cid]]) {
    p <- .split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2i, inherits = FALSE)) next
    st <- get(p$series_id, envir = s2i, inherits = FALSE)
    rg <- .lookup_rg(st, p$suffix); if (is.null(rg)) next
    if (!identical(rg$primary_role %||% "", "treated")) next
    n_t <- n_t + 1L; labs <- c(labs, lab_of(rg, p$suffix))
    cmp <- .lookup_cmp_by_treated_group(st, p$suffix); if (is.null(cmp)) next
    cg <- .lookup_rg(st, cmp$control_group); if (is.null(cg)) next
    n_res <- n_res + 1L
    v <- .ca_member_contrast(lab_of(rg, p$suffix), lab_of(cg, cmp$control_group),
                             fl_of(rg), fl_of(cg), NA_character_, NA_character_, oe, caches)
    if (!nzchar(v$drop_reason) && !is.na(v$entity)) ents <- c(ents, v$entity)
  }
  rows[[length(rows) + 1L]] <- data.frame(
    cluster_id = cid, n_treated = n_t, n_ricostruiti = n_res,
    n_entita_distinte = length(unique(ents)),
    entita = paste(sort(unique(ents)), collapse = " | "),
    n_label_distinte = length(unique(tolower(labs))), stringsAsFactors = FALSE)
}
cens <- bind_rows(rows) |> left_join(cl[, c("cluster_id","k","canonical_name","kind_effective_resolved")], by = "cluster_id")
cat("=== censimento mega (99 poolate in v10) ===\n")
cat("con contrasto ricostruibile su >=1 braccio:", sum(cens$n_ricostruiti > 0), "\n")
cat("una sola entita' del delta (coerenti per quanto misurabile):",
    sum(cens$n_entita_distinte == 1), "\n")
cat(">=2 entita' del delta (minestrone misurato):", sum(cens$n_entita_distinte >= 2), "\n")
cat("nessuna entita' risolta (non misurabile):", sum(cens$n_entita_distinte == 0), "\n")
print(summary(cens$n_label_distinte))
write.csv(cens, file.path(OUT, "censimento-mega.csv"), row.names = FALSE)
```

Run: `Rscript --vanilla analysis/audit/2026-07-27-contrast-builder/30-censimento-mega.R 2>&1 | tee analysis/audit/2026-07-27-contrast-builder/30.log`
Atteso: ~10-20 min. **L'esito va portato all'utente prima del GO**, con la copertura dichiarata
(49%) accanto a ogni numero.

- [ ] **Step 3: commit**

```bash
git add analysis/audit/2026-07-27-contrast-builder/
git commit -m "Smoke sui gruppi bandiera + censimento di coerenza del ramo mega"
```

---

## Dopo il piano — il GATE UTENTE

Nessuno di questi passi si fa senza il GO esplicito:

1. **Re-cluster Stadio 3** (~8h, `setsid`, verificare SID==PID). Prima: controllare se
   `recover_identity()` è cambiato → se sì, bump di `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` a v8.
2. **Re-pool Stadio 4** (~50h) + verifica ANTI-STALE (`Methods` deve contenere `rem_group` e i
   cluster devono essere `cgroup_L5_*`).
3. **Ri-censimento della coerenza sui dati veri, su TUTTI i gruppi.**

Prima di allora nessun numero di questo lavoro può essere chiamato "validato", "finale" o
"publication-grade".
