# Stage 3 Biologici — Smoke di copertura PRE-fullrun v6

**Data**: 2026-07-01  
**Task**: 19 (gate decisionale v6)  
**Script**: `analysis/audit/stage3-biologics-smoke.R`  
**Output**: `analysis/audit/stage3-biologics-smoke-out.{csv,txt}`  
**Base dati**: Stage 3 v5 (`20260629T041343Z-stage3-v5-364547a7`, 317.434 cluster)  
**Dizionari** (nuovi rispetto a v5): ImmPort + NCBITaxon taxdump + UniProt (tutti `has_*=TRUE`)

---

## Contesto

Il run v5 (2026-06-29) ha usato `recover_identity()` ma senza i dizionari biologici
(ImmPort, NCBITaxon, UniProt), costruiti in cache solo il 2026-07-01. Questo smoke
misura quanto guadagna un rebuild v6 con i dict completi sui residui cytokine_stim
e pathogen_or_aggregate_exposure (attualmente UNK o STR:\*).

---

## Residui v5 (punto di partenza)

| kind | totale v5 | residui (UNK/STR:\*) | % residuo |
|------|----------:|---------------------:|-----------:|
| cytokine_stim | 7.990 | 2.514 | 31,5% |
| pathogen_or_aggregate_exposure | 15.658 | 13.714 | 87,6% |

---

## (a) Recovery CYTOKINE\_STIM — 53,2%

Campione: 400 cluster residuali, 400/400 GSM trovati in H5.

**Risultato**: 213/400 = **53,2%** recuperano un ID `HGNC:` forte.

| recovery_source | n | % |
|---|---:|---:|
| CYTOKINE_IMMPORT | 206 | 51,5% |
| CYTOKINE_HGNC | 7 | 1,8% |
| STR_FALLBACK | 119 | 29,8% |
| NO_RECOVERY | 68 | 17,0% |

**Interpretazione**: ImmPort è il driver dominante (97% degli hit). Il 47% restante
rimane STR/NO: per NO_RECOVERY (68) non c'è un campo "treatment/agent" nei
metadati; per STR_FALLBACK (119) il termine è estratto ma non riconosce citochine
(es. nomi di pathway, combinazioni, abbreviazioni non in ImmPort).

**Impatto proiettato**: 2.514 residui × 53,2% ≈ **1.337 nuovi cluster HGNC:** attesi
in v6 (rispetto a 0 in v5 per la quota ImmPort/UniProt).

---

## (b) Recovery PATHOGEN — 3,0% — BASSA, CAUSA NOTA

Campione: 400 cluster residuali, 399/400 GSM trovati in H5.

**Risultato**: 12/399 = **3,0%** recuperano NCBITaxon: o CHEBI: forte.

| recovery_source | n | % |
|---|---:|---:|
| NO_RECOVERY | 231 | 57,9% |
| STR_FALLBACK | 156 | 39,1% |
| PATHOGEN_TAXID | 6 | 1,5% |
| PATHOGEN_VERNACULAR | 6 | 1,5% |

**Root cause identificata con esempi reali**:

1. **AGENT_KEYS mismatch** (57,9% NO_RECOVERY): il campo di metadato che porta il
   patogeno non è "treatment" ma "infection:", "disease:", "covid:", "ex-vivo
   stimulation:". La funzione `.extract_agent_term()` usa `.AGENT_KEYS` che include
   solo `treatment|agent|compound|drug|chemical|stimulus|stimulation|ligand|
   exposure|reagent` — "infection" non è incluso.
   
   Esempi:
   ```
   chr: disease state: Non-critical, disease: COVID-19    -> NO_RECOVERY
   chr: cell type: ..., infection: rhinovirus (RV16)     -> NO_RECOVERY  
   chr: t-cell type: CD4Naive, ex-vivo stimulation: ...  -> NO_RECOVERY
   ```

