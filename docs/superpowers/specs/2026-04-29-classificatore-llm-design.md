# Design — Classificatore LLM meta-analytics-aware (Stadio 2 della pipeline simulomicsr)

- **Data:** 2026-04-29 (v5 — applicate TUTTE le 17 revisioni strutturali + 14 incrementali emerse dai 4 dry-run su 190 sample)
- **Stato:** Stable v3 schema, pronta per `writing-plans` (in attesa di approvazione finale utente)
- **Allegati dry-run** (prove e motivazioni di ogni revisione):
  - `2026-04-29-classificatore-llm-design.dry-run.md` — 10 sample, R1-R7
  - `2026-04-29-classificatore-llm-design.dry-run-2.md` — 30 sample, R8-R20
  - `2026-04-29-classificatore-llm-design.dry-run-3.md` — 50 sample, R21-R30
  - `2026-04-29-classificatore-llm-design.dry-run-4.md` — 100 sample, R31-R32 (convergenza al 1%)
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

## 3. Schema dati — Stadio 1 (sample_facts) — versione v3 (post 4 dry-run, 190 sample)

Output JSON per ogni GSM. Campi `null` quando il dato non è ricavabile dalla stringa di metadati. Vocabolari controllati segnalati con asterisco; gli altri campi sono stringhe libere ma normalizzate (lowercase, trim).

> **Storia revisioni schema:**
> - **stage1.v1** — iniziale (commit 64984d2)
> - **stage1.v2** — dopo dry-run 1 (10 sample → R1-R7). Commit 1520caa, applicato in spec v4 (a62a600)
> - **stage1.v3** — dopo dry-run 2-4 (190 sample totali → R8-R32). Applica TUTTE le 17 strutturali + 14 incrementali emerse. Vedi `dry-run-2.md`, `dry-run-3.md`, `dry-run-4.md` per le motivazioni.

```json
{
  "geo_accession": "GSM1009635",
  "series_id": "GSE41166",
  "organism": "Homo sapiens",                              // cell-of-origin (free text → NCBI Taxonomy ex-post)
  "host_organism": null,                                   // R14: host se diverso (xenograft, infezione)

  "cell_context": {
    "cell_type_or_line_raw": "Primary Human Umbilical Vein Endothelial Cells",
    "cell_line_cellosaurus_candidate": null,
    "tissue": "vascular endothelium",
    "tissue_segment": null,                                // R21: sub-anatomical (duodenum/ileum/sigmoid/...)
    "passage_or_state": "P3-6",
    "context_kind": "primary_culture",                     // *enum §3.5
    "developmental_stage": null,                           // R16: NP, beta-like, midbrain DA, fetal PCW19, ...
    "cell_state": null,                                    // *enum §3.8 (R31): senescent, exhausted, ...
    "subcellular_fraction": null,                          // R25: {kind, raw} | null — ER, nuclear, polysome...
    "engineered_modifications": [],                        // R2 + R9 + R17: baseline stabile della linea
    "co_culture_partners": [],                             // R10: cellule conviventi (cell_type, modifications, organism, role)
    "sort_markers": [],                                    // R11: ["CD34+", "Lin-", "ALDH+", ...]
    "cell_composition_estimates": []                       // R26: {marker, proportion, method} per bulk eterogenei
  },

  "disease_state": {                                       // R3
    "term_raw": null,                                      // es. "ME/CFS", "NEPC", "Crohn's disease"
    "mesh_id_candidate": null,                             // verificato ex-post da R/lookup.R
    "status": "none"                                       // *enum §3.6
  },

  "perturbations": [                                       // R1: array
    {
      "kind": "cytokine_stimulation",                      // *enum §3.1
      "agent_raw": "VEGF",
      "agent_normalized": {
        "type": "gene_or_protein",                         // *enum §3.2
        "id_database": "HGNC",                             // *enum §3.2: HGNC|UniProt|DrugBank|ChEMBL|CHEBI|MeSH|CAS|null
        "id": "HGNC:12680",
        "preferred_name": "VEGFA",
        "collection": null                                 // R13: {name, id_in_collection} per UVCB / codici opachi
      },
      "dose": {"value_raw": null, "value_numeric": null, "unit": null},
      "duration": {"value_raw": "0h", "value_hours": 0, "is_zero_timepoint": true},
      "phase": null,                                       // R24: *enum §3.9 (exposure/washout/recovery/persistence/rebound)
      "temporal_order": null,                              // R30: int — per trattamenti sequenziali, 1-based
      "is_negative_control": false,                        // siNT, scrambled, empty vector, mock
      "mediated_effect": null                              // R8: {kind, targets:[]} per Tet-On/AID/4-OHT
    }
  ],

  "technical_treatments": [],                              // R4: {kind, agent_raw}, vocab §3.4

  "patient_metadata": null,                                // R12: opzionale per studi clinici (vedi §3.10)

  "extraction": {
    "schema_version": "stage1.v3",
    "model": "openai:gpt-5.4-mini",                        // default Stadio 1; vedi §5.3
    "confidence": 0.78,
    "ambiguity_flags": [],                                 // *enum §3.3
    "raw_input_hash": "sha256:..."
  }
}
```

