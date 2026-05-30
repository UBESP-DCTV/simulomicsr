# F3 — Smoke Stadio 2 pre-fullrun (validate-before-fullrun, sessione 11)

> Data: 2026-05-30. Branch `p5-llm-anchor-classification-audit`.
> Config invariata (temp=0, rep_pen=1.1, microbatch=50, stage2 tiered_max_tokens).
> Prompt Stadio 2 EN (D3). load_all branch. Master Stadio 1 v2 CONGELATO.

## Scopo

Validare lo Stadio 2 sul materiale **reale** del fullrun F3 — l'input costruito
a partire dal master Stadio 1 v2 rescued (508.037 record, recuperi inclusi) —
**senza rifare lo Stadio 1**. Differenza chiave vs benchmark sessione 9: lì lo
Stadio 1 veniva rifatto da zero sui 756 campioni; qui parte dal master congelato
che daremo al fullrun, quindi testa anche i 1.464 record recuperati + i 2
curati a mano (GSE157354).

## Setup

- Sottoinsieme: i 72 studi del gold design-aware (756 campioni,
  `analysis/p4-output/f2-eval-gold.csv`), tutti presenti nel bacino v2.
  → 72 record stage2, 0 chunk.
- Tier: S=44, M=20, L=7, XL=1 (rischio stall #39734 minimo su questo smoke).
- run_id `20260530T094323Z-f3-stage2-smoke-637480` (slurm 22943).
- Wall: ~4 min (09:43:23Z → 09:47:11Z). 72/72 completati, 0 falliti schema, 0 worker falliti.

## Risultati

| Metrica | Valore | Riferimento |
|---|---:|---|
| Schema validity s2 | **100,00%** (72/72) | soglia ≥99% |
| Binary accuracy vs gold | **94,04%** (722 valutabili) | baseline sessione 9: 94,14% |
| Sensitivity | 97,6% | sessione 9: 96,9% |
| Specificity | 89,0% | sessione 9: 90,2% |
| F1 | 0,951 | sessione 9: 0,951 |
| Coverage gap (campioni non predetti) | 21 (~2,9%) | gap noto ~3,5% |

Confusion (gold × pred):

```
         pred
gold      control treated <NA>
  control     266      33    7
  treated      10     413   14
  <NA>          8       4    1
```

## Interpretazione

Lo Stadio 2 digerisce senza problemi il materiale congelato — recuperi inclusi —
e classifica come nel benchmark su scala della sessione 9: la differenza di
0,10pp è uno-due campioni (rumore di campionamento sullo stesso gold). I 1.464
record recuperati a fatica + i 2 curati a mano **non rompono lo schema a valle**
(validity 100%) né degradano l'accuratezza. Gli errori residui sono le stesse
categorie già documentate in `2026-05-28-f2-stage1-prompt-fragility.md` §4.2
(studi multi-asse difendibili + buco di copertura), nessun pattern nuovo.

## Verdetto gate

**PASS.** Schema 100% (≥99%), accuratezza in linea con la baseline validata
(94,04% vs 94,14%), sul materiale reale del fullrun. Gate pre-F3-fullrun
superato. Il fullrun procede su decisione utente esplicita (config + stima wall
+ scelta job unico/chunked presentati separatamente).

## Riferimenti

- Script: `analysis/p4-fase-f3-stage2-smoke.R`.
- Eval RDS: `analysis/p4-output/<ts>-f3-stage2-smoke-eval.rds`.
- Input smoke: `analysis/input/p4-f3-stage2-smoke-input.jsonl` (72 record).
- Gold: `analysis/p4-output/f2-eval-gold.csv` (756 campioni / 72 studi).
