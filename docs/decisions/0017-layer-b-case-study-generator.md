# ADR-0017 — Layer B case study generator architecture

**Stato:** Accepted (2026-05-24, post-implementation + smoke 3-cluster validato)
**Data:** 2026-05-24
**Branch:** `p5-stadio4-layer-b` (31 commit, ff-merged a master)
**Tag:** `p5-stadio4-layer-b-complete`
**Spec di riferimento:** `docs/superpowers/specs/2026-05-24-p5-stadio4-layer-b-design.md`
**Plan di riferimento:** `docs/superpowers/plans/2026-05-24-p5-stadio4-layer-b-plan.md`
**Smoke validation:** `analysis/p4-output/20260524T145030Z-layer-b-smoke-fc13af22/layer_b_report.html`
  (3 cluster: `group_L0_1a0673ae` mega-small, `group_L0_a6f8c0e9` mega-big, `pair_L2_3ce85e50` mega_aug. Wall 2.8 min.)

**Test suite Layer B:** 142+ PASS / 0 FAIL su filter `^layer-b`. 269 cumulative su intera suite simulomicsr.

## Contesto

Stadio 4 Layer A ha prodotto effect-size pooled per 487 cluster cross-studio (run_id `96c43acb`, 2026-05-23). Il finding scope decision 2026-05-19 stabilisce ~10-20 case study "showcase" curati a mano come deliverable Results del paper. Layer B è la pipeline semi-automatica che converte una selezione manuale di cluster_id in bundle publication-ready.

## Decisione

Adozione di un'architettura **CSV-driven selection + comprehensive plot bundle + aggregate Quarto report**, con le seguenti decisioni rilevanti:

1. **Input mechanism**: CSV manualmente curato (`analysis/layer-b-selection.csv`). Schema `cluster_id, label_paper, priority, notes`. Trasparente, versionabile, audit-trailable.
2. **Plot set**: 8 plot per cluster con dispatch conditional per metodo (forest = REM+MEGA-AUG, heterogeneity = REM only).
3. **Output qualità**: Drop-into-paper polished (PNG @300 DPI + SVG separati), caption inglese paper-ready, palette viridis, font Helvetica 11pt, dimensioni Nature/Cell-compliant.
4. **Top-N defaults**: forest 10 / heatmap 30 / top-gene table 30 / volcano labels 15. Tutti configurabili via `layer_b_default_config()`.
5. **Aggregate report**: HTML standalone via Quarto (`embed-resources: true`). NO PDF (evita wkhtmltopdf/LaTeX deps).
6. **Bundle structure**: dir-per-cluster + un `narrative.qmd` per-cluster (no master narrative).
7. **Dependencies**: `clusterProfiler` + `org.Hs.eg.db` + `ComplexHeatmap` + `sva` + `DESeq2` + `ggrepel` + `kableExtra` come hard `Imports`. `ggplot2` e `quarto` MOSSI da `Suggests` a `Imports` (breaking minor accepted). `ReactomePA` opt-in `Suggests` con skip-graceful.
8. **Targets integration**: NO in `_targets.R`. Script standalone primary `analysis/p5-stage4-layer-b-build.R` (pattern Layer A).
9. **Smoke gate**: 3-cluster pre-batch obbligatorio (memoria `validate-before-fullrun`).

## Razionale

1. **CSV curato vs dashboard button**: la dashboard Layer A include già il picker (Sezione 5) con score composto. Aggiungere un'export button alla dashboard richiederebbe modifiche Quarto+DT+crosstalk JS non necessarie quando un CSV manuale dà lo stesso audit trail con zero dev front-end.

2. **Comprehensive plot set**: l'utente ha esplicitamente scelto "tutti gli 8" durante brainstorming dopo aver visto i mockup. Conditional dispatch evita di forzare plot non applicabili (forest su mega-strict, heterogeneity su non-REM).

3. **Drop-into-paper polished vs discussion-aid composite**: il paper Results richiede figure singole inseribili — un composite multi-panel richiederebbe comunque re-disegno manuale. Polish up-front sostituisce re-work downstream.

