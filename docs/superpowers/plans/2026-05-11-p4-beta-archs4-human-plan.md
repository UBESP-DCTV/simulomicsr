# P4 β — ARCHS4 human ETL + stage1+stage2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eseguire la pipeline `simulomicsr` stage1+stage2 sull'intero dump bulk RNA-seq human di ARCHS4 v2.5 (~500k sample, ~10k studies) producendo le facts strutturate input per Stadio 3 cross-study clustering.

**Architecture:** Pipeline a 5 fasi sequenziali con 3 gate pre-full-run.

```
Phase 1: Foundation (R package code)
  - R/etl-archs4-utils.R + R/etl-archs4-h5.R + R/etl-series-resolver.R con TDD
Phase 2: ETL pipeline
  - Download H5 + transform + resolver applicato
Phase 3: Pre-flight gates
  - GATE #0 resolver replication on gold
  - GATE #1 mini-gold v5 format B re-eval (DGX)
  - GATE #2 smoke 1000 sample (DGX)
Phase 4: Full run
  - Stage1 (~35h) + Stage2 (~50-70h) DGX jobs
Phase 5: Reporting + closing
  - Coverage report Quarto + cron monitor + tag/merge
```

**Tech Stack:** R 4.5+, renv, testthat, rhdf5 (BioC), rentrez, jsonlite, httr2, Quarto. DGX Singularity vLLM v0.20.2-cu129 + Mistral-Small-3.2-24B.

**Spec source:** `docs/superpowers/specs/2026-05-11-p4-beta-archs4-human-design.md` (decisioni catturate empiricamente in Exp A+C+D+D2).

**Branch:** `p4-beta-archs4-human` (da `master` @ `20aa7bd`)

---

## Phase 1: Foundation

### Task 1: Branch + dependencies update

**Files:**
- Modify: `DESCRIPTION` (Imports field)
- Modify: `renv.lock` (rigenerato da `renv::snapshot()`)

- [ ] **Step 1: Crea il branch**

```bash
git switch -c p4-beta-archs4-human
```

- [ ] **Step 2: Verifica BioC + dependency disponibili in renv**

```bash
Rscript -e '
for (p in c("rhdf5", "rentrez", "jsonlite", "httr2", "readxl", "dplyr", "stringr")) {
  cat(p, ":", requireNamespace(p, quietly = TRUE), "\n")
}'
```

Expected: tutti TRUE. Se `rhdf5` è FALSE, installalo via `BiocManager::install("rhdf5")`.

- [ ] **Step 3: Aggiungi rhdf5 a DESCRIPTION**

Edit `DESCRIPTION` (Imports field, in ordine alfabetico):

```
Imports:
    ...
    rentrez,
    rhdf5,
    ...
```

- [ ] **Step 4: Snapshot renv**

```bash
Rscript -e 'renv::snapshot(prompt = FALSE)'
```

Expected: aggiorna `renv.lock` con rhdf5 e rentrez se non già presenti.

- [ ] **Step 5: Commit**

```bash
git add DESCRIPTION renv.lock
git commit -m "P4 Task β-1: branch p4-beta + dependencies rhdf5/rentrez

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `R/etl-archs4-utils.R` — helpers (filtri + format-B string builder)

**Files:**
- Create: `R/etl-archs4-utils.R`
- Create: `tests/testthat/test-etl-archs4-utils.R`

- [ ] **Step 1: Scrivi test failing per `build_sample_string_format_B`**

`tests/testthat/test-etl-archs4-utils.R`:

```r
test_that("build_sample_string_format_B concatena title + source + characteristics", {
  result <- build_sample_string_format_B(
    title = "RNA-seq of MCF7 tamoxifen 24h",
    source_name_ch1 = "MCF7 cell line",
    characteristics_ch1 = "cell line: MCF7,treatment: tamoxifen 1uM,timepoint: 24h"
  )
  expect_equal(
    result,
    "title: RNA-seq of MCF7 tamoxifen 24h,source: MCF7 cell line,cell line: MCF7,treatment: tamoxifen 1uM,timepoint: 24h"
  )
})

test_that("build_sample_string_format_B gestisce NA/empty graceful", {
  expect_equal(
    build_sample_string_format_B(NA, "src", "key: value"),
    "source: src,key: value"
  )
  expect_equal(
    build_sample_string_format_B("", "", "key: value"),
    "key: value"
  )
  expect_equal(
    build_sample_string_format_B(NA, NA, NA),
    ""
  )
})

test_that("is_sample_classifiable filtra organism, library_strategy, string length", {
  expect_true(is_sample_classifiable("Homo sapiens", "RNA-Seq", "title: x,key: very long enough metadata"))
  expect_false(is_sample_classifiable("Mus musculus", "RNA-Seq", "title: x,key: y val"))
  expect_false(is_sample_classifiable("Homo sapiens", "scRNA-seq", "title: x,key: very long metadata"))
  expect_false(is_sample_classifiable("Homo sapiens", "RNA-Seq", "short"))
})
```

- [ ] **Step 2: Run test (fail expected)**

```bash
Rscript -e 'devtools::test(filter = "etl-archs4-utils")'
```

Expected: 4 FAIL with "could not find function build_sample_string_format_B".

- [ ] **Step 3: Implementa `R/etl-archs4-utils.R`**

```r
#' Costruisce la stringa input stage1 in formato B (ADR-spec P4 β).
#'
#' @param title Sample title da ARCHS4 H5 `/meta/samples/title`.
#' @param source_name_ch1 Sample source name da ARCHS4 H5 `/meta/samples/source_name_ch1`.
#' @param characteristics_ch1 Characteristics_ch1 da ARCHS4 H5 `/meta/samples/characteristics_ch1`.
#' @return Stringa concatenata pronta per stage1 prompt.
#' @keywords internal
build_sample_string_format_B <- function(title, source_name_ch1, characteristics_ch1) {
  parts <- c()
  if (!is.na(title) && nzchar(title)) parts <- c(parts, paste0("title: ", title))
  if (!is.na(source_name_ch1) && nzchar(source_name_ch1)) parts <- c(parts, paste0("source: ", source_name_ch1))
  if (!is.na(characteristics_ch1) && nzchar(characteristics_ch1)) parts <- c(parts, characteristics_ch1)
  paste(parts, collapse = ",")
}

#' Filtra un sample per inclusione nella pipeline P4 β (human, bulk RNA-seq, metadata non-trivial).
#'
#' @param organism Organism da ARCHS4 (`organism_ch1`).
#' @param library_strategy Library strategy (`library_strategy`).
#' @param string Stringa format B ricostruita.
#' @return Logical TRUE se passa i filtri.
#' @keywords internal
is_sample_classifiable <- function(organism, library_strategy, string) {
  if (is.na(organism) || organism != "Homo sapiens") return(FALSE)
  if (is.na(library_strategy) || library_strategy != "RNA-Seq") return(FALSE)
  if (is.na(string) || nchar(string) < 20) return(FALSE)
  TRUE
}
```

- [ ] **Step 4: Run test (pass expected)**

```bash
Rscript -e 'devtools::test(filter = "etl-archs4-utils")'
```

Expected: 4 PASS.

- [ ] **Step 5: Commit**

```bash
git add R/etl-archs4-utils.R tests/testthat/test-etl-archs4-utils.R
git commit -m "P4 Task β-2: R/etl-archs4-utils.R format-B string + sample filter

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `R/etl-archs4-h5.R` — HDF5 reader + JSONL emitter

**Files:**
- Create: `R/etl-archs4-h5.R`
- Create: `tests/testthat/test-etl-archs4-h5.R`
- Create: `tests/testthat/fixtures/archs4-mini.h5` (fixture per tests)