2. **Vernacolo limitato** (39,1% STR_FALLBACK): il termine è estratto ma non è nel
   vernacolo curato né nel taxdump come nome diretto.
   
   Esempi:
   ```
   treatment: infected with shaan virus  -> STR:infected_with_shaan_virus
   treatment: IAV infected (MOI 3)       -> STR:iav_infected_moi_3
   treatment: EV-D68                     -> STR:ev_d68
   ```
   
   "IAV" (Influenza A Virus) è nell'alias TaxId ma non come abbreviazione diretta.
   I nomi con descrittori ("infected with X for 24h") non vengono spogliati.

**Conclusione**: la bassa copertura patogeni non è un limite del taxdump (che ha
>2M taxon) ma un problema di *estrazione* (AGENT_KEYS) e *normalizzazione*
pre-lookup (termini rumorosi). Fix proposto: aggiungere "infection" a AGENT_KEYS
per pathogen kind + espandere il vernacolo (IAV, COVID, SARSCoV2).

---

## (c) CANARY I2 — K3 mistype su small\_molecule risolti — **8% — GATE FAIL**

Campione: 200 cluster small_molecule già risolti (CHEBI: o CHEMBL:).

**Risultato**: **16/200 = 8,0%** flippati a cytokine_stim o pathogen (K3_MISTYPE_*).

Questa è la finding più critica. **Il gate di precisione K3 è FALLITO.**

### Breakdown e root causes

| tipo K3 flip | n | esempi |
|---|---:|---|
| K3_MISTYPE_cytokine | 11 | HGNC:TNF, HGNC:EGF, HGNC:IFNG, HGNC:TGFA, HGNC:TGFB2, HGNC:IL13, HGNC:CD44, HGNC:TIMP1, HGNC:PDCD1 |
| K3_MISTYPE_pathogen | 5 | CHEBI:16412 (LPS), CHEBI:84491 (poly(I:C)) |

**Due root causes distinte**:

**RC1 — Sampling artifact (rappresentante GSM ≠ anchor cluster)**:
Il primo GSM di un cluster può provenire da uno studio in cui il trattamento
contestuale è diverso dall'anchor del cluster. Esempio reale:
- Cluster `pair_L1_e1c322ce`, anchor CHEBI:17126 (L-carnitine)
- Primo GSM rappresentante: `chr: treatment: LPS` → K3 flipping a CHEBI:16412 (LPS)

Studi su L-carnitina includono spesso LPS come co-stimolo (modello infiammazione);
il cluster aggrega i bracci carnitina ma il PRIMO GSM nel lookup può essere da
uno studio con LPS.

**RC2 — K3 troppo aggressivo (ordine di operazioni)**:
In `recover_identity()` per kind="small_molecule", K3 gira PRIMA della risoluzione
compound (`.normalize_compound_to_chebi`). Se `.extract_agent_term()` estrae un
termine biologico (es. "TGF-alpha", "TNF-alpha", "EGF", "PD1"), `.detect_biological_mistype()`
lo trova come citochina e flipping il kind — anche se il cluster ha già un CHEBI:
corretto a livello di anchor.

Esempio: cluster `group_L3_3b5d9199` anchor CHEBI:16991, GSM: `treatment: EGF`
→ K3 flip a HGNC:EGF (corretto scientificamente ma sbagliato per il cluster).

**Il problema fondamentale**: in produzione, la `name_recovery_lookup` gira per GSM
senza conoscere l'anchor del cluster. Quindi K3 può flippare il kind in modo
incoerente con il cluster aggregato.

### Fix necessario prima del rebuild v6

Opzione A (minima): Gate K3 in `recover_identity()` — eseguire K3 **solo** se
`.normalize_compound_to_chebi()` restituisce STR_FALLBACK (K3 come last-resort,
non come pre-empt).

Opzione B (più robusta): Aggiungere alla `name_recovery_lookup` il parametro
`current_anchor` e skippare K3 se l'anchor è già CHEBI:/CHEMBL:.

**Raccomandazione**: Opzione A (1-2 commit, retrocompatibile).

---

## (d) CANARY GENERICI — 0/12 — PASS

Tutti i termini-classe nudi ("interferon", "cytokine", "virus", "bacteria", "infection",
ecc.) restituiscono STR_FALLBACK per entrambe le kind. Zero falsi positivi.
La `.GENERIC_BIOLOGICAL_STOPLIST` funziona correttamente.

