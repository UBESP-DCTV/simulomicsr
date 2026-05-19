# Stadio 4 — DE per-studio + MEGA cross-study production (design spec)

**Stato:** draft 2026-05-19 — in attesa di review utente
**Branch target:** `p5-stadio4-de-perstudio` (da creare partendo da `master` @ `p5-stadio3-complete` + tag `p4-beta-rescue-complete`)
**Predecessore:** P5 Stadio 3 complete (267.056 cluster cross-studio, run β `2153addc`, ff-merge a master 2026-05-19)
**Successore previsto:** Stadio 5 metafor REM **solo per i 33 cluster REM proper** (path MEGA ha pooling built-in). Possibili Layer B case study (10-20 cluster human-curated) e/o release Layer C extended catalog come follow-up.
**Decisioni rilevanti:** ADR-0006 (positioning vs RummaGEO), ADR-0014 (Stage 3 tiered anchor + dual-mode), finding scope decision Layer A (2026-05-19), finding power gain quantification (2026-05-19), user DE methods benchmark (memoria, non pubblicato).
**ADR proposto con questo spec:** **ADR-0015** — Stage 4 three-path architecture (limma-voom REM + dream MEGA + dream MEGA-augmentation) con persistent counts cache, per-study DE artifact reusable, e Quarto diagnostic dashboard.

---

## 1. Contesto e obiettivo

Stadio 4 trasforma i ~412 cluster Layer A (definiti nel finding scope decision 2026-05-19) in **effect-size pooled cross-studio**, gene per gene, secondo tre path coerenti con i tre tipi di cluster utilizzabili emersi da Stadio 3:

| Path | Cluster Layer A | Modello statistico | Output ruolo |
|---|---:|---|---|
| **REM** | 33 cluster `usable_rem_strict` k=3-9 | Per-study limma-voom + eBayes → `metafor::rma` REML cross-study | Effect-size + τ², I² per gene per cluster |
| **MEGA** | 312 cluster `usable_mega_strict` k≥5 (L0/L1, safety≥0.7) | dream (`variancePartition::dream`) su raw counts: `~ treatment + (1|study)` | Effect-size mixed-effects per gene per cluster |
| **MEGA-AUG** | 67 cluster pair k=2 con baseline cross-studio | dream con shared baseline augmented dai cluster group con stesso `control_anchor` a stesso L | Effect-size pair amplificato da baseline pool |

**Stadio 5** (`metafor::rma` REML) resta logicamente separato **solo per i 33 REM proper**: per i path MEGA il pooling è built-in nel modello misto. Stadio 4 produce due artifact: `per_study_de.parquet` (long, milioni di righe) consumabile per analisi ad-hoc, e `cluster_pooled.parquet` (cluster × gene → pooled stats).

L'unicità rispetto allo stato dell'arte (ADR-0006): RummaGEO si ferma a gene-set Jaccard; MetaSRA/MetaHQ/Mondal si fermano a metadati harmonized. Solo simulomicsr produce `(yi, vi)` quantitativi pronti per metafor + raw-counts mega-analysis con baseline cross-studio, perché solo simulomicsr ha l'`comparability_anchor` canonical v3 cross-studio.

## 2. Goals & non-goals

### Goals

1. **Three-path production pipeline** sui ~412 cluster Layer A, con engine uniforme **limma-family** (limma-voom + dream condividono `eBayes` shrinkage, pattern di tooling consistente).
2. **Caching layer doppio**: counts H5 (per evitare re-fetch costoso, ~1-5 sec per studio × ~500 studi unique) + per-study DE come artifact reusabile (per evitare ricompute quando uno studio appare in più cluster).
3. **Output reusabile**: `per_study_de.parquet` consumabile per Layer B case study senza re-run.
4. **QC sample-level documentato**: `lib_size ≥ 500.000` formalmente enforced, cluster rescue automatico con flag esplicit.
5. **Diagnostic Quarto dashboard** (`stage4_dashboard.html`) come deliverable insieme ai parquet, per esplorazione interattiva dei 412 cluster prodotti e selezione human-curated dei Layer B case study.
6. **Idempotenza**: `run_id` deterministico, byte-equal re-run guaranteed.
7. **Targets-pipeline native**: integrazione standard, parallelism via `future::multisession`, **niente DGX** (CPU-bound, nessuna GPU needed).

### Non-goals

