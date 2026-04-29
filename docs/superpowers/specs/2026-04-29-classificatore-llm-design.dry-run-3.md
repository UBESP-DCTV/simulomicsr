# Dry-run 3 dello schema classificatore — 50 sample reali

**Data:** 2026-04-29  
**Spec di riferimento:** `2026-04-29-classificatore-llm-design.md` v4 (schema stage1.v2)  
**Dry-run precedenti:** `dry-run.md` (10 sample → R1-R7), `dry-run-2.md` (30 sample → R8-R20)  
**Scopo:** spingere la due diligence verso la convergenza, esplorando domini ancora poco testati. Decidere se applicare le revisioni allo schema o continuare a iterare.

## Composizione del campione

30 sample stratificati su categorie nuove (non-mammalian + microbe-related; aging/sex; withdrawal/wash-out/resistance; polysome/Ribo/fractionation; viral vector/AAV/vaccini) + 20 random.

**Nota:** alcuni filtri categoriali sono noisy (es. "non_mammalian" ha pescato anche sample umani che menzionano *E. coli* come pathogen). I sample sono comunque utili perché esercitano dimensioni nuove (infezione, segmentazione anatomica, microbiota).

---

## Output condensato per sample (✓ regge / ⚠ rompe / ◐ richiede Stadio 2)

### Categoria: organismi non-mammiferi e infezioni microbiche

| # | GSM | Pattern | Esito |
|---|---|---|---|
| 1 | GSM3612264 | `'treatment: E. coli'` (stringa minimale) | v2 ✓ — pathogen kind, flag `description_too_short`, Stadio 2 essenziale ◐ |
| 2 | GSM4133134 | Sigmoid colon biopsy, healthy female, no treatment, Crohn's cohort baseline | v2 + R12 patient_metadata ✓ |
| 3 | GSM5529059 | Duodenal enteroid + pathogenic E. coli | v2 ✓ — ⚠ R21: `tissue_segment` (duodenum/ileum/sigmoid) manca |
| 4 | GSM5529078 | Ileal enteroid + non-pathogenic E. coli control | v2 + R21 ✓ |
| 5 | GSM2770978 | NSG mouse host + bone marrow + MLL-AF4 oncogene fusion transduced | v2 + R14 host_organism + R9 variant (MLL-AF4) ✓ |
| 6 | GSM4133013 | Crohn's disease patient, active rectum biopsy | v2 + R12 ✓ |

### Categoria: aging / sex difference / coorte clinica

Sample 7-12, tutti dal **GSE192861 — studio Mepolizumab vs Placebo per asma in coorte longitudinale (visit Randomization vs Visit 14)**. Pattern condiviso:

```
source tissue: Nasal Lavage, flowcell id: ..., visit: ...,
study id: ICAC30, fastq total reads: ..., percent aligned: ...,
treatment: Mepolizumab|Placebo, time in study in years: ...
```

⚠ **NUOVO R22:** la stringa contiene **campi tecnici/QC del sequencing** (`flowcell id`, `fastq total reads`, `percent aligned`, `aligned counts in millions`, `median cv coverage`) che sono **rumore** per la classificazione biologica. Lo Stadio 1 deve essere istruito esplicitamente a *ignorarli*. Implicazione di prompt design, non strutturale: il prompt sistema include una lista di "noise patterns" da filtrare (QC sequencing, technical IDs, batch labels privi di significato biologico).

⚠ **NUOVO R23 (longitudinal clinical studies):** `treatment: Mepolizumab` su un sample isolato non basta — serve sapere il `visit` (Randomization vs Visit 14) per costruire il vero design longitudinale. Lo Stadio 2 lo gestisce ricostruendo il design del GSE. Questa è una *conferma dell'architettura ibrida*, non una nuova revisione.

### Categoria: withdrawal / wash-out / drug resistance

| # | GSM | Pattern chiave | Esito |
|---|---|---|---|
| 13 | GSM5065472 | CWR-R1 castration-resistant + SOX2 sort marker | v2 + R11 + R2 (drug_adapted) ✓ |
| 14 | GSM4952050 | Metastatic melanoma post anti-PD-1, refractory, Responder | v2 + R12 ✓ |
| 15 | GSM6046826 | Etoposide-resistant K562 line | v2 + R2 (drug_adapted) ✓ |
| 16 | GSM4732270 | **GSI washout for 4h** | ⚠ **NUOVO R24** |
| 17 | GSM6372390 | Utomilumab 1.2 mg/kg, melanoma stage IV, "Objective progression" | v2 + R12 ✓ |
| 18 | GSM5149467 | FGF2 + Gilteritinib early-resistant MOLM14 + 100nM Gilteritinib | v2 + R2 + R8? ✓ |

⚠ **R24 (NUOVO STRUTTURALE):** **drug washout / recovery / persistence** sono fasi temporali esplicite di un disegno (drug applied → drug removed → recovery period). Lo schema v2 modella `duration` ma non distingue la *fase*. Proposta: `perturbations[].phase ∈ {exposure, washout, recovery, persistence, rebound}` opzionale. Rilevante per una *minoranza* di studi ma quando c'è è critica.

