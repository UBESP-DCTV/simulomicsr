# Verifica di coerenza dei cluster Stadio 3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilire, per ognuno dei 13.287 cluster cross-studio (k≥2) dello Stadio 3 v10, se raggruppa campioni che misurano lo stesso contrasto (coerente) o biologie/controlli diversi (minestrone/degenere), con la prova accanto a ogni verdetto; poi diagnosticare perché il gate di selezione ammette i minestroni.

**Architecture:** Riuso del dispatch reale dello Stadio 4 per ricostruire i contrasti per-studio (garantisce che verifichiamo *ciò che è stato poolato*); segnali deterministici a scala su tutti i 13.287 (Fase A omogeneità del controllo + Fase C degenere); consistenza ADR-0021 sui soli ~714 poolati (Fase B); deep-dive LLM su campione + flaggati per calibrare e confermare (Fase D); verdetto AND multi-asse.

**Tech Stack:** R (arrow, dplyr, metafor via `R/stage4-consistency.R`), testthat TDD, subagenti Claude per il deep-dive LLM.

## Global Constraints

- Branch `review-scientific-consistency-2026-06-10`; master invariato; **no push** salvo richiesta.
- **VIETATO inventare metriche statistiche**: riusare `R/stage4-consistency.R` (ADR-0021) e i metadati Stadio 2 esistenti. Nessun claim "paper-grade" senza prova sui dati.
- **Verdetto AND multi-asse**: la consistenza è necessaria non sufficiente (breast 0.98 = minestrone).
- **Scope (B)**: consistenza solo sui ~714 poolati, riuso parquet v10; **nessun re-run DE**, nessun re-cluster/re-pool.
- Commenti/commit/messaggi in **italiano**; ASCII per accenti nei file `.Rd`.
- Input (path esatti):
  - Stage 3 v10: `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7/` (`clusters.rds`, `assignments.parquet`).
  - Stadio 2 master: `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`.
  - Stadio 4 v10: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032/` (`cluster_pooled.parquet`, `per_study_de.parquet`).
- Funzioni riusabili esistenti (NON riscrivere): `.split_record_id`, `.lookup_cmp`, `.lookup_cmp_by_treated_group`, `.lookup_rg`, `.index_stage2_master`, `.load_stage2_master` (`R/stage4-dispatch.R`); `.summarize_consistency_over_sig`, `.rem_prediction_interval`, `.rem_consistency_from_i2` (`R/stage4-consistency.R`).

## File Structure

- `R/stage3-coherence.R` — helper testabili: `.normalize_control_type`, `.reconstruct_cluster_contrasts`, `.cluster_coherence_signals`, `.coherence_verdict`. (Riusabili anche dal futuro gate di coerenza.)
- `tests/testthat/test-stage3-coherence.R` — test TDD dei quattro helper.
- `analysis/audit/2026-07-23-coherence/10-signals-all-clusters.R` — run Fase 0+A+C su tutti i 13.287.
- `analysis/audit/2026-07-23-coherence/20-consistency-pooled.R` — run Fase B sui 714 poolati.
- `analysis/audit/2026-07-23-coherence/30-deepdive-prep.R` — prepara i bundle di evidenza (control-label + top geni PI-robusti) per la Fase D.
- `analysis/audit/2026-07-23-coherence/40-assemble-verdict.R` — unisce A/B/C/D → tabella verdetto + distribuzioni.
- `analysis/audit/2026-07-23-coherence/50-gate-diagnosis.R` — diagnosi gate ADR-0022 + simulazione gate di coerenza.
- Output (gitignored se pesanti): `per-member-contrasts.parquet`, `per-cluster-signals.rds`, `consistency-pooled.csv`, `deepdive-verdicts.rds`, `cluster-verdicts.rds`; summary/distribuzioni committati come CSV.
- `docs/findings/2026-07-23-stage3-cluster-coherence.md` — finding con i numeri + prove + verdetto vetrina Layer B.

---

### Task 1: Normalizzatore control-type + ricostruzione contrasti (helper testabili)

**Files:**
- Create: `R/stage3-coherence.R`
- Test: `tests/testthat/test-stage3-coherence.R`

**Interfaces:**
- Consumes: `.split_record_id`, `.lookup_cmp`, `.lookup_cmp_by_treated_group`, `.lookup_rg`, `.index_stage2_master` (da `R/stage4-dispatch.R`).
- Produces:
  - `.normalize_control_type(label)` → `character(1)` classe canonica del controllo (per confronto CROSS-studio). NB: usa `label_human`, NON factor_levels (le chiavi factor_levels sono study-specific → non comparabili cross-studio).
  - `.reconstruct_cluster_contrasts(cluster_id, mode, asg_by_clid, s2_idx)` → `data.frame(study_id, treated_label, treated_fl, control_label, control_fl, design_kind)` (una riga per membro risolto; 0 righe se nessuno risolve).

- [ ] **Step 1: Scrivere il test che fallisce per `.normalize_control_type`**

```r
# tests/testthat/test-stage3-coherence.R
test_that(".normalize_control_type collassa sinonimi di veicolo/controllo alla stessa classe", {
  syn <- c("DMSO", "vehicle", "vehicle control", "untreated", "untreated control",
           "control", "mock", "PBS", "0.1% DMSO")
  cls <- vapply(syn, simulomicsr:::.normalize_control_type, character(1))
  expect_equal(length(unique(cls)), 1L)  # tutti -> stessa classe "vehicle_untreated"
})

