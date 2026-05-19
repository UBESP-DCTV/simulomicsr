# Esempi di meta-analisi cross-studio rese possibili (o amplificate) dal metodo simulomicsr Stadio 3

**Data:** 2026-05-19
**Branch / tag riferimento:** master @ `61a7b01` / `p5-stadio3-complete`
**Output ispezionato:** `analysis/p4-output/20260519T055547Z-stage3-2153addc/` (run_id `2153addc`,
267.056 cluster su 39.247 stage2 + 879.167 stage1 records, ARCHS4 human bulk RNA-seq).

## Contesto

Stadio 3 della pipeline simulomicsr produce due viste di cluster cross-studio:
- **anchor-pair** (input per random-effects meta-analisi, `metafor::rma`): coppie
  `(treated, control)` canonicalmente comparabili tra studi indipendenti;
- **anchor-group** (input per mega-analisi su raw counts ARCHS4): gruppi di
  sample che condividono lo stesso contesto sperimentale (cell line, tissue,
  trattamento o stato disease), riutilizzabili come shared baseline.

L'esplorazione dell'output (267.056 cluster, di cui 345 utilizzabili per REM
e 4.163 per mega-analisi relaxed) ha messo in luce quattro categorie di
casi che illustrano il valore del metodo, articolato come segue.

---

## Case 1 — Random-effects meta-analisi *textbook* (k≥3 cross-study)

**Cluster (livello L2):**

```
cytokine_stim | CHEBI:17236 | wt | exposure | HEK293 (CVCL_0023) |
cell_line_in_vitro | proliferating | whole_cell | lung | none
__VS__
vehicle_only | unknown | wt | exposure | HEK293 (CVCL_0023) |
cell_line_in_vitro | proliferating | whole_cell | lung | none
```

- **k = 4 studi indipendenti**: `GSE206784`, `GSE146403`, `GSE136864`, `GSE156295`
- 23 sample totali, safety_min = 0.5, direction = canonical
- A L2 sono droppati `dose_canonical` e `duration_canonical`: i quattro studi
  condividono ligando, cell line, contesto e direzione del confronto, varia
  solo dose o tempo.

**Cosa rende possibile**: con k = 4 la stima di τ² è identificabile in
`metafor::rma()` (DerSimonian-Laird) e il pooling random-effects produce
effect-size + intervallo di confidenza per ogni gene, con quantificazione
della between-study heterogeneity.

**Equivalente in letteratura senza simulomicsr**: RummaGEO (Maayan Lab, 2024)
classifica i quattro studi indipendentemente, producendo quattro gene-set
UP/DOWN; la sovrapposizione si misura via Jaccard, senza effect-size
quantitativo e senza modello mixed-effects per la heterogeneity. La nostra
pipeline produce direttamente l'input `(yi, vi)` di una meta-analisi proper.

---

## Case 2 — Mega-analisi con shared baseline (amplificazione di potere 10×)

**Cluster pair (livello L2):**

```
TREATED: small_molecule | CHEBI:17199 | wt | exposure | LNCaP |
         cell_line_in_vitro | proliferating | whole_cell | prostate | none
CONTROL: vehicle_only | unknown | wt | exposure | LNCaP |
         cell_line_in_vitro | proliferating | whole_cell | prostate | none
```

- **REM input limitato**: 2 studi (`GSE115395`, `GSE99795`), 33 sample
  totali. Con k = 2 metafor REM degenera a fixed-effect (τ² non
  identificabile).

**Augmentazione via mega-analisi**: lo *stesso* control anchor
(`vehicle_only|LNCaP|prostate|...`) compare in 50 cluster group-mode
distinti, riferiti a 50 studi diversi, per un totale di **361 sample
control LNCaP+vehicle** disponibili come pool condiviso.

Pool primi 10 GSE: `GSE117410, GSE252576, GSE99795, GSE236441, GSE145844,
GSE147876, GSE234110, GSE243329, GSE161691, GSE163109`.

**Cosa rende possibile**: invece di valutare l'effetto del piccolo molecule
CHEBI:17199 contro 16-17 control LNCaP del singolo studio originale, è
possibile costruire un modello misto su raw counts ARCHS4 in cui i sample
treated del cluster pair sono confrontati contro un baseline pool LNCaP da
361 sample cross-studio, con `study` come random effect. La precisione
sull'effetto-trattamento aumenta di ~10× rispetto alla REM disponibile.

**Equivalente in letteratura senza simulomicsr**: l'idea di riutilizzare
sample di studi diversi come shared baseline richiede di averli classificati
con la *stessa* identità canonical. Senza l'anchor v3 di simulomicsr
(`vehicle_only|unknown|LNCaP|prostate|...`), questi 50 studi sono noti
ad ARCHS4 come "control" del loro proprio studio, ma il loro stato
"comparabile a un altro treatment" non è esplicitato in alcun database
pubblico. La nostra pipeline è la prima a renderli un asset riutilizzabile.

---

## Case 3 — Disease cohort case-vs-control replicato

**Cluster pair (livello L0, anchor strict, safety_min = 1.0):**

```
pathogen_or_aggregate_exposure | Tuberculosis | wt | exposure | Plasma |
primary_tissue | proliferating | whole_cell | plasma | case
__VS__
none | unknown | wt | exposure | Plasma | primary_tissue |
proliferating | whole_cell | plasma | none
control_type = disease_normal
```

