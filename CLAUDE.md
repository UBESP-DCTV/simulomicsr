# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Fonte canonica del contesto del progetto per ogni sessione Claude Code,
> indipendentemente dalla macchina (laptop o server). Sostituisce la
> memoria locale di Claude Code (`~/.claude/projects/<path>/memory/`)
> che è machine-specific e non portabile.
>
> **Quando una sessione inizia in questa directory, leggi questo file
> per intero prima di agire.**

## Visione del progetto

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio
design-aware** basata su classificazione LLM dei metadati. Il nome è
legacy — il pacchetto NON simula nulla.

**Positioning (ADR-0006).** simulomicsr **non** è un altro annotatore
di GEO/SRA — quel campo è coperto da ARCHS4, MetaHQ (Hicks 2026),
MetaSRA, e dal multi-agent metadata curation di Mondal et al. 2025. Il
valore unico è la pipeline end-to-end **design-aware**: dal metadato
testuale alle comparisons appaiate (`design_role` LLM-driven entro lo
studio) → canonical `comparability_anchor` v3 cross-studio → pooling
effect-size random-effects (`metafor` REM). L'unico competitor end-to-end
vicino è RummaGEO (Maayan 2024), che però resta a livello di gene-set
per-studio senza anchor canonico né effect size. **Benchmark
testa-a-testa vs RummaGEO è deliverable integrale di P3.5 eval** (non
aggiunta opzionale post-hoc).

Pipeline complessiva (5 stadi):

1. **Acquisizione** — bulk RNAseq da ARCHS4-like (HDF5, ~700k+ sample da GEO).
2. **Stadio 1 sample-level** (P2 ✅) — classificare ogni sample dalla
   stringa di metadati GEO in un record JSON `sample_facts.stage1.v3`
   (cell context, perturbazioni, dose, tempo, ambiguity flags).
3. **Stadio 2 study-level** (P3 ✅) — interpretare il design
   sperimentale dello studio: replicate groups, design_role per sample,
   comparisons con `comparability_anchor` canonicalizzato per
   cross-studio matching.
4. **Stadio 3 raggruppamento** — cluster cross-studio sui
   `comparability_anchor`.
5. **Stadio 4 DE per-studio + Stadio 5 meta-analisi**
   (`DESeq2`/`limma` + `metafor` REM).

## Asset chiave — gold standard

`data-raw/relevant_sample_classified.xlsx` (committato nel repo, ~10 MB).

- Foglio `relevant_sample`: 130.784 righe × 8 colonne.
- Colonne: `Column1`, `string` (input metadata), `trtctr_EP` (gold
  manuale autore), `geo_accession`, `series_id`, `treat`, `trtctr`
  (baseline shallow), `gold` (ricontrollo terzo revisore).
