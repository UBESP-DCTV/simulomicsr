# A1 — Sintesi audit `library_source` ARCHS4 (input per ADR-0019)

> **Data**: 2026-05-26.
> **Scope**: RED ALERT FASE A1 (Stadio 0 audit). Audit del campo
> `meta/samples/library_source` su tutti i 879.167 GSM del master rescued
> ARCHS4 v2.5 human (`p4-beta-stage1-master-predictions-rescued.jsonl`).
> **Output**: questo file è il materiale evidence per ADR-0019
> (FASE B1) e per il finding paper-grade G2 (FASE G2).
> **Branch**: `p5-llm-anchor-classification-audit`.

## 1. Universo analizzato

- N record master rescued: **879.167**.
- Match con `meta/samples/geo_accession` H5: 879.167 / 879.167 (no miss).
- Sanity filtri Stadio 0 attuali:
  - `organism_ch1`: 100% `Homo sapiens` (879.167 / 879.167).
  - `library_strategy`: 100% `RNA-Seq` (879.167 / 879.167).

I filtri esistenti `(organism + library_strategy)` sono coerenti col master,
quindi nessuna sorpresa upstream da quel lato. Il problema sta sul campo
non filtrato `library_source`.

## 2. Distribuzione `library_source` sui 879.167 rescued

Comando: subset H5 → master GSM, poi tabulazione `meta/samples/library_source`.

| `library_source` | n | % |
|---|---:|---:|
| `transcriptomic` | 850.225 | 96.71% |
| `transcriptomic single cell` | 27.971 | 3.18% |
| `genomic` | 634 | 0.07% |
| `other` | 293 | 0.03% |
| `genomic single cell` | 44 | 0.005% |
| **totale** | **879.167** | **100.00%** |

Tutti i 4 valori non-`transcriptomic` sono problematici per assunzioni
bulk-RNA-seq, per motivi diversi (sezioni 3-5).

## 3. Single-cell esplicito (A1)

**28.015 sample = 3.19% del bacino**, distribuiti su 848 studi.

Breakdown per `series_id` (frac di sample SC nello studio):

| frac_sc | n studi |
|---|---:|
| 1-10% | 4 |
| 10-50% | 40 |
| 50-99% | 20 |
| **100%** | **784** |

- 784 / 848 studi (92.5%) sono **100% SC** → drop study-level pulito.
- **64 studi sono mixed** (frac_sc 1-99%) → vedi sezione 4. Vanno gestiti
  *sample-level*, non study-level.

Output supporto:
- `analysis/audit/A1-single-cell-by-library-source.tsv` (28.015 GSM + series_id + libsrc).
- `analysis/audit/A1-single-cell-series-breakdown.tsv` (848 studi).

## 4. 64 studi mixed (A1b)

Ispezione manuale su 6 studi paradigmatici
(`analysis/audit/A1b-mixed-studies-detail.tsv`) ha identificato 3 pattern:

1. **Multi-modality dichiarato** (dominante: es. GSE254205, GSE173950,
   GSE179159, GSE145862, GSE231523): gli autori pubblicano deliberatamente
   bulk + SC dello stesso tessuto/condizione nella stessa GSE. Non è un
   errore di submission.
2. **SC ancillary library mascherato come `other`** (GSE231523 con 1
   sample HTO-derived cDNA, `libsrc=other`): collaterale del workflow SC,
   non bulk.
3. **Sample disomogeneo / submission error** (GSE213972: 1 SC su hESC in
   studio bulk di Kidney organoid): single sample fuori contesto.

**Conseguenza operativa**: per i 64 mixed il filtro Stadio 0 deve agire
*sample-level* (drop i sample SC), non *study-level*. I sample bulk dei
medesimi studi (~640 sample) restano validi.

## 5. `library_source = "other"` — 293 sample, 56 studi (A1c)

Concentrazione: top 5 studi coprono 117/293 (40%), mediana 2 sample/studio.

Composizione (keyword scan + ispezione 30 esempi):

| sotto-cluster | n stimato | motivazione drop |
|---|---:|---|
| SC ancillary library (HTO, ADT, BCR, TCR, CITE, CellTag, CellPlex) | ~141 | Librerie companion del workflow scRNA-seq dello stesso studio, NON misurano bulk transcriptome |
| 4sU-labelled / TT-seq / metabolic labeling (GSE237457-460) | ~35 | Misura *newly-synthesized RNA*, non steady-state |
| Polysome profiling RNA-seq (GSE262593-262597) | ~28 | Misura mRNA *legato a ribosomi*, non transcriptome |
| mRNA + gDNA combo-seq custom (GSE223145) | ~22 | Stesso pool nucleic acid mRNA+gDNA, non bulk standard |
| Digital microfluidics SC (GSE240579) | ~3 | SC custom (sotto-detected da regex) |
| RIP/CLIP / RNase T1 enrichment (GSE256250) | ~3 | RNA proteina-bound, non transcriptome |
| Possibile bulk standard mis-labeled (GSE248039 NucleoSpin RNA Mini) | ~12 | Edge case: bulk reale settato in `other` per errore submitter |

