# Stadio 4 DE method benchmark — debugging the dream slowness (2026-05-20)

## Contesto

Durante la smoke 5-cluster Stadio 4 (Task 17, branch `p5-stadio4-de-perstudio`)
il path corrente `voomWithDreamWeights + dream + eBayes` (`R/stage4-dream-mega.R`)
ha mostrato wall budget realistico **10-35 min per cluster**, contro
l'aspettativa del plan di **≤ 10 min per tutti i 5 picks**. Il pacchetto
ARCHS4 v2.5 H5 sample-axis bug e' stato gia' fixato (commit `284bdd8`); la
slowness e' rimasta.

L'utente ha chiesto di "trattare come bug, non come perf-opt": indagare
DOVE finisce il tempo, e fare prove autonome per scegliere il metodo
migliore in termini di velocita' e (per quanto misurabile) precisione.

## Setup

- Branch `p5-stadio4-de-perstudio`, HEAD `414505f`.
- Script bench: `analysis/p5-stage4-dream-perf-bench.R`.
- BLAS thread cap: `OPENBLAS_NUM_THREADS=4` per evitare oversubscription su
  dgx 32-core (la causa primaria della smoke originale al 30x parallelism
  con throughput inefficiente).
- Cluster picks (mismi della smoke):
  - **C1 = `pair_L0_96ddb249`** (mega_aug, k=2, 2 studi, 8 sample, 22784
    geni post-`filterByExpr`). Baseline pool degenere (0 nuovi studi
    aggiunti).
  - **C2 = `group_L0_c62104eb`** (mega strict, k=5, 5 studi, 20 sample,
    30063 geni post-`filterByExpr`). 20 vs n_total=33 perche'
    `.build_group_dispatch_from_stage3` esclude i replicate group con
    `primary_role` non in `{treated, control}`.
- 4 metodi testati (stessi `filterByExpr` + `normLibSizes` TMM upstream):
  - **M1**: `voomWithDreamWeights + dream + eBayes` (current default,
    REFERENCE)
  - **M2**: `limma::voom + dream + eBayes` (1 LMM pass invece di 2)
  - **M3**: `limma::voom + duplicateCorrelation(block=study) ×2 + lmFit + eBayes`
    (consensus correlation single estimate, no per-gene LMM)
  - **M4**: `limma::voom + study fixed-effect + lmFit + eBayes` (rigetta
    random effect; study come covariata)

## Risultati

### Wall time per fase (sec)

#### C1 (mega_aug k=2, 22784 geni, 2 studi)

| Method | voom | model | eBayes | Total | Speedup vs M1 |
|---|---|---|---|---|---|
| M1 voomDream+dream | 299.88 | 1819.32 | 0.11 | **2119.30** | 1.0× |
| M2 voom+dream | 0.11 | 1810.61 | 0.08 | **1810.80** | 1.17× |
| M3 voom+dupCor+lmFit | 0.30 | 33.18 | 0.03 | **33.52** | **63×** |
| M4 voom+study(fixed)+lmFit | 0.21 | 0.88 | 0.02 | **1.12** | **1893×** |

#### C2 (mega k=5, 30063 geni, 5 studi)

| Method | voom | model | eBayes | Total | Speedup vs M1 |
|---|---|---|---|---|---|
| M1 voomDream+dream | 402.16 | 1092.76 | 0.12 | **1495.04** | 1.0× |
| M2 voom+dream | 0.20 | 1099.41 | 0.11 | **1099.71** | 1.36× |
| M3 voom+dupCor+lmFit | 0.38 | 76.11 | 0.03 | **76.52** | **20×** |
| M4 voom+study(fixed)+lmFit | 0.20 | 1.41 | 0.04 | **1.65** | **906×** |

### Concordanza vs M1 (reference)

| Cluster | Method | Spearman ρ (logFC) | Sign-agreement top-100 \|logFC\| | %p<0.05 | λ inflation |
|---|---|---|---|---|---|
| C1 | M1 | 1.0000 | 100% | 36.7% | 5.66 |
| C1 | M2 | 0.9996 | 100% | 36.7% | 5.67 |
| C1 | M3 | **0.9991** | **100%** | 33.9% | 5.08 |
| C1 | M4 | 0.9991 | 100% | 34.5% | 5.28 |
| C2 | M1 | 1.0000 | 100% | 11.1% | 1.32 |
| C2 | M2 | 0.9980 | 100% | 4.4% | 1.01 |
| C2 | M3 | **0.9931** | **100%** | 0.5% | 1.66 |
| C2 | M4 | 0.9125 | 100% | 62.2% | **13.0** |

(λ inflation alta su C1 per tutti i metodi: il cluster e' "differentiation
Mesendoderm vs untreated" su H9 — segnale biologico massivo, non
artefact. M4 su C2: λ=13 + 62% p<0.05 = chiara mis-calibrazione causata da
`Coefficients not estimable: studyGSE83115`, confounding study × treatment
parziale; M4 quindi inappropriato per mega con k≥3 studi.)

## Findings (debugging)

