# Dry-run 4 dello schema classificatore — 100 sample reali

**Data:** 2026-04-29  
**Spec di riferimento:** `2026-04-29-classificatore-llm-design.md` v4 (schema stage1.v2)  
**Dry-run precedenti:** dry-run.md (10), dry-run-2.md (30), dry-run-3.md (50)  
**Scopo:** ultima sessione di due diligence. Verificare se la convergenza si conferma (tasso strutturale ≤5%) oppure emergono ancora nuove rotture sistematiche.

## Composizione

56 sample stratificati su domini ancora poco testati: single-cell pseudobulk (Smart-seq2), plant/yeast/fungal specific, ChIP/CLIP/ATAC mascherati, embryonic/developmental, stem cell types, mock/sham/vehicle distinct, healthy/normal cohort. + 44 random.

**Filtri categoriali noisy (atteso):** alcuni filtri hanno pescato false-positive — utili per discovery: il filtro "non_mammalian/plant/yeast" ha pescato sample umani con sistema **AID/Auxin** (HCT116 con auxin-inducible degron tagged sui geni endogeni); il filtro "chip_clip_atac" ha pescato 4 sample BLUEPRINT ChIP-seq che NON sono RNAseq → conferma R20 (lo stadio upstream deve filtrare per `assay_type=RNA-Seq`).

`spatial_transcriptomics`: filtro vuoto → il xlsx pre-filtrato non contiene sample spatial transcriptomics. Atteso: ARCHS4 è bulk RNAseq.

---

## Pattern emersi (sintesi)

Per brevità, **non** ripeto entry per ogni sample. Indico solo i pattern nuovi e le conferme dei dry-run precedenti.

### Conferme dello schema v2 + R1-R30