**Conclusione**: la stragrande maggioranza dei 293 viola l'assunzione bulk
steady-state. Quota "salvabile" stimata: ~12 sample (GSE248039) = 0.001%
del bacino → drop accettabile per coerenza, da menzionare in supplementary.

Output supporto: `analysis/audit/A1c-libsrc-other-detail.tsv` (293 sample).

## 6. `library_source = "genomic"` — 634 sample, 68 studi (A1d)

Concentrazione: top 5 studi coprono 224/634 (35%), top 20 coprono ~440/634
(70%).

### 6.1 Inconsistenza metadata GEO

| campo | distribuzione sui 634 |
|---|---|
| `library_selection` | 634 / 634 = `cDNA` |
| `molecule_ch1` | 558 `genomic DNA`, 62 `total RNA`, 14 `protein` |

Per definizione GEO: `library_strategy=RNA-Seq` + `library_selection=cDNA`
(la libreria è cDNA) ma `library_source=genomic` + `molecule_ch1=genomic DNA`
(la fonte sarebbe gDNA). I tre campi controllati sono incoerenti tra loro
→ metadata sloppy dal submitter.

### 6.2 Composizione effettiva (keyword scan)

| categoria | n | esempio |
|---|---:|---|
| ATAC-seq mascherato | 25 | GSE207654 `ATAC-seq_iMK-D7-rep1` |
| ChIP-seq mascherato | 40 | GSE173568 `127495 S11 27ac` (CUT&Run/ChIP) |
| WGBS / RRBS / methyl | 11 | GSE178798 `WGBS is generated using Truseq DNA methylation kit` |
| scATAC | 3 | — |
| CUT&Run | 1 | — |
| gDNA amplicon / PCR puro | 123 | GSE266289 `Genomic DNA was subjected to 35 cycles of PCR` |
| ADT/protein (CITE-seq) | (14 by `molecule_ch1=protein`) | GSE186267 `COVID-19 blood rep3 (ADT)` |

### 6.3 Sintesi 3 cluster

1. **~80-100 NON-RNA-Seq mascherati** (ATAC + ChIP + WGBS + scATAC + CUT&Run
   + gDNA-PCR puro): submitter ha settato `library_strategy=RNA-Seq`
   erroneamente. NON sono RNA-Seq.
2. **~14 ADT/CITE-seq SC ancillary** (`molecule_ch1=protein`): coerenti
   col cluster `other` (SC companion library).
3. **~520 bulk RNA-Seq mainstream con metadata sloppy**: title/protocol
   dichiarano chiaramente RNA-Seq (`MM.1S A-485 RNA-Seq rep1`,
   `liverTissue_RNA-seq_sample_SJLB438`, `T47D_WT_clone2_E2_5day_RNAseq`,
   TRIzol/RNeasy + TruSeq Stranded mRNA-seq) ma submitter ha riempito
   `library_source` + `molecule_ch1` in modo inconsistente. Sono
   "salvabili" in teoria, ma sono **untrusted metadata**: chi sbaglia
   3 campi controllati GEO è plausibile sbagli anche
   `characteristics_ch1` (testo libero) su cui l'LLM ragiona.

Output supporto: `analysis/audit/A1d-libsrc-genomic-detail.tsv` (634 sample).

## 7. Decisione architetturale: whitelist `library_source == "transcriptomic"`

### 7.1 Regola

Filtro Stadio 0 esteso (v2):

```
keep = (organism_ch1 == "Homo sapiens")
     & (library_strategy == "RNA-Seq")
     & (library_source == "transcriptomic")
     & (nchar(string) >= 20)
     & ... (altri filtri SC: vedi FASE A2, A3 per extract_protocol e singlecellprobability)
```

Drop totale dal filtro `library_source` sole: **28.942 / 879.167 = 3.29%**.

### 7.2 Motivazione puntuale per ciascun valore escluso

