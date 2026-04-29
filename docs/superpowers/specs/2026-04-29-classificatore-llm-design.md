# Design — Classificatore LLM meta-analytics-aware (Stadio 2 della pipeline simulomicsr)

- **Data:** 2026-04-29
- **Stato:** Draft (in attesa di review utente)
- **Ambito:** Stadio 2 della pipeline complessiva (vedi ADR-0002 e visione progetto)
- **ADR collegati:** ADR-0001 (tracking), ADR-0002 (struttura repo)
- **Skill upstream:** brainstorming
- **Skill downstream attesa:** writing-plans

## 1. Obiettivo

Trasformare la stringa testuale di metadati GEO di ciascun sample RNAseq in una rappresentazione strutturata che renda *decidibili*, in modo automatizzabile a valle:

- quali sample dentro lo stesso studio sono replicate biologiche della stessa condizione (per `DESeq2`/`limma` per-studio);
- quali coppie di gruppi dentro lo studio costituiscono un confronto biologicamente sensato (treated-vs-control);
- quali confronti cross-studio condividono *il medesimo* intervento e contesto (per `metafor` cross-studio).

Il classificatore NON produce direttamente un'etichetta `treated/control`. Quel binario è un output derivato a valle, dove e quando serve.

## 2. Architettura: ibrida a due stadi

```
sample text (GEO metadata string)              study summary GEO (title + summary + design_field)
            │                                                      │
            ▼                                                      ▼
   ┌──────────────────┐                                ┌─────────────────────┐
   │  Stadio 1        │   (parallelo, idempotente)     │                     │
   │  sample-level    │   modello: Claude Haiku 4.5    │                     │
   │  estrazione      │   1 chiamata per GSM           │                     │
   │  fattuale        │                                │                     │
   └────────┬─────────┘                                │                     │
            │ JSON sample_facts (per GSM)              │                     │
            ▼                                          ▼                     │
   ┌────────────────────────────────────────────────────────┐                │
   │  Stadio 2  — study-level                                │                │
   │  modello: Claude Sonnet 4.6                            │                │
   │  input: tabella sample_facts del GSE + study summary    │                │
   │  output:                                               │                │
   │     - design_summary, design_kind, factors             │                │
   │     - replicate_groups (con sample_ids)                │                │
   │     - design_role per sample                           │                │
   │     - comparisons (lista di contrasti suggeriti        │                │
   │       con comparability_anchor canonicalizzato)         │                │
   └────────────────┬───────────────────────────────────────┘                │
                    │                                                        │
                    ▼                                                        │
            Tabella canonica  ──────────────►  pronto per stadio 3           │
            sample × study × condition         (raggruppamento cross-studio)
```

Vincoli di progettazione che giustificano la separazione in due stadi:

- Lo Stadio 1 è *fattuale* (estrai cosa è scritto nella stringa) → veloce, cacheable, parallelo, prompt piccolo, schema rigido.
- Lo Stadio 2 è *interpretativo del design* (relazione fra sample dentro lo studio) → richiede contesto allargato e ragionamento; ma riceve dati già strutturati, non testo grezzo, quindi il context window basta.
- I due stadi falliscono in modo diverso e si validano in modo diverso (vedi §6).

## 3. Schema dati — Stadio 1 (sample_facts)

Output JSON per ogni GSM. Campi `null` quando il dato non è ricavabile dalla stringa di metadati. Vocabolari controllati segnalati con asterisco; gli altri campi sono stringhe libere ma normalizzate (lowercase, trim).

