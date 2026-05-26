# A3 — Sintesi audit `singlecellprobability` + lib_size (input per ADR-0019)

> **Data**: 2026-05-26.
> **Scope**: RED ALERT FASE A3 (Stadio 0 audit). Filtro residuo single-cell
> tramite predizione ML `meta/samples/singlecellprobability` di ARCHS4
> (classifier su pattern conteggi `/data/expression`), applicato ai sample
> sopravvissuti ad A1+A2+lib_size.
> **Output**: questo file è materiale evidence per ADR-0019 (FASE B1) e
> finding paper-grade G2 (FASE G2).
> **Branch**: `p5-llm-anchor-classification-audit`.

## 1. Universo analizzato

Numeri aggiornati 2026-05-26 sessione 4 (post-fix regex underscore-aware
A2 + A3c, vedi `A2-synthesis-protocol-regex.md` §6.2bis).

- Bacino A3: sample rescued ∩ `library_source == "transcriptomic"` ∩
  NOT in A2 drop = **548.373** (vs 547.531 pre-fix, +842).
- Filtro QC lib_size ≥ 500.000 (uguale a Stadio 4):
  - Sopravvissuti: **509.262 / 548.373 = 92.87%**.
  - Drop lib_size: 39.111 (7.13%).
- I drop lib_size sono **separati** dal drop SC: sono sample
  bulk-RNA-Seq legittimi ma con sequencing depth insufficiente per la
  meta-analisi DE.

## 2. Distribuzione `singlecellprobability` sui 509.262 post-lib_size

| stat | valore |
|---|---:|
| min | 0.000 |
| Q1 | 0.0026 |
| **median** | **0.0064** |
| mean | 0.0484 |
| Q3 | 0.0199 |
| max | 1.000 |

**Skewed verso zero**: dopo A1+A2+lib_size la stragrande maggioranza dei
sample ha probabilità SC bassissima. Scenario "filtri puliti" del
RED_ALERT confermato.

## 3. Validazione FPR manual cluster-based (n=50 per bin)

Strategia: confronto manuale TP (single-cell veri) vs FP (bulk veri o
bulk-low-input mascherati da ML) su 4 bin di `singlecellprobability`.

| bin | n popolazione | FP manual | FPR | Wilson 95% CI |
|---|---:|---:|---:|---|
| > 0.5 (aggregato A3b) | 14.557 | 18/50 | **36%** | [24.1%, 49.9%] |
| 0.5-0.6 | 3.664 | 18/50 | 36% | [24.1%, 49.9%] |
| 0.7-0.8 | 3.410 | 7/50 | **14%** | [6.9%, 26.2%] |
| ≥ 0.9 | 1.224 | 4/50 | **8%** | [3.2%, 18.8%] |

### 3.1 Curva FPR proxy (regex automatic su tutti i 508.685)

Pattern BULK_LOW_INPUT (19 regex) derivato dai FP manuali: QuantSeq,
TM3'seq, ScreenSeq, LCM/10-cell, FFPE, RiboSeq, EV/exoRNA, swab COVID,
HTG EdgeSeq, CAGE, PAXgene Blood, PicoPure, SMARTer Stranded Total Pico,
Smart-3SEQ, Lexogen 3' mRNA, HTGseq, spatial_trans, embryo blastomere.

Pattern bulk_low_input aggiornati 2026-05-26 sessione 4 (regex
underscore-aware su 10_cell, 16_cell, Ribo_seq, Smart_3SEQ, ecc.).

| threshold | n_drop | n_bulk_proxy | %_bulk_proxy |
|---:|---:|---:|---:|
| 0.50 | 14.557 | 2.971 | 20.41% |
| 0.55 | 12.682 | 2.250 | 17.74% |
| 0.60 | 10.893 | 1.677 | 15.40% |
| 0.65 | 9.024 | 1.146 | 12.70% |
| 0.70 | 7.194 | 733 | 10.19% |
| 0.75 | 5.401 | 407 | 7.54% |
| 0.80 | 3.784 | 218 | 5.76% |
| 0.85 | 2.355 | 101 | 4.29% |
| **0.90** | **1.224** | **37** | **3.02%** |
| 0.95 | 526 | 16 | 3.04% |

**Plateau a 0.9** (curva si stabilizza ~3% proxy / ~8% manual). Sotto 0.9
cresce monotonicamente. Ratio manual/proxy = 1.5-2x in tutti i bin
(proxy sottostima FPR vero; cattura solo metodi univoci, perde
casi sottili).

