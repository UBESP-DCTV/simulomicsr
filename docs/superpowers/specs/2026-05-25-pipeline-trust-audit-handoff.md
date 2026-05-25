# Pipeline trust audit — handoff per nuova sessione

**Data:** 2026-05-25
**Branch:** `p5-llm-anchor-classification-audit`
**Master:** invariato (su `p5-stadio4-layer-b-batch-15` complete)
**Status:** **PAUSE richiesta dall'utente per audit completo pipeline**

---

## Contesto

In questa sessione (2026-05-25) abbiamo eseguito:

- **S1** (5 commit pre-sessione): implementazione anchor v3.1 con post-hoc
  ontology override (resolver v1.0.0). Suite test 1703 PASS.
- **S2** (3 commit): Stage 3 v3.1 rebuild run_id `52357b00`, 79.9 min wall.
  Audit 4 critically wrong → 2/4 FIXED, 2/4 RESIDUAL (Pregnanetriol +
  dihydroxyphthalic). Report `docs/findings/2026-05-25-stage3-v31-diff.md`.
- **S1bis + S2bis** (3 commit): anchor v3.1.1 + resolver v1.1.0, Stage 3
  v3.1.1 rebuild run_id `2655ecb0`. Audit 4/4 chiuso (3 deterministic FIXED
  + 1 FLAGGED via `kind_chebi_zero_roles`). Report
  `docs/findings/2026-05-25-stage3-v311-diff.md`.

**Bug paper-grade scoperti incrementalmente** (in ordine di scoperta):

1. **Bug Pregnanetriol** (audit pre-sessione) — MeSH D04 sterol classed
   `disease_vs_normal` dal LLM, non corretto dal resolver v1.0.0.
2. **Bug dihydroxyphthalic** (audit pre-sessione) — CHEBI:17199 con 0 roles
   + LLM=pathogen, non corretto dal resolver v1.0.0.
3. **Bug Interferon-beta-like** (scoperto in S1bis TDD) — MeSH tree D MEDIUM
   small_molecule contraddiceva falsamente LLM=cytokine_stim, **~1735 cluster
   impattati** (3x più grande del case target).

**Reazione utente (2026-05-25 sera, fine sessione)**:

> "sono preoccupato. Continui a trovare bug e metterci delle pezze. Non mi
> fido più di tutta la pipeline. Ripercorrila tutta"
>
> "per adesso aggiorna i docs fino ad adesso, faccio audit completo dalla
> prossima sessione"

L'utente ha ragione paper-grade: ogni rebuild ha rivelato nuovi bug, segnale
che la spec S1 §4.3 (decision table resolver) era incompleta e che il pattern
"discovery-driven patching" non garantisce coverage end-to-end della pipeline.

---

## Scope audit completo proposto per next session

Audit **stage-by-stage** con gate utente per ogni stadio. Wall stimato:
2-4h per stadio × 5 stadi = **10-20h totali distribuiti su 2-3 sessioni**.

### Stadio 1 — LLM sample-level classification (879k record beta + 130k alpha)

**Cosa pretende di fare:** classificare ogni sample dalla stringa di metadati
GEO in `sample_facts.stage1.v3` (cell context, perturbazioni, dose, tempo,
ambiguity flags).

**Cosa auditare:**
- Schema validity 100% (verificato in P4 β, ma re-check cross-distribuzione
  per tier S/M/L/XL).
- Drift LLM kind distribution vs ground truth subset (mini-gold 100 + gold
  130k XLSX).
- Cross-check `agent_normalized` field-swap effettivo nei dati raw vs S2
  (l'audit diceva 23.87% ma il diff dice CHEBI_FIELDSWAP=0 ⇒ discrepancy
  da chiarire).
- Edge case: stage1 fail rescue cascade H1/H1.2/H1.3 (vedi CLAUDE.md
  precedente) — verificare che i 802 rescue + 19 rescue strong + 1 manual
  curation siano coerenti.
- ARCHS4 mouse-mislabel discovery H2 — 9.654 sample droppati GSE-level.
  Verificare conteggi nel master rescued.

**Output:** trust report `docs/findings/<date>-stage1-trust-audit.md`.

### Stadio 2 — LLM study-level design classification (39.247 record)

**Cosa pretende di fare:** interpretare design sperimentale per studio:
replicate groups, design_role per sample, comparisons con
`comparability_anchor`.

**Cosa auditare:**
- Schema validity 100% (verificato in P4 β rescue H3, re-check).
- `design_role` accuracy binaria 98% su mini-gold (P3.5 era 96.7% α, β
  gate1 98%). Verificare se ci sono pattern wrong specifici (multi_arm
  splits, time_course, etc.).
