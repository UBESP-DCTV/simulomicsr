# Layer B v13: i case study esistono, e costruirli ha cambiato il deliverable

**Data:** 2026-07-31 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟡 **9 case study (3 main + 6 supplementari), scelti sulle misure e non sul k. Il
deliverable ora dice anche QUANTO il pooling è efficace, non solo quanti studi entrano. Non è
"validato": vedi §10.**

---

## 0. Che cosa è cambiato rispetto alla prima stesura di questo documento

Questo finding è stato scritto due volte nella stessa giornata. La prima stesura, dopo il primo
build, conteneva **un errore** e **una raccomandazione sbagliata**, entrambi corretti misurando:

| prima stesura | dopo |
|---|---|
| «i simboli genici duplicati costano 0-5 posti su 30 nelle tabelle» | **RITRATTATO (§9).** Avevo misurato sul parquet grezzo invece che sull'artefatto prodotto. La tabella deduplica già (`.rank_and_dedup_genes`): **zero duplicati in tutti e 12 i bundle**. |
| «propongo di ritrattare il verdetto di coerenza del gruppo Parkinson» | **RITIRATA (§6).** Leggendo tutti e 20 i gruppi di malattia, la stessa forma è in **almeno 6**. Ritrattarne uno sarebbe stata una lista scritta a mano. Al suo posto: due assi misurati su tutti e 191, nel deliverable. |

E una critica dell'utente, giusta e accolta: la misura di efficacia del pooling **stava in un file di
audit invece che nel deliverable**. Ora è nel deliverable (§4).

## 1. Che cosa è stato costruito

**Build finale:** `analysis/p4-output/…-layer-b-…` (9 bundle) da
`analysis/p5-stage4-layer-b-build-v13.R` su `analysis/layer-b-selection-v13-finale.csv`.
Un primo build esplorativo a 12 case study (con i doppioni ancora aperti) resta in
`20260730T160606Z-layer-b-c279e308`.

| dove | case study | perché questo |
|---|---|---|
| **main fig. 1** | DHT (k=23) **contro** enzalutamide (k=19) | controllo positivo e negativo insieme: KLK3 **+2,27** / **−1,60**, TMPRSS2 +1,78 / −0,92, FKBP5 +2,32 / −1,22, NKX3-1 +1,37 / −1,24, da studi diversi in gruppi costruiti separatamente |
| **main fig. 2** | **TGF-β1** (k=49) | vince su LPS su ogni asse: 49 studi contro 35, **45,1 studi efficaci** contro 31,8, 7.233 geni sig contro 6.883, e i sei bersagli attesi tutti misurati **al k pieno** (48-49 su 49) |
| supplementari | SARS-CoV-2 (k=33) · IFN-γ (k=19) · JQ1 (k=24) · **Crohn** (k=10) | copertura di tipo: patogeno, citochina, piccola molecola, malattia |
| limiti dichiarati | **Parkinson** · **IL1A** | un gruppo che sul k sembra solido e che le misure nuove smontano; e uno incoerente dichiarato |

**La malattia non è più Parkinson né il carcinoma epatocellulare: è Crohn.** Misurato: Crohn ha 10
studi, **6,9 efficaci**, nessuno sopra il 21%, 3.515 geni significativi, e tutti i membri sono
tessuto o campione di paziente. Parkinson ha **1,8 studi efficaci su 10**; l'epatocellulare ha il
67% del peso su due studi problematici e **72 geni significativi in tutto**.

## 2. Due difetti della macchina, trovati PRIMA di lanciarla

La macchina Layer B è anteriore ad ADR-0025 e non conosce i cluster del deliverable:

1. **L'anchor dei cluster v13 non è parsabile.** `anchor_key` per `mode=cgroup` ha **tre** segmenti
   (`entità||verso||tipo-di-controllo`), non i 13 dell'anchor canonico v3.
   `extract_anchor_summary()` non crasha: restituisce `NA` su tutto. Ogni summary card avrebbe
   scritto `Anchor: ? x ? (tissue=?)`. Fallimento silenzioso, misurato.
