# ADR-0011: Tier-based per-record max_tokens (single-pass strategy)

- **Status:** Accepted
- **Date:** 2026-05-10
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** —
- **Relates to:** ADR-0009 (safe-mode stage2), ADR-0008 (sampling defaults)

## Context and Problem Statement

Lo Stadio 2 di simulomicsr (study_design extraction) processa input JSONL eterogenei: chunks da pochi KB (studi semplici, pochi sample) fino a 40+ KB (studi grandi con sample-facts ricche). Con un singolo `max_tokens` globale (default 4096), il dataset α stage2 cs25 (8546 record) ha mostrato:

- 90.6% schema valid al primo pass (truncation gli altri 9.4%)
- Rescue cycle 1 con max_tokens=8192: recupera 95.5% dei truncated → 99.6% cumulativo
- Rescue cycle 2 con max_tokens=32768: recupera 53% dei rimanenti → 99.8% cumulativo
- Wall time totale: ~25.5h (3 pass) + cold load × 3 + setup overhead

Il pattern dei rescue cycles ha tre svantaggi strutturali:

1. **Spreco di compute**: ogni rescue ri-elabora dei record già processati ma falliti (richiede di ri-loadare il modello ~7 min × 2 = ~15 min sprecati). Inoltre il record processato 2 volte paga il prefill quasi-doppio.
2. **Pipeline complexity**: 3 result files da mergiare manualmente, gestione degli "applied_patches", possibili duplicati cross-pass.
3. **Non scala** al P4 β (ARCHS4 ~700k sample): se 9.4% dei sample richiede rescue su un dataset 100x più grande, il rescue cycle pesa di più del run principale.

## Decision Drivers

- **Single-pass goal**: la pipeline α dovrebbe completare un dataset in un singolo job senza retry post-hoc.
- **Affidabilità e determinismo**: il rescue cycle dipende dal "knowing what to rescue" — fragile se il pattern cambia.
- **Calibrazione su dati reali**: abbiamo 8546 record α processati e classificati per tier — base empirica per una strategy informata.
- **Costo zero su DGX self-host**: paghiamo in wall time (XL records lenti), non in $.

## Considered Options

1. **A — Tier-based per-record max_tokens** (questa scelta): mappa input bytes → max_tokens via tier S/M/L/XL, ogni record processato col suo budget proporzionato.
2. **B — Mantieni 3-pass (status quo α)**: nessun cambio.
3. **C — Singolo max_tokens grande globale** (es. 32768 per tutti): elimina rescue ma sprecca KV cache reservation per record piccoli che non ne hanno bisogno.
4. **D — Output length predictor ML** (regressore output_size = f(input_features)): più sofisticato di tier-based ma richiede labeled training data e validation.

## Decision Outcome

Scelta: **Opzione A — Tier-based**.

Motivazione: cattura lo spirito di D (per-record budget) con la semplicità di una euristica B-vs-C ben calibrata. Le soglie sono basate sui dati α (non arbitrarie). I tier rispondono alla correlazione osservata tra dimensione input e dimensione output (positiva ma non lineare, per cui un tier bin-based è più robusto di un fattore moltiplicativo). Single-pass elimina i rescue artifacts.

### Tier mapping

| Tier | Input size | max_tokens | Stima copertura α |
|------|-----------|------------|-------------------|
| S    | < 15 KB   | 4096       | ~70% (90%+ valid first try osservato) |
| M    | 15-25 KB  | 8192       | ~20% (95%+ valid first try) |
| L    | 25-35 KB  | 16384      | ~8%  |
| XL   | ≥ 35 KB   | 32768      | ~2% (riserva di sicurezza per outlier) |

Soglie hard-coded in `R/dgx-utils.R::.dgx_tier_max_tokens()`. Calibrate su distribuzione record α stage2 cs25:
- Realtà osservata: S=39% / M=15% / L=24% / XL=22% (XL più alto del previsto perchè i big studies stage2 dominano per chunks)
- Rapporto KB→token approssimativo (Mistral tokenizer su JSON dense): ~3.5 char/token.
- Soglie KB scelte per allineare al 4x scaling dei max_tokens: 15 / 25 / 35 KB ≈ 4 / 7 / 10 K token input.

### Implementation

Tre layer:

**R/dgx-utils.R**: `.dgx_tier_max_tokens(input_bytes)` — helper interno mapping bytes → {tier, max_tokens}.

**R/dgx-bundle.R**: `dgx_p4_build_bundle()` accetta nuovo flag `tiered_max_tokens=FALSE` (default OFF). Quando TRUE:
- Annota ogni record dell'input.jsonl con field `max_tokens` per-record.
- Bumpa `gen$max_model_len` da 32768 a 65536 se ci sono record L/XL (per accomodare prompt grande + output 32K).
- Manifest registra `tier_summary` con count per tier.
- Solo per stage2 (stage1 record sono uniformemente piccoli).

