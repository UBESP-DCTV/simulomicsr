# P3 — Stadio 2 study_design + comparability_anchor (versione leggibile)

Companion al plan dettagliato `2026-05-02-p3-stadio2-study-design-plan.md`.
Qui solo cosa ti riguarda: cosa otterrai, dove devi decidere, dove la sessione si fermerà ad aspettarti.

## Cosa è P3 in una frase

P2 ha consegnato la **classificazione per-sample**: dato un GSM, ne estrae un record `sample_facts.stage1.v3`. P3 fa il salto di livello: dato un GSE (con tutti i suoi sample_facts già validati + un summary GEO scaricato live), ricostruisce il **design dello studio** — chi è treated, chi è control, quali sono le coppie di confronto — e calcola il **`comparability_anchor` v3** (chiave canonica deterministica a 13 segmenti) per ogni comparison. È lo Stadio che permette il salto a meta-analisi cross-studio.

## Cosa otterrai a fine P3

- `inst/schemas/study_design.stage2.v1.json` — schema strict per OpenAI Structured Outputs, vocab `design_kind` (10 valori) + `design_role` (13 valori) presi dalla spec v5 §4.1-§4.2.
- `classify_study()` — funzione esportata che dato un GSE produce un record `study_design.stage2.v1` validato. Cache automatica via P1.
- `fetch_study_summary()` — wrapper su `rentrez::entrez_summary(db="gds")` con cache filesystem JSONL. Niente hammering NCBI: ogni GSE chiamato una volta sola.
- `make_anchor()` — R puro, deterministico, no LLM: 13 segmenti `kind|agent|variant|dose|duration|phase|cell_id|context|state|subcell|tissue|disease|engineered`. Implementa le regole R8 (mediated_effect → l'inducente Dox sparisce, il target SOX17 entra), R9 (variant), R24 (phase washout), R25 (subcellular default whole_cell), R31 (cell_state default proliferating).
- `make_inducer_log()` — audit log per i sample con `mediated_effect != null`. Cattura ciò che `make_anchor()` perde di proposito.
- Pipeline `analysis/_targets.R` estesa: `study_summaries` (fetch GEO per unique GSE) → `study_designs_raw` (LLM call per GSE) → `study_designs_validated`/`invalid` (schema partition) → **`comparisons_table`** (flat table con anchor precalcolato — pronto per consumo da Stadio 3-5).
- Vignette `stage2-classify.Rmd` con esempio end-to-end (offline-buildable).
- Suite di test (~25 nuovi expectations) + smoke E2E reale gated `OPENAI_API_KEY`.

A fine P3 sai: il prompt Stadio 2 funziona contro gpt-5.5, l'anchor v3 è calcolato correttamente sui sample reali, la `comparisons_table` è popolata su ~30-40 GSE del dev set P2. **Non sai ancora**: quanto bene fa rispetto a un gold design-aware, e quanto batte (o no) RummaGEO. Quello è P3.5.

## Quello su cui devi decidere

### Adesso, prima di lanciare l'esecuzione

**1. Modello di default = `gpt-5.5`.** Per Stadio 2 la spec §5.3.1 lo ha dichiarato fin dall'inizio (è il default per il Stadio "ricco di ragionamento sul design"). Il P2 hotfix `temperature` opzionale è già in master. Confermi `gpt-5.5` o vuoi sperimentare con un altro modello?

**2. Costo del run su ~30-40 GSE del dev set P2.** Stima larga (system ~3000 token, user ~3000-8000 a seconda di quanti GSM ha il GSE, output ~1500-3000): **~$0.50-1.50 totale** per il run completo. Sotto $5 anche se incappiamo in iterazioni. Cumulativo P1+P2+P3 stimato ~$5-7 sul tetto di $500 (ampi margini per P3.5 + P4).

**3. Fixture mini Stadio 2 (Task 10).** Servono 3 GSE rappresentativi (1 time_course, 1 treatment_vs_vehicle, 1 knockdown_panel). Il plan dice di sceglierli interattivamente dal dev set P2 (i 3 PLACEHOLDER nello script `data-raw/build-stage2-fixtures.R` sono intenzionali). Il candidato canonico per time_course è `GSE41166` (VEGF HUVEC, già usato come esempio nella spec §4); per gli altri due lo scegli tu durante Step 10.1, oppure lascio scegliere allo subagent in base alla composizione del dev set.

**4. `entrez_summary(db="gds")` e `overall_design`.** L'EUtils API per `gds` espone `title` e `summary` direttamente, ma `overall_design` richiederebbe un secondo call a `entrez_fetch(rettype="xml")` con parsing custom. Il plan accetta `NA` per `overall_design` per ora — lo Stadio 2 prompt funziona con `summary` come fonte primaria. Se a fine P3 vediamo che il prompt soffre per questa lacuna, aggiungiamo il parsing XML come Task supplementare. Vuoi questo trade-off oppure preferisci che pianifichi il parsing XML fin da subito (costo: +1 task)?

### Più avanti, quando arriverà il momento

**5. Soglie di accettabilità a fine Task 13 (run reale)** sui ~30-40 GSE del dev set:
- `validity_rate > 0.90` (atteso ~1.0 con Structured Outputs strict; se scende sotto, schema bug o GSE fuori scope tipo single-cell o ChIP).
- `confidence median > 0.6` sui design ricostruiti.
- `design_kind != "unclear"` su almeno 70% dei GSE (sotto questa soglia il prompt non sta capendo il design — iterazione obbligatoria).
- `comparisons_table` non-vuota: almeno N comparisons cross-GSE con anchor ben formato (13 segmenti) per N ≥ 20.

Se sotto soglia, c'è un giro di iterazione sul prompt (system più dettagliato) o sui few-shot (la spec §3 ne ha 1, ne aggiungiamo 2 per copertura). È il pattern dei 4 dry-run di v5 — replicato qui in piccolo.

**6. Truncation policy.** Il plan **non implementa** truncation per GSE con > 50 sample (spec §11). Il dev set P2 ha 100 sample distribuiti su ~30-40 GSE → media 2-3 sample/GSE → no truncation needed. La truncation policy reale serve per il run massivo (P4 — alcuni GSE ARCHS4 hanno 200-500 sample). La aggiungiamo come ADR + Task in P4 quando serve davvero.

**7. Modello arbitro per `confidence < 0.5`.** Spec §5.3.1 prevede re-process con gpt-5.5 più aggressivo per GSE problematici. P3 **non lo implementa** — è P3.5 (insieme alla baseline eval). Per ora i GSE con bassa confidence vanno in `study_designs_validated` con il flag visibile per ispezione manuale.

### Decisioni rinviate non bloccanti per P3

- **ADR-0003** — rinome pacchetto (sempre aperto, non blocca).
- **Vocabolari extra** (Cellosaurus, DrugBank, ChEMBL, MeSH) — P3 usa quello che è in `sample_facts` di Stadio 1; nessun nuovo lookup R deterministico.
- **Integrazione MetaHQ** — ADR-0006: opzionale come upstream per `normalize_tissue()`. Se il prompt Stadio 2 confonde tissue normalization, integriamo a metà P3; altrimenti rimandiamo.
- **Migrazione `ellmer`** — sempre P3+ come ADR separato (non blocca).
- **Batch API OpenAI** per Stadio 2 — non serve a 30-40 GSE; sarà P4.

## Cosa P3 NON fa (per evitare confusione)

- Non costruisce il **gold design-aware** su 200-300 sample — P3.5.
- Non esegue il **benchmark vs RummaGEO** — P3.5 (deliverable integrale, ADR-0006).
- Non gira sui 700k+ sample ARCHS4 — P4 (run massivo via Batch API; richiede server-switch ADR-0005).
- Non implementa **truncation policy** né **chunking** per GSE grandi — P4.
- Non implementa il **modello arbitro** per re-processing GSE con `confidence < 0.5` — P3.5.
- Non scarica `overall_design` dall'XML EUtils — P3 accetta `NA` (vedi punto 4 sopra).
- Non implementa Stadio 3-5 (clustering anchor, DE per studio, meta-analisi REM) — P4-P5.
- Non aggiunge nuovi vocabolari di lookup deterministico (Cellosaurus, DrugBank, ecc.) — plan separato.

## Stima di tempo

Esecuzione subagent-driven con review tra task, 17 task. Stima realistica: **3-4 ore walltime** se il prompt regge al primo colpo; **mezza giornata - giornata intera** se Task 11 (smoke E2E reale) o Task 13 (run su 30-40 GSE) rivelano che il prompt va raffinato — è il caso buono, perché significa che hai numeri freschi.

Se invece tutto fila: a fine giornata hai `comparisons_table` popolata, anchor v3 calcolati su ~50-100 comparisons cross-studio, branch `p3-stage2` mergeato e tagged.

## Dove la sessione si fermerà ad aspettarti

Quattro stop espliciti pre-pianificati:

- **Step 10.1** (scelta dei 3 GSE per le fixture): ti mostro la composizione del dev set per series_id e ti chiedo conferma sui 3 GSE scelti (default suggerito: GSE41166 per time_course, due da ispezionare).
- **Dopo Task 11** (smoke E2E reale su gpt-5.5): se la chiamata fallisce o il design ricostruito è palesemente sbagliato, mi fermo. Non procedo finché non capiamo se è un problema di prompt o un GSE patologico.
- **Prima di Step 13.2** (run vero sui 30-40 GSE): ti chiedo "lancio?" — è il punto di consumo serio di token (~$0.50-1.50). Senza la tua conferma, non procedo.
- **Dopo Task 14** (`comparisons_table` popolata): ti mostro `table(comparisons_table$design_kind)` + `length(unique(comparability_anchor))` + alcuni anchor d'esempio per QC visiva. Se la distribuzione è sbilanciata o gli anchor sono malformati, c'è un'iterazione di prompt + `make_anchor()` (i due possono interagire: un design_role sbagliato cambia il segmento 12 dell'anchor).

Per il resto la sessione fila senza interruzioni: tutti gli altri task sono offline (test mockati, schema validation, R puro per `make_anchor()`).

## Cosa P3 lascia pronto per P3.5

- `study_designs_validated` su 30-40 GSE: input pronto per costruire il **gold design-aware** in P3.5 (esperto rivede 200-300 sample stratificati per `design_kind`).
- `comparisons_table` con anchor v3: input pronto per il **benchmark RummaGEO** in P3.5 (matrice di confusione + anchor coverage + pooling REM vs gene-set overlap; vedi ADR-0006 §"Deliverable integrale").
- Cache LLM Stadio 2 su disco: re-run zero-cost se la metrica eval ricalcola contro fixture identiche.
- Tag `p3-stage2-complete` su master.

P3.5 sarà il piano successivo — brainstorming + plan separato (probabilmente più piccolo: 8-10 task tra `R/eval-rummageo.R`, `R/eval-design-gold.R`, target eval, report Quarto).
