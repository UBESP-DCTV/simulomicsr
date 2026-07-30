# Layer B v13: i case study esistono, e guardarli ha trovato tre cose che i numeri aggregati non dicevano

**Data:** 2026-07-31 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Build:** `analysis/p4-output/20260730T160606Z-layer-b-c279e308` (12 bundle, 72 figure, wall **10,0 min**)
**Stato:** 🟡 **Il materiale guardabile esiste. Le stime poolate reggono. Due delle figure — la
tabella dei top geni e la heatmap — NON mostrano quello che il lettore penserebbe, e uno dei due
case study di malattia non regge.**

---

## 1. Che cosa è stato costruito

12 case study sui 191 gruppi poolati di v13, tutti `rem_group`, tutti `mode=cgroup` (ADR-0025):

| dove | case study |
|---|---|
| main paper | DHT (k=23) · enzalutamide (k=19) · **entrambi** i candidati ad alto k: TGF-β1 (k=49) e LPS (k=35) |
| supplementari | SARS-CoV-2 (k=33) · IFN-γ (k=19) · JQ1 (k=24) · **entrambi** i candidati malattia: Parkinson (k=10) e carcinoma epatocellulare (k=9) |
| incoerenti dichiarati | IL1A (k=4) · IFNA1 (k=3) · «antigen» (k=3) |

I due doppioni (TGF-β1/LPS, Parkinson/HCC) sono stati costruiti entrambi **perché la scelta fra i
due era aperta e il costo di costruirli tutti e due è di due minuti**. La decisione resta dell'utente,
ma ora poggia sulle figure invece che sul k.

Ogni bundle: volcano, forest, MA, heatmap, pannello di eterogeneità, arricchimento GO, tabella dei
top 30 geni, summary card, stub della narrativa. Più un report HTML unico da 23,8 MB con **75
immagini incorporate e zero riferimenti esterni** (verificato, non assunto).

## 2. Due difetti della macchina, trovati PRIMA di lanciarla

L'handout chiedeva di verificare i percorsi e il dispatch `rem_group`. La verifica ne ha trovati due
che l'handout non prevedeva, entrambi dovuti al fatto che la macchina Layer B è **anteriore ad
ADR-0025**:

1. **L'anchor dei cluster v13 non è parsabile dal codice esistente.** `anchor_key` per `mode=cgroup`
   ha **tre** segmenti (`entità||verso||tipo-di-controllo`), non i 13 dell'anchor canonico v3.
   `extract_anchor_summary()` non crasha: restituisce `NA` su tutti i campi. Ogni summary card
   avrebbe scritto `Anchor: ? x ? (tissue=?)`. Fallimento silenzioso, misurato. Ora l'anchor si
   costruisce dalle colonne del contrasto, con una guardia che **ferma il build** se un cluster della
   selezione resta senza anchor.
2. **`canonical_name` per il DHT dice «4-maleylacetoacetate».** L'etichetta delle figure viene dal CSV
   di selezione (`label_paper`), non da `canonical_name` — verificato leggendo il codice, non
   supposto. Il CSV è **generato dal deliverable annotato** (`10-selection.R`), così k, n_sig, I² e
   verdetto di coerenza vengono dal dato e non da una trascrizione.

Il fix `rem_group` del 2026-07-23 (forest, eterogeneità, summary card) è invece già nel codice di
pacchetto ed è stato riverificato.

**Pre-flight, 5 controlli su 12 cluster, tutti passati** (`20-preflight.R`): esistenza nel Layer A ·
method `rem_group` su tutte le 220.493 righe · dispatch che risolve 12/12 · **numero di studi risolti
== k del deliverable == max `k_effective` del pool su tutti e 12** · 3.146 campioni tutti presenti
nell'asse H5.

