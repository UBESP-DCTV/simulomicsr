# Censimento del deliverable v12 sui dati VERI: 297 gruppi coerenti su 312, letti uno per uno

**Data:** 2026-07-28 · **Branch:** `review-scientific-consistency-2026-06-10`
**Sorgente:** `analysis/p4-output/20260727T204316Z-stage3-v12-364547a7` (re-cluster eseguito, 8h45m)
**Stato:** 🟡 **Primo censimento su output di pipeline vero, non su simulazione. Nessun re-pool:
il deliverable non e ancora poolato.**

---

## 1. Perche questo censimento

Il re-cluster v12 ha materializzato l'ancoraggio dal-contrasto (ADR-0025). Il deliverable che ne
esce e di **312 gruppi**, non i 144 misurati in simulazione: 187 di essi (**il 60%**) non erano mai
stati letti da nessuno. Il 97,2% di coerenza della simulazione valeva su un altro insieme.

Portare al re-pool (~50 ore) un deliverable per il 60% non verificato sarebbe stato ripetere
l'errore che questo progetto ha gia fatto per mesi. L'utente ha scelto di censire prima.

**Criterio** (definizione utente, 2026-07-24): un gruppo e coerente se **tutti** i confronti che
contiene misurano lo **stesso** contrasto. La forza (k, I²) si riporta accanto, non e il gate.
**Il tessuto non entra nella chiave** e non e di per se un difetto (ADR-0025 §Negative): stesso
metro del censimento del 2026-07-27, altrimenti i numeri non sono confrontabili.

**Metodo:** un bundle per gruppo con l'identita del contrasto e ogni confronto tenuto (studio,
trattato ⇒ controllo, coi `factor_levels` dei due bracci), letti tutti — 312 su 312.
Riproducibile: `analysis/audit/2026-07-28-censimento-v12/`.

## 2. Esito

| | |
|---|---:|
| gruppi del deliverable (dopo dedup Stadio 4) | **312** |
| **coerenti** | **297 (95,2%)** |
| incoerenti | **15 (4,8%)** |
| confronti totali | 5.110 |
| studi-slot (somma k) | 2.076 |

**Confronto onesto con la simulazione:** 97,2% su 144 → **95,2% su 312**. La percentuale scende di
2 punti, ma il numero assoluto di gruppi coerenti passa da 140 a 297. La frequenza di incoerenza e
praticamente la stessa nei due sottoinsiemi: **8 su 187** fra i gruppi nuovi (4,3%), **7 su 125**
fra quelli gia letti (5,6%).

**Tre gruppi giudicati coerenti il 2026-07-27 sono oggi incoerenti** (influenza, HIV-1, adenoma):
non e cambiato il metro, e cambiata la loro composizione — il builder gira su tutti i confronti
dello Stadio 2 e ha aggiunto membri che prima non c'erano. Va detto, non nascosto.

## 3. I quindici incoerenti

Tabella completa con il motivo per ognuno: `analysis/audit/2026-07-28-censimento-v12/verdetti.csv`.
Si raggruppano in **cinque meccanismi**, non quindici casi isolati:

| meccanismo | gruppi | esempio |
|---|---|---|
| **clinico vs sperimentale** | influenza, HIV-1 | pazienti positivi contro controlli sani, insieme a cellule infettate contro mock |
| **l'entita e una classe, non una molecola** | `cytokine_stimulation`, U0126, `affected` | 'inibitori MAPK' raccoglie inibitori di MEK, ERK e JNK |
| **l'entita e un reagente, non la biologia** | auxina (×2), dTAGv-1 | l'induttore del degron e comune, la proteina degradata e diversa in ogni studio |
| **direzioni opposte sotto lo stesso verso** | TP53 | knockout e sovraespressione nella stessa meta-analisi |
| **residui gia noti** | CSF2, PTSD, Recurrence, adenoma, IL3, `2_gram` | polarizzazione M1/M0; perturbazione dentro-malattia; sigla che collide (`iL3` = larve di nematode) |

I primi tre meccanismi sono **generalizzabili** e si potrebbero chiudere con regole, non con liste:
(a) l'asse clinico/sperimentale esiste gia nel gate ma non scatta quando il controllo clinico non usa
le parole del vocabolario; (b) i nomi di classe ('inhibitors', 'cytokines') si riconoscono; (c) gli
induttori hanno gia una blacklist (`.cg_is_inducer`, doxiciclina) a cui mancano auxina e dTAG.

**Non le ho scritte.** Cambiare il gate ora significa un altro re-cluster da 8h45m, ed e una
decisione dell'utente. Le riporto quantificate: chiuderebbero **7 dei 15** (influenza, HIV-1,
cytokine_stimulation, U0126, IAA, auxina, dTAGv-1), portando il deliverable a **304/312 = 97,4%**.

## 4. Un difetto di identita trovato e misurato: entita presente su entrambi i bracci

Leggendo il gruppo TGFB1 ho trovato `GSE233083: "TGF-β1 + 3C" ⇒ "TGF-β1 + DMSO"`. TGF-β1 sta su
**entrambi** i lati: quel confronto misura 3C, non TGF-β1.

