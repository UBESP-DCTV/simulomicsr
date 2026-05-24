# Stadio 4 Layer B — Showcase case study generator (design spec)

**Stato:** draft 2026-05-24 — in attesa di review utente
**Branch target:** `p5-stadio4-layer-b` (da creare partendo da `master` @ `a6c7ccf` / tag `p5-stadio4-complete`)
**Predecessore:** P5 Stadio 4 Layer A complete (run_id `96c43acb`, 622/622 cluster OK, 487 cluster pooled mega+mega_aug, dashboard 74 MB)
**Successore previsto:** Curation human-driven dei case study (output Layer B integrato nel paper Results) + eventuale Stadio 5 metafor REM standalone se future Stage 3 runs producono REM proper (0 in run β attuale).
**Decisioni rilevanti:**

- Finding scope decision (2026-05-19): Layer B = ~10-20 case study curati a mano, "showcase" per paper Results
- ADR-0006 (positioning): Layer B è dove la pipeline produce evidence biologica narrabile, complementare al deliverable batch Layer A
- ADR-0015 (Stage 4 architecture): Layer B consuma read-only il `cluster_pooled.parquet` + `per_study_de.parquet` di Layer A
- User feedback `validate-before-fullrun`: smoke 3-cluster pre-batch è gate obbligatorio
- User feedback `pipeline-config-uniformity`: config Layer B mirror dello stile Layer A (config list + `run_id` deterministico + dir output versionata)
- User DE methods benchmark: limma-voom best, già usato in Layer A; Layer B non re-fa DE, consuma il pooled output

**ADR proposto con questo spec:** **ADR-0017** — Layer B case study generator architecture (CSV-driven selection + 8-plot publication-grade asset bundle per cluster + Quarto aggregate report).

---

## 1. Contesto e obiettivo

Stadio 4 Layer A ha prodotto effect-size pooled per 487 cluster cross-studio (mega 182 + mega_aug 305), con dashboard interattiva che include un picker (Sezione 5) che suggerisce candidati Layer B via score composto `(n_sig_FDR05 × log(k_eff)) / (1 + tau2_median)`.

Il finding scope decision 2026-05-19 stabilisce che il paper deve includere **10-20 case study "showcase"** con biological narrative interpretata, ognuno con figure publication-grade dedicate (1-2 figure per case study nel Results del paper).

Layer B è la **pipeline semi-automatica** che, data una selezione manuale di cluster_id curata dall'utente, produce per ogni cluster un bundle di asset publication-ready (plot + tabelle + template narrative) + un report aggregato HTML standalone per visualizzazione/condivisione.

**L'unicità rispetto a Layer A:** Layer A è batch-deterministic su tutto il set ~412 (effettivi 487) cluster con focus statistico. Layer B è human-curated subset con focus narrativo: l'utente sceglie i case study con valore biologico raccontabile e Layer B genera gli asset publication-grade. Layer B NON re-fa DE né pooling — consuma il pooled output di Layer A.

## 2. Goals & non-goals

### Goals

1. **Pipeline semi-automatica** che, data una lista di `cluster_id` curata dall'utente, produce per ogni cluster un bundle di 8 asset publication-grade.
2. **Input CSV-driven**: l'utente compila `analysis/layer-b-selection.csv` (committato) con `cluster_id, label_paper, priority, notes`. Workflow trasparente, versionabile, audit-trailable.
3. **Output publication-grade**: ogni plot è drop-into-paper polished (PNG @300 DPI + SVG separati), caption in inglese paper-ready, formato Nature/Cell-compliant (font, dimensions, palette).
4. **Conditional dispatch per metodo**: forest plot solo per cluster con per-study DE disponibile (REM, MEGA-AUG); heterogeneity panel solo per REM. Caption esplicativa quando un plot non si applica.
5. **Aggregate report HTML standalone**: `layer_b_report.html` con TOC + sezione per cluster (8 plot + narrative reso), apribile via `file://`, no server runtime.
6. **Idempotenza**: `run_id` deterministico = hash(stage4_run_id + selection_csv_sha256 + config + schema_versions), byte-equal re-run garantito.
7. **Smoke gate pre-batch**: workflow obbligatorio smoke 3-cluster prima del batch 10-20 (consolidato pattern progetto, memoria `validate-before-fullrun`).

### Non-goals