⚠️ **Un mio errore di misura, corretto prima di usarlo.** La prima versione del controllo confrontava
il dispatch con un `k_effective` pescato con `match()`: `k_effective` in `cluster_pooled` è
**per-gene**, e 12 cluster danno 219 combinazioni distinte. Sei cluster risultavano "disallineati" per
colpa del metro, non del dato.

## 3. La biologia regge: 32 bersagli attesi su 32

Geni scelti dalla letteratura **prima** di guardare, gli stessi del controllo del 2026-07-30. Rango
sull'ordinamento per FDR:

| gruppo | bersagli | esito |
|---|---|---|
| DHT | KLK3, TMPRSS2, FKBP5, NKX3-1 | tutti **su**, ranghi 152–484 su 19.186 |
| enzalutamide | gli stessi quattro | tutti **giù**, ranghi 179–1.009 su 18.452 |
| TGF-β1 | SERPINE1, CCN2, SMAD7, JUNB, TGFBI, COL1A1 | tutti su, ranghi 26–649, **tutti a k=48-49 su 49** |
| LPS | TNF, IL6, IL1B, CXCL8, CCL2, NFKBIA | tutti su, ranghi 6–429, k=20-35 |
| SARS-CoV-2 | IFIT1, ISG15, IFIT3, CXCL10, OAS1, MX1 | tutti su, ranghi 53–471 |
| IFN-γ | GBP1, CXCL9, CXCL10, STAT1, IDO1, GBP5 | tutti su, ranghi 10–91 |

**32 su 32 presenti, segno corretto, tutti nel 5% più significativo.** L'arricchimento GO conferma
in modo indipendente: IFN-γ dà «response to type II interferon» (letteralmente sé stesso),
enzalutamide dà biogenesi ribosomiale e replicazione del DNA (blocco proliferativo da AR spento),
DHT dà biosintesi del colesterolo e degli steroli (il programma lipogenico noto a valle di AR).

## 4. FINDING 1 — la tabella dei top geni e la heatmap non mostrano l'effetto, mostrano dove τ² è caduto a zero

La tabella dei top 30 geni è ordinata per FDR. Guardando il bundle DHT: i primi tre sono AFP (k=5),
KRT72 (k=6), COL22A1 (k=2), **su 23 studi**. I bersagli veri dell'androgeno stanno dal rango 152 in
poi. Misurato su tutti e 12 e sul meccanismo, non sull'impressione:

| | |
|---|---|
| **il meccanismo** | con k basso il random-effects non riesce a stimare τ², lo pone a **0**, l'errore standard collassa e l'FDR precipita. Su SARS-CoV-2: SE mediano **0,554 a k=2** contro **0,088 a k=21-33**; τ²=0 nel **56,6%** dei geni a k=2 contro **0%** a k≥21. **Nove dei primi dieci geni per FDR hanno τ²=0 e I²=0.** |
| **quanto pesa sui primi 20** | SARS-CoV-2: k mediano dei primi 20 = **6,5 su 33**, e **20 su 20** stanno sotto metà del k pieno. JQ1 3,5 su 24 (15/20). IFN-γ **3 su 19** (15/20). |
| **quanto pesa sul totale** | poco, ed è la parte rassicurante: i geni significativi a k=2 sono **0,7–3,2%** nei gruppi grandi (16,7% in HCC, 35,5% in «antigen»). Fra il 43% e il 71% dei geni significativi sta al **k pieno**. |

**Il difetto è nella selezione dei 30 da mostrare, non nelle stime.**

E si propaga alla heatmap, per una catena che è stata verificata passo per passo:

> k basso → τ²=0 → FDR minuscolo → il gene entra nei top 30 → ma è un gene **espresso a zero nella
> maggior parte dei campioni** → ComBat lo salta esplicitamente («genes with uniform expression
> within a single batch (all zeros); these will not be adjusted») → nella heatmap quella riga resta
> segnale di studio puro.

