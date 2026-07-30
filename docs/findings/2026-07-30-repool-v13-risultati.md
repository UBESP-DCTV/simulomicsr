# Re-pool v13: 191 meta-analisi poolate, e il pooling cambia la composizione di 3 gruppi su 4

**Data:** 2026-07-30 · **Branch:** `review-scientific-consistency-2026-06-10`
**Run:** `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296`
(wall **28h17m**, run_id `ac125296`)
**Stato:** 🟡 **Il deliverable è poolato e annotato. I² e τ² esistono. Non è "validato": vedi §6.**

---

## 1. Il run

Script `analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R`, lanciato con `setsid` (SID==PID),
`deliverable_methods = "rem_group"` (ADR-0026). Un solo errore, **non fatale e già noto**: il render
della dashboard quarto (binario assente). Tutti i deliverable DE sono stati scritti.

## 2. Verifica ANTI-STALE: passata su tutti i punti

Letta **dai file prodotti**, non dal log (`analysis/audit/2026-07-29-etichette-v13/50-antistale-v13.R`).

| controllo | esito |
|---|---|
| `Methods` contiene solo `rem_group` | ✅ 3.178.307 righe su 3.178.307 |
| `cluster_id` con prefisso `cgroup_L5_` | ✅ 191 su 191 |
| ~191 cluster poolati | ✅ **191**, e sono **esattamente** i 191 previsti (`setequal`, non un conteggio) |
| `k_effective` mai maggiore di `k` | ✅ zero casi; il `k` per cluster è **identico al previsto su tutti e 191**, somma 1.234 = 1.234 |
| 114 non poolati | un solo motivo: `rem_group_insufficient_in_study_controls` |

**La previsione fatta prima della fine del run ha centrato il risultato cluster per cluster.**

## 3. Il deliverable

| | |
|---|---:|
| meta-analisi poolate | **191** |
| righe poolate | 3.178.307 |
| geni significativi (FDR<0,05) | 315.037 |
| I² mediano fra i cluster | 73,2% |
| **righe con I² e τ² non NA** | **3.178.307 su 3.178.307** |

L'ultima riga è la differenza che contava. Il ramo `mega`, uscito dal deliverable con ADR-0026, aveva
`I2` e `tau2` **NA su tutte** le sue 1,75 M di righe e non poteva rispondere alla domanda «quanto sono
d'accordo gli studi?». Questo ramo può.

Bandiera (k previsto → reale): TGFB1 49→**49** (7.233 geni sig, I² 94) · LPS 35→**35** (6.883) ·
SARS 33→**33** (1.801) · enzalutamide 19→**19** (3.498) · vemurafenib 8→**8** (947).

Il cluster più grande (TGFB1, 49 studi) ha richiesto **59 minuti da solo**.

## 4. Il pooling cambia la composizione di 3 gruppi su 4

Il censimento aveva giudicato i **raggruppamenti**. Il pooling scarta gli studi senza controllo
interno, quindi un gruppo può entrare nel pool con meno studi di quelli letti. Misurato confrontando,
per ogni cluster, l'insieme degli studi poolati con quello degli studi assegnati:

| | |
|---|---:|
| gruppi con lo **stesso** insieme di studi | **45 (23,6%)** |
| gruppi che hanno perso studi | **146 (76,4%)** |
| studi persi in totale | **524** |
| gruppi con studi poolati mai censiti | 0 |
| frazione di studi tenuti, nei gruppi cambiati (mediana) | 0,71 |

**Il 96,9% di coerenza misurato prima del pooling non descriveva questi insiemi.** Per i 185 gruppi
coerenti il verdetto regge per un motivo logico, non per una nuova misura: la coerenza è **chiusa per
sottoinsiemi** — se tutti i confronti di un gruppo misurano lo stesso contrasto, lo fa anche un
qualunque sottoinsieme, e togliere studi non può introdurre eterogeneità di contrasto. Il gate
`k_eff≥3` su studi **distinti** esclude anche il caso degenere (un gruppo ridotto a un solo studio).
È un argomento, e va usato solo nella direzione che assolve.

Nella direzione opposta l'argomento non vale, quindi **i sei incoerenti sono stati riletti uno per
uno sui membri effettivamente poolati** (`70-rilettura-poolati.R` →
`rilettura-incoerenti-poolati.txt`).

