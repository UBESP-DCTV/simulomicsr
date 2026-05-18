# Stadio 3 — Raggruppamento cross-studio sui comparability_anchor (design spec)

**Stato:** draft 2026-05-18 — in attesa di review utente
**Branch target:** `p5-stadio3-raggruppamento` (da creare partendo da `master` @ `p4-beta-rescue-complete`)
**Predecessore:** P4 β rescue complete (stage1 879.167 record 100% LLM-only + manual; stage2 39.247 predictions 100% schema validity)
**Successore previsto:** P5 Stadio 4 (DE per-studio) + P5 Stadio 5 (meta-analisi `metafor` REM) + mega-analisi opzionale via modello misto
**Decisioni rilevanti:** ADR-0006 (positioning vs RummaGEO), ADR-0012 (stage2 schema multi-axis limitation), ADR-0014 (nuova, Proposed con questo spec — Stage 3 tiered anchor + dual-mode + canonical directionality)

---

## 1. Contesto e obiettivo

Stadio 3 è il **collante deterministico cross-studio** della pipeline simulomicsr: trasforma le 39.247 stage2 predictions LLM-driven (entro lo studio: chi è treated, chi è control, con quale `comparability_anchor` v3) in **cluster cross-studio di sample/comparison comparabili** che alimentano:
- **Stadio 4** — DE per-studio (DESeq2/limma) sulle coppie originali within-study, output `(yi, vi)` per gene per comparison;
- **Stadio 5** — meta-analisi cross-studio:
  - **REM** (`metafor::rma`) sui cluster anchor-pair → effect-size pooled con τ², I², CI;
  - **MEGA-analisi** (modello misto su raw counts da ARCHS4 H5) sui cluster anchor-group → effect-size con study come random effect.

L'unicità di simulomicsr (vedi ADR-0006) risiede nella **canonical `comparability_anchor` v3 cross-studio** che permette pooling deterministico, in opposizione a RummaGEO (signature-based, no anchor canonico) e agli annotatori upstream (MetaHQ, ARCHS4, Mondal) che non producono confronti appaiati.

Stadio 3 non era esistente nella codebase prima di questo spec. `R/anchors.R::make_anchor()` produce anchor per-sample ma nessuna logica di matching cross-study. Questo design colma quel gap.

## 2. Goals & non-goals

### Goals

1. **Maximum data extraction** ("spremere per bene"): adaptive granularity via **5 livelli di strictness** (L0..L4) che relaxano progressivamente l'anchor per recuperare cluster k-deboli a livelli più stretti.
2. **Dual-mode output**: anchor-group (per mega-analisi su raw counts) E anchor-pair (per REM `metafor`), entrambi a tutti i 5 livelli. Decisione architetturale convalidata: ibrida (vs solo REM solo mega).
3. **Scientifically defensible pooling**: hard filters per partizioni biologicamente non-mergeabili; pooling safety score quantitativo per cluster; canonical directionality per evitare cancellation di segnale in REM.
4. **Reproducible + auditable**: `run_id` deterministico hash di input+config; metadata completa per re-build; versioning anchor schema embedded.
5. **Targets-pipeline native**: integrazione standard con la pipeline `_targets/` esistente del progetto; nessuna dipendenza nuova oltre `arrow` (già transitive via targets recenti).

### Non-goals

- **NON** esegue DE (Stadio 4) né meta-analisi (Stadio 5) — produce solo i cluster come input.
- **NON** corregge errori upstream (mouse-mislabeled GSE → β rescue Task 3+3b già completati).
- **NON** modifica `R/anchors.R::make_anchor()` esistente per-sample — quella funzione resta canonica per L0; Stage 3 introduce funzione **derivata** che droppa segmenti per L1..L4.
- **NON** ottimizza il rebuild a singoli record (no incremental; il rebuild completo è il pattern; il `run_id` dedup garantisce no overwrite).
- **NON** affronta tissue-cross pooling come default (rimane analisi additional su demand, mai automatica).

