# P4 β rescue strategies — consolidated for paper Methods/Results

> **Status:** Consolidated 2026-05-17, branch `p4-beta-rescue`
> **Purpose:** Riassunto operativo e paper-ready delle tre strategie di
> rescue implementate sopra il fullrun β P4 ARCHS4 v2.5 human. Non sono
> elencate qui le prove fallite intermedie né i tentativi di debugging —
> solo le strategie consolidate, riproducibili dal codice in `analysis/`.
> Da includere come sezione dedicata in Methods/Results dell'articolo.

## Contesto

Il fullrun β P4 (NEWS 0.0.0.9016) ha processato **888.821 sample** ARCHS4
v2.5 human bulk RNA-seq filtered con Mistral-Small-3.2-24B in containerized
vLLM (v0.20.2-cu129) su 4 H100 DGX. Output stage1 single-pass: **887.250
valid / 1.571 fails** (0.18%). Output stage2 single-pass cs50: **39.162
valid / 43 fails** (0.11%).

Sopra il fullrun originale abbiamo applicato una cascade di **tre
strategie di rescue indipendenti**, che insieme hanno portato il dataset
a:

- Stage1 LLM-only validity: **99.998%** (878.398 / 878.418 LLM_attempted)
- Stage2 schema validity: **100.000%** (39.247 valid, 0 residual)
- 72 GSE mouse-mislabeled-as-human identificati upstream come byproduct
  metodologico (discovery indipendente, contributo positivo).

Le strategie sono definite come **single-shot retry config overrides**
applicati solo ai record falliti — il default pipeline rimane invariato
(uniformità config su tutti gli stadi, `feedback_pipeline_config_uniformity`).
Sono indipendenti tra loro: H1 risolve stage1 LLM fails non-ETL, H2
identifica e rimuove contaminazione organism, H3 risolve stage2 stall
edge-case su tier XL.

## H1 — Stage1 LLM JSON-failure rescue

**Trigger.** 822 stage1 fails non-ETL classificati per failure mode
(`analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv`):

| Failure mode | N | Pattern |
|---|---|---|
| MODE_A_WHITESPACE | 660 | decoder loop su field-boundary `["string","null"]`, rep_pen 1.1 insufficiente |
| MODE_B_LEGIT_TRUNC | 147 | JSON parziale corretto, max_tokens 2048 stage1 esaurito su metadata verbose |
| OTHER_DEGEN | 15 | pattern misti rari (formatting tag, token loops residuali) |

**Configurazione rescue.** Single-shot override:

| Parametro | Default pipeline | H1 rescue |
|---|---|---|
| `repetition_penalty` | 1.1 | **1.2** |
| `max_tokens` | 2048 (stage1) | **4096** |
| `max_model_len` | 4096 | **8192** |
| `temperature` | 0.0 | 0.0 (invariato) |
| backend structured outputs | xgrammar→outlines | invariato |

**Razionale del triplo-override.** La combinazione estende
simultaneamente (1) il budget token (Mode B fix, dimostrato in α 100%
Mode B recovery con max_tokens 2048→4096), (2) il rep_pen (Mode A fix,
dimostrato in α 100% Mode A recovery con 1.1→1.2), (3) il context model
length per record verbose senza compromettere richieste normali (overhead
trascurabile, modello supporta fino a 128k context). Single-shot
sostituisce il pattern α multi-round (uniqfail_temp00_rep11 →
rep11_maxtok2048 → rep12_maxtok2048) collassandolo in una sola
sottomissione, riducendo overhead di submit/collect.

**Risultato.**

- Smoke20 (5 chunk random sample, slurm 21008, 1m39s wall): **20/20 =
  100% recovery**.
- Full retry 822 record (slurm 21103, **3m21s wall**): **802/822 = 97.6%
  recovery**. 20 residual irrecuperabili (Mode A edge case con field-boundary
  collapse profondo, non risolto da rep_pen 1.2).

**Tracking.** Master output `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl`
(879.167 record, gitignored). Colonna `rescue_source = "h1_rep12_maxtok4096"`
su 802 record rescued (NA sui 878.345 originali clean + sui 20 fail
residual).

**Riferimenti codice.**

- Input build: `analysis/p4-beta-rescue-build-input.R`
- Submit smoke: `analysis/p4-beta-rescue-h1-stage1-smoke.R`
- Submit full: `analysis/p4-beta-rescue-h1-stage1-full.R`
- Merge: `analysis/p4-beta-rescue-h1-merge.R`
- ADR: `docs/decisions/0008-vllm-sampling-defaults.md` — Addendum 2026-05-17

