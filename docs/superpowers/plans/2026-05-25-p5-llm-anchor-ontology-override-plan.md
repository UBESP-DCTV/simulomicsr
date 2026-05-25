# P5 — LLM anchor ontology override — Implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` o `superpowers:executing-plans` per eseguire questo plan task-by-task. Steps usano checkbox (`- [ ]`).

**Goal:** Implementare la mitigation OPZIONE 2 dell'audit 2026-05-24: resolver downstream che usa ChEBI/HGNC/MeSH come ground-truth in `R/anchors.R`, rebuild Stage 3 con anchor v3.1, rebuild Stage 4 Layer A, re-curare Layer B selection, validare con audit post-fix.

**Architecture:** post-hoc ontology lookup downstream Stage 2 master (immutato) → nuovo resolver in `R/anchors.R::resolve_agent_canonical()` + `infer_kind_from_ontology()` → modifica `R/stage3-anchor-levels.R::extract_anchor_segments()` per usare i resolved values → `clusters.rds v3.1` con tracking columns → Stage 4 rebuild logic invariata → Layer B rebuild su nuova shortlist.

**Tech Stack:** R 4.6.0 + renv 1.1.4. Zero nuovi package (riusa dplyr + tibble + readr già `Imports`). Dictionary RDS preferred in `tools::R_user_dir("simulomicsr","cache")`. TDD obbligatorio.

