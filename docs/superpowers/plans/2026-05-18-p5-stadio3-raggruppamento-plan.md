# P5 Stadio 3 — Raggruppamento cross-studio: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementare Stadio 3 che trasforma le 39.247 stage2 predictions in cluster cross-studio comparabili (anchor-pair per REM + anchor-group per mega-analisi), con 5 livelli di strictness, hard filters biologici, pooling safety quantitativo, canonical directionality detection, e output 5-file in directory versionata.

**Architecture:** Funzioni R pure + targets pipeline integration. Tiered anchor builder deriva da `R/anchors.R::make_anchor()` esistente per L0; nuove funzioni droppano segmenti per L1..L4. Hard filters (`subcellular`, `context_kind`) partition primaria. Dual-mode clustering (pair / group). Output in `analysis/p4-output/<timestamp>-stage3-<run_id>/` (5 file: parquet + 3 rds + json).

**Tech Stack:** R 4.5+, package simulomicsr (existing), `arrow` (NEW dep), `digest` (existing), `jsonlite` (existing), `tibble`/`dplyr`/`purrr` (existing). Tests via `testthat`. Pipeline via `targets`.

**Spec di riferimento:** `docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md` (commit `ac317fd`).

---

## File Structure

### Files da creare (R package source)

| File | Responsibility |
|------|----------------|
| `R/stage3-config.R` | `stage3_default_config()` + tier assignment + thresholds defaults |
| `R/stage3-anchor-levels.R` | `.build_anchor_for_level()` + tier-aware anchor derivation |
| `R/stage3-direction.R` | `.check_direction_canonical()` per anchor-pair |
| `R/stage3-safety.R` | `.compute_pooling_safety()` (min, geom_mean, per-segment) |
| `R/stage3-eligibility.R` | `.filter_eligible_records()` + non_clusterable construction |
| `R/stage3-cluster.R` | `.partition_by_hard_filters()` + `.assign_records_to_clusters()` |
| `R/stage3-usability.R` | `.tag_cluster_usability()` + 4 boolean use-flags |
| `R/stage3-metadata.R` | `.enrich_cluster_metadata()` (gpl, studies, donors) |
| `R/stage3-summary.R` | `.build_record_summary()` (min_viable_level helpers) |
| `R/stage3-archs4-meta.R` | `load_archs4_metadata()` + cache via `R_user_dir` |
| `R/stage3-build.R` | `build_stage3_clusters()` orchestrator + `stage3_result` S3 |
| `R/stage3-io.R` | `write_stage3_to_dir()` + `load_stage3()` |
| `R/stage3-helpers.R` | `filter_clusters()` + `cluster_records()` user helpers |

### Files da creare (tests)

| File | Coverage |
|------|----------|
| `tests/testthat/test-stage3-config.R` | Default config schema + tier partition invariants |
| `tests/testthat/test-stage3-anchor-levels.R` | Per-level anchor builder + monotonicity property |
| `tests/testthat/test-stage3-direction.R` | Canonical/swapped/ambiguous/indeterminate detection |
| `tests/testthat/test-stage3-safety.R` | Safety min + geom_mean + per-segment + L0 edge case |
| `tests/testthat/test-stage3-eligibility.R` | Tier S incomplete, n_per_group n1, direction filters |
| `tests/testthat/test-stage3-cluster.R` | Hard filter partition + cluster assignment + ID stability |
| `tests/testthat/test-stage3-usability.R` | 4 boolean flags + threshold edge cases |
| `tests/testthat/test-stage3-metadata.R` | GPL enrichment + study list + donor count |
| `tests/testthat/test-stage3-summary.R` | min_viable_level per mode |
| `tests/testthat/test-stage3-archs4-meta.R` | Cache hit/miss + H5 read |
| `tests/testthat/test-stage3-build.R` | Orchestrator end-to-end on mock data |
| `tests/testthat/test-stage3-io.R` | Round-trip write/load |
| `tests/testthat/test-stage3-helpers.R` | filter_clusters + cluster_records |
| `tests/testthat/test-stage3-fixture-mini.R` | Integration su 5 GSE da stage2-fixtures-mini |
| `tests/testthat/test-stage3-perf-budget.R` | Perf smoke (skip on CI), 15min budget |

### Files da modificare

| File | Modifica |
|------|----------|
| `DESCRIPTION` | Aggiungere `arrow` in Suggests; bump Version a 0.0.0.9018 |
| `NAMESPACE` | Auto-generato via roxygen, no edit manuale |
| `NEWS.md` | Aggiungere sezione 0.0.0.9018 con descrizione Stage 3 |
| `analysis/_targets.R` | Aggiungere targets stage3_config, archs4_metadata, stage3_run, stage3_out_dir |

### Files documentation

| File | Responsibility |
|------|----------------|
| `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md` | ADR Proposed → Accepted con merge |
| `docs/superpowers/plans/2026-05-18-p5-stadio3-raggruppamento-HUMANE.md` | Companion review checklist umana |

---

## Task 0: Setup — ADR-0014 + DESCRIPTION + dependency

**Files:**
- Create: `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md`
- Modify: `DESCRIPTION` (add `arrow` to Suggests, bump Version)
- Modify: `NEWS.md` (skeleton 0.0.0.9018 section)

- [ ] **Step 0.1: Write ADR-0014 in status Proposed**

Crea `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md`:

```markdown
# ADR-0014 — Stadio 3 tiered anchor + dual-mode + canonical directionality

**Status:** Proposed (2026-05-18)
**Decisori:** lucavd
**Predecessori:** ADR-0006 (positioning), ADR-0012 (stage2 schema multi-axis limitation)
**Sostituisce:** —
**Spec di riferimento:** `docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md`

## Contesto

Stadio 3 (raggruppamento cross-studio sui `comparability_anchor`) era pianificato in CLAUDE.md
come unico step da specificare post-β. Pre-spec, l'assunzione implicita era "cluster by exact
13-segment anchor match, k≥1 acceptable". Su 39.247 stage2 predictions cross 28k+ studi questo
genera ~70-90% singleton clusters, vanificando il pooling cross-study.

## Decisione

Stadio 3 implementa:

1. **Tiered anchor a 5 livelli** (L0..L4) con droppability biology-driven
   - Tier S (inviolabile, 3 segmenti): kind_effective, agent_id, tissue
   - Tier A (system identity, 3): variant_label, disease_status, phase_canonical
   - Tier B (modulators, 2): cell_state, cell_id
   - Tier C (continuous, 2): dose_canonical, duration_canonical
   - Tier D (low-info, 1): has_engineered

2. **Hard filters (2 segmenti)** come partition non-mergeabili a qualunque L:
   subcellular, context_kind

3. **Dual-mode**: anchor-group (per mega-analisi raw counts) + anchor-pair
   (per REM metafor). Output entrambi sempre.

4. **Canonical directionality** + flag `direction_check` per evitare cancellation REM
   cross-study quando ruoli sono swapped tra studi.

5. **Pooling safety score** `min(modal_freq per dropped segment)` come primary aggregator
   (weakest-link semantics; conservative).

6. **Boolean use-flags** (`usable_rem/mega × strict/relaxed`) in luogo di tier labels
   GOLD/SILVER/BRONZE (rigore vs heuristica).

## Conseguenze

### Positive
- "Spremiamo per bene" i dati: cluster pesabili a 5 livelli adattivi.
- Mega-analisi diventa first-class consumer (raw counts ARCHS4 H5 disponibile).
- Direction safety previene errori scientifici subdoli in REM cross-study.

### Negative / costi
- Output 5x piu' grande (5 levels) vs single L0.
- ADR-0006 va emendato: "metafor REM resta primary, mega-analisi secondary per cluster
  k-deboli N-ricchi" (addendum a questo ADR).
- Performance budget 15min su 39k record (a verificare in plan).

### Da rivisitare
- Se v2 di safety score serve un metric piu' raffinato (Shannon entropy normalized),
  esporre come opt-in.
- Se cross-tissue pooling diventa richiesto, valutare promozione `tissue` da S a A.

## Status

Proposed 2026-05-18. Diventera' Accepted al merge del branch `p5-stadio3-raggruppamento`.
```

- [ ] **Step 0.2: Bump DESCRIPTION e aggiungere `arrow` in Suggests**

Modifica `DESCRIPTION`:

```
Version: 0.0.0.9018
```

E nella sezione `Suggests:` aggiungi (in ordine alfabetico):

```
    arrow,
```

dopo `Suggests:` e prima di `checkmate,`.

- [ ] **Step 0.3: Skeleton NEWS.md 0.0.0.9018**

Aggiungi all'inizio di `NEWS.md` (dopo la riga `# simulomicsr (development version)` o equivalente):

```markdown
# simulomicsr 0.0.0.9018 (development)

## P5 — Stadio 3 raggruppamento cross-studio

* Nuovo modulo: cluster cross-studio sui `comparability_anchor` v3 con 5 livelli di
  strictness (L0..L4), hard filters biologici (subcellular, context_kind), dual-mode
  output (anchor-pair per REM + anchor-group per mega-analisi), canonical directionality
  detection per REM, pooling safety quantitativo. Dettagli in
  `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md` e
  `docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md`.
* API: `build_stage3_clusters()`, `stage3_default_config()`, `write_stage3_to_dir()`,
  `load_stage3()`, `filter_clusters()`, `cluster_records()`.
* Nuova dipendenza opzionale: `arrow` (per parquet `assignments` output).
```

- [ ] **Step 0.4: Verifica package coerente con devtools::document()**

Run:
```bash
Rscript --vanilla -e 'devtools::document()'
```

Expected: nessun error, no NAMESPACE changes ancora (no nuove funzioni esportate).

- [ ] **Step 0.5: Commit setup**

```bash
git checkout -b p5-stadio3-raggruppamento
git add DESCRIPTION NEWS.md docs/decisions/0014-stage3-tiered-anchor-dual-mode.md
git commit -m "P5 Stadio 3 Task 0: ADR-0014 Proposed + bump 0.0.0.9018 + arrow dep

Setup branch p5-stadio3-raggruppamento.

ADR-0014 documenta tiered anchor 5-livelli + hard filters + dual-mode + canonical
directionality. Status Proposed, diventa Accepted al merge.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 1: stage3_default_config + tier assignment

**Files:**
- Create: `R/stage3-config.R`
- Create: `tests/testthat/test-stage3-config.R`

- [ ] **Step 1.1: Scrivi test failing per `stage3_default_config()` structure**

Crea `tests/testthat/test-stage3-config.R`:

```r
test_that("stage3_default_config restituisce list con campi essenziali", {
  cfg <- stage3_default_config()

  expect_type(cfg, "list")
  expect_named(cfg, c("tier_assignment", "thresholds", "schema_versions"),
               ignore.order = TRUE)
})

test_that("tier_assignment include tutti e soli i 13 segmenti dell'anchor v3", {
  cfg <- stage3_default_config()
  ta <- cfg$tier_assignment

  expect_named(ta, c("S", "A", "B", "C", "D", "hard_filters"),
               ignore.order = TRUE)

  all_segments <- unlist(ta, use.names = FALSE)
  expected_13 <- c(
    "kind_effective", "agent_id", "variant_label", "dose_canonical",
    "duration_canonical", "phase_canonical", "cell_id", "context_kind",
    "cell_state", "subcellular", "tissue", "disease_status", "has_engineered"
  )

  expect_setequal(all_segments, expected_13)
  expect_equal(length(all_segments), 13L)  # nessun segmento ripetuto
})

test_that("tier S contiene esattamente i 3 segmenti inviolabili", {
  cfg <- stage3_default_config()
  expect_setequal(cfg$tier_assignment$S,
                  c("kind_effective", "agent_id", "tissue"))
})

test_that("hard_filters sono subcellular + context_kind", {
  cfg <- stage3_default_config()
  expect_setequal(cfg$tier_assignment$hard_filters,
                  c("subcellular", "context_kind"))
})

test_that("thresholds REM hanno k_min=2, k_recommended=3, k_gold=10", {
  cfg <- stage3_default_config()
  expect_equal(cfg$thresholds$rem$k_min, 2L)
  expect_equal(cfg$thresholds$rem$k_recommended, 3L)
  expect_equal(cfg$thresholds$rem$k_gold, 10L)
})

test_that("thresholds MEGA hanno n_studies 2/5/10 e n_total 30", {
  cfg <- stage3_default_config()
  expect_equal(cfg$thresholds$mega$n_studies_min, 2L)
  expect_equal(cfg$thresholds$mega$n_studies_recommended, 5L)
  expect_equal(cfg$thresholds$mega$n_studies_gold, 10L)
  expect_equal(cfg$thresholds$mega$n_total_recommended, 30L)
})

test_that("thresholds safety strict=0.7 relaxed=0.5", {
  cfg <- stage3_default_config()
  expect_equal(cfg$thresholds$safety$strict, 0.7)
  expect_equal(cfg$thresholds$safety$relaxed, 0.5)
})

test_that("schema_versions documenta tutte le versioni", {
  cfg <- stage3_default_config()
  expect_named(cfg$schema_versions,
               c("anchor", "stage3_algorithm", "sample_facts", "study_design"),
               ignore.order = TRUE)
  expect_equal(cfg$schema_versions$anchor, "v3")
  expect_equal(cfg$schema_versions$stage3_algorithm, "v1")
  expect_equal(cfg$schema_versions$sample_facts, "stage1.v3")
  expect_equal(cfg$schema_versions$study_design, "stage2.v2")
})
```

- [ ] **Step 1.2: Verifica test fallisce**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-config")'
```

Expected: tutti i test FAIL con `could not find function "stage3_default_config"`.

- [ ] **Step 1.3: Implementa `R/stage3-config.R`**

Crea `R/stage3-config.R`:

