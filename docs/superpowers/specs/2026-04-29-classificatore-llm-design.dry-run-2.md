# Dry-run 2 dello schema classificatore — 30 sample reali

**Data:** 2026-04-29  
**Spec di riferimento:** `2026-04-29-classificatore-llm-design.md` v4 (schema stage1.v2)  
**Dry-run precedente:** `2026-04-29-classificatore-llm-design.dry-run.md` (10 sample, 7 revisioni R1-R7)  
**Scopo:** verificare se lo schema **v2** copre casi d'uso non testati nel primo dry-run e identificare ulteriori revisioni.

## Composizione del campione

20 sample stratificati su categorie nuove (multi-organism, iPSC/organoid/PDX, CRISPR/overexpression, co-culture, drug combinations) + 10 random.

---

## Output condensato per sample

Convenzioni: ✓ = lo schema v2 regge; ⚠ = problema strutturale; ◐ = caso che richiede solo Stadio 2 con study summary.

### Categoria: multi-organism / non-human

**#1 GSM5211976** `'TIL, TGFBR2 knockout, treatment: TGF-B1'` — KO stabile + cytokine. v2 lo gestisce: `engineered_modifications=[{kind:crispr_stable, target:"TGFBR2"}]` + `perturbations=[{kind:cytokine_stimulation, agent:"TGF-B1"}]`. ⚠ MINORE: TIL = Tumor Infiltrating Lymphocyte (cellule sortate da tumore). Quale `context_kind`? Servirebbe `tissue_extracted_lymphocytes` o ampliamento di `primary_tissue` con sotto-tipo.

**#2 GSM4981649** `'hiPSC differentiated into NP, treatment: 50...'` — `context_kind=iPSC_derived`. ⚠ NUOVO: il sample è uno *stage di differenziamento intermedio* (NP = neural precursor). Per la meta-analisi cross-studio "iPSC → NP" deve raggrupparsi separatamente da "iPSC → mature neurons". Manca `cell_context.developmental_stage`.

**#3 GSM4392077** `'Aflatoxin B1, cas number: 1162-65-8, concentration: 1 uM'` — clean, schema v2 ✓. Nota: `cas number` è un'altra fonte ID per `agent_normalized.id_database` (CAS Registry); attualmente lo schema accetta CHEBI ma non CAS esplicitamente.

**#4 GSM5666631** `'TNBC, MDAMB231, treatment_type: knockout, treatment: ICE2, time: 96'` — clean v2 ✓ (engineered_modifications con crispr_stable target=ICE2 OPPURE perturbations con genetic_knockout — *ambiguità*: KO è stabile o acuto? Dipende da study).

> *Nota generale categoria*: i filtri "multi-organism" hanno pescato comunque tutti **human** (false-positive: i match testuali su "mouse"/"rat" possono essere termini menzionati nei metadati senza che il sample sia non-human). Gli organismi sono dichiarati altrove in GEO (campo `organism_ch1`); lo Stadio 1 dovrà attingere a quel campo, non solo alla stringa concatenata. ⚠ implicazione per lo stadio upstream di acquisizione: la stringa di input al classificatore va **arricchita con `organism_ch1`**, non lasciata solo coi `characteristics_ch1`.

### Categoria: iPSC / organoid / PDX

**#5 GSM3523622** `'HCT116, culture condition: spheroid, treatment: DMSO'` — `context_kind=organoid` (sferoide è 3D, lo include). Vehicle. v2 ✓.

**#6 GSM3578988** `'PDX Glioblastoma cell line, siSUPT6H, SUPT6H KD'` — `context_kind=pdx_derived_cell_line` + `perturbations=[{kind:genetic_knockdown, target:"SUPT6H"}]`. v2 ✓.

**#7 GSM3899622** `'Pancreatic Beta-like cells, Untreated, hPSCs-derived organoid'` — ⚠ stessa nota del #2: serve `developmental_stage="pancreatic beta-like"` + `context_kind=organoid`. Senza, il sample finisce in mucchio coi non-differentiated.

