# ADR-0018: Post-hoc ontology override in agent anchor resolution

- **Status:** Proposed
- **Date:** 2026-05-25
- **Deciders:** lucavd
- **Supersedes:** —
- **Superseded by:** —
- **Branch di lavoro:** `p5-llm-anchor-classification-audit`
- **Spec di riferimento:** `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
- **Plan di esecuzione:** `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
- **Audit drive:** `docs/findings/2026-05-24-llm-anchor-classification-audit.md`

## Context and Problem Statement

L'audit di cross-validation 2026-05-24 (ChEBI 2026-05-01 release, HGNC complete set 2026, MeSH 2025) sui 267.056 cluster Stage 3 ha rilevato tre classi di errore sistematico nel output LLM Mistral-Small-3.2-24B che impattano la **interpretazione biologica** dei cluster, anche se NON invalidano il pooling DE algoritmico:

1. **Field-swap rate 23.87%** (63.738 cluster): il LLM riempie il campo `agent_normalized.preferred_name` con un numero ID controllato vocabulary (CHEBI/HGNC/MeSH) invece di un nome leggibile, lasciando il campo `id` vuoto. L'ID emesso è MA primariamente corretto (95.7% ChEBI valid, 78.9% HGNC valid quando dichiarato), recuperabile post-hoc con lookup deterministico.

2. **Pure hallucination rate 0.97%** (2.587 cluster): ID numerico inesistente in ChEBI/HGNC/MeSH. Bassissimo overall, ma include casi di MeSH UI confusi (es. `D011279` = Pregnanetriol invece di "Prostatic Neoplasms" attesa).

3. **`kind_effective` accuracy disastrosa per kind biologici**:
   - `cytokine_stim`: 0.7% match con ChEBI `has_role` (su 3.018 cluster con CHEBI risolto)
   - `pathogen_or_aggregate_exposure`: 2.4% match (su 1.705 cluster)
   - `vehicle_only`: 93.5% match (corretto)
   Causa probabile: il LLM associa "stimulation" generica al kind `cytokine_stim` indipendentemente dall'agente reale (Ethanol, Carnitine, DNA, tRNA sono frequenti misclassificazioni).