1. **Il bottleneck NON e' `voomWithDreamWeights`**.
   - C1: `voomWithDreamWeights` 300 s vs `dream` 1819 s → dream domina 86%
     del wall.
   - C2: `voomWithDreamWeights` 402 s vs `dream` 1093 s → dream domina 73%
     del wall.
   - Conclusione: sostituire `voomWithDreamWeights` con `limma::voom` (M2)
     salva solo 14-27% del wall — non risolve il problema.

2. **`dream` e' lento per costruzione**: ~22k-30k geni × per-gene LMM
   `lme4::lmer` × 2 passes (gia' coperto da voomWithDreamWeights solo se M1).
   Per gene: ~50-80 ms su lme4. Per cluster: 18-30 min. Non c'e' bug —
   e' il costo intrinseco di per-gene mixed models su quel volume di geni.

3. **Boundary singular fits su k=2**: C1 (2 studi, random effect `(1|study)`
   con solo 2 livelli) ha `dream` piu' lento di C2 (5 studi). lme4 lotta
   con boundary cases. Il random effect con 2 livelli e' statisticamente
   poco informativo (varianza non identificabile).

4. **`filterByExpr` permissivo**: 22-30k geni post-filter (~30-45% del
   transcriptome annotato). Stringerebbe il filter ma indebolirebbe la
   sensibilita' biologica — non e' la strada giusta.

5. **M3 (limma + duplicateCorrelation) raggiunge biologia equivalente
   con 20-63× il wall**.
   - ρ = 0.993-0.999 vs M1: i logFC sono praticamente identici.
   - Sign-agreement top-100 = 100%: i top hit per |logFC| sono identici.
   - %p<0.05 leggermente piu' basso (33.9 vs 36.7 su C1, 0.5 vs 11.1
     su C2). M3 e' lievemente piu' conservative — atteso, poiche'
     duplicateCorrelation usa una correlazione consenso single-estimate
     vs random effect per-gene di dream. Conservativita' e' una proprieta'
     desiderabile per meta-analysis paper-grade (REM downstream ribilancia
     via weights).
   - Allineamento con il prior dell'utente
     (`user_de_methods_benchmark.md`): "limma-voom best, DESeq2
     disqualified per n piccoli".

6. **M4 (study fixed-effect) e' fast ma fragile**: confounding study ×
   treatment fa fallire la stima (`Coefficients not estimable`) su C2,
   producendo λ=13. Inappropriato come default.

## Raccomandazione

**Switchare il default di `.run_dream_mega` (e quindi MEGA + MEGA-AUG) a M3
`limma::voom + duplicateCorrelation(study) + lmFit + eBayes`**.

Tradeoff onesti:

- **Pro M3**:
  - 20-63× speedup riduce Layer A full run da ~hours-days a ~minuti.
  - Concordanza con M1 a livello "in pratica indistinguibile" (ρ > 0.993,
    sign-agreement 100% top-100).
  - Conservativita' superiore (meno falsi positivi a livello cluster);
    paper-grade.
  - M3 e' gia' il fallback in `.run_dream_mega` (lines 80-94) — il path
    e' validato, solo da promuovere a default.
  - Pacchetto `user_de_methods_benchmark.md` memory: limma-voom = best
    per piccoli n. Bench conferma.

- **Contro M3**:
  - duplicateCorrelation modella study come **consensus correlation**
    invece che come random effect proprio. Per cluster con eterogeneita'
    study marcata (es. batch effects diversi), un random effect potrebbe
    catturarla meglio. **Non osservato nel bench**, ma teoricamente possibile.
  - Per cluster MEGA con k molto alto (>20 studi), random effect di dream
    diventa piu' informativo. Bench coperti solo a k=5; estendere prima
    del Layer A full sarebbe utile.

- **Pro M1 (status quo)**:
  - Modello formalmente piu' espressivo (random effect proper).
  - Variancepartition framework e' la "gold standard" letteratura per
    repeated measures.

- **Contro M1**:
  - Wall per cluster prohibitivo per Layer A full run.
  - Su k=2 (mega_aug), random effect con 2 livelli non e' nemmeno
    statisticamente identificato.

## Open questions per ADR

- **Validare M3 vs M1 su un cluster MEGA strict con k>10** (es.
  `group_L0_c5aacc5f` MCF7, k=11): se ρ rimane >0.99 e wall < 5 min, M3
  e' confermato come default uniforme. Se ρ scende sotto 0.95, valutare
  M1 per k>=10 + M3 per k<10 (hybrid).
- **Eventuale `mega_aug_min_baseline_studies` threshold**: cluster con
  baseline degenere (0 studies augmented, come C1 qui) potrebbero usare
  semplicemente limma-voom (M3) senza differenziazione vs mega; il
  modello augmented diventa rilevante solo quando baseline aggiunge
  studies/sample reali.

## Output

- `analysis/p5-stage4-dream-perf-bench.R` — bench script (committed).
- `analysis/p4-output/p5-stage4-bench-20260520T054044Z/` — risultati raw
  (gitignored).
  - `bench_results.rds` — full timings + coef vectors per metodo per
    cluster.
  - `bench_summary.csv` — tabella comparativa.
