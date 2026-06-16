# F6 Consistency Metric — Implementation Plan (Fase A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Calcolare un punteggio di consistenza cross-studio [0,1] per tutti i 776 cluster Stadio 4, per-metodo (mega = 1−VPC(study); rem = 1−I² + prediction interval; mega_aug k=2 = sign-concordance), sui geni FDR-significativi, da dare allo shortlist Layer B.

**Architecture:** 4 helper puri in `R/stage4-consistency.R` (TDD su input sintetici) + uno script di orchestrazione `analysis/p4-fase-f6-consistency.R` che riusa gli helper Stadio 4 già mappati per ricalcolare VPC (mega, variancePartition) / PI (rem, metafor) / sign-concordance (mega_aug, da per_study_de), smoke-gated prima del run pieno (~3–9h sui 173 mega).

**Tech Stack:** R, testthat (TDD), variancePartition (VPC), metafor (PI/HKSJ), edgeR/limma (preprocessing), arrow (parquet).

Spec: `docs/superpowers/specs/2026-06-15-f6-reproducibility-consistency-metric-design.md`. ADR-0021. Run Stadio 4: `analysis/p4-output/20260613T051637Z-stage4-4f7ea215/`.

---

## File Structure

- Create `R/stage4-consistency.R` — 4 helper puri (`@keywords internal`): `.summarize_consistency_over_sig`, `.rem_prediction_interval`, `.sign_concordance`, `.consistency_score`.
- Create `tests/testthat/test-stage4-consistency.R` — TDD per i 4 helper.
- Create `analysis/p4-fase-f6-consistency.R` — orchestrazione (riusa helper Stadio 4 + i 4 nuovi), smoke-gated (`SMOKE` env), output esteso `cluster_reproducibility.rds` + `cluster_vpc_per_gene.parquet` (mega) + `cluster_pi_per_gene.parquet` (rem).
- Generated: `man/dot-*.Rd` per i 4 helper.

---

## Task 1: `.summarize_consistency_over_sig` — riassunto su geni sig

**Files:**
- Create: `R/stage4-consistency.R`
- Test: `tests/testthat/test-stage4-consistency.R`

- [ ] **Step 1: Write the failing test**

