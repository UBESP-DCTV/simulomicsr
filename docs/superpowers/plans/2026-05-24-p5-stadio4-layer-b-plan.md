# P5 Stadio 4 Layer B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementare il generatore semi-automatico di case study Layer B per Stadio 4: dato un CSV con 10-20 cluster_id curati a mano, produce per ogni cluster un bundle publication-grade (8 plot) + un report Quarto aggregato HTML standalone.

**Architecture:** Pipeline a 3 sub-stage (B.1 Loader+QC → B.2 Asset gen → B.3 Aggregate report) consumante read-only il `cluster_pooled.parquet` + `per_study_de.parquet` di Layer A. Script standalone primary (no targets integration). Smoke 3-cluster gate obbligatorio pre-batch.

**Tech Stack:** R 4.6.0 + renv 1.1.4. ggplot2 + ggrepel (volcano, MA, GO, heterogeneity), metafor::forest + ggplot2 custom (forest), ComplexHeatmap + DESeq2::vst + sva::ComBat (heatmap), clusterProfiler + org.Hs.eg.db + ReactomePA (GO enrichment), kableExtra (LaTeX), Quarto (aggregate report), arrow + digest (parquet + run_id), testthat 3.0 (TDD).

**Spec di riferimento:** `docs/superpowers/specs/2026-05-24-p5-stadio4-layer-b-design.md`

---

## Task 0: Branch setup + ADR-0017 + DESCRIPTION delta + renv install

**Files:**
- Create: `docs/decisions/0017-layer-b-case-study-generator.md`
- Modify: `DESCRIPTION`
- Modify: `renv.lock` (via renv::install)

- [ ] **Step 1: Create branch from master**

Run:
```bash
cd /home/user/simulomicsr
git checkout master
git status   # verifica clean
git checkout -b p5-stadio4-layer-b
```

Expected: branch `p5-stadio4-layer-b` creato, HEAD su `85e9bcb` (spec commit) o successivo.

- [ ] **Step 2: Scrivere ADR-0017**

Crea `docs/decisions/0017-layer-b-case-study-generator.md` con:

```markdown
# ADR-0017 — Layer B case study generator architecture

**Stato:** Proposed
**Data:** 2026-05-24
**Branch:** `p5-stadio4-layer-b`
**Spec di riferimento:** `docs/superpowers/specs/2026-05-24-p5-stadio4-layer-b-design.md`

## Contesto

Stadio 4 Layer A ha prodotto effect-size pooled per 487 cluster cross-studio (run_id `96c43acb`, 2026-05-23). Il finding scope decision 2026-05-19 stabilisce ~10-20 case study "showcase" curati a mano come deliverable Results del paper. Layer B è la pipeline semi-automatica che converte una selezione manuale di cluster_id in bundle publication-ready.

## Decisione

Adozione di un'architettura **CSV-driven selection + comprehensive plot bundle + aggregate Quarto report**, con le seguenti decisioni rilevanti:

1. **Input mechanism**: CSV manualmente curato (`analysis/layer-b-selection.csv`). Schema `cluster_id, label_paper, priority, notes`. Trasparente, versionabile, audit-trailable.
2. **Plot set**: 8 plot per cluster con dispatch conditional per metodo (forest = REM+MEGA-AUG, heterogeneity = REM only).
3. **Output qualità**: Drop-into-paper polished (PNG @300 DPI + SVG separati), caption inglese paper-ready, palette viridis, font Helvetica 11pt, dimensioni Nature/Cell-compliant.
4. **Top-N defaults**: forest 10 / heatmap 30 / top-gene table 30 / volcano labels 15. Tutti configurabili via `layer_b_default_config()`.
5. **Aggregate report**: HTML standalone via Quarto (`embed-resources: true`). NO PDF (evita wkhtmltopdf/LaTeX deps).
6. **Bundle structure**: dir-per-cluster + un `narrative.qmd` per-cluster (no master narrative).
7. **Dependencies**: `clusterProfiler` + `org.Hs.eg.db` + `ComplexHeatmap` + `sva` + `DESeq2` + `ggrepel` + `kableExtra` come hard `Imports`. `ggplot2` e `quarto` MOSSI da `Suggests` a `Imports` (breaking minor accepted). `ReactomePA` opt-in `Suggests` con skip-graceful.
8. **Targets integration**: NO in `_targets.R`. Script standalone primary `analysis/p5-stage4-layer-b-build.R` (pattern Layer A).
9. **Smoke gate**: 3-cluster pre-batch obbligatorio (memoria `validate-before-fullrun`).

## Razionale

1. **CSV curato vs dashboard button**: la dashboard Layer A include già il picker (Sezione 5) con score composto. Aggiungere un'export button alla dashboard richiederebbe modifiche Quarto+DT+crosstalk JS non necessarie quando un CSV manuale dà lo stesso audit trail con zero dev front-end.

2. **Comprehensive plot set**: l'utente ha esplicitamente scelto "tutti gli 8" durante brainstorming dopo aver visto i mockup. Conditional dispatch evita di forzare plot non applicabili (forest su mega-strict, heterogeneity su non-REM).

3. **Drop-into-paper polished vs discussion-aid composite**: il paper Results richiede figure singole inseribili — un composite multi-panel richiederebbe comunque re-disegno manuale. Polish up-front sostituisce re-work downstream.

4. **org.Hs.eg.db hard dep**: senza, lo skip silente del GO enrichment introduce variabilità nei deliverable Layer B cross-machine. Errore deterministico al `library()` è preferibile a output incompleti silenti.

5. **NO targets integration**: Layer B è human-curation driven — la selezione cambia raramente, non automaticamente. Targets aggiunge complessità (cache invalidation cross-cluster, BPPARAM) senza valore (single-shot). Lo script standalone è più chiaro per il workflow dell'utente.

## Conseguenze

- Nuovi file `R/layer-b-*.R` (~15 file source + ~17 test file).
- DESCRIPTION delta: ~7 Imports nuovi + 2 mossi + 1 Suggests nuovo. renv.lock cambia.
- Output dir convention versionata `analysis/p4-output/<ts>-layer-b-<run_id>/` (analogo Layer A).
- Bundle paper-ready: PNG/SVG/CSV/LaTeX per ogni cluster + HTML standalone aggregate.
- Smoke gate consolidato come pattern obbligatorio per ogni fullrun Layer B futuro.
- `analysis/layer-b-selection.csv` diventa il primary audit trail della curation: scelta cluster + label paper documentate in git.

## Decisioni rinviate

- Dashboard "export selected to CSV" button (v2 enhancement se utente trova attrito nel copy/paste).
- LLM-generated draft narrative (rischio hallucination biologica troppo alto per v1).
- Multi-organism support (ARCHS4 mouse) — dipendente da γ pipeline future.
- Cross-cluster integration (es. combine 2 cluster narrative in un singolo case study composto) — out-of-scope v1.

## Riferimenti

- Spec: `docs/superpowers/specs/2026-05-24-p5-stadio4-layer-b-design.md`
- ADR-0006 (positioning vs RummaGEO)
- ADR-0015 (Stage 4 three-path architecture)
- ADR-0016 (Stage 4 crash fixes baseline pool cap)
- Finding scope decision: `docs/findings/2026-05-19-stadio-4-5-scope-decision.md`
```

- [ ] **Step 3: Aggiornare DESCRIPTION**

Modifica `DESCRIPTION` (sezioni `Imports:` e `Suggests:`):

In `Imports:` aggiungi (in ordine alfabetico):
```
    clusterProfiler,
    ComplexHeatmap,
    DESeq2,
    ggplot2,
    ggrepel,
    kableExtra,
    org.Hs.eg.db,
    quarto,
    sva,
```

Rimuovi da `Suggests:` (perché spostati in Imports):
- `ggplot2,`
- `quarto,`

In `Suggests:` aggiungi:
```
    ReactomePA,
```

- [ ] **Step 4: Installare nuove dipendenze**

Run:
```bash
cd /home/user/simulomicsr
Rscript -e 'renv::install(c(
  "bioc::clusterProfiler",
  "bioc::ComplexHeatmap",
  "bioc::DESeq2",
  "bioc::org.Hs.eg.db",
  "bioc::sva",
  "bioc::ReactomePA",
  "ggrepel",
  "kableExtra"
))'
Rscript -e 'renv::snapshot(prompt = FALSE)'
```

Expected: tutte le installazioni OK, `renv.lock` aggiornato. `quarto` e `ggplot2` già presenti.

- [ ] **Step 5: Verify load**

Run:
```bash
Rscript -e 'library(clusterProfiler); library(ComplexHeatmap); library(DESeq2); library(org.Hs.eg.db); library(sva); library(ggrepel); library(kableExtra); cat("OK all loaded\n")'
```

Expected: stampa "OK all loaded" senza errori.

- [ ] **Step 6: Commit**

```bash
git add docs/decisions/0017-layer-b-case-study-generator.md DESCRIPTION renv.lock
git commit -m "P5 Stadio 4 Layer B Task 0: ADR-0017 + DESCRIPTION delta + renv install

ADR-0017 (Proposed) cattura le 9 decisioni rilevanti del brainstorming
2026-05-24 + razionale + conseguenze.

DESCRIPTION delta:
- Imports nuovi: clusterProfiler, ComplexHeatmap, DESeq2, ggrepel,
  kableExtra, org.Hs.eg.db, sva
- Mossi da Suggests a Imports: ggplot2, quarto
- Suggests nuovo: ReactomePA (opt-in skip-graceful)

renv.lock aggiornato con 7 Bioc packages + 2 CRAN."
```

---

## Task 1: Config defaults (`layer_b_default_config()`)

**Files:**
- Create: `R/layer-b-config.R`
- Create: `tests/testthat/test-layer-b-config.R`

- [ ] **Step 1: Scrivere il test failing**

Crea `tests/testthat/test-layer-b-config.R`:

```r
test_that("layer_b_default_config returns expected schema", {
  config <- layer_b_default_config()

  # Top-level keys
  expect_named(
    config,
    c("top_n_forest", "top_n_heatmap", "top_n_table", "top_n_volcano_labels",
      "fdr_threshold", "palette", "language", "heatmap_normalize",
      "go_enrichment", "save_svg", "dpi", "min_genes_for_go_ora",
      "max_heatmap_samples"),
    ignore.order = TRUE
  )

  # Default values (consolidati nel brainstorming)
  expect_equal(config$top_n_forest, 10L)
  expect_equal(config$top_n_heatmap, 30L)
  expect_equal(config$top_n_table, 30L)
  expect_equal(config$top_n_volcano_labels, 15L)
  expect_equal(config$fdr_threshold, 0.05)
  expect_equal(config$palette, "viridis")
  expect_equal(config$language, "en")
  expect_true(config$heatmap_normalize)
  expect_true(config$go_enrichment)
  expect_true(config$save_svg)
  expect_equal(config$dpi, 300L)
  expect_equal(config$min_genes_for_go_ora, 200L)
  expect_equal(config$max_heatmap_samples, 100L)
})

test_that("layer_b_default_config returns plain list (serializable to JSON)", {
  config <- layer_b_default_config()
  json <- jsonlite::toJSON(config, auto_unbox = TRUE)
  parsed <- jsonlite::fromJSON(json)
  expect_equal(parsed$top_n_forest, 10L)
  expect_equal(parsed$fdr_threshold, 0.05)
})
```

- [ ] **Step 2: Run test per verificare il fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-config")'
```

Expected: FAIL con `could not find function "layer_b_default_config"`.

- [ ] **Step 3: Implementare`R/layer-b-config.R`**

Crea `R/layer-b-config.R`:

```r
#' Default config for Layer B case study generator
#'
#' Returns a plain list of defaults used by [build_layer_b_results()] e
#' funzioni interne. Tutti i campi sono override-abili passando una list
#' parziale al `config` argument: i campi mancanti restano ai default.
#'
#' @return Lista con i seguenti elementi:
#' \describe{
#'   \item{top_n_forest}{`integer(1)` — top-N geni nel forest plot (default 10).}
#'   \item{top_n_heatmap}{`integer(1)` — top-N geni nella heatmap (default 30).}
#'   \item{top_n_table}{`integer(1)` — top-N geni nella top-gene table (default 30).}
#'   \item{top_n_volcano_labels}{`integer(1)` — top-N geni labellati nel volcano (default 15).}
#'   \item{fdr_threshold}{`numeric(1)` — soglia FDR per significatività (default 0.05).}
#'   \item{palette}{`character(1)` — palette colore base (default "viridis").}
#'   \item{language}{`character(1)` — lingua caption/narrative ("en" o "it", default "en").}
#'   \item{heatmap_normalize}{`logical(1)` — applicare vst+ComBat alla heatmap (default TRUE).}
#'   \item{go_enrichment}{`logical(1)` — generare GO enrichment plot (default TRUE).}
#'   \item{save_svg}{`logical(1)` — salvare anche SVG oltre PNG (default TRUE).}
#'   \item{dpi}{`integer(1)` — DPI per output PNG (default 300).}
#'   \item{min_genes_for_go_ora}{`integer(1)` — soglia minima geni nell'universo per ORA (default 200; sotto skip-graceful).}
#'   \item{max_heatmap_samples}{`integer(1)` — max sample plottati nella heatmap (default 100; sopra subsample stratificato).}
#' }
#'
#' @export
#' @examples
#' config <- layer_b_default_config()
#' # Override solo top_n_forest:
#' config$top_n_forest <- 20L
layer_b_default_config <- function() {
  list(
    top_n_forest         = 10L,
    top_n_heatmap        = 30L,
    top_n_table          = 30L,
    top_n_volcano_labels = 15L,
    fdr_threshold        = 0.05,
    palette              = "viridis",
    language             = "en",
    heatmap_normalize    = TRUE,
    go_enrichment        = TRUE,
    save_svg             = TRUE,
    dpi                  = 300L,
    min_genes_for_go_ora = 200L,
    max_heatmap_samples  = 100L
  )
}
```

- [ ] **Step 4: Run test per verificare il pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-config")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-config.R tests/testthat/test-layer-b-config.R
git commit -m "P5 Stadio 4 Layer B Task 1: layer_b_default_config()

Lista plain dei default consolidati nel brainstorming:
- top-N: 10 forest / 30 heatmap / 30 table / 15 volcano labels
- fdr_threshold=0.05, palette=viridis, language=en, dpi=300
- min_genes_for_go_ora=200 (skip-graceful sotto)
- max_heatmap_samples=100 (subsample stratificato sopra)

JSON-serializable per inclusione in run_metadata.json."
```

---

## Task 2: Selection loader + validator

**Files:**
- Create: `R/layer-b-selection.R`
- Create: `tests/testthat/test-layer-b-selection.R`
- Create: `tests/testthat/test-layer-b-validate-selection.R`

- [ ] **Step 1: Scrivere test failing per .load_layer_b_selection**

Crea `tests/testthat/test-layer-b-selection.R`:

```r
test_that(".load_layer_b_selection reads CSV with required columns", {
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv))
  writeLines(c(
    "cluster_id,label_paper,priority,notes",
    "pair_L0_abc123,IFN_A549,1,Type-I interferon canonical",
    "group_L0_def456,LNCaP_androgen,2,"
  ), csv)

  sel <- simulomicsr:::.load_layer_b_selection(csv)
  expect_s3_class(sel, "tbl_df")
  expect_named(sel, c("cluster_id", "label_paper", "priority", "notes"))
  expect_equal(nrow(sel), 2L)
  expect_type(sel$priority, "integer")
  expect_equal(sel$cluster_id, c("pair_L0_abc123", "group_L0_def456"))
})

test_that(".load_layer_b_selection accepts data.frame directly (polimorfismo)", {
  df <- tibble::tibble(
    cluster_id  = c("pair_L0_xxx", "group_L0_yyy"),
    label_paper = c("Case A", "Case B"),
    priority    = c(1L, 2L),
    notes       = c("", "test")
  )
  sel <- simulomicsr:::.load_layer_b_selection(df)
  expect_s3_class(sel, "tbl_df")
  expect_equal(nrow(sel), 2L)
})

test_that(".load_layer_b_selection fails on missing required columns", {
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv))
  writeLines(c("cluster_id,label_paper", "pair_L0_abc,IFN"), csv)
  expect_error(
    simulomicsr:::.load_layer_b_selection(csv),
    "missing required column"
  )
})

test_that(".load_layer_b_selection fails on duplicate cluster_id", {
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv))
  writeLines(c(
    "cluster_id,label_paper,priority,notes",
    "pair_L0_dup,A,1,",
    "pair_L0_dup,B,2,"
  ), csv)
  expect_error(
    simulomicsr:::.load_layer_b_selection(csv),
    "duplicate cluster_id"
  )
})
```

Crea `tests/testthat/test-layer-b-validate-selection.R`:

```r
test_that("layer_b_validate_selection fails fast on missing cluster_id", {
  # Build a minimal fake stage4_dir with cluster_pooled.parquet
  stage4_dir <- tempfile()
  dir.create(stage4_dir)
  on.exit(unlink(stage4_dir, recursive = TRUE))

  cp <- tibble::tibble(
    cluster_id = rep(c("cl_a", "cl_b"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 2),
    method = "mega",
    logFC_pool = 0.5,
    SE_pool = 0.1,
    p_value_pool = 0.01,
    tau2 = NA_real_,
    I2 = NA_real_,
    Q = NA_real_,
    Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = 0.05,
    direction_applied = "none"
  )
  arrow::write_parquet(cp, file.path(stage4_dir, "cluster_pooled.parquet"))

  selection <- tibble::tibble(
    cluster_id = c("cl_a", "cl_missing"),
    label_paper = c("A", "Missing"),
    priority = c(1L, 2L),
    notes = c("", "")
  )

  expect_error(
    layer_b_validate_selection(selection, stage4_dir),
    "cluster_id not found in stage4 output: cl_missing"
  )
})

test_that("layer_b_validate_selection returns enriched tibble when all OK", {
  stage4_dir <- tempfile()
  dir.create(stage4_dir)
  on.exit(unlink(stage4_dir, recursive = TRUE))

  cp <- tibble::tibble(
    cluster_id = rep(c("cl_a", "cl_b"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 2),
    method = c(rep("mega", 3), rep("mega_aug", 3)),
    logFC_pool = c(0.5, 1.2, -0.8, 2.0, 0.3, -1.5),
    SE_pool = 0.1,
    p_value_pool = c(0.001, 0.5, 0.02, 0.0001, 0.6, 0.005),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = c(5L, 5L, 5L, 2L, 2L, 2L),
    n_baseline_studies_augmented = c(NA, NA, NA, 8L, 8L, 8L),
    FDR_BH_within_cluster = c(0.005, 0.6, 0.04, 0.0003, 0.7, 0.015),
    direction_applied = "none"
  )
  arrow::write_parquet(cp, file.path(stage4_dir, "cluster_pooled.parquet"))

  selection <- tibble::tibble(
    cluster_id = c("cl_a", "cl_b"),
    label_paper = c("A", "B"),
    priority = c(1L, 2L),
    notes = c("", "")
  )

  result <- layer_b_validate_selection(selection, stage4_dir)
  expect_s3_class(result, "tbl_df")
  expect_named(
    result,
    c("cluster_id", "label_paper", "priority", "notes",
      "exists_in_stage4", "method", "k_effective", "n_sig_FDR05"),
    ignore.order = TRUE
  )
  expect_true(all(result$exists_in_stage4))
  expect_equal(result$method, c("mega", "mega_aug"))
  expect_equal(result$k_effective, c(5L, 2L))
  # cl_a: 2 geni con FDR < 0.05 (0.005, 0.04); cl_b: 2 geni (0.0003, 0.015)
  expect_equal(result$n_sig_FDR05, c(2L, 2L))
})
```