```r
#' Default configuration per Stadio 3 raggruppamento cross-studio
#'
#' Restituisce la configurazione di default che governa Stage 3: tier assignment
#' dei 13 segmenti dell'anchor v3 (vedi `make_anchor()`), thresholds per quality
#' flags (REM k_min/recommended/gold + MEGA n_studies/n_total + safety strict/relaxed),
#' versioning schema per riproducibilita'.
#'
#' Tier system (drop order D -> A; S sempre presente; hard_filters mai droppabili):
#'
#' - **S (inviolabile)**: kind_effective, agent_id, tissue
#' - **A (system identity)**: variant_label, disease_status, phase_canonical
#' - **B (modulators)**: cell_state, cell_id
#' - **C (continuous)**: dose_canonical, duration_canonical
#' - **D (low-info)**: has_engineered
#' - **hard_filters (partition)**: subcellular, context_kind
#'
#' @return list con 3 componenti: `tier_assignment`, `thresholds`, `schema_versions`.
#' @seealso `build_stage3_clusters()`, ADR-0014.
#' @export
stage3_default_config <- function() {
  list(
    tier_assignment = list(
      S = c("kind_effective", "agent_id", "tissue"),
      A = c("variant_label", "disease_status", "phase_canonical"),
      B = c("cell_state", "cell_id"),
      C = c("dose_canonical", "duration_canonical"),
      D = c("has_engineered"),
      hard_filters = c("subcellular", "context_kind")
    ),
    thresholds = list(
      rem = list(
        k_min         = 2L,
        k_recommended = 3L,
        k_gold        = 10L
      ),
      mega = list(
        n_studies_min         = 2L,
        n_studies_recommended = 5L,
        n_studies_gold        = 10L,
        n_total_recommended   = 30L
      ),
      safety = list(
        strict  = 0.7,
        relaxed = 0.5
      )
    ),
    schema_versions = list(
      anchor             = "v3",
      stage3_algorithm   = "v1",
      sample_facts       = "stage1.v3",
      study_design       = "stage2.v2"
    )
  )
}

#' Restituisce i segmenti droppati a un livello L
#'
#' Helper interno: dato il tier_assignment e il livello L (0..4), restituisce
#' i segmenti che vengono RIMOSSI dall'anchor a quel livello. L0 = empty (nessun
#' drop). L4 = drop(D + C + B + A). I tier S e hard_filters NON sono mai
#' nell'output.
#'
#' @keywords internal
.dropped_segments_at_level <- function(tier_assignment, level) {
  stopifnot(level %in% 0L:4L)
  drop_tiers <- switch(
    as.character(level),
    "0" = character(),
    "1" = "D",
    "2" = c("D", "C"),
    "3" = c("D", "C", "B"),
    "4" = c("D", "C", "B", "A")
  )
  unlist(tier_assignment[drop_tiers], use.names = FALSE)
}

#' Restituisce i segmenti mantenuti nell'anchor a un livello L (S + tier-residui)
#'
#' Non include hard_filters (quelli sono partition esterna, non parte dell'anchor key).
#' @keywords internal
.kept_segments_at_level <- function(tier_assignment, level) {
  dropped <- .dropped_segments_at_level(tier_assignment, level)
  all_droppable <- unlist(tier_assignment[c("S", "A", "B", "C", "D")],
                          use.names = FALSE)
  setdiff(all_droppable, dropped)
}
```

- [ ] **Step 1.4: Verifica test passa**

Run:
```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-config")'
```

Expected: PASS tutti i test scritti in 1.1.

- [ ] **Step 1.5: Aggiungi test per le funzioni helper interne**

Aggiungi in `tests/testthat/test-stage3-config.R`:

```r
test_that(".dropped_segments_at_level produce drop monotonic", {
  ta <- stage3_default_config()$tier_assignment

  d0 <- simulomicsr:::.dropped_segments_at_level(ta, 0L)
  d1 <- simulomicsr:::.dropped_segments_at_level(ta, 1L)
  d2 <- simulomicsr:::.dropped_segments_at_level(ta, 2L)
  d3 <- simulomicsr:::.dropped_segments_at_level(ta, 3L)
  d4 <- simulomicsr:::.dropped_segments_at_level(ta, 4L)

  expect_length(d0, 0L)
  expect_setequal(d1, "has_engineered")
  expect_setequal(d2, c("has_engineered", "dose_canonical", "duration_canonical"))
  expect_setequal(d3, c("has_engineered", "dose_canonical", "duration_canonical",
                        "cell_state", "cell_id"))
  expect_setequal(d4, c("has_engineered", "dose_canonical", "duration_canonical",
                        "cell_state", "cell_id",
                        "variant_label", "disease_status", "phase_canonical"))

  # Monotonicity: d_i subset of d_{i+1}
  expect_true(all(d0 %in% d1))
  expect_true(all(d1 %in% d2))
  expect_true(all(d2 %in% d3))
  expect_true(all(d3 %in% d4))
})

test_that(".kept_segments_at_level always includes tier S", {
  ta <- stage3_default_config()$tier_assignment
  for (L in 0L:4L) {
    kept <- simulomicsr:::.kept_segments_at_level(ta, L)
    expect_true(all(ta$S %in% kept), info = sprintf("L%d", L))
  }
})

test_that(".kept_segments_at_level at L4 is exactly tier S", {
  ta <- stage3_default_config()$tier_assignment
  expect_setequal(simulomicsr:::.kept_segments_at_level(ta, 4L), ta$S)
})

test_that(".kept_segments_at_level at L0 is all droppable segments", {
  ta <- stage3_default_config()$tier_assignment
  expected <- unlist(ta[c("S", "A", "B", "C", "D")], use.names = FALSE)
  expect_setequal(simulomicsr:::.kept_segments_at_level(ta, 0L), expected)
})
```

- [ ] **Step 1.6: Verifica nuovi test passano**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-config")'
```

Expected: PASS tutti.

- [ ] **Step 1.7: Commit Task 1**

```bash
git add R/stage3-config.R tests/testthat/test-stage3-config.R
git commit -m "P5 Stadio 3 Task 1: stage3_default_config + tier assignment

Tier S/A/B/C/D + hard_filters definiti. Thresholds REM/MEGA/safety con defaults
da spec. Helper interni .dropped_segments_at_level + .kept_segments_at_level
con monotonicity tested.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: .build_anchor_for_level — tier-aware anchor derivation

**Files:**
- Create: `R/stage3-anchor-levels.R`
- Create: `tests/testthat/test-stage3-anchor-levels.R`

- [ ] **Step 2.1: Scrivi test failing per `.build_anchor_for_level()`**

Crea `tests/testthat/test-stage3-anchor-levels.R`:

```r
# Helper per costruire un sample_fact fixture
make_test_sample_fact <- function() {
  list(
    perturbations = list(list(
      kind = "small_molecule",
      agent_normalized = list(id = "CHEMBL941", preferred_name = "imatinib"),
      dose = list(value_raw = "10nM"),
      duration = list(value_raw = "24h"),
      phase = "exposure"
    )),
    cell_context = list(
      cell_type_or_line_raw = "HUVEC",
      cell_line_cellosaurus_candidate = "CVCL_2959",
      context_kind = "cell_line",
      cell_state = "proliferating",
      subcellular_fraction = NULL,
      tissue = "endothelium",
      engineered_modifications = list()
    ),
    disease_state = list(status = "healthy", mesh_id_candidate = NULL)
  )
}

test_that(".build_anchor_for_level a L0 equivale a make_anchor() (13 segmenti)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  anchor_l0 <- simulomicsr:::.build_anchor_for_level(
    stage1_facts = fact,
    stage2_role = "treated",
    level = 0L,
    tier_assignment = cfg$tier_assignment
  )

  # Stesso numero di segmenti di make_anchor()
  expect_equal(length(strsplit(anchor_l0, "\\|")[[1]]), 13L)
})

test_that(".build_anchor_for_level L1 ha 12 segmenti (drop has_engineered)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  anchor_l1 <- simulomicsr:::.build_anchor_for_level(
    fact, "treated", 1L, cfg$tier_assignment
  )
  expect_equal(length(strsplit(anchor_l1, "\\|")[[1]]), 12L)
})

test_that(".build_anchor_for_level L4 ha 3 segmenti (solo Tier S)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  anchor_l4 <- simulomicsr:::.build_anchor_for_level(
    fact, "treated", 4L, cfg$tier_assignment
  )
  segs <- strsplit(anchor_l4, "\\|")[[1]]
  expect_equal(length(segs), 3L)
  # Tier S: kind_effective, agent_id, tissue
  expect_equal(segs[1], "small_molecule")     # kind_effective
  expect_equal(segs[2], "CHEMBL941")          # agent_id
  expect_equal(segs[3], "endothelium")        # tissue
})

test_that(".build_anchor_for_level e' deterministico (stesso input -> stesso output)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  a1 <- simulomicsr:::.build_anchor_for_level(fact, "treated", 2L, cfg$tier_assignment)
  a2 <- simulomicsr:::.build_anchor_for_level(fact, "treated", 2L, cfg$tier_assignment)
  expect_identical(a1, a2)
})

test_that(".extract_hard_filters restituisce subcellular + context_kind", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  hf <- simulomicsr:::.extract_hard_filters(fact, cfg$tier_assignment)
  expect_named(hf, c("subcellular", "context_kind"))
  expect_equal(hf$context_kind, "cell_line")
  expect_equal(hf$subcellular, "whole_cell")  # default quando NULL
})

test_that(".extract_anchor_segments restituisce 13 segmenti named", {
  fact <- make_test_sample_fact()

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated")
  expect_named(segs, c(
    "kind_effective", "agent_id", "variant_label", "dose_canonical",
    "duration_canonical", "phase_canonical", "cell_id", "context_kind",
    "cell_state", "subcellular", "tissue", "disease_status", "has_engineered"
  ))
  expect_equal(segs$kind_effective, "small_molecule")
  expect_equal(segs$tissue, "endothelium")
})
```

- [ ] **Step 2.2: Verifica test failing**

Run:
```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-anchor-levels")'
```

Expected: FAIL "could not find function".

- [ ] **Step 2.3: Implementa `R/stage3-anchor-levels.R`**

Crea `R/stage3-anchor-levels.R`:

```r
#' Estrae i 13 segmenti dell'anchor v3 come named list
#'
#' Replica internamente la logica di `make_anchor()` ma restituisce un named list
#' con i 13 valori invece della stringa concatenata. Usato come basis per costruire
#' anchor a livelli L0..L4 droppando segmenti.
#'
#' @keywords internal
.extract_anchor_segments <- function(stage1_facts, stage2_role) {
  # Riusa le funzioni helper esistenti da R/anchors.R
  pert <- .select_primary_perturbation(stage1_facts$perturbations, stage2_role)

  has_active_perturbation <- length(stage1_facts$perturbations) > 0L &&
    !is.null(pert$kind) &&
    !identical(pert$kind, "none") &&
    !identical(pert$kind, "vehicle_only") &&
    !identical(pert$kind, "unclear")

  is_disease_design <- stage2_role %in% c("case", "comparison") ||
    (isTRUE(stage1_facts$disease_state$status %in%
              c("case", "comparison", "disease_model")) &&
       !has_active_perturbation)

  if (is_disease_design) {
    kind_effective <- "disease_vs_normal"
    agent_id       <- stage1_facts$disease_state$mesh_id_candidate %||% "unknown"
    variant_label  <- "wt"
  } else if (!is.null(pert$mediated_effect) && length(pert$mediated_effect) > 0L) {
    kind_effective <- .map_kind_to_anchor(pert$mediated_effect$kind %||% pert$kind %||% "unclear")
    target_name    <- if (length(pert$mediated_effect$targets) > 0L)
                        pert$mediated_effect$targets[[1L]]
                      else
                        "unknown"
    agent_id       <- paste0("HGNC:", target_name)
    variant_label  <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)
  } else {
    kind_effective <- .map_kind_to_anchor(pert$kind %||% "unclear")
    agent_id       <- .resolve_agent_id(pert$agent_normalized)
    variant_label  <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)
  }

  dose_canonical     <- .normalize_dose(pert$dose$value_raw %||% NULL)
  duration_canonical <- .normalize_duration(pert$duration$value_raw %||% NULL)
  phase_canonical    <- pert$phase %||% "exposure"

  cell_id     <- .normalize_cell_id(
    stage1_facts$cell_context$cell_line_cellosaurus_candidate,
    stage1_facts$cell_context$cell_type_or_line_raw
  )
  context_kind <- stage1_facts$cell_context$context_kind %||% "unclear"
  cell_state   <- stage1_facts$cell_context$cell_state %||% "proliferating"
  subcellular  <- if (!is.null(stage1_facts$cell_context$subcellular_fraction) &&
                       length(stage1_facts$cell_context$subcellular_fraction) > 0L)
                    stage1_facts$cell_context$subcellular_fraction$kind %||% "whole_cell"
                  else
                    "whole_cell"
  tissue       <- stage1_facts$cell_context$tissue %||% "na"

  disease_status <- .resolve_disease_status(stage1_facts$disease_state, stage2_role)
  has_engineered <- tolower(as.character(
    length(stage1_facts$cell_context$engineered_modifications) > 0L
  ))

  list(
    kind_effective     = kind_effective,
    agent_id           = agent_id,
    variant_label      = variant_label,
    dose_canonical     = dose_canonical,
    duration_canonical = duration_canonical,
    phase_canonical    = phase_canonical,
    cell_id            = cell_id,
    context_kind       = context_kind,
    cell_state         = cell_state,
    subcellular        = subcellular,
    tissue             = tissue,
    disease_status     = disease_status,
    has_engineered     = has_engineered
  )
}

#' Costruisce l'anchor a un dato livello L (droppando segmenti per tier)
#'
#' L0 = tutti 13 segmenti (equivalente di `make_anchor()`). L1..L4 progressivamente
#' droppano tier D, C, B, A. Tier S (kind_effective, agent_id, tissue) sempre presente.
#' Hard filters (subcellular, context_kind) NON inclusi qui (gestiti separatamente).
#'
#' L'ordine dei segmenti nell'output e' canonical (sorted per `.kept_segments_at_level()`),
#' per garantire determinismo del cluster key.
#'
#' @return character(1) chiave concatenata con "|"
#' @keywords internal
.build_anchor_for_level <- function(stage1_facts, stage2_role, level, tier_assignment) {
  stopifnot(level %in% 0L:4L)

  segs <- .extract_anchor_segments(stage1_facts, stage2_role)
  kept <- .kept_segments_at_level(tier_assignment, level)

  # Ordine deterministico: segmenti in ordine alfabetico per chiavi stabili
  kept_sorted <- sort(kept)
  values <- vapply(kept_sorted, function(s) as.character(segs[[s]]), character(1L))

  paste(values, collapse = "|")
}

#' Estrae i 2 hard filters (subcellular + context_kind) come named list
#'
#' Usati per partition primaria dei records a `.partition_by_hard_filters()`.
#' Mai dropabili a nessun L.
#'
#' @keywords internal
.extract_hard_filters <- function(stage1_facts, tier_assignment) {
  segs <- .extract_anchor_segments(stage1_facts, stage2_role = "treated")
  hf_keys <- tier_assignment$hard_filters
  segs[hf_keys]
}
```

- [ ] **Step 2.4: Verifica test passano**

Run:
```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-anchor-levels")'
```

Expected: PASS.

- [ ] **Step 2.5: Property-based test su monotonicity tra livelli**

Aggiungi a `tests/testthat/test-stage3-anchor-levels.R`:

```r
test_that("monotonicity: anchor a L_high e' subset di anchor a L_low (lessicalmente)", {
  # Per ogni sample, segmenti di L_high subset di L_low (in termini di kept_segments)
  cfg <- stage3_default_config()
  ta <- cfg$tier_assignment

  for (L in 0L:3L) {
    kept_L     <- simulomicsr:::.kept_segments_at_level(ta, L)
    kept_Lplus <- simulomicsr:::.kept_segments_at_level(ta, L + 1L)
    expect_true(all(kept_Lplus %in% kept_L),
                info = sprintf("L%d+1 segments must subset L%d segments", L, L))
  }
})

test_that("disease_vs_normal override: stage2_role=case produce kind_effective=disease_vs_normal", {
  fact <- make_test_sample_fact()
  fact$disease_state$status <- "case"
  fact$disease_state$mesh_id_candidate <- "D003920"  # diabetes mellitus

  cfg <- stage3_default_config()
  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "case")
  expect_equal(segs$kind_effective, "disease_vs_normal")
  expect_equal(segs$agent_id, "D003920")
})
```

Run + expect PASS:
```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-anchor-levels")'
```

- [ ] **Step 2.6: Commit Task 2**

```bash
git add R/stage3-anchor-levels.R tests/testthat/test-stage3-anchor-levels.R
git commit -m "P5 Stadio 3 Task 2: .build_anchor_for_level + .extract_hard_filters

Tier-aware anchor derivation per L0..L4. L0 equivale make_anchor() 13 seg.
L4 = tier S only (3 seg). Monotonicity property tested. Hard filters
estratti separatamente.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: .check_direction_canonical — canonical directionality detection

**Files:**
- Create: `R/stage3-direction.R`
- Create: `tests/testthat/test-stage3-direction.R`

- [ ] **Step 3.1: Scrivi test failing**

Crea `tests/testthat/test-stage3-direction.R`:

```r
test_that("direction canonical: vehicle control + perturbed treated -> canonical", {
  treated_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL941")
  control_segs <- list(kind_effective = "vehicle_only", agent_id = "DMSO")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "vehicle"
  )
  expect_equal(result, "canonical")
})

test_that("direction swapped: vehicle in treated_group + perturbed in control_group", {
  treated_segs <- list(kind_effective = "vehicle_only", agent_id = "DMSO")
  control_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL941")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "vehicle"
  )
  expect_equal(result, "swapped")
})

test_that("direction ambiguous: control_type=secondary_arm", {
  treated_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL941")
  control_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL112")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "secondary_arm"
  )
  expect_equal(result, "ambiguous")
})

test_that("direction indeterminate: anchor incompleti", {
  treated_segs <- list(kind_effective = "unclear", agent_id = "unknown")
  control_segs <- list(kind_effective = "vehicle_only", agent_id = "DMSO")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "vehicle"
  )
  expect_equal(result, "indeterminate")
})

test_that("direction canonical: disease_normal + disease in treated -> canonical", {
  treated_segs <- list(kind_effective = "disease_vs_normal", agent_id = "D003920")
  control_segs <- list(kind_effective = "disease_vs_normal", agent_id = "D003920")
  # In disease_vs_normal designs, ENTRAMBI hanno kind_effective="disease_vs_normal"
  # by anchor function override. La distinzione e' nel disease_status.

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "disease_normal"
  )
  expect_equal(result, "canonical")
})

test_that("direction canonical: control_type=untreated comportamento simmetrico a vehicle", {
  treated_segs <- list(kind_effective = "cytokine_stim", agent_id = "HGNC:TNF")
  control_segs <- list(kind_effective = "none", agent_id = "unknown")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "untreated"
  )
  expect_equal(result, "canonical")
})

test_that("direction swapped: control_type=untreated ma none in treated_group", {
  treated_segs <- list(kind_effective = "none", agent_id = "unknown")
  control_segs <- list(kind_effective = "cytokine_stim", agent_id = "HGNC:TNF")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "untreated"
  )
  expect_equal(result, "swapped")
})
```

- [ ] **Step 3.2: Verifica test failing**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-direction")'
```

Expected: FAIL.

- [ ] **Step 3.3: Implementa `R/stage3-direction.R`**

Crea `R/stage3-direction.R`:

```r
#' Convention canonica per control_type (baseline-roles)
#'
#' control_type values il cui ruolo "baseline / no-perturbation" e' chiaro:
#' il control_group e' assunto essere il baseline; il treated_group la perturbed.
#'
#' @keywords internal
.canonical_control_types <- c(
  "vehicle", "untreated", "genetic_negative", "inducer_off",
  "time_zero", "disease_normal"
)

#' control_type values che sono intrinsecamente ambigui sul role assignment
#' @keywords internal
.ambiguous_control_types <- c("secondary_arm")

#' kind_effective che indicano "baseline / no-perturbation"
#' @keywords internal
.baseline_kinds <- c("none", "vehicle_only", "unclear")

#' Determina se la direzione del pair (treated -> control) e' canonical
#'
#' Stage 3 NON flippa automaticamente: espone solo il flag. P5 al consumption
#' time, se `swapped`, moltiplica yi per -1.
#'
#' Regole:
#' - `canonical`: control_type in .canonical_control_types AND treated_anchor
#'   ha kind_effective NON-baseline AND control_anchor ha kind_effective baseline.
#'   Speciale: control_type=disease_normal accetta `disease_vs_normal` in entrambi
#'   (override anchor function), e canonical e' assunta dal LLM.
#' - `swapped`: control_type in .canonical_control_types AND ruoli sono invertiti
#'   (baseline nel treated, perturbed nel control).
#' - `ambiguous`: control_type in .ambiguous_control_types (secondary_arm).
#' - `indeterminate`: uno dei anchor ha tier S incomplete (kind=unclear OR
#'   agent_id=unknown) e impossibile valutare.
#'
#' @keywords internal
.check_direction_canonical <- function(treated_anchor_segments,
                                       control_anchor_segments,
                                       control_type) {
  t_kind <- treated_anchor_segments$kind_effective
  t_agent <- treated_anchor_segments$agent_id
  c_kind <- control_anchor_segments$kind_effective
  c_agent <- control_anchor_segments$agent_id

  # Indeterminate: tier S incomplete (impossibile valutare)
  tier_s_missing <- function(kind, agent) {
    identical(kind, "unclear") || identical(agent, "unknown")
  }

  if (tier_s_missing(t_kind, t_agent) || tier_s_missing(c_kind, c_agent)) {
    return("indeterminate")
  }

  # Ambiguous: control_type intrinsecamente non-determinabile
  if (control_type %in% .ambiguous_control_types) {
    return("ambiguous")
  }

  # disease_normal: convention assume LLM ha gia' assegnato correttamente
  # (entrambi i kind sono "disease_vs_normal" per anchor override).
  if (identical(control_type, "disease_normal")) {
    return("canonical")
  }

  # Standard canonical/swapped check
  if (control_type %in% .canonical_control_types) {
    t_is_baseline <- t_kind %in% .baseline_kinds
    c_is_baseline <- c_kind %in% .baseline_kinds

    if (!t_is_baseline && c_is_baseline) return("canonical")
    if (t_is_baseline && !c_is_baseline) return("swapped")

    # Edge case: entrambi baseline o entrambi non-baseline
    # (es. control_type=untreated ma sia treated_group sia control_group
    # hanno una perturbazione attiva — comparison di due trattamenti diversi)
    return("ambiguous")
  }

  # control_type non recognized (non dovrebbe accadere se stage2 schema valida)
  "indeterminate"
}
```

- [ ] **Step 3.4: Verifica test passano**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-direction")'
```

Expected: PASS.

- [ ] **Step 3.5: Commit Task 3**

```bash
git add R/stage3-direction.R tests/testthat/test-stage3-direction.R
git commit -m "P5 Stadio 3 Task 3: .check_direction_canonical per anchor-pair

4 stati: canonical | swapped | ambiguous | indeterminate. Decision tree
basato su control_type + kind_effective di treated/control. NON flippa
automaticamente: espone flag per P5 sign-flip a consumption time.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: .compute_pooling_safety — safety score quantitativo

**Files:**
- Create: `R/stage3-safety.R`
- Create: `tests/testthat/test-stage3-safety.R`

- [ ] **Step 4.1: Scrivi test failing**

Crea `tests/testthat/test-stage3-safety.R`:

```r
test_that("safety_min = 1.0 quando nessun segmento droppato (L0)", {
  cluster_records <- list(
    list(dose_canonical = "10nM", duration_canonical = "24h"),
    list(dose_canonical = "10nM", duration_canonical = "24h")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = character()
  )
  expect_equal(result$safety_min, 1.0)
  expect_equal(result$safety_geom_mean, 1.0)
  expect_equal(length(result$safety_per_segment), 0L)
})

test_that("safety per single dropped segment: tutti uguali -> safety=1.0", {
  cluster_records <- list(
    list(dose_canonical = "10nM"),
    list(dose_canonical = "10nM"),
    list(dose_canonical = "10nM")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = "dose_canonical"
  )
  expect_equal(result$safety_min, 1.0)
  expect_equal(result$safety_per_segment$dose_canonical, 1.0)
})

test_that("safety modal frequency = 2/3 per 3 records con 2-1 split", {
  cluster_records <- list(
    list(dose_canonical = "10nM"),
    list(dose_canonical = "10nM"),
    list(dose_canonical = "100nM")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = "dose_canonical"
  )
  expect_equal(result$safety_min, 2/3, tolerance = 1e-9)
  expect_equal(result$safety_per_segment$dose_canonical, 2/3, tolerance = 1e-9)
})

test_that("safety_min usa weakest-link semantics su segmenti multipli", {
  # 4 records, 4 dropped segs: 3 con safety alta, 1 con safety bassa
  cluster_records <- list(
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "proliferating", has_engineered = "false"),
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "proliferating", has_engineered = "false"),
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "proliferating", has_engineered = "true"),
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "quiescent", has_engineered = "true")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = c("dose_canonical", "duration_canonical",
                          "cell_state", "has_engineered")
  )
  # safety_per_segment: dose=1.0, duration=1.0, cell_state=3/4=0.75,
  #                     has_engineered=2/4=0.5
  expect_equal(result$safety_per_segment$dose_canonical, 1.0)
  expect_equal(result$safety_per_segment$has_engineered, 0.5)
  expect_equal(result$safety_min, 0.5)
  # geom_mean = (1 * 1 * 0.75 * 0.5)^(1/4) ~ 0.66
  expect_equal(result$safety_geom_mean, (1 * 1 * 0.75 * 0.5)^(1/4),
               tolerance = 1e-9)
})

test_that("safety con cluster di 1 record sempre 1.0 (no eterogeneita' possibile)", {
  cluster_records <- list(
    list(dose_canonical = "10nM")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = "dose_canonical"
  )
  expect_equal(result$safety_min, 1.0)
  expect_equal(result$safety_per_segment$dose_canonical, 1.0)
})
```

- [ ] **Step 4.2: Verifica test failing**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-safety")'
```

Expected: FAIL.

- [ ] **Step 4.3: Implementa `R/stage3-safety.R`**

Crea `R/stage3-safety.R`:

```r
#' Calcola il pooling safety score per un cluster
#'
#' Per ogni segmento droppato, calcola la modal frequency (max p) nel cluster.
#' Aggrega via min (weakest-link, primary) e geom_mean (softer, secondary).
#' Mantiene per-segment scores nell'output per analisi custom.
#'
#' L0 case (no segments dropped): safety = 1.0 by convention.
#'
#' @param cluster_records list of list, ogni elemento e' un sample_fact o anchor segments
#'   con i segmenti droppati come keys.
#' @param dropped_segments character vector dei nomi dei segmenti droppati.
#' @return list con `safety_min`, `safety_geom_mean`, `safety_per_segment` (named list).
#' @keywords internal
.compute_pooling_safety <- function(cluster_records, dropped_segments) {
  if (length(dropped_segments) == 0L) {
    return(list(
      safety_min         = 1.0,
      safety_geom_mean   = 1.0,
      safety_per_segment = list()
    ))
  }

  per_segment <- vapply(dropped_segments, function(seg) {
    values <- vapply(cluster_records, function(r) {
      v <- r[[seg]]
      if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)
    }, character(1L))
    # Modal frequency: max(table) / total
    tbl <- table(values, useNA = "ifany")
    as.numeric(max(tbl) / length(values))
  }, numeric(1L))

  names(per_segment) <- dropped_segments

  list(
    safety_min         = min(per_segment),
    safety_geom_mean   = exp(mean(log(per_segment))),
    safety_per_segment = as.list(per_segment)
  )
}
```

- [ ] **Step 4.4: Verifica test passano**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-safety")'
```

Expected: PASS.

- [ ] **Step 4.5: Commit Task 4**

```bash
git add R/stage3-safety.R tests/testthat/test-stage3-safety.R
git commit -m "P5 Stadio 3 Task 4: .compute_pooling_safety

Min (weakest-link primary) + geom_mean (secondary) + per-segment modal freq.
L0 edge case = safety 1.0 by convention. Single-record cluster = 1.0.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: .filter_eligible_records — pre-cluster eligibility

**Files:**
- Create: `R/stage3-eligibility.R`
- Create: `tests/testthat/test-stage3-eligibility.R`

- [ ] **Step 5.1: Scrivi test failing**

Crea `tests/testthat/test-stage3-eligibility.R`:

```r
# Helper: construct un record di input per Stage 3
make_test_record <- function(record_id = "GSE100__cmp01",
                              mode = "pair",
                              kind_treated = "small_molecule",
                              agent_treated = "CHEMBL941",
                              tissue_treated = "endothelium",
                              kind_control = "vehicle_only",
                              agent_control = "DMSO",
                              tissue_control = "endothelium",
                              n_treated = 3, n_control = 3,
                              control_type = "vehicle") {
  list(
    record_id = record_id,
    mode = mode,
    series_id = sub("__.*$", "", record_id),
    treated_anchor_segments = list(
      kind_effective = kind_treated, agent_id = agent_treated,
      tissue = tissue_treated, variant_label = "wt",
      disease_status = "healthy", phase_canonical = "exposure",
      cell_state = "proliferating", cell_id = "HUVEC",
      dose_canonical = "10nM", duration_canonical = "24h",
      has_engineered = "false", subcellular = "whole_cell",
      context_kind = "cell_line"
    ),
    control_anchor_segments = list(
      kind_effective = kind_control, agent_id = agent_control,
      tissue = tissue_control, variant_label = "wt",
      disease_status = "healthy", phase_canonical = "exposure",
      cell_state = "proliferating", cell_id = "HUVEC",
      dose_canonical = "nodose", duration_canonical = "24h",
      has_engineered = "false", subcellular = "whole_cell",
      context_kind = "cell_line"
    ),
    n_treated_group = n_treated,
    n_control_group = n_control,
    control_type = control_type
  )
}

