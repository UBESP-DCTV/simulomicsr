# Deep research — quale database per nominare le small molecule (Stadio 3)

Prompt pronto da incollare in un tool di deep research. Contesto incluso così la ricerca
è mirata al nostro caso d'uso reale.

---

## Prompt

> Sto costruendo una pipeline bioinformatica riproducibile (deliverable di un paper) che
> fa meta-analisi RNA-seq cross-studio. Per raggruppare studi confrontabili devo **dare un
> ID canonico** a menzioni testuali rumorose di **small molecule / farmaci** estratte dai
> metadati GEO (campi `characteristics_ch1`/`source_name_ch1`/`title`), del tipo
> `"osimertinib 2 um 9d"`, `"10 um enzalutamide and 30 nm onvansertib"`, `"GDC-0973"`,
> `"ABT-751"`, `"KW-2449"`. Uso già **ChEBI** (primario) e ho appena aggiunto **ChEMBL 37**
> (dump SQLite offline, alias→ID) come 2ª sorgente. Voglio capire, con evidenza, **quale/quali
> database** dovrei usare per massimizzare la copertura SENZA sacrificare la precisione.
>
> Vincoli del mio caso d'uso (rispondi tenendoli presenti):
> - **Dizionario OFFLINE nome→ID**: la pipeline fa ~1 milione di lookup deterministici contro
>   hash-table locali; NON posso usare API live (lente, rate-limited, non riproducibili). Mi
>   serve un **dump scaricabile in bulk** (tabelle nome/sinonimi→ID), non un servizio.
> - **Riproducibilità paper**: devo poter **redistribuire il dizionario derivato** come
>   supplementary. La **licenza** conta (ChEMBL è CC BY-SA; DrugBank ha redistribuzione limitata).
> - Il residuo che NON riesco a nominare è dominato da **composti da ricerca / preclinici**
>   (inibitori di chinasi, sigle-codice tipo GDC-/ABT-/AT-/KW-) e da farmaci clinici scritti
>   con dose/tempo/sinonimi. Le citochine/patogeni biologici (LPS, TNF, IFN, IL, TGF) sono un
>   problema separato (non small-molecule) — escludili o trattali a parte.
> - **Precisione prima della copertura**: in meta-analisi unire due composti diversi è peggio
>   che lasciarne uno "ignoto". Mi interessa anche **come** fare matching robusto-ma-preciso
>   di nomi rumorosi (normalizzazione, tokenizzazione, gating, evitare match su parole-classe
>   generiche come "acid"/"inhibitor").
>
> Confronta in modo fattuale (con numeri di copertura/dimensione dove disponibili, e con le
> fonti) almeno questi database, e segnalane altri rilevanti che mi sfuggono:
> **ChEMBL, DrugBank, PubChem (CID + sinonimi), RxNorm, DrugCentral, Guide to Pharmacology
> (IUPHAR/BPS GtoPdb), KEGG DRUG, UniChem (come hub di cross-reference), ChEBI** (già usato),
> e eventualmente **DrugBank Open Data / Open Targets / PubChem RDF**.
>
> Per ciascuno riporta, in una **tabella comparativa**:
> 1. **Copertura**: farmaci approvati vs composti da ricerca/preclinici; presenza dei
>    **research code** (GDC-0973, ABT-751…) come sinonimi.
> 2. **Sinonimi/alias**: quantità e qualità (brand, INN, USAN, codici); rumorosità (rischio di
>    falsi positivi da sinonimi ambigui — es. PubChem).
> 3. **Licenza** per redistribuzione di un dizionario derivato in un paper (aperta vs ristretta).
> 4. **Formato del dump bulk** scaricabile (SQLite/flat/RDF/XML) e dimensione; facilità di
>    estrarre una tabella nome→ID offline.
> 5. **Cross-reference** verso ChEBI/PubChem/InChIKey (per de-duplicare e canonicalizzare,
>    evitando che lo stesso composto prenda due ID da fonti diverse — UniChem è rilevante qui).
> 6. **Stabilità degli ID** e cadenza di aggiornamento.
>
> Poi dammi:
> - una **raccomandazione**: sorgente primaria + eventuali complementari, e in che ordine
>   interrogarle, per il MIO residuo (composti da ricerca + clinici con sigle-codice), con il
>   ragionamento;
> - **best practice e tool** noti per il **named-entity normalization di nomi di farmaci da
>   testo libero biomedico** verso ID canonici (es. approcci di normalizzazione/dizionario,
>   gestione di sinonimi ambigui, gating di precisione, eventuali risorse tipo PubChem
>   PUG/`OnSIDES`/`pubchempy`/`PubTator`/`tmChem`/`ChemListem` — valuta se rilevanti per un
>   dizionario OFFLINE);
> - eventuali **insidie** (es. InChIKey collision, sali/forme, racemi, sinonimi generici come
>   "acid"/"inhibitor"/"drug" che sono entità in alcune ontologie e causano merge spuri).
>
> Cita le fonti (pagine di documentazione/licenza/download dei DB, paper di benchmark di
> normalizzazione). Privilegia evidenza verificabile su affermazioni generiche.

---

## Note per quando arrivano i risultati
- Decisione attesa: confermare ChEMBL come primario o aggiungere una complementare (es.
  GtoPdb/DrugCentral per i research compounds, UniChem per i cross-ref a ChEBI).
- Collegare con il **gate di copertura** già fatto (Task 7: 63,4% recupero; residuo = sigle
  oscure + termini troppo rumorosi) per stimare quanto guadagnerebbe ogni fonte aggiuntiva.
- Questo è propedeutico a un eventuale **v6** (più copertura), DOPO il v5 (ChEMBL) e il
  TODO biologici. Non blocca il run v5.
