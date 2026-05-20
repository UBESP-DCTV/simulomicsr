# Stadio 4 — MEGA-AUG bidirezionale (design spec)

**Stato:** Draft 2026-05-20 — in attesa di review utente
**Branch target:** `p5-stadio4-de-perstudio` (corrente, HEAD `facfc0c`)
**Predecessore:** P5 Stadio 4 Task 1-19 (orchestrator MEGA + MEGA-AUG monodirezionale + safe helpers) + fix #1/#2 fullrun (`b5bd59f`, `699dc49`)
**Documento paper-grade di riferimento:** `docs/findings/2026-05-20-mega-aug-bidirectional-method.md` (Methods + Results del paper). **Questa spec implementa il "come"; il findings spiega il "perché".**
**ADR proposto:** **ADR-0016** — MEGA-AUG bidirezionale + anchor matching policy + indirect comparison declaration + shared baseline correction Franchini 2012. Da scrivere alla chiusura del fullrun di validazione.

---

## 1. Stato attuale e obiettivo

Stadio 4 oggi produce contrasti su tre path:

- **REM** (33 cluster strict): per-study limma-voom + `metafor::rma` REML.
- **MEGA** (312 cluster strict k≥5): dream `~ treatment + (1|study)` su raw counts cross-study, due bracci nello stesso cluster.
- **MEGA-AUG monodirezionale** (67 cluster pair k=2 + baseline group con stesso `control_anchor_key`): dream su pair augmentato del braccio control con baseline pool cross-studio.

Il MEGA-AUG monodirezionale (`R/stage4-mega-aug.R::.assemble_mega_aug_metadata`) cerca un baseline che matchi **esattamente** `anchor_key == pair_cluster$control_anchor_key` e lo aggiunge come `control` rows. Limiti attuali:

1. **Solo monodirezionale**: aumenta solo il braccio control, mai il treated. Se un pair k=2 ha treated baseline-like ma control rarissimo, non possiamo aumentare il control con baseline esterni — risultato: il pair resta sotto-pottenziato.
2. **Match anchor strict string equality**: `anchor_key` è un anchor canonico complesso (`cell_context | perturbation | dose | time | ...`). Match strict perde candidati che differiscono solo per dose o tempo.
3. **Nessun tracking di overlap studi**: se baseline e pair vengono da studi completamente disgiunti, l'orchestrator non lo segnala. Il random effect `study` di dream non risolve il confonding (vedi findings sez. 4 Nodo 2).
4. **Nessuna correzione shared baseline**: se lo stesso baseline pool è riusato in N pair distinti, il pooling REM downstream sottostima gli standard error (vedi findings sez. 4 Nodo 3).

**Obiettivo MEGA-AUG bidirezionale**: sanare i 4 limiti sopra trasformando i 4163 baseline pool single-arm di Layer A in un'infrastruttura completa di augmentation cross-studio, **dichiarata trasparentemente come indirect comparison** e **statisticamente onesta** sulla correlation tra contrasti riusati.

## 2. Goals & non-goals

### Goals

1. **Bidirezionalità**: il matching baseline ↔ pair lavora simmetrico su entrambi i bracci. Pair con anchor (treated=A, control=B): cerchiamo baseline pool con `anchor_key ≈ A` (per augmentare treated) **E** baseline pool con `anchor_key ≈ B` (per augmentare control).
2. **Anchor matching configurabile**: due policy `strict` e `relaxed` (default `relaxed`, sez. 4). La `relaxed` tollera differenze su `dose`, `time`, `exposure_route`; resta strict su `cell_context`, `perturbation_category`, `tissue`, `disease_state`, `genetic_background`.
3. **Indirect comparison declaration**: ogni contrasto MEGA-AUG riceve metadata `comparison_kind ∈ {"direct_overlap", "indirect_partial", "indirect_disjoint"}` in funzione del numero di studi overlap tra baseline pool aumentato e pair native.
4. **Modalità studi disgiunti configurabile**: config `mega_aug$disjoint_policy ∈ {"permissive", "strict"}` (default `permissive` per il primo run di validazione). `strict` richiede ≥1 studio overlap, `permissive` ammette disjoint con flag.
5. **Shared baseline correction**: tracking del riuso del baseline pool, applicazione della correzione di covarianza Franchini 2012 nel pooling REM `metafor::rma.mv` quando `baseline_reuse_count ≥ 2`.
6. **Backward compatibility**: il MEGA-AUG monodirezionale esistente è un caso particolare (config legacy). Test esistenti devono continuare a passare con `mega_aug$direction = "control_only"`.
7. **Idempotenza + run_id deterministico**: byte-equal re-run guaranteed (richiesto pipeline Stadio 4).