- **NON** computa Layer B case study (10-20 cluster manuali con biological narrative): quelli sono produzioni human-curated post-Layer A, supportate dalla dashboard ma non automate.
- **NON** computa Layer C extended catalog (310 REM k=2 + 3.400 MEGA-relaxed): out-of-scope per la scope decision 2026-05-19.
- **NON** include Stadio 5 metafor REM step a parte: i 33 REM cluster sono già pooled in `cluster_pooled.parquet` via `metafor::rma` chiamato internamente. "Stadio 5" rimane label logica per la sezione metafor nel paper Methods, non un sub-pipeline separata.
- **NON** fa outlier-detection automatica sample-level (skipped in v1, riservato a v2 se vediamo τ² gonfiato outlier-driven).
- **NON** modifica gli artifact Stadio 3 (consumati read-only).

## 3. Architettura — pipeline a 5 sub-stage

```
Stage3 outputs ──┐
                 │
                 ▼
        ┌────────────────┐
        │ 4.A — Cluster  │  Selection Layer A + QC sample-level (lib_size ≥ 500k)
        │   selection &  │  Cluster rescue: drop sample/study, recompute k
        │   sample QC    │  → eligible_clusters.rds (≤412 cluster post-QC)
        └────────┬───────┘
                 │
                 ▼
        ┌────────────────┐
        │ 4.B — Counts   │  ARCHS4 H5 fetch + cache persistente
        │   prefetch     │  Counts cache keyed by xxhash32(gse, sorted(sample_ids))
        │   & cache      │  → tools::R_user_dir/stage4-counts/<key>.rds
        └────────┬───────┘
                 │
                 ▼
        ┌────────────────┐
        │ 4.C — Per-     │  limma-voom + eBayes per (cluster, study) in REM + MEGA-AUG pair-side
        │   study DE     │  Long format output
        │                │  → per_study_de.parquet
        └────────┬───────┘
                 │
                 ▼
        ┌────────────────┐
        │ 4.D — Cluster  │  REM: metafor::rma REML su per_study_de subset
        │   pooling      │  MEGA: dream `~ treatment + (1|study)` su counts cluster
        │                │  MEGA-AUG: dream con baseline pool augmented
        │                │  → cluster_pooled.parquet
        └────────┬───────┘
                 │
                 ▼
        ┌────────────────┐
        │ 4.E —          │  Quarto render: overview + per-cluster drill-down
        │   Diagnostic   │  htmlwidgets (DT, plotly) per filter/sort/explore
        │   dashboard    │  → stage4_dashboard.html
        └────────────────┘
```

I 5 sub-stage sono **target separati nel pipeline targets**: ognuno cacheable individualmente, recomputable in isolation se cambia config.

### 3.1 Stage 4.A — Cluster selection + QC

Input: `stage3_run` (path al dir Stadio 3 `20260519T055547Z-stage3-2153addc`).
Output: `eligible_clusters` tibble.

Selezione Layer A:
```r
layer_a <- s3$clusters |>
  filter(
    (usable_rem_strict & k %in% 3:9) |              # 33 REM proper (k_gold≥10 → 2 cluster da gestire come k=10+)
    (usable_mega_strict & n_studies >= 5) |          # 312 MEGA strict
    (mega_aug_pair_with_baseline_pool)               # 67 MEGA-augmentation (vedi §3.3)
  )
```

QC sample-level:
- **lib_size threshold**: `lib_size_sample >= 500.000` (configurabile via `getOption("simulomicsr.stage4.qc.lib_size_min")`). Lib_size disponibile da ARCHS4 H5 metadata già letto in Stadio 3.
- Sample sotto soglia: marcati `qc_dropped_sample`, raccolti in `qc_report$qc_drops_sample`.
- Studio post-QC con `n_treated_remaining >= 2 & n_control_remaining >= 2`: tenuto. Altrimenti `qc_drops_study$reason ∈ {n_treated_below_2, n_control_below_2, all_samples_dropped}`.
- Cluster post-QC:
  - REM: `k_remaining >= 2`. Sotto soglia → `non_processable$reason = "k_below_2_post_qc"`.
  - MEGA strict: `n_studies_remaining >= 5 & n_total_remaining >= 30`.
  - MEGA-augmentation: pair studi entrambi sopravvivono + baseline pool ha ≥ 3 studi rimasti.

### 3.2 Stage 4.B — Counts prefetch + cache persistente

Input: `eligible_clusters`. Output: `counts_cache_manifest` (paths to cached `.rds` files).

Cache dir: `tools::R_user_dir("simulomicsr", which = "cache")/stage4-counts/`.

Per ogni studio unique negli eligible cluster:
- `cache_key = xxhash32(paste0(gse, "_", paste(sort(sample_ids), collapse = "|")))`.
- Se `<cache_dir>/<cache_key>.rds` esiste: skip fetch (cache hit).
- Altrimenti: `rhdf5::h5read(h5_path, "data/expression", index = list(NULL, sample_indices))` + save integer matrix con `saveRDS(compress = "xz")`.