```json
{
  "geo_accession": "GSM1009635",
  "series_id": "GSE41166",
  "organism": "Homo sapiens",                              // free text, canonicalizzato a binomio standard
  "cell_context": {
    "cell_type_or_line_raw": "Primary Human Umbilical Vein Endothelial Cells",
    "cell_line_cellosaurus_candidate": null,               // ID Cellosaurus se identificabile, altrimenti null
    "tissue": "vascular endothelium",                      // free text
    "passage_or_state": "P3-6"
  },
  "perturbation": {
    "kind": "cytokine_stimulation",                        // *enum: vedi §3.1
    "agent_raw": "VEGF",
    "agent_normalized": {
      "type": "gene_or_protein",                           // *enum: vedi §3.2
      "id_database": "HGNC",                               // *enum: HGNC | UniProt | DrugBank | ChEMBL | MeSH | CHEBI | null
      "id": "HGNC:12680",                                  // null se non risolvibile dalla sola stringa
      "preferred_name": "VEGFA"
    },
    "dose": {                                              // null se non riportato
      "value_raw": null,
      "value_numeric": null,
      "unit": null
    },
    "duration": {                                          // null se non riportato
      "value_raw": "0h",
      "value_hours": 0,
      "is_zero_timepoint": true                            // flag esplicito: t=0 in time-course
    }
  },
  "extraction": {
    "schema_version": "stage1.v1",
    "model": "claude-haiku-4-5",
    "confidence": 0.78,                                    // 0..1
    "ambiguity_flags": [                                   // *enum
      "missing_dose",
      "time_zero_timepoint"
    ],
    "raw_input_hash": "sha256:..."                         // dello string GEO usato in input
  }
}
```

### 3.1 Vocabolario `perturbation.kind`

- `small_molecule` — drug/compound (es. doxorubicin, dmso, tamoxifen)
- `genetic_knockdown` — siRNA, shRNA, antisense
- `genetic_knockout` — CRISPR, gene deletion
- `genetic_overexpression` — transgene, vector overexpression
- `cytokine_stimulation` — recombinant proteins (VEGF, TNF, IL6, EGF, …)
- `pathogen_exposure` — viral/bacterial infection
- `environmental` — hypoxia, starvation, irradiation, heat shock
- `disease_vs_normal` — sample da paziente o tessuto patologico vs sano (no intervention attiva)
- `differentiation` — protocollo di differenziamento cellulare
- `mechanical_or_physical` — strain, shear, electroporation
- `none` — nessuna perturbazione esplicita riportata
- `unclear` — riportato qualcosa di non riconducibile a nessun kind sopra

### 3.2 Vocabolario `agent_normalized.type`

- `gene_or_protein` (HGNC / UniProt) — per knockdown, knockout, overexpression, cytokine, recombinant protein
- `small_molecule` (DrugBank / ChEMBL / CHEBI) — drug, compound
- `vehicle` — DMSO, PBS, water, ethanol, mock
- `disease_term` (MeSH) — quando `kind=disease_vs_normal`
- `none`
- `other`

### 3.3 Vocabolario `ambiguity_flags`

`missing_dose`, `missing_duration`, `time_zero_timepoint`, `multi_factor_in_string`, `compound_unmapped`, `cell_line_ambiguous`, `vehicle_only`, `description_too_short`, `mixed_organism_terms`, `study_specific_jargon`.

## 4. Schema dati — Stadio 2 (study_design)

Un oggetto JSON per ogni GSE, prodotto dall'LLM dopo aver letto: (a) lista dei `sample_facts` dello stadio 1, (b) `study_title` + `study_summary` + `study_overall_design` da GEO API per quel GSE.

```json
{
  "series_id": "GSE41166",
  "design_summary": "Time-course of VEGF stimulation in primary HUVEC ...",
  "design_kind": "time_course",                            // *enum: vedi §4.1
  "factors": [                                             // dimensioni manipolate nel design
    {"name": "VEGF stimulation", "type": "stimulation", "levels": ["unstimulated", "VEGF"]},
    {"name": "time", "type": "time", "levels": ["0h", "1h", "6h", "24h"]}
  ],
  "replicate_groups": [
    {
      "group_id": "VEGF_1h",
      "label_human": "HUVEC + VEGF, 1h",
      "sample_ids": ["GSM1009636", "GSM1009637", "GSM1009638"],
      "design_role": "perturbed",                          // *enum: vedi §4.2
      "factor_levels": {"VEGF stimulation": "VEGF", "time": "1h"}
    },
    {
      "group_id": "baseline_t0",
      "label_human": "HUVEC, t=0h baseline",
      "sample_ids": ["GSM1009635"],
      "design_role": "baseline_t0",
      "factor_levels": {"VEGF stimulation": "VEGF", "time": "0h"}
    }
  ],
  "comparisons": [
    {
      "comparison_id": "GSE41166__VEGF_1h_vs_baseline",
      "treated_group": "VEGF_1h",
      "control_group": "baseline_t0",
      "varying_factor": "time",
      "fixed_factors": {"VEGF stimulation": "VEGF", "cell": "HUVEC"},
      "comparability_anchor": "cytokine_stim|HGNC:12680|nodose|1h|HUVEC|vascular_endothelium",
      "anchor_version": "v1",
      "study_internal_score": 0.84                         // 0..1: qualità del confronto interno
    }
  ],
  "extraction": {
    "schema_version": "stage2.v1",
    "model": "claude-sonnet-4-6",
    "confidence": 0.81,
    "ambiguity_flags": ["nonstandard_baseline_choice"],
    "input_sample_count": 12,
    "input_truncated": false
  }
}
```