- `trtctr_EP` riflette una semantica "qualunque intervento esplicito"
  che diverge da `design_role` — il gold "design-aware" è in
  `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 sample, P3.5-C/D).

## Stato corrente (2026-05-23 — P5 Stadio 4 Layer A fullrun COMPLETE, tag `p5-stadio4-complete`)

### P5 Stadio 4 Task 21 chiusura — debugging sistematico + fullrun (branch `p5-stadio4-de-perstudio` ff-merged in master, 2026-05-22/23)

Sessione di debugging sistematico post-handoff: 5 bug distinti isolati con riproduzione minimale + fix mirati (no whack-a-mole). 8 commit + 1 commit doc. Suite Stadio 4 finale: **322 PASS / 0 FAIL / 1 SKIP** (+34 vs handoff 288).

**Bug fixati questa sessione**:

- **Problema A — `duplicate row.names` MEGA-AUG bidir** (`25c158d`): 3 sotto-cause emerse dallo scan dei 310 cluster `mega_aug`. (a) 13 cluster con stesso baseline pool su entrambi i bracci → mono-fallback (Opzione 1: augmenta solo il braccio control, marca `bidir_collapsed_to_mono=TRUE` nelle diagnostiche). (b) 7 cluster con pool distinti ma GSM condivisi (super-series ARCHS4) → drop role-conflict da entrambi i bracci. (c) 5 cluster `mega_aug` senza pair risolvibile → skip-guard esplicito `mega_aug_no_study_dispatch`. Scan post-fix: 0/310 duplicati.
- **Scoperta paper-grade: dream non aveva mai girato sui dati reali** (`f3ce3af`, ADR-0016 §Decision 2). ARCHS4 v2.5 `meta/genes/symbol` ha 4638/67186 simboli duplicati (paralogi PAR/KIR/HLA: più Ensembl ID legittimi mappano sullo stesso HGNC symbol). `dream` rifiuta rownames non unici → `.run_dream_mega` ripiegava silenziosamente sul fallback limma. Nessun risultato scientifico prodotto da questa pipeline è stato impattato (i 4 fullrun precedenti erano falliti prima del completamento; smoke test usavano fixture con simboli già unici). Fix: `make.unique()` deterministico in `.h5_gene_axis` (KIR3DL2, KIR3DL2.1, …) — cross-study coerente, niente perdita di informazione, niente aggregazione biased ante-test.
- **Problema B — OOM su cluster MEGA-AUG grandi** (`d5f6040` + `f8fab2e` + `22a5a0f` + `8c6eba9`, ADR-0016). Due fix complementari:
  - Cap dimensione baseline pool: `max_baseline_per_arm = 350` (calibrato da curva di saturazione su dati veri — `analysis/p5-stage4-debug-problemB-saturation.R`: a 350 correlazione logFC col pool pieno = 0.997, n. geni significativi al picco; oltre 350 il risultato non migliora).
  - Worker cap: `dream_workers_cap` 100 → 16 (in isolamento dream costa ~1 GB/worker, ma in contesto reale `build_stage4_results` fork-COW dello state alza il costo a ~3.4 GB/worker — a 32 worker il picco era 127 GB; a 16 worker il picco per-cluster è ~71 GB, validato end-to-end sui 3 cluster `mega_aug` più grandi).
  - Bonus: per-cluster progress logging + memoization assi H5 (`.h5_sample_axis` + `.h5_gene_axis` in env `.h5_axis_memo`).
- **Dashboard render — volcano subsample** (`858d9bb`): a 13.7M righe il chunk `volcano-overall` produceva una stringa che eccedeva R max length nel post-process knitr (`gsub`). Sub-campionamento deterministico a max 100k punti (tutti i sig + sample dei non-sig, seed=42).

### Layer A fullrun COMPLETE (run_id `96c43acb`, 2026-05-22T23:10Z → 2026-05-23T03:26Z)

- **622/622 cluster OK, 0 errori, watchdog mai triggered.** Wall 1682 min (~28h) su laptop 251 GB. **Dream-based** con il fix gene-symbol applicato.
- **Output** `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` (gitignored):
  - `cluster_pooled.parquet` 375 MB — **13.691.756 righe** (mega 4.506.781 + mega_aug 9.184.975 by_method).
  - `per_study_de.parquet` 383 MB — 12.009.646 righe.
  - `stage4_dashboard.html` 77 MB.
  - `run_metadata.json` (config completa registrata) + `qc_report.rds` + `non_processable.rds`.
- **Config registrata**: `max_baseline_per_arm=350`, `dream_workers_cap=16`, `legacy_monodirectional=FALSE` (bidir on), `franchini_correction=TRUE`, `de_engine.mega=dream`, `de_engine.mega_aug=dream`.

## Stadio 4 Layer B (2026-05-24, branch `p5-stadio4-layer-b`)

Pipeline semi-automatica generator di "showcase case study" publication-grade.
Input: `analysis/layer-b-selection.csv` (10-20 cluster_id curati a mano dalla
dashboard Layer A). Output: bundle dir-per-cluster + Quarto HTML aggregate.

Decisioni chiave (vedi ADR-0017 + spec 2026-05-24):
- Workflow: semi-automatico CSV-driven (no Shiny, no dashboard button)
- 8 plot per cluster con dispatch conditional (forest = REM+MEGA-AUG,
  heterogeneity = REM only)
- Drop-into-paper polished (PNG @300 DPI + SVG, caption inglese paper-ready)
- Top-N: 10 forest / 30 heatmap / 30 table / 15 volcano labels
- HTML standalone aggregate (NO PDF)
- NO targets integration (script standalone primary)
- Smoke 3-cluster gate obbligatorio pre-batch

Test suite Layer B: 142+ PASS / 0 FAIL su filter `^layer-b` (269 cumulative
suite intera). Wall smoke 3-cluster: 2.8 min.

DESCRIPTION delta paper-grade: clusterProfiler, ComplexHeatmap, DESeq2, dplyr,
ggplot2, ggrepel, kableExtra, org.Hs.eg.db, patchwork, quarto, sva in `Imports`;
ReactomePA, ggrastr in `Suggests`.

**Status: COMPLETE 2026-05-24, tag `p5-stadio4-layer-b-complete`, ADR-0017 Accepted.**

Smoke validation (2026-05-24): 3 cluster pick (mega_big group_L0_a6f8c0e9,
mega_aug pair_L2_3ce85e50, mega_small group_L0_1a0673ae) → bundle dir-per-cluster
+ layer_b_report.html standalone 8 MB con 16/16 immagini base64-embedded +
caption english paper-ready + run_metadata.json con bioc_versions +
n_plots_generated/skipped + summary card con anchor risolto (treated side per
pair, level-aware per group L0..L4).

Cleanup paper-grade post-implementation: ggplot2 4.0 deprecations rimosse, SVG
size -66% to -90% (raster body via ggrastr + ComplexHeatmap::use_raster), HTML
embed-resources fix (era 0 base64 -> 16), parse_anchor_key gestisce mode='pair'
(treated__VS__control), ComBat guard su single-level treatment, summary_card
n_total_samples threading via per_cluster_samples (era N/A per mega-strict),
extract_anchor_summary public helper (era duplicato inline negli script).

Branch p5-stadio4-layer-b 31 commit ff-merged. Push remote rimane all'utente.

### Layer B selection + batch 15 case study (2026-05-24, branch `p5-stadio4-layer-b-selection`)

Curation paper-grade della selection.csv tramite shortlist data-driven sul
`cluster_pooled.parquet` (13.7M righe) + dedup gerarchia anchor v3 (487 cluster
Layer A → 293 unici). Script riproducibile `analysis/p5-stage4-layer-b-shortlist.R`
con criteri documentati: hard gates (k_effective≥4, n_sig_05≥50, max_logFC≥1.5,
kind_effective non-degenere; relaxed per mega coarse-anchor) + score composito
4-dim equipesi (magnitude/effect/power/precision) + stratified pick con cap
diversità biologica + smoke pin garantiti.

Shortlist 31 candidati → selection finale **15 case study** publication-grade:
- 13 mega_aug biology-driven: pathogen exposure × 3 (TLR ligands in blood,
  Resiquimod TLR7/8, polyI:C TLR3), small_molecule × 2 (ChEBI:17236 lung +
  smoke), cytokine × 2 (IFN-β kidney, ChEBI:16236 skin), environmental × 2
  (Hypoxia HUVEC, contact inhibition lung), genetic_overexpression × 1
  (miR-9/9*-124 neural reprog skin), disease_vs_normal × 1 (MeSH:D011279
  Prostatic Neoplasms), differentiation × 1 (Mesendoderm hESC)
- 2 mega smoke-validated: group_L0_a6f8c0e9 (transversal blood) +
  group_L0_1a0673ae (transversal skin)
- Coverage 11 kind_effective × 8 tessuti, mix level L0-L4.

Batch eseguito su laptop (wall **9.3 min**, run_id `56b911e6`):
- Output `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/` (gitignored):
  15 bundle dir-per-cluster + `layer_b_report.html` 33 MB standalone con
  **88 plot base64-embedded** (no reference esterne) + `run_metadata.json`
  con bioc_versions + selection_sha256 + `selection_resolved.csv`.
- n_plots_generated/skipped: 88 / 17 (forest skip-graceful per i 2 mega
  non-REM; heterogeneity sempre generato).
- Warnings: 31 generici (ComBat mean.only su single-sample batch, pattern noto).

Next steps user-driven:
- Aprire `layer_b_report.html` per review visiva delle 15 case study
- Compilare `narrative.qmd` per ogni bundle (sezioni TODO: Biological context,
  Findings, Discussion) → integrazione nel paper Results
- ChEBI ID lookup per le 4 label "CHEBI:xxxxx" generiche (es. CHEBI:17126,
  CHEBI:17199, CHEBI:17236, CHEBI:16236) per arricchire le label paper
- Eventuale Stadio 5 meta-analisi (spec design da scrivere)

### ⚠️ AUDIT LLM ANCHOR CLASSIFICATION (2026-05-24, branch `p5-llm-anchor-classification-audit`, NON MERGIATO)

Durante il ChEBI lookup richiesto dall'utente per arricchire le label Layer B
è emerso un finding paper-grade gravissimo che bloccca l'integrazione Layer B
nel paper finché non si decide una mitigation. Audit cross-validation degli
`agent_id` LLM-emitted (Mistral-Small-3.2) contro ontologie controllate ChEBI
(205k compounds), HGNC (45k genes), MeSH 2025 (31k descriptors):

| Metrica | Valore | Cosa dice |
|---|---:|---|
| Field-swap rate `<DB>:<num>` | **23.87%** (63738/267056) | ID numerico nel campo `preferred_name` invece di `id`. Recuperabile post-hoc via lookup. |
| Pure hallucination rate | 0.97% (2587/267056) | Bassissimo. |
| `kind_effective` accuracy vs ChEBI has_role | cytokine_stim **0.7%** match, pathogen **2.4%** match, vehicle_only 93.5% match | **Disastroso** per cytokine/pathogen. |
| Fragmentation L0G (compound, kind, level, mode fissati) | 34.4% | 1/3 compounds split in piu' cluster. |

**Su 15 case study Layer B**:
- 7 scientificamente validi (poly(I:C), Resiquimod, IFN-β, Hypoxia, miR-9, contact inhibition, Mesendoderm)
- 2 transversal ambigui (smoke `group_L0_*`)
- 2 con compound LLM-oscuro CHEBI:17236 (probable consistent hallucination)
- **4 critically wrong**: Carnitine-as-pathogen, Ethanol-as-cytokine, dihydroxyphthalic-as-pathogen, Pregnanetriol-as-disease

**Impatto**:
- Pooling DE Stage 4 algoritmicamente VALIDO (anchor stringa deterministica)
- Interpretazione BIOLOGICA INVALIDA per migliaia di cluster (label numerica + kind wrong)
- L2 paper limitation va espansa drasticamente

**Decisione utente 2026-05-25**: OPZIONE 2 — post-hoc ontology override
+ rebuild Stage 3 + Stage 4 + Layer B. ADR-0018 Proposed.

Documentazione completa pronta su branch `p5-llm-anchor-classification-audit`:
- **ADR-0018**: `docs/decisions/0018-llm-anchor-ontology-override.md` (decisione architetturale)
- **Spec**: `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
  (design tecnico: decision tables, edge cases, versioning, validation strategy)
