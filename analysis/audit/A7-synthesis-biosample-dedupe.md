# A7 — Sintesi dedupe `relation` (BioSample SAMN) vs `donor_id` (LLM)

> **Data**: 2026-05-26.
> **Scope**: RED ALERT FASE A7 (Stadio 0 audit). Confronto qualità di
> due segnali ortogonali per identificare "stesso campione biologico in
> studi diversi": `meta/samples/relation` ARCHS4 (parsing SAMN BioSample)
> vs `donor_id` LLM-estratto in Stadio 1.
> **Output**: questo file è materiale evidence per ADR-0019 (FASE B1) e
> spec FASE E0 (dedupe implementation).
> **Branch**: `p5-llm-anchor-classification-audit`.

## 1. Universo analizzato

- Master rescued: **879.167** GSM (post-rescue cascade β).
- H5 ARCHS4 v2.5: 888.821 sample (subset al rescued via geo_accession).

## 2. Coverage 2×2 sui 879.167 rescued

| | donor_id presente | donor_id NA | totale |
|---|---:|---:|---:|
| SAMN presente | **246.780** | 632.217 | **878.997 (99.98%)** |
| SAMN NA | 72 | 98 | 170 (0.02%) |
| totale | 246.852 (28.08%) | 632.315 (71.92%) | 879.167 |

**Quadranti narrativi**:
- Both = 246.780 (28.07%) — SAMN e donor_id entrambi presenti.
- SAMN only = 632.217 (71.91%) — solo SAMN.
- donor only = **72 (0.01%)** — solo donor_id, no SAMN. Marginale.
- None = 98 (0.01%) — nessun segnale.

## 3. Duplicati cross-GSE

### 3.1 SAMN (segnale deterministico NCBI-controlled)

| metric | valore |
|---|---:|
| SAMN unique con valore | 878.620 |
| SAMN in >1 series_id | **176 (0.020%)** |
| GSM con SAMN cross-GSE | **425 (0.048%)** del bacino |

Distribuzione `n_distinct_series` per SAMN duplicato:

| n series | n SAMN |
|---|---:|
| 2 | 149 |
| 3 | 13 |
| 4-5 | 8 |
| 6-10 | 6 |
| >10 | 0 |

### 3.2 donor_id (segnale euristico LLM)

| metric | valore |
|---|---:|
| donor_id unique non-NA | 45.449 |
| donor_id in >1 series_id | **4.163 (9.16%)** |

**Top 20 donor_id più frequenti cross-GSE** (= falsi duplicati):

| donor_id | n_distinct_series |
|---|---:|
| `encdo000aad` | 415 |
| `1` | 234 |
| `encdo000aac` | 233 |
| `2` | 230 |
| `3` | 227 |
| `donor 1` | 216 |
| `donor 2` | 213 |
| `donor 3` | 174 |
| `patient 1` | 156 |
| `4` | 152 |
| `patient 2` | 145 |
| `patient 3` | 142 |
| `5` | 133 |
| ... | ... |

Eccetto `encdo000aad/aac` (= ENCODE Project donor IDs, riusati cross-studio),
i top sono **nomi generici**: numeri sequenziali (1, 2, 3, ...), label
`donor N`, `patient N`. Lo "patient 1" nel studio A NON è lo stesso individuo
di "patient 1" nel studio B. **donor_id LLM-estratto collassa cross-studio**.

### 3.3 Concordanza interna (sanity)

SAMN con >1 distinct donor_id (cioè LLM ha estratto donor_id diversi per
GSM dello stesso campione biologico): **0 / 246.546** dove entrambi
presenti. **Concordanza perfetta intra-SAMN**.

## 4. Decisione architetturale (input ADR-0019 + FASE E0 spec)

### 4.1 Regola

**Strategia dedupe**: `relation` BioSample SAMN come **segnale primario
e unico** per cross-study dedupe. donor_id LLM **NON usato** come fallback.

