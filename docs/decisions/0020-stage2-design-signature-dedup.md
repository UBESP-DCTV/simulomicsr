# ADR-0020 — Stadio 2 su condizioni di design deduplicate (niente chunking)

- **Status**: Proposed (2026-06-02); D1-D4 + namespacing decise 2026-06-04 (sessione 13)
- **Contesto RED ALERT**: FASE F4. Supera la strategia di chunking cs50 dello
  Stadio 2 (ADR-0010/0013) come *modalità di input*, non come default di sampling.
- **Driven by**: finding `docs/findings/2026-06-01-stage3-stage4-chunked-study-sample-resolution-bug.md`.

## Contesto

Lo Stadio 2 (study-level) inferisce il disegno sperimentale di uno studio:
`replicate_groups` (chi è replicato di chi) + `comparisons` (trattato vs
controllo, con `comparability_anchor`). Per farlo deve vedere i campioni di uno
studio **insieme** — la nozione di "controllo" esiste solo in relazione agli
altri campioni.

Per il limite di contesto del modello (Mistral-Small-3.2), lo Stadio 2 input
spezza ogni studio con >50 campioni in chunk da 50, **shufflando** i campioni
prima del taglio (`analysis/p4-beta-stage2-build-input.R:132-145`). Ogni chunk
diventa un record LLM indipendente.

**Conseguenza (finding 2026-06-01)**: l'LLM vede solo una fetta casuale dello
studio per chunk → definisce gruppi/confronti per-fetta, in modo incoerente:
- group_id non byte-stabili tra chunk (`GSE..__X` vs `GSE.._X`),
- 639 group_id con `primary_role` in conflitto tra chunk,
- **comparison cross-chunk**: i due bracci di un confronto finiscono in chunk
  diversi (300 studi; ~435 confronti REM eligible-dopo-ricostruzione persi),
- a valle, `record_id = series__suffix` collide e `.index_stage2_master`
  (per series, last-wins) perde i chunk non-ultimi → **35% dei campioni F3
  (55% nel run β già prodotto) misrisolti nel pooling DE**.

Nessun riassemblaggio meccanico a valle ricostruisce in modo affidabile un
output così frammentato (i tentativi namespacing/union sono entrambi
inaccettabili: il primo perde i confronti cross-chunk, il secondo richiede
matching fuzzy + risoluzione di conflitti — assumption-heavy).

## Decisione

Eliminare il chunking dei campioni dallo Stadio 2. Dare all'LLM le **condizioni
di design distinte** dello studio, deduplicate per **firma** sui Stage 1 facts,
e poi **espandere** l'assegnazione su tutti i campioni membri.

Razionale quantitativo (sonda sui 1.659 studi chunked F3): condizioni distinte
per studio **mediana 13**, p90 56, **≤100 nel 96,3%**, ≤400 nel 99,5%. Cioè uno
studio da 5.000 campioni ha tipicamente ~13 condizioni reali (replicati): l'intero
disegno entra in un singolo contesto LLM senza chunking.

Effetto collaterale positivo: la deduplica **pre-calcola i replicate group** (una
firma = un gruppo di replicati), riducendo il compito dell'LLM a (a) eventuale
merge di condizioni quasi-identiche, (b) assegnazione ruolo, (c) definizione
confronti — su pochi elementi invece che migliaia. Più robusto, non solo più
piccolo.

Non tocca lo Stadio 1 (per-campione, non frammentato): il master F2 (508.037)
resta valido. C ridisegna **solo** l'input Stadio 2 + re-run (rifà F3), poi F4.

## Conseguenze

- **Re-run Stadio 2** su DGX con il nuovo input (rifà F3 → master v3, **un record
  per studio**, niente chunking). Atteso più veloce/economico del run F3 attuale
  (28.567 record chunked, molti XL → ~24.394 record compatti).
- **`.reassemble_stage2_chunks`** (fix namespacing F4) diventa **superato**: con
  un record per studio è un no-op idempotente. Da shelvare o tenere come rete
  difensiva (col crash fixato), non più "il fix".