### 3.1 Vocabolario `perturbations[].kind` (v3, R6 + R28 + R29)

- `small_molecule` — drug/compound (doxorubicin, tamoxifen, ecc.)
- `vehicle_only` — solo veicolo dichiarato (DMSO, PBS, water, ethanol, mock)
- `genetic_knockdown` — siRNA, shRNA, antisense
- `genetic_knockout` — CRISPR-Cas9 acuto, gene deletion
- `genetic_overexpression` — transgene, vector overexpression *senza specifica CRISPRa* (R29)
- `crispra_activation` — **R29 NEW** CRISPRa (dCas9-VP64/VPR/SAM, ecc.)
- `crispri_repression` — **R29 NEW** CRISPRi (dCas9-KRAB acuto)
- `cytokine_stimulation` — recombinant proteins (VEGF, TNF, IL6, EGF, …)
- `pathogen_or_aggregate_exposure` — viral/bacterial infection, misfolded aggregate exposure (alpha-syn PFF, Aβ, ecc.) (R6)
- `environmental_or_behavioral` — **R28 RIN.** hypoxia, starvation, irradiation, heat shock, exercise, meditation, sleep, dietary
- `differentiation` — protocollo di differenziamento cellulare
- `mechanical_or_physical` — strain, shear, electroporation, indentation
- `none` — nessuna perturbazione esplicita riportata
- `unclear` — riportato qualcosa di non riconducibile a nessun kind sopra

> Nota: `disease_vs_normal` come `kind` è **rimosso** in v3 — lo stato di malattia è in `disease_state` (R3).

### 3.2 Vocabolario `agent_normalized.type` e `id_database` (v3, R19)

`type`: `gene_or_protein`, `small_molecule`, `vehicle`, `disease_term`, `genotype`, `none`, `other`.

`id_database` (R19 +CAS): `HGNC`, `MGI`, `UniProt`, `DrugBank`, `ChEMBL`, `CHEBI`, `MeSH`, `CAS`, `Cellosaurus`, `Ensembl`, `NCBITaxonomy`, `null`.

### 3.3 Vocabolario `ambiguity_flags` (v3, R7 + R32)

`missing_dose`, `missing_duration`, `time_zero_timepoint`, `multi_factor_in_string`, `compound_unmapped`, `cell_line_ambiguous`, `vehicle_only`, `description_too_short`, `mixed_organism_terms`, `study_specific_jargon`, `multiple_perturbations`, `engineered_cell_line`, `technical_treatment_only`, `disease_state_present`, `control_unspecified`, `post_treatment_ambiguous`, `protocol_only_no_perturbation`, **`metadata_inconsistency`** (R32 NEW), **`opaque_compound_code`** (R13).

### 3.4 Vocabolario `technical_treatments[].kind` (v3, R4)

`culture_matrix` (Matrigel, collagen, fibronectin, charcoal-stripped FBS), `culture_media` (special media), `electroporation_method` (delivery fisico), `rna_fractionation` (xPAP, total, polyA), `subcellular_isolation`, `cell_synchronization` (serum starvation, double thymidine, nocodazole), `chip_or_clip_setup` (antibody, crosslinking), `batch_or_processing` (batch label puro), `other_technical`.

