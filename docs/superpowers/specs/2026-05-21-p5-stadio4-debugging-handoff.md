# P5 Stadio 4 — Handoff debugging (2026-05-21)

> **Sessione dedicata: SOLO debugging.** NON lanciare il fullrun Layer A
> finché entrambi i problemi aperti (sez. 3) non sono isolati con test
> minimali riproducibili e fixati. Invocare la skill
> `superpowers:systematic-debugging`.

## 1. Stato branch

- Branch: `p5-stadio4-de-perstudio`, HEAD `f3d194c`.
- Suite Stadio 4: **288 PASS / 0 FAIL / 1 SKIP**.
- Task 21 (MEGA-AUG bidirezionale) implementato T1-T8 + T11 + hotfix #1/#2.
- Pacchetto: `devtools::load_all()` per la sessione.

### Commit Task 21 (oltre `facfc0c`)

| Commit | Contenuto |
|---|---|
| `0f6fdae` | doc findings paper-grade + spec implementativa |
| `d629e02` | doc fix: anchor v3 = 13 segmenti tier-based |
| `2fa53e6` | T1 anchor matching + parsing |
| `97ed61e` | mini-gold 29 candidati hand-curated |
| `579dcf6` | T2 find_baseline_for_pair |
| `a9d3de5` | T3+T4 classify_comparison_kind + assemble bidir |
| `340bbed` | T5+T8 orchestrator dispatch + config |
| `4469f76` | T6 Franchini V matrix building block |
| `1cb25d1` | Test 5.1 gold annotation + confusion matrix |
| `92d0792` | coverage analysis (92% pair augmentation effettiva) |
| `1970ee6` | T12 prep: fullrun script abilita bidir |
| `081fde6` | hotfix #1: pre-filter stage2_master vs H5 |
| `f3d194c` | hotfix #2: tryCatch wrap in .pool_all_clusters |

## 2. I 4 tentativi di fullrun Layer A (tutti falliti)

| # | Wall | Exit | Causa | Fix applicato | Status fix |
|---|---|---|---|---|---|
| 1 | 43 min | 1 | `duplicate row.names GSM4556584` path MEGA-AUG | (pre-Task21, commit b5bd59f) | superato |
| 2 | 29 min | 1 | stesso, path MEGA | (pre-Task21, commit 699dc49) | superato |
| 3-bis #1 | 1h 11m | 1 | `Sample IDs not found in H5: GSM6401594` | hotfix #1 `081fde6`: pre-filter stage2_master vs H5 sample axis (727 sample 0.089% droppati) | **verificato OK** — run successivo passa quel punto |
| 3-bis #2 | 6h 49m | 1 | `duplicate row.names` in path non coperto | hotfix #2 `f3d194c`: tryCatch wrap → cluster failed skippato in `non_processable` invece di crash totale | **parziale** — vedi problema A |
| 3-bis #3 | 39 min | 137 (OOM) | orphan workers del run #2 non puliti + 100 nuovi worker → >251 GB | cleanup `pkill -9 -x R` pre-launch | superato (procedurale) |
| 3-bis #4 | 8h 6m | 137 (OOM) | un singolo cluster MEGA grande × 100 dream worker COW → 14→251 GB in ~8 min | **NESSUNO** — vedi problema B |

Numerazione: i primi 2 sono pre-Task21 (vecchio handoff). I "3-bis" sono i 4 tentativi della sessione Task 21 (2026-05-20/21).

## 3. Problemi APERTI da debuggare sistematicamente

### Problema A — `duplicate row.names` nei cluster MEGA-AUG bidir

**Sintomo.** Fullrun #4 ha skippato 3 cluster con
`pool_runtime_error: duplicate 'row.names' are not allowed`:
- `pair_L0_e45151a4` (method=mega_aug)
- `pair_L1_37c75531` (method=mega_aug)
- `pair_L2_a28b250f` (method=mega_aug)