Geni dei top 30 con oltre metà dei campioni a conteggio zero: **DHT 8/30, enzalutamide 7/30,
IFN-γ 16/30**, TGF-β1 3/30.

⚠️ **Qui ho corretto una mia conclusione prima di scriverla.** Misurando sul log-CPM grezzo, lo
studio spiegava il 55–84% della varianza e il trattamento l'1–8%: sembrava che la heatmap mostrasse
batch ovunque. Ma la heatmap applica **VST + ComBat**, e misurare a monte della correzione misura
un'altra cosa. Rifatta sulla catena vera:

| gruppo | R² studio pre-ComBat | **post-ComBat** | R² trattamento |
|---|---:|---:|---:|
| TGF-β1 | 0,55 | **0,03** | 0,24 |
| DHT | 0,82 | **0,02** | 0,14 |
| enzalutamide | 0,69 | **0,01** | 0,05 |
| **IFN-γ** | 0,84 | **0,82** | **0,01** |

**ComBat funziona in tre casi su quattro.** Il fallimento è mirato: in IFN-γ, dove 16 dei 30 geni
sono quasi tutti zero, ComBat non può correggere e la heatmap resta una mappa degli studi.

**Conseguenza pratica**: la tabella dei top geni e la heatmap vanno filtrate per k (e per espressione
minima) prima di finire in un paper. È un cambiamento al `layer_b_default_config()`, **non fatto**:
è una decisione dell'utente.

## 5. FINDING 2 — 105 delle 191 meta-analisi sono dominate da un solo studio

Misurato su **tutti e 191**, non su un campione. Il peso di uno studio su un gene in un random-effects
è `1/(SE²+τ²)`; il numero efficace di studi è quello di Kish, `(Σw)²/Σw²`. Calcolato sui geni
significativi, **dopo il collasso dei bracci dentro lo studio** — l'unità su cui gira davvero il REM.

⚠️ **Secondo mio errore di misura, corretto.** La prima versione pesava i **bracci**: `per_study_de`
ha una riga per braccio, e TGF-β1 ne ha 83 per 49 studi. Il metro corretto è stato validato
esplicitamente: **0 geni su 40.251 hanno un conteggio di studi diverso da `k_effective`.**

| | |
|---|---:|
| gruppi dominati da un solo studio (≥50% del peso) | **105 su 191 (55,0%)** |
| con uno studio al ≥70% | 37 (19,4%) |
| **con meno di 2 studi efficaci** | **66 (34,6%)** |
| frazione efficace mediana (k_kish / k) | 0,65 |

E il fenomeno è **interamente concentrato sui k bassi**:

| fascia di k | gruppi | frazione efficace | dominati |
|---|---:|---:|---:|
| k=3-4 | 105 | 0,65 | **84 (80%)** |
| k=5-6 | 31 | 0,63 | 11 (35%) |
| k=7-10 | 34 | 0,58 | 10 (29%) |
| k=11-20 | 13 | 0,90 | **0** |
| k=21-49 | 8 | 0,94 | **0** |

I sette case study di punta stanno tutti nella parte sana: TGF-β1 49 → **45,1 efficaci** (studio più
pesante: 2,6%), LPS 34 → 31,8, SARS 33 → 29,2, JQ1 24 → 22,8, DHT 23 → 20,9, enzalutamide 19 → 17,4,
IFN-γ 19 → 17,1.

Il caso estremo è **«Lung Neoplasms», k=3, 1,0 studi efficaci, 98,8% del peso su uno solo** — e
1.884 geni significativi. Verificato sui dati: dei tre studi, `GSE148862` contribuisce **159 geni su
~20.000** e `GSE216561` ha un SE mediano di **1,95** contro **0,48**. Per quasi tutti i geni quel
gruppo è uno studio con due comparse.

