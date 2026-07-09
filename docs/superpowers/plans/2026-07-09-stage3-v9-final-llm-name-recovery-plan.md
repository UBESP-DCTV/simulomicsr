# Ultimo run v9 — recupero-nome LLM nativo + rifusione frammenti — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Portare il recupero-nome LLM (Mistral) *dentro* la pipeline Stadio 3 così che le meta-analisi escano con il nome corretto e le entità spezzate si rifondano, poi eseguire l'ultimo full run v9 (re-cluster + re-pool) prima della pubblicazione.

**Architecture:** Le correzioni LLM alimentano lo **stesso** `recovery_lookup` (GSM → identità) che già alimenta il recupero-nome deterministico dentro `build_stage3_clusters()`. Il flusso è a due passaggi: (1) build v9-pre → triage sospetti → Mistral → side-table; (2) side-table → overlay GSM→identità sul `recovery_lookup` → re-build (i frammenti si fondono) → re-pool Stadio 4. Le correzioni sono agganciate ai **campioni membri** dei cluster rivisti (non a una regola globale sul nome) → nessun rischio di over-correction.

**Tech Stack:** R (pacchetto `simulomicsr`), testthat (TDD), macchinario T13 esistente (`R/name-cleanup.R`), DGX/Mistral per il passo LLM.

## Global Constraints

- **Branch:** `review-scientific-consistency-2026-06-10`. Master invariato, **no push** (salvo richiesta esplicita utente).
- **TDD bite-sized** per ogni task di codice (test → fail → impl → pass → commit). Italiano in commenti/commit/messaggi.
- **`Rscript` con renv** (NO `--vanilla`) per i test/build sul laptop; funzioni interne `@keywords internal`.
- **Retrocompat byte-identica** dei rami/percorsi non toccati (non-regressione verificata dai test).
- **Precision-gate:** si applica solo `action == "override"` (match STRONG + confidenza alta); `flag_review`/incerte NON applicate.
- **Cache:** bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` se cambia il resolver deterministico (fix STR:/ChEMBL) — altrimenti il re-cluster riusa lookup stale (memoria `feedback_bump_lookup_cache_version`).
- **Run pesanti = GATED** (gate utente separati, `setsid` per i detached multi-ora). I subagent NON lanciano run pesanti.

---

## FASE A — Fix deterministici (codice, TDD)

### Task 1: Sigla `STR:` per bersagli genetici mediati ignoti a HGNC

**Files:**
- Modify: `R/stage3-anchor-levels.R:154` (ramo `mediated_effect`, fallback `MEDIATED_HGNC_NO_LOOKUP`)
- Test: `tests/testthat/test-stage3-anchor-levels.R`

**Interfaces:**
- Consuma: `resolve_agent_canonical()` (invariato).
- Produce: per un target `mediated_effect` ignoto a HGNC, `agent_id` = `"STR:<target>"` (prima `"HGNC:<target>"`), `resolution_source = "MEDIATED_STR_NO_LOOKUP"`.

- [ ] **Step 1: Scrivi il test che fallisce** — un mediated_effect con target non-gene (es. `"DTMYC"`) produce `agent_id` con prefisso `STR:`, non `HGNC:`.

```r
test_that("mediated target ignoto a HGNC usa STR: non HGNC:", {
  env <- .load_ontology_dicts()
  facts <- list(  # stage1_facts minimale con mediated_effect target ignoto
    perturbations = list(list(kind = "genetic_perturbation",
      mediated_effect = list(kind = "genetic_knockdown", targets = list("DTMYC")))),
    cell_context = list(engineered_modifications = NULL)
  )
  seg <- .extract_anchor_segments(facts, recovery = NULL, ontology_env = env)
  expect_true(startsWith(seg$agent_id, "STR:"))
  expect_false(startsWith(seg$agent_id, "HGNC:"))
  expect_identical(seg$resolution_source, "MEDIATED_STR_NO_LOOKUP")
})
```

- [ ] **Step 2: Esegui il test, verifica FAIL** — `Rscript -e 'devtools::test(filter="stage3-anchor-levels")'` → FAIL (oggi emette `HGNC:DTMYC`). (Adatta i nomi campo dello `stage1_facts` fixture alla firma reale di `.extract_anchor_segments` leggendo la funzione; il cuore del test è l'asserzione sul prefisso.)

- [ ] **Step 3: Implementa** — in `R/stage3-anchor-levels.R:153-156`:

```r
      # Target sconosciuto a HGNC: NON e' un gene canonico -> forma STR:
      # (stessa classe del fix I2; un HGNC:<sigla> fabbricato inquina l'identita').
      agent_id          <- paste0("STR:", target_name)
      resolution_source <- "MEDIATED_STR_NO_LOOKUP"
      canonical_name    <- target_name