**#8 GSM3314930** `'ileum organoid TI365, Mock 48h'` — context_kind=organoid + perturbations=[{kind:vehicle_only, agent:"Mock"}]. v2 ✓ ma "Mock" è genericissimo (Stadio 2 deve disambiguare).

### Categoria: CRISPR / overexpression / inducible systems

**#9 GSM3270676** `'TF-induced fibroblasts, time: 21 days after induction, Ectopic expression of transcription factors'` — kind=`genetic_overexpression`, agent=opaco ("transcription factors" non specifica). Stadio 2 con summary recupera quali TFs. ◐ + ⚠ NUOVO: sample è un **endpoint riprogrammazione cellulare** ("induced fibroblasts" = de-differentiated phenotype). Cattura via developmental_stage o un nuovo `reprogramming_status`?

**#10 GSM4677412** `'585B1 hiPSCs, day6, reporter transgene: Blimp1-tdTomato/TFAP2C-EGFP, other transgenes: rtTA + tetO-SOX17/TFAP2C/GATA3, treatment: Dox, pgclcs induced: Yes'` — ⚠ **CASO CHIAVE PER LO SCHEMA**: 

Sistema **Tet-ON inducibile**: rtTA (transactivator stabile) + tetO-{SOX17,TFAP2C,GATA3} (3 transgeni inducibili) + reporter Blimp1/TFAP2C. Il `treatment: Dox` ATTIVA l'overexpression dei 3 fattori. La perturbazione *vera* per la meta-analisi è "overexpression di SOX17/TFAP2C/GATA3", non "Dox da solo".

Lo schema v2 mette Dox in `perturbations[].kind=small_molecule`. **Ma la perturbazione biologicamente di interesse è l'overexpression mediata** che lo schema non collega.

**Possibili fix:**
- (A) Aggiungere `perturbations[].mediated_effect: {kind, targets:[]}` — Dox `mediated_effect={kind:genetic_overexpression, targets:["HGNC:SOX17","HGNC:TFAP2C","HGNC:GATA3"]}`
- (B) Creare due perturbations: `[{kind:small_molecule, agent:Dox, role:"inducer"}, {kind:genetic_overexpression, targets:[...], role:"induced", inducer_index:0}]`
- (C) Usare `engineered_modifications` per il transgene e `perturbations` solo per Dox; lasciare allo Stadio 2 ricostruire la connessione

→ Proposta R8: opzione **(A) `mediated_effect`** — più compatto, coerente con design "una perturbazione = una causa".

Inoltre: il sample ha `reporter transgene` distinti dai `transgeni inducibili`. Servono *due tipi* in `engineered_modifications`: `reporter_stable` (esiste già in v2 §3.7) e `inducible_transgene` (NUOVO).

**#11 GSM5479549** `'HEK293T, transgene: APOBEC1-YTH, doxycycline 1ug/mL 24h'` — Dox-inducibile overexpression di una variante APOBEC1-YTH (proteina di fusione, *non* mutant). v2 ✓ con R8 (mediated_effect).

**#12 GSM5480839** `'HEK293T, transgene: APOBEC1-YTHmut, doxycycline 1ug/mL 24h'` — sample identico ma con la **mutante**. Differenza chiave per la meta-analisi: WT vs mutant è il vero confronto biologico nel GSE. ⚠ NUOVO: serve catturare la **variante del transgene**, non solo il nome. Proposta R9: `engineered_modifications[].variant: {label:"YTHmut", description, is_wildtype:false}`.

### Categoria: co-culture

**#13 GSM6005157** `'iPSC microglia extracted from co-culture with motor neurons, WT, male, differentiation in co-culture with motor neurons for 14 days'` — sample è MICROGLIA, ma cresciute in co-culture con motor neurons. ⚠ NUOVO: la *compagnia di co-culture* (motor neurons) è informazione critica per la meta-analisi cross-studio. Proposta R10: `cell_context.co_culture_partners: [{cell_type, modifications, source_organism, role:"feeder"|"partner"|"target"}]`.

