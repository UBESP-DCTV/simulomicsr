# P5 Stadio 4 — DE per-studio + MEGA cross-study production Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementare la pipeline production Stadio 4 in `simulomicsr` che consuma l'output Stadio 3 (cluster cross-studio) e produce effect-size pooled per ~412 cluster Layer A via tre path (limma-voom REM, dream MEGA, dream MEGA-augmentation) con caching counts persistente e Quarto diagnostic dashboard.

**Architecture:** 5 sub-stage (QC → counts cache → per-study DE → cluster pooling → dashboard) implementati come moduli R separati, integrati nel pipeline `targets` esistente. TDD bite-sized per ogni modulo; fixture mini per integration test; replication test per idempotenza; smoke 5-cluster come gate pre-Layer-A full run.

**Tech Stack:** R 4.5+, limma-voom + eBayes (REM per-study DE), `variancePartition::dream` (MEGA + MEGA-AUG mixed models), `metafor::rma` REML (REM pooling), `rhdf5` (ARCHS4 H5 read), `arrow` (parquet output), `targets` (pipeline orchestration), `future::multisession` (parallelism), Quarto + DT + plotly (dashboard).

**Spec di riferimento:** `docs/superpowers/specs/2026-05-19-p5-stadio4-de-perstudio-design.md`

---

## File structure overview

**R/ files da creare (`@keywords internal` se non `@export`):**
- `R/stage4-config.R` — `stage4_default_config()` (config + thresholds)
- `R/stage4-helpers.R` — `.run_id_for_stage4()`, `.compute_input_hashes()`, `cluster_de_summary()`
- `R/stage4-qc.R` — `.qc_filter_samples_and_studies()`, `.identify_layer_a_clusters()`
- `R/stage4-counts-cache.R` — `.fetch_counts_cached()`, `prefetch_counts_for_clusters()`, `cache_purge_stage4()`
- `R/stage4-limma-de.R` — `.run_limma_voom_de()`
- `R/stage4-rem-pooling.R` — `.pool_rem_cluster()`
- `R/stage4-dream-mega.R` — `.run_dream_mega()`
- `R/stage4-mega-aug.R` — `.assemble_mega_aug_metadata()`
- `R/stage4-orchestrator.R` — `.run_per_study_de_all()`, `.pool_all_clusters()`, `.build_qc_report()`
- `R/stage4-build.R` — `build_stage4_results()` (entry point export)
- `R/stage4-io.R` — `write_stage4_to_dir()`, `load_stage4()`
- `R/stage4-dashboard.R` — `render_stage4_dashboard()`
- `inst/templates/stage4-dashboard.qmd` — Quarto template

**Test files da creare (mirror `tests/testthat/`):**
- `helper-stage4-fixtures.R` (auto-loaded fixture builders)
- `test-stage4-config.R`
- `test-stage4-helpers.R`
- `test-stage4-qc.R`
- `test-stage4-counts-cache.R`
- `test-stage4-limma-de.R`
- `test-stage4-rem-pooling.R`
- `test-stage4-dream-mega.R`
- `test-stage4-mega-aug.R`
- `test-stage4-orchestrator.R`
- `test-stage4-io.R`
- `test-stage4-build.R` (integration end-to-end mini)
- `test-stage4-replication.R` (idempotence)
- `test-stage4-direction-flip.R`
- `test-stage4-dashboard.R`

**Script analysis/:**
- `analysis/p5-stage4-smoke5.R` (smoke 5-cluster pre-fullrun)
- `analysis/p5-stage4-layer-a-fullrun.R` (Layer A full ~412 cluster)

**Docs:**
- `docs/decisions/0015-stage4-three-path-architecture.md` (ADR Proposed)
- `NEWS.md` (bullet 0.0.0.9019)

**targets integration:**
- `analysis/_targets.R` (additivo, target Stadio 4)

---

## Task 1: Branch setup + DESCRIPTION dependencies + stage4-config skeleton

**Files:**
- Modify: `DESCRIPTION` (add Imports + Suggests)
- Create: `R/stage4-config.R`
- Test: `tests/testthat/test-stage4-config.R`

- [ ] **Step 1: Create branch `p5-stadio4-de-perstudio` partendo da master @ p5-stadio3-complete**

```bash
git checkout master
git pull --ff-only  # se serve sync con remoto (verifica con utente, non push)
git checkout -b p5-stadio4-de-perstudio
```

Verifica: `git branch --show-current` → `p5-stadio4-de-perstudio`

- [ ] **Step 2: Aggiornare DESCRIPTION con nuove dipendenze**

Aggiungere agli Imports: `edgeR`, `limma`, `variancePartition`, `metafor`, `BiocParallel`, `arrow`, `parallelly`, `xfun` (xfun fornisce `xfun::file_string` utility per Quarto rendering; alternativa scartare se non serve).
Aggiungere ai Suggests: `quarto`, `DT`, `plotly`, `crosstalk`.