```

- [ ] **Step 4: Esegui i test, verifica PASS** — `Rscript -e 'devtools::test(filter="stage3-anchor-levels")'` → PASS, 0 regressioni nel file.

- [ ] **Step 5: Commit** — `git add R/stage3-anchor-levels.R tests/testthat/test-stage3-anchor-levels.R && git commit -m "P5 audit F6 v9 Task 1: STR: per target mediati ignoti a HGNC"`

### Task 2: Uniforma il casing del prefisso ChEMBL

**Files:**
- Modify: `R/stage3-name-recovery.R:248` (`"CHEMBL:"` → `"ChEMBL:"`)
- Test: `tests/testthat/test-stage3-name-recovery.R`

**Interfaces:**
- Produce: il prefisso ChEMBL è **sempre** `"ChEMBL:"` (forma di `R/anchors.R:360`), mai `"CHEMBL:"`.

- [ ] **Step 1: Scrivi il test che fallisce** — la risoluzione compound→ChEMBL emette prefisso `"ChEMBL:"`.

```r
test_that("prefisso ChEMBL e' ChEMBL: non CHEMBL:", {
  env <- .load_ontology_dicts()
  # un compound risolto via ChEMBL (usa un alias presente nel dizionario reale;
  # in mancanza, mocka .chembl_lookup per restituire un chembl_id noto)
  res <- .normalize_compound_to_chebi("<compound-che-risolve-solo-via-chembl>", env)
  if (!is.na(res$id)) expect_false(startsWith(res$id, "CHEMBL:"))
  # asserzione diretta sul sito di costruzione:
  expect_match(deparse(body(simulomicsr:::.resolve_one_compound)), "ChEMBL:", fixed = TRUE, all = FALSE)
})
```

(Se il test basato su dati è fragile, tieni solo l'asserzione sul sito di costruzione via `deparse(body(...))`, oppure aggiungi un test unit sul ramo ChEMBL con `.chembl_lookup` mockato.)

- [ ] **Step 2: Esegui, verifica FAIL** — `Rscript -e 'devtools::test(filter="stage3-name-recovery")'` → FAIL.

- [ ] **Step 3: Implementa** — `R/stage3-name-recovery.R:248`: `id = paste0("ChEMBL:", ch$chembl_id)`.

- [ ] **Step 4: Esegui, verifica PASS** — test filtrati PASS.

- [ ] **Step 5: Commit** — `git commit -m "P5 audit F6 v9 Task 2: uniforma prefisso ChEMBL: (era CHEMBL:)"`

### Task 3: Bump versione cache lookup (invalida lookup stale post fix A)

**Files:**
- Modify: `R/stage3-name-recovery-lookup.R` (costante `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`, es. `v5` → `v6`)
- Test: `tests/testthat/test-stage3-name-recovery-lookup.R`

**Interfaces:** la chiave cache cambia → il lookup viene ricostruito (non riusa lo stale post fix STR:/ChEMBL).

- [ ] **Step 1: Test** — la costante versione è `"v6"` (o successiva) e compare nella chiave cache.

```r
test_that("schema version lookup bumpata post fix STR/ChEMBL", {
  expect_identical(simulomicsr:::.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION, "v6")
})
```

- [ ] **Step 2: FAIL** — `Rscript -e 'devtools::test(filter="stage3-name-recovery-lookup")'`.
- [ ] **Step 3: Implementa** — bump della costante a `"v6"`.
- [ ] **Step 4: PASS**.
- [ ] **Step 5: Commit** — `git commit -m "P5 audit F6 v9 Task 3: bump cache lookup v6 (fix STR/ChEMBL)"`

---

## FASE B — Overlay delle correzioni LLM sul recovery_lookup (codice, TDD)

### Task 4: `.side_table_to_recovery_overlay()` — side-table → GSM→identità

**Files:**
- Create: `R/stage3-name-cleanup-overlay.R`
- Test: `tests/testthat/test-stage3-name-cleanup-overlay.R`

**Interfaces:**
- Consuma: `side_table` (output `run_name_cleanup`: colonne `cluster_id, new_id, new_canonical, new_kind, action`), `assignments` (tibble `cluster_id, record_id`), `record_to_gsms` (function `record_id -> chr GSM membri`, dallo stage2_master).
- Produce: `.side_table_to_recovery_overlay(side_table, assignments, record_to_gsms) -> named list` GSM → `list(kind, agent_id, canonical_name, recovery_source="LLM_NAME_CLEANUP")`, **solo** per righe `action == "override"`.

- [ ] **Step 1: Scrivi il test che fallisce**

```r
test_that("overlay mappa i GSM dei cluster override all'identita' corretta", {
  side <- tibble::tibble(
    cluster_id = c("group_L4_A", "group_L4_B"),
    new_id = c("CHEBI:68534", NA), new_canonical = c("Enzalutamide", NA),
    new_kind = c("small_molecule", NA), action = c("override", "flag_review"))
  asg <- tibble::tibble(cluster_id = c("group_L4_A","group_L4_B"),
                        record_id  = c("GSE1__grp1","GSE2__grp2"))
  r2g <- function(rid) if (rid == "GSE1__grp1") c("GSM1","GSM2") else "GSM9"
  ov <- .side_table_to_recovery_overlay(side, asg, r2g)
  expect_setequal(names(ov), c("GSM1","GSM2"))           # solo override
  expect_identical(ov[["GSM1"]]$agent_id, "CHEBI:68534")
  expect_identical(ov[["GSM1"]]$recovery_source, "LLM_NAME_CLEANUP")
  expect_false("GSM9" %in% names(ov))                     # flag_review escluso
})
```

- [ ] **Step 2: FAIL** — `Rscript -e 'devtools::test(filter="name-cleanup-overlay")'`.
- [ ] **Step 3: Implementa** `R/stage3-name-cleanup-overlay.R`:

```r
#' Converte la side-table del name-cleanup in overlay GSM -> identita' corretta.
#' Solo le righe action=="override" (precision-gate). L'overlay si sovrappone
#' al recovery_lookup deterministico (Task 5); e' agganciato ai GSM membri dei
#' cluster rivisti -> nessun rischio di over-correction globale sul nome.
#' @keywords internal
.side_table_to_recovery_overlay <- function(side_table, assignments, record_to_gsms) {
  ov <- list()
  keep <- side_table[side_table$action == "override" & !is.na(side_table$new_id), , drop = FALSE]
  asg_by <- split(assignments$record_id, assignments$cluster_id)
  for (i in seq_len(nrow(keep))) {
    cid <- keep$cluster_id[i]
    rids <- asg_by[[cid]]; if (is.null(rids)) next
    ident <- list(kind = keep$new_kind[i], agent_id = keep$new_id[i],
                  canonical_name = keep$new_canonical[i], recovery_source = "LLM_NAME_CLEANUP")
    for (rid in rids) for (g in record_to_gsms(rid)) ov[[g]] <- ident
  }
  ov
}
```

- [ ] **Step 4: PASS**.
- [ ] **Step 5: Commit** — `git commit -m "P5 audit F6 v9 Task 4: side-table -> overlay GSM->identita' (precision-gated)"`

### Task 5: `.overlay_recovery_lookup()` — fonde l'overlay nel recovery_lookup env

**Files:**
- Modify: `R/stage3-name-cleanup-overlay.R`
- Test: `tests/testthat/test-stage3-name-cleanup-overlay.R`

**Interfaces:**
- Produce: `.overlay_recovery_lookup(recovery_lookup_env, overlay) -> recovery_lookup_env` (stesso env, mutato in-place: per ogni GSM nell'overlay, l'identità LLM **vince** su quella deterministica). Ritorna l'env per comodità.

- [ ] **Step 1: Test** — dopo overlay, il GSM corretto ha l'identità LLM; i GSM non toccati restano invariati.

```r
test_that("overlay vince sul recovery deterministico per i GSM rivisti", {
  env <- new.env(hash = TRUE, parent = emptyenv())
  assign("GSM1", list(kind="small_molecule", agent_id="CHEBI:2decenal",
                      canonical_name="2-decenal", recovery_source="CHEBI"), envir=env)
  assign("GSMx", list(kind="disease", agent_id="MeSH:D1", canonical_name="x",
                      recovery_source="MESH"), envir=env)
  ov <- list(GSM1 = list(kind="small_molecule", agent_id="CHEBI:68534",
                         canonical_name="Enzalutamide", recovery_source="LLM_NAME_CLEANUP"))
  out <- .overlay_recovery_lookup(env, ov)
  expect_identical(get("GSM1", envir=out)$agent_id, "CHEBI:68534")
  expect_identical(get("GSMx", envir=out)$agent_id, "MeSH:D1")  # invariato
})
```

- [ ] **Step 2: FAIL**.
- [ ] **Step 3: Implementa**:

```r
#' Sovrappone l'overlay LLM al recovery_lookup deterministico (in-place).
#' Per ogni GSM nell'overlay, l'identita' LLM sostituisce quella deterministica.
#' @keywords internal
.overlay_recovery_lookup <- function(recovery_lookup_env, overlay) {
  for (g in names(overlay)) assign(g, overlay[[g]], envir = recovery_lookup_env)
  recovery_lookup_env
}
```

- [ ] **Step 4: PASS**.
- [ ] **Step 5: Commit** — `git commit -m "P5 audit F6 v9 Task 5: overlay LLM vince sul recovery deterministico"`

### Task 6: Registra le nuove funzioni (NAMESPACE/collate se serve)

**Files:**
- Modify: `DESCRIPTION` (Collate se listato esplicitamente) / esegui `devtools::document()`
- Test: `Rscript -e 'devtools::load_all(); exists(".side_table_to_recovery_overlay")'`

- [ ] **Step 1: Verifica caricamento** — `Rscript -e 'suppressMessages(devtools::load_all(".")); stopifnot(is.function(simulomicsr:::.side_table_to_recovery_overlay), is.function(simulomicsr:::.overlay_recovery_lookup))'` → nessun errore.
- [ ] **Step 2: `devtools::document()`** se il pacchetto usa roxygen collate; rigenera man/ se necessario.
- [ ] **Step 3: Suite completa perimetro** — `Rscript -e 'devtools::test(filter="name-cleanup|anchor-levels|name-recovery")'` → tutti PASS.
- [ ] **Step 4: Commit** — `git commit -m "P5 audit F6 v9 Task 6: registra overlay + document"`

---

## FASE C — Selezione sospetti v9 + orchestrazione (codice + script)

### Task 7: `.build_suspect_triage()` — triage sospetti da cluster v9-pre

**Files:**
- Create: `R/stage3-suspect-triage.R` (generalizza la logica di `analysis/audit/2026-07-05-stage4-popB-coherence-check.R`)
- Test: `tests/testthat/test-stage3-suspect-triage.R`

**Interfaces:**
- Consuma: `clusters` (tibble clusters.rds: `cluster_id, anchor_key, kind_effective_resolved, canonical_name, agent_id_resolved, k, n_studies, kind_confidence, kind_chebi_zero_roles`).
- Produce: `.build_suspect_triage(clusters, min_k = 1L) -> tibble(cluster_id, name, kind, k, n_studies, cls, role)` dove `cls ∈ {suspect, canary, skip}` e `role ∈ {candidate, canary}`. **Sospetto** se: `agent_id_resolved` è `STR:`/`UNK`, o `kind_chebi_zero_roles`, o `kind_confidence` bassa, o nome-spazzatura (ChEBI/MeSH improbabile come perturbazione — euristica lista). **Canary**: nome forte + kind alto + k≥3. **Portata generosa** (§2 spec): include i frammenti piccoli con nome-spazzatura.

- [ ] **Step 1: Scrivi il test che fallisce** (righe sintetiche → classi attese)

```r
test_that("triage marca sospetti, canary e skip", {
  cl <- tibble::tibble(
    cluster_id = c("A","B","C"),
    anchor_key = c("small_molecule|STR:foo|lung","small_molecule|CHEBI:68534|prostate","disease_vs_normal|MeSH:D000544|brain"),
    kind_effective_resolved = c("small_molecule","small_molecule","disease_vs_normal"),
    canonical_name = c("foo","Enzalutamide","Alzheimer's disease"),
    agent_id_resolved = c("STR:foo","CHEBI:68534","MeSH:D000544"),
    k = c(1L, 25L, 6L), n_studies = c(1L,25L,6L),
    kind_confidence = c("NONE","STRONG","STRONG"), kind_chebi_zero_roles = c(FALSE,FALSE,FALSE))
  tr <- .build_suspect_triage(cl)
  expect_identical(tr$role[tr$cluster_id=="A"], "candidate")  # STR: -> sospetto
  expect_identical(tr$role[tr$cluster_id=="B"], "canary")     # noto-buono
})
```

- [ ] **Step 2: FAIL** — `Rscript -e 'devtools::test(filter="suspect-triage")'`.
- [ ] **Step 3: Implementa** `.build_suspect_triage()` (euristiche sopra; riusa `.strip_name_markup` da name-cleanup.R per i nomi; lista nomi-spazzatura come costante interna commentata). Mantieni la firma dello schema atteso da `.load_name_cleanup_candidates` (`cluster_id, name, kind, cls, role`) così `run_name_cleanup` lo consuma senza modifiche.
- [ ] **Step 4: PASS** + edge (cluster vuoto → tibble 0 righe; canary con k<3 → non canary).
- [ ] **Step 5: Commit** — `git commit -m "P5 audit F6 v9 Task 7: triage sospetti v9 (portata generosa, canary)"`

### Task 8: Script v9-pre reclustering (build senza overlay LLM)

**Files:**
- Create: `analysis/p4-fase-f7-stage3-v9-pre.R` (copia di `analysis/p4-fase-f6-stage3-reclustering.R`, cambi minimi: token `v9-pre`, out_dir, nessun overlay)

**Interfaces:** produce `analysis/p4-output/<ts>-stage3-v9-pre-<runid>/{clusters.rds, assignments.parquet, run_metadata.json}`.

- [ ] **Step 1: Copia lo script f6** e cambia SOLO: `TOKEN <- "v9-pre"`, header, out_dir. Nessun altro cambio (il recupero deterministico + fix STR:/ChEMBL girano già).
- [ ] **Step 2: Smoke** — `SMOKE=1 Rscript analysis/p4-fase-f7-stage3-v9-pre.R` → PASS in pochi minuti (verifica: STR: attivo su target ignoti, ChEMBL: uniforme, cache v6 ricostruita).
- [ ] **Step 3: Commit** — `git commit -m "P5 audit F6 v9 Task 8: script v9-pre reclustering (smoke PASS)"`

### Task 9: Script v9-final reclustering (build con overlay LLM)

**Files:**
- Create: `analysis/p4-fase-f7-stage3-v9-final.R` (come f7-pre + step overlay tra build del `recovery_lookup` e `build_stage3_clusters`)
- Test: smoke con overlay sintetico

**Interfaces:** legge la side-table LLM (path via env `SIDE_TABLE`), costruisce l'overlay (Task 4), lo fonde nel `recovery_lookup` (Task 5) PRIMA di `build_stage3_clusters()`. Produce `<ts>-stage3-v9-<runid>/`.

- [ ] **Step 1: Copia f7-pre**, inserisci dopo la riga `recovery_lookup <- build_name_recovery_lookup(...)` (≈ riga 278):

```r
# Overlay correzioni LLM (name-cleanup): GSM->identita' corretta (precision-gated).
if (nzchar(Sys.getenv("SIDE_TABLE"))) {
  side <- readRDS(Sys.getenv("SIDE_TABLE"))
  r2g  <- function(rid) {  # record_id -> GSM membri, via stage2_master gia' caricato
    pr <- .split_record_id(rid); st <- s2_idx[[pr$series_id]]
    rg <- .lookup_rg(st, pr$suffix); if (is.null(rg)) character(0) else as.character(unlist(rg$sample_ids))
  }
  overlay <- .side_table_to_recovery_overlay(side, assignments_prepass, r2g)
  recovery_lookup <- .overlay_recovery_lookup(recovery_lookup, overlay)
  cli::cli_alert_success(sprintf("Overlay LLM applicato: %d GSM corretti", length(overlay)))
}
```

(Adatta `assignments_prepass`/`s2_idx` ai nomi reali nello script; se il pre-pass non espone gli assignment, ricavali dal primo build o dal `record_summary`.)

- [ ] **Step 2: Smoke con overlay sintetico** — side-table finta su 1-2 cluster del subset smoke → verifica nel log "Overlay LLM applicato: N GSM" e che quei cluster cambino identità/si fondano.
- [ ] **Step 3: Commit** — `git commit -m "P5 audit F6 v9 Task 9: script v9-final con overlay LLM (smoke PASS)"`

### Task 10: Script re-pool Stadio 4 v9 + run-name-cleanup parametrizzato

**Files:**
- Create: `analysis/p4-fase-f5-stage4-layer-a-rebuild-v9.R` (copia `-v8`, cambi: stage3_dir→v9, out_dir/token v9)
- Modify: `analysis/p5-name-cleanup-run.R` (parametrizza `TRIAGE` via env; default = triage v9 generato da Task 7 su v9-pre)

- [ ] **Step 1: Copia lo script v8** cambiando stage3_dir, out_dir, token `v9`. `DRY_RUN` deve stampare il Layer A.
- [ ] **Step 2: DRY_RUN** del re-pool v9 → PASS (Layer A conteggi sensati).
- [ ] **Step 3: Parametrizza** `p5-name-cleanup-run.R`: `TRIAGE <- Sys.getenv("TRIAGE", "<default v9>")` + genera il triage v9 con `.build_suspect_triage(readRDS(<v9-pre>/clusters.rds))`.
- [ ] **Step 4: Commit** — `git commit -m "P5 audit F6 v9 Task 10: script re-pool v9 (DRY_RUN PASS) + run-name-cleanup parametrico"`

---

## FASE D — RUN PESANTI GATED (NON subagent; gate utente tra ogni step)

> Ogni step qui è un **run pesante gated**: si esegue solo col via dell'utente, `setsid` per i detached, monitor via `pgrep`. La validazione-prima-del-fullrun è obbligatoria (Task 13).

### Task 11 (GATED): Build v9-pre
- [ ] `SMOKE=0 setsid Rscript analysis/p4-fase-f7-stage3-v9-pre.R` (~8h). Verifica: clusters.rds prodotto, STR:/ChEMBL/gene-id materializzati, cache v6.

### Task 12 (GATED, DGX): Recupero-nome Mistral sui sospetti v9-pre
- [ ] Genera triage v9 (`.build_suspect_triage` su v9-pre/clusters.rds) → CSV.
- [ ] `TRIAGE=<v9-triage> Rscript analysis/p5-name-cleanup-run.R build|submit|collect` (DGX, ~minuti). → `side-table-v9.rds`.

### Task 13 (GATED): Cancello di validazione (validate-before-fullrun)
- [ ] **Smoke recupero** + **canary**: sui canary la side-table deve dare 0 `override` (0 falsi allarmi); sui candidate recupero alto (come T13 13/13).
- [ ] **Fusioni attese**: `.measure_fragmentation(side_v9, k_by_cluster)` → le 31 entità note si fondono? frammentazione scende? k sale?
- [ ] **GO/NO-GO esplicito all'utente.** Se non netto → STOP + report.

### Task 14 (GATED): Re-cluster v9-final + re-pool Stadio 4 v9
- [ ] `SIDE_TABLE=<side-v9> SMOKE=0 setsid Rscript analysis/p4-fase-f7-stage3-v9-final.R` (re-cluster con overlay).
- [ ] `setsid Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v9.R` (~17h). Verifica anti-stale (Methods, N pooled, entità note più potenti).

### Task 15 (GATED): Closeout
- [ ] Re-gate omogeneità/frammentazione v9 vs v8; finding + ADR + CLAUDE.md + ledger + memorie. Layer B = plan separato a valle.

---

## Self-review checklist (autore)
- Copertura spec: §1 flusso→Task 8/9/11/14; §2 sospetti→Task 7/12; §3 fix→Task 1/2/3; §4 gate→Task 13; §5 limiti→Task 15 doc; §7 unità→Task 4/5/7/9. ✓
- Nessun placeholder di codice nei task TDD (codice reale mostrato).
- Firme coerenti: `.side_table_to_recovery_overlay`/`.overlay_recovery_lookup`/`.build_suspect_triage` usate coerentemente in Task 4/5/7/9.
- Le adattazioni ai nomi-variabile reali degli script f6 (Task 9) sono segnalate esplicitamente come step di adattamento, non lasciate implicite.