2. **`canonical_name` per il DHT dice «4-maleylacetoacetate».** L'etichetta delle figure viene dal
   CSV di selezione, che ora è **generato dal deliverable** invece che trascritto.

Il fix `rem_group` del 2026-07-23 era già nel codice di pacchetto ed è stato riverificato.
**Pre-flight 5/5** (`20-preflight.R`): esistenza nel Layer A · method su tutte le 220.493 righe ·
dispatch che risolve 12/12 · **studi risolti == k del deliverable == max `k_effective`** ·
3.146 campioni tutti nell'asse H5.

⚠️ **Errore di misura mio, corretto prima di usarlo.** Il primo controllo confrontava il dispatch con
un `k_effective` pescato con `match()`: `k_effective` in `cluster_pooled` è **per-gene**, e 12
cluster danno 219 combinazioni distinte. Sei cluster sembravano disallineati per colpa del metro.

## 3. La biologia regge: 32 bersagli attesi su 32

Geni scelti dalla letteratura **prima** di guardare. Tutti presenti, segno corretto, tutti nel 5% più
significativo (ranghi 6–1.009 su ~19-20.000). TGF-β1 li ha tutti a k=48-49 su 49.

L'arricchimento GO conferma in modo indipendente, ed è la parte del bundle che **non** soffre del
difetto del §5 (usa tutti i geni significativi, non i primi 30): IFN-γ dà «response to type II
interferon», enzalutamide dà biogenesi ribosomiale e replicazione del DNA (blocco proliferativo da AR
spento), DHT dà biosintesi del colesterolo e degli steroli — il programma lipogenico noto a valle di
AR.

## 3bis. LA FIGURA 1 È PIÙ FORTE DI QUELLO CHE CERCAVAMO

L'argomento noto era: quattro bersagli scelti dalla letteratura salgono col DHT e scendono con
l'enzalutamide. È vero, ma sono **geni scelti prima**. Guardando le tabelle dei due bundle è saltato
fuori che fra i primi trenta geni di ciascun gruppo **quindici sono gli stessi**, e nessuno era stato
scelto da nessuno. Misurato su tutto il trascrittoma condiviso:

| insieme | n | Pearson | Spearman | segno opposto |
|---|---:|---:|---:|---:|
| tutti i geni in comune | 18.284 | −0,435 | −0,388 | 63,9% |
| **significativi in entrambi** | **1.299** | **−0,841** | **−0,939** | **97,5%** |
| significativi con \|logFC\|>1 | 174 | −0,815 | −0,862 | **99,4%** |

**Dei 15 geni condivisi fra i primi trenta, 15 su 15 hanno segno opposto**: PGC (+4,63 / −3,04),
SLC38A4 (+4,15 / −4,23), UGT2B28, CHRNA2, HPGD, CCDC141, ST6GALNAC1, ALPK2, TUBA3E, PLA2G5, KLK2,
MOGAT2, NNMT, PCED1B.

⚠️ **Il caveat, con il suo numero.** I due gruppi condividono **2 studi** (GSE123766, GSE236286) su 23
e 19. Un esperimento che misura entrambi i bracci produrrebbe stime correlate per costruzione, quindi
va pesato: quei due studi valgono **8,6%** del peso nel gruppo DHT e **10,2%** in quello
enzalutamide. Circa il 90% di ciascuna stima viene da studi esclusivi del proprio gruppo.

Perché i quattro bersagli noti non compaiono in cima alla tabella ordinata per FDR: hanno **I² fra
99,7 e 99,9**, cioè gli studi concordano sul segno ma non sulla magnitudine, e questo gonfia
l'errore standard del pooled. **L'ordinamento per FDR premia i geni consistenti, non quelli
grandi**: è una proprietà del random-effects, non un difetto, ma va detta quando si sceglie che cosa
mostrare. Col punteggio del volcano (|logFC| × −log10 FDR) FKBP5 è 16°, TMPRSS2 22°, KLK3 33° nel
DHT, e KLK3 è 13° nell'enzalutamide.