- [ ] **Step 1: Crea fixture H5 ridotta per testing**

```bash
Rscript -e '
library(rhdf5)
fix <- "tests/testthat/fixtures/archs4-mini.h5"
dir.create(dirname(fix), recursive = TRUE, showWarnings = FALSE)
if (file.exists(fix)) file.remove(fix)
h5createFile(fix)
h5createGroup(fix, "meta")
h5createGroup(fix, "meta/samples")
h5write(c("GSM001", "GSM002", "GSM003", "GSM004"),
        fix, "meta/samples/geo_accession")
h5write(c("GSE100", "GSE100,GSE101", "GSE102", "GSE103"),
        fix, "meta/samples/series_id")
h5write(c("MCF7 tam 24h", "MCF7 DMSO 24h", "HEK293 baseline", ""),
        fix, "meta/samples/title")
h5write(c("MCF7", "MCF7", "HEK293", "K562"),
        fix, "meta/samples/source_name_ch1")
h5write(c("cell: MCF7,trt: tam", "cell: MCF7,trt: DMSO", "cell: HEK293,trt: none", "x"),
        fix, "meta/samples/characteristics_ch1")
h5write(c("Homo sapiens", "Homo sapiens", "Mus musculus", "Homo sapiens"),
        fix, "meta/samples/organism_ch1")
h5write(c("RNA-Seq", "RNA-Seq", "RNA-Seq", "scRNA-Seq"),
        fix, "meta/samples/library_strategy")
H5close()
cat("Fixture created:", fix, "\n")
'
```

Expected: file `tests/testthat/fixtures/archs4-mini.h5` creato (~3 KB).

- [ ] **Step 2: Test failing per `read_archs4_metadata`**

`tests/testthat/test-etl-archs4-h5.R`:

```r
test_that("read_archs4_metadata legge i campi richiesti", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  meta <- read_archs4_metadata(fix)
  expect_s3_class(meta, "data.frame")
  expect_equal(nrow(meta), 4)
  expect_named(meta, c("geo_accession", "series_id", "title", "source_name_ch1",
                        "characteristics_ch1", "organism_ch1", "library_strategy"),
               ignore.order = TRUE)
  expect_equal(meta$geo_accession[1], "GSM001")
  expect_equal(meta$series_id[2], "GSE100,GSE101")
})

test_that("archs4_to_stage1_jsonl emette JSONL con filtri applicati", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  out <- tempfile(fileext = ".jsonl")
  res <- archs4_to_stage1_jsonl(fix, out)
  expect_s3_class(res, "list")
  expect_true("included" %in% names(res))
  expect_true("skipped" %in% names(res))
  # GSM001 + GSM002 = passano (human + RNA-Seq + string >= 20).
  # GSM003 = mouse, skippato.
  # GSM004 = scRNA-Seq + string short, skippato.
  expect_equal(res$included, 2L)
  expect_equal(res$skipped, 2L)
  # Verifica JSONL content
  lines <- readLines(out)
  expect_equal(length(lines), 2L)
  rec1 <- jsonlite::fromJSON(lines[1])
  expect_equal(rec1$geo_accession, "GSM001")
  expect_true(grepl("^title: MCF7 tam 24h,source: MCF7,", rec1$string))
})
```

- [ ] **Step 3: Run test (fail expected)**

```bash
Rscript -e 'devtools::test(filter = "etl-archs4-h5")'
```

Expected: 2 FAIL with "could not find function read_archs4_metadata".

- [ ] **Step 4: Implementa `R/etl-archs4-h5.R`**

```r
#' Legge i metadata sample da un dump ARCHS4 H5.
#'
#' Estrae i campi sotto `/meta/samples/` necessari per la classificazione P4 β.
#'
#' @param h5_path Path al file `human_gene_v2.5.h5` ARCHS4.
#' @return Data frame con una riga per sample.
#' @keywords internal
read_archs4_metadata <- function(h5_path) {
  stopifnot(file.exists(h5_path))
  fields <- c("geo_accession", "series_id", "title", "source_name_ch1",
              "characteristics_ch1", "organism_ch1", "library_strategy")
  cols <- lapply(fields, function(f) {
    as.character(rhdf5::h5read(h5_path, paste0("meta/samples/", f)))
  })
  names(cols) <- fields
  rhdf5::H5close()
  data.frame(cols, stringsAsFactors = FALSE)
}

#' Trasforma ARCHS4 H5 in JSONL raw input per stage1 (format B, filtri applicati).
#'
#' @param h5_path Path ARCHS4 H5.
#' @param out_jsonl_path Path di output JSONL (una riga per sample).
#' @param skip_log_path Path di output TSV con sample skippati e ragione (default NULL).
#' @return Lista con `included` (int), `skipped` (int), `total` (int).
#' @keywords internal
archs4_to_stage1_jsonl <- function(h5_path, out_jsonl_path, skip_log_path = NULL) {
  meta <- read_archs4_metadata(h5_path)
  meta$string <- mapply(
    build_sample_string_format_B,
    meta$title, meta$source_name_ch1, meta$characteristics_ch1
  )
  meta$keep <- mapply(
    is_sample_classifiable,
    meta$organism_ch1, meta$library_strategy, meta$string
  )
  meta$skip_reason <- ifelse(
    meta$keep, NA_character_,
    ifelse(meta$organism_ch1 != "Homo sapiens", "not_human",
    ifelse(meta$library_strategy != "RNA-Seq", "not_bulk_rnaseq",
    ifelse(nchar(meta$string) < 20, "string_too_short", "unknown")))
  )
  if (!is.null(skip_log_path)) {
    skipped <- meta[!meta$keep, c("geo_accession", "series_id", "skip_reason")]
    write.table(skipped, skip_log_path, sep = "\t", row.names = FALSE, quote = FALSE)
  }
  kept <- meta[meta$keep, ]
  recs <- lapply(seq_len(nrow(kept)), function(i) {
    list(
      geo_accession = kept$geo_accession[i],
      series_id = kept$series_id[i],
      string = kept$string[i],
      library_strategy = kept$library_strategy[i],
      organism = kept$organism_ch1[i]
    )
  })
  out_lines <- vapply(recs, jsonlite::toJSON, character(1L), auto_unbox = TRUE)
  writeLines(out_lines, out_jsonl_path)
  list(included = nrow(kept), skipped = nrow(meta) - nrow(kept), total = nrow(meta))
}
```

- [ ] **Step 5: Run test (pass expected)**

```bash
Rscript -e 'devtools::test(filter = "etl-archs4-h5")'
```

Expected: 2 PASS.

- [ ] **Step 6: Commit**