Counts stored as integer matrix (genes × samples), rownames = HGNC symbol (da ARCHS4 H5 `meta/genes/symbol`), colnames = GSM accession. Stima disk size: ~600 MB worst-case per ~500 unique GSE × ~30 sample mean.

Cache **non auto-purged**. Funzione `cache_purge_stage4(older_than_days = NULL)` opt-in.

### 3.3 Stage 4.C — Per-study DE (REM + MEGA-AUG pair-side)

Input: `eligible_clusters` + `counts_cache_manifest`. Output: `per_study_de.parquet`.

**Quali tuple processare**: l'union di:
- `(cluster_id, study_id)` per ogni REM cluster (~33 cluster × 3-4 studi = ~120 tuple).
- `(cluster_id, study_id)` per ogni MEGA-AUG cluster, **solo studi del pair** (67 cluster × 2 studi = 134 tuple). Lo shared baseline non passa per per-study DE.

Il deduplication su `(study_id, sorted_treated_sample_ids, sorted_control_sample_ids)` permette riuso: stesso comparison appare in più cluster solo se la comparison è identica (raro ma possibile per cluster a livelli L diversi).

Pipeline per ogni tuple:
1. Load counts dalla cache.
2. `dge <- edgeR::DGEList(counts = counts)`.
3. `keep <- edgeR::filterByExpr(dge, group = treatment)`; `dge <- dge[keep, , keep.lib.sizes = FALSE]`.
4. `dge <- edgeR::normLibSizes(dge, method = "TMM")`.
5. `design <- model.matrix(~ treatment)` (treatment factor con `control` come reference).
6. `v <- limma::voom(dge, design)`.
7. `fit <- limma::lmFit(v, design)`.
8. `fit <- limma::eBayes(fit)`.
9. Per ogni gene:
   - `logFC = fit$coefficients[, "treatmenttreated"]`
   - `SE = sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"]`
   - `p_value = fit$p.value[, "treatmenttreated"]`
   - `t_stat = fit$t[, "treatmenttreated"]`
10. Apply canonical direction flip se `direction_check == "swapped"` per il cluster: `logFC <- -logFC`. `direction_applied = "flipped"` in output.

Long format output:

| Column | Type | Notes |
|---|---|---|
| `cluster_id` | string | Foreign key to Stage 3 `clusters.rds` |
| `study_id` | string | GSE accession |
| `gene` | string | HGNC symbol |
| `logFC` | double | limma-voom + eBayes coefficient |
| `SE` | double | `sqrt(s2.post) * stdev.unscaled` (eBayes shrunk) |
| `p_value` | double | limma raw p-value (no FDR adjustment a livello per-study) |
| `t_stat` | double | eBayes moderated t-statistic |
| `n_treated` | integer | Post-QC sample count |
| `n_control` | integer | Post-QC sample count |
| `direction_applied` | factor | `none` (canonical) ∣ `flipped` (was swapped, logFC negated) |

Compression: zstd level 9 via `arrow::write_parquet(..., compression = "zstd", compression_level = 9)`. Stima 200-400 MB.

### 3.4 Stage 4.D — Cluster pooling

Input: `per_study_de` + `eligible_clusters` + `counts_cache_manifest`.
Output: `cluster_pooled.parquet`.

**Path REM (33 cluster):**

Per ogni cluster:
- Filter `per_study_de` by `cluster_id`.
- Per ogni gene presente in ≥ 2 studi del cluster: `metafor::rma(yi = logFC, sei = SE, method = "REML")`.
- Estrai: `logFC_pool = res$b`, `SE_pool = res$se`, `p_value_pool = res$pval`, `tau2 = res$tau2`, `I2 = res$I2`, `Q = res$QE`, `Q_pval = res$QEp`, `k_effective = res$k`.
- Set `method = "rem"`, `n_baseline_studies_augmented = NA`.

Edge case: REML convergence failure (rare, k=2 con logFC molto vicini). Catch via `tryCatch` → fallback a `method = "DL"` (DerSimonian-Laird closed-form); log in `qc_report$pooling_warnings`.

**Path MEGA (312 cluster):**

Per ogni cluster:
- Assembla counts matrix da tutti gli studi del cluster (concat sample-wise da cache).
- Metadata tibble: `sample_id`, `study` (factor), `treatment` (factor con `control` come reference).
- `vobj <- variancePartition::voomWithDreamWeights(counts, formula = ~ treatment + (1|study), data = metadata)`.
- `fitmm <- variancePartition::dream(vobj, formula = ~ treatment + (1|study), data = metadata, BPPARAM = BiocParallel::MulticoreParam(workers_for_dream))`.
- `fitmm <- variancePartition::eBayes(fitmm)`.
- Per ogni gene:
  - `logFC_pool = fitmm$coefficients[, "treatmenttreated"]`
  - `SE_pool = sqrt(fitmm$s2.post) * fitmm$stdev.unscaled[, "treatmenttreated"]`
  - `p_value_pool = fitmm$p.value[, "treatmenttreated"]`