## 4. IL DELIVERABLE ORA DICE QUANTO IL POOLING È EFFICACE

Il deliverable riportava `k_effective`: **quanti** studi entrano. Non diceva quanto **contano**. In un
random-effects il peso è `1/(SE²+τ²)`: uno studio può portare il 98% e gli altri essere comparse.

`analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv` ha ora, per ogni meta-analisi:

| colonna | che cosa dice |
|---|---|
| `k_kish` | **numero efficace di studi**, `(Σw)²/Σw²`: vale `k` se pesano uguale, tende a 1 se uno domina |
| `frazione_efficace` | `k_kish / k` |
| `quota_top1`, `dominato` | quota di peso del primo studio, e se supera il 50% |
| `studio_dominante` | **quale** studio porta il peso |
| `materiale_misto`, `n_studi_model/primary/unknown` | il gruppo mescola sistemi in vitro e materiale di paziente? |
| `classe_studio_dominante`, `dominato_da_modello` | chi porta il peso è un modello in vitro, in un gruppo che contiene anche pazienti? |

Codice di pacchetto, test scritti prima: `R/stage4-pooling-effectiveness.R` (**38 PASS**) e
`R/stage3-material-class.R` (**49 PASS**).

**Riproduzione esatta sui dati veri**: la funzione di pacchetto dà gli stessi numeri della misura
fatta a mano — **scarto massimo 0,0000000000** su `k_kish` e su `quota_top1`, `k_studies` identico su
tutti e 191.

### I numeri, su tutti e 191

| | |
|---|---:|
| dominati da un solo studio (≥50% del peso) | **105 (55,0%)** |
| con uno studio al ≥70% | 37 (19,4%) |
| **con meno di 2 studi efficaci** | **66 (34,6%)** |
| frazione efficace mediana | 0,65 |
| materiale misto | 49 (25,7%) |
| **dominati da un modello in vitro** | **8 (4,2%)** |

Il fenomeno è **interamente concentrato sui k bassi**: k=3-4 → 80% dominati; **k≥11 → zero**.
I nove case study stanno tutti nella parte sana tranne i due dichiarati.

**Coerenza e dominanza sono assi indipendenti**, e questa è la riga che va nei Methods:

|  | non dominato | dominato |
|---|---:|---:|
| coerente | 85 | **100** |
| incoerente | 1 | 5 |

Il caso estremo è **«Lung Neoplasms», k=3, 1,0 studi efficaci, 98,8% del peso su uno**, con 1.884
geni significativi. Verificato: dei tre studi, `GSE148862` contribuisce **159 geni su ~20.000** e
`GSE216561` ha un SE mediano di **1,95** contro **0,48**.

**Non è un errore**, e va detto così: l'inverso della varianza *deve* dare più peso a chi misura
meglio. Il punto è che **per un terzo dei gruppi il pooling non aggiunge quasi nulla a ciò che diceva
già lo studio più grande**, e prima nulla lo segnalava.

⚠️ **Secondo errore di misura mio, corretto.** La prima versione pesava i **bracci**: `per_study_de`
ha una riga per braccio, e TGF-β1 ne ha 83 per 49 studi. Il ramo `rem_group` collassa i bracci dentro
lo studio prima del random-effects. Rifatta col collasso e **validata: 0 disallineamenti su 40.251
geni**. Il test che difende quest'unità è in `test-stage4-pooling-effectiveness.R`.

⚠️ **Terzo errore, visto nell'output prima di pubblicarlo.** La colonna `dominato_da_modello` si
accendeva anche su TGF-β1 e LPS, dove lo studio "dominante" pesa il 2,5% e il 3,8% — cioè non domina
affatto. Mancava la congiunzione con `dominato`. Con la congiunzione: da 17 gruppi a **8**.