- **2 studi indipendenti**, 58 sample totali, direction = canonical
- Variante parallela (Plasma cell-free RNA invece di Plasma totale): k = 2,
  69 sample, safety = 1.0
- Entrambi cluster contengono coppie `(case = pazienti TB, control =
  donatori sani)` con assegnazione del ruolo confermata
  cross-studio dalla pipeline LLM Stage 2.

**Cosa rende possibile**: meta-analisi proper di biomarker plasma per
diagnosi TB cross-cohort. Per la natura `disease_vs_normal` del design,
la pipeline ha (a) impostato `kind_effective="disease_vs_normal"` come
override anchor, (b) assegnato `disease_status="case"` ai pazienti TB e
"none" ai control, (c) confermato che la *direzione* del contrasto è
canonical (case→treated, control→control) in entrambi gli studi.

**Equivalente in letteratura senza simulomicsr**: un'analisi K-means +
keyword come quella di RummaGEO confonde "case" con "treatment" (sample
treated = chiunque non sia un "ctrl" testuale) e non distingue
case-control da treatment-control. Le pipeline di harmonization base
(MetaSRA, MetaHQ) classificano i sample con tissue/disease ontology ma
non producono coppie comparison.

---

## Case 4 — Shared baselines giganti (territorio mega-analisi-only)

I sei cluster group più popolosi a livello L4 (anchor ridotto al solo
tier S = `kind | agent | tissue`):

| Anchor | k_studi | n_sample |
|---|---:|---:|
| `none \| unknown \| blood` | 953 | 18.448 |
| `vehicle_only \| unknown \| blood` | 668 | 8.629 |
| `none \| unknown \| brain` | 596 | 11.488 |
| `none \| unknown \| skin` | 440 | 6.706 |
| `vehicle_only \| unknown \| breast` | 355 | 1.517 |
| `none \| unknown \| bone marrow` | 301 | 7.098 |

**Cosa rende possibile**: per ogni perturbazione studiata in uno dei
sei tessuti, anche se in *un solo studio originale*, è possibile
computare una distribuzione di riferimento empirica su centinaia di
studi e migliaia di sample cross-studio. Questo abilita:

1. Z-score normalizzati di una signature transcriptomica di interesse
   rispetto a una distribuzione robusta "tissue-X-baseline";
2. Identificazione di geni con eterogeneità basal alta (poco utili
   come biomarker) vs geni con eterogeneità basale bassa (alta utilità
   discriminativa);
3. Pooling cross-study di treatment specifici contro un comune denominator
   "untreated tissue" cui contribuiscono fino a 953 studi.

**Equivalente in letteratura senza simulomicsr**: nessuno espone
esplicitamente quali studi GEO siano cross-comparabili come baseline.
ARCHS4 fornisce raw counts allineati ma non l'anchor canonical; MetaHQ
classifica tissue/disease ma non separa "untreated" da "perturbed"; la
classificazione design_role di simulomicsr è il primo passo che rende
questi 953 studi un *asset coerente* riutilizzabile.

---

## Riassunto del valore metodologico

| Capability | Cluster simulomicsr | Stato dell'arte |
|---|---:|---|
| REM con k ≥ 3 cross-study identificati | 35 | Nessuno: RummaGEO non fa effect-size meta-analisi |
| Pair anchor canonical match cross-study (k ≥ 2) | 345 | RummaGEO via signature overlap (Jaccard non quantitativo) |
| Shared baseline cross-study (k ≥ 100) | 6 tessuti (blood, brain, skin, ecc.) | Nessuno espone l'asset esplicitamente |
| Disease cohort case_vs_control replicate | 5 cluster (TB, brain) | Nessuno fa primary_role-aware case_vs_control cross-study |

Il valore unico di simulomicsr non risiede nelle dimensioni della
classificazione (i 879k sample di stage1 sono già coperti da ARCHS4 +
MetaSRA + MetaHQ), né nell'estrazione di metadati ricchi (Mondal et
al. 2025 ottiene copertura comparabile con un sistema multi-agent).
Risiede nel **rendere comparabili** cross-studio gruppi di sample
attraverso un anchor canonicalizzato design-aware, e nel produrre
direttamente l'input quantitativo per `metafor::rma()` (REM) e per
modelli misti su raw counts (mega-analisi).

Riferimenti:
- Spec design: `docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md`
- ADR 0014: `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md`
- ADR 0006 (positioning vs RummaGEO/MetaSRA/MetaHQ): `docs/decisions/0006-stato-arte-vs-simulomicsr.md`
- Output run β: `analysis/p4-output/20260519T055547Z-stage3-2153addc/`

**Caveat sulla risoluzione `agent_id`**: in alcuni casi (es. CHEBI:17236,
CHEBI:17199 sopra) l'identificatore ChEBI estratto dallo Stadio 2 LLM può
non corrispondere alla classificazione `kind_effective` (es. CHEBI:17236
classificato come `cytokine_stim`). Per la canonicalizzazione cross-study
quello che conta è che gli studi nel cluster siano *internamente
consistenti*: cioè i 4 studi del Case 1 hanno tutti classificato lo stesso
agente con lo stesso ChEBI ID e lo stesso `kind_effective`. Verifica
manuale dell'ID è raccomandata prima di pubblicare meta-analisi specifiche
basate su un cluster.
