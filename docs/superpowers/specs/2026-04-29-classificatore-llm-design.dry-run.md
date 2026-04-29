# Dry-run dello schema classificatore — 10 sample reali dal xlsx

**Data:** 2026-04-29  
**Spec di riferimento:** `2026-04-29-classificatore-llm-design.md` v3  
**Scopo:** validare lo schema PRIMA di scrivere il piano d'implementazione. Io (Claude) faccio da LLM Stadio 1 e (dove possibile) Stadio 2 sui 10 sample stratificati estratti da `data-raw/relevant_sample_classified.xlsx`.

I sample sono stati selezionati per stressare dimensioni diverse:

| # | Categoria di stress | GSM | GSE |
|---|---|---|---|
| 1 | Drug + vehicle, classico | GSM1359855 | GSE56361 |
| 2 | Doppia perturbazione (drug + siCtrl) | GSM1826445 | GSE71069 |
| 3 | siRNA knockdown su target | GSM4338287 | GSE145872 |
| 4 | Time-course con t=0 untreated | GSM3673544 | GSE128385 |
| 5 | Baseline genetica (dCas9) + acute | GSM5713557 | GSE190096 |
| 6 | Disease state + intervento attivo | GSM3664562 | GSE128078 |
| 7 | Disease vs normal + technical | GSM5502814 | GSE181462 |
| 8 | Multi-dim PD model | GSM5970869 | GSE199349 |
| 9 | Stringa povera | GSM6020662 | GSE200186 |
| 10 | Linea drug-resistant + post-treatment | GSM2095928 | GSE79492 |

## Output del dry-run, per sample

### Sample 1 — GSM1359855 (DMSO + HEK293, classico)

**Input:** `"treatment: DMSO medium, cell line: HEK 293"`  
**Gold xlsx:** trtctr_EP=control, trtctr=control, gold=control

**Stadio 1 atteso:**
```json
{
  "geo_accession": "GSM1359855",
  "series_id": "GSE56361",
  "organism": null,
  "cell_context": {
    "cell_type_or_line_raw": "HEK 293",
    "cell_line_cellosaurus_candidate": "CVCL_0045",
    "tissue": "kidney (embryonic)",
    "passage_or_state": null
  },
  "perturbation": {
    "kind": "small_molecule",
    "agent_raw": "DMSO",
    "agent_normalized": {"type": "vehicle", "id_database": null, "id": null, "preferred_name": "DMSO"},
    "dose": {"value_raw": null, "value_numeric": null, "unit": null},
    "duration": {"value_raw": null, "value_hours": null, "is_zero_timepoint": false}
  },
  "extraction": {"confidence": 0.62, "ambiguity_flags": ["missing_dose", "missing_duration", "vehicle_only"]}
}
```

**Stadio 2 (atteso, con study summary GEO):** lo `design_kind` sarà uno tra `treatment_vs_vehicle` (se il GSE ha anche compounds) o `unclear`; questo sample sarà `vehicle_control`.

**Verdetto:** lo schema regge. ✓

---

### Sample 2 — GSM1826445 (EGF + shRNA non-targeting, doppia perturbazione) ⚠️

**Input:** `"treatment: 100 ng/mL EGF for 4 h, shRNA: non-targeting shRNA (Sigma), chip antibody: N/A, cell type: HMEC"`  
**Gold xlsx:** trtctr_EP=treated, trtctr=treated, gold=null

**Problema:** ci sono **due** interventi sullo stesso sample: EGF (cytokine, attivo) + shRNA-NT (genetic, controllo). Lo schema attuale ha `perturbation` SINGOLARE → uno dei due va perso.

**Possibili fix:**
- Promuovere a `perturbations: [...]` (array). Conseguenza: ogni elemento mantiene il suo `kind`/`agent`/`dose`/`duration`. Lo Stadio 2 decide quale è "di interesse" e quale è "background condition".