- [ ] **Step 2: Run test per fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-(selection|validate)")'
```

Expected: FAIL — funzioni non definite.

- [ ] **Step 3: Implementare `R/layer-b-selection.R`**

Crea `R/layer-b-selection.R`:

```r
#' Carica selection Layer B (interno)
#'
#' Polimorfico: accetta path-to-CSV (character) o data.frame already-loaded.
#' Valida schema + duplicati + tipi.
#'
#' @param selection character path-to-CSV o data.frame.
#' @return tibble con `cluster_id, label_paper, priority, notes`.
#' @keywords internal
.load_layer_b_selection <- function(selection) {
  if (is.character(selection)) {
    if (!file.exists(selection)) {
      cli::cli_abort("Selection CSV not found: {.path {selection}}")
    }
    sel <- readr::read_csv(
      selection,
      col_types = readr::cols(
        cluster_id  = readr::col_character(),
        label_paper = readr::col_character(),
        priority    = readr::col_integer(),
        notes       = readr::col_character()
      ),
      progress = FALSE
    )
  } else if (is.data.frame(selection)) {
    sel <- tibble::as_tibble(selection)
  } else {
    cli::cli_abort(
      "selection must be a character path or data.frame, got {.cls {class(selection)[1]}}"
    )
  }

  required <- c("cluster_id", "label_paper", "priority", "notes")
  missing_cols <- setdiff(required, names(sel))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "Selection is missing required column(s): {.field {missing_cols}}"
    )
  }

  # Coerce priority to integer if read as double
  sel$priority <- as.integer(sel$priority)
  # Replace NA notes with ""
  sel$notes[is.na(sel$notes)] <- ""

  if (anyDuplicated(sel$cluster_id) > 0L) {
    dups <- unique(sel$cluster_id[duplicated(sel$cluster_id)])
    cli::cli_abort(
      "Selection has duplicate cluster_id: {.field {dups}}"
    )
  }

  sel[, required]
}

#' Valida selection Layer B contro Layer A output (pre-check pubblico)
#'
#' Verifica che ogni `cluster_id` esista in `cluster_pooled.parquet` di Layer A
#' (fail-fast su typo o drift Stage 4 re-run). Restituisce tibble arricchita
#' con `exists_in_stage4`, `method`, `k_effective`, `n_sig_FDR05` per ogni
#' cluster — usabile come smoke check pre-batch da R interactive.
#'
#' @param selection character path-to-CSV o data.frame (passato a [.load_layer_b_selection]).
#' @param stage4_dir character path al dir output di Layer A (contiene `cluster_pooled.parquet`).
#' @param fdr_threshold numeric soglia per `n_sig_FDR05` (default 0.05).
#'
#' @return tibble con `cluster_id, label_paper, priority, notes,
#'   exists_in_stage4, method, k_effective, n_sig_FDR05`.
#' @export
#' @examples
#' \dontrun{
#' val <- layer_b_validate_selection(
#'   "analysis/layer-b-selection.csv",
#'   "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
#' )
#' print(val)
#' }
layer_b_validate_selection <- function(selection, stage4_dir, fdr_threshold = 0.05) {
  sel <- .load_layer_b_selection(selection)

  cp_path <- file.path(stage4_dir, "cluster_pooled.parquet")
  if (!file.exists(cp_path)) {
    cli::cli_abort(
      "cluster_pooled.parquet not found in stage4_dir: {.path {cp_path}}"
    )
  }

  cp <- arrow::open_dataset(cp_path)
  cluster_ids <- sel$cluster_id

  # Pull subset (small: just selected cluster_ids)
  cp_subset <- cp |>
    dplyr::filter(cluster_id %in% cluster_ids) |>
    dplyr::collect()

  present <- unique(cp_subset$cluster_id)
  missing <- setdiff(cluster_ids, present)
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Selected cluster_id not found in stage4 output: {.field {missing}}",
      "i" = "Re-browse the Layer A dashboard or check for stage4 re-run drift."
    ))
  }

  # Aggregate stats per cluster
  agg <- cp_subset |>
    dplyr::group_by(cluster_id) |>
    dplyr::summarise(
      method = dplyr::first(method),
      k_effective = as.integer(dplyr::first(k_effective)),
      n_sig_FDR05 = sum(FDR_BH_within_cluster < fdr_threshold, na.rm = TRUE),
      .groups = "drop"
    )

  result <- dplyr::left_join(sel, agg, by = "cluster_id")
  result$exists_in_stage4 <- TRUE

  # Reorder columns
  result[, c("cluster_id", "label_paper", "priority", "notes",
             "exists_in_stage4", "method", "k_effective", "n_sig_FDR05")]
}
```

- [ ] **Step 4: Run test per verificare pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-(selection|validate)")'
```

Expected: PASS 6/6 (4 in selection + 2 in validate-selection).

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-selection.R tests/testthat/test-layer-b-selection.R tests/testthat/test-layer-b-validate-selection.R
git commit -m "P5 Stadio 4 Layer B Task 2: selection loader + validator

.load_layer_b_selection() interno polimorfico:
- Accetta path-to-CSV o data.frame
- Valida schema (cluster_id, label_paper, priority, notes)
- Fail-fast su missing columns + duplicate cluster_id

layer_b_validate_selection() public (smoke check pre-batch):
- Verifica esistenza cluster_id in cluster_pooled.parquet di Layer A
- Fail-fast con suggerimento di rebrowse dashboard se drift
- Restituisce tibble arricchito con method, k_effective, n_sig_FDR05"
```

---

## Task 3: Layer A subset fetcher

**Files:**
- Create: `R/layer-b-fetch.R` (parte 1: `.fetch_layer_a_subset`)
- Create: `tests/testthat/test-layer-b-fetch.R`

- [ ] **Step 1: Test failing per `.fetch_layer_a_subset`**

Crea `tests/testthat/test-layer-b-fetch.R`:

```r
make_fake_stage4_dir <- function() {
  d <- tempfile("stage4_")
  dir.create(d)

  cp <- tibble::tibble(
    cluster_id = rep(c("cl_a", "cl_b", "cl_c"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 3),
    method = rep(c("mega", "mega_aug", "mega"), each = 3),
    logFC_pool = c(0.5, 1.2, -0.8, 2.0, 0.3, -1.5, 0.1, 0.2, 0.3),
    SE_pool = 0.1,
    p_value_pool = c(0.001, 0.5, 0.02, 0.0001, 0.6, 0.005, 0.9, 0.8, 0.7),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = c(5L, 5L, 5L, 2L, 2L, 2L, 6L, 6L, 6L),
    n_baseline_studies_augmented = c(NA, NA, NA, 8L, 8L, 8L, NA, NA, NA),
    FDR_BH_within_cluster = c(0.005, 0.6, 0.04, 0.0003, 0.7, 0.015, 0.9, 0.9, 0.9),
    direction_applied = "none"
  )
  arrow::write_parquet(cp, file.path(d, "cluster_pooled.parquet"))

  ps <- tibble::tibble(
    cluster_id = rep("cl_b", 6),  # only mega_aug ha per_study
    study_id = rep(c("GSE1", "GSE2"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 2),
    logFC = c(2.1, 0.4, -1.4, 1.9, 0.2, -1.6),
    SE = 0.15,
    p_value = 0.001,
    t_stat = 8.0,
    n_treated = 3L, n_control = 3L,
    direction_applied = "none"
  )
  arrow::write_parquet(ps, file.path(d, "per_study_de.parquet"))

  qc <- list(
    qc_drops_sample = tibble::tibble(),
    qc_drops_study = tibble::tibble(),
    qc_drops_cluster = tibble::tibble(
      cluster_id = "cl_z",
      original_k = NA_integer_, qc_final_k = NA_integer_,
      original_n_studies = NA_integer_, qc_final_n_studies = NA_integer_,
      reason = "mega_rank_deficient"
    ),
    pooling_warnings = tibble::tibble(),
    mega_aug_diagnostics = tibble::tibble(cluster_id = "cl_b", bidir_collapsed_to_mono = FALSE)
  )
  saveRDS(qc, file.path(d, "qc_report.rds"))

  meta <- list(run_id = "deadbeef", config = list(de_engine = list(mega = "dream")))
  jsonlite::write_json(meta, file.path(d, "run_metadata.json"), auto_unbox = TRUE)

  d
}

test_that(".fetch_layer_a_subset returns subset for requested cluster_ids", {
  d <- make_fake_stage4_dir()
  on.exit(unlink(d, recursive = TRUE))

  sub <- simulomicsr:::.fetch_layer_a_subset(d, c("cl_a", "cl_b"))

  expect_named(sub, c("cluster_pooled", "per_study_de", "qc_report_subset",
                       "mega_aug_diagnostics", "stage4_run_id"),
               ignore.order = TRUE)
  expect_equal(sort(unique(sub$cluster_pooled$cluster_id)), c("cl_a", "cl_b"))
  expect_equal(sort(unique(sub$per_study_de$cluster_id)), "cl_b")  # cl_a is mega, no per_study
  expect_equal(sub$stage4_run_id, "deadbeef")
  expect_equal(nrow(sub$mega_aug_diagnostics), 1L)
})

test_that(".fetch_layer_a_subset error if stage4_dir missing files", {
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  expect_error(
    simulomicsr:::.fetch_layer_a_subset(d, "cl_a"),
    "cluster_pooled.parquet not found"
  )
})
```

- [ ] **Step 2: Run test per fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-fetch")'
```

Expected: FAIL — `.fetch_layer_a_subset` non definita.

- [ ] **Step 3: Implementare `R/layer-b-fetch.R` (parte 1)**

Crea `R/layer-b-fetch.R`:

```r
#' Fetch subset Layer A per i cluster_id selezionati
#'
#' Read-only fetch da `stage4_dir`: filtra `cluster_pooled.parquet`,
#' `per_study_de.parquet`, `qc_report.rds` per i `cluster_ids` richiesti.
#' Estrae anche il `run_id` di Stage 4 da `run_metadata.json` per
#' provenance del `run_id` Layer B.
#'
#' @param stage4_dir character path al dir di Layer A output.
#' @param cluster_ids character vector di cluster_id da filtrare.
#'
#' @return list con `cluster_pooled` (tibble), `per_study_de` (tibble, may have
#'   0 rows for mega-strict clusters), `qc_report_subset` (list filtered da qc_report.rds),
#'   `mega_aug_diagnostics` (tibble subset, may be 0 rows), `stage4_run_id` (character).
#' @keywords internal
.fetch_layer_a_subset <- function(stage4_dir, cluster_ids) {
  cp_path <- file.path(stage4_dir, "cluster_pooled.parquet")
  ps_path <- file.path(stage4_dir, "per_study_de.parquet")
  qc_path <- file.path(stage4_dir, "qc_report.rds")
  meta_path <- file.path(stage4_dir, "run_metadata.json")

  for (p in c(cp_path, ps_path, qc_path, meta_path)) {
    if (!file.exists(p)) {
      cli::cli_abort("{basename(p)} not found in stage4_dir: {.path {p}}")
    }
  }

  cp <- arrow::open_dataset(cp_path) |>
    dplyr::filter(cluster_id %in% cluster_ids) |>
    dplyr::collect()

  ps <- arrow::open_dataset(ps_path) |>
    dplyr::filter(cluster_id %in% cluster_ids) |>
    dplyr::collect()

  qc_full <- readRDS(qc_path)
  qc_sub <- list(
    qc_drops_sample = qc_full$qc_drops_sample,  # global, no filter
    qc_drops_study = qc_full$qc_drops_study[qc_full$qc_drops_study$cluster_id %in% cluster_ids, , drop = FALSE],
    qc_drops_cluster = qc_full$qc_drops_cluster[qc_full$qc_drops_cluster$cluster_id %in% cluster_ids, , drop = FALSE],
    pooling_warnings = qc_full$pooling_warnings[qc_full$pooling_warnings$cluster_id %in% cluster_ids, , drop = FALSE]
  )

  mega_aug_diag <- if (!is.null(qc_full$mega_aug_diagnostics) && nrow(qc_full$mega_aug_diagnostics) > 0L) {
    qc_full$mega_aug_diagnostics[qc_full$mega_aug_diagnostics$cluster_id %in% cluster_ids, , drop = FALSE]
  } else {
    tibble::tibble()
  }

  meta <- jsonlite::read_json(meta_path)
  stage4_run_id <- meta$run_id %||% NA_character_

  list(
    cluster_pooled = cp,
    per_study_de = ps,
    qc_report_subset = qc_sub,
    mega_aug_diagnostics = mega_aug_diag,
    stage4_run_id = stage4_run_id
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
```

- [ ] **Step 4: Run test per pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-fetch")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-fetch.R tests/testthat/test-layer-b-fetch.R
git commit -m "P5 Stadio 4 Layer B Task 3: .fetch_layer_a_subset()

Read-only subset di Layer A per cluster_ids selezionati:
- Filter cluster_pooled.parquet + per_study_de.parquet via arrow
- Subset qc_report.rds (drops_study, drops_cluster, pooling_warnings,
  mega_aug_diagnostics) per cluster_id
- Estrae stage4_run_id da run_metadata.json per provenance
- Fail-fast su stage4_dir incompleto"
```

---

## Task 4: Cluster counts assembler

**Files:**
- Modify: `R/layer-b-fetch.R` (aggiungi `.assemble_cluster_counts`)
- Modify: `tests/testthat/test-layer-b-fetch.R` (aggiungi test)

- [ ] **Step 1: Aggiungere test failing per .assemble_cluster_counts**

Append a `tests/testthat/test-layer-b-fetch.R`:

```r
test_that(".assemble_cluster_counts builds matrix + metadata for a cluster", {
  skip_if_not_installed("rhdf5")

  # Create synthetic counts matrix: 50 genes × 6 samples
  set.seed(42)
  counts <- matrix(rpois(50 * 6, lambda = 100), nrow = 50,
                   dimnames = list(paste0("G", 1:50), paste0("GSM", 1:6)))

  # Cluster assignment: 2 studies × 3 sample × (treatment | control)
  cluster_id <- "test_cl"
  per_cluster_samples <- tibble::tibble(
    sample_id = paste0("GSM", 1:6),
    study_id  = c("GSE1", "GSE1", "GSE1", "GSE2", "GSE2", "GSE2"),
    treatment = c("treated", "treated", "control", "treated", "control", "control")
  )

  # Fake counts cache: pre-saved RDS keyed by study
  cache_dir <- tempfile("counts_cache_")
  dir.create(cache_dir)
  on.exit(unlink(cache_dir, recursive = TRUE))

  # Save counts per (cluster, study) — mimic Stage 4 cache structure
  cache_manifest <- list(
    test_cl = list(
      GSE1 = file.path(cache_dir, "test_cl_GSE1.rds"),
      GSE2 = file.path(cache_dir, "test_cl_GSE2.rds")
    )
  )
  saveRDS(counts[, 1:3], cache_manifest$test_cl$GSE1)
  saveRDS(counts[, 4:6], cache_manifest$test_cl$GSE2)

  result <- simulomicsr:::.assemble_cluster_counts(
    cluster_id = "test_cl",
    per_cluster_samples = per_cluster_samples,
    cache_manifest = cache_manifest
  )

  expect_named(result, c("counts", "metadata"), ignore.order = TRUE)
  expect_equal(dim(result$counts), c(50L, 6L))
  expect_equal(colnames(result$counts), paste0("GSM", 1:6))
  expect_equal(rownames(result$counts), paste0("G", 1:50))
  expect_s3_class(result$metadata, "tbl_df")
  expect_equal(nrow(result$metadata), 6L)
  expect_equal(result$metadata$treatment,
               c("treated", "treated", "control", "treated", "control", "control"))
})
```

- [ ] **Step 2: Run test per fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-fetch")'
```

Expected: FAIL — `.assemble_cluster_counts` non definita.

- [ ] **Step 3: Aggiungere implementazione in `R/layer-b-fetch.R`**

Append a `R/layer-b-fetch.R`:

```r
#' Assembla counts + metadata per un cluster
#'
#' Combina counts matrix dai file cache per ogni studio del cluster + metadata
#' tibble con sample_id, study_id, treatment. Cache hit assunto (Layer B
#' consuma il cache di Stage 4 già popolato).
#'
#' @param cluster_id character (1).
#' @param per_cluster_samples tibble con `sample_id, study_id, treatment` per
#'   il cluster (assemblata upstream dal caller, tipicamente dal join di Stage 3
#'   assignment + Stage 2 design_role).
#' @param cache_manifest list nested `cache_manifest[[cluster_id]][[study_id]]`
#'   = path al file .rds con counts matrix integer (genes × samples_of_study).
#'
#' @return list con `counts` (integer matrix genes × all_samples) e `metadata`
#'   (tibble sample_id, study_id, treatment in colonna-order).
#' @keywords internal
.assemble_cluster_counts <- function(cluster_id, per_cluster_samples, cache_manifest) {
  if (is.null(cache_manifest[[cluster_id]])) {
    cli::cli_abort(
      "Cache manifest missing for cluster {.field {cluster_id}}"
    )
  }

  studies <- unique(per_cluster_samples$study_id)
  counts_list <- lapply(studies, function(s) {
    path <- cache_manifest[[cluster_id]][[s]]
    if (is.null(path) || !file.exists(path)) {
      cli::cli_abort(
        "Counts cache missing for cluster {.field {cluster_id}} / study {.field {s}}"
      )
    }
    readRDS(path)
  })
  names(counts_list) <- studies

  # Rownames consistency check
  ref_genes <- rownames(counts_list[[1L]])
  for (s in studies[-1L]) {
    if (!identical(rownames(counts_list[[s]]), ref_genes)) {
      cli::cli_abort(
        "Gene axis mismatch between studies {.field {studies[1L]}} and {.field {s}} for cluster {.field {cluster_id}}"
      )
    }
  }

  # Combine cbind in study order, ensure column order matches per_cluster_samples
  combined <- do.call(cbind, counts_list)

  # Reorder columns to match per_cluster_samples$sample_id
  missing_in_cache <- setdiff(per_cluster_samples$sample_id, colnames(combined))
  if (length(missing_in_cache) > 0L) {
    cli::cli_abort(
      "Samples missing from cache for cluster {.field {cluster_id}}: {.field {missing_in_cache}}"
    )
  }
  combined <- combined[, per_cluster_samples$sample_id, drop = FALSE]

  list(
    counts = combined,
    metadata = per_cluster_samples
  )
}
```

- [ ] **Step 4: Run test per pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-fetch")'
```

Expected: PASS 3/3.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-fetch.R tests/testthat/test-layer-b-fetch.R
git commit -m "P5 Stadio 4 Layer B Task 4: .assemble_cluster_counts()

Combina counts matrix dai file cache per ogni studio del cluster.
- Rownames consistency check tra studi (fail-fast su mismatch)
- Column reorder per matchare per_cluster_samples$sample_id
- Fail-fast su missing cache files o sample mancanti"
```

---

## Task 5: Volcano plot

**Files:**
- Create: `R/layer-b-plot-volcano.R`
- Create: `tests/testthat/test-layer-b-volcano.R`

- [ ] **Step 1: Test failing per `.build_volcano`**

Crea `tests/testthat/test-layer-b-volcano.R`:

```r
make_fake_cluster_pooled <- function(n_genes = 100, n_sig = 20, cluster_id = "cl_test") {
  set.seed(42)
  logFC <- c(rnorm(n_sig, mean = 0, sd = 3), rnorm(n_genes - n_sig, mean = 0, sd = 0.3))
  p_value <- c(runif(n_sig, 1e-10, 0.01), runif(n_genes - n_sig, 0.05, 1))
  tibble::tibble(
    cluster_id = cluster_id,
    gene = paste0("G", seq_len(n_genes)),
    method = "mega",
    logFC_pool = logFC,
    SE_pool = abs(logFC) / 5 + 0.1,
    p_value_pool = p_value,
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = p.adjust(p_value, method = "BH"),
    direction_applied = "none"
  )
}

test_that(".build_volcano writes PNG + SVG with expected content", {
  cp <- make_fake_cluster_pooled()
  out_dir <- tempfile("volcano_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()

  result <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = cfg)

  expect_named(result, c("png_path", "svg_path", "caption"), ignore.order = TRUE)
  expect_true(file.exists(result$png_path))
  expect_true(file.exists(result$svg_path))
  expect_match(basename(result$png_path), "^volcano\\.png$")
  expect_match(basename(result$svg_path), "^volcano\\.svg$")
  expect_match(result$caption, "Volcano plot")
  expect_match(result$caption, "FDR<0\\.05")
  # PNG file should be non-empty
  expect_gt(file.info(result$png_path)$size, 1000L)
})

test_that(".build_volcano handles 0 sig genes gracefully", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 0)
  out_dir <- tempfile("volcano_zero_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "0 of 50")
})
```

- [ ] **Step 2: Run test per fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-volcano")'
```

Expected: FAIL — `.build_volcano` non definita.

- [ ] **Step 3: Implementare `R/layer-b-plot-volcano.R`**

Crea `R/layer-b-plot-volcano.R`:

```r
#' Volcano plot publication-grade per un cluster
#'
#' Genera volcano plot (logFC_pool vs -log10(p_value_pool)) con FDR<0.05 color,
#' top-N labels via ggrepel. Salva PNG (DPI configurabile) + SVG.
#'
#' @param cluster_pooled_subset tibble subset di `cluster_pooled.parquet` per il
#'   cluster di interesse (tutte le righe stesso `cluster_id`).
#' @param out_dir character path al dir dove salvare `volcano.png` + `volcano.svg`.
#' @param config list di config (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path`, `caption`.
#' @keywords internal
.build_volcano <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_volcano_labels

  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr
  cp$neg_log10_p <- -log10(pmax(cp$p_value_pool, .Machine$double.xmin))

  n_total <- nrow(cp)
  n_sig <- sum(cp$is_sig, na.rm = TRUE)

  # Top-N labels: ranked by |logFC| × -log10(FDR) tra i sig
  cp$label_score <- abs(cp$logFC_pool) * (-log10(pmax(cp$FDR_BH_within_cluster, .Machine$double.xmin)))
  sig_idx <- which(cp$is_sig)
  if (length(sig_idx) > 0L) {
    ranked_sig <- sig_idx[order(cp$label_score[sig_idx], decreasing = TRUE)]
    top_idx <- head(ranked_sig, top_n)
    cp$label <- ifelse(seq_len(nrow(cp)) %in% top_idx, cp$gene, NA_character_)
  } else {
    cp$label <- NA_character_
  }

  p <- ggplot2::ggplot(cp, ggplot2::aes(x = logFC_pool, y = neg_log10_p)) +
    ggplot2::geom_point(ggplot2::aes(color = is_sig), alpha = 0.6, size = 1.5) +
    ggplot2::scale_color_manual(
      values = c(`TRUE` = "#CC3333", `FALSE` = "#BBBBBB"),
      labels = c(`TRUE` = sprintf("FDR<%g", fdr_thr), `FALSE` = "not sig"),
      name = NULL
    ) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "#333333", alpha = 0.5) +
    ggrepel::geom_text_repel(
      ggplot2::aes(label = label),
      size = 3, max.overlaps = top_n,
      box.padding = 0.3, segment.alpha = 0.5,
      na.rm = TRUE
    ) +
    ggplot2::labs(
      x = expression(log[2]~"FC pooled"),
      y = expression(-log[10]~"p-value pooled")
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank()
    )

  png_path <- file.path(out_dir, "volcano.png")
  svg_path <- file.path(out_dir, "volcano.svg")

  ggplot2::ggsave(png_path, p, width = 6, height = 6, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, p, width = 6, height = 6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "Volcano plot for cluster %s. %d of %d genes significant at FDR<%g (BH-corrected within cluster).",
    unique(cp$cluster_id), n_sig, n_total, fdr_thr
  )

  list(
    png_path = png_path,
    svg_path = svg_path,
    caption = caption
  )
}
```

- [ ] **Step 4: Run test per pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-volcano")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-plot-volcano.R tests/testthat/test-layer-b-volcano.R
git commit -m "P5 Stadio 4 Layer B Task 5: .build_volcano()

Volcano publication-grade:
- ggplot2 + ggrepel labels (top-N config.top_n_volcano_labels=15)
- Color FDR<0.05 rosso #CC3333 vs not-sig grigio #BBBBBB
- Top-N ranking: |logFC| × -log10(FDR) tra i sig
- PNG 6x6 @config.dpi=300 + SVG opzionale
- Caption auto formattata"
```