**inst/dgx/python/run_p4_vllm.py**: in `worker_main`, costruisce per-record `SamplingParams` (vLLM accetta `sampling_params` come lista parallela ai messaggi). Se record ha field `max_tokens`, usa quel valore; altrimenti fallback a `gen.max_tokens` globale.

### Validation

Smoke test 100 record bilanciati (25 per tier) sull'α cs25 dataset, 2026-05-10 SLURM 20009:
- **100% schema validity** (vs 90.6% del 4096-flat first-pass)
- Tutti 4 worker hanno stampato `per-record max_tokens: 25/25 record con override, valori distinti=[4096, 8192, 16384, 32768]`
- vLLM init con `max_seq_len=65536` confermato
- Wall time: ~14 min totali (cold load 7 min + 7 min gen)

### Consequences

- **Positive:**
  - Eliminazione dei rescue cycles per stage2.
  - Pipeline conceptually single-pass; manifest + canonical result file univoco.
  - Coverage attesa ~99% in single pass (vs 90.6% del 4096-flat).
  - Scalabilità migliorata per P4 β (1 pass vs 3 → -2/3 cold load × N runs).

- **Negative:**
  - Wall time totale aumenta in valore assoluto (~50-80h stimati per α full vs 25.5h del 3-pass), perché XL records (22% del dataset) vengono processati con max_tokens=32768 anche quando il modello produrrebbe output corto.
  - Soglie KB sono hard-coded; cambio dataset (es. P4 β ARCHS4) potrebbe richiedere ri-calibrazione.
  - Edge case: record con dimensione INPUT al boundary (es. 14.9 KB → tier S vs 15.0 KB → tier M) può causare differenza significativa di budget. Mitigato dalla heuristic recovery (vedi sotto).

- **Neutral:**
  - max_model_len=65536 è sopra il default 32768 ma ben dentro Mistral-Small-3.2 native (128K). KV cache su H100 80GB con max_num_seqs=1 ha headroom.
  - Tier S records non beneficiano (max_tokens=4096 stesso del flat-default attuale). Beneficio puro per M/L/XL.

## Heuristic recovery integrato

Pattern Mistral-3.2 identificato 2026-05-10 (commit 7113755): il modello occasionalmente droppa il token `"value":` dentro array `factor_levels`, producendo `{"key":"X", "RAWVAL"}` invece di `{"key":"X", "value":"RAWVAL"}`. Questo causa `json.loads` failure pur essendo "quasi-valid".

Recovery applicato in due punti:

1. **Python live (run_p4_vllm.py `_try_parse`)**: durante la generazione il worker tenta `json.loads`, se fallisce applica regex `_RX_MISSING_VALUE` e ritenta. Field `applied_patches` in predictions.jsonl tracciabile per audit.

2. **R post-collect (dgx_p4_collect)**: stesso patch via `.try_recover_stage2_json()` per record con `valid_schema=FALSE` letti da predictions.jsonl. Markdown fence strip + missing-value patch. Cli alert con count recuperati.

Validato sui 3 result α esistenti: +8 record recuperati senza re-running (main +2, rescue1 +3, rescue2 +3). Schema validity 99.801% → 99.836% (canonical merge).

## Pros and Cons of the Options

### A — Tier-based (chosen)

- **Pro:** Single-pass; calibrato su dati reali; per-record budget proporzionato; minimal code change (3 layer); scalabile a β.
- **Contro:** Wall time più alto in assoluto; soglie possono richiedere re-calibrazione su dataset diversi.

### B — Status quo 3-pass

- **Pro:** Nessun nuovo codice; pipeline rodata.
- **Contro:** Wall time minore in α ma scalability poor; complessità mergeing 3 file; setup overhead × 3.

### C — Singolo max_tokens=32K globale

- **Pro:** Semplicissimo; deadlock-proof come tier-based.
- **Contro:** Spreco di KV per record S (la maggioranza); concorrenza ridotta nel scheduler vLLM (anche se safe-mode attenua); throughput peggiore.

### D — ML predictor

- **Pro:** Massima accuratezza nel sizing.
- **Contro:** Richiede labeled training set; complexity; over-engineering per il problema corrente; tier-based è "good enough" sui dati.

## Links

- Smoke test result: `analysis/p4-bundles/smoke-tiered100-result.rds` (100% validity).
- Implementation commit: `e41f7a1` (framework tier) + `7113755` (heuristic recovery).
- Eval downstream: `docs/decisions/0009-stage2-safe-mode-vllm-deadlock.md` (safe-mode max_num_seqs=1 invariato; tier-based si combina con safe-mode).
- vLLM upstream issue: #39734 (scheduler deadlock — non riemerge col safe-mode).
- Memory: `feedback_dgx_time_limit_default.md` (default time=72h+ per DGX self-host).
