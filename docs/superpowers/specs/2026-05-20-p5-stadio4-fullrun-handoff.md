# P5 Stadio 4 — Handoff fullrun (2026-05-20)

## Stato branch

- Branch: `p5-stadio4-de-perstudio`
- HEAD: `699dc49` — "P5 Stadio 4 fullrun fix #2: MEGA path dedup + rank-deficient skip + pooling_warnings"
- Suite Stadio 4: **145 PASS / 0 FAIL / 1 SKIP** (Quarto SKIP pre-esistente)
- Pacchetto installato nella renv lib (`devtools::install(quick=TRUE)` per la sessione corrente)
- Untracked file di run-state nel filesystem (gitignored): `analysis/p5-stage4-layer-a-fullrun.{log,state,r.pid,wrapper.pid,pid}`. R process NON attivo (ultimo run failed).

## Riepilogo delle 4 sessioni di lavoro (2026-05-19/20)

### Task 16-17 + bench (sessioni precedenti)

- Task 16b/c/d: dispatch builders + mega_aug control_anchor_key wiring (gap del plan emerso a smoke).
- Task 17: smoke 5-cluster script + ARCHS4 v2.5 H5 sample-axis fix.
- Bench DE methods seriale: M1 (voomDream+dream, ref), M2 (voom+dream), M3 (limma+dupCor), M4 (study fixed-eff). dream domina wall (1819 sec su mega_aug k=2). M3 = 20-63x speedup ma ρ logFC scende a 0.947 a k=11. M4 fragile (Coefficients not estimable su collinear study).
- Bench parallel dgx 100-core + OPENBLAS=1: speedup 12-18x (35 min → 2 min per cluster mega_aug).
- ADR-0015: scelta `dream` parallel default + `compute$dream_workers = NA_integer_` (auto-detect), capped a `dream_workers_cap = 100L`. Allineato al FDR-calibration benchmark dell'utente.

### Fix #1 (commit `b5bd59f`, MEGA-AUG path)

Bug fullrun 1° tentativo (43 min wall, exit=1): `duplicate 'row.names': GSM4556584` in
`.run_dream_mega` per cluster MEGA-AUG. Pair_cluster con piu' comparison-records condividono
treated_group → unlist produce duplicati.

Fix:
- `.assemble_mega_aug_metadata` dedupa pair_treated/control (treated > control wins).
- Aggiunto mapping per-sample → study esplicito (`treated_sample_studies`, `control_sample_studies`)
  per risolvere ANCHE bug latente cyclic `rep(studies_in_cluster, length.out=...)`.
- `.enrich_group_baseline_sample_ids` aggiunge `sample_studies` list-column parallela a `sample_ids`.

Smoke 1-cluster mega_aug postfix: OK in 6 min.

### Fix #2 (commit `699dc49`, MEGA path)

Bug fullrun 2° tentativo (29 min wall, exit=1): **STESSO errore** `GSM4556584 duplicate`,
ma sul **path MEGA puro** (non mega_aug). Errore del fix #1: limitato il dedup solo a mega_aug
quando il pattern era piu' generale.

Fix:
- Nuovo file `R/stage4-mega-safe.R`:
  - `.build_mega_metadata_safe(grp, cluster_id)` → metadata deduped + conflicts tibble.
    Distingue 3 casi: (a) same study + same role → dedup silent; (b) same sample + different
    roles → DROPPED + `role_conflict_dropped` log; (c) cross-study same role →
    `cross_study_duplicate_kept_first` log.
  - `.check_mega_rank(metadata, n_min=2L)` → rank-deficient se n per livello < n_min.
- Orchestrator MEGA branch usa helper + skippa cluster rank-deficient (registrati in
  `non_processable` con motivo esplicito).
- `cluster_pooled` ora porta `attr(., "pooling_warnings")` e `attr(., "non_processable_in_pool")`
  propagati a `qc_report`.

Smoke 5-pick postfix#2: build complete in 671.8 sec MA gate `stopifnot(n_rows > 0L)` FAILED su
`group_L0_c62104eb`: 0 righe perche' rank-deficient (19 control + 1 treated, n_min=2 → skipped).
**Comportamento corretto** del fix, **gate troppo stretto**.

## Open issues (non risolti — input per nuova sessione)

### 1. Smoke gate troppo stretto

`analysis/p5-stage4-smoke5.R` ha `stopifnot(n_rows > 0L)` per ogni pick. Con il fix #2 i
cluster rank-deficient sono skippati intenzionalmente → 0 rows e' un esito valido. Gate da
rilassare: accept skipped cluster se il cluster appare in `result$qc_report$qc_drops_cluster`
con motivo `mega_rank_deficient`.

