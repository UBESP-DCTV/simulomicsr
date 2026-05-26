# A4 — Sintesi contaminazione `cluster_pooled.parquet` + A5/A6 chiusura

> **Data**: 2026-05-26.
> **Scope**: RED ALERT FASE A4 + A5 + A6 (Stadio 0 audit). Quantificazione
> contaminazione single-cell del run Stadio 4 baseline (`96c43acb`,
> `cluster_pooled.parquet`) tramite cross-reference con drop list A1+A2+A3.
> **Output**: questo file è materiale evidence per ADR-0019 (FASE B1) e
> finding paper-grade G2 (FASE G2).
> **Branch**: `p5-llm-anchor-classification-audit`.

## 1. Universo analizzato

- Run Stadio 4 baseline: `analysis/p4-output/20260523T032601Z-stage4-96c43acb/`
- Cluster Layer A processati con successo: **487** (182 `group_mega` +
  305 `pair_mega_aug`). 622 cluster dispatched dallo Stadio 3, 135
  finiti in `qc_drops_cluster` (sotto-soglia QC). Lavoriamo sui 487.
- Mapping cluster_id → GSM ricostruito via
  `assignments.parquet` (707k) + Stage 2 `collect.rds` (39k predictions)
  usando le funzioni interne `simulomicsr:::.build_*_dispatch_from_stage3`.

## 2. Drop list union

| filtro | n GSM |
|---|---:|
| A1 (`library_source` non-`transcriptomic`) | 28.015 |
| A2 (regex SC + post title-bulk rescue) | 302.694 |
| A3 scprob ≥ 0.9 | 1.225 |
| A3 lib_size < 500.000 (QC) | 38.846 |
| **Union SC-only (A1+A2+A3-scprob)** | **331.934** |
| Union ALL (incl. lib_size QC) | 370.780 |

Per A4 usiamo `Union SC-only` come "drop list di interesse" (l'inquinamento
SC del cluster_pooled). `lib_size QC` è filtro Stadio 4 condiviso, già
applicato a `cluster_pooled.parquet` e quindi non più presente nei 487
cluster osservati.

## 3. Distribuzione `frac_sc` per bucket × method

`frac_sc` = `n_sample_drop_SC / n_sample_totali` per cluster.

| bucket frac_sc | mega (group) | mega_aug (pair) | totale | % di 487 |
|---|---:|---:|---:|---:|
| 0% (clean) | 56 | 281 | **337** | **69.2%** |
| 0-1% | 3 | 0 | 3 | 0.6% |
| 1-10% | 43 | 0 | 43 | 8.8% |
| 10-50% | 53 | 7 | 60 | 12.3% |
| 50-99% | 17 | 8 | 25 | 5.1% |
| 100% | 10 | 9 | **19** | **3.9%** |

**Aggregati**:

| metric | valore |
|---|---:|
| cluster clean (frac_sc = 0%) | 337/487 = **69.2%** |
| cluster contaminati (frac_sc > 0) | 150/487 = **30.8%** |
| cluster heavily contaminati (frac_sc ≥ 50%) | 46/487 = 9.45% |
| cluster 100% SC | 19/487 = 3.9% |
| sample SC nei pool (sample-level) | 2.928 / 19.405 = **15.09%** |
| size cluster: median / mean / max | 20 / 40 / 544 |

## 4. Pattern paper-grade per method

| method | clean | contaminato | pattern |
|---|---:|---:|---|
| `group_mega` (n=182) | 56 (31%) | **126 (69%)** | contaminazione **diffusa** lungo tutti i bucket (3+43+53+17+10) — MEGA pure aggrega tutti i sample del GSE indipendentemente dal design |
| `pair_mega_aug` (n=305) | 281 (92%) | 24 (8%) | contaminazione **rara ma "tutto-o-niente"** (0+0+7+8+9) — pair-mode parte da comparison esplicite curate dal submitter |

Interpretazione biologica: i cluster `group_mega` ereditano contaminazione
più alta perché aggregano tutti i sample di un GSE — inclusi i companion
SC ancillary library (HTO/ADT/BCR) e gli scRNA-seq paralleli che il
submitter ha pubblicato nello stesso accession. I cluster `pair_mega_aug`
filtrano implicitamente per comparison esplicite (treated_vs_control), che
il submitter ha curato meglio; quando contaminati, però, sono tipicamente
100% SC (interi studi single-cell mascherati come bulk).