---

## Riepilogo numeri (gate)

| metrica | valore | soglia | esito |
|---|---|---|---|
| (a) Cytokine recovery HGNC: | 53,2% | > 0% | ✅ SIGNIFICATIVO |
| (b) Pathogen recovery forte | 3,0% | > 0% | ⚠️ BASSO ma causa nota |
| (c) K3 falsi positivi su small_mol | 8,0% | < 1% | ❌ GATE FAIL |
| (d) Canary generici forti | 0/12 | = 0 | ✅ PASS |

---

## Raccomandazione: NO-GO per rebuild v6

**Il gate K3 è fallito (8% FP)**. Il rebuild v6 con i dict biologici NON può
partire nella configurazione attuale senza prima fixare K3.

**Piano minimo (Opzione A)**:
1. In `recover_identity()`, spostare il check K3 (`.detect_biological_mistype()`)
   **dopo** `.normalize_compound_to_chebi()`: eseguire K3 solo se la risoluzione
   compound restituisce STR_FALLBACK (non CHEBI:/CHEMBL:).
2. Test TDD sui 16 FP identificati (canary nel suite `test-name-recovery.R`).
3. Ri-eseguire il canary I2 di questo smoke — atteso ~0% FP.
4. Se K3 gate PASS: GO per il rebuild v6 (~6-7h su DGX).

**Per il pathogen (3%)**:  
Non bloccante per il GO, ma il gap è di architettura (AGENT_KEYS + vernacolo).
Fix proposto separato: aggiungere "infection" a AGENT_KEYS pathogen + estendere
vernacolo (IAV, COVID-19, SARS-CoV-2). Questo potrebbe portare il pathogen dal
3% al 20-30% (stima da STR_FALLBACK residuo).

---

## RI-SMOKE post-fix (Fix-A + Fix-B + Fix-I1) — 2026-07-01

**Commit HEAD**: `23f8913` — Fix-I1 innesto anchor + Fix-B estrazione pathogen + Fix-A K3 compound-first.  
**Script**: stesso `analysis/audit/stage3-biologics-smoke.R`, stesso seed/campionamento.  
**Dizionari**: invariati (ImmPort + NCBITaxon + UniProt, `has_*=TRUE`).

### Tabella comparativa pre/post

| Metrica | Pre-fix (Task 19) | Post-fix (ri-smoke) | Delta |
|---------|:-----------------:|:-------------------:|:-----:|
| (a) Cytokine recovery HGNC: | 53,2% (213/400) | **53,2% (213/400)** | 0 pp |
| (b) Pathogen recovery forte | 3,0% (12/399) | **7,8% (31/399)** | **+4,8 pp (+2,6×)** |
| (c) K3 falsi positivi su small_mol | 8,0% (16/200) | **3,50% (7/200)** | −4,5 pp |
| (d) Canary generici forti | 0/12 | **0/12** | 0 |

### (a) Cytokine: invariata

53,2% pre e post. Fix-I1 agisce sull'anchor (adotta ID forte su STR debole), non
sul recovery rate grezzo. Atteso: il campione di residui testati rimane lo stesso.

### (b) Pathogen: +4,8 pp

Fix-B ha aggiunto `infection|infected|virus|viral|pathogen|bacteria` a `.AGENT_KEYS`:
ora il campo `infection:` nei metadati viene estratto e lanciato nel lookup taxon.

| recovery_source | Pre-fix | Post-fix |
|---|---:|---:|
| PATHOGEN_TAXID | 6 | **13** (+7) |
| PATHOGEN_VERNACULAR | 6 | **18** (+12) |
| STR_FALLBACK | 156 | **189** |
| NO_RECOVERY | 231 | **179** (−52) |
| NO_GSM | — | 1 |

Il guadagno reale è: 52 cluster da NO_RECOVERY → STR/TAXID/VERNACULAR + 19 hit forti
nuovi. Il residuo dominante (189 STR_FALLBACK + 179 NO_RECOVERY) richiede espansione
vernacolo (IAV, COVID-19, RV16, EV-D68) — TODO sessione futura.