**Spec di riferimento:** `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
**ADR di riferimento:** `docs/decisions/0018-llm-anchor-ontology-override.md`
**Audit drive:** `docs/findings/2026-05-24-llm-anchor-classification-audit.md`

**Branch policy:** continuiamo su `p5-llm-anchor-classification-audit` (NON creiamo branch nuovo). Master resta su `p5-stadio4-layer-b-batch-15` finché non chiudiamo S5.

**Pre-requisiti pipeline pre-S1:**

- [ ] Dictionary RDS già pronte (commit `7a0e20c`): verifica esistenza dei 3 file
  ```bash
  ls -lah ~/.cache/R/simulomicsr/chebi/chebi-lookup.rds \
          ~/.cache/R/simulomicsr/hgnc-lookup.rds \
          ~/.cache/R/simulomicsr/mesh-lookup.rds
  ```
  Se mancanti: rilancio script audit:
  ```bash
  Rscript analysis/p5-audit-chebi-build-dict.R
  Rscript analysis/p5-audit-hgnc-mesh-build-dict.R
  ```
- [ ] Master Stage 2 rescued path verificato: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (34 MB, 39.247 predictions)
- [ ] Layer A old preserved: `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` non cancellato (baseline diff)
- [ ] Branch + ADR-0018 + spec + plan committati (questo plan stesso)

---

## SESSIONE 1 — Implementation + tests + smoke isolato (4-6h)

### Task 0: Setup branch + ADR-0018 commit + verifica state

**Files:** (already created in this session)
- `docs/decisions/0018-llm-anchor-ontology-override.md`
- `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
- `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
- `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-HUMANE.md`

- [ ] **Step 0.1 Verify branch state**
  ```bash
  cd /home/user/simulomicsr
  git status   # working tree clean atteso
  git log --oneline -5
  # HEAD = 1e43e88 (CLAUDE.md alert), 7a0e20c (audit), 954fbf7 (Layer B status), 8c97dc4, 9b486b9
  ```
- [ ] **Step 0.2 Verify pre-requisites pipeline**
  Vedi sezione Pre-requisiti sopra.

### Task 1: `R/ontology-lookup.R` — loader + accessor functions

**Files:**
- Create: `R/ontology-lookup.R`
- Create: `tests/testthat/test-ontology-lookup.R`
- Create: `inst/extdata/ontology-fixtures-mini/chebi-mini.rds`
- Create: `inst/extdata/ontology-fixtures-mini/hgnc-mini.rds`
- Create: `inst/extdata/ontology-fixtures-mini/mesh-mini.rds`

- [ ] **Step 1.1 Build mini fixture dictionaries**

  Script `analysis/p5-build-ontology-fixtures.R` (one-off):
  - Carica ChEBI full → estrai 30 compounds noti (Carnitine, Ethanol, DMSO, Resiquimod, poly(I:C), Hypoxia=NOT_FOUND, etc.) + roles + secondary IDs
  - Carica HGNC full → estrai 20 simboli noti (TP53, VEGFA, FTO, AKT3, etc.) + aliases + entrez_id
  - Carica MeSH full → estrai 15 disease/chemical descriptors (D011279 Pregnanetriol, D011471 Prostatic Neoplasms, D016899 IFN-beta, etc.)
  - Salva in `inst/extdata/ontology-fixtures-mini/`
  Run: `Rscript analysis/p5-build-ontology-fixtures.R`
  Expected output: 3 RDS file, ognuno <100 KB.

- [ ] **Step 1.2 Write test file** (TDD red phase)

  `tests/testthat/test-ontology-lookup.R`:
  ```r
  # Test: load_ontology_dicts() works with custom path
  # Test: .chebi_lookup_id(17126) returns Carnitine
  # Test: .chebi_lookup_id(123456) returns the compound (preliminary stars=2)
  # Test: .chebi_lookup_id(999999999) returns NULL (NOT_FOUND)
  # Test: .chebi_lookup_alias("ethanol") returns id=16236
  # Test: .chebi_roles(16236) returns vector incl "polar solvent", "neurotoxin"
  # Test: .chebi_roles(17126) returns roles incl "human metabolite"
  # Test: .hgnc_lookup_hgnc(11998) returns TP53 symbol  # (verify hgnc_int)
  # Test: .hgnc_lookup_entrez(7157) returns TP53 (Entrez gene id for TP53)
  # Test: .mesh_lookup_ui("D011279") returns "Pregnanetriol" with tree_top="D"
  # Test: .mesh_lookup_term("interferon beta") returns ui="D016899"
  # Test: refresh=FALSE riusa cache; refresh=TRUE reload
  # Test: .ontology_release_meta() ritorna release sha256 + dates
  ```

  Run: `devtools::test(filter = "ontology-lookup")`
  Expected: ALL FAIL (red phase).

- [ ] **Step 1.3 Implement `R/ontology-lookup.R`**

  Skeleton:
  ```r
  #' Ontology dictionary loader + accessor
  #'
  #' @noRd
  .ontology_env <- new.env(parent = emptyenv())

  .load_ontology_dicts <- function(refresh = FALSE,
                                   cache_dir = tools::R_user_dir("simulomicsr","cache"),
                                   fixture_dir = NULL) {
    if (!refresh && !is.null(.ontology_env$loaded)) return(.ontology_env)
    if (!is.null(fixture_dir)) {
      .ontology_env$chebi <- readRDS(file.path(fixture_dir, "chebi-mini.rds"))
      .ontology_env$hgnc  <- readRDS(file.path(fixture_dir, "hgnc-mini.rds"))
      .ontology_env$mesh  <- readRDS(file.path(fixture_dir, "mesh-mini.rds"))
    } else {
      stopifnot(dir.exists(cache_dir))
      .ontology_env$chebi <- readRDS(file.path(cache_dir, "chebi", "chebi-lookup.rds"))
      .ontology_env$hgnc  <- readRDS(file.path(cache_dir, "hgnc-lookup.rds"))
      .ontology_env$mesh  <- readRDS(file.path(cache_dir, "mesh-lookup.rds"))
    }
    .ontology_env$loaded <- TRUE
    .ontology_env
  }

  .chebi_lookup_id <- function(chebi_int, env = .load_ontology_dicts()) { ... }
  .chebi_lookup_alias <- function(alias_lower, env = .load_ontology_dicts()) { ... }
  .chebi_roles <- function(chebi_int, env = .load_ontology_dicts()) { ... }
  .hgnc_lookup_hgnc <- function(hgnc_int, env = .load_ontology_dicts()) { ... }
  .hgnc_lookup_entrez <- function(entrez_int, env = .load_ontology_dicts()) { ... }
  .hgnc_lookup_symbol <- function(symbol_lower, env = .load_ontology_dicts()) { ... }
  .mesh_lookup_ui <- function(ui_str, env = .load_ontology_dicts()) { ... }
  .mesh_lookup_term <- function(term_lower, env = .load_ontology_dicts()) { ... }
  .ontology_release_meta <- function(env = .load_ontology_dicts()) { ... }
  ```

  Run: `devtools::test(filter = "ontology-lookup")`
  Expected: ALL PASS (green phase).

- [ ] **Step 1.4 Commit**
  ```bash
  git add R/ontology-lookup.R tests/testthat/test-ontology-lookup.R \
          inst/extdata/ontology-fixtures-mini/ analysis/p5-build-ontology-fixtures.R
  git commit -m "P5 audit Task 1: R/ontology-lookup.R + mini fixtures + tests TDD"
  ```

### Task 2: `R/anchors.R::resolve_agent_canonical()` (NEW)

**Files:**
- Modify: `R/anchors.R`
- Create: `tests/testthat/test-anchors-resolve-canonical.R`

- [ ] **Step 2.1 Write test fixtures + test file** (red phase)

  `tests/testthat/test-anchors-resolve-canonical.R`:
  Build fixture cases coprendo l'intera decision table di spec §4.2 (16+ casi):
  ```r
  # Case CHEBI_DIRECT
  agent <- list(id_database = "CHEBI", id = "17126", preferred_name = "carnitine", type = "small_molecule")
  expect_equal(resolve_agent_canonical(agent, fixture_env)$canonical_id, "CHEBI:17126")
  expect_equal(resolve_agent_canonical(agent, fixture_env)$resolution_source, "CHEBI_DIRECT")
  expect_equal(resolve_agent_canonical(agent, fixture_env)$canonical_name, "carnitine")

  # Case CHEBI_FIELDSWAP
  agent <- list(id_database = "CHEBI", id = NULL, preferred_name = "17126", type = "small_molecule")
  expect_equal(resolve_agent_canonical(agent, fixture_env)$canonical_id, "CHEBI:17126")
  expect_equal(resolve_agent_canonical(agent, fixture_env)$resolution_source, "CHEBI_FIELDSWAP")

  # Case WRONG_DB_to_HGNC
  agent <- list(id_database = "CHEBI", id = NULL, preferred_name = "11998", type = "small_molecule")
  # 11998 = TP53 in HGNC, not CHEBI
  expect_equal(resolve_agent_canonical(agent, fixture_env)$canonical_id, "HGNC:11998")
  expect_equal(resolve_agent_canonical(agent, fixture_env)$resolution_source, "WRONG_DB_to_HGNC")

  # Case STRING_ALIAS_CHEBI
  agent <- list(id_database = NULL, id = NULL, preferred_name = "Resiquimod", type = "small_molecule")
  expect_equal(resolve_agent_canonical(agent, fixture_env)$canonical_id, "CHEBI:36706")

  # ... etc per ogni branch della decision table
  ```

- [ ] **Step 2.2 Implement `resolve_agent_canonical()` in `R/anchors.R`**

  Function signature + decision table implementation. Vedi spec §4.2. Mantieni la vecchia `.resolve_agent_id` come `.resolve_agent_id_legacy` (per backward-compat se serve cross-reference); aggiungi `@keywords internal`.

  Run: `devtools::test(filter = "anchors-resolve-canonical")`
  Expected: ALL PASS.

- [ ] **Step 2.3 Commit**

### Task 3: `R/anchors.R::infer_kind_from_ontology()` + override policy (NEW)

**Files:**
- Modify: `R/anchors.R`
- Create: `tests/testthat/test-anchors-infer-kind.R`

- [ ] **Step 3.1 Test cases (red phase)**

  Decision table di spec §4.3 → 20+ fixture casi:
  ```r
  # Ethanol (CHEBI:16236) — kind=cytokine_stim LLM → ontology=vehicle_only STRONG → OVERRIDE
  # Carnitine (CHEBI:17126) — kind=pathogen LLM → ontology=small_molecule WEAK ma contradiction → OVERRIDE (kind_assertion_contradiction)
  # Resiquimod (CHEBI:36706) — kind=small_molecule LLM → ontology STRONG cytokine_stim (interferon inducer) → OVERRIDE to cytokine_stim
  # Pregnanetriol MeSH D011279 — kind=disease_vs_normal LLM → MeSH tree=D04.* (chemicals not disease) → flag MESH_HALLUCINATED_OR_WRONG_KIND, LLM preserved
  # Hypoxia STR — no ontology → LLM kind preserved, no override
  # DMSO CHEBI:28262 — kind=vehicle_only LLM → ontology=vehicle_only STRONG (polar aprotic solvent) → no override (already matches)
  ```

- [ ] **Step 3.2 Implement `infer_kind_from_ontology()` + helper `_kind_assertion_contradicts()`**

  Vedi spec §4.3 per logica. Output completo:
  ```r
  list(
    kind_resolved = chr|NA,
    role_evidence = chr|NA,
    confidence = "STRONG"|"MEDIUM"|"WEAK"|"NONE",
    overridden = lgl,
    override_reason = chr|NA   # "STRONG_CONFIDENCE_MATCH" | "LLM_CONTRADICTION_DETECTED" | NA
  )
  ```

- [ ] **Step 3.3 Test + commit**

### Task 4: `R/stage3-anchor-levels.R::extract_anchor_segments()` integration

**Files:**
- Modify: `R/stage3-anchor-levels.R`
- Create: `tests/testthat/test-stage3-anchor-v31.R`

- [ ] **Step 4.1 Identifica integration points**

  Run `grep -n "extract_anchor_segments\|resolve_agent_id\|agent_normalized" R/stage3-anchor-levels.R` per mappare uso esistente.

  `extract_anchor_segments(study_facts, comparison)` riceve la lista LLM-derived; tutti i 13 segmenti vengono prodotti. I segmenti che ci interessano sono:
  - `segment_1 = kind_effective`
  - `segment_2 = agent_id`

- [ ] **Step 4.2 Refactor extract_anchor_segments() per ritornare canonical**

  - Inserisce `resolve_agent_canonical(agent_normalized)` per ottenere canonical_id e source.
  - Inserisce `infer_kind_from_ontology(canonical_id)` per kind override.
  - Ritorna SIA i segmenti (per anchor_key) SIA un attributo `$tracking_meta` con:
    - `agent_id_llm_original`
    - `agent_id_resolved`
    - `resolution_source`
    - `kind_effective_llm_original`
    - `kind_effective_resolved`
    - `kind_overridden`
    - `kind_override_reason`

- [ ] **Step 4.3 Caller side (probabilmente `R/stage3-build.R` o wherever clusters.rds è composto)**

  - Aggrega `tracking_meta` da tutti gli study/comparison di un cluster
  - Aggiunge colonne al `clusters` tibble: `agent_id_llm_original`, `agent_id_resolved`, etc.

- [ ] **Step 4.4 Test integration**

  Test fixture: load un stage2 fixture mini (`inst/extdata/stage2-fixtures-mini/`) con un sample-facts contenente CHEBI:17126 field-swap. Run `extract_anchor_segments` → verifica `segment_2 = "CHEBI:17126"` corretto e `tracking_meta$resolution_source = "CHEBI_FIELDSWAP"`.

  Run: `devtools::test(filter = "stage3-anchor-v31")`

- [ ] **Step 4.5 Commit**

### Task 5: Smoke isolato (3 cluster representativi, no full rebuild)

**Files:**
- Create: `analysis/p5-ontology-override-smoke.R`

- [ ] **Step 5.1 Smoke script**

  Carica 3 study fixtures dal `inst/extdata/stage2-fixtures-mini/` rappresentativi:
  - 1 con CHEBI field-swap (Carnitine pathogen wrong)
  - 1 con MeSH disease term
  - 1 con stringa libera (Hypoxia)

  Esegue resolve_agent_canonical + infer_kind_from_ontology + extract_anchor_segments. Output console:
  ```
  Cluster_A: agent_llm_original="CHEBI:17126" -> resolved="CHEBI:17126" (CHEBI_FIELDSWAP)
            kind_llm="pathogen_or_aggregate_exposure" -> resolved="small_molecule" (LLM_CONTRADICTION_DETECTED)
  ```

- [ ] **Step 5.2 Run smoke + visual check**
  ```bash
  Rscript analysis/p5-ontology-override-smoke.R 2>&1 | tee analysis/p5-ontology-override-smoke.log
  ```

- [ ] **Step 5.3 Commit smoke + log**
  Gate utente: review smoke output. Decisione: avanzare a S2.

---

## SESSIONE 2 — Stage 3 rebuild full + diff (1-3h)

### Task 6: Stage 3 rebuild (sui 39.247 stage2 master record)

**Files:**
- Modify: `analysis/p5-stage3-build.R` (se esiste; alternative `R/stage3-build.R` exported function)

- [ ] **Step 6.1 Identifica entry point Stage 3 build**
  ```bash
  grep -rn "build_stage3\|run_stage3" R/ analysis/ | head
  ```

- [ ] **Step 6.2 Run Stage 3 rebuild**
  ```bash
  cd /home/user/simulomicsr
  Rscript analysis/p5-stage3-build.R \
    --stage2-master analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds \
    --output-dir analysis/p4-output/$(date -u +%Y%m%dT%H%M%SZ)-stage3-v31 \
    2>&1 | tee analysis/p5-stage3-rebuild.log
  ```
  Wall stima: ~1h laptop (Stage 3 cluster build originale era ~30-60 min per 39k record).

- [ ] **Step 6.3 Validate output**
  Verifica:
  - `clusters.rds` ha le nuove 6 colonne (`agent_id_llm_original`, etc.)
  - `run_metadata.json` ha `schema_versions.anchor = "v3.1"` + `ontology_releases` section
  - n_studies = 39.247 invariato
  - n_cluster totale ± 5% rispetto old 267.056

### Task 7: Diff comparison Stage 3 old vs new

**Files:**
- Create: `analysis/p5-stage3-diff.R`

- [ ] **Step 7.1 Build diff script**
  - Load old clusters: `analysis/p4-output/20260519T055547Z-stage3-2153addc/clusters.rds`
  - Load new clusters: `analysis/p4-output/<new-ts>-stage3-v31/clusters.rds`
  - Stats per ogni resolution_source bucket: count, % cluster_id cambiati
  - Stats per kind_overridden: count, % per kind_effective
  - Per i 4 critically wrong Layer B (Carnitine cluster, Ethanol cluster, Pregnanetriol, dihydroxyphthalic): verifica come sono ora classificati

- [ ] **Step 7.2 Output report `docs/findings/2026-05-XX-stage3-v31-diff.md`**
  - Tabella before/after delle metriche audit
  - Audit residuo: che % di cluster ha ancora `kind_overridden=FALSE` ma kind_effective semanticamente wrong?
  - Recommendation per S3 (avanzare Stage 4 full rebuild?)

- [ ] **Step 7.3 Gate utente:** review diff stats → decisione S3.

---

## SESSIONE 3 — Stage 4 rebuild full (4-6h DGX o 28h laptop)

### Task 8: Stage 4 smoke (3 cluster su nuovo Stage 3)

**Files:**
- Reuse: smoke pattern di Stage 4 esistente

- [ ] **Step 8.1 Identifica 3 cluster smoke rappresentativi**
  Sul nuovo Stage 3:
  - 1 mega-big (un cluster con k>=20)
  - 1 mega-aug (un cluster pair_L4_*)
  - 1 mega-small (k=2-5)

- [ ] **Step 8.2 Run Stage 4 smoke 3-cluster**
  Riusa `analysis/p5-stage4-smoke-3cluster.R` se esiste (vedi tag `p5-stadio4-complete`).
  Wall stima: 5-10 min.

- [ ] **Step 8.3 Validate output**
  - pooled DE valid (n_sig coerente con magnitude attesa)
  - schema cluster_pooled.parquet invariato (Stage 4 schema NON cambia)

### Task 9: Stage 4 rebuild full (Layer A v3.1)

**DECISION GATE:** rebuild su laptop (28h) o DGX (4-6h, 2TB RAM)?

- [ ] **Step 9.1 Decisione utente: DGX o laptop?**
  Vedi memoria `user_dgx_backup_2tb` per criteri.

- [ ] **Step 9.2 Submit Stage 4 rebuild full**
  Riusa `build_stage4_results()` con stesso config registrato in `run_metadata.json` di Stage 4 v1:
  ```r
  config <- list(
    max_baseline_per_arm = 350,
    dream_workers_cap = 16,
    legacy_monodirectional = FALSE,
    franchini_correction = TRUE,
    de_engine = list(mega = "dream", mega_aug = "dream", rem = "limma-voom+eBayes"),
    pooling = list(rem_method = "REML", rem_fallback = "DL", fdr = "BH_within_cluster"),
    qc = list(lib_size_min = 500000)
  )
  ```
  Output dir: `analysis/p4-output/<ts>-stage4-v31-<run_id>/`.

- [ ] **Step 9.3 Validate output**
  - 622/622 cluster pooled OK atteso (numero cluster potrebbe variare leggermente per cambi anchor)
  - `cluster_pooled.parquet` + `per_study_de.parquet` + `stage4_dashboard.html` + `run_metadata.json`
  - `run_metadata.json` registra `schema_versions.anchor = "v3.1"` propagato da Stage 3

---

## SESSIONE 4 — Layer B re-shortlist + batch (30 min)

### Task 10: Layer B re-shortlist su Stage 4 v3.1

**Files:**
- Modify: `analysis/p5-stage4-layer-b-shortlist.R` (path Stage 4 nuovo)
- Modify: `analysis/layer-b-selection.csv` (re-curare)

- [ ] **Step 10.1 Update shortlist path**
  Cambia `stage4_dir` nello script verso il nuovo `analysis/p4-output/<ts>-stage4-v31-<run_id>/`.

- [ ] **Step 10.2 Run shortlist**
  ```bash
  Rscript analysis/p5-stage4-layer-b-shortlist.R
  ```
  Output: `analysis/p4-output/layer-b-shortlist.csv` aggiornata.

- [ ] **Step 10.3 Audit shortlist nuova**
  Riusa `analysis/p5-audit-15-layer-b.R` ma con shortlist intera (31 candidati): verifica che NESSUN candidato sia critically wrong (kind_validation = WRONG). Se ce ne sono, restringe ulteriormente la shortlist.

- [ ] **Step 10.4 Re-curare layer-b-selection.csv (15 case study)**
  - Mantieni almeno i 7 validi del precedente (poly(I:C), Resiquimod, IFN-β, Hypoxia, miR-9, contact inhibition, Mesendoderm) se ancora presenti come cluster_id post-rebuild
  - Sostituisci i 4 critically wrong + 2 unknown trasversali con nuovi candidati paper-grade dal nuovo audit
  - Aggiorna le label_paper con `compound_name` resolved (non più `CHEBI:NNNN`)

### Task 11: Layer B batch rebuild

- [ ] **Step 11.1 Update path in build script**
  `analysis/p5-stage4-layer-b-build.R`: aggiorna `stage4_dir` + `stage3_dir`.

- [ ] **Step 11.2 Lancia batch**
  ```bash
  Rscript analysis/p5-stage4-layer-b-build.R 2>&1 | tee analysis/p5-stage4-layer-b-build-v31.log
  ```
  Wall stima: 10-15 min (15 cluster).

- [ ] **Step 11.3 Audit post-rebuild**
  Riusa `analysis/p5-audit-15-layer-b.R` sui 15 nuovi → expect <5% misclassification.

- [ ] **Step 11.4 SendUserFile del nuovo `layer_b_report.html`**
  Gate utente: review visiva paper-grade.

---

## SESSIONE 5 — Close: ADR Accepted + memorie + master merge (1-2h)

### Task 12: Update ADR-0018 → Accepted

- [ ] **Step 12.1 Edit `docs/decisions/0018-llm-anchor-ontology-override.md`**
  - Status: Proposed → Accepted
  - Aggiungi sezione "Validation results" con i numeri reali (override rate, mismatch residuo, Layer B audit post-rebuild)

### Task 13: Update CLAUDE.md + memorie + NEWS

- [ ] **Step 13.1 CLAUDE.md**
  - Rimuovi sezione "AUDIT LLM ANCHOR CLASSIFICATION" warning, sostituisci con "Stadio 3 v3.1 + Stage 4 v3.1 + Layer B v3.1 COMPLETE, tag `p5-anchor-ontology-override-complete`"

- [ ] **Step 13.2 Memorie**
  - Update `project_llm_anchor_classification_audit.md` con risultato mitigation (status: "MITIGATED via OPZIONE 2")
  - Update `project_paper_known_limitations.md` con L2 residuale post-mitigation

- [ ] **Step 13.3 NEWS.md**
  Aggiungi versione 0.0.0.9021:
  ```
  - Stage 3 anchor v3.1 con post-hoc ontology override (ADR-0018)
  - R/ontology-lookup.R + R/anchors.R::resolve_agent_canonical + infer_kind_from_ontology
  - Stage 3+4 rebuild + Layer B re-shortlist
  ```

### Task 14: Final merge to master + tag

- [ ] **Step 14.1 Suite test completa**
  ```bash
  Rscript -e "devtools::test()" 2>&1 | tail -30
  ```
  Expect: PASS / 0 FAIL.

- [ ] **Step 14.2 R CMD check**
  ```bash
  Rscript -e "devtools::check()" 2>&1 | tail -20
  ```
  Expect: 0 errors / 0 warnings / 0 notes (o solo notes pre-esistenti).

- [ ] **Step 14.3 Merge in master**
  ```bash
  git checkout master
  git merge --ff-only p5-llm-anchor-classification-audit
  git tag p5-anchor-ontology-override-complete
  ```
  **NO push** (convenzione utente).

- [ ] **Step 14.4 Confirm finale all'utente**
  Riepilogo finale: numeri before/after + report `docs/findings/2026-05-XX-stage3-v31-diff.md`.

---

## Riferimenti

- Spec: `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
- ADR: `docs/decisions/0018-llm-anchor-ontology-override.md`
- HUMANE companion: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-HUMANE.md`
- Audit drive: `docs/findings/2026-05-24-llm-anchor-classification-audit.md`
- Layer B previous output: `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/` (baseline diff)
- Stage 4 previous output: `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` (baseline diff)
- Stage 3 previous output: `analysis/p4-output/20260519T055547Z-stage3-2153addc/` (baseline diff)