test_that(".normalize_control_type tiene distinti controlli SEMANTICAMENTE diversi", {
  expect_false(identical(
    simulomicsr:::.normalize_control_type("normoxia (20% O2)"),
    simulomicsr:::.normalize_control_type("control diet")))
  expect_false(identical(
    simulomicsr:::.normalize_control_type("scrambled shRNA"),
    simulomicsr:::.normalize_control_type("DMSO")))
})

test_that(".normalize_control_type ignora dose/unita'/numeri nella stessa classe biologica", {
  expect_equal(
    simulomicsr:::.normalize_control_type("10 nM tamoxifen"),
    simulomicsr:::.normalize_control_type("100 nM tamoxifen"))
})
```

- [ ] **Step 2: Eseguire i test e verificarne il fallimento**

Run: `Rscript --vanilla -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-coherence.R")'`
Expected: FAIL (`.normalize_control_type` non trovata).

- [ ] **Step 3: Implementare `.normalize_control_type`**

```r
# R/stage3-coherence.R
#' Normalizza un control-label (label_human) in una classe canonica cross-studio
#'
#' Serve a contare quanti TIPI di controllo semanticamente diversi convivono in un
#' cluster (segnale di minestrone). Usa label_human (comparabile cross-studio),
#' NON factor_levels (chiavi study-specific). Determinismo: lowercase, strip
#' dose/unita'/numeri, collasso di sinonimi di veicolo/baseline in un'unica classe.
#' Controlli specifici (dieta, normossia, scramble genetico) restano distinti.
#' Conservativo verso la diversita': NON collassa controlli biologicamente diversi.
#' @keywords internal
.normalize_control_type <- function(label) {
  if (length(label) == 0L || is.na(label) || !nzchar(trimws(label))) return("NA")
  x <- tolower(trimws(label))
  x <- gsub("\\b\\d+(\\.\\d+)?\\s?(nm|um|µm|mm|mg|ng|ug|µg|%|h|hr|hrs|day|days|d|week|weeks|min)\\b", " ", x)
  x <- gsub("\\b\\d+(\\.\\d+)?\\b", " ", x)              # numeri isolati
  x <- gsub("[^a-z ]+", " ", x)                            # punteggiatura
  x <- trimws(gsub("\\s+", " ", x))
  # classe veicolo/baseline: sinonimi comuni -> stessa classe
  veh <- c("dmso","vehicle","untreated","control","mock","pbs","saline","none",
           "no treatment","not treated","baseline","normal","healthy","naive")
  toks <- strsplit(x, " ")[[1]]
  if (any(toks %in% veh) &&
      !any(toks %in% c("diet","normoxia","normoxic","hypoxia","scramble","scrambled",
                        "wildtype","wt","sirna","shrna","sgrna","irradiated","fasting"))) {
    return("vehicle_untreated")
  }
  if (x == "") return("NA")
  x
}
```

- [ ] **Step 4: Eseguire i test di `.normalize_control_type` e verificarne il PASS**

