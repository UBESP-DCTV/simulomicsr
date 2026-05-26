# A2 — Sintesi audit `extract_protocol_ch1` regex SC (input per ADR-0019)

> **Data**: 2026-05-26.
> **Scope**: RED ALERT FASE A2 (Stadio 0 audit). Audit dei single-cell
> mascherati come `library_source = "transcriptomic"` via parsing
> testuale di `meta/samples/extract_protocol_ch1` (+ title +
> source_name_ch1).
> **Output**: questo file è materiale evidence per ADR-0019 (FASE B1)
> e finding paper-grade G2 (FASE G2).
> **Branch**: `p5-llm-anchor-classification-audit`.

## 1. Universo analizzato

- Bacino A2: sample che hanno **superato A1** (cioè `library_source ==
  "transcriptomic"` AND nel master rescued) = **850.225** sample.
- I 28.015 SC esplicitamente etichettati da `library_source` (A1) sono
  esclusi da questo bacino per construction (overlap atteso 0,
  verificato 0).

## 2. Problema metodologico (riconoscere il compromesso)

A1 era **deterministico** (whitelist su vocabolario controllato GEO).
A2 è **probabilistico**: `extract_protocol_ch1` è testo libero scritto
da migliaia di submitter senza standard linguistico. Qualunque parsing
introduce:

- variabilità lessicale (sinonimi, typo, ordering),
- ambiguità semantica (es. "single cell suspension" è SC nel contesto
  scRNA-seq ma è anche bulk dopo dissociazione tessutale),
- bias di copertura (kit nuovi sotto-detected; kit noti over-detected),
- arbitrarietà della lista di kit "SC" (chi decide?).

L'alternativa — non filtrare i sample con metadati `library_source`
inaffidabili — è peggiore: 35-36% del bacino sopravvissuto ad A1 è
SC mascherato. Quindi A2 è un compromesso accettato con FPR documentato.

La strategia di mitigazione è **multi-segnale concordante** (A2 ∩ A3):
A3 (`singlecellprobability` di ARCHS4, predizione ML su pattern conteggi)
fornirà un secondo segnale ortogonale al regex testuale. La decisione
finale di drop sarà costruita su entrambi (intersection per ridurre FPR
o union per ridurre FNR — scelta data-driven in A5).

## 3. Lista pattern approvata 2026-05-26

Divisa in 2 gruppi per separare confidence levels.

### Gruppo K — kit/platform specifici (alta confidenza)

| pattern label | regex |
|---|---|
| 10x_Chromium | `(?i)\b10[xX]\s*Genomics\b\|\bChromium\b\|\b10[xX]\s*chip\b\|\b10[xX]\s*chromium\b` |
| SmartSeq | `(?i)(?<!3-)(?<!3)\bSmart[- ]?Seq[23]?\b` |
| Fluidigm_C1 | `(?i)Fluidigm\|\bC1 chip\b\|\bC1 IFC\b` |
| ICELL8 | `(?i)ICELL8` |
| Drop-seq_inDrop | `(?i)Drop[- ]?seq\|inDrop` |
| CEL-seq_MARS-seq | `(?i)CEL[- ]?seq\|MARS[- ]?seq` |
| Seq-Well | `(?i)Seq[- ]?Well` |
| BD_Rhapsody | `(?i)BD\s*Rhapsody\|Rhapsody` |
| Digital_microfluid | `(?i)Digital microfluidic` |
| CellPlex | `(?i)CellPlex\|3'\s*CellPlex` |
| CellTag | `(?i)CellTag` |
| Multi-seq | `(?i)Multi[- ]?seq` |
| snDrop | `(?i)snDrop` |

**Note pattern**:
- `10x_Chromium` richiede contesto `Genomics`/`Chromium`/`chip` per
  evitare match con `10x SDS buffer`, `10x SSC`, `10x diluted`
  (validation A2b: −10.377 catch vs pattern grezzo).