## 3. Architettura — 5 livelli + 2 hard filters + 2 modes

### 3.1 Tiered anchor (5 livelli, droppability biology-driven)

I 13 segmenti dell'`comparability_anchor` v3 (vedi `R/anchors.R::make_anchor()`) sono partizionati in 5 tier + 2 hard filter sulla base della **severità biologica** del pool-arli:

| Categoria | Segmenti | Razionale biologico |
|-----------|----------|---------------------|
| **Hard filters (2)** — partition, mai droppabili | `subcellular`, `context_kind` | Apples-vs-oranges quando non-default. Nuclear vs whole-cell RNA-seq = transcript populations diverse. Primary cells vs immortalized = baseline drift incomparabile. Definiscono sotto-popolazioni *non-mergeabili* a *qualunque* livello. |
| **Tier S — inviolabile (3)** | `kind_effective`, `agent_id`, `tissue` | Identità biologica minima del confronto. Cambiare uno = confronto diverso. Tissue confermato in S: cross-tissue pool è additional analysis dichiarata, non default. |
| **Tier A — system identity (3)** | `variant_label`, `disease_status`, `phase_canonical` | Differenze qualitative di stato del sistema. WT vs mutant, healthy vs disease, exposure vs washout/recovery sono stati biologicamente distinti. |
| **Tier B — modulators (2)** | `cell_state`, `cell_id` | Modulatori entro stesso tissue/context; generalmente pool-abili intra-tissue. Cell_state (proliferating/quiescent/differentiated) modula response a anti-mitotici, differenzianti. Cell_id (HUVEC vs HMEC entro endothelial) tollera pooling. |
| **Tier C — continuous (2)** | `dose_canonical`, `duration_canonical` | Variabili continue binnable; pooling crea "average effect" direzionalmente meaningful; P5 può modellarle come covariate. |
| **Tier D — low-info (1)** | `has_engineered` | Bool spesso ridondante con `variant_label` (entrambi derivati da `engineered_modifications`). Free merge a L1. |

**Droppability ordinata D → C → B → A → (S resta).** Genera 5 livelli:

| Livello | Anchor segmenti | Hard filters | Caso d'uso |
|---------|----------------|--------------|------------|
| **L0** | 11 (tutti i droppable) | 2 | REM gold-standard, max specificità |
| **L1** | 10 (drop D) | 2 | "Free merge" — collassa records che differiscono solo per `has_engineered` |
| **L2** | 8 (drop D+C) | 2 | Pool dose/tempo, REM con eterogeneità contained; P5 può covariare |
| **L3** | 6 (drop D+C+B) | 2 | Pool entro-tissue cross-cell-line — territorio mega-analisi |
| **L4** | 3 (solo Tier S) | 2 | Max aggressive: "imatinib-anywhere-in-muscle, healthy + disease, WT + variant" |

Hard filters `subcellular` + `context_kind` sono **sempre enforced** indipendentemente dal livello: i cluster a qualunque L sono partizionati primariamente da questi due segmenti, poi raggruppati per anchor key droppato.

### 3.2 Dual-mode clustering

Per ogni livello L ∈ {L0..L4} Stage 3 produce **due viste** di cluster:

| Mode | Unità | Anchor key | Consumo |
|------|-------|-----------|---------|
| **pair** | Comparison (treated_group ↔ control_group da stage2 schema) | `(treated_anchor_LX, control_anchor_LX, control_type)` per L0/L1; `(treated_anchor_LX, control_anchor_LX)` per L2+ (control_type droppato a livelli aggressivi) | REM `metafor::rma` su `(yi, vi)` per-comparison |
| **group** | Replicate_group (da stage2 schema) | `anchor_LX` singolo | Mega-analisi su raw counts ARCHS4: due anchor-group qualunque possono accoppiarsi a costo zero (controls riutilizzabili cross-comparison) |

