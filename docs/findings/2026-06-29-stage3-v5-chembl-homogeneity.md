# Finding — Stadio 3 v5 (ChEMBL name-recovery): omogeneità small_molecule

**Data:** 2026-06-29 (sessione 21, RED ALERT F6, Plan B)
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Scope:** chiusura dei 3 run gated del Plan B (Task 8-10) — recupero nome
farmaci/small-molecule via ChEMBL → re-cluster Stadio 3 v5 → re-pool Stadio 4 v5 →
re-gate omogeneità.

---

## In una frase

Il recupero deterministico del nome dei composti via **ChEMBL** (49.099 molecole,
128.937 alias) ha **sciolto il "minestrone" `small_molecule` al livello biologicamente
rilevante**: ai livelli granulari L0/L1 (anchor = composto specifico) la frazione di
cluster-minestrone scende a **~8%**, pari a `disease_vs_normal` (7,7%). Il residuo
globale del 36,5% è dominato dai livelli aggregati L2-L4, dove il pooling raggruppa
*per classe ChEBI* (minestrone in larga parte *by-design*).

## I tre run (tutti su laptop, detached)

| Task | cosa | wall | output |
|---|---|---|---|
| 8 | re-cluster Stadio 3 → v5 | 400 min (~6h40) | `analysis/p4-output/20260629T041343Z-stage3-v5-364547a7/` (317.434 cluster, 546.885 assignment) |
| 9 | re-pool Stadio 4 Layer A → v5 | 619 min (~10h19) | `/sda/simulomicsr-stage4-v5/20260629T164735Z-stage4-v5-4f7ea215/` (7.362.958 righe pooled, 987.589 sig FDR<0,05) |
| 10 | re-gate omogeneità v5 | ~2 min audit | `analysis/audit/stage3-homogeneity-check-v5-full-out.{txt,csv}` |

- Task 8: `run_metadata.json` conferma `ontology_releases.chembl` reale
  (`chembl_37.db`, `fixture_subset:false`), cache lookup `v2`, assert `has_chembl` passato.
  Recovery via ChEMBL: `CHEMBL_ALIAS` 3.961 + `CHEMBL_VIA_CHEBI` 446 = 4.407 cluster.
- Task 9: **zero crash df-residui** su tutti i 348 mega_aug → fix `0c41848` validato sul
  full run. Stima DRY_RUN (164s/cluster=24h) pessimistica: i mega_aug viaggiano ~70-90s
  (cap `max_baseline_per_arm=350`), wall reale ~11h come da handout.

## Gate omogeneità — confronto v3 → v4 → v5

Frazione di cluster "minestrone" (mescolano ≥2 identità distinte sui GSM membri,
lato treated/case). Conteggio membri-only (review-fix 2026-06-26).

| kind | v3 (pre-rework) | v4 (post-disease, pre-ChEMBL) | **v5 (post-ChEMBL)** |
|---|---:|---:|---:|
| `disease_vs_normal` | 63,7% | 7,7% | **7,7%** |
| **`small_molecule`** | 70,2% | 49,0% | **36,5%** |
| `cytokine_stim` | 60,2% | 63,6% | **61,2%** |
| `pathogen_or_aggregate_exposure` | 67,2% | 38,2% | **33,0%** |
| **Totale** | 66,3% | 27,7% | **22,7%** |

Criterio handout **soddisfatto**: `small_molecule` scende nettamente sotto il 49% v4
(a 36,5%, −12,5pp / −25% relativo); nessun altro kind perturbativo peggiora.

## Il finding chiave: il residuo NON è name-recovery insufficiente

Dei 409 minestroni `small_molecule` residui, **399 (97,5%) hanno anchor `CHEBI:`**
(non `STR:`/`UNK`) → **non** è un problema di nomi mancanti. Il name-recovery ha
funzionato; il minestrone residuo è una questione di **granularità del pooling**.

### small_molecule minestrone% per livello anchor (v4 → v5)

| livello | v4 | **v5** | natura |
|---|---:|---:|---|
| L0 | 12,1% | **8,3%** | anchor = composto specifico |
| L1 | 12,4% | **7,9%** | anchor = composto specifico |
| L2 | 23,3% | 17,2% | aggregazione intermedia |
| L3 | 32,9% | 24,5% | pooling per classe |
| L4 | 40,7% | 31,7% | pooling per classe (anchor ID alti, fino a 39 composti-figli) |

- **L0+L1 (granulare): 8,1% minestrone** — pari a `disease` (7,7%). Qui il ChEMBL ha
  sciolto il minestrone.
- **L2+L3+L4 (aggregato): 26,7%** — dominano il residuo globale. A questi livelli il
  pooling raggruppa volutamente composti per antenato ChEBI; il gate conta ogni
  composto-figlio come "diverso" → li marca minestrone, ma è in parte *by-design*.
- Il ChEMBL migliora l'omogeneità a **ogni** livello (L0→L4 tutti in calo), quindi resta
  anche del minestrone "vero" recuperabile ai livelli alti (margine secondario).

## Finding minori (annotati, non bloccanti)

1. **Casing `ChEMBL:` vs `CHEMBL:`**: 20 cluster su 317.434 (0,006%) hanno il prefisso
   con casing del brand (`ChEMBL:`) invece di `CHEMBL:` → frammenterebbe quei 20 dal
   resto. Candidato micro-fix nel codice di normalizzazione per un rebuild futuro; non
   giustifica un re-run da 6h40.
2. **Stadio 4 v5 — 105 non-processable** su 533 Layer A (19,7%) — da caratterizzare
   (probabilmente rank-deficient, come nel v4).
3. **Dashboard quarto fallita** (non-fatale, nota): manca il binario `quarto` in PATH;
   i deliverable DE sono integri, ri-renderizzabile con `render_stage4_dashboard(out_dir)`.

## TODO (sessioni future, NON questa)

- **Biologici (cytokine/pathogen)**: `cytokine_stim` resta a 61,2% — il name-recovery
  Plan B copriva solo farmaci/small-molecule. Serve un vocabolario/fonte per i biologici
  (citochine/patogeni) + fix-tipo K3 (LPS/TNF/IL mal-etichettati small_molecule →
  pathogen/cytokine). Brainstorming dedicato.
- **LLM-fallback finale (DECISIONE C, generale)**: dopo tutto il recupero deterministico,
  i residui `STR:`/`UNK` di disease+small_molecule+farmaci si tentano con un LLM,
  precision-gated. Infrastruttura: `analysis/audit/name-recovery-llm-benchmark.R`.
- **Minestrone L3/L4 by-design vs reale**: valutare se il gate debba distinguere i pool
  gerarchici intenzionali dai minestroni veri ai livelli alti.

## Riproducibilità

```
# Task 8 (re-cluster): SMOKE=0 Rscript analysis/p4-fase-f6-stage3-reclustering.R
# Task 9 (re-pool):    Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v5.R
# Task 10 (gate):
Rscript analysis/audit/stage3-homogeneity-check.R \
  analysis/p4-output/20260629T041343Z-stage3-v5-364547a7 \
  analysis/input/human_gene_v2.5.h5  Inf Inf \
  analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl
```