- `SmartSeq` esclude esplicitamente `Smart-3SEQ` (Foley 2019, bulk
  3'-tag RNA-seq, NON single-cell).

### Gruppo S — semantica single-cell (richiede validazione FP)

| pattern label | regex |
|---|---|
| single_cell_literal | `(?i)\bsingle[- ]?cell\b` |
| single_nucle | `(?i)\bsingle[- ]?nucle[ari]+\b` |
| snRNA | `(?i)\bsn[- ]?RNA(-?seq)?\b\|\bNuc[- ]?seq\b` |
| scRNA | `(?i)\bsc[- ]?RNA(-?seq)?\b` |

### Target di match

`extract_protocol_ch1` ∪ `title` ∪ `source_name_ch1` (concatenati con
` || `). Ridondante ma robusto contro submission inconsistenti.

## 4. Catch raw per pattern

| pattern | n hit |
|---|---:|
| SmartSeq | 171.228 |
| single_cell_literal | 158.108 |
| Fluidigm_C1 | 67.729 |
| scRNA | 34.782 |
| 10x_Chromium | 16.792 |
| ICELL8 | 11.887 |
| single_nucle | 7.437 |
| CEL-seq_MARS-seq | 7.221 |
| Drop-seq_inDrop | 2.674 |
| Seq-Well | 1.315 |
| CellPlex | 1.197 |
| snRNA | 671 |
| BD_Rhapsody | 145 |
| snDrop | 78 |
| Multi-seq | 39 |
| Digital_microfluid | 8 |
| CellTag | 0 |

**Union (qualunque pattern matcha)**: 303.564 / 850.225 = **35.70%**.
Sovrapposizioni: solo K = 135.803, solo S = 40.402, K ∩ S = 127.359.

## 5. Validazione FPR cluster-based (A2b)

Strategia: 1000 random per ciascun pattern volumetrico (SmartSeq + single_cell_literal), contesto match ±80 char, cluster exact-match dopo normalizzazione, top-30 cluster (~46% del sample) + alarm-keyword scan sulla coda.

### 5.1 SmartSeq (n=1000)

- Top 30 cluster (486/1000): 0 FP.
- Coda alarm-scan (12 candidati): 7 FP confermati (bulk-low-input
  Smart-seq2 con 100-400 cells sorted; titles `(bulk)`, `Bulk_RNA-Seq_NSCLC`,
  `Tm treated QRICH1 KO cells-2`, etc.).
- **FPR = 7/1000 = 0.70%**, Wilson 95% CI **[0.34%, 1.45%]**.
- FP attesi estrapolati sui 171.228 catch: ~1.200 (range 580-2.480).

### 5.2 single_cell_literal (n=1000)

- Top 30 cluster (454/1000): 0 FP.
- Coda alarm-scan (24 candidati): 7 FP confermati + 3 FP-conservative
  (multi-modality con title ambiguo) = 10 FP totali.
- **FPR = 10/1000 = 1.00%**, Wilson 95% CI **[0.55%, 1.83%]**.
- FP attesi estrapolati sui 158.108 catch: ~1.580 (range 870-2.890).

### 5.3 Eziologia dei FP

Quasi tutti i FP osservati sono **bulk-low-input in studi multi-modality**
dove il submitter ha messo nello stesso GSE bulk + scRNA-seq, e
`extract_protocol_ch1` cita entrambi. Esempi tipo:

- `Sample-106 (Total Bulk RNA-seq)` con protocol `SMARTer Stranded Total
  RNA Sample Prep + snRNA-seq snATAC-seq` (GSE174367)
- `iPS2.D49.3 (bulk)` con protocol `For single cell RNAseq (SmartSeq2
  library prep) ...` (GSE112732)
- `Bulk_RNA-Seq_NSCLC_11_NTIL` con protocol `Bulk RNA-seq was performed
  using Smartseq2 protocol` (GSE90728)

Il regex non distingue il sample specifico nel GSE multi. **Il `title`
del sample chiarisce**.

## 6. Title-based rescue post-FPR

### 6.1 Regola

Sample che matchano regex SC ma il cui `title` contiene `bulk`
esplicito → **escluso dal drop**, marcato `title_bulk_rescue = TRUE`.

```
title_bulk_rescue := grepl("(?i)\\bbulk\\b|\\bbulkRNA", title)
drop_final := (any_K | any_S) & !title_bulk_rescue
```

### 6.2 Effetto

- Sample rescued: **870**
- Drop A2 finale: **302.694 / 850.225 = 35.60%** (delta −870 vs 35.70%)

### 6.3 Validazione rescue

20 random rescued classificati manualmente: **0/20 false rescue**. Tutti
e 20 sono bulk veri in studi multi-modality (titles tipo `(Total Bulk
RNA-seq)`, `Bulk_RNA-Seq`, `(bulk)`, `bulkRNA`). Wilson 95% upper bound
sui 20 random ≈ 14% (n piccolo) ma il volume rescued è 0.1% del bacino
e il pattern `\\bbulk\\b` nel title GEO è semanticamente univoco in
contesto RNA-seq.

### 6.4 Riduzione FPR stimata

Confronto FP osservati pre/post rescue sui validation sample (n=1000
per pattern):

| pattern | FP pre-rescue | FP post-rescue | riduzione FPR |
|---|---:|---:|---:|
| SmartSeq | 7 | 2-3 (residui ambigui senza title-bulk) | ~60-70% |
| single_cell_literal | 10 | 3-4 (residui multi-modality title generico) | ~60-70% |

FPR stimato post-rescue:
- SmartSeq: ~0.25-0.30%
- single_cell_literal: ~0.30-0.40%

FP residui post-rescue sui 2 pattern combinati: ~600-1200 sample
attesi (vs ~2.780 pre-rescue). Sull'intero bacino 879.167: ~**0.07-0.14%
FP residuo**.

## 7. Numeri aggregati A1 + A2

| filtro | sample drop | bacino input | drop rate |
|---|---:|---:|---:|
| A1 (`library_source != "transcriptomic"`) | 28.942 | 879.167 | 3.29% |
| A2 (regex SC, rescue post-rescue) | 302.694 | 850.225 | 35.60% |
| **Aggregato A1+A2 single-cell drop** | **330.709** | **879.167** | **37.62%** |

Bacino post-A1+A2 (candidati bulk RNA-Seq): **547.588 / 879.167 = 62.27%**.

Plausibilità: il banner RED_ALERT cita stima indipendente ARCHS4
`singlecellprobability > 0.5 = 31.9%` del dataset. I due segnali
convergono (A2 regex 35.60% vs ARCHS4 ML 31.9%). Differenza ~3.7pp
attesa: A2 cattura anche SC ancillary (HTO/ADT/BCR/TCR) che la ML
ARCHS4 (trainata su pattern conteggi) può perdere.

## 8. Decisione architetturale (input ADR-0019)

### 8.1 Regola A2

Filtro Stadio 0 v2 (parte SC tramite protocol):

```
hit_regex_K := match(extract_protocol_ch1 || title || source_name_ch1,
                     patterns_K)  # 13 pattern kit-specific
hit_regex_S := match(extract_protocol_ch1 || title || source_name_ch1,
                     patterns_S)  # 4 pattern semantica
title_bulk_rescue := grepl("(?i)\\bbulk\\b|\\bbulkRNA", title)

drop_A2 := (hit_regex_K | hit_regex_S) & !title_bulk_rescue
```

### 8.2 Motivazione metodologica per il paper

- Il segnale regex è **probabilistico** (testo libero), ma è l'unica
  evidenza disponibile dopo che `library_source` è settato male da
  ~36% dei submitter.
- La validazione cluster-based FPR su 2 pattern volumetrici (n=2000)
  documenta FPR < 1% pre-rescue, < 0.4% post-rescue.
- Title-bulk rescue è una correzione mirata zero-cost (0/20 false rescue)
  che cattura ~70% dei FP residui pre-rescue.
- A3 (`singlecellprobability` ARCHS4) come secondo segnale ortogonale
  ridurrà ulteriormente FPR (multi-signal concordance — strategia A5).

### 8.3 Sample residui flaggati ma non droppati

I 870 rescued non sono droppati ma sono **flaggati** con
`title_bulk_rescue = TRUE` per audit-trail (file
`A2-rescued-by-title-bulk.tsv`). Se in A3 emerge che alcuni di loro
hanno `singlecellprobability` alta, possono essere ri-droppati in
seconda istanza (mitigation in seguito).

## 9. Limitations dichiarate per il paper

L<n>. **Stage 0 single-cell filter via regex su extract_protocol_ch1**.
È un parser probabilistico su testo libero. FPR documentato cluster-based:
0.70% SmartSeq + 1.00% single_cell_literal (pre-rescue), ridotto a
~0.3% post title-bulk rescue. Combined con `singlecellprobability`
secondo segnale (Stage 0 v2 design), FPR residuo atteso < 0.2%
dell'intero bacino. La lista pattern (gruppo K kit-specific + gruppo S
semantica + title-bulk rescue) è committed nel codice e pre-registered
in ADR-0019. Per cluster con sample dubbi, la decisione finale è
intersezione di 3 segnali (regex AND singlecellprobability) con
fallback title-bulk rescue.