Pair garantisce paired-comparisons within-study (Stage 4 fa DE su quella coppia). Group permette accoppiamento creativo cross-study a P5 (es. anchor-group "HUVEC vehicle 24h" con 200 sample da molti studi diversi può fare control per molti anchor-group treatment).

### 3.3 Canonical directionality (REM only)

**Problema:** anchor-pair key `(treated_anchor, control_anchor, control_type)` non enforce by-design il **senso** del contrasto. Due studi possono assegnare ruoli opposti per la stessa comparison biologica:
- Studio A: `treated_group=imatinib-treated`, `control_group=vehicle` → yi = logFC(imatinib/vehicle), up-genes positive.
- Studio B (LLM error o convention diversa): `treated_group=vehicle`, `control_group=imatinib` → yi = logFC(vehicle/imatinib), up-genes negative.

Naive pooling cancella il segnale.

**Soluzione:** Stage 3 detecta direction non-canonical e **espone flag**, non flippa automaticamente:

| `control_type` | Convention canonica |
|----------------|---------------------|
| `vehicle`, `untreated`, `genetic_negative`, `inducer_off`, `time_zero` | `control_group` è baseline; `treated_group` è perturbed |
| `disease_normal` | `control_group=healthy`; `treated_group=disease` |
| `secondary_arm` | Ambiguous — flag `direction_check="ambiguous"` |

Per ogni comparison, Stage 3 calcola `direction_check ∈ {canonical, swapped, ambiguous, indeterminate}`:
- **canonical**: il ruolo assegnato matcha la convention.
- **swapped**: rilevato role swap (es. `control_type=vehicle` ma `treated_anchor$kind_effective=vehicle_only`).
- **ambiguous**: convention non determinabile (secondary_arm, multi-arm complex).
- **indeterminate**: anchor incompleti per il check.

P5 al consumption time, se `direction_check=swapped`, moltiplica yi per -1 prima del pooling REM. Records con `ambiguous`/`indeterminate` vanno in `non_clusterable.rds` per REM (non per MEGA).

## 4. Quality scoring + use-flags

### 4.1 Pooling safety score

Per ogni cluster a livello L, quantifica la heterogeneity dei segmenti droppati:

```
Per ogni segmento s ∈ dropped_segments(L):
  safety_s(C) = max_v(frequency di v nel cluster C[s])   # modal frequency

safety_min(C)       = min(safety_s)         # primary aggregator (weakest-link)
safety_geom_mean(C) = geom_mean(safety_s)   # secondary, softer
safety_per_segment(C) = named list {s: safety_s}  # raw distribution for custom analysis
```

Per L0 (nessun segmento droppato): `safety_min = safety_geom_mean = 1.0` per convention.