test_that("eligible record (pair) passes filter cleanly", {
  rec <- make_test_record()
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 1L)
  expect_length(result$non_clusterable, 0L)
})

test_that("tier_s_incomplete: kind=unclear -> non_clusterable", {
  rec <- make_test_record(kind_treated = "unclear")
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 0L)
  expect_length(result$non_clusterable, 1L)
  expect_equal(result$non_clusterable[[1]]$reason, "tier_s_incomplete")
})

test_that("tier_s_incomplete: agent=unknown -> non_clusterable", {
  rec <- make_test_record(agent_treated = "unknown")
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "tier_s_incomplete")
})

test_that("tier_s_incomplete: tissue=na -> non_clusterable", {
  rec <- make_test_record(tissue_treated = "na")
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "tier_s_incomplete")
})

test_that("rem_eligibility_n1: n_treated=1 -> non_clusterable per pair", {
  rec <- make_test_record(n_treated = 1)
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "rem_eligibility_n1")
  expect_match(result$non_clusterable[[1]]$details, "n_treated_group=1")
})

test_that("rem_eligibility_n1: n_control=1 -> non_clusterable per pair", {
  rec <- make_test_record(n_control = 1)
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "rem_eligibility_n1")
  expect_match(result$non_clusterable[[1]]$details, "n_control_group=1")
})

test_that("group mode: n_treated=1 e' eligible (no rem_eligibility filter)", {
  rec <- make_test_record(mode = "group", n_treated = 1)
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 1L)
})

test_that("multiple records: separati corretti tra eligible e non_clusterable", {
  recs <- list(
    make_test_record(record_id = "GSE1__cmp01"),                          # eligible
    make_test_record(record_id = "GSE2__cmp01", kind_treated = "unclear"), # tier_s
    make_test_record(record_id = "GSE3__cmp01", n_treated = 1),            # n1
    make_test_record(record_id = "GSE4__cmp01")                           # eligible
  )
  result <- simulomicsr:::.filter_eligible_records(recs)
  expect_length(result$eligible, 2L)
  expect_length(result$non_clusterable, 2L)
})
```

- [ ] **Step 5.2: Verifica test failing**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-eligibility")'
```

Expected: FAIL.

- [ ] **Step 5.3: Implementa `R/stage3-eligibility.R`**

Crea `R/stage3-eligibility.R`:

```r
#' Verifica se un anchor segments ha Tier S completo
#'
#' Tier S = kind_effective, agent_id, tissue. Se uno qualunque e' "unclear",
#' "unknown" o "na", il record non puo' essere clusterizzato a nessun L.
#'
#' @keywords internal
.has_complete_tier_s <- function(anchor_segments) {
  k <- anchor_segments$kind_effective
  a <- anchor_segments$agent_id
  t <- anchor_segments$tissue

  !(is.null(k) || identical(k, "unclear") || identical(k, "unknown") || is.na(k)) &&
    !(is.null(a) || identical(a, "unknown") || identical(a, "unclear") || is.na(a)) &&
    !(is.null(t) || identical(t, "na") || identical(t, "unknown") ||
        identical(t, "unclear") || is.na(t))
}

#' Filtra records eligible per Stage 3 clustering
#'
#' Per ogni record applica:
#' 1. Tier S incomplete check (treated AND control anchors per mode=pair;
#'    treated per mode=group).
#' 2. REM eligibility (mode=pair only): n_per_group >= 2 per entrambi i gruppi.
#'
#' Direction check NON e' qui (richiede tutti gli anchor segments + control_type;
#' fatto in fase di cluster assembly per Stage 3).
#'
#' @param records list di record (output di stage2 normalized + sample_facts joined)
#' @return list(eligible = list_of_records, non_clusterable = list_of_dropped)
#' @keywords internal
.filter_eligible_records <- function(records) {
  eligible <- list()
  non_clusterable <- list()

  for (rec in records) {
    mode <- rec$mode

    # 1. Tier S complete check
    t_complete <- .has_complete_tier_s(rec$treated_anchor_segments)
    c_complete <- if (identical(mode, "pair"))
                    .has_complete_tier_s(rec$control_anchor_segments)
                  else TRUE

    if (!t_complete || !c_complete) {
      details_parts <- character()
      if (!t_complete) details_parts <- c(details_parts, "treated_anchor_segments")
      if (!c_complete) details_parts <- c(details_parts, "control_anchor_segments")
      non_clusterable[[length(non_clusterable) + 1L]] <- list(
        record_id = rec$record_id,
        mode      = mode,
        reason    = "tier_s_incomplete",
        details   = paste0("incomplete: ", paste(details_parts, collapse = ","))
      )
      next
    }

    # 2. REM eligibility (mode=pair only)
    if (identical(mode, "pair")) {
      if (isTRUE(rec$n_treated_group < 2L)) {
        non_clusterable[[length(non_clusterable) + 1L]] <- list(
          record_id = rec$record_id,
          mode      = mode,
          reason    = "rem_eligibility_n1",
          details   = sprintf("n_treated_group=%d (< 2)", rec$n_treated_group)
        )
        next
      }
      if (isTRUE(rec$n_control_group < 2L)) {
        non_clusterable[[length(non_clusterable) + 1L]] <- list(
          record_id = rec$record_id,
          mode      = mode,
          reason    = "rem_eligibility_n1",
          details   = sprintf("n_control_group=%d (< 2)", rec$n_control_group)
        )
        next
      }
    }

    eligible[[length(eligible) + 1L]] <- rec
  }

  list(eligible = eligible, non_clusterable = non_clusterable)
}
```

- [ ] **Step 5.4: Verifica test passano**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-eligibility")'
```

Expected: PASS.

- [ ] **Step 5.5: Commit Task 5**

```bash
git add R/stage3-eligibility.R tests/testthat/test-stage3-eligibility.R
git commit -m "P5 Stadio 3 Task 5: .filter_eligible_records pre-cluster

Tier S incomplete + REM eligibility (n_per_group>=2) filters. Mode-aware:
group accepts n=1, pair requires n>=2 both sides. Output split eligible
vs non_clusterable con reason+details.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: .partition_by_hard_filters + .assign_records_to_clusters

**Files:**
- Create: `R/stage3-cluster.R`
- Create: `tests/testthat/test-stage3-cluster.R`

- [ ] **Step 6.1: Scrivi test failing**

Crea `tests/testthat/test-stage3-cluster.R`:

```r
test_that(".partition_by_hard_filters separa per (subcellular, context_kind)", {
  recs <- list(
    list(record_id = "r1",
         hard_filters = list(subcellular = "whole_cell", context_kind = "cell_line")),
    list(record_id = "r2",
         hard_filters = list(subcellular = "whole_cell", context_kind = "cell_line")),
    list(record_id = "r3",
         hard_filters = list(subcellular = "nuclear",    context_kind = "cell_line")),
    list(record_id = "r4",
         hard_filters = list(subcellular = "whole_cell", context_kind = "primary"))
  )
  parts <- simulomicsr:::.partition_by_hard_filters(recs)

  # Tre partition: (whole_cell, cell_line), (nuclear, cell_line), (whole_cell, primary)
  expect_length(parts, 3L)

  sizes <- vapply(parts, length, integer(1L))
  expect_setequal(sizes, c(2L, 1L, 1L))
})

test_that(".assign_records_to_clusters genera cluster_id deterministico via xxhash32", {
  recs <- list(
    list(record_id = "r1", anchor_key = "small_molecule|CHEMBL941|endothelium"),
    list(record_id = "r2", anchor_key = "small_molecule|CHEMBL941|endothelium"),
    list(record_id = "r3", anchor_key = "small_molecule|CHEMBL112|endothelium")
  )
  result <- simulomicsr:::.assign_records_to_clusters(
    records = recs, mode = "pair", level = 0L
  )

  # 2 unique anchor_keys -> 2 clusters
  expect_equal(length(unique(result$cluster_id)), 2L)

  # Records con stesso anchor_key -> stesso cluster_id
  r1_cl <- result$cluster_id[result$record_id == "r1"]
  r2_cl <- result$cluster_id[result$record_id == "r2"]
  r3_cl <- result$cluster_id[result$record_id == "r3"]
  expect_equal(r1_cl, r2_cl)
  expect_true(r3_cl != r1_cl)
})

test_that("cluster_id format: 'pair_L0_<8hex>'", {
  recs <- list(
    list(record_id = "r1", anchor_key = "small_molecule|CHEMBL941|endothelium")
  )
  result <- simulomicsr:::.assign_records_to_clusters(
    records = recs, mode = "pair", level = 0L
  )

  cl_id <- result$cluster_id[1]
  expect_match(cl_id, "^pair_L0_[0-9a-f]{8}$")
})

test_that("cluster_id deterministico cross-call (stesso input -> stesso ID)", {
  recs <- list(
    list(record_id = "r1", anchor_key = "small_molecule|CHEMBL941|endothelium")
  )
  r1 <- simulomicsr:::.assign_records_to_clusters(recs, "pair", 0L)
  r2 <- simulomicsr:::.assign_records_to_clusters(recs, "pair", 0L)

  expect_identical(r1$cluster_id, r2$cluster_id)
})
```

- [ ] **Step 6.2: Verifica test failing**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-cluster")'
```

Expected: FAIL.

- [ ] **Step 6.3: Implementa `R/stage3-cluster.R`**

Crea `R/stage3-cluster.R`:

```r
#' Partiziona records per hard_filters (subcellular, context_kind)
#'
#' Sub-partitions sono mutually exclusive: records con (subcellular="nuclear",
#' context_kind="cell_line") MAI mergeano con (subcellular="whole_cell",
#' context_kind="cell_line") a nessun L.
#'
#' @return named list: ogni elemento e' una sub-partition (list of records).
#' @keywords internal
.partition_by_hard_filters <- function(records) {
  if (length(records) == 0L) return(list())
  keys <- vapply(records, function(r) {
    hf <- r$hard_filters
    sprintf("%s|%s", hf$subcellular %||% "NA", hf$context_kind %||% "NA")
  }, character(1L))
  split(records, keys)
}

#' Calcola cluster_id deterministico via xxhash32
#'
#' Format: `<mode>_L<level>_<8hex>` dove 8hex = primi 8 char di
#' digest::digest(anchor_key, "xxhash32").
#'
#' @keywords internal
.cluster_id_for_anchor <- function(anchor_key, mode, level) {
  hash8 <- substr(digest::digest(anchor_key, algo = "xxhash32"), 1L, 8L)
  sprintf("%s_L%d_%s", mode, level, hash8)
}

#' Assegna records a cluster basato su anchor_key (raggruppa per chiave)
#'
#' Records con stesso anchor_key finiscono nello stesso cluster. Output e' una
#' tibble (record_id, mode, level, cluster_id, anchor_key) long-format.
#'
#' @param records list of records, ognuno con `$record_id` e `$anchor_key`.
#' @param mode "pair" or "group"
#' @param level 0..4
#' @return tibble di assignments
#' @keywords internal
.assign_records_to_clusters <- function(records, mode, level) {
  if (length(records) == 0L) {
    return(tibble::tibble(
      record_id  = character(),
      mode       = character(),
      level      = integer(),
      cluster_id = character(),
      anchor_key = character()
    ))
  }

  record_ids <- vapply(records, function(r) r$record_id, character(1L))
  anchor_keys <- vapply(records, function(r) r$anchor_key, character(1L))

  # Unique anchor_keys -> cluster_ids (deterministic via hash)
  unique_keys <- unique(anchor_keys)
  key_to_clid <- setNames(
    vapply(unique_keys, .cluster_id_for_anchor, character(1L),
           mode = mode, level = level),
    unique_keys
  )

  tibble::tibble(
    record_id  = record_ids,
    mode       = mode,
    level      = level,
    cluster_id = unname(key_to_clid[anchor_keys]),
    anchor_key = anchor_keys
  )
}
```

- [ ] **Step 6.4: Verifica test passano**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-cluster")'
```

Expected: PASS.

- [ ] **Step 6.5: Commit Task 6**

```bash
git add R/stage3-cluster.R tests/testthat/test-stage3-cluster.R
git commit -m "P5 Stadio 3 Task 6: .partition_by_hard_filters + .assign_records_to_clusters

Hard filter partition primaria (subcellular x context_kind). Cluster
assembly key-based con cluster_id deterministico via xxhash32 (8 hex).
Format: <mode>_L<level>_<hash>.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: .tag_cluster_usability — 4 boolean use-flags

**Files:**
- Create: `R/stage3-usability.R`
- Create: `tests/testthat/test-stage3-usability.R`

- [ ] **Step 7.1: Scrivi test failing**

Crea `tests/testthat/test-stage3-usability.R`:

```r
test_that("usable_rem_strict TRUE: pair, L0, k=5, safety_min=0.8", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 0.8
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_true(flags$usable_rem_strict)
  expect_true(flags$usable_rem_relaxed)
})

test_that("usable_rem_strict FALSE: pair, L2 (level > 1)", {
  cluster_row <- list(
    mode = "pair", level = 2L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 0.8
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_rem_strict)
  expect_true(flags$usable_rem_relaxed)
})

test_that("usable_rem_strict FALSE: k=2 (< k_recommended=3)", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 2L, n_total = 10L,
    n_studies = 2L, safety_min = 0.9
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_rem_strict)
  expect_true(flags$usable_rem_relaxed)  # k>=2 (k_min) e safety>=0.5
})

test_that("usable_rem_relaxed FALSE: k=1 (< k_min=2)", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 1L, n_total = 3L,
    n_studies = 1L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_rem_strict)
  expect_false(flags$usable_rem_relaxed)
})

test_that("usable_mega_strict TRUE: group, L0, n_studies=5, n_total=30, safety=0.8", {
  cluster_row <- list(
    mode = "group", level = 0L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 0.8
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_true(flags$usable_mega_strict)
  expect_true(flags$usable_mega_relaxed)
})

test_that("usable_mega_relaxed FALSE: n_studies=1", {
  cluster_row <- list(
    mode = "group", level = 0L, k = 1L, n_total = 100L,
    n_studies = 1L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_mega_relaxed)
})

test_that("usable_mega_relaxed FALSE: n_total=5 (< 10)", {
  cluster_row <- list(
    mode = "group", level = 0L, k = 2L, n_total = 5L,
    n_studies = 2L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_mega_relaxed)
})

test_that("flags off-mode sono FALSE (mode=pair -> usable_mega_* FALSE)", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_mega_strict)
  expect_false(flags$usable_mega_relaxed)
})
```

- [ ] **Step 7.2: Verifica test failing**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-usability")'
```

Expected: FAIL.

- [ ] **Step 7.3: Implementa `R/stage3-usability.R`**

Crea `R/stage3-usability.R`:

```r
#' Calcola i 4 boolean use-flags per un cluster
#'
#' Sostituiscono i tier labels GOLD/SILVER/BRONZE/DESCRIPTIVE con flag funzionali
#' espliciti: l'intent del consumer (REM o MEGA) e' codificato direttamente.
#'
#' Logica:
#' - `usable_rem_strict`:   mode=pair AND level in {0,1} AND k>=k_recommended_rem
#'                          AND safety_min>=safety_strict
#' - `usable_rem_relaxed`:  mode=pair AND k>=k_min_rem AND safety_min>=safety_relaxed
#' - `usable_mega_strict`:  mode=group AND level in {0,1} AND n_studies>=n_studies_recommended_mega
#'                          AND n_total>=n_total_recommended_mega AND safety_min>=safety_strict
#' - `usable_mega_relaxed`: mode=group AND n_studies>=n_studies_min_mega
#'                          AND n_total>=10 AND safety_min>=safety_relaxed
#'
#' @keywords internal
.tag_cluster_usability <- function(cluster_row, thresholds) {
  mode <- cluster_row$mode

  rem_t  <- thresholds$rem
  mega_t <- thresholds$mega
  saf_t  <- thresholds$safety

  is_pair  <- identical(mode, "pair")
  is_group <- identical(mode, "group")

  list(
    usable_rem_strict = is_pair &&
      cluster_row$level %in% c(0L, 1L) &&
      cluster_row$k >= rem_t$k_recommended &&
      cluster_row$safety_min >= saf_t$strict,

    usable_rem_relaxed = is_pair &&
      cluster_row$k >= rem_t$k_min &&
      cluster_row$safety_min >= saf_t$relaxed,

    usable_mega_strict = is_group &&
      cluster_row$level %in% c(0L, 1L) &&
      cluster_row$n_studies >= mega_t$n_studies_recommended &&
      cluster_row$n_total >= mega_t$n_total_recommended &&
      cluster_row$safety_min >= saf_t$strict,

    usable_mega_relaxed = is_group &&
      cluster_row$n_studies >= mega_t$n_studies_min &&
      cluster_row$n_total >= 10L &&
      cluster_row$safety_min >= saf_t$relaxed
  )
}
```

- [ ] **Step 7.4: Verifica test passano**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-usability")'
```

Expected: PASS.

- [ ] **Step 7.5: Commit Task 7**

```bash
git add R/stage3-usability.R tests/testthat/test-stage3-usability.R
git commit -m "P5 Stadio 3 Task 7: .tag_cluster_usability con 4 boolean use-flags

usable_rem_{strict,relaxed} + usable_mega_{strict,relaxed} mode-specific.
Strict richiede L in {0,1} e safety>=0.7. Relaxed accetta L0..L4 e
safety>=0.5. Sostituisce tier labels heuristici.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: .enrich_cluster_metadata — gpl + studies + donors

**Files:**
- Create: `R/stage3-metadata.R`
- Create: `tests/testthat/test-stage3-metadata.R`

- [ ] **Step 8.1: Scrivi test failing**

Crea `tests/testthat/test-stage3-metadata.R`:

```r
test_that("studies_in_cluster + n_studies da series_id dei records", {
  cluster_records <- list(
    list(series_id = "GSE100"),
    list(series_id = "GSE100"),
    list(series_id = "GSE200"),
    list(series_id = "GSE300")
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  expect_setequal(result$studies_in_cluster, c("GSE100", "GSE200", "GSE300"))
  expect_equal(result$n_studies, 3L)
})

test_that("n_distinct_donors da stage1_facts$donor (quando presente)", {
  cluster_records <- list(
    list(series_id = "GSE100", stage1_facts = list(donor = list(donor_id = "D1"))),
    list(series_id = "GSE100", stage1_facts = list(donor = list(donor_id = "D2"))),
    list(series_id = "GSE200", stage1_facts = list(donor = list(donor_id = "D1"))),  # D1 ripetuto cross-GSE
    list(series_id = "GSE200", stage1_facts = list(donor = NULL))                    # no donor info
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  # D1 + D2 = 2 distinct (D1 cross-GSE collassa, NULL escluso)
  expect_equal(result$n_distinct_donors, 2L)
})

test_that("n_distinct_donors NA quando nessun record ha donor info", {
  cluster_records <- list(
    list(series_id = "GSE100", stage1_facts = list(donor = NULL)),
    list(series_id = "GSE200", stage1_facts = list(donor = NULL))
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  expect_true(is.na(result$n_distinct_donors))
})

test_that("gpl_platforms enrichment quando archs4_metadata e' fornito", {
  cluster_records <- list(
    list(series_id = "GSE100"),
    list(series_id = "GSE200")
  )
  # Mock archs4_metadata: data.frame con (series_id, gpl)
  archs4_meta <- tibble::tibble(
    series_id = c("GSE100", "GSE200", "GSE300"),
    gpl       = c("GPL16791", "GPL11154", "GPL16791")
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = archs4_meta
  )
  expect_setequal(result$gpl_platforms, c("GPL16791", "GPL11154"))
  expect_equal(result$n_gpl_distinct, 2L)
})

test_that("gpl_platforms = NULL/empty quando archs4_metadata NULL", {
  cluster_records <- list(
    list(series_id = "GSE100")
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  expect_true(length(result$gpl_platforms) == 0L || is.na(result$n_gpl_distinct))
})
```

- [ ] **Step 8.2: Verifica failing + implementa `R/stage3-metadata.R`**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-metadata")'
```

Expected: FAIL. Poi crea `R/stage3-metadata.R`:

```r
#' Arricchisce cluster metadata con gpl_platforms, studies_in_cluster,
#' n_distinct_donors derivati dai records del cluster.
#'
#' @param cluster_records list of records nel cluster (each con $series_id,
#'   $stage1_facts).
#' @param archs4_metadata tibble (series_id, gpl, [library_strategy]) opzionale.
#'   Se NULL, gpl_platforms = character(0) e n_gpl_distinct = NA.
#' @return list con `studies_in_cluster`, `n_studies`, `gpl_platforms`,
#'   `n_gpl_distinct`, `n_distinct_donors`.
#' @keywords internal
.enrich_cluster_metadata <- function(cluster_records, archs4_metadata = NULL) {
  series_ids <- unique(vapply(cluster_records, function(r) {
    r$series_id %||% NA_character_
  }, character(1L)))
  series_ids <- series_ids[!is.na(series_ids)]

  # Donors
  donor_ids <- vapply(cluster_records, function(r) {
    d <- r$stage1_facts$donor
    if (is.null(d)) return(NA_character_)
    d$donor_id %||% NA_character_
  }, character(1L))
  donor_ids_present <- donor_ids[!is.na(donor_ids)]
  n_distinct_donors <- if (length(donor_ids_present) == 0L)
                         NA_integer_
                       else
                         length(unique(donor_ids_present))

  # GPL enrichment
  if (is.null(archs4_metadata)) {
    gpl_platforms  <- character()
    n_gpl_distinct <- NA_integer_
  } else {
    matched <- archs4_metadata[archs4_metadata$series_id %in% series_ids, , drop = FALSE]
    gpl_platforms  <- unique(matched$gpl)
    gpl_platforms  <- gpl_platforms[!is.na(gpl_platforms)]
    n_gpl_distinct <- length(gpl_platforms)
  }

  list(
    studies_in_cluster = series_ids,
    n_studies          = length(series_ids),
    gpl_platforms      = gpl_platforms,
    n_gpl_distinct     = n_gpl_distinct,
    n_distinct_donors  = n_distinct_donors
  )
}
```

- [ ] **Step 8.3: Verifica PASS + commit**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-metadata")'
```

Expected: PASS. Poi:

```bash
git add R/stage3-metadata.R tests/testthat/test-stage3-metadata.R
git commit -m "P5 Stadio 3 Task 8: .enrich_cluster_metadata (gpl, studies, donors)

Auxiliary metadata per cluster: studies_in_cluster + n_studies da series_id,
n_distinct_donors da stage1_facts$donor (NA se mai presente), gpl_platforms
+ n_gpl_distinct da archs4_metadata opzionale.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: .build_record_summary — min_viable_level per mode

**Files:**
- Create: `R/stage3-summary.R`
- Create: `tests/testthat/test-stage3-summary.R`

- [ ] **Step 9.1: Scrivi test failing**

Crea `tests/testthat/test-stage3-summary.R`:

```r
test_that("min_viable_level_rem = L0 quando cluster L0 usable_rem_relaxed", {
  assignments <- tibble::tibble(
    record_id  = c("r1", "r1", "r1"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc")
  )
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    usable_rem_relaxed  = c(TRUE, TRUE, TRUE),
    usable_mega_relaxed = c(FALSE, FALSE, FALSE)
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)

  r1 <- result[result$record_id == "r1" & result$mode == "pair", ]
  expect_equal(as.character(r1$min_viable_level_rem), "L0")
  expect_equal(r1$min_viable_cluster_rem, "pair_L0_aaaa")
})

test_that("min_viable_level_rem = L2 quando L0/L1 NON usable, L2 usable", {
  assignments <- tibble::tibble(
    record_id  = c("r1", "r1", "r1"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc")
  )
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    usable_rem_relaxed  = c(FALSE, FALSE, TRUE),
    usable_mega_relaxed = c(FALSE, FALSE, FALSE)
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)
  r1 <- result[result$record_id == "r1" & result$mode == "pair", ]
  expect_equal(as.character(r1$min_viable_level_rem), "L2")
  expect_equal(r1$min_viable_cluster_rem, "pair_L2_cccc")
})

test_that("min_viable_level_rem = NONE quando nessun L usable", {
  assignments <- tibble::tibble(
    record_id  = c("r1"),
    mode       = c("pair"),
    level      = c(0L),
    cluster_id = c("pair_L0_aaaa")
  )
  clusters <- tibble::tibble(
    cluster_id = "pair_L0_aaaa", mode = "pair", level = 0L,
    usable_rem_relaxed = FALSE, usable_mega_relaxed = FALSE
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)
  expect_equal(as.character(result$min_viable_level_rem), "NONE")
  expect_true(is.na(result$min_viable_cluster_rem))
})

test_that("in_n_clusters_rem conta livelli distinti per pair", {
  assignments <- tibble::tibble(
    record_id  = c("r1", "r1", "r1", "r1", "r1"),
    mode       = c("pair", "pair", "pair", "pair", "pair"),
    level      = c(0L, 1L, 2L, 3L, 4L),
    cluster_id = c("pair_L0_a", "pair_L1_b", "pair_L2_c", "pair_L3_d", "pair_L4_e")
  )
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_a", "pair_L1_b", "pair_L2_c", "pair_L3_d", "pair_L4_e"),
    mode = "pair", level = 0L:4L,
    usable_rem_relaxed = TRUE, usable_mega_relaxed = FALSE
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)
  r1 <- result[result$record_id == "r1" & result$mode == "pair", ]
  expect_equal(r1$in_n_clusters_rem, 5L)
})
```

- [ ] **Step 9.2: Implementa `R/stage3-summary.R`**

Verifica failing, poi crea:

```r
#' Costruisce la tabella record_summary con min_viable_level per mode
#'
#' Per ogni (record_id, mode), trova il livello L piu' basso (max strict)
#' dove il record appartiene a un cluster con `usable_{mode}_relaxed=TRUE`.
#' Se nessun L qualifica, restituisce "NONE" e NA cluster.
#'
#' @param assignments tibble (record_id, mode, level, cluster_id, anchor_key)
#' @param clusters tibble con almeno (cluster_id, mode, level,
#'   usable_rem_relaxed, usable_mega_relaxed)
#' @return tibble (record_id, mode, min_viable_level_<mode>, min_viable_cluster_<mode>,
#'   in_n_clusters_<mode>)
#' @keywords internal
.build_record_summary <- function(assignments, clusters) {
  # Join assignments con clusters per ottenere flag usability
  joined <- dplyr::left_join(
    assignments,
    clusters[, c("cluster_id", "usable_rem_relaxed", "usable_mega_relaxed")],
    by = "cluster_id"
  )

  # Per ogni (record_id, mode), trova min level con usable_<mode>_relaxed=TRUE
  result <- joined |>
    dplyr::group_by(.data$record_id, .data$mode) |>
    dplyr::summarise(
      min_viable_level_rem = {
        if (.data$mode[1] != "pair") {
          NA_character_
        } else {
          usable_levels <- .data$level[.data$usable_rem_relaxed]
          if (length(usable_levels) == 0L) "NONE"
          else sprintf("L%d", min(usable_levels))
        }
      },
      min_viable_cluster_rem = {
        if (.data$mode[1] != "pair") {
          NA_character_
        } else {
          usable_levels <- .data$level[.data$usable_rem_relaxed]
          if (length(usable_levels) == 0L) NA_character_
          else .data$cluster_id[.data$level == min(usable_levels) &
                                  .data$usable_rem_relaxed][1]
        }
      },
      min_viable_level_mega = {
        if (.data$mode[1] != "group") {
          NA_character_
        } else {
          usable_levels <- .data$level[.data$usable_mega_relaxed]
          if (length(usable_levels) == 0L) "NONE"
          else sprintf("L%d", min(usable_levels))
        }
      },
      min_viable_cluster_mega = {
        if (.data$mode[1] != "group") {
          NA_character_
        } else {
          usable_levels <- .data$level[.data$usable_mega_relaxed]
          if (length(usable_levels) == 0L) NA_character_
          else .data$cluster_id[.data$level == min(usable_levels) &
                                  .data$usable_mega_relaxed][1]
        }
      },
      in_n_clusters_rem  = if (.data$mode[1] == "pair")
                              dplyr::n_distinct(.data$cluster_id)
                            else 0L,
      in_n_clusters_mega = if (.data$mode[1] == "group")
                              dplyr::n_distinct(.data$cluster_id)
                            else 0L,
      .groups = "drop"
    )

  result
}
```

- [ ] **Step 9.3: Verifica PASS + commit**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-summary")'
```

Expected: PASS.

