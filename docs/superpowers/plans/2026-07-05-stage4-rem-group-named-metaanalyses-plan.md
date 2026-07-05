# Ramo `rem_group` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ammettere allo Stadio 4 le meta-analisi cross-studio nominate (group L2–L4, `safety_min` basso) via un nuovo percorso `rem_group` che le poola in REM per-studio, riusando il macchinario esistente.

**Architecture:** Nuovo `method = "rem_group"` per i cluster `mode=group` nominati. Una porta di ammissione senza `safety_min` (dedup a un livello per entità), un dispatch-builder group-aware che recupera i controlli in-study via `stage2_master$comparisons`, e l'instradamento nel percorso REM per-studio già esistente (`.run_per_study_de_all` → `.pool_rem_cluster`). I tre rami esistenti (`rem`/`mega`/`mega_aug`) restano invariati.

**Tech Stack:** R (package `simulomicsr`), testthat (TDD), `metafor` (REM), limma-voom (DE per-studio). Fixture sintetiche per i test (no H5 reale nelle unità).

## Global Constraints

- **Retrocompatibilità byte-identica** sui 3 rami esistenti: nessun cluster oggi processato (72 mega + 353 mega_aug + 8 rem) deve cambiare. Test di non-regressione obbligatori.
- **Nessun re-cluster Stadio 3**: i cluster v7 (`analysis/p4-output/20260703T113045Z-stage3-v7-364547a7/`) sono l'input; si cambia solo la selezione + pooling a valle.
- **Parametri in `stage4_default_config()`**, mai hard-coded: `k_eff_min=3`, `n_min=2`, `excluded_kinds`.
- **Soglie decise:** `k_eff ≥ 3` studi contribuenti (dopo linking), `n_min = 2` per braccio per-studio, cap superiore `k` rimosso per `rem_group`.
- **Dedup:** una meta-analisi per entità `(kind_effective_resolved, agent_id_resolved)`, livello a k massimo.
- **No augmentation** in questo plan (ibrido documentato: eventuale passo-2 data-driven post-smoke).
- **Commit atomici** italiani formato `P5 audit RED_ALERT F6: <azione>`. Master invariato, no push.
- **Comando test (laptop):** `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('<path>')"` (renv bypass, vedi CLAUDE.md note operative).
- Colonne cluster disponibili (da `.summarize_clusters`, `R/stage3-build.R`): `cluster_id, mode, level, k, n_total, n_studies, safety_min, usable_rem_strict, usable_rem_relaxed, usable_mega_strict, usable_mega_relaxed, kind_effective_resolved, agent_id_resolved, studies_in_cluster, direction_check`.

---

## File Structure

- `R/stage4-config.R` — **Modify**: aggiungi blocco `rem_group` a `stage4_default_config()` + bump `schema_versions`.
- `R/stage4-qc.R` — **Modify**: `.identify_layer_a_clusters` (aggiungi ramo `rem_group` + include nel rbind) + nuovo helper `.dedup_rem_group_by_entity`.
- `R/stage4-dispatch.R` — **Modify**: nuovo `.build_group_rem_dispatch_from_stage3` + helper `.lookup_cmp_by_treated_group`.
- `R/stage4-rem-pooling.R` — **Modify**: parametro `method_label` in `.pool_rem_cluster` (default `"rem"`, retrocompat).
- `R/stage4-orchestrator.R` — **Modify**: filtro `method` in `.run_per_study_de_all` (aggiungi `rem_group`) + ramo `rem_group` in `.pool_all_clusters` (cutoff `k_eff` + pool).
- `R/stage4-build.R` — **Modify**: costruisci `group_rem_dispatch` e fondilo in `study_dispatch`.
- `tests/testthat/test-stage4-rem-group.R` — **Create**: unità (config, porta, dedup, dispatch-builder).
- `tests/testthat/test-stage4-rem-group-integration.R` — **Create**: end-to-end mock H5 + non-regressione.
- `analysis/audit/2026-07-05-stage4-rem-group-smoke.R` — **Create** (Task 8): smoke gate script.
- `analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R` — **Create** (Task 9): script run gated v8.

---

## Task 1: Config `rem_group` + schema bump

**Files:**
- Modify: `R/stage4-config.R:12-104`
- Test: `tests/testthat/test-stage4-rem-group.R`

