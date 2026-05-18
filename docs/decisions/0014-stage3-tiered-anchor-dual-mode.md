# ADR-0014 -- Stadio 3 tiered anchor + dual-mode + canonical directionality

**Status:** Accepted (2026-05-18, implementation complete su branch p5-stadio3-raggruppamento; merge a master tramite ff-merge dopo ottimizzazione perf)
**Decisori:** lucavd
**Predecessori:** ADR-0006 (positioning), ADR-0012 (stage2 schema multi-axis limitation)
**Sostituisce:** --
**Spec di riferimento:** `docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md`

## Contesto

Stadio 3 (raggruppamento cross-studio sui `comparability_anchor`) era pianificato in CLAUDE.md
come unico step da specificare post-beta. Pre-spec, l'assunzione implicita era "cluster by exact
13-segment anchor match, k>=1 acceptable". Su 39.247 stage2 predictions cross 28k+ studi questo
genera ~70-90% singleton clusters, vanificando il pooling cross-study.

## Decisione

Stadio 3 implementa:

1. **Tiered anchor a 5 livelli** (L0..L4) con droppability biology-driven
   - Tier S (inviolabile, 3 segmenti): kind_effective, agent_id, tissue
   - Tier A (system identity, 3): variant_label, disease_status, phase_canonical
   - Tier B (modulators, 2): cell_state, cell_id
   - Tier C (continuous, 2): dose_canonical, duration_canonical
   - Tier D (low-info, 1): has_engineered

2. **Hard filters (2 segmenti)** come partition non-mergeabili a qualunque L:
   subcellular, context_kind

3. **Dual-mode**: anchor-group (per mega-analisi raw counts) + anchor-pair
   (per REM metafor). Output entrambi sempre.

4. **Canonical directionality** + flag `direction_check` per evitare cancellation REM
   cross-study quando ruoli sono swapped tra studi.

5. **Pooling safety score** `min(modal_freq per dropped segment)` come primary aggregator
   (weakest-link semantics; conservative).

6. **Boolean use-flags** (`usable_rem/mega x strict/relaxed`) in luogo di tier labels
   GOLD/SILVER/BRONZE (rigore vs heuristica).

## Conseguenze

### Positive
- "Spremiamo per bene" i dati: cluster pesabili a 5 livelli adattivi.
- Mega-analisi diventa first-class consumer (raw counts ARCHS4 H5 disponibile).
- Direction safety previene errori scientifici subdoli in REM cross-study.

### Negative / costi
- Output 5x piu' grande (5 levels) vs single L0.
- ADR-0006 va emendato: "metafor REM resta primary, mega-analisi secondary per cluster
  k-deboli N-ricchi" (addendum a questo ADR).
- Performance budget 15min su 39k record (a verificare in plan).

### Da rivisitare
- Se v2 di safety score serve un metric piu' raffinato (Shannon entropy normalized),
  esporre come opt-in.
- Se cross-tissue pooling diventa richiesto, valutare promozione `tissue` da S a A.

## Status

Accepted 2026-05-18. Implementazione completa su branch `p5-stadio3-raggruppamento`; ff-merge a master rinviato dopo ottimizzazione perf orchestrator (~32min wall vs 15min plan budget su full β).