Run: `Rscript --vanilla -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-coherence.R")'`
Expected: i 3 test di `.normalize_control_type` PASS.

- [ ] **Step 5: Scrivere il test per `.reconstruct_cluster_contrasts` su un cluster reale**

```r
test_that(".reconstruct_cluster_contrasts ricostruisce >=1 contrasto per un cluster poolato noto", {
  skip_if_not(dir.exists("analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"))
  S3 <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"
  S2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
  asg <- arrow::read_parquet(file.path(S3, "assignments.parquet"))
  s2  <- simulomicsr:::.load_stage2_master(S2)
  s2_idx <- simulomicsr:::.index_stage2_master(s2)
  asg_by <- split(asg$record_id, asg$cluster_id)
  df <- simulomicsr:::.reconstruct_cluster_contrasts(
    "group_L4_b6a3eabd", "group", asg_by, s2_idx)   # SARS-CoV-2 poolato
  expect_gt(nrow(df), 1L)
  expect_true(all(c("study_id","treated_label","control_label","design_kind") %in% names(df)))
})
```

- [ ] **Step 6: Eseguire il test e verificarne il fallimento** (funzione non definita).

- [ ] **Step 7: Implementare `.reconstruct_cluster_contrasts`**

```r
#' Ricostruisce i contrasti per-studio di un cluster (stesso dispatch dello Stadio 4)
#'
#' Pair -> .lookup_cmp; group -> .lookup_cmp_by_treated_group; entrambi -> .lookup_rg.
#' Una riga per membro RISOLTO (comparison trovata + treated/control presenti).
#' @keywords internal
.reconstruct_cluster_contrasts <- function(cluster_id, mode, asg_by_clid, s2_idx) {
  fl_sig <- function(rg) {
    fl <- rg$factor_levels
    if (length(fl) == 0L) return("")
    paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), "")), collapse = ";")
  }
  lab <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
  rids <- asg_by_clid[[cluster_id]]
  if (is.null(rids)) return(.empty_contrast_df())
  rows <- list()
  for (rid in rids) {
    p <- .split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2_idx, inherits = FALSE)) next
    st <- get(p$series_id, envir = s2_idx, inherits = FALSE)
    cmp <- if (identical(mode, "pair")) .lookup_cmp(st, p$suffix)
           else .lookup_cmp_by_treated_group(st, p$suffix)
    if (is.null(cmp)) next
    tg <- .lookup_rg(st, cmp$treated_group); cg <- .lookup_rg(st, cmp$control_group)
    if (is.null(tg) || is.null(cg)) next
    rows[[length(rows) + 1L]] <- data.frame(
      study_id      = p$series_id,
      treated_label = lab(tg, cmp$treated_group), treated_fl = fl_sig(tg),
      control_label = lab(cg, cmp$control_group), control_fl = fl_sig(cg),
      design_kind   = st$design_kind %||% "NA", stringsAsFactors = FALSE)
  }
  if (length(rows) == 0L) return(.empty_contrast_df())
  do.call(rbind, rows)
}

.empty_contrast_df <- function() data.frame(
  study_id = character(0), treated_label = character(0), treated_fl = character(0),
  control_label = character(0), control_fl = character(0), design_kind = character(0),
  stringsAsFactors = FALSE)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
```

- [ ] **Step 8: Eseguire tutti i test del file e verificarne il PASS.**

Run: `Rscript --vanilla -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-coherence.R")'`
Expected: tutti PASS.

- [ ] **Step 9: Commit**

```bash
git add R/stage3-coherence.R tests/testthat/test-stage3-coherence.R
git commit -m "P5 coherence Task 1: normalizzatore control-type + ricostruzione contrasti (TDD)"
```

---

### Task 2: Segnali per-cluster (Fase A/C) + regola di verdetto (helper testabili)

**Files:**
- Modify: `R/stage3-coherence.R`
- Modify: `tests/testthat/test-stage3-coherence.R`

**Interfaces:**
- Consumes: `.normalize_control_type`, `.reconstruct_cluster_contrasts` (Task 1).
- Produces:
  - `.cluster_coherence_signals(contrast_df)` → `list(n_resolved, n_control_types, control_homogeneity, n_design_kinds, n_treated_types, n_degenerate, frac_degenerate)`.
  - `.coherence_verdict(signals, consistency = NA, deepdive = NA)` → `character(1)` in `{coherent, minestrone, degenerate, uncertain}`.