Effetto cumulato: il **clustering Stage 3** è semantically valido per il pooling DE (la chiave testuale dell'anchor v3 è deterministica per composto, gli studi su stesso composto pool insieme), ma le label biologiche dei cluster e il `kind_effective` sono sistematicamente sbagliati. Per il paper, questo invalida l'interpretazione biologica e quindi la sezione Results.

Il fix radicale (re-run Stage 1 con prompt rivisto) costerebbe 4-5 giorni di wall. Il fix invasivo (re-prompt Stage 2 mirato) costerebbe 1-2 giorni. La maggior parte degli errori è **deterministicamente recuperabile via ontology lookup** (ChEBI 205k compounds, HGNC 45k genes, MeSH 31k descriptors), senza nessuna re-inferenza LLM.

## Decision Drivers

- **D1 Paper-grade correctness:** le label e i kind devono essere biologicamente coerenti per la sezione Results. Non possiamo pubblicare "Pathogen exposure in blood; agent CHEBI:17126" sapendo che CHEBI:17126 è Carnitine.
- **D2 No re-LLM inference:** il rerun completo Stage 1/2 è 4-5 giorni di compute e non è migrationally compatible con i dataset esistenti.
- **D3 Algoritmica preservation:** il pooling Stage 4 e il design dell'anchor v3 a 13 segmenti sono validati. Non vogliamo cambiare quei contratti.
- **D4 Reproducibility:** il fix deve essere deterministico, versionato, ri-eseguibile. Le ontologie ChEBI/HGNC/MeSH hanno release dates note; il resolver deve registrare quale release è usata in `run_metadata.json`.
- **D5 Traceability:** il LLM original output va PRESERVATO. Ogni cluster deve avere campi `agent_id_llm_original` + `kind_effective_llm_original` accanto al `agent_id_resolved` + `kind_effective_resolved`. Il paper riporta sia il rate di override sia la conservatività della procedura.
- **D6 Wall time accettabile:** Stage 3 rebuild (minuti-ore), Stage 4 rebuild (4-6h DGX o 28h laptop, già rodato), Layer B rebuild (10 min). Totale 1-2 giorni di lavoro paper-grade.
- **D7 Stage 1/2 master output INVARIATO:** lo Stage 1 master predictions (879k record, 0.0% LLM residual post-rescue) e Stage 2 master rescued (39.247 predictions, 100% schema validity) restano artefatti immutati. Il rebuild parte dal master Stage 2 con nuovo resolver downstream.

## Considered Options

1. **Layer B patch-only (cosmetic).** Sostituire i 4 case study critically wrong nella selection, fixare le label, rilanciare il batch Layer B (10 min). Non risolve la pipeline; rimane suboptimal per il dataset full e per il paper Methods.

2. **Post-hoc ontology override in `R/anchors.R` + rebuild Stage 3 + Stage 4 + Layer B.** Implementa il resolver downstream che usa ChEBI/HGNC/MeSH dictionary come ground-truth. Stage 3 rebuild ricalcola tutti gli anchor_key e ricluster. Stage 4 rebuild ripoola sul nuovo Stage 3 (cluster_id cambiano). Layer B rebuild su nuova shortlist. ~1-2 giorni totali.

3. **Stage 2 re-prompt mirato + rebuild downstream.** Identifica ~5.000 cluster con kind_effective mismatch confermato, re-prompta Stage 2 LLM con istruzione esplicita "valida agent vs kind". Costo: stage 2 chunked rerun parziale (~3-6h DGX) + Stage 3 rebuild + Stage 4 rebuild. Mantiene LLM-driven semantics ma richiede infrastruttura DGX disponibile.

4. **Stage 1 prompt fix + full rerun pipeline.** Modifica system prompt Stage 1 con istruzione esplicita "If id_database is set, put the numeric ID in field `id`, NOT in `preferred_name`". Re-run Stage 1 (~18h DGX) + Stage 2 (~42h DGX) + Stage 3 + Stage 4 + Layer B. ~4-5 giorni totali. Risolve field-swap radicalmente. NON risolve l'errore sistematico su `kind_effective` per cytokine/pathogen (richiede redesign separato del prompt Stage 2).

## Decision Outcome

Scelta: **Opzione 2** — Post-hoc ontology override in `R/anchors.R` + rebuild Stage 3 + Stage 4 + Layer B.

Motivazione (ancorata ai driver):

- **D1**: ChEBI lookup risolve il 95.7% dei field-swap CHEBI (= dataset più accurato dell'audit). L'inference di `kind_effective` da `has_role` corregge l'80% degli errori cytokine/pathogen — gli unici irrecuperabili sono compound senza ChEBI roles (es. 4,5-dihydroxyphthalic acid) e MeSH hallucinated, che restano come paper-grade caveat residuo.
- **D2 + D6**: zero re-LLM inference; il rebuild downstream è tutto deterministic + parallelo. Wall total 1-2 giorni vs 4-5 dell'Opzione 4.
- **D3**: pooling Stage 4 logic invariato (lo riusiamo identical). L'anchor v3 design (13 segmenti) preservato — cambia solo come si POPOLA il segmento `agent_id` (e potenzialmente `kind_effective`).
- **D4**: ChEBI release date, HGNC tag, MeSH year registrati in `run_metadata.json` di Stage 3 + Stage 4. Resolver è codice (TDD-tested), idempotente per la stessa release.
- **D5**: tracking columns aggiunte allo schema Stage 3 (`agent_id_llm_original`, `agent_id_resolved`, `resolution_source` ∈ {LLM_LITERAL, CHEBI_DIRECT, CHEBI_FIELDSWAP, HGNC_*, MeSH_*, STRING_ALIAS_MATCH, FALLBACK}, `kind_effective_llm_original`, `kind_effective_resolved`, `kind_overridden` boolean, `kind_override_reason`).
- **D7**: Stage 1/2 master non toccati. Il branch `p5-llm-anchor-classification-audit` resta isolato finché il rebuild non è validato.

L'Opzione 4 resta valida come miglioramento futuro per dataset diversi (es. γ ARCHS4 mouse) o come "consolidation cleanup" ma NON è bloccante per questo paper.

### Consequences

- **Positive:**
  - 95.7% dei field-swap CHEBI risolti automaticamente, 78.9% degli HGNC, 93.6% dei MeSH naked
  - ~80% dei `kind_effective` cytokine/pathogen mismatch corretti via ChEBI roles
  - L2 limitation paper-grade quantificata e mitigata (rate residuo basso documentato)
  - Layer B selection ri-curabile su base più solida (la shortlist 31 attuale conteneva 5-7 case study problematici)
  - Codice resolver riusabile per qualunque downstream LLM-output usage in simulomicsr

- **Negative:**
  - Stage 3 + Stage 4 rebuild necessario (wall 4-6h DGX o 28h laptop)
  - Cluster_id cambiano (xxh32(anchor_key) ricalcolato) → `analysis/layer-b-selection.csv` corrente diventa obsoleto, va re-curato sulla nuova shortlist
  - Hard runtime dependency su ChEBI / HGNC / MeSH dictionary (~30 MB cache user_dir)
  - Nuova versione anchor `v3.1` (rispetto a v3); l'output Stage 3 deve segnalare `schema_versions.anchor = "v3.1"` per ovvi motivi di tracciabilità

- **Neutral:**
  - DESCRIPTION delta minore (nessun nuovo package — usiamo readr, dplyr, tibble già `Imports`)
  - I 2 cluster con compound LLM-oscuro CHEBI:17236 ("2-hydroxy-6-oxohexa-2,4-dienoic acid") restano come open question — sono probable LLM hallucination consistente. Senza re-LLM non si risolve. Si flagga come "suspected hallucination, requires manual review".
  - Stage 2 LLM original predictions restano sul disco e referenziabili da `run_metadata.json` di Stage 3 v3.1 per tracciabilità.

## Pros and Cons of the Options

### Opzione 1 — Layer B patch-only

- **Pro**: 1-2h wall, zero rebuild
- **Contro**:
  - Fix solo cosmetico Layer B; il dataset full Stage 3 (267k cluster) resta sporcato
  - Paper Methods deve documentare "selezionato manualmente per evitare 4 wrong" — non riproducibile
  - Future Layer B run replicheranno gli stessi bug
  - L2 limitation paper resta non-mitigated → reviewer red flag

### Opzione 2 — Post-hoc ontology override (SCELTA)

- **Pro**: deterministica, riproducibile, conservativa (preserva LLM original), wall accettabile
- **Contro**:
  - Cluster_id cambiano → re-shortlist Layer B
  - Hard dependency ontologie esterne (versioning needed)
  - Compound senza ChEBI roles restano unvalidatable

### Opzione 3 — Stage 2 re-prompt mirato

- **Pro**: corregge sintatticamente il LLM output (non solo downstream resolver)
- **Contro**:
  - Richiede DGX disponibile (~3-6h H100 stage2)
  - LLM Mistral può ri-sbagliare anche con prompt rivisto
  - kind_effective accuracy potrebbe non migliorare significativamente (il problema è probabilmente nel prompt design, non nel modello)
  - Non scala automaticamente ai cluster con compound senza ChEBI roles

### Opzione 4 — Stage 1 prompt fix + full rerun

- **Pro**:
  - Fix radicale field-swap; LLM output pulito ex-ante
  - Beneficio per future run (γ mouse, dataset diversi)
- **Contro**:
  - 4-5 giorni wall per un fix che ChEBI lookup fa in minuti
  - NON risolve `kind_effective` accuracy (richiede prompt Stage 2 separato)
  - Burn DGX time + non-trivial coordination (cron, watch logs, ...)
  - Re-run produce dataset MIGRATIONALLY-INCOMPATIBLE con tutti i deliverable esistenti (test fixture, smoke, gold mini-eval, ecc.)
  - Eccessivo per la natura del problema (field-swap è bug di field-assignment, non knowledge-bug)

## Notes for future me

- L'Opzione 4 può comunque essere considerata in **futuro** dopo il paper, per la pulizia generale del codebase / dataset γ. Aprire ADR separato.
- ChEBI release pinning: la pipeline NON deve scaricare ChEBI automaticamente ad ogni run — deve usare la release pinata in cache. Il refresh è esplicito.
- L'output Stage 3 v3.1 deve contenere `agent_id_llm_original` e `kind_effective_llm_original` per permettere audit retrospettivo paper-grade (es. "su 39.247 stage2 records, il resolver ha overridden 6.123 kind_effective; di questi, X risultati confirmed by ChEBI role, Y by MeSH branch, Z unvalidatable").