- `design_kind` distribution sui 39k study: cosa dice il LLM, distribuzione
  vs ground truth subset.
- Edge case: super-series ARCHS4 (193k multi-series risolti) — verificare
  che super-series resolver non abbia introdotto duplicate o lost.
- Cross-check schema versions Stage 2 v2 vs documento `stage2.v2`.

**Output:** trust report `docs/findings/<date>-stage2-trust-audit.md`.

### Stadio 3 — anchor v3.1.1 + resolver v1.1.0 (390k cluster)

**Cosa pretende di fare:** raggruppare studi cross-studio per anchor key
canonical (ChEBI/HGNC/MeSH-prefixed).

**Cosa auditare:**
- Decision table resolver completa (16+ branch spec §4.2): verificare TUTTI
  i path con test fixtures dedicati. Audit current test coverage.
- Audit kind_chebi_zero_roles=TRUE set (34.878 cluster): sample N=50 per
  validare manualmente che il flag identifica correttamente i pattern
  Resiquimod-like (legit) vs dihydroxyphthalic-like (ambiguo).
- Smoke su categorie poco-testate:
  - HGNC pure (gene knockdown/overexpression target)
  - ChEMBL naked (CHEMBL_NAKED_NOLOOKUP, 81 cluster)
  - HALLUCINATED_OR_FALLBACK 12.278 cluster: sample N=30 per pattern
- Audit `kind_overridden=FALSE` con `kind_unvalidatable=TRUE` set: distribuzione,
  pattern recurring (es. tutte le HGNC).
- Cross-check fragmentation: cluster L0G fragmentation 34.4% (audit) vs
  v3.1.1 distribution.
- Cross-check anchor_key parsing: `parse_anchor_key` su sample N=100
  per validare round-trip correctness.

**Output:** trust report `docs/findings/<date>-stage3-trust-audit.md`.

### Stadio 4 — Layer A pooling DE (run_id 96c43acb, baseline pre-v3.1.1)

**Cosa pretende di fare:** pooling DE per-studio + REM/MEGA su cluster
Stage 3.

**Cosa auditare:**
- ⚠️ **Layer A 96c43acb è stato fatto su Stage 3 v3 baseline, NON v3.1.1.**
  La logica statistica è valida (pooling deterministico su gene matrix), ma
  l'**interpretation downstream** dei cluster pooled usa anchor v3
  (pre-fix). Cosa significa per i risultati Layer B esistenti?
- Dream silent fallback bug (ADR-0016 Decision 2): verificare che fix
  `make.unique()` su gene symbols sia preservato.
- QC report `qc_report.rds` 96c43acb: completeness, missing values, etc.
- Smoke 5 cluster paradigmatici: 1 mega-big + 1 mega-aug bidir + 1 mega-aug
  mono + 1 REM-only + 1 skipped (non-clusterable). Verificare consistency
  pooled statistics.
- Cross-check config registrata: `max_baseline_per_arm=350`,
  `dream_workers_cap=16`, `franchini_correction=TRUE`, etc.
- Bias check Franchini correction: validare che la correction è applicata
  correttamente sui mega-aug.

**Decisione cardinale post-audit Stage 4:**
- Layer A 96c43acb è ancora trustable post-S2bis o devo lanciare nuovo
  fullrun su Stage 3 v3.1.1 (4-6h DGX)? Risposta dipende dall'interpretation
  use-case downstream Layer B.

**Output:** trust report `docs/findings/<date>-stage4-trust-audit.md`.

### Stadio 5 — Layer B existing selection (run 56b911e6, 15 case study)

**Cosa pretende di fare:** plot publication-grade per cluster selezionati a mano.

**Cosa auditare:**
- 11/15 case study che NON sono i 4 critically wrong: validare uno-per-uno
  che `kind_effective_resolved` e `agent_id_resolved` (calcolati post-v3.1.1)
  sono coerenti con `narrative.qmd` previsto.
- Audit `kind_chebi_zero_roles` flag sui 15: quali sono flagged? Sono
  problematici? Es. Resiquimod CHEBI:36706 case 2 — anche se flagged,
  è legit.
- Audit literature check: per ogni case, validare via PubMed/UniProt che
  l'interpretation è scientifica. (Audit hard, tempo > 1h per case = 15h
  totali. Sconsigliato fullrun, meglio random sample 5/15.)
- Cross-check con audit S2bis: i 15 cluster originali (selezionati
  pre-S2bis) hanno ancora gli STESSI `cluster_id` in v3.1.1? Probabilmente
  alcuni anchor_key sono cambiati per la nuova rule
  DISEASE_KIND_CONTRADICTED.

**Output:** trust report `docs/findings/<date>-layer-b-trust-audit.md`.