```r
test_that(".summarize_consistency_over_sig: mediana/IQR sui soli geni FDR-sig non-NA", {
  vals <- c(0.1, 0.5, 0.9, 0.3, NA)
  fdr  <- c(0.01, 0.2, 0.04, 0.001, 0.001)  # sig: idx 1,3,4 (idx5 sig ma val NA)
  res <- .summarize_consistency_over_sig(vals, fdr, threshold = 0.05)
  expect_equal(res$n_used, 3L)
  expect_equal(res$median, median(c(0.1, 0.9, 0.3)))
  expect_equal(res$iqr, IQR(c(0.1, 0.9, 0.3)))
})

test_that(".summarize_consistency_over_sig: nessun gene sig -> NA + n_used 0", {
  res <- .summarize_consistency_over_sig(c(0.2, 0.3), c(0.4, 0.9), threshold = 0.05)
  expect_true(is.na(res$median)); expect_equal(res$n_used, 0L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: FAIL — `could not find function ".summarize_consistency_over_sig"`.

- [ ] **Step 3: Write minimal implementation**

```r
#' Riassume una metrica per-gene (VPC_study o I2) sui soli geni FDR-significativi
#' @keywords internal
.summarize_consistency_over_sig <- function(values, fdr, threshold = 0.05) {
  stopifnot(length(values) == length(fdr))
  sig <- !is.na(fdr) & fdr < threshold & !is.na(values)
  if (!any(sig)) return(list(median = NA_real_, iqr = NA_real_, n_used = 0L))
  v <- values[sig]
  list(median = stats::median(v), iqr = stats::IQR(v), n_used = length(v))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-consistency.R tests/testthat/test-stage4-consistency.R
git commit -m "P5 audit RED_ALERT F6: .summarize_consistency_over_sig (TDD)"
```

---

## Task 2: `.rem_prediction_interval` — PI 95% per-gene (metafor REML+HKSJ)

**Files:**
- Modify: `R/stage4-consistency.R`
- Test: `tests/testthat/test-stage4-consistency.R`

- [ ] **Step 1: Write the failing test**

```r
test_that(".rem_prediction_interval: studi concordi e precisi -> PI esclude 0", {
  # 4 studi, logFC ~2 con SE piccole -> effetto chiaro, PI > 0
  res <- .rem_prediction_interval(logFC = c(2.0, 2.2, 1.9, 2.1),
                                  SE = c(0.1, 0.12, 0.09, 0.11))
  expect_true(res$pi_lower > 0)
  expect_true(isTRUE(res$excl0))
  expect_true(is.finite(res$tau2))
})

test_that(".rem_prediction_interval: studi discordi -> PI include 0", {
  res <- .rem_prediction_interval(logFC = c(2.0, -1.8, 1.5, -2.2),
                                  SE = c(0.3, 0.3, 0.3, 0.3))
  expect_true(res$pi_lower < 0 && res$pi_upper > 0)
  expect_false(isTRUE(res$excl0))
})

test_that(".rem_prediction_interval: <2 studi -> NA", {
  res <- .rem_prediction_interval(logFC = c(2.0), SE = c(0.1))
  expect_true(is.na(res$pi_lower)); expect_true(is.na(res$excl0))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: FAIL — function not found.

- [ ] **Step 3: Write minimal implementation**

```r
#' Prediction interval 95% per-gene da logFC/SE per-studio (metafor REML + HKSJ)
#'
#' @param logFC,SE vettori per-studio (un gene). @param level percentuale (default 95).
#' @return list(pi_lower, pi_upper, tau2, excl0). NA se < 2 studi o non-convergenza.
#' @keywords internal
.rem_prediction_interval <- function(logFC, SE, level = 95) {
  ok <- is.finite(logFC) & is.finite(SE) & SE > 0
  yi <- logFC[ok]; sei <- SE[ok]
  na <- list(pi_lower = NA_real_, pi_upper = NA_real_, tau2 = NA_real_, excl0 = NA)
  if (length(yi) < 2L) return(na)
  fit <- tryCatch(
    metafor::rma(yi = yi, sei = sei, method = "REML", test = "knha"),
    error = function(e) tryCatch(
      metafor::rma(yi = yi, sei = sei, method = "PM", test = "knha"),
      error = function(e2) NULL))
  if (is.null(fit)) return(na)
  pr <- tryCatch(predict(fit, level = level), error = function(e) NULL)
  if (is.null(pr) || is.null(pr$pi.lb)) return(na)
  pil <- pr$pi.lb; piu <- pr$pi.ub
  list(pi_lower = pil, pi_upper = piu, tau2 = fit$tau2,
       excl0 = is.finite(pil) && is.finite(piu) && (pil > 0 || piu < 0))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage4-consistency.R tests/testthat/test-stage4-consistency.R
git commit -m "P5 audit RED_ALERT F6: .rem_prediction_interval REML+HKSJ (TDD)"
```

---

## Task 3: `.sign_concordance` — direzione concorde dei 2 studi (mega_aug k=2)

**Files:**
- Modify: `R/stage4-consistency.R`
- Test: `tests/testthat/test-stage4-consistency.R`

- [ ] **Step 1: Write the failing test**

```r
test_that(".sign_concordance: frazione direzione-concorde sui soli geni sig", {
  a   <- c( 2,  -1,  3, -2,  1)
  b   <- c( 1,  -2,  3,  2, -1)   # concordi: idx 1,2,3 ; discordi: 4,5
  sig <- c(TRUE, TRUE, TRUE, TRUE, FALSE)  # gene5 non-sig -> escluso
  res <- .sign_concordance(a, b, sig)
  expect_equal(res$n_used, 4L)
  expect_equal(res$concordance, 3/4)
})

test_that(".sign_concordance: logFC 0/NA esclusi dal denominatore", {
  res <- .sign_concordance(c(2, 0, NA), c(1, 1, 1), c(TRUE, TRUE, TRUE))
  expect_equal(res$n_used, 1L); expect_equal(res$concordance, 1)
})

test_that(".sign_concordance: nessun gene sig usabile -> NA", {
  res <- .sign_concordance(c(2, 3), c(1, 2), c(FALSE, FALSE))
  expect_true(is.na(res$concordance)); expect_equal(res$n_used, 0L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: FAIL — function not found.

- [ ] **Step 3: Write minimal implementation**

```r
#' Sign-concordance dei logFC di 2 studi sui geni sig (proxy consistenza k=2)
#' @keywords internal
.sign_concordance <- function(logFC_a, logFC_b, sig_mask) {
  stopifnot(length(logFC_a) == length(logFC_b), length(sig_mask) == length(logFC_a))
  use <- sig_mask & is.finite(logFC_a) & is.finite(logFC_b) &
         logFC_a != 0 & logFC_b != 0
  if (!any(use)) return(list(concordance = NA_real_, n_used = 0L))
  agree <- sign(logFC_a[use]) == sign(logFC_b[use])
  list(concordance = mean(agree), n_used = sum(use))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage4-consistency.R tests/testthat/test-stage4-consistency.R
git commit -m "P5 audit RED_ALERT F6: .sign_concordance (TDD)"
```

---

## Task 4: `.consistency_score` — asse unico [0,1] per-metodo

**Files:**
- Modify: `R/stage4-consistency.R`
- Test: `tests/testthat/test-stage4-consistency.R`

- [ ] **Step 1: Write the failing test**

```r
test_that(".consistency_score: mega/rem = 1 - eterogeneita', clamp [0,1]", {
  expect_equal(.consistency_score("mega", median_heterogeneity = 0.3), 0.7)
  expect_equal(.consistency_score("rem", median_heterogeneity = 0.45), 0.55)
  expect_equal(.consistency_score("mega", median_heterogeneity = 1.2), 0) # clamp
})

test_that(".consistency_score: mega_aug = sign_concordance", {
  expect_equal(.consistency_score("mega_aug", sign_concordance = 0.8), 0.8)
})

test_that(".consistency_score: componenti NA -> NA", {
  expect_true(is.na(.consistency_score("mega", median_heterogeneity = NA_real_)))
  expect_true(is.na(.consistency_score("mega_aug", sign_concordance = NA_real_)))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: FAIL — function not found.

- [ ] **Step 3: Write minimal implementation**

```r
#' Asse unico di consistenza [0,1] per metodo
#'
#' mega/rem: 1 - frazione varianza between-study (VPC_study / I2). mega_aug:
#' sign_concordance. NA se la componente e' NA.
#' @keywords internal
.consistency_score <- function(method, median_heterogeneity = NA_real_,
                               sign_concordance = NA_real_) {
  s <- switch(method,
    mega     = 1 - median_heterogeneity,
    rem      = 1 - median_heterogeneity,
    mega_aug = sign_concordance,
    NA_real_)
  if (length(s) != 1L || is.na(s)) return(NA_real_)
  max(0, min(1, s))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-stage4-consistency.R")'`
Expected: PASS (tutti i test del file).

- [ ] **Step 5: Rigenera docs + commit**

```bash
Rscript -e 'devtools::document(quiet=TRUE)'
git add R/stage4-consistency.R tests/testthat/test-stage4-consistency.R man/
git commit -m "P5 audit RED_ALERT F6: .consistency_score asse unico (TDD)"
```

---

## Task 5: Script orchestrazione `analysis/p4-fase-f6-consistency.R`

**Files:**
- Create: `analysis/p4-fase-f6-consistency.R`

Lo script NON è unit-tested (è orchestrazione); è validato dallo smoke gate (Task 6). Riusa gli helper Stadio 4 mappati dal piano agente F6. Struttura:

- [ ] **Step 1: Bootstrap (identico a `analysis/p4-fase-f5-stage4-layer-a-rebuild-v3.R:19-78`)**: `OPENBLAS/OMP=1` + `RhpcBLASctl`; `devtools::load_all(".")`; `load_stage3("…stage3-v3-364547a7")`; `.load_stage2_master("…master-v3.jsonl")`; ricopia inline `.filter_stage2_master_to_h5` (prefiltro asse H5); `config <- stage4_default_config()` con `mega_aug$legacy_monodirectional<-FALSE` + `compute$dream_workers_cap<-32L`; costruisci `h5_metadata` (lib_size 1e7 placeholder) come `…rebuild-v3.R:109-146`; `fetch_fn <- function(g,s) simulomicsr:::.fetch_counts_cached(g,s,h5_path=H5,gene_biotype_filter="protein_coding")`. Env `SMOKE` → processa solo N cluster per metodo. Carica `cluster_pooled.parquet` (per FDR per-gene + method).

- [ ] **Step 2: mega (VPC).** Per ogni `cid` method=="mega" (skip se NULL dispatch): `grp<-.build_group_dispatch_from_stage3(...)[[cid]]`; `safe<-.build_mega_metadata_safe(grp,cid,biosample_lookup=…,libsize_lookup=…)`; `rank<-.check_mega_rank(safe$metadata)` (skip se rank-deficient → consistency NA, motivo registrato); assembla counts come `stage4-orchestrator.R:208-230` (fetch per studio, `Reduce(intersect)` geni, `cbind`, **riattacca `attr(counts,"gene_symbol")`**, reorder metadata su `match(colnames,sample_id)`); `joined<-.join_covariates_to_metadata(...)`; replica preprocessing `.run_dream_mega:87-119` (DGEList→filterByExpr(group=treatment)→normLibSizes TMM→`.augment_de_design`→formula `~treatment+(1|study)[+cov]`→`voomWithDreamWeights`); `vp<-variancePartition::fitExtractVarPartModel(vobj,form,metadata,BPPARAM)`; mappa `gene_id`=rownames(vp), `gene_symbol`=attr; join FDR per gene da cluster_pooled; `summ<-.summarize_consistency_over_sig(vp$study, fdr_per_gene)`; `consistency<-.consistency_score("mega", median_heterogeneity=summ$median)`. Accumula righe per-gene (cluster_id, gene_id, gene_symbol, vpc_study, vpc_treatment, vpc_residual) → `cluster_vpc_per_gene.parquet`.

- [ ] **Step 3: rem (I² + PI).** Carica `per_study_de.parquet` (cluster_id, study_id, gene_id, logFC, SE). Per ogni `cid` method=="rem": prendi I² per-gene da cluster_pooled + FDR; `summ_i2<-.summarize_consistency_over_sig(I2_per_gene, fdr)`; per i geni **sig**, raggruppa `per_study_de[cid]` per gene → `.rem_prediction_interval(logFC, SE)` → accumula `pi_lower/upper/tau2/excl0`; `pi_frac_excl0<-mean(excl0, na.rm=TRUE)`; `tau2_median<-median(tau2 dei sig)`; `consistency<-.consistency_score("rem", median_heterogeneity=summ_i2$median)`. Righe per-gene (cluster_id, gene_id, logFC_pool, pi_lower, pi_upper, tau2, I2) → `cluster_pi_per_gene.parquet`.

- [ ] **Step 4: mega_aug (sign-concordance).** Per ogni `cid` method=="mega_aug": da `per_study_de[cid]` (2 study_id) pivot a gene×studio logFC; `sig_mask` = geni con FDR<0.05 in cluster_pooled; `sc<-.sign_concordance(logFC_a, logFC_b, sig_mask)`; `consistency<-.consistency_score("mega_aug", sign_concordance=sc$concordance)`.

- [ ] **Step 5: Assembla + scrivi.** Tabella per-cluster: `cluster_id, method, k_studies, conc_confidence, n_sig_used, consistency_score, median_vpc_study, median_I2, tau2_median, pi_frac_excl0, sign_concordance, note`. Scrivi `cluster_reproducibility_v2.rds` + i due parquet per-gene nella dir del run. Stampa summary (distribuzione consistency per metodo, n NA/skip).

- [ ] **Step 6: Commit (script, no run)**

```bash
git add analysis/p4-fase-f6-consistency.R
git commit -m "P5 audit RED_ALERT F6: script orchestrazione consistenza (smoke-gated)"
```

---

## Task 6: Smoke gate (6 cluster) + run pieno

**Files:** nessuna modifica codice; esecuzione.

- [ ] **Step 1: Smoke su 6 cluster (2 mega + 2 rem + 2 mega_aug)**

Run: `SMOKE=2 Rscript analysis/p4-fase-f6-consistency.R 2>&1 | tee analysis/p4-fase-f6-consistency-smoke.log`
Verifica: consistency_score ∈ [0,1] per tutti; VPC_study mega ∈ (0,1); PI rem coerente col segno di I² (alto I² → PI più largo); sign_concordance mega_aug ∈ [0,1]; nessun crash; wall/RSS per stimare il run pieno.

- [ ] **Step 2: STOP gate** — riporta i 6 risultati all'utente, conferma sensatezza prima del run pieno.

- [ ] **Step 3: Run pieno (post-OK)** — `Rscript analysis/p4-fase-f6-consistency.R` in background (~3–9h, monitor orario come F5). Output: `cluster_reproducibility_v2.rds` + parquet per-gene.

- [ ] **Step 4: Commit doc esito** (numeri finali in `analysis/audit/F5-concordance-metric.md` addendum o nuova nota).

---

## Self-Review

- **Spec coverage:** mega VPC (Task 2/5-step2 ✓), rem I²+PI (Task 2+5-step3 ✓), mega_aug sign-concordance (Task 3+5-step4 ✓), asse unico (Task 4 ✓), gene set sig (Task 1 ✓), artefatti per-gene (Task 5 step2-3 ✓), smoke gate (Task 6 ✓), output esteso (Task 5 step5 ✓). NON-fa: LOO/LINCS/pathway (fuori scope, Fase C) ✓.
- **Placeholder scan:** gli step orchestrazione (Task 5) descrivono file:funzione esatte dal piano agente, non pseudo-codice vago; le funzioni Stadio 4 riusate sono tutte esistenti (verificate dal piano agente F6).
- **Type consistency:** `.consistency_score` riceve `median_heterogeneity`/`sign_concordance` come in Task 4; `.summarize_consistency_over_sig` ritorna `$median` usato come `median_heterogeneity`; `.rem_prediction_interval` ritorna `excl0` usato in `pi_frac_excl0`. Coerenti.
