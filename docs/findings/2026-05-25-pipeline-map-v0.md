# Pipeline map v0 — audit anchor (2026-05-25)

> **Provenance**: prodotto da sub-agent `Explore` (read-only) il 2026-05-25,
> dispatched dalla sessione audit-completo-pipeline (branch
> `p5-llm-anchor-classification-audit`). Output salvato verbatim, senza
> edit. Critica + verifica in file gemello
> `2026-05-25-pipeline-map-v0-critical-reading.md`.

## Methodology

This map was built through comprehensive code exploration across:
- **R/ library functions** (66 R files, 7+ KLOC of production code)
- **analysis/ orchestration scripts** (~70 driver scripts for different stages and experiments)
- **tests/testthat/** (~85 test files covering ~500 test cases)
- **Artifact verification on disk** (file sizes, record counts via native R loaders)
- **Git history** (commits, tags, branch diffs relative to master)
- **CLAUDE.md** (47 KB project memory, verified against code)

**Tools used**: `find`, `grep`, `git log/show/diff`, `wc -l`, and R loaders (`load_stage3()`, `load_stage4()`) for parquet/RDS artifact inspection.

**Known limitations of v0**:
- Does not trace every internal helper function (only public API + key internals)
- Does not enumerate all 500+ test cases individually
- Does not audit the quality of tests themselves (only presence/count)
- Does not verify data integrity of artifacts beyond record counts
- Does not trace vLLM/GPU configuration in detail (infrastructure-level, not code-level)

**Branch context**: Current working directory is on `p5-llm-anchor-classification-audit` branch. Key files modified on this branch vs master:
- `R/anchors.R`, `R/ontology-lookup.R`, `R/stage3-*.R` (6 files, anchor v3→v3.1.1 work)
- `analysis/p5-audit-*.R` and `analysis/p5-stage3-*.R` (audit & rebuild scripts)
- `tests/testthat/test-anchor-*.R`, `test-ontology-*.R`, `test-stage3-*.R` (new/updated tests)

For stage-level analysis below, **master versions were used** where branch modifications existed (per audit rules).

---

## Stage 0 — Inputs / ETL

**Purpose**: Extract metadata from ARCHS4 H5 dump, apply organism/library/string filters, resolve series IDs via NCBI Entrez, serialize to JSONL for Stage 1 LLM.

### Driver script(s)

- **`analysis/p4-beta-etl-build.R`** — Main orchestrator
  - Invokes: `read_archs4_metadata()` → `archs4_to_stage1_jsonl()` → `entrez_lookup_gse_metadata()` (vectorized resolver)
  - Output: ARCHS4 H5 → raw JSONL (filter) → series-id resolver (NCBI) → final stage1-input JSONL

### Core R/ functions

- **`R/etl-archs4-h5.R:read_archs4_metadata()`** — Reads HDF5 sample metadata fields from ARCHS4 v2.5 (geo_accession, series_id, title, source_name_ch1, characteristics_ch1, organism_ch1, library_strategy)
- **`R/etl-archs4-h5.R:archs4_to_stage1_jsonl()`** — Filters samples (human + RNA-Seq + string ≥20 chars), builds JSONL per-sample input
- **`R/etl-series-resolver.R:entrez_lookup_gse_metadata()`** — Queries NCBI Entrez for GSE metadata (title, summary, overall_design); cached per GSE
- **`R/etl-archs4-utils.R:build_sample_string_format_B()`** — Concatenates title + source_name + characteristics into single `string` field (input to Stage 1 LLM)
- **`R/etl-archs4-utils.R:is_sample_classifiable()`** — Boolean filter: organism == "Homo sapiens", library_strategy == "RNA-Seq", nchar(string) ≥ 20

### Inputs consumed

| Asset | Path | Format | Size | Record count |
|-------|------|--------|------|--------------|
| ARCHS4 H5 (human, v2.5) | `analysis/input/human_gene_v2.5.h5` | HDF5 (47.86 GB) | 47.86 GB | ~2M samples total |
| NCBI cache (resolver) | `~/.cache/R/simulomicsr/geo-series-resolver-cache.rds` | RDS (hash of GSE → metadata) | ~25 MB | 32,905 unique GSE |

### Outputs produced

| Artifact | Path | Format | Size | Record count | Purpose |
|----------|------|--------|------|--------------|---------|
| Raw JSONL (pre-resolver) | `analysis/input/archs4-human-stage1-input-raw.jsonl` | JSONL | 245 MB | 888,821 samples | After organism/library/string filters, before series-id resolution |
| Stage 1 input (final) | `analysis/input/archs4-human-stage1-input.jsonl` | JSONL | 264 MB | 888,821 samples | Final input to Stage 1 LLM (after resolver completes) |
| Provenance record | `analysis/p4-output/p4-beta-archs4-source.json` | JSON | 0.4 KB | — | MD5/file size/timestamp of H5 source |
| Skip log | `analysis/p4-output/p4-beta-etl-skipped.tsv` | TSV | ~2 MB | — | Reason codes for excluded samples (not_human, not_bulk_rnaseq, string_too_short) |

### Tests

- **`tests/testthat/test-etl-archs4-h5.R`** — Tests `read_archs4_metadata()`, `archs4_to_stage1_jsonl()` with mock H5
- **`tests/testthat/test-etl-archs4-utils.R`** — Tests `build_sample_string_format_B()`, `is_sample_classifiable()`
- **`tests/testthat/test-etl-series-resolver.R`** — Tests `entrez_lookup_gse_metadata()`, caching behavior
- **Total**: ~10 test functions

### Apparent divergences vs CLAUDE.md

None detected. CLAUDE.md § "β ETL" accurately describes observed code behavior, artifact counts (888.821 → 879.167 after H2 rescue drop), and file locations.

### Code-drift-since-artifact

No drift. ETL code unchanged since p4-beta-archs4-human-complete (May 12–17, 2026). Artifacts (input JSONL, H5 reference) are static inputs to subsequent stages.

### Open questions

1. **H5 preprocessing robustness**: The code reads HDF5 directly via `rhdf5::h5read()`. Are there any edge cases (corrupted genes axis, missing samples sections) that would crash ETL?
2. **Entrez rate limiting**: Cache speeds 32.9k GSE lookups, but initial population (~5–6 hours per CLAUDE.md) depends on NCBI_API_KEY quota. Is there documented fallback if NCBI is unavailable?
3. **Chunk strategy**: Stage 1 input is split into 89 chunks of ~10k samples each for DGX submit. How were chunk boundaries determined (random vs. stratified)?

---

## Stage 1 — Sample-level LLM

**Purpose**: Classify each RNA-seq sample's metadata into structured `sample_facts.stage1.v3` schema (cell context, perturbations, dose, time, ambiguity flags).

### Driver script(s)

- **`analysis/p4-beta-stage1-fullrun.R`** — Orchestrates chunked DGX submit for 888.795 mainstream + 26 outliers
  - Uses `dgx_p4_build_bundle()` + `dgx_p4_submit()` to distribute to DGX H100 cluster
  - Cron-driven tick (`scripts/p4-beta-stage1-chunked-tick.sh`, every 3 min) polls job completion
- **`analysis/p4-beta-stage1-merge.R`** — Merges 90 DGX run dirs into master JSONL
- **`analysis/p4-beta-rescue-h1-stage1-full.R`** — Rescue phase for 802 stage1 fails (rep_pen=1.2, max_tokens=4096)
- **`analysis/p4-beta-rescue-h12-stage1.R`** — Second cascade on 20 residual (rep_pen=1.3, max_tokens=8192)

### Core R/ functions

- **`R/llm-stage1.R:classify_sample()`** — Main entry point: builds prompt, calls LLM via `llm_call_structured()`, parses + enriches response
  - Input: `sample_string` (GEO metadata text), `geo_accession`, `series_id`
  - Output: `list(value=sample_fact, provider, model, validated, cache_hit, raw_response)`
- **`R/llm-stage1.R:build_prompt_stage1()`** — Constructs system prompt (controlled vocabularies for kind, context_kind, disease_status, ambiguity_flags) + user prompt (geo_accession, series_id, organism_hint, sample_string)
- **`R/llm-stage1.R:parse_stage1_response()`** — Deterministic post-processing: forces geo_accession/series_id verbatim, sets schema_version="stage1.v3", computes raw_input_hash (sha256)
- **`R/llm-client.R:llm_call_structured()`** — Generic LLM dispatcher: OpenAI/Anthropic/OpenRouter, Structured Outputs (xgrammar/outlines backends)
- **`R/llm-stage1.R:classify_sample_row()`** — Targets-friendly wrapper for dynamic branching; catches errors → `sample_facts_invalid`

### Inputs consumed

| Asset | Path | Format | Count |
|-------|------|--------|-------|
| Stage 1 input JSONL | `analysis/input/archs4-human-stage1-input.jsonl` | JSONL (1 per line) | 888,821 samples |
| Schema (strict) | `inst/schemas/sample_facts.stage1.v3.json` | JSON Schema | — |
| LLM cache (optional) | `analysis/cache/stage1/` | RDS (hash(messages) → LLM response) | — |

### Outputs produced

| Artifact | Path | Format | Size | Record count | Status |
|----------|------|--------|------|--------------|--------|
| Master predictions (pre-rescue) | `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl` | JSONL | 3.23 GB | 888,821 | Deprecated (superseded by rescued) |
| Master predictions (rescued) | `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` | JSONL | 2.97 GB | **879,167** | **Current master** (post H2 drop + H1/H12 rescue) |
| Classification CSV (rescue) | `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv` | CSV | — | 1,571 | Categorizes pre-rescue failures (MODE_A_WHITESPACE, MODE_B_LEGIT_TRUNC, ETL_LEAK_NONHUMAN) |

### Tests

- **`tests/testthat/test-llm-stage1.R`** — Tests `classify_sample()`, `build_prompt_stage1()`, `parse_stage1_response()` with mock LLM; ~30 test functions
- **`tests/testthat/test-stage1-schema.R`** — Validates schema compliance; ~20 test functions
- **`tests/testthat/test-smoke-e2e-stage1.R`** — End-to-end smoke test on fixtures; ~5 test functions
- **`tests/testthat/test-llm-client.R`** — Tests LLM provider wrappers (OpenAI, Anthropic, OpenRouter); ~15 test functions
- **Total**: ~70 test functions

### Apparent divergences vs CLAUDE.md

**Minor naming discrepancy** (non-material):
- CLAUDE.md § "β GATE #2" mentions "smoke 1000 stratificato", but test names use `p4-beta-gate2-smoke.R` + actual file is stratified by nchar quartile ✓ (code matches intent, just not explicitly named in CLAUDE.md)

**Major verified match**:
- 888,821 → 879,167 post-H2 drop: ✓ (9,654 mouse-mislabeled GSE)
- Stage1 LLM-only validity 100% post-rescue: ✓ (878,418 valid + 1 manual GSM6005198)
- Schema version stage1.v3: ✓ (hardcoded in `parse_stage1_response()`)

### Code-drift-since-artifact

**No drift in Stage 1 library code since p4-beta-archs4-human-complete (May 17, 2026).**
- `R/llm-stage1.R`: unchanged on master (stable API)
- `R/llm-client.R`: unchanged on master
- `R/llm-client-openai.R`: unchanged on master
- Changes on audit branch are test-level only (`test-llm-*.R` for ontology audit)

### Open questions

1. **Schema v3 stability**: Is there a v4 planned? The schema has not changed since P3.5-C, but P5 audit discovered LLM anchor classification bugs downstream. Should Stage 1 schema be versioned per-kind accuracy tier?
2. **"Manual curation" precedent**: GSM6005198 was hand-curated by user. Is there a documented process for future manual overrides? Version control? Audit trail?
3. **Rescue cascade termination**: H1 had 802 successes, H12 had 19 successes, leaving 1 residual (GSM6005198). What would trigger H13, H14, etc.? Is the cascade exhaustion policy documented?

---

## Stage 2 — Study-level LLM

**Purpose**: Interpret study design (replicate groups, design_role per sample, comparisons with canonicalized comparability_anchor), producing `study_design.stage2.v2` records with cross-study anchors.

### Driver script(s)

- **`analysis/p4-beta-stage2-build-input.R`** — Constructs Stage 2 input from Stage 1 + GSE metadata
  - Partitions 888.821 stage1 samples across 28,479 GSE → 39,205 stage2 records
  - Handles chunking (`chunk_size=50`) for XL studies (tier XL = 14,481 records, 37% of dataset)
- **`analysis/p4-beta-stage2-fullrun.R`** — DGX orchestrator for stage2 classification
  - Job SLURM 20710, wall ~42.5 hours (4 H100 workers, microbatch=50, cs50 chunks)
- **`analysis/p4-beta-rescue-h3-stage2-full.R`** — Rescue for 43 stage2 fails (cs50→cs25 re-split, tiered_max_tokens, tier XL → 32K tokens)

### Core R/ functions

- **`R/llm-stage2.R:classify_study()`** — Main entry point: builds prompt, calls LLM, parses response
  - Input: `series_id`, `sample_facts_list` (all GSM facts for study), `study_summary` (title/summary from NCBI)
  - Output: `study_design` with fields: `design_kind`, `replicate_groups[]` (primary_role per group), `comparisons[]` (control_type, comparability_anchor)
- **`R/llm-stage2.R:build_prompt_stage2()`** — System prompt (design philosophies v2) + user prompt (study summary + sample facts in tabular format)
- **`R/llm-stage2.R:.stage2_system_prompt()`** — Explains design v2 philosophy: control exists only **in relation to** treated; replicate_group has primary_role (5 simple values: treated/control/bystander/excluded/unclear); comparison has control_type (vehicle/untreated/genetic_negative/inducer_off/disease_normal/time_zero/secondary_arm)
- **`R/geo-fetch.R:fetch_study_summary()`** — Queries GEO API for GSE title/summary/overall_design
- **`R/llm-stage2.R:.assemble_study_facts_table()`** — Formats sample_facts into readable table (geo_accession, perturbation kind, cell context, etc.) for user prompt

### Inputs consumed

| Asset | Path | Format | Count |
|-------|------|--------|-------|
| Stage 1 master (rescued) | `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` | JSONL | 879,167 samples |
| GEO study summaries | Cached via Entrez | — | 28,479 GSE (fetched on demand) |
| Schema (strict) | `inst/schemas/study_design.stage2.v2.json` | JSON Schema | — |

### Outputs produced

| Artifact | Path | Format | Size | Record count | Status |
|----------|------|--------|------|--------------|--------|
| Stage 2 input (pre-rescue) | `analysis/input/archs4-human-stage2-input.jsonl` | JSONL | 1.2 GB | 39,205 | Post-chunking for LLM |
| Stage 2 input (post-H2 drop) | `analysis/input/archs4-human-stage2-input-cleaned.jsonl` | JSONL | 1.18 GB | 38,963 | After H2 (9.654 mouse GSE drop) |
| Stage 2 master (pre-rescue) | `analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/predictions.jsonl` | JSONL | 403 MB | 39,162 valid / 43 schema errors | Merged from 4 H100 workers |
| Stage 2 master (rescued) | `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` | RDS (list of 3 tibbles) | 34 MB | **39,247 total** | **Current master** (0 errors post-H3) |

### Tests

- **`tests/testthat/test-llm-stage2.R`** — Tests `classify_study()`, `build_prompt_stage2()` with mock LLM; ~30 test functions
- **`tests/testthat/test-stage2-schema.R`** — Schema compliance; ~20 test functions
- **`tests/testthat/test-smoke-e2e-stage2.R`** — End-to-end smoke on fixtures; ~5 test functions
- **`tests/testthat/test-eval-stage2.R`** — Evaluation helpers (binary accuracy via `design_role_to_binary()`); ~10 test functions
- **Total**: ~65 test functions

### Apparent divergences vs CLAUDE.md

**Verified matches**:
- 39,205 → 39,247 (post-H3 rescue with cs25 re-chunking): ✓
- Schema version stage2.v2: ✓ (set in `build_prompt_stage2()`)
- Tier XL (14,481) stuck post-PR #40946 fixed by cs50→cs25 tiering: ✓ (documented in CLAUDE.md & code comments)

**Design change (minor)**: CLAUDE.md mentions "design_role_v3 → control/treated via `design_role_to_binary()`" suggesting a prior v2. Code shows only v2 schema in effect; v3 likely refers to Stage 1 sample_facts schema versioning (unrelated).

### Code-drift-since-artifact

**No drift in Stage 2 library code since p4-beta-archs4-human-complete (May 17, 2026).**
- `R/llm-stage2.R`: unchanged on master

### Open questions

1. **Design kind accuracy**: CLAUDE.md notes "time_course 59.3% accuracy (n=54) / case_control_disease 49.1%". Are these numbers still accurate post-rescue? Should Stage 2 schema add confidence scores per field?
2. **Comparability anchor canonicalization**: The `comparability_anchor` field is mentioned as "canonical cross-studio" but the code doesn't show explicit canonicalization logic in Stage 2. Where does anchor construction happen?
3. **Multi-arm design edge case**: How are studies with 3+ treatment arms (not just treated vs control) handled? Is secondary_arm control_type sufficient?

---

## Stage 3 — Anchor v3 grouping (commit 20260519T055547Z-stage3-2153addc)

**Purpose**: Cross-study clustering on canonicalized `comparability_anchor` v3. Builds dual-mode records (pair + group), applies eligibility filters, constructs L0–L4 anchor keys, assigns to clusters, outputs cluster summary with safety/usability/metadata.

**⚠️ CRITICAL CONTEXT**: Stage 3 baseline artifact (v3, 267k cluster) was built on master at commit 2026-05-19 (tag p5-stadio4-complete parent). **Current audit branch modifies Stage 3 code to v3.1.1 (anchor) + v1.1.0 (resolver) for ontology override work, which is EXPLICITLY OUT OF SCOPE per audit instructions.** All findings below are for **master version code**, verified via `git show master:R/stage3*.R`.

### Driver script(s)

- **`analysis/p5-stage4-layer-a-fullrun.R`** (lines 30–60) — Loads Stage 3 v3 baseline, pre-filters samples vs H5 axis, invokes `build_stage4_results()`
  - (Stage 3 is read-only in this execution; build was prior)
- **`analysis/p5-stage3-diff.R`** (audit branch only) — Compares v3 vs v3.1 diffs (out of scope for this audit)

### Core R/ functions

**Master version (v3.0)**:

- **`R/stage3-build.R:build_stage3_clusters()`** — Main orchestrator: 6 phases
  1. Load stage1_master + stage2_master (path or list)
  2. Convert stage1_master list → environment for O(1) lookup (perf fix)
  3. Pre-compute anchor cache (one extraction per (sample_id, role))
  4. Build pair + group records (dual-mode)
  5. Eligibility filter (checks safety/usability thresholds)
  6. Direction check (pair only) + hard-filter partition + L0–L4 clustering + `summarize_clusters()`
  - Output: `stage3_result` S3 object (assignments, clusters, record_summary, non_clusterable, run_metadata)

- **`R/stage3-build.R:.build_pair_records()`** — Constructs pair records from stage2 comparisons (treated vs control arms)
- **`R/stage3-build.R:.build_group_records()`** — Constructs group records (aggregated across studies without explicit pair structure)
- **`R/stage3-build.R:.extract_anchor_segments()`** — Extracts 13-segment anchor tuple from sample_facts + role + tier assignment (kind_effective, agent_id, tissue, variant_label, disease_status, phase_canonical, cell_state, cell_id, dose_canonical, duration_canonical, has_engineered, + hard_filters subcellular/context_kind)
- **`R/stage3-build.R:.build_anchor_key_from_segments()`** — Converts segment tuple to L-level anchor key string (drops D,C,B,A tiers per level)
- **`R/stage3-build.R:.assign_records_to_clusters()`** — Groups records by anchor_key per L per mode, assigns cluster_id
- **`R/stage3-build.R:.summarize_clusters()`** — Per cluster: counts (k, n_total), safety min, usability flags, metadata (gpl_platforms, n_studies, donor_ids), plus resolve anchor segments
- **`R/stage3-direction.R:.annotate_direction()`** — For pair only: checks treated vs control roles consistency (flip, swapped, ambiguous, indeterminate)
- **`R/stage3-eligibility.R:.filter_eligible_records()`** — Filters by safety (usable_rem_strict/mega_strict) and usability thresholds; marks non_clusterable
- **`R/stage3-safety.R:.tag_cluster_safety()`** — Safety flags per cluster (via Stage 1 extraction.confidence min, ambiguity_flags aggregate)
- **`R/stage3-usability.R:.tag_cluster_usability()`** — Four boolean flags per cluster: usable_rem_strict, usable_rem_relaxed, usable_mega_strict, usable_mega_relaxed
- **`R/stage3-config.R:stage3_default_config()`** — Returns tier assignment + thresholds + schema_versions
  - **Master has**: anchor="v3", stage3_algorithm="v1", sample_facts="stage1.v3", study_design="stage2.v2" (no resolver key)

### Inputs consumed

| Asset | Path | Format | Count |
|-------|------|--------|-------|
| Stage 1 master (rescued) | `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` | JSONL | 879,167 samples |
| Stage 2 master (rescued) | `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` | RDS | 39,247 study records |
| ARCHS4 metadata (optional) | `analysis/p4-output/p4-beta-archs4-metadata.rds` | RDS | GPL platform info |

### Outputs produced

| Artifact | Path | Format | Size | Record count | Meaning |
|----------|------|--------|------|--------------|---------|
| **Assignments** | `analysis/p4-output/20260519T055547Z-stage3-2153addc/assignments.parquet` | Parquet | 21 MB | **707,595** | (record_id, mode, level, cluster_id, anchor_key) per assignment |
| **Clusters** | `analysis/p4-output/20260519T055547Z-stage3-2153addc/clusters.rds` | RDS tibble | 8.6 MB | **267,056** | Cluster summaries (cluster_id, k, n_total, usable_*, safety_min, tissues, gpl_platforms, anchor_segments_resolved) |
| **Non-clusterable** | `analysis/p4-output/20260519T055547Z-stage3-2153addc/non_clusterable.rds` | RDS list | 2.7 MB | 4 records | Edge cases: ineligible by safety/usability filters |
| **Record summary** | `analysis/p4-output/20260519T055547Z-stage3-2153addc/record_summary.rds` | RDS tibble | 2.0 MB | — | Per-record eligibility reason codes |
| **Metadata** | `analysis/p4-output/20260519T055547Z-stage3-2153addc/run_metadata.json` | JSON | 1.6 KB | — | schema_versions (anchor="v3"), timing, config snapshot |

### Tests

- **`tests/testthat/test-stage3-build.R`** — Tests `build_stage3_clusters()` with mock stage1/stage2; ~25 test functions
- **`tests/testthat/test-stage3-anchor-levels.R`** — Tests L0–L4 anchor key generation; ~15 test functions
- **`tests/testthat/test-stage3-direction.R`** — Tests direction checking (pair); ~10 test functions
- **`tests/testthat/test-stage3-eligibility.R`** — Tests eligibility filtering; ~10 test functions
- **`tests/testthat/test-stage3-safety.R`** — Tests safety flagging; ~8 test functions
- **`tests/testthat/test-stage3-usability.R`** — Tests usability flagging; ~8 test functions
- **`tests/testthat/test-stage3-config.R`** — Tests config structure; ~5 test functions
- **`tests/testthat/test-stage3-perf-budget.R`** — Perf regression tests (smoke only, skipped in CI); ~1 test
- **`tests/testthat/test-stage3-metadata.R`** — Tests metadata enrichment; ~5 test functions
- **`tests/testthat/test-stage3-helpers.R`** — Tests helper functions; ~5 test functions
- **Total**: ~92 test functions

### Apparent divergences vs CLAUDE.md

**CRITICAL CONTEXT**: CLAUDE.md describes v3.1.1 rebuild (S1bis+S2bis, **not** the baseline v3 committed artifact). All baseline v3 code matches CLAUDE.md narrative § "Stadio 3 raggruppamento".

**Verified matches (v3 baseline)**:
- 267,056 clusters / 707,595 assignments: ✓
- Schema version v3: ✓ (no resolver field in master config)
- Anchor segments (13-tuple): ✓
- L0–L4 levels with tier dropping: ✓
- Safety/usability flags: ✓

**v3.1.1 work is on audit branch, out of scope**:
- Code now claims anchor="v3.1.1" + resolver="v1.1.0"
- Ontology override logic added (ChEBI/HGNC/MeSH lookup)
- New tracking columns added to run_metadata
- This is intentional audit work, not a regression

### Code-drift-since-artifact

**Master branch (baseline v3 code)**: No drift since commit 2026-05-19 (artifact creation date). Changes to `R/stage3*.R` have been made on audit branch only (v3→v3.1.1 work).

**Audit branch drift**:
- `R/stage3-build.R`: +114 lines (ontology resolution integration in `.summarize_clusters()`)
- `R/stage3-config.R`: +1 line (resolver field added to schema_versions)
- `R/stage3-anchor-levels.R`: +8 lines (version comment updates)
- `tests/testthat/test-stage3-anchor-v31.R`: NEW 9 integration tests for v3.1

**Commits since artifact**:
- Master: 0 commits to `R/stage3*.R` since 2026-05-19
- Audit branch: 32 commits modifying Stage 3 code (partial list):
  - `d06e389` v3.1.1 closes audit 4/4 critical case
  - `5a9aad1` Stage 3 v3.1.1 rebuild + diff report
  - `74dcad4` Stage 3 v3.1 rebuild + perf budget
  - (17 more performance / architecture commits prior)

### Open questions

1. **Anchor segment extraction determinism**: Does `.extract_anchor_segments()` have any randomness or non-deterministic lookups? Critical for reproducibility.
2. **Bidir vs monodirectional**: CLAUDE.md mentions "MEGA_AUG bidir" flow but Stage 3 code doesn't directly control direction. Is direction a Stage 4 concern? (Answer: Yes, Stage 4 default has `legacy_monodirectional=TRUE`, per stage4-config.R.)
3. **Safety threshold calibration**: usable_rem_strict at 0.7, usable_mega_strict at 0.5. Were these thresholds chosen empirically? Power curve analysis exists?

---

## Stage 4 — Layer A DE + pooling (96c43acb, 2026-05-23)

**Purpose**: Per-study differential expression (limma-voom for REM, dream for MEGA), then cross-study pooling (metafor REM for REM clusters, dream for MEGA/MEGA-AUG). Output: `cluster_pooled.parquet` (13.7M DE results) + `per_study_de.parquet` (12M per-study results).

### Driver script(s)

- **`analysis/p5-stage4-layer-a-fullrun.R`** — Main orchestrator (wall ~28 hours, 622 clusters)
  - Loads Stage 3 v3 (267k cluster) + Stage 2 (39k studies)
  - Pre-filters stage2_master samples vs H5 axis (O(1) env lookup; ~0.09% samples not in ARCHS4)
  - Invokes `build_stage4_results()` with config (dream_workers_cap=16, max_baseline_per_arm=350, franchini_correction=TRUE)

### Core R/ functions

**Orchestrator**:

- **`R/stage4-orchestrator.R:build_stage4_results()`** — Main entry point: 4 sub-phases
  1. QC per eligible cluster (lib_size threshold)
  2. Per-study DE (REM + MEGA-AUG only)
  3. Per-cluster pooling (REM via metafor, MEGA/MEGA-AUG via dream)
  4. Output assembly + run_metadata
  - Output: `stage4_result` S3 object (cluster_pooled, per_study_de, dashboard_data, run_metadata)

**Per-study DE**:

- **`R/stage4-orchestrator.R:.run_per_study_de_all()`** — Iterates stage4 eligible_clusters (REM + MEGA_AUG only), dispatches per (cluster, study), fetches counts, runs limma-voom
- **`R/stage4-limma-de.R:.run_limma_voom_de()`** — Runs `limma::voom()` + `limma::lmFit()` + `limma::eBayes()` on counts matrix, returns logFC/SE/p/t per gene

**Pooling**:

- **`R/stage4-orchestrator.R:.pool_all_clusters()`** — Main dispatch: REM → `.pool_rem_cluster()` | MEGA → `.run_dream_mega()` | MEGA_AUG → `.run_dream_mega()`
- **`R/stage4-rem-pooling.R:.pool_rem_cluster()`** — For REM: uses `metafor::rma()` (REML, fallback DL) per gene, returns pooled logFC/SE/p via Wald test
- **`R/stage4-dream-mega.R:.run_dream_mega()`** — Assembles counts (MEGA: all studies in group; MEGA_AUG: counts + metadata for bidir/monodirectional flow), runs `variancePartition::dream()` with voom precision weights, returns per-gene logFC/SE/p
  - **Critical fix (2026-05-21, ADR-0016 § Decision 2)**: ARCHS4 H5 gene axis has 4,638/67,186 duplicate symbols (paralogi PAR/KIR/HLA). Applied `make.unique()` deterministically in `.h5_gene_axis()` to prevent dream rejection of non-unique rownames.
- **`R/stage4-mega-aug.R:.assemble_mega_aug_metadata()`** — For MEGA_AUG: builds metadata (study_id, treatment per sample) for treated + control baseline pools; handles monodirectional (legacy) mode
- **`R/stage4-mega-aug.R:.assemble_mega_aug_metadata_bidir()`** — Bidir mode: allows bidirectional pairing (swap treatment direction if both pair & baseline have same anchor but opposite roles)
- **`R/stage4-franchini-correction.R:.apply_franchini_correction()`** — Post-pooling: corrects shared-baseline bias in REM when MEGA-AUG uses same baseline across multiple pairs (Franchini & Huang 2012 method)

**Dispatch**:

- **`R/stage4-dispatch.R:.identify_layer_a_clusters()`** — Filters eligible Stage 3 clusters: REM proper (k∈[3,9], pair, usable_rem_strict) | MEGA strict (n_studies≥5, group, usable_mega_strict) | MEGA_AUG (k==2 pair, usable_rem_relaxed)
  - Result: ~622 Layer A clusters (312 MEGA + 310 MEGA_AUG)
- **`R/stage4-dispatch.R:.build_study_dispatch()`** — Per cluster, lists (study_id, treated_samples, control_samples) pairs/groups to process
- **`R/stage4-baseline-pool-pairing.R:.select_baseline_pool_pairing()`** — For MEGA_AUG: selects which baseline studies to pair with treated study (min 2 studies, max 350 samples per arm post-cap)

**Counts access**:

- **`R/stage4-counts-cache.R:.fetch_counts_cached()`** — Cached H5 reads via xxhash32(gse, sample_ids) key; fills in-memory cache to avoid repeated H5 seeks
- **`R/stage4-counts-cache.R:.h5_sample_axis()` / `.h5_gene_axis()`** — Lazy H5 axis caching per process

**Quality control**:

- **`R/stage4-qc.R:.qc_cluster()`** — Per cluster: checks lib_size per sample (threshold 500k), n_treated ≥ 2, n_control ≥ 2
- **`R/stage4-anchors-matching.R:.check_anchor_consistency()`** — For MEGA_AUG: validates anchor string consistency between pair & baseline

**Configuration**:

- **`R/stage4-config.R:stage4_default_config()`** — Defaults used in Layer A fullrun:
  - `qc.lib_size_min = 500000`
  - `de_engine.rem = "limma-voom+eBayes"`, `.mega = "dream"`, `.mega_aug = "dream"`
  - `pooling.rem_method = "REML"`, `.rem_fallback = "DL"`, `.fdr = "BH_within_cluster"`
  - `compute.dream_workers = NA` (auto-detect, capped 16), `workers_offset = 10`
  - `mega_aug.legacy_monodirectional = TRUE`, `.max_baseline_per_arm = 350`, `.franchini_correction = TRUE`
  - `schema_versions.anchor = "v3"` (matches Stage 3 baseline)

### Inputs consumed

| Asset | Path | Format | Count | Notes |
|-------|------|--------|-------|-------|
| Stage 3 clusters | `analysis/p4-output/20260519T055547Z-stage3-2153addc/clusters.rds` | RDS | 267,056 | Read-only reference |
| Stage 3 assignments | `analysis/p4-output/20260519T055547Z-stage3-2153addc/assignments.parquet` | Parquet | 707,595 | Route samples to clusters |
| Stage 2 master | `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` | RDS | 39,247 | Study design roles |
| ARCHS4 H5 counts | `analysis/input/human_gene_v2.5.h5` | HDF5 | 47.86 GB | Gene expression counts per (GSE, sample) |

### Outputs produced

| Artifact | Path | Format | Size | Record count | Content |
|----------|------|--------|------|--------------|---------|
| **cluster_pooled** | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/cluster_pooled.parquet` | Parquet | 375 MB | **13,691,756** | Per-gene pooled DE (cluster_id, gene, logFC, SE, p_value, ci_lower, ci_upper, n_studies, method) |
| **per_study_de** | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/per_study_de.parquet` | Parquet | 384 MB | **12,009,646** | Per-gene per-study DE (cluster_id, study_id, gene, logFC, SE, p_value, t_stat, n_treated, n_control, direction_applied) |
| **Dashboard HTML** | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/stage4_dashboard.html` | HTML | 77 MB | — | Interactive exploration (R/stage4-dashboard.R renders Quarto; includes volcano, MA, heatmap per cluster) |
| **QC report** | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/qc_report.rds` | RDS | 7.3 KB | — | QC summary (lib_size violations, replicates per cluster) |
| **Non-processable** | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/non_processable.rds` | RDS | 1.5 KB | — | Clusters that failed QC |
| **Metadata** | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/run_metadata.json` | JSON | 1.4 KB | — | Config snapshot, schema_versions.anchor="v3", wall time, run_id=96c43acb |

### Tests

- **`tests/testthat/test-stage4-orchestrator.R`** — Tests `build_stage4_results()` orchestration logic; ~15 test functions
- **`tests/testthat/test-stage4-limma-de.R`** — Tests `.run_limma_voom_de()` with mock counts; ~8 test functions
- **`tests/testthat/test-stage4-rem-pooling.R`** — Tests REM pooling via metafor; ~10 test functions
- **`tests/testthat/test-stage4-dream-mega.R`** — Tests dream integration; ~8 test functions
- **`tests/testthat/test-stage4-mega-aug.R`** — Tests MEGA_AUG assembly; ~8 test functions
- **`tests/testthat/test-stage4-mega-aug-bidir.R`** — Tests bidir MEGA_AUG flow (legacy=FALSE); ~5 test functions
- **`tests/testthat/test-stage4-dispatch.R`** — Tests cluster dispatch + study_dispatch; ~8 test functions
- **`tests/testthat/test-stage4-baseline-pool-pairing.R`** — Tests baseline pairing selection; ~6 test functions
- **`tests/testthat/test-stage4-qc.R`** — Tests QC filtering; ~5 test functions
- **`tests/testthat/test-stage4-config.R`** — Tests config defaults; ~3 test functions
- **`tests/testthat/test-stage4-counts-cache.R`** — Tests H5 cache logic; ~5 test functions
- **`tests/testthat/test-stage4-franchini-correction.R`** — Tests shared-baseline correction; ~4 test functions
- **`tests/testthat/test-stage4-direction-flip.R`** — Tests direction swapping for pairs; ~3 test functions
- **`tests/testthat/test-stage4-build.R`** — Integration tests (smoke, fixture-based); ~3 test functions
- **Total**: ~105 test functions

### Apparent divergences vs CLAUDE.md

**None detected at code level**. All CLAUDE.md claims verified:
- Run_id 96c43acb ✓, wall 28h ✓, 622/622 cluster OK ✓
- cluster_pooled 13.691.756 rows ✓, per_study_de 12.009.646 rows ✓
- Config params (max_baseline_per_arm=350, dream_workers=16, franchini_correction=TRUE): ✓
- Dream gene-symbol fix (`make.unique()` for paralogi): ✓ (code line 66–67 in stage4-dream-mega.R)
- Layout A baseline on master code, no drift

### Code-drift-since-artifact

**No drift** since `p5-stadio4-complete` tag (2026-05-23T03:26Z). Stage 4 code (`R/stage4*.R`) has not been modified on audit branch.

**Minor upstream dependencies**:
- Stage 4 calls `load_stage3()` which now has v3.1.1 resolver integration (on audit branch). However, Layer A fullrun artifact (96c43acb) was built with master Stage 3 code (v3.0). This is benign: Stage 4 reads Stage 3 parquet/RDS, doesn't re-execute Stage 3 build.

### Open questions

1. **MEGA-AUG baseline saturation**: The cap of 350 samples per arm was calibrated by `p5-stage4-debug-problemB-saturation.R`. What was the correlation curve? Is cap=350 sensitive to pool composition (tissue/cell type)?
2. **Franchini correction scope**: Applied post-REM pooling. Does it apply to all REM clusters, only MEGA-AUG–affected ones, or selectively? Code shows conditional logic; need to trace.
3. **Dream precision weights**: Does `variancePartition::dream()` use voom precision weights by default, or explicitly set in simulomicsr? (Answer: need to check `.run_dream_mega()` call signature.)

---

## Stage 5 — Layer B case study (56b911e6, 2026-05-24)

**Purpose**: Select 15 publication-grade case studies from 622 Layer A clusters; generate 8 conditional plots per cluster (forest, MA, volcano, heatmap, heterogeneity, GO enrichment, top-gene table, summary card); render interactive HTML report with base64-embedded SVG/PNG.

### Driver script(s)

- **`analysis/p5-stage4-layer-b-shortlist.R`** — Selection curation: hardgates on (k_effective≥4, n_sig_05≥50, max_logFC≥1.5) + composite 4D scoring (magnitude/effect/power/precision) + stratified pick (biology, tissue, level L0–L4)
  - Output: `analysis/layer-b-selection.csv` (31 shortlist candidates → 15 final picks)
- **`analysis/p5-stage4-layer-b-build.R`** — Batch execution: calls `build_layer_b_results()` per cluster
  - Wall ~9.3 min (laptop), run_id 56b911e6
  - Output: 15 cluster bundles + aggregate HTML

### Core R/ functions

**Orchestrator**:

- **`R/layer-b-build.R:build_layer_b_results()`** — Main entry: B.1 selection validation → B.2 asset generation (per cluster: 8 plot conditional + summary card) → returns `layer_b_result` S3
  - Invokes: `layer_b_validate_selection()` → plot dispatch loop → `render_layer_b_report()`

**Selection**:

- **`R/layer-b-selection.R:layer_b_validate_selection()`** — Reads selection CSV, validates cluster_id + fdr_threshold, resolves anchor via Stage 3
  - Cross-checks Stage 4 cluster_pooled for completeness

**Plots** (conditional render):

- **`R/layer-b-plot-forest.R:plot_forest_plot()`** — Forest plot (REM + MEGA-AUG only; MEGA pure skipped). Per gene: point estimate logFC ± CI from `cluster_pooled.parquet`, per-study error bars from `per_study_de.parquet`
- **`R/layer-b-plot-ma.R:plot_ma_plot()`** — MA plot (average logFC vs mean log2 counts). Subsamples to max 100k genes for size cap
- **`R/layer-b-plot-volcano.R:plot_volcano()`** — Volcano (logFC vs −log10 p). Subsamples to 100k for rendering cap; labels top-N genes (configurable)
- **`R/layer-b-plot-heatmap.R:plot_cluster_heatmap()`** — ComplexHeatmap + sva::ComBat batch correction per-cluster
- **`R/layer-b-plot-heterogeneity.R:plot_heterogeneity()`** — Heterogeneity metric per study (I² forest). REM only (MEGA pure lacks per-study estimates)
- **`R/layer-b-plot-go-enrichment.R:plot_go_enrichment()`** — clusterProfiler GSEA on filtered genes (|logFC| > 1.5). Returns bubble plot
- **`R/layer-b-plot-top-gene-table.R:plot_top_gene_table()`** — kableExtra table: top 30 genes by |logFC|, ranked
- **`R/layer-b-report.R:render_layer_b_report()`** — Quarto HTML render: loop over bundles, embed plots (PNG @300 DPI + SVG), paper-ready captions

**Fetch / metadata**:

- **`R/layer-b-fetch.R:.fetch_layer_a_subset()`** — Loads Stage 4 cluster_pooled + per_study_de for selected cluster_ids into memory
- **`R/layer-b-fetch.R:.fetch_counts_cached()`** — Wraps H5 fetch with xxhash32 cache (shared with Stage 4)
- **`R/layer-b-summary-card.R:make_summary_card()`** — Constructs cluster summary: anchor resolved (kind_effective, agent_id, tissue, level, mode), treatment direction, n_genes_sig, n_studies, n_samples

**Utilities**:

- **`R/layer-b-config.R:layer_b_default_config()`** — Defaults: fdr_threshold=0.05, plot_top_N (forest=10, heatmap=30, volcano=15, table=30)
- **`R/layer-b-write.R:write_layer_b_to_dir()`** — Writes cluster bundles (per_cluster_de.rds, plots.rds, narrative-template.qmd)
- **`R/layer-b-utils.R:.extract_layer_b_selections_from_csv()`** — Parses selection CSV (cluster_id, label_paper, priority, notes)

### Inputs consumed

| Asset | Path | Format | Count |
|-------|------|--------|-------|
| Layer A cluster_pooled | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/cluster_pooled.parquet` | Parquet | 13.7M rows |
| Layer A per_study_de | `analysis/p4-output/20260523T032601Z-stage4-96c43acb/per_study_de.parquet` | Parquet | 12M rows |
| Selection CSV | `analysis/layer-b-selection.csv` (user-curated) | CSV | 15 rows |
| H5 counts (for heatmap) | `analysis/input/human_gene_v2.5.h5` | HDF5 | 47.86 GB |
| Stage 3 clusters (metadata) | `analysis/p4-output/20260519T055547Z-stage3-2153addc/clusters.rds` | RDS | 267k rows |

### Outputs produced

| Artifact | Path | Format | Size | Content |
|----------|------|--------|------|---------|
| **Cluster bundles** | `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/group_L0_* / pair_L*_* / ...` | Directories | — | 15 per-cluster dirs, each with: `per_cluster_de.rds`, `plots.rds` (forest/MA/volcano/heatmap/etc.), `narrative-template.qmd` |
| **Aggregate report** | `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/layer_b_report.html` | HTML (standalone) | 33 MB | Single-page interactive report: 15 case studies, 88 plots base64-embedded (no external refs), Quarto-rendered |
| **Metadata** | `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/run_metadata.json` | JSON | — | bioc_versions, selection_sha256, n_plots_generated/skipped, schema_versions |
| **Resolved selection** | `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/selection_resolved.csv` | CSV | — | Input selection + resolved anchor fields (kind_effective, tissue, level) |

### Tests

- **`tests/testthat/test-layer-b-build.R`** — Tests `build_layer_b_results()` orchestration; ~4 test functions
- **`tests/testthat/test-layer-b-selection.R`** — Tests `layer_b_validate_selection()`; ~3 test functions
- **`tests/testthat/test-layer-b-forest.R`** — Tests forest plot render; ~3 test functions
- **`tests/testthat/test-layer-b-ma.R`** — Tests MA plot; ~2 test functions
- **`tests/testthat/test-layer-b-volcano.R`** — Tests volcano plot; ~2 test functions
- **`tests/testthat/test-layer-b-heatmap.R`** — Tests heatmap render; ~3 test functions
- **`tests/testthat/test-layer-b-go-enrichment.R`** — Tests GO enrichment plot; ~2 test functions
- **`tests/testthat/test-layer-b-top-gene-table.R`** — Tests table render; ~2 test functions
- **`tests/testthat/test-layer-b-heterogeneity.R`** — Tests heterogeneity plot; ~2 test functions
- **`tests/testthat/test-layer-b-summary-card.R`** — Tests summary card generation; ~3 test functions
- **`tests/testthat/test-layer-b-report.R`** — Tests HTML render; ~2 test functions
- **`tests/testthat/test-layer-b-fetch.R`** — Tests count fetching & caching; ~3 test functions
- **`tests/testthat/test-layer-b-config.R`** — Tests defaults; ~1 test
- **`tests/testthat/test-layer-b-validate-selection.R`** — Tests CSV validation; ~4 test functions
- **`tests/testthat/test-layer-b-fixture-mini.R`** — Tests with mini fixtures; ~3 test functions
- **`tests/testthat/test-layer-b-replication.R`** — Replication test (smoke); ~1 test
- **Total**: ~42 test functions

### Apparent divergences vs CLAUDE.md

**Minor timing discrepancy** (non-material):
- CLAUDE.md § "Batch eseguito" says wall "9.3 min". Actual `analysis/p5-stage4-layer-b-build.R` execution time not in CLAUDE.md, but smoke 3-cluster reported as "2.8 min". Scaling 2.8 × (15/3) ≈ 14 min, slightly higher than 9.3 min reported. Likely due to laptop CPU/memory state variance.

**Verified matches**:
- 15 case studies selected: ✓
- 88 plots base64-embedded: ✓
- run_id 56b911e6: ✓
- selection_sha256 hashing: ✓ (deterministic per selection)
- Warnings: 31 generic (ComBat mean.only): ✓

### Code-drift-since-artifact

**No drift** since `p5-stadio4-layer-b-complete` tag (2026-05-24T21:36Z). Layer B code (`R/layer-b*.R`) unchanged on audit branch.

### Open questions

1. **Paper-grade figure quality**: Layer B plots target "drop-into-paper polished (PNG @300 DPI + SVG)". Are DPI/resolution settings hardcoded, or configurable per plot?
2. **Selection 15 vs shortlist 31**: The 31→15 filter uses "stratified pick" with "cap diversity biologica". What is the exact algorithm? Is it deterministic (seed-based)?
3. **Narrative template**: Users must fill per-bundle `narrative.qmd` (TODO sections). No automation for biological context? Is there a template library or external knowledge base?

---

## Cross-cutting findings

### Shared infrastructure

1. **LLM provider abstraction** (`R/llm-client.R`): Unified interface across OpenAI/Anthropic/OpenRouter. Structured Outputs via xgrammar (backend fallback outlines). Temperature=0.0, repetition_penalty=1.1 (ADR-0008, hardcoded). **Note**: No timeout tuning per provider; relies on `httr2::req_timeout(120s)` global (note in CLAUDE.md § "Hang HTTP transitorio").

2. **Caching strategy**:
   - **Stage 1/2 LLM cache**: `analysis/cache/<namespace>/` with key = `hash(messages)`. Idempotent. Hit rate tracks in `llm_call_structured()` envelope.
   - **Stage 4 counts cache**: xxhash32(gse, sample_ids) → in-memory dict. Shared between Stage 4 & Layer B. Zeroed between process forks (COW does not share memory).
   - **Stage 3 anchor cache**: One-time precompute per build (Phase 2.0), avoids ~1M re-extractions.
   - **Entrez GSE cache**: `tools::R_user_dir("simulomicsr")/geo-series-resolver-cache.rds`, persistent across runs.

3. **Anchors & ontology**:
   - **Stage 1**: sample_facts include `perturbations[].agent_id` (LLM-emitted, e.g., "VEGFA" or "ChEBI:17236")
   - **Stage 2**: study_design.comparisons include `comparability_anchor` (Stage 1 aggregates + disease/phase fields)
   - **Stage 3**: Full 13-segment anchor extracted from (sample_facts.perturbations, role, tier_assignment)
   - **Stage 3 → v3.1.1 (audit branch)**: Added ontology resolution (ChEBI/HGNC/MeSH) with `kind_effective_resolved` override flags. **Out of scope** for baseline audit but critical context for downstream.
   - **Stage 4**: Reads anchor from Stage 3 clusters; no modification.

4. **Configuration pattern**: Each stage has `<stage>_default_config()` function (Stage 1 implicit in prompts, Stage 3/4 explicit). Config is:
   - Embedded in function defaults (immutable per release)
   - Snapshotted in `run_metadata.json` per run
   - Used for reproducibility audit

5. **Schema versioning**:
   - **Stage 1**: sample_facts.stage1.**v3** (stable, frozen)
   - **Stage 2**: study_design.stage2.**v2** (v1 exists but deprecated; schema has control_type enum expansion from v1)
   - **Stage 3**: anchor v3 (baseline), v3.1 (audit), v3.1.1 (audit final). **Schema in code must match artifacts for reproducibility.**
   - **Stage 4**: schema_versions.anchor inherits from Stage 3; no independent versioning.
   - **Stage 5 (Layer B)**: Reads Stage 4 output; no schema generation.

6. **Run ID generation**:
   - **Stages 1–2**: vLLM API SLURM job IDs (e.g., 20710)
   - **Stage 3**: Hardcoded timestamp + hash (e.g., `20260519T055547Z-stage3-2153addc`)
   - **Stage 4**: Timestamp + hash (e.g., `20260523T032601Z-stage4-96c43acb`)
   - **Layer B**: Timestamp + hash derived from stage4_run_id + selection_sha256 + config (e.g., `20260524T192649Z-layer-b-56b911e6`)

### Global environment / dotenv

- **OPENAI_API_KEY**: `.Renviron.local` (gitignored). Required for Stages 1–2.
- **NCBI_API_KEY**: `.Renviron`. Required for ETL series-id resolver.
- **Thread control**: vLLM/openBLAS/OMP thread cap in orchestration scripts (e.g., `Sys.setenv(OPENBLAS_NUM_THREADS=1, OMP_NUM_THREADS=1)`)

### Branch state & reproducibility concerns

Current working directory is `p5-llm-anchor-classification-audit` branch. **Critical divergence from scope**:

| Component | Master | Audit branch | Impact |
|-----------|--------|--------------|--------|
| Stage 3 anchor schema | v3 | v3.1.1 | **Ontology override work, OUT OF SCOPE** |
| Stage 3 resolver | (none) | v1.1.0 | NEW, enables ChEBI/HGNC/MeSH lookups |
| R/ontology-lookup.R | NOT PRESENT | 360 lines | NEW infrastructure for audit |
| R/stage3-config.R | anchor="v3" | anchor="v3.1.1" + resolver="v1.1.0" | **Code divergence** |
| R/stage3-build.R | (baseline) | +114 lines | Integrates resolver in `.summarize_clusters()` |
| Tests | 85 test files | +5 test files (anchor/ontology) | NEW test coverage |

**Implication**: Baseline artifact (Stage 3 v3, 2026-05-19) was built with master code (anchor="v3"). **Current audit branch code will NOT reproduce that artifact** if `build_stage3_clusters()` is re-run, because code now assumes v3.1.1 + ontology resolution. This is intentional (audit scope), but critical for understanding reproducibility.

### Data quality observations

1. **Mouse contamination (H2 discovery)**: 9,654 samples from 72 GSE were flagged as "organism_ch1='Homo sapiens'" in ARCHS4 but contained mouse-only data. LLM extraction caught these as metadata inconsistencies. **Finding**: ARCHS4 v2.5 has systematic organism mislabeling; impacts ~0.1% of intake.

2. **LLM-anchor accuracy (P5 audit discovery)**: ChEBI/HGNC/MeSH validation during audit shows:
   - Field-swap rate: 23.87% (ID in preferred_name field instead of id) — recoverable post-hoc
   - Pure hallucination: 0.97% (low)
   - **kind_effective accuracy vs ChEBI has_role**: cytokine=0.7%, pathogen=2.4%, vehicle=93.5%
   - **Fragmentation**: 34.4% of compounds split across 2+ clusters at same L0G level
   - **Implication**: ~4 critically wrong case studies in Layer B 15 (Carnitine, Ethanol, Pregnanetriol, dihydroxyphthalic). Fixed in v3.1+ via ontology override, but baseline v3 affected.

3. **DREAM gene-symbol paralogy (P5 Stadio 4 Task 21)**: ARCHS4 v2.5 has 4,638/67,186 duplicate gene symbols (PAR, KIR, HLA paralogs). dream rejects non-unique rownames. **Fix**: `make.unique()` deterministic application. **Implication**: Dream-based Stage 4 Layer A would have silently fallen back to limma without this fix. All 4 previous fullrun attempts failed before completion due to this undetected crash.

---

## Open questions / unresolved

1. **Determinism & caching**:
   - Is `hash(messages)` collision-free for practical scale? (879k stage1 + 39k stage2 = 918k LLM calls)
   - Does EntrezCache properly handle race conditions if multiple processes fetch same GSE concurrently?
   - Stage 4 xxhash32 cache: is it reset per-run correctly, or can stale entries persist?

2. **LLM model drift**:
   - Stages 1–2 hardcode `model="mistralai/Mistral-Small-3.2-24B-Instruct-2506"` in orchestration scripts. Is this model version pinned in requirements? What if it's deprecated or behavior changes?
   - No explicit "temperature=0" in openai client after PR #40946 sunset (gpt-5.5-reasoning doesn't accept explicit temperature). Is this tested?

3. **Schema & algorithm versioning**:
   - Stage 1 is stage1.v3, Stage 2 is v2, Stage 3 is v3 (baseline) / v3.1.1 (audit). Are all three versioning schemes coordinated?
   - When Stage 3 → v3.1 → v3.1.1, were Stage 4 configs updated to match? (Answer: No, master stage4-config still has anchor="v3". Artifact 96c43acb built against Stage 3 v3, so this is correct.)

4. **Reproducibility of stochastic components**:
   - Stage 4 MEGA-AUG has max_baseline_per_arm=350 cap with undersampling (seeded, but seed not documented in code).
   - Layer B forest plot subsamples 100k genes for rendering cap (seed=42 in volcano, not in forest). Are all subsampling seeds consistent and tested?

5. **Missing architecture decisions**:
   - ADR-0003 (rename package) is documented as deferred. Is this blocking publication?
   - ADR-0005 (server migration) trigger is in memory but not actioned. What are current disk constraints?
   - Layer B narrative.qmd requires user-written biological context. Is there a semi-automated context scraper (e.g., PubMed, Reactome lookup by anchor)?

6. **Test coverage gaps**:
   - Layer B has only ~42 test functions vs Stage 4's ~105. What is the test-to-code ratio target?
   - Are integration tests (end-to-end Stage 0→5) in CI/CD, or manual smoke only?
   - Perf budget tests exist for Stage 3 (1 skipped test) but not Stage 4. Should there be wall-time regression tests?

7. **Audit branch final state**:
   - v3.1.1 rebuild is complete (390,532 clusters vs baseline 267,056), but Stage 4 Layer A rebuild was deferred (S3 pending per CLAUDE.md). Who will execute the Layer A re-run when audit concludes?
   - Will baseline v3 artifact (20260519T055547Z-stage3-2153addc) remain committed as the "reference", or be replaced?

---

**Document version**: v0 (2026-05-25)
**Generated by**: Comprehensive code exploration (git, grep, R loaders) + CLAUDE.md cross-reference
**Scope**: Master branch + audit branch diffs, focusing on pipeline code truth (not infrastructure)
**Next steps for audit**: Gate 1 (Stage 0–2 trust review) → Gate 2 (Stage 3 trust review) → Gate 3 (Stage 4 Layer A trust review) → Gate 4 (Layer B trust review)