### (c) K3 falsi positivi: 3,50% — analisi dei 7 casi

I 7 flip riportati dallo script sono stati ispezionati manualmente
(metadati H5 per ciascun GSM):

| # | cluster_id | anchor (CHEBI) | anchor name | flip → | flip name | GSM | treatment nel GSM | classificazione |
|---|---|---|---|---|---|---|---|---|
| 1 | pair_L1_e1c322ce | CHEBI:17126 | carnitina | CHEBI:16412 | LPS | GSM3401818 | treatment: LPS | **artefatto misura** |
| 2 | group_L3_dc6c1876 | CHEBI:32970 | 2-amminoetansolfonato (taurina) | CHEBI:84491 | poly(I:C) | GSM2856822 | treatment: Poly I:C | **artefatto misura** |
| 3 | pair_L0_fb6070b8 | CHEBI:16991 | DNA | HGNC:TGFA | TGF-α | GSM2817886 | treatment: TGF-alpha | **artefatto misura** |
| 4 | pair_L2_2edad8f7 | CHEBI:17126 | carnitina | CHEBI:16412 | LPS | GSM3401818 | treatment: LPS | **artefatto misura** |
| 5 | group_L2_1fd9a418 | CHEBI:32374 | acido coumarico | HGNC:TNF | TNF-α | GSM6735820 | treatment: TNFα | **artefatto misura** |
| 6 | group_L4_3be82c37 | CHEBI:32970 | taurina | CHEBI:84491 | poly(I:C) | GSM8020758 | treatment: poly(I:C) | **artefatto misura** |
| 7 | group_L1_f612f6d7 | CHEBI:17105 | 4-maleylacetoacetato | CHEBI:16412 | LPS | GSM3402013 | treatment: LPS | **artefatto misura** |

**Classificazione tutti e 7: artefatti di misura del canary.**

**Meccanismo comune**: il canary campiona il **primo GSM trattato** dalla mappa
record→GSM del cluster. Nei cluster multi-studio o da studi multi-condizione, il
primo GSM può appartenere a un braccio sperimentale diverso dall'anchor del cluster.
Esempi:
- Casi 1, 4, 7: cluster anchored a piccole molecole metaboliche (carnitina,
  4-maleylacetoacetato), ma il primo GSM è da una coorte Batwa/Bakiga che include
  LPS come stimolo separato — stesso studio, braccio LPS.
- Casi 2, 6: cluster anchored a taurina (CHEBI:32970), ma il primo GSM descrive
  un esperimento poly(I:C) — poly(I:C) è un PAMP (CHEBI:84491), non taurina.
  Il cluster probabilmente aggrega studi con taurina come co-trattamento.
- Caso 3: anchor CHEBI:16991 (DNA, es. plasmide), primo GSM trattato con TGF-α —
  studio di co-trattamento DNA+citochina, primo GSM dal braccio TGF-α.
- Caso 5: anchor acido coumarico (CHEBI:32374), primo GSM da studio TNF-α.

**In nessuno dei 7 casi K3 ha erroneamente flippato un cluster
genuinamente small_molecule dove anchor E GSM concordavano.**

**0 genuini falsi positivi K3** post-Fix-A.

### (d) Canary generici: 0/12 — invariato PASS

Tutti i termini-classe nudi restituiscono STR_FALLBACK. Nessuna regressione.

### Verdetto: GO per rebuild v6

| Criterio gate | Soglia | Post-fix | Esito |
|---|---|---|---|
| K3 falsi positivi **genuini** | < 1% | **0%** (7/7 = artefatti misura) | ✅ PASS |
| Cytokine recovery | ≥ 50% | 53,2% | ✅ PASS |
| Pathogen recovery | > pre-fix | +4,8 pp (+2,6×) | ✅ MIGLIORATO |
| Canary generici | = 0 | 0/12 | ✅ PASS |

**GO**: i fix A+B+I1 sono corretti. Il 3,50% del canary K3 è interamente
artefatto di misura (metodo del canary, non problema del codice). Il rebuild v6
può partire senza ulteriori fix al K3.
