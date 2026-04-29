# Design — Classificatore LLM meta-analytics-aware (Stadio 2 della pipeline simulomicsr)

- **Data:** 2026-04-29 (v2 — dopo prima review utente)
- **Stato:** Draft (iterato, in attesa di review v2 + decisione su §9.4 vocabolari e §9.5 disease_vs_normal)
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
    "model": "openai:gpt-4o-mini",                          // provider:modello — astratto, vedi §5.3
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
    "model": "openai:gpt-5",                                // provider:modello — astratto, vedi §5.3
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

### 5.3 Provider LLM e modelli

**Provider primario: OpenAI** (vincolo organizzativo: pagamento via università). L'`R/llm-client.R` è progettato come strato astratto per consentire swap futuro a Anthropic (preferenza dell'utente quando il vincolo cambia) o provider locale.

#### 5.3.1 Modelli proposti (placeholder concreti, decisione finale in ADR-modelli separato)

- **Stadio 1: modello OpenAI veloce/economico** (es. `gpt-4o-mini` o equivalente "nano" della serie 5 quando disponibile). Schema rigido, output JSON breve.
- **Stadio 2: modello OpenAI capace** (es. `gpt-5` o `gpt-4o`). Ragionamento sul design dello studio, schema più ricco.
- **Modello arbitro**: `gpt-5` (o Opus equivalente se torniamo a Anthropic) per re-processing di GSE con `confidence < 0.5` allo Stadio 2.

#### 5.3.2 Feature OpenAI da sfruttare

- **Structured Outputs** (`response_format: {type: "json_schema", strict: true}`) — garantisce conformità 100% allo schema JSON dichiarato. Riduce a zero gli errori di parsing.
- **Batch API** (`/v1/batches`) — sconto 50%, latenza fino a 24h, ideale per lo Stadio 1 sui 700k+ sample ARCHS4.
- **Automatic Prompt Caching** — sui prompt > 1024 token cachati ricarichi pagano ~50% in meno; nessuna gestione manuale, ma TTL ~5-10 min: serve raggruppare le chiamate dello stesso template entro la finestra.

#### 5.3.3 Costi indicativi (tutto ARCHS4 ≈ 700k+ sample)

Ordine di grandezza (da raffinare con benchmark sul dev set):
- Stadio 1 (700k chiamate, GPT-4o-mini, batch API + caching): ~$300-700
- Stadio 2 (~50k GSE univoci stimati, GPT-5/4o, real-time + caching): ~$500-1500
- Eval set + iterazioni di sviluppo: ~$100-300
- **Totale stimato: $1000-2500** sull'intero ARCHS4

Vincolo budget: **nessun problema operativo dichiarato dall'utente** (copertura università). I numeri restano da verificare con un benchmark sui primi 1000 sample.

#### 5.3.4 Astrazione del client

```r
# R/llm-client.R (firma indicativa)
llm_call(
  provider   = "openai",                  # "openai" | "anthropic" | "local" — swap-friendly
  model      = "gpt-4o-mini",
  messages   = list(...),
  response_schema = json_schema_obj,      # se provider lo supporta
  cache_key  = NULL,                      # bypass cache se NULL
  batch      = FALSE,                     # se TRUE accumula in batch file
  ...
)
```

Adapter per ogni provider: `R/llm-client-openai.R`, `R/llm-client-anthropic.R` (già pronto per il futuro). Schema → format-string mapping per Structured Outputs (OpenAI) e Tool Use (Anthropic).

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

## 9. Decisioni — stato dopo prima review utente (2026-04-29)

| # | Tema | Stato | Decisione / Note |
|---|---|---|---|
| 1 | Colonna `gold` nel xlsx | **Risolto** | È il ricontrollo di un terzo revisore sulla classificazione treated/control (oltre EP). Utilizzabile come gold di seconda generazione. Documentato anche in `data-raw/README.md` |
| 2 | Sorgente sample finale | **Risolto** | Tutto ARCHS4 (~700k+ sample). Il xlsx 130k è il sotto-insieme già etichettato e resta il primo eval set. Implicazione: serve uno stadio upstream (acquisizione + filtraggio rilevanza) prima del classificatore — *spec separata* |
| 3 | Budget LLM e provider | **Risolto** | Provider: OpenAI (vincolo università). Nessun blocco di budget dichiarato. Astrazione del client per swap futuro |
| 4 | Vocabolari controllati (HGNC/DrugBank/Cellosaurus/...) | **In discussione** | Utente non li conosce. Proposta default: ibrido — l'LLM produce nome canonico + id_candidate; lookup deterministico R verifica e corregge (vedi §9.A) |
| 5 | `disease_vs_normal` come prima classe | **In discussione** | Da decidere se includere in meta-analisi o come scope separato (vedi §9.B) |
| 6 | Schema versioning policy | **Risolto** | Procediamo come da §5.4 con `schema_version` esplicito. Migration script in `R/migrate.R` quando serve un bump |
| 7 | Multi-organism | **Risolto — aperto** | Manteniamo lo schema agnostico sull'organism. Nessuna restrizione a human+mouse |
| 8 | Gold design-aware | **Pianificato** | L'utente lo costruirà quando saremo "a buon punto" (prototipo Stadio 2 funzionante su un subset, prima del run massivo) |