### 3.5 Vocabolario `cell_context.context_kind` (v3, R5 + R18)

`cell_line_in_vitro`, `primary_culture`, `iPSC_derived`, `organoid` (include sferoidi 3D), `xenograft`, `primary_tissue` (biopsy, whole blood, ecc.), `pdx_derived_cell_line`, `co_culture`, `tumor_extracted_cells` (R18: TIL, sorted-from-tumor), `unclear`.

### 3.6 Vocabolario `disease_state.status` (v3, R3)

`case`, `comparison`, `disease_model`, `none`.

### 3.7 Vocabolario `cell_context.engineered_modifications[].kind` (v3, R2 + R17 + R9)

`germline_genotype` (es. `SNCA_4COPY`, `BRCA1_5382insC`), `crispr_stable` (dCas9-KRAB stabile, KO stabile), `transgene_stable` (overexpression integrata stabile), `inducible_transgene` (R17: rtTA + tetO-GENE), `drug_adapted` (MCF-7/AC-1, etoposide-resistant K562), `reporter_stable` (Blimp1-tdTomato, luciferase), `other`.

Ogni elemento ha campo opzionale `variant: {label, description, is_wildtype}` (R9) per distinguere WT vs mutant del transgene (es. APOBEC1-YTH vs APOBEC1-YTHmut).

### 3.8 Vocabolario `cell_context.cell_state` (v3, R31 NEW)

`proliferating`, `senescent`, `quiescent`, `dormant`, `activated`, `anergic`, `exhausted`, `naive`, `memory`, `differentiated`, `dedifferentiated`, `undifferentiated`, `transitional`, `apoptotic`, `stressed`, `recovering`, `unclear`, `none`.

### 3.9 Vocabolario `perturbations[].phase` (v3, R24 NEW)

`exposure` (drug attivo durante la finestra di sample), `washout` (drug rimosso dopo esposizione), `recovery` (post-washout), `persistence` (esposizione lunga termine), `rebound` (post-withdrawal effetto rebound), `null` (default — nessuna fase distinta).

### 3.10 Schema `patient_metadata` (v3, R12, opzionale)

```json
{
  "donor_id": null,                    // anonimizzato es. "P5", "donor 2"
  "age": null,
  "sex": null,                         // "M"|"F"|"other"|null
  "ancestry_or_population": null,      // "Bakiga", "Han Chinese", ecc. (free text)
  "ancestry_admixture": null,          // proporzione 0..1 se dichiarata
  "clinical_response": null,           // "CR"|"PR"|"SD"|"PD"|"Responder"|"NonResponder"|null
  "survival_group": null,              // "Short_Survivor"|"Long_Survivor"|null
  "stage": null,                       // staging tumorale, severity score
  "condition": null,                   // "non-SAA", "Ctrl", "active", "remission", ecc.
  "visit_or_timepoint": null           // "Randomization", "Visit 14", "T0", "Day 28", ecc.
}
```

### 3.11 Schema `co_culture_partners[]` (v3, R10)

```json
{
  "cell_type": "...",                  // "motor neurons", "BMSC", "feeder MEFs"
  "source_organism": null,             // "Mus musculus" se host diverso
  "modifications": [],                 // engineered modifications del partner
  "role": "partner"                    // "feeder" | "partner" | "target" | "stromal"
}
```

### 3.12 Schema `subcellular_fraction` (v3, R25)

```json
{ "kind": "ER", "raw": "cellular fraction: ER" }
```

`kind` ∈ `ER`, `nuclear`, `cytoplasmic`, `chromatin`, `mitochondrial`, `membrane`, `polysome`, `monosome`, `ribosome_associated`, `exosome`, `total_rna`, `other`.

## 4. Schema dati — Stadio 2 (study_design)

