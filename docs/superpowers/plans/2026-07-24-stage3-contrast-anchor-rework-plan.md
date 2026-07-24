# Plan — Rework anchoring Stadio 3: anchor derivato-dal-contrasto (Opzione B)

**Data:** 2026-07-24 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Spec di design:** `docs/superpowers/specs/2026-07-24-stage3-contrast-anchor-design.md`
**Finding (numeri):** `docs/findings/2026-07-24-anchor-contrast-coherence-simulation.md`
**Decisioni utente (bloccate):** B (re-anchor a monte) · k≥3 · combo=entità · drop degeneri/nuisance-only ·
validazione su TUTTI i cluster · pipeline+gate DETERMINISTICI (LLM di validazione = Mistral, NON Claude).

> 🔴 GATE: nessun re-cluster (~8h) / re-pool (~50h) finché la **Fase 1** (simulazione col resolver canonico)
> non passa e l'utente non dà il GO. Regola hard 3 (validate-before-fullrun).

---

## 0. Obiettivo e criterio di accettazione

Cambiare come lo Stadio 3 forma i cluster in modo che, **per costruzione**, un cluster raggruppi solo studi
che misurano lo **stesso contrasto** (stessa entità-delta + stesso tipo-controllo). Criterio = **coerenza
per-cluster** (ogni cluster = meta-analisi difendibile), verificata su TUTTI i cluster. La consistenza si
riporta come forza. Tutto deterministico e riproducibile.

## 1. Idea centrale (da cui derivano le fasi)

Oggi l'anchor entità = perturbazione primaria del **campione trattato** (comparison-blind). Nuovo:
**anchor entità = canonicalize( perturbazioni(trattato) ∖ perturbazioni(controllo) )** = il DELTA della
comparison Stadio 2, + `control_type`. Il DELTA si ottiene confrontando i `factor_levels` dei due bracci
(già disponibili nella comparison Stadio 2, già usati dal dispatch Stadio 4). L'entità del delta passa nel
**resolver esistente** (HGNC/ChEBI/MeSH/ChEMBL): riusa TUTTA la macchina dei nomi, le dà solo l'entità
giusta. Perturbazioni **held-constant** (SARS in "SARS+farmaco vs SARS") non ancorano più.

---

## FASE 0 — Preparazione (no code di produzione)

- **T0.1** Congelare gli asset di questa sessione come baseline (già in `analysis/audit/2026-07-24-anchor-coherence-sim/`).
- **T0.2** Definire la **firma-di-contrasto canonica** (il cuore): funzione pura che, dati `treated_fl` +
  `control_fl` di una comparison, restituisce `(control_type, delta_class, delta_entity_raw)`. Base già
  scritta in `contrast-sig-engine.R` (parse factor_levels, classificatore chiave→classe, delta). Da
  portare in un modulo R testato.

## FASE 1 — VALIDAZIONE IN SIMULAZIONE (il gate go/no-go, NO re-cluster)

Prova che il design funziona **prima** di spendere le 8h. Riusa i contrasti già ricostruiti (38.440 membri).

- **T1.1 — Filtro degeneri (a monte).** Implementare il drop delle comparison degeneri con criterio
  **`factor_levels` identici** (NON label): normalizza e confronta la firma key=value dei due bracci. Deve
  droppare i ~246 nulli veri, NON i 18 mal-etichettati (label uguale ma factor diversi). **Loggare la lista
  droppata** (GSE + comparison_id). Test: i 20 esempi noti (`60-degenerate-measure.R`).
- **T1.2 — Entità-delta CANONICA.** Estendere `contrast-sig-engine.R`: l'entità del delta passa nel
  **resolver reale** (`resolve_agent_canonical` / `.normalize_*_to_*`) invece del valore grezzo-da-label.
  Aspettativa: i sinonimi si fondono (SARS "infected"/"sars cov" → `NCBITaxon:2697049`), k recuperato.
- **T1.3 — Simulazione ri-cluster canonica.** Ri-partizionare i contrasti per `(entità-delta canonica,
  control_type)` — **cross-cluster** (non più solo within-cluster: qui i frammenti sinonimi di cluster
  diversi possono fondersi, cosa che il lower bound di stanotte NON catturava). Contare cluster poolabili
  k≥3 e k.