- Set `method = "mega"`, `tau2 = NA, I2 = NA, Q = NA, Q_pval = NA, n_baseline_studies_augmented = NA`.

Edge case: dream convergence failure su cluster piccoli → fallback a `limma::voom + limma::duplicateCorrelation(block = study)`, marca `pooling_fallback = "limma_dupcor"` in `qc_report`.

**Path MEGA-AUG (67 cluster):**

Per ogni MEGA-AUG cluster pair:
1. Identifica i due studi del pair (treated_set + control_set definiti da Stage 3 cluster).
2. Identifica il **baseline pool**: filter `s3$clusters` per `mode == "group" & level == cluster$level & anchor_key == cluster$control_anchor_key` (string equality sulla canonical anchor key). Estrai tutti i sample del cluster group risultante che NON appartengono ai due studi del pair (deduplica per sample_id per evitare double-counting cross-cluster).
3. Metadata tibble: include sample del pair (treated/control come da cluster) + sample del baseline pool (treatment = `control`, study = study originale di ogni sample, conservato come livello del factor `study`).
4. `vobj <- voomWithDreamWeights(counts, formula = ~ treatment + (1|study), data = metadata)`.
5. `dream(...)` + `eBayes(...)` come MEGA.
6. Per ogni gene: estrai coefficients + SE + p-value come MEGA.
7. `n_baseline_studies_augmented = n_unique_studies_in_baseline_pool` (esclusi i 2 del pair).
8. `method = "mega_aug"`, `tau2 = NA, I2 = NA`.

Multiple testing per-cluster: `FDR_BH_within_cluster = p.adjust(p_value_pool, method = "BH")` separatamente per ogni `cluster_id`.

Output schema `cluster_pooled.parquet`:

| Column | Type | Notes |
|---|---|---|
| `cluster_id` | string | Composite primary key with `gene` |
| `gene` | string | HGNC symbol |
| `method` | factor | `rem` ∣ `mega` ∣ `mega_aug` |
| `logFC_pool` | double | Pooled effect size |
| `SE_pool` | double | Pooled standard error |
| `p_value_pool` | double | From metafor (REM) or dream (MEGA) |
| `tau2` | double | NA for MEGA/MEGA-AUG; REML estimate for REM |
| `I2` | double | NA for MEGA/MEGA-AUG; from rma() for REM (0-100 scale) |
| `Q` | double | Cochran's Q (REM only) |
| `Q_pval` | double | Q test p-value (REM only) |
| `k_effective` | integer | Post-QC k_studies used in pooling (REM: k studi; MEGA/AUG: n_studies di levels factor `study`) |
| `n_baseline_studies_augmented` | integer | NA except MEGA-AUG |
| `FDR_BH_within_cluster` | double | p.adjust within cluster_id |
| `direction_applied` | factor | Inherited from per_study_de majority for REM; `none` for MEGA/MEGA-AUG (random effect assorbe direction inconsistency) |

Compression: zstd level 9. Stima 50-150 MB (412 cluster × ~10k geni = ~4M rows).

### 3.5 Stage 4.E — Diagnostic Quarto dashboard

Input: `per_study_de.parquet`, `cluster_pooled.parquet`, `qc_report.rds`, `eligible_clusters` + Stage 3 cluster metadata.
Output: `stage4_dashboard.html` (~5-20 MB embedded, target deliverable per il paper supplementary).

Quarto document `analysis/p5-stage4-dashboard.qmd` con sezioni:

**Sezione 1 — Overview Layer A**:
- Card metrics: n_clusters_processed, n_clusters_dropped_qc, n_genes_total, n_significant_genes (FDR<0.05) per path.
- Distribution plots (plotly): n_clusters per method × k_effective.
- QC summary: top reason for sample drops, study drops, cluster drops.

**Sezione 2 — Cluster browser**:
- DT::datatable interattiva con tutti i ~412 cluster, filterable per:
  - `method` (rem / mega / mega_aug)
  - `k_effective` range
  - `n_significant_genes` (FDR<0.05) range
  - `tissue`, `kind_effective`, `agent_id` (da join con `s3$clusters$anchor_key`)
  - `tau2` range (REM only)
  - `safety_min` (da s3)
- Click su row → drill-down al cluster detail.