### Non-goals

- **NON** modifichiamo il path REM o MEGA puro.
- **NON** implementiamo augmentation multi-arm (un pair con più di un treated arm condiviso). Future work, sez. 7 findings.
- **NON** modifichiamo Stadio 3 (anchor canonical resta v3, cluster registry read-only).
- **NON** implementiamo Bayesian hierarchical / power prior (Tseng 2020): la correzione Franchini 2012 è la baseline frequentista, sufficiente per il payload paper.

## 3. Anatomia del cambiamento

### File esistenti modificati

| File | Cambiamento |
|---|---|
| `R/stage4-mega-aug.R` | `.assemble_mega_aug_metadata()` generalizzata: parametro `direction ∈ {"control_only", "treated_only", "both"}` + arg `anchor_matcher` (chiusura prodotta da `make_anchor_matcher(policy)`). Output esteso con `comparison_kind`, `n_studies_overlap`, `n_studies_baseline_disjoint`, `baseline_pool_ids` (per shared-baseline tracking). |
| `R/stage4-orchestrator.R` | MEGA-AUG branch invoca `.assemble_mega_aug_metadata` due volte (control + treated) per ogni pair; chiama il nuovo `.classify_comparison_kind()`; rispetta `disjoint_policy` config; aggrega `baseline_pool_ids` per il `cluster_id` corrente nel cluster_pooled attr `baseline_pool_usage`. |
| `R/stage4-rem-pooling.R` | `.pool_rem_cluster()` riceve `baseline_pool_usage` e applica correzione Franchini 2012 quando un baseline è riusato ≥ 2 volte tra cluster pool. |
| `R/stage4-config.R` | `stage4_default_config()` aggiunge sezione `mega_aug` (vedi sez. 5). |
| `R/stage4-qc.R` | `qc_report` aggiunge sezione `mega_aug_diagnostics` con count per `comparison_kind`, distribution di `n_studies_overlap`, `baseline_pool_reuse_distribution`. |

### File nuovi

| File | Contenuto |
|---|---|
| `R/stage4-anchor-matching.R` | `parse_anchor_canonical(anchor_key) → tibble`, `make_anchor_matcher(policy) → function(a, b) → bool`, `match_anchor_strict()`, `match_anchor_relaxed()`. |
| `R/stage4-baseline-pool-pairing.R` | `find_baseline_for_pair(pair, group_clusters, matcher, direction) → list di candidate pool con score`; ranking se più di un candidato. |
| `R/stage4-franchini-correction.R` | `build_franchini_V_matrix(cluster_results, baseline_usage)` per `metafor::rma.mv`. |
| `tests/testthat/test-stage4-anchor-matching.R` | TDD su 20-30 candidati manuali (vedi findings 5.1). |
| `tests/testthat/test-stage4-mega-aug-bidirectional.R` | end-to-end coverage del nuovo flow. |
| `tests/testthat/test-stage4-franchini-correction.R` | unit test della matrice V e del comportamento `rma.mv` shared-baseline. |

## 4. Anchor matching: parsing + policy