**#14 GSM3384121** `'PBMC, co-culture with prkcb-/- BMSC, venetoclax treated'` — TRIPLE: PBMC (sample) + cocultured con **mouse** BMSC knockout (prkcb-/-) + venetoclax (drug). Multi-organism nella stessa coppia di colture! La cellula partner è da specie diversa. R10 deve includere `source_organism` per il partner.

**#15 GSM5776152** `'hiPSC-derived midbrain DA + glutamatergic + GABAergic neurons + astrocytes co-culture, 0.2% DMSO'` — ⚠ NUOVO: 4 tipi cellulari nella stessa coltura → `cell_context.cell_type_or_line_raw` non basta. Serve `cell_context.cell_type_mixture: [{cell_type, fraction_estimate}]` o un campo `multiple_cell_types: true`. R10 esteso o nuovo R11.

**#16 GSM4074272** `'coculture, 4-Hydroxytamoxifen (TAM), 3D'` — ⚠ MEDIUM: 4-OHT è un **inducer** di Cre-ERT2 in molti sistemi inducibili Cre-loxP. In altri sistemi è un drug attivo (anti-estrogenico). Senza study summary lo Stadio 1 mette `kind=small_molecule, agent=4-OHT` con flag di ambiguità funzionale. Stadio 2 disambigua. ◐.

### Categoria: drug combinations

**#17 GSM5062406** `'Tumor, CD3+ T cells, treatment: POST, sorted: Live/Dead-CD14-CD20-CD45+CD3+'` — ⚠ "POST" è opaco (POST-treatment? POSTOP? Codice interno?) → Stadio 2 essenziale ◐. ⚠ NUOVO: i markers di **sorting** ("Live/Dead-CD14-CD20-CD45+CD3+") sono cruciali per identificare la sottopopolazione. Proposta R11: `cell_context.sort_markers: [...]`.

**#18 GSM5939650** `'On-treatment, Paclitaxel + Regorafenib, advanced esophagogastric cancer, group: Short_Survivor, response: SD'` — drug combination → `perturbations=[{paclitaxel}, {regorafenib}]` ✓. ⚠ NUOVO: metadati clinici (`response:"SD"`, `group:"Short_Survivor"`) sono **patient stratification info**, rilevanti per il raggruppamento (potresti voler poolare solo "Short_Survivor"). Proposta R12: `patient_metadata: {response, survival_group, age, sex, ...}` come campo opzionale strutturato.

**#19 GSM5361652** `'HSPCs, Lin-CD34+CD38-CD45RA-CD90+ HSPCs cultured in vitro for 72h'` — il "treatment" descrive il PROTOCOLLO di coltura; non c'è una vera perturbazione. v2 ⚠ ambiguo: `perturbations=[]` + `technical_treatments=[{kind:cell_culture_protocol, agent:"in_vitro_72h"}]`. Sort markers di nuovo (R11). Ambiguity flag `protocol_only_no_perturbation`.

**#20 GSM5292413** `'Meloxicam + Filgrastim, Female, mobilizer status: Poor, peripheral blood stem cells'` — drug combo + clinical phenotype (Poor mobilizer = clinical outcome label). Proposta R12 di nuovo (patient_metadata).

### Categoria: random discovery (sample 21–30)

**#21 GSM3565549** `'HCC1806, Abemaciclib 1uM 6h'` — clean, schema v2 ✓.

**#22 GSM5633030** `'iCell Hepatocytes, treatment: 175_VHGO_10, uvcb_class: VHGO, dose: 10'` — ⚠ NUOVO: codice opaco "175_VHGO_10" = ID interno di una collezione UVCB (Unknown/Variable Composition compounds, comune in toxicogenomics: petroleum products, polymers, ecc.). Lo Stadio 1 lascia `agent_normalized.id=null` e flag `compound_unmapped`. Ma `uvcb_class: VHGO` è un *raggruppamento parziale* utile. Proposta R13: `agent_normalized.collection: {name, id_in_collection}` per oggetti senza ID standard.