**Sezione 3 — Cluster detail (parametrizzato via URL fragment `#cluster_id`)**:
- Volcano plot (plotly) `logFC_pool` vs `-log10(p_value_pool)`, color by FDR<0.05.
- Forest plot (per REM cluster): top 20 geni con highest |logFC_pool| AND lowest tau2 — mostra per-study `logFC ± SE` + pooled.
- Per-study DE table (DT): filter `per_study_de` by cluster_id.
- Heterogeneity panel (REM only): tau2 distribution, I² distribution, identification dei "REM-amenable genes" (low tau2 = real gain) vs "REM-resisted genes" (high tau2 = legitimate heterogeneity).
- For MEGA-AUG: indicator `n_baseline_studies_augmented` + comparison with naive pair-only baseline (if computable from per_study_de subset).

**Sezione 4 — Methods note (snippet ready per paper)**:
- Auto-generated YAML config snapshot (mirror di `config` da `run_metadata.json`).
- Reference reads: ADR-0015, finding scope decision, finding power gain.

**Sezione 5 — Layer B candidate picker**:
- Tabella ordinabile DT con i 412 cluster ranked by un composite score `(n_significant_genes_FDR05 × log(k_effective)) / (1 + tau2_median)` — heuristic per "interpretable + statistically robust + low heterogeneity".
- Top 20 evidenziato come "first-pick suggestions" per Layer B curation.
- User copy/paste manuale dei cluster_id selezionati in un follow-up curation script. No state persistence interattiva in v1 (riservato a v2 se serve).

Engine: Quarto + R chunks + `htmlwidgets` (DT, plotly, crosstalk). Renders standalone (no live server). Build target via `quarto::quarto_render()` chiamato da `tar_target(stage4_dashboard_html, format = "file")`.

## 4. Output schema completo (6 file in directory versionata)

```
analysis/p4-output/<YYYYMMDDTHHMMSSZ>-stage4-<run_id>/
├── per_study_de.parquet              # §3.3
├── cluster_pooled.parquet            # §3.4
├── qc_report.rds                     # §4.1
├── non_processable.rds               # §4.2
├── stage4_dashboard.html             # §3.5
└── run_metadata.json                 # §4.3
```

### 4.1 `qc_report.rds`

Lista con 4 elementi:

- `qc_drops_sample`: tibble (sample_id, gsm, gse, lib_size, reason)
- `qc_drops_study`: tibble (cluster_id, study_id, n_treated_remaining, n_control_remaining, reason ∈ {`n_treated_below_2`, `n_control_below_2`, `all_samples_dropped`})
- `qc_drops_cluster`: tibble (cluster_id, original_k, qc_final_k, original_n_studies, qc_final_n_studies, reason)
- `pooling_warnings`: tibble (cluster_id, gene_or_global, kind ∈ {`rem_reml_failed_falled_back_to_DL`, `dream_failed_falled_back_to_limma_dupcor`, `escalc_zero_variance`}, message)

### 4.2 `non_processable.rds`

Tibble dei cluster Layer A che NON sono processabili post-QC, schema = `qc_drops_cluster`.

### 4.3 `run_metadata.json`

```json
{
  "run_id": "<8-hex>",
  "timestamp": "ISO 8601 UTC",
  "schema_versions": {
    "anchor": "v3",
    "stage3_algorithm": "v1",
    "stage4_algorithm": "v1"
  },
  "package_version": "...",
  "r_version": "...",
  "bioc_versions": {"limma": "...", "edgeR": "...", "variancePartition": "...", "metafor": "..."},
  "input_files": {
    "stage3_dir": {"path": "...", "run_id": "...", "sha256_clusters_rds": "..."},
    "archs4_h5": {"path": "...", "sha256": "..."}
  },
  "config": {
    "qc": {"lib_size_min": 500000},
    "de_engine": {"rem": "limma-voom+eBayes", "mega": "dream", "mega_aug": "dream"},
    "pooling": {"rem_method": "REML", "rem_fallback": "DL", "fdr": "BH_within_cluster"},
    "compute": {"workers": "availableCores() - 10"}
  },
  "output_counts": {
    "n_clusters_input_layer_a": 412,
    "n_clusters_processed": "...",
    "n_clusters_non_processable": "...",
    "by_method": {"rem": "...", "mega": "...", "mega_aug": "..."},
    "n_per_study_de_rows": "...",
    "n_cluster_pooled_rows": "...",
    "n_genes_significant_fdr05_total": "..."
  },
  "compute_summary": {
    "wall_seconds": "...",
    "peak_mem_mb": "...",
    "counts_cache_hits": "...",
    "counts_cache_misses": "..."
  }
}
```

`run_id = substr(digest::digest(canonical_form(input_hashes + config + schema_versions)), 1, 8)`. Deterministico.

## 5. API surface

R package functions:

**Public (`@export`):**