- [ ] **Step 1: Test per `.cluster_coherence_signals`**

```r
test_that(".cluster_coherence_signals conta i tipi di controllo distinti e i degeneri", {
  df <- data.frame(
    study_id = c("A","B","C"),
    treated_label = c("drugX","drugX","drugX"), treated_fl = c("t=x","t=x","t=x"),
    control_label = c("DMSO","vehicle","control diet"),   # 2 tipi: vehicle_untreated + diet
    control_fl    = c("c=dmso","c=veh","c=x"),
    design_kind = c("treatment_vs_vehicle","treatment_vs_vehicle","dietary"),
    stringsAsFactors = FALSE)
  s <- simulomicsr:::.cluster_coherence_signals(df)
  expect_equal(s$n_resolved, 3L)
  expect_equal(s$n_control_types, 2L)
  expect_equal(s$n_design_kinds, 2L)
  expect_equal(s$n_degenerate, 0L)
})

test_that(".cluster_coherence_signals flagga i membri degeneri (treated==control)", {
  df <- data.frame(
    study_id = "A", treated_label = "case", treated_fl = "g=case",
    control_label = "case", control_fl = "g=case",
    design_kind = "case_control_disease", stringsAsFactors = FALSE)
  s <- simulomicsr:::.cluster_coherence_signals(df)
  expect_equal(s$n_degenerate, 1L)
  expect_equal(s$frac_degenerate, 1.0)
})
```

- [ ] **Step 2: Eseguire e verificare il fallimento.**

- [ ] **Step 3: Implementare `.cluster_coherence_signals`**

```r
#' Riassume i segnali di coerenza (Fase A/C) da un data.frame di contrasti
#' @keywords internal
.cluster_coherence_signals <- function(contrast_df) {
  n <- nrow(contrast_df)
  if (n == 0L) return(list(n_resolved = 0L, n_control_types = NA_integer_,
    control_homogeneity = NA_real_, n_design_kinds = NA_integer_,
    n_treated_types = NA_integer_, n_degenerate = NA_integer_, frac_degenerate = NA_real_))
  ctrl_types <- vapply(contrast_df$control_label, .normalize_control_type, character(1))
  trt_types  <- vapply(contrast_df$treated_label, .normalize_control_type, character(1))
  # degenere: stessa firma factor_levels (stesso studio, chiavi confrontabili) o stesso label
  deg <- (nzchar(contrast_df$treated_fl) & contrast_df$treated_fl == contrast_df$control_fl) |
         (tolower(trimws(contrast_df$treated_label)) == tolower(trimws(contrast_df$control_label)))
  n_ct <- length(unique(ctrl_types))
  list(
    n_resolved = n,
    n_control_types = n_ct,
    control_homogeneity = 1 / n_ct,                 # 1 = un solo tipo; ->0 = molti tipi
    n_design_kinds = length(unique(contrast_df$design_kind)),
    n_treated_types = length(unique(trt_types)),
    n_degenerate = sum(deg),
    frac_degenerate = mean(deg))
}
```

- [ ] **Step 4: Eseguire e verificare il PASS.**

- [ ] **Step 5: Test per `.coherence_verdict` (regola AND multi-asse)**

```r
test_that(".coherence_verdict: consistente ma control-eterogeneo => minestrone (breast docet)", {
  s <- list(n_resolved=6L, n_control_types=8L, control_homogeneity=1/8,
            n_design_kinds=3L, n_degenerate=0L, frac_degenerate=0)
  expect_equal(simulomicsr:::.coherence_verdict(s, consistency=0.98), "minestrone")
})
test_that(".coherence_verdict: degenere prevale", {
  s <- list(n_resolved=4L, n_control_types=1L, control_homogeneity=1,
            n_design_kinds=1L, n_degenerate=3L, frac_degenerate=0.75)
  expect_equal(simulomicsr:::.coherence_verdict(s), "degenerate")
})
test_that(".coherence_verdict: control-omogeneo + non-degenere + consistenza ok => coherent", {
  s <- list(n_resolved=5L, n_control_types=1L, control_homogeneity=1,
            n_design_kinds=1L, n_degenerate=0L, frac_degenerate=0)
  expect_equal(simulomicsr:::.coherence_verdict(s, consistency=0.7, deepdive="one_contrast"), "coherent")
})
test_that(".coherence_verdict: copertura insufficiente => uncertain", {
  s <- list(n_resolved=1L, n_control_types=1L, control_homogeneity=1,
            n_design_kinds=1L, n_degenerate=0L, frac_degenerate=0)
  expect_equal(simulomicsr:::.coherence_verdict(s), "uncertain")
})
```

