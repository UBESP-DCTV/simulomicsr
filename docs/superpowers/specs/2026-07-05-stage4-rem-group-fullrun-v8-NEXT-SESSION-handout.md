# Handout — Prossima sessione: FULLRUN Stadio 4 v8 (ramo rem_group)

**Data:** 2026-07-05
**Per:** sessione dedicata al re-pool Stadio 4 v8 (run gated ~11-15h)
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push)
**Prerequisito:** codice ramo `rem_group` COMPLETO + validato (questa sessione). NON serve altro sviluppo.

## In una frase

Il codice del nuovo ramo di pooling `rem_group` (meta-analisi cross-studio nominate L2–L4)
è implementato, revisionato (final review Opus) e validato sui dati veri. Resta **un solo passo**:
lanciare il **re-pool Stadio 4 v8** con lo script già pronto e DRY_RUN-validato, poi il closeout.
**NON serve re-cluster Stadio 3.**

## ⚠️ CACHE — LEGGERE PRIMA (la lezione dell'ultima volta)

L'utente teme la ripetizione del disastro v6→v7 (cache stale → fullrun sprecato, output identico).
**Quel caso NON si applica qui, ma va capito il perché:**

- **v6→v7** era la cache del **name-recovery dello Stadio 3** (`.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`,
  memoria `feedback_bump_lookup_cache_version`): un **re-cluster** riusò il lookup su disco stale.
- **v8 è un re-pool Stadio 4, NON un re-cluster.** L'unica cache in gioco è la **cache dei counts**
  (`~/.cache/R/simulomicsr/stage4-counts/`, `.cache_key_for_fetch` in `R/stage4-counts-cache.R`):
  memoizza SOLO le matrici di conteggi grezze lette dall'H5, con chiave
  `(v2_ensembl, biotype, gse, sorted(sample_ids))` — **indipendente dal metodo di pooling**.

**Conseguenze operative:**
1. ✅ **NON purgare la cache counts.** Va RIUSATA: velocizza (niente ri-lettura dei 47 GB H5) e
   NON produce stale — i counts di uno studio sono identici a prescindere dal ramo. Gli studi dei
   `rem_group` non ancora in cache verranno fetchati normalmente.
2. ✅ **Non esiste cache del risultato pooled.** `build_stage4_results` ricalcola SEMPRE DE +
   pooling; il ramo `rem_group` + `.collapse_arms_by_study` è codice fresco, eseguito ad ogni run:
   NON può essere "saltato" da una cache.
3. ✅ Il bump `schema_versions$rem_group_strategy = "v1_per_study_rem_named_groups"` (aggiunto in
   questa sessione) NON tocca la chiave della cache counts → non la invalida impropriamente.
4. **VERIFICA ANTI-STALE (obbligatoria a fine run):** il summary del run v8 DEVE mostrare
   `Methods = ..., rem_group` e `di cui rem_group ~70` (cluster pooled). Se `rem_group = 0` →
   RED (ma non sarebbe cache: sarebbe un bug — indagare, non ri-lanciare alla cieca).

## Come lanciare (script pronto, DRY_RUN già validato)

Script: `analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R` (commit `eb2a782`).
- Input INVARIATI: Stadio 3 v7 (`analysis/p4-output/20260703T113045Z-stage3-v7-364547a7/`),
  master v3 (`analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`), H5
  (`analysis/input/human_gene_v2.5.h5`).
- Output NUOVO: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v8/<ts>-stage4-v8-<run_id>/`
  (NVMe `/` non basta; stesso disco di v6/v7).

**DRY_RUN già eseguito e PASS (2026-07-05):**
```
Layer A: 885 clusters (rem=8, mega=175, mega_aug=353, rem_group=349), 69238 sample, 0 errori
```
(rem_group=349 = ammessi dalla porta; ~70 saranno processati dopo il cutoff k_eff nel pool.)

**Full run detached (GATE UTENTE):** usare `setsid`, NON `run_in_background`
(memoria `feedback_setsid_for_long_detached_runs` — l'harness può uccidere i processi lunghi):
```bash
setsid Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R \
  > analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.log 2>&1 < /dev/null &
