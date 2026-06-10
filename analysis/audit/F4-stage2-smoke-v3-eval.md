# F4 Stadio 2 v3 — smoke gate (opzione C)

> RED ALERT FASE F4, sessione 13 (2026-06-10). Validate-before-fullrun.
> Run `20260610T105605Z-f4-stage2-smoke-v3-f1e3ce` (slurm 24021).

## Scopo

Validare lo Stadio 2 **v3** (input a condizioni deduplicate per `design_signature`
+ prompt `n_replicates` + espansione rappresentante→membri) sui 72 studi del gold
design-aware (756 campioni, `f2-eval-gold.csv`), prima del fullrun. Tutti i 72
studi gold sono a 1 record (0 chunk): lo smoke esercita prompt + espansione, non
la fusione chunk.

## Esito — GATE PASS

| metrica | v3 | baseline F3 (sess 11) |
|---|---:|---:|
| schema | **100%** (72/72) | 100% |
| binary accuracy | **94,04%** (n=738) | 94,04% |
| sensitivity | 96,8% | 97,6% |
| specificity | 90,1% | 89,0% |
| f1 | 0,950 | 0,951 |
| coverage gap | **5 (0,7%)** | 21 (2,9%) |

Confusion (gold × pred): control 274/30/2, treated 14/420/3, NA 8/4/1.

Gate = schema 100% + accuracy ≥ 94% → **superato**.

## Lettura

- L'opzione C **riproduce esattamente** l'accuratezza F3 (94,04%) → il nuovo
  approccio (condizioni + n_replicates + espansione) **non degrada** la
  classificazione design-aware sul gold non-chunked. Il guadagno dell'opzione C
  (integrità della membership per gli studi chunkati) è strutturale, non
  misurato da questo gold.
- Coverage migliorata (gap 21→5): l'espansione copre tutti i membri di ogni
  condizione invece di perdere campioni nei chunk.
- **Soffitto oracle 98,92%** (predizioni sintetiche a ruolo perfetto per
  condizione): lo scarto ~4,9% dal reale è errore di classificazione LLM +
  rumore gold (calibrato 88,2% vs umano); ~1,1% (8/740) è false-merge della
  firma (condizioni che raggruppano gold-role opposti). Coerente con i finding
  F2/F3 (multi-asse + coverage gap).

## Riproduzione

- Smoke: `analysis/p4-fase-f4-stage2-smoke-v3.R` (submit+poll+collect+assembly+eval).
- Solo eval: `EVAL_ONLY=1 PREDS=<predictions.jsonl> Rscript ...`.
- Eval RDS: `analysis/p4-output/p4-f4-stage2-smoke-v3-eval.rds`.