---

## Workflow proposto per next session

1. **Sessione 1**: Stadi 1 + 2 (LLM classification). ~4-8h. Output: 2 trust report.
2. **Sessione 2**: Stadio 3 (anchor + resolver). ~3-5h. Output: 1 trust report.
3. **Sessione 3**: Stadi 4 + 5 (DE pooling + Layer B). ~3-7h. Output: 2 trust report.

Gate utente tra ogni sessione. Branch invariato fino a chiusura audit.

**Sub-skill da usare**: `superpowers:systematic-debugging` come framework,
NOT `executing-plans` (che presuppone un plan già scritto).

**Memoria correlata**: [[no-whack-a-mole-debugging-sistematico-dopo-crash-ripetuti]]
+ [[feedback-no-fretta-paper-grade]] + [[feedback-explain-then-decide]] +
[[feedback_audit_before_patch_cycle]] (NEW, da scrivere — vedi sotto).

---

## Decisioni rinviate (post-audit completo)

- **S3 Stage 4 rebuild v3.1.1 su DGX**: SOSPESO finché audit non chiuso.
- **S4 Layer B re-shortlist + batch**: SOSPESO.
- **S5 close ADR-0018 → Accepted**: SOSPESO. ADR resta `Proposed`.
- **Merge `p5-llm-anchor-classification-audit` → master**: SOSPESO.

---

## Lessons learned paper-grade (per archive)

1. **Audit comprehensive PRIMA di iniziare patch incrementali.** Quando un
   audit identifica N case wrong, NON limitarsi a fixarli uno-per-uno via
   TDD; cerca PATTERN che li causano nella spec / decision table. Il bug
   Interferon-beta è stato scoperto via TDD solo perché ho aggiunto un test
   "sanity check" — ma sarebbe rimasto silente se non avessi pensato a
   includerlo. Quanti altri sanity check non ho aggiunto?

2. **Spec decision table NON è prova di copertura.** Spec §4.2 (resolver) +
   §4.3 (override) erano formalmente scritte, ma incomplete. Asymmetric
   trust su source non era nella spec. Né la regola DISEASE_KIND_CONTRADICTED.
   Né l'enum ZERO_ROLES.

3. **TDD su edge case è una linea di difesa, non una garanzia.** I 4
   critically wrong dell'audit non sarebbero stati identificati via
   sole-test. Servono **dati reali full-scale** + audit cross-check
   (ChEBI/MeSH/HGNC/PubMed) per scoprire bug nascosti.

4. **Trust va costruito una sola volta + difeso continuously**, non
   ricostruito sotto pressione. Quando l'utente perde fiducia, NON spingere
   per "fix subito, poi recuperiamo"; ferma il lavoro, audita, ricostruisci
   trust.

---

## Riferimenti

- Spec ADR-0018: `docs/decisions/0018-llm-anchor-ontology-override.md`
  (status: Proposed, in attesa di audit chiusura)
- Spec design v1.0.0: `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
- Plan task-by-task: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
- Findings paper-grade:
  - `docs/findings/2026-05-24-llm-anchor-classification-audit.md` (audit originale)
  - `docs/findings/2026-05-25-stage3-v31-diff.md` (diff v3 vs v3.1 intermediate)
  - `docs/findings/2026-05-25-stage3-v311-diff.md` (diff v3 vs v3.1.1 final)
- Commit log branch:
  ```
  561f3f0 P5 audit S2bis close: CLAUDE.md status S1bis+S2bis COMPLETED + handoff S3 DGX
  5a9aad1 P5 audit S2bis: Stage 3 v3.1.1 rebuild + diff + finding (4/4 audit chiuso)
  d06e389 P5 audit S1bis: anchor v3.1.1 chiude 4/4 audit set
  68cd42c P5 audit S2 close: CLAUDE.md status S2 COMPLETED + handoff S3
  f16de37 P5 audit S2 Task 7: diff Stage 3 v3 -> v3.1 + finding report
  74dcad4 P5 audit S2 Task 6: Stage 3 v3.1 rebuild + perf budget v3.1
  723df2f P5 audit S1 close: CLAUDE.md status S1 COMPLETED + handoff S2
  45459f2 P5 audit Task 5: smoke isolato 6 case paradigmatici anchor v3.1
  afac917 P5 audit Task 4: integrazione anchor v3.1 in Stage 3 + tracking columns
  7aad2e2 P5 audit Task 3: infer_kind_from_ontology + override policy TDD
  a91764d P5 audit Task 2: resolve_agent_canonical() in R/anchors.R + tests TDD
  5ea32c7 P5 audit Task 1: R/ontology-lookup.R + mini fixtures + tests TDD
  ```