**Stadio 1 atteso DOPO fix:**
```json
{
  "perturbations": [
    {"kind": "cytokine_stimulation", "agent_raw": "EGF",
     "agent_normalized": {"type":"gene_or_protein","id_database":"HGNC","id":"HGNC:3229","preferred_name":"EGF"},
     "dose": {"value_raw":"100 ng/mL","value_numeric":100,"unit":"ng/mL"},
     "duration": {"value_raw":"4 h","value_hours":4,"is_zero_timepoint":false}},
    {"kind": "genetic_knockdown", "agent_raw": "non-targeting shRNA (Sigma)",
     "agent_normalized": {"type":"vehicle","id_database":null,"id":null,"preferred_name":"shRNA-NT"},
     "dose": {"value_raw":null,"value_numeric":null,"unit":null},
     "duration": {"value_raw":null,"value_hours":null,"is_zero_timepoint":false}}
  ],
  "extraction": {"confidence": 0.78, "ambiguity_flags": ["multiple_perturbations"]}
}
```

**Verdetto:** lo schema **si rompe**. Necessario: `perturbation → perturbations: []`. ⚠️

---

### Sample 3 — GSM4338287 (CWC27 DsiRNA, knockdown classico)

**Input:** `"cell type: h-TERT RPE-1, treatment: CWC27 DsiRNA"`  
**Gold xlsx:** trtctr_EP=treated, trtctr=control (shallow sbaglia, non riconosce DsiRNA come treatment)

**Stadio 1 atteso:**
```json
{
  "cell_context": {"cell_type_or_line_raw": "h-TERT RPE-1", "cell_line_cellosaurus_candidate": "CVCL_4388", ...},
  "perturbation": {
    "kind": "genetic_knockdown",
    "agent_raw": "CWC27 DsiRNA",
    "agent_normalized": {"type":"gene_or_protein","id_database":"HGNC","id":"HGNC:24762","preferred_name":"CWC27"},
    "dose": null, "duration": null
  },
  "extraction": {"confidence": 0.83, "ambiguity_flags": ["missing_dose","missing_duration"]}
}
```

**Stadio 2 atteso:** `design_role: perturbed` → mappa a `treated_predicted`. Disaccordo con shallow `trtctr=control`, accordo con `trtctr_EP=treated`. ✓

**Verdetto:** schema regge, e lo schema cattura un caso che la baseline shallow sbaglia. ✓ ✨

---

### Sample 4 — GSM3673544 (xenograft + Untreated + t=0, time-course baseline)

**Input:** `"tissue: cell-line derived xenograft, cell line used for xenograft: MIA PaCa-2, cell type used for xenograft: pancreas carcinoma, treatment: Untreated, time point: 0 h, replicate: rep5, internal_id: J19549"`  
**Gold xlsx:** trtctr_EP=control, trtctr=control, gold=null

**Stadio 1 atteso:**
```json
{
  "cell_context": {
    "cell_type_or_line_raw": "MIA PaCa-2 (xenograft)",
    "cell_line_cellosaurus_candidate": "CVCL_0428",
    "tissue": "pancreas (carcinoma, xenograft model)",
    "passage_or_state": "xenograft in vivo"
  },
  "perturbation": {
    "kind": "none",
    "agent_raw": "Untreated",
    "agent_normalized": {"type":"none", ...},
    "duration": {"value_raw":"0 h","value_hours":0,"is_zero_timepoint":true}
  },
  "extraction": {"confidence": 0.85, "ambiguity_flags": ["time_zero_timepoint"]}
}
```

**Stadio 2 atteso:** `design_role: baseline_t0` → mappa a `control_predicted`. ✓

**Verdetto:** schema regge. La distinzione "in vivo xenograft vs in vitro" si rappresenta in `passage_or_state` o in un campo aggiuntivo? Possibile aggiunta: `cell_context.context_kind ∈ {in_vitro, in_vivo, ex_vivo, primary_tissue, xenograft, organoid}`. ⚠️ minore

---

### Sample 5 — GSM5713557 (HEK293 dCas9-KRAB stable + sgRNA acute) ⚠️

**Input:** `"cell line: HEK2937, modification: dCas9-KRAB-MeCP2, treatment: sgRNA transfected"`  
**Gold xlsx:** trtctr_EP=treated, trtctr=control (shallow sbaglia)

**Problema:** la cellula HA UNA MODIFICA STABILE (`dCas9-KRAB-MeCP2`, sistema CRISPRi) + un INTERVENTO ACUTO (`sgRNA transfected`). Lo schema attuale non distingue *baseline genetica della linea* da *perturbazione attiva*.