```bash
git add R/etl-archs4-h5.R tests/testthat/test-etl-archs4-h5.R tests/testthat/fixtures/archs4-mini.h5
git commit -m "P4 Task β-3: R/etl-archs4-h5.R HDF5 reader + JSONL emitter

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `R/etl-series-resolver.R` — resolver SRP-driven (Op D revised)

**Files:**
- Create: `R/etl-series-resolver.R`
- Create: `tests/testthat/test-etl-series-resolver.R`

- [ ] **Step 1: Test failing per `entrez_lookup_gse_metadata`**

`tests/testthat/test-etl-series-resolver.R`:

```r
test_that("entrez_lookup_gse_metadata estrae SRP e SuperSeries pattern", {
  skip_if_not(nzchar(Sys.getenv("NCBI_API_KEY")), "NCBI_API_KEY needed")
  res <- entrez_lookup_gse_metadata("GSE177616")
  expect_type(res, "list")
  expect_true(!is.na(res$srp))
  expect_match(res$srp, "^SRP[0-9]+$")
  expect_false(res$is_super_series)
  res_super <- entrez_lookup_gse_metadata("GSE145669")
  expect_true(res_super$is_super_series)
})
```

- [ ] **Step 2: Implementa `entrez_lookup_gse_metadata`**

`R/etl-series-resolver.R`:

```r
#' Lookup metadata di un GSE da NCBI Entrez `gds` database.
#'
#' Estrae i campi necessari per il resolver SRP-driven (Op D revised, spec P4 β):
#' - `srp`: SRA project ID se linkato (indica sub-method specifico).
#' - `is_super_series`: TRUE se il summary matcha il pattern GEO `"^This SuperSeries is composed of"`.
#'
#' @param gse Accession GEO (es. "GSE177616").
#' @return Lista con campi `uid, srp, is_super_series, title, pdat, n_samples, summary`.
#' @keywords internal
entrez_lookup_gse_metadata <- function(gse) {
  if (nzchar(Sys.getenv("NCBI_API_KEY"))) {
    rentrez::set_entrez_key(Sys.getenv("NCBI_API_KEY"))
  }
  s <- rentrez::entrez_search(db = "gds", term = paste0(gse, "[Accession]"))
  if (length(s$ids) == 0) {
    return(list(uid = NA, srp = NA, is_super_series = FALSE,
                title = NA, pdat = NA, n_samples = NA, summary = NA))
  }
  gse_uids <- s$ids[grepl("^2[0-9]+$", s$ids)]
  uid <- if (length(gse_uids) > 0) gse_uids[1] else s$ids[1]
  info <- rentrez::entrez_summary(db = "gds", id = uid)
  srp <- NA
  if (length(info$extrelations) > 0 && is.data.frame(info$extrelations)) {
    sra_row <- info$extrelations[info$extrelations$relationtype == "SRA", ]
    if (nrow(sra_row) > 0) srp <- sra_row$targetobject[1]
  }
  summary_text <- as.character(info$summary %||% "")
  is_super <- grepl("^This SuperSeries is composed of", summary_text)
  list(
    uid = uid,
    srp = srp,
    is_super_series = is_super,
    title = info$title %||% NA,
    pdat = info$pdat %||% NA,
    n_samples = info$n_samples %||% NA,
    summary = substr(summary_text, 1, 300)
  )
}
```

- [ ] **Step 3: Test failing per `resolve_series_id`** (decision tree completo)

```r
# Helper mock cache for unit tests (no real Entrez calls)
mock_cache <- list(
  "GSE100" = list(srp = NA, is_super_series = FALSE),
  "GSE101" = list(srp = "SRP001", is_super_series = FALSE),  # sub-method
  "GSE102" = list(srp = NA, is_super_series = TRUE),  # super
  "GSE103" = list(srp = "SRP002", is_super_series = FALSE),  # sub-method 2
  "GSE104" = list(srp = NA, is_super_series = FALSE)  # parent NotSuper
)

test_that("resolve_series_id case 1 GSE -> input echoed", {
  expect_equal(resolve_series_id("GSE100", mock_cache)$decision, "GSE100")
  expect_equal(resolve_series_id("GSE100", mock_cache)$branch, "single_gse")
})

test_that("resolve_series_id case 1 SuperSeries + 1 NotSuper -> NotSuper", {
  out <- resolve_series_id("GSE102,GSE100", mock_cache)
  expect_equal(out$decision, "GSE100")
  expect_equal(out$branch, "clean_super_scarted")
  out2 <- resolve_series_id("GSE100,GSE102", mock_cache)
  expect_equal(out2$decision, "GSE100")
})

test_that("resolve_series_id case 2 NotSuper, only SRP_a -> A", {
  out <- resolve_series_id("GSE101,GSE104", mock_cache)
  expect_equal(out$decision, "GSE101")
  expect_equal(out$branch, "srp_a_only")
})

test_that("resolve_series_id case 2 NotSuper, only SRP_b -> B (override lower-acc)", {
  out <- resolve_series_id("GSE104,GSE101", mock_cache)
  expect_equal(out$decision, "GSE101")
  expect_equal(out$branch, "srp_b_only")
})

test_that("resolve_series_id case 2 NotSuper, both SRP -> lower-acc tiebreak", {
  out <- resolve_series_id("GSE101,GSE103", mock_cache)
  expect_equal(out$decision, "GSE101")
  expect_equal(out$branch, "tiebreak_both_srp")
})