## 5. Nessuno dei sei è assolto — e tre PEGGIORANO

Il gate del pooling non seleziona per correttezza biologica: seleziona per presenza di un controllo
interno. Può quindi **far cadere gli studi giusti e lasciare l'intruso**.

| gruppo | studi letti → poolati | esito |
|---|---:|---|
| **IFNA1** (`HGNC:5417`) | 6 → 3 | **peggiorato**: caduti quasi tutti gli IFN-α veri (GSE124810, GSE221804, GSE234424); resta GSE126517, che misura **R5020** (progestinico). L'intruso passa da 1 su 6 a **1 su 3** |
| **IL1A** (`HGNC:5991`) | 6 → 4 | **peggiorato**: caduti i due studi IL-1α veri (GSE120784, GSE142706); restano **entrambi** gli IL-1β (GSE155141; GSE205853 è per giunta IFN-γ+IL-1β). **2 su 4** misurano un'altra citochina |
| **IL3** (`HGNC:6011`) | 4 → 3 | **peggiorato**: caduto uno studio di IL-3 vera; resta GSE93620, dove `iL3` sono le **larve** infettive del nematode *A. ceylanicum*. **1 su 3** |
| influenza (`NCBITaxon:11320`) | 9 → 7 | resta: GSE113210 (`influenza at AV` → `Control CV`, sorveglianza clinica) è ancora dentro; il rapporto va da 1 su 9 a **1 su 7** |
| adenoma (`STR:adenoma`) | 4 → 3 | resta: caduto un adenoma del colon, ma ipofisario (GSE208107) e colon (GSE72820) restano insieme |
| «antigen» (`CHEBI:59132`) | 3 → 3 | **invariato**, provato: stesso insieme di membri. Entità che è una classe-ombrello |

**Coerenza del deliverable poolato: 185 / 191 = 96,9%** — stessa percentuale di prima, ma ora
riferita agli insiemi veri, e con i motivi riscritti su ciò che c'è dentro (i motivi del censimento
citavano numeri che non descrivono più questi gruppi).

Questo è un **fatto nuovo sul metodo**, non solo su sei gruppi: il gate dei controlli interni e la
correttezza dell'entità sono indipendenti, e la loro combinazione può concentrare l'errore invece di
diluirlo. Va nei Methods.

## 5bis. RITRATTAZIONE — il censimento giudicava su etichette TRONCATE

**Il bundle di lettura del censimento tagliava le etichette a 58 caratteri sul trattato e 40 sul
controllo** (`10-bundle-v13.R:112`). Su un confronto il pezzo tagliato conteneva l'informazione
decisiva, e ho dato un verdetto su mezza frase:

| | |
|---|---|
| letto | `T47D ... treated with R5020 for 6 ho…` |
| **testo intero** | `T47D ... treated with R5020 for 6 hours AND IFN-alpha for 18 hours` → `... EtOH for 6 hours and water for 18 hours` |