**#23 GSM5824357** `'DU145 xenograft, ALDH+, control, mouse strain: NMRI-Foxn1 nu/nu'` — ⚠ NUOVO: sample da xenograft → cellule **umane DU145** in **mouse host**. Lo schema v2 ha `organism` ma non distingue cell-origin organism dal host organism. Proposta R14: `host_organism` distinto. Inoltre R11 (sort marker ALDH+).

**#24 GSM5617268** `'BT549-Cdc25a, NO Dox, 48h'` — sistema inducibile NON indotto. ⚠ NUOVO: "NO Dox" è un **non-induction control** del sistema inducibile, distinto da "untreated" generale. Lo Stadio 2 lo classifica come `negative_inducer_control` o `untreated_control`? Il vocabolario `design_role` v2 non ha un valore specifico → proposta R15: aggiungere `negative_inducer_control` come `design_role`.

**#25 GSM4327443** `'Female, untreated, condition: non-SAA, Lin-CD34+, Bone Marrow, age 37'` — patient metadata (R12) + sort markers (R11) + condition (`non-SAA` = relativo a Severe Aplastic Anemia). `disease_state.status="comparison"` (è il control non-malato in un GSE caso/controllo SAA). v2 ✓ con R12.

**#26 GSM5636999** `'A375 Cells, 076_gasoline_100, uvcb_class: NAPTHA, dose: 100'` — toxicogenomics (gasoline come treatment!). R13 si applica. v2 ⚠ ma copribile.

**#27 GSM4329295** `'Male, untreated, Ctrl, Lin-CD34+, Bone marrow, age 14'` — analogo a #25.

**#28 GSM5666663** `'MCF7, knockout, HECTD1, time: 96'` — clean v2 ✓ (genetic_knockout HECTD1, MCF7, 96h).

**#29 GSM5309255** `'EBV de novo infection, ethanol'` — pathogen (EBV) + ethanol. v2: perturbations=[{kind:pathogen_or_aggregate_exposure, agent:EBV}, {kind:vehicle_only, agent:ethanol}]. ✓ Multiple perturbations gestite da R1.

**#30 GSM3537274** `'endometrial epithelial cells, ARID1A KO, Complete Growth Media'` — clean v2 ✓ (engineered_modifications crispr_stable ARID1A).

---

## Sintesi nuove revisioni R8–R15

| ID | Cosa | Da quali sample emerge | Priorità |
|---|---|---|---|
| **R8** | `perturbations[].mediated_effect: {kind, targets:[]}` per sistemi inducibili (Dox→OE, 4-OHT→Cre, etc.) — collega l'agente inducente all'effetto biologico vero | #10, #11, #12, #16, #24 | **Alta** (struttura) |
| **R9** | `engineered_modifications[].variant: {label, description, is_wildtype}` per distinguere WT vs mutant del transgene | #11 vs #12 | **Alta** (cross-studio) |
| **R10** | `cell_context.co_culture_partners: [{cell_type, modifications, source_organism, role}]` | #13, #14, #15 | **Alta** (struttura) |
| **R11** | `cell_context.sort_markers: [...]` (lista markers di sorting/enrichment) | #17, #19, #23, #25, #27 | **Alta** (sotto-popolazioni) |
| **R12** | `patient_metadata: {response, survival_group, age, sex, condition, donor_id, ...}` opzionale strutturato | #18, #20, #25, #27 | **Media** (clinical-grade) |
| **R13** | `agent_normalized.collection: {name, id_in_collection}` per UVCB / collezioni interne / codici opachi | #22, #26 | **Media** (toxicogenomics) |
| **R14** | `cell_context.host_organism` distinto da `organism` (cell-of-origin) | #23 (xenograft) | **Media** (in vivo studies) |
| **R15** | Aggiungere `negative_inducer_control` a vocabolario `design_role` (Stadio 2 §4.2) | #24 ("NO Dox") | **Bassa** (incremento) |
| **R16** | Nuovo vocabolario `cell_context.developmental_stage` o `differentiation_endpoint` per iPSC-derived/organoid endpoints | #2 (NP), #7 (beta-like), #9 (induced fibroblasts), #15 (DA neurons) | **Alta** (iPSC era) |
| **R17** | Nuovo `engineered_modifications[].kind = inducible_transgene` | #10, #11, #12 | **Bassa** (estensione vocab v2 §3.7) |
| **R18** | Espandere `cell_context.context_kind` per includere `tumor_extracted_cells` (TIL, tumor-infiltrating, sorted from tumor) o creare sotto-tipo | #1, #17 | **Bassa** (incremento vocab v2 §3.5) |
| **R19** | Espandere `agent_normalized.id_database` con `CAS` (Chemical Abstracts Service) | #3 | **Bassa** (incremento) |
| **R20** | Implicazione architettonica: la stringa input allo Stadio 1 va **arricchita** dai metadati GEO `organism_ch1` (e idealmente `source_name_ch1`, `title`), non solo `characteristics_ch1` come faceva il xlsx originale | tutto multi-organism | **Alta** (a monte del classificatore) |

