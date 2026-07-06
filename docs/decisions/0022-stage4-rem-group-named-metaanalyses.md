# ADR-0022: Stadio 4 — ramo `rem_group` per le meta-analisi cross-studio nominate

- **Status:** Accepted
- **Date:** 2026-07-06
- **Deciders:** lucavd, Claude (audit RED_ALERT F6)
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

La porta di selezione dello Stadio 4 (`.identify_layer_a_clusters`) ammetteva al pooling solo tre
metodi (`rem` pair k∈[3,9], `mega` group MEGA-strict, `mega_aug` pair k=2). Il gate `mega`
richiedeva `usable_mega_strict` = `level ∈ {0,1}` **e** `safety_min ≥ 0.7`. Questi due requisiti sono
auto-contraddittori rispetto a dove vivono le meta-analisi vere: il **nome** del composto/malattia sta
a **L2–L4** (enzalutamide=L4), e una meta-analisi cross-studio reale ha `safety_min` basso **per
design** (25 laboratori con linee/dosi/tempi diversi). Risultato: su 72 MEGA processati in v7, **71
erano senza nome**; SARS-CoV-2 (k=25), enzalutamide (25), Breast Neoplasms (88) esistevano nello
Stadio 3 ma `poolable=FALSE`. Il deliverable finale era vuoto proprio delle cose che il progetto
promette (finding `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`).

Errore concettuale sotto: la soglia `safety_min ≥ 0.7` ha senso per il **MEGA** (modello congiunto,
serve omogeneità), ma queste sono target da **REM** (random-effects: *modella* l'eterogeneità I²/τ²,
non la filtra). Lo Stadio 4 applicava la mentalità MEGA a tutto.

## Decision Drivers

- Recuperare al pooling le meta-analisi **nominate** cross-studio (il valore unico del progetto),
  senza degradare la validità statistica (paper-grade).
- **Non toccare** i tre rami esistenti (retrocompat byte-identica: nessuna regressione sui risultati v7).
- Evitare la **pseudo-replicazione**: bracci multipli dello stesso studio (dosi/tempi diversi) non
  devono gonfiare k e sgonfiare I²/τ².
- Onestà sui limiti: dichiarare ciò che non viene modellato invece di nasconderlo.

## Considered Options

1. **Abbassare le soglie del gate `mega` esistente** (es. `safety_min` a 0.5, ammettere L2–L4) —
   riusa il MEGA. Rischio: poolare in un unico modello studi eterogenei = statistica indifendibile;
   inoltre modifica un ramo esistente (regressione).
2. **Nuovo ramo `rem_group`**: porta strutturale separata (group nominati L2–L4, `kind` non degenere,
   **senza** `safety_min`), instradata a REM per-studio con eterogeneità I²/τ² a valle. Additivo.
3. **Solo documentare il limite** e lasciare il deliverable com'è — scartata (il progetto non
   manterrebbe la sua promessa).

Sotto-decisione per l'opzione 2 (pseudo-replicazione dei bracci intra-studio):
- (A) contare `unique(study_id)` nel gate k_eff — necessario ma non sufficiente (il REM resta
  pseudo-replicato).
- (B) fondere i bracci nel builder unendo i campioni — cambia i contrasti DE.
- (C) **collapse a valle**: sintesi per-studio via inverse-variance fixed-effect per
  `(cluster, study, gene)` prima del REM, **senza** unire i campioni. Builder invariato.

## Decision Outcome

Scelta: **Opzione 2 (ramo `rem_group`) + sotto-decisione (C) collapse dei bracci intra-studio.**

Motivazione: il ramo separato recupera le meta-analisi nominate senza toccare i rami esistenti
(retrocompat byte-identica verificata: mega/mega_aug/rem 72/353/8 identici a v7) e usa il metodo
statisticamente corretto per target eterogenei (REM, che modella I²/τ² invece di filtrarli). Il gate
è **strutturale** (group nominato, `kind` non degenere, `k_eff≥3` su studi distinti, `n_min=2`),
senza `safety_min`: l'eterogeneità è un output da riportare, non un criterio di esclusione. Il collapse
(C) elimina la pseudo-replicazione mantenendo i bracci come contrasti separati nel DE — sintesi per
studio a valle, non fusione dei campioni.

### Consequences

- **Positive:** 70 meta-analisi nominate ora poolate (prima ~0), tutte le bandiera presenti con I²/τ²
  onesti; `k_effective` = studi distinti; nessuna regressione sui rami esistenti; deliverable
  finalmente popolato di ciò che il progetto promette.
- **Negative:** i 279 cluster treated-only senza comparison Stadio 2 con quel group come
  `treated_group` cadono (`rem_group_insufficient_in_study_controls`, k_eff<3) — recupero rinviato a
  un passo 3 (augmentation cross-studio del lato-controllo). Il collapse assume **indipendenza tra
  bracci**: la correlazione da control condiviso non è modellata (raffinamento Franchini futuro,
  limite dichiarato).
- **Neutral:** cache-bust via `schema_versions.rem_group_strategy` (non tocca la chiave della cache
  counts). Il ramo è sempre eseguito (nessuna cache del pooled).

## Links

- Finding-causa: `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`
- Finding-risultati: `docs/findings/2026-07-06-stage4-rem-group-results.md`
- Spec: `docs/superpowers/specs/2026-07-05-stage4-rem-group-named-metaanalyses-design.md`
- Plan: `docs/superpowers/plans/2026-07-05-stage4-rem-group-named-metaanalyses-plan.md`
- Run v8: `…/simulomicsr-stage4-v8/20260706T112612Z-stage4-v8-a500d032/` (run_id `a500d032`)
- Commit feature: `4f3a544`..`eb2a782`; verifica `analysis/audit/2026-07-06-stage4-v8-*`.
- Correlato: ADR-0021 (metrica di consistenza cross-studio), ADR-0018 (ontology override).
