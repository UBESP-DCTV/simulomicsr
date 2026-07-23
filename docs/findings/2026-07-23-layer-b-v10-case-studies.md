# Layer B v10 — 18 case study publication-grade sulle meta-analisi nominate (rem_group)

**Data:** 2026-07-23
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Stato:** ✅ batch Layer B v10 completo (18/18 bundle + report HTML aggregato).
**Run:** notturno autonomo (handout `docs/superpowers/specs/2026-07-22-layer-b-v10-NEXT-SESSION-handout.md`).

## 0. Idea in una riga

Il deliverable finale della pipeline v10 è il **Layer B**: bundle publication-grade
(volcano/forest/MA/heatmap/heterogeneity/GO + top-gene table + summary card + narrative
stub) per una selezione curata delle **184 meta-analisi cross-studio nominate (rem_group)**
di v10 (ADR-0024). Questo run materializza **18 case study** (10 flagship validati opzione C
+ 8 extra), coprendo 7 malattie, 5 farmaci, 5 patogeni, 1 citochina/gene.

## 1. Esito del batch

| Voce | Valore |
|---|---|
| Case study generati | **18 / 18** (0 falliti) |
| Wall | **11,7 min** (laptop) |
| Plot generati / skippati | **108 / 18** |
| Report HTML aggregato | ✅ **reso** (`layer_b_report.html`, 35 MB, standalone embed-resources) |
| Output dir | `analysis/p4-output/20260722T215752Z-layer-b-d7a475bb/` (gitignored) |

Ogni bundle contiene 8 asset: `volcano.png/svg`, `forest.png`, `ma.png/svg`, `heatmap.png/svg`,
`heterogeneity.png/svg`, `go_enrichment.png` + `go_enrichment_table.csv`, `top_genes.csv/tex`,
`summary_card.md`, `captions.json`, `narrative.qmd` (stub da compilare per il paper).

I **18 skip** (`n_plots_skipped=18`, uno per cluster) sono i `forest.svg`: il forest REM usa
`metafor::forest()` in base-graphics, non trivialmente esportabile in SVG → `svg_path=NA`
by-design (`R/layer-b-plot-forest.R:159`). Il `forest.png` (300 DPI) è presente per tutti.
Alcuni `go_enrichment_table.csv` sono vuoti (nessun termine oltre soglia per quel cluster):
skip-graceful atteso, non un errore.

## 2. I 18 case study (valori risolti da Layer B)

`method = rem_group` per tutti. `k_effective`/`n_sig` sono ricalcolati da Layer B sul
`cluster_pooled.parquet` v10 (possono scostarsi ±1-3 dai valori della selection per il collapse
bracci intra-studio). ★ = flagship (priority 1, k_eff predetto=reale nel re-gate opzione C).

| # | label | agent_id | kind | tessuto | k_eff | n_sig(FDR<0,05) | ★ |
|--:|---|---|---|---|--:|--:|:-:|
| 1 | Carcinoma Renal Cell | MeSH:D002292 | disease | kidney | 6 | 7962 | |
| 2 | Lung Neoplasms | MeSH:D008175 | disease | lung | 5 | 3444 | |
| 3 | gastric cancer | MeSH:D013274 | disease | stomach | 6 | 4138 | |
| 4 | hepatocellular carcinoma | MeSH:D006528 | disease | liver | 36 | 3576 | ★ |
| 5 | colorectal cancer | MeSH:D015179 | disease | colon | 27 | 1037 | ★ |
| 6 | bleomycin A2 | CHEBI:3139 | small_molecule | prostate | 5 | 5483 | |
| 7 | physostigmine | CHEBI:27953 | small_molecule | prostate | 4 | 5141 | |
| 8 | RSV | NCBITaxon:12814 | pathogen | lung | 4 | 2725 | |
| 9 | TGFB1 | HGNC:11766 | cytokine/gene | lung | 5 | 2558 | |
| 10 | influenza virus | NCBITaxon:11309 | pathogen | lung | 12 | 1253 | |
| 11 | Lipopolysaccharide | CHEBI:16412 | pathogen(PAMP) | blood | 4 | 598 | ★ |
| 12 | SARS-CoV-2 | NCBITaxon:2697049 | pathogen | lung | 21 | 1646 | ★ |
| 13 | breast cancer | MeSH:D001943 | disease | breast | 7 | 686 | ★ |
| 14 | prostate cancer | MeSH:D011471 | disease | prostate | 8 | 553 | ★ |
| 15 | M. tuberculosis | NCBITaxon:1773 | pathogen | blood | 20 | 1322 | ★ |
| 16 | tamoxifen | CHEBI:41774 | small_molecule | breast | 8 | 454 | ★ |
| 17 | Enzalutamide | CHEBI:68534 | small_molecule | prostate | 32 | 3193 | ★ |
| 18 | fulvestrant | CHEBI:31638 | small_molecule | breast | 8 | 419 | ★ |