### §9.A — Vocabolari controllati (riferimento)

Sono dizionari ufficiali che assegnano un ID univoco a un'entità biologica. Servono perché due studi possono dire la stessa cosa con nomi diversi (es. `VEGFA` vs `VEGF` vs `Vascular Endothelial Growth Factor A` → tutti `HGNC:12680`). Senza ID canonico, il raggruppamento cross-studio è inaffidabile.

| Vocabolario | Cosa contiene | Esempio | Lookup |
|---|---|---|---|
| **HGNC** | Gene umani | `HGNC:1100` = BRCA1 | dump TSV pubblico, free |
| **MGI** | Gene mouse | `MGI:104537` = Brca1 | dump TSV pubblico, free |
| **UniProt** | Proteine | `P38398` = BRCA1 | API + dump |
| **Cellosaurus** | Linee cellulari | `CVCL_8800` = OCI-LY1 | dump XML, free |
| **DrugBank** | Farmaci approvati | `DB00997` = Doxorubicin | dump XML, accademico free con licenza |
| **ChEMBL** | Composti chimici (ampio) | `CHEMBL53463` | dump SQLite, free |
| **MeSH** | Termini medici | `D001943` = Breast Neoplasms | dump XML, free |
| **NCBI Taxonomy** | Specie | `9606` = Homo sapiens | dump TSV, free |

**Strategia ibrida proposta** (default): nello Stadio 1 l'LLM compila `agent_normalized.preferred_name` (es. `"VEGFA"`) e tenta `id_candidate` (es. `"HGNC:12680"`). Una funzione R deterministica `normalize_agent()` esegue lookup nei dump locali (`R/lookup.R`, dati cached in `inst/extdata/` o scaricati on-demand) e o conferma o sostituisce con il match corretto. Conseguenze: l'LLM può sbagliare ID e veniamo coperti; se l'agente è ambiguo (es. `"control"`), l'ID resta `null` e il sample viene classificato senza anchor canonico.

### §9.B — Studi `disease_vs_normal`

Sono studi che confrontano sample da pazienti/tessuti patologici vs sample sani (es. tumore vs adiacente normale, paziente vs donatore). Sono comuni nei dataset GEO (TCGA-style, oncologia, autoimmuni, neuro).

In ottica meta-analisi:
- **Statistica**: simile a treated-vs-control formalmente (DESeq2/limma, contrasto fra due gruppi), ma il "trattamento" non è applicato → è uno stato. La direzione del fold change è "case − comparison".
- **Comparability anchor**: diverso. La chiave canonica diventa `disease_vs_normal | MeSH_disease_term | tissue | organism`. Non c'è dose, durata, agent.
- **Volume**: significativo. Escludendoli si perde una grande fetta di GEO.

Tre opzioni:
- **(B1)** Includere come prima classe nel design del classificatore E nella meta-analisi finale. Il classificatore già copre `design_kind=case_control_disease` e `design_role ∈ {case, comparison}`. Comparability anchor adattato.
- **(B2)** Includere nel classificatore (lo schema li copre comunque) ma escludere dalla meta-analisi statistica (li raccogliamo, non li poolliamo).
- **(B3)** Escludere dal classificatore (filtro pre-Stadio 2). Solo studi `treatment_vs_*` e `time_course` proseguono.

**Default proposto:** (B1) includere. Motivazione: il filtro è semplice e separabile downstream (gli anchor di tipo `disease_vs_normal|...` non si confondono con `small_molecule|...`); la copertura del corpus aumenta. La meta-analisi statistica può applicare modelli leggermente diversi senza che il classificatore cambi.

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

## 12. Punti chiusi dopo seconda review utente

- **§3 schema Stadio 1** — i campi proposti (perturbation kind/agent, dose, time, cell context, organism, confidence, ambiguity flags) sono il candidato di partenza; nessun campo aggiunto/rimosso in questa iterazione. Possibili aggiunte future come ADR separato.
- **§4.2 `design_role`** — la lista (perturbed, vehicle_control, untreated_control, negative_genetic_control, positive_control, baseline_t0, case, comparison, secondary_arm, excluded, unclear) è il candidato di partenza.
- **§6.2 proxy `design_role → trtctr_predicted`** — è il "ponte tecnico" tra le metriche del nostro schema design-aware e il vecchio gold xlsx (che etichetta solo treated/control). Accettato come strumento di non-regressione, NON come gold di valutazione primaria. Il gold primario sarà il design-aware da costruire (§9.8).
- **§9.1 colonna `gold`** — risolto: ricontrollo di un terzo revisore (vedi §9 tabella).
- **§9.5 `disease_vs_normal`** — proposta default: includere come prima classe (B1). In attesa di conferma utente — vedi §9.B.

Una volta che l'utente approva questa versione della spec, si passa alla skill `writing-plans` per il piano di implementazione (target-by-target, con checkpoint di review).