**Conseguenza:** se metti `dCas9-KRAB-MeCP2` in `perturbation`, perdi l'sgRNA. Se metti l'sgRNA, perdi il fatto che la baseline è una linea CRISPRi (rilevante per il raggruppamento cross-studio: solo studi con stessa baseline sono comparabili).

**Possibili fix:**
- Aggiungere `cell_context.engineered_modifications: ["dCas9-KRAB-MeCP2"]` o più strutturato `[{system:"CRISPRi", elements:["dCas9","KRAB","MeCP2"]}]`
- L'sgRNA acute resta in `perturbations[]`

**Verdetto:** lo schema **si rompe**. Necessario: campo `engineered_modifications` su `cell_context`. ⚠️

---

### Sample 6 — GSM3664562 (ME/CFS + cardiopulmonary exercise) ⚠️

**Input:** `"tissue: Whole blood, disease state: ME/CFS, treatment: Cardiopulmonary exercise, timepoint (day): 1, individual identifier: G13"`  
**Gold xlsx:** trtctr_EP=treated, trtctr=control (shallow sbaglia su "Cardiopulmonary exercise")

**Problema:** ci sono DUE dimensioni di interesse: (a) lo stato di malattia (`disease state: ME/CFS`), (b) l'intervento attivo (esercizio). Il design tipico di questi studi è 2×2: malato esercitato, malato non esercitato, sano esercitato, sano non esercitato.

Lo schema attuale ha `perturbation.kind ∈ {disease_vs_normal, environmental, ...}` ma non può rappresentare CONTEMPORANEAMENTE lo stato di malattia + l'intervento attivo. Va letto come "due dimensioni nello stesso sample".

**Possibili fix:**
- Aggiungere `disease_state: {term_raw, mesh_id_candidate, status: "case"|"comparison"|"none"}` come campo separato e indipendente da `perturbations`
- `perturbations[]` porta gli interventi attivi (esercizio nel caso)

**Stadio 1 atteso DOPO fix:**
```json
{
  "cell_context": {"cell_type_or_line_raw": "Whole blood", "tissue": "blood", "context_kind": "primary_tissue", ...},
  "disease_state": {"term_raw": "ME/CFS", "mesh_id_candidate": "D015673", "status": "case"},
  "perturbations": [
    {"kind": "environmental", "agent_raw": "Cardiopulmonary exercise", "agent_normalized": {"type":"other"}, ...}
  ]
}
```

**Verdetto:** schema **si rompe** sui design `disease × intervention`. Necessario: campo `disease_state` separato. ⚠️

---

### Sample 7 — GSM5502814 (NEPC + MATRIGEL = technical, non perturbazione) ⚠️

**Input:** `"donor: WCM155, tissue: Neuroendocrine prostate cancer (NEPC), treatment: MATRIGEL"`  
**Gold xlsx:** trtctr_EP=control, trtctr=MATRIGEL (shallow non interpreta)

**Problema:** "treatment: MATRIGEL" non è una perturbazione biologica; è la matrice di cultura per crescere organoidi. È informazione **tecnica/protocollare**, non l'intervento di interesse.

Senza una distinzione esplicita, lo schema mette MATRIGEL in `perturbation.agent_raw` e lo studio sembra "drug treated with MATRIGEL". Sbagliato.

**Possibili fix:**
- Aggiungere `technical_treatments: []` come campo separato (matrici di cultura, vehicle solo, electroporation method, RNA fractionation, batch effects)
- Vocabolario `perturbation.kind` aggiunge `not_a_perturbation` come opzione

**Stadio 1 atteso DOPO fix:**
```json
{
  "cell_context": {"tissue": "prostate (NEPC)", "context_kind": "primary_tissue/organoid", ...},
  "disease_state": {"term_raw": "Neuroendocrine prostate cancer (NEPC)", "mesh_id_candidate": "D011471 (refined)", "status": "case"},
  "perturbations": [],
  "technical_treatments": [{"kind": "culture_matrix", "agent_raw": "MATRIGEL"}],
  "extraction": {"confidence": 0.65, "ambiguity_flags": ["technical_treatment_only", "disease_state_present"]}
}
```