---

## Task 6: Forest plot (REM + MEGA-AUG dispatch)

**Files:**
- Create: `R/layer-b-plot-forest.R`
- Create: `tests/testthat/test-layer-b-forest.R`

- [ ] **Step 1: Test failing per `.build_forest`**

Crea `tests/testthat/test-layer-b-forest.R`:

```r
make_fake_per_study_de <- function(cluster_id = "cl_aug", n_genes = 50, n_studies = 2) {
  set.seed(42)
  studies <- paste0("GSE", seq_len(n_studies))
  expand.grid(study_id = studies, gene = paste0("G", seq_len(n_genes)),
              KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      cluster_id = cluster_id,
      logFC = rnorm(dplyr::n(), 0, 1),
      SE = abs(rnorm(dplyr::n(), 0.3, 0.1)),
      p_value = runif(dplyr::n(), 0, 1),
      t_stat = logFC / SE,
      n_treated = 3L, n_control = 3L,
      direction_applied = "none"
    ) |>
    dplyr::select(cluster_id, study_id, gene, logFC, SE, p_value, t_stat,
                  n_treated, n_control, direction_applied)
}

test_that(".build_forest produces PNG for mega_aug cluster", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 15, cluster_id = "cl_aug")
  cp$method <- "mega_aug"
  cp$n_baseline_studies_augmented <- 8L
  ps <- make_fake_per_study_de(cluster_id = "cl_aug", n_genes = 50, n_studies = 2)

  out_dir <- tempfile("forest_aug_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "mega_aug",
    out_dir = out_dir,
    config = cfg
  )
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "Forest plot")
  expect_match(result$caption, "k=2 pair")
})

test_that(".build_forest skip mega-strict with explanatory caption", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 10, cluster_id = "cl_mega")
  cp$method <- "mega"
  ps <- tibble::tibble()  # mega strict has no per_study_de

  out_dir <- tempfile("forest_mega_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "mega",
    out_dir = out_dir,
    config = cfg
  )
  expect_true(is.na(result$png_path) || is.null(result$png_path))
  expect_match(result$caption, "Forest plot N/A for mega-strict")
})
```

- [ ] **Step 2: Run test per fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-forest")'
```

Expected: FAIL — `.build_forest` non definita.

- [ ] **Step 3: Implementare `R/layer-b-plot-forest.R`**

Crea `R/layer-b-plot-forest.R`:

```r
#' Forest plot top-N geni (REM + MEGA-AUG dispatch)
#'
#' Per `method == "rem"`: usa `metafor::forest()` su per-study yi/vi.
#' Per `method == "mega_aug"`: custom ggplot con 2 studi del pair + pooled diamond.
#' Per `method == "mega"`: skip-graceful con caption esplicativa (no per-study DE
#' nel Layer A output).
#'
#' @param per_study_de_subset tibble subset per il cluster (può essere 0 rows per mega).
#' @param cluster_pooled_subset tibble subset per il cluster.
#' @param method character "rem", "mega", o "mega_aug".
#' @param out_dir character dir output.
#' @param config list config.
#'
#' @return list con `png_path` (NA se skip), `svg_path` (NA se skip o save_svg=FALSE),
#'   `caption` (skip-explanation se applicable).
#' @keywords internal
.build_forest <- function(per_study_de_subset, cluster_pooled_subset, method,
                          out_dir, config) {
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_forest

  if (method == "mega") {
    return(list(
      png_path = NA_character_,
      svg_path = NA_character_,
      caption = "Forest plot N/A for mega-strict method (per-study DE absorbed in mixed model; per-study coefficients not extracted in Layer A)."
    ))
  }

  if (nrow(per_study_de_subset) == 0L) {
    return(list(
      png_path = NA_character_,
      svg_path = NA_character_,
      caption = sprintf("Forest plot N/A for cluster (method=%s): no per-study DE rows found.", method)
    ))
  }

  cp <- cluster_pooled_subset
  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr

  top_genes <- cp[cp$is_sig, , drop = FALSE]
  top_genes <- top_genes[order(abs(top_genes$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top_genes <- head(top_genes, top_n)

  if (nrow(top_genes) == 0L) {
    return(list(
      png_path = NA_character_,
      svg_path = NA_character_,
      caption = sprintf("Forest plot N/A: no genes significant at FDR<%g for cluster.", fdr_thr)
    ))
  }

  ps <- per_study_de_subset[per_study_de_subset$gene %in% top_genes$gene, , drop = FALSE]

  if (method == "mega_aug") {
    df_plot <- ps |>
      dplyr::mutate(
        ci_lo = logFC - 1.96 * SE,
        ci_hi = logFC + 1.96 * SE,
        gene = factor(gene, levels = rev(top_genes$gene))
      )
    pooled_df <- top_genes |>
      dplyr::transmute(
        gene = factor(gene, levels = rev(top_genes$gene)),
        study_id = "Pool",
        logFC = logFC_pool,
        ci_lo = logFC_pool - 1.96 * SE_pool,
        ci_hi = logFC_pool + 1.96 * SE_pool
      )

    p <- ggplot2::ggplot() +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "#666666") +
      ggplot2::geom_errorbarh(
        data = df_plot,
        ggplot2::aes(y = gene, xmin = ci_lo, xmax = ci_hi, color = study_id),
        height = 0.2
      ) +
      ggplot2::geom_point(
        data = df_plot,
        ggplot2::aes(y = gene, x = logFC, color = study_id),
        size = 2
      ) +
      ggplot2::geom_errorbarh(
        data = pooled_df,
        ggplot2::aes(y = gene, xmin = ci_lo, xmax = ci_hi),
        color = "#CC3333", height = 0.3, size = 0.8
      ) +
      ggplot2::geom_point(
        data = pooled_df,
        ggplot2::aes(y = gene, x = logFC),
        color = "#CC3333", shape = 18, size = 4
      ) +
      ggplot2::scale_color_viridis_d(name = "Study") +
      ggplot2::labs(x = expression(log[2]~"FC"), y = NULL) +
      ggplot2::theme_bw(base_size = 11) +
      ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

    h <- max(3, nrow(top_genes) * 0.5)
    png_path <- file.path(out_dir, "forest.png")
    svg_path <- file.path(out_dir, "forest.svg")
    ggplot2::ggsave(png_path, p, width = 8, height = h, dpi = config$dpi)
    if (config$save_svg) {
      ggplot2::ggsave(svg_path, p, width = 8, height = h, device = "svg")
    } else {
      svg_path <- NA_character_
    }

    n_aug <- unique(cp$n_baseline_studies_augmented)
    n_aug_str <- if (length(n_aug) == 1 && !is.na(n_aug)) sprintf("%d", n_aug) else "n/a"
    caption <- sprintf(
      "Forest plot of top %d significantly DE genes (FDR<%g). Pool diamond (red) reflects mixed-model coefficient (k=2 pair + %s baseline studies).",
      nrow(top_genes), fdr_thr, n_aug_str
    )

  } else if (method == "rem") {
    # REM path via metafor::forest per ogni gene. Build matrix of yi, vi per gene.
    png_path <- file.path(out_dir, "forest.png")
    svg_path <- file.path(out_dir, "forest.svg")

    grDevices::png(png_path, width = 8 * config$dpi, height = max(3, nrow(top_genes) * 0.5) * config$dpi,
                   res = config$dpi)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mfrow = c(min(nrow(top_genes), 4L), 1L), mar = c(3, 1, 2, 1))
    for (g in top_genes$gene[seq_len(min(nrow(top_genes), 4L))]) {
      ps_g <- ps[ps$gene == g, , drop = FALSE]
      if (nrow(ps_g) < 2L) next
      tryCatch({
        res <- metafor::rma(yi = ps_g$logFC, sei = ps_g$SE, method = "REML")
        metafor::forest(res, slab = ps_g$study_id, header = g)
      }, error = function(e) NULL)
    }
    grDevices::dev.off()
    on.exit()

    svg_path <- NA_character_  # metafor::forest base graphics non SVG-trivial
    caption <- sprintf(
      "Forest plots for top %d significantly DE genes (FDR<%g). Each panel: per-study logFC ± 95%% CI and REML-pooled summary (k=%d).",
      min(nrow(top_genes), 4L), fdr_thr, unique(top_genes$k_effective)[1L]
    )

  } else {
    cli::cli_abort("Unknown method for forest plot: {.field {method}}")
  }

  list(
    png_path = png_path,
    svg_path = svg_path,
    caption = caption
  )
}
```

- [ ] **Step 4: Run test per pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-forest")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-plot-forest.R tests/testthat/test-layer-b-forest.R
git commit -m "P5 Stadio 4 Layer B Task 6: .build_forest()

Dispatch per metodo:
- mega_aug: custom ggplot con 2 studi pair + pooled diamond rosso
- rem: metafor::forest base graphics, 1 panel per gene (top 4)
- mega: skip-graceful con caption esplicativa

Top-N ranking by |logFC| con FDR<0.05.
Output PNG (SVG solo per mega_aug path)."
```

---

## Task 7: MA plot

**Files:**
- Create: `R/layer-b-plot-ma.R`
- Create: `tests/testthat/test-layer-b-ma.R`

- [ ] **Step 1: Test failing**

Crea `tests/testthat/test-layer-b-ma.R`:

```r
test_that(".build_ma_plot writes PNG with loess smooth", {
  cp <- make_fake_cluster_pooled(n_genes = 200, n_sig = 30)
  # Synthetic counts for baseMean computation
  counts <- matrix(rpois(200 * 6, lambda = 100), nrow = 200,
                   dimnames = list(cp$gene, paste0("GSM", 1:6)))

  out_dir <- tempfile("ma_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_ma_plot(cp, counts = counts, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "MA plot")
  expect_match(result$caption, "loess")
})
```

Per usare `make_fake_cluster_pooled` definita in test-layer-b-volcano.R, devi spostarla a un helper o ridefinirla. Sposta `make_fake_cluster_pooled` a `tests/testthat/helper-layer-b-fixtures.R` (testthat carica auto i file `helper-*.R`).

Crea `tests/testthat/helper-layer-b-fixtures.R`:

```r
# Helpers per fixture sintetiche usate dai test layer-b-*

make_fake_cluster_pooled <- function(n_genes = 100, n_sig = 20, cluster_id = "cl_test") {
  set.seed(42)
  logFC <- c(rnorm(n_sig, mean = 0, sd = 3), rnorm(n_genes - n_sig, mean = 0, sd = 0.3))
  p_value <- c(runif(n_sig, 1e-10, 0.01), runif(n_genes - n_sig, 0.05, 1))
  tibble::tibble(
    cluster_id = cluster_id,
    gene = paste0("G", seq_len(n_genes)),
    method = "mega",
    logFC_pool = logFC,
    SE_pool = abs(logFC) / 5 + 0.1,
    p_value_pool = p_value,
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = p.adjust(p_value, method = "BH"),
    direction_applied = "none"
  )
}

make_fake_per_study_de <- function(cluster_id = "cl_aug", n_genes = 50, n_studies = 2) {
  set.seed(42)
  studies <- paste0("GSE", seq_len(n_studies))
  expand.grid(study_id = studies, gene = paste0("G", seq_len(n_genes)),
              KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      cluster_id = cluster_id,
      logFC = rnorm(dplyr::n(), 0, 1),
      SE = abs(rnorm(dplyr::n(), 0.3, 0.1)),
      p_value = runif(dplyr::n(), 0, 1),
      t_stat = logFC / SE,
      n_treated = 3L, n_control = 3L,
      direction_applied = "none"
    ) |>
    dplyr::select(cluster_id, study_id, gene, logFC, SE, p_value, t_stat,
                  n_treated, n_control, direction_applied)
}
```

Rimuovi le definizioni locali da `test-layer-b-volcano.R` e `test-layer-b-forest.R` se duplicate.

- [ ] **Step 2: Run test per fail**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-ma")'
```

Expected: FAIL — `.build_ma_plot` non definita.

- [ ] **Step 3: Implementare `R/layer-b-plot-ma.R`**

Crea `R/layer-b-plot-ma.R`:

```r
#' MA plot (mean expression vs logFC) per un cluster
#'
#' X = log10(mean across-sample CPM+1), Y = logFC_pool. Loess smooth (dashed)
#' come sanity check assenza di trend mean-FC.
#'
#' @param cluster_pooled_subset tibble subset per cluster.
#' @param counts matrix integer (genes × samples) per il cluster.
#' @param out_dir character dir output.
#' @param config list.
#'
#' @return list `png_path, svg_path, caption`.
#' @keywords internal
.build_ma_plot <- function(cluster_pooled_subset, counts, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold

  # baseMean: mean log2(CPM+1) per gene
  lib_size <- colSums(counts)
  cpm <- t(t(counts) / lib_size) * 1e6
  base_mean <- rowMeans(log2(cpm + 1))

  # Match by gene
  match_idx <- match(cp$gene, names(base_mean))
  cp$baseMean <- base_mean[match_idx]
  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr

  cp_plot <- cp[!is.na(cp$baseMean), , drop = FALSE]

  p <- ggplot2::ggplot(cp_plot, ggplot2::aes(x = baseMean, y = logFC_pool)) +
    ggplot2::geom_point(ggplot2::aes(color = is_sig), alpha = 0.5, size = 1.2) +
    ggplot2::scale_color_manual(
      values = c(`TRUE` = "#CC3333", `FALSE` = "#BBBBBB"),
      labels = c(`TRUE` = sprintf("FDR<%g", fdr_thr), `FALSE` = "not sig"),
      name = NULL
    ) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "#333333", alpha = 0.5) +
    ggplot2::geom_smooth(method = "loess", se = FALSE, linetype = "dashed",
                         color = "#3366aa", linewidth = 0.6) +
    ggplot2::labs(
      x = expression(log[2]~"mean expression (CPM+1)"),
      y = expression(log[2]~"FC pooled")
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank())

  png_path <- file.path(out_dir, "ma.png")
  svg_path <- file.path(out_dir, "ma.svg")
  ggplot2::ggsave(png_path, p, width = 6, height = 6, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, p, width = 6, height = 6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "MA plot. Loess smooth (dashed blue) shows absence of mean-effect-size trend; horizontal alignment confirms TMM normalization adequacy in upstream Layer A."
  )

  list(png_path = png_path, svg_path = svg_path, caption = caption)
}
```

- [ ] **Step 4: Run test per pass**

Run:
```bash
Rscript -e 'devtools::test(filter = "layer-b-ma")'
```

Expected: PASS 1/1.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-plot-ma.R tests/testthat/test-layer-b-ma.R tests/testthat/helper-layer-b-fixtures.R
git commit -m "P5 Stadio 4 Layer B Task 7: .build_ma_plot()

MA plot: x = log2 mean(CPM+1) across samples, y = logFC_pool.
- Color FDR<0.05 vs not-sig
- Loess smooth dashed blu (sanity check assenza trend mean-FC)
- PNG 6x6 @300 DPI + SVG opzionale

Helper file tests/testthat/helper-layer-b-fixtures.R per
make_fake_cluster_pooled() + make_fake_per_study_de() condivisi."
```