**Interfaces:**
- Produces: `stage4_default_config()$rem_group` = list con `k_eff_min` (int), `n_min` (int), `excluded_kinds` (chr vector). `schema_versions$rem_group_strategy` (chr).

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-stage4-rem-group.R
test_that("stage4_default_config espone il blocco rem_group con soglie decise", {
  cfg <- stage4_default_config()
  expect_true(!is.null(cfg$rem_group))
  expect_identical(cfg$rem_group$k_eff_min, 3L)
  expect_identical(cfg$rem_group$n_min, 2L)
  expect_true("vehicle_only" %in% cfg$rem_group$excluded_kinds)
  expect_true("none" %in% cfg$rem_group$excluded_kinds)
  expect_identical(cfg$schema_versions$rem_group_strategy,
                   "v1_per_study_rem_named_groups")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: FAIL (`cfg$rem_group` is NULL).

- [ ] **Step 3: Write minimal implementation**

In `R/stage4-config.R`, dentro la `list(...)` di `stage4_default_config()`, aggiungi il blocco `rem_group` subito dopo il blocco `mega_aug` (dopo la riga 73 `)`, prima di `schema_versions`):

```r
    rem_group = list(
      # FASE F6 2026-07-05: ammissione group nominati L2-L4 (safety_min basso
      # per design) al REM per-studio. safety_min NON e' un gate qui (il REM
      # modella l'eterogeneita' via I2/tau2, non la filtra). Vedi spec
      # docs/superpowers/specs/2026-07-05-stage4-rem-group-named-metaanalyses-design.md.
      k_eff_min      = 3L,               # min studi contribuenti (dopo linking control in-study)
      n_min          = 2L,               # min campioni per braccio per-studio (limma-voom richiede replica)
      excluded_kinds = c("vehicle_only", "none", "")  # kind degeneri non-perturbativi
    ),
```

E dentro `schema_versions = list(...)`, aggiungi (dopo `samn_dedupe_strategy`, con virgola prima):

```r
      ,
      # FASE F6 2026-07-05: ramo rem_group (meta-analisi nominate al REM
      # per-studio). Bump per invalidare output/cache pre-fix.
      rem_group_strategy = "v1_per_study_rem_named_groups"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage4-config.R tests/testthat/test-stage4-rem-group.R
git commit -m "P5 audit RED_ALERT F6: config rem_group + schema bump"
```

---

## Task 2: Porta di ammissione `rem_group`

**Files:**
- Modify: `R/stage4-qc.R:11-40` (`.identify_layer_a_clusters`)
- Test: `tests/testthat/test-stage4-rem-group.R`

**Interfaces:**
- Consumes: `stage4_config$rem_group$excluded_kinds`, `stage4_config$rem_group$k_eff_min`.
- Produces: righe con `method == "rem_group"` in output di `.identify_layer_a_clusters`. Depend on Task 3 helper `.dedup_rem_group_by_entity` (in questo task lo si chiama; definito in Task 3, ma per far passare il test di Task 2 si introduce uno stub identità che Task 3 sostituisce).

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-stage4-rem-group.R  (append)
.mk_cluster_row <- function(cluster_id, mode, level, k, n_total, n_studies,
                            safety_min, usable_mega_strict, kind, agent) {
  tibble::tibble(
    cluster_id = cluster_id, mode = mode, level = level, k = k,
    n_total = n_total, n_studies = n_studies, safety_min = safety_min,
    usable_rem_strict = FALSE, usable_rem_relaxed = FALSE,
    usable_mega_strict = usable_mega_strict, usable_mega_relaxed = FALSE,
    kind_effective_resolved = kind, agent_id_resolved = agent,
    studies_in_cluster = list(paste0("GSE", seq_len(n_studies))),
    direction_check = "ok"
  )
}

test_that("porta rem_group ammette group nominato L4, esclude coarse/vehicle/pair", {
  clusters <- dplyr::bind_rows(
    .mk_cluster_row("group_L4_enza", "group", 4L, 25L, 400L, 25L, 0.33,
                    FALSE, "small_molecule", "CHEBI:enzalutamide"),
    .mk_cluster_row("group_L0_coarse", "group", 0L, 8L, 200L, 8L, 0.85,
                    TRUE,  "environmental", "STR:hypoxia"),
    .mk_cluster_row("group_L3_veh", "group", 3L, 5L, 60L, 5L, 0.30,
                    FALSE, "vehicle_only", "CHEBI:dmso"),
    .mk_cluster_row("pair_L2_x", "pair", 2L, 4L, 40L, 4L, 0.60,
                    FALSE, "small_molecule", "CHEBI:foo")
  )
  cfg <- stage4_default_config()
  out <- .identify_layer_a_clusters(clusters, cfg)
  rg <- out[out$method == "rem_group", ]
  expect_identical(rg$cluster_id, "group_L4_enza")
  expect_false("group_L0_coarse" %in% out$cluster_id[out$method == "rem_group"])
  expect_false("group_L3_veh"    %in% out$cluster_id)
  expect_false(any(out$method == "rem_group" & out$mode == "pair"))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: FAIL (nessuna riga con `method == "rem_group"`).

- [ ] **Step 3: Write minimal implementation**

In `R/stage4-qc.R`, dentro `.identify_layer_a_clusters`, prima della riga `do.call(rbind, list(rem, mega, mega_aug))`, aggiungi il blocco `rem_group` e includilo nel rbind:

```r
  # rem_group (FASE F6 2026-07-05): group nominati L2-L4 (safety_min basso per
  # design) -> REM per-studio. Mutua esclusivita' col ramo mega garantita da
  # !usable_mega_strict (i L2-L4 non sono mai usable_mega_strict per il vincolo
  # di livello {0,1}; se un cluster soddisfa entrambi vince mega). Nessun gate
  # safety_min: il REM modella l'eterogeneita', non la filtra.
  rg_cfg      <- stage4_config$rem_group
  excl_kinds  <- rg_cfg$excluded_kinds %||% c("vehicle_only", "none", "")
  min_k_raw   <- rg_cfg$k_eff_min %||% 3L
  rem_group <- stage3_clusters[
    stage3_clusters$mode == "group" &
    !stage3_clusters$usable_mega_strict &
    !(stage3_clusters$kind_effective_resolved %in% excl_kinds) &
    !is.na(stage3_clusters$agent_id_resolved) &
    nzchar(stage3_clusters$agent_id_resolved) &
    stage3_clusters$k >= min_k_raw,
  ]
  if (nrow(rem_group) > 0L) {
    rem_group$method <- "rem_group"
    rem_group <- .dedup_rem_group_by_entity(rem_group)
  }

  do.call(rbind, list(rem, mega, mega_aug, rem_group))
```

E rimuovi la vecchia riga finale `do.call(rbind, list(rem, mega, mega_aug))`.

Aggiungi lo **stub** di `.dedup_rem_group_by_entity` in `R/stage4-qc.R` (sarà sostituito in Task 3), sopra `.identify_layer_a_clusters`:

```r
#' Dedup rem_group a un cluster per entita' (placeholder Task 2, impl Task 3)
#' @keywords internal
.dedup_rem_group_by_entity <- function(rem_group_clusters) {
  rem_group_clusters
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage4-qc.R tests/testthat/test-stage4-rem-group.R
git commit -m "P5 audit RED_ALERT F6: porta ammissione rem_group in identify_layer_a_clusters"
```

---

## Task 3: Dedup a un livello per entità

**Files:**
- Modify: `R/stage4-qc.R` (sostituisci lo stub `.dedup_rem_group_by_entity`)
- Test: `tests/testthat/test-stage4-rem-group.R`

**Interfaces:**
- Produces: `.dedup_rem_group_by_entity(rem_group_clusters)` → tibble con **una** riga per entità `(kind_effective_resolved, agent_id_resolved)`, quella a `k` massimo (tie-break `n_total` desc, `level` desc, `cluster_id` asc).

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-stage4-rem-group.R  (append)
test_that("dedup rem_group tiene un cluster per entita al k massimo", {
  rg <- dplyr::bind_rows(
    .mk_cluster_row("group_L4_enza", "group", 4L, 25L, 400L, 25L, 0.33,
                    FALSE, "small_molecule", "CHEBI:enzalutamide"),
    .mk_cluster_row("group_L3_enza", "group", 3L, 9L, 120L, 9L, 0.40,
                    FALSE, "small_molecule", "CHEBI:enzalutamide"),
    .mk_cluster_row("group_L4_tam", "group", 4L, 9L, 90L, 9L, 0.35,
                    FALSE, "small_molecule", "CHEBI:tamoxifen")
  )
  rg$method <- "rem_group"
  out <- .dedup_rem_group_by_entity(rg)
  expect_setequal(out$cluster_id, c("group_L4_enza", "group_L4_tam"))
  expect_identical(
    out$cluster_id[out$agent_id_resolved == "CHEBI:enzalutamide"],
    "group_L4_enza"
  )
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: FAIL (lo stub restituisce entrambi i cluster enzalutamide).

- [ ] **Step 3: Write minimal implementation**

Sostituisci lo stub in `R/stage4-qc.R` con:

```r
#' Dedup rem_group: una meta-analisi per entita' (kind, agent) al k massimo
#'
#' Le stesse entita' nominate compaiono a piu' livelli L2/L3/L4. Si tiene un
#' solo cluster per entita' \code{(kind_effective_resolved, agent_id_resolved)}:
#' quello a \code{k} massimo (tie-break \code{n_total} desc, \code{level} desc,
#' \code{cluster_id} asc). Decisione utente 2026-07-05: massimizza potenza;
#' l'eterogeneita' di contesto residua e' catturata dall'I2/tau2 del REM.
#'
#' @keywords internal
.dedup_rem_group_by_entity <- function(rem_group_clusters) {
  if (nrow(rem_group_clusters) == 0L) return(rem_group_clusters)
  entity <- paste0(rem_group_clusters$kind_effective_resolved, "||",
                   rem_group_clusters$agent_id_resolved)
  ord <- order(entity,
               -rem_group_clusters$k,
               -rem_group_clusters$n_total,
               -rem_group_clusters$level,
               rem_group_clusters$cluster_id)
  rg  <- rem_group_clusters[ord, , drop = FALSE]
  ent <- entity[ord]
  rg[!duplicated(ent), , drop = FALSE]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage4-qc.R tests/testthat/test-stage4-rem-group.R
git commit -m "P5 audit RED_ALERT F6: dedup rem_group per entita al k massimo"
```

---

## Task 4: Dispatch-builder group-aware

**Files:**
- Modify: `R/stage4-dispatch.R` (aggiungi `.lookup_cmp_by_treated_group` + `.build_group_rem_dispatch_from_stage3`)
- Test: `tests/testthat/test-stage4-rem-group.R`

**Interfaces:**
- Consumes: helper esistenti `.index_stage2_master`, `.split_record_id`, `.lookup_rg` (`R/stage4-dispatch.R`).
- Produces: `.build_group_rem_dispatch_from_stage3(eligible_clusters, stage3_assignments, stage2_master, n_min = 2L)` → named list `cluster_id → list di {study_id, treated, control}` (stesso schema di `.build_study_dispatch_from_stage3`). Entry con `<n_min` treated o control scartate; dedup per `(study_id, treated_group)`. `.lookup_cmp_by_treated_group(study, group_id)` → comparison (list) con `treated_group == group_id`, o NULL.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-stage4-rem-group.R  (append)
.mk_study <- function(series_id, rgs, cmps) {
  list(series_id = series_id, replicate_groups = rgs, comparisons = cmps)
}
.rg <- function(group_id, role, sids) {
  list(group_id = group_id, primary_role = role, sample_ids = sids)
}
.cmp <- function(comparison_id, treated_group, control_group) {
  list(comparison_id = comparison_id, treated_group = treated_group,
       control_group = control_group)
}

test_that("group_rem_dispatch linka i control in-study (both_roles + treated_only)", {
  # Studio both_roles: treated tg1 + control cg1 nello stesso studio, entrambi
  # membri del cluster (record __tg1 e __cg1).
  s_both <- .mk_study("GSE1",
    rgs  = list(.rg("tg1","treated",c("s1","s2","s3")),
                .rg("cg1","control",c("s4","s5"))),
    cmps = list(.cmp("c1","tg1","cg1")))
  # Studio treated_only: solo tg2 nel cluster; il control cg2 vive fuori dal
  # cluster ma nella comparison dello stesso studio.
  s_treat <- .mk_study("GSE2",
    rgs  = list(.rg("tg2","treated",c("t1","t2")),
                .rg("cg2","control",c("u1","u2"))),
    cmps = list(.cmp("c2","tg2","cg2")))
  # Studio senza control ricostruibile: comparison assente per tg3.
  s_noctrl <- .mk_study("GSE3",
    rgs  = list(.rg("tg3","treated",c("x1","x2"))),
    cmps = list())
  # Studio con < n_min control (1 solo control) -> scartato.
  s_small <- .mk_study("GSE4",
    rgs  = list(.rg("tg4","treated",c("a1","a2")),
                .rg("cg4","control",c("b1"))),
    cmps = list(.cmp("c4","tg4","cg4")))
  stage2_master <- list(s_both, s_treat, s_noctrl, s_small)

  eligible <- .mk_cluster_row("group_L4_e", "group", 4L, 4L, 40L, 4L, 0.3,
                              FALSE, "small_molecule", "CHEBI:e")
  eligible$method <- "rem_group"
  assignments <- tibble::tibble(
    cluster_id = "group_L4_e",
    record_id  = c("GSE1__tg1", "GSE1__cg1", "GSE2__tg2",
                   "GSE3__tg3", "GSE4__tg4")
  )

  disp <- .build_group_rem_dispatch_from_stage3(eligible, assignments,
                                                stage2_master, n_min = 2L)
  d <- disp[["group_L4_e"]]
  studies <- vapply(d, function(x) x$study_id, character(1))
  expect_setequal(studies, c("GSE1", "GSE2"))   # GSE3 no-ctrl, GSE4 <n_min esclusi
  gse1 <- d[[which(studies == "GSE1")]]
  expect_setequal(gse1$treated, c("s1","s2","s3"))
  expect_setequal(gse1$control, c("s4","s5"))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: FAIL (`.build_group_rem_dispatch_from_stage3` non esiste).

- [ ] **Step 3: Write minimal implementation**

In `R/stage4-dispatch.R`, aggiungi in coda:

```r
#' Lookup comparison da study via treated_group (prima match, deterministico)
#'
#' Per i group treated-only il control vive fuori dal cluster: si risale al
#' control_group dello stesso studio cercando la comparison in cui il group_id
#' e' il \code{treated_group}. Se un group e' treated_group di piu' comparison,
#' vince la prima (ordine deterministico dell'input stage2).
#'
#' @keywords internal
.lookup_cmp_by_treated_group <- function(study, group_id) {
  for (cmp in study$comparisons) {
    if (identical(cmp$treated_group, group_id)) return(cmp)
  }
  NULL
}

#' Costruisce study_dispatch per cluster group-mode nominati (rem_group)
#'
#' Mappa ogni cluster group con method \code{rem_group} in una lista di
#' per-study record \code{{study_id, treated, control}}, con lo STESSO schema
#' di \code{.build_study_dispatch_from_stage3} (cosi' il dispatch si fonde nello
#' stesso attr "study_dispatch" e il ramo REM per-studio lo consuma invariato).
#'
#' Per ogni record group \code{<series>__<group_id>} treated si cerca la
#' comparison dello stesso studio in cui \code{group_id} e' il treated_group ->
#' control_group -> sample_ids (stesso studio). Serve UNIFORMEMENTE both_roles
#' (control nel cluster) e treated_only (control in record fratello): la
#' relazione vive sempre in \code{study\$comparisons}. Entry con < n_min treated
#' o control scartate (limma-voom richiede replica). Dedup per
#' \code{(study_id, treated_group)}.
#'
#' @inheritParams .build_study_dispatch_from_stage3
#' @param n_min integer campioni minimi per braccio per-studio (default 2).
#' @return named list (cluster_id -> list di \code{{study_id, treated,
#'   control}}). Cluster senza entry valide sono omessi.
#' @keywords internal
.build_group_rem_dispatch_from_stage3 <- function(eligible_clusters,
                                                   stage3_assignments,
                                                   stage2_master,
                                                   n_min = 2L) {
  group_clusters <- eligible_clusters[
    eligible_clusters$mode == "group" &
      eligible_clusters$method == "rem_group",
  ]
  if (nrow(group_clusters) == 0L) return(list())

  s2_idx <- .index_stage2_master(stage2_master)
  asg_by_clid <- split(stage3_assignments$record_id,
                       stage3_assignments$cluster_id)

  dispatch <- vector("list", 0L)
  for (i in seq_len(nrow(group_clusters))) {
    cid <- group_clusters$cluster_id[i]
    record_ids <- asg_by_clid[[cid]]
    if (is.null(record_ids) || length(record_ids) == 0L) next

    cluster_dispatch <- vector("list", 0L)
    seen_keys <- character(0L)
    for (rid in record_ids) {
      parsed <- .split_record_id(rid)
      if (is.na(parsed$series_id)) next
      if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
      study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
      cmp <- .lookup_cmp_by_treated_group(study, parsed$suffix)
      if (is.null(cmp)) next

      tg <- .lookup_rg(study, cmp$treated_group)
      cg <- .lookup_rg(study, cmp$control_group)
      if (is.null(tg) || is.null(cg)) next
      treated <- as.character(unlist(tg$sample_ids))
      control <- as.character(unlist(cg$sample_ids))
      if (length(treated) < n_min || length(control) < n_min) next

      key <- paste0(parsed$series_id, "||", cmp$treated_group)
      if (key %in% seen_keys) next
      seen_keys <- c(seen_keys, key)

      cluster_dispatch[[length(cluster_dispatch) + 1L]] <- list(
        study_id = parsed$series_id,
        treated  = treated,
        control  = control
      )
    }
    if (length(cluster_dispatch) > 0L) {
      dispatch[[cid]] <- cluster_dispatch
    }
  }
  dispatch
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage4-dispatch.R tests/testthat/test-stage4-rem-group.R
git commit -m "P5 audit RED_ALERT F6: dispatch-builder group-aware rem_group (control in-study via comparisons)"
```

---

## Task 5: `.pool_rem_cluster` — parametro `method_label`

**Files:**
- Modify: `R/stage4-rem-pooling.R:26-107`
- Test: `tests/testthat/test-stage4-rem-group.R`

**Interfaces:**
- Produces: `.pool_rem_cluster(per_study_de_subset, method = "REML", fallback = "DL", method_label = "rem")` → la colonna `method` dell'output vale `method_label`. Default `"rem"` = retrocompat byte-identica.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-stage4-rem-group.R  (append)
test_that(".pool_rem_cluster marca il method_label (rem_group) senza rompere il default", {
  subset <- tibble::tibble(
    cluster_id = "group_L4_e",
    gene_id    = rep(c("ENSG1", "ENSG2"), each = 3L),
    gene_symbol = rep(c("A", "B"), each = 3L),
    logFC      = c(1.0, 1.2, 0.8, -0.5, -0.6, -0.4),
    SE         = rep(0.2, 6L)
  )
  out_default <- .pool_rem_cluster(subset)
  expect_true(all(out_default$method == "rem"))
  out_group <- .pool_rem_cluster(subset, method_label = "rem_group")
  expect_true(all(out_group$method == "rem_group"))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: FAIL (`method_label` non è un argomento; oppure `out_group$method` è `"rem"`).

- [ ] **Step 3: Write minimal implementation**

In `R/stage4-rem-pooling.R`, cambia la firma (riga 26-27):

```r
.pool_rem_cluster <- function(per_study_de_subset, method = "REML",
                              fallback = "DL", method_label = "rem") {
```

e nella costruzione della tibble output (riga 83) sostituisci `method = "rem",` con:

```r
      method       = method_label,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/stage4-rem-pooling.R tests/testthat/test-stage4-rem-group.R
git commit -m "P5 audit RED_ALERT F6: method_label in pool_rem_cluster (default rem, retrocompat)"
```

---

## Task 6: Orchestratore — instradamento `rem_group` + cutoff `k_eff`

**Files:**
- Modify: `R/stage4-orchestrator.R:32-35` (filtro `.run_per_study_de_all`)
- Modify: `R/stage4-orchestrator.R:159-184` (ramo `rem_group` in `.pool_all_clusters`)
- Test: `tests/testthat/test-stage4-rem-group-integration.R`

**Interfaces:**
- Consumes: `attr(eligible_clusters, "study_dispatch")` (ora include i cluster rem_group, merge in Task 7), nuovo parametro `rem_group_config` di `.pool_all_clusters` (`.pool_all_clusters` **non** riceve `config` intero — solo `mega_aug_config` e sotto-parametri, firma `R/stage4-orchestrator.R:131-138`; va aggiunto un parametro esplicito).
- Produces: risultati con `method == "rem_group"` in `cluster_pooled`; cluster con `k_eff < k_eff_min` registrati in `non_processable` con reason `rem_group_insufficient_in_study_controls: k_eff=<n>`.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-stage4-rem-group-integration.R
test_that(".run_per_study_de_all include i cluster rem_group", {
  eligible <- tibble::tibble(
    cluster_id = "group_L4_e", mode = "group", method = "rem_group",
    direction_check = "ok"
  )
  fetch_fn <- function(gse, sids) {
    m <- matrix(rpois(20L * length(sids), 100L), nrow = 20L,
                dimnames = list(paste0("ENSG", 1:20), sids))
    m
  }
  disp <- list(group_L4_e = list(
    list(study_id = "GSE1", treated = c("s1","s2","s3"), control = c("s4","s5")),
    list(study_id = "GSE2", treated = c("t1","t2"),      control = c("u1","u2")),
    list(study_id = "GSE5", treated = c("p1","p2"),      control = c("q1","q2"))
  ))
  attr(eligible, "study_dispatch") <- disp
  res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn)
  expect_true(nrow(res) > 0L)
  expect_true(all(res$cluster_id == "group_L4_e"))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group-integration.R')"`
Expected: FAIL (rem_group non nel filtro `method`, `res` vuoto).

- [ ] **Step 3: Write minimal implementation**

(a) In `R/stage4-orchestrator.R`, riga 32-35, estendi il filtro:

```r
  # Filtra solo REM + MEGA-AUG + REM_GROUP (MEGA puro non fa per-study DE).
  per_study_clusters <- eligible_clusters[
    eligible_clusters$method %in% c("rem", "mega_aug", "rem_group"),
  ]
```

(b) In `.pool_all_clusters` aggiungi un parametro alla firma (`R/stage4-orchestrator.R:131-138`) — `config` intero non è in scope qui:

```r
.pool_all_clusters <- function(per_study_de, eligible_clusters, fetch_fn,
                                stage3_clusters, workers = 1L,
                                dream_workers_cap = 8L,
                                mega_aug_config = NULL,
                                rem_group_config = NULL,
                                biosample_lookup = NULL,
                                libsize_lookup = NULL,
                                metadata_extra = NULL,
                                de_covariates = character(0)) {
```

e subito dopo `group_dispatch <- attr(eligible_clusters, "group_dispatch")` (riga 160), leggi la soglia:

```r
  rem_group_k_eff_min <- rem_group_config$k_eff_min %||% 3L
```

(c) Nel corpo del loop, subito dopo il ramo `if (method == "rem") { ... }` (dopo la riga 184 `out_list[[...]] <- pool`), aggiungi il ramo `rem_group` come `else if`:

```r
    } else if (method == "rem_group") {
      disp_i <- dispatch[[cid]]
      k_eff  <- length(disp_i %||% list())
      if (k_eff < rem_group_k_eff_min) {
        non_processable_list[[length(non_processable_list) + 1L]] <-
          tibble::tibble(
            cluster_id         = cid,
            original_k         = NA_integer_,
            qc_final_k         = k_eff,
            original_n_studies = NA_integer_,
            qc_final_n_studies = k_eff,
            reason = sprintf("rem_group_insufficient_in_study_controls: k_eff=%d",
                             k_eff)
          )
        next
      }
      subset <- per_study_de[per_study_de$cluster_id == cid, ]
      pool <- .pool_rem_cluster(subset, method_label = "rem_group")
      out_list[[length(out_list) + 1L]] <- pool
```

(Il passaggio di `rem_group_config` dal chiamante `build_stage4_results` è fatto in Task 7 Step 3b.)

- [ ] **Step 4: Run test to verify it passes**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group-integration.R')"`
Expected: PASS (il primo test; il ramo pool completo è coperto in Task 7).

- [ ] **Step 5: Commit**

```bash
git add R/stage4-orchestrator.R tests/testthat/test-stage4-rem-group-integration.R
git commit -m "P5 audit RED_ALERT F6: orchestrator instrada rem_group + cutoff k_eff in non_processable"
```

---

## Task 7: Aggancio in `build_stage4_results` + end-to-end + non-regressione

**Files:**
- Modify: `R/stage4-build.R:152-159`
- Test: `tests/testthat/test-stage4-rem-group-integration.R`

**Interfaces:**
- Consumes: `.build_group_rem_dispatch_from_stage3` (Task 4), `config$rem_group$n_min`.
- Produces: `study_dispatch` (attr) fuso con `group_rem_dispatch`; i cluster rem_group fluiscono nel per-study DE + pool.

- [ ] **Step 1: Write the failing test (merge dispatch)**

```r
# tests/testthat/test-stage4-rem-group-integration.R  (append)
test_that("il group_rem_dispatch si fonde nello study_dispatch (cluster_id disgiunti)", {
  study_dispatch <- list(pair_A = list(list(study_id = "GSE9",
    treated = c("a","b"), control = c("c","d"))))
  group_rem_dispatch <- list(group_L4_e = list(list(study_id = "GSE1",
    treated = c("s1","s2"), control = c("s3","s4"))))
  merged <- c(study_dispatch, group_rem_dispatch)
  expect_setequal(names(merged), c("pair_A", "group_L4_e"))
  expect_length(merged, 2L)
})
```

- [ ] **Step 2: Run test to verify it fails/passes**

Run: `Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group-integration.R')"`
Expected: PASS (verifica la semantica del merge `c()`; è il contratto che implementiamo in Step 3).

- [ ] **Step 3: Implement the merge in build**

In `R/stage4-build.R`, dopo il blocco `study_dispatch <- .build_study_dispatch_from_stage3(...)` (righe 152-154) e prima di `group_dispatch <- .build_group_dispatch_from_stage3(...)` (riga 155), inserisci:

```r
  # FASE F6 2026-07-05: group nominati L2-L4 -> REM per-studio. Stesso schema
  # {study_id, treated, control} dei pair, quindi si fonde nello study_dispatch
  # (cluster_id disgiunti: rem_group e' group, rem/mega_aug sono pair).
  group_rem_dispatch <- .build_group_rem_dispatch_from_stage3(
    qc$eligible_clusters, stage3_assignments, stage2_master,
    n_min = config$rem_group$n_min %||% 2L
  )
  study_dispatch <- c(study_dispatch, group_rem_dispatch)
```

- [ ] **Step 3b: Propaga `rem_group_config` alla chiamata `.pool_all_clusters`**

In `R/stage4-build.R`, nella chiamata `.pool_all_clusters(...)` (riga 193), aggiungi il parametro subito dopo `mega_aug_config = config$mega_aug,`:

```r
    mega_aug_config   = config$mega_aug,
    rem_group_config  = config$rem_group,
```

- [ ] **Step 4: Write the end-to-end + non-regression test**

```r
# tests/testthat/test-stage4-rem-group-integration.R  (append)
test_that("non-regressione: identify_layer_a non altera i rami rem/mega/mega_aug", {
  # Un cluster per ramo esistente + un rem_group; i method dei rami esistenti
  # restano invariati e disgiunti dal nuovo.
  clusters <- dplyr::bind_rows(
    .mk_cluster_row("pair_rem",  "pair",  0L, 5L, 60L, 5L, 0.80, FALSE,
                    "small_molecule", "CHEBI:a"),
    .mk_cluster_row("group_meg", "group", 0L, 8L, 200L, 8L, 0.90, TRUE,
                    "environmental", "STR:hyp"),
    .mk_cluster_row("group_reg", "group", 4L, 25L, 400L, 25L, 0.30, FALSE,
                    "small_molecule", "CHEBI:enza")
  )
  clusters$usable_rem_strict[clusters$cluster_id == "pair_rem"] <- TRUE
  cfg <- stage4_default_config()
  out <- .identify_layer_a_clusters(clusters, cfg)
  expect_identical(out$method[out$cluster_id == "pair_rem"], "rem")
  expect_identical(out$method[out$cluster_id == "group_meg"], "mega")
  expect_identical(out$method[out$cluster_id == "group_reg"], "rem_group")
})
```

- [ ] **Step 5: Run all rem-group tests + regression suite**

Run:
```
Rscript --vanilla -e "devtools::load_all('.'); testthat::test_file('tests/testthat/test-stage4-rem-group.R'); testthat::test_file('tests/testthat/test-stage4-rem-group-integration.R')"
Rscript --vanilla -e "devtools::load_all('.'); testthat::test_dir('tests/testthat', filter='stage4')"
```
Expected: tutti PASS, 0 FAIL. La suite `stage4` esistente (rem/mega/mega_aug/qc/dispatch) resta verde (non-regressione).

- [ ] **Step 6: Commit**

```bash
git add R/stage4-build.R tests/testthat/test-stage4-rem-group-integration.R
git commit -m "P5 audit RED_ALERT F6: merge group_rem_dispatch in build + end-to-end + non-regressione"
```

---

## Task 8: Smoke gate (validate-before-fullrun) — GATE UTENTE

**Files:**
- Create: `analysis/audit/2026-07-05-stage4-rem-group-smoke.R`

**Interfaces:**
- Consumes: Stadio 3 v7 (`analysis/p4-output/20260703T113045Z-stage3-v7-364547a7/{clusters.rds,assignments.parquet}`), stage2 master v3 (`analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`), H5 (`analysis/input/human_gene_v2.5.h5`).
- Produces: report `analysis/audit/2026-07-05-stage4-rem-group-smoke.md` + CSV con, per un sottoinsieme di entità nominate note (SARS-CoV-2, enzalutamide, Breast Neoplasms, Prostatic, Alzheimer, fulvestrant, tamoxifen, vemurafenib): `entity, k_raw, k_eff, ammesso, I2_median, tau2_median, n_sig_FDR05`, + conteggio globale dei cadenti per `k_eff<3`.

- [ ] **Step 1: Scrivi lo script smoke**

Lo script (NON-TDD, è validazione): carica i cluster v7, applica `.identify_layer_a_clusters` con la config aggiornata, filtra `method=="rem_group"`, costruisce il `group_rem_dispatch`, e per il sottoinsieme bandiera esegue il per-study DE + pool su un cap di studi (subset), misurando `k_eff`, quanti studi cadono per assenza di controllo in-study, e I²/τ² risultanti. Riusa `.build_group_rem_dispatch_from_stage3`, `.run_per_study_de_all`, `.pool_rem_cluster` via `devtools::load_all()`. H5 fetch via `.fetch_counts_cached` (cache-backed).

Struttura minima:
```r
devtools::load_all(".")
stage3_dir <- "analysis/p4-output/20260703T113045Z-stage3-v7-364547a7"
clusters   <- readRDS(file.path(stage3_dir, "clusters.rds"))
assignments <- arrow::read_parquet(file.path(stage3_dir, "assignments.parquet"))
stage2_master <- .load_stage2_master("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
cfg <- stage4_default_config()

layer_a <- .identify_layer_a_clusters(clusters, cfg)
rg <- layer_a[layer_a$method == "rem_group", ]
message(sprintf("rem_group ammessi (post-dedup): %d entita", nrow(rg)))

disp <- .build_group_rem_dispatch_from_stage3(rg, assignments, stage2_master,
                                              n_min = cfg$rem_group$n_min)
k_eff <- vapply(rg$cluster_id, function(c) length(disp[[c]] %||% list()), integer(1))
# ... tabella entity/k_raw/k_eff/ammesso + salva CSV + report md
# ... per le entita bandiera: pool REM su subset e riporta I2/tau2/n_sig
```

- [ ] **Step 2: Esegui lo smoke (leggero, no run 11h)**

Run: `Rscript --vanilla analysis/audit/2026-07-05-stage4-rem-group-smoke.R 2>&1 | tee analysis/audit/2026-07-05-stage4-rem-group-smoke.log`
Expected: le entità bandiera entrano nella porta; `k_eff` sensato; il REM produce estimate/I²/τ² finiti. Report + CSV materializzati.

- [ ] **Step 3: GATE UTENTE**

Presenta il report: quante/quali entità sopravvivono a `k_eff≥3`, quante cadono per mancanza di controlli in-study, valori I²/τ². **Decisione data-driven:** se troppe cadono → discutere il passo-2 augmentation (fuori da questo plan). Solo con approvazione esplicita si procede al Task 9.

- [ ] **Step 4: Commit**

```bash
git add analysis/audit/2026-07-05-stage4-rem-group-smoke.R analysis/audit/2026-07-05-stage4-rem-group-smoke.md
git commit -m "P5 audit RED_ALERT F6: smoke gate rem_group (report entita bandiera + cadenti)"
```

---

## Task 9: Run gated re-pool Stadio 4 v8 — GATE UTENTE

**Files:**
- Create: `analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R` (copia di `-v7.R` con 3-4 edit)

**Interfaces:**
- Consumes: Stadio 3 v7 + stage2 master v3 + H5 (come Task 8).
- Produces: `/sda/simulomicsr-stage4-v8/<ts>-stage4-v8-*/` con `cluster_pooled.parquet` (ora include `method=="rem_group"`), `per_study_de.parquet`, `run_metadata.json` (config `rem_group` + soglie registrate), `non_processable.rds`.

- [ ] **Step 1: Prepara lo script v8**

Copia `analysis/p4-fase-f5-stage4-layer-a-rebuild-v7.R` → `-v8.R`. Edit: `stage3_dir` → v7 (invariato, i cluster v7 vanno bene); `out_dir` → `/sda/simulomicsr-stage4-v8/` + token `v8`; log message v7→v8. **Non** serve re-cluster Stadio 3. Verifica che `build_stage4_results` riceva `config = stage4_default_config()` (che ora include `rem_group`).

- [ ] **Step 2: Smoke DRY_RUN dello script v8**

Run: `SMOKE=1 Rscript --vanilla analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R`
Expected: la selezione riporta i cluster rem_group ammessi (> 0), nessun errore di config/path.

- [ ] **Step 3: GATE UTENTE — full run detached (~11h)**

Con approvazione esplicita: `setsid Rscript --vanilla analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R > <log> 2>&1 < /dev/null &` (memoria `feedback_setsid_for_long_detached_runs`; verifica `SID==PID`). Monitor via `pgrep -f rebuild-v8`. Alternativa DGX (2TB RAM) se serve. **Non** usare `run_in_background`.

- [ ] **Step 4: Re-gate + closeout**

Verifica output v8: n. cluster `rem_group` poolati, entità nominate presenti (SARS/enzalutamide/Breast), distribuzione I²/τ². Aggiorna: finding `docs/findings/2026-07-05-stage4-rem-group-results.md`, CLAUDE.md (stato sessione), ledger `.superpowers/sdd/progress.md`, ADR-0022 (Accepted), memoria `project_stage3_minestrone_rework`. Master invariato, no push.

---

## Self-Review

**1. Spec coverage** (spec §3 decisioni → task):
- REM per-studio uniforme → Task 4 (dispatch) + Task 6 (instradamento) + Task 5 (label). ✓
- Porta strutturale senza safety + I² a valle → Task 2 (porta) ; I² prodotto da `.pool_rem_cluster` (esistente), gate qualità a valle = Layer B (fuori scope, documentato). ✓
- Ibrido documentato (no augmentation) → Task 6 (cutoff → non_processable, no augmentation) + Task 8 (report cadenti, decisione passo-2). ✓
- Soglie k_eff≥3 / n_min=2 / cap rimosso → Task 1 (config) + Task 4 (n_min) + Task 6 (k_eff); il cap `k≤9` non è mai applicato al ramo rem_group (nessun vincolo superiore nel filtro Task 2). ✓
- Dedup una per entità a k massimo → Task 3. ✓
- Output `method="rem_group"` + schema bump → Task 5 + Task 1. ✓
- Smoke gate + run gated → Task 8 + Task 9. ✓

**2. Placeholder scan:** nessun TBD/TODO; ogni step di codice mostra codice reale. Il solo punto "verifica il nome del parametro config" (Task 6 nota) è un'istruzione di allineamento al codice esistente, non un buco di design.

**3. Type consistency:** `.build_group_rem_dispatch_from_stage3` ritorna named list `cluster_id → list di {study_id, treated, control}` — identico schema consumato da `.run_per_study_de_all` (`R/stage4-orchestrator.R:46-53`). `method_label` (Task 5) coerente con `method=="rem_group"` (Task 2/6). `.dedup_rem_group_by_entity` firma stabile Task 2 (stub) → Task 3 (impl). `k_eff = length(dispatch[[cid]])` coerente col contatore entry del builder.