- [ ] **Step 6: Eseguire e verificare il fallimento.**

- [ ] **Step 7: Implementare `.coherence_verdict`** (soglie di default esplicite; calibrate/riportate nel finding)

```r
#' Verdetto AND multi-asse da segnali + consistenza + deep-dive
#'
#' Soglie di DEFAULT (documentate nel finding, non nascoste):
#'   - min_resolved = 2 : sotto = uncertain (copertura insufficiente).
#'   - deg_frac_hi  = 0.5: frac_degenerate >= => degenerate.
#'   - homogeneous control = n_control_types == 1 (dopo normalizzazione).
#'   - design homogeneous  = n_design_kinds <= 1.
#'   - consistency_ok = (is.na) o >= 0.5 dove disponibile.
#'   - deepdive: se valutato, "one_contrast" richiesto per coherent; "multi_contrast" => minestrone.
#' @keywords internal
.coherence_verdict <- function(signals, consistency = NA_real_, deepdive = NA_character_,
                               min_resolved = 2L, deg_frac_hi = 0.5, cons_ok = 0.5) {
  s <- signals
  if (is.na(s$n_resolved) || s$n_resolved < min_resolved) return("uncertain")
  if (!is.na(s$frac_degenerate) && s$frac_degenerate >= deg_frac_hi) return("degenerate")
  if (!is.na(deepdive) && identical(deepdive, "multi_contrast")) return("minestrone")
  control_homog <- !is.na(s$n_control_types) && s$n_control_types == 1L
  design_homog  <- !is.na(s$n_design_kinds)  && s$n_design_kinds  <= 1L
  if (!control_homog || !design_homog) return("minestrone")
  # qui: control-omogeneo E design-omogeneo E non-degenere
  cons_pass <- is.na(consistency) || consistency >= cons_ok
  dd_pass   <- is.na(deepdive) || identical(deepdive, "one_contrast")
  if (cons_pass && dd_pass) return("coherent")
  "uncertain"
}
```

- [ ] **Step 8: Eseguire l'intero file di test e verificarne il PASS.**

- [ ] **Step 9: Commit**

```bash
git add R/stage3-coherence.R tests/testthat/test-stage3-coherence.R
git commit -m "P5 coherence Task 2: segnali per-cluster + verdetto AND multi-asse (TDD)"
```

---

### Task 3: Run Fase 0+A+C su tutti i 13.287 cluster

**Files:**
- Create: `analysis/audit/2026-07-23-coherence/10-signals-all-clusters.R`

**Interfaces:**
- Consumes: gli helper dei Task 1-2 + gli input Stage 3 v10 / Stage 2 master.
- Produces (in `analysis/audit/2026-07-23-coherence/`): `per-member-contrasts.parquet` (una riga per membro risolto), `per-cluster-signals.rds` (13.287 righe con i segnali A/C + `cluster_id, kind, k, mode, level, anchor_key, canonical_name`).

- [ ] **Step 1: Scrivere lo script** che: carica `clusters.rds` (filtra `k>=2`), `assignments.parquet`, Stage 2 master; costruisce `s2_idx` e `asg_by_clid`; per ogni cluster chiama `.reconstruct_cluster_contrasts` (mode dalla riga cluster) → salva le righe membro + `.cluster_coherence_signals` → riga per-cluster. Progress ogni 1000 cluster. Salva i due output.

- [ ] **Step 2: Eseguire** `Rscript analysis/audit/2026-07-23-coherence/10-signals-all-clusters.R` (attesa ~pochi min: la ricostruzione è O(membri), Stage 2 master ~24k in env).