**Non è un errore, ed è importante dirlo così:** la pesatura per inverso della varianza *deve* dare
più peso a chi misura meglio. Il punto è un altro — **per un terzo dei gruppi il pooling non aggiunge
quasi nulla a quello che diceva già lo studio più grande**, e nulla nel deliverable lo segnala.
Coerenza e dominanza sono assi indipendenti: **tutti e 105 i gruppi dominati sono marcati
«coerenti»**. Va nei Methods, e `k_kish` andrebbe accanto a `k_effective` nel deliverable.

## 6. FINDING 3 — il case study di malattia non regge, in nessuna delle due versioni

Era l'unica voce della selezione senza un'alternativa già decisa. Entrambi i candidati falliscono, e
per motivi diversi.

**Parkinson (`MeSH:D010300`, k=10): 1,8 studi efficaci, 73,2% del peso su `GSE181029`.** Leggendo i
membri a testo intero, `GSE181029` **non è cervello di paziente**: sono progenitori neurali e neuroni
dopaminergici **derivati da iPSC** con mutazioni PARK2 — un modello cellulare. Gli altri nove studi
sono tessuto post-mortem (sostanza nera, amigdala, giro temporale) o campioni di paziente. È la stessa
forma «clinico contro sperimentale» che nel censimento v13 ha reso **incoerenti** influenza e HIV-1.

> **Contraddice il verdetto in atti.** Il gruppo Parkinson è marcato `coherent`. Se la regola che ha
> squalificato influenza vale, vale anche qui — con l'aggravante che qui il membro fuori posto porta
> quasi tre quarti del peso. **Il verdetto va rivisto**; non lo cambio da solo perché la marcatura è
> una lettura umana e la decisione è dell'utente. Un secondo membro, `GSE90469` («Patient-Derived
> Dopamine Neurons»), è pure in coltura, ma pesa lo 0,7%.