---

## Task 8: Top-gene table (CSV + LaTeX)

**Files:**
- Create: `R/layer-b-plot-top-gene-table.R`
- Create: `tests/testthat/test-layer-b-top-gene-table.R`

- [ ] **Step 1: Test failing**

Crea `tests/testthat/test-layer-b-top-gene-table.R`:

```r
test_that(".build_top_gene_table writes CSV + LaTeX", {
  cp <- make_fake_cluster_pooled(n_genes = 100, n_sig = 40)
  out_dir <- tempfile("tgt_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)

  expect_named(result, c("csv_path", "tex_path", "caption", "n_rows"),
               ignore.order = TRUE)
  expect_true(file.exists(result$csv_path))
  expect_true(file.exists(result$tex_path))

  # CSV content check
  csv_df <- readr::read_csv(result$csv_path, show_col_types = FALSE)
  expect_true(all(c("gene", "logFC_pool", "SE_pool", "FDR_BH_within_cluster") %in% names(csv_df)))
  expect_lte(nrow(csv_df), cfg$top_n_table)

  # LaTeX content check
  tex <- readLines(result$tex_path)
  expect_true(any(grepl("booktabs|toprule|tabular", tex)))
})

test_that(".build_top_gene_table handles 0 sig genes", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 0)
  out_dir <- tempfile("tgt_zero_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)
  expect_equal(result$n_rows, 0L)
  expect_match(result$caption, "No genes significant")
})
```