4. **org.Hs.eg.db hard dep**: senza, lo skip silente del GO enrichment introduce variabilità nei deliverable Layer B cross-machine. Errore deterministico al `library()` è preferibile a output incompleti silenti.

5. **NO targets integration**: Layer B è human-curation driven — la selezione cambia raramente, non automaticamente. Targets aggiunge complessità (cache invalidation cross-cluster, BPPARAM) senza valore (single-shot). Lo script standalone è più chiaro per il workflow dell'utente.

## Conseguenze

- Nuovi file `R/layer-b-*.R` (~15 file source + ~17 test file).
- DESCRIPTION delta: ~7 Imports nuovi + 2 mossi + 1 Suggests nuovo. renv.lock cambia.
- Output dir convention versionata `analysis/p4-output/<ts>-layer-b-<run_id>/` (analogo Layer A).
- Bundle paper-ready: PNG/SVG/CSV/LaTeX per ogni cluster + HTML standalone aggregate.
- Smoke gate consolidato come pattern obbligatorio per ogni fullrun Layer B futuro.
- `analysis/layer-b-selection.csv` diventa il primary audit trail della curation: scelta cluster + label paper documentate in git.

## Decisioni rinviate

- Dashboard "export selected to CSV" button (v2 enhancement se utente trova attrito nel copy/paste).
- LLM-generated draft narrative (rischio hallucination biologica troppo alto per v1).
- Multi-organism support (ARCHS4 mouse) — dipendente da γ pipeline future.
- Cross-cluster integration (es. combine 2 cluster narrative in un singolo case study composto) — out-of-scope v1.

## Addendum 2026-07-23 — Layer B v10 (deliverable finale rem_group-focused)

Il deliverable Layer B della pipeline v10 è un batch di **18 case study focalizzati sulle
meta-analisi cross-studio NOMINATE (`rem_group`, ADR-0022/0024)**: 10 flagship validati
opzione C + 8 extra (7 malattie, 5 farmaci, 5 patogeni, 1 citochina/gene). Run notturno
autonomo, wall 11,7 min, 108 plot generati, report HTML reso. Output
`analysis/p4-output/20260722T215752Z-layer-b-d7a475bb/`. Finding
`docs/findings/2026-07-23-layer-b-v10-case-studies.md`.

**Estensione architetturale (retrocompatibile) al method `rem_group`.** La macchina Layer B
originale (questo ADR) conosceva i method `{mega, mega_aug, rem}`; il ramo `rem_group`
(introdotto in v8+, ADR-0022) non era gestito nel dispatch dei campioni né nei plot builder.
Poiché `rem_group` è REM per-studio con lo STESSO schema statistico di `rem` (τ²/I²/Q/k_effective
+ per-study logFC/SE), è stato instradato sul ramo `rem` esistente in `.build_forest`,
`.build_heterogeneity_panel`, `.build_summary_card` + aggiunto `.build_group_rem_dispatch_from_stage3`
allo script di build. Cambi additivi (rem/mega/mega_aug invariati, 33 test builder PASS/0 FAIL).
Decisione paper-grade: identità di schema, non assunzione — lo skip-graceful (come `mega`)
avrebbe prodotto forest/heterogeneity "N/A" per meta-analisi che HANNO quelle statistiche.

## Riferimenti

- Spec: `docs/superpowers/specs/2026-05-24-p5-stadio4-layer-b-design.md`
- ADR-0006 (positioning vs RummaGEO)
- ADR-0015 (Stage 4 three-path architecture)
- ADR-0016 (Stage 4 crash fixes baseline pool cap)
- ADR-0022 (Stage 4 rem_group named meta-analyses) · ADR-0024 (v10 LLM-fallback)
- Finding scope decision: `docs/findings/2026-05-19-stadio-4-5-scope-decision.md`
- Finding Layer B v10: `docs/findings/2026-07-23-layer-b-v10-case-studies.md`