## 5. FINDING — la tabella dei top geni e la heatmap mostravano τ²=0, non l'effetto (CORRETTO)

Nel primo build il bundle DHT aveva in cima AFP (k=5), KRT72 (k=6), COL22A1 (k=2), **su 23 studi**,
mentre i bersagli veri dell'androgeno cominciavano dal rango 152. Il meccanismo, verificato:

> k basso → il random-effects non stima τ², lo pone a **0** → l'errore standard collassa → l'FDR
> precipita → il gene entra nei primi 30 → ma è **a conteggio zero nella maggior parte dei campioni**
> → ComBat lo salta esplicitamente («genes with uniform expression within a single batch») → nella
> heatmap quella riga resta segnale di **studio**.

Misure: su SARS-CoV-2, SE mediano **0,554 a k=2** contro **0,088 a k≥21**; τ²=0 nel **56,6%** dei
geni a k=2 contro **0%** a k≥21; **nove dei primi dieci** geni per FDR hanno τ²=0 e I²=0. Il k
mediano dei primi venti era **6,5 su 33** (JQ1 3,5 su 24; IFN-γ 3 su 19). Correlazione fra k e
frazione di zeri: **Spearman −0,813**.

⚠️ **Una conclusione corretta prima di scriverla.** Misurando sul log-CPM grezzo lo studio spiegava
il 55-84% della varianza: sembrava batch ovunque. Ma la heatmap applica **VST + ComBat**. Rifatta
sulla catena vera: R² dello studio **0,82 → 0,02** (DHT), 0,55 → 0,03 (TGF-β1), 0,69 → 0,01
(enzalutamide). **ComBat funziona in tre casi su quattro.** Fallisce solo su **IFN-γ (0,84 → 0,82)**,
dove 16 dei 30 geni mostrati sono quasi tutti zero e ComBat non può correggerli.

**FIX APPLICATO** (`layer_b_default_config()$top_genes_min_k_frac = 0.5`, 31 test): un gene entra
nella tabella e nella heatmap solo se misurato in **almeno metà** degli studi del cluster. Il filtro:

- è **dichiarato nella caption** con quanti geni ha tolto e perché — nessun taglio silenzioso;
- **non svuota mai una figura**: se nessun gene passa, torna all'insieme intero e lo scrive;
- **non tocca le stime poolate**: decide solo quali geni si mostrano;
- prende `k_max` dal cluster **intero**, non dai geni sopravvissuti a un filtro precedente.

**VERIFICATO SULL'ARTEFATTO PRODOTTO**, non solo sui test (`140-verifica-filtro.R`, confronto fra i
due build sugli 8 cluster in comune):

| | prima | dopo |
|---|---:|---:|
| geni mostrati sotto metà del k, in totale | **106** | **0** |
| k mediano dei geni mostrati — SARS-CoV-2 | 6,0 | **33,0** |
| — IFN-γ | 4,0 | **19,0** |
| — JQ1 | 4,0 | **24,0** |
| — enzalutamide | 9,0 | **19,0** |
| geni con oltre metà dei campioni a zero — IFN-γ | 16/30 | **0/30** |
| — DHT | 8/30 | **0/30** |
| frazione mediana di zeri fra i mostrati | ~50-68% | **0,0-0,3%** |

Il cambiamento si vede: la tabella di IFN-γ prima aveva in cima geni GIMAP a k=2 con l'85-92% dei
campioni a zero; **ora ha STAT1, GBP1, CXCL9, TAP1, TRIM69, NMI** — i geni canonici della risposta a
interferone γ. 8 bundle su 9 dichiarano il filtro nella caption; il nono è IL1A, dove non è stato
tolto nulla e la nota giustamente non compare.

**E la varianza si sposta dove deve.** Rimisurato sui geni *effettivamente mostrati* dal bundle
nuovo, con la stessa catena VST+ComBat della figura:

| gruppo | R² studio (post-ComBat) | R² **trattamento** |
|---|---:|---:|
| **IFN-γ** | 0,82 → **0,04** | 0,01 → **0,81** |
| DHT | 0,02 → 0,01 | 0,14 → **0,25** |
| enzalutamide | 0,01 → 0,00 | 0,05 → **0,11** |
| TGF-β1 | 0,03 → 0,03 | 0,24 → **0,27** |

Su IFN-γ è un ribaltamento completo: la heatmap prima era una mappa degli studi, ora separa i
campioni in due blocchi per trattamento con gli studi mescolati in entrambi, e le righe sono la firma
canonica dell'interferone γ (STAT1, STAT2, IRF1, GBP1, IDO1, TAP1/TAP2, l'immunoproteasoma
PSMB9/PSMB10/PSME1/PSME2, CXCL9/CXCL11, PARP9/PARP14/DTX3L). Geni con oltre metà dei campioni a zero:
**0/30 su tutti e quattro** (erano 8, 7, 16 e 3).

## 6. FINDING — «paziente contro modello in vitro» non è di Parkinson: è di almeno 6 gruppi su 20

Il gruppo Parkinson (k=10, marcato coerente) ha il **73,2%** del peso su `GSE181029`, che leggendo il
testo intero **non è cervello di paziente** ma progenitori neurali e neuroni dopaminergici **derivati
da iPSC** con mutazione PARK2. Gli altri nove studi sono tessuto post-mortem o campioni di paziente.

**La prima stesura proponeva di ritrattare il verdetto di quel gruppo. La proposta è ritirata**, per
un motivo che è una misura e non un ripensamento: leggendo **tutti e 20** i gruppi di malattia, la
stessa forma c'è in almeno sei — Parkinson (iPSC, 73%), Huntington (progenitori gliali, 57%),
spondilite anchilosante (differenziamento adipogenico, 80%), colorettale (sferoidi, 47%), carcinoma
renale (colture, 31%), diabete gestazionale (progenitori endoteliali, 11%). Ritrattarne uno sarebbe
stata **una lista scritta a mano** — l'errore che questo progetto ha già pagato per mesi.

Al suo posto: il segnale è **misurato su tutti e 191** e sta nel deliverable, e i verdetti di coerenza
restano quelli che sono. Il rilevatore (`R/stage3-material-class.R`) è un'euristica **dichiarata**,
con vocabolario esplicito e match a parola intera; il suo accordo col giudizio umano sui 20 gruppi
letti a mano è **19 su 20 (95%)**. L'unico disaccordo — «Stomach Neoplasms» — è un caso in cui il
rilevatore ha ragione e la mia lettura l'aveva classificato sotto un'altra voce (`GSE46597` confronta
cellule staminali gastriche contro cellule differenziate: non è tumore contro normale).

Gli **8 gruppi dominati da un modello in vitro** (con materiale di paziente dentro): StemRegenin 1
(88,3%), cabozantinib (84,3%), spondilite (80,7%), **Parkinson (73,2%)**, scompenso cardiaco (68,5%),
tofacitinib (64,1%), ponatinib (61,3%), **Huntington (60,2%)**.

## 7. Quanto pesano i difetti già noti: poco dove conta

| gruppo | studi difettosi | peso totale |
|---|---:|---:|
| Parkinson | 2 | **74,1%** |
| carcinoma epatocellulare | 2 | **67,4%** |
| DHT | 2 (`DHT and ENZ`; `E2 and DHT`) | 9,4% |
| TGF-β1 | 3 (iPSC vs primarie; passaggio; etnia) | 6,8% |
| enzalutamide | 1 (`LAPC4_ENZA` vs `VCaP_DMSO`) | 6,4% |
| IFN-γ | 1 (soggetto diverso) | 4,8% |
| JQ1 | 1 (DIPG pons vs brain) | 4,8% |
| SARS-CoV-2 | 2 | 4,7% |