- **Plan**: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
  (task-by-task implementation, 5 sessioni S1-S5 con gate utente)
- **HUMANE**: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-HUMANE.md`
  (versione leggibile + decisioni rinviate + cosa NON fa + stima tempo)
- **Audit drive**: `docs/findings/2026-05-24-llm-anchor-classification-audit.md`

Wall stimato totale: **1-2 giorni** distribuiti su 5 sessioni con gate
utente tra ogni sessione (vedi plan §SESSIONE 1..5).

### S1 COMPLETED 2026-05-25 (impl + tests + smoke isolato)

**5 commit incrementali su `p5-llm-anchor-classification-audit`** (master invariato):

- `5ea32c7` T1: `R/ontology-lookup.R` + mini fixtures + tests TDD (28 test, 56 expect_*).
  Loader singleton + 9 accessor O(1) hash-env per ~315k lookup downstream.
- `a91764d` T2: `resolve_agent_canonical()` in `R/anchors.R` + tests (28 test, 70 expect_*).
  Decision table 16+ branch spec §4.2.
- `7aad2e2` T3: `infer_kind_from_ontology` + `infer_kind_with_override` + tests
  (28 test, 51 expect_*). Override policy paper-grade conservativa: STRONG match
  registrato senza override; STRONG differ → ONTOLOGY_OVERRIDE_STRONG;
  MEDIUM/WEAK + LLM in {cytokine_stim, pathogen} kind incompatibile →
  LLM_CONTRADICTION_DETECTED; NONE → LLM preservato + kind_unvalidatable=TRUE.
- `afac917` T4: integrazione `.extract_anchor_segments` v3.1 + `make_anchor` thin
  wrapper + `.summarize_clusters` 11 tracking columns + `ontology_releases`
  in `run_metadata` + schema_versions anchor=v3.1 + resolver=v1.0.0.
  **9 nuovi test integration** (test-stage3-anchor-v31.R). Defensive
  `.coerce_chr1` + `.normalize_key_chr` per LLM real-world input
  character(0)/array/NA (critico: previene crash exists() in ~315k lookup).
- `45459f2` T5: smoke isolato `analysis/p5-ontology-override-smoke.R` 6 case
  paradigmatici, 6/6 PASS (log `analysis/p5-ontology-override-smoke.log`).

**Test result globale S1**: 1703 PASS / 0 FAIL / 3 SKIP (full suite escluso
perf-budget). Anchor-related: 443 PASS. Stage 3 (mocked): 268 PASS.
No regressioni.

**Smoke validato** sui 6 paradigmi dell'audit:
1. Carnitine field-swap LLM=pathogen → CHEBI:17126 + override LLM_CONTRADICTION_DETECTED
2. Ethanol LLM=cytokine_stim → CHEBI:16236 + override ONTOLOGY_OVERRIDE_STRONG → vehicle_only
3. DMSO type=vehicle → STR:dmso LLM_VEHICLE_LITERAL (preserva intent)
4. Resiquimod (0 ChEBI roles) LLM=pathogen → preservato + kind_unvalidatable=TRUE
5. poly(I:C) LLM=pathogen → CHEBI:84491 STRONG match (adjuvant)
6. Disease role=case D011471 → MeSH:D011471 STRONG disease_vs_normal

**Gate utente S1→S2 APPROVATO** (2026-05-25).

### S1bis + S2bis COMPLETED 2026-05-25 (anchor v3.1.1 + Stage 3 rebuild + 4/4 audit chiuso)

**Decisione utente 2026-05-25 (post-S2 v3.1 diff)**: OPZIONE B
(extend resolver per chiudere tutti i 4 audit case) + **DGX UniPD per S3**
Stage 4 rebuild.

**Output rebuild Stage 3 v3.1.1**:
`analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/` (gitignored).
- 390.532 cluster (+13 vs v3.1 per nuova rule DISEASE_KIND_CONTRADICTED)
- 1.255.180 assignments (invariato vs v3.1)
- Wall rebuild: 78.9 min (invariato vs v3.1 79.9 min)
- schema_versions.anchor=v3.1.1 + resolver=v1.1.0 in run_metadata.json

**Score override v3 → v3.1 → v3.1.1**:

| metric | v3 | v3.1 (S2) | v3.1.1 (S1bis+S2bis) |
|---|---:|---:|---:|
| kind_overridden | 0 | 7068 (1.81%) | **7845 (2.01%)** |
| LLM_CONTRADICTION_DETECTED | 0 | 4568 | **2833 (-1735 BUG FIX)** |
| DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY | 0 | 0 | **2512 (NEW)** |
| ONTOLOGY_OVERRIDE_STRONG | 0 | 2500 | 2500 |
| kind_chebi_zero_roles flag | n/a | n/a | **34878 (8.93%) NEW** |

**Audit 4 critically wrong Layer B → 3/4 FIXED deterministic + 1/4 FLAGGED**:

| Compound | Status v3.1.1 | Override reason |
|---|---|---|
| Carnitine CHEBI:17126 | ✅ FIXED (since v3.1) | LLM_CONTRADICTION_DETECTED |
| Ethanol CHEBI:16236 | ✅ FIXED (since v3.1) | ONTOLOGY_OVERRIDE_STRONG |
| Pregnanetriol MeSH:D011279 | ✅ **FIXED (NEW v3.1.1)** | DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY |
| dihydroxyphthalic CHEBI:17199 | ⚠️ FLAGGED | kind_chebi_zero_roles=TRUE (Layer B shortlist filter) |

**BUG silente paper-grade scoperto durante TDD S1bis**: la asymmetric trust
su `source = MESH_TREE_D` ha salvato **1735 cluster** che la policy v3.1
avrebbe wrongly demotato (es. Interferon-beta MeSH:D016899 LLM=cytokine_stim
→ MeSH tree D MEDIUM small_molecule incompatibile → demote erroneo). MeSH
tree D include sia chemicals che proteine immunitarie (D12), evidence troppo
coarse per smentire LLM cytokine specifico. Magnitude inattesa ~3x più grande
del caso target Pregnanetriol singolo. Regression test guard permanente.

**Commit S1bis + S2bis** (branch `p5-llm-anchor-classification-audit`):
- `d06e389` P5 audit S1bis: anchor v3.1.1 chiude 4/4 audit set
- `5a9aad1` P5 audit S2bis: Stage 3 v3.1.1 rebuild + diff + finding

**Report paper-grade**:
- `docs/findings/2026-05-25-stage3-v31-diff.md` — diff v3 vs v3.1 (intermediate)
- `docs/findings/2026-05-25-stage3-v311-diff.md` — diff v3 vs v3.1.1 (final)

### S2 COMPLETED 2026-05-25 (intermediate Stage 3 rebuild v3.1 + diff + report)

**Output rebuild Stage 3 v3.1**:
`analysis/p4-output/20260525T140219Z-stage3-v31-52357b00/` (gitignored).
- 390.519 cluster (+46.2% vs baseline v3 267.056)
- 1.255.180 assignments (+77.3% vs 707.595)
- 192.897 non_clusterable
- Wall rebuild: 79.9 min laptop 251 GB
- schema_versions.anchor=v3.1 + resolver=v1.0.0 + ontology_releases
  (ChEBI 205k compound + HGNC 45k + MeSH 31k) in run_metadata.json

**Override conservativo**: kind_overridden 7068 (1.81%):
- 64.6% LLM_CONTRADICTION_DETECTED (4568)
- 35.4% ONTOLOGY_OVERRIDE_STRONG (2500)

Override per kind_effective_resolved:
- 4558 → small_molecule (Carnitine-like, LLM diceva pathogen)
- 1670 → vehicle_only (Ethanol/DMSO-like, LLM diceva cytokine_stim)
- 440 → cytokine_stim (Resiquimod-like, LLM diceva small_molecule)
- 316 → disease_vs_normal (MeSH disease descriptors missed)
- 84 → pathogen_or_aggregate_exposure (poly(I:C)/TLR agonists)

**Audit 4 critically wrong Layer B (vedi `docs/findings/2026-05-25-stage3-v31-diff.md`)**:

| Compound | Old kind | New kind | Status |
|---|---|---|---|
| Carnitine CHEBI:17126 | pathogen | small_molecule | ✅ FIXED |
| Ethanol CHEBI:16236 | cytokine_stim | vehicle_only | ✅ FIXED |
| Pregnanetriol MeSH:D011279 | disease_vs_normal | disease_vs_normal | ⚠️ RESIDUAL |
| dihydroxyphthalic CHEBI:17199 | pathogen | pathogen | ⚠️ RESIDUAL |

2/4 risolti, 2/4 residual (policy attuale conservativa: no MeSH tree_top
check, no override per ChEBI compound con 0 roles annotation).

**Perf budget v3.1** (test aggiornato): 90 min wall + 8 GB memory delta
(cushion ~15-18% sui valori reali 76.6 min / 6.75 GB). Overhead +60 min su
Phase 6 `summarize_clusters` per resolve+infer lookup su 390k cluster
(atteso per design ADR-0018).

**Commit S2**:
- `74dcad4` P5 audit S2 Task 6: Stage 3 v3.1 rebuild + perf budget v3.1
- `f16de37` P5 audit S2 Task 7: diff Stage 3 v3 -> v3.1 + finding report

**Gate utente S2→S3 in attesa**.

### Prossima sessione: S3 (Stage 4 Layer A rebuild v3.1.1 su DGX)

Plan task 8-9 (`docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`):

1. **Smoke 3-cluster Stage 4 su Stage 3 v3.1.1** (~5-10 min): 1 mega-big + 1
   mega-aug + 1 mega-small da `analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/clusters.rds`
   per validare schema cluster_pooled.parquet invariato (anchor change non
   impatta Stage 4 pooling logic).
2. **Stage 4 fullrun v3.1.1 su DGX** (decisione utente: DGX UniPD per memory-heavy
   mega-aug):
   - Config invariata vs baseline Layer A: `max_baseline_per_arm=350,
     dream_workers_cap=16, legacy_monodirectional=FALSE, franchini_correction=TRUE,
     de_engine=dream per mega+mega_aug, pooling REML+DL fallback, FDR BH within cluster`
   - Submit via `dgx_p4_submit(time=...)` (memoria `feedback_dgx_time_limit_default`:
     default 72:00:00, mai stretto). Wall stimato 4-6h su DGX 2TB RAM 100 cores.
   - Output `analysis/p4-output/<ts>-stage4-v311-<run_id>/` con
     `cluster_pooled.parquet` + `per_study_de.parquet` + `stage4_dashboard.html`
     + `run_metadata.json` con `schema_versions.anchor=v3.1.1` propagato.
3. **Validazione output**: ~622 cluster pooled atteso (numero può variare
   leggermente per anchor changes ai livelli L0-L2 che produrranno cluster
   nuovi o split).

**Pre-requisiti S3 (verificati 2026-05-25)**:
- Stage 4 baseline preserved: `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` ✓
- Stage 3 v3.1 intermediate: `analysis/p4-output/20260525T140219Z-stage3-v31-52357b00/` ✓
- **Stage 3 v3.1.1 final**: `analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/` ✓ (input S3)
- DGX setup vignette: `vignettes/p4-dgx-setup.Rmd`

**Pre-requisito Layer B (S4) note**: shortlist deve includere filter su
`kind_chebi_zero_roles=TRUE` per i kind a rischio (pathogen + cytokine_stim)
per evitare Layer B audit-case-4-like (dihydroxyphthalic), come prescritto
in `docs/findings/2026-05-25-stage3-v311-diff.md §7`.

Branch invariato (`p5-llm-anchor-classification-audit`), master invariato.
Sub-skill: `superpowers:executing-plans` sul plan task-by-task.

Memoria: [[project_llm_anchor_classification_audit]].

---

## Stato precedente (2026-05-17 — P4 β rescue cascade COMPLETE, tag p4-beta-rescue-complete pending)

### α (consolidato, riproducibile)

Pipeline classification stage1 + stage2 sul gold-standard XLSX 130.784 sample:

- **α stage1** (Task 21, 2026-05-07) → 130.784 / 130.784 = **100.00%** schema. Dettagli NEWS 0.0.0.9009-0.0.0.9011 + ADR-0008.
- **α stage2** original (Task 22, 2026-05-10, v0.10.0 + workaround stack) → 8.532 / 8.546 cs25 = 99.84% schema, mini-gold 93.3%.
- **α stage2 re-run cs50** (ADR-0010, 2026-05-11, v0.20.2-cu129 + clean stack) → **6.649 / 6.652 cs50 = 99.96%** schema single-pass, **mini-gold 96.7%** (+3.4pp). Default flipped cs25→cs50.

### β (stage1 + stage2 fullrun COMPLETE 2026-05-15/17, tag p4-beta-archs4-human-complete)

Pipeline scalata su ARCHS4 v2.5 human bulk RNA-seq (~10x α):

- **β ETL** (Task β-1..β-6, 2026-05-12) → **888.821 sample** human + RNA-Seq, 32.905 unique GSE pre-resolver, **193.097 multi-series** risolti. Output JSONL `analysis/input/archs4-human-stage1-input.jsonl` (262 MB, gitignored).
- **β series-id-resolver SRP-driven Op D revised** (`R/etl-series-resolver.R`, Task β-4): 99.86% resolti via signal (`clean_super_scarted` 183.041 + `srp_a_only/b_only` 9.011 + minor branches), 0.54% heuristic tiebreak/fallback (1.041 sample), 0 sample droppati. Test 23-pair gold replication PASS (Exp D2).
- **β GATE #1** mini-gold format B (Task β-8, 2026-05-12): stage1+stage2 end-to-end su 100 mini-gold → schema 100% s1 + 100% s2, **accuracy binaria 98.00%** (mappato design_role_v3 → control/treated via `R/eval-stage2.R::design_role_to_binary`). +1.3pp vs α 96.7%. Wall DGX 4 min totali.
- **β GATE #2** smoke 1000 stratificato per nchar quartile (Task β-9, 2026-05-12): schema **99.50% s1 + 100% s2**, 5 LLM fail droppati lenient (0.5%), tier S=718 M=3 L=0 XL=0 (no overflow), design_kind distribution sana (case_control 40%, treatment_vs_vehicle 18%, multi_arm 17%).
- **β Task 10 stage1 fullrun via chunked orchestrator** (2026-05-14/15): wall **17h53min** (20:07 UTC 2026-05-14 → 14:00 UTC 2026-05-15) per 888.795 record mainstream. 89 chunks da 10k, cron `*/3 * * * *` autonomous + cascade COMPLETED→submit-next. Throughput stabile ~12.1 min/chunk. **Zero stall**. State machine: `scripts/p4-beta-stage1-chunked-tick.sh` + `analysis/p4-beta-chunked-state.txt`.
- **β Task 10b stage1 outliers** (2026-05-15): 26 record con `nchar > 3500` (0.003%) processati separatamente con `max_model_len=32768` (Strategy A2). Strategy A1 (`max_model_len=8192`) aveva riprodotto stall su job 20705. Wall **2m23s** per 26/26 record. Strategia documentata in memoria `project_vllm_scheduler_deadlock`.
- **β Master output stage1**: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl` (888.821 righe, 3.23 GB, gitignored), concat di 90 run dirs DGX (89 chunks + 1 outliers).
- **β Task 11 stage2-input build** (2026-05-15): 887.250 sample validi (1.571 droppati lenient per LLM fail) / 28.479 GSE → **39.205 record stage2** (12.989 chunked in 2.263 studi multi-chunk + 26.216 unsplit). Output `analysis/input/archs4-human-stage2-input.jsonl` (1.2 GB, gitignored). Wall 18m46s local.
- **β Task 12 stage2 fullrun** (2026-05-15/17): job slurm **20710**, run_id `20260515T175712Z-beta-stage2-fullrun-a275b0`, wall reale **1d 18h 29m 42s** (~42.5h DGX), ExitCode 0:0 COMPLETED. Schema validity **99.89%** (39.162/39.205, 43 errori). Tier S=16.493 / M=5.626 / L=2.605 / **XL=14.481** (37%). Throughput steady ~12-14 rec/min aggregato (4 worker H100, microbatch 50 cs50 ADR-0010/0013). Output 4 worker file merged in `predictions.jsonl` 403 MB sul DGX, collected localmente.