- [ ] **Step 3: VERIFICARE l'output sui dati veri** (guardia anti-illusione): stampare (a) copertura `n_resolved/n_members` mediana e n. cluster con 0 risolti; (b) su `mode=="group" & k>=2`: distribuzione `n_control_types`; (c) i valori dei 184 rem_group poolati coincidono con la misura di calibrazione già fatta (0/184 con `n_control_types==1` NON deve valere DOPO la normalizzazione — la normalizzazione riduce il conteggio; riportare quanti passano da >1 a 1). Confronto esplicito con `pooled-184-res.rds` (scratchpad) per non introdurre regressioni silenziose.

- [ ] **Step 4: Commit** (script + summary CSV committabile; output pesanti gitignored)

```bash
echo "analysis/audit/2026-07-23-coherence/*.parquet" >> .gitignore
echo "analysis/audit/2026-07-23-coherence/*.rds" >> .gitignore
git add analysis/audit/2026-07-23-coherence/10-signals-all-clusters.R .gitignore
git commit -m "P5 coherence Task 3: segnali A/C su tutti i 13287 cluster k>=2"
```

---

### Task 4: Run Fase B — consistenza sui 714 poolati

**Files:**
- Create: `analysis/audit/2026-07-23-coherence/20-consistency-pooled.R` (generalizza `analysis/p5-stage4-showcase-consistency-v10.R` da 15 a 714 cluster).

**Interfaces:**
- Consumes: `cluster_pooled.parquet` + `per_study_de.parquet` (Stage 4 v10); `.summarize_consistency_over_sig`, `.rem_prediction_interval`, `.rem_consistency_from_i2`.
- Produces: `analysis/audit/2026-07-23-coherence/consistency-pooled.csv` (714 righe: `cluster_id, method, k_studies, n_sig_used, consistency_score, median_I2, pi_frac_excl0`).

- [ ] **Step 1: Scrivere lo script** — enumerare i `cluster_id` poolati distinti da `cluster_pooled.parquet` (tutti i method), riusare ESATTAMENTE la logica REM dello script showcase (loop per-cluster, PI per-gene sui geni sig). Per `method %in% c("mega","mega_aug")` la consistenza si legge dalla colonna esistente se presente (mega=VPC, mega_aug=sign-concordance); altrimenti riportare `NA` con nota (il ramo REM/PI è quello prioritario per rem_group).

- [ ] **Step 2: Eseguire** (attesa: minuti–decine di minuti; 714 cluster, I/O parquet filtrato). Se >30 min, loggare progress orario (memoria `feedback_hourly_updates_during_long_runs`).

- [ ] **Step 3: VERIFICARE**: i 9 showcase + 6 drop già noti (da `2026-07-23-showcase-consistency-summary.csv`) devono riprodursi entro tolleranza numerica. Stampare il confronto riga-per-riga.

- [ ] **Step 4: Commit**

```bash
git add analysis/audit/2026-07-23-coherence/20-consistency-pooled.R analysis/audit/2026-07-23-coherence/consistency-pooled.csv
git commit -m "P5 coherence Task 4: consistenza ADR-0021 su tutti i 714 poolati"
```

---

### Task 5: Fase D — deep-dive LLM (calibrazione D1 + biologia D2) con guardia anti-errore

**Files:**
- Create: `analysis/audit/2026-07-23-coherence/30-deepdive-prep.R` (prepara i bundle di evidenza).
- Output: `analysis/audit/2026-07-23-coherence/deepdive-verdicts.rds`.

**Interfaces:**
- Consumes: `per-member-contrasts.parquet` (Task 3), `cluster_pi_per_gene` (dal parquet v10 / rigenerato per i poolati: i top geni con `excl0==TRUE`).
- Produces: per ogni cluster valutato: `deepdive_verdict ∈ {one_contrast, multi_contrast, unclear}` (D2), `n_control_types_semantic` (D1), `note`.