**Nei gruppi di punta i difetti noti pesano fra il 4,7% e il 9,4%: non guidano il risultato.** Tre
sono **nuovi** rispetto al 2026-07-30: `GSE210984` in TGF-β1 (trattato = MSC da iPSC, controllo = MSC
primarie), `GSE78801` in JQ1 (pons contro brain), `GSE130247` in DHT (`DHT and ENZ`: l'antagonista
dentro il gruppo dell'agonista).

## 8. Che cosa NON è stato fatto, per scelta

- **I verdetti di coerenza non sono stati toccati.** Cambiarli richiederebbe una regola applicata a
  tutti e 305 e un nuovo censimento, non una correzione mirata.
- **La regola «entità con un gruppo proprio»** (IL-1α/IL-1β) resta aperta: ~9 h di re-cluster + ~28 h
  di re-pool, decisione dell'utente.
- **Il filtro sui volcano label** non è stato aggiunto: lì un simbolo ripetuto è cosmetico.

## 9. RITRATTAZIONE — i simboli genici duplicati non costano posti nelle tabelle

La prima stesura diceva: «le tabelle da 30 righe perdono da 0 a 5 posti per simboli con più ID
Ensembl». **È falso.** `.rank_and_dedup_genes()` deduplica per simbolo **prima** di prendere i primi
30, in tabella e in heatmap, e il commento nel codice dice pure perché. Verificato sull'artefatto:
**zero simboli duplicati in tutte e 12 le tabelle prodotte**.

Il dato di partenza resta vero — `UBD` ha sei ID Ensembl nel gruppo SARS-CoV-2, 4,6% dei simboli ne
ha più di uno — ma **avevo misurato sul parquet grezzo invece che sul file che la pipeline produce**.
È la stessa classe di errore che questo progetto continua a pagare: *misurare l'oggetto sbagliato*.

## 10. Che cosa questo NON dimostra

- **Non è una validazione del deliverable.** Le misure dei §4 e §6 sono su tutti e 191; quelle dei
  §3, §5 e §7 sono sui case study costruiti.
- **La lettura dei membri è umana**, ripetibile sugli stessi file (`membri-case-study.txt`,
  `malattie-membri.txt`: testo intero, massimo 129 caratteri, **nessun limite toccato**), non
  l'output di una regola.
- **`materiale_misto` è un'euristica dichiarata**, non un classificatore di materiale biologico. Non
  copre i nomi propri delle linee cellulari; il suo accordo col giudizio umano è misurato solo sui 20
  gruppi di malattia.
- **La soglia del filtro (metà del k) è una scelta**, non un risultato. È un parametro di config.
- **Il forest e il pannello di eterogeneità non sono stati letti uno per uno**: la dominanza è stata
  misurata dai pesi, che è più forte, ma le figure vanno guardate prima del paper.

## 11. Riproducibilità

`analysis/audit/2026-07-31-layer-b-v13/`: `10-selection.R` · `20-preflight.R` · `30-k-per-gene.R` ·
`40-dominanza-forest.R` · `50-membri-case-study.R` · `60-peso-dei-difetti.R` ·
`70-dominanza-tutti-191.R` · `80-heatmap-verifica.R` · `90-malattie-modello-vs-paziente.R` ·
`100-efficacia-pacchetto.R` · `110-materiale-tutti-191.R` · `120-selection-finale.R` ·
`130-deliverable-arricchito.R` · `140-verifica-filtro.R`.

Codice di pacchetto nuovo: `R/stage4-pooling-effectiveness.R`, `R/stage3-material-class.R`,
filtro di copertura in `R/layer-b-utils.R` + innesto in `R/layer-b-plot-top-gene-table.R` e
`R/layer-b-plot-heatmap.R`. Test: `test-stage4-pooling-effectiveness.R` (38),
`test-stage3-material-class.R` (49), `test-layer-b-gene-coverage-filter.R` (31).