- [ ] **Step 2: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-top-gene-table")'
```

Expected: FAIL.

- [ ] **Step 3: Implementare `R/layer-b-plot-top-gene-table.R`**

Crea `R/layer-b-plot-top-gene-table.R`:

```r
#' Top-gene table (CSV + LaTeX booktabs) per un cluster
#'
#' Top-N geni FDR<thr ranked by |logFC_pool|. Output 2 file: `top_genes.csv`
#' (machine-readable) e `top_genes.tex` (paper-ready, kableExtra booktabs).
#'
#' @param cluster_pooled_subset tibble subset per cluster.
#' @param out_dir character.
#' @param config list.
#'
#' @return list `csv_path, tex_path, caption, n_rows`.
#' @keywords internal
.build_top_gene_table <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_table

  sig <- cp[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr, , drop = FALSE]
  sig <- sig[order(abs(sig$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top <- head(sig, top_n)

  csv_path <- file.path(out_dir, "top_genes.csv")
  tex_path <- file.path(out_dir, "top_genes.tex")

  if (nrow(top) == 0L) {
    # Empty CSV + LaTeX with explanatory caption
    readr::write_csv(top, csv_path)
    writeLines(
      sprintf("%% No genes significant at FDR<%g for cluster %s.",
              fdr_thr, unique(cp$cluster_id)[1L]),
      tex_path
    )
    return(list(
      csv_path = csv_path,
      tex_path = tex_path,
      caption = sprintf("No genes significant at FDR<%g for this cluster.", fdr_thr),
      n_rows = 0L
    ))
  }

  out_cols <- c("gene", "logFC_pool", "SE_pool", "p_value_pool",
                "FDR_BH_within_cluster", "k_effective", "tau2", "I2",
                "direction_applied")
  out_cols <- intersect(out_cols, names(top))
  top_out <- top[, out_cols, drop = FALSE]

  readr::write_csv(top_out, csv_path)

  # LaTeX via kableExtra
  cluster_id_str <- unique(cp$cluster_id)[1L]
  tex_str <- kableExtra::kbl(
    top_out,
    format = "latex",
    booktabs = TRUE,
    digits = c(NA, 3, 3, -2, -2, 0, 3, 1, NA),
    caption = sprintf("Top %d differentially expressed genes for cluster %s (FDR<%g, ranked by $|\\\\log_2 FC|$).",
                      nrow(top_out), cluster_id_str, fdr_thr),
    label = sprintf("tab:top-genes-%s", gsub("[^a-zA-Z0-9]", "-", cluster_id_str))
  )
  writeLines(as.character(tex_str), tex_path)

  caption <- sprintf(
    "Top %d differentially expressed genes (FDR<%g, ranked by |logFC|). Full table in top_genes.csv.",
    nrow(top_out), fdr_thr
  )

  list(
    csv_path = csv_path,
    tex_path = tex_path,
    caption = caption,
    n_rows = nrow(top_out)
  )
}
```

- [ ] **Step 4: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-top-gene-table")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-plot-top-gene-table.R tests/testthat/test-layer-b-top-gene-table.R
git commit -m "P5 Stadio 4 Layer B Task 8: .build_top_gene_table()

Top-30 geni FDR<0.05 ranked by |logFC_pool|.
- CSV machine-readable (full schema)
- LaTeX booktabs via kableExtra (paper-ready, caption + label)
- Edge case 0 sig: file vuoti + caption esplicativa"
```

---

## Task 9: Heatmap (vst + ComBat + subsample)

**Files:**
- Create: `R/layer-b-plot-heatmap.R`
- Create: `tests/testthat/test-layer-b-heatmap.R`

- [ ] **Step 1: Test failing**

Crea `tests/testthat/test-layer-b-heatmap.R`:

```r
test_that(".build_heatmap writes PNG with vst+ComBat + annotation rows", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(42)
  n_genes <- 200
  n_samples_per_study <- 8
  n_studies <- 2
  n_samples <- n_samples_per_study * n_studies

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 50)
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", seq_len(n_studies)), each = n_samples_per_study),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "vst")
})

test_that(".build_heatmap subsamples to max_heatmap_samples", {
  skip_if_not_installed("ComplexHeatmap")
  set.seed(1)
  n_genes <- 100
  n_samples <- 150  # > max_heatmap_samples default (100)

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 30, cluster_id = "cl_big")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:3), each = 50),
    treatment = rep(c("control", "treated"), length.out = n_samples)
  )

  out_dir <- tempfile("hm_big_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_match(result$caption, "subsampled to")
})
```

- [ ] **Step 2: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-heatmap")'
```

Expected: FAIL — `.build_heatmap` non definita.

- [ ] **Step 3: Implementare `R/layer-b-plot-heatmap.R`**

Crea `R/layer-b-plot-heatmap.R`:

```r
#' Heatmap top-N geni × sample (vst + ComBat batch-corrected)
#'
#' Top-N geni FDR<thr ranked by |logFC_pool|. Counts normalize via
#' `DESeq2::vst()` + `sva::ComBat()` batch correction per `study_id` (cosmetico,
#' esplicitato nella caption). Subsample stratificato per (study, treatment)
#' se n_samples > max_heatmap_samples.
#'
#' @param counts integer matrix genes × samples (rownames = HGNC symbol).
#' @param metadata tibble con `sample_id, study_id, treatment` in colonna-order.
#' @param cluster_pooled_subset tibble per top-N selection.
#' @param out_dir character.
#' @param config list.
#'
#' @return list `png_path, svg_path, caption`.
#' @keywords internal
.build_heatmap <- function(counts, metadata, cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_heatmap
  max_samples <- config$max_heatmap_samples

  sig <- cp[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr, , drop = FALSE]
  sig <- sig[order(abs(sig$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top_genes <- head(sig$gene, top_n)

  if (length(top_genes) == 0L) {
    png_path <- file.path(out_dir, "heatmap.png")
    grDevices::png(png_path, width = 800, height = 400, res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5, sprintf("Heatmap N/A: no genes significant at FDR<%g", fdr_thr))
    grDevices::dev.off()
    return(list(png_path = png_path, svg_path = NA_character_,
                caption = sprintf("Heatmap N/A: no genes significant at FDR<%g for this cluster.", fdr_thr)))
  }

  # Subsample stratificato per (study, treatment) se necessario
  subsample_note <- ""
  if (ncol(counts) > max_samples) {
    seed <- digest::digest2int(unique(cp$cluster_id)[1L])
    set.seed(seed)
    metadata$strata <- paste(metadata$study_id, metadata$treatment, sep = "::")
    strata_sizes <- table(metadata$strata)
    # Proportional allocation, min 1 per strata
    target_per_strata <- pmax(1L, round(strata_sizes / sum(strata_sizes) * max_samples))
    # Trim if total > max_samples
    excess <- sum(target_per_strata) - max_samples
    while (excess > 0L) {
      biggest <- names(target_per_strata)[which.max(target_per_strata)]
      target_per_strata[biggest] <- target_per_strata[biggest] - 1L
      excess <- excess - 1L
    }
    picked_ids <- unlist(lapply(names(target_per_strata), function(s) {
      ids <- metadata$sample_id[metadata$strata == s]
      sample(ids, min(length(ids), target_per_strata[s]))
    }), use.names = FALSE)
    counts <- counts[, picked_ids, drop = FALSE]
    metadata <- metadata[metadata$sample_id %in% picked_ids, , drop = FALSE]
    metadata <- metadata[match(picked_ids, metadata$sample_id), , drop = FALSE]
    subsample_note <- sprintf(" Samples subsampled to %d via stratified random selection across (study, treatment) cells (seed deterministic from cluster_id).",
                              length(picked_ids))
  }

  # vst + ComBat
  dds_counts <- counts[rownames(counts) %in% top_genes, , drop = FALSE]
  # vst può richiedere sufficient counts — usa size factors estimate
  full_counts_for_sf <- counts
  vst_mat <- tryCatch({
    DESeq2::varianceStabilizingTransformation(round(as.matrix(full_counts_for_sf)), blind = TRUE)
  }, error = function(e) {
    # Fallback a log2(CPM+1) se vst fallisce (small N)
    lib_size <- colSums(full_counts_for_sf)
    log2(t(t(full_counts_for_sf) / lib_size) * 1e6 + 1)
  })
  vst_sub <- vst_mat[rownames(vst_mat) %in% top_genes, , drop = FALSE]

  combat_mat <- tryCatch({
    sva::ComBat(
      dat = vst_sub,
      batch = metadata$study_id,
      mod = stats::model.matrix(~ treatment, data = metadata)
    )
  }, error = function(e) vst_sub)

  # Row-wise z-score
  z_mat <- t(scale(t(combat_mat)))

  # Annotation
  ha <- ComplexHeatmap::HeatmapAnnotation(
    Study = metadata$study_id,
    Treatment = metadata$treatment,
    col = list(
      Study = viridisLite::viridis(length(unique(metadata$study_id))) |>
        setNames(unique(metadata$study_id)),
      Treatment = c(control = "#BBBBBB", treated = "#333333")
    ),
    annotation_height = grid::unit(c(4, 4), "mm")
  )

  hm <- ComplexHeatmap::Heatmap(
    z_mat,
    name = "z-score",
    top_annotation = ha,
    show_column_names = FALSE,
    show_row_names = TRUE,
    row_names_gp = grid::gpar(fontsize = 8),
    cluster_columns = TRUE,
    cluster_rows = TRUE,
    col = circlize::colorRamp2(c(-2, 0, 2), c("#3050a0", "white", "#c04040"))
  )

  png_path <- file.path(out_dir, "heatmap.png")
  svg_path <- file.path(out_dir, "heatmap.svg")

  grDevices::png(png_path, width = 8 * config$dpi, height = 10 * config$dpi, res = config$dpi)
  ComplexHeatmap::draw(hm)
  grDevices::dev.off()

  if (config$save_svg) {
    grDevices::svg(svg_path, width = 8, height = 10)
    ComplexHeatmap::draw(hm)
    grDevices::dev.off()
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "Heatmap of top %d DE genes (rows) across samples (columns). VST + ComBat batch correction applied for visual cross-study coherence; effect-size statistics in pooled output are NOT batch-corrected.%s",
    length(top_genes), subsample_note
  )

  list(png_path = png_path, svg_path = svg_path, caption = caption)
}
```

- [ ] **Step 4: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-heatmap")'
```

Expected: PASS 2/2 (skip se Bioc deps mancanti).

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-plot-heatmap.R tests/testthat/test-layer-b-heatmap.R
git commit -m "P5 Stadio 4 Layer B Task 9: .build_heatmap()

Top-30 geni × sample heatmap publication-grade:
- DESeq2::vst() + sva::ComBat() per coerenza visuale cross-studio
- Row-wise z-score
- Annotation rows: study (viridis) + treatment (binary)
- Subsample stratificato per (study, treatment) se > 100 sample
  (seed deterministic da cluster_id)
- ComplexHeatmap engine, PNG 8x10 + SVG
- Caption esplicita disclaimer ComBat cosmetico"
```

---

## Task 10: GO/Reactome enrichment

**Files:**
- Create: `R/layer-b-plot-go-enrichment.R`
- Create: `tests/testthat/test-layer-b-go-enrichment.R`

- [ ] **Step 1: Test failing**

Crea `tests/testthat/test-layer-b-go-enrichment.R`:

```r
test_that(".build_go_enrichment skip-graceful on small universe", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 5)  # < 200 threshold
  out_dir <- tempfile("go_small_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_go_enrichment(cp, out_dir = out_dir, config = cfg)

  expect_named(result, c("png_path", "svg_path", "csv_path", "caption"),
               ignore.order = TRUE)
  expect_match(result$caption, "below threshold")
})

test_that(".build_go_enrichment runs on real-sized universe", {
  skip_if_not_installed("clusterProfiler")
  skip_if_not_installed("org.Hs.eg.db")

  # Real HGNC symbols (subset cromatina/cell cycle che probabilmente enriched)
  real_genes <- c("TP53", "MYC", "CCND1", "CDK2", "RB1", "E2F1", "CDKN1A",
                  "MDM2", "ATM", "ATR", "BRCA1", "BRCA2", "RAD51", "CHEK1",
                  "CHEK2", "PCNA", "MCM2", "MCM3", "MCM4", "MCM5", "MCM6",
                  "MCM7", "ORC1", "CDC6", "CDT1", "GMNN", "FOXM1", "PLK1",
                  "AURKA", "AURKB", "BUB1", "BUB3", "MAD2L1", "CDC20",
                  "CCNB1", "CCNB2", "CDK1", "CDC25A", "CDC25B", "CDC25C")
  filler <- paste0("FILLER_GENE_", 1:300)
  all_genes <- c(real_genes, filler)
  n_total <- length(all_genes)

  set.seed(42)
  cp <- tibble::tibble(
    cluster_id = "cl_go",
    gene = all_genes,
    method = "mega",
    logFC_pool = c(rnorm(length(real_genes), 3, 1), rnorm(length(filler), 0, 0.3)),
    SE_pool = 0.1,
    p_value_pool = c(runif(length(real_genes), 1e-10, 0.001), runif(length(filler), 0.05, 1)),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = NA_real_,
    direction_applied = "none"
  )
  cp$FDR_BH_within_cluster <- p.adjust(cp$p_value_pool, method = "BH")

  out_dir <- tempfile("go_real_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_go_enrichment(cp, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$csv_path))
  expect_match(result$caption, "GO Biological Process")
})
```

- [ ] **Step 2: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-go-enrichment")'
```

Expected: FAIL.

- [ ] **Step 3: Implementare `R/layer-b-plot-go-enrichment.R`**

Crea `R/layer-b-plot-go-enrichment.R`:

```r
#' GO BP + Reactome enrichment per un cluster (ORA via clusterProfiler)
#'
#' Over-representation analysis: gene set = geni FDR<thr nel cluster,
#' universe = tutti i geni testati nel cluster. Skip-graceful se universo
#' sotto soglia `min_genes_for_go_ora`.
#'
#' @param cluster_pooled_subset tibble subset.
#' @param out_dir character.
#' @param config list.
#'
#' @return list `png_path, svg_path, csv_path, caption`.
#' @keywords internal
.build_go_enrichment <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  min_universe <- config$min_genes_for_go_ora

  universe <- unique(cp$gene[!is.na(cp$p_value_pool)])
  gene_set <- unique(cp$gene[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr])

  png_path <- file.path(out_dir, "go_enrichment.png")
  svg_path <- file.path(out_dir, "go_enrichment.svg")
  csv_path <- file.path(out_dir, "go_enrichment_table.csv")

  if (length(universe) < min_universe) {
    grDevices::png(png_path, width = 800, height = 400, res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5,
      sprintf("GO N/A: %d genes tested\n(below threshold %d for ORA reliability)",
              length(universe), min_universe))
    grDevices::dev.off()
    writeLines("", csv_path)
    return(list(
      png_path = png_path, svg_path = NA_character_, csv_path = csv_path,
      caption = sprintf("GO enrichment N/A: %d genes tested, below threshold %d for over-representation analysis reliability.",
                        length(universe), min_universe)
    ))
  }

  if (length(gene_set) == 0L) {
    grDevices::png(png_path, width = 800, height = 400, res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5, sprintf("GO N/A: no genes significant at FDR<%g", fdr_thr))
    grDevices::dev.off()
    writeLines("", csv_path)
    return(list(
      png_path = png_path, svg_path = NA_character_, csv_path = csv_path,
      caption = sprintf("GO enrichment N/A: no genes significant at FDR<%g.", fdr_thr)
    ))
  }

  enrich_res <- tryCatch({
    clusterProfiler::enrichGO(
      gene          = gene_set,
      universe      = universe,
      OrgDb         = org.Hs.eg.db::org.Hs.eg.db,
      keyType       = "SYMBOL",
      ont           = "BP",
      pAdjustMethod = "BH",
      qvalueCutoff  = 0.05,
      readable      = FALSE
    )
  }, error = function(e) NULL)

  if (is.null(enrich_res) || nrow(as.data.frame(enrich_res)) == 0L) {
    grDevices::png(png_path, width = 800, height = 400, res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5, "GO BP: no significant enrichment at FDR<0.05")
    grDevices::dev.off()
    writeLines("", csv_path)
    return(list(
      png_path = png_path, svg_path = NA_character_, csv_path = csv_path,
      caption = sprintf("GO Biological Process over-representation: no terms enriched at FDR<0.05 for %d input genes.",
                        length(gene_set))
    ))
  }

  enrich_df <- as.data.frame(enrich_res)
  readr::write_csv(enrich_df, csv_path)

  top_terms <- enrich_df[order(enrich_df$p.adjust), , drop = FALSE]
  top_terms <- head(top_terms, 10L)
  top_terms$neg_log10_padj <- -log10(top_terms$p.adjust)
  top_terms$Description <- factor(top_terms$Description,
                                  levels = rev(top_terms$Description))

  p <- ggplot2::ggplot(top_terms, ggplot2::aes(x = neg_log10_padj, y = Description, fill = neg_log10_padj)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_viridis_c(name = "-log10(p.adj)", option = "viridis") +
    ggplot2::labs(x = expression(-log[10]~"(p.adjust BH)"), y = NULL,
                  title = "GO Biological Process — top 10 enriched terms") +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(legend.position = "right",
                   panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(png_path, p, width = 8, height = 6, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, p, width = 8, height = 6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "GO Biological Process over-representation analysis. %d significant terms at FDR<0.05 (BH-corrected). Universe: %d genes tested in cluster.",
    nrow(enrich_df), length(universe)
  )

  list(png_path = png_path, svg_path = svg_path, csv_path = csv_path, caption = caption)
}
```

- [ ] **Step 4: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-go-enrichment")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-plot-go-enrichment.R tests/testthat/test-layer-b-go-enrichment.R
git commit -m "P5 Stadio 4 Layer B Task 10: .build_go_enrichment()

clusterProfiler::enrichGO (BP, ORA, BH).
- Universe = geni testati nel cluster; gene set = FDR<0.05.
- Skip-graceful se universo < min_genes_for_go_ora (default 200).
- Skip-graceful se 0 sig genes o 0 enriched terms.
- Barchart top-10 termini con palette viridis.
- Output: PNG 8x6, SVG, CSV con enrichment full table."
```

---

## Task 11: Heterogeneity panel (REM only)

**Files:**
- Create: `R/layer-b-plot-heterogeneity.R`
- Create: `tests/testthat/test-layer-b-heterogeneity.R`

- [ ] **Step 1: Test failing**

Crea `tests/testthat/test-layer-b-heterogeneity.R`:

```r
test_that(".build_heterogeneity_panel skip non-REM with explanatory caption", {
  cp <- make_fake_cluster_pooled(n_genes = 100, n_sig = 30, cluster_id = "cl_mega")
  cp$method <- "mega"

  out_dir <- tempfile("het_mega_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heterogeneity_panel(cp, out_dir = out_dir, config = cfg)
  expect_match(result$caption, "N/A for non-REM")
})

test_that(".build_heterogeneity_panel runs on REM cluster", {
  set.seed(42)
  cp <- make_fake_cluster_pooled(n_genes = 200, n_sig = 50, cluster_id = "cl_rem")
  cp$method <- "rem"
  cp$tau2 <- abs(rnorm(nrow(cp), 0.05, 0.1))  # mix di REM-amenable e REM-resisted
  cp$I2 <- pmin(100, abs(rnorm(nrow(cp), 30, 25)))

  out_dir <- tempfile("het_rem_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heterogeneity_panel(cp, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "REM-amenable")
})
```

- [ ] **Step 2: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-heterogeneity")'
```

Expected: FAIL.

- [ ] **Step 3: Implementare `R/layer-b-plot-heterogeneity.R`**

Crea `R/layer-b-plot-heterogeneity.R`:

```r
#' Heterogeneity panel (τ² + I² + REM-amenable split) — REM only
#'
#' Pannello 2×1: (a) histogram τ² per-gene; (b) split bar REM-amenable
#' (`tau2 < 0.1`) vs REM-resisted (`tau2 >= 0.1`) con `%` di geni FDR<0.05
#' in ciascuna classe. Skip se metodo non-REM.
#'
#' @param cluster_pooled_subset tibble subset.
#' @param out_dir character.
#' @param config list.
#'
#' @return list `png_path, svg_path, caption`.
#' @keywords internal
.build_heterogeneity_panel <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  method <- unique(cp$method)[1L]

  if (method != "rem") {
    png_path <- file.path(out_dir, "heterogeneity.png")
    grDevices::png(png_path, width = 800, height = 400, res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5, sprintf("Heterogeneity panel N/A\n(method = %s, REM-only)", method))
    grDevices::dev.off()
    return(list(
      png_path = png_path, svg_path = NA_character_,
      caption = sprintf("Heterogeneity panel N/A for non-REM methods (method=%s); per-gene τ² not estimable in mixed-model framework (mega) or pair-only design (mega_aug).", method)
    ))
  }

  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr
  cp$tau2_class <- ifelse(is.na(cp$tau2), NA_character_,
                          ifelse(cp$tau2 < 0.1, "REM-amenable (τ²<0.1)", "REM-resisted (τ²≥0.1)"))

  # Panel (a) histogram tau2
  p_hist <- ggplot2::ggplot(cp[!is.na(cp$tau2), , drop = FALSE], ggplot2::aes(x = tau2)) +
    ggplot2::geom_histogram(bins = 30, fill = "#3366aa", color = "white") +
    ggplot2::geom_vline(xintercept = 0.1, linetype = "dashed", color = "#CC3333") +
    ggplot2::labs(x = expression(tau^2~"(REML)"), y = "Count of genes") +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  # Panel (b) split bar
  split_summary <- cp[!is.na(cp$tau2_class), , drop = FALSE] |>
    dplyr::group_by(tau2_class) |>
    dplyr::summarise(
      n_total = dplyr::n(),
      n_sig = sum(is_sig, na.rm = TRUE),
      pct_sig = n_sig / n_total * 100,
      .groups = "drop"
    )

  p_split <- ggplot2::ggplot(split_summary, ggplot2::aes(x = tau2_class, y = pct_sig, fill = tau2_class)) +
    ggplot2::geom_col() +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%d / %d\n(%.1f%%)", n_sig, n_total, pct_sig)),
                       vjust = -0.3, size = 3) +
    ggplot2::scale_fill_manual(values = c("REM-amenable (τ²<0.1)" = "#3366aa",
                                          "REM-resisted (τ²≥0.1)" = "#CC3333"),
                               guide = "none") +
    ggplot2::labs(x = NULL, y = sprintf("%% of genes FDR<%g", fdr_thr)) +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank()) +
    ggplot2::expand_limits(y = max(split_summary$pct_sig, na.rm = TRUE) * 1.15)

  # Combine 2x1 via patchwork-like (use cowplot if available)
  png_path <- file.path(out_dir, "heterogeneity.png")
  svg_path <- file.path(out_dir, "heterogeneity.svg")

  combined <- if (requireNamespace("patchwork", quietly = TRUE)) {
    patchwork::wrap_plots(p_hist, p_split, ncol = 2L)
  } else {
    p_hist
  }
  ggplot2::ggsave(png_path, combined, width = 8, height = 4, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, combined, width = 8, height = 4, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  amen <- split_summary[split_summary$tau2_class == "REM-amenable (τ²<0.1)", , drop = FALSE]
  amen_pct <- if (nrow(amen) > 0L) amen$pct_sig else NA_real_

  caption <- sprintf(
    "Heterogeneity panel (REM). Left: per-gene τ² distribution (REML). Right: %% genes FDR<%g in REM-amenable (τ²<0.1) vs REM-resisted (τ²≥0.1) splits. REM-amenable: %.1f%% sig.",
    fdr_thr, amen_pct
  )

  list(png_path = png_path, svg_path = svg_path, caption = caption)
}
```

- [ ] **Step 4: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-heterogeneity")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-plot-heterogeneity.R tests/testthat/test-layer-b-heterogeneity.R
git commit -m "P5 Stadio 4 Layer B Task 11: .build_heterogeneity_panel()

REM-only:
- Pannello 2x1: histogram tau2 + split bar REM-amenable/resisted (cut=0.1)
- Skip non-REM con caption esplicativa
- patchwork combine se disponibile, fallback single panel
- Quantifica power gain effettivo del pooling per cluster"
```

---

## Task 12: Summary card + narrative template

**Files:**
- Create: `R/layer-b-summary-card.R`
- Create: `tests/testthat/test-layer-b-summary-card.R`

- [ ] **Step 1: Test failing**

Crea `tests/testthat/test-layer-b-summary-card.R`:

```r
test_that(".build_summary_card writes .md with all required fields", {
  cp <- make_fake_cluster_pooled(n_genes = 100, n_sig = 25, cluster_id = "pair_L0_test")
  cp$method <- "mega_aug"
  cp$n_baseline_studies_augmented <- 8L
  cp$k_effective <- 2L

  layer_a_subset <- list(
    cluster_pooled = cp,
    per_study_de = tibble::tibble(),
    qc_report_subset = list(),
    mega_aug_diagnostics = tibble::tibble(
      cluster_id = "pair_L0_test", bidir_collapsed_to_mono = FALSE
    ),
    stage4_run_id = "deadbeef"
  )

  stage3_meta <- tibble::tibble(
    cluster_id = "pair_L0_test",
    kind_effective = "treatment_vs_vehicle",
    agent_id = "CHEBI:17234",
    tissue = "A549",
    safety_min = 0.92
  )

  out_dir <- tempfile("sc_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  selection_row <- tibble::tibble(
    cluster_id = "pair_L0_test",
    label_paper = "IFN_A549_test",
    priority = 1L,
    notes = ""
  )

  result <- simulomicsr:::.build_summary_card(
    cluster_id = "pair_L0_test",
    layer_a_subset = layer_a_subset,
    stage3_metadata = stage3_meta,
    selection_row = selection_row,
    config = cfg
  )

  expect_true(file.exists(result$md_path))
  md_content <- readLines(result$md_path)
  joined <- paste(md_content, collapse = "\n")
  expect_match(joined, "pair_L0_test")
  expect_match(joined, "IFN_A549_test")
  expect_match(joined, "mega_aug")
  expect_match(joined, "k.*=.*2")
  expect_match(joined, "safety_min")
  expect_match(joined, "8")  # n_baseline_studies_augmented
})

test_that(".write_narrative_template writes .qmd with required TODO sections", {
  out_dir <- tempfile("nt_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  selection_row <- tibble::tibble(
    cluster_id = "cl_test", label_paper = "Test Case",
    priority = 1L, notes = ""
  )

  qmd_path <- simulomicsr:::.write_narrative_template(
    cluster_id = "cl_test",
    summary_card_path = NULL,
    selection_row = selection_row,
    config = cfg
  )
  qmd_path_resolved <- file.path(out_dir, basename(qmd_path))
  # since .write_narrative_template signature can be modified to accept out_dir, adapt:
  expect_true(file.exists(qmd_path))
  content <- paste(readLines(qmd_path), collapse = "\n")
  expect_match(content, "Biological context")
  expect_match(content, "Findings")
  expect_match(content, "Discussion")
  expect_match(content, "TODO")
  expect_match(content, "Test Case")
})
```

- [ ] **Step 2: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-summary-card")'
```

Expected: FAIL.

- [ ] **Step 3: Implementare `R/layer-b-summary-card.R`**

Crea `R/layer-b-summary-card.R`:

```r
#' Costruisci summary card (.md) per un cluster Layer B
#'
#' Card 1-pagina con metadata cluster: cluster_id, label_paper, anchor, method,
#' k_effective, n_studies, n_total_samples, n_sig_FDR05, top-gene, safety_min,
#' tau2_median (REM only), direction_applied distribution, n_baseline_studies_augmented
#' (MEGA-AUG only). Output embedabile nel report Quarto aggregato.
#'
#' @param cluster_id character (1).
#' @param layer_a_subset list (output di `.fetch_layer_a_subset`).
#' @param stage3_metadata tibble con colonne anchor (kind_effective, agent_id,
#'   tissue, safety_min, ...).
#' @param selection_row tibble (1 row) con `cluster_id, label_paper, priority, notes`.
#' @param config list.
#' @param out_dir character; se NULL, usa `tempdir()`.
#'
#' @return list `md_path`.
#' @keywords internal
.build_summary_card <- function(cluster_id, layer_a_subset, stage3_metadata,
                                selection_row, config, out_dir = tempdir()) {
  cp <- layer_a_subset$cluster_pooled
  cp_c <- cp[cp$cluster_id == cluster_id, , drop = FALSE]
  if (nrow(cp_c) == 0L) {
    cli::cli_abort("No rows in cluster_pooled for cluster {.field {cluster_id}}")
  }

  fdr_thr <- config$fdr_threshold
  method <- unique(cp_c$method)[1L]
  k_eff <- unique(cp_c$k_effective)[1L]
  n_sig <- sum(!is.na(cp_c$FDR_BH_within_cluster) & cp_c$FDR_BH_within_cluster < fdr_thr)
  n_total <- nrow(cp_c)
  pct_sig <- if (n_total > 0L) n_sig / n_total * 100 else NA_real_

  # Top gene
  sig <- cp_c[!is.na(cp_c$FDR_BH_within_cluster) & cp_c$FDR_BH_within_cluster < fdr_thr, , drop = FALSE]
  sig <- sig[order(abs(sig$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top_gene_str <- if (nrow(sig) > 0L) {
    sprintf("%s (logFC=%.2f, FDR=%.2g)", sig$gene[1L], sig$logFC_pool[1L], sig$FDR_BH_within_cluster[1L])
  } else {
    "(none significant)"
  }

  # tau2_median for REM
  tau2_median_str <- if (method == "rem" && any(!is.na(cp_c$tau2))) {
    sprintf("%.4f", median(cp_c$tau2, na.rm = TRUE))
  } else {
    "N/A (non-REM)"
  }

  # direction distribution
  dir_tbl <- table(cp_c$direction_applied, useNA = "ifany")
  dir_str <- paste(sprintf("%s: %d", names(dir_tbl), as.integer(dir_tbl)), collapse = "; ")

  # Stage 3 metadata
  s3_row <- stage3_metadata[stage3_metadata$cluster_id == cluster_id, , drop = FALSE]
  anchor_str <- if (nrow(s3_row) > 0L) {
    sprintf("%s × %s (tissue=%s)",
            s3_row$kind_effective[1L] %||% "?",
            s3_row$agent_id[1L] %||% "?",
            s3_row$tissue[1L] %||% "?")
  } else {
    "(no Stage 3 metadata)"
  }
  safety_str <- if (nrow(s3_row) > 0L) sprintf("%.2f", s3_row$safety_min[1L]) else "N/A"

  # n_baseline_studies_augmented for MEGA-AUG
  n_aug_str <- if (method == "mega_aug") {
    n_aug <- unique(cp_c$n_baseline_studies_augmented)
    n_aug <- n_aug[!is.na(n_aug)]
    if (length(n_aug) > 0L) as.character(n_aug[1L]) else "N/A"
  } else {
    "N/A (non-MEGA-AUG)"
  }

  # n_total_samples: from layer_a_subset$per_study_de if available, else from mega_aug_diagnostics
  n_total_samples_str <- "N/A"
  ps <- layer_a_subset$per_study_de
  if (!is.null(ps) && nrow(ps) > 0L) {
    ps_c <- ps[ps$cluster_id == cluster_id, , drop = FALSE]
    if (nrow(ps_c) > 0L) {
      n_total_samples_str <- as.character(
        sum(unique(ps_c[, c("study_id", "n_treated", "n_control")])$n_treated +
            unique(ps_c[, c("study_id", "n_treated", "n_control")])$n_control)
      )
    }
  }

  md_lines <- c(
    sprintf("# %s — Cluster %s", selection_row$label_paper[1L], cluster_id),
    "",
    sprintf("- **Cluster ID:** `%s`", cluster_id),
    sprintf("- **Anchor:** %s", anchor_str),
    sprintf("- **Method:** `%s`", method),
    sprintf("- **k_effective:** %s", as.character(k_eff)),
    sprintf("- **n_total_samples:** %s", n_total_samples_str),
    sprintf("- **n_sig FDR<%g:** %d / %d (%.1f%%)", fdr_thr, n_sig, n_total, pct_sig),
    sprintf("- **Top gene:** %s", top_gene_str),
    sprintf("- **safety_min (Stage 3):** %s", safety_str),
    sprintf("- **τ² median:** %s", tau2_median_str),
    sprintf("- **n_baseline_studies_augmented:** %s", n_aug_str),
    sprintf("- **direction_applied distribution:** %s", dir_str),
    "",
    if (nzchar(selection_row$notes[1L])) sprintf("**User notes:** %s", selection_row$notes[1L]) else NULL
  )
  md_lines <- md_lines[!is.null(md_lines)]

  md_path <- file.path(out_dir, "summary_card.md")
  writeLines(md_lines, md_path)

  list(md_path = md_path)
}

#' Scrivi narrative.qmd template per un cluster
#'
#' Template Quarto con sezioni TODO ("Biological context", "Findings",
#' "Discussion") che l'utente cura a mano. Embed pointer al summary_card.md
#' + lista figure.
#'
#' @param cluster_id character (1).
#' @param summary_card_path character path al summary_card.md (NULL OK; entry skip).
#' @param selection_row tibble (1 row).
#' @param config list.
#' @param out_dir character.
#'
#' @return character path al .qmd scritto.
#' @keywords internal
.write_narrative_template <- function(cluster_id, summary_card_path, selection_row,
                                      config, out_dir = tempdir()) {
  label_paper <- selection_row$label_paper[1L]

  qmd_lines <- c(
    "---",
    sprintf('title: "Case study: %s (%s)"', label_paper, cluster_id),
    "---",
    "",
    sprintf("# Case study: %s", label_paper),
    "",
    "## Summary card",
    "",
    if (!is.null(summary_card_path) && file.exists(summary_card_path)) {
      paste(readLines(summary_card_path), collapse = "\n")
    } else {
      sprintf("_(summary_card.md not yet generated for cluster %s)_", cluster_id)
    },
    "",
    "## Biological context",
    "",
    "_TODO: write biological narrative (1-2 paragraphs). What is the",
    "biological intervention/disease? Why is this comparison interesting?",
    "What known mechanisms apply?_",
    "",
    "## Findings",
    "",
    "_TODO: interpret top-30 genes table + volcano + GO enrichment.",
    "Which genes confirm known biology? Are there surprises? Cross-reference",
    "with literature._",
    "",
    "## Discussion",
    "",
    "_TODO: discuss heterogeneity (if REM), cross-study consistency (forest),",
    "caveats (mega_aug baseline-pool), implications for the field._",
    "",
    "## Figures",
    "",
    "::: {.figure-list}",
    "- volcano.svg",
    "- forest.svg (REM/MEGA-AUG only)",
    "- ma.svg",
    "- heatmap.svg",
    "- go_enrichment.svg",
    "- heterogeneity.svg (REM only)",
    ":::"
  )

  qmd_path <- file.path(out_dir, "narrative.qmd")
  writeLines(qmd_lines, qmd_path)
  qmd_path
}
```

- [ ] **Step 4: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-summary-card")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-summary-card.R tests/testthat/test-layer-b-summary-card.R
git commit -m "P5 Stadio 4 Layer B Task 12: summary card + narrative template

.build_summary_card(): card .md con cluster_id, anchor (Stage 3),
method, k_eff, n_sig, top-gene, safety_min, tau2_median (REM),
n_baseline_studies_augmented (MEGA-AUG), direction_applied dist.

.write_narrative_template(): .qmd con frontmatter Quarto + sezioni
TODO 'Biological context'/'Findings'/'Discussion' + figure list.
Lingua: inglese (paper-ready)."
```

---

## Task 13: Utils + write/load round-trip

**Files:**
- Create: `R/layer-b-utils.R`
- Create: `R/layer-b-write.R`
- Create: `tests/testthat/test-layer-b-utils.R`
- Create: `tests/testthat/test-layer-b-write.R`

- [ ] **Step 1: Test failing per `.run_id_for_layer_b`**

Crea `tests/testthat/test-layer-b-utils.R`:

```r
test_that(".run_id_for_layer_b is deterministic", {
  id_a <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef",
    selection_sha256 = "abc123",
    config = layer_b_default_config(),
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  id_b <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef",
    selection_sha256 = "abc123",
    config = layer_b_default_config(),
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  expect_equal(id_a, id_b)
  expect_match(id_a, "^[a-f0-9]{8}$")
})

test_that(".run_id_for_layer_b changes if config changes", {
  id_a <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef", selection_sha256 = "abc",
    config = layer_b_default_config(),
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  cfg2 <- layer_b_default_config(); cfg2$top_n_table <- 50L
  id_b <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef", selection_sha256 = "abc",
    config = cfg2,
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  expect_false(id_a == id_b)
})
```

- [ ] **Step 2: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-utils")'
```

Expected: FAIL.

- [ ] **Step 3: Implementare `R/layer-b-utils.R`**

Crea `R/layer-b-utils.R`:

```r
#' Genera run_id deterministico per Layer B
#'
#' Hash a 8-hex di canonical-form(stage4_run_id + selection_csv_sha256 +
#' config + schema_versions). Idempotenza: stesso input → stesso run_id.
#'
#' @param stage4_run_id character (1).
#' @param selection_sha256 character (1).
#' @param config list (vedi `layer_b_default_config()`).
#' @param schema_versions list (e.g. `list(layer_b_algorithm = "v1", stage4_algorithm = "v1")`).
#'
#' @return character 8-hex.
#' @keywords internal
.run_id_for_layer_b <- function(stage4_run_id, selection_sha256, config, schema_versions) {
  payload <- list(
    stage4_run_id = stage4_run_id,
    selection_sha256 = selection_sha256,
    config = config[order(names(config))],
    schema_versions = schema_versions[order(names(schema_versions))]
  )
  substr(digest::digest(payload, algo = "sha256"), 1L, 8L)
}

#' Carica selection_sha256 da un CSV
#' @keywords internal
.sha256_of_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}
```

- [ ] **Step 4: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-utils")'
```

Expected: PASS 2/2.

- [ ] **Step 5: Test failing per `write_layer_b_to_dir` + `load_layer_b`**

Crea `tests/testthat/test-layer-b-write.R`:

```r
test_that("write_layer_b_to_dir + load_layer_b round-trip", {
  # Build a minimal layer_b_result object
  lb <- structure(
    list(
      cluster_bundles = list(
        cl_a = list(
          cluster_id = "cl_a",
          plots = list(
            volcano = list(png_path = "cl_a/volcano.png", svg_path = "cl_a/volcano.svg", caption = "volcano A"),
            ma = list(png_path = "cl_a/ma.png", svg_path = "cl_a/ma.svg", caption = "ma A")
          ),
          summary_card_path = "cl_a/summary_card.md",
          narrative_path = "cl_a/narrative.qmd"
        )
      ),
      selection_resolved = tibble::tibble(
        cluster_id = "cl_a", label_paper = "A", priority = 1L, notes = "",
        exists_in_stage4 = TRUE, method = "mega", k_effective = 5L, n_sig_FDR05 = 10L
      ),
      run_metadata = list(
        run_id = "abcd1234",
        timestamp = "2026-05-24T12:00:00Z",
        config = layer_b_default_config(),
        schema_versions = list(layer_b_algorithm = "v1")
      )
    ),
    class = "layer_b_result"
  )

  d <- tempfile("lb_write_")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))

  # Create the per-cluster dir + dummy files so write_layer_b_to_dir succeeds
  dir.create(file.path(d, "cl_a"))
  file.create(file.path(d, "cl_a", "volcano.png"))
  file.create(file.path(d, "cl_a", "summary_card.md"))
  file.create(file.path(d, "cl_a", "narrative.qmd"))

  write_layer_b_to_dir(lb, d)

  expect_true(file.exists(file.path(d, "selection_resolved.csv")))
  expect_true(file.exists(file.path(d, "run_metadata.json")))

  lb2 <- load_layer_b(d)
  expect_s3_class(lb2, "layer_b_result")
  expect_equal(lb2$run_metadata$run_id, "abcd1234")
  expect_equal(nrow(lb2$selection_resolved), 1L)
})
```

- [ ] **Step 6: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-write")'
```

Expected: FAIL.

- [ ] **Step 7: Implementare `R/layer-b-write.R`**

Crea `R/layer-b-write.R`:

```r
#' Scrive bundle Layer B su directory
#'
#' Scrive `selection_resolved.csv`, `run_metadata.json` + assume che i file
#' per-cluster siano già stati scritti in place (la generazione è delegata a
#' `build_layer_b_results()`).
#'
#' @param lb oggetto `layer_b_result` (S3 list).
#' @param dir character path (creato se non esiste).
#'
#' @return invisible(`dir`).
#' @export
write_layer_b_to_dir <- function(lb, dir) {
  stopifnot(inherits(lb, "layer_b_result"))
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

  readr::write_csv(lb$selection_resolved, file.path(dir, "selection_resolved.csv"))
  jsonlite::write_json(
    lb$run_metadata,
    file.path(dir, "run_metadata.json"),
    auto_unbox = TRUE, pretty = TRUE
  )

  # captions.json per ogni cluster bundle (se non già scritto)
  for (cl_id in names(lb$cluster_bundles)) {
    bundle <- lb$cluster_bundles[[cl_id]]
    cl_dir <- file.path(dir, cl_id)
    if (!dir.exists(cl_dir)) dir.create(cl_dir, recursive = TRUE)
    captions <- lapply(bundle$plots, function(p) p$caption)
    names(captions) <- names(bundle$plots)
    jsonlite::write_json(captions, file.path(cl_dir, "captions.json"),
                         auto_unbox = TRUE, pretty = TRUE)
  }

  invisible(dir)
}

#' Carica bundle Layer B da directory
#'
#' Reads back `selection_resolved.csv`, `run_metadata.json`, e ricostruisce
#' lo scheletro `layer_b_result` con paths ai file per-cluster (NON ricarica
#' i plot binari).
#'
#' @param dir character path.
#'
#' @return `layer_b_result` S3.
#' @export
load_layer_b <- function(dir) {
  sel_path <- file.path(dir, "selection_resolved.csv")
  meta_path <- file.path(dir, "run_metadata.json")
  if (!file.exists(sel_path) || !file.exists(meta_path)) {
    cli::cli_abort("Layer B dir incomplete: missing {.path selection_resolved.csv} or {.path run_metadata.json}")
  }

  sel <- readr::read_csv(sel_path, show_col_types = FALSE)
  meta <- jsonlite::read_json(meta_path)

  cluster_ids <- sel$cluster_id
  bundles <- lapply(cluster_ids, function(cl_id) {
    cl_dir <- file.path(dir, cl_id)
    captions_path <- file.path(cl_dir, "captions.json")
    captions <- if (file.exists(captions_path)) jsonlite::read_json(captions_path) else list()

    list(
      cluster_id = cl_id,
      cluster_dir = cl_dir,
      plot_files = list.files(cl_dir, pattern = "\\.(png|svg|csv|tex|md|qmd|json)$", full.names = TRUE),
      captions = captions
    )
  })
  names(bundles) <- cluster_ids

  structure(
    list(
      cluster_bundles = bundles,
      selection_resolved = sel,
      run_metadata = meta,
      dir = dir
    ),
    class = "layer_b_result"
  )
}
```

- [ ] **Step 8: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-write")'
```

Expected: PASS 1/1.

- [ ] **Step 9: Commit**

```bash
git add R/layer-b-utils.R R/layer-b-write.R tests/testthat/test-layer-b-utils.R tests/testthat/test-layer-b-write.R
git commit -m "P5 Stadio 4 Layer B Task 13: utils + write/load round-trip

.run_id_for_layer_b(): 8-hex deterministico da
hash(stage4_run_id + selection_sha256 + config + schema_versions).
Ordina i campi config + schema_versions per stabilità cross-platform.

.sha256_of_file(): helper per selection_sha256.

write_layer_b_to_dir(): scrive selection_resolved.csv + run_metadata.json
+ captions.json per cluster (file plot stessi già scritti dal builder).

load_layer_b(): ricostruisce skeleton da dir, NO ricarica binari.
Lista plot_files + captions per cluster."
```

---

## Task 14: Build orchestrator (`build_layer_b_results`)

**Files:**
- Create: `R/layer-b-build.R`
- Create: `tests/testthat/test-layer-b-build.R`

- [ ] **Step 1: Test failing — integration mini**

Per questo task serve un fixture Layer A completo (parquet + cache counts).
Lo costruiamo nel test usando il pattern di Task 3/4. Crea
`tests/testthat/test-layer-b-build.R`:

```r
make_fake_layer_a_dir <- function() {
  d <- tempfile("stage4_full_")
  dir.create(d)

  # Cluster pooled: 2 cluster (1 mega + 1 mega_aug), 100 geni ciascuno
  set.seed(42)
  build_cp_chunk <- function(cluster_id, method, n_genes = 100, n_sig = 25) {
    logFC <- c(rnorm(n_sig, 0, 3), rnorm(n_genes - n_sig, 0, 0.3))
    pv <- c(runif(n_sig, 1e-10, 0.001), runif(n_genes - n_sig, 0.05, 1))
    tibble::tibble(
      cluster_id = cluster_id,
      gene = paste0("HGNC", seq_len(n_genes)),
      method = method,
      logFC_pool = logFC,
      SE_pool = abs(logFC)/5 + 0.1,
      p_value_pool = pv,
      tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
      k_effective = if (method == "mega") 5L else 2L,
      n_baseline_studies_augmented = if (method == "mega_aug") 8L else NA_integer_,
      FDR_BH_within_cluster = p.adjust(pv, "BH"),
      direction_applied = "none"
    )
  }
  cp <- dplyr::bind_rows(
    build_cp_chunk("cl_mega_1", "mega"),
    build_cp_chunk("cl_aug_1", "mega_aug")
  )
  arrow::write_parquet(cp, file.path(d, "cluster_pooled.parquet"))

  # Per-study DE solo per mega_aug
  ps <- tibble::tibble(
    cluster_id = rep("cl_aug_1", 200L),
    study_id   = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 100L),
    gene       = rep(paste0("HGNC", 1:100), 2L),
    logFC      = rnorm(200, 0, 1),
    SE         = abs(rnorm(200, 0.3, 0.1)),
    p_value    = runif(200, 0, 1),
    t_stat     = rnorm(200, 0, 2),
    n_treated  = 3L, n_control = 3L,
    direction_applied = "none"
  )
  arrow::write_parquet(ps, file.path(d, "per_study_de.parquet"))

  qc <- list(
    qc_drops_sample = tibble::tibble(),
    qc_drops_study = tibble::tibble(),
    qc_drops_cluster = tibble::tibble(),
    pooling_warnings = tibble::tibble(),
    mega_aug_diagnostics = tibble::tibble(
      cluster_id = "cl_aug_1", bidir_collapsed_to_mono = FALSE,
      comparison_kind_overall = "direct_overlap"
    )
  )
  saveRDS(qc, file.path(d, "qc_report.rds"))
  saveRDS(tibble::tibble(), file.path(d, "non_processable.rds"))

  meta <- list(
    run_id = "fakea4ce",
    config = list(de_engine = list(mega = "dream"))
  )
  jsonlite::write_json(meta, file.path(d, "run_metadata.json"), auto_unbox = TRUE)

  d
}

make_fake_counts_cache <- function(cluster_ids, samples_per_study = 6L) {
  cache_dir <- tempfile("counts_cache_")
  dir.create(cache_dir)

  manifest <- list()
  for (cl_id in cluster_ids) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    manifest[[cl_id]] <- list()
    for (s in studies) {
      counts <- matrix(rpois(100 * samples_per_study, lambda = 100), nrow = 100,
                       dimnames = list(paste0("HGNC", 1:100),
                                       paste0(s, "_GSM", 1:samples_per_study)))
      path <- file.path(cache_dir, sprintf("%s_%s.rds", cl_id, s))
      saveRDS(counts, path)
      manifest[[cl_id]][[s]] <- path
    }
  }
  list(dir = cache_dir, manifest = manifest)
}

test_that("build_layer_b_results end-to-end on mini fixture", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))
  on.exit(unlink(cache$dir, recursive = TRUE), add = TRUE)

  # Build per_cluster_samples: 2 study × 3 sample per study × 2 treatment
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }

  selection <- tibble::tibble(
    cluster_id = c("cl_mega_1", "cl_aug_1"),
    label_paper = c("MegaTest", "AugTest"),
    priority = c(1L, 2L),
    notes = c("", "")
  )

  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE  # skip in test (slow + needs real symbols)

  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("lb_out_")
  )

  expect_s3_class(result, "layer_b_result")
  expect_equal(length(result$cluster_bundles), 2L)
  expect_true(file.exists(file.path(result$dir, "selection_resolved.csv")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "volcano.png")))
  expect_true(file.exists(file.path(result$dir, "cl_aug_1", "forest.png")))
  # mega should NOT have forest png (skip-graceful)
  expect_false(file.exists(file.path(result$dir, "cl_mega_1", "forest.png")))
  expect_match(result$run_metadata$run_id, "^[a-f0-9]{8}$")
})
```

- [ ] **Step 2: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-build")'
```