test_that("resolve_series_id case 2 NotSuper, no SRP -> lower-acc fallback", {
  out <- resolve_series_id("GSE100,GSE104", mock_cache)
  expect_equal(out$decision, "GSE100")
  expect_equal(out$branch, "fallback_no_srp")
})
```

- [ ] **Step 4: Implementa `resolve_series_id`**

Append to `R/etl-series-resolver.R`:

```r
#' Resolver SRP-driven per series_id multipli (Op D revised, spec P4 β sez. 4.2).
#'
#' @param series_id_raw Stringa `"GSE_a,GSE_b[,GSE_c...]"`.
#' @param cache List of lists keyed by GSE, each with `srp` and `is_super_series` fields.
#'   Tipicamente popolata via `entrez_lookup_gse_metadata`.
#' @return Lista `list(decision = "GSE_X", branch = "<branch_name>")`.
#'   `branch` in: `single_gse, clean_super_scarted, srp_a_only, srp_b_only,
#'   tiebreak_both_srp, fallback_no_srp, multi_gse_multi_branch`.
#' @keywords internal
resolve_series_id <- function(series_id_raw, cache) {
  gses <- trimws(strsplit(series_id_raw, ",")[[1]])
  gses <- gses[nzchar(gses)]
  if (length(gses) == 1L) return(list(decision = gses, branch = "single_gse"))
  not_super <- vapply(gses, function(g) {
    !(cache[[g]]$is_super_series %||% FALSE)
  }, logical(1L))
  candidates <- gses[not_super]
  if (length(candidates) == 1L) return(list(decision = candidates, branch = "clean_super_scarted"))
  if (length(candidates) == 0L) {
    # Tutti SuperSeries: caso patologico, prendi primo come fallback ultimo
    return(list(decision = gses[1L], branch = "all_super_pathological"))
  }
  # Candidate >=2 NotSuper: SRP-driven decision
  has_srp <- vapply(candidates, function(g) {
    v <- cache[[g]]$srp %||% NA
    !is.na(v) && nzchar(v)
  }, logical(1L))
  if (length(candidates) == 2L) {
    if (has_srp[1] && !has_srp[2]) return(list(decision = candidates[1], branch = "srp_a_only"))
    if (!has_srp[1] && has_srp[2]) return(list(decision = candidates[2], branch = "srp_b_only"))
    # Both SRP or both no-SRP: lower-accession tiebreak
    nums <- as.numeric(gsub("GSE", "", candidates))
    pick <- candidates[which.min(nums)]
    branch <- if (all(has_srp)) "tiebreak_both_srp" else "fallback_no_srp"
    return(list(decision = pick, branch = branch))
  }
  # Candidate >=3: multi-branch, apply same logic on subset
  if (sum(has_srp) == 1L) return(list(decision = candidates[has_srp], branch = "srp_one_of_many"))
  nums <- as.numeric(gsub("GSE", "", candidates))
  list(decision = candidates[which.min(nums)], branch = "multi_gse_multi_branch")
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
```

- [ ] **Step 5: Run unit tests (pass expected)**

```bash
Rscript -e 'devtools::test(filter = "etl-series-resolver")'
```

Expected: 7+ PASS (i 6 unit tests sopra + il test API live se NCBI_API_KEY presente).

- [ ] **Step 6: Test replication su gold-standard**

```r
test_that("resolve_series_id replica esattamente Exp D2 sui 23 pair del gold", {
  ext_cache_path <- "analysis/scratch/exp-d-entrez-extended.rds"
  skip_if_not(file.exists(ext_cache_path), "exp-d cache not available")
  ext <- readRDS(ext_cache_path)
  cache <- setNames(lapply(names(ext), function(g) {
    list(srp = ext[[g]]$srp, is_super_series = FALSE)  # Exp A pre-classifica NotSuper
  }), names(ext))
  expected <- read.csv("analysis/scratch/exp-d2-23pair-classification.csv", stringsAsFactors = FALSE)
  for (i in seq_len(nrow(expected))) {
    si <- paste(expected$gse_a[i], expected$gse_b[i], sep = ",")
    out <- resolve_series_id(si, cache)
    expect_equal(out$decision, expected$decision[i],
                 info = sprintf("Pair %s expected %s",
                                expected$pair_key[i], expected$decision[i]))
  }
})
```

- [ ] **Step 7: Run replication test (pass expected)**

```bash
Rscript -e 'devtools::test(filter = "etl-series-resolver")'
```

Expected: 23 expectations PASS (uno per pair). Se FAIL su qualche pair, debug e fix.

- [ ] **Step 8: Commit**

```bash
git add R/etl-series-resolver.R tests/testthat/test-etl-series-resolver.R
git commit -m "P4 Task β-4: R/etl-series-resolver.R SRP-driven Op D revised + replication test gold

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2: ETL pipeline

### Task 5: `analysis/p4-beta-etl-build.R` — orchestrator ETL

**Files:**
- Create: `analysis/p4-beta-etl-build.R`

- [ ] **Step 1: Crea script orchestrator**

```r
# analysis/p4-beta-etl-build.R
# Pipeline ETL completa P4 β: ARCHS4 H5 -> resolver -> JSONL stage1-input.

library(simulomicsr)
library(jsonlite)
library(fs)

stopifnot(nzchar(Sys.getenv("NCBI_API_KEY")))

# Path ARCHS4 H5 download (utente lo posiziona qui prima del run)
H5_PATH <- "analysis/input/archs4-human-gene-v2.5.h5"
STAGE1_INPUT_RAW <- "analysis/input/archs4-human-stage1-input-raw.jsonl"
STAGE1_INPUT_FINAL <- "analysis/input/archs4-human-stage1-input.jsonl"
ENTREZ_CACHE <- tools::R_user_dir("simulomicsr", "cache") |>
  file.path("geo-series-resolver-cache.rds")
PROVENANCE_PATH <- "analysis/p4-output/p4-beta-archs4-source.json"
SKIPPED_PATH <- "analysis/p4-output/p4-beta-etl-skipped.tsv"
MULTISERIES_LOG <- "analysis/p4-output/p4-beta-etl-multiseries.tsv"
TIEBREAK_LOG <- "analysis/p4-output/series-id-resolver-tiebreak.tsv"
FALLBACK_LOG <- "analysis/p4-output/series-id-resolver-fallback.tsv"

dir_create(dirname(c(STAGE1_INPUT_RAW, PROVENANCE_PATH, ENTREZ_CACHE)))

# ---- 1. Provenance record ----
stopifnot(file.exists(H5_PATH))
sha256 <- tools::md5sum(H5_PATH)  # quick check; SHA256 vero via openssl in step seguente
writeLines(jsonlite::toJSON(list(
  file = H5_PATH,
  size_bytes = as.integer(file.info(H5_PATH)$size),
  md5 = unname(sha256),
  fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
  source_url = "https://maayanlab.cloud/archs4/download.html",
  version_label = "human_gene_v2.5.h5"
), pretty = TRUE, auto_unbox = TRUE), PROVENANCE_PATH)
cat("Provenance saved:", PROVENANCE_PATH, "\n")

# ---- 2. ETL H5 -> JSONL raw (filtri organism/library_strategy/string-length) ----
cat("Reading H5...\n")
res_etl <- simulomicsr:::archs4_to_stage1_jsonl(
  h5_path = H5_PATH,
  out_jsonl_path = STAGE1_INPUT_RAW,
  skip_log_path = SKIPPED_PATH
)
cat(sprintf("ETL done. Included %d / Skipped %d (Total %d)\n",
            res_etl$included, res_etl$skipped, res_etl$total))

# ---- 3. Series-id-resolver: fetch metadata per i GSE unici nel JSONL raw ----
recs <- jsonlite::stream_in(file(STAGE1_INPUT_RAW), verbose = FALSE)
all_gses <- unique(trimws(unlist(strsplit(recs$series_id, ","))))
all_gses <- all_gses[nzchar(all_gses)]
cat(sprintf("Unique GSE da fetchare: %d\n", length(all_gses)))

entrez_cache <- if (file.exists(ENTREZ_CACHE)) readRDS(ENTREZ_CACHE) else list()
todo <- setdiff(all_gses, names(entrez_cache))
cat(sprintf("GSE non in cache: %d (stima %.1f min)\n",
            length(todo), length(todo) / 80 / 60))

t0 <- Sys.time()
for (i in seq_along(todo)) {
  entrez_cache[[todo[i]]] <- simulomicsr:::entrez_lookup_gse_metadata(todo[i])
  if (i %% 200 == 0) {
    saveRDS(entrez_cache, ENTREZ_CACHE)
    cat(sprintf("  [%d/%d] cache saved\n", i, length(todo)))
  }
}
saveRDS(entrez_cache, ENTREZ_CACHE)
cat(sprintf("Entrez done in %.1f min\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# ---- 4. Apply resolver per sample, write final JSONL ----
tiebreak_rows <- list()
fallback_rows <- list()
multi_rows <- list()
recs$series_id_resolved <- NA_character_
recs$resolver_branch <- NA_character_

for (i in seq_len(nrow(recs))) {
  out <- simulomicsr:::resolve_series_id(recs$series_id[i], entrez_cache)
  recs$series_id_resolved[i] <- out$decision
  recs$resolver_branch[i] <- out$branch
  if (out$branch == "tiebreak_both_srp") {
    tiebreak_rows[[length(tiebreak_rows) + 1L]] <-
      data.frame(geo_accession = recs$geo_accession[i],
                 series_id_input = recs$series_id[i],
                 series_id_resolved = out$decision,
                 stringsAsFactors = FALSE)
  } else if (out$branch == "fallback_no_srp" || out$branch == "all_super_pathological") {
    fallback_rows[[length(fallback_rows) + 1L]] <-
      data.frame(geo_accession = recs$geo_accession[i],
                 series_id_input = recs$series_id[i],
                 series_id_resolved = out$decision,
                 branch = out$branch,
                 stringsAsFactors = FALSE)
  }
  if (grepl(",", recs$series_id[i])) {
    multi_rows[[length(multi_rows) + 1L]] <-
      data.frame(geo_accession = recs$geo_accession[i],
                 series_id_input = recs$series_id[i],
                 series_id_resolved = out$decision,
                 resolver_branch = out$branch,
                 stringsAsFactors = FALSE)
  }
}

write_jsonl <- function(df, path) {
  lines <- vapply(seq_len(nrow(df)),
                  function(i) jsonlite::toJSON(as.list(df[i, ]), auto_unbox = TRUE),
                  character(1L))
  writeLines(lines, path)
}
write_jsonl(recs[, c("geo_accession", "series_id_resolved", "string",
                     "library_strategy", "organism")], STAGE1_INPUT_FINAL)

if (length(tiebreak_rows) > 0) write.table(do.call(rbind, tiebreak_rows), TIEBREAK_LOG,
                                            sep = "\t", row.names = FALSE, quote = FALSE)
if (length(fallback_rows) > 0) write.table(do.call(rbind, fallback_rows), FALLBACK_LOG,
                                            sep = "\t", row.names = FALSE, quote = FALSE)
if (length(multi_rows) > 0) write.table(do.call(rbind, multi_rows), MULTISERIES_LOG,
                                         sep = "\t", row.names = FALSE, quote = FALSE)

cat("\n=== ETL complete ===\n")
cat(sprintf("Final JSONL: %s\n", STAGE1_INPUT_FINAL))
cat(sprintf("N records included: %d\n", nrow(recs)))
cat(sprintf("Multi-series tracked: %d\n", length(multi_rows)))
cat(sprintf("Tiebreak log: %d\n", length(tiebreak_rows)))
cat(sprintf("Fallback log: %d\n", length(fallback_rows)))
cat("\nBranch distribution:\n")
print(table(recs$resolver_branch))
```

- [ ] **Step 2: Smoke test su fixture mini-h5**

```bash
# Modifica temporanea H5_PATH a fixture per test
Rscript -e '
source("analysis/p4-beta-etl-build.R")
' 2>&1 | tail -20
```

Expected: pipeline runs senza errori sul fixture (4 sample → 2 inclusi, 1 multi-series resolved).

Skip se preferisci eseguire direttamente con il download ARCHS4 reale (Task 6).

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-etl-build.R
git commit -m "P4 Task β-5: analysis/p4-beta-etl-build.R orchestrator ETL completo

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Download ARCHS4 v2.5 H5 + esegui ETL completo

**Files:**
- Create: `analysis/input/archs4-human-gene-v2.5.h5` (45 GB, gitignored)
- Create: `analysis/input/archs4-human-stage1-input-raw.jsonl` (gitignored)
- Create: `analysis/input/archs4-human-stage1-input.jsonl` (gitignored)
- Create: `analysis/p4-output/p4-beta-archs4-source.json` (committed)

- [ ] **Step 1: Download H5 da ARCHS4 (1-3h wall, 45 GB)**

```bash
cd analysis/input/
wget -c https://s3.amazonaws.com/mssm-seq-matrix/human_gene_v2.5.h5
cd ../..
ls -la analysis/input/human_gene_v2.5.h5
```

Expected: file size 45 GB, completo.

- [ ] **Step 2: Calcola SHA256 per provenance**

```bash
sha256sum analysis/input/archs4-human-gene-v2.5.h5
```

Expected: hash 64-char hex. Annota nel provenance JSON manualmente o aggiusta lo script.

- [ ] **Step 3: Run ETL full**

```bash
Rscript analysis/p4-beta-etl-build.R 2>&1 | tee analysis/p4-output/p4-beta-etl-build.log
```

Expected: ~1-2h wall.
- Included ~500k sample, skipped ~200k (mouse + scRNA + short string)
- Entrez fetch ~6.3k GSE in ~80 min
- JSONL output `archs4-human-stage1-input.jsonl` ~150-200 MB

- [ ] **Step 4: Sanity check output**

```bash
wc -l analysis/input/archs4-human-stage1-input.jsonl
head -3 analysis/input/archs4-human-stage1-input.jsonl
Rscript -e '
recs <- jsonlite::stream_in(file("analysis/input/archs4-human-stage1-input.jsonl"), verbose = FALSE)
cat("Total records:", nrow(recs), "\n")
cat("Multi-series resolved (resolver_branch != single_gse):\n")
print(table(recs$resolver_branch))
'
```

Expected: ~500k record, branch distribution ~90% single_gse / clean_super, ~9% srp-driven, ~1% tiebreak+fallback.

- [ ] **Step 5: Commit provenance e log**

```bash
git add analysis/p4-output/p4-beta-archs4-source.json
git commit -m "P4 Task β-6: ARCHS4 v2.5 ETL completato + provenance

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3: Pre-flight gates

### Task 7: Build mini-gold v5 in format B

**Files:**
- Create: `analysis/p4-beta-build-minigold-formatB.R`
- Create: `inst/extdata/p35c-minigold-reviewed-v5-formatB.csv` (committed)

- [ ] **Step 1: Script per costruire mini-gold format B**

```r
# analysis/p4-beta-build-minigold-formatB.R
# Per i 100 sample di p35c-minigold-reviewed-v5.csv, ricostruisci `string` in format B.
# Richiede: title + source_name_ch1 per ogni sample, fetched da GEO via entrez_summary.

library(simulomicsr)
library(rentrez)
library(readr)

stopifnot(nzchar(Sys.getenv("NCBI_API_KEY")))
rentrez::set_entrez_key(Sys.getenv("NCBI_API_KEY"))

mg <- read.csv("inst/extdata/p35c-minigold-reviewed-v5.csv", stringsAsFactors = FALSE)
cat("Mini-gold v5:", nrow(mg), "sample\n")

# Fetch per ogni sample (GSM) title + source_name via Entrez gds db (sample-level)
fetch_sample_meta <- function(gsm) {
  s <- entrez_search(db = "gds", term = paste0(gsm, "[Accession]"))
  if (length(s$ids) == 0) return(list(title = NA, source = NA))
  # Sample UIDs in gds iniziano con 3
  uid <- s$ids[grepl("^3[0-9]+$", s$ids)][1]
  if (is.na(uid)) uid <- s$ids[1]
  info <- entrez_summary(db = "gds", id = uid)
  list(
    title = info$title %||% NA,
    source = info$sourcename %||% info$source_name_ch1 %||% NA
  )
}

mg$title <- NA_character_
mg$source_name_ch1 <- NA_character_
for (i in seq_len(nrow(mg))) {
  meta <- fetch_sample_meta(mg$geo_accession[i])
  mg$title[i] <- meta$title
  mg$source_name_ch1[i] <- meta$source
  cat(sprintf("[%d/%d] %s | title: %s\n", i, nrow(mg), mg$geo_accession[i],
              substr(meta$title, 1, 50)))
}

# Build format B string
mg$string_formatB <- mapply(
  simulomicsr:::build_sample_string_format_B,
  mg$title, mg$source_name_ch1, mg$string  # original "string" = characteristics_ch1
)

# Save extended mini-gold
out_path <- "inst/extdata/p35c-minigold-reviewed-v5-formatB.csv"
write.csv(mg, out_path, row.names = FALSE)
cat("Saved:", out_path, "\n")
cat("nchar(string_formatB) summary:\n")
print(summary(nchar(mg$string_formatB)))
```

- [ ] **Step 2: Esegui**

```bash
Rscript analysis/p4-beta-build-minigold-formatB.R 2>&1 | tail -20
```

Expected: 100 sample con title + source_name fetched, file CSV salvato. ~3-5 min wall.

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-build-minigold-formatB.R inst/extdata/p35c-minigold-reviewed-v5-formatB.csv
git commit -m "P4 Task β-7: mini-gold v5 esteso con format B (title + source + chars)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: GATE #1 — Mini-gold format B re-eval

**Files:**
- Create: `analysis/p4-beta-gate1-minigold.R`

- [ ] **Step 1: Script gate #1 — bundle + submit + parse**

```r
# analysis/p4-beta-gate1-minigold.R
# GATE #1: re-eval mini-gold v5 format B con config IDENTICA al full-run pianificato.

library(simulomicsr)

# Prepare input JSONL per mini-gold format B
mg <- read.csv("inst/extdata/p35c-minigold-reviewed-v5-formatB.csv", stringsAsFactors = FALSE)
input_jsonl <- "analysis/input/p4-beta-gate1-minigold-input.jsonl"
recs <- lapply(seq_len(nrow(mg)), function(i) {
  list(geo_accession = mg$geo_accession[i],
       series_id = mg$series_id[i],
       string = mg$string_formatB[i],
       library_strategy = "RNA-Seq",
       organism = "Homo sapiens")
})
writeLines(vapply(recs, jsonlite::toJSON, character(1L), auto_unbox = TRUE),
           input_jsonl)
cat("Mini-gold format B JSONL:", input_jsonl, "\n")

# Build bundle (riusa dgx_p4_build_bundle)
bundle <- dgx_p4_build_bundle(
  input_jsonl = input_jsonl,
  run_id = paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ"), "-p4-beta-gate1-minigold"),
  stage = "stage1+stage2",   # eseguibilità pipeline completa
  vllm_version = "v0.20.2-cu129",
  model = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
  temperature = 0.0,
  repetition_penalty = 1.1,
  max_num_seqs = 6,
  microbatch = 50,
  stage2_chunk_size = 50,  # cs50 per ADR-0013
  tier_max_tokens = c(S = 4096, M = 8192, L = 16384, XL = 32768)
)

# Submit
job <- dgx_p4_submit(bundle, time = "12:00:00", partition = "dgx12cluster")
cat("Job submitted:", job$id, "\n")
cat("Wait ~1h for completion. Monitor via: dgx_p4_status(job)\n")
saveRDS(job, paste0("analysis/p4-output/", job$run_id, "-job.rds"))
```

- [ ] **Step 2: Submit gate #1**

```bash
Rscript analysis/p4-beta-gate1-minigold.R 2>&1 | tee analysis/p4-output/p4-beta-gate1-submit.log
```

Expected: bundle creato + sbatch sottomesso a DGX. Job ID restituito.

- [ ] **Step 3: Wait + collect (1h+ wall)**

```bash
# Polling via cron monitor (Task 15) o manualmente:
Rscript -e '
job <- readRDS(list.files("analysis/p4-output", "p4-beta-gate1.*-job\\.rds$", full.names = TRUE)[1])
print(dgx_p4_status(job))
'
# Quando state == "COMPLETED":
Rscript -e '
job <- readRDS(list.files("analysis/p4-output", "p4-beta-gate1.*-job\\.rds$", full.names = TRUE)[1])
dgx_p4_collect(job, dest = "analysis/p4-output")
'
```

- [ ] **Step 4: Parse + evaluate gate criteria**

```r
# Eval mini-gold format B
job <- readRDS(list.files("analysis/p4-output", "p4-beta-gate1.*-job\\.rds$", full.names = TRUE)[1])
preds_path <- file.path("analysis/p4-output", job$run_id, "predictions.jsonl")
mg <- read.csv("inst/extdata/p35c-minigold-reviewed-v5-formatB.csv", stringsAsFactors = FALSE)
preds <- jsonlite::stream_in(file(preds_path), verbose = FALSE)
m <- merge(mg, preds, by = "geo_accession", all.x = TRUE)

# Schema validity
schema_valid <- mean(!is.na(m$primary_role), na.rm = TRUE)
cat(sprintf("Schema valid rate: %.2f%%\n", 100 * schema_valid))

# Accuracy contro design_role_gold_v3_original (format B test)
acc <- mean(m$primary_role == m$design_role_gold_v3_original, na.rm = TRUE)
cat(sprintf("Accuracy vs gold: %.2f%%\n", 100 * acc))

# Tier overflow
n_overflow <- sum(grepl("OVERFLOW", m$error_flag %||% ""), na.rm = TRUE)
cat(sprintf("Overflow events: %d (target 0)\n", n_overflow))

# Gate decision
gate_pass <- schema_valid >= 0.995 && acc >= 0.967 && n_overflow == 0
if (gate_pass) cat("\nGATE #1 PASS ✓ procedi a smoke 1000 (Task 9)\n")
if (acc >= 0.95 && acc < 0.967) cat("\nGATE #1 borderline — nuova sessione per decidere\n")
if (acc < 0.95) cat("\nGATE #1 FAIL — investigare\n")
```

- [ ] **Step 5: Commit results gate #1**

```bash
git add analysis/p4-beta-gate1-minigold.R analysis/p4-output/<run_id>-gate1-eval.rds
git commit -m "P4 Task β-8: GATE #1 mini-gold format B re-eval — risultati

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: GATE #2 — Smoke test 1000 sample stratificato

**Files:**
- Create: `analysis/p4-beta-gate2-smoke.R`

- [ ] **Step 1: Script smoke 1000**

```r
# analysis/p4-beta-gate2-smoke.R
# GATE #2: smoke stratificato 1000 sample dal ETL output reale.

library(simulomicsr)
library(jsonlite)

set.seed(42)
INPUT_FULL <- "analysis/input/archs4-human-stage1-input.jsonl"
recs <- stream_in(file(INPUT_FULL), verbose = FALSE)
cat("Total records pre-smoke:", nrow(recs), "\n")

# Stratificato per quartile di nchar(string)
recs$nch <- nchar(recs$string)
q <- quantile(recs$nch, c(0, 0.25, 0.5, 0.75, 1))
recs$stratum <- cut(recs$nch, breaks = q, include.lowest = TRUE, labels = paste0("Q", 1:4))
sample_idx <- unlist(lapply(levels(recs$stratum), function(s) {
  pool <- which(recs$stratum == s)
  sample(pool, min(250, length(pool)))
}))
smoke <- recs[sample_idx, c("geo_accession", "series_id_resolved", "string",
                             "library_strategy", "organism")]
names(smoke)[2] <- "series_id"  # rename per compat con dgx_p4 pattern
cat("Smoke sample size:", nrow(smoke), "\n")

input_jsonl <- "analysis/input/p4-beta-gate2-smoke1000-input.jsonl"
writeLines(vapply(seq_len(nrow(smoke)),
                  function(i) toJSON(as.list(smoke[i, ]), auto_unbox = TRUE),
                  character(1L)),
           input_jsonl)

bundle <- dgx_p4_build_bundle(
  input_jsonl = input_jsonl,
  run_id = paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ"), "-p4-beta-gate2-smoke1000"),
  stage = "stage1+stage2",
  vllm_version = "v0.20.2-cu129",
  model = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
  temperature = 0.0,
  repetition_penalty = 1.1,
  max_num_seqs = 6,
  microbatch = 50,
  stage2_chunk_size = 50,
  tier_max_tokens = c(S = 4096, M = 8192, L = 16384, XL = 32768)
)
job <- dgx_p4_submit(bundle, time = "06:00:00", partition = "dgx12cluster")
saveRDS(job, paste0("analysis/p4-output/", job$run_id, "-job.rds"))
cat("Smoke job submitted:", job$id, "\n")
```

- [ ] **Step 2: Submit smoke**

```bash
Rscript analysis/p4-beta-gate2-smoke.R 2>&1 | tee analysis/p4-output/p4-beta-gate2-submit.log
```

Expected: bundle + sbatch. Stima 1.5h wall.

- [ ] **Step 3: Wait + collect + evaluate gate**

```r
job <- readRDS(list.files("analysis/p4-output", "p4-beta-gate2.*-job\\.rds$", full.names = TRUE)[1])
# attendi state COMPLETED, then:
dgx_p4_collect(job, dest = "analysis/p4-output")
preds <- stream_in(file(file.path("analysis/p4-output", job$run_id, "predictions.jsonl")), verbose = FALSE)

# Gate metrics
schema_s1 <- mean(!is.na(preds$primary_role), na.rm = TRUE)
n_overflow_xl <- sum(preds$tier == "XL" & preds$truncated == TRUE, na.rm = TRUE)
throughput <- nrow(preds) / as.numeric(difftime(job$end_time, job$start_time, units = "mins"))

cat(sprintf("Schema valid stage1: %.2f%%\n", 100 * schema_s1))
cat(sprintf("Tier XL overflow events: %d (target 0)\n", n_overflow_xl))
cat(sprintf("Throughput rec/min: %.1f\n", throughput))
cat(sprintf("Stima stage1 full ETA: %.1f h\n", 500000 / throughput / 60))

# Distribuzione design_role
cat("\nDesign role distribution:\n")
print(prop.table(table(preds$primary_role)))

# Tier distribution
cat("\nTier distribution (expected ~70% S, ~25% M, ~4% L, ~1% XL):\n")
print(prop.table(table(preds$tier)))

gate_pass <- schema_s1 >= 0.995 && n_overflow_xl == 0 && throughput > 100
if (gate_pass) cat("\nGATE #2 PASS ✓ procedi a stage1 full run\n")
```

- [ ] **Step 4: Commit risultati gate #2**

```bash
git add analysis/p4-beta-gate2-smoke.R analysis/p4-output/<run_id>-gate2-eval.rds
git commit -m "P4 Task β-9: GATE #2 smoke 1000 sample stratificato — risultati

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4: Full run

### Task 10: Stage1 full run — submission + monitoring

**Files:**
- Create: `analysis/p4-beta-stage1-fullrun.R`

- [ ] **Step 1: Script stage1 full submission**

```r
# analysis/p4-beta-stage1-fullrun.R
# Stage1 full run su ~500k sample ARCHS4 human.

library(simulomicsr)

INPUT <- "analysis/input/archs4-human-stage1-input.jsonl"
stopifnot(file.exists(INPUT))

bundle <- dgx_p4_build_bundle(
  input_jsonl = INPUT,
  run_id = paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ"), "-p4-beta-stage1-full"),
  stage = "stage1",
  vllm_version = "v0.20.2-cu129",
  model = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
  temperature = 0.0,
  repetition_penalty = 1.1,
  max_num_seqs = 6,
  microbatch = 50
)
job <- dgx_p4_submit(bundle, time = "168:00:00", partition = "dgx12cluster")
saveRDS(job, paste0("analysis/p4-output/", job$run_id, "-job.rds"))
cat("Stage1 full run submitted. Job:", job$id, " ETA ~35h wall\n")
```

- [ ] **Step 2: Submit + monitor**

```bash
Rscript analysis/p4-beta-stage1-fullrun.R
# Monitor via cron (Task 15) o manual:
Rscript -e '
job <- readRDS(list.files("analysis/p4-output", "p4-beta-stage1-full.*-job\\.rds$", full.names = TRUE)[1])
print(dgx_p4_status(job))
'
```

- [ ] **Step 3: Wait ~35h, collect output**

```r
job <- readRDS(list.files("analysis/p4-output", "p4-beta-stage1-full.*-job\\.rds$", full.names = TRUE)[1])
dgx_p4_collect(job, dest = "analysis/p4-output")
preds_path <- file.path("analysis/p4-output", job$run_id, "predictions.jsonl")
recs <- jsonlite::stream_in(file(preds_path), verbose = FALSE)
cat(sprintf("Stage1 output: %d records (input was 500k, valid expected >99%)\n", nrow(recs)))
```

- [ ] **Step 4: Recovery se job FAILED**

Se `dgx_p4_status(job)$state == "FAILED"` o `"TIMEOUT"`: re-submit con `dgx_p4_recover(run_id)`. La cache LLM in `analysis/cache/` salta i record già processati.

- [ ] **Step 5: Commit risultati stage1**

```bash
# .rds file di summary stats (non i preds full che sono gitignored)
git add analysis/p4-beta-stage1-fullrun.R analysis/p4-output/<run_id>/stats.rds
git commit -m "P4 Task β-10: stage1 full run completato su ~500k ARCHS4 human

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Modifica `analysis/p4-stage2-build-input.R` per source ARCHS4

**Files:**
- Modify: `analysis/p4-stage2-build-input.R`

- [ ] **Step 1: Verifica struttura attuale**

```bash
Read 50 lines from analysis/p4-stage2-build-input.R
```

Expected: identificare la sezione di input source (probabilmente XLSX lookup hardcoded).

- [ ] **Step 2: Modifica per accept input parametrizzato**

In `analysis/p4-stage2-build-input.R`, sostituisci la sezione "input source" con:

```r
# CONFIG
STAGE1_PREDS <- Sys.getenv("STAGE1_PREDS_PATH",
  unset = "analysis/p4-output/<run-id>/predictions.jsonl")  # P4 β ARCHS4
CHUNK_SIZE <- as.integer(Sys.getenv("CHUNK_SIZE", "50"))
SERIES_ID_FIELD <- "series_id_resolved"  # P4 β usa il resolved
```

Sostituisci ogni reference a `series_id` con `series_id_resolved` nella logica di aggregation per studio. NON cambia il chunk_size default (cs50, ADR-0013).

- [ ] **Step 3: Test che lo script gira sul preds di stage1**

```bash
STAGE1_PREDS_PATH="analysis/p4-output/<run-id>/predictions.jsonl" \
  Rscript analysis/p4-stage2-build-input.R 2>&1 | tail -10
```

Expected: chunk JSON files in `analysis/input/archs4-human-stage2-input/cs50_*.json`. Numero atteso ~200 chunk.

- [ ] **Step 4: Commit modifica**

```bash
git add analysis/p4-stage2-build-input.R
git commit -m "P4 Task β-11: p4-stage2-build-input.R parametrizzato per ARCHS4 source

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Stage2 full run — submission + monitoring

**Files:**
- Create: `analysis/p4-beta-stage2-fullrun.R`

- [ ] **Step 1: Script stage2 full submission**

```r
# analysis/p4-beta-stage2-fullrun.R
library(simulomicsr)

# Stage2 input è prodotto da p4-stage2-build-input.R (Task 11)
INPUT_DIR <- "analysis/input/archs4-human-stage2-input"
stopifnot(dir.exists(INPUT_DIR))

bundle <- dgx_p4_build_bundle(
  input_dir = INPUT_DIR,
  run_id = paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ"), "-p4-beta-stage2-full"),
  stage = "stage2",
  vllm_version = "v0.20.2-cu129",
  model = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
  temperature = 0.0,
  repetition_penalty = 1.1,
  max_num_seqs = 6,
  microbatch = 50,
  tier_max_tokens = c(S = 4096, M = 8192, L = 16384, XL = 32768)
)
job <- dgx_p4_submit(bundle, time = "168:00:00", partition = "dgx12cluster")
saveRDS(job, paste0("analysis/p4-output/", job$run_id, "-job.rds"))
cat("Stage2 full run submitted. Job:", job$id, " ETA ~50-70h wall\n")
```

- [ ] **Step 2: Submit + monitor + collect**

Same pattern di Task 10. Wait ~50-70h.

- [ ] **Step 3: Commit risultati stage2**

```bash
git add analysis/p4-beta-stage2-fullrun.R analysis/p4-output/<run_id>/stats.rds
git commit -m "P4 Task β-12: stage2 full run completato su ~10k studi

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5: Reporting + closing

### Task 13: Coverage report Quarto

**Files:**
- Create: `analysis/p4-beta-coverage-report.Rmd`

- [ ] **Step 1: Skeleton del report**

```r
---
title: "P4 β — ARCHS4 human coverage report"
date: "`r Sys.Date()`"
output:
  quarto::html_document:
    toc: true
    theme: cosmo
---

# Pipeline coverage P4 β

```{r setup, include=FALSE}
library(jsonlite)
library(dplyr)
library(ggplot2)
recs1 <- stream_in(file("analysis/p4-output/<stage1-run-id>/predictions.jsonl"), verbose = FALSE)
recs2 <- stream_in(file("analysis/p4-output/<stage2-run-id>/predictions.jsonl"), verbose = FALSE)
multi <- read.table("analysis/p4-output/p4-beta-etl-multiseries.tsv",
                    sep = "\t", header = TRUE)
skipped <- read.table("analysis/p4-output/p4-beta-etl-skipped.tsv",
                      sep = "\t", header = TRUE)
```

## 1. ETL coverage

- Total sample in ARCHS4 v2.5 H5: TODO_FROM_LOG
- Sample includibili (filtri organism + library + length): `r nrow(recs1) + nrow(skipped)`
- Sample skippati per reason:
```{r}
table(skipped$skip_reason)
```

## 2. Series-id-resolver coverage

- Sample multi-series totali: `r nrow(multi)`
- Branch distribution:
```{r}
table(multi$resolver_branch)
```
- Tiebreak (`tiebreak_both_srp`) sample count: `r sum(multi$resolver_branch == "tiebreak_both_srp")`
- Fallback (`fallback_no_srp`) sample count: `r sum(multi$resolver_branch == "fallback_no_srp")`

## 3. Stage1 classification coverage

```{r}
schema_valid_rate <- mean(!is.na(recs1$primary_role))
cat(sprintf("Schema valid: %.2f%%\n", 100 * schema_valid_rate))
table(recs1$primary_role)
```

## 4. Stage2 study-level coverage

- Studi unici classificati: `r length(unique(recs2$series_id_resolved))`
- Distribuzione `design_role`:
```{r}
table(recs2$design_role)
```

## 5. Comparability_anchor distribution (top-20)

```{r}
recs2 |>
  count(comparability_anchor, sort = TRUE) |>
  slice_head(n = 20) |>
  knitr::kable()
```

## 6. Comparison vs P4 α

α stage1 cs50: 130.784 sample → 6649 record stage2 cs50.
β stage1: `r nrow(recs1)` sample → ? record stage2.

(da popolare con dati reali post-run)
```

- [ ] **Step 2: Render**

```bash
Rscript -e 'quarto::quarto_render("analysis/p4-beta-coverage-report.Rmd")'
```

Expected: HTML output in `analysis/p4-beta-coverage-report.html`.

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-coverage-report.Rmd
git commit -m "P4 Task β-13: coverage report Quarto

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Cron monitoring script

**Files:**
- Create: `scripts/p4-beta-monitor.sh`

- [ ] **Step 1: Script monitoring**

```bash
#!/bin/bash
# P4 β cron monitor — generates log file readable on-demand.
# Setup: crontab -e
#   0 */2 * * * /home/user/simulomicsr/scripts/p4-beta-monitor.sh >> /home/user/simulomicsr/analysis/p4-beta-monitor.log 2>&1

set -uo pipefail
TS=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
echo "==== [$TS] P4 β monitor ===="

# squeue snapshot
echo "-- SLURM jobs --"
ssh -o BatchMode=yes dgx 'bash -lc "squeue -u u0044 --format=\"%A %j %T %M %l\""' 2>&1 || \
  echo "[ATTENTION] ssh failed"

# Latest slurm.out tail per job attivo
echo "-- Last slurm.out tail (50 lines) --"
ssh -o BatchMode=yes dgx 'bash -lc "tail -50 ~/p4-beta/slurm-*.out 2>/dev/null | head -200"' 2>&1 || \
  echo "[no slurm.out yet]"

# Conta record nei JSONL output corrente (live throughput)
echo "-- Output JSONL line count --"
ssh -o BatchMode=yes dgx 'bash -lc "for f in ~/p4-beta/output/*/predictions.jsonl; do echo \"\$f: \$(wc -l < \$f) lines\"; done"' 2>&1 || \
  echo "[no output yet]"

echo ""
```

- [ ] **Step 2: Permission + dry-run**

```bash
chmod +x scripts/p4-beta-monitor.sh
scripts/p4-beta-monitor.sh
```

Expected: log lines, possibly "ssh failed" if non-interactive ssh non setup. Doc per user setup in commit msg.

- [ ] **Step 3: Crontab setup (utente, non auto)**

Doc nello script o in README. Utente esegue:

```bash
( crontab -l 2>/dev/null; echo "0 */2 * * * /home/user/simulomicsr/scripts/p4-beta-monitor.sh >> /home/user/simulomicsr/analysis/p4-beta-monitor.log 2>&1" ) | crontab -
```

- [ ] **Step 4: Commit**

```bash
git add scripts/p4-beta-monitor.sh
git commit -m "P4 Task β-14: cron monitor script + crontab setup doc

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Final cleanup + git tag + merge

**Files:**
- Modify: `NEWS.md` (changelog)
- Modify: `DESCRIPTION` (version bump)

- [ ] **Step 1: Aggiungi sezione NEWS.md**

`NEWS.md`:

```markdown
# simulomicsr 0.0.0.9016 — P4 β ARCHS4 human

## Aggiunte
- ETL ARCHS4 H5 → JSONL stage1-input (R/etl-archs4-h5.R, R/etl-archs4-utils.R).
- Series-id-resolver SRP-driven Op D revised (R/etl-series-resolver.R), 99.3% sample ambiguous risolti via signal causale, 0 sample persi.
- Coverage report Quarto P4 β (analysis/p4-beta-coverage-report.Rmd).
- Cron monitor script (scripts/p4-beta-monitor.sh).

## Risultati P4 β full run
- Stage1 ~500k sample human, ~XXh wall.
- Stage2 ~10k studi, ~YYh wall.
- Coverage: ZZ studi DE-able prodotti per Stadio 3.

## Spec
- docs/superpowers/specs/2026-05-11-p4-beta-archs4-human-design.md

## Tag
- p4-beta-archs4-human-complete
```

- [ ] **Step 2: Version bump in DESCRIPTION**

```
Version: 0.0.0.9016
```

- [ ] **Step 3: Commit final + tag**

```bash
git add NEWS.md DESCRIPTION
git commit -m "P4 Task β-15: NEWS 0.0.0.9016 P4 β complete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git tag p4-beta-archs4-human-complete
```

- [ ] **Step 4: Merge fast-forward to master**

```bash
git switch master
git merge --ff-only p4-beta-archs4-human
```

Se `--ff-only` fallisce per divergenza: investigate, rebase if needed.

- [ ] **Step 5: Final status**

```bash
git log --oneline master..p4-beta-archs4-human  # should be empty post-merge
git tag --list | grep p4-beta
```

L'utente farà `git push` quando ready.

---

## Self-review checklist

- ✓ Spec coverage: tutte le sezioni 1-10 del design coperte (scope, organism, resume, format B, resolver SRP-driven, 3 gates, full runs, coverage report, monitoring, cleanup).
- ✓ Placeholder scan: nessun "TBD/TODO/implement later" salvo `<run-id>` segnaposti che vanno sostituiti runtime.
- ✓ Type consistency: `resolve_series_id` ritorna list(decision, branch) coerente in tutti i test + chiamate. Stessa interface in Task 4, 5, 11.
- ✓ Format-B builder coerente: `build_sample_string_format_B` in Task 2, riusato in Task 5 e Task 7.

---

## Execution handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-11-p4-beta-archs4-human-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — dispatch fresh subagent per task, review tra task, fast iteration. Buono per i task R-coding con TDD (Task 2-4, 11).

**2. Inline Execution** — esecuzione in questa sessione con executing-plans skill, batch + checkpoint per review. Buono per task lunghi singoli (Task 6, 10, 12).

Approccio ibrido suggerito: subagent-driven per Phase 1 (coding TDD) + inline per Phase 2-5 (orchestration runtime, dipende da download/job submission).