Un oggetto JSON per ogni GSE, prodotto dall'LLM dopo aver letto: (a) lista dei `sample_facts` dello stadio 1 (schema v2), (b) `study_title` + `study_summary` + `study_overall_design` da GEO API per quel GSE.

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
    "model": "openai:gpt-5.5",                              // default per Stadio 2; vedi §5.3
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

### 4.2 Vocabolario `design_role` (v3, + R15 + R27)

- `perturbed` — riceve trattamento/perturbazione attiva di interesse
- `vehicle_control` — solo veicolo/solvente (DMSO, PBS, water, mock)
- `untreated_control` — nessun trattamento (no vehicle dichiarato)
- `negative_genetic_control` — siNT, siNeg, scrambled, empty vector, non-targeting
- `negative_inducer_control` — **R15 NEW** sistema inducibile NON indotto (es. "NO Dox", "no IPTG", "no 4-OHT")
- `positive_control` — controllo positivo del saggio (raro nei design RNAseq)
- `baseline_t0` — campione a tempo zero in time-course
- `case` — sample patologico in disegno disease vs normal
- `comparison` — sample sano/normale in disegno disease vs normal
- `bystander` — **R27 NEW** cellule non-direttamente-perturbed che condividono la coltura/tessuto (frequente in studi infezione, irradiation, paracrine effects)
- `secondary_arm` — braccio di trattamento alternativo (non quello di interesse principale)
- `excluded` — sample che il LLM segnala come inadatto al design (QC fallito, outlier dichiarato)
- `unclear` — ruolo non ricostruibile

### 4.3 Definizione di `comparability_anchor` (v3 con schema esteso)