L'anchor canonico v3 è una stringa `"<perturbation>|<dose>|<time>|<exposure_route>|<cell_context>|<tissue>|<disease_state>|<genetic_background>|<readout>|<replicate_phase>"` (separatore `|`, 10 campi, ordine fissato da Stadio 2 schema). Per il matching dobbiamo parsarla in struttura.

**`parse_anchor_canonical(anchor_key)`** → tibble 1-riga con 10 colonne, una per campo.

**Policy `strict`**: due anchor matchano sse tutti i 10 campi sono uguali (== string equality dopo parsing).

**Policy `relaxed`** (default proposto):

| Campo | Match policy |
|---|---|
| `perturbation_category` | **strict** |
| `cell_context` | **strict** |
| `tissue` | **strict** |
| `disease_state` | **strict** |
| `genetic_background` | **strict** |
| `dose` | **tolerated** (qualunque valore matcha, incluso `na/none/unknown`) |
| `time` | **tolerated** |
| `exposure_route` | **tolerated** |
| `readout` | **strict** |
| `replicate_phase` | **strict** |

Razionale dettagliato nel findings sez. 4 Nodo 1. La policy esatta su quali campi sono `tolerated` è negoziabile via config (`mega_aug$relaxed_fields`).

**`make_anchor_matcher(policy)`** ritorna una chiusura `function(a, b) → bool` che incapsula la regola scelta. Usata da `find_baseline_for_pair` nel ranking.

## 5. Configurazione

Aggiunta a `stage4_default_config()`:

```r
mega_aug = list(
  direction         = "both",                    # "control_only" | "treated_only" | "both"
  anchor_policy     = "relaxed",                 # "strict" | "relaxed"
  relaxed_fields    = c("dose", "time", "exposure_route"),
  disjoint_policy   = "permissive",              # "permissive" | "strict"
                                                  # "permissive" ammette n_studies_overlap == 0;
                                                  # "strict" scarta il candidato e logga.
  min_baseline_studies = 2L,                     # baseline pool con < N studi e' scartato (rumore)
  max_baseline_pool_reuse = NA_integer_,         # NA = nessun cap; integer = max riusi per pool
  franchini_correction  = TRUE,                  # attiva correzione shared-baseline nel REM pooling
  legacy_monodirectional = FALSE                 # se TRUE, comporta come pre-bidirezionale
)
```