**Verdetto:** schema **si rompe**. Necessario: `technical_treatments[]` o flag esplicito `not_a_perturbation`. ⚠️

---

### Sample 8 — GSM5970869 (PD model: genotype + disease + PFF) ⚠️

**Input:** `"cell type: Patient derived Ngn2 induced cortical neurons, snca genotype: SNCA_4COPY, disease state: Parkinson's Disease model, pff treatment: PFFyes, timepoint: h3"`  
**Gold xlsx:** trtctr_EP=treated, trtctr=PFFyes

**Problema:** TRE dimensioni:
1. Genotipo (`SNCA_4COPY` = 4 copie del gene SNCA, modello genetico di PD)
2. Stato di malattia (`PD model`)
3. Perturbazione attiva (`PFFyes` = pre-formed fibrils di alfa-sinucleina, induce aggregazione tipo-PD)

Lo schema attuale ne cattura una sola.

**Stadio 1 atteso DOPO fix (cumula §5 + §6 + §7):**
```json
{
  "cell_context": {
    "cell_type_or_line_raw": "Ngn2-induced cortical neurons (patient-derived)",
    "context_kind": "iPSC_derived",
    "engineered_modifications": [{"kind": "germline_genotype", "raw": "SNCA_4COPY"}]
  },
  "disease_state": {"term_raw": "Parkinson's Disease model", "mesh_id_candidate": "D010300", "status": "case"},
  "perturbations": [
    {"kind": "pathogen_exposure_or_aggregate", "agent_raw": "PFF (alpha-synuclein pre-formed fibrils)",
     "agent_normalized": {"type":"gene_or_protein","id_database":"HGNC","id":"HGNC:11138","preferred_name":"SNCA"},
     "duration": {"value_raw": "h3", "value_hours": 3}}
  ]
}
```

**Verdetto:** lo schema **si rompe** in 3 punti, ma le correzioni cumulative degli altri sample lo risolvono. Aggiunta minore al vocabolario `perturbation.kind`: serve `aggregate_exposure` o ampliare `pathogen_exposure` a `pathogen_or_aggregate_exposure`. ⚠️

---

### Sample 9 — GSM6020662 (stringa "treatment: Control")

**Input:** `"treatment: Control"`  
**Gold xlsx:** trtctr_EP=control, trtctr=control

**Stadio 1 atteso:**
```json
{
  "cell_context": {"cell_type_or_line_raw": null, "cell_line_cellosaurus_candidate": null, "tissue": null},
  "perturbations": [],
  "extraction": {"confidence": 0.30, "ambiguity_flags": ["description_too_short", "control_unspecified"]}
}
```

**Stadio 2 atteso:** ricevendo lo study summary GEO, lo Stadio 2 decide cosa significa "Control" (probabilmente uno tra `untreated_control`, `vehicle_control`, `negative_genetic_control`). Senza summary, l'output Stadio 1 è giustamente confidence-bassa e flaggata.

**Verdetto:** schema regge ma la VITALITÀ DI STADIO 2 è confermata: senza esso, sample come questo finiscono in pattumiera. ✓

---

### Sample 10 — GSM2095928 (MCF-7/AC-1 drug-resistant + Day 28 + Control) ⚠️

**Input:** `"cell line: MCF-7/AC-1, time: Post treatment (Day 28), treatment: Control"`  
**Gold xlsx:** trtctr_EP=control, trtctr=control

**Problema:** MCF-7/AC-1 **è una linea pre-adattata cronicamente all'inibitore dell'aromatasi** (drug-resistant model). Quindi NON è una linea wild-type: ha un'esposizione cronica integrata nella sua identità. "Day 28 post-treatment" è ambiguo senza study summary.

**Stadio 1 atteso (con conoscenza della linea):**
```json
{
  "cell_context": {
    "cell_type_or_line_raw": "MCF-7/AC-1",
    "cell_line_cellosaurus_candidate": "CVCL_DR21 (or similar AI-resistant MCF-7 derivative)",
    "tissue": "breast (luminal A, ER+)",
    "engineered_modifications": [{"kind": "drug_adapted", "raw": "anastrozole/AI-adapted MCF-7 derivative"}]
  },
  "perturbations": [
    {"kind": "none", "agent_raw": "Control", ...,
     "duration": {"value_raw":"Day 28 post-treatment","value_hours":672,"is_zero_timepoint":false}}
  ],
  "extraction": {"confidence": 0.45, "ambiguity_flags": ["control_unspecified", "post_treatment_ambiguous", "engineered_cell_line"]}
}
```

