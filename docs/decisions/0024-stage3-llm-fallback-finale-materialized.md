# ADR-0024: LLM-fallback finale sugli indeterminati — materializzato in v10

- **Status:** Accepted
- **Date:** 2026-07-22
- **Deciders:** lucavd, Claude (audit RED_ALERT F6, v10)
- **Supersedes:** —
- **Superseded by:** —
- **Base:** ADR-0023 (overlay name-cleanup v9), ADR-0022 (ramo rem_group), ADR-0018 (ontology override)

## Context and Problem Statement

Dopo il v9, metà del corpus Stadio 3 (**158.751 cluster**, `agent_id_resolved` = `UNK`/`STR:`)
restava indeterminata: nomi non risolti né dal recupero deterministico (v5–v7) né dall'overlay
name-cleanup sui sospetti k≥2 (v9). La domanda: **conviene un LLM-fallback finale su TUTTI gli
indeterminati** (Mistral legge i metadati grezzi dei membri e propone l'identità) e
**materializzarlo** con un re-cluster + re-pool (~2 giorni di calcolo)? La decisione richiedeva
di **quantificare l'upside con statistiche complete** (nessun campione) PRIMA di spendere il
ciclo pesante — non a intuito.

## Decision Drivers

- **Misura-prima-di-materializzare:** il run pesante (re-cluster+re-pool) è gated; si fa SOLO se
  l'upside poolabile — non il recupero-nome grezzo — lo giustifica.
- **Statistiche complete:** il fallback Mistral su TUTTI gli indeterminati (non un campione),
  poi la simulazione deterministica dell'impatto, poi il guadagno POOLABILE reale (gate rem_group
  riprodotto senza re-pool).
- **Precisione paper-grade:** precision-gate (solo `override`), canary-safety, kind
  canonicalizzato (come v9); nessun degrado dell'omogeneità.
- **Onestà sul limite L7:** distinguere l'upside reale (meta-analisi nominate poolabili) dal
  rumore (k=1 isolati) e dagli indeterminati che restano treated-only (non recuperabili).

## Considered Options

1. **Materializzare (A)** — LLM-fallback su tutti gli indeterminati → 2° overlay nel re-cluster
   v10 → re-pool v10. Costo ~2 giorni di calcolo (la parte costosa, il run Mistral, è già fatta).
2. **Documentare come limite noto (B)** — misurare l'upside e lasciarlo NON materializzato,
   tenere v9 come stato finale.
3. **Affinare poi decidere (C)** — prima misurare il guadagno POOLABILE reale (non solo
   studi-membri) sulle bandiera, poi scegliere A/B con un numero concreto.

## Decision Outcome

Percorso: **C → A**. Prima l'opzione C (affinamento): l'analisi di guadagno poolabile
(`2026-07-20-v9-fallback-poolable-gain.R`) riproduce il gate rem_group (ADR-0022) sul membership
post-overlay senza re-pool, e stima **+22 nuove meta-analisi poolabili, +41 rafforzate, +151 k_eff**
(validata: breast k_eff_pre=23 vs v9 noto 22). Con quel numero concreto — upside NON throttled a
trivialità dall'L7 — l'utente ha scelto **A (materializzare)**.

Meccanismo: il re-cluster v10 (`p4-fase-f8-stage3-v10-final.R`) applica **DUE overlay** al
recovery_lookup — quello v9 (k≥2, cluster_id v9-pre) + quello fallback (STR:/UNK, cluster_id
v9-final) — additivi/disgiunti (il fallback ha girato sui cluster ANCORA STR/UNK dopo v9). Stesso
precision-gate e canonicalizzazione kind dell'ADR-0023. Il re-pool v10 riusa il ramo rem_group
invariato (config uniformity).

### Consequences

- **Positive:** rem_group poolati **161 → 184** (+23); k_eff bandiera cresce (breast 22→30,
  colorectal 18→27, hepatocellular 28→34, enzalutamide 27→30) — **come predetto dalla simulazione**
  (±1-3, over-stima H5 dichiarata); omogeneità **invariata** (I²_med 79,9→77,6, range identico →
  fusioni coerenti); 1,45M geni significativi (v9 1,23M). 23 nuove meta-analisi per il Layer B.
- **Negative:** ~2 giorni di calcolo (re-cluster 7,6h + re-pool 50,6h); il 79% degli override
  (k=1 isolati) non contribuisce al pooling (solo etichetta migliore nel catalogo).
- **Neutral:** 71 entità nominate restano NON poolabili (k_eff<3): il gate di controllo interno
  (**limite L7**, treated-only) morde ancora e NON è aggirato dalla de-frammentazione.

## Pros and Cons of the Options

### Opzione A (scelta, dopo C)
- **Pro:** materializza un upside REALE e VALIDATO (la sim ha predetto i k_eff); parte costosa
  già fatta; completezza paper ("fallback su tutti gli indeterminati").
- **Contro:** 2 giorni di calcolo; gran parte degli override è rumore cosmetico k=1.

### Opzione B (documentare)
- **Pro:** nessun calcolo pesante; v9 già cattura le fusioni grandi.
- **Contro:** lascia +23 meta-analisi nominate e il rafforzamento bandiera sul tavolo, dopo aver
  già pagato il run Mistral.

### Opzione C (affinare)
- **Pro:** converte l'incertezza L7 in un numero concreto (gate rem_group riprodotto) → decisione
  A/B fondata, non a intuito. **È stato il passo che ha ribaltato la raccomandazione da B ad A.**
- **Contro:** un'analisi extra (~ore) prima di decidere — ma cheap vs i 2 giorni del run.

## Links

- Finding: `docs/findings/2026-07-22-stage4-v10-fallback-materialization.md`.
- Codice: `analysis/p5-name-cleanup-fallback-run.R`, `analysis/p4-fase-f8-stage3-v10-final.R`,
  `analysis/p4-fase-f5-stage4-layer-a-rebuild-v10.R`.
- Analisi: `analysis/audit/2026-07-19-v9-*`, `2026-07-20-v9-fallback-poolable-gain.*`,
  `2026-07-20-stage4-v10-regate.*`.