Implementazione (FASE E0):
- Nuova funzione `R/etl-archs4-utils.R::parse_biosample_id(relation_text)`
  che estrae `SAMN<digits>` da `relation` H5 via regex.
- Stadio 3 cluster summary `R/stage3-metadata.R::.enrich_cluster_metadata()`
  aggiunge `n_distinct_biosamples` come count `SAMN` unique per cluster.
- `donor_id` LLM resta in Stadio 2 (intra-studio replicate-group
  resolution dove funziona), ma NON viene esposto a Stadio 3.

### 4.2 Razionale

1. **Coverage**: SAMN copre 99.98% del bacino. Il 0.01% di donor-only
   non giustifica complessità del fallback.
2. **Determinismo**: SAMN è un ID controlled-vocabulary NCBI. donor_id
   LLM è estratto da testo libero `characteristics_ch1`.
3. **Anti-rumore cross-studio**: donor_id LLM produce 4.163 falsi
   duplicati cross-GSE (9.16% dei donor_id unique), perché nomi generici
   ("patient 1", "donor 2", numeri) si ripetono in studi indipendenti
   senza essere lo stesso individuo.
4. **Concordanza interna**: dove entrambi presenti, 0 conflitti. SAMN
   copre già il segnale utile completamente.

### 4.3 Alternative scartate

- **Union (SAMN ∪ donor_id)**: aggiunge 72 sample-level coverage (+0.01%)
  + 4.163 falsi duplicati cross-GSE. Tradeoff sfavorevole.
- **donor_id primario + SAMN fallback**: invertirebbe la fonte deterministica
  con l'euristica. Anti-pattern.
- **Combine intelligente (SAMN se presente, donor_id solo per SAMN-only)**:
  technically possibile ma complicato per <0.01% recovery. Non vale
  la pena di codice.

## 5. Implicazione paper

**425 GSM (0.048%) con SAMN cross-GSE** sono i veri duplicati cross-studio
del bacino rescued. Numero piccolo ma non zero. Va gestito per evitare
doppia-conta nei pool DE: due GSM con stesso SAMN ma serie diverse vanno
contati come 1 sample biologico (non 2) in Stadio 4 meta-analysis.

**Limitations sezione paper**:

L<n>. **Cross-study sample dedupe via BioSample SAMN only**. Il campo
`donor_id` LLM-estratto in Stadio 1 NON è esposto a Stadio 3 per
dedupe cross-studio perché produce falsi duplicati (9.16% donor_id
unique appaiono in >1 series_id). donor_id resta valido per intra-studio
replicate-group resolution in Stadio 2 (dove il submitter ha coerenza
locale dei nomi). Per cross-studio l'unico segnale affidabile è
`relation` BioSample SAMN (coverage 99.98%, deterministico).

## 6. Output supporto

| file | contenuto |
|---|---|
| `A7-biosample-vs-donor.R` | script A7 |
| `A7-biosample-donor-coverage.tsv` | 879.167 righe (geo, series, samn, donor_id, has_samn, has_donor, samn_is_cross) |
| `A7-cross-gse-duplicates.tsv` | 176 SAMN con cross-GSE n_distinct_series |
| `A7-discordant-samn-donor.tsv` | (vuoto: 0 conflitti) |
| `A7-synthesis-biosample-dedupe.md` | questo file |

## 7. Cosa decide A7

> **Strategia dedupe cross-studio = BioSample SAMN (`relation` H5 parsed)
> come segnale primario unico**. Coverage 99.98%, 425 GSM duplicati
> cross-GSE identificati. donor_id LLM NON usato per cross-studio
> (rumore 9.16% falsi duplicati con nomi generici).

## 8. Cosa NON decide A7

- L'implementazione del parser SAMN: FASE E0.
- L'integrazione di `n_distinct_biosamples` in `.enrich_cluster_metadata`:
  FASE E0.
- L'uso di `donor_id` in Stadio 2 (resta invariato, intra-studio):
  fuori scope Stage 0 audit.