### 2. Decisione scientifica su cluster baseline-pool (richiesta utente)

L'utente ha sollevato 2026-05-20: "Se hanno tutti treated puo essere che possano essere
usati assieme ad altri campioni no?"

Cluster `group_L0_c62104eb` ha anchor `none|unknown|wt|nodose|na|exposure|CD4+ T cells|...`
= **baseline pool di CD4+ T cells non-perturbate da 5 studi**. Non e' un MEGA contrast — e'
un baseline. Il 1 sample "treated" e' probabilmente Stage 2 LLM misclassification.

3 opzioni (DA DECIDERE con utente, NON ancora implementate):

- **A. Skip + visibility**: Skip MEGA contrast (corretto), arricchire `non_processable` con
  `n_treated`, `n_control`, `n_studies`, `anchor_key`, `candidate_baseline_pool_for_aug`
  flag. Sezione dashboard "Skipped clusters classification" (3 cat: rank-deficient,
  imbalanced, conflicts). I sample sono comunque usati come baseline aug via
  `.enrich_group_baseline_sample_ids` (gia' implementato). **Minimal change, immediato.**
- **B. MEGA-AUG bidirezionale**: nuovo path "baseline_aug_pair" dove un baseline cluster (n
  ≥ 5 di una sola condizione) e' augmentato con un pair k=2 che fornisce il braccio
  mancante (treated). Significativo design change. ADR-grade + dev settimana.
- **C. Layer A re-definition**: includere in Layer A solo group cluster con min(n_treated,
  n_control) ≥ n_min. Cluster baseline-only fuori da Layer A (rimangono solo come baseline
  per mega_aug). Cambia count Layer A (312 → ~150 stimato). Decisione ADR-grade.

Mia preferenza: A per questo fullrun + B/C come decisione separata.

### 3. n_min_mega_treatment configurabile

Attualmente `.check_mega_rank` hardcoda `n_min = 2L`. Aggiungere a `stage4_default_config()`
come `compute$mega_n_min_per_level = 2L` cosi' l'utente puo' overridare senza patchare codice.

### 4. Conflict logging in mega_aug

Il fix #1 di `.assemble_mega_aug_metadata` dedupa silenziosamente. Per simmetria con MEGA,
dovrebbe emettere `conflicts` tibble analogo (role_conflict_dropped per sample in
treated+control overlap, cross_study_duplicate_kept_first per cross-study dup nel baseline).

### 5. Tag chiusura branch (Task 20)

Bloccato finche' Layer A fullrun non completa con successo. Procedura: ff-merge a master +
tag `p5-stadio4-complete`. ADR-0015 aggiornato a `Accepted` con i numeri Layer A reali.

## File chiave

- `R/stage4-mega-safe.R` (NEW) — `.build_mega_metadata_safe` + `.check_mega_rank`
- `R/stage4-orchestrator.R` — MEGA + MEGA-AUG branches con safe helpers
- `R/stage4-mega-aug.R` — `.assemble_mega_aug_metadata` con per-sample study map (fix #1)
- `R/stage4-dispatch.R` — `.enrich_group_baseline_sample_ids` con sample_studies parallel
- `analysis/p5-stage4-smoke5.R` — smoke 5-pick (gate da rilassare, vedi #1)
- `analysis/p5-stage4-layer-a-fullrun.R` — fullrun script (committed)
- `analysis/p5-stage4-dream-perf-bench.R` — bench seriale (committed)
- `analysis/p5-stage4-dream-parallel-bench.R` — bench parallel (committed)
- `analysis/p5-stage4-bench-k11.R` — bench k=11 validation (committed)
- `docs/findings/2026-05-20-stage4-de-method-bench.md` — bench results
- `docs/decisions/0015-stage4-dream-default-parallel.md` — ADR Status: Accepted

## Tasks da fare nella nuova sessione (ordine)

1. **Discutere decisione cluster baseline-pool** (#2): A / B / C / hybrid → utente decide.
2. **Implementare la decisione**.
3. **Rilassare smoke gate** (#1): accept skipped cluster.
4. **Configurabilita' n_min** (#3): aggiungere a `stage4_default_config()`.
5. **Conflict logging mega_aug** (#4): symmetry con MEGA.
6. **Smoke 5-pick** real-data per verifica end-to-end. Wall budget aspettato ~12-15 min.
7. **Layer A fullrun** (nohup setsid, ~17-28h overnight). Cron orario per active monitoring.
8. **Task 20 chiusura**: ADR Accepted + ff-merge + tag.