| Function | Signature | Purpose |
|---|---|---|
| `build_stage4_results()` | `(stage3_dir, h5_path, config = stage4_default_config())` → `stage4_result` S3 | Entry-point. Esegue tutti i 5 sub-stage. |
| `stage4_default_config()` | `()` → `list` | Defaults: lib_size_min, fdr method, workers count. |
| `write_stage4_to_dir()` | `(s4, dir)` → invisible(character paths) | Scrive 6 file. |
| `load_stage4()` | `(dir)` → `stage4_result` | Reads back. |
| `cluster_de_summary()` | `(s4, cluster_id)` → list (per_study tibble + pooled tibble) | Per cluster: per_study + pooled side-by-side. |
| `prefetch_counts_for_clusters()` | `(eligible_clusters, h5_path, cache_dir = NULL)` → manifest | Standalone callable per Layer B prep. |
| `render_stage4_dashboard()` | `(s4, out_path, quarto_template = system.file("templates/stage4-dashboard.qmd", package = "simulomicsr"))` → invisible(out_path) | Render Quarto dashboard standalone. |
| `cache_purge_stage4()` | `(cache_dir = NULL, older_than_days = NULL)` → invisible(removed_count) | Opt-in cleanup counts cache. |

**Internal (`@keywords internal`):**

- `.qc_filter_samples_and_studies(clusters, archs4_metadata, config)`
- `.identify_layer_a_clusters(s3_clusters, mega_aug_pair_join)`
- `.fetch_counts_cached(gse, sample_ids, h5_path, cache_dir)`
- `.run_limma_voom_de(counts, treatment_vec, study_id, direction_flip)` → tibble per_study row
- `.run_dream_mega(counts, metadata, formula, workers)` → tibble gene-level
- `.assemble_mega_aug_metadata(cluster_pair, stage3_clusters, counts_cache_manifest)` → tibble (sample_id, study, treatment)
- `.pool_rem_cluster(per_study_de_subset, fallback_to_dl = TRUE)` → tibble gene-level
- `.run_id_for_stage4(input_hashes, config, schema_versions)` → 8-hex string

## 6. Targets integration

Additivo in `analysis/_targets.R`:

```r
list(
  # ... esistenti P2/P3/P4 + stage3 ...

  tar_target(stage4_config, stage4_default_config()),
  tar_target(stage3_dir_for_stage4,
             "analysis/p4-output/20260519T055547Z-stage3-2153addc",
             format = "file"),
  tar_target(h5_for_stage4,
             "analysis/input/human_gene_v2.5.h5",
             format = "file"),

  tar_target(
    stage4_eligible_clusters,
    .qc_filter_samples_and_studies(
      stage3_clusters = load_stage3(stage3_dir_for_stage4)$clusters,
      h5_path = h5_for_stage4,
      config = stage4_config
    )
  ),

  tar_target(
    stage4_counts_cache,
    prefetch_counts_for_clusters(
      stage4_eligible_clusters,
      h5_path = h5_for_stage4
    ),
    format = "rds"
  ),

  tar_target(
    stage4_per_study_de,
    .run_per_study_de_all(stage4_eligible_clusters, stage4_counts_cache, stage4_config),
    format = "rds"
  ),

  tar_target(
    stage4_cluster_pooled,
    .pool_all_clusters(stage4_per_study_de, stage4_eligible_clusters, stage4_counts_cache, stage4_config),
    format = "rds"
  ),

  tar_target(
    stage4_qc_report,
    .build_qc_report(stage4_eligible_clusters, stage4_per_study_de, stage4_cluster_pooled),
    format = "rds"
  ),

  tar_target(
    stage4_input_hashes,
    .compute_input_hashes(stage3_dir_for_stage4, h5_for_stage4),
    format = "rds"
  ),

  tar_target(
    stage4_out_dir,
    {
      s4 <- list(
        per_study_de = stage4_per_study_de,
        cluster_pooled = stage4_cluster_pooled,
        eligible_clusters = stage4_eligible_clusters,
        qc_report = stage4_qc_report,
        config = stage4_config
      )
      dir <- file.path(
        "analysis/p4-output",
        sprintf("%s-stage4-%s",
                format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
                .run_id_for_stage4(stage4_input_hashes, stage4_config))
      )
      write_stage4_to_dir(s4, dir)
      dir
    },
    format = "file"
  ),

  tar_target(
    stage4_dashboard_html,
    render_stage4_dashboard(load_stage4(stage4_out_dir), file.path(stage4_out_dir, "stage4_dashboard.html")),
    format = "file"
  )
)
```

Parallel backend setup in `_targets.R` o `R/zzz.R::.onLoad()`:
```r
future::plan(future::multisession, workers = max(1L, parallelly::availableCores() - 10L))
```

## 7. Test strategy

### 7.1 Unit tests (`tests/testthat/`)