### 4.1 Vocabolario `design_kind`

- `case_control_disease` — sample da pazienti/tessuti patologici vs controlli sani
- `treatment_vs_vehicle` — drug + vehicle control
- `treatment_vs_untreated` — drug senza vehicle control esplicito
- `time_course` — stimolo + serie temporale
- `dose_response` — stesso compound, dosi multiple
- `knockdown_panel` — più target gene knockdown vs siNT/siCtrl
- `factorial` — interaction design (es. drug × cell line)
- `differentiation_course` — protocollo di differenziamento
- `multi_arm_treatment` — più trattamenti distinti vs un comune control
- `unclear` — design non ricostruibile

### 4.2 Vocabolario `design_role`

- `perturbed` — riceve trattamento/perturbazione attiva di interesse
- `vehicle_control` — solo veicolo/solvente (DMSO, PBS, water, mock)
- `untreated_control` — nessun trattamento (no vehicle dichiarato)
- `negative_genetic_control` — siNT, siNeg, scrambled, empty vector, non-targeting
- `positive_control` — controllo positivo del saggio (raro nei design RNAseq)
- `baseline_t0` — campione a tempo zero in time-course
- `case` — sample patologico in disegno disease vs normal
- `comparison` — sample sano/normale in disegno disease vs normal
- `secondary_arm` — braccio di trattamento alternativo (non quello di interesse principale)
- `excluded` — sample che il LLM segnala come inadatto al design (QC fallito, outlier dichiarato)
- `unclear` — ruolo non ricostruibile

### 4.3 Definizione di `comparability_anchor`