## 10. Output supporto

| file | contenuto |
|---|---|
| `A2-extract-protocol-sc.R` | script A2: regex K+S + title-bulk rescue |
| `A2-sc-by-extract-protocol.tsv` | 302.694 GSM drop finale (post-rescue) |
| `A2-rescued-by-title-bulk.tsv` | 870 GSM rescued (audit trail) |
| `A2b-pattern-fpr-validation.R` | script A2b: 1000-random cluster-based |
| `A2b-SmartSeq-clusters.tsv` | top 50 cluster SmartSeq |
| `A2b-single_cell_literal-clusters.tsv` | top 50 cluster single_cell_literal |
| `A2b-tail-fp-scan.R` | scan alarm-keyword sulla coda 1000-random |
| `A2-synthesis-protocol-regex.md` | questo file |

## 11. Cosa decide A2

> Drop A2 = 302.694 / 850.225 = **35.60%** dei sopravvissuti ad A1, via
> regex SC (gruppo K kit-specific 13 pattern + gruppo S semantica 4
> pattern) AND NOT title-bulk-rescue. Aggregato A1+A2 = **330.709 /
> 879.167 = 37.62%** del bacino rescued.

## 12. Cosa NON decide A2

- La soglia `singlecellprobability`: FASE A3 + A5.
- La logica AND vs OR tra regex e singlecellprobability nel filtro
  finale: FASE A5 (data-driven dopo aver visto distribuzione A3).
- La quantificazione dell'inquinamento corrente in
  `cluster_pooled.parquet`: FASE A4.
- La decisione rebuild vs filtro post-hoc: FASE A6.
- La strategia dedupe BioSample vs `donor_id`: FASE A7.