Coperti senza nuove rotture strutturali:
- **AID/Auxin degron system** (sample #9-16): cellule stably AID-tagged + Auxin acute = caso particolare di **R8 mediated_effect** (Auxin → degradation of MED26 / endogenous tagged target). Schema regge.
- **Single-cell pseudobulk Smart-seq2 PDOX colorectal** (sample #1-8): R5 (`pdx_derived_cell_line`) + R14 (host_organism) + R22 (Smart-seq2 = technical protocol da ignorare). Schema regge.
- **CRISPRa esplicito** (sample #87, "treatment category: CRISPRa, IL10RB-3 gRNA"): conferma che **R29** (distinguere CRISPRa) è essenziale, non opzionale.
- **HSPC cultured 48h/96h** (sample #34, #36, #40): cellule in coltura per durate diverse. Differenza non è una perturbazione né un design role — è uno **stato funzionale temporale**. Cattura via R31 (vedi sotto).
- **Mock infection + drug** (sample #45, #47): mock = controllo parallelo del fattore infezione, in design factoriale infezione × drug. R1 (perturbations multiple) gestisce.
- **CAR-T** (sample #50, "car: α-Lewis-Y, genotype: MOCK"): R2 (engineered_modifications kind=transgene_stable) + R9 (variant: α-Lewis-Y CAR construct). Schema regge.
- **Population/ancestry metadata** (sample #95 "population: Batwa, admixture: 0.966"): R12 patient_metadata. Schema regge.
- **Treatment opachi** (sample #82 "C6nc", #86 "PALLY_48_hours_LY_48_hours"): R13. Schema regge.
- **Internal inconsistency raro** (sample #54 "tissue: normal lung tissue, cell line: IMR90"): IMR90 è una linea fibroblast usata come *modello* di lung normale, non una contraddizione. Coperto da `cell_context` con campi paralleli. ⚠ **R32 minor**: utile aggiungere flag `metadata_inconsistency` quando l'LLM rileva contraddizioni interne — ma non strutturale.

### Nuove rotture strutturali (sole 1)

**⚠ R31 NUOVO STRUTTURALE: `cell_context.cell_state`**

Stato funzionale/biologico della cellula come dimensione separata da modifiche genetiche e da perturbazioni attive. Esempi reali:

- Sample #29 GSM1917145: `'IMR90, cell condition: senescent, cotransduced with pWZL HRASV12 and shRen, DMSO 48h'` — IMR90 in *stato senescente* (indotto da HRASV12 oncogenic). La senescenza non è una perturbazione (è già accaduta), non è una modifica genetica (è un fenotipo), non è il context_kind (è cellula in coltura come tante). È uno *stato cellulare* rilevante per la meta-analisi (proliferating vs senescent rispondono diversamente ai drug).
- Sample #34, #36, #40 GSM5361xxx: HSPCs `cultured in vitro for 48h/96h` — stato di attivazione/maturazione temporale (HSPC quiescenti vs attivate diversi).
- Tipico di studi T-cell exhaustion, stem cell quiescence, neuronal maturation, drug-induced senescence.

**Vocabolario proposto:**

```
cell_state ∈ {
  proliferating, senescent, quiescent, dormant,    # stati di ciclo cellulare
  activated, anergic, exhausted, naive, memory,    # immunologia
  differentiated, dedifferentiated, undifferentiated, transitional,  # commitment
  apoptotic, stressed, recovering,                 # risposta a danno
  unclear, none
}
```

Frequenza stimata di rilevanza: 5-10% dei sample (alta in immunologia, oncologia, aging, stem cell research). Strutturale ma compatto (un solo enum).

### Nuove incrementali (sole 1)

**R32 minor**: `ambiguity_flags` aggiungere `metadata_inconsistency` per stringhe internamente contraddittorie.

---

## Convergenza finale (4 dry-run cumulativi)

| Dry-run | Sample | Nuove strutturali | Cumulativi | Tasso strutt. |
|---|---|---|---|---|
| 1 | 10 | 7 (R1–R7) | 7 | **70%** |
| 2 | 30 | 5 (R8, R9, R10, R11, R16) | 12 | 17% |
| 3 | 50 | 4 (R24, R25, R29, R30) | 16 | 8% |
| 4 | 100 | **1** (R31) | 17 | **1%** |
| **Tot** | **190** | **17 strutturali, 14 incrementali** | | |

Il tasso è crollato a **1%**. La convergenza è solida: nei 100 sample del quarto dry-run, una sola nuova rottura strutturale è emersa, e quella riguarda una dimensione orthogonale (stato cellulare) facilmente aggiungibile come campo enum.

**Predizione robusta:** un quinto dry-run su altri 100-200 sample troverebbe ≤1 nuova revisione strutturale, prevalentemente in sotto-domini molto specifici (spatial trascriptomics, single-cell pseudobulk con metadati cluster, plant transcriptomics, microbiome, ecc.) che ARCHS4 stesso copre poco essendo bulk-mammalian-focused.

**Stop ai dry-run.** Il rendimento marginale è praticamente zero per la sostanza dello schema.

## Lista finale di tutte le revisioni emerse (R1–R32)

### Strutturali (17)
- **R1** `perturbations: []` array
- **R2** `cell_context.engineered_modifications: []`
- **R3** `disease_state: {term, mesh_id, status}`
- **R4** `technical_treatments: []`
- **R5** `cell_context.context_kind`
- **R6** ampliare vocab `kind` con `pathogen_or_aggregate_exposure`
- **R7** vocab `ambiguity_flags` esteso (multi)
- **R8** `perturbations[].mediated_effect` per sistemi inducibili (Tet, AID, ecc.)
- **R9** `engineered_modifications[].variant: {label, description, is_wildtype}`
- **R10** `cell_context.co_culture_partners: []`
- **R11** `cell_context.sort_markers: []`
- **R16** `cell_context.developmental_stage`
- **R20** Implicazione architettura: arricchire stringa input upstream (organism_ch1, source_name, title)
- **R24** `perturbations[].phase ∈ {exposure, washout, recovery, persistence, rebound}`
- **R25** `cell_context.subcellular_fraction`
- **R29** Distinguere `crispra_activation` / `crispri_repression` da `genetic_overexpression`
- **R30** `perturbations[].temporal_order`
- **R31** `cell_context.cell_state` ∈ {proliferating, senescent, quiescent, activated, exhausted, ...}

### Incrementali (12)
R12 patient_metadata, R13 agent.collection (UVCB), R14 host_organism, R15 design_role bystander/negative_inducer_control, R17 inducible_transgene kind, R18 tumor_extracted context_kind, R19 CAS database, R21 tissue_segment, R22 prompt design noise filtering, R23 (conferma architettura), R26 cell_composition_estimates, R27 design_role bystander, R28 environmental → environmental_or_behavioral, R32 metadata_inconsistency flag

(Alcuni numeri si sovrappongono perché contate in sezioni diverse; vedi singoli dry-run per dettaglio.)

## Decisione raccomandata

Stop. Definire schema **stage1.v3 = MVP** che include le strutturali + le incrementali a basso costo:

**MVP =** R1, R2, R3, R4, R5, R8, R9, R10, R11, R16, R24, R25, R29, R30, R31

**Estensioni post-MVP (da inserire come campi opzionali con default null):** R6, R7, R12-R15, R17-R23, R26-R28, R32

**Implicazione architettonica (non parte dello schema, ma documentata):** R20 — input arricchimento upstream → spec separata.

Procedere a `writing-plans` con questo schema.