# verifica SID==PID; monitora con: pgrep -f rebuild-v8
```
- Wall atteso: la stima DRY_RUN (40h @164s/cluster) è **pessimistica** — v7 reale fu 668 min (~11h)
  per 433 cluster, e la cache counts riusata da v7 accorcia molti fetch. Stima realistica ~11–15h.
- Config: `dream_workers_cap=32`, MEGA-AUG bidirezionale, biotype protein_coding (= v7, uniformity).
- Alternativa DGX (2TB RAM, memoria `user_dgx_backup_2tb`) se serve, ma il laptop 256GB regge (= v7).

## Cosa attendersi nel run v8 (dai dati di validazione di questa sessione)

- **70 meta-analisi nominate `rem_group` processate** (k_eff≥3 studi distinti), es. SARS-CoV-2,
  enzalutamide, Breast/Prostatic Neoplasms, fulvestrant, tamoxifen, vemurafenib. Prima erano ~0.
- I 3 rami esistenti (`rem`/`mega`/`mega_aug`) INVARIATI (retrocompat byte-identica verificata).
- `non_processable` con reason `rem_group_insufficient_in_study_controls: k_eff=<n>` per i ~279
  rem_group che cadono (nessuna comparison stage2 con quel group come treated_group — ibrido
  documentato; l'augmentation cross-studio è un eventuale passo-3 futuro, NON in v8).
- Il collapse dei bracci intra-studio (inverse-variance FE) rende k_effective per gene = studi
  distinti (validato: SARS 10→5, enzalutamide 10→5) e gli I² onesti.

## Closeout post-run (dopo il fullrun v8)

1. **Verifica anti-stale** (sopra): `Methods` include `rem_group`, ~70 pooled, non_processable con
   reason rem_group.
2. **Re-gate**: n. cluster rem_group processati, distribuzione I²/τ²/n_sig, le bandiera presenti.
   Confronto vs v7 (che aveva 71/72 mega senza nome).
3. **Finding** `docs/findings/2026-07-05-stage4-rem-group-results.md`.
4. **ADR-0022** (portare a Accepted) — è la decisione architetturale del ramo rem_group.
5. **CLAUDE.md** header (stato fine sessione fullrun) + ledger `.superpowers/sdd/progress.md`.
6. **Memoria** `project_stage3_minestrone_rework` (aggiornare con l'esito v8).
7. Master invariato, no push (convenzione).

## Stato del codice (questa sessione — tutto committato sul branch)

Feature `rem_group` = commit `4f3a544`..`eb2a782` (14 commit codice + audit):
- Task 1-7 (config, porta+dedup, dispatch-builder group-aware, method_label, orchestrator, build merge).
- Fix regressione fixture legacy (`.col_or_default`), fix Important (guardia fail-loud merge).
- **Fix C1 CRITICAL** (final review Opus): il ramo era un no-op silenzioso in produzione
  (`direction_check=NA` sui group) → `isTRUE` coerce + difesa in profondità + test.
- **Fix I1** (decisione utente): gate `k_eff` su studi distinti + **collapse bracci intra-studio**
  inverse-variance FE (`.collapse_arms_by_study`, opzione C: sintetizza per studio SENZA unire i
  campioni). Limite noto documentato: correlazione da control condiviso non modellata (raffinamento
  Franchini futuro).
- Suite `stage4`: 780 PASS, 2 FAIL PRE-ESISTENTI indipendenti (`test-stage4-dashboard.R:33` quarto
  CLI mancante + `test-stage4-gene-axis.R:313` test-debt E2) — NON toccare, già rossi a `e8af92a`.

Spec: `docs/superpowers/specs/2026-07-05-stage4-rem-group-named-metaanalyses-design.md`.
Plan: `docs/superpowers/plans/2026-07-05-stage4-rem-group-named-metaanalyses-plan.md`.
Finding causa: `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`.
Audit validazione: `analysis/audit/2026-07-05-stage4-rem-group-smoke.*` (feeb5aa) +
`analysis/audit/2026-07-05-stage4-rem-group-collapse-validate.*` (fdbaaf1).

## Note operative

- Comando test su questa macchina: `Rscript -e ...` **SENZA** `--vanilla` (devtools nel renv cache;
  `--vanilla` non lo trova). Vale anche per gli script.
- Memorie: `feedback_setsid_for_long_detached_runs`, `feedback_bump_lookup_cache_version` (contesto
  cache), `feedback_validate_before_fullrun`, `user_dgx_backup_2tb`, `project_stage3_minestrone_rework`.
- Ledger completo di questa sessione: `.superpowers/sdd/progress.md` (sezione 2026-07-05).
- Handout successivo (dopo il fullrun): la pulizia-nomi Mistral
  (`2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`) resta il passo dopo.