Stringa canonica deterministica per cross-studio matching, prodotta da una funzione R pura `make_anchor(stage1_facts, stage2_role)` (NON dall'LLM). Schema concatenato con `|`:

```
{perturbation.kind}|{agent_normalized.id_or_preferred_name}|{dose_canonical}|{duration_hours_or_NA}|{cell_canonical}|{tissue_canonical}
```

Esempi:
- `cytokine_stim|HGNC:12680|nodose|1h|HUVEC|vascular_endothelium`
- `small_molecule|DB00997|10nM|24h|MCF7|breast`
- `genetic_knockdown|HGNC:1001|nodose|72h|OCI-LY1|lymphoid`

L'anchor è **versionato** (`anchor_version`) per poter cambiare la regola senza dover re-classificare i sample (basta ricalcolare la funzione deterministica).

## 5. Pipeline tecnica (R + targets)

### 5.1 Modulo libreria (`R/`)

Funzioni pure, testabili, distribuibili nel pacchetto:

- `R/llm-stage1.R` — costruzione prompt stadio 1, parsing risposta, validazione schema
- `R/llm-stage2.R` — costruzione prompt stadio 2, parsing, validazione schema
- `R/llm-client.R` — wrapper sottile su `httr2` per chiamate Anthropic API (no dipendenze pesanti); supporta prompt caching e batch API
- `R/anchors.R` — `make_anchor()`, normalizzazioni (dose, duration, cell line)
- `R/cache.R` — cache locale per chiamate LLM (JSONL append-only + indice SQLite per query veloce)
- `R/geo-fetch.R` — recupero `study_title`, `study_summary`, `study_overall_design` per GSE; cacheable
- `R/validate.R` — validatori JSON Schema (con `jsonvalidate`) per output stadio 1 e 2
- `R/eval-metrics.R` — metriche di accuratezza vs gold standard (xlsx)

### 5.2 Pipeline applicativa (`analysis/_targets.R`)

Target principali (in ordine di dipendenza):

1. `samples_input` — lettura `data-raw/relevant_sample_classified.xlsx` o sorgente più ampia in futuro
2. `geo_studies_meta` — fetch metadati di studio per ciascun GSE univoco (cacheable, idempotente per GSE)
3. `sample_facts` — Stadio 1 LLM, una chiamata per GSM, con cache su disco. Parallelo via `tar_target(pattern = map(samples_input))` o batch API
4. `sample_facts_validated` — schema validation; sample che falliscono validazione vanno a `sample_facts_invalid` per ispezione manuale
5. `study_designs` — Stadio 2 LLM, una chiamata per GSE che ha ≥ 2 `sample_facts_validated`. Cache per GSE
6. `study_designs_validated` — schema validation
7. `comparisons_table` — flatten di tutte le `comparisons` cross-GSE, una riga per coppia treated_group/control_group, con `comparability_anchor` precalcolato
8. `eval_against_gold` — confronto contro `trtctr_EP` del xlsx, metriche aggregate e per-strato
9. `eval_report` — Quarto report con confusion matrix, calibrazione confidence, casi di disaccordo

### 5.3 Modelli e costi

- **Stadio 1: Claude Haiku 4.5.** Throughput alto, schema rigido, output breve. Prompt caching aggressivo: il system prompt + lo schema JSON + i few-shot example sono cachati (TTL 5 min). Quando possibile, **batch API** (sconto 50%) per il run massivo.
- **Stadio 2: Claude Sonnet 4.6.** Ragionamento sul design, schema più ricco, contesto dello studio. Prompt caching su system + schema + esempi. Online (non batch) perché lo stadio 2 viene tipicamente lanciato a follow-up dello stadio 1 e il volume è ~10× più piccolo.
- **Opus 4.7** non viene usato come default ma resta disponibile per: re-processing di GSE con `extraction.confidence < 0.5` dello stadio 2; arbitraggio su sample contesi durante la valutazione.
- **Locale (es. Llama 3.1 8B/70B)** è considerato out of scope per questo design ma non escluso: il `R/llm-client.R` dovrà essere astratto sui provider per lasciare la porta aperta.

Stima costi indicativa (da raffinare): ~$200-500 per il run completo sui 130k sample del xlsx, con prompt caching e batch API. **Vincolo finale di budget da confermare con l'utente.**

### 5.4 Idempotenza e cache

- Cache stadio 1: chiave = `sha256(schema_version_stage1 + sample_string)`. Storage: `analysis/cache/stage1.jsonl` + index SQLite. Mai sovrascrivere; bumping di `schema_version` invalida la cache.
- Cache stadio 2: chiave = `sha256(schema_version_stage2 + series_id + facts_hash + study_summary_hash)`, dove `facts_hash` è calcolato sui `sample_facts` del GSE ordinati per `geo_accession` ascendente (deterministico, indipendente dall'ordine in cui sono prodotti).
- Cache GEO meta: chiave = `series_id`, refresh manuale solo.
- I `targets` costruiscono il loro stato sopra a queste cache: `tar_make()` ricalcola solo i sample/studi nuovi o invalidati.

## 6. Validazione

### 6.1 Eval set primario — gold xlsx

Sottoinsieme stratificato dei 130k sample del xlsx, da costruire come `analysis/eval/eval_set_v1.tsv`. Stratificazione:

- 60% sample dove `trtctr_EP == trtctr` (casi facili, baseline d'accordo) — per rilevare regressioni
- 30% sample dove `trtctr_EP != trtctr` (casi su cui shallow sbaglia) — per misurare il guadagno
- 10% sample con stringhe ambigue/corte (testato manualmente)

Dimensione iniziale: 1000 sample (validazione veloce). Espansione successiva: tutti i 130k.

### 6.2 Metriche

**Stadio 1 (sample-level fatti)** — non si valuta direttamente vs il xlsx (lo schema è più ricco), ma:

- *Schema validity rate*: % di output che passano JSON schema
- *Recall di campi chiave*: % di sample con `perturbation.kind != null`, `cell_context.cell_type_or_line_raw != null`
- *Calibration plot*: confidence dichiarata vs accuratezza umana su sub-sample manuale (200 sample)

**Stadio 2 (ruoli e gruppi)** — si valuta producendo un derived `trtctr_predicted ∈ {treated, control}` collassando `design_role`:
- `treated_predicted` ⇐ `design_role ∈ {perturbed, case, secondary_arm}`
- `control_predicted` ⇐ `design_role ∈ {vehicle_control, untreated_control, negative_genetic_control, baseline_t0, comparison}`
- *Agreement con `trtctr_EP`*: accuracy, F1, confusion matrix (con `unclear` come terzo stato)
- *Improvement vs baseline shallow `trtctr`*: differenza di accuracy
- *Per-strato*: GSE-stratified, cell-line-stratified
- *Casi di disaccordo*: revisione manuale di un sub-sample (50-100) con annotazione del motivo

**Caveat semantico importante.** Il `trtctr_EP` del xlsx riflette una classificazione "*il sample ha ricevuto qualsiasi intervento esplicito*" (es. siNT viene marcato `treated` perché è stata applicata una transfection). In ottica meta-analisi, siNT è invece `negative_genetic_control` rispetto a siGENE: cioè *control* nel disegno. I due gold standard misurano cose diverse. Conseguenza:

- Il proxy `design_role → trtctr_predicted` qui sopra produrrà **disaccordo sistematico con `trtctr_EP`** sui sample tipo siNT/siCtrl, scrambled, vehicle. Questo NON è un errore del classificatore ma un'evoluzione di semantica che è il senso stesso del progetto.
- Conviene quindi affiancare un **gold standard "design-aware"** rifatto su un subset (es. 200-300 sample stratificati) sotto la nuova semantica, ovvero etichettando direttamente `design_role` invece di `trtctr`. Senza questo, le metriche §6 misurano allineamento con una semantica obsoleta.
- Il xlsx storico resta utile come (i) test di non-regressione per la classificazione "grezza" e (ii) sorgente di sample da cui estrarre lo stratified eval set.

### 6.3 Failure handling

- Confidence stadio 1 < 0.5 → flag, ma include nel dataset (non bloccante)
- Confidence stadio 2 < 0.5 → re-process con Sonnet → Opus se ancora < 0.5
- GSE con > 30% sample `unclear` allo stadio 2 → flag per revisione manuale
- Schema validation fail → re-prompt fino a 2 tentativi, poi route a `sample_facts_invalid`

## 7. Collegamento agli stadi successivi della pipeline simulomicsr

- **Stadio 3 (raggruppamento)** consuma `comparisons_table`. Cluster cross-studio = sample con stesso `comparability_anchor`. Soglia minima k = 3 studi per anchor per essere considerato meta-analizzabile (default, configurabile).
- **Stadio 4 (DE per-studio)** legge `replicate_groups` per costruire le matrici di design `DESeq2`/`limma`. Ogni `comparison` produce uno o più contrasti.
- **Stadio 5 (meta-analisi)** poolia gli effect size dei contrasti che condividono lo stesso `comparability_anchor` con `metafor` (REM).

## 8. Esecuzione

- **Sviluppo locale**: dev set di 100-500 sample, real-time API (latenza bassa per iterazione)
- **Eval set**: 1000 sample, real-time API
- **Run completo**: 130k sample, **batch API** per stadio 1 (sconto 50%, latenza fino a 24h accettabile); studio-by-studio real-time o batch per stadio 2 a seconda del volume finale

Ambiente: l'ambiente attuale `renv` è disallineato (R 4.2.2 lockfile vs 4.5.2 system) — la riconciliazione è ADR separato (vedi task #12). Non blocca il design, blocca l'esecuzione del prototipo.

## 9. Decisioni rinviate / da chiarire con l'utente

1. **Colonna `gold` nel xlsx.** Significato esatto (consenso EP+altro? revisione successiva?). Va chiarito prima di usarla in valutazione.
2. **Sorgente sample finale.** Si lavora solo sui 130k del xlsx, oppure si scala in futuro a tutto ARCHS4 (~700k+)? Il design regge a entrambi i casi; cambia solo il piano d'esecuzione.
3. **Vincolo budget LLM.** Stima $200-500 per run completo. Tetto da confermare.
4. **Vocabolari controllati esterni.** Mappare a HGNC/UniProt/DrugBank/Cellosaurus richiede risorse di lookup: si fa subito (Stadio 1 prova a normalizzare) o ex-post deterministicamente? Default proposto: l'LLM tenta nello Stadio 1 ma lo schema accetta `null`; in parallelo, una funzione R deterministica `R/normalize.R` può raffinare.
5. **Gestione di sample `disease_vs_normal`.** Lo schema li copre, ma la meta-analisi differential expression su questo sub-design ha statistica diversa (case-control invece di treated-vs-control). Va deciso se includerli come prima classe o trattarli come scope separato della meta-analisi.
6. **Schema versioning policy.** Bumping di `schema_version` invalida la cache → ricalcolo costoso. Conviene definire una policy (deprecation window, migration script) prima del primo run sui 130k.
7. **Multi-organism.** Lo schema accetta organism free; se la pipeline scala oltre human/mouse, vocabolari di gene ID divergono. Proposta: per ora ristringere a human + mouse nei criteri di inclusione meta-analisi, e flaggare gli altri.
8. **Costruzione di un gold "design-aware".** Per misurare davvero la qualità dello Stadio 2 serve un sub-set etichettato direttamente come `design_role` (vedi caveat in §6.2). Dimensione minima proposta: 200-300 sample, stratificati per `design_kind` e per cell context. Costo: lavoro umano. Da decidere: chi etichetta? In quanto tempo?

## 10. Out of scope (esplicitamente)

- Implementazione del provider LLM diverso da Anthropic
- Fine-tuning di un modello custom
- Active learning loop con re-annotation umana via UI
- Estrazione di metadati che non aiutano la meta-analisi (es. piattaforma sequenziamento, quality scores)
- Stadio 3+ (raggruppamento, DE, meta-analisi statistica) — design propri in ADR/spec successivi

## 11. Rischi principali

| Rischio | Probabilità | Impatto | Mitigazione |
|---|---|---|---|
| LLM allucina mapping a ID database (HGNC, DrugBank) inesistenti | Media | Alto (sporca anchor) | Validazione ID via lookup deterministico ex-post; flag `compound_unmapped` |
| Stadio 2 sbaglia ruolo per studi factoriali complessi | Media | Medio | `design_kind=factorial` triggers Sonnet → Opus reprocess; flag manuale |
| GEO API rate limit blocca il fetch dei `study_summary` | Bassa | Medio | Cache aggressive su disco; backoff esponenziale; possibile fallback a NCBI EUtils batch |
| Drift di schema tra prototipo e run finale | Alta | Alto | `schema_version` esplicito in ogni record; migration scripts in `R/migrate.R` |
| Costi LLM esplodono su long-tail di GSE grandi (centinaia di sample) | Media | Medio | Truncation policy nello Stadio 2; chunking se sample > 50; flag `input_truncated` |
| Mismatch fra semantica gold xlsx (`trtctr_EP`) e semantica design-aware del classificatore | Alta | Medio | Esplicitato in §6.2 caveat; affiancare un gold "design-aware" rifatto su subset (vedi §9.8); usare il xlsx come test di non-regressione, non come gold primario per lo Stadio 2 |

## 12. Open questions for review

L'utente è invitato a verificare in particolare:

- §3 schema Stadio 1: campi mancanti? campi superflui?
- §4.2 vocabolario `design_role`: serve aggiungere `dose_response_arm`, `differentiation_endpoint`, altro?
- §6.2 metriche: il proxy "design_role → trtctr_predicted" è accettabile come ponte al gold xlsx?
- §9 punto 1: cosa è `gold`?
- §9 punto 5: includere `disease_vs_normal` come prima classe?

Una volta approvata la spec, si passa alla skill `writing-plans` per il piano di implementazione (target-by-target, con checkpoint di review).