## 5. Decisione A5 — soglia `singlecellprobability` (chiusura)

Confermata in A3 + verificata in A4: **th = 0.9** (plateau curva FPR
proxy + manual 8% Wilson 95% CI [3-19%]). A4 conferma che la soglia 0.9
non è eccessiva: anche a 0.9 il sample SC nei pool è 15%, sopra 0.5 sarebbe
nettamente di più ma con FPR alto.

## 6. Decisione A6 — rebuild vs filtro post-hoc (chiusura)

Soglia operativa del RED_ALERT (§A6): "Se inquinamento basso (<5% cluster
con frac_sc > 0), potrebbe essere sufficiente filtro post-hoc".

Risultato: **30.8% cluster con frac_sc > 0** = **6.16× sopra soglia**.

**Decisione: REBUILD TOTALE OBBLIGATORIO**.

Razionale data-driven:

1. **31% cluster contaminati** è pattern sistemico, non outlier.
2. **15.09% sample SC nei pool** distorce in modo non recuperabile le
   statistiche DE (logFC, SE, p-value, k_effective, FDR within-cluster).
   Distribuzione count SC vs bulk hanno variance/dispersion incompatibili
   con assunzioni limma-voom/dream.
3. **46 cluster (9.45%) con ≥50% SC** non sono interpretabili
   biologicamente: l'effetto stimato è dominato dal segnale SC.
4. **19 cluster (3.9%) sono 100% SC** — devono essere completamente
   eliminati, non corretti.
5. Anche per i 337 cluster "clean" (frac_sc=0%), il rebuild è
   coerentemente necessario perché Stadio 3 anchor v3.1.1 ha cambiato
   il vocabolario (audit ontology precedente, ADR-0018 Proposed).

Filtro post-hoc non è sufficiente perché:
- Anche escludendo i 150 cluster contaminati, i 337 cluster "clean"
  restano basati su anchor v3 obsoleto (Carnitine-as-pathogen,
  Ethanol-as-cytokine bug paper-grade).
- Lo Stadio 0 v2 rebuild risana entrambi (SC filter + ontology override).

## 7. Conseguenze sul resto del RED_ALERT

A6 confermato rebuild ⇒ FASE F (re-run pipeline) è obbligatoria, NON
opzionale. Conferma il workflow del RED_ALERT:

- F1 ETL re-run con filtro v2 (Stage 0)
- F2 Stadio 1 fullrun DGX
- F3 Stadio 2 fullrun DGX
- F4 Stadio 3 rebuild (anchor v3.1.1)
- F5 Stadio 4 Layer A rebuild
- F6 Layer B re-selection + rebuild

Il run baseline `96c43acb` (Layer A) e il run Layer B `56b911e6` (15
case study) sono **obsoleti**. Non utilizzabili per il paper Results.

## 8. Output supporto

| file | contenuto |
|---|---|
| `A4-cluster-pooled-contamination.R` | script A4 |
| `A4-cluster-contamination.tsv` | 487 righe (cluster_id, method, n_total, n_drop_a1, n_drop_a2, n_drop_a3_scprob, n_drop_a3_libsize, n_drop_union_sc, frac_sc) |
| `A4-synthesis-cluster-contamination.md` | questo file |

## 9. Cosa decide A4 + A5 + A6

> **A4**: 30.8% dei 487 cluster Layer A baseline contiene almeno 1
> sample SC (Union A1+A2+A3-scprob). 15.09% dei sample aggregati nei
> pool è SC. 9.45% cluster con ≥50% SC.
>
> **A5**: soglia singlecellprobability = **0.9** (plateau curva FPR,
> chiusa in A3).
>
> **A6**: **rebuild totale OBBLIGATORIO** (data-driven, 6x sopra soglia
> 5%). Filtro post-hoc respinto. FASE F del RED_ALERT non opzionale.

## 10. Cosa NON decide A4

- La strategia dedupe BioSample (`relation`) vs `donor_id` LLM: FASE A7.
- Il codice del filtro v2 Stadio 0: FASE C (post-ADR-0019).
- Il prompt Stadio 1 con `molecule_ch1`: FASE D (gate utente).