### Categoria: polysome / Ribo / fractionation

| # | GSM | Pattern chiave | Esito |
|---|---|---|---|
| 19 | GSM5062825 | Tumor CD3+ T cells, treatment "PRE", sort markers Live/Dead-CD14-CD20-CD45+CD3+ | v2 + R11 ◐ |
| 20 | GSM4258223 | HEK 293T, mock infection, **cellular fraction: ER**, total RNA | ⚠ **NUOVO R25** |
| 21 | GSM1533229 | TRA-1-60+ enriched + DOX days 0-20 (riprogrammazione iPSC) | v2 + R11 + R8 + R16 ✓ |
| 22 | GSM5063534 | duplicato pattern di #19 | v2 + R11 ✓ |
| 23 | GSM3067253 | MCF7 + serum starvation | v2 ✓ (kind=environmental) |
| 24 | GSM3401905 | PBMC, donor Bakiga (Ugandan ethnic group), admixture %, **cell type proportions (CD4, CD8, CD14)**, LPS | ⚠ **NUOVO R26** |

⚠ **R25 (NUOVO STRUTTURALE):** **subcellular fractionation** del campione (`cellular fraction: ER` / nuclear / cytoplasmic / chromatin / mitochondrial / membrane / polysome / exosome). Lo schema v2 metterebbe questo in `technical_treatments` ma è una dimensione abbastanza chiave da meritare un campo dedicato. Proposta: `cell_context.subcellular_fraction: {kind, raw}` con vocabolario controllato.

⚠ **R26 (NUOVO):** **cell composition / deconvolution estimates** in sample bulk (`proportion of cd4: 0.54`, `proportion of cd14: ...`). Per la meta-analisi cross-studio di campioni bulk eterogenei (PBMC, whole blood, tumor bulk), la composizione cellulare è confounder potente. Proposta: `cell_composition_estimates: [{marker, proportion, method}]` opzionale.

### Categoria: viral vectors / AAV / vaccini / infezioni

| # | GSM | Pattern chiave | Esito |
|---|---|---|---|
| 25 | GSM4427391 | HeLa-229, **Salmonella infection (bystander cells)** | ⚠ **NUOVO R27** |
| 26 | GSM6551675 | H3.3K27M glioma, AAVS1 control KO, nucleofection 4d | v2 + R9 + R4 ✓ |
| 27 | GSM2901590 | H1792 + inducible Id1 shRNA infection | v2 + R8 + R4 ✓ |
| 28 | GSM4891239 | HCT116 + lentivirus negative control sequence | v2 + R4 + R7 ✓ |
| 29 | GSM1595862 | Lung adenocarcinoma + RelA-S536E mutant + DMSO | v2 R1 (multi) + R9 (variant) + R7 ✓ |
| 30 | GSM6551659 | duplicato pattern #26 | v2 ✓ |

⚠ **R27 (NUOVO incrementale):** vocabolario `design_role` Stadio 2 § 4.2 dovrebbe includere `bystander` (cellule non-direttamente-infettate ma esposte agli effetti delle vicine in studi di pathogen exposure). Frequente in studi infezione, importante per il pooling.

### Categoria: random discovery (sample 31–50)

Highlights: la maggior parte dei sample random sono **catturati pulitamente da v2 con le revisioni R1-R20 già accumulate**. Eccezioni interessanti:

- **#34 GSM5286267** `'age: 30, Male, treatment: T4 (three months after meditation), Whole Blood'` — ⚠ **NUOVO R28**: studi *behavioral / lifestyle interventions* (meditation, sleep, diet, exercise come *intervento longitudinale*). Vocabolario v2 §3.1 ha `environmental` che contiene exercise; serve ampliare/rinominare a **`environmental_or_behavioral`** per includere interventi comportamentali strutturati.

- **#46 GSM4752923** `'SMARCA4 activation sgRNA'` — ⚠ **NUOVO R29**: distinguere **CRISPRa (activation)** da **CRISPRi (interference)** e da `genetic_overexpression` classico (transgene). Vocabolario v2 §3.1 li accorpa. Proposta: aggiungere `crispra_activation` e `crispri_repression` a `perturbation.kind` (oppure introdurre `mechanism` come campo separato: `chemical|crispra|crispri|knockout|knockdown|transgene|cytokine|...`).

- **#49 GSM5378449** `'treatment: PALLY_48_hours_LY_12_hours'` — ⚠ **NUOVO R30**: **sequential / staged treatment** (drug A per 48h, poi drug B per 12h). v2 modella `perturbations[]` come array senza ordering. Proposta: `perturbations[].temporal_order: integer` o `relative_start_hours: float`. Rilevante per studi farmacologici sequenziali e wash-out + ri-trattamento.

- **#48 GSM2678543** `'BJ Fibroblasts, treatment: WT'` — "WT" come treatment è opaco senza summary, Stadio 2 essenziale ◐

---

## Sintesi nuove revisioni R21-R30

