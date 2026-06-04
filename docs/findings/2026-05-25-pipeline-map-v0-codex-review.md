# Codex independent review — pipeline map v0 (2026-05-25)

> **Provenance**: prodotto da `codex:rescue` (OpenAI Codex CLI v0.118.0,
> direct startup) il 2026-05-25, invocato dalla sessione audit-completo-pipeline
> (branch `p5-llm-anchor-classification-audit`). Output salvato verbatim,
> senza edit. Codex aveva accesso ai file v0 + critical-reading e al
> codice del repo. Suoi ID: C1-C11 (nuovi findings) + push-back su E1-E7
> / L1-L5.
>
> **Non è un fix.** Regola 2 dell'audit: tutto è annotato, niente patch.
> I findings di codex si fondono nella backlog audit per il passo 2
> (fix uno-alla-volta dopo che il passo 1 chiude).

## Findings nuovi di codex (C1-C11)

### C1 — HIGH
**Observed**: Stage 3 cluster IDs are 32-bit hashes only: `hash8 <- substr(digest::digest(anchor_key, algo = "xxhash32"), 1L, 8L)` in [R/stage3-cluster.R](/home/user/simulomicsr/R/stage3-cluster.R), and summarization groups by `cluster_id` (`split(..., assignments$cluster_id)`) in [R/stage3-build.R](/home/user/simulomicsr/R/stage3-build.R).
**Why it matters**: at 267k+ clusters, 32-bit collision risk is non-trivial; collisions silently merge biologically different anchors.
**Pass 2 verify**: scan `assignments.parquet` for any `cluster_id` mapping to multiple distinct `anchor_key`.

### C2 — HIGH
**Observed**: Stage 4 counts cache key ignores H5 path/version and code version: `.cache_key_for_fetch` hashes only `gse + sorted(sample_ids)` in [R/stage4-counts-cache.R](/home/user/simulomicsr/R/stage4-counts-cache.R). Cached matrices are persisted on disk (`saveRDS`) and reused globally.
**Why it matters**: stale/wrong matrices can be reused across runs/datasets; this is stronger than generic cache concern.
**Pass 2 verify**: compare cached vs fresh fetches for a sample of keys and inspect whether cache directory predated the Stage 4 full run.

### C3 — HIGH
**Observed**: QC study-drop check is not cluster-specific: `n_rem <- sum(remaining_meta$gse == sid)` in [R/stage4-qc.R](/home/user/simulomicsr/R/stage4-qc.R).
**Why it matters**: a study can appear "QC-valid" because unrelated samples from the same GSE survive, even if all samples relevant to that cluster were dropped.
**Pass 2 verify**: recompute remaining counts using cluster dispatch sample IDs, not whole-study counts.

### C4 — HIGH
**Observed**: Dream failure silently falls back to limma, but output method remains `"mega"`/`"mega_aug"`: fallback block in [R/stage4-dream-mega.R](/home/user/simulomicsr/R/stage4-dream-mega.R), then `method = method_label`.
**Why it matters**: method provenance in scientific output is misreported under failure conditions.
**Pass 2 verify**: force a known dream failure and check whether `cluster_pooled` records disclose fallback usage.

### C5 — HIGH
**Observed**: Stage 3 run_id is based on counts/config, not input content hash: `.build_run_metadata()` hashes `n_records` summaries + config in [R/stage3-build.R](/home/user/simulomicsr/R/stage3-build.R).
**Why it matters**: materially different stage1/stage2 inputs with same counts can produce same Stage 3 run_id; Stage 4 inherits this weak provenance via `stage3_run_id`.
**Pass 2 verify**: mutate one stage1 record (keep count unchanged) and check whether Stage 3 run_id changes.

### C6 — MEDIUM
**Observed** (structural fidelity divergence): v0 map claims Layer A default/used `legacy_monodirectional=TRUE`, but artifact metadata for run `96c43acb` records `"legacy_monodirectional": false` in [analysis/p4-output/20260523T032601Z-stage4-96c43acb/run_metadata.json](/home/user/simulomicsr/analysis/p4-output/20260523T032601Z-stage4-96c43acb/run_metadata.json).
**Why it matters**: audit narrative of MEGA-AUG directionality is factually wrong for the cited production artifact.
**Pass 2 verify**: check exact fullrun script/config override used for `96c43acb`.