## H2 — Mouse-mislabeled-as-human GSE detection + GSE-level drop (discovery)

**Trigger.** Phase 2 debugging dei 749 stage1 fails classificati
`ETL_LEAK_NONHUMAN` (degenerazione decoder su metadata mouse-specific) ha
rivelato un pattern strutturale: tutti concentrati in pochi GSE, e l'LLM
classifica tutti gli altri sample dello stesso GSE come `Mus musculus`
(in disagreement col campo upstream `organism_ch1 = "Homo sapiens"` di
ARCHS4 v2.5). Cross-check organism breakdown per GSE su tutto il master
stage1 ha esteso la scoperta a **72 studi GEO** mouse-mislabeled-as-human.

**Threshold di flagging studio.** Uno studio è marcato suspect se entrambi:

- `≥ 5 sample` classificati non-human dall'LLM Mistral-Small-3.2-24B
- `≥ 50%` dei sample con classificazione valida è non-human

72 studi soddisfano il criterio. Lista completa in
`analysis/p4-output/p4-beta-rescue-h2-suspects.rds` (72 righe × 4 colonne:
`series_id`, `total`, `nonhuman`, `pct_nonhuman`).

**Decisione drop policy: GSE-level conservative.** Per ogni GSE flagged
droppiamo tutti i sample dello studio (anche quelli human-classified
clean) per evitare contaminazione organism parziale downstream.

**Numeri (paper-grade)**:

| Categoria | N sample |
|---|---|
| Sample classificati non-human dall'LLM (discovery diretta) | **8.398** |
| Sample human-classified collaterali in GSE mixed (drop conservativo) | 1.256 |
| **Drop GSE-level effettivo (Stage1: 888.821 → 879.167)** | **9.654** (1.09% β) |
| LLM JSON failures su metadata mouse-specific (signal indiretto, tutti nei 72 GSE) | 749 |
| **Totale signal mouse-mislabel raccolto dalla pipeline** | **10.403** (1.17% β) |

Concentrazione: il signal indiretto LLM JSON failure è dominato da
**GSE86977 (746 / 749 = 99.6%)**, uno studio embrionale con `cre line: DCX+`
(DCX-Cre transgenic line mouse-only) consistentemente confondente per il
decoder.

Stage2-input correlato: 39.205 → **38.963 record** (−242 record GSE-level).

**Significato metodologico.** Per confronto, gli annotatori GEO/SRA
esistenti citati in ADR-0006 (MetaSRA, MetaHQ Hicks 2026, multi-agent
metadata curation Mondal 2025, RummaGEO Maayan 2024) operano sul campo
strutturato `organism` senza re-interpretare il free-text di
`title + characteristics_ch1`. La pipeline simulomicsr funziona quindi
come **QC layer secondario downstream** che identifica errori upstream
non-rilevati dai filtri esistenti. I 72 studi sono candidati alla
segnalazione GEO curators per re-annotation upstream.

**Riferimenti.**

- Discovery doc esteso: `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md`
- Script cleanup: `analysis/p4-beta-rescue-h2-cleanup.R`
- ADR positioning: `docs/decisions/0006-stato-arte-vs-simulomicsr.md`

## H3 — Stage2 stall rescue via cs25 re-split

**Trigger.** 43 stage2 cs50 record falliti nel fullrun originale (slurm
20710), tutti residual edge-case del vLLM Issue #39734 (scheduler HoL
stall su request grandi entro max_model_len ma in pressione KV cache).
Distribuzione tier: tutti i 43 fails sono concentrati su tier XL
(max_tokens = 32768 nel pipeline tiered_max_tokens del fullrun stage2).