**Causa provata** (caso minimale riproducibile, `20-ispeziona.R`): `.ca_combo_from_labels()` calcola
correttamente gli agenti del trattato assenti dal controllo, ma usa il risultato **solo se ne restano
≥2**; con uno solo l'informazione viene buttata e l'entita si risolve dal valore intero, che ripesca
la parte comune. `3C` per giunta viene scartato dalla soglia dei 3 caratteri alfanumerici.

**Impatto misurato su tutto il deliverable: 1 confronto su 4.954.** La ricerca strutturale del pattern
`X + A` contro `X + B` trova 3 casi, di cui 2 corretti (`TGFb1 + Vehicle` ⇒ `vehicle`: il residuo e
davvero TGF-β1). Difetto reale, impatto trascurabile, **non corretto**: la correzione richiede un
re-cluster.

⚠️ **Due metri sbagliati prima di quello giusto.** Il primo rilevatore ri-tokenizzava il controllo a
mano e non trovava nemmeno il caso di partenza (la beta greca sparisce, `tgf` non risolve): dava
0,2%, un limite inferiore prodotto da uno strumento cieco. Il secondo applicava il resolver al lato
controllo e lo mancava lo stesso (aggancia DMSO). Solo il terzo, strutturale, ha misurato davvero.
**Ho riportato solo l'ultimo perche gli altri due erano sbagliati, non perche davano il numero che
preferivo.**

## 5. Le etichette sono sbagliate su decine di gruppi — gli ID no

Il campo mostrato come nome del gruppo e inaffidabile in modo sistematico:

| ID (corretto) | nome mostrato | cos'e davvero |
|---|---|---|
| CHEBI:63637 | sodium aurothiomalate | vemurafenib |
| CHEBI:85993 | PI(18:0/18:3(6Z,9Z,12Z)) | palbociclib |
| CHEBI:137113 | D-cycloserine(1+) | JQ1 |
| CHEBI:27899 | 2,2',3,4',5,5'-Hexachloro-4-biphenylol | cisplatino |
| CHEBI:50131 | 2,3,4,5-Tetrachloro-4'-biphenylol | decitabina |
| HGNC:5973 | IL5RA | IL13 |
| MeSH:D008180 | cancer | lupus eritematoso sistemico |

**Verificato coi resolver: gli ID sono tutti giusti** (`vemurafenib → CHEBI:63637`, ecc.). Sbagliata
e solo l'etichetta, che il cluster eredita dall'anchor vecchio invece di risolverla dall'entita del
contrasto. Non tocca la validita scientifica, ma **va corretto prima del paper**: le etichette delle
meta-analisi vanno prese risolvendo `contrast_entity`, non leggendo `canonical_name`.

## 6. Frammentazione: potenza buttata, non incoerenza

Sedici entita compaiono in due o piu gruppi (`frammentazione.csv`). I gruppi sono internamente
coerenti — non e un difetto di validita — ma la meta-analisi e spezzata:

- **TGF-β1 in quattro gruppi** (61 + 11 + 3 + 3 = 78 studi-slot);
- **nutlin-3a in tre** (10 + 6 + 5), con **due ID ChEBI diversi** per la stessa molecola;
- **TNF-α in due** (38 + 7), uno con l'ID del gene e uno con l'ID ChEMBL della proteina ricombinante;
- **interferone alfa in tre** (5 + 3 + 3).

Due cause distinte: **scritture che il resolver non riconosce** (`TGFb`, `ATRA`, `1,25(OH)2D3`) e
**tipi di controllo che il gate tiene separati pur essendo lo stesso controllo** (`vehicle_untreated`
vs `no treatment` vs `unstimulated` vs `RPMI media`). La seconda causa e la piu facile da chiudere e
da sola recupererebbe DHT 27→30, LPS 41→44, IFN-γ 30→33, TGFB1 61→64.

## 7. Che cosa questo NON dimostra

- **Non e una validazione del pooling.** I gruppi non sono ancora poolati: I², τ² e i geni
  significativi non esistono. Il re-pool (~50 h) e dietro un GO dell'utente.
- **I verdetti sono giudizi di lettura**, ripetibili da un umano che legge gli stessi bundle, non
  l'output di una regola deterministica.
- **Il 95,2% non e un risultato finale**: e la coerenza dei raggruppamenti, misurata prima del
  pooling. Se il re-pool scartasse membri per ragioni sue, andrebbe rimisurata.
- **Nessuna delle regole proposte al §3 e stata scritta.** Il gate e quello che ha girato.

## 8. Riproducibilita

`analysis/audit/2026-07-28-censimento-v12/`:
`10-bundle.R` / `11-bundle-compatto.R` → `bundle-v12-compatto.txt` (5.903 righe, il file letto) ·
`20-ispeziona.R` (un confronto cogli argomenti veri del build) ·
`30-entita-su-entrambi.R`, `31-entita-simmetrica.R` (i due metri sbagliati, conservati) ·
`verdetti.csv` (i 15 incoerenti col motivo) · `frammentazione.csv` (le 16 entita spezzate) ·
`indice-v12.csv` (tutti i 312 con k, n, e se erano gia stati letti).