| Valore escluso | n | Motivazione |
|---|---:|---|
| `transcriptomic single cell` | 27.971 | SC-seq: distribuzione count sparsa, dropout, varianza ZINB. Incompatibile con assunzioni di limma-voom / dream (bulk negative binomial steady-state). Dichiarazione esplicita del submitter GEO, deterministico. |
| `genomic single cell` | 44 | Single-cell DNA-seq (mutational profiling), non transcriptome. |
| `genomic` | 634 | (a) ~80-100 sono ATAC/ChIP/WGBS/gDNA-PCR mascherati come `library_strategy=RNA-Seq` (submitter mistake); (b) ~14 ADT/CITE-seq ancillary `molecule_ch1=protein`; (c) ~520 bulk RNA-Seq con metadata GEO incoerenti su 3 campi controllati (`library_source=genomic` + `molecule_ch1=genomic DNA` ma `library_strategy=RNA-Seq` + `library_selection=cDNA`) → unfit per pipeline metadata-driven. |
| `other` | 293 | (a) ~141 SC ancillary (HTO/ADT/BCR/TCR/CITE/CellTag/CellPlex); (b) ~152 metodi che violano assunzione bulk steady-state (4sU/TT-seq, polysome profiling, RIP/CLIP, mRNA+gDNA combo, digital microfluidics). |

### 7.3 Razionale whitelist > blacklist

1. **Future-proof**: future versioni ARCHS4 potrebbero introdurre nuovi
   valori (`spatial transcriptomic`, `metatranscriptomic`) che devono
   defaultare a *drop* (richiede review esplicito), non a *include*.
2. **Riduzione superficie di errore**: solo `transcriptomic` è
   esplicitamente safe per le assunzioni del modello DE downstream.
3. **Trust-by-construction**: il campo `library_source` è controllato GEO
   (vocabolario chiuso). Limitare il filtro all'unico valore safe nel
   vocabolario è la regola più stringente esprimibile.

### 7.4 Counter-fattuale (cosa perdiamo)

- ~520 bulk RNA-Seq mainstream in `library_source=genomic` con metadata
  sloppy (sezione 6.3 cluster 3): ~0.06% del bacino.
- ~12 bulk RNA-Seq in `library_source=other` (GSE248039): ~0.001% del bacino.
- Totale "perdita potenziale di sample bulk legittimi": ~530 sample (0.06%).

Tradeoff: rinunciamo a 0.06% di sample per garantire che il restante 96.71%
(850.225) sia bulk-RNA-Seq con metadata GEO coerente. **Tradeoff favorevole**
per un paper che si dichiara "bulk RNA-seq meta-analysis cross-study".

### 7.5 Conseguenza sulla gestione dei 64 studi mixed

Anche col filtro `library_source == "transcriptomic"`, i 64 studi mixed
restano con i loro sample bulk (~640 sample) intatti: solo i sample SC
all'interno di quegli studi cadono. Il filtro è quindi *sample-level
intrinsecamente*, non *study-level*: non serve logica aggiuntiva per
i mixed.

## 8. Output supporto (committati in `analysis/audit/`)

| file | contenuto |
|---|---|
| `A1-library-source-count.R` | script A1: conta + breakdown per studio |
| `A1-single-cell-by-library-source.tsv` | 28.015 GSM SC + series_id + libsrc |
| `A1-single-cell-series-breakdown.tsv` | 848 studi con almeno 1 sample SC |
| `A1b-mixed-studies-investigation.R` | script A1b: ispezione 64 mixed |
| `A1b-mixed-studies-detail.tsv` | 4 sample × 64 series per ispezione manuale |
| `A1c-libsrc-other-investigation.R` | script A1c: ispezione `other` |
| `A1c-libsrc-other-detail.tsv` | 293 sample `library_source=other` |
| `A1d-libsrc-genomic-investigation.R` | script A1d: ispezione `genomic` |
| `A1d-libsrc-genomic-detail.tsv` | 634 sample `library_source=genomic` |
| `A1-synthesis-libsrc-whitelist.md` | questo file |

## 9. Cosa decide A1 (riassunto in 1 frase)

> Filtro Stadio 0 v2 adotta la **whitelist `library_source == "transcriptomic"`**
> come regola pulita e future-proof; drop atteso 28.942 / 879.167 = **3.29%**
> con motivazione puntuale per ciascuno dei 4 valori esclusi (sezione 7.2).

## 10. Cosa NON decide A1

- Il filtro `extract_protocol_ch1` per single-cell mascherato come
  `library_source=transcriptomic`: FASE A2.
- La soglia `singlecellprobability`: FASE A3 + A5.
- La quantificazione dell'inquinamento corrente in `cluster_pooled.parquet`:
  FASE A4.
- La decisione binaria rebuild vs filtro post-hoc: FASE A6.
- La strategia dedupe BioSample vs `donor_id`: FASE A7.