- **T1.4 — Verifica coerenza su TUTTI i cluster simulati.**
  - **Deterministica (primaria, 100%):** control-homogeneity, singola entità canonica, non-degenere.
  - **Mistral (audit, su tutti i poolabili):** rubrica "un contrasto o molti?" via il modello della
    pipeline (DGX, self-hosted). Confronto deterministico↔Mistral; ogni disaccordo indagato.
- **T1.5 — Controlli.** (a) i **26 coerenti attuali restano interi**; (b) un **minestrone noto** (SARS
  non-splittato) resta flaggato incoerente (controllo negativo); (c) k **batte il lower bound** di stanotte.
- **GATE T1 → utente:** tabella coerenza per-cluster (deterministica) + k vs lower bound + 26/26 preservati.
  Se non passa → STOP, torno con il perché. Se passa → GO per Fase 2.

## FASE 2 — IMPLEMENTAZIONE NELLA PIPELINE (solo dopo GATE T1)

- **T2.1** Portare il filtro degeneri (T1.1) nel build Stadio 3 (o pre-pass su stage2_master), loggato.
- **T2.2** Innestare la firma-di-contrasto canonica in `.extract_anchor_segments` / `.build_anchor_for_level`:
  l'anchor entità dei group/pair deriva dal DELTA della comparison, non dalla perturbazione del campione.
  Richiede il lookup della comparison a build-time (portare `.lookup_cmp_by_treated_group` a monte).
  **Decisione tecnica aperta (la risolve la Fase 1):** unità di clustering = comparison (contrasto) invece
  di treated-group, per i multi-arm. TDD, retrocompat verificata.
- **T2.3** Gate di coerenza deterministico come componente (control-homogeneity + entità unica + non-degenere).
- **T2.4** Bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` + anchor schema version (lezione cache-miss v7).
- **T2.5** Suite test verde; smoke SMOKE=1 sul nuovo anchor.

## FASE 3 — RE-CLUSTER + RE-POOL (run gated, setsid, update orari)

- **T3.1** Re-cluster Stadio 3 (~8h). **ANTI-STALE**: schema version bumpata, log filtro degeneri presente,
  struttura cluster cambiata come predetto in Fase 1 (non output cache stale).
- **T3.2** Re-pool Stadio 4 (~50h, DGX/disco esterno).
- **T3.3** **Verifica coerenza per-cluster su TUTTI i poolabili REALI** (deterministica + Mistral) →
  deve combaciare con la predizione Fase 1. Case study noti (SARS-vs-mock, enzalutamide, fulvestrant, HCC)
  presenti e coerenti.
- **GATE T3 → utente:** deliverable con verdetto coerente/scartato-spiegato per OGNI cluster + la prova.

## FASE 4 — CLOSEOUT

- ADR nuovo (anchor derivato-dal-contrasto + gate deterministico). Finding risultati. Ledger. Solo qui,
  con la prova per-cluster, si può parlare di clustering irreprensibile. Layer B dopo (secondario).

---

## Criterio di PASS (deciso con l'utente)
**Garanzia per-cluster, non una percentuale:** OGNI cluster del deliverable è verificato **coerente**
(deterministicamente) **oppure scartato/spiegato**, con la prova accanto. Più: filtro degeneri loggato,
26/26 preservati, k ≥ lower bound, tutto ricalcolabile senza Claude.

## Rischi / questioni aperte (oneste)
- **Unità di clustering** (comparison vs treated-group) per i multi-arm: la Fase 1 misura quale dà coerenza
  senza distruggere k.
- **Copertura resolver sul delta**: se il resolver non canonicalizza un'entità-delta, resta `STR:` → possibile
  frammentazione residua (misurata in Fase 1, non a valle).
- **disease low-k**: molte disease coerenti finiranno k<3 → scartate (accettato). Meno cluster, tutti veri.
- **Filtro degeneri label-based sui 18**: conservativo; loggato per audit.