Stringa canonica deterministica per cross-studio matching, prodotta da una funzione R pura `make_anchor(stage1_facts, stage2_role)` (NON dall'LLM). Per ciascun confronto si genera l'anchor PRENDENDO LA PERTURBAZIONE DI INTERESSE (selezionata dallo Stadio 2 fra le `perturbations[]` del sample) e fattorizzando le altre dimensioni rilevanti.

**Regola di selezione del campo "agente di interesse":** se la perturbazione ha `mediated_effect != null` (R8 — sistemi inducibili tipo Tet-On/AID/4-OHT), l'agente *biologicamente* di interesse è il `mediated_effect.target` (es. SOX17 per Dox→tetO-SOX17), non l'inducente (Dox). Il campo `kind_effective` riflette questa risoluzione.

Formato v3 (concatenato con `|`, 11 segmenti):

```
{kind_effective}|{agent_id_or_name}|{variant_label_or_wt}|
{dose_canonical}|{duration_hours_or_NA}|{phase_or_default}|
{cell_id}|{context_kind}|{cell_state_or_default}|{subcellular_or_default}|
{tissue_canonical}|{disease_status_or_none}|{has_engineered_baseline:bool}
```

Esempi v3:

- `cytokine_stim|HGNC:12680|wt|nodose|1h|exposure|HUVEC|primary_culture|proliferating|whole_cell|vascular_endothelium|none|false`
- `small_molecule|DB00997|wt|10nM|24h|exposure|MCF-7|cell_line_in_vitro|proliferating|whole_cell|breast|none|false`
- `genetic_knockdown|HGNC:1001|wt|nodose|72h|exposure|OCI-LY1|cell_line_in_vitro|proliferating|whole_cell|lymphoid|none|false`
- `genetic_overexpression|HGNC:SOX17|wt|nodose|6d|exposure|585B1|iPSC_derived|undifferentiated|whole_cell|na|none|true`  *(via Dox→tetO-SOX17, R8)*
- `genetic_overexpression|HGNC:APOBEC1|YTHmut|nodose|24h|exposure|HEK293T|cell_line_in_vitro|proliferating|whole_cell|kidney_embryonic|none|true`  *(R9 variant distingue da WT)*
- `disease_vs_normal|MeSH:D010300|wt|nodose|na|persistence|iPSC_neurons|iPSC_derived|differentiated|whole_cell|brain|case|true`  *(PD model con genotype)*
- `pathogen_or_aggregate_exposure|HGNC:11138|wt|nodose|3h|exposure|iPSC_neurons|iPSC_derived|differentiated|whole_cell|brain|disease_model|true`  *(PFF su SNCA_4COPY)*
- `small_molecule|GSI|wt|standard|4h|washout|SCC_IC8|cell_line_in_vitro|proliferating|whole_cell|skin|none|false`  *(R24 phase=washout)*

Note:
- **R8 mediated_effect**: se presente, `kind_effective = mediated_effect.kind` e `agent = mediated_effect.target`. L'inducente (Dox) viene perso dall'anchor — è in una funzione separata `make_inducer_log(stage1_facts)` per audit.
- **R9 variant**: `variant_label_or_wt` espone il label del mutante (`YTHmut`, `HRASV12`, `K351A`); `wt` se wild-type.
- **R24 phase**: il default è `exposure`; altri valori (washout/recovery/persistence/rebound) entrano nell'anchor solo se esplicitamente dichiarati nel sample.
- **R31 cell_state**: separa proliferating da senescent/exhausted/quiescent. Default `proliferating` se non flaggato (assunzione standard).
- **R25 subcellular**: default `whole_cell` se total RNA (assunzione bulk standard).
- **has_engineered_baseline**: true se `engineered_modifications` non vuoto. Sample con questa flag = true sono raggruppati separatamente da quelli con baseline wild-type.
- Per `disease_vs_normal`, l'anchor distingue `case` da `comparison` (fold-change atteso = case − comparison).
- L'anchor è **versionato** (`anchor_version="v3"`); future regole non invalidano i `sample_facts` ma richiedono solo un ricalcolo deterministico.

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

- **Stadio 1 (default): `gpt-5.4-mini`** — modello OpenAI veloce/economico, schema rigido, output JSON breve. Eseguito in batch API per il run massivo.
- **Stadio 2 (default): `gpt-5.5`** — modello OpenAI capace, ragionamento sul design dello studio, schema più ricco. Real-time per default; batch se il volume di GSE giustifica la latenza.
- **Sviluppo iniziale**: `gpt-5.5` ANCHE per lo Stadio 1 nei primi 100-200 sample del dev set, per non confondere "errore di schema" con "limite del modello piccolo". Switch a `gpt-5.4-mini` solo quando il prompt è stabile e gli errori dipendono dal modello.
- **Modello arbitro**: `gpt-5.5` per re-processing di GSE con `confidence < 0.5` allo Stadio 2.

**A/B opzionale (consigliato sul dev set)**: validare il prompt anche con un modello Anthropic (Claude Haiku 4.5 / Sonnet 4.6) sul medesimo dev set di 100-200 sample. Confronto di disagreement rate tra provider de-risca le scelte di prompt e mette un secondo paio di occhi sui casi ambigui. Costo aggiuntivo limitato. *Vincolo*: necessita di crediti API Anthropic separati dal piano Claude Max (i piani Max non includono crediti API — vanno acquistati su `console.anthropic.com`).

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
| 4 | Vocabolari controllati (HGNC/DrugBank/Cellosaurus/...) | **Risolto** | Strategia ibrida: LLM produce nome canonico + id_candidate nello Stadio 1; funzione R deterministica `R/lookup.R` verifica/corregge tramite dump locali. Dettagli §9.A |
| 5 | `disease_vs_normal` come prima classe | **Risolto** | Inclusi come prima classe (opzione B1 in §9.B). Lo Stadio 2 li annota; la meta-analisi li poolia separatamente con anchor disease-based |
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

**Decisione (2026-04-29 v3):** **(B1) inclusi come prima classe.** Motivazione: il filtro è semplice e separabile downstream (gli anchor di tipo `disease_vs_normal|...` non si confondono con `small_molecule|...`); la copertura del corpus aumenta. La meta-analisi statistica può applicare modelli leggermente diversi senza che il classificatore cambi.

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
- **§9.4 vocabolari controllati** — risolto: strategia ibrida LLM + lookup R deterministico (vedi §9.A).
- **§9.5 `disease_vs_normal`** — risolto: inclusi come prima classe (B1) (vedi §9.B).

Una volta che l'utente approva questa versione della spec, si passa alla skill `writing-plans` per il piano di implementazione (target-by-target, con checkpoint di review).