### β rescue cascade (Task 1-15, 2026-05-17, branch `p4-beta-rescue`)

Post-fullrun cleanup di 1.571 stage1 fails + 43 stage2 fails + discovery
paper-grade mouse-mislabeled GSE. Cascade tre strategie:

- **Phase 1 classification** (Task 2): 1.571 stage1 fails decomposti in MODE_A_WHITESPACE (660), MODE_B_LEGIT_TRUNC (147), OTHER_DEGEN (15), ETL_LEAK_NONHUMAN (749). CSV `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv`.
- **H2 — mouse-mislabeled GSE discovery + GSE-level drop** (Task 3+3b): 72 GSE ARCHS4 v2.5 `organism_ch1="Homo sapiens"` ma contenuti murini → 9.654 sample droppati GSE-level (8.398 LLM-non-human + 1.256 human collaterali) + 749 LLM JSON failure signal indiretto. Stage1 master cleaned: 888.821 → **879.167**. Stage2-input: 39.205 → **38.963**. Discovery doc paper-grade: `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md`.
- **H1 — Stage1 LLM-failure rescue** (Task 4-8): single-shot config `rep_pen=1.2 + max_tokens=4096 + max_model_len=8192` sui 822 Mode A/B/OTHER fails. Smoke20 21008 = 20/20 = 100%. Full retry 21103 = **802/822 = 97.6%** in 3m21s. Master rescued: `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (879.167 record, colonna `rescue_source = "h1_rep12_maxtok4096"` su 802).
- **H1.2 — Stage1 strong cascade su H1 residual** (post-Task 15, 2026-05-18): single-shot strong `rep_pen=1.3 + max_tokens=8192 + max_model_len=16384` sui 20 H1 residual (18 Mode A + 2 Mode B). Full retry 21136 = **19/20 = 95%** in 4m03s. 1 residual GSM6005198. Master aggiornato in-place; colonna `rescue_source = "h12_rep13_maxtok8192"` su 19 record.
- **H1.3 — Manual curation single-record** (post-H1.2, 2026-05-18): GSM6005198 (whitespace flood profondo non cedevole a rep_pen=1.3) curato a mano leggendo i metadata input, validato contro `sample_facts.stage1.v3` schema e iniettato nel master. Colonna `rescue_source = "manual_curation_2026-05-18"` su 1 record. Script `analysis/p4-beta-rescue-h13-manual-gsm6005198.R`. Branch `p4-beta-rescue-h12` ff-merge → master, tag `p4-beta-rescue-complete` retagged su nuovo HEAD.
- **H3 — Stage2 stall rescue cs25** (Task 9-13): cs50→cs25 re-split sui 43 stage2 fails (tier XL stuck post-PR #40946) + `tiered_max_tokens=TRUE` con XL=32768. 85 cs25 chunks generati. Smoke5 21129 = 5/5 = 100% in 2m35s. Full retry 21132 = **85/85 valid, 0 residual, 43/43 original keys fully rescued** in 8min. Master rescued: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (39.247 predictions, 0 errors).

**Risultato finale β post-rescue**:

| Metric | Pre-rescue | Post-rescue cascade |
|---|---|---|
| Stage1 master records | 888.821 | **879.167** (H2 drop −9.654) |
| Stage1 LLM+manual validity | 99.82% | **100.000%** (878.418 / 878.418, 0 residual, 1 manual curation GSM6005198; escludi 749 ETL leak ridroppati per H2) |
| Stage2 records | 39.205 | **38.963** (post H2) → **39.247 predictions** (post H3 con cs25 splits) |
| Stage2 schema validity | 99.89% | **100.000%** (0 residual) |
| Mouse contamination upstream | 9.147 latent | **0** (72 GSE dropped + 72 candidati re-annotation GEO/ARCHS4) |

Strategie consolidate documentate per paper Methods/Results: `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`. ADR-0008 Addendum 2026-05-17 con H1+H3 config. NEWS 0.0.0.9017.

**Pipeline running config (invariata da α)**:

- **Container**: `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` (cu129 per driver 535 DGX compat).
- **Modello**: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` self-hosted FP16 su DGX H100. Costo $0.
- **vLLM API**: `StructuredOutputsParams` (backend auto = xgrammar→outlines fallback). `GuidedDecodingParams` rimosso in vLLM v0.12.0.
- **Sampling** (ADR-0008): `temperature=0.0, repetition_penalty=1.1` stage1+stage2. Tier-based per-record max_tokens stage2 (S/M/L/XL → 4K/8K/16K/32K, ADR-0011).
- **Concurrency restored** (post PR #40946): `max_num_seqs=6, microbatch=50` stage2. Safe-mode (ADR-0009) declassato a fallback contingency.
- **Stage2 chunking**: `chunk_size=50` (cs50 default, ADR-0010 addendum + ADR-0013).
- **Schema validation**: structured_outputs = parser-grade by construction.

**Tag/branch attivi**:

- Tag α: `p4-vllm-upgrade-v0.20.2-complete` (commit 31c676a, addendum 89ca20e per cs50 flip).
- Tag β: **`p4-beta-archs4-human-complete`** (2026-05-17, closing Task β-15). Branch `p4-beta-archs4-human` ff-merged in `master` locale. Push remote rimane all'utente.
- **Test**: 544 PASS / 0 FAIL / 3 SKIP α-level (skip pre-esistenti OPENAI_API_KEY) + 41 PASS β resolver = 585 total tests.

**File risultato α + β attualmente sul disco**:

- α stage1: `analysis/p4-output/alpha-stage1-final.rds` (130.784 × 7, colonna `rescue_source`)
- α stage2 cs50: `analysis/p4-output/20260510T215308Z-p5-alpha-cs50-final-8db4c0/predictions.jsonl` (6649/6652 valid)
- α eval mini-gold cs50: `analysis/p4-output/phase3-h1-eval-20088.rds`
- β ETL output JSONL stage1-input: `analysis/input/archs4-human-stage1-input.jsonl` (gitignored, 262 MB)
- β ETL provenance: `analysis/p4-output/p4-beta-archs4-source.json` (committato force-add)
- β H5 source: `analysis/input/human_gene_v2.5.h5` (47.86 GB, gitignored; SHA256 `a1063426cb51986c77574d80d344918a075804c155e9b18c2e551b1077ad5d18`)
- β cache Entrez resolver: `tools::R_user_dir("simulomicsr","cache")/geo-series-resolver-cache.rds` (~25 MB, 32.905 GSE)
- β GATE #1 eval: `analysis/p4-output/20260512T142323Z-p4-beta-gate1-minigold-eval.rds` (force-add committato)
- β GATE #2 eval: `analysis/p4-output/20260512T150505Z-p4-beta-gate2-smoke1000-eval.rds` (force-add committato)
- β stage1 chunked input shuffled: `analysis/input/archs4-human-stage1-input-shuffled.jsonl` (gitignored, 262 MB; seed=42 globale, output di `shuf --random-source=<(yes 42)`)
- β stage1 chunked input filtered (`nchar <= 3500`): `analysis/input/archs4-human-stage1-input-shuffled-filtered.jsonl` (gitignored, 262 MB, 888.795 record)
- β stage1 outliers (`nchar > 3500`): `analysis/input/archs4-human-stage1-outliers.jsonl` (gitignored, 26 record, ~140 KB)
- β stage1 chunks (89 file): `analysis/input/chunks/chunk-00.jsonl` .. `chunk-88.jsonl` (gitignored, ~2.9 MB ciascuno)
- β stage1 master predictions: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl` (gitignored, **888.821 righe, 3.23 GB**, concat di 89 chunks + 1 outliers)
- β stage1 state machine: `analysis/p4-beta-chunked-state.txt` (gitignored, ultimo valore `89` = orchestrator idle)
- β stage1 orchestrator log: `analysis/p4-beta-chunked-orchestrator.log` (gitignored, ~70 KB, log cron tick ogni 3min)
- β stage2 input cs50: `analysis/input/archs4-human-stage2-input.jsonl` (gitignored, **39.205 record, 1.2 GB**, output di `analysis/p4-beta-stage2-build-input.R`)
- β stage2 fullrun output (collect dir): `analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/` (gitignored, contiene `predictions.jsonl` 403 MB merged + 4 worker file + `run_summary.json` + `collect.rds`)
- β rescue stage1 fails classified: `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv` (committato, 1.571 fails × 5 colonne)
- β rescue H2 suspects (72 GSE flagged): `analysis/p4-output/p4-beta-rescue-h2-suspects.rds` (committato, 72 × 4 colonne)
- β rescue stage1 cleaned (post H2): `analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl` (gitignored, **879.167 righe, 2.97 GB**)
- β rescue stage2-input cleaned (post H2): `analysis/input/archs4-human-stage2-input-cleaned.jsonl` (gitignored, **38.963 record, 1.18 GB**)
- β rescue H1 input: `analysis/input/archs4-human-stage1-rescue.jsonl` (gitignored, 822 record, 296 KB)
- β rescue stage1 master rescued (post H1): `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (gitignored, **879.167 righe, 2.97 GB**, colonna `rescue_source = "h1_rep12_maxtok4096"` su 802)
- β rescue H3 input cs25: `analysis/input/archs4-human-stage2-rescue-cs25.jsonl` (gitignored, **85 chunks, 3.2 MB**)
- β rescue stage2 master rescued (post H3): `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (gitignored, 39.247 predictions + 0 errors, colonna `rescue_source = "h3_cs25_resplit"` su 85 cs25 chunks)

## Convenzioni operative dell'utente

### Tracciabilità — ogni decisione documentata

Mai prendere una decisione architetturale senza scriverla in modo
durevole prima di committare codice che la riflette.

- **ADR** (decisioni architetturali) → `docs/decisions/NNNN-<slug>.md`. Template in `docs/decisions/template.md`.
- **Spec** (brainstorming/design) → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
- **Plan** (implementazione) → `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md` + companion HUMANE per la review umana.
- **Commit atomici** con messaggi italiani descrittivi formato `P<N> Task <M>: <azione>`. Sono il "come tecnico" complementare all'ADR.

A fine milestone: raccogliere materiale da ADR/spec per generare /
aggiornare vignette o capitoli del futuro manuale.

### Git workflow

- **Branch per fase:** `p<N>-<slug>` (es. `p2-stage1`).
- **Merge fast-forward only** su master a fine fase. Tag `p<N>-<slug>-complete`.
- **MAI fare `git push`** — l'utente lo fa lui, sempre. Master locale può essere molti commit ahead.
- **MAI usare `--no-verify` o `--no-gpg-sign`** salvo richiesta esplicita.
- Pulire `renv/settings.json` (untracked, autogenerato) e ripristinare `analysis/_targets/.gitignore` + `analysis/_targets/meta/meta` (rigenerati da `tar_make`) prima di ogni commit.

### Convenzioni codice

- **Italiano nei commenti, docstring, messaggi commit, error messages.**
  ASCII per i caratteri accentati nei file Rd generati da roxygen
  (usare `§`/`—` o equivalenti `sec.`/`--` nel roxygen `#'`).
- Funzioni interne: `@keywords internal`. Solo i veri entry point sono `@export`.
- TDD bite-sized (test → fail → impl → pass → commit) per ogni step di plan.

### Note operative tecniche ricorrenti

- **renv 0.16.0 (lockfile) vs renv 1.1.4 (installato):** `Rscript -e ...` (no vanilla) può non trovare `devtools` perché renv intercetta il libpath. Workaround: `Rscript --vanilla -e ...` bypassa renv e usa system libs (devtools/targets installati globalmente). **Sul server DGX (R 4.6.0)** è il contrario: usare `Rscript -e ...` SENZA `--vanilla` (renv lib path corretta nel project).
- **`callr_function = NULL` per `tar_make`:** indispensabile quando i target chiamano OpenAI. callr crea sub-process R che NON ereditano la API key dal parent.
- **`format = "qs"` non disponibile su CRAN per R 4.5.2** → P2 usa `format = "rds"` per `tar_option_set`.
- **`sample_facts_validator` storizza un PATH allo schema, non il validator compilato** — i contesti V8 di `jsonvalidate` non sono serializzabili in RDS. `compile_schema()` viene chiamato inline nei target di partition.
- **MAI fare `git checkout -- analysis/_targets/meta/meta` MENTRE un `tar_make` è in corso**: il meta viene aggiornato in tempo reale, un checkout lo riporta a stato pre-run e il job successivo non riconosce più gli oggetti già calcolati. La convenzione "ripristina meta prima del commit" vale solo quando NESSUN tar_make sta girando in background.
- **Hang HTTP transitorio iniziale**: la prima call OpenAI dopo network glitch può essere catturata in I/O wait su socket (CPU 0%, processo S, TCP ESTABLISHED) senza timeout effettivo del `req_timeout(120s)` di httr2 (rare edge case). Workaround: kill + retry.
- **NON re-introdurre `temperature = 0` come default** in `R/llm-client-openai.R` (gpt-5.5 reasoning models ritornano 400 `unsupported_value` su qualunque temperature esplicita). Per output deterministici su modelli storici (gpt-4o, gpt-5.4-mini), passare `temperature = 0` esplicito dal chiamante.

### Note operative DGX (P4 cluster)

- **Path `/home/u0044/` NON `/mnt/home/u0044/`** — i compute node UniPD HPC non montano `/mnt/home/`. Sintomo del bug: ExitCode `0:53` con job FAILED in 2 secondi senza log files.
- **ssh non-interattivo NON sourca `/etc/profile.d/*.sh`** → `SLURM_CONF` mancante. Fix in `R/dgx-utils.R::.dgx_ssh()`: wrap del comando remoto con `bash -lc <cmd>` per forzare login shell.
- **Esecuzione singularity diretta, NO `srun`** — `srun singularity` non è supportato/affidabile su questo cluster. Usare `singularity exec --nv ...` direttamente.
- Vignette setup completa: `vignettes/p4-dgx-setup.Rmd`.

## Decisioni rinviate

- **ADR-0003 — rinome pacchetto.** "simulomicsr" non riflette la pipeline. Da affrontare prima del primo `install_github` pubblico.
- **ADR-0010 — vLLM upgrade evaluation.** Aprire SOLO dopo chiusura α + tag p4-dgx-complete; vLLM Issue #39734 non risolto upstream nemmeno in 0.19.x.
- **Vocabolari extra** (Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI). Necessari per Stadio 2 esteso (post-α).
- **Gold "design-aware"** scaled su 200-300 sample. Mini-gold v5 attuale è 100 sample.
- **Integrazione MetaHQ** come upstream per `normalize_tissue()` / `normalize_disease()` in Stadio 2.
- **Migrazione a `ellmer`** come client LLM (multi-provider, batch API più ergonomico). ADR separato post-α.
- **Cache cross-modello.** P1 attuale partiziona per `(provider, model, messages)`. Se servisse cache cross-modello, ADR dedicato.
- **Migrazione su server con più spazio.** ADR-0005 documenta trigger e procedura.
- **Findings sotto-soglia P3.5-A** (eventuale prompt iter post-α): `treatment_vs_untreated` 77.3% (n=141), `time_course` 59.3% (n=54), `case_control_disease` 49.1% (n=57, sotto casuale).
- ~~**β retry/uniqfail infrastructure pre full run**~~ **DONE 2026-05-17 con β rescue cascade**. Risolto via Phase 1 classification + H1 single-shot rep_pen=1.2/max_tokens=4096 + H3 cs50→cs25 invece di multi-round retry. Risultato: stage1 LLM-only 99.998% + stage2 100.000%. Cascade documentato in ADR-0008 addendum 2026-05-17 + `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`.
- **β gate2 throughput measurement bug** (cosmetico, gate-decision non impattata). Lo script `analysis/p4-beta-gate2-smoke.R` misura wall come `Sys.time()` pre/post `poll_until_done`, ma resume da job COMPLETED restituisce ~5 sec → "throughput 9996 rec/min" artefatto. Fix corretto: pull `sacct -j JID --format=Elapsed` e usare quello come wall reale. ETA stage1 full corretta calcolata a mano dal log poll iniziale: ~59h.

## Roadmap

### β tutti i task DONE (chiusura 2026-05-17)

1. ~~**β Task 10 stage1 full run**~~ **DONE** 2026-05-14/15. 888.795 record mainstream + 26 outliers = 888.821 totali. Wall 17h53min mainstream + 2m23s outliers. Master output: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl`.
2. ~~**β Task 10b stage1 outliers**~~ **DONE** 2026-05-15. Strategy A2 (`max_model_len=32768`) ha completato 26/26 record in 2m23s wall.
3. ~~**β Task 11 stage2-input**~~ **DONE** 2026-05-15. 39.205 record stage2 (vs ~17k stima gate2). Output `analysis/input/archs4-human-stage2-input.jsonl` (1.2 GB).
4. ~~**β Task 12 stage2 full run**~~ **DONE** 2026-05-15/17. Wall reale ~42.5h (vs stima iniziale 6-8h sbagliata per via di 37% tier XL e cold-start). Schema validity 99.89% (39.162/39.205). Job slurm 20710 ExitCode 0:0.
5. ~~**β Task 15 closing**~~ **DONE** 2026-05-17. NEWS 0.0.0.9016 esteso, tag `p4-beta-archs4-human-complete`, ff-merge → master locale. Push remote rimane all'utente.
6. ~~**β rescue cascade Task 1-15**~~ **DONE** 2026-05-17. Stage1 99.998% LLM-only + stage2 100.000%. NEWS 0.0.0.9017 esteso, tag `p4-beta-rescue-complete` (pending Task 15 close), ff-merge → master locale. Discovery paper-grade H2 (72 mouse-mislabeled GSE) + strategie rescue consolidate in `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`.

### Post-β + P5 Stadio 4 Layer A (immediato)

1. ~~**Stadio 3 raggruppamento cross-studio**~~ **DONE** pre-fullrun (Stage 3 build `2153addc` da cui parte il fullrun: 267.056 cluster, 707.595 assignment, 39.247 stage2 studies).
2. ~~**Stadio 4 Layer A** (`build_stage4_results`)~~ **DONE 2026-05-23** (run_id `96c43acb`, 622/622 cluster OK).
3. **Stadio 4 Layer B** + **Stadio 5 meta-analisi**: prossimo step su `cluster_pooled.parquet` (13.7M righe). Spec design da scrivere.
4. **Rename pacchetto** (ADR-0003) prima del primo `install_github` pubblico.
5. **Migrazione a `ellmer`** come ADR separato.
6. **γ ARCHS4 mouse** (post-human consolidato). NO γ in pianificazione attiva — gestito come variante futura.

## Dove vivere i dati che il repo NON contiene

| Asset                       | Location                                                          | Come ottenerlo / ricostruirlo                                            |
|-----------------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------|
| `OPENAI_API_KEY`            | `.Renviron.local` (gitignored)                                    | Utente ricrea manualmente. Riga `OPENAI_API_KEY="sk-..."`.               |
| renv libreria               | `~/Library/Caches/.../renv/` (macOS) o `~/.cache/R/renv/` (Linux) | `renv::restore()` da `renv.lock` committato.                             |
| HGNC dump completo          | `tools::R_user_dir("simulomicsr", which="cache")/hgnc_complete_set.tsv` | Download manuale da `https://www.genenames.org/download/archive/`.   |
| Cache LLM                   | `analysis/cache/` (gitignored)                                    | Auto-popolata dai run di `tar_make`. Trasferibile via `rsync`.           |
| Pipeline state              | `analysis/_targets/` (gitignored)                                 | Auto-popolato da `tar_make`. Trasferibile via `rsync`.                   |
| ARCHS4 H5 human v2.5        | `analysis/input/human_gene_v2.5.h5` (47.86GB, gitignored)         | `wget -c https://mssm-data.s3.amazonaws.com/human_gene_v2.5.h5` (~1.5h wall). SHA256 + provenance in `analysis/p4-output/p4-beta-archs4-source.json`. |
| File risultato α stage1/2   | `analysis/p4-output/*.rds` (gitignored)                           | Output dei job DGX, ricostruibili da `analysis/p4-bundles/*-job.rds`.    |
| β ETL output JSONL          | `analysis/input/archs4-human-stage1-input.jsonl` (262MB, gitignored) | Re-generato da `Rscript analysis/p4-beta-etl-build.R` (richiede H5 + cache Entrez). Stage 4 vectorizzato ~3 sec con cache full, ~5min Stage 2 H5 re-read. |
| β cache Entrez resolver     | `tools::R_user_dir("simulomicsr", which="cache")/geo-series-resolver-cache.rds` | Re-buildabile via `entrez_lookup_gse_metadata` (~5-6h wall per 32.9k GSE @ ~1.5 GSE/s con NCBI_API_KEY). |
| Bundle/runtime DGX          | `analysis/p4-bundles/` (gitignored)                               | Generati da `dgx_p4_build_bundle()`.                                     |

## Riferimenti chiave

### ADR (decisioni architetturali, in `docs/decisions/`)

- 0001 sistema-tracking · 0002 struttura-research-compendium · 0004 renv-riconciliato · 0005 server-migration-trigger
- **0006 stato-arte-vs-simulomicsr** — analisi competitor 2024-2026 + benchmark RummaGEO + decisione P3-B
- **0007 dgx-self-host-vllm** — bespoke minimale dentro simulomicsr + workflow Docker→DockerHub→Singularity
- **0008 vllm-sampling-defaults** — temperature=0.0, repetition_penalty=1.1 stage1+stage2
- **0009 stage2-safe-mode-vllm-deadlock** — `max_num_seqs=1, microbatch=1` stage2 deadlock-proof Issue #39734
- **0011 tier-based-max-tokens** — single-pass strategy per stage2 con per-record max_tokens proporzionato
- **0012 stage2-schema-multi-axis-limitation** — known limit `primary_role` mono-axis vs design factoriali (paper-grade note)

### Specs / plans (in `docs/superpowers/`)

- Spec classificatore: `specs/2026-04-29-classificatore-llm-design.md` (v5 approvata 2026-04-29).
- Plan P1-P4: `plans/<date>-p<N>-*.md` + companion HUMANE.
- Spec investigation Task 22: `specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md` (RESOLVED).

### Report Quarto

- `analysis/eval/p35-benchmark.html` (838 KB) — P3.5-B prototipo (15 GSE, 197 sample).
- `analysis/eval/p35a-benchmark.html` (980 KB) — P3.5-A scaled (100 GSE, 1507 sample, paper-ready: Wilson CI + McNemar + bootstrap + Holm).

### Documentazione storica

- **`docs/model-evaluation-history.md`** — valutazioni P3.5-C (5 modelli closed) + P3.5-D (21 modelli OpenRouter) + pattern strutturali + decisione mistral-small-3.2.

### Vignette + utenti

- `vignettes/p4-dgx-setup.Rmd` — one-time guide setup DGX.
- `README.md`, `NEWS.md` — entry point utente + storia versioni.