**Carcinoma epatocellulare (`MeSH:D006528`, k=9): 3,0 studi efficaci, 67,4% del peso su due studi
problematici, e solo 72 geni significativi.** `GSE120663` misura **PBMC (sangue)** dove tutti gli
altri misurano tessuto epatico (27,7% del peso); `GSE77509` usa **un solo controllo** («Adjacent
Normal #3») per tumori di pazienti diversi e include un trombo portale (39,7%).

**Alternative misurate, dalla stessa tabella** (tutti i gruppi `MeSH:` dei 191, ordinati per studi
efficaci):

| malattia | k | studi efficaci | studio più pesante | geni sig | I² |
|---|---:|---:|---:|---:|---:|
| **Crohn Disease** | 10 | **6,9** | 20,3% | 3.515 | 62,9 |
| Colorectal Neoplasms | 7 | 3,9 | 36,0% | 1.318 | 72,8 |
| **Alzheimer Disease** | 6 | 3,8 | 35,8% | 6.231 | 44,5 |
| Breast Neoplasms | 5 | 3,7 | 35,3% | 3.264 | 70,8 |
| Pre-Eclampsia | 6 | 3,5 | 44,7% | 2.461 | 50,4 |
| — Parkinson | 10 | 1,8 | 73,2% | 976 | 64,2 |
| — Carcinoma, Hepatocellular | 9 | 3,0 | 47,9% | 72 | 75,8 |

**Crohn è il candidato giusto**: k=10, quasi 7 studi efficaci, nessuno sopra il 21%, 3.515 geni
significativi. Alzheimer è il secondo, con più geni ma meno studi. **Non li ho costruiti**: la
selezione è una decisione presa, e cambiarla è dell'utente. Sono due minuti di build.

## 7. Quanto pesano i difetti già noti: poco, e ora è un numero

Il finding del 2026-07-30 elencava difetti di appaiamento senza quantificarli. Ora sì — peso mediano
nel random-effects, sui geni significativi:

| gruppo | studi difettosi | peso totale |
|---|---:|---:|
| **Parkinson** | 2 | **74,1%** |
| **HCC** | 2 | **67,4%** |
| DHT | 2 (`DHT and ENZ`; `E2 and DHT`) | 9,4% |
| TGF-β1 | 3 (iPSC vs primarie; passaggio; etnia) | 6,8% |
| enzalutamide | 1 (`LAPC4_ENZA` vs `VCaP_DMSO`) | 6,4% |
| IFN-γ | 1 (soggetto diverso) | 4,8% |
| JQ1 | 1 (DIPG pons vs brain) | 4,8% |
| SARS-CoV-2 | 2 (cuore di paziente; `COVID-19 Lung` vs `hESC Mock`) | 4,7% |

**Nei sette gruppi di punta i difetti noti pesano fra il 4,7% e il 9,4%: non guidano il risultato.**
Nei due gruppi di malattia lo guidano e basta. Tre difetti sono **nuovi** rispetto al 2026-07-30:
`GSE210984` in TGF-β1 (trattato = MSC da iPSC, controllo = MSC primarie), `GSE78801` in JQ1 (pons
contro brain), `GSE130247` in DHT (`DHT and ENZ`: l'antagonista dentro il gruppo dell'agonista).

## 8. Un difetto minore, misurato: simboli genici duplicati nelle tabelle

L'asse dei geni è pulito — **zero righe duplicate per `(cluster_id, gene_id)` su 3.178.307**. Ma le
tabelle e le etichette usano `gene_symbol`, e nella regione MHC lo stesso simbolo ha più ID Ensembl
su aplotipi alternativi: `UBD` compare **sei volte** nel gruppo SARS-CoV-2, tre con valori identici.
È una nuova manifestazione di un problema noto dal 2026-05-21 (memoria
`project_archs4_gene_symbol_duplicates`), che l'asse Ensembl aveva risolto **nel calcolo** ma non
**nella visualizzazione**.

Ampiezza sui 12: 4,6% dei simboli hanno più di un ID (12,0% delle righe). Costo sulle tabelle da 30
righe: **da 0 a 5 posti persi** (HCC 5, LPS 4, SARS 3, zero su quattro gruppi).

## 9. Che cosa questo NON dimostra

- **Non è una validazione del deliverable.** Sono 12 gruppi su 191. Le misure dei §5 e §8 sono su
  tutti e 191; quelle dei §4, §6 e §7 sono sui 12 costruiti.
- **La verifica dei membri è una lettura umana**, come il censimento: ripetibile sugli stessi file
  (`membri-case-study.txt`, testo intero, massimo 88 caratteri, **nessun limite toccato**), non
  l'output di una regola.
- **Il verdetto su Parkinson è una proposta di ritrattazione, non una ritrattazione applicata.** Il
  deliverable annotato non è stato modificato.
- **Nessuna correzione è stata applicata alle figure.** Il filtro per k sui top geni e sulla heatmap
  è proposto, non fatto.
- **Il forest e il pannello di eterogeneità non sono stati letti uno per uno**: la dominanza è stata
  misurata dai pesi, che è più forte, ma le figure andrebbero comunque guardate prima del paper.

## 10. Riproducibilità

`analysis/audit/2026-07-31-layer-b-v13/`:
`10-selection.R` → `analysis/layer-b-selection-v13.csv` ·
`20-preflight.R` → `preflight-dispatch.rds` ·
`30-k-per-gene.R` → `k-per-gene-quote.csv`, `bersagli-attesi-rango.csv` ·
`40-dominanza-forest.R` → `dominanza-forest.csv` ·
`50-membri-case-study.R` → `membri-case-study.txt` ·
`60-peso-dei-difetti.R` → `peso-dei-difetti.csv` ·
`70-dominanza-tutti-191.R` → `dominanza-tutti-191.csv` ·
`80-heatmap-verifica.R` → `heatmap-verifica.csv`.

Build: `analysis/p5-stage4-layer-b-build-v13.R` → `analysis/p4-output/20260730T160606Z-layer-b-c279e308`.
