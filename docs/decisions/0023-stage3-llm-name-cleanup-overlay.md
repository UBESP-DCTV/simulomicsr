# ADR-0023: Stadio 3 — overlay LLM name-cleanup nel re-cluster (de-frammentazione v9)

- **Status:** Accepted
- **Date:** 2026-07-19
- **Deciders:** lucavd, Claude (audit RED_ALERT F6, Fase D v9)
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

Il recupero-nome deterministico (v5–v7) risolve gran parte dei minestroni ma lascia una coda di
cluster mal-nominati (`agent_id_resolved` = `STR:`/`UNK`, o nomi-spazzatura da risoluzione troppo
larga). Per questi, i frammenti della **stessa** entità restano dispersi sotto etichette diverse →
non si fondono → le meta-analisi cross-studio nominate (ramo `rem_group`, ADR-0022) sono meno
numerose e meno potenti del possibile. Il name-cleanup Mistral (run T13, `R/name-cleanup.R`) produce
una **side-table** `cluster → identità corretta` verificata (precision-gated, canary-protetta), ma
finora restava fuori dalla pipeline (usata solo per etichettare a valle). Serve decidere **come**
portare quelle correzioni **dentro** il re-cluster in modo che i frammenti si fondano davvero.

## Decision Drivers

- **De-frammentazione reale:** la correzione deve agire sull'asse che frammenta (l'`agent_id`, 2°
  segmento dell'anchor), non solo sull'etichetta finale.
- **Precisione paper-grade:** nessuna over-correction; solo correzioni ad alta confidenza; i cluster
  già-buoni (canary) non devono essere toccati.
- **Coerenza dell'anchor:** il `kind` (1° segmento) deve restare un kind-anchor canonico, altrimenti
  un ID corretto con kind incoerente NON si fonde (o peggio inietta un bucket spurio).
- **Retrocompatibilità:** senza side-table lo script deve produrre il v9-pre-equivalente
  (deterministico), così l'overlay è un layer additivo verificabile in isolamento.

## Considered Options

1. **Overlay `GSM → identità` sul `recovery_lookup`, solo `action=="override"`** — il name-cleanup
   corregge l'agent_id dei GSM membri dei cluster rivisti; l'LLM vince sul deterministico solo dove
   la policy ha prodotto un override ad alta confidenza.
2. **Ri-etichettatura post-hoc dei cluster poolati** (come oggi) — nessuna fusione, solo label più
   leggibili sul deliverable. Scartata: non de-frammenta.
3. **Fidarsi del `kind` LLM tal-quale nell'anchor** — scartata: `new_kind` è vocabolario libero
   (`cytokine`, `genetic_mutation`), non enum; iniettarlo grezzo rompe il bucketing.

## Decision Outcome

Scelta: **Opzione 1** — overlay `GSM → identità` sul `recovery_lookup`, gate `action=="override" &
!is.na(new_id)`, con **canonicalizzazione STRETTA del kind** prima dell'iniezione.

Motivazione: agganciare la correzione ai GSM membri dei cluster override fa sì che il re-cluster
ricalcoli l'anchor con l'`agent_id` giusto → i frammenti della stessa entità coincidono e si fondono,
mantenendo lo stesso kind deterministico (che governa il 1° segmento per i non-genetic/non-biologici).
Il precision-gate (override-only) e la canary-safety (un canary non può mai produrre `override`)
tengono la precisione. La canonicalizzazione (`.canonicalize_overlay_kind`: `cytokine`→`cytokine_stim`,
`pathogen`→`pathogen_or_aggregate_exposure`, scarto dei `genetic_*` non-anchor) evita sia i merge
mancati (biologici grezzi) sia l'iniezione di kind non-anchor.

### Consequences

- **Positive:** rem_group poolati **70 → 161** (+130%); disease UNK 25.086 → 9.748; le meta-analisi
  bandiera guadagnano potenza (breast rem_group k 6 → k_eff 22) **senza** degradare l'omogeneità
  (I²_med 74,2 → 79,9, range invariato: fusioni coerenti, non minestroni).
- **Negative:** costo computazionale del re-pool cresce (2478 min vs 1067 v8) per il maggior numero
  e la maggiore dimensione delle meta-analisi rem_group; il `kind` proposto da Mistral entra
  canonicalizzato, non ri-derivato dall'ontologia (fidato sugli override).
- **Neutral:** il `k_effective` poolato resta molto minore degli studi-membri (breast 277 → 22): il
  collo di bottiglia è il gate di controllo interno (**limite L7**, treated-only), non il name-recovery.

## Pros and Cons of the Options

### Opzione 1 (scelta)
- **Pro:** de-frammenta all'asse giusto; additiva e isolabile (retrocompat senza side-table);
  precision + canary gate; kind canonicalizzato → anchor coerente.
- **Contro:** dipende dalla qualità della side-table Mistral; kind fidato (non ri-validato in-anchor).

### Opzione 3 (kind LLM grezzo)
- **Pro:** nessun codice extra.
- **Contro:** `new_kind` non-enum → iniezione di kind non-anchor → un-bucketing (misurato: 21 override
  `genetic_*` non-anchor + 438 biologici grezzi sul side-table k≥2). Trappola addizionale:
  `.canonicalize_resolver_kind` mapperebbe `genetic_*`→`genetic_perturbation`, anch'esso non-anchor.

## Links

- Finding: `docs/findings/2026-07-19-stage4-v9-defragmentation-results.md`.
- Codice: `R/stage3-name-cleanup-overlay.R` (`.side_table_to_recovery_overlay`,
  `.overlay_recovery_lookup`, `.canonicalize_overlay_kind`), `R/stage3-suspect-triage.R`.
- Script: `analysis/p4-fase-f7-stage3-v9-final.R`, `analysis/p4-fase-f5-stage4-layer-a-rebuild-v9.R`,
  `analysis/p5-name-cleanup-run.R`.
- Base: ADR-0022 (ramo rem_group), ADR-0018 (ontology override), name-cleanup T13
  (`docs/findings/2026-07-07-name-cleanup-results.md`).