### 3.2 Pattern dei FP

**Weakness ML ARCHS4 identificate paper-grade**:

1. **bulk-low-input methods classificati come SC** (FP dominante):
   QuantSeq 3' mRNA-Seq, TM3'seq, ScreenSeq (Evotec), LCM 10-cell pool,
   FFPE total RNA, RiboSeq, EV/exoRNA, COVID swab, HTG EdgeSeq, CAGE.
   Pattern conteggi (lib_size basso + dropout) confonde il classifier.
2. **NanoString GeoMx DSP (spatial transcriptomics)** classificato come
   SC con scprob >0.9. 3/4 FP nel bin ≥0.9 sono GSE232853 DSP regions.
3. **Bulk-low-input sorted populations** (CD4+ T cell subsets, 30-200
   sorted cells per condition + SMARTer Ultra Low / Nextera XT) →
   scprob 0.3-0.5 (mid range, ambiguo per ML).

**Weakness opposta (FN)**: SC plate-based ad alto coverage (SmartSeq2,
TARGET-seq, NASC-seq, micromanipulation CTCs) → scprob 0.3-0.5 perché
lib_size 1-3M sovrappone bulk-low-input. Stima ~1.000 FN nella fascia
0.3-0.5 (10% × 10.734 bin size).

## 4. Decisione architetturale (input ADR-0019)

### 4.1 Soglia singlecellprobability = 0.9

Razionale data-driven:
- **Plateau** a 0.9: la curva FPR si stabilizza, sotto cresce monotonicamente.
- **Drop limitato**: 1.224 / 509.262 = 0.24% del bacino post-lib_size.
- **FPR contenuto**: 8% manual (Wilson CI [3-19%]). ~100 FP attesi
  (NanoString DSP residue + casi rari).
- **Recovery utile**: ~1.125 SC veri droppati che A1+A2 hanno mancato
  (TARGET-seq, SCRB-seq, CTC micromanipulation, SC con submitter
  ext_protocol povero o non standard).

### 4.2 Regola A3

```
keep_A3 := (sample passa A1+A2) AND
           (lib_size >= 500.000) AND
           (singlecellprobability < 0.9)
```

Lib_size threshold = stesso QC del Stadio 4 (coerenza pipeline).

### 4.3 Alternative considerate e scartate