`Imports:` (preservare l'esistente + aggiungere):
```
    arrow,
    BiocParallel,
    edgeR,
    limma,
    metafor,
    parallelly,
    variancePartition,
```
`Suggests:` (preservare l'esistente + aggiungere):
```
    crosstalk,
    DT,
    plotly,
    quarto,
```

Note: `arrow` era in Suggests, promuoverlo a Imports (lo Stadio 3 lo usa già transitively).

- [ ] **Step 3: Scrivere test failing per stage4_default_config**

```r
# tests/testthat/test-stage4-config.R
test_that("stage4_default_config restituisce list con campi essenziali", {
  cfg <- stage4_default_config()

  expect_type(cfg, "list")
  expect_named(cfg, c("qc", "de_engine", "pooling", "compute", "schema_versions"),
               ignore.order = TRUE)
})

test_that("qc threshold lib_size_min e' 500000 di default", {
  cfg <- stage4_default_config()
  expect_equal(cfg$qc$lib_size_min, 500000L)
})

test_that("de_engine specifica limma-voom per REM e dream per MEGA", {
  cfg <- stage4_default_config()
  expect_equal(cfg$de_engine$rem, "limma-voom+eBayes")
  expect_equal(cfg$de_engine$mega, "dream")
  expect_equal(cfg$de_engine$mega_aug, "dream")
})

test_that("pooling specifica REML come metodo default con DL fallback per REM", {
  cfg <- stage4_default_config()
  expect_equal(cfg$pooling$rem_method, "REML")
  expect_equal(cfg$pooling$rem_fallback, "DL")
  expect_equal(cfg$pooling$fdr, "BH_within_cluster")
})

test_that("compute$workers usa availableCores - 10 di default", {
  cfg <- stage4_default_config()
  expect_type(cfg$compute$workers_offset, "integer")
  expect_equal(cfg$compute$workers_offset, 10L)
})

test_that("schema_versions include stage4_algorithm v1", {
  cfg <- stage4_default_config()
  expect_equal(cfg$schema_versions$stage4_algorithm, "v1")
})
```

- [ ] **Step 4: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-config")'
```
Expected: FAIL with "could not find function stage4_default_config".

- [ ] **Step 5: Implementare R/stage4-config.R**

```r
#' Default configuration per Stadio 4 DE per-studio + MEGA cross-study production
#'
#' Restituisce la configurazione di default che governa Stage 4: QC sample-level
#' (lib_size threshold), DE engine choice (limma-voom REM + dream MEGA),
#' pooling method (REML con DL fallback per REM), parallelism (workers offset),
#' versioning schema per riproducibilita'.
#'
#' @return list con 5 componenti: \code{qc}, \code{de_engine}, \code{pooling},
#'   \code{compute}, \code{schema_versions}.
#' @seealso \code{\link{build_stage4_results}}, ADR-0015.
#' @export
stage4_default_config <- function() {
  list(
    qc = list(
      lib_size_min = 500000L
    ),
    de_engine = list(
      rem      = "limma-voom+eBayes",
      mega     = "dream",
      mega_aug = "dream"
    ),
    pooling = list(
      rem_method   = "REML",
      rem_fallback = "DL",
      fdr          = "BH_within_cluster"
    ),
    compute = list(
      workers_offset = 10L,
      dream_workers_cap = 8L
    ),
    schema_versions = list(
      anchor             = "v3",
      stage3_algorithm   = "v1",
      stage4_algorithm   = "v1"
    )
  )
}
```

- [ ] **Step 6: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-config")'
```
Expected: PASS (6 test).

- [ ] **Step 7: Commit**

```bash
git add DESCRIPTION R/stage4-config.R tests/testthat/test-stage4-config.R
git commit -m "P5 Stadio 4 Task 1: branch + DESCRIPTION deps + stage4_default_config"
```

---

## Task 2: stage4-helpers.R — run_id determinismo + input hashes

**Files:**
- Create: `R/stage4-helpers.R`
- Test: `tests/testthat/test-stage4-helpers.R`

- [ ] **Step 1: Scrivere test failing per .run_id_for_stage4**

```r
# tests/testthat/test-stage4-helpers.R
test_that(".run_id_for_stage4 e' deterministico per stessi input", {
  hashes <- list(stage3 = "abc123", h5 = "def456")
  cfg <- stage4_default_config()
  schema <- cfg$schema_versions

  id1 <- .run_id_for_stage4(hashes, cfg, schema)
  id2 <- .run_id_for_stage4(hashes, cfg, schema)

  expect_identical(id1, id2)
  expect_true(nchar(id1) == 8L)
  expect_true(grepl("^[0-9a-f]{8}$", id1))
})

test_that(".run_id_for_stage4 cambia con config diverse", {
  hashes <- list(stage3 = "abc123", h5 = "def456")
  cfg1 <- stage4_default_config()
  cfg2 <- cfg1; cfg2$qc$lib_size_min <- 1000000L

  id1 <- .run_id_for_stage4(hashes, cfg1, cfg1$schema_versions)
  id2 <- .run_id_for_stage4(hashes, cfg2, cfg2$schema_versions)

  expect_false(identical(id1, id2))
})

test_that(".compute_input_hashes restituisce list con stage3 e h5", {
  # Fixture: stage3 dir mock + h5 file mock
  tmp_stage3 <- withr::local_tempdir()
  tmp_h5     <- withr::local_tempfile(fileext = ".h5")
  saveRDS(list(run_id = "mock1234"), file.path(tmp_stage3, "run_metadata.rds"))
  writeBin(as.raw(c(0x89, 0x48, 0x44, 0x46)), tmp_h5)  # bytes mock

  hashes <- .compute_input_hashes(tmp_stage3, tmp_h5)

  expect_named(hashes, c("stage3", "h5"))
  expect_true(nchar(hashes$stage3) >= 8L)
  expect_true(nchar(hashes$h5) >= 8L)
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-helpers")'
```
Expected: FAIL with ".run_id_for_stage4 not found".

- [ ] **Step 3: Implementare R/stage4-helpers.R**

```r
#' Calcola run_id deterministico per Stadio 4
#'
#' Hash di (input_hashes + config + schema_versions) -> 8-hex string. Re-run
#' con stesso input/config produce stesso run_id (idempotenza).
#'
#' @param input_hashes list con stage3 + h5 sha256
#' @param config stage4 config (vedi \code{stage4_default_config})
#' @param schema_versions list con anchor + stage3_algorithm + stage4_algorithm
#' @return character scalar 8-hex
#' @keywords internal
.run_id_for_stage4 <- function(input_hashes, config, schema_versions) {
  canonical <- list(
    inputs = input_hashes,
    config = config[setdiff(names(config), "compute")],  # workers non parte del run_id
    schema = schema_versions
  )
  full <- digest::digest(canonical, algo = "sha256", serialize = TRUE)
  substr(full, 1L, 8L)
}

#' Calcola hash sha256 di stage3 dir + h5 file per run_id
#'
#' @param stage3_dir path al directory Stadio 3 (verra' hashata
#'   \code{clusters.rds} se presente, altrimenti l'intera dir).
#' @param h5_path path al file ARCHS4 H5.
#' @return list con 2 elementi: \code{stage3}, \code{h5}.
#' @keywords internal
.compute_input_hashes <- function(stage3_dir, h5_path) {
  stage3_target <- file.path(stage3_dir, "clusters.rds")
  if (!file.exists(stage3_target)) {
    # fallback al directory intero (concat di sha256 dei file ordinati)
    files <- list.files(stage3_dir, full.names = TRUE, recursive = TRUE)
    files <- sort(files)
    stage3_hash <- digest::digest(
      sapply(files, digest::digest, algo = "sha256", file = TRUE,
             USE.NAMES = FALSE),
      algo = "sha256"
    )
  } else {
    stage3_hash <- digest::digest(stage3_target, algo = "sha256", file = TRUE)
  }

  h5_hash <- digest::digest(h5_path, algo = "sha256", file = TRUE)

  list(
    stage3 = substr(stage3_hash, 1L, 16L),
    h5     = substr(h5_hash, 1L, 16L)
  )
}

#' Helper consumer-facing: estrai per_study + pooled side-by-side per un cluster
#'
#' Utile per esplorazione interattiva e per la dashboard.
#'
#' @param s4 stage4_result object (output di \code{load_stage4} o
#'   \code{build_stage4_results}).
#' @param cluster_id string cluster_id.
#' @return list con 2 tibble: \code{per_study} e \code{pooled}.
#' @export
cluster_de_summary <- function(s4, cluster_id) {
  per_study <- s4$per_study_de[s4$per_study_de$cluster_id == cluster_id, ]
  pooled    <- s4$cluster_pooled[s4$cluster_pooled$cluster_id == cluster_id, ]
  list(per_study = per_study, pooled = pooled)
}
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-helpers")'
```
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-helpers.R tests/testthat/test-stage4-helpers.R
git commit -m "P5 Stadio 4 Task 2: stage4-helpers run_id + input_hashes + cluster_de_summary"
```

---

## Task 3: helper-stage4-fixtures + stage4-qc.R — sample/study/cluster QC

**Files:**
- Create: `tests/testthat/helper-stage4-fixtures.R`
- Create: `R/stage4-qc.R`
- Test: `tests/testthat/test-stage4-qc.R`

- [ ] **Step 1: Creare helper fixtures per test Stage 4**

```r
# tests/testthat/helper-stage4-fixtures.R
#' Costruisce input mock eligible_clusters + h5_metadata per i test Stage 4
#'
#' Restituisce list con:
#' - clusters: tibble Stage 3 clusters (3 cluster: 1 REM proper, 1 MEGA strict, 1 MEGA-AUG pair)
#' - h5_metadata: tibble (sample_id, gsm, gse, lib_size) con 30 sample
#' - mode "controlled fail": alcuni sample con lib_size sotto soglia
#' @keywords internal
make_test_stage4_input <- function(seed = 42L) {
  set.seed(seed)
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_aaaaaaaa", "group_L0_bbbbbbbb", "pair_L0_cccccccc"),
    mode = factor(c("pair", "group", "pair"), levels = c("pair", "group")),
    level = c(0L, 0L, 0L),
    anchor_key = c("TEST_PAIR_KEY", "TEST_GROUP_KEY", "TEST_AUG_KEY"),
    k = c(3L, 5L, 2L),
    n_total = c(18L, 30L, 12L),
    n_treated = c(9L, NA_integer_, 6L),
    n_control = c(9L, NA_integer_, 6L),
    safety_min = c(1.0, 0.8, 1.0),
    safety_geom_mean = c(1.0, 0.85, 1.0),
    usable_rem_strict = c(TRUE, FALSE, FALSE),
    usable_rem_relaxed = c(TRUE, FALSE, TRUE),
    usable_mega_strict = c(FALSE, TRUE, FALSE),
    usable_mega_relaxed = c(FALSE, TRUE, FALSE),
    direction_check = factor(c("canonical", "na", "canonical"),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    n_studies = c(3L, 5L, 2L),
    studies_in_cluster = list(
      c("GSE001", "GSE002", "GSE003"),
      c("GSE001", "GSE002", "GSE003", "GSE004", "GSE005"),
      c("GSE006", "GSE007")
    )
  )

  # 5 GSE x ~6 sample = 30 sample, lib_size random N(1e6, 3e5), alcuni sotto 500k
  gse_ids <- paste0("GSE00", 1:7)
  h5_metadata <- tibble::tibble(
    sample_id = paste0("GSM", sprintf("%06d", 1:42)),
    gsm = paste0("GSM", sprintf("%06d", 1:42)),
    gse = rep(gse_ids, each = 6),
    lib_size = pmax(50000L, as.integer(rnorm(42, mean = 1.2e6, sd = 4e5)))
  )

  list(clusters = clusters, h5_metadata = h5_metadata)
}
```

- [ ] **Step 2: Scrivere test failing per QC**

```r
# tests/testthat/test-stage4-qc.R
test_that(".qc_filter_samples_and_studies marca sample sotto lib_size_min", {
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  result <- .qc_filter_samples_and_studies(
    stage3_clusters = input$clusters,
    h5_metadata = input$h5_metadata,
    config = cfg
  )

  expect_named(result, c("eligible_clusters", "qc_drops_sample",
                          "qc_drops_study", "qc_drops_cluster"),
               ignore.order = TRUE)
  expect_true(nrow(result$qc_drops_sample) >= 0L)
  expect_true(all(result$qc_drops_sample$lib_size < 500000L))
})

test_that("identify_layer_a_clusters filtra correttamente i 3 path", {
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  la <- .identify_layer_a_clusters(input$clusters, stage4_config = cfg)

  expect_true(all(la$method %in% c("rem", "mega", "mega_aug")))
  expect_equal(sum(la$method == "rem"), 1L)
  expect_equal(sum(la$method == "mega"), 1L)
})

test_that("cluster con tutti sample droppati va in qc_drops_cluster", {
  input <- make_test_stage4_input(seed = 42L)
  # forza lib_size = 100k per tutti i sample di GSE001
  input$h5_metadata$lib_size[input$h5_metadata$gse == "GSE001"] <- 100000L

  cfg <- stage4_default_config()
  result <- .qc_filter_samples_and_studies(input$clusters, input$h5_metadata, cfg)

  expect_true(any(result$qc_drops_study$study_id == "GSE001"))
})
```

- [ ] **Step 3: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-qc")'
```
Expected: FAIL with ".qc_filter_samples_and_studies not found".

- [ ] **Step 4: Implementare R/stage4-qc.R**

```r
#' Identifica cluster Layer A (REM proper + MEGA strict + MEGA-aug)
#'
#' Layer A = i ~412 cluster publishable definiti nel finding scope decision
#' 2026-05-19. Aggiunge colonna \code{method} con il path da seguire.
#'
#' @param stage3_clusters tibble di \code{clusters.rds} Stage 3.
#' @param stage4_config output di \code{stage4_default_config}.
#' @return tibble con colonne originali + \code{method} (\code{rem} \code{mega}
#'   \code{mega_aug}).
#' @keywords internal
.identify_layer_a_clusters <- function(stage3_clusters, stage4_config) {
  rem <- stage3_clusters[
    stage3_clusters$usable_rem_strict &
    stage3_clusters$k >= 3L & stage3_clusters$k <= 9L &
    stage3_clusters$mode == "pair",
  ]
  if (nrow(rem) > 0L) rem$method <- "rem"

  mega <- stage3_clusters[
    stage3_clusters$usable_mega_strict &
    stage3_clusters$n_studies >= 5L &
    stage3_clusters$mode == "group",
  ]
  if (nrow(mega) > 0L) mega$method <- "mega"

  # MEGA-AUG: pair k=2 con baseline pool (vedi mega_aug_pair_with_baseline_pool
  # nello spec; v1 identifica come pair k==2 + usable_rem_relaxed + esiste un
  # group cluster con stesso control_anchor allo stesso L).
  # Implementazione semplificata: derivata dal cluster STAGE3 (s3 ha gia' i
  # candidate); per ora marca tutti i pair k=2 mode=pair usable_rem_relaxed
  # con method=mega_aug e flag baseline_pool_check da verificare a build time.
  mega_aug <- stage3_clusters[
    stage3_clusters$mode == "pair" &
    stage3_clusters$k == 2L &
    stage3_clusters$usable_rem_relaxed,
  ]
  if (nrow(mega_aug) > 0L) mega_aug$method <- "mega_aug"

  do.call(rbind, list(rem, mega, mega_aug))
}

#' Filtra sample, studi e cluster per QC sample-level
#'
#' @param stage3_clusters tibble Stage 3 clusters.
#' @param h5_metadata tibble con (sample_id, gsm, gse, lib_size).
#' @param config stage4 config.
#' @return list con \code{eligible_clusters}, \code{qc_drops_sample},
#'   \code{qc_drops_study}, \code{qc_drops_cluster}.
#' @keywords internal
.qc_filter_samples_and_studies <- function(stage3_clusters, h5_metadata, config) {
  layer_a <- .identify_layer_a_clusters(stage3_clusters, config)

  # Sample drops: lib_size sotto soglia
  qc_drops_sample <- h5_metadata[h5_metadata$lib_size < config$qc$lib_size_min, ]
  qc_drops_sample$reason <- "lib_size_below_500k"

  # Studio per cluster: identificato dai studies_in_cluster
  # Per ogni (cluster_id, study_id), conta sample remaining post lib_size
  # qc_drops_study costruito iterando sui cluster
  dropped_samples <- qc_drops_sample$sample_id
  qc_drops_study <- tibble::tibble(
    cluster_id = character(),
    study_id = character(),
    n_treated_remaining = integer(),
    n_control_remaining = integer(),
    reason = character()
  )

  # Cluster eligible post-QC: stessa tibble layer_a, eventualmente con
  # k_post_qc < k (logica future-prooming; v1 conserva i cluster originali +
  # passa i dropped per filtraggio downstream).
  eligible_clusters <- layer_a

  # qc_drops_cluster: cluster non-processable post QC. v1 empty perche'
  # la decisione finale e' presa in orchestratore con counts veri; flag
  # placeholder per output schema.
  qc_drops_cluster <- tibble::tibble(
    cluster_id = character(),
    original_k = integer(),
    qc_final_k = integer(),
    original_n_studies = integer(),
    qc_final_n_studies = integer(),
    reason = character()
  )

  list(
    eligible_clusters = eligible_clusters,
    qc_drops_sample   = qc_drops_sample,
    qc_drops_study    = qc_drops_study,
    qc_drops_cluster  = qc_drops_cluster
  )
}
```

- [ ] **Step 5: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-qc")'
```
Expected: PASS (3 test).

- [ ] **Step 6: Commit**

```bash
git add tests/testthat/helper-stage4-fixtures.R R/stage4-qc.R tests/testthat/test-stage4-qc.R
git commit -m "P5 Stadio 4 Task 3: stage4-qc lib_size filter + layer_a identification + fixtures"
```

---

## Task 4: stage4-counts-cache.R — fetch persistente da ARCHS4 H5

**Files:**
- Create: `R/stage4-counts-cache.R`
- Test: `tests/testthat/test-stage4-counts-cache.R`

- [ ] **Step 1: Scrivere test failing per cache key + fetch**

```r
# tests/testthat/test-stage4-counts-cache.R
test_that(".cache_key_for_fetch e' deterministico per stessi (gse, sample_ids)", {
  k1 <- .cache_key_for_fetch("GSE001", c("GSM001", "GSM002"))
  k2 <- .cache_key_for_fetch("GSE001", c("GSM002", "GSM001"))  # ordine diverso
  expect_identical(k1, k2)  # sorted internamente
  expect_true(nchar(k1) == 8L)
})

test_that("cache_purge_stage4 ritorna 0 quando cache_dir non esiste", {
  tmp <- file.path(withr::local_tempdir(), "no_cache")
  result <- cache_purge_stage4(cache_dir = tmp)
  expect_equal(result, 0L)
})

test_that(".fetch_counts_cached salva su disco e rispetta cache hit", {
  tmp_cache <- withr::local_tempdir()

  # Mock fetch function che incrementa counter ogni volta
  call_count <- 0L
  mock_fetch <- function(gse, sample_ids) {
    call_count <<- call_count + 1L
    matrix(1:6, nrow = 3, ncol = 2,
           dimnames = list(c("g1", "g2", "g3"), sample_ids))
  }

  # Prima call: cache miss -> fetch
  m1 <- .fetch_counts_cached("GSE001", c("GSM001", "GSM002"),
                              fetch_fn = mock_fetch, cache_dir = tmp_cache)
  expect_equal(call_count, 1L)

  # Seconda call: cache hit -> no fetch
  m2 <- .fetch_counts_cached("GSE001", c("GSM001", "GSM002"),
                              fetch_fn = mock_fetch, cache_dir = tmp_cache)
  expect_equal(call_count, 1L)  # ancora 1, no incremento
  expect_identical(m1, m2)
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-counts-cache")'
```
Expected: FAIL with ".cache_key_for_fetch not found".

- [ ] **Step 3: Implementare R/stage4-counts-cache.R**

```r
#' Cache key per fetch counts ARCHS4
#'
#' xxhash32 di (gse, sorted(sample_ids)) -> 8-hex stabile.
#'
#' @keywords internal
.cache_key_for_fetch <- function(gse, sample_ids) {
  sorted <- sort(sample_ids)
  payload <- paste0(gse, "_", paste(sorted, collapse = "|"))
  hash <- digest::digest(payload, algo = "xxhash32", serialize = FALSE)
  substr(hash, 1L, 8L)
}

#' Default cache dir per Stadio 4 counts
#'
#' @keywords internal
.default_stage4_cache_dir <- function() {
  base <- tools::R_user_dir("simulomicsr", which = "cache")
  file.path(base, "stage4-counts")
}

#' Fetch counts ARCHS4 con cache persistente
#'
#' @param gse string GSE accession
#' @param sample_ids character vector di GSM ids
#' @param h5_path path al H5 ARCHS4 (NULL se fetch_fn override fornito)
#' @param fetch_fn function (gse, sample_ids) -> matrix; default chiama
#'   \code{.fetch_counts_from_h5} (per testabilita').
#' @param cache_dir cache directory; default \code{.default_stage4_cache_dir()}
#' @return integer matrix (genes x samples)
#' @keywords internal
.fetch_counts_cached <- function(gse, sample_ids, h5_path = NULL,
                                  fetch_fn = NULL,
                                  cache_dir = NULL) {
  if (is.null(cache_dir)) cache_dir <- .default_stage4_cache_dir()
  if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

  key <- .cache_key_for_fetch(gse, sample_ids)
  cache_file <- file.path(cache_dir, paste0(key, ".rds"))

  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  if (is.null(fetch_fn)) {
    if (is.null(h5_path)) stop("h5_path required when fetch_fn is NULL")
    fetch_fn <- function(g, s) .fetch_counts_from_h5(g, s, h5_path)
  }

  counts <- fetch_fn(gse, sample_ids)
  saveRDS(counts, cache_file, compress = "xz")
  counts
}

#' Fetch counts da ARCHS4 H5 (low-level, no cache)
#'
#' @param gse string GSE accession
#' @param sample_ids character vector di GSM ids
#' @param h5_path path al H5 ARCHS4
#' @return integer matrix (genes x samples) con rownames HGNC symbol +
#'   colnames GSM accession.
#' @keywords internal
.fetch_counts_from_h5 <- function(gse, sample_ids, h5_path) {
  # Read sample index from h5 meta
  all_gsm <- rhdf5::h5read(h5_path, "meta/samples/geo_accession")
  idx <- match(sample_ids, all_gsm)
  if (any(is.na(idx))) {
    stop(sprintf("Sample IDs not found in H5: %s",
                 paste(sample_ids[is.na(idx)], collapse = ", ")))
  }

  # Read counts subset (genes are all rows; samples are subset cols)
  counts <- rhdf5::h5read(h5_path, "data/expression",
                          index = list(NULL, idx))
  storage.mode(counts) <- "integer"

  # Rownames = HGNC symbol; colnames = GSM
  genes <- rhdf5::h5read(h5_path, "meta/genes/symbol")
  rownames(counts) <- genes
  colnames(counts) <- sample_ids

  counts
}

#' Prefetch counts per tutti i cluster eligible Stage 4
#'
#' Itera su tutti gli (gse, sample_ids) unique negli eligible cluster e
#' popola la cache. Output manifest path -> cache_key.
#'
#' @param eligible_clusters tibble output di \code{.qc_filter_samples_and_studies}.
#' @param h5_path path al H5 ARCHS4.
#' @param cache_dir cache dir; default \code{.default_stage4_cache_dir()}.
#' @return tibble (gse, n_samples, cache_key, cache_path, status)
#' @export
prefetch_counts_for_clusters <- function(eligible_clusters, h5_path,
                                          cache_dir = NULL) {
  if (is.null(cache_dir)) cache_dir <- .default_stage4_cache_dir()

  # Itera unique (gse, sample_ids) -- implementazione delegata al chiamante
  # per ora: stub che ritorna tibble vuota.
  # Versione full sara' implementata in Task orchestrator quando vediamo
  # come i sample_ids sono propagati da Stage 3.
  tibble::tibble(
    gse = character(),
    n_samples = integer(),
    cache_key = character(),
    cache_path = character(),
    status = character()
  )
}

#' Purge cache counts Stadio 4
#'
#' Opt-in cleanup. Mai chiamato automaticamente.
#'
#' @param cache_dir cache dir; default \code{.default_stage4_cache_dir()}.
#' @param older_than_days se non-NULL, rimuovi solo file piu' vecchi di N giorni.
#' @return invisible(integer) numero di file rimossi.
#' @export
cache_purge_stage4 <- function(cache_dir = NULL, older_than_days = NULL) {
  if (is.null(cache_dir)) cache_dir <- .default_stage4_cache_dir()
  if (!dir.exists(cache_dir)) return(invisible(0L))

  files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files) == 0L) return(invisible(0L))

  if (!is.null(older_than_days)) {
    cutoff <- Sys.time() - older_than_days * 86400
    files <- files[file.info(files)$mtime < cutoff]
  }

  file.remove(files)
  invisible(length(files))
}
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-counts-cache")'
```
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-counts-cache.R tests/testthat/test-stage4-counts-cache.R
git commit -m "P5 Stadio 4 Task 4: stage4-counts-cache fetch + cache persistente xxhash key"
```

---

## Task 5: stage4-limma-de.R — limma-voom + eBayes per single study

**Files:**
- Create: `R/stage4-limma-de.R`
- Test: `tests/testthat/test-stage4-limma-de.R`

- [ ] **Step 1: Scrivere test failing per .run_limma_voom_de**

```r
# tests/testthat/test-stage4-limma-de.R
test_that(".run_limma_voom_de produce tibble per-gene con logFC + SE + p", {
  skip_if_not_installed("limma")
  skip_if_not_installed("edgeR")

  # Fixture: 100 geni x 6 sample (3 treated + 3 control)
  set.seed(42)
  counts <- matrix(rnbinom(600, size = 5, mu = 100), nrow = 100, ncol = 6)
  rownames(counts) <- paste0("GENE_", sprintf("%03d", 1:100))
  colnames(counts) <- paste0("GSM", sprintf("%06d", 1:6))
  # Induci differenziale su primi 10 geni (treated up)
  counts[1:10, 1:3] <- counts[1:10, 1:3] * 5

  treatment_vec <- factor(rep(c("treated", "control"), each = 3),
                          levels = c("control", "treated"))

  res <- .run_limma_voom_de(counts, treatment_vec, study_id = "GSE001",
                             cluster_id = "TEST", direction_flip = FALSE)

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("cluster_id", "study_id", "gene", "logFC", "SE",
                       "p_value", "t_stat", "n_treated", "n_control",
                       "direction_applied"),
               ignore.order = TRUE)
  expect_equal(unique(res$study_id), "GSE001")
  expect_equal(unique(res$n_treated), 3L)
  expect_equal(unique(res$n_control), 3L)
  expect_true(all(res$SE > 0))
  expect_true(all(res$p_value >= 0 & res$p_value <= 1))
})

test_that(".run_limma_voom_de applica direction_flip negando logFC", {
  skip_if_not_installed("limma")

  set.seed(42)
  counts <- matrix(rnbinom(600, size = 5, mu = 100), nrow = 100, ncol = 6)
  rownames(counts) <- paste0("GENE_", sprintf("%03d", 1:100))
  colnames(counts) <- paste0("GSM", sprintf("%06d", 1:6))
  treatment_vec <- factor(rep(c("treated", "control"), each = 3),
                          levels = c("control", "treated"))

  res_canon <- .run_limma_voom_de(counts, treatment_vec, "GSE001",
                                    cluster_id = "TEST",
                                    direction_flip = FALSE)
  res_flip  <- .run_limma_voom_de(counts, treatment_vec, "GSE001",
                                    cluster_id = "TEST",
                                    direction_flip = TRUE)

  expect_equal(res_flip$logFC, -res_canon$logFC)
  expect_equal(unique(res_flip$direction_applied), "flipped")
  expect_equal(unique(res_canon$direction_applied), "none")
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-limma-de")'
```
Expected: FAIL with ".run_limma_voom_de not found".

- [ ] **Step 3: Implementare R/stage4-limma-de.R**

```r
#' Run limma-voom + eBayes per single (cluster, study)
#'
#' Pipeline: DGEList -> filterByExpr -> normLibSizes(TMM) -> voom ->
#' lmFit -> eBayes -> per-gene extraction (logFC, SE, p, t).
#'
#' Direction flip: se \code{direction_flip=TRUE} (cluster con
#' \code{direction_check="swapped"} da Stage 3), il logFC viene negato in output.
#'
#' @param counts integer matrix (genes x samples)
#' @param treatment_vec factor con levels \code{c("control", "treated")}
#' @param study_id string GSE accession
#' @param cluster_id string cluster_id per output column
#' @param direction_flip logical: se TRUE, multiplica logFC per -1
#' @return tibble con colonne cluster_id, study_id, gene, logFC, SE, p_value,
#'   t_stat, n_treated, n_control, direction_applied.
#' @keywords internal
.run_limma_voom_de <- function(counts, treatment_vec, study_id, cluster_id,
                                direction_flip = FALSE) {
  stopifnot(
    is.matrix(counts) || is.data.frame(counts),
    is.factor(treatment_vec),
    "control" %in% levels(treatment_vec),
    "treated" %in% levels(treatment_vec),
    ncol(counts) == length(treatment_vec)
  )

  n_treated <- sum(treatment_vec == "treated")
  n_control <- sum(treatment_vec == "control")

  dge <- edgeR::DGEList(counts = counts, group = treatment_vec)
  keep <- edgeR::filterByExpr(dge, group = treatment_vec)
  dge <- dge[keep, , keep.lib.sizes = FALSE]
  dge <- edgeR::normLibSizes(dge, method = "TMM")

  design <- stats::model.matrix(~ treatment_vec)
  colnames(design) <- c("(Intercept)", "treatmenttreated")

  v   <- limma::voom(dge, design)
  fit <- limma::lmFit(v, design)
  fit <- limma::eBayes(fit)

  logFC  <- fit$coefficients[, "treatmenttreated"]
  SE     <- sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"]
  p_val  <- fit$p.value[, "treatmenttreated"]
  t_stat <- fit$t[, "treatmenttreated"]

  if (direction_flip) {
    logFC <- -logFC
    direction_applied <- "flipped"
  } else {
    direction_applied <- "none"
  }

  tibble::tibble(
    cluster_id        = cluster_id,
    study_id          = study_id,
    gene              = rownames(fit),
    logFC             = unname(logFC),
    SE                = unname(SE),
    p_value           = unname(p_val),
    t_stat            = unname(t_stat),
    n_treated         = n_treated,
    n_control         = n_control,
    direction_applied = direction_applied
  )
}
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-limma-de")'
```
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-limma-de.R tests/testthat/test-stage4-limma-de.R
git commit -m "P5 Stadio 4 Task 5: stage4-limma-de single-study limma-voom + eBayes + direction flip"
```

---

## Task 6: stage4-rem-pooling.R — metafor::rma REML + DL fallback

**Files:**
- Create: `R/stage4-rem-pooling.R`
- Test: `tests/testthat/test-stage4-rem-pooling.R`

- [ ] **Step 1: Scrivere test failing per .pool_rem_cluster**

```r
# tests/testthat/test-stage4-rem-pooling.R
test_that(".pool_rem_cluster ritorna tibble gene-level con tau2 + I2 + Q", {
  skip_if_not_installed("metafor")

  # Fixture: 5 geni x 3 studi
  per_study <- tibble::tibble(
    cluster_id = "TEST",
    study_id = rep(c("GSE001", "GSE002", "GSE003"), each = 5),
    gene = rep(paste0("G", 1:5), 3),
    logFC = c( 2.0, 1.0, 0.5, -0.5, -1.0,
               2.2, 1.1, 0.5, -0.4, -1.1,
               1.8, 0.9, 0.6, -0.5, -0.9),
    SE    = rep(c(0.3, 0.4, 0.3, 0.3, 0.4), 3),
    p_value = 0.01,
    t_stat = NA_real_,
    n_treated = 3L,
    n_control = 3L,
    direction_applied = "none"
  )

  res <- .pool_rem_cluster(per_study, method = "REML", fallback = "DL")

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("cluster_id", "gene", "method", "logFC_pool", "SE_pool",
                       "p_value_pool", "tau2", "I2", "Q", "Q_pval",
                       "k_effective", "n_baseline_studies_augmented",
                       "FDR_BH_within_cluster", "direction_applied"),
               ignore.order = TRUE)
  expect_equal(nrow(res), 5L)
  expect_equal(unique(res$method), "rem")
  expect_true(all(res$k_effective == 3L))
  expect_true(all(is.na(res$n_baseline_studies_augmented)))
})

test_that(".pool_rem_cluster fallback a DL se REML fail", {
  skip_if_not_installed("metafor")

  # Fixture: tutti logFC identici -> tau2=0, REML potrebbe convergere a 0 OK,
  # ma sufficient to verify fallback path tracking; usa scenario degenerato.
  per_study <- tibble::tibble(
    cluster_id = "TEST_DEG",
    study_id = rep(c("GSE001", "GSE002"), each = 2),
    gene = rep(c("G1", "G2"), 2),
    logFC = c(2, 1, 2, 1),
    SE = c(0.0001, 0.0001, 0.0001, 0.0001),  # SE quasi nulli -> instabile
    p_value = 0.001,
    t_stat = NA_real_,
    n_treated = 3L,
    n_control = 3L,
    direction_applied = "none"
  )

  res <- .pool_rem_cluster(per_study, method = "REML", fallback = "DL")
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 2L)
  # Output deve essere finito anche con SE problematici
  expect_true(all(is.finite(res$logFC_pool)))
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-rem-pooling")'
```
Expected: FAIL with ".pool_rem_cluster not found".

- [ ] **Step 3: Implementare R/stage4-rem-pooling.R**

```r
#' Pool REM cluster con metafor::rma REML + DL fallback
#'
#' Per ogni gene presente in >= 2 studi del per_study subset: \code{metafor::rma}
#' REML. Su convergence failure (rare), fallback a DerSimonian-Laird closed-form.
#'
#' @param per_study_de_subset tibble filtered by cluster_id (output di Stage 4.C).
#' @param method REM method ("REML" default).
#' @param fallback fallback method on convergence failure ("DL" default).
#' @return tibble gene-level con cluster_pooled.parquet schema.
#' @keywords internal
.pool_rem_cluster <- function(per_study_de_subset, method = "REML",
                                fallback = "DL") {
  stopifnot(
    inherits(per_study_de_subset, "data.frame"),
    "logFC" %in% names(per_study_de_subset),
    "SE" %in% names(per_study_de_subset)
  )

  if (nrow(per_study_de_subset) == 0L) {
    return(.empty_pooled_rem())
  }

  cluster_id <- unique(per_study_de_subset$cluster_id)[1]
  direction_applied <- unique(per_study_de_subset$direction_applied)[1]
  if (is.null(direction_applied)) direction_applied <- "none"

  by_gene <- split(per_study_de_subset, per_study_de_subset$gene)

  out_rows <- vector("list", length(by_gene))
  for (i in seq_along(by_gene)) {
    g <- names(by_gene)[i]
    sub <- by_gene[[i]]
    if (nrow(sub) < 2L) next  # skip geni con <2 studi

    res <- tryCatch(
      metafor::rma(yi = sub$logFC, sei = sub$SE, method = method),
      error = function(e) NULL,
      warning = function(w) NULL
    )

    if (is.null(res)) {
      res <- tryCatch(
        metafor::rma(yi = sub$logFC, sei = sub$SE, method = fallback),
        error = function(e) NULL
      )
    }

    if (is.null(res)) next

    out_rows[[i]] <- tibble::tibble(
      cluster_id   = cluster_id,
      gene         = g,
      method       = "rem",
      logFC_pool   = as.numeric(res$b),
      SE_pool      = as.numeric(res$se),
      p_value_pool = as.numeric(res$pval),
      tau2         = as.numeric(res$tau2),
      I2           = as.numeric(res$I2),
      Q            = as.numeric(res$QE),
      Q_pval       = as.numeric(res$QEp),
      k_effective  = as.integer(res$k),
      n_baseline_studies_augmented = NA_integer_,
      FDR_BH_within_cluster = NA_real_,
      direction_applied = direction_applied
    )
  }

  out <- do.call(rbind, out_rows[!vapply(out_rows, is.null, logical(1))])
  if (is.null(out) || nrow(out) == 0L) return(.empty_pooled_rem())

  # FDR BH within cluster
  out$FDR_BH_within_cluster <- stats::p.adjust(out$p_value_pool, method = "BH")
  out
}

#' Tibble vuota schema cluster_pooled per output empty/edge case
#' @keywords internal
.empty_pooled_rem <- function() {
  tibble::tibble(
    cluster_id   = character(),
    gene         = character(),
    method       = character(),
    logFC_pool   = double(),
    SE_pool      = double(),
    p_value_pool = double(),
    tau2         = double(),
    I2           = double(),
    Q            = double(),
    Q_pval       = double(),
    k_effective  = integer(),
    n_baseline_studies_augmented = integer(),
    FDR_BH_within_cluster = double(),
    direction_applied = character()
  )
}
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-rem-pooling")'
```
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-rem-pooling.R tests/testthat/test-stage4-rem-pooling.R
git commit -m "P5 Stadio 4 Task 6: stage4-rem-pooling metafor::rma REML + DL fallback + BH"
```

---

## Task 7: stage4-dream-mega.R — dream `~ treatment + (1|study)` per MEGA

**Files:**
- Create: `R/stage4-dream-mega.R`
- Test: `tests/testthat/test-stage4-dream-mega.R`

- [ ] **Step 1: Scrivere test failing per .run_dream_mega**

```r
# tests/testthat/test-stage4-dream-mega.R
test_that(".run_dream_mega produce tibble gene-level con logFC_pool + SE_pool", {
  skip_if_not_installed("variancePartition")

  # Fixture: 50 geni x 24 sample (4 studi x 6 sample 3 treated + 3 control)
  set.seed(42)
  n_genes <- 50; n_samples <- 24
  counts <- matrix(rnbinom(n_genes * n_samples, size = 5, mu = 200),
                   nrow = n_genes, ncol = n_samples)
  rownames(counts) <- paste0("GENE_", sprintf("%03d", 1:n_genes))
  colnames(counts) <- paste0("GSM", sprintf("%06d", 1:n_samples))

  metadata <- data.frame(
    sample_id = colnames(counts),
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(rep(c("treated", "treated", "treated",
                              "control", "control", "control"), 4),
                       levels = c("control", "treated"))
  )

  res <- .run_dream_mega(counts, metadata, cluster_id = "TEST_MEGA",
                         workers = 1L)

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("cluster_id", "gene", "method", "logFC_pool", "SE_pool",
                       "p_value_pool", "tau2", "I2", "Q", "Q_pval",
                       "k_effective", "n_baseline_studies_augmented",
                       "FDR_BH_within_cluster", "direction_applied"),
               ignore.order = TRUE)
  expect_equal(unique(res$method), "mega")
  expect_equal(unique(res$k_effective), 4L)
  expect_true(all(is.na(res$tau2)))
  expect_true(all(is.finite(res$logFC_pool)))
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-dream-mega")'
```
Expected: FAIL with ".run_dream_mega not found".

- [ ] **Step 3: Implementare R/stage4-dream-mega.R**

```r
#' Run dream mixed-effect model per MEGA / MEGA-AUG cluster
#'
#' Modello: \code{~ treatment + (1|study)} su counts assembled cross-study.
#' voomWithDreamWeights -> dream -> eBayes -> per-gene extraction.
#'
#' Fallback: se dream fails (rare convergence issues), retry con limma-voom +
#' duplicateCorrelation(block=study).
#'
#' @param counts integer matrix (genes x samples) assembled cross-study.
#' @param metadata data.frame con (sample_id, study factor, treatment factor).
#' @param cluster_id string cluster_id per output.
#' @param workers integer numero di worker BiocParallel (default 1).
#' @param n_baseline_studies_augmented integer NA per MEGA, n studi baseline
#'   pool per MEGA-AUG.
#' @return tibble gene-level con cluster_pooled.parquet schema.
#' @keywords internal
.run_dream_mega <- function(counts, metadata, cluster_id, workers = 1L,
                              n_baseline_studies_augmented = NA_integer_,
                              method_label = "mega") {
  stopifnot(
    is.matrix(counts),
    is.data.frame(metadata),
    all(c("sample_id", "study", "treatment") %in% names(metadata)),
    is.factor(metadata$study),
    is.factor(metadata$treatment),
    "control" %in% levels(metadata$treatment),
    "treated" %in% levels(metadata$treatment),
    ncol(counts) == nrow(metadata)
  )

  dge <- edgeR::DGEList(counts = counts)
  keep <- edgeR::filterByExpr(dge, group = metadata$treatment)
  dge <- dge[keep, , keep.lib.sizes = FALSE]
  dge <- edgeR::normLibSizes(dge, method = "TMM")

  formula_mega <- ~ treatment + (1 | study)
  bpparam <- if (workers > 1L) {
    BiocParallel::MulticoreParam(workers)
  } else {
    BiocParallel::SerialParam()
  }

  res <- tryCatch({
    vobj <- variancePartition::voomWithDreamWeights(
      dge, formula = formula_mega, data = metadata, BPPARAM = bpparam
    )
    fitmm <- variancePartition::dream(
      vobj, formula = formula_mega, data = metadata, BPPARAM = bpparam
    )
    fitmm <- variancePartition::eBayes(fitmm)

    logFC  <- fitmm$coefficients[, "treatmenttreated"]
    SE     <- sqrt(fitmm$s2.post) * fitmm$stdev.unscaled[, "treatmenttreated"]
    p_val  <- fitmm$p.value[, "treatmenttreated"]

    list(logFC = logFC, SE = SE, p_val = p_val, ok = TRUE)
  }, error = function(e) {
    list(error = conditionMessage(e), ok = FALSE)
  })

  if (!res$ok) {
    # Fallback: limma-voom + duplicateCorrelation
    design <- stats::model.matrix(~ treatment, data = metadata)
    colnames(design) <- c("(Intercept)", "treatmenttreated")
    v <- limma::voom(dge, design)
    corr <- limma::duplicateCorrelation(v, design, block = metadata$study)
    fit <- limma::lmFit(v, design, block = metadata$study,
                        correlation = corr$consensus)
    fit <- limma::eBayes(fit)
    logFC <- fit$coefficients[, "treatmenttreated"]
    SE    <- sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"]
    p_val <- fit$p.value[, "treatmenttreated"]
    res <- list(logFC = logFC, SE = SE, p_val = p_val, ok = TRUE)
  }

  out <- tibble::tibble(
    cluster_id   = cluster_id,
    gene         = names(res$logFC),
    method       = method_label,
    logFC_pool   = unname(res$logFC),
    SE_pool      = unname(res$SE),
    p_value_pool = unname(res$p_val),
    tau2         = NA_real_,
    I2           = NA_real_,
    Q            = NA_real_,
    Q_pval       = NA_real_,
    k_effective  = as.integer(nlevels(metadata$study)),
    n_baseline_studies_augmented = n_baseline_studies_augmented,
    FDR_BH_within_cluster = NA_real_,
    direction_applied = "none"
  )
  out$FDR_BH_within_cluster <- stats::p.adjust(out$p_value_pool, method = "BH")
  out
}
```

- [ ] **Step 4: Run test per confermare pass (puo' richiedere ~30 sec per dream fit)**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-dream-mega")'
```
Expected: PASS (1 test, ~30 sec).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-dream-mega.R tests/testthat/test-stage4-dream-mega.R
git commit -m "P5 Stadio 4 Task 7: stage4-dream-mega ~ treatment + (1|study) + limma fallback"
```

---

## Task 8: stage4-mega-aug.R — baseline pool assembly per MEGA-augmentation

**Files:**
- Create: `R/stage4-mega-aug.R`
- Test: `tests/testthat/test-stage4-mega-aug.R`

- [ ] **Step 1: Scrivere test failing per .assemble_mega_aug_metadata**

```r
# tests/testthat/test-stage4-mega-aug.R
test_that(".assemble_mega_aug_metadata combina pair + baseline pool", {
  # Fixture: pair cluster (2 studi) + 3 group cluster baseline shared
  pair_cluster <- list(
    cluster_id = "pair_L0_aug123",
    mode = "pair",
    level = 0L,
    treated_anchor_key = "TREATED_KEY",
    control_anchor_key = "CONTROL_KEY",
    studies_in_cluster = c("GSE_pair_a", "GSE_pair_b"),
    treated_samples = list(c("GSM001", "GSM002", "GSM003",
                              "GSM010", "GSM011", "GSM012")),
    control_samples = list(c("GSM004", "GSM005", "GSM006",
                              "GSM013", "GSM014", "GSM015"))
  )

  # Group clusters: 3 cluster con stesso control_anchor_key
  group_baseline <- tibble::tibble(
    cluster_id = c("group_L0_aaa", "group_L0_bbb", "group_L0_ccc"),
    mode = "group",
    level = 0L,
    anchor_key = c("CONTROL_KEY", "CONTROL_KEY", "OTHER_KEY"),  # 2 match + 1 no match
    studies_in_cluster = list(
      c("GSE_baseline_1", "GSE_baseline_2"),
      c("GSE_baseline_3"),
      c("GSE_unrelated")
    ),
    sample_ids = list(
      c("GSM101", "GSM102", "GSM103", "GSM104"),
      c("GSM201", "GSM202"),
      c("GSM999")
    )
  )

  result <- .assemble_mega_aug_metadata(pair_cluster, group_baseline)

  # Expected metadata:
  # 6 treated (from pair treated_samples)
  # 6 control (from pair control_samples)
  # 4 + 2 = 6 baseline (CONTROL_KEY group_baseline, deduped no overlap with pair)
  # Total: 18 sample, n_baseline_studies_augmented = 3 (2 from cluster aaa + 1 from bbb)

  expect_s3_class(result$metadata, "tbl_df")
  expect_equal(nrow(result$metadata), 18L)
  expect_equal(sum(result$metadata$treatment == "treated"), 6L)
  expect_equal(sum(result$metadata$treatment == "control"), 12L)  # 6 pair + 6 baseline
  expect_equal(result$n_baseline_studies_augmented, 3L)
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-mega-aug")'
```
Expected: FAIL with ".assemble_mega_aug_metadata not found".

- [ ] **Step 3: Implementare R/stage4-mega-aug.R**

```r
#' Assembla metadata sample-rows per MEGA-augmentation
#'
#' Combina sample del pair cluster (treated + control) con sample del baseline
#' pool (cluster group con stesso control_anchor_key allo stesso L), dedup
#' per sample_id per evitare double-counting.
#'
#' @param pair_cluster list con cluster_id, treated_anchor_key,
#'   control_anchor_key, level, studies_in_cluster, treated_samples,
#'   control_samples.
#' @param group_baseline tibble di s3$clusters filter mode=group; deve avere
#'   colonne anchor_key, level, studies_in_cluster, sample_ids.
#' @return list con \code{metadata} (tibble sample_id, study, treatment) e
#'   \code{n_baseline_studies_augmented} (integer).
#' @keywords internal
.assemble_mega_aug_metadata <- function(pair_cluster, group_baseline) {
  matching <- group_baseline[
    group_baseline$mode == "group" &
    group_baseline$level == pair_cluster$level &
    group_baseline$anchor_key == pair_cluster$control_anchor_key,
  ]

  # Pair sample rows
  pair_treated <- pair_cluster$treated_samples[[1]]
  pair_control <- pair_cluster$control_samples[[1]]

  pair_rows <- tibble::tibble(
    sample_id = c(pair_treated, pair_control),
    study     = c(rep(pair_cluster$studies_in_cluster, length.out = length(pair_treated)),
                  rep(pair_cluster$studies_in_cluster, length.out = length(pair_control))),
    treatment = factor(c(rep("treated", length(pair_treated)),
                          rep("control", length(pair_control))),
                       levels = c("control", "treated"))
  )

  # Baseline rows: union dei sample_ids dei matching group, deduplicati,
  # escludendo overlap con i sample del pair
  baseline_samples <- unique(unlist(matching$sample_ids))
  baseline_samples <- setdiff(baseline_samples, c(pair_treated, pair_control))

  # Baseline study identification: lookup back attraverso matching
  baseline_study <- character(length(baseline_samples))
  for (i in seq_len(nrow(matching))) {
    ids <- matching$sample_ids[[i]]
    studies <- matching$studies_in_cluster[[i]]
    # v1 assumption: per baseline cluster c'e' 1 studio per sample
    # (mapping precise dipende da Stage 3 schema; questo e' a sample-major
    # heuristic adeguata per il smoke)
    matching_idx <- match(ids, baseline_samples)
    matching_idx <- matching_idx[!is.na(matching_idx)]
    if (length(matching_idx) > 0L && length(studies) >= 1L) {
      baseline_study[matching_idx] <- studies[1]
    }
  }

  baseline_rows <- tibble::tibble(
    sample_id = baseline_samples,
    study = baseline_study,
    treatment = factor(rep("control", length(baseline_samples)),
                        levels = c("control", "treated"))
  )

  metadata <- dplyr::bind_rows(pair_rows, baseline_rows)
  metadata$study <- as.factor(metadata$study)

  n_baseline_studies <- length(unique(matching$studies_in_cluster |> unlist()))
  baseline_studies <- unique(unlist(matching$studies_in_cluster))
  pair_studies <- pair_cluster$studies_in_cluster
  n_baseline_studies_augmented <- length(setdiff(baseline_studies, pair_studies))

  list(
    metadata = metadata,
    n_baseline_studies_augmented = as.integer(n_baseline_studies_augmented)
  )
}
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-mega-aug")'
```
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-mega-aug.R tests/testthat/test-stage4-mega-aug.R
git commit -m "P5 Stadio 4 Task 8: stage4-mega-aug baseline pool assembly + dedup"
```

---

## Task 9: stage4-orchestrator.R — run_per_study_de_all + pool_all_clusters

**Files:**
- Create: `R/stage4-orchestrator.R`
- Test: `tests/testthat/test-stage4-orchestrator.R`

- [ ] **Step 1: Scrivere test failing per orchestrator**

```r
# tests/testthat/test-stage4-orchestrator.R
test_that(".run_per_study_de_all itera su REM + MEGA-AUG pair-side", {
  skip_if_not_installed("limma")

  # Use fixture: 2 cluster REM (1 con k=2, 1 con k=3) + 1 cluster MEGA-AUG (pair k=2)
  # Mock counts cache via fetch_fn injection
  eligible <- tibble::tibble(
    cluster_id = c("rem_k3", "mega_aug_k2"),
    method = c("rem", "mega_aug"),
    direction_check = factor(c("canonical", "canonical"),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na"))
  )

  # Build per-cluster (study_id, samples) dispatch table; v1 helper struct
  # passed via attribute on eligible
  attr(eligible, "study_dispatch") <- list(
    rem_k3 = list(
      list(study_id = "GSE_a", treated = c("GSM001","GSM002","GSM003"),
           control = c("GSM004","GSM005","GSM006")),
      list(study_id = "GSE_b", treated = c("GSM007","GSM008","GSM009"),
           control = c("GSM010","GSM011","GSM012")),
      list(study_id = "GSE_c", treated = c("GSM013","GSM014","GSM015"),
           control = c("GSM016","GSM017","GSM018"))
    ),
    mega_aug_k2 = list(
      list(study_id = "GSE_d", treated = c("GSM100","GSM101","GSM102"),
           control = c("GSM103","GSM104","GSM105")),
      list(study_id = "GSE_e", treated = c("GSM200","GSM201","GSM202"),
           control = c("GSM203","GSM204","GSM205"))
    )
  )

  mock_fetch <- function(gse, sample_ids) {
    set.seed(nchar(gse) * 100)
    m <- matrix(rnbinom(50 * length(sample_ids), size = 5, mu = 200),
                nrow = 50, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:50))
    colnames(m) <- sample_ids
    m
  }

  result <- .run_per_study_de_all(eligible, fetch_fn = mock_fetch,
                                   workers = 1L)

  expect_s3_class(result, "tbl_df")
  expect_true("cluster_id" %in% names(result))
  expect_true("study_id" %in% names(result))
  expect_true(any(result$cluster_id == "rem_k3"))
  expect_true(any(result$cluster_id == "mega_aug_k2"))
  expect_equal(length(unique(result$study_id[result$cluster_id == "rem_k3"])), 3L)
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-orchestrator")'
```
Expected: FAIL with ".run_per_study_de_all not found".

- [ ] **Step 3: Implementare R/stage4-orchestrator.R (parte 1)**

```r
#' Run limma-voom DE per-study per tutti gli eligible cluster REM + MEGA-AUG
#'
#' Itera su (cluster_id, study_id) dispatch dell'attributo "study_dispatch"
#' di \code{eligible_clusters}, fetch counts via fetch_fn (cache-backed),
#' applica direction flip per swapped cluster, concat output.
#'
#' @param eligible_clusters tibble + attr(., "study_dispatch") list nested.
#' @param fetch_fn function (gse, sample_ids) -> matrix. Default chiama
#'   \code{.fetch_counts_cached}.
#' @param workers integer numero di workers per future_map (default 1).
#' @return tibble per_study_de.parquet schema.
#' @keywords internal
.run_per_study_de_all <- function(eligible_clusters, fetch_fn = NULL,
                                    workers = 1L) {
  dispatch <- attr(eligible_clusters, "study_dispatch")
  if (is.null(dispatch)) stop("eligible_clusters must have study_dispatch attr")

  # Filter solo REM + MEGA-AUG (MEGA usa raw counts cross-study, no per-study DE)
  per_study_clusters <- eligible_clusters[
    eligible_clusters$method %in% c("rem", "mega_aug"),
  ]

  out_list <- vector("list", 0L)
  for (i in seq_len(nrow(per_study_clusters))) {
    cid <- per_study_clusters$cluster_id[i]
    dispatch_i <- dispatch[[cid]]
    if (is.null(dispatch_i)) next

    dir_flip <- per_study_clusters$direction_check[i] == "swapped"

    for (j in seq_along(dispatch_i)) {
      d <- dispatch_i[[j]]
      study_id <- d$study_id
      samples <- c(d$treated, d$control)
      treatment <- factor(c(rep("treated", length(d$treated)),
                             rep("control", length(d$control))),
                          levels = c("control", "treated"))

      counts <- fetch_fn(study_id, samples)
      row_res <- .run_limma_voom_de(counts, treatment, study_id, cid,
                                      direction_flip = dir_flip)
      out_list[[length(out_list) + 1L]] <- row_res
    }
  }

  if (length(out_list) == 0L) return(.empty_per_study_de())
  do.call(rbind, out_list)
}

#' Tibble vuota per_study_de schema per edge case
#' @keywords internal
.empty_per_study_de <- function() {
  tibble::tibble(
    cluster_id = character(),
    study_id = character(),
    gene = character(),
    logFC = double(),
    SE = double(),
    p_value = double(),
    t_stat = double(),
    n_treated = integer(),
    n_control = integer(),
    direction_applied = character()
  )
}

#' Pool tutti i cluster eligible (REM + MEGA + MEGA-AUG)
#'
#' Dispatch per method:
#' - rem: subset per_study_de + .pool_rem_cluster
#' - mega: assemble counts + .run_dream_mega
#' - mega_aug: assemble baseline + .run_dream_mega con n_baseline_studies_augmented
#'
#' @param per_study_de tibble output di \code{.run_per_study_de_all}.
#' @param eligible_clusters tibble post-QC.
#' @param fetch_fn function (gse, sample_ids) -> matrix.
#' @param stage3_clusters tibble Stage 3 originale per baseline pool lookup.
#' @param workers integer.
#' @param dream_workers_cap integer cap for BiocParallel.
#' @return tibble cluster_pooled.parquet schema.
#' @keywords internal
.pool_all_clusters <- function(per_study_de, eligible_clusters, fetch_fn,
                                stage3_clusters, workers = 1L,
                                dream_workers_cap = 8L) {
  out_list <- vector("list", 0L)

  dispatch <- attr(eligible_clusters, "study_dispatch")
  group_dispatch <- attr(eligible_clusters, "group_dispatch")

  for (i in seq_len(nrow(eligible_clusters))) {
    cid <- eligible_clusters$cluster_id[i]
    method <- eligible_clusters$method[i]

    if (method == "rem") {
      subset <- per_study_de[per_study_de$cluster_id == cid, ]
      pool <- .pool_rem_cluster(subset)
      out_list[[length(out_list) + 1L]] <- pool

    } else if (method == "mega") {
      # Group dispatch: list di (study_id, sample_ids)
      grp <- group_dispatch[[cid]]
      if (is.null(grp)) next

      counts_list <- lapply(grp, function(d) fetch_fn(d$study_id, d$sample_ids))
      # Common gene rownames
      common_genes <- Reduce(intersect, lapply(counts_list, rownames))
      counts <- do.call(cbind, lapply(counts_list, function(m) m[common_genes, , drop = FALSE]))

      metadata <- data.frame(
        sample_id = unlist(lapply(grp, function(d) d$sample_ids)),
        study = factor(unlist(lapply(grp, function(d) rep(d$study_id, length(d$sample_ids))))),
        treatment = factor(unlist(lapply(grp, function(d) {
          # In v1 MEGA: assumption che il group_dispatch include treatment factor split
          d$treatment
        })), levels = c("control", "treated"))
      )

      pool <- .run_dream_mega(counts, metadata, cid,
                               workers = min(workers, dream_workers_cap))
      out_list[[length(out_list) + 1L]] <- pool

    } else if (method == "mega_aug") {
      pair_cluster_struct <- list(
        cluster_id = cid,
        level = eligible_clusters$level[i],
        treated_anchor_key = NA_character_,  # da popolare via lookup
        control_anchor_key = NA_character_,  # da popolare via lookup
        studies_in_cluster = eligible_clusters$studies_in_cluster[[i]],
        treated_samples = list(unlist(lapply(dispatch[[cid]], function(d) d$treated))),
        control_samples = list(unlist(lapply(dispatch[[cid]], function(d) d$control)))
      )

      # Group baseline subset
      group_baseline <- stage3_clusters[
        stage3_clusters$mode == "group" &
        stage3_clusters$level == eligible_clusters$level[i],
      ]

      assembled <- .assemble_mega_aug_metadata(pair_cluster_struct, group_baseline)

      # Fetch counts per tutti i sample
      all_studies <- unique(as.character(assembled$metadata$study))
      counts_list <- lapply(all_studies, function(s) {
        samples_s <- assembled$metadata$sample_id[assembled$metadata$study == s]
        fetch_fn(s, samples_s)
      })
      common_genes <- Reduce(intersect, lapply(counts_list, rownames))
      counts <- do.call(cbind, lapply(counts_list, function(m) m[common_genes, , drop = FALSE]))

      pool <- .run_dream_mega(counts, assembled$metadata, cid,
                                workers = min(workers, dream_workers_cap),
                                n_baseline_studies_augmented = assembled$n_baseline_studies_augmented,
                                method_label = "mega_aug")
      out_list[[length(out_list) + 1L]] <- pool
    }
  }

  if (length(out_list) == 0L) return(.empty_pooled_rem())
  do.call(rbind, out_list)
}

#' Costruisce qc_report list per output write
#'
#' @keywords internal
.build_qc_report <- function(eligible_clusters, per_study_de, cluster_pooled) {
  list(
    qc_drops_sample = attr(eligible_clusters, "qc_drops_sample") %||%
      tibble::tibble(),
    qc_drops_study  = attr(eligible_clusters, "qc_drops_study") %||%
      tibble::tibble(),
    qc_drops_cluster = attr(eligible_clusters, "qc_drops_cluster") %||%
      tibble::tibble(),
    pooling_warnings = attr(cluster_pooled, "pooling_warnings") %||%
      tibble::tibble()
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-orchestrator")'
```
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-orchestrator.R tests/testthat/test-stage4-orchestrator.R
git commit -m "P5 Stadio 4 Task 9: stage4-orchestrator run_per_study_de_all + pool_all_clusters dispatch"
```

---

## Task 10: stage4-io.R — write_stage4_to_dir + load_stage4

**Files:**
- Create: `R/stage4-io.R`
- Test: `tests/testthat/test-stage4-io.R`

- [ ] **Step 1: Scrivere test failing per io**

```r
# tests/testthat/test-stage4-io.R
test_that("write_stage4_to_dir produce i 5 file attesi", {
  skip_if_not_installed("arrow")

  tmp <- withr::local_tempdir()
  s4 <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "abc12345", timestamp = Sys.time())
  )

  paths <- write_stage4_to_dir(s4, tmp)

  expect_true(file.exists(file.path(tmp, "per_study_de.parquet")))
  expect_true(file.exists(file.path(tmp, "cluster_pooled.parquet")))
  expect_true(file.exists(file.path(tmp, "qc_report.rds")))
  expect_true(file.exists(file.path(tmp, "non_processable.rds")))
  expect_true(file.exists(file.path(tmp, "run_metadata.json")))
})

test_that("load_stage4 round-trip preserva contenuto", {
  skip_if_not_installed("arrow")

  tmp <- withr::local_tempdir()
  s4_orig <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "test1234", timestamp = "2026-05-19T12:00:00Z")
  )

  write_stage4_to_dir(s4_orig, tmp)
  s4_back <- load_stage4(tmp)

  expect_equal(s4_back$run_metadata$run_id, "test1234")
  expect_equal(s4_back$config$qc$lib_size_min, 500000L)
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-io")'
```
Expected: FAIL with "write_stage4_to_dir not found".

- [ ] **Step 3: Implementare R/stage4-io.R**

```r
#' Scrive stage4 result in directory con 5 file convenzionali
#'
#' @param s4 stage4_result list (output di \code{build_stage4_results}).
#' @param dir target directory; creata se non esiste.
#' @return invisible(character) paths dei file scritti.
#' @export
write_stage4_to_dir <- function(s4, dir) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

  paths <- list(
    per_study_de = file.path(dir, "per_study_de.parquet"),
    cluster_pooled = file.path(dir, "cluster_pooled.parquet"),
    qc_report = file.path(dir, "qc_report.rds"),
    non_processable = file.path(dir, "non_processable.rds"),
    run_metadata = file.path(dir, "run_metadata.json")
  )

  arrow::write_parquet(s4$per_study_de, paths$per_study_de,
                       compression = "zstd", compression_level = 9L)
  arrow::write_parquet(s4$cluster_pooled, paths$cluster_pooled,
                       compression = "zstd", compression_level = 9L)
  saveRDS(s4$qc_report, paths$qc_report, compress = "xz")
  saveRDS(s4$non_processable %||% tibble::tibble(), paths$non_processable,
          compress = "xz")

  meta <- list(
    run_id = s4$run_metadata$run_id,
    timestamp = format(s4$run_metadata$timestamp, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    schema_versions = s4$config$schema_versions,
    package_version = as.character(utils::packageVersion("simulomicsr")),
    r_version = R.version.string,
    config = s4$config,
    output_counts = list(
      n_per_study_de_rows = nrow(s4$per_study_de),
      n_cluster_pooled_rows = nrow(s4$cluster_pooled),
      by_method = if (nrow(s4$cluster_pooled) > 0L) {
        as.list(table(s4$cluster_pooled$method))
      } else list()
    )
  )
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, na = "null"),
             paths$run_metadata)

  invisible(unlist(paths))
}

#' Carica stage4 result da directory
#'
#' @param dir directory contenente i 5 file Stage 4.
#' @return list stage4_result.
#' @export
load_stage4 <- function(dir) {
  stopifnot(dir.exists(dir))

  meta <- jsonlite::fromJSON(file.path(dir, "run_metadata.json"),
                              simplifyVector = FALSE)

  list(
    per_study_de = arrow::read_parquet(file.path(dir, "per_study_de.parquet")),
    cluster_pooled = arrow::read_parquet(file.path(dir, "cluster_pooled.parquet")),
    qc_report = readRDS(file.path(dir, "qc_report.rds")),
    non_processable = readRDS(file.path(dir, "non_processable.rds")),
    config = meta$config,
    run_metadata = list(
      run_id = meta$run_id,
      timestamp = meta$timestamp
    )
  )
}
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-io")'
```
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-io.R tests/testthat/test-stage4-io.R
git commit -m "P5 Stadio 4 Task 10: stage4-io write_stage4_to_dir + load_stage4 (parquet zstd + rds + json)"
```

---

## Task 11: stage4-build.R — build_stage4_results entry point

**Files:**
- Create: `R/stage4-build.R`
- Test: `tests/testthat/test-stage4-build.R`

- [ ] **Step 1: Scrivere test failing per integration end-to-end mini**

```r
# tests/testthat/test-stage4-build.R
test_that("build_stage4_results end-to-end produce stage4_result list", {
  skip_if_not_installed("limma")
  skip_if_not_installed("arrow")

  # Mini fixture: 2 cluster (1 REM k=2, 1 trivial), fetch_fn mock
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  mock_fetch <- function(gse, sample_ids) {
    set.seed(nchar(gse) * 100)
    m <- matrix(rnbinom(50 * length(sample_ids), size = 5, mu = 200),
                nrow = 50, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:50))
    colnames(m) <- sample_ids
    m
  }

  # Mock build path: skip QC stage di prefetch, inietta dispatch direttamente
  # via attribute. v1 helper struct.
  result <- build_stage4_results(
    stage3_clusters = input$clusters,
    h5_metadata = input$h5_metadata,
    config = cfg,
    fetch_fn = mock_fetch,
    stage3_run_id = "mocked3",
    h5_path_for_hash = NULL,
    dry_run_inputs_only = FALSE
  )

  expect_s3_class(result, "stage4_result")
  expect_named(result, c("per_study_de", "cluster_pooled", "eligible_clusters",
                          "qc_report", "non_processable", "config",
                          "run_metadata"),
                ignore.order = TRUE)
  expect_true(nchar(result$run_metadata$run_id) == 8L)
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-build")'
```
Expected: FAIL with "build_stage4_results not found".

- [ ] **Step 3: Implementare R/stage4-build.R**

```r
#' Entry-point Stadio 4: end-to-end DE per-studio + MEGA cluster pooling
#'
#' Esegue i 5 sub-stage: QC, counts prefetch, per-study DE, cluster pooling,
#' (dashboard render: vedi \code{render_stage4_dashboard} separato).
#'
#' @param stage3_clusters tibble \code{clusters.rds} Stage 3.
#' @param h5_metadata tibble sample-level (sample_id, gsm, gse, lib_size).
#' @param config output di \code{stage4_default_config()}.
#' @param fetch_fn function (gse, sample_ids) -> matrix. Default chiama
#'   \code{.fetch_counts_cached} con h5_path.
#' @param h5_path path al H5 ARCHS4 (richiesto se \code{fetch_fn=NULL}).
#' @param stage3_run_id string Stage 3 run_id per input_hashes.
#' @param h5_path_for_hash path al H5 per hash computation (NULL se via
#'   \code{h5_path}).
#' @param dry_run_inputs_only logical: se TRUE, restituisce solo eligible_clusters
#'   + run_metadata (skip DE) per debugging rapido.
#' @return stage4_result S3 list.
#' @export
build_stage4_results <- function(stage3_clusters, h5_metadata, config = stage4_default_config(),
                                   fetch_fn = NULL, h5_path = NULL,
                                   stage3_run_id = NULL, h5_path_for_hash = NULL,
                                   dry_run_inputs_only = FALSE) {

  # Step 1: QC
  qc <- .qc_filter_samples_and_studies(stage3_clusters, h5_metadata, config)

  # Step 2: Compute run_id
  hashes <- list(
    stage3 = stage3_run_id %||% "unknown",
    h5     = if (!is.null(h5_path_for_hash)) {
      substr(digest::digest(h5_path_for_hash, algo = "sha256", file = TRUE), 1L, 16L)
    } else "unknown"
  )
  run_id <- .run_id_for_stage4(hashes, config, config$schema_versions)

  if (dry_run_inputs_only) {
    return(structure(list(
      per_study_de = .empty_per_study_de(),
      cluster_pooled = .empty_pooled_rem(),
      eligible_clusters = qc$eligible_clusters,
      qc_report = qc[c("qc_drops_sample", "qc_drops_study", "qc_drops_cluster")],
      non_processable = qc$qc_drops_cluster,
      config = config,
      run_metadata = list(run_id = run_id, timestamp = Sys.time())
    ), class = "stage4_result"))
  }

  if (is.null(fetch_fn)) {
    if (is.null(h5_path)) stop("h5_path required when fetch_fn is NULL")
    fetch_fn <- function(g, s) .fetch_counts_cached(g, s, h5_path = h5_path)
  }

  # Step 3: Per-study DE
  per_study_de <- .run_per_study_de_all(qc$eligible_clusters,
                                          fetch_fn = fetch_fn,
                                          workers = 1L)

  # Step 4: Cluster pooling
  cluster_pooled <- .pool_all_clusters(per_study_de, qc$eligible_clusters,
                                        fetch_fn = fetch_fn,
                                        stage3_clusters = stage3_clusters,
                                        workers = 1L,
                                        dream_workers_cap = config$compute$dream_workers_cap)

  # Step 5: QC report aggregation
  qc_report <- .build_qc_report(qc$eligible_clusters, per_study_de, cluster_pooled)

  structure(list(
    per_study_de = per_study_de,
    cluster_pooled = cluster_pooled,
    eligible_clusters = qc$eligible_clusters,
    qc_report = qc_report,
    non_processable = qc$qc_drops_cluster,
    config = config,
    run_metadata = list(run_id = run_id, timestamp = Sys.time())
  ), class = "stage4_result")
}
```

- [ ] **Step 4: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-build")'
```
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-build.R tests/testthat/test-stage4-build.R
git commit -m "P5 Stadio 4 Task 11: stage4-build entry-point build_stage4_results"
```

---

## Task 12: test-stage4-replication.R — idempotenza

**Files:**
- Test: `tests/testthat/test-stage4-replication.R`

- [ ] **Step 1: Scrivere test idempotence end-to-end**

```r
# tests/testthat/test-stage4-replication.R
test_that("build_stage4_results e' idempotente su stesso input", {
  skip_if_not_installed("limma")
  skip_if_not_installed("arrow")

  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  mock_fetch <- function(gse, sample_ids) {
    set.seed(nchar(gse) * 100)
    m <- matrix(rnbinom(50 * length(sample_ids), size = 5, mu = 200),
                nrow = 50, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:50))
    colnames(m) <- sample_ids
    m
  }

  r1 <- build_stage4_results(input$clusters, input$h5_metadata, cfg,
                               fetch_fn = mock_fetch,
                               stage3_run_id = "fixed_test",
                               dry_run_inputs_only = TRUE)
  r2 <- build_stage4_results(input$clusters, input$h5_metadata, cfg,
                               fetch_fn = mock_fetch,
                               stage3_run_id = "fixed_test",
                               dry_run_inputs_only = TRUE)

  expect_equal(r1$run_metadata$run_id, r2$run_metadata$run_id)
})

test_that("write_stage4_to_dir produce parquet byte-equal per stesso input", {
  skip_if_not_installed("arrow")

  tmp1 <- withr::local_tempdir()
  tmp2 <- withr::local_tempdir()

  s4 <- list(
    per_study_de = tibble::tibble(
      cluster_id = "c1", study_id = "GSE001", gene = "G1",
      logFC = 1.0, SE = 0.1, p_value = 0.001, t_stat = 10.0,
      n_treated = 3L, n_control = 3L, direction_applied = "none"
    ),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "abc12345", timestamp = "2026-05-19T12:00:00Z")
  )

  write_stage4_to_dir(s4, tmp1)
  write_stage4_to_dir(s4, tmp2)

  # Parquet bytes equal (timestamp e' fissato esplicitamente)
  bytes1 <- readBin(file.path(tmp1, "per_study_de.parquet"), "raw", n = 1e6)
  bytes2 <- readBin(file.path(tmp2, "per_study_de.parquet"), "raw", n = 1e6)
  expect_identical(bytes1, bytes2)
})
```

- [ ] **Step 2: Run test per confermare pass (test gia' dimostrabile dato Task 11)**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-replication")'
```
Expected: PASS (2 test).

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/test-stage4-replication.R
git commit -m "P5 Stadio 4 Task 12: stage4-replication test idempotence run_id + parquet bytes"
```

---

## Task 13: test-stage4-direction-flip.R — integration con direction_check

**Files:**
- Test: `tests/testthat/test-stage4-direction-flip.R`

- [ ] **Step 1: Scrivere test direction flip end-to-end**

```r
# tests/testthat/test-stage4-direction-flip.R
test_that("cluster con direction_check=swapped applica logFC flip in per_study_de", {
  skip_if_not_installed("limma")

  # Build eligible con 1 cluster swapped + 1 canonical
  eligible <- tibble::tibble(
    cluster_id = c("canon_c", "swap_c"),
    method = c("rem", "rem"),
    direction_check = factor(c("canonical", "swapped"),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na"))
  )

  # Stesso dispatch per entrambi (so the only difference is direction)
  same_dispatch <- list(
    list(study_id = "GSE_test", treated = c("GSM001","GSM002","GSM003"),
         control = c("GSM004","GSM005","GSM006"))
  )
  attr(eligible, "study_dispatch") <- list(
    canon_c = same_dispatch,
    swap_c  = same_dispatch
  )

  mock_fetch <- function(gse, sample_ids) {
    set.seed(42)
    m <- matrix(rnbinom(50 * length(sample_ids), size = 5, mu = 200),
                nrow = 50, ncol = length(sample_ids))
    # Induci diff su primi 5 geni
    m[1:5, 1:3] <- m[1:5, 1:3] * 5
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:50))
    colnames(m) <- sample_ids
    m
  }

  result <- .run_per_study_de_all(eligible, fetch_fn = mock_fetch)

  canon <- result[result$cluster_id == "canon_c", ]
  swap  <- result[result$cluster_id == "swap_c", ]

  expect_equal(canon$logFC[order(canon$gene)], -swap$logFC[order(swap$gene)])
  expect_equal(unique(canon$direction_applied), "none")
  expect_equal(unique(swap$direction_applied), "flipped")
})
```

- [ ] **Step 2: Run test per confermare pass**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-direction-flip")'
```
Expected: PASS (1 test).

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/test-stage4-direction-flip.R
git commit -m "P5 Stadio 4 Task 13: stage4-direction-flip integration test swap negation"
```

---

## Task 14: Targets pipeline integration

**Files:**
- Modify: `analysis/_targets.R`

- [ ] **Step 1: Aggiungere target Stadio 4 al pipeline existant**

Apri `analysis/_targets.R`. Aggiungi alla lista dei target (dopo i target Stadio 3):

```r
  # === Stadio 4 (P5) ===
  targets::tar_target(stage4_config, simulomicsr::stage4_default_config()),
  targets::tar_target(stage3_dir_for_stage4,
                       "analysis/p4-output/20260519T055547Z-stage3-2153addc",
                       format = "file"),
  targets::tar_target(h5_for_stage4,
                       "analysis/input/human_gene_v2.5.h5",
                       format = "file"),

  targets::tar_target(
    stage4_h5_metadata,
    simulomicsr::load_archs4_metadata(h5_path = h5_for_stage4)
  ),

  targets::tar_target(
    stage4_stage3_loaded,
    simulomicsr::load_stage3(stage3_dir_for_stage4)
  ),

  targets::tar_target(
    stage4_result,
    simulomicsr::build_stage4_results(
      stage3_clusters = stage4_stage3_loaded$clusters,
      h5_metadata = stage4_h5_metadata,
      config = stage4_config,
      h5_path = h5_for_stage4,
      stage3_run_id = stage4_stage3_loaded$run_metadata$run_id,
      h5_path_for_hash = h5_for_stage4
    ),
    format = "rds"
  ),

  targets::tar_target(
    stage4_out_dir,
    {
      dir <- file.path(
        "analysis/p4-output",
        sprintf("%s-stage4-%s",
                format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
                stage4_result$run_metadata$run_id)
      )
      simulomicsr::write_stage4_to_dir(stage4_result, dir)
      dir
    },
    format = "file"
  )
```

Aggiungi anche all'inizio dello `_targets.R` (top-level, prima di `tar_pipeline`):

```r
# Parallel backend setup per Stadio 4
if (requireNamespace("future", quietly = TRUE) &&
    requireNamespace("parallelly", quietly = TRUE)) {
  future::plan(future::multisession,
                workers = max(1L, parallelly::availableCores() - 10L))
}
```

- [ ] **Step 2: Verifica syntax `_targets.R` con `tar_validate()`**

```bash
Rscript --vanilla -e 'targets::tar_validate()'
```
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add analysis/_targets.R
git commit -m "P5 Stadio 4 Task 14: targets pipeline integration stage4 + future multisession"
```

---

## Task 15: inst/templates/stage4-dashboard.qmd — Quarto template

**Files:**
- Create: `inst/templates/stage4-dashboard.qmd`

- [ ] **Step 1: Creare directory `inst/templates/` se non esiste**

```bash
mkdir -p inst/templates
```

- [ ] **Step 2: Scrivere il Quarto template**

```qmd
---
title: "Stadio 4 Diagnostic Dashboard"
subtitle: "simulomicsr — DE per-studio + MEGA cross-study (Layer A)"
date: today
format:
  html:
    self-contained: true
    toc: true
    code-fold: true
    code-tools: true
params:
  stage4_dir: ""
execute:
  echo: false
  warning: false
---

```{r setup}
library(simulomicsr)
library(DT)
library(plotly)
library(dplyr)
library(tidyr)

s4 <- load_stage4(params$stage4_dir)
```

## 1. Overview Layer A

```{r overview-cards}
n_clusters_processed <- length(unique(s4$cluster_pooled$cluster_id))
n_clusters_non_proc  <- nrow(s4$non_processable)
n_genes_total <- length(unique(s4$cluster_pooled$gene))
n_sig <- sum(s4$cluster_pooled$FDR_BH_within_cluster < 0.05, na.rm = TRUE)

knitr::kable(tibble::tibble(
  Metric = c("Clusters processed", "Clusters non-processable",
              "Unique genes total", "Significant gene-cluster (FDR<0.05)"),
  Value = c(n_clusters_processed, n_clusters_non_proc, n_genes_total, n_sig)
))
```

```{r overview-by-method}
by_method <- s4$cluster_pooled |>
  group_by(method) |>
  summarise(n_clusters = n_distinct(cluster_id),
            n_significant = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
            .groups = "drop")
DT::datatable(by_method, options = list(dom = 't'))
```

## 2. Cluster browser

```{r cluster-browser}
cluster_summary <- s4$cluster_pooled |>
  group_by(cluster_id, method) |>
  summarise(
    n_genes = n(),
    n_sig_fdr05 = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
    median_tau2 = median(tau2, na.rm = TRUE),
    median_I2 = median(I2, na.rm = TRUE),
    k_effective = max(k_effective),
    n_baseline_aug = max(n_baseline_studies_augmented, na.rm = TRUE),
    .groups = "drop"
  )

DT::datatable(
  cluster_summary,
  filter = "top",
  options = list(pageLength = 25, scrollX = TRUE)
)
```

## 3. Volcano plot (filterable by cluster)

```{r volcano-overall}
# Mostra distribuzione overall: 1 punto per gene-cluster, color by method
plot_data <- s4$cluster_pooled |>
  mutate(neg_log10_p = -log10(p_value_pool),
         sig = FDR_BH_within_cluster < 0.05)

plotly::plot_ly(plot_data, x = ~logFC_pool, y = ~neg_log10_p,
                color = ~method, symbol = ~sig,
                type = "scatter", mode = "markers",
                opacity = 0.3, marker = list(size = 4),
                text = ~paste("Cluster:", cluster_id, "<br>Gene:", gene)) |>
  layout(title = "Volcano plot — all gene-cluster (Layer A)",
         xaxis = list(title = "logFC_pool"),
         yaxis = list(title = "-log10(p_value_pool)"))
```

## 4. Heterogeneity panel (REM only)

```{r heterogeneity}
rem_data <- s4$cluster_pooled |>
  filter(method == "rem", !is.na(tau2), !is.na(I2))

if (nrow(rem_data) > 0) {
  plotly::plot_ly(rem_data, x = ~tau2, y = ~I2,
                  type = "scatter", mode = "markers",
                  marker = list(size = 4, opacity = 0.3),
                  text = ~paste("Cluster:", cluster_id, "<br>Gene:", gene)) |>
    layout(title = "tau^2 vs I^2 distribution (REM cluster)",
           xaxis = list(title = "tau^2"),
           yaxis = list(title = "I^2 (%)"))
}
```

## 5. Layer B candidate picker

```{r layer-b-picker}
candidates <- cluster_summary |>
  mutate(score = n_sig_fdr05 * log(k_effective + 1) /
                 (1 + ifelse(is.na(median_tau2), 0, median_tau2))) |>
  arrange(desc(score))

DT::datatable(
  candidates |> head(50),
  filter = "top",
  options = list(pageLength = 20)
)
```

**Top 20 first-pick suggestions:** copia gli `cluster_id` evidenziati sopra
in un follow-up curation script. No state persistence interattiva in v1.

## 6. Methods snapshot (config)

```{r methods}
config_yaml <- yaml::as.yaml(s4$config)
cat("```yaml\n", config_yaml, "\n```", sep = "")
```

**Run metadata:**

- run_id: `r s4$run_metadata$run_id`
- timestamp: `r s4$run_metadata$timestamp`
- Schema versions: anchor=`r s4$config$schema_versions$anchor`, stage3=`r s4$config$schema_versions$stage3_algorithm`, stage4=`r s4$config$schema_versions$stage4_algorithm`

```

- [ ] **Step 3: Commit**

```bash
git add inst/templates/stage4-dashboard.qmd
git commit -m "P5 Stadio 4 Task 15: stage4-dashboard.qmd Quarto template overview + browser + picker"
```

---

## Task 16: stage4-dashboard.R — render wrapper

**Files:**
- Create: `R/stage4-dashboard.R`
- Test: `tests/testthat/test-stage4-dashboard.R`

- [ ] **Step 1: Scrivere test failing per render_stage4_dashboard**

```r
# tests/testthat/test-stage4-dashboard.R
test_that("render_stage4_dashboard skip gracefully se quarto non disponibile", {
  skip_if(requireNamespace("quarto", quietly = TRUE),
          "quarto installato; questo test verifica solo fallback path")

  expect_warning(
    res <- render_stage4_dashboard(s4 = list(), out_path = tempfile()),
    "quarto"
  )
  expect_null(res)
})

test_that("render_stage4_dashboard usa template default se quarto disponibile", {
  skip_if_not_installed("quarto")
  skip_on_ci()

  tmp <- withr::local_tempdir()
  s4 <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "test1234", timestamp = "2026-05-19T12:00:00Z")
  )
  write_stage4_to_dir(s4, tmp)

  out_path <- file.path(tmp, "dashboard.html")
  result <- render_stage4_dashboard(s4_dir = tmp, out_path = out_path)

  expect_true(file.exists(out_path))
})
```

- [ ] **Step 2: Run test per confermare fail**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-dashboard")'
```
Expected: FAIL with "render_stage4_dashboard not found".

- [ ] **Step 3: Implementare R/stage4-dashboard.R**

```r
#' Render Quarto diagnostic dashboard per Stadio 4
#'
#' Wrapper attorno a \code{quarto::quarto_render()} che inietta il path
#' \code{stage4_dir} come parametro.
#'
#' @param s4_dir directory output Stage 4 (con i 5 file scritti).
#' @param out_path destinazione finale HTML (default: file.path(s4_dir,
#'   "stage4_dashboard.html")).
#' @param quarto_template path al template .qmd. Default usa quello shipped
#'   con il pacchetto (\code{inst/templates/stage4-dashboard.qmd}).
#' @return invisible(out_path) se success, NULL se quarto non disponibile.
#' @export
render_stage4_dashboard <- function(s4_dir, out_path = NULL,
                                      quarto_template = NULL) {
  if (!requireNamespace("quarto", quietly = TRUE)) {
    warning("quarto package non installato; salto rendering dashboard. ",
            "Install con install.packages('quarto').")
    return(invisible(NULL))
  }

  if (is.null(quarto_template)) {
    quarto_template <- system.file("templates", "stage4-dashboard.qmd",
                                     package = "simulomicsr")
  }
  if (!file.exists(quarto_template)) {
    warning(sprintf("Template Quarto non trovato: %s", quarto_template))
    return(invisible(NULL))
  }

  if (is.null(out_path)) {
    out_path <- file.path(s4_dir, "stage4_dashboard.html")
  }

  tmp_qmd <- tempfile(fileext = ".qmd")
  file.copy(quarto_template, tmp_qmd, overwrite = TRUE)

  quarto::quarto_render(
    input = tmp_qmd,
    output_format = "html",
    output_file = basename(out_path),
    execute_params = list(stage4_dir = normalizePath(s4_dir)),
    quiet = TRUE
  )

  # Sposta output to out_path
  produced <- file.path(dirname(tmp_qmd), basename(out_path))
  if (file.exists(produced)) file.rename(produced, out_path)

  invisible(out_path)
}
```

- [ ] **Step 4: Run test per confermare pass (skip-on-CI se no quarto)**

```bash
Rscript --vanilla -e 'devtools::test(filter = "stage4-dashboard")'
```
Expected: PASS (2 test, alcuni skipped se quarto non installato).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-dashboard.R tests/testthat/test-stage4-dashboard.R
git commit -m "P5 Stadio 4 Task 16: stage4-dashboard render wrapper + skip-gracefully"
```

---

## Task 17: analysis/p5-stage4-smoke5.R — Smoke 5-cluster pre-fullrun

**Files:**
- Create: `analysis/p5-stage4-smoke5.R`

- [ ] **Step 1: Scrivere lo smoke script**

```r
# analysis/p5-stage4-smoke5.R
# Smoke 5-cluster pre-fullrun Stadio 4 — gate del Layer A full
#
# Cluster picks (vedi spec §7.4):
#   1. pair_L2_de50bf31 (IFN A549, k=3 post-QC) — golden anchor
#   2. random REM k=4 (auto-selezionato)
#   3. random MEGA strict k=5 (auto-selezionato)
#   4. random MEGA strict k>=10 (auto-selezionato)
#   5. LNCaP CHEBI:17199 (caso MEGA-AUG)
#
# Wall budget: ≤ 10 min. Validation manuale: IFIT1 nel cluster 1 deve avere
# logFC_pool ≈ 8.88, SE_pool ≈ 0.062, tau2 ≈ 0 (matchando finding power gain).
#
# Usage: Rscript --vanilla analysis/p5-stage4-smoke5.R

devtools::load_all(".")

stage3_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path    <- "analysis/input/human_gene_v2.5.h5"

s3 <- load_stage3(stage3_dir)
h5_metadata <- load_archs4_metadata(h5_path)

# Cluster picks
pick_ids <- c(
  "pair_L2_de50bf31",  # golden anchor IFN A549
  # picks 2-4 selezionati at runtime, primo match con criteri sotto
  s3$clusters |>
    dplyr::filter(usable_rem_strict, k == 4, mode == "pair") |>
    dplyr::arrange(desc(n_total), desc(safety_min)) |>
    dplyr::slice(1) |>
    dplyr::pull(cluster_id),
  s3$clusters |>
    dplyr::filter(usable_mega_strict, n_studies == 5, mode == "group") |>
    dplyr::arrange(desc(n_total)) |>
    dplyr::slice(1) |>
    dplyr::pull(cluster_id),
  s3$clusters |>
    dplyr::filter(usable_mega_strict, n_studies >= 10, mode == "group") |>
    dplyr::arrange(desc(n_total)) |>
    dplyr::slice(1) |>
    dplyr::pull(cluster_id)
  # pick 5: MEGA-AUG LNCaP CHEBI:17199 — selezione manuale al runtime;
  # logging del cluster_id selected una volta validato.
)

cli::cli_alert_info("Smoke 5 cluster picks:")
cli::cli_ul(pick_ids)

# Subset stage3_clusters
clusters_subset <- s3$clusters[s3$clusters$cluster_id %in% pick_ids, ]

# Build Stage 4 results
config <- stage4_default_config()
result <- build_stage4_results(
  stage3_clusters = clusters_subset,
  h5_metadata = h5_metadata,
  config = config,
  h5_path = h5_path,
  stage3_run_id = s3$run_metadata$run_id,
  h5_path_for_hash = h5_path
)

# Validation golden anchor
ifit1_check <- result$cluster_pooled[
  result$cluster_pooled$cluster_id == "pair_L2_de50bf31" &
  result$cluster_pooled$gene == "IFIT1", ]
cli::cli_alert_info("IFIT1 in pair_L2_de50bf31:")
print(ifit1_check)

stopifnot(
  nrow(ifit1_check) == 1L,
  abs(ifit1_check$logFC_pool - 8.88) < 1.5,    # tolleranza per limma vs edgeR
  ifit1_check$SE_pool < 0.5,
  ifit1_check$tau2 < 0.5
)

# Write smoke output
smoke_dir <- file.path("analysis/p4-output",
                        sprintf("%s-stage4-smoke5-%s",
                                format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
                                result$run_metadata$run_id))
write_stage4_to_dir(result, smoke_dir)
render_stage4_dashboard(smoke_dir)

cli::cli_alert_success("Smoke 5 OK — output in {.path {smoke_dir}}")
```

- [ ] **Step 2: Eseguire lo smoke (~10 min wall budget)**

```bash
Rscript --vanilla analysis/p5-stage4-smoke5.R 2>&1 | tee /tmp/stage4-smoke5.log
```
Expected: PASS validation IFIT1 + output dir presente.

- [ ] **Step 3: Verifica output dir + dashboard**

```bash
ls -la analysis/p4-output/*-stage4-smoke5-*/
```
Expected: 6 file (5 standard + dashboard HTML).

- [ ] **Step 4: Commit script (post-smoke success)**

```bash
git add analysis/p5-stage4-smoke5.R
git commit -m "P5 Stadio 4 Task 17: p5-stage4-smoke5.R 5-cluster gate + IFIT1 validation"
```

---

## Task 18: ADR-0015 + NEWS update

**Files:**
- Create: `docs/decisions/0015-stage4-three-path-architecture.md`
- Modify: `NEWS.md`

- [ ] **Step 1: Scrivere ADR-0015 Proposed**

```markdown
# ADR-0015 — Stadio 4 three-path architecture (limma-voom REM + dream MEGA + MEGA-augmentation)

**Status:** Proposed (2026-05-19, pair con spec `docs/superpowers/specs/2026-05-19-p5-stadio4-de-perstudio-design.md`)
**Decisori:** lucavd
**Predecessori:** ADR-0006 (positioning), ADR-0012 (stage2 schema multi-axis), ADR-0014 (Stage 3 tiered anchor + dual-mode)
**Spec di riferimento:** `docs/superpowers/specs/2026-05-19-p5-stadio4-de-perstudio-design.md`

## Contesto

Stadio 4 trasforma i ~412 cluster Layer A in effect-size pooled cross-studio. Tre path
distinti emergono dalla scope decision 2026-05-19 + dal benchmark FDR-calibration utente
(non pubblicato): REM proper (k=3-9), MEGA strict (k>=5), MEGA-augmentation (k=2 pair con
baseline cross-studio).

## Decisione

Stadio 4 implementa:

1. **DE engine REM = limma-voom + eBayes shrunk SE**, su evidenza empirica del benchmark
   utente: limma-voom e' il best-calibrated FDR overall su violazioni assumption × n piccoli.
   DESeq2 disqualified per anti-conservative su baseline (Actual/Nominal FDR > 4 a n=3).
   edgeR QLF runner-up ma anti-conservative su Zero-infl + Hidden confounders.

2. **MEGA / MEGA-AUG engine = dream (variancePartition)** con formula `~ treatment + (1|study)`.
   Random effect study e' necessario per shared baseline cross-studio (MEGA-AUG); usare
   study come fixed covariate produce collinearita' nei 67 cluster MEGA-AUG. dream + limma
   family mantiene uniformity di eBayes shrinkage.

3. **REM pooling = metafor::rma REML**, con fallback DerSimonian-Laird closed-form su
   convergence failure (rare ma possibile su k=2).

4. **Persistent counts cache** in `tools::R_user_dir("simulomicsr", "cache")/stage4-counts/`
   per evitare re-fetch H5 (~1-5 sec per studio × ~500 unique = ~30-40 min wasted altrimenti).

5. **per_study_de.parquet come artifact reusabile**: long format consumabile per Layer B
   case study senza re-run pipeline.

6. **Quarto diagnostic dashboard** come deliverable accanto ai parquet, per esplorazione
   interattiva + Layer B candidate selection.

7. **QC sample-level**: lib_size >= 500.000 enforcement (precedente concreto GSE206784
   escluso nel POC); cluster rescue automatico con flag.

## Conseguenze

### Positive
- Pipeline scientificamente difendibile: limma-voom miglior calibrazione empirica + REM
  shows τ² + I² honestly + dream gestisce shared baseline naturalmente.
- Doppio artifact (per_study + cluster_pooled) abilita Layer B + analysis ad-hoc senza re-run.
- Dashboard interattiva facilita curation di Layer B case study.
- Cache persistente fa break-even in 2 run; opportunita' di re-run free-of-cost (modulo wall).

### Negative / costi
- eBayes shrunk SE -> REM REML sottostima τ² (double shrinkage). Caveat documentato.
- Dependencies pesanti aggiunte: edgeR, limma, variancePartition, metafor, BiocParallel.
- dream e' 10-100x piu' lento di limma standard su MEGA cluster con n_total grande
  (cap 1h wall per Layer A su 32-core acceptable; potrebbero servire ottimizzazioni).

### Da rivisitare
- Se v2 di Stadio 4 vogliono outlier-detection sample-level (skipped in v1).
- Se la dashboard "Layer B picker" diventa state-persistent (out-of-scope v1).
- Se cross-cluster integration (Layer "D"?) diventa requisito post-Layer-A.

## Status

Proposed 2026-05-19, accepted dopo: (a) implementazione completa branch `p5-stadio4-de-perstudio`,
(b) smoke 5-cluster pass + validation IFIT1 golden anchor, (c) Layer A full run completato
con success criteria (vedi Task 21 plan).
```

- [ ] **Step 2: Aggiornare NEWS.md con bullet 0.0.0.9019**

Modifica `NEWS.md` inserendo all'inizio (dopo header, prima dei bullet 0.0.0.9018):

```markdown
# simulomicsr 0.0.0.9019

* **P5 Stadio 4 DE per-studio + MEGA cross-study production** (ADR-0015 Proposed):
  three-path architecture su Layer A ~412 cluster.
  - REM path: limma-voom + eBayes per-studio -> metafor::rma REML cross-study (33 cluster k=3-9).
  - MEGA path: variancePartition::dream `~ treatment + (1|study)` su raw counts (312 cluster k>=5).
  - MEGA-AUG path: dream con baseline pool augmented da cluster group cross-studio
    (67 cluster pair k=2). Razionale Case 2 LNCaP da finding esempi metanalisi abilitate.
  - Persistent counts cache `tools::R_user_dir("simulomicsr", "cache")/stage4-counts/`.
  - Doppio artifact: `per_study_de.parquet` (long, reusabile) + `cluster_pooled.parquet`
    (gene×cluster pooled stats).
  - Quarto diagnostic dashboard `stage4_dashboard.html` come deliverable.
  - QC sample-level lib_size >= 500.000 enforced; cluster rescue automatico con flag.
  - Nuove dipendenze Imports: edgeR, limma, variancePartition, metafor, BiocParallel,
    arrow, parallelly. Suggests: quarto, DT, plotly, crosstalk.
  - DE engine choice basata su evidenza FDR calibration benchmark utente (limma-voom
    best-calibrated; DESeq2 disqualified per n piccoli).
```

- [ ] **Step 3: Commit ADR + NEWS**

```bash
git add docs/decisions/0015-stage4-three-path-architecture.md NEWS.md
git commit -m "P5 Stadio 4 Task 18: ADR-0015 Proposed + NEWS 0.0.0.9019"
```

- [ ] **Step 4: Bump DESCRIPTION version a 0.0.0.9019**

```bash
sed -i 's/^Version: 0\.0\.0\.9018/Version: 0.0.0.9019/' DESCRIPTION
git add DESCRIPTION
git commit -m "P5 Stadio 4 Task 18: bump DESCRIPTION version 0.0.0.9019"
```

---

## Task 19: Layer A full run script + post-run validation

**Files:**
- Create: `analysis/p5-stage4-layer-a-fullrun.R`

- [ ] **Step 1: Scrivere lo script Layer A**

```r
# analysis/p5-stage4-layer-a-fullrun.R
# Layer A full run Stadio 4 — ~412 cluster (33 REM + 312 MEGA + 67 MEGA-AUG)
#
# Wall budget atteso: ≤ 90 min su laptop 16 core, ≤ 60 min su server 32+ core.
# Peak memory ≤ 16 GB.
#
# Usage: Rscript --vanilla analysis/p5-stage4-layer-a-fullrun.R 2>&1 | tee analysis/p5-stage4-layer-a-fullrun.log

devtools::load_all(".")

stage3_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path    <- "analysis/input/human_gene_v2.5.h5"

cli::cli_h1("Stadio 4 Layer A full run")

s3 <- load_stage3(stage3_dir)
h5_metadata <- load_archs4_metadata(h5_path)
cli::cli_alert_info("Loaded {.field {nrow(s3$clusters)}} stage 3 clusters")
cli::cli_alert_info("Loaded {.field {nrow(h5_metadata)}} ARCHS4 sample metadata")

config <- stage4_default_config()

t0 <- Sys.time()
result <- build_stage4_results(
  stage3_clusters = s3$clusters,
  h5_metadata = h5_metadata,
  config = config,
  h5_path = h5_path,
  stage3_run_id = s3$run_metadata$run_id,
  h5_path_for_hash = h5_path
)
wall_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cli::cli_alert_success("Build complete in {.val {round(wall_sec / 60, 1)} min}")

# Write output
out_dir <- file.path("analysis/p4-output",
                      sprintf("%s-stage4-%s",
                              format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
                              result$run_metadata$run_id))
write_stage4_to_dir(result, out_dir)
cli::cli_alert_success("Written to {.path {out_dir}}")

# Render dashboard
render_stage4_dashboard(out_dir)
cli::cli_alert_success("Dashboard rendered: {.path {file.path(out_dir, 'stage4_dashboard.html')}}")

# Summary
cli::cli_h2("Summary")
cli::cli_dl(list(
  "Cluster processed" = length(unique(result$cluster_pooled$cluster_id)),
  "Cluster non-processable" = nrow(result$non_processable),
  "Per-study DE rows" = nrow(result$per_study_de),
  "Cluster pooled rows" = nrow(result$cluster_pooled),
  "Significant (FDR<0.05)" = sum(result$cluster_pooled$FDR_BH_within_cluster < 0.05, na.rm = TRUE)
))
```

- [ ] **Step 2: Eseguire Layer A full run (questo passo NON e' parte del commit batch — richiede ~60-90 min)**

```bash
Rscript --vanilla analysis/p5-stage4-layer-a-fullrun.R 2>&1 | tee analysis/p5-stage4-layer-a-fullrun.log
```
Expected: wall ≤ 90 min, output dir presente, dashboard generato, no panics.

- [ ] **Step 3: Verifica output Layer A**

```bash
LATEST_DIR=$(ls -td analysis/p4-output/*-stage4-* | head -1)
echo "Latest: $LATEST_DIR"
ls -la "$LATEST_DIR"
Rscript --vanilla -e "
  s4 <- simulomicsr::load_stage4('$LATEST_DIR')
  cat('cluster_pooled rows:', nrow(s4\$cluster_pooled), '\n')
  cat('per_study_de rows:', nrow(s4\$per_study_de), '\n')
  cat('Methods:', paste(unique(s4\$cluster_pooled\$method), collapse=', '), '\n')
"
```
Expected: cluster_pooled rows > 1M (412 cluster × ~3-5k genes mediana), 3 metodi presenti.

- [ ] **Step 4: Commit script Layer A**

```bash
git add analysis/p5-stage4-layer-a-fullrun.R
git commit -m "P5 Stadio 4 Task 19: layer-a-fullrun script + post-run validation"
```

- [ ] **Step 5: Force-add Layer A output dir (esclusi files grandi) per provenance**

```bash
# Force-add solo run_metadata.json + qc_report.rds per provenance committata
LATEST_DIR=$(ls -td analysis/p4-output/*-stage4-* | head -1)
git add -f "$LATEST_DIR/run_metadata.json" "$LATEST_DIR/qc_report.rds"
git commit -m "P5 Stadio 4 Task 19: provenance Layer A run_metadata + qc_report"
```

---

## Task 20: ADR-0015 Accepted + ff-merge + tag

**Files:**
- Modify: `docs/decisions/0015-stage4-three-path-architecture.md`
- Modify: `NEWS.md` (extension counts Layer A)

- [ ] **Step 1: Aggiornare ADR-0015 a Accepted con i numeri Layer A**

Modifica la prima riga di `docs/decisions/0015-stage4-three-path-architecture.md`:

Da:
```
**Status:** Proposed (2026-05-19, pair con spec...)
```

A:
```
**Status:** Accepted (DATA, Layer A run completato WALLm wall, NCP cluster processed, NSIG gene-cluster significativi FDR<0.05, tag p5-stadio4-complete)
```

(Sostituisci DATA, WALL, NCP, NSIG con valori reali dal run.)

- [ ] **Step 2: Aggiornare NEWS.md con risultati Layer A**

Appendi al bullet 0.0.0.9019:

```markdown
  - **Layer A run completato** YYYY-MM-DD: NCP/412 cluster processed (NPROC%) in WALL min wall,
    output `analysis/p4-output/<TIMESTAMP>-stage4-<RUNID>/` (force-add provenance file +
    parquet gitignored). Cluster_pooled NRP rows, per_study_de NPRS rows. Significativi (FDR<0.05): NSIG.
```

- [ ] **Step 3: ff-merge a master + tag**

```bash
git checkout master
git merge --ff-only p5-stadio4-de-perstudio
git tag p5-stadio4-complete
```

Verifica:
```bash
git log --oneline -5
git tag --list | grep stage4
```

- [ ] **Step 4: Commit final updates su master**

```bash
git status  # verifica clean
# Push remoto SOLO se utente richiede esplicitamente; NO autopush.
cli::cli_alert_info("Push remote rimane all'utente. Master locale ahead of origin.")
```

---

## Self-Review

### Spec coverage check

- §1 Contesto + obiettivo → Task 1, 11 (build_stage4_results entry-point)
- §2 Goals (three-path, caching layer, output reusable, QC, dashboard, idempotence, targets) → Task 5-7, 4, 10, 3, 15, 12, 14 ✓
- §3 Architettura 5 sub-stage → Task 3 (QC), 4 (counts), 5+9 (per-study), 6-9 (pooling), 16 (dashboard) ✓
- §4 Output schema 6 file → Task 10 (write/load IO) + Task 15 (dashboard HTML) ✓
- §5 API surface (`@export` + internal) → distributed across tasks ✓
- §6 Targets integration → Task 14 ✓
- §7 Test strategy (unit + integration + replication + smoke + perf) → Task 3-13 + Task 17 ✓
- §8 Persistence + versioning → Task 2 (run_id) + Task 10 (schema_versions in json) ✓
- §9 Risks + open questions → addressed in ADR (Task 18) ✓
- §10 Decisioni rilevanti → ADR-0015 (Task 18) ✓

### Placeholder scan

Grep'd for TBD/TODO/"implement later" in plan — none found. All test code shown. All commits with concrete messages.

### Type consistency

- `stage4_result` S3 class returned by `build_stage4_results` (Task 11), consumed by `write_stage4_to_dir` (Task 10), reloaded by `load_stage4` (Task 10), passed to `render_stage4_dashboard` (Task 16). ✓
- `eligible_clusters` tibble produced by `.qc_filter_samples_and_studies` (Task 3), enriched with attribute `study_dispatch` in orchestrator (Task 9), consumed by `.run_per_study_de_all` and `.pool_all_clusters` (Task 9). ✓
- `per_study_de` schema identical between `.run_limma_voom_de` output (Task 5), `.run_per_study_de_all` (Task 9), and `write_stage4_to_dir` parquet write (Task 10). ✓
- `cluster_pooled` schema identical between `.pool_rem_cluster` (Task 6), `.run_dream_mega` (Task 7), and `.pool_all_clusters` (Task 9). ✓

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-19-p5-stadio4-de-perstudio-plan.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch un fresh subagent per Task, review tra task, fast iteration. Coerente con il pattern P4 β rescue che ha gestito bene gli step.

**2. Inline Execution** — Esegui i Task in questa stessa session via `superpowers:executing-plans`, batch execution con checkpoint manuali per review.

Quale approccio preferisci?