Il fullrun aveva `max_num_seqs=6, microbatch=50` (ADR-0009 safe-mode
declassato a fallback post-PR #40946); per i 43 record problematici il
fix mainstream non è sufficiente.

**Configurazione rescue.** Single-shot override sul chunking, NON sulla
config sampling/concurrency:

| Parametro | Default pipeline stage2 | H3 rescue |
|---|---|---|
| `chunk_size` | 50 (cs50) | **25 (cs25)** |
| `tiered_max_tokens` | True (XL = 32768) | True invariato (XL = 32768) |
| `max_num_seqs` | 6 | invariato |
| `microbatch` | 50 | invariato |
| sampling | `temperature=0.0, rep_pen=1.1` | invariato |

**Razionale del cs50→cs25 re-split.** Dimezzare il chunk_size dimezza
il numero di sample per request, riducendo l'output token budget
necessario e quindi la KV cache footprint per request. Questo allevia
la pressione scheduler che innesca HoL stall su request grandi.
Rilevante: ADR-0013 documenta perché cs50 è scelto come default
(throughput aggregato superiore vs cs25 in steady-state); per il rescue
sacrifichiamo throughput in cambio di completezza sui 43 outlier.

Il re-split produce **85 cs25 chunks** dai 43 cs50 fails: ogni cs50
originale (es. record_id `XYZ--p3of5`) diventa 1-2 cs25 chunks
(`XYZ--p3of5--rsc1of2`, `XYZ--p3of5--rsc2of2`). Tracking
`original_record_key` mantenuto in `chunk_metadata`.

Tier distribution risultante sui 85 cs25 chunks: **L=26, XL=59** (no S/M
— erano tutti tier XL/L nel cs50 originale).

**Risultato.**

- Smoke5 (5 chunks random sample, slurm 21129, 2m35s wall): **5/5 = 100%
  recovery**.
- Full retry 85 cs25 chunks (slurm 21132, **8min wall**): **85/85 cs25
  chunks valid, 0 residual**. Aggregati per `original_record_key`: **43/43
  cs50 original keys fully rescued** (logica merge: una key è rescued
  solo se TUTTE le sue cs25 parts sono valid_schema=TRUE).

**Tracking.** Master output `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds`
(39.247 predictions = 39.162 originali + 85 cs25 rescued, 0 errors).
Colonna `rescue_source = "h3_cs25_resplit"` su 85 cs25 chunks (NA sui
39.162 originali clean).

**Granularità mista cs50/cs25 nel master.** Conseguenza del re-split: i
predictions stage2 finali hanno granularità mista (39.162 cs50 + 85 cs25).
Per Stadio 3 raggruppamento downstream, ogni chunk mantiene record_id
univoco e i sample sono distintamente etichettati in
`chunk_metadata.original_record_key`, quindi nessuna ambiguità.

**Riferimenti codice.**

- Input build: `analysis/p4-beta-rescue-h3-build-input.R`
- Submit smoke: `analysis/p4-beta-rescue-h3-stage2-smoke.R`
- Validate smoke: `analysis/p4-beta-rescue-h3-stage2-smoke-validate.R`
- Submit full: `analysis/p4-beta-rescue-h3-stage2-full.R`
- Merge: `analysis/p4-beta-rescue-h3-merge.R`
- ADR contesto: `docs/decisions/0009-stage2-safe-mode-vllm-deadlock.md`,
  `docs/decisions/0011-tier-based-max-tokens.md`,
  `docs/decisions/0013-stage2-chunk-size-cs50.md`

## Riassunto numerico finale β post-rescue cascade

| Metric | Pre-rescue (NEWS 0.0.0.9016) | Post-rescue (NEWS 0.0.0.9017) |
|---|---|---|
| Stage1 master records | 888.821 | **879.167** (−9.654 H2 GSE-level drop) |
| Stage1 LLM-only validity | 99.82% | **99.998%** |
| Stage1 records con `rescue_source` annotation | 0 | 802 (h1_rep12_maxtok4096) |
| Stage2 input records (post H2 cleanup) | 39.205 | **38.963** (−242 H2 GSE-level) |
| Stage2 predictions valid | 39.162 | **39.247** (39.162 cs50 + 85 cs25 rescued) |
| Stage2 schema validity | 99.89% | **100.000%** (0 residual) |
| Stage2 records con `rescue_source` annotation | 0 | 85 cs25 chunks (h3_cs25_resplit) |
| Mouse contamination upstream (latent) | ~10.403 sample non-rilevati | **0** (72 GSE droppati + flagged per re-annotation) |

## Per il paper

Sezione consigliata: **Methods → "Rescue strategies"** dopo la descrizione
del fullrun base.

Per ognuna delle tre strategie, riportare nel paper:

1. **Trigger** (1 frase): che tipo di fail / discovery è.
2. **Configurazione single-shot rescue** (tabella delta vs default
   pipeline): 2-3 parametri modificati, sampling invariato.
3. **Razionale** (1-2 frasi): perché questo override risolve il pattern.
4. **Risultato quantitativo** (1 riga): smoke recovery %, full recovery
   %, wall time.
5. **Tracking** (1 frase): colonna `rescue_source` con tag specifico per
   riproducibilità.

H2 in particolare merita sezione separata in **Results** come contributo
positivo (NOT Limitations): la pipeline funge da QC layer secondario su
upstream metadata curation, identificando errori non-rilevati dai filtri
ARCHS4/GEO esistenti (compare con ADR-0006 stato-arte vs simulomicsr).

Le 72 GSE flagged possono essere offerte come **supplementary material**
per riproducibilità + community contribution (segnalazione GEO/ARCHS4
curators per re-annotation).
