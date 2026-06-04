# Spec — Stadio 2 su condizioni di design deduplicate (FASE F4 / opzione C)

> Design tecnico per ADR-0020. Driven by finding 2026-06-01.
> Stato: draft, in attesa gate utente sulle decisioni aperte (D1-D4).

## Obiettivo

Far vedere allo Stadio 2 l'**intero disegno** di uno studio in un singolo
contesto LLM, senza chunking dei campioni, comprimendo lo studio alle sue
**condizioni di design distinte** (deduplica per firma sui Stage 1 facts) ed
espandendo l'output su tutti i campioni.

## Pipeline proposta

```
Stage1 master F2 (508k, per-campione)
   │  (build input v3, locale)
   ├─ per studio: signature(sample_facts) per ogni campione
   ├─ group-by signature → condizioni distinte
   │     ognuna: { condition_id, repr_sample_facts, n_replicates, member_sample_ids }
   └─ 1 record per studio: { record_id=series, series_id, conditions:[...], study_summary }
            │  (Stadio 2 LLM, DGX — niente chunking)
            ├─ replicate_groups (su condizioni) + comparisons + comparability_anchor
            │  (collect + expand, locale)
            └─ espandi: ogni gruppo/condizione → tutti i member_sample_ids
                  → master Stadio 2 v3 (1 record per studio)
                        → F4 (Stadio 3) → F5 (Stadio 4)
```

## Componenti

### 1. `design_signature(sample_facts) -> character(1)`  [D1 — DECISA 2026-06-04]

Chiave canonica deterministica sui campi Stage 1 della **sola condizione
sperimentale**. Campi inclusi (decisione utente: esclusa l'identità individuale
— donor_id, age, sex, ancestry):

- `cell_context`: tissue, cell_type_or_line_raw, context_kind, cell_state,
  developmental_stage, subcellular_fraction, engineered_modifications (set),
  sort_markers (set), co_culture_partners (set)
- `disease_state`: status, term_raw (+ mesh_id_candidate)
- `perturbations` (lista, ordinata canonicamente): per ciascuna — kind,
  agent_normalized (type, id_database, id), dose (value_numeric+unit, fallback
  value_raw), duration (value_hours, fallback value_raw), phase,
  is_zero_timepoint, is_negative_control
- `patient_metadata` **design-rilevanti**: condition, clinical_response, stage,
  survival_group, visit_or_timepoint
  - **ESCLUSI** (identità individuale, non assi di disegno): donor_id, age, sex,
    ancestry — *salvo* che lo studio li usi come fattore (vedi D1: rischio).

Proprietà: NA-aware, ordine-insensibile su set/liste, JSON canonico sort_keys.
Implementazione R pura + TDD (fixture: campioni replicati → stessa firma;
campioni con dose diversa → firme diverse; ecc.).

### 2. Build input v3 (`analysis/...-stage2-build-input-v3.R`)

Per ogni `series_id`:
1. firma di ogni campione,
2. group-by firma → condizioni; per ciascuna scegli un **rappresentante**
   deterministico (es. primo GSM alfabetico) + `n_replicates` + `member_sample_ids`,
3. emetti **un record/studio**: `conditions: [{condition_id, sample_facts(repr),
   n_replicates, member_sample_ids}]`.
4. **Coda D2**: studi con #condizioni > soglia (es. 200) → strategia da decidere.

Niente shuffle, niente split. Output: `archs4-human-stage2-input-v3.jsonl`,
1 riga per studio.

### 3. Cambio prompt Stadio 2  [D4 — gate utente]

Oggi (`inst/dgx/python/prompts.py:56-93`): `samples:` + JSON dei sample_facts.
Opzione raccomandata (minima churn): **rappresentante + conteggio**. La lista
`samples:` contiene una voce per condizione (sample_facts del rappresentante)
con due campi extra: `n_replicates`, `geo_accession` = id rappresentante. Una
riga di istruzione nel system prompt: "ogni voce rappresenta n_replicates
campioni biologicamente equivalenti; raggruppa e confronta le voci". L'LLM
emette `replicate_groups`/`comparisons` sui rappresentanti.

Vincolo: cambio prompt **minimo e gated**; prompt invariato altrove. Estrazione
verbatim + diff + OK utente prima di applicare (come D1a Stadio 1).

### 4. Espansione (collect, locale)

Per ogni gruppo emesso dall'LLM: i `sample_ids` (rappresentanti) → sostituiti
con la union dei `member_sample_ids` delle condizioni corrispondenti. Output:
master Stadio 2 v3, schema identico all'attuale `study_design.stage2.v2`, **1
record per studio**. A questo punto F4/F5 girano senza riassemblaggio.

### 5. Re-run + validazione

- **Smoke gate**: i 72 studi del gold design-aware → schema 100% + binary
  accuracy ≥ baseline (94%). Confronto design: studi non-chunked devono restare
  ~identici; studi chunked devono diventare coerenti (1 record, confronti
  cross-fetta ricomposti).
- **Fullrun** DGX (gate utente separato, validate-before-fullrun).

## Rischi

- **Firma troppo grossolana** → collassa condizioni distinte (false merge,
  disegno errato). Mitigazione: includere tutti gli assi di disegno; validare su
  gold; l'LLM può comunque ri-separare se i facts del rappresentante lo indicano.
- **Firma troppo fine** → poca compressione (coda D2). Mitigazione: escludere
  identità individuali; D2.
- **Dipendenza da Stage 1**: la firma è buona quanto la cattura degli assi da
  parte di Stage 1. *Non* è una regressione: l'input chunked attuale usa gli
  stessi facts.
- **Cambio prompt** sposta il comportamento LLM → re-validazione su gold (gate).

## Decisioni aperte (gate utente)

| # | Decisione | Stato |
|---|---|---|
| D1 | Campi della firma (design vs identità) | **DECISA 2026-06-04**: sola condizione sperimentale (§1); escluse donor/age/sex/ancestry |
| D2 | Coda >soglia condizioni (max 2432) | **DECISA 2026-06-04**: chunking *per-condizione* coerente + broadcast controlli/baseline in ogni blocco; soglia (token vs 32k XL) misurata empiricamente in build v3; ~9 giganti ispezionati uno per uno |
| D3 | Scope re-run | **DECISA 2026-06-04**: **tutti** i 24.394 studi (uniformità config) |
| D4 | Forma cambio prompt | **DECISA 2026-06-04**: rappresentante + `n_replicates` (minima churn); verbatim+diff+OK resta gated |
| — | Sorte `.reassemble_stage2_chunks` | **DECISA 2026-06-04**: sostituire con guard fail-loud (errore su `series_id` duplicato); completeness guard per-studio resta |

## Fuori scope

- Stadio 1 (invariato). Master F2 valido.
- `.reassemble_stage2_chunks` (F4 namespacing): superato, da shelvare.