Copertura: **7 malattie · 5 farmaci · 5 patogeni · 1 citochina/gene**; kind_effective misto
(disease/small_molecule/pathogen/cytokine); tessuti kidney/lung/stomach/liver/colon/prostate/
breast/blood. Le 6 flagship-bandiera del re-gate opzione C (breast/colorectal/hepatocell/
enzalutamide/SARS/M.tuberc) sono tutte nel set, più tamoxifen/fulvestrant/prostate/LPS.

## 3. Bug scoperto e chiuso durante il run: Layer B non conosceva il method `rem_group`

Il run ha rivelato un **gap sistematico**: la macchina Layer B (progettata 2026-05-24, ADR-0017,
per i method `{mega, mega_aug, rem}`) è **anteriore al ramo `rem_group`** (ADR-0022, v8+). Poiché
la selection v10 è **interamente `rem_group`** (tutti group L4 nominati), il build casca. Due
fallimenti distinti, entrambi con la stessa causa radice ("`rem_group` non gestito"), chiusi in
blocco (no whack-a-mole) dopo aver mappato **tutti** i punti di dispatch su `method`:

1. **Dispatch dei campioni** (fatale sul 1° cluster): lo script `analysis/p5-stage4-layer-b-build-v10.R`
   costruiva solo `study_dispatch` (pair rem/mega_aug) e `group_dispatch` (mega puro), **senza**
   `.build_group_rem_dispatch_from_stage3` → nessun cluster rem_group risolto in campioni. Fix:
   aggiunto il dispatch rem_group + merge in `study_dispatch` (stesso schema `{study_id,treated,control}`),
   replica esatta di `R/stage4-build.R:158-171` (guard cluster_id disgiunti inclusa).
2. **Plot builder** (fatale sul forest del 1° cluster): `rem_group` non era nel dispatch di
   `.build_forest` (→ `cli_abort("Unknown method")`), né di `.build_heterogeneity_panel`
   (→ pannello "N/A" invece delle statistiche vere), né del τ² in `.build_summary_card`.
   `rem_group` **è** un metodo REM per-studio (`metafor::rma`, ADR-0022) con `tau2/I2/Q/k_effective`
   in `cluster_pooled` e `logFC/SE/study_id` in `per_study_de` (verificato: tutte le colonne non-NA):
   → instradato sul ramo `rem` esistente in tutti e tre i builder (`R/layer-b-plot-forest.R:132`,
   `R/layer-b-plot-heterogeneity.R:24`, `R/layer-b-summary-card.R:61`).

**Validazione prima di ogni rilancio** (non a intuito): (a) il dispatch fix risolve **18/18**
cluster in studi/campioni coerenti coi k_eff attesi; (b) `.build_forest` + `.build_heterogeneity_panel`
girano su dati reali di 3 cluster rem_group (breast/enzalutamide/M.tuberc) producendo i PNG; (c) i
test mirati `test-layer-b-{forest,heterogeneity,summary-card}.R` restano **33 PASS / 0 FAIL** (i cambi
sono additivi: rem/mega/mega_aug invariati). Il build completo poi produce il forest per tutti e 18.

**Perché è la scelta conservativa/paper-grade** (nota per l'autonomia): `rem_group` condivide con
`rem` la struttura statistica esatta (REM effect-size, τ² REML, per-study slab) — trattarlo come
`rem` non è un'assunzione ma un'identità di schema. L'alternativa (skip-graceful come per `mega`)
avrebbe prodotto forest/heterogeneity "N/A" per meta-analisi che invece HANNO quelle statistiche:
un deliverable degradato, non conservativo.

## 4. Deliverable / artefatti

- Bundle + report: `analysis/p4-output/20260722T215752Z-layer-b-d7a475bb/` (gitignored):
  18 sottodir + `layer_b_report.html` (35 MB) + `run_metadata.json` + `selection_resolved.csv`.
- Selection curata: `analysis/layer-b-selection-v10.csv` (18 case study, in git).
- Fix di codice (in git): `R/layer-b-plot-forest.R`, `R/layer-b-plot-heterogeneity.R`,
  `R/layer-b-summary-card.R`, `analysis/p5-stage4-layer-b-build-v10.R`.
- Log build: `analysis/p5-stage4-layer-b-build-v10.log`.

## 5. Prossimo

Compilare le `narrative.qmd` per-bundle (sezioni **Biological context / Findings / Discussion**)
per la sezione Results del paper. Il set copre 4 famiglie di perturbazione con effect-size pooled
random-effects nominati cross-studio — il valore unico della pipeline design-aware (ADR-0006).
Master invariato.
