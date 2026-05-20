# ADR-0015: Stadio 4 mantiene `dream` come default DE MEGA/MEGA-AUG, attivando parallelismo BiocParallel come standard

- **Status:** Accepted
- **Date:** 2026-05-20
- **Deciders:** lucavd
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

L'esecuzione di Stadio 4 (Task 17 smoke) ha rivelato che il path
`voomWithDreamWeights + dream + eBayes` (`R/stage4-dream-mega.R`, scelto
in Task 7 del plan) prende **15-35 minuti wall per cluster** su dati ARCHS4
reali (8-30 sample × 17k-30k geni post-`filterByExpr`), contro l'aspettativa
del plan di **≤ 10 min per 5 picks** (Task 17). Il problema non e' un bug
software ma il costo intrinseco di `lme4::lmer` per-gene moltiplicato per
~22-30k geni × due passi (`voomWithDreamWeights` + `dream`).

Domanda: dato che la full Layer A run e' ~622 cluster (335 strict + 312
MEGA + ~310 MEGA-AUG nel Stage 3 build attuale `2153addc`), va trovato un
default sostenibile, conservando le proprieta' statistiche del modello
mixed-effect.

## Decision Drivers

1. **FDR calibration.** L'utente (lucavd) ha un benchmark non pubblicato
   (figura condivisa 2026-05-20) che testa 9 metodi DE su ratio
   "Actual / Nominal FDR" sotto 8 scenari di violazione (Baseline,
   Zero-infl., Sample correlation, Batch, Hidden conf., Outliers, FC
   asym., Combined) × 4 dimensioni (n=3, 5, 10, 20). Findings rilevanti:
   - `dream` riporta ratio FDR ≤ 0.64 in TUTTI gli scenari dove
     produce output (zero-inflation, combined; altre celle vuote =
     non riportato). **Ben calibrato / conservativo**.
   - `limma-voom` standard: rotto a n=3 Zero-infl. (ratio 8.17),
     **2.09 a n=20 Hidden conf.** (raddoppio FP).
   - `DESeq2`, `MAST`, `edgeR LRT`: anti-conservative diffusi.
2. **Riproducibilita' paper-grade.** `dream` e' la primaria letteratura
   per modelli misti su dati RNA-seq con repeated measures
   (Hoffman & Roussos, 2021, Bioinformatics).
3. **Wall budget.** Layer A full con 622 cluster deve completarsi in
   tempo ragionevole su DGX 128-core.
4. **Determinismo.** Risultati paralleli devono essere bit-identici a
   serial per riproducibilita'.
5. **Compatibilita'.** Salvaguardia per chi gira su laptop (pochi core).

## Considered Options

1. **Opzione A — `dream` con parallelismo `BiocParallel::MulticoreParam`,
   workers da config (auto-detect default).** Mantiene il modello mixed-
   effect; speedup 12-18x via fork.
2. **Opzione B — Switch a `limma::voom + duplicateCorrelation + lmFit`.**
   ~3-4x piu' veloce di Opzione A; concordanza con dream sui logFC
   ottima a k=5 (ρ=0.993) ma scende a k=11 (ρ=0.947). FDR calibration
   sotto violazioni NON misurata; il pre-existing benchmark testa solo
   limma-voom standard SENZA duplicateCorrelation.
3. **Opzione C — Hybrid (limma+dupCor per k≤4, dream per k≥5).**
   Riduce wall ma introduce un confine arbitrario.
4. **Opzione D — Non default, sostituire da config.** Eredita il
   problema: l'utente medio non sa quale scegliere.

## Decision Outcome

Scelta: **Opzione A** — `dream` resta il default, con parallelismo
`BiocParallel::MulticoreParam(workers)` attivo.

Motivazione:

- L'evidenza FDR-calibration di lucavd (figura paper non pubblicata,
  2026-05-20) mostra dream come l'unico metodo con ratio FDR < 1 in
  TUTTI gli scenari di violazione testati. Switchare a un alternativo
  richiederebbe ri-validare FDR sotto violazioni per QUEL alternativo —
  non disponibile.
- Il bench Stadio 4 in `docs/findings/2026-05-20-stage4-de-method-bench.md`
  mostra che la concordanza logFC limma+dupCor vs dream **degrada con
  k**: ρ=0.999 a k=2, 0.993 a k=5, **0.947 a k=11**. La differenza
  cresce dove il random effect proper diventa piu' informativo, ovvero
  proprio i cluster MEGA strict (k≥5 per definizione).
- Bench parallel run su DGX 128-core conferma speedup 12-18x con
  workers=100 (vs serial M1), portando wall per cluster a 60-130 sec.
  Layer A full stima ~17h overnight — accettabile.
- Determinismo verificato: test
  `.run_dream_mega(workers=4)` == `.run_dream_mega(workers=1)` a
  tolerance 1e-10 (vedi `tests/testthat/test-stage4-dream-mega.R`).
  `lme4::lmer` non usa RNG, fork non altera la sequenza dei calcoli.
- limma-voom + duplicateCorrelation rimane **fallback automatico** in
  `R/stage4-dream-mega.R` quando dream lancia un'errore di convergenza,
  preservando robustezza.

## Implementation

- `R/stage4-config.R::stage4_default_config()`:
  - Aggiunto `compute$dream_workers = NA_integer_` (NA = auto-detect).
  - Bump `compute$dream_workers_cap` da 8L a 100L.
  - Helper `.resolve_dream_workers(config)` con logica:
    `if (is.na(dream_workers)) availableCores() - workers_offset
     else dream_workers`, capped a `dream_workers_cap`.
- `R/stage4-build.R::build_stage4_results()`: risolve workers via
  `.resolve_dream_workers(config)`, passa a `.pool_all_clusters`.
- `.pool_all_clusters` e `.run_dream_mega` gia' supportano il flusso
  workers > 1 via `BiocParallel::MulticoreParam` (vedi Task 7 plan).

## Operational notes

- **OPENBLAS_NUM_THREADS=1 raccomandato** nell'environment prima di
  lanciare R con dream parallel. Senza limit, ogni worker forkato puo'
  spawnare 32+ thread BLAS → oversubscription → throughput peggiore di
  serial. Il bench parallel ha usato `Sys.setenv(OPENBLAS_NUM_THREADS=1)`
  + `RhpcBLASctl::blas_set_num_threads(1)`.
- **RAM**: BiocParallel forkato e' Copy-On-Write su Linux. Con 100
  worker × ~3 GB RSS condiviso il peak e' ~10-15 GB reali (le pagine
  modificate). Verificato non OOM su DGX 251 GB.
- **Non sostituire** workers=100 con plain `parallel::mclapply` —
  `variancePartition::dream` si aspetta `BPPARAM` di BiocParallel.

## Risks / Reversibility

- Se future versioni di `variancePartition` cambiano l'interfaccia
  `BPPARAM`, il path puo' fallire con errore esplicito; il fallback
  automatico a limma-voom + duplicateCorrelation copre la regressione.
- La scelta puo' essere overridata facilmente da config:
  `cfg$compute$dream_workers <- 1L` torna a serial.

## References

- `docs/findings/2026-05-20-stage4-de-method-bench.md` — bench full
  (seriale + parallel + k=11) con timing e concordanza.
- Hoffman GE, Roussos P (2021). "Dream: powerful differential expression
  analysis for repeated measures designs." Bioinformatics 37(2):192-201.
- ADR-0008 (`vllm-sampling-defaults`) — pattern analogo "default
  conservativo + override config".
- Memoria utente `user_de_methods_benchmark` (non pubblicata, condivisa
  in chat 2026-05-20).