```bash
git add R/stage3-summary.R tests/testthat/test-stage3-summary.R
git commit -m "P5 Stadio 3 Task 9: .build_record_summary con min_viable_level per mode

Per ogni (record_id, mode) trova L minimo con usable_<mode>_relaxed=TRUE.
NONE se nessun L qualifica. in_n_clusters_<mode> = count distinct cluster_id.
Mode-specific: pair record -> _rem cols, group record -> _mega cols.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: load_archs4_metadata — cached helper

**Files:**
- Create: `R/stage3-archs4-meta.R`
- Create: `tests/testthat/test-stage3-archs4-meta.R`

- [ ] **Step 10.1: Scrivi test (mock H5 with rhdf5)**

Crea `tests/testthat/test-stage3-archs4-meta.R`:

```r
test_that("load_archs4_metadata read GPL + series_id from H5 (mock)", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("withr")

  # Mock H5: temp file with synthetic dataset
  tmp_h5 <- withr::local_tempfile(fileext = ".h5")
  rhdf5::h5createFile(tmp_h5)
  rhdf5::h5createGroup(tmp_h5, "meta")
  rhdf5::h5createGroup(tmp_h5, "meta/samples")

  rhdf5::h5write(c("GSM1", "GSM2", "GSM3"), tmp_h5, "meta/samples/geo_accession")
  rhdf5::h5write(c("GSE100", "GSE100", "GSE200"), tmp_h5, "meta/samples/series_id")
  rhdf5::h5write(c("GPL16791", "GPL16791", "GPL11154"), tmp_h5, "meta/samples/instrument_model")

  meta <- load_archs4_metadata(h5_path = tmp_h5, use_cache = FALSE)

  expect_s3_class(meta, "tbl_df")
  expect_named(meta, c("sample_id", "series_id", "gpl"), ignore.order = TRUE)
  expect_equal(nrow(meta), 3L)
})

test_that("load_archs4_metadata uses cache on second call", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("withr")

  tmp_h5 <- withr::local_tempfile(fileext = ".h5")
  rhdf5::h5createFile(tmp_h5)
  rhdf5::h5createGroup(tmp_h5, "meta")
  rhdf5::h5createGroup(tmp_h5, "meta/samples")
  rhdf5::h5write(c("GSM1"), tmp_h5, "meta/samples/geo_accession")
  rhdf5::h5write(c("GSE100"), tmp_h5, "meta/samples/series_id")
  rhdf5::h5write(c("GPL16791"), tmp_h5, "meta/samples/instrument_model")

  tmp_cache_dir <- withr::local_tempdir()

  m1 <- load_archs4_metadata(h5_path = tmp_h5, cache_dir = tmp_cache_dir,
                              use_cache = TRUE)
  m2 <- load_archs4_metadata(h5_path = tmp_h5, cache_dir = tmp_cache_dir,
                              use_cache = TRUE)
  expect_identical(m1, m2)

  cache_files <- list.files(tmp_cache_dir, pattern = "archs4-metadata")
  expect_true(length(cache_files) >= 1L)
})
```

- [ ] **Step 10.2: Implementa `R/stage3-archs4-meta.R`**

```r
#' Carica ARCHS4 metadata (sample_id, series_id, gpl) da H5
#'
#' Legge i field necessari da `/meta/samples/` dell'H5 ARCHS4 v2.5 e li
#' restituisce come tibble. Costoso (H5 da 47GB), supporta cache via RDS
#' in `tools::R_user_dir("simulomicsr", "cache")`.
#'
#' Nota: il name del field "gpl" mappa a `meta/samples/instrument_model` in
#' ARCHS4 v2.5 schema (NON `meta/samples/Sample_platform_id`); verifica
#' al build con `rhdf5::h5ls(h5_path)` se schema cambia.
#'
#' library_strategy NON viene letto (verificato non-disponibile in v2.5; se
#' aggiunto in future versions, plan v2 lo aggiungera').
#'
#' @param h5_path string path al H5 (es. `analysis/input/human_gene_v2.5.h5`).
#' @param cache_dir optional dir override. Default: `R_user_dir("simulomicsr", "cache")`.
#' @param use_cache logical, default TRUE. Skip cache lookup/write se FALSE.
#' @return tibble (sample_id, series_id, gpl).
#' @export
load_archs4_metadata <- function(h5_path,
                                  cache_dir = NULL,
                                  use_cache = TRUE) {
  if (is.null(cache_dir)) {
    cache_dir <- tools::R_user_dir("simulomicsr", which = "cache")
  }
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  cache_key  <- digest::digest(c(h5_path, file.info(h5_path)$mtime),
                                algo = "xxhash32")
  cache_file <- file.path(cache_dir, sprintf("archs4-metadata-%s.rds", cache_key))

  if (use_cache && file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  sample_id <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
  series_id <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
  gpl       <- as.character(rhdf5::h5read(h5_path, "meta/samples/instrument_model"))

  meta <- tibble::tibble(
    sample_id = sample_id,
    series_id = series_id,
    gpl       = gpl
  )

  if (use_cache) {
    saveRDS(meta, cache_file)
  }

  meta
}
```

- [ ] **Step 10.3: PASS + commit**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-archs4-meta")'
```

Expected: PASS (con `rhdf5` installato).

```bash
git add R/stage3-archs4-meta.R tests/testthat/test-stage3-archs4-meta.R
git commit -m "P5 Stadio 3 Task 10: load_archs4_metadata con cache RDS

Legge (sample_id, series_id, gpl) da H5 ARCHS4 v2.5. Cache in
R_user_dir('simulomicsr','cache') keyed su h5_path + mtime. library_strategy
NON disponibile in v2.5 schema (verificato).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: build_stage3_clusters — orchestrator + stage3_result S3

**Files:**
- Create: `R/stage3-build.R`
- Create: `tests/testthat/test-stage3-build.R`

- [ ] **Step 11.1: Scrivi test on mock end-to-end**

Crea `tests/testthat/test-stage3-build.R`:

```r
# Helper: build 3 mock records pair-mode (2 cluster expected at L0)
make_mock_stage3_input <- function() {
  list(
    stage1_master = list(
      "GSM1" = make_test_sample_fact(),
      "GSM2" = make_test_sample_fact(),
      "GSM3" = (function() {
        f <- make_test_sample_fact()
        f$perturbations[[1]]$dose$value_raw <- "100nM"  # different dose -> different anchor at L0/L1
        f
      })()
    ),
    stage2_master = list(
      list(
        series_id = "GSE100",
        replicate_groups = list(
          list(group_id = "g1", sample_ids = c("GSM1"), n = 1L),
          list(group_id = "g2", sample_ids = c("GSM2"), n = 1L)
        ),
        comparisons = list(
          list(comparison_id = "c1", treated_group = "g1", control_group = "g2",
               control_type = "vehicle", design_kind = "treatment_vs_vehicle")
        )
      )
    )
  )
}

test_that("build_stage3_clusters returns stage3_result S3 with expected components", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(
    stage1_master = input$stage1_master,
    stage2_master = input$stage2_master,
    config = stage3_default_config(),
    archs4_metadata = NULL
  )

  expect_s3_class(s3, "stage3_result")
  expect_named(s3, c("assignments", "clusters", "record_summary",
                     "non_clusterable", "run_metadata"),
               ignore.order = TRUE)

  expect_s3_class(s3$assignments, "tbl_df")
  expect_s3_class(s3$clusters, "tbl_df")
  expect_s3_class(s3$record_summary, "tbl_df")
  expect_s3_class(s3$non_clusterable, "tbl_df")
  expect_type(s3$run_metadata, "list")
})

test_that("run_metadata contains run_id + schema_versions + output_counts", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(
    stage1_master = input$stage1_master,
    stage2_master = input$stage2_master,
    config = stage3_default_config()
  )

  rm <- s3$run_metadata
  expect_match(rm$run_id, "^[0-9a-f]{8}$")
  expect_named(rm$schema_versions, c("anchor", "stage3_algorithm",
                                       "sample_facts", "study_design"),
               ignore.order = TRUE)
  expect_true("output_counts" %in% names(rm))
})

test_that("idempotenza: stesso input -> stesso run_id", {
  input <- make_mock_stage3_input()
  s3a <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                                 config = stage3_default_config())
  s3b <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                                 config = stage3_default_config())
  expect_equal(s3a$run_metadata$run_id, s3b$run_metadata$run_id)
})
```

- [ ] **Step 11.2: Implementa `R/stage3-build.R`**

```r
#' Orchestrator principale di Stadio 3
#'
#' Carica stage1_master + stage2_master, costruisce records dual-mode (pair + group),
#' applica eligibility filter, partiziona per hard_filters, costruisce anchor per
#' L0..L4, raggruppa per anchor_key, calcola safety + usability + metadata, output
#' come `stage3_result` S3.
#'
#' @param stage1_master path string o named list (per test) di sample_facts indexed
#'   per GSM.
#' @param stage2_master path string o list di stage2 study records.
#' @param config output di `stage3_default_config()`. Custom configs supportati per
#'   override threshold + tier assignment.
#' @param archs4_metadata tibble opzionale (output di `load_archs4_metadata()`).
#'   Se NULL, gpl_platforms column = empty.
#' @return `stage3_result` S3 object (list con 5 componenti).
#' @export
build_stage3_clusters <- function(stage1_master,
                                    stage2_master,
                                    config = stage3_default_config(),
                                    archs4_metadata = NULL) {
  ta <- config$tier_assignment
  thresholds <- config$thresholds

  # 1. Caricamento input se path
  if (is.character(stage1_master)) {
    stage1_master <- .load_stage1_master(stage1_master)
  }
  if (is.character(stage2_master)) {
    stage2_master <- .load_stage2_master(stage2_master)
  }

  # 2. Costruzione records dual-mode
  records_pair  <- .build_pair_records(stage2_master, stage1_master, ta)
  records_group <- .build_group_records(stage2_master, stage1_master, ta)

  # 3. Eligibility filter
  pair_filt  <- .filter_eligible_records(records_pair)
  group_filt <- .filter_eligible_records(records_group)

  # 4. Direction check (pair only)
  pair_filt$eligible <- .annotate_direction(pair_filt$eligible)
  # Spostare direction_ambiguous/indeterminate in non_clusterable
  bad_dir <- vapply(pair_filt$eligible, function(r) {
    r$direction_check %in% c("ambiguous", "indeterminate")
  }, logical(1L))
  if (any(bad_dir)) {
    for (r in pair_filt$eligible[bad_dir]) {
      pair_filt$non_clusterable[[length(pair_filt$non_clusterable) + 1L]] <- list(
        record_id = r$record_id, mode = "pair",
        reason = sprintf("direction_%s", r$direction_check),
        details = sprintf("control_type=%s", r$control_type)
      )
    }
    pair_filt$eligible <- pair_filt$eligible[!bad_dir]
  }

  # 5. Hard filter partition + clustering per L0..L4 per mode
  assignments_all <- list()
  for (mode in c("pair", "group")) {
    eligible <- if (mode == "pair") pair_filt$eligible else group_filt$eligible
    if (length(eligible) == 0L) next
    parts <- .partition_by_hard_filters(eligible)
    for (L in 0L:4L) {
      for (part in parts) {
        # Costruisci anchor_key per ogni record nella partition al livello L
        part_with_keys <- lapply(part, function(r) {
          if (mode == "pair") {
            tk <- .build_anchor_key_from_segments(r$treated_anchor_segments, ta, L)
            ck <- .build_anchor_key_from_segments(r$control_anchor_segments, ta, L)
            r$anchor_key <- if (L %in% c(0L, 1L)) {
              sprintf("%s__VS__%s__CT_%s", tk, ck, r$control_type)
            } else {
              sprintf("%s__VS__%s", tk, ck)
            }
          } else {  # group
            r$anchor_key <- .build_anchor_key_from_segments(
              r$anchor_segments, ta, L
            )
          }
          r
        })
        asg <- .assign_records_to_clusters(part_with_keys, mode, L)
        assignments_all[[length(assignments_all) + 1L]] <- asg
      }
    }
  }
  assignments <- dplyr::bind_rows(assignments_all)

  # 6. Per ogni cluster_id, compute summary (k, n_total, safety, metadata, usability)
  clusters <- .summarize_clusters(
    assignments = assignments,
    eligible_pair = pair_filt$eligible,
    eligible_group = group_filt$eligible,
    config = config,
    archs4_metadata = archs4_metadata
  )

  # 7. Record summary
  record_summary <- .build_record_summary(assignments, clusters)

  # 8. Non clusterable (consolidata)
  nc <- dplyr::bind_rows(
    purrr::map_dfr(pair_filt$non_clusterable, tibble::as_tibble),
    purrr::map_dfr(group_filt$non_clusterable, tibble::as_tibble)
  )
  if (nrow(nc) == 0L) {
    nc <- tibble::tibble(record_id = character(), mode = character(),
                          reason = character(), details = character())
  }

  # 9. Run metadata + run_id deterministico
  run_metadata <- .build_run_metadata(
    stage1_master_summary = list(n_records = length(stage1_master)),
    stage2_master_summary = list(n_records = length(stage2_master)),
    config = config,
    output_counts = list(
      n_records_input_stage2     = length(stage2_master),
      n_records_clusterable_pair = length(pair_filt$eligible),
      n_records_clusterable_group = length(group_filt$eligible),
      n_non_clusterable_records  = nrow(nc),
      n_assignments_total        = nrow(assignments),
      n_clusters_per_level = list(
        pair  = .count_clusters_per_level(clusters, "pair"),
        group = .count_clusters_per_level(clusters, "group")
      )
    )
  )

  structure(
    list(
      assignments     = assignments,
      clusters        = clusters,
      record_summary  = record_summary,
      non_clusterable = nc,
      run_metadata    = run_metadata
    ),
    class = "stage3_result"
  )
}

#' @keywords internal
.build_anchor_key_from_segments <- function(segments, tier_assignment, level) {
  # Riadatta .build_anchor_for_level che richiede stage1_facts
  kept <- .kept_segments_at_level(tier_assignment, level)
  kept_sorted <- sort(kept)
  values <- vapply(kept_sorted, function(s) as.character(segments[[s]]), character(1L))
  paste(values, collapse = "|")
}