**Verdetto:** lo schema **si rompe** sulla baseline genetica/farmacologica della linea. Stessa fix del sample 5 (`engineered_modifications`). Lo Stadio 2 con summary è essenziale per interpretare "Day 28 post-treatment". ⚠️

---

## Sintesi delle revisioni necessarie allo schema

| ID revisione | Cosa | Impatto | Sample che lo richiedono |
|---|---|---|---|
| **R1** | `perturbation` → `perturbations: []` (array) | Alto (cambia struttura) | 2, 5, 6, 7, 8, 10 |
| **R2** | Aggiungere `cell_context.engineered_modifications: []` (baseline genetica/farmacologica della linea) | Alto (nuovo campo strutturato) | 5, 8, 10 |
| **R3** | Aggiungere `disease_state: {term_raw, mesh_id_candidate, status}` (separato da perturbazioni) | Alto (nuovo campo, semantico chiave) | 6, 7, 8 |
| **R4** | Aggiungere `technical_treatments: []` (matrici cultura, batch, fractionation, etc.) | Medio (separa rumore) | 7 (e tanti altri non-mostrati) |
| **R5** | Aggiungere `cell_context.context_kind` (in_vitro / in_vivo / xenograft / iPSC_derived / primary_tissue / organoid) | Medio (rilevante per anchor) | 4, 7, 8 |
| **R6** | Espandere `perturbation.kind` con `aggregate_exposure` (o ampliare `pathogen_exposure`) | Basso | 8 |
| **R7** | Espandere `ambiguity_flags`: `multiple_perturbations`, `engineered_cell_line`, `technical_treatment_only`, `disease_state_present`, `control_unspecified`, `post_treatment_ambiguous` | Basso | tutti |

## Cosa NON si rompe (lo schema ha tenuto)

- Vocabolario `design_kind` (Stadio 2): copre i casi visti
- Vocabolario `design_role` (Stadio 2): copre i casi visti
- Approccio ibrido a 2 stadi: confermato come essenziale (sample 9, 10)
- Strategia normalizzazione vocabolari ibrida (LLM + lookup R): confermata; HGNC/MeSH/Cellosaurus tutti rilevanti nei sample
- `comparability_anchor` deterministico: il formato regge se si decide quale `perturbation` è "di interesse" (lo Stadio 2 lo fa)

## Cosa il dry-run NON ha potuto valutare

- Comportamento dell'LLM REALE su questi sample (questo è un dry-run "ideale" — un modello specifico potrebbe perdere alcune di queste sottigliezze)
- Performance dello Stadio 2 senza accesso allo `study_summary` GEO (non ho fetched quei dati)
- Gestione di GSE con > 50 sample (truncation)
- Costi reali per token su prompt completo

## Raccomandazione per la spec

Applicare **R1, R2, R3, R4, R5, R6, R7 al PRIMO commit di revisione spec v4** prima di passare a `writing-plans`. R1-R3 sono cambiamenti strutturali importanti; R4-R7 sono incrementali. Tutti emergono da casi reali del corpus, non da speculazione.

Dopo le revisioni, lo schema diventa:

```
sample_facts {
  geo_accession, series_id, organism,
  cell_context {
    cell_type_or_line_raw, cell_line_cellosaurus_candidate, tissue,
    passage_or_state, context_kind,
    engineered_modifications: []
  },
  disease_state {term_raw, mesh_id_candidate, status},
  perturbations: [{kind, agent_raw, agent_normalized, dose, duration}, ...],
  technical_treatments: [{kind, agent_raw}, ...],
  extraction {schema_version, model, confidence, ambiguity_flags, raw_input_hash}
}
```

Lo Stadio 2 (`study_design`) resta sostanzialmente invariato, ma `replicate_groups[].sample_ids` ora si appoggia su questo schema più ricco.

## Prossimo step proposto

Far approvare le 7 revisioni dall'utente, applicarle alla spec come v4, committare, poi `writing-plans`.