Expected: FAIL.

- [ ] **Step 3: Implementare `R/layer-b-build.R`**

Crea `R/layer-b-build.R`:

```r
#' Build Layer B results (orchestrator)
#'
#' Entry-point public. Esegue i 3 sub-stage: B.1 Loader+QC, B.2 Asset gen
#' (8 plot per cluster + summary card + narrative template), B.3 (delegato
#' a `render_layer_b_report()` chiamato dal caller).
#'
#' @param stage4_dir character path Layer A output.
#' @param selection character path-to-CSV o data.frame.
#' @param counts_cache_manifest list nested `cache[[cluster_id]][[study_id]] = path`.
#'   Tipicamente derivato dal `counts_cache_manifest` di Stage 4.
#' @param per_cluster_samples_provider function(cluster_id) → tibble
#'   `sample_id, study_id, treatment` per il cluster (assemblata upstream
#'   dal join Stage 3 assignment + Stage 2 design_role).
#' @param stage3_metadata tibble opzionale con `cluster_id, kind_effective,
#'   agent_id, tissue, safety_min` (per summary card). NULL → summary card
#'   senza Stage 3 fields.
#' @param config list (vedi `layer_b_default_config()`).
#' @param out_dir character path output dir. Se NULL, genera dir versionata
#'   in `analysis/p4-output/<ts>-layer-b-<run_id>/`.
#' @param h5_path character path al H5 ARCHS4 (per re-fetch counts in caso
#'   di cache miss; NULL = nessun fetch fallback).
#'
#' @return `layer_b_result` S3 list.
#' @export
build_layer_b_results <- function(stage4_dir, selection,
                                   counts_cache_manifest,
                                   per_cluster_samples_provider,
                                   stage3_metadata = NULL,
                                   config = layer_b_default_config(),
                                   out_dir = NULL,
                                   h5_path = NULL) {
  cli::cli_h1("Layer B build")
  t0 <- Sys.time()

  # B.1 Loader + QC
  cli::cli_alert_info("B.1 Loader + validation")
  sel_resolved <- layer_b_validate_selection(selection, stage4_dir, config$fdr_threshold)
  cluster_ids <- sel_resolved$cluster_id

  layer_a_subset <- .fetch_layer_a_subset(stage4_dir, cluster_ids)

  # Stage 3 metadata default empty tibble
  if (is.null(stage3_metadata)) {
    stage3_metadata <- tibble::tibble(
      cluster_id = character(),
      kind_effective = character(), agent_id = character(),
      tissue = character(), safety_min = numeric()
    )
  }

  # B.2 Asset gen
  cli::cli_alert_info("B.2 Asset generation ({.field {length(cluster_ids)}} cluster)")

  # Hash selection per run_id
  sel_for_hash <- sel_resolved[order(sel_resolved$cluster_id), c("cluster_id", "label_paper", "priority", "notes")]
  sel_sha <- digest::digest(sel_for_hash, algo = "sha256")

  schema_versions <- list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  run_id <- .run_id_for_layer_b(
    stage4_run_id    = layer_a_subset$stage4_run_id,
    selection_sha256 = sel_sha,
    config           = config,
    schema_versions  = schema_versions
  )

  if (is.null(out_dir)) {
    out_dir <- file.path(
      "analysis/p4-output",
      sprintf("%s-layer-b-%s",
              format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), run_id)
    )
  }
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  cluster_bundles <- list()
  for (cl_id in cluster_ids) {
    cli::cli_alert("Processing {.field {cl_id}}...")
    cl_dir <- file.path(out_dir, cl_id)
    if (!dir.exists(cl_dir)) dir.create(cl_dir, recursive = TRUE)

    cp_sub <- layer_a_subset$cluster_pooled[layer_a_subset$cluster_pooled$cluster_id == cl_id, , drop = FALSE]
    ps_sub <- layer_a_subset$per_study_de[layer_a_subset$per_study_de$cluster_id == cl_id, , drop = FALSE]
    method <- unique(cp_sub$method)[1L]

    # Counts assembly
    per_cluster_samples <- per_cluster_samples_provider(cl_id)
    counts_meta <- .assemble_cluster_counts(cl_id, per_cluster_samples, counts_cache_manifest)

    plots <- list()
    plots$volcano <- .build_volcano(cp_sub, out_dir = cl_dir, config = config)
    plots$forest  <- .build_forest(ps_sub, cp_sub, method = method, out_dir = cl_dir, config = config)
    plots$ma      <- .build_ma_plot(cp_sub, counts = counts_meta$counts, out_dir = cl_dir, config = config)
    plots$top_gene_table <- .build_top_gene_table(cp_sub, out_dir = cl_dir, config = config)
    plots$heatmap <- .build_heatmap(counts_meta$counts, counts_meta$metadata, cp_sub,
                                    out_dir = cl_dir, config = config)
    if (isTRUE(config$go_enrichment)) {
      plots$go_enrichment <- .build_go_enrichment(cp_sub, out_dir = cl_dir, config = config)
    }
    plots$heterogeneity <- .build_heterogeneity_panel(cp_sub, out_dir = cl_dir, config = config)

    selection_row <- sel_resolved[sel_resolved$cluster_id == cl_id, , drop = FALSE]
    summary_card <- .build_summary_card(cl_id, layer_a_subset, stage3_metadata,
                                        selection_row, config, out_dir = cl_dir)
    narrative_path <- .write_narrative_template(cl_id, summary_card$md_path,
                                                selection_row, config, out_dir = cl_dir)

    cluster_bundles[[cl_id]] <- list(
      cluster_id = cl_id,
      cluster_dir = cl_dir,
      plots = plots,
      summary_card_path = summary_card$md_path,
      narrative_path = narrative_path
    )
  }

  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  run_metadata <- list(
    run_id = run_id,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    schema_versions = schema_versions,
    package_version = as.character(utils::packageVersion("simulomicsr")),
    r_version = R.version.string,
    input_files = list(
      stage4_dir = list(path = stage4_dir, run_id = layer_a_subset$stage4_run_id),
      selection_sha256 = sel_sha
    ),
    config = config,
    output_counts = list(
      n_clusters_processed = length(cluster_ids),
      by_method = as.list(table(sel_resolved$method))
    ),
    compute_summary = list(wall_seconds = wall)
  )

  result <- structure(
    list(
      cluster_bundles = cluster_bundles,
      selection_resolved = sel_resolved,
      run_metadata = run_metadata,
      dir = out_dir
    ),
    class = "layer_b_result"
  )

  write_layer_b_to_dir(result, out_dir)

  cli::cli_alert_success("Layer B build OK in {.field {round(wall, 1)}s}: {.path {out_dir}}")
  result
}
```

- [ ] **Step 4: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-build")'
```