| ID | Cosa | Tipo | Sample reale |
|---|---|---|---|
| **R21** | `cell_context.tissue_segment` (anatomical sub-region: duodenum, ileum, sigmoid, rectum, ecc.) | incrementale | #3, #4, #2, #6 |
| **R22** | Prompt design Stadio 1: istruire a IGNORARE QC/technical fields rumorosi (flowcell, percent aligned, ecc.) | implementativo | #7-12 |
| **R23** | (Conferma architettura ibrida — nessuna revisione) | — | #7-12 |
| **R24** | `perturbations[].phase ∈ {exposure, washout, recovery, persistence, rebound}` | **strutturale** | #16 |
| **R25** | `cell_context.subcellular_fraction: {kind, raw}` (ER, nuclear, cytoplasm, chromatin, polysome, ecc.) | **strutturale** | #20 |
| **R26** | `cell_composition_estimates: [{marker, proportion, method}]` per bulk con deconvolution dichiarata | incrementale | #24 |
| **R27** | `design_role: bystander` (Stadio 2 vocab §4.2) | incrementale | #25 |
| **R28** | Vocab `kind` v2 §3.1: `environmental` → `environmental_or_behavioral` | incrementale | #34 |
| **R29** | Vocab `kind` v2 §3.1: aggiungere `crispra_activation`, `crispri_repression`; o introdurre campo `mechanism` separato | **strutturale** | #46 |
| **R30** | `perturbations[].temporal_order: int` o `relative_start_hours: float` per trattamenti sequenziali | **strutturale** | #49 |

**Strutturali totali nuove**: R24, R25, R29, R30 → 4 revisioni  
**Incrementali totali nuove**: R21, R26, R27, R28 → 4 revisioni  
**Implementative**: R22 → 1 nota di prompt design

## Analisi di convergenza

| Dry-run | Sample | Strutturali nuovi | Tasso strutturale |
|---|---|---|---|
| 1 | 10 | 7 (R1-R7) | **70%** |
| 2 | 30 | 5 (R8, R9, R10, R11, R16) | 17% |
| 3 | 50 | 4 (R24, R25, R29, R30) | **8%** |

Il tasso di rotture strutturali è in **calo costante**. Sta convergendo verso un asintoto basso ma probabilmente non zero (la coda di GEO è enorme e variegata).

**Estrapolazione probabilistica:** un quarto dry-run su altri 50-100 sample troverebbe presumibilmente 1-3 nuove revisioni strutturali, prevalentemente legate a domini molto specifici (single-cell pseudobulk, spatial transcriptomics, plant/yeast molto rappresentati nei sample non-mammalian non ancora ben coperti, ChIP/CLIP-seq mascherati). Tornano sempre sotto al 10% di rotture.

## Trade-off: schema ricco vs schema operativo

Lo schema sta diventando *molto* ricco. Costo operativo:
- **Token di output dell'LLM Stadio 1** crescono con il numero di campi (oggi: ~150-300 token. Con tutte le revisioni R1-R30: ~250-500 token per sample). Con 700k sample dell'ARCHS4 completo, ogni 100 token in più = ~$50-100 di costo aggiuntivo (su gpt-5.4-mini batch).
- **Probabilità di errore di compilazione** cresce con la complessità dello schema. Schema strict mode di OpenAI mitiga ma non azzera.
- **Sviluppo del prompt** richiede esempi few-shot più ampi (più sample → context window prompt più grande → più costo per chiamata).

**Proposta: schema MVP + estensioni progressive.**

- **MVP (Minimum Viable Product)** = v2 + revisioni dei 3 dry-run *strutturali* selezionate per coprire la maggioranza degli use case meta-analitici:
  - R1 (perturbations array)
  - R2 (engineered_modifications)
  - R3 (disease_state)
  - R4 (technical_treatments)
  - R5 (context_kind)
  - R8 (mediated_effect)
  - R9 (variant)
  - R10 (co_culture_partners)
  - R11 (sort_markers)
  - R16 (developmental_stage)
  - R20 (input arricchimento — pertiene allo stadio upstream)
  - R24 (perturbations.phase) — leggera, opzionale
  - R29 (mechanism distinction CRISPRa/CRISPRi/transgene) — strutturale ma compatto

- **Estensioni post-MVP** = R6, R7, R12, R13, R14, R15, R17, R18, R19, R21, R22, R23, R25, R26, R27, R28, R30 — applicabili come campi opzionali estensibili senza breaking change al primo run.

Questo dà uno schema **stage1.v3** stabile con cui iniziare l'implementazione, e un piano di evoluzione progressiva senza dover ri-eseguire i 700k sample ad ogni miglioramento.

## Proposta finale

**Stop ai dry-run.** Lo schema sta convergendo (8% rotture sul terzo dry-run), e ogni dry-run aggiuntivo costa tempo umano e di sviluppo. Il rendimento marginale è in calo.

Procedere così:
1. Applicare lo **schema stage1.v3 = v2 + revisioni MVP elencate sopra** alla spec come **v5**.
2. Documentare le R rimanenti come *roadmap di estensioni* in spec §13 (nuova sezione "Schema evolution roadmap").
3. Passare a `writing-plans` per il piano d'implementazione.
4. Ri-valutare l'estensione dello schema dopo il primo run sul dev set di 1000 sample (dati empirici reali batono dry-run mentale).