Il tryCatch wrap (hotfix #2) li skippa → non crashano il fullrun, ma è un
**bug reale** che riduce la copertura Layer A. Tutti e 3 sono `mega_aug`
→ il path bidir produce metadata o count matrix con row.names duplicati
in un edge case non coperto.

**Cosa è già escluso.** I fix #1 (`b5bd59f` dedup pair samples) e #2
(`699dc49` MEGA path dedup) coprivano i path legacy. Il bidir
`.assemble_mega_aug_metadata_bidir` (commit `a9d3de5`) fa già dedup
`!duplicated()` su pair_rows e baseline_rows. Quindi il duplicato emerge
ALTROVE: probabilmente nel concat counts cross-study dell'orchestrator
(`R/stage4-orchestrator.R` MEGA-AUG branch ~righe 280-320,
`do.call(cbind, counts_list)` + `match(colnames(counts), ...)`), oppure
nel fetch_fn quando due studi del baseline pool contengono lo stesso GSM.

**Debug sistematico (riproducibile, NON serve fullrun):**
1. Smoke targeted: costruire un mini-run Stadio 4 con SOLO i 3 cluster
   noti (`pair_L0_e45151a4`, `pair_L1_37c75531`, `pair_L2_a28b250f`) +
   i loro baseline pool, bidir attivo. Riproduce il crash in pochi minuti.
2. `options(error = recover)` o `traceback()` per il punto esatto.
3. Ipotesi primaria: `metadata` o `counts` passati a `.run_dream_mega`
   hanno `sample_id` ripetuto perché lo stesso GSM appare nel pair E nel
   baseline pool di un ARM diverso (es. GSM in treated-baseline e in
   control simultaneamente), oppure cross-study stesso GSM.
4. Fix mirato nella dedup di `.assemble_mega_aug_metadata_bidir` o nel
   concat counts orchestrator.

### Problema B — OOM su cluster MEGA grande (fullrun #4)

**Sintomo.** Fullrun #4 OOM (exit 137) dopo 8h 6m. Tra il check delle
15:17 (14 GB used) e la morte alle 15:24 (~8 min) la memoria è salita da
14 a 251 GB. Un singolo cluster MEGA grande processato con
`dream_workers = 100` (BiocParallel multicore fork) ha sfondato i 251 GB
del laptop: ogni worker ha la sua copia COW delle strutture, e su un
cluster con migliaia di sample il picco × 100 esplode.

**Dati noti.**
- `dream_workers_cap = 100` (ADR-0015, `stage4_default_config()$compute`).
- Coverage analysis (`92d0792`): alcuni pair hanno baseline pool enormi
  (es. `pair_L3_0a500a99` = 1443 extra sample da 229 studi). I cluster
  MEGA `mode=group` possono avere `n_total` fino a 7191 (vedi
  `clusters.rds`, `summary(group_la$n_treated)` max 7191).
- Il fullrun #4 NON ha progress logging per cluster → non si sa QUALE
  cluster ha ucciso. Wall ~8h → probabilmente uno dei cluster MEGA
  group più grandi.

**Debug sistematico:**
1. Identificare i cluster MEGA candidati killer: query su `clusters.rds`
   per i `mode=group` Layer A con `n_total` massimo (top 10-20).
2. Stimare il footprint memoria di `dream` su un cluster da N sample ×
   ~25k geni × W worker. Misurare su 1-2 cluster grandi isolati con
   `dream_workers` variabile (8, 32, 100) → curva memoria.
3. Decidere la strategia worker cap:
   - statico ridotto (`dream_workers_cap` 100 → 24-32), oppure
   - dinamico memory-aware (cap ∝ 1/n_sample del cluster), oppure
   - switch DGX (2 TB RAM, vedi memoria `user_dgx_backup_2tb`).
4. Aggiungere progress logging per-cluster al fullrun script
   (`cli_alert` con cluster_id + wall + RSS) — indispensabile per ogni
   futuro fullrun.

## 4. Decisione infrastruttura (input utente atteso)

L'utente ha la **DGX UniPD: 2 TB RAM + 100 core** disponibile come
alternativa al laptop (251 GB). Opzioni discusse, non ancora decise:
- A: switch DGX (8x headroom, risolve B definitivamente; richiede H5
  47 GB + Stage 2/3 data + R env sulla DGX).
- B: riduci `dream_workers_cap` locale a 24-32.
- C: worker cap dinamico memory-aware.
- D: DGX + cap dinamico.

Da decidere a inizio sessione debugging, dopo il punto 3.B.1-2 (curva
memoria) che quantifica quanto serve davvero.

## 5. File di stato (filesystem, gitignored)

Archivi dei 4 crash conservati per post-mortem:
- `analysis/p5-stage4-layer-a-fullrun.log.previous-failed-2026-05-20`
- `analysis/p5-stage4-layer-a-fullrun.{log,state}.crash-h5-missing-sample-20260520T231341Z`
- `analysis/p5-stage4-layer-a-fullrun.{log,state}.crash-duprownames-20260521T062748Z`
- `analysis/p5-stage4-layer-a-fullrun.{log,state}.oom-orphan-workers-20260521T071848Z`
- `analysis/p5-stage4-layer-a-fullrun.{log,state}.oom-bigcluster-<ts>`

Nessun processo R attivo (verificato post-cleanup). Nessun output
`cluster_pooled` prodotto (build_stage4_results scrive solo a
completamento — i 4 run sono tutti morti prima).

## 6. Tasks nuova sessione (ordine)

1. Invocare `superpowers:systematic-debugging`.
2. **Problema A**: smoke targeted 3-cluster → root cause → fix mirato →
   test di regressione.
3. **Problema B**: query cluster size + curva memoria dream → strategia
   worker cap → progress logging nel fullrun script.
4. Decidere infrastruttura (locale cap-ridotto vs DGX) con l'utente.
5. Scaled validation (smoke 5-pick + magari 20-pick) con ENTRAMBI i fix.
6. Solo allora: ri-lanciare il fullrun Layer A.
7. Task 20 chiusura: ADR-0015/0016 + ff-merge + tag `p5-stadio4-complete`.

## 7. Cosa NON rifare

- NON lanciare il fullrun Layer A prima del punto 5.
- NON applicare fix reattivi + ri-lancio fullrun (anti-pattern
  whack-a-mole, vedi memoria `feedback_no_whackamole_systematic_debug`).
- NON committare `--no-verify`. Pulire `renv/settings.json` +
  `analysis/_targets/` prima dei commit.