- **Cambio prompt Stadio 2** (gate utente esplicito, come per Stadio 1): minimo —
  ogni voce di `samples:` diventa una condizione rappresentativa con
  `n_replicates` + `member_sample_ids`. Vedi spec D4.
- **Re-validazione** sul gold design-aware 72 studi (smoke gate) prima del
  fullrun.
- I risultati `96c43acb` + Layer B `56b911e6` restano **non affidabili** come
  baseline (già marcati dal finding).

## Decisioni

- **D1 — DECISA (2026-06-04)**: la firma è la **sola condizione sperimentale**.
  INCLUDE: `cell_context` (tissue, cell_type_or_line_raw, context_kind,
  cell_state, developmental_stage, subcellular_fraction,
  engineered_modifications, sort_markers, co_culture_partners), `disease_state`
  (status, term_raw, mesh_id_candidate), `perturbations` (kind, agent type/db/id,
  dose, duration, phase, is_zero_timepoint, is_negative_control),
  `patient_metadata` sperimentali (condition, clinical_response, stage,
  survival_group, visit_or_timepoint). **ESCLUDE l'identità individuale**:
  donor_id, age, sex, ancestry_or_population, ancestry_admixture.

### Decisioni residue — DECISE 2026-06-04 (sessione 13)

- **D2 — DECISA**: gestione della coda di studi con #condizioni che eccede il
  contesto LLM (in produzione `max_model_len` tier XL = 32k token; ~100 condizioni
  compatte entrano → copre il 96,3% degli studi chunked; sopra ≈3,7%, max 2.432).
  Politica: **chunking per-condizione coerente** per i soli studi-coda, con i
  controlli/baseline (`is_negative_control` / `is_zero_timepoint`) **ripetuti
  (broadcast) in ogni blocco**, così i confronti trattato-vs-controllo
  sopravvivono entro chunk. La **soglia esatta** va misurata empiricamente sul
  peso reale (token) di un record-condizione durante il build input v3, non
  indovinata. I ~9 studi giganti (screen tipo LINCS) vanno ispezionati uno per uno.
- **D3 — DECISA**: re-run su **tutti i 24.394 studi** (uniformità config — anche i
  non-chunked vedono il prompt nuovo, ri-eseguirli evita un confounder
  metodologico). Coerente con `feedback_pipeline_config_uniformity`.
- **D4 — DECISA**: forma del cambio prompt = **rappresentante + `n_replicates`**
  (minima churn). L'estrazione verbatim + diff + OK utente resta uno step gated
  successivo prima di applicare.
- **Sorte `.reassemble_stage2_chunks` — DECISA**: **sostituire con un guard
  fail-loud**. La funzione namespacing (committata in `c940cde`, agganciata a
  `R/stage3-build.R:55` + `R/stage4-build.R:151`) è superata da C; come "rete
  difensiva" sarebbe dannosa perché, se mai girasse su un master chunked,
  produrrebbe il riassemblaggio per-namespacing — che questo stesso ADR dichiara
  scientificamente inaccettabile (perde i confronti cross-chunk) — **in silenzio**,
  con output schema-valido. La sostituiamo con un controllo di invariante che
  **fallisce rumorosamente** se trova `series_id` duplicati (input chunked
  inatteso). Il completeness guard per-studio (`.apply_stage2_completeness_by_series`
  + `.build_stage2_input_lookup`) è indipendente e **resta** (da verificare la
  non-dipendenza da reassemble in fase di implementazione).

## Alternative scartate

- **Namespacing per-chunk** (riassemblaggio meccanico): perde i confronti REM
  cross-chunk (~435+). Scientificamente inaccettabile.
- **Union fuzzy per group_id**: matching non affidabile (id non byte-stabili) +
  risoluzione di 639 conflitti di ruolo → assumption-heavy, fragile.
- **Lasciare il chunking + filtro post-hoc**: non risolve la frammentazione del
  disegno alla radice.