- `test-stage4-qc.R`: lib_size threshold, study drop logic, cluster rescue (k≥2 REM, n_studies≥5 MEGA strict, baseline pool ≥3 MEGA-AUG).
- `test-stage4-counts-cache.R`: cache key determinism (xxhash32 stability), hit/miss behavior, integer matrix dimensions correttamente preservate.
- `test-stage4-limma-de.R`: limma-voom + eBayes su fixture mini (3 sample per arm, 100 gene synthetic), confronto coefficient + SE con valori attesi (reference run pinato).
- `test-stage4-dream-mega.R`: dream `~ treatment + (1|study)` su fixture (2 studi × 6 sample), verifica `coefficients["treatmenttreated"]` e SE finiti.
- `test-stage4-rem-pooling.R`: `.pool_rem_cluster` su tibble fixture con 3 studi × 5 geni, verifica `metafor::rma` output + REML→DL fallback path su input degenerato.
- `test-stage4-mega-aug-assembly.R`: `.assemble_mega_aug_metadata` su fixture con 2 studi pair + 5 studi baseline → metadata tibble corretto, no duplicati sample.
- `test-stage4-direction-flip.R`: `direction_check == "swapped"` causa `logFC` negation in per_study_de + `direction_applied = "flipped"`.

### 7.2 Integration test

`test-stage4-fixture-mini.R`: end-to-end su Stadio 3 mini fixture (`inst/extdata/stage3-fixtures-mini/` da creare derivando 5 cluster sintetici dal Stadio 3 mini esistente) → build stage 4 → verifica:
- 6 file output presenti con schema corretto.
- No NA inattesi in `cluster_pooled.parquet$logFC_pool`.
- Almeno 1 cluster per ognuno dei 3 path (rem, mega, mega_aug).
- `run_id` riproducibile (re-run produce same id).

### 7.3 Replication / idempotence

`test-stage4-replication.R`: run stage 4 twice on same input → byte-equal output (modulo timestamp). Check:
- `run_id` deterministico.
- `per_study_de.parquet` byte-equal (parquet writer è deterministic con same compression).
- `cluster_pooled.parquet` byte-equal.
- `run_metadata.json` byte-equal modulo `timestamp` e `compute_summary` (`wall_seconds`).

### 7.4 Smoke 5-cluster pre-fullrun (β-style validation)

Script `analysis/p5-stage4-smoke5.R`. Cluster picks:

| # | cluster_id | Path | Razionale |
|---|---|---|---|
| 1 | `pair_L2_de50bf31` | REM (k=3 post-QC) | IFN A549, golden anchor da finding power gain; replica IFIT1 ~10×, MX1 ~8× |
| 2 | selected at plan time from `usable_rem_strict & k == 4` | REM | Coverage REM k=4 path |
| 3 | selected at plan time from `usable_mega_strict & n_studies == 5` | MEGA | Coverage MEGA strict base case |
| 4 | selected at plan time from `usable_mega_strict & n_studies >= 10` cell-line specifico | MEGA | Coverage MEGA strict large k |
| 5 | LNCaP CHEBI:17199 pair (Case 2 findings) | MEGA-AUG | Coverage MEGA-AUG path; baseline pool 50+ studi |

Picks 2-4 deterministicamente identificati nel plan via filtro su `clusters.rds` dell'output Stage 3 corrente, sortato per `n_total` desc + `safety_min` desc, primo match (riproducibilità del pick fissata dal seed = run_id Stage 3).

Wall budget atteso: ≤ 10 min total.
Validation manuale: 
- IFIT1 nel cluster 1 deve avere `logFC_pool ≈ 8.88, SE_pool ≈ 0.062, tau2 ≈ 0` (matchando finding power gain).
- Smoke gate prima del Layer A full: ≥ 4/5 cluster completati senza fallback paths attivati; cluster 1 replica golden anchor.

### 7.5 Performance smoke

`test-stage4-perf-budget.R` (skipped on CI, run manuale):
- Layer A full (412 cluster) → wall ≤ 90 min su laptop 16 core, ≤ 60 min su server 32+ core (post `availableCores() - 10` adjustment).
- Peak memory ≤ 16 GB.
- Output dir size ≤ 1 GB (escludendo counts cache, che vive fuori dal run dir).

## 8. Persistence + versioning

- `schema_versions.stage4_algorithm = "v1"`. Bump in caso di modifiche al QC, ai default config, o all'output schema (per-study + cluster_pooled).
- `run_id` deterministico hash di `(stage3_run_id + h5_sha256 + config + schema_versions)`.
- Counts cache: chiave content-addressed, sopravvive cross-run; cleanup manuale via `cache_purge_stage4()`. Mai auto-purge.
- Audit trail: nessun overwrite del dir output. Run history accumulata in `analysis/p4-output/`.