Expected: PASS 1/1.

- [ ] **Step 5: Commit**

```bash
git add R/layer-b-build.R tests/testthat/test-layer-b-build.R
git commit -m "P5 Stadio 4 Layer B Task 14: build_layer_b_results() orchestrator

Entry-point public per il bundle Layer B end-to-end:
- B.1: validate_selection + fetch_layer_a_subset
- B.2: per cluster genera tutti 8 plot (conditional dispatch) +
  summary card + narrative template
- run_id deterministico da hash(stage4_run_id + selection + config + schema)
- write_layer_b_to_dir chiamato in-line al termine

per_cluster_samples_provider è una function injection per disaccoppiare
il join Stage 3-assignment dal builder (testabile in isolation)."
```

---

## Task 15: Aggregate report (Quarto)

**Files:**
- Create: `R/layer-b-report.R`
- Create: `inst/templates/layer-b-report.qmd`
- Create: `tests/testthat/test-layer-b-report.R`

- [ ] **Step 1: Template Quarto**

Crea `inst/templates/layer-b-report.qmd`:

```markdown
---
title: "Layer B Case Studies"
format:
  html:
    embed-resources: true
    toc: true
    toc-depth: 2
    code-fold: true
    fig-cap-location: bottom
params:
  layer_b_dir: ""
execute:
  echo: false
  warning: false
  message: false
---

```{r setup}
library(simulomicsr)
lb <- load_layer_b(params$layer_b_dir)
```

# Overview

Run id: ``r lb$run_metadata$run_id``
Generated: ``r lb$run_metadata$timestamp``
Package version: ``r lb$run_metadata$package_version``

## Selection

```{r selection-table}
DT::datatable(lb$selection_resolved, options = list(pageLength = 25))
```

## Methods note

Config used:

```{r config-print}
yaml::as.yaml(lb$run_metadata$config) |> cat()
```

# Case studies

```{r case-studies, results = "asis"}
for (cl_id in names(lb$cluster_bundles)) {
  bundle <- lb$cluster_bundles[[cl_id]]
  label_paper <- lb$selection_resolved$label_paper[lb$selection_resolved$cluster_id == cl_id]

  cat(sprintf("\n\n## %s — %s\n\n", label_paper, cl_id))

  # Summary card
  smc_path <- file.path(bundle$cluster_dir, "summary_card.md")
  if (file.exists(smc_path)) {
    cat(paste(readLines(smc_path), collapse = "\n"), "\n\n")
  }

  # Plots (PNG embeds)
  for (plot_name in c("volcano", "forest", "ma", "heatmap", "go_enrichment", "heterogeneity")) {
    png_path <- file.path(bundle$cluster_dir, sprintf("%s.png", plot_name))
    caption <- bundle$captions[[plot_name]] %||% sprintf("%s (no caption)", plot_name)
    if (file.exists(png_path)) {
      cat(sprintf("\n![%s](%s)\n\n", caption, png_path))
    }
  }

  # Top-gene table
  tg_csv <- file.path(bundle$cluster_dir, "top_genes.csv")
  if (file.exists(tg_csv) && file.info(tg_csv)$size > 0L) {
    df <- readr::read_csv(tg_csv, show_col_types = FALSE)
    if (nrow(df) > 0L) {
      cat("\n### Top-gene table\n\n")
      print(knitr::kable(df, format = "html", digits = 3))
    }
  }

  # Narrative
  narr_path <- file.path(bundle$cluster_dir, "narrative.qmd")
  if (file.exists(narr_path)) {
    cat("\n### Narrative\n\n")
    narr_lines <- readLines(narr_path)
    # Strip frontmatter
    body_start <- which(narr_lines == "---")
    if (length(body_start) >= 2L) {
      narr_lines <- narr_lines[(body_start[2L] + 1L):length(narr_lines)]
    }
    cat(paste(narr_lines, collapse = "\n"), "\n")
  }
}
```
```

- [ ] **Step 2: Test failing**

Crea `tests/testthat/test-layer-b-report.R`:

```r
test_that("render_layer_b_report produces HTML standalone", {
  skip_if_not_installed("quarto")
  skip_if(Sys.which("quarto") == "")

  # Create a minimal layer_b dir
  d <- tempfile("lb_rep_")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))

  sel <- tibble::tibble(
    cluster_id = "cl_test", label_paper = "Test", priority = 1L, notes = "",
    exists_in_stage4 = TRUE, method = "mega", k_effective = 5L, n_sig_FDR05 = 10L
  )
  readr::write_csv(sel, file.path(d, "selection_resolved.csv"))

  meta <- list(run_id = "rep01234", timestamp = "2026-05-24T00:00:00Z",
               package_version = "0.0.0.9020", config = list())
  jsonlite::write_json(meta, file.path(d, "run_metadata.json"), auto_unbox = TRUE)

  cl_dir <- file.path(d, "cl_test"); dir.create(cl_dir)
  writeLines("# Test summary", file.path(cl_dir, "summary_card.md"))
  writeLines("# Test narrative\n_TODO_", file.path(cl_dir, "narrative.qmd"))
  jsonlite::write_json(list(volcano = "test caption"), file.path(cl_dir, "captions.json"),
                       auto_unbox = TRUE)

  lb <- load_layer_b(d)
  out_html <- file.path(d, "layer_b_report.html")

  result <- render_layer_b_report(lb, out_html)
  expect_true(file.exists(out_html))
  expect_gt(file.info(out_html)$size, 1000L)
})
```

- [ ] **Step 3: Run test per fail**

```bash
Rscript -e 'devtools::test(filter = "layer-b-report")'
```

Expected: FAIL.

- [ ] **Step 4: Implementare `R/layer-b-report.R`**

Crea `R/layer-b-report.R`:

```r
#' Render Quarto aggregate report Layer B (HTML standalone)
#'
#' @param lb `layer_b_result` (output di `build_layer_b_results()` o `load_layer_b()`).
#' @param out_path character path output HTML. Default: `lb$dir/layer_b_report.html`.
#' @param template character path al .qmd template. Default: incluso nel pacchetto.
#'
#' @return invisible(out_path).
#' @export
render_layer_b_report <- function(lb, out_path = NULL, template = NULL) {
  stopifnot(inherits(lb, "layer_b_result"))
  if (is.null(out_path)) {
    out_path <- file.path(lb$dir, "layer_b_report.html")
  }
  if (is.null(template)) {
    template <- system.file("templates/layer-b-report.qmd", package = "simulomicsr")
    if (template == "") {
      cli::cli_abort("Template layer-b-report.qmd not found in installed package")
    }
  }

  # Quarto richiede di lavorare in una working dir; copia template a tmpdir
  tmpd <- tempfile("lb_render_"); dir.create(tmpd)
  on.exit(unlink(tmpd, recursive = TRUE))
  qmd_local <- file.path(tmpd, "layer-b-report.qmd")
  file.copy(template, qmd_local, overwrite = TRUE)

  quarto::quarto_render(
    input = qmd_local,
    output_file = "layer_b_report.html",
    execute_params = list(layer_b_dir = normalizePath(lb$dir)),
    quiet = TRUE
  )

  rendered_html <- file.path(tmpd, "layer_b_report.html")
  if (!file.exists(rendered_html)) {
    cli::cli_abort("Quarto render did not produce expected output: {.path {rendered_html}}")
  }
  file.copy(rendered_html, out_path, overwrite = TRUE)

  invisible(out_path)
}
```

- [ ] **Step 5: Run test per pass**

```bash
Rscript -e 'devtools::test(filter = "layer-b-report")'
```

Expected: PASS 1/1 (skip se quarto CLI mancante).

- [ ] **Step 6: Commit**

```bash
git add R/layer-b-report.R inst/templates/layer-b-report.qmd tests/testthat/test-layer-b-report.R
git commit -m "P5 Stadio 4 Layer B Task 15: render_layer_b_report() (Quarto)

Template inst/templates/layer-b-report.qmd:
- Frontmatter: embed-resources=true, TOC depth 2, code-fold
- Overview: selection DT table + config YAML snapshot
- Per cluster: summary card + PNG embeds + top-gene kable + narrative

render_layer_b_report():
- Copy template a tmpdir (Quarto vuole working dir local)
- execute_params = list(layer_b_dir = <abs path>)
- Copy rendered HTML a out_path"
```

---

## Task 16: Integration test fixture-mini + replication

**Files:**
- Create: `tests/testthat/test-layer-b-fixture-mini.R`
- Create: `tests/testthat/test-layer-b-replication.R`

- [ ] **Step 1: Test integration end-to-end**

Crea `tests/testthat/test-layer-b-fixture-mini.R`:

```r
test_that("build + write + load + report end-to-end on mini fixture", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))
  on.exit(unlink(cache$dir, recursive = TRUE), add = TRUE)

  per_cluster_samples_provider <- function(cluster_id) {
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }

  selection <- tibble::tibble(
    cluster_id = c("cl_mega_1", "cl_aug_1"),
    label_paper = c("MegaTest", "AugTest"),
    priority = c(1L, 2L),
    notes = c("", "")
  )

  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  result <- build_layer_b_results(
    stage4_dir = stage4_dir, selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("lb_mini_")
  )

  # Round-trip
  result2 <- load_layer_b(result$dir)
  expect_equal(result2$run_metadata$run_id, result$run_metadata$run_id)
  expect_equal(length(result2$cluster_bundles), 2L)

  # Files attesi per cluster mega (no forest)
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "volcano.png")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "ma.png")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "heatmap.png")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "summary_card.md")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "narrative.qmd")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "top_genes.csv")))
  # mega skip forest
  expect_false(file.exists(file.path(result$dir, "cl_mega_1", "forest.png")))

  # Files attesi per cluster mega_aug (forest YES)
  expect_true(file.exists(file.path(result$dir, "cl_aug_1", "forest.png")))

  # selection_resolved + run_metadata committed
  expect_true(file.exists(file.path(result$dir, "selection_resolved.csv")))
  expect_true(file.exists(file.path(result$dir, "run_metadata.json")))
})
```

Crea `tests/testthat/test-layer-b-replication.R`:

```r
test_that("build_layer_b_results twice on same input yields same run_id", {
  skip_if_not_installed("ComplexHeatmap")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1"))
  on.exit(unlink(cache$dir, recursive = TRUE), add = TRUE)

  per_cluster_samples_provider <- function(cluster_id) {
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }

  selection <- tibble::tibble(
    cluster_id = "cl_mega_1", label_paper = "X",
    priority = 1L, notes = ""
  )

  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  r1 <- build_layer_b_results(
    stage4_dir = stage4_dir, selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg, out_dir = tempfile("lb_rep1_")
  )
  r2 <- build_layer_b_results(
    stage4_dir = stage4_dir, selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg, out_dir = tempfile("lb_rep2_")
  )

  expect_equal(r1$run_metadata$run_id, r2$run_metadata$run_id)

  # selection_resolved should be byte-equal
  s1 <- readr::read_csv(file.path(r1$dir, "selection_resolved.csv"), show_col_types = FALSE)
  s2 <- readr::read_csv(file.path(r2$dir, "selection_resolved.csv"), show_col_types = FALSE)
  expect_equal(s1, s2)
})
```

- [ ] **Step 2: Run tests**

```bash
Rscript -e 'devtools::test(filter = "layer-b-(fixture-mini|replication)")'
```

Expected: PASS 2/2.

- [ ] **Step 3: Run full Layer B test suite**

```bash
Rscript -e 'devtools::test(filter = "^layer-b")'
```

Expected: tutti i test PASS (modulo skip Bioc-deps assenti).

- [ ] **Step 4: Commit**

```bash
git add tests/testthat/test-layer-b-fixture-mini.R tests/testthat/test-layer-b-replication.R
git commit -m "P5 Stadio 4 Layer B Task 16: integration test + replication

test-layer-b-fixture-mini.R:
- End-to-end build su 2 cluster (mega + mega_aug) fixture sintetiche
- Verifica file presenti per metodo (forest solo per mega_aug, skip mega)
- Round-trip load_layer_b matcha run_id originale

test-layer-b-replication.R:
- run_id identico su 2 build con stesso input
- selection_resolved.csv byte-equal"
```

---

## Task 17: Standalone batch script + smoke script + selection CSV template

**Files:**
- Create: `analysis/p5-stage4-layer-b-build.R`
- Create: `analysis/p5-stage4-layer-b-smoke.R`
- Create: `analysis/layer-b-selection.csv` (template vuoto committato)
- Modify: `.gitignore` (eventualmente)

- [ ] **Step 1: Script batch**

Crea `analysis/p5-stage4-layer-b-build.R`:

```r
# analysis/p5-stage4-layer-b-build.R
# Layer B batch build: legge analysis/layer-b-selection.csv,
# esegue build_layer_b_results, render report aggregato.
#
# Pre-requisiti:
#   - analysis/layer-b-selection.csv compilato (10-20 cluster_id)
#   - Layer A output esistente in analysis/p4-output/<YYYYMMDDTHHMMSSZ>-stage4-96c43acb/
#   - Stage 4 counts cache in tools::R_user_dir("simulomicsr","cache")/stage4-counts/
#
# Usage:
#   nohup Rscript analysis/p5-stage4-layer-b-build.R \
#     2>&1 | tee analysis/p5-stage4-layer-b-build.log &

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
})

cli_h1("Stadio 4 Layer B batch build")

stage4_dir    <- "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
selection_csv <- "analysis/layer-b-selection.csv"
h5_path       <- "analysis/input/human_gene_v2.5.h5"

stopifnot(dir.exists(stage4_dir), file.exists(selection_csv), file.exists(h5_path))

# Pre-validation
cli_alert_info("Pre-validation...")
val <- layer_b_validate_selection(selection_csv, stage4_dir)
print(val)
if (any(!val$exists_in_stage4)) {
  cli_abort("Some cluster_id missing from stage4 — aborting.")
}

# Caricamento Stage 3 metadata (per summary card)
stage3_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
s3 <- load_stage3(stage3_dir)
stage3_metadata <- s3$clusters[, c("cluster_id", "kind_effective", "agent_id", "tissue", "safety_min")]

# Counts cache manifest (riusato da Stage 4)
counts_cache_dir <- file.path(tools::R_user_dir("simulomicsr", "cache"), "stage4-counts")
if (!dir.exists(counts_cache_dir)) {
  cli_abort("Stage 4 counts cache mancante: {.path {counts_cache_dir}}")
}
# Costruisci manifest dal pattern dei file in cache (Stage 4 lo persiste come <cluster_id>__<study_id>.rds)
build_manifest <- function(cache_dir, cluster_ids) {
  manifest <- list()
  for (cl_id in cluster_ids) {
    files <- list.files(cache_dir, pattern = sprintf("^%s__.+\\.rds$", cl_id), full.names = TRUE)
    studies <- sub(sprintf("^%s__", cl_id), "", sub("\\.rds$", "", basename(files)))
    manifest[[cl_id]] <- setNames(as.list(files), studies)
  }
  manifest
}
counts_cache_manifest <- build_manifest(counts_cache_dir, val$cluster_id)

# per_cluster_samples_provider (join Stage 3 assignment + Stage 2 design_role)
stage2_master <- simulomicsr:::.load_stage2_master("analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds")
assignments <- s3$assignments

per_cluster_samples_provider <- function(cluster_id) {
  asg <- assignments[assignments$cluster_id == cluster_id, c("sample_id", "study_id"), drop = FALSE]
  # design_role → treatment binary
  s2_rows <- stage2_master[stage2_master$gsm %in% asg$sample_id, c("gsm", "design_role"), drop = FALSE]
  asg$treatment <- ifelse(s2_rows$design_role[match(asg$sample_id, s2_rows$gsm)] %in%
                           c("control", "vehicle", "untreated"), "control", "treated")
  asg
}

# Batch build
cli_alert_info("Build...")
t0 <- Sys.time()
result <- build_layer_b_results(
  stage4_dir = stage4_dir,
  selection = selection_csv,
  counts_cache_manifest = counts_cache_manifest,
  per_cluster_samples_provider = per_cluster_samples_provider,
  stage3_metadata = stage3_metadata,
  config = layer_b_default_config(),
  h5_path = h5_path
)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

# Render aggregate report
cli_alert_info("Render aggregate report...")
render_layer_b_report(result, file.path(result$dir, "layer_b_report.html"))

cli_alert_success("Layer B batch OK in {.field {round(wall/60, 1)} min}: {.path {result$dir}}")
```