**Razionale min vs geom_mean:** convention statistica QC privilegia weakest-link. Esempio: 4 dropped, {seg1=0.9, seg2=0.9, seg3=0.9, seg4=0.1} → min=0.1 (unsafe correttamente), geom=0.52 (nasconde l'asse problematico). Min cattura la realtà: un singolo asse near-random invalida pool su quell'asse.

### 4.2 Boolean use-flags (sostituiscono tier labels)

In luogo di GOLD/SILVER/BRONZE labels heuristici, ogni cluster espone 4 flag funzionali:

| Flag | Criteri |
|------|---------|
| `usable_rem_strict` | `mode=pair` AND `level∈{L0,L1}` AND `k≥k_recommended_rem` (=3) AND `safety_min≥0.7` |
| `usable_rem_relaxed` | `mode=pair` AND `k≥k_min_rem` (=2) AND `safety_min≥0.5` |
| `usable_mega_strict` | `mode=group` AND `level∈{L0,L1}` AND `n_studies≥5` AND `n_total≥30` AND `safety_min≥0.7` |
| `usable_mega_relaxed` | `mode=group` AND `n_studies≥2` AND `n_total≥10` AND `safety_min≥0.5` |

P5 filtra trivialmente: `filter(stage3_clusters, usable_rem_strict)`. Niente ambiguità di "tier value".

### 4.3 Thresholds (configurable via R options)

Default in `stage3_default_config()`:

```r
list(
  rem  = list(k_min = 2, k_recommended = 3, k_gold = 10),
  mega = list(n_studies_min = 2, n_studies_recommended = 5, n_studies_gold = 10,
              n_total_recommended = 30),
  safety = list(strict = 0.7, relaxed = 0.5)
)
```

k_gold=10 (non 5) per τ² affidabile (Veroniki et al. 2016, REML). Configurabile via `getOption("simulomicsr.stage3.thresholds")` per analisi custom.

### 4.4 Eligibility filter (record-level, pre-clustering)

Records esclusi a monte:
- **Tier S incomplete**: `kind_effective="unclear" OR agent_id∈{"unknown","unclear"} OR tissue="na"`. Non clusterizzabile a nessun L (tier S sempre presente).
- **REM-mode only**: comparison dove `n_treated_group<2 OR n_control_group<2`. Tale comparison non può produrre `(yi, vi)` da DESeq2/limma → escluso da pair clusters.
- **Directionality ambiguous/indeterminate**: escluso da pair clusters (vedi 3.3); restano in group clusters (mega può accoppiare creativamente).

Records esclusi vanno in `non_clusterable.rds` con `reason` esplicita.

## 5. Output schema (5 file in directory versionata)

```
analysis/p4-output/<YYYYMMDDTHHMMSSZ>-stage3-<run_id>/
├── assignments.parquet
├── clusters.rds
├── record_summary.rds
├── non_clusterable.rds
└── run_metadata.json
```

### 5.1 `assignments.parquet` (~390k rows, columnar)

| Column | Type | Notes |
|--------|------|-------|
| `record_id` | string | Per `mode=pair`: `<series_id>__<comparison_id>`. Per `mode=group`: `<series_id>__<group_id>`. |
| `mode` | factor | `pair` ∣ `group` |
| `level` | integer | 0..4 |
| `cluster_id` | string | `sprintf("%s_L%d_%s", mode, level, xxhash32(anchor_key))` |

Long format. ~39247 record × 5 livelli × 2 mode ≈ 390k rows worst case (minus records che non passano eligibility per uno o entrambi i mode). Parquet per columnar filter veloce.

### 5.2 `clusters.rds`

| Column | Type | Notes |
|--------|------|-------|
| `cluster_id` | string | Primary key |
| `mode` | factor | `pair` ∣ `group` |
| `level` | integer | 0..4 |
| `anchor_key` | string | Stringified anchor at level L (e.g., `"small_molecule\|CHEMBL941\|wt\|10nM\|24h\|exposure\|HUVEC\|cell_line\|proliferating"` at L0). For `mode=pair`: `"<treated>__VS__<control>__CT_<control_type>"`. |
| `k` | integer | Per `pair`: n unique studi. Per `group`: n unique studi. |
| `n_total` | integer | Sample totali (sum su replicate_groups del cluster) |
| `n_treated` / `n_control` | integer | Solo `mode=pair` |
| `safety_min` | double | Min modal-freq across dropped segments. 1.0 a L0. |
| `safety_geom_mean` | double | Geom mean (secondary) |
| `safety_per_segment` | list<named double> | Per-segment modal freq |
| `usable_rem_strict` / `usable_rem_relaxed` / `usable_mega_strict` / `usable_mega_relaxed` | logical | Boolean use-flags |
| `direction_check` | factor | `canonical` ∣ `swapped` ∣ `ambiguous` ∣ `indeterminate` ∣ `na` (na per `mode=group`) |
| `gpl_platforms` | list<character> | Unique GPL IDs per studi del cluster (da ARCHS4 metadata) |
| `n_gpl_distinct` | integer | length(gpl_platforms) |
| `library_strategies` | list<character> | Se disponibile da ARCHS4 metadata (verificare al build; se assente, droppare colonna) |
| `n_distinct_donors` | integer | Se estraibile da `stage1_facts$donor`; NA altrimenti |
| `studies_in_cluster` | list<character> | Set di GSE IDs |
| `n_studies` | integer | length(studies_in_cluster) |

### 5.3 `record_summary.rds`

| Column | Type | Notes |
|--------|------|-------|
| `record_id` | string | |
| `mode` | factor | `pair` ∣ `group` (un record può apparire in entrambi se eligible) |
| `min_viable_level_rem` | factor | `L0`..`L4` ∣ `NONE`. Solo per `mode=pair`. Lowest L dove il cluster è `usable_rem_relaxed`. |
| `min_viable_cluster_rem` | string | Cluster ID a `min_viable_level_rem` |
| `min_viable_level_mega` | factor | Solo per `mode=group`. Lowest L dove cluster è `usable_mega_relaxed`. |
| `min_viable_cluster_mega` | string | |
| `in_n_clusters_rem` | integer | Quanti pair-cluster diversi (across L) contengono questo record |
| `in_n_clusters_mega` | integer | Idem per group |
| `direction_check` | factor | Solo `mode=pair` |

Default partition non-overlapping per P5 quick-start: ogni record sceglie il min_viable_level e P5 analizza a quel livello.

### 5.4 `non_clusterable.rds`

| Column | Type | Notes |
|--------|------|-------|
| `record_id` | string | Stesso schema di `assignments.parquet` |
| `mode` | factor | `pair` ∣ `group` (no `both`: un record escluso da entrambi i mode genera due righe distinte) |
| `reason` | factor | `tier_s_incomplete` (applicabile a entrambi i mode) ∣ `rem_eligibility_n1` (solo pair) ∣ `direction_ambiguous` (solo pair) ∣ `direction_indeterminate` (solo pair) |
| `details` | string | Free-text diagnostic (e.g., "agent_id=unknown", "n_treated_group=1") |

### 5.5 `run_metadata.json`

Schema completo:

```json
{
  "run_id": "<8-hex hash>",
  "timestamp": "ISO 8601",
  "schema_versions": {
    "anchor": "v3",
    "stage3_algorithm": "v1",
    "sample_facts": "stage1.v3",
    "study_design": "stage2.v2"
  },
  "package_version": "...",
  "r_version": "...",
  "input_files": {
    "stage1_master": {"path": "...", "sha256": "...", "n_records": ...},
    "stage2_master": {"path": "...", "sha256": "...", "n_records": ...}
  },
  "config": {
    "thresholds": {...},
    "tier_assignment": {
      "S": ["kind_effective","agent_id","tissue"],
      "A": ["variant_label","disease_status","phase_canonical"],
      "B": ["cell_state","cell_id"],
      "C": ["dose_canonical","duration_canonical"],
      "D": ["has_engineered"],
      "hard_filters": ["subcellular","context_kind"]
    }
  },
  "output_counts": {
    "n_records_input_stage2": ...,
    "n_records_clusterable_pair": ...,
    "n_records_clusterable_group": ...,
    "n_non_clusterable_records": ...,
    "n_clusters_per_level": {"pair": {"L0": ..., "L1": ..., ...}, "group": {...}},
    "n_assignments_total": ...
  }
}
```

`run_id = substr(digest(canonical_form(input_files + config + schema_versions)), 1, 8)` — deterministico. Same input + same config → same run_id → same directory. Re-run con config diverso → nuovo run_id, no overwrite.

## 6. API surface

Funzioni esposte (`@export`):

| Funzione | Signature | Scopo |
|----------|-----------|-------|
| `build_stage3_clusters()` | `(stage1_master, stage2_master, config = stage3_default_config(), archs4_metadata = NULL)` → `stage3_result` S3 | Entry-point principale. `archs4_metadata=NULL` skippa GPL/library_strategy enrichment (le colonne corrispondenti in `clusters.rds` saranno NA o omitted; `n_distinct_donors` resta calcolabile da stage1 facts). |
| `stage3_default_config()` | `()` → `list` | Config default con tier assignment + thresholds |
| `write_stage3_to_dir()` | `(s3, dir)` → invisible(`character` paths) | Scrive 5 file nel dir convenzionale |
| `load_stage3()` | `(dir)` → `stage3_result` | Reads back |
| `filter_clusters()` | `(s3, mode = c("pair","group"), usability = c("strict","relaxed","any"))` → `tbl_df` | Helper filter |
| `cluster_records()` | `(s3, cluster_id)` → `tbl_df` | Lookup record di un cluster |

Funzioni internal (`@keywords internal`):

- `.build_anchor_for_level(stage1_fact, stage2_role, level, tier_assignment)` — variante di `make_anchor()` che droppa segmenti per L1..L4
- `.compute_pooling_safety(cluster_records, dropped_segments)` — implementa §4.1
- `.check_direction_canonical(comparison, treated_anchor, control_anchor, control_type)` — implementa §3.3
- `.tag_cluster_usability(cluster_row, thresholds)` — calcola i 4 boolean `usable_*`
- `.partition_by_hard_filters(records)` — partition primaria per `(subcellular, context_kind)`
- `.assign_records_to_clusters(...)` — orchestratore matching key-based (group_by anchor_key)

## 7. Integrazione targets

In `analysis/_targets.R` (additivo, non sostituisce target esistenti):

```r
list(
  # ... targets esistenti P2/P3/P4 ...

  tar_target(stage3_config, stage3_default_config()),
  tar_target(stage1_master_path,
             "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl",
             format = "file"),
  tar_target(stage2_master_path,
             "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds",
             format = "file"),
  tar_target(archs4_metadata,
             load_archs4_metadata(h5_path = "analysis/input/human_gene_v2.5.h5"),
             format = "rds"),

  tar_target(
    stage3_run,
    build_stage3_clusters(
      stage1_master = stage1_master_path,
      stage2_master = stage2_master_path,
      archs4_metadata = archs4_metadata,
      config = stage3_config
    ),
    format = "rds"
  ),

  tar_target(
    stage3_out_dir,
    {
      dir <- file.path(
        "analysis/p4-output",
        sprintf("%s-stage3-%s",
                format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
                stage3_run$run_metadata$run_id)
      )
      write_stage3_to_dir(stage3_run, dir)
      dir
    },
    format = "file"
  )
)
```

Re-run idempotent: stesso input+config → stesso `run_id` → stesso dirname (modulo timestamp prefix). Il timestamp prefix garantisce coerenza con P4 collect-dir convention; il `run_id` suffix garantisce dedup logico.

## 8. Test strategy

### 8.1 Unit tests (`tests/testthat/test-stage3-anchor-levels.R`)

- Tier assignment immutable (test that `stage3_default_config()$tier_assignment` matches expected partition).
- `.build_anchor_for_level()` per ogni L produce stringa con il numero corretto di segmenti.
- Hard filters: records con `subcellular="nuclear"` non si raggruppano con `subcellular="whole_cell"` a *nessun* L.
- L0 cluster ⊆ L1 cluster ⊆ ... ⊆ L4 cluster (property-based: per ogni record, cluster_size monotonic ascending in L).
- `safety_min(L0) = 1.0` always.

### 8.2 Integration test (`tests/testthat/test-stage3-fixture-mini.R`)

Fixture: 5 GSE da `inst/extdata/stage2-fixtures-mini/` esistente (copre design_kind eterogenei: `case_control_disease`, `treatment_vs_vehicle`, `treatment_vs_untreated`, `knockdown_panel`, `multi_arm_treatment`).

End-to-end: build clusters → verifica:
- Output dir contiene 5 file expected.
- `assignments.parquet` ha N_records × 5 × {1..2} rows.
- `clusters.rds` ha colonne expected con tipi corretti.
- `run_metadata.json` parseable e `run_id` riproducibile a re-run.
- Almeno 1 cluster per ogni livello L0..L4.
- Almeno 1 cluster `direction_check="canonical"` e idealmente uno `swapped` (fixture potrebbe richiedere injection di swap test-case).

### 8.3 Performance smoke (`tests/testthat/test-stage3-perf-budget.R` skipped on CI)

Su full β stage2 (39.247 record):
- Wall time end-to-end ≤ **15 min** su laptop standard (target P5 plan).
- Memory peak ≤ 4 GB.
- Output dir size ≤ 200 MB.

Se sforati: ottimizzazioni candidate in plan (data.table groupby invece di dplyr, parallelism cross-level via `future`, ecc.).

## 9. Persistence + versioning details

- **Versioning anchor schema**: `schema_versions.anchor` in run_metadata. Upgrade a v4 future invalida automaticamente i `cluster_id` (intended: anchor diverso → cluster diversi).
- **Versioning stage3 algorithm**: `schema_versions.stage3_algorithm = "v1"`. Bump a v2 se cambiamo tier assignment, threshold defaults, o aggreghiamo safety differente.
- **Idempotenza**: `run_id` hash di `(input_files.sha256 + config + schema_versions)` → re-run stesso input genera stessa dir.
- **Audit trail**: nessun overwrite. Run history accumulata in `analysis/p4-output/`. Cleanup manuale.

## 10. Rischi + open questions

| Rischio | Mitigazione |
|---------|-------------|
| `library_strategies` non disponibile in ARCHS4 metadata | Verificare al build, droppare colonna se assente. Non-blocker. |
| Donor info sporadico in `stage1_facts` | Colonna `n_distinct_donors` può essere quasi-sempre NA in pratica. Acceptable; resta per gli studi dove c'è. |
| Cluster L4 troppo grandi/inutili (es. "any small_molecule effect in muscle" con 500 record) | `safety_min` basso → `usable_rem_strict=FALSE`. P5 filtra. Quality flag fa il lavoro. |
| Hard filter `context_kind` troppo aggressivo (separa iPSC-derived da primary anche se similar) | ADR-0014 documenta tradeoff. Configurabile via custom config se utente vuole rilassare. |
| Direction swap detection produce molti falsi-`indeterminate` | Plan deve includere validazione manuale su sample di comparisons. Threshold di confidence puo' essere aggiunto in v2. |
| Performance >15min budget | Ottimizzazione iterativa in plan: data.table, future, partial parquet writes. Non architecturally blocker. |

### Open questions per plan (non per spec)

1. Quale path di lettura per `stage1_master` JSONL (879k record): full load in memory vs streamed `jsonlite::stream_in()` con pre-filtering ai GSM referenziati in stage2?
2. ARCHS4 metadata caricamento: full H5 (~47 GB) re-open ogni run, o cache `data.frame` con (sample_id, gse, gpl, library_strategy) in `tools::R_user_dir("simulomicsr")`?
3. Bootstrap confidence intervals su `safety_min` come additional QC (out-of-scope per v1)?

## 11. Decisioni rilevanti & cross-reference

- **ADR-0006** (positioning) — Stage 3 è il pezzo che differenzia simulomicsr da RummaGEO (anchor canonico cross-study).
- **ADR-0012** (stage2 schema multi-axis) — Stage 3 ricostruisce direzione tramite `direction_check` perché `primary_role` mono-axis non è sufficiente.
- **ADR-0014 (nuovo, Proposed)** — Stage 3 tiered anchor (5 livelli) + hard filters + dual-mode (pair/group) + canonical directionality. Sostituisce l'implicito assunto pre-Stage-3 di "anchor singolo L0 strict only".
- **CLAUDE.md** — pipeline overview: Stage 3 è output 1 di P5 spec (post-β); P5 Stage 4+5 consumeranno questo output.

---

**Pronto per review.** Dopo approvazione utente, prossimo step: invocare `superpowers:writing-plans` per stendere il plan implementativo step-by-step (TDD bite-sized).