## 9. Rischi + open questions

| Rischio | Mitigazione |
|---|---|
| eBayes shrunk SE → REM REML sottostima τ² (double shrinkage) | Documented caveat in Methods e nello spec. v2 può aggiungere flag opt-in per unshrunk SE (`fit$stdev.unscaled * fit$sigma`). |
| Dream convergence failure su cluster MEGA piccoli (k=5, n_total=30) | `tryCatch` + fallback a `limma::voom + duplicateCorrelation(block = study)`. Log in `qc_report$pooling_warnings$kind = "dream_failed_falled_back_to_limma_dupcor"`. |
| MEGA-AUG baseline pool con high heterogeneity (50+ studi) | dream gestisce con random effect; `n_baseline_studies_augmented` in output permette stratificazione/sensitività post-hoc. |
| Counts cache disk growth oltre stima | Stima ~600 MB worst-case. `cache_purge_stage4()` funzione opt-in. Mai auto-purge cross-run. Logato in `compute_summary.counts_cache_misses`. |
| Layer A wall budget sforato | Profile post-smoke; ottimizzazioni in plan: parallel dream calls via BiocParallel, batched H5 reads, partial parquet writes. Non blocker architetturale. |
| HGNC symbol drift tra ARCHS4 v2.5 e gold v3 | ARCHS4 H5 ha rownames HGNC consolidati; verificare al build (sample match tra H5 `meta/genes/symbol` e gold), log mapping mismatches in qc_report. |
| Dashboard Quarto build fallisce per assenza Quarto CLI | `render_stage4_dashboard()` skip-gracefully con `if (!quarto::quarto_available()) warning(...); return(NULL)`. Dashboard è soft-deliverable, non blocking. |
| dream BPPARAM workers configurazione | dream usa BiocParallel; `BPPARAM = MulticoreParam(min(8, workers))` cap a 8 per ridurre RAM (cluster MEGA con 100+ sample × 30k geni può saturare RAM). Workers per-cluster, non per-gene. |

### Open questions per plan (non per spec)

1. `voomWithDreamWeights` vs `voom` standard per MEGA: dream documentation raccomanda `voomWithDreamWeights` per random-effect models. Verificare empiricamente sul smoke 5-cluster — se SE differ significativamente, locked-in.
2. `BiocParallel::MulticoreParam` setup ottimale: `workers = ?` (cap a 8 per default vs `availableCores() - 10`). Test perf sul smoke.
3. Dashboard cluster detail drill-down: come gestire 412 sezioni HTML in un singolo file? Embed lazily (htmlwidgets crosstalk) vs separate `cluster_<id>.html` files linked da overview. Decisione: single-file con crosstalk per portabilità (singolo deliverable).
4. Layer B picker selection persistence: export CSV vs integrazione con un futuro `layer_b_curation` module. Out-of-scope di Stage 4 v1; export CSV è MVP.

## 10. Decisioni rilevanti & cross-reference

- **ADR-0006** (positioning) — Stage 4 implementa la promessa "design-aware effect-size pooling cross-studio" che differenzia simulomicsr da RummaGEO et al.
- **ADR-0012** (stage2 schema multi-axis) — la limitazione `primary_role` mono-axis è già stata risolta da Stadio 3 via `direction_check`; Stage 4 applica il flip in per_study_de.
- **ADR-0014** (Stage 3) — Stage 4 consuma cluster output as-is, `usable_*` flags determinano selezione Layer A.
- **ADR-0015 NUOVO (Proposed con questo spec)** — Stage 4 three-path architecture (limma-voom REM + dream MEGA + dream MEGA-augmentation) con persistent counts cache, per-study DE artifact reusable, e Quarto diagnostic dashboard.
- **Finding scope decision** (2026-05-19) — Layer A = ~412 cluster definiti.
- **Finding power gain** (2026-05-19) — empirical evidence che pipeline funziona; `pair_L2_de50bf31` IFN A549 fissa il golden anchor per replication test.
- **Finding esempi metanalisi abilitate** (2026-05-19) — Case 2 LNCaP fissa il template MEGA-augmentation.
- **User DE methods benchmark** (memoria utente, non pubblicato) — limma-voom best-calibrated overall; razionale per engine choice in Methods.
- **CLAUDE.md** roadmap "Post-β immediato" punto 1 — questo spec realizza il "Output 3 ADR-0006".

---

**Pronto per review.** Dopo approvazione utente: ADR-0015 Proposed scritto in pair con questo spec, branch `p5-stadio4-de-perstudio` creato, prossimo step invocare `superpowers:writing-plans` per stendere il plan implementativo step-by-step (TDD bite-sized).