- [ ] **Step 2: Script smoke**

Crea `analysis/p5-stage4-layer-b-smoke.R`:

```r
# analysis/p5-stage4-layer-b-smoke.R
# Smoke 3-cluster pre-batch: validation visuale di tutta la pipeline
# senza compilare il CSV utente. Selezione deterministica dei 3 pick
# dal run β `96c43acb`.
#
# Wall budget: <=5 min.
#
# Usage: Rscript analysis/p5-stage4-layer-b-smoke.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
  library(dplyr)
})

cli_h1("Layer B smoke 3-cluster")

stage4_dir <- "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
stopifnot(dir.exists(stage4_dir))

# Determinare 3 picks deterministici dal cluster_pooled.parquet:
# - 1 mega strict con n_studies >= 10 (coverage MEGA grande)
# - 1 mega_aug pair con n_baseline_studies_augmented >= 10 (coverage MEGA-AUG)
# - 1 mega strict con n_studies 5-6 (coverage borderline)
cp <- arrow::open_dataset(file.path(stage4_dir, "cluster_pooled.parquet"))
cluster_meta <- cp |>
  group_by(cluster_id, method, k_effective) |>
  summarise(
    n_sig = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
    n_aug = max(n_baseline_studies_augmented, na.rm = TRUE),
    .groups = "drop"
  ) |>
  collect()

pick_mega_big <- cluster_meta |>
  filter(method == "mega", k_effective >= 10) |>
  arrange(desc(n_sig)) |> slice(1)
pick_aug <- cluster_meta |>
  filter(method == "mega_aug", n_aug >= 10) |>
  arrange(desc(n_sig)) |> slice(1)
pick_mega_small <- cluster_meta |>
  filter(method == "mega", k_effective %in% 5:6) |>
  arrange(desc(n_sig)) |> slice(1)

selection <- bind_rows(pick_mega_big, pick_aug, pick_mega_small) |>
  transmute(
    cluster_id,
    label_paper = paste0("smoke_", c("mega_big", "mega_aug", "mega_small")),
    priority = 1:3,
    notes = ""
  )
print(selection)

# Per il resto, riusa il loader del batch script (read_only sections)
source("analysis/p5-stage4-layer-b-build.R", echo = FALSE,
       local = environment(), max.deparse.length = Inf)
# NOTA: il source sopra esegue il build full — per lo smoke serve una
# riscrittura più compatta. Vedi sotto.
```

Visto che il batch script esegue tutto, lo smoke va riscritto in standalone.
Versione standalone definitiva:

```r
# analysis/p5-stage4-layer-b-smoke.R (versione standalone)

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli); library(dplyr)
})

cli_h1("Layer B smoke 3-cluster")

stage4_dir <- "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
stage3_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
counts_cache_dir <- file.path(tools::R_user_dir("simulomicsr","cache"), "stage4-counts")
stopifnot(dir.exists(stage4_dir), dir.exists(stage3_dir), file.exists(stage2_path),
          dir.exists(counts_cache_dir))

# Pick 3 cluster deterministici
cp <- arrow::open_dataset(file.path(stage4_dir, "cluster_pooled.parquet"))
meta <- cp |>
  group_by(cluster_id, method, k_effective) |>
  summarise(
    n_sig = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
    n_aug = max(n_baseline_studies_augmented, na.rm = TRUE),
    .groups = "drop"
  ) |>
  collect()

pick <- bind_rows(
  meta |> filter(method == "mega", k_effective >= 10) |>
    arrange(desc(n_sig)) |> slice(1),
  meta |> filter(method == "mega_aug", n_aug >= 10) |>
    arrange(desc(n_sig)) |> slice(1),
  meta |> filter(method == "mega", k_effective %in% 5:6) |>
    arrange(desc(n_sig)) |> slice(1)
)
selection <- pick |> transmute(
  cluster_id,
  label_paper = paste0("smoke_", c("mega_big", "mega_aug", "mega_small")),
  priority = 1:3,
  notes = ""
)
print(selection)

# Stage 3 metadata + per_cluster_samples_provider (copy/paste dal batch script)
s3 <- load_stage3(stage3_dir)
stage3_metadata <- s3$clusters[, c("cluster_id","kind_effective","agent_id","tissue","safety_min")]
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
assignments <- s3$assignments
build_manifest <- function(cache_dir, cluster_ids) {
  out <- list()
  for (cl_id in cluster_ids) {
    f <- list.files(cache_dir, pattern = sprintf("^%s__.+\\.rds$", cl_id), full.names = TRUE)
    sd <- sub(sprintf("^%s__", cl_id), "", sub("\\.rds$", "", basename(f)))
    out[[cl_id]] <- setNames(as.list(f), sd)
  }; out
}
counts_cache_manifest <- build_manifest(counts_cache_dir, selection$cluster_id)
per_cluster_samples_provider <- function(cluster_id) {
  asg <- assignments[assignments$cluster_id == cluster_id, c("sample_id","study_id")]
  s2 <- stage2_master[stage2_master$gsm %in% asg$sample_id, c("gsm","design_role")]
  asg$treatment <- ifelse(
    s2$design_role[match(asg$sample_id, s2$gsm)] %in% c("control","vehicle","untreated"),
    "control", "treated")
  asg
}

cli_alert_info("Build...")
t0 <- Sys.time()
result <- build_layer_b_results(
  stage4_dir = stage4_dir,
  selection = selection,
  counts_cache_manifest = counts_cache_manifest,
  per_cluster_samples_provider = per_cluster_samples_provider,
  stage3_metadata = stage3_metadata,
  config = layer_b_default_config(),
  out_dir = file.path("analysis/p4-output",
    sprintf("%s-layer-b-smoke-%s",
      format(Sys.time(), "%Y%m%dT%H%M%SZ", tz="UTC"),
      digest::digest(selection$cluster_id) |> substr(1,8)))
)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

render_layer_b_report(result, file.path(result$dir, "layer_b_report.html"))

cli_alert_success("Smoke OK in {.field {round(wall/60, 1)} min}: {.path {result$dir}}")
cli_alert("Open report: {.path {file.path(result$dir, 'layer_b_report.html')}}")
cli_alert("VALIDATE manualmente:")
cli_alert("  - 3 cluster bundle generati (mega_big, mega_aug, mega_small)")
cli_alert("  - Volcano + heatmap + GO + summary card presenti per ogni cluster")
cli_alert("  - forest.png solo per mega_aug")
cli_alert("  - heterogeneity caption esplicativa 'N/A non-REM' per tutti (0 REM nel run beta)")
```

- [ ] **Step 3: Template CSV selezione**

Crea `analysis/layer-b-selection.csv`:

```csv
cluster_id,label_paper,priority,notes
# Sostituire le righe sotto con i cluster_id curati a mano dalla dashboard Layer A.
# Sfoglia analysis/p4-output/20260523T032601Z-stage4-96c43acb/stage4_dashboard.html,
# Sezione 5 (Layer B candidate picker), copia 10-20 cluster_id rilevanti.
# Esempio (rimuovere dopo aver compilato):
pair_L0_PLACEHOLDER1,REPLACE_LABEL_PAPER,1,"motivazione biologica breve"
pair_L0_PLACEHOLDER2,REPLACE_LABEL_PAPER,2,""
```

- [ ] **Step 4: Verifica syntax R + commit**

Run:
```bash
Rscript -e 'parse("analysis/p5-stage4-layer-b-build.R"); parse("analysis/p5-stage4-layer-b-smoke.R"); cat("syntax OK\n")'
```

Expected: stampa "syntax OK".

- [ ] **Step 5: Commit**

```bash
git add analysis/p5-stage4-layer-b-build.R analysis/p5-stage4-layer-b-smoke.R analysis/layer-b-selection.csv
git commit -m "P5 Stadio 4 Layer B Task 17: standalone scripts + selection CSV template

analysis/p5-stage4-layer-b-build.R:
- Batch full su analysis/layer-b-selection.csv
- Pre-validation con layer_b_validate_selection
- Costruzione counts_cache_manifest dal cache Stage 4 esistente
- per_cluster_samples_provider via join Stage 3 assignments + Stage 2 design_role

analysis/p5-stage4-layer-b-smoke.R:
- 3 pick deterministici (mega_big, mega_aug, mega_small) dal run beta 96c43acb
- Wall budget <=5min
- Validation prompts manuali al termine

analysis/layer-b-selection.csv:
- Template committato con placeholder + istruzioni inline"
```

---

## Task 18: NEWS.md + CLAUDE.md update

**Files:**
- Modify: `NEWS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: NEWS entry**

Modifica `NEWS.md`: aggiungi all'inizio del file (sotto header eventuale):

```markdown
# simulomicsr 0.0.0.9020

## Stadio 4 Layer B — case study generator (2026-05-24)

Pipeline semi-automatica per produrre asset publication-grade per 10-20
"showcase case study" curati a mano. Input: CSV `analysis/layer-b-selection.csv`
con `cluster_id, label_paper, priority, notes`. Output: bundle dir-per-cluster
con 8 plot publication-grade (volcano, forest [REM/MEGA-AUG], MA, top-gene
table, heatmap, GO/Reactome enrichment, heterogeneity [REM only], summary card)
+ aggregate report HTML standalone via Quarto.

### Public API

- `build_layer_b_results()` — orchestrator end-to-end
- `layer_b_default_config()` — config defaults
- `layer_b_validate_selection()` — pre-check smoke (typo, drift Stage 4)
- `write_layer_b_to_dir()`, `load_layer_b()` — bundle persistence
- `render_layer_b_report()` — Quarto aggregate report

### Spec + ADR

- Spec: `docs/superpowers/specs/2026-05-24-p5-stadio4-layer-b-design.md`
- ADR-0017 (Proposed): `docs/decisions/0017-layer-b-case-study-generator.md`

### DESCRIPTION delta

- Imports nuovi: clusterProfiler, ComplexHeatmap, DESeq2, ggrepel, kableExtra, org.Hs.eg.db, sva
- Mossi da Suggests a Imports: ggplot2, quarto
- Suggests nuovo: ReactomePA (opt-in skip-graceful)
```

- [ ] **Step 2: CLAUDE.md aggiornamento stato**

Modifica `CLAUDE.md`. Sostituisci il blocco esistente "## Stato corrente (2026-05-23 ...)" con:

```markdown
## Stato corrente (2026-05-24 — P5 Stadio 4 Layer B implementato, branch `p5-stadio4-layer-b`)

### Layer A consolidato (2026-05-23, tag `p5-stadio4-complete`)

[mantieni TUTTO il contenuto del vecchio "Stato corrente" qui sotto, INVARIATO]

### Layer B nuovo (2026-05-24)

Pipeline semi-automatica generator di "showcase case study" publication-grade.
Input: `analysis/layer-b-selection.csv` (10-20 cluster_id curati a mano dalla
dashboard Layer A). Output: bundle dir-per-cluster + Quarto HTML aggregate.

Decisioni chiave (vedi ADR-0017 + spec 2026-05-24):
- Workflow: semi-automatico CSV-driven (no Shiny, no dashboard button)
- 8 plot per cluster con dispatch conditional (forest = REM+MEGA-AUG,
  heterogeneity = REM only)
- Drop-into-paper polished (PNG @300 DPI + SVG, caption inglese paper-ready)
- Top-N: 10 forest / 30 heatmap / 30 table / 15 volcano labels
- HTML standalone aggregate (NO PDF)
- NO targets integration (script standalone primary)
- Smoke 3-cluster gate obbligatorio pre-batch

Test suite Layer B: ~17 file, integration + replication.

DESCRIPTION delta: +7 Imports Bioc/CRAN + 2 mossi da Suggests + 1 Suggests nuovo.

Branch: `p5-stadio4-layer-b` (da mergere a master dopo smoke gate utente OK).
```

(Il dettaglio dello stato Layer A precedente resta invariato — solo la sezione 'stato corrente' viene rititolata e arricchita con Layer B.)

- [ ] **Step 3: Commit**

```bash
git add NEWS.md CLAUDE.md
git commit -m "P5 Stadio 4 Layer B Task 18: NEWS 0.0.0.9020 + CLAUDE.md aggiornato

NEWS 0.0.0.9020: cattura il deliverable Layer B (public API,
spec + ADR cross-ref, DESCRIPTION delta).

CLAUDE.md: nuova sotto-sezione 'Layer B nuovo (2026-05-24)' che
documenta workflow, decisioni chiave, status branch."
```

---

## Task 19: Smoke gate execution + (post-validation) batch user

**Files (nessun source — solo execution):**
- Run: `analysis/p5-stage4-layer-b-smoke.R`
- (Eventuale) Update: `analysis/layer-b-selection.csv` con cluster_id reali

- [ ] **Step 1: Execute smoke**

```bash
cd /home/user/simulomicsr
Rscript analysis/p5-stage4-layer-b-smoke.R 2>&1 | tee analysis/p5-stage4-layer-b-smoke.log
```

Expected: wall ≤5 min, 3 cluster bundle generati, report HTML aperto via:

```bash
xdg-open analysis/p4-output/<timestamp>-layer-b-smoke-<hash>/layer_b_report.html
# o macOS:
# open analysis/p4-output/<timestamp>-layer-b-smoke-<hash>/layer_b_report.html
```

- [ ] **Step 2: Validation manuale utente**

Controlli da fare nel report aperto in browser:
1. 3 sezioni cluster presenti (mega_big, mega_aug, mega_small)
2. Volcano leggibile, top-N labels presenti
3. Forest plot SOLO per la sezione mega_aug; le sezioni mega hanno caption skip "N/A for mega-strict"
4. MA plot con loess smooth
5. Heatmap leggibile (annotation studio+treatment visibile, palette z-score)
6. GO enrichment plot con barchart top-10
7. Heterogeneity sezione ha caption "N/A for non-REM" (0 REM nel run β)
8. Top-gene table embedded
9. Summary card con metadata corretti
10. Narrative template con sezioni TODO visibili

- [ ] **Step 3: Se smoke OK — STOP per session boundary**

Pattern progetto (`validate-before-fullrun`): dopo smoke OK, stop sessione,
aprire nuova per il batch user-curated. Comunica all'utente:

> "Smoke 3-cluster OK. Pronto per curare `analysis/layer-b-selection.csv`
> con 10-20 cluster_id reali, poi lanciare il batch via
> `Rscript analysis/p5-stage4-layer-b-build.R`."

- [ ] **Step 4: (Branch close) Merge p5-stadio4-layer-b in master**

Solo dopo smoke OK + (eventuale) batch user OK.

```bash
git checkout master
git merge --ff-only p5-stadio4-layer-b
# Tag
git tag p5-stadio4-layer-b-complete
# Push manuale utente
echo "MASTER ahead di origin di N commit. Push manuale utente."
```

- [ ] **Step 5: ADR-0017 status → Accepted**

Una volta merged + batch user OK, modifica `docs/decisions/0017-layer-b-case-study-generator.md`:

```markdown
**Stato:** Accepted (2026-05-XX, post-smoke OK + batch user OK)
```

Commit standalone:

```bash
git add docs/decisions/0017-layer-b-case-study-generator.md
git commit -m "ADR-0017: Proposed -> Accepted (Layer B smoke + batch user OK)"
```

---

## Self-Review checklist

Eseguito a fine plan dal writing-plans skill author (Claude):

### 1. Spec coverage

| Spec section | Task(s) |
|---|---|
| §1 Contesto + obiettivo | All (foundational) |
| §2 Goals (1-7) | Tasks 1-15 + 17-19 |
| §2 Non-goals (explicitly NOT in scope) | Negative coverage — by absence of tasks |
| §3.1 B.1 Loader+QC | Tasks 2, 3, 4 |
| §3.2 B.2 Asset gen (8 plot) | Tasks 5, 6, 7, 8, 9, 10, 11, 12 |
| §3.3 B.3 Aggregate report | Task 15 |
| §3.4 Output dir convention | Task 13, 14 |
| §3.5 run_metadata.json schema | Task 13, 14 |
| §4 API surface | All tasks + Task 14 (orchestrator) |
| §5 DESCRIPTION delta + ADR-0017 | Task 0 |
| §6 Test strategy (6.1-6.5) | Tests in ogni task + Task 16 integration + Task 19 smoke |
| §7 Persistence + versioning | Task 13 + Task 14 |
| §8 Rischi + mitigations | Coperti come edge case test in ogni plot task |
| §9 Decisioni rilevanti & cross-reference | ADR-0017 (Task 0) + spec |

Gap rilevati: nessuno bloccante.

### 2. Placeholder scan

- TBD / TODO / FIXME: solo i `_TODO_` legit nel narrative template (Task 12) — intenzionali.
- "implement later" / "fill in details": assenti.
- Steps senza codice quando il codice serve: nessuno.

### 3. Type consistency

- `layer_b_result` S3 list: schema consistente (cluster_bundles, selection_resolved, run_metadata, dir) attraverso Task 13, 14, 15, 16.
- `cluster_pooled` schema: usata in Task 2 (validate), Task 3 (fetch), Task 5-12 (plot subset). Colonne consistenti.
- `per_study_de` schema: idem.
- Function naming: tutti i `.build_*` interni; tutti i public verbi (`build_`, `write_`, `load_`, `render_`, `layer_b_*`).

### 4. Ambiguity check

- `per_cluster_samples_provider` injection in Task 14: ben definita signature `function(cluster_id) → tibble`, usata coerentemente in batch script + smoke script (Task 17).
- `counts_cache_manifest` nested list shape `[[cluster_id]][[study_id]] = path`: consistente tra Task 4 e Task 14.
- `out_dir` parameter: ogni `.build_*` plot riceve `out_dir` esplicito, nessuna assumption su working dir.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-24-p5-stadio4-layer-b-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**