**Interazione con `mega_aug_n_min_per_level`** (issue #3 handoff, da aggiungere insieme): config `compute$mega_n_min_per_level = 2L` resta separata (governa il MEGA pure path, non il MEGA-AUG).

## 6. Classification `comparison_kind`

Calcolato in `.classify_comparison_kind(pair_studies, baseline_studies)`:

| Casistica | Valore `comparison_kind` |
|---|---|
| Almeno 1 studio in entrambi i set | `direct_overlap` |
| Nessun overlap MA `|pair_studies| ≥ 2` e `|baseline_studies| ≥ 3` | `indirect_partial` (informativo: entrambi sono multi-study, anche se disjoint) |
| Nessun overlap E uno dei due ha 1 solo studio | `indirect_disjoint` (più rischioso) |

Tutti i contrasti `indirect_*` sono dichiarati esplicitamente in `cluster_pooled.parquet` con i tre count (`n_studies_overlap`, `n_studies_pair_unique`, `n_studies_baseline_unique`) per consentire downstream filtering paper-grade.

## 7. Shared baseline correction (Franchini 2012)

Quando ≥ 2 cluster MEGA-AUG aumentati condividono **lo stesso baseline pool** (medesimo `cluster_id` group), i loro standard error nel pooling REM sono correlati.

**Tracking**: `attr(cluster_pooled, "baseline_pool_usage")` = list `pool_id → vector di cluster_id che lo usano`.

**Pooling**: per ogni gene, `.pool_rem_cluster()` riceve `baseline_pool_usage` e:

- Se nessun pool è riusato: standard REM `metafor::rma(yi, vi, method = "REML")`.
- Se ≥ 1 pool riusato: costruisce matrice V di covarianza esplicita à la Franchini 2012, chiama `metafor::rma.mv(yi, V, random = ~ 1 | cluster_id, method = "REML")`.

**Formula V (semplificata)**: per coppia di contrasti $i$, $j$ che condividono il braccio baseline pool $B$:
$$V_{ij} = \frac{\sigma^2_B}{n_B}$$
dove $\sigma^2_B$ è la varianza intra-baseline-pool e $n_B$ il numero di sample del pool. La derivazione completa è in `R/stage4-franchini-correction.R::.build_franchini_V_matrix()`.

**Toggle**: `mega_aug$franchini_correction = FALSE` disabilita per ablation study (Results sez. 6.4 findings).

## 8. Data flow

```
Stage3 clusters ──┬──> pair clusters (mode=pair, 345)
                  └──> group baseline pools (mode=group, 4163)
                                │
                                ▼
       ┌─────────────────────────────────────────┐
       │ MEGA-AUG branch orchestrator            │
       │                                          │
       │ for each pair cluster:                   │
       │   matcher <- make_anchor_matcher(policy) │
       │   if direction in {control, both}:       │
       │     control_pool <-                      │
       │       find_baseline_for_pair(            │
       │         pair, groups,                    │
       │         matcher,                         │
       │         arm="control")                   │
       │   if direction in {treated, both}:       │
       │     treated_pool <-                      │
       │       find_baseline_for_pair(            │
       │         pair, groups,                    │
       │         matcher,                         │
       │         arm="treated")                   │
       │                                          │
       │   metadata <-                            │
       │     .assemble_mega_aug_metadata_bidir(   │
       │       pair, control_pool, treated_pool)  │
       │                                          │
       │   kind <- .classify_comparison_kind(...) │
       │   if disjoint_policy=="strict" &         │
       │       kind=="indirect_disjoint": SKIP    │
       │                                          │
       │   dream_result <- .run_dream_mega_aug(   │
       │     metadata, counts)                    │
       │                                          │
       │   record baseline_pool_usage             │
       │                                          │
       └──────────────────────┬──────────────────┘
                              │
                              ▼
       ┌─────────────────────────────────────────┐
       │ REM pooling con Franchini 2012          │
       │                                          │
       │ for each gene:                           │
       │   V <- .build_franchini_V_matrix(...)    │
       │   if V is diagonal:                      │
       │     rma(yi, vi, REML)                    │
       │   else:                                  │
       │     rma.mv(yi, V, ~1|cluster_id, REML)   │
       └─────────────────────────────────────────┘
```

## 9. Test plan

Gancio diretto al findings paper-grade sez. 5:

- **Test 5.1 (anchor matching, hand-curated)**: `tests/testthat/test-stage4-anchor-matching.R`. 20-30 candidati validati a mano in un CSV gold (`inst/extdata/p5-mega-aug-anchor-matching-gold.csv`, da creare). Strict + relaxed policy testate, confusion matrix attesa nel Results 6.1 findings.
- **Test 5.2 (batch confounding simulation)**: `analysis/p5-stage4-mega-aug-confounding-sim.R`. 5-10 GSE noti, split artificiale, degradation curve in funzione di `n_studies_overlap`. Output in `analysis/p4-output/<timestamp>-mega-aug-sim/` + Results 6.2 findings.
- **Test 5.3 (strict-vs-relaxed sensitivity)**: lanciato come secondary run del fullrun Layer A. Diff in numero contrasti + concordanza top-100 logFC tra `anchor_policy = "strict"` e `"relaxed"`. Results 6.3 findings.
- **Test 5.4 (augmentation gain over pair-only)**: A/B run con `direction = "control_only"` (= legacy monodirectional) vs `direction = "both"`. Results 6.4 findings.
- **Test 5.5 (RummaGEO benchmark)**: deliverable Stage 4 separato, vedi ADR-0006.

## 10. Migration / backward compat

- L'attuale `.assemble_mega_aug_metadata` resta callable via `config$mega_aug$legacy_monodirectional = TRUE`. Tutti i 145 test Stadio 4 esistenti devono passare in legacy mode.
- Lo schema di `cluster_pooled` è esteso con 5 nuove colonne (`comparison_kind`, `n_studies_overlap`, `n_studies_pair_unique`, `n_studies_baseline_unique`, `baseline_pool_reuse_count`). Schema version `stage4_algorithm = "v2"` (era `"v1"`).
- L'esistente `qc_report$pooling_warnings` (fix #2) resta invariato. Nuova sezione `qc_report$mega_aug_diagnostics`.

## 11. Open questions

- **Q1**: ranking dei candidate baseline pool quando ce ne sono > 1 per uno stesso braccio. Strategia v0.1: prendi il pool con più studi (`n_studies` max), tiebreaker su `n_total` max. Alternative: prendere tutti e poolare gerarchicamente (più complesso, future work).
- **Q2**: `disjoint_policy = "permissive"` default vs `"strict"` default. Decisione: lanciamo `permissive` come prima validation, e in 5.2 simulation vediamo se la degradation curve giustifica un downgrade a `strict`.
- **Q3**: `max_baseline_pool_reuse` cap. Default `NA` (nessun cap) — la correzione Franchini lo gestisce statisticamente. Da rivedere se i Results 6.4 mostrano patologie.
- **Q4**: `relaxed_fields` set definitivo. Default proposto `c("dose", "time", "exposure_route")` — ma si potrebbe tollerare anche `replicate_phase` per cluster proliferating-vs-quiescent. Da decidere con test 5.1.

## 12. Sequenza implementativa proposta

In ordine, con TDD bite-sized:

1. **T1** — `R/stage4-anchor-matching.R` + `tests/testthat/test-stage4-anchor-matching.R`. Mini-gold 20-30 candidati hand-curated. Bloccante per il resto.
2. **T2** — `R/stage4-baseline-pool-pairing.R` + test. Selection + ranking.
3. **T3** — `.assemble_mega_aug_metadata_bidir()` in `R/stage4-mega-aug.R` (parametrized) + test backward-compat.
4. **T4** — `.classify_comparison_kind()` + test edge case.
5. **T5** — orchestrator integration (`R/stage4-orchestrator.R`) + smoke 1 cluster.
6. **T6** — `R/stage4-franchini-correction.R` + test analitici (matrice V su 2-3 mini-case).
7. **T7** — `.pool_rem_cluster()` con `rma.mv` fallback.
8. **T8** — `stage4_default_config()` additions.
9. **T9** — `qc_report` mega_aug_diagnostics + dashboard pane.
10. **T10** — simulation batch confounding (`analysis/p5-stage4-mega-aug-confounding-sim.R`).
11. **T11** — smoke 5-pick real-data postfix.
12. **T12** — fullrun Layer A bidirezionale (overnight).
13. **T13** — Results sezioni in findings + ADR-0016.
14. **T14** — ff-merge + tag `p5-stadio4-complete`.

Stima wall: ~5-7 giorni dev + 1-2 giorni test/fullrun.

## 13. Riferimenti

- Findings paper-grade: `docs/findings/2026-05-20-mega-aug-bidirectional-method.md`.
- Spec Stadio 4 originale: `docs/superpowers/specs/2026-05-19-p5-stadio4-de-perstudio-design.md`.
- Handoff fullrun 2026-05-20: `docs/superpowers/specs/2026-05-20-p5-stadio4-fullrun-handoff.md`.
- ADR-0015 (dream parallel default): `docs/decisions/0015-stage4-dream-default-parallel.md`.
- ADR-0006 (positioning vs RummaGEO): `docs/decisions/0006-stato-arte-vs-simulomicsr.md`.