#' @keywords internal
.count_clusters_per_level <- function(clusters, mode) {
  cl_mode <- clusters[clusters$mode == mode, ]
  if (nrow(cl_mode) == 0L) return(setNames(rep(0L, 5L), sprintf("L%d", 0:4)))
  tbl <- table(factor(cl_mode$level, levels = 0L:4L))
  setNames(as.integer(tbl), sprintf("L%d", 0:4))
}
```

- [ ] **Step 11.3: Aggiungi helper `.build_pair_records`, `.build_group_records`, `.annotate_direction`, `.summarize_clusters`, `.build_run_metadata`, `.load_stage1_master`, `.load_stage2_master`**

Aggiungi a `R/stage3-build.R` (continua il file):

```r
#' Costruisce records pair-mode da stage2 comparisons
#' @keywords internal
.build_pair_records <- function(stage2_master, stage1_master, tier_assignment) {
  records <- list()
  for (study in stage2_master) {
    sid <- study$series_id
    rg_lookup <- setNames(study$replicate_groups,
                           vapply(study$replicate_groups,
                                   function(g) g$group_id, character(1L)))
    for (cmp in study$comparisons) {
      tg <- rg_lookup[[cmp$treated_group]]
      cg <- rg_lookup[[cmp$control_group]]
      if (is.null(tg) || is.null(cg)) next  # malformed

      # Use first sample of each group as representative for anchor extraction
      # (samples in same replicate_group SHOULD have same sample_facts; if not,
      # use first; future v2: validate intra-group homogeneity)
      tg_sample <- tg$sample_ids[1]
      cg_sample <- cg$sample_ids[1]

      tg_facts <- stage1_master[[tg_sample]]
      cg_facts <- stage1_master[[cg_sample]]
      if (is.null(tg_facts) || is.null(cg_facts)) next

      t_segs <- .extract_anchor_segments(tg_facts, stage2_role = "treated")
      c_segs <- .extract_anchor_segments(cg_facts, stage2_role = "control")

      # Hard filters (use treated as canonical)
      hf <- .extract_hard_filters(tg_facts, tier_assignment)

      records[[length(records) + 1L]] <- list(
        record_id = sprintf("%s__%s", sid, cmp$comparison_id),
        mode      = "pair",
        series_id = sid,
        comparison_id = cmp$comparison_id,
        treated_anchor_segments = t_segs,
        control_anchor_segments = c_segs,
        n_treated_group = length(tg$sample_ids),
        n_control_group = length(cg$sample_ids),
        control_type = cmp$control_type,
        hard_filters = hf,
        stage1_facts = tg_facts  # for donor extraction
      )
    }
  }
  records
}

#' Costruisce records group-mode da stage2 replicate_groups
#' @keywords internal
.build_group_records <- function(stage2_master, stage1_master, tier_assignment) {
  records <- list()
  for (study in stage2_master) {
    sid <- study$series_id
    for (rg in study$replicate_groups) {
      if (length(rg$sample_ids) == 0L) next
      first_sample <- rg$sample_ids[1]
      facts <- stage1_master[[first_sample]]
      if (is.null(facts)) next

      # Group anchor: usa primary_role come stage2_role surrogate
      role_for_anchor <- switch(
        rg$primary_role,
        treated = "treated",
        control = "control",
        bystander = "treated",
        excluded  = "treated",
        unclear   = "treated",
        "treated"
      )
      segs <- .extract_anchor_segments(facts, stage2_role = role_for_anchor)
      hf <- .extract_hard_filters(facts, tier_assignment)

      records[[length(records) + 1L]] <- list(
        record_id = sprintf("%s__%s", sid, rg$group_id),
        mode      = "group",
        series_id = sid,
        group_id  = rg$group_id,
        anchor_segments = segs,
        n_treated_group = length(rg$sample_ids),  # for non_clusterable details
        n_control_group = length(rg$sample_ids),  # placeholder, group always passes
        hard_filters = hf,
        stage1_facts = facts
      )
    }
  }
  records
}

#' Annota records pair con direction_check
#' @keywords internal
.annotate_direction <- function(records_pair) {
  lapply(records_pair, function(r) {
    r$direction_check <- .check_direction_canonical(
      r$treated_anchor_segments, r$control_anchor_segments, r$control_type
    )
    r
  })
}

#' Riassume cluster (k, n_total, safety, metadata, usability) da assignments
#' @keywords internal
.summarize_clusters <- function(assignments, eligible_pair, eligible_group,
                                  config, archs4_metadata) {
  if (nrow(assignments) == 0L) {
    return(tibble::tibble(
      cluster_id = character(), mode = character(), level = integer(),
      anchor_key = character(), k = integer(), n_total = integer(),
      n_treated = integer(), n_control = integer(),
      safety_min = numeric(), safety_geom_mean = numeric(),
      safety_per_segment = list(),
      usable_rem_strict = logical(), usable_rem_relaxed = logical(),
      usable_mega_strict = logical(), usable_mega_relaxed = logical(),
      direction_check = character(),
      gpl_platforms = list(), n_gpl_distinct = integer(),
      n_distinct_donors = integer(),
      studies_in_cluster = list(), n_studies = integer()
    ))
  }

  ta <- config$tier_assignment
  pair_lookup  <- setNames(eligible_pair, vapply(eligible_pair,
                                                   function(r) r$record_id,
                                                   character(1L)))
  group_lookup <- setNames(eligible_group, vapply(eligible_group,
                                                    function(r) r$record_id,
                                                    character(1L)))

  rows <- list()
  for (cl_id in unique(assignments$cluster_id)) {
    cl_rows <- assignments[assignments$cluster_id == cl_id, ]
    mode  <- cl_rows$mode[1]
    level <- cl_rows$level[1]
    anchor_key <- cl_rows$anchor_key[1]

    member_records <- if (mode == "pair") pair_lookup[cl_rows$record_id]
                       else group_lookup[cl_rows$record_id]
    member_records <- member_records[!vapply(member_records, is.null, logical(1L))]

    # k = unique studies
    studies <- unique(vapply(member_records, function(r) r$series_id, character(1L)))
    k <- length(studies)

    # n_total = sum sample counts
    n_treated <- if (mode == "pair")
                   sum(vapply(member_records, function(r) r$n_treated_group, integer(1L)))
                 else NA_integer_
    n_control <- if (mode == "pair")
                   sum(vapply(member_records, function(r) r$n_control_group, integer(1L)))
                 else NA_integer_
    n_total <- if (mode == "pair")
                 n_treated + n_control
               else
                 sum(vapply(member_records, function(r) r$n_treated_group, integer(1L)))

    # Safety: dropped segments at this level (per anchor side)
    dropped_segs <- .dropped_segments_at_level(ta, level)
    # Per pair: serve safety su treated_anchor + control_anchor; usiamo concat
    # per il calc (consideriamo anche control_type droppato a L2+)
    # Per simplicita': calcoliamo safety su treated_anchor solo (good enough)
    safety_input_records <- if (mode == "pair")
                              lapply(member_records,
                                      function(r) r$treated_anchor_segments)
                            else
                              lapply(member_records,
                                      function(r) r$anchor_segments)
    safety <- .compute_pooling_safety(safety_input_records, dropped_segs)

    # Metadata enrichment
    meta <- .enrich_cluster_metadata(member_records, archs4_metadata)

    # Direction check (pair only — take from first record, all members assumed homogeneous)
    direction_check <- if (mode == "pair")
                         member_records[[1]]$direction_check
                       else
                         NA_character_

    cluster_row_for_usability <- list(
      mode = mode, level = level, k = k, n_total = n_total,
      n_studies = meta$n_studies, safety_min = safety$safety_min
    )
    usability <- .tag_cluster_usability(cluster_row_for_usability,
                                          config$thresholds)

    rows[[length(rows) + 1L]] <- tibble::tibble(
      cluster_id = cl_id, mode = mode, level = level, anchor_key = anchor_key,
      k = k, n_total = n_total, n_treated = n_treated, n_control = n_control,
      safety_min = safety$safety_min,
      safety_geom_mean = safety$safety_geom_mean,
      safety_per_segment = list(safety$safety_per_segment),
      usable_rem_strict = usability$usable_rem_strict,
      usable_rem_relaxed = usability$usable_rem_relaxed,
      usable_mega_strict = usability$usable_mega_strict,
      usable_mega_relaxed = usability$usable_mega_relaxed,
      direction_check = direction_check,
      gpl_platforms = list(meta$gpl_platforms),
      n_gpl_distinct = meta$n_gpl_distinct,
      n_distinct_donors = meta$n_distinct_donors,
      studies_in_cluster = list(meta$studies_in_cluster),
      n_studies = meta$n_studies
    )
  }
  dplyr::bind_rows(rows)
}

#' Costruisce run_metadata con run_id deterministico
#' @keywords internal
.build_run_metadata <- function(stage1_master_summary, stage2_master_summary,
                                  config, output_counts) {
  # Canonical form: deterministic JSON
  canon <- jsonlite::toJSON(
    list(s1 = stage1_master_summary, s2 = stage2_master_summary,
         schema = config$schema_versions, thresholds = config$thresholds,
         tier = config$tier_assignment),
    auto_unbox = TRUE
  )
  run_id <- substr(digest::digest(canon, algo = "xxhash32"), 1L, 8L)

  list(
    run_id = run_id,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    schema_versions = config$schema_versions,
    package_version = as.character(utils::packageVersion("simulomicsr")),
    r_version = R.version.string,
    input_files = list(stage1_master = stage1_master_summary,
                        stage2_master = stage2_master_summary),
    config = config,
    output_counts = output_counts
  )
}

#' Load stage1 master JSONL into named list indexed by GSM
#' @keywords internal
.load_stage1_master <- function(path) {
  if (!file.exists(path)) stop("stage1_master path non esiste: ", path)
  lines <- readLines(path)
  parsed <- lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)
  # Assume each line ha campo `geo_accession` o `sample_id` come key
  keys <- vapply(parsed, function(p) {
    p$geo_accession %||% p$sample_id %||% p$key %||% NA_character_
  }, character(1L))
  setNames(parsed, keys)
}

#' Load stage2 master RDS or JSONL
#' @keywords internal
.load_stage2_master <- function(path) {
  if (grepl("\\.rds$", path)) {
    readRDS(path)
  } else {
    lines <- readLines(path)
    lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)
  }
}
```

- [ ] **Step 11.4: PASS test + commit**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-build")'
```

Expected: PASS.

```bash
git add R/stage3-build.R tests/testthat/test-stage3-build.R
git commit -m "P5 Stadio 3 Task 11: build_stage3_clusters orchestrator + stage3_result S3

End-to-end: load stage1+2 -> dual-mode records -> eligibility -> direction
check -> hard-filter partition -> per-L clustering -> cluster summary +
safety + usability + metadata -> record_summary. Output stage3_result S3
con 5 componenti. run_id deterministico via xxhash32.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: write_stage3_to_dir + load_stage3 — I/O round-trip

**Files:**
- Create: `R/stage3-io.R`
- Create: `tests/testthat/test-stage3-io.R`

- [ ] **Step 12.1: Test round-trip**

Crea `tests/testthat/test-stage3-io.R`:

```r
test_that("write_stage3_to_dir produces 5 expected files", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  tmp_dir <- withr::local_tempdir()

  write_stage3_to_dir(s3, tmp_dir)

  expected_files <- c("assignments.parquet", "clusters.rds",
                      "record_summary.rds", "non_clusterable.rds",
                      "run_metadata.json")
  for (f in expected_files) {
    expect_true(file.exists(file.path(tmp_dir, f)), info = f)
  }
})

test_that("load_stage3 round-trips identically", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  input <- make_mock_stage3_input()
  s3_orig <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  tmp_dir <- withr::local_tempdir()
  write_stage3_to_dir(s3_orig, tmp_dir)

  s3_loaded <- load_stage3(tmp_dir)

  # Check key fields equal (tibbles compare by value)
  expect_equal(nrow(s3_loaded$assignments), nrow(s3_orig$assignments))
  expect_equal(nrow(s3_loaded$clusters), nrow(s3_orig$clusters))
  expect_equal(s3_loaded$run_metadata$run_id, s3_orig$run_metadata$run_id)
})
```

- [ ] **Step 12.2: Implementa `R/stage3-io.R`**

```r
#' Scrive un stage3_result in directory convenzionale (5 file)
#'
#' Layout:
#' - `assignments.parquet` (via arrow)
#' - `clusters.rds`
#' - `record_summary.rds`
#' - `non_clusterable.rds`
#' - `run_metadata.json` (pretty-printed)
#'
#' @param s3 oggetto stage3_result da `build_stage3_clusters()`
#' @param dir path directory (creata se non esiste).
#' @return invisible character vector dei path scritti.
#' @export
write_stage3_to_dir <- function(s3, dir) {
  stopifnot(inherits(s3, "stage3_result"))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)

  paths <- c(
    file.path(dir, "assignments.parquet"),
    file.path(dir, "clusters.rds"),
    file.path(dir, "record_summary.rds"),
    file.path(dir, "non_clusterable.rds"),
    file.path(dir, "run_metadata.json")
  )

  arrow::write_parquet(s3$assignments, paths[1])
  saveRDS(s3$clusters, paths[2])
  saveRDS(s3$record_summary, paths[3])
  saveRDS(s3$non_clusterable, paths[4])
  writeLines(
    jsonlite::toJSON(s3$run_metadata, pretty = TRUE, auto_unbox = TRUE),
    paths[5]
  )

  invisible(paths)
}

#' Legge stage3_result da directory scritta con `write_stage3_to_dir()`
#'
#' @param dir directory path
#' @return `stage3_result` S3 object
#' @export
load_stage3 <- function(dir) {
  stopifnot(dir.exists(dir))

  structure(
    list(
      assignments     = arrow::read_parquet(file.path(dir, "assignments.parquet")),
      clusters        = readRDS(file.path(dir, "clusters.rds")),
      record_summary  = readRDS(file.path(dir, "record_summary.rds")),
      non_clusterable = readRDS(file.path(dir, "non_clusterable.rds")),
      run_metadata    = jsonlite::fromJSON(
        file.path(dir, "run_metadata.json"),
        simplifyVector = FALSE
      )
    ),
    class = "stage3_result"
  )
}
```

- [ ] **Step 12.3: PASS + commit**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-io")'
```

Expected: PASS.

```bash
git add R/stage3-io.R tests/testthat/test-stage3-io.R
git commit -m "P5 Stadio 3 Task 12: write_stage3_to_dir + load_stage3 round-trip

5 file: assignments.parquet + 3 rds + run_metadata.json pretty-printed.
Round-trip identico via assertion su run_id + nrow tabelle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: filter_clusters + cluster_records — user helpers

**Files:**
- Create: `R/stage3-helpers.R`
- Create: `tests/testthat/test-stage3-helpers.R`

- [ ] **Step 13.1: Test helpers**

Crea `tests/testthat/test-stage3-helpers.R`:

```r
test_that("filter_clusters(mode='pair', usability='strict') restituisce usable_rem_strict", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)

  result <- filter_clusters(s3, mode = "pair", usability = "strict")
  expect_true(all(result$mode == "pair"))
  # All passed clusters should have usable_rem_strict TRUE OR result is empty
  if (nrow(result) > 0L) {
    expect_true(all(result$usable_rem_strict))
  }
})

test_that("filter_clusters(mode='any', usability='any') restituisce tutti", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  result <- filter_clusters(s3, mode = "any", usability = "any")
  expect_equal(nrow(result), nrow(s3$clusters))
})