### C7 — MEDIUM
**Observed** (structural fidelity divergence): v0 map describes Stage 4 counts cache as in-memory; code is persistent disk cache (`readRDS`/`saveRDS`, `tools::R_user_dir(...)/stage4-counts`) in [R/stage4-counts-cache.R](/home/user/simulomicsr/R/stage4-counts-cache.R).
**Why it matters**: persistence materially changes staleness/reproducibility risk model.
**Pass 2 verify**: enumerate cache files and mtimes around fullrun start/end.

### C8 — MEDIUM
**Observed**: possible silent key overwrite in Stage 1 loader path: keys built then `setNames(parsed, keys)` in `.load_stage1_master()` and later converted with `list2env(...)` in [R/stage3-build.R](/home/user/simulomicsr/R/stage3-build.R).
**Why it matters**: duplicate GSM keys can silently overwrite records before Stage 3 clustering.
**Pass 2 verify**: count duplicate/NA keys in stage1 master JSONL and compare expected vs loaded unique keys.

### C9 — MEDIUM
**Observed**: Layer B run metadata writes NA numerics as strings (`"bundle_size_mb": "NA"`, `"peak_mem_mb": "NA"`) in [analysis/p4-output/20260524T192649Z-layer-b-56b911e6/run_metadata.json](/home/user/simulomicsr/analysis/p4-output/20260524T192649Z-layer-b-56b911e6/run_metadata.json).
**Why it matters**: schema/type instability across artifacts complicates strict machine-read reproducibility checks.
**Pass 2 verify**: inspect other Layer B run metadata for type consistency.

### C10 — MEDIUM
**Observed**: baseline subsampling seed is weakly derived: `seed <- sum(utf8ToInt(as.character(seed_key))) %% 2147483647L` in [R/stage4-mega-aug.R](/home/user/simulomicsr/R/stage4-mega-aug.R).
**Why it matters**: high collision chance across different pool IDs yields repeated subsamples, creating hidden dependence patterns.
**Pass 2 verify**: collision scan across baseline pool IDs and resulting sampled index sets.

### C11 — MEDIUM
**Observed** (tests suspicious): core Stage 4 integration test runs only dry-run path (`dry_run_inputs_only = TRUE`) in [tests/testthat/test-stage4-build.R](/home/user/simulomicsr/tests/testthat/test-stage4-build.R); perf test skipped on CI/CRAN in [tests/testthat/test-stage3-perf-budget.R](/home/user/simulomicsr/tests/testthat/test-stage3-perf-budget.R); API smoke tests are env-gated.
**Why it matters**: major production paths (DE + pooling + cache interactions) can regress while tests still pass.
**Pass 2 verify**: report which Stage 4/Layer B tests execute in CI vs skip, and whether any non-dry integration test covers full pooling path.

## Codex push-back su E1–E7 / L1–L5

- **E1**: keep (low). Correct semantic issue; not computationally critical.
- **E2**: keep but mark "needs file access". Concern is valid; payload lacks branch `stage3-io`/loader diff, so currently speculative.
- **E3**: keep (low). True process-quality issue.
- **E4**: re-rank up (medium→HIGH candidate). Dependency chain-of-custody is a real reproducibility axis; Layer B at least records Bioc versions, Stage 3/4 don't.
- **E5**: keep but soften. Partially mitigated by `selection_sha256` already recorded in Layer B metadata.
- **E6**: extend and strengthen (HIGH confirmed). Concrete key-design issues (C2) and persistence make this worse than phrased.
- **E7**: keep (low). Good audit-structure recommendation.
- **L1**: keep.
- **L2**: extend (now partially validated from payload run_metadata; found real map mismatch on MEGA-AUG direction flag).
- **L3**: re-rank down slightly (from unknown to lower priority): quick spot-check of Stage1 prompt/schema looked broadly aligned in payload.
- **L4**: keep (medium).
- **L5**: keep and extend with C2 (cache key/versioning specifics).

---

**Document version**: v0 codex review (2026-05-25)
**Generated by**: codex:rescue (Codex CLI v0.118.0)
**Scope**: independent third-party review of pipeline map v0 + critical reading