- **th=0.5**: drop 14.502 → ~5.200 FP bulk-low-input legittimi
  (QuantSeq, TM3', ScreenSeq) wrongly droppati. **FPR 36% troppo alto**.
- **th=0.7**: drop 7.184 → ~1.000 FP. Compromesso intermedio, ma
  recovery extra modesto vs th=0.9 (~6.000 SC veri in più contro ~900 FP
  extra).
- **Nessuna soglia**: accetta 2.85% SC residuo nel bacino post-A1+A2.
  Conservativo ma rinuncia a 1.224 SC catturabili con drop cheap.
- **th=0.95**: drop 527 → curva al plateau, riduzione marginale del FP
  ma anche del recovery. Non differisce sostanzialmente da 0.9.

## 5. Numeri aggregati A1+A2+A3

| filtro | sample drop | bacino input | drop rate |
|---|---:|---:|---:|
| A1 (`library_source != "transcriptomic"`) | 28.942 | 879.167 | 3.29% |
| A2 (regex SC + title-bulk rescue) | 302.694 | 850.225 | 35.60% |
| A3 lib_size < 500k (QC) | 39.111 | 548.373 | 7.13% |
| A3 singlecellprobability ≥ 0.9 | 1.224 | 509.262 | 0.24% |
| **TOTALE Stage 0 drop** | **371.129** | **879.167** | **42.21%** |

**Bacino finale post-Stage 0 v2**: 879.167 − 371.129 = **507.838**
sample candidati bulk RNA-Seq human steady-state.

> ⚠️ Nota: la riga "A3 lib_size < 500k" rappresenta sample bulk
> legittimi droppati per insufficient sequencing depth (QC condiviso
> con Stadio 4). NON sono single-cell. Vengono droppati per coerenza
> di QC pipeline, non per il filtro SC stesso.

## 6. Limitations dichiarate per il paper

L<n>. **Stage 0 single-cell filter via singlecellprobability ML**.
ARCHS4 ML classifier ha 2 weakness identificate cluster-based:
(a) bulk-low-input methods (QuantSeq, TM3', ScreenSeq, LCM, FFPE) →
predetti come SC con scprob > 0.5 (FPR 36% manual a 0.5, 14% a 0.7-0.8,
8% a ≥0.9 Wilson 95% CI [3-19%]);
(b) SC plate-based ad alto coverage → scprob 0.3-0.5 (FN, ~10%
nella fascia). Filtro adottato th=0.9 al plateau della curva FPR
(drop +1.224 sample, 0.24% del bacino post-lib_size, FP attesi ~100
dominati da NanoString GeoMx DSP spatial transcriptomics).

## 7. Prospettiva futura — LLM-based quality check post-aggregazione

**Idea**: dopo Stadio 3 (clustering cross-studio sui comparability anchor),
i sample selezionati per cluster di interesse possono essere ri-passati
a un LLM (Mistral-Small-3.2 self-hosted DGX, oppure Claude / GPT) come
**quality check finale mirato** per limare residui SC / bulk-low-input
che hanno superato Stage 0 (A1+A2+A3).

Razionale:
- Stage 0 è filtro globale su 879k sample → must be cheap (regex +
  ML probability), accetta FN residui ~1.000 SC veri + FP attesi ~100
  bulk-low-input.
- Post-aggregazione il numero di sample per cluster è O(10-100), quindi
  LLM-classification per-sample diventa economicamente sostenibile
  ($0 su Mistral self-hosted DGX).
- LLM può integrare segnali ortogonali a regex+ML: contesto biologico
  del cluster, coerenza fra title/source/ext_protocol/characteristics,
  semantica del trattamento → tipologia esperimento (bulk vs SC).

**Quando attuarla**: post-rebuild Stage 3 + Stage 4 (cioè dopo
FASE F del RED_ALERT). NON nel scope corrente di Stage 0 audit.

**Costo stimato**: 1-2 sessioni LLM mirate sui cluster Layer B candidati,
~5-10k sample max → wall <1h su DGX Mistral. Confronto risultato vs
flag corrente Stage 0 → identifica sample-level FN/FP residui da
chiarire prima di pubblicare cluster nei case study Layer B.

**Status**: deferred. Da aprire come task post-FASE F (rebuild) o post-
chiusura RED_ALERT Stadio 0. Memo per non perderlo.

## 8. Output supporto

| file | contenuto |
|---|---|
| `A3-singlecellprobability.R` | script A3: lib_size scan + scprob summary + plot |
| `A3-libsize-scprob-bacino.tsv` | 548.373 righe (geo, series, lib_size, scprob, passed_libsize_500k) — fix underscore-aware applicato |
| `A3-libsize-scprob-bacino.OLD.tsv` | backup 547.531 righe pre-fix |
| `A3-scprob-distribution.png` | istogramma scprob + log10(lib_size) post-lib_size |
| `A3-run.log` | log fullrun con per-slab progress |
| `A3b-fp-fn-analysis.R` | script A3b: cross-tab + 50 manual 0.5+, 50 manual 0.3-0.5 |
| `A3b-run.log` | output A3b con 100 sample classified manuale |
| `A3b-inspection-dfs.rds` | RDS data frame intermedio A3b |
| `A3c-fpr-curve.R` | script A3c: curva FPR proxy + 50×3 bin manual |
| `A3c-fpr-curve.tsv` | tabella FPR proxy per soglia 0.5-0.95 |
| `A3c-fpr-curve.png` | plot curva FPR proxy |
| `A3c-manual-bin-samples.tsv` | 150 sample classification dump |
| `A3c-run.log` | output A3c con 150 sample classified |
| `A3-synthesis-singlecellprobability.md` | questo file |

## 9. Cosa decide A3

> Soglia **singlecellprobability ≥ 0.9** come safety net SC residuo.
> Drop addizionale 1.224 / 509.262 = **0.24%** del bacino post-lib_size.
> Aggregato A1+A2+A3 (escluso lib_size QC che è filtro condiviso con
> Stadio 4) = **332.861 / 879.167 = 37.86%** del bacino rescued
> attribuito al filtro SC Stage 0.

## 10. Cosa NON decide A3

- La quantificazione dell'inquinamento corrente in
  `cluster_pooled.parquet` (run 96c43acb): FASE A4.
- La decisione binaria rebuild vs filtro post-hoc: FASE A6.
- La strategia dedupe BioSample vs `donor_id`: FASE A7.
- LLM-based quality check post-aggregazione: prospettiva futura
  post-FASE F (vedi §7).