- [ ] **Step 1: Prep** — per (i) tutti i 184 rem_group poolati, (ii) i cluster flaggati da A/C (es. `frac_degenerate>0` o `n_control_types` alto), (iii) campione stratificato `kind × k` (~40) del resto: estrarre l'elenco DEDUPLICATO dei control-label reali + i top ~30 geni PI-robusti (excl0). Salvare i bundle.
- [ ] **Step 2: Orchestrazione LLM** — l'orchestratore (Claude, sessione principale) dispaccia subagenti batchati con prompt che ricevono SOLO l'evidenza grezza e restituiscono: D1 (raggruppa i control-label in tipi semantici → conteggio) + D2 ("questi contrasti misurano UN contrasto biologico? i geni PI-robusti sono coerenti con l'anchor?"). Nessun accesso al verdetto atteso.
- [ ] **Step 3: GUARDIA anti-verdetto-sbagliato** — l'orchestratore ri-verifica a mano un sottoinsieme (≥15) dei verdetti LLM contro i control-label reali e i geni reali; calcola il **tasso di accordo LLM-vs-dati** e lo registra nel finding. Se accordo < 80% → il deep-dive LLM è declassato a segnale secondario e il verdetto pesa di più su A/C deterministici. (Riflette l'errore dei revisori del 2026-07-23.)
- [ ] **Step 4: Salvare** `deepdive-verdicts.rds` + commit dello script + di un CSV di sintesi (verdetti + accordo).

```bash
git add analysis/audit/2026-07-23-coherence/30-deepdive-prep.R analysis/audit/2026-07-23-coherence/deepdive-summary.csv
git commit -m "P5 coherence Task 5: deep-dive LLM D1/D2 + guardia accordo LLM-vs-dati"
```

---

### Task 6: Assemblaggio verdetto, diagnosi gate, finding

**Files:**
- Create: `analysis/audit/2026-07-23-coherence/40-assemble-verdict.R`
- Create: `analysis/audit/2026-07-23-coherence/50-gate-diagnosis.R`
- Create: `docs/findings/2026-07-23-stage3-cluster-coherence.md`

- [ ] **Step 1: Assemblaggio** — join `per-cluster-signals` + `consistency-pooled` + `deepdive-verdicts`; applicare `.coherence_verdict` a ogni cluster (consistency/deepdive = NA dove non disponibili). Output `cluster-verdicts.rds` + CSV di summary committabile con le distribuzioni {coerente/minestrone/degenere/incerto} per `kind` e per fascia di `k`.
- [ ] **Step 2: Diagnosi gate** — mostrare che ADR-0022 `.identify_layer_a_clusters` è solo strutturale; contare quanti dei 184 poolati risultano minestrone/degenere; simulare un gate di coerenza (`n_control_types==1` & `frac_degenerate==0` & `n_design_kinds<=1`) e riportare quanti dei 184 lo passano.
- [ ] **Step 3: Finding** `docs/findings/2026-07-23-stage3-cluster-coherence.md`: numeri per kind/k, impatto sui 184, il tasso di accordo LLM, esempi con prova (control-label reali), verdetto onesto sulla vetrina Layer B (9 + 184), proposta di gate. **Nessun claim non provato.**
- [ ] **Step 4: Commit + aggiornare** ledger `.superpowers/sdd/progress.md` e (se il gate è accettato dall'utente) preparare bozza ADR.

```bash
git add analysis/audit/2026-07-23-coherence/40-assemble-verdict.R analysis/audit/2026-07-23-coherence/50-gate-diagnosis.R analysis/audit/2026-07-23-coherence/cluster-verdicts-summary.csv docs/findings/2026-07-23-stage3-cluster-coherence.md
git commit -m "P5 coherence Task 6: verdetto per-cluster + diagnosi gate + finding"
```

---

## Self-Review (checklist eseguita)

- **Spec coverage:** Fase 0 (Task 1) · A (Task 1-3) · B (Task 4) · C (Task 1-3) · D (Task 5) · verdetto (Task 2,6) · diagnosi gate (Task 6) · deliverable 1-4 (Task 3-6). Tutte le sezioni della spec hanno un task.
- **Placeholder scan:** soglie di verdetto esplicitate con valori numerici di default in `.coherence_verdict`; nessun "TBD".
- **Type consistency:** `.normalize_control_type`/`.reconstruct_cluster_contrasts`/`.cluster_coherence_signals`/`.coherence_verdict` usate con firme coerenti tra Task 1-2-3-6.
- **Correzione vs spec §3:** il control-type usa `label_human` (comparabile cross-studio), NON la firma factor_levels (study-specific) — factor_levels resta per il check degenere. Scelta più difendibile, documentata qui e nel finding.