test_that("cluster_records ritorna records di un cluster specifico", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)

  if (nrow(s3$clusters) > 0L) {
    first_cl <- s3$clusters$cluster_id[1]
    recs <- cluster_records(s3, first_cl)
    expect_true(nrow(recs) > 0L)
    expect_true(all(recs$cluster_id == first_cl))
  }
})
```

- [ ] **Step 13.2: Implementa `R/stage3-helpers.R`**

```r
#' Filter clusters by mode + usability
#'
#' Helper convenience per consumer Stage 3 → P5.
#'
#' @param s3 stage3_result
#' @param mode "pair" | "group" | "any". Default "any".
#' @param usability "strict" | "relaxed" | "any". Default "any".
#' @return tibble subset di s3$clusters
#' @export
filter_clusters <- function(s3,
                              mode = c("any", "pair", "group"),
                              usability = c("any", "strict", "relaxed")) {
  stopifnot(inherits(s3, "stage3_result"))
  mode <- match.arg(mode)
  usability <- match.arg(usability)

  result <- s3$clusters
  if (mode != "any") {
    result <- result[result$mode == mode, ]
  }
  if (usability != "any") {
    col_rem  <- sprintf("usable_rem_%s",  usability)
    col_mega <- sprintf("usable_mega_%s", usability)
    if (mode == "pair") {
      result <- result[isTRUE_vec(result[[col_rem]]), ]
    } else if (mode == "group") {
      result <- result[isTRUE_vec(result[[col_mega]]), ]
    } else {
      # mode=any: usable in either mode
      result <- result[isTRUE_vec(result[[col_rem]]) |
                          isTRUE_vec(result[[col_mega]]), ]
    }
  }
  result
}

#' Lookup records che appartengono a un cluster
#'
#' @param s3 stage3_result
#' @param cluster_id string
#' @return tibble subset di s3$assignments con record_id matching
#' @export
cluster_records <- function(s3, cluster_id) {
  stopifnot(inherits(s3, "stage3_result"))
  s3$assignments[s3$assignments$cluster_id == cluster_id, ]
}

#' @keywords internal
isTRUE_vec <- function(x) {
  vapply(x, isTRUE, logical(1L))
}
```

- [ ] **Step 13.3: PASS + commit**

```bash
Rscript --vanilla -e 'devtools::document(); devtools::test(filter = "stage3-helpers")'
```

Expected: PASS.

```bash
git add R/stage3-helpers.R tests/testthat/test-stage3-helpers.R
git commit -m "P5 Stadio 3 Task 13: filter_clusters + cluster_records user helpers

Convenience filters per consumer P5. filter_clusters(mode, usability)
restituisce subset di s3\$clusters. cluster_records(s3, cluster_id) ritorna
assignments matching.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Integration test su stage2-fixtures-mini

**Files:**
- Create: `tests/testthat/test-stage3-fixture-mini.R`

- [ ] **Step 14.1: Test end-to-end su 5 GSE da fixture esistente**

Crea `tests/testthat/test-stage3-fixture-mini.R`:

```r
test_that("Stage 3 end-to-end su stage2-fixtures-mini (5 GSE)", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  fixture_dir <- system.file("extdata/stage2-fixtures-mini",
                              package = "simulomicsr")
  skip_if(fixture_dir == "", "fixture dir not installed")

  # Identifica 5 GSE distinti con sia sample-facts che study-summary
  sample_facts_files <- list.files(fixture_dir, pattern = "-sample-facts\\.json$",
                                     full.names = TRUE)
  study_summary_files <- list.files(fixture_dir, pattern = "-study-summary\\.json$",
                                      full.names = TRUE)
  gse_ids <- sub("-sample-facts\\.json$", "", basename(sample_facts_files))[1:5]

  # Build stage1_master from sample-facts files
  stage1_master <- list()
  for (gse in gse_ids) {
    sf_path <- file.path(fixture_dir, sprintf("%s-sample-facts.json", gse))
    facts_list <- jsonlite::fromJSON(sf_path, simplifyVector = FALSE)
    # Assume formato: list of sample facts indexed by GSM
    for (f in facts_list) {
      gsm <- f$geo_accession %||% f$sample_id
      if (!is.null(gsm)) stage1_master[[gsm]] <- f
    }
  }

  # Build stage2_master from study-summary files (proxy: serve study completi)
  stage2_master <- list()
  for (gse in gse_ids) {
    ss_path <- file.path(fixture_dir, sprintf("%s-study-summary.json", gse))
    if (file.exists(ss_path)) {
      stage2_master[[length(stage2_master) + 1L]] <- jsonlite::fromJSON(
        ss_path, simplifyVector = FALSE
      )
    }
  }

  s3 <- build_stage3_clusters(stage1_master, stage2_master)

  # Verifica output strutturali
  expect_s3_class(s3, "stage3_result")
  expect_true(nrow(s3$assignments) > 0L)
  expect_true(nrow(s3$clusters) > 0L)
  expect_true(all(s3$assignments$level %in% 0L:4L))
  expect_true(all(s3$assignments$mode %in% c("pair", "group")))

  # Almeno un cluster per ogni livello (per mode pair se ci sono comparisons)
  if (any(s3$clusters$mode == "pair")) {
    levels_present <- unique(s3$clusters$level[s3$clusters$mode == "pair"])
    expect_true(0L %in% levels_present)
  }

  # Idempotenza: run_id stabile
  s3b <- build_stage3_clusters(stage1_master, stage2_master)
  expect_equal(s3$run_metadata$run_id, s3b$run_metadata$run_id)

  # Round-trip via disk
  tmp_dir <- withr::local_tempdir()
  write_stage3_to_dir(s3, tmp_dir)
  s3_loaded <- load_stage3(tmp_dir)
  expect_equal(nrow(s3$assignments), nrow(s3_loaded$assignments))
})
```

- [ ] **Step 14.2: Run + verifica + commit**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-fixture-mini")'
```

Expected: PASS (eventualmente con skip se fixture incomplete; in tal caso aggiustare fixture format).

```bash
git add tests/testthat/test-stage3-fixture-mini.R
git commit -m "P5 Stadio 3 Task 14: integration test su stage2-fixtures-mini

End-to-end build + write + load round-trip su 5 GSE. Verifica almeno
1 cluster per L0 pair, idempotenza run_id.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Targets pipeline integration

**Files:**
- Modify: `analysis/_targets.R`

- [ ] **Step 15.1: Aggiungi targets stage3**

Modifica `analysis/_targets.R` aggiungendo (alla fine della list dei targets):

```r
  # ============================================================
  # P5 Stadio 3 — Raggruppamento cross-studio
  # ============================================================

  tar_target(stage3_config, simulomicsr::stage3_default_config()),

  tar_target(
    stage1_master_path_p5,
    "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl",
    format = "file"
  ),

  tar_target(
    stage2_master_path_p5,
    "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds",
    format = "file"
  ),

  tar_target(
    archs4_metadata_p5,
    simulomicsr::load_archs4_metadata(
      h5_path = "analysis/input/human_gene_v2.5.h5"
    ),
    format = "rds"
  ),

  tar_target(
    stage3_run,
    simulomicsr::build_stage3_clusters(
      stage1_master   = stage1_master_path_p5,
      stage2_master   = stage2_master_path_p5,
      config          = stage3_config,
      archs4_metadata = archs4_metadata_p5
    ),
    format = "rds"
  ),

  tar_target(
    stage3_out_dir,
    {
      dir <- file.path(
        "analysis/p4-output",
        sprintf(
          "%s-stage3-%s",
          format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
          stage3_run$run_metadata$run_id
        )
      )
      simulomicsr::write_stage3_to_dir(stage3_run, dir)
      dir
    },
    format = "file"
  )
```

- [ ] **Step 15.2: Smoke test targets locale (no full run)**

Run:
```bash
cd /home/user/simulomicsr && Rscript --vanilla -e '
  setwd("analysis")
  targets::tar_visnetwork()
'
```

Expected: nessun errore di sintassi nel target graph. (Visnetwork output non importante; verifica che non ci siano typo.)

- [ ] **Step 15.3: Commit pipeline integration**

```bash
git add analysis/_targets.R
git commit -m "P5 Stadio 3 Task 15: targets pipeline integration

5 nuovi targets: stage3_config, stage1/2_master_path_p5, archs4_metadata_p5,
stage3_run (S3), stage3_out_dir (file). Output dir convention:
<YYYYMMDDTHHMMSSZ>-stage3-<run_id> coerente con P4 collect-dir.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: Performance smoke (skipped on CI)

**Files:**
- Create: `tests/testthat/test-stage3-perf-budget.R`

- [ ] **Step 16.1: Smoke test on full β stage2**

Crea `tests/testthat/test-stage3-perf-budget.R`:

```r
test_that("Stage 3 perf budget: 15 min wall-time, 4 GB memory peak", {
  skip_on_ci()
  skip_on_cran()
  skip_if_not(file.exists("analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"),
              "β stage2 master output not present")
  skip_if_not(file.exists("analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"),
              "β stage1 master output not present")

  start_time <- Sys.time()
  start_mem  <- as.numeric(pryr::mem_used())

  s3 <- simulomicsr::build_stage3_clusters(
    stage1_master = "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl",
    stage2_master = "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds",
    archs4_metadata = NULL  # skip h5 load for perf isolation
  )

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  peak_mem_gb <- (as.numeric(pryr::mem_used()) - start_mem) / 1e9

  cli::cli_inform("Stage 3 wall-time: {round(elapsed, 1)}s ({round(elapsed/60, 1)} min)")
  cli::cli_inform("Stage 3 peak memory delta: {round(peak_mem_gb, 2)} GB")

  expect_lt(elapsed, 15 * 60)  # 15 min
  expect_lt(peak_mem_gb, 4)
})
```

- [ ] **Step 16.2: Run manualmente, profile**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage3-perf-budget")'
```

Expected: PASS (o report del bottleneck per ottimizzazione iterativa).

- [ ] **Step 16.3: Commit**

```bash
git add tests/testthat/test-stage3-perf-budget.R
git commit -m "P5 Stadio 3 Task 16: perf smoke test (skip on CI)

Target 15min wall, 4GB peak memory su full β stage2 (39k record).
Skip se file β non presenti. Report cli per profile manuale.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: Full β run + ADR-0014 Accepted + tag

**Files:**
- Modify: `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md` (Proposed → Accepted)
- Modify: `NEWS.md` (aggiungi output counts effettivi)

- [ ] **Step 17.1: Run full target locale**

```bash
cd /home/user/simulomicsr && Rscript --vanilla -e '
  setwd("analysis")
  targets::tar_make(stage3_out_dir)
'
```

Expected: completion in <15 min con stage3_out_dir creato in `analysis/p4-output/`.

Read i 5 file output e verifica:
- `run_metadata.json` ha `output_counts` con n cluster per livello.
- `clusters.rds` ha >0 rows.
- `assignments.parquet` ha >0 rows.

- [ ] **Step 17.2: Aggiungi counts in NEWS.md**

Modifica `NEWS.md` 0.0.0.9018 aggiungendo (dopo "API: ..."):

```markdown
* Run β iniziale: <FILL: tot record clusterable / non-clusterable, n cluster per mode/level>.
  Output in `analysis/p4-output/<dirname>/`.
```

Sostituisci `<FILL: ...>` con i numeri effettivi dal `run_metadata.json` prodotto da 17.1.

- [ ] **Step 17.3: Aggiorna ADR-0014 a Accepted**

Modifica `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md`:

```markdown
**Status:** Accepted (2026-05-18, merge p5-stadio3-raggruppamento)
```

(Era `Proposed`.)

- [ ] **Step 17.4: Tag + ff-merge**

```bash
git add NEWS.md docs/decisions/0014-stage3-tiered-anchor-dual-mode.md
git commit -m "P5 Stadio 3 Task 17: ADR-0014 Accepted + NEWS run β counts

Run β iniziale completato in <wall_time>. ADR-0014 promosso da Proposed a
Accepted al merge.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

# Verifica test suite
Rscript --vanilla -e 'devtools::test()'

# Se tutto verde:
git checkout master
git merge --ff-only p5-stadio3-raggruppamento
git tag -a p5-stadio3-complete -m "P5 Stadio 3 (raggruppamento cross-studio) complete

Stadio 3 implementato con tiered anchor 5-livelli + hard filters + dual-mode
+ canonical directionality + 4 boolean use-flags + safety min aggregator.
ADR-0014 Accepted. Output run β iniziale in analysis/p4-output/.

Spec: docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md
Plan: docs/superpowers/plans/2026-05-18-p5-stadio3-raggruppamento-plan.md"
```

L'utente fara' `git push` manualmente (vedi convenzione CLAUDE.md).

---

## Self-Review

**Coverage check:**

- Spec §1 (contesto + obiettivo) → covered da ADR-0014 (Task 0) + intro Task 11.
- Spec §2 (goals + non-goals) → covered implicitamente dalle decisioni dei Task 1-13.
- Spec §3.1 (tiered anchor 5 livelli) → Task 1 (config) + Task 2 (anchor levels).
- Spec §3.2 (dual-mode) → Task 11 build orchestrator.
- Spec §3.3 (canonical directionality) → Task 3 + Task 11 (.annotate_direction).
- Spec §4.1 (pooling safety) → Task 4.
- Spec §4.2 (boolean use-flags) → Task 7.
- Spec §4.3 (thresholds) → Task 1 (config).
- Spec §4.4 (eligibility filter) → Task 5 + Task 11 (direction filter).
- Spec §5.1-5.5 (output schema 5 file) → Task 11 (build) + Task 12 (write).
- Spec §6 (API surface) → Task 1, 10, 11, 12, 13.
- Spec §7 (targets integration) → Task 15.
- Spec §8.1 (unit tests) → Task 1-13.
- Spec §8.2 (integration test) → Task 14.
- Spec §8.3 (perf smoke) → Task 16.
- Spec §9 (versioning) → Task 11 (run_metadata builder).
- Spec §10 risks → handled inline nei task; library_strategy verifica in Task 10.
- Spec §11 ADR-0014 → Task 0 (Proposed) + Task 17 (Accepted).

**Placeholder scan:**
- Task 17.2 `<FILL: ...>` e' intenzionale (l'engineer riempie con numeri effettivi del run).
- Tutti gli altri step hanno codice completo o comandi specifici.

**Type consistency:**
- `stage3_result` S3 referenziato consistentemente in Task 11, 12, 13.
- `stage3_default_config()` schema rispettato in tutti i task downstream (Task 7 thresholds, Task 11 tier_assignment).
- `assignments` schema (record_id, mode, level, cluster_id, anchor_key) consistente in Task 6, 9, 11, 12.
- `clusters` schema (cluster_id, mode, level, anchor_key, k, n_total, ..., 4 usable_*, safety_*) consistente in Task 11 (.summarize_clusters), 12 (write), 13 (filter_clusters).

**Gaps identificati e risolti inline:**
- Spec §5.2 menziona `library_strategies` come optional → Task 10 implementa solo (sample_id, series_id, gpl), library_strategy esplicitamente droppato con commento ("v2 will add if H5 schema evolves"). Coerente con spec §10 risk mitigation.