- **NON** re-esegue DE per-studio né pooling (consuma `cluster_pooled.parquet` + `per_study_de.parquet` di Layer A read-only).
- **NON** automatizza la selezione dei case study (lo score composto della dashboard Layer A è suggerimento, non automation).
- **NON** genera narrative biologica via LLM (template TODO che l'utente cura a mano; rischio hallucination biologica troppo alto per paper Results).
- **NON** produce export PDF del report aggregato (HTML standalone è sufficiente; PDF richiederebbe wkhtmltopdf/LaTeX deps non motivati).
- **NON** integra targets pipeline (`_targets.R` resta invariato; Layer B è one-shot script-driven, non iterativa).
- **NON** modifica la dashboard Layer A (separata, già completa).

## 3. Architettura — pipeline a 3 sub-stage

```
Layer A output (read-only)  ──┐
Stage 4 counts cache         ──┼──> ┌────────────────────┐
analysis/layer-b-selection.csv ─┘   │ B.1 — Loader + QC  │
                                    │  .load_selection() │
                                    │  .validate_ids()   │
                                    │  .fetch_subset()   │
                                    │  .assemble_counts()│
                                    └─────────┬──────────┘
                                              │
                                              ▼
                                    ┌────────────────────┐
                                    │ B.2 — Asset gen    │
                                    │  per cluster:      │
                                    │   .build_volcano() │
                                    │   .build_forest()  │  [REM/MEGA-AUG]
                                    │   .build_ma()      │
                                    │   .build_top_tbl() │
                                    │   .build_heatmap() │
                                    │   .build_go_enr()  │
                                    │   .build_heterog() │  [REM only]
                                    │   .build_summary() │
                                    │   .write_narrative_template() │
                                    └─────────┬──────────┘
                                              │
                                              ▼
                                    ┌────────────────────┐
                                    │ B.3 — Aggregate    │
                                    │  render Quarto:    │
                                    │   layer_b_report.html │
                                    └────────────────────┘
```

I 3 sub-stage sono **chiamate sequenziali** nello script standalone `analysis/p5-stage4-layer-b-build.R`. Niente target separati in `_targets.R` (motivazione: Layer B è human-curation driven, non pipeline iterativa; lo standalone è più chiaro per il workflow utente).

### 3.1 Stage B.1 — Loader + QC

Input: `selection` (polimorfico: path-to-CSV o data.frame), `stage4_dir`, `h5_path`.
Output: `layer_b_context` (lista per-cluster).

Steps:
1. `.load_layer_b_selection(selection)` → tibble. Se `selection` è character, leggi CSV; se è data.frame, valida direttamente. Schema atteso: `cluster_id (chr), label_paper (chr), priority (int 1-99), notes (chr, optional)`. Fail-fast su schema invalido.
2. `.validate_cluster_ids(selection, stage4_dir)` → tibble con `cluster_id, exists_in_stage4, method, k_effective, n_sig_FDR05`. Fail-fast con error message chiaro se ANY `cluster_id` non esiste in `cluster_pooled.parquet` (drift Stage 4 re-run, typo). Esposto anche public come `layer_b_validate_selection()`.
3. `.fetch_layer_a_subset(stage4_dir, cluster_ids)` → list con (a) `cluster_pooled_subset` filtered da `cluster_pooled.parquet`, (b) `per_study_de_subset` filtered da `per_study_de.parquet`, (c) `qc_report_subset` from `qc_report.rds` filtered su `cluster_ids`, (d) Stage 3 metadata join (anchor, kind_effective, agent_id, safety_min — necessari per summary card).
4. `.assemble_cluster_counts(cluster_id, layer_a_subset, counts_cache_manifest)` per ogni cluster → list con (counts matrix integer genes×samples, metadata tibble sample_id/study/treatment). Riusa `prefetch_counts_for_clusters()` di Stage 4 se cache miss.
5. Aggrega in `layer_b_context = list of per-cluster sub-list`. Ogni sub-list ha: `cluster_id, label_paper, priority, method, k_effective, n_sig_FDR05, cluster_pooled, per_study_de, counts, metadata, summary_stats`.

### 3.2 Stage B.2 — Asset generation

Per ogni cluster in `layer_b_context`, esegue 8 plot generator + summary card + narrative template. Loop sequenziale (non parallelo per v1 — la maggior parte dei plot è veloce, e GO enrichment + heatmap potrebbero saturare memoria se parallel).

#### 8 plot per cluster (specs)

**1. Volcano (`build_volcano`):**
- Engine: `ggplot2` + `ggrepel`.
- X: `logFC_pool`, Y: `-log10(p_value_pool)`.
- Color: `FDR_BH_within_cluster < fdr_threshold` (rosso `#CC3333`) vs not-sig (grigio `#BBBBBB`).
- Labels: top `top_n_volcano_labels = 15` geni per `|logFC| × -log10(FDR)` con FDR<0.05.
- Threshold lines: `logFC = 0` (vertical), p-value equivalente a FDR=0.05 (orizzontale).
- Caption auto: `"Volcano plot for cluster <id>. <n_sig> of <n_total> genes significant at FDR<0.05 (BH-corrected within cluster)."`
- Output: `volcano.png` (6×6 inch @300 DPI) + `volcano.svg`.
- Applica a: tutti.

**2. Forest plot top-N geni (`build_forest`):**
- Engine: `metafor::forest()` per REM, custom `ggplot2` per MEGA-AUG.
- Top-N: top `top_n_forest = 10` geni per `|logFC_pool|` con FDR<0.05.
- Per-study row: GSE accession + `logFC ± 1.96·SE`.
- Pooled row: diamond + label `"Pool (k=<k>, τ²=<tau2>)"` per REM, `"Pool (k=2 pair + <n_aug> baseline studies)"` per MEGA-AUG.
- MEGA strict: skip; caption `"Forest plot N/A for mega-strict method (per-study DE absorbed in mixed model; per-study coefficients not extracted in Layer A)."`
- Output: `forest.png` (8×N×0.5 inch h-scale con N) + `forest.svg`.
- Applica a: REM, MEGA-AUG.

**3. MA plot (`build_ma_plot`):**
- X: `log10(baseMean across studies)`, Y: `logFC_pool`.
- baseMean: median across studies del cluster di `mean(log2(CPM+1))` per gene (calcolato on-the-fly da `counts`).
- Color: FDR<0.05 vs not-sig.
- Loess smooth dashed (sanity check assenza di trend mean-FC).
- Caption auto: `"MA plot. Loess smooth (dashed) shows absence of mean-effect-size trend; horizontal alignment confirms TMM normalization adequacy in upstream Layer A."`
- Output: `ma.png` (6×6 inch) + `ma.svg`.
- Applica a: tutti.

**4. Top-gene table (`build_top_gene_table`):**
- Top `top_n_table = 30` geni ranked by `|logFC_pool|` con FDR<0.05.
- Columns: `gene, logFC_pool, SE_pool, p_value_pool, FDR_BH_within_cluster, k_effective, tau2 (NA for MEGA), I2 (NA for MEGA), direction_applied`.
- Output: `top_genes.csv` + `top_genes.tex` (kableExtra booktabs format con caption ready per paper).
- Caption (in .tex): `"Top 30 differentially expressed genes for cluster <id> (FDR<0.05, ranked by |logFC|)."`
- Applica a: tutti.

**5. Heatmap top-N geni × sample (`build_heatmap`):**
- Top-N: top `top_n_heatmap = 30` geni per `|logFC_pool|` con FDR<0.05.
- Normalizzazione: `DESeq2::vst(counts, blind = TRUE)` + `sva::ComBat(dat = vst, batch = study_id, mod = model.matrix(~treatment))` per cosmetica cross-studio.
- Scale: row-wise z-score.
- Annotation rows (top): `study` (categoricale, palette `viridis::viridis(n_studies)`) + `treatment` (binary, palette fissa).
- Sample-axis subsample: se `n_samples > 100`, sample stratificato senza replacement per `(study, treatment)` cell, target n=100 sample bilanciati proporzionalmente alla dimensione di ogni cella (min 1 per cella se possibile). Deterministic seed `digest::digest2int(cluster_id)`.
- Engine: `ComplexHeatmap::Heatmap()`.
- Caption auto: `"Heatmap of top 30 DE genes (rows) across samples (columns). VST + ComBat batch correction applied for visual cross-study coherence; effect-size statistics in pooled output are NOT batch-corrected. <subsample_note if applies>"`
- Output: `heatmap.png` (8×10 inch) + `heatmap.svg`.
- Applica a: tutti.

**6. GO/Reactome enrichment (`build_go_enrichment`):**
- Engine: `clusterProfiler::enrichGO(ont = "BP", OrgDb = org.Hs.eg.db, qvalueCutoff = 0.05, pAdjustMethod = "BH")` su geni FDR<0.05 vs universe = geni testati nel cluster (da `cluster_pooled_subset$gene`).
- Plus `ReactomePA::enrichPathway()` se `ReactomePA` installato (opt-in via Suggests).
- Skip-graceful: se `n_genes_tested < 200` (threshold per ORA reliability) → genera file con caption `"GO enrichment N/A: <N> genes tested below threshold for over-representation analysis reliability."`
- Plot: barchart top-10 GO terms (BP) by `-log10(p.adjust)`, palette viridis.
- Output: `go_enrichment.png` (8×6 inch) + `go_enrichment.svg` + `go_enrichment_table.csv` (full enrichment result da `as.data.frame(enrich_result)`).
- Caption auto: `"GO Biological Process over-representation analysis. <N_sig> significant terms at FDR<0.05 (BH-corrected). Universe: <N_universe> genes tested in cluster."`
- Applica a: tutti (con skip-graceful su small universe).

**7. Heterogeneity panel (`build_heterogeneity_panel`):**
- Pannello 2×1:
  - (a) Histogram `tau2` per-gene del cluster (REM only — da `cluster_pooled_subset$tau2`).
  - (b) Split bar REM-amenable (`tau2 < 0.1`) vs REM-resisted (`tau2 >= 0.1`) con `%` di geni FDR<0.05 in ciascuna classe.
- Skip non-REM: genera file con caption `"Heterogeneity panel N/A for non-REM methods; per-gene τ² not estimable in mixed-model framework (mega) or pair-only design (mega_aug)."`
- Output: `heterogeneity.png` (8×4 inch) + `heterogeneity.svg`.
- Applica a: REM only.

**8. Cluster summary card (`build_summary_card`):**
- Formato: `.md` (embedabile nel report Quarto aggregato).
- Contenuti:
  - `cluster_id`
  - `label_paper` (da selection CSV)
  - Anchor canonical (kind_effective, agent_id, tissue, da Stage 3 metadata)
  - Method (rem/mega/mega_aug)
  - `k_effective`, `n_studies`, `n_total_samples`
  - `n_sig_FDR05` (n + %)
  - Top-gene (gene, logFC, FDR)
  - `safety_min` (da Stage 3)
  - `tau2_median` (REM only)
  - `direction_applied` distribuzione (% canonical / % flipped)
  - `n_baseline_studies_augmented` (MEGA-AUG only)
- Output: `summary_card.md`.

#### Narrative template (`write_narrative_template`)

Per ogni cluster, genera `narrative.qmd` con struttura fissa:

```markdown
---
title: "Case study: {{label_paper}} ({{cluster_id}})"
---

# Case study: {{label_paper}}

## Summary card

{{embed summary_card.md}}

## Biological context

_TODO: write biological narrative (1-2 paragraphs). What is the
biological intervention/disease? Why is this comparison interesting?
What known mechanisms apply?_

## Findings

_TODO: interpret top-30 genes table + volcano + GO enrichment.
Which genes confirm known biology? Are there surprises? Cross-reference
with literature._

## Discussion

_TODO: discuss heterogeneity (if REM), cross-study consistency (forest),
caveats (mega_aug baseline-pool), implications for the field._

## Figures

::: {.figure-list}
- volcano.svg
- forest.svg (REM/MEGA-AUG only)
- ma.svg
- heatmap.svg
- go_enrichment.svg
- heterogeneity.svg (REM only)
:::
```

Lingua: **English** (paper-ready, conforme alla decisione brainstorming).

### 3.3 Stage B.3 — Aggregate report

Input: `layer_b_result` (output di B.2, struttura S3 con dir paths).
Output: `layer_b_report.html` standalone.

Render via `quarto::quarto_render()` di un template `inst/templates/layer-b-report.qmd` che:
- Frontmatter: `format: html, embed-resources: true, toc: true, toc-depth: 2`.
- Sezione overview: tabella DT con tutti i cluster del bundle (cluster_id, label_paper, method, k, n_sig, link to section).
- Sezione "Methods note" auto-generata: config snapshot + reference reads (ADR-0017, finding scope decision).
- Una sezione `## {{label_paper}}` per cluster, che embed:
  - Summary card (rendered da `summary_card.md`).
  - Tutti i plot PNG (NON SVG embed — SVG sono per uso paper esterno, PNG sono per il report aggregato per limit file size).
  - Top-gene table embedded (rendered da `top_genes.csv`).
  - `narrative.qmd` content (rendered inline).

Stima size: ~30-80 MB per 20 cluster (8 PNG × ~500 KB × 20 = ~80 MB).

### 3.4 Output dir convention

```
analysis/p4-output/<YYYYMMDDTHHMMSSZ>-layer-b-<run_id>/
├── layer_b_report.html             # aggregate HTML standalone
├── selection_resolved.csv          # selection CSV + metadata risolto (method, k_effective, n_sig_FDR05)
├── run_metadata.json               # config + provenance + run_id
├── <cluster_id_1>/
│   ├── volcano.png, volcano.svg
│   ├── forest.png, forest.svg                 # se applicabile
│   ├── ma.png, ma.svg
│   ├── top_genes.csv, top_genes.tex
│   ├── heatmap.png, heatmap.svg
│   ├── go_enrichment.png, go_enrichment.svg
│   ├── go_enrichment_table.csv
│   ├── heterogeneity.png, heterogeneity.svg   # REM only
│   ├── summary_card.md
│   ├── narrative.qmd                          # template da curare a mano
│   └── captions.json                          # auto-generated captions, schema {filename: caption_string}
└── <cluster_id_2>/ ...
```

### 3.5 `run_metadata.json` schema

```json
{
  "run_id": "<8-hex>",
  "timestamp": "ISO 8601 UTC",
  "schema_versions": {
    "layer_b_algorithm": "v1",
    "stage4_algorithm": "v1"
  },
  "package_version": "...",
  "r_version": "...",
  "bioc_versions": {
    "clusterProfiler": "...",
    "org.Hs.eg.db": "...",
    "ComplexHeatmap": "...",
    "ReactomePA": "<n/a if not installed>"
  },
  "input_files": {
    "stage4_dir": {"path": "...", "run_id": "...", "sha256_cluster_pooled": "..."},
    "selection_csv": {"path": "...", "sha256": "...", "n_rows": ...}
  },
  "config": {
    "top_n_forest": 10,
    "top_n_heatmap": 30,
    "top_n_table": 30,
    "top_n_volcano_labels": 15,
    "fdr_threshold": 0.05,
    "palette": "viridis",
    "language": "en",
    "heatmap_normalize": true,
    "go_enrichment": true,
    "save_svg": true,
    "dpi": 300
  },
  "output_counts": {
    "n_clusters_processed": "...",
    "by_method": {"rem": "...", "mega": "...", "mega_aug": "..."},
    "n_plots_generated": "...",
    "n_plots_skipped": "...",
    "bundle_size_mb": "...",
    "report_size_mb": "..."
  },
  "compute_summary": {
    "wall_seconds": "...",
    "peak_mem_mb": "..."
  }
}
```

`run_id = substr(digest::digest(canonical_form(stage4_run_id + selection_csv_sha256 + config + schema_versions)), 1, 8)`. Deterministico.

## 4. API surface

### Public (`@export`)

| Function | Signature | Purpose |
|---|---|---|
| `build_layer_b_results()` | `(stage4_dir, selection, h5_path, config = layer_b_default_config())` → `layer_b_result` S3 | Entry-point. `selection` polimorfico: path-to-CSV o data.frame. |
| `layer_b_default_config()` | `()` → `list` | Defaults: vedi schema sopra. |
| `write_layer_b_to_dir()` | `(lb, dir)` → invisible(character paths) | Scrive bundle dir-per-cluster + report aggregato. |
| `load_layer_b()` | `(dir)` → `layer_b_result` | Reads back manifest. |
| `render_layer_b_report()` | `(lb, out_path = file.path(dir, "layer_b_report.html"))` → invisible(path) | Render Quarto report aggregato standalone. |
| `layer_b_validate_selection()` | `(selection, stage4_dir)` → tibble | Pre-check standalone (typo, drift). Esposta per smoke check pre-batch. |

### Internal (`@keywords internal`)

- `.load_layer_b_selection(csv_path)` → tibble
- `.fetch_layer_a_subset(stage4_dir, cluster_ids)` → list
- `.assemble_cluster_counts(cluster_id, layer_a_subset, counts_cache_manifest)` → list
- `.build_volcano(cluster_pooled_subset, config)` → list(png_path, svg_path, caption)
- `.build_forest(per_study_de_subset, cluster_pooled_subset, method, config)`
- `.build_ma_plot(cluster_pooled_subset, counts, config)`
- `.build_top_gene_table(cluster_pooled_subset, config)` → list(csv_path, tex_path)
- `.build_heatmap(counts, metadata, top_genes, config)`
- `.build_go_enrichment(cluster_pooled_subset, config)` → list(png_path, svg_path, csv_path, caption)
- `.build_heterogeneity_panel(cluster_pooled_subset, config)` (REM only)
- `.build_summary_card(cluster_id, layer_a_subset, stage3_metadata, config)` → md_path
- `.write_narrative_template(cluster_id, summary_card, config)` → qmd_path
- `.write_layer_b_selection_template(out_path)` → invisible(path) (helper opzionale, NON public)
- `.run_id_for_layer_b(stage4_run_id, selection_sha256, config, schema_versions)` → 8-hex

### Script standalone

`analysis/p5-stage4-layer-b-build.R` — entry-point per batch utente (analogo a `p5-stage4-layer-a-fullrun.R`):

```r
# analysis/p5-stage4-layer-b-build.R
# Layer B batch build: read selection CSV, run build_layer_b_results,
# render aggregate report.
#
# Pre-requisiti:
#   - analysis/layer-b-selection.csv compilato (10-20 cluster_id)
#   - Layer A output esistente in analysis/p4-output/<YYYYMMDDTHHMMSSZ>-stage4-96c43acb/
#
# Usage:
#   nohup Rscript analysis/p5-stage4-layer-b-build.R \
#     2>&1 | tee analysis/p5-stage4-layer-b-build.log &

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
})

cli_h1("Stadio 4 Layer B batch build")

stage4_dir   <- "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
selection_csv <- "analysis/layer-b-selection.csv"
h5_path       <- "analysis/input/human_gene_v2.5.h5"

stopifnot(dir.exists(stage4_dir), file.exists(selection_csv), file.exists(h5_path))

# Pre-validation smoke check
cli_alert_info("Pre-validation...")
val <- layer_b_validate_selection(selection_csv, stage4_dir)
print(val)

# Batch build
cli_alert_info("Build...")
t0 <- Sys.time()
result <- build_layer_b_results(
  stage4_dir = stage4_dir,
  selection = selection_csv,
  h5_path = h5_path,
  config = layer_b_default_config()
)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

# Write output
out_dir <- file.path(
  "analysis/p4-output",
  sprintf("%s-layer-b-%s",
          format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
          result$run_metadata$run_id)
)
write_layer_b_to_dir(result, out_dir)

# Render aggregate report
render_layer_b_report(load_layer_b(out_dir),
                      file.path(out_dir, "layer_b_report.html"))

cli_alert_success("Layer B batch OK in {.field {round(wall/60, 1)} min}: {.path {out_dir}}")
```

### Smoke script

`analysis/p5-stage4-layer-b-smoke.R` — pre-batch validation con 3 cluster pick deterministici (1 mega strict k≥10, 1 mega_aug pair, 1 mega strict k=5-6 borderline). Selection in script (no CSV intermedio per lo smoke).

## 5. DESCRIPTION delta + ADR-0017

### DESCRIPTION delta

**Aggiunte nuove a `Imports:`** (hard deps Layer B):

```
clusterProfiler
org.Hs.eg.db
ComplexHeatmap
ggrepel
kableExtra
sva
DESeq2
```

**Mosse da `Suggests:` a `Imports:`** (passano da opzionali a essenziali per Layer B):

```
ggplot2     # ogni plot Layer B lo usa
quarto      # render_layer_b_report() lo usa
```

**Aggiunte a `Suggests:`** (opt-in con skip-graceful):

```
ReactomePA  # plus su GO BP enrichment di clusterProfiler
```

**Già in `Imports:`** (non duplicare): `arrow`, `BiocParallel`, `digest`, `edgeR`, `limma`, `metafor`, `parallelly`, `rhdf5`, `variancePartition`.

`org.Hs.eg.db` è hard dep (utente choice esplicita brainstorming Q5: "Imports: enforced dependency"). renv lock-in cross-machine. Documentazione vignette + DESCRIPTION + ADR-0017.

`ggplot2` da Suggests → Imports comporta un breaking change minore di policy: chi installa simulomicsr per usare solo Stage 1-3 ora porta dietro ggplot2. Trade-off accettato dato che ggplot2 è dipendenza light (~5 MB).

### ADR-0017 (Proposed con questo spec)

**Title:** Layer B case study generator — CSV-driven selection + comprehensive plot bundle + aggregate Quarto report

**Decisions captured:**

1. CSV manualmente curato come input mechanism (selection trasparente, versionabile)
2. Comprehensive plot set (8 plot) con conditional dispatch per metodo
3. Drop-into-paper polished output (PNG @300 DPI + SVG, caption inglese paper-ready)
4. clusterProfiler + org.Hs.eg.db come hard deps in Imports (no skip-graceful, fail-fast se mancano)
5. HTML standalone aggregate report (no PDF, no Shiny)
6. Narrative per-cluster (uno `.qmd` per cluster, no master narrative)
7. NO targets integration in `_targets.R` (script standalone primary)
8. Smoke 3-cluster gate obbligatorio pre-batch (memoria `validate-before-fullrun`)

## 6. Test strategy

### 6.1 Unit tests (`tests/testthat/`)

- `test-layer-b-selection.R`: CSV parsing, schema validation, fail-fast su typo cluster_id, polimorfismo selection (path vs data.frame).
- `test-layer-b-fetch.R`: subset Layer A correttamente filtrato, counts cache hit, gestione cluster con metodo misto.
- `test-layer-b-volcano.R`: rendering PNG+SVG, top-N labels selection deterministica, edge case 0 sig genes (caption esplicativa).
- `test-layer-b-forest.R`: dispatch REM vs MEGA-AUG vs MEGA-skip, output dimensions corretto, metafor::forest non-NULL.
- `test-layer-b-ma.R`: assi corretti, loess smooth presente, edge case <10 genes.
- `test-layer-b-top-gene-table.R`: top-30 selection, CSV+LaTeX schema, kableExtra formatting.
- `test-layer-b-heatmap.R`: vst+ComBat dimensioni preservate, z-score row-wise correct, annotation rows, sample subsample stratificato deterministic.
- `test-layer-b-go-enrichment.R`: skip-graceful su small universe (<200 geni), output schema, fallback su 0 enriched terms.
- `test-layer-b-heterogeneity.R`: skip non-REM cluster (caption corretta), REM histogram + split bar.
- `test-layer-b-summary-card.R`: schema, auto-population stats.
- `test-layer-b-narrative-template.R`: presenza sezioni TODO, no LLM-generated content.
- `test-layer-b-report-aggregate.R`: render Quarto end-to-end su fixture mini, HTML standalone size sensata, TOC presente.
- `test-layer-b-run-id.R`: determinism (run_id stabile per stessa input).
- `test-layer-b-validate-selection.R`: fail-fast su cluster_id missing, schema CSV invalido.

### 6.2 Integration test

`test-layer-b-fixture-mini.R`: 2 cluster fixture (1 mega + 1 mega_aug) → `build_layer_b_results()` end-to-end → verifica:
- Bundle dir-per-cluster creato con tutti i file attesi.
- Forest plot presente solo per mega_aug, non per mega (caption skip presente).
- `layer_b_report.html` standalone (file://-openable, no broken refs).
- `selection_resolved.csv` correttamente popolato.
- Re-run idempotente (modulo timestamp).

### 6.3 Smoke pre-batch utente

Script `analysis/p5-stage4-layer-b-smoke.R`:
- Selection (in-script) con 3 cluster picks deterministici dal run β `96c43acb`:
  - 1 mega strict con `n_studies >= 10` (coverage MEGA grande)
  - 1 mega_aug pair con `n_baseline_studies_augmented >= 10` (coverage MEGA-AUG)
  - 1 mega strict con `n_studies` 5-6 (coverage borderline edge case)
- Wall budget atteso: ≤5 min.
- Validation manuale:
  - Bundle 3 cluster generato.
  - `layer_b_report.html` apribile + visualmente sensato.
  - Caption skip-pattern visibile per heterogeneity (no REM in questo run).
- **Smoke gate**: utente conferma OK → procede a batch 10-20 cluster.

### 6.4 Replication / idempotence

`test-layer-b-replication.R`: run Layer B twice on same input → byte-equal output (modulo timestamp). Check:
- `run_id` deterministico.
- Plot PNG byte-equal (ggplot2 + ComplexHeatmap sono deterministic con same seed; sva ComBat con set.seed locale).
- `top_genes.csv` byte-equal.
- `run_metadata.json` byte-equal modulo `timestamp` + `compute_summary.wall_seconds`.

### 6.5 Performance budget

- Wall budget atteso (laptop 16 core, 251 GB RAM): ≤2 min/cluster, totale ≤45 min per 20 cluster.
- Peak memory: ≤8 GB (heatmap vst+ComBat + enrichGO i più memory-intensive).
- Output bundle size: ≤200 MB per 20 cluster (8 plot × ~1 MB SVG + 30 KB CSV + 50 KB heatmap PNG = ~10 MB/cluster).
- Aggregate report HTML: ≤80 MB per 20 cluster.

## 7. Persistence + versioning

- `schema_versions.layer_b_algorithm = "v1"`. Bump in caso di modifiche al config schema, output bundle structure, o plot defaults.
- `run_id` deterministico hash di `(stage4_run_id + selection_csv_sha256 + config + schema_versions)`.
- Counts cache: riutilizzato read-only da Stage 4, mai modificato.
- Audit trail: nessun overwrite del dir output. Run history accumulata in `analysis/p4-output/`.
- Selection CSV: committato in `analysis/layer-b-selection.csv`, audit trail della curation.

## 8. Rischi + open questions

| Rischio | Mitigazione |
|---|---|
| `org.Hs.eg.db` install fallisce su system senza Bioc → blocca pipeline | Hard dep documentata in DESCRIPTION + vignette + ADR-0017. Errore deterministico al `library()`, no silent skip. |
| ComBat su cluster mega_aug con baseline pool da 10-50+ studi diversi → overcorrection | Caption disclaimer esplicito: *"ComBat applied for visual coherence only; effect-size statistics are not batch-corrected"*. Heatmap è SECONDARIO al volcano/forest per evidenza. |
| Cluster_id selezionato non più esistente (drift Stage 4 re-run) | `layer_b_validate_selection()` pre-check con error message chiaro + suggerimento di rebrowse dashboard. |
| GO enrichment universe troppo piccolo (cluster con pochi geni testati) | Skip-graceful: caption *"GO enrichment N/A: <N> genes tested, below threshold for ORA reliability"*. Threshold: 200 geni. |
| Volcano caption con N_sig=0 (cluster brutto selezionato) | Caption esplicito + suggerimento di rivedere la selezione. Plot generato comunque (zero hits = informativo). |
| Heatmap top-30 geni × hundreds di sample (cluster mega_aug grande) → unleggibile | Sample-axis subsample stratificato per (study, treatment) se >100 sample, max 100 sample plottati. Caption esplicita. Seed deterministic = `digest::digest2int(cluster_id)`. |
| `narrative.qmd` template render fallisce nel report aggregato se utente edita male | Template è valid Quarto by default. Render del report aggregato skip-graceful con warning se un narrative.qmd ha syntax error. |
| Quarto report aggregato file size esplode su 20 cluster (250+ embed asset) | PNG ottimizzati embedded nel report; SVG separati per uso paper esterno. Stima 30-80 MB. |
| metafor::forest() su 10 geni × 4-9 studi richiede layout grafico delicato | Smoke test su 1 REM cluster (se mai ne avremo nel run β attuale = 0) validerà. In assenza di REM nel run β, forest si testa solo per MEGA-AUG con metafor-style custom ggplot. |
| ReactomePA install fallisce ma utente non se ne accorge | Skip-graceful Suggests pattern: se mancante, skip ReactomePA panel + warning chiaro + caption esplicativa nel report aggregato. |

### Open questions per plan implementativo (non per spec)

1. ComplexHeatmap vs pheatmap: ComplexHeatmap superiore per annotation row/col + customization. Conferma in plan via smoke test.
2. `enrichGO` BP only vs BP+MF+CC: BP è standard paper RNAseq. Decisione: BP only in v1, eventuale flag config in v2.
3. Forest plot layout su 10 geni × 4-9 studi: dimensione SVG/PNG (8×N×0.5 inch) richiede sperimentazione su cluster reale; smoke validerà.
4. Sample subsample heatmap > 100 sample: stratificato per (study, treatment) — verifica nel plan il bilanciamento (es. min 2 per arm per studio).

## 9. Decisioni rilevanti & cross-reference

- **ADR-0006** (positioning) — Layer B è il deliverable "biological narrative" che differenzia simulomicsr (effect-size cross-studio + curation) vs RummaGEO (gene-set per-studio without narrative).
- **ADR-0015** (Stage 4 three-path) — Layer B consuma read-only il `cluster_pooled.parquet` + `per_study_de.parquet`, no re-DE.
- **ADR-0016** (Stage 4 crash fixes baseline pool cap) — Layer B può processare cluster mega_aug con baseline pool capped (max_baseline_per_arm=350); le diagnostiche `bidir_collapsed_to_mono` sono visibili nella summary card.
- **ADR-0017 NUOVO (Proposed con questo spec)** — Layer B case study generator architecture.
- **Finding scope decision** (2026-05-19) — Layer B = ~10-20 case study curati. Questo spec realizza il "Showcase case study" Layer (B) del finding.
- **User feedback** `validate-before-fullrun` — smoke 3-cluster gate obbligatorio.
- **User feedback** `pipeline-config-uniformity` — stile config mirror Layer A.
- **CLAUDE.md** roadmap "Stadio 4 Layer B + Stadio 5 meta-analisi" — questo spec realizza il Layer B half.

---

**Pronto per review.** Dopo approvazione utente: ADR-0017 Proposed scritto in pair con questo spec, branch `p5-stadio4-layer-b` creato, prossimo step invocare `superpowers:writing-plans` per stendere il plan implementativo step-by-step (TDD bite-sized).