**Su R20**: il xlsx storico ha solo la stringa concatenata da `characteristics_ch1`, ma GEO espone anche `organism_ch1`, `source_name_ch1`, `title`, `description`, e (a livello GSE) `summary` + `overall_design`. Lo Stadio 1 dovrebbe ricevere tutti i campi GEO sample-level rilevanti, non solo quello che era nel xlsx. Questo è un requirement per lo **stadio upstream di acquisizione** (separato dal classificatore — già flaggato in spec come scope rinviato).

## Cosa NON è emerso (lo schema v2 ha tenuto)

- L'architettura ibrida 2-stadi è ancora pienamente confermata. I sample con `treatment:"POST"`, `treatment:"175_VHGO_10"`, `cocultured with motor neurons` sono interpretabili solo con study summary.
- Il vocabolario `perturbation.kind` v2 copre la maggior parte dei kind reali. Sole estensioni minori (R17 inducible_transgene, R18 tumor_extracted).
- Il vocabolario `design_kind` regge sui casi visti.
- Il vocabolario `design_role` necessita una sola aggiunta (R15).
- `comparability_anchor` v2 (con context_kind, disease_status, has_engineered_baseline) regge — ma con R8 la "perturbation di interesse" da inserire nell'anchor diventa il `mediated_effect.target` se presente, non l'agent puro.

## Priorità e impatto sulle decisioni

**Schema v3 = v2 + (R8, R9, R10, R11, R16)** copre tutti i casi che si rompono in modo strutturale. Le restanti R12-R20 sono incrementali e possono essere applicate in modo non-breaking (campi opzionali, vocabolari estesi).

**Implicazione per l'architettura della pipeline:** R20 conferma che lo *stadio upstream* (acquisizione + parsing metadati) è prerequisito non rinviabile: senza arricchimento della stringa input, il classificatore opera su informazione povera. Da inserire come **prima** spec dopo questa.

**Convergenza:** dopo 30 + 10 = 40 sample, il tasso di nuovi problemi strutturali sta diminuendo (R1-R7 dal primo 10, R8-R11+R16 dal secondo 30 ≈ 5 strutturali / 30 sample contro 7 / 10 del primo). Lo schema sta convergendo. Un terzo dry-run su altri 30-50 sample probabilmente troverebbe solo casi di vocabolario.

## Prossimo step proposto

1. Applicare **R8, R9, R10, R11, R16** (le strutturali) come schema **stage1.v3**
2. Applicare R12-R20 come incrementali nello stesso commit
3. Spec arriva a **v5**
4. Decidere se fare un terzo dry-run o passare a `writing-plans`