Il verdetto «GSE126517 misura R5020, non interferone» **è ritrattato**: l'interferone c'è, e il
controllo ha entrambi i veicoli (etanolo per R5020, acqua per l'interferone). Quel confronto misura
la **combinazione** R5020+IFN-α, mentre gli altri due studi del gruppo misurano IFN-α da solo: il
gruppo resta incoerente, ma per **combinazione non catturata** — categoria già nota e dichiarata —
non perché un membro misuri un'altra entità. Lo stesso studio compare correttamente nel gruppo
`STR:r5020` col braccio R5020 puro: la pipeline aveva letto bene il disegno fattoriale, e l'errore
era mio.

**Ampiezza del difetto, misurata:**

| | |
|---|---:|
| confronti con almeno un lato tagliato | 462 su 5.398 (**8,6%**) |
| gruppi censiti (305) con almeno un membro tagliato | **134 (44%)** |
| **fra i 191 poolati** | **99 (52%)** |
| fra i 63 riletti uno per uno nel censimento v13 | 38 |

**Rilettura dei 99 col testo intero** (`90-bundle-intero.R` → `bundle-intero-99.txt`, letti tutti):

- **zero verdetti ribaltati**: nessun gruppo giudicato coerente diventa incoerente;
- 96 confermati coerenti, 3 confermati incoerenti (influenza, IL3, IFNA1);
- **un motivo ritrattato** (IFNA1, sopra).

I 92 gruppi poolati **senza** etichette tagliate non sono stati rigenerati: il loro verdetto poggiava
già su testo intero.

**La lezione, che vale più del singolo caso.** In due giorni tre strumenti di misura scritti da me
sono stati ciechi, sempre allo stesso modo: il filtro sugli alias dava per buono il caso `LTA` da cui
era nato; la normalizzazione cancellava le lettere greche e faceva sparire `IL-1β`; il bundle tagliava
le etichette. In tutti e tre i casi **lo strumento vedeva meno del dato**. È un principio che si può
scrivere prima di conoscere la biologia — *prima di giudicare, verifica che lo strumento veda il dato
per intero* — con accanto un controllo banale (quante stringhe toccano il limite?) che li avrebbe
fatti saltare fuori subito.

## 6. Che cosa questo NON dimostra

- **Non è una validazione biologica.** I 191 gruppi hanno I², τ² e geni significativi; nessuno ha
  ancora guardato se i geni che escono sono quelli attesi. È il passo successivo (Layer B).
- **Il 96,9% resta un giudizio di lettura**, ripetibile da un umano sugli stessi bundle, non
  l'output di una regola.
- **99 dei 185 coerenti sono stati riletti sui membri poolati, col testo intero** (§5bis); per gli
  altri 92 il verdetto poggia sull'argomento di chiusura per sottoinsiemi del §4 e su testo che non
  era troncato.
- **La rilettura ha trovato difetti che non cambiano il verdetto ma vanno detti**: membri che
  misurano una combinazione anziché l'entità sola (TGF-β1+ipossia, metformina+lisato di M.tb,
  5-FU/leucovorina, EPZ5676+altri tre farmaci), e confronti appaiati male — `LAPC4_ENZA` contro
  `VCaP_DMSO` (linea diversa), `human heart, SARS-CoV-2 infected person` contro `human ES-derived
  macrophage` (materiale diverso), aspirina `visit 2` contro `visit 1`. Sono le categorie che le
  regole di riga del 2026-07-26 dovevano intercettare: che siano nel deliverable va verificato a
  parte.
- **Le etichette sono corrette, non tutte leggibili**: restano i nomi sistematici ChEBI e gli 11
  patogeni con il nome normalizzato senza spazi (finding del 2026-07-29, §4).

## 7. Il deliverable annotato

`analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv` (e `.rds`): una riga per
meta-analisi, con `contrast_entity_label` (etichetta risolta dall'ID) accanto a `canonical_name`
(nome vecchio, mai sovrascritto), `coherence_verdict` / `coherence_reason` / `coherence_source`,
`k_effective`, `n_sig`, `I2_med`, più `n_studi_censiti`, `n_studi_poolati`, `stessi_membri` e
`studi_caduti`.

Codice di pacchetto usato: `R/stage3-entity-label.R` e `R/stage4-coherence-annotation.R`
(**131 test PASS / 0 FAIL** sul perimetro toccato, scritti prima dell'implementazione).

I tre verdetti riferiti a gruppi che il gate ha scartato (Recurrence, CSF2, PTSD) sono stati tolti
**esplicitamente**, non allentando il controllo che ferma la marcatura quando un verdetto resta
orfano.

## 7bis. Il controllo biologico: PASSA, e sul test più severo

Finora nessuno aveva mai verificato che i geni che escono siano quelli giusti. Sei gruppi con attese
note dalla letteratura, geni scelti **prima** di guardare i risultati:

| gruppo | k | geni attesi | esito |
|---|---:|---|---|
| LPS | 35 | TNF, IL6, IL1B, CXCL8, CCL2, NFKBIA | tutti **su**, tutti FDR<0,01 |
| TGF-β1 | 49 | SERPINE1, CCN2, SMAD7, JUNB, TGFBI, COL1A1 | tutti **su** (SERPINE1 +2,43; TGFBI +2,00) |
| SARS-CoV-2 | 33 | IFIT1, ISG15, IFIT3, CXCL10, OAS1, MX1 | tutti **su** — risposta interferone |
| IFN-γ | 19 | GBP1, CXCL9, CXCL10, STAT1, IDO1, GBP5 | tutti **su** (CXCL9 +11,17; IDO1 +9,76) |
| **DHT** (agonista AR) | 23 | KLK3, TMPRSS2, FKBP5, NKX3-1 | **+2,27 +1,78 +2,32 +1,37** |
| **enzalutamide** (antagonista AR) | 19 | gli stessi quattro | **−1,60 −0,92 −1,22 −1,24** |

L'ultima coppia è la prova decisiva: **agonista e antagonista dello stesso recettore danno effetti di
segno opposto sugli stessi bersagli**, misurati da studi diversi in due gruppi costruiti
indipendentemente. Nessun difetto strutturale può produrre questo per caso.

Da riportare accanto: gli I² di questi geni stanno fra 94 e 100. Gli studi concordano sul **segno**,
non sulla **magnitudine** — che è quanto un random-effects deve dichiarare, non nascondere.

## 7ter. Le regole di riga non coprono passaggio, visita ed etnia

Verificato applicando `.rp_row_defect` (le regole in produzione dal 2026-07-26) ai difetti di
appaiamento visti leggendo i 99: **nessuno dei sei viene segnalato** — `LAPC4_ENZA` contro
`VCaP_DMSO` (linea diversa), aspirina `visit 2` contro `visit 1`, cuore di paziente COVID contro
macrofago da staminali, TGF-β1 `(Chinese)` contro controllo `(Malay)`, `Passage 24` contro
`Passage 6`, TNF `finger` contro `knee`. Non è una regressione: quelle forme non sono coperte.

Misura esatta di ciò che si può contare senza ambiguità (numero estratto e confrontato):

| | confronti | gruppi |
|---|---:|---:|
| `passage` diverso fra i bracci | 18 | 2 (Nutlin-3, TGF-β1) |
| `visit` diversa | 4 | 1 (aspirina) |
| `donor` diverso | 16 | 9 |
| **totale** | **38 su 4.452 (0,85%)** | 12 su 191 |

**I 16 "donatore diverso" non sono difetti**: sono quasi tutti caso-controllo di malattia
(schizofrenia, RCC, diabete di tipo 1, psoriasi, cheloide, diabete gestazionale, HCC), dove donatori
diversi sono obbligatori — lo stesso punto già chiarito il 2026-07-25. Restano **~22 difetti veri
(0,5%) in 4 gruppi**. Etnia, sede anatomica e tipo cellulare diversi **non sono stati misurati**:
servirebbe un vocabolario, e un rilevatore improvvisato qui costa più di quanto renda.

Tabella: `analysis/audit/2026-07-29-etichette-v13/appaiamenti-numero-diverso.csv`.

## 7quater. Etichette leggibili

`R/stage3-entity-label.R` ora ha `.display_entity_label()`: applica le scelte umane curate in
**`inst/extdata/entity-label-overrides.csv`** (dati, non codice — è una decisione, non una regola) e
converte gli underscore delle entità `STR:` in spazi. Test:
`tests/testthat/test-stage3-entity-label-display.R` (**13 PASS / 0 FAIL**).

21 etichette curate su 191: gli 11 patogeni (`severeacuterespiratorysyndromecoronavirus2` →
**SARS-CoV-2**, `humanbetaherpesvirus5` → **HCMV**), i nomi sistematici ChEBI
(`17β-hydroxy-5α-androstan-3-one` → **DHT**, `17β-hydroxy-17-methylestra-4,9,11-trien-3-one` →
**R1881**, il nome da 104 caratteri → **SAG**), e **i due identificativi difettosi del §2, marcati
nell'etichetta stessa**: `CHEBI:73572` → «lipoteichoic acid (LTA) — ID ERRATO», `HGNC:1653` →
«anti-CD3/CD28 stimulation». Ogni override porta con sé la sua `nota`, così chi legge sa perché.

## 8. Riproducibilità

`analysis/audit/2026-07-29-etichette-v13/`: `50-antistale-v13.R` · `60-deliverable-annotato.R` →
`deliverable-v13-poolato.{csv,rds}` · `70-rilettura-poolati.R` →
`rilettura-incoerenti-poolati.txt` · `verdetti-poolato-v13.csv` (i motivi riletti).
Finding del giorno prima: `docs/findings/2026-07-29-etichette-identita-e-gate-del-pooling.md`.
