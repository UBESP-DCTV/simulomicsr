---
type: Finding
title: "Il disegno della validazione esterna: LINCS giudica metà delle meta-analisi, e un fallimento ha già una prova scritta"
description: "Copertura e circolarità sulle 194, soglie candidate con il valore atteso per caso, prova fra le tre spiegazioni di un fallimento. Nessun confronto fra stime e fonte esterna."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-04T18:00:00+01:00'}
sources:
- {id: disegno, resource: "docs/superpowers/specs/2026-11-04-validazione-esterna-design.md", title: "Il disegno che la sessione successiva esegue"}
- {id: previsioni, resource: "analysis/audit/2026-11-04-S6-validazione-disegno/00-previsioni.md", title: "Cancelli e previsioni, commit beb9723"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi"}
- {id: lim, resource: "https://doi.org/10.1038/s41598-021-97005-z", title: "Lim e Pavlidis, Sci Rep 2021;11:17624"}
- {id: tahoe, resource: "https://huggingface.co/datasets/tahoebio/Tahoe-100M", title: "Tahoe-100M, licenza CC0"}
- {id: gdc, resource: "https://api.gdc.cancer.gov/files", title: "GDC, conte dei campioni TCGA"}
---

# In breve

## In breve: come controlliamo le stime con dati che non vengono dal nostro corpus?

**A cosa serviva.** Tutte le verifiche fatte finora usano gli stessi dati che hanno prodotto le stime. Questa sessione scrive il controllo con dati esterni prima di guardare un risultato: che cosa confrontiamo, quale esito è un fallimento, che cosa succede dopo un fallimento. Non ho confrontato nessuna stima con una fonte esterna.

**Cosa abbiamo trovato.**

1. **La validazione esterna può giudicare circa metà delle meta-analisi.** LINCS, una raccolta pubblica di profili di farmaci misurati su linee cellulari, permette la misura per 96 meta-analisi su 194, e per 24 delle 40 dell'insieme principale.
   - Il verdetto userà solo i composti: 19 nelle 40 e 53 nelle altre 132.
   - I ligandi avranno solo una descrizione, perché il loro elenco di riferimento ha 164 voci invece di 5.466 e i nomi con lettere greche non sono ancora controllati.
   - Nelle 40 restano senza validazione 16 meta-analisi, fra cui tutte le 8 malattie. Non conosco una fonte aperta e indipendente da GEO per queste malattie, e non ho fatto una ricerca sistematica.
2. **LINCS è esterna rispetto al nostro corpus, per quello che possiamo vedere.** Nessuno dei 1.383 studi delle 194 sta fra le serie LINCS, usa la sua piattaforma o la cita nel metadato. La ricerca non legge il riassunto della serie GEO.
3. **I numeri scritti nel piano sulla copertura erano da correggere.** I «111 composti già agganciati» erano candidati: LINCS ne aveva 90, e 77 di questi restano nelle 194. Con i composti nuovi il totale torna a 90 su 194, quindi il 47% del piano resta quasi giusto per compensazione.
   - I ligandi sono 20, non 15. Il piano usa una colonna che sbaglia il tipo: per esempio dice che TGFB1 è una piccola molecola.
   - La mia previsione su questo numero è smentita per lo stesso motivo.
4. **Il risultato avrà tre riferimenti.** Il composto giusto cade per caso nel primo 10% dei composti una volta su 10. In letteratura, due edizioni della Connectivity Map (LINCS è la seconda) arrivano a 17 su 100. La stessa edizione contro se stessa arriva a 83 su 100.
   - Una risposta generica può alzare il valore del caso, quindi misureremo anche i composti sbagliati. Se quel valore supera la soglia, sostituisce la soglia.
5. **Il disegno stabilisce adesso come distinguere le tre spiegazioni di un fallimento.** La fonte e l'identità valgono solo se le prove scritte ora le dimostrano. Altrimenti la causa è il metodo.
   - La fonte è la causa in tre casi. LINCS ritrova se stessa meno di 50 volte su 100. Due fonti indipendenti non raggiungono la soglia. Una seconda fonte conferma le stime dove LINCS non le conferma.
   - Il limite di 50 volte su 100 è un mio giudizio, come i margini delle previsioni.
   - L'identità è la causa se le meta-analisi con verdetto «corretta» e aggancio per struttura passano e le altre no. Le 19 hanno tutte il verdetto «corretta», quindi lì serve la prova di un errore di aggancio.
   - Per il metodo confronteremo ogni meta-analisi con i suoi singoli studi, così vediamo se la combinazione peggiora le stime.

**Cosa devi decidere.**

1. **Quale fonte? Consiglio LINCS per il verdetto, più Tahoe-100M e TCGA con un ruolo limitato.** Tahoe-100M è un atlante aperto di 379 farmaci, fuori da GEO. Copre 8 delle 19 meta-analisi, quindi serve per provare la fonte e non per il verdetto. TCGA copre 6 tumori, nessuno nelle 40. Serve a provare che il controllo vede l'inversione già nota nel carcinoma epatocellulare.
   - In alternativa usiamo solo LINCS. Risparmiamo circa 2 ore, ma dopo un fallimento non abbiamo una seconda fonte per provare la causa.
   - In alternativa chiediamo anche dati ad accesso controllato per Parkinson e disturbo bipolare. L'attesa può durare mesi, e non ho misurato questa copertura.
2. **Quale soglia? Consiglio almeno 8 composti su 19 nel primo 10%.** Questo esito dice che le stime riconoscono il composto meglio di quanto due edizioni della Connectivity Map si riconoscono fra loro. Se la quota vera è 50%, il test passa 82 volte su 100.
   - In alternativa la soglia è 6 su 19. Dice soltanto che le stime superano il caso.
   - In alternativa la soglia è 11 su 19, cioè più di metà. Se la quota vera è 50%, il test passa solo 32 volte su 100.
   - Le altre 132 hanno un verdetto separato con la stessa regola: 16, 11 o 24 composti su 53.
3. **Che cosa resta se il test fallisce e la causa è il metodo? Consiglio di tenere nell'articolo la catena, il catalogo dei confronti, le verifiche e i limiti.** L'articolo dichiara il fallimento e lascia le stime in supplementare come ipotesi non validate. Decidi tu dopo aver letto il risultato.
   - In alternativa correggiamo il metodo e rifacciamo tutto. Costa settimane e serve una terza fonte mai vista, che oggi non abbiamo.
   - In alternativa fermiamo l'articolo. Salviamo il lavoro futuro e perdiamo il lavoro fatto.
4. **Quando eseguiamo il test? Consiglio adesso sul risultato di oggi, e di nuovo con lo stesso codice dopo le correzioni.** Un fallimento del metodo arriva così prima del lavoro sulle correzioni. Gli errori già noti non toccano questi 19 composti. Il numero dell'articolo è il secondo, e nessuna correzione può guardare l'esito di una singola meta-analisi.
   - In alternativa lo eseguiamo solo dopo le correzioni. Il calcolo è uno solo, ma scopriamo un fallimento a lavoro finito.
5. **Quante estrazioni usiamo nel confronto con studi non collegati? Consiglio 99.** Il confronto partirà dopo le correzioni, su tutti i gruppi. Con 99 estrazioni il verdetto per singola meta-analisi regge la correzione per molti test, e il calcolo dura al massimo 35 ore.
   - In alternativa usiamo 19 estrazioni. Il calcolo dura al massimo 7 ore, ma il verdetto vale solo per l'insieme.

**Comunque:**

- non cambiamo nessun verdetto e non tocchiamo il risultato depositato;
- l'articolo avrà una colonna con l'esito per ogni meta-analisi, anche «non validata»;
- i Methods diranno che il test guarda 978 geni su 21.758, su linee tumorali, e che vale per l'insieme e non per la singola meta-analisi;
- le malattie, i patogeni e le esposizioni ambientali restano non validati, salvo una descrizione su 6 tumori.

Appena decidi questi 5 punti, la sessione è chiusa.

**Sui tempi di calcolo.** La stima è mia. Lo scarico di LINCS dura 2,1 ore a 4,7 MB/s e quello di Tahoe-100M dura 0,7 ore a 35,7 MB/s, misurati su 100 MB. Per TCGA e per la lettura dei file conto al massimo 3 ore, senza una misura. Il test dura quindi circa 6 ore, quasi tutte di attesa della rete, e circa 4 ore con la sola LINCS. Le 35 ore del confronto con studi non collegati vengono dai 15,1 minuti misurati per 137 gruppi. Lo script indica 32 processori, e il numero effettivo non è registrato.

# 1. I cancelli

Testo in `00-previsioni.md`[^previsioni], commit `beb9723`.

| # | cancello | esito | fonte |
|---|---|---|---|
| 1 | manifesto SHA-256, inizio e fine | **passa**: tutti i file coincidono, due volte | `10-manifesto-e-copia.sh verifica`, `90-cancelli-finali.txt` |
| 2 | riproduzione dell'aggancio sul v15 | **passa**: 111 righe, 111 `metodo_match` uguali, 111 `pert_id` uguali | `10-out.txt` |
| 3 | copertura | **passa**: 194 in una sola classe, somma 194; 40 e 172 righe agganciate per `cluster_id` | `05-classi.R`, `40-out.txt` |
| 4a | positivi e negativo dell'aggancio | **passa**: `bortezomib` ed `erlotinib` per InChIKey completo; l'acido ascorbico resta `nessuno` | `10-out.txt`, `60-out.txt` |
| 4b | circolarità con uno studio aggiunto | **passa**: vede 1 su 1 (`GSE100574`) | `30-out.txt` |
| 4c | ricerca nel testo con la parola di controllo | **passa**: `CRISPR` in 3.633 campioni del bacino, in 4 studi delle 194 | `30-out.txt` |
| 5 | cieco | **passa**: 0 file `.gctx`; `cluster_pooled` letto solo per `cluster_id` e `gene_id` | `90-cancelli-finali.txt`, `40-copertura.R:74` |

# 2. Le previsioni

Conte su tutta la tabella: non hanno intervallo di confidenza.

| # | quantità | attesa | intervallo | valore | esito |
|---|---|---:|---:|---:|---|
| P1 | meta-analisi con almeno una firma `trt_cp` | 72 | [60; 90] | 90 | confermata, sul limite |
| P2 | lo stesso, nelle 40 | 16 | [12; 21] | 20 | confermata |
| P3 | studi fra le serie LINCS note | 0 | [0; 0] | 0 | confermata |
| P4 | studi che citano LINCS, L1000 o CMap | 3 | [0; 26] | 0 | confermata |
| P5 | composti con firma che sono misurabili | 70% | [50%; 90%] | 88,9% (80 su 90) | confermata, vicina al limite |
| P6 | meta-analisi con una firma di ligando | 12 | [8; 15] | **20** | **smentita**, §3 |
| P7 | meta-analisi senza una fonte esterna disponibile | 35% | [25%; 50%] | 43,3% (40,2% con TCGA) | confermata; contando solo le misurabili 50,5% (47,4% con TCGA) |

I margini di P1, P2, P5, P7 sono un mio giudizio.

# 3. I dubbi, e come sono chiusi

**I 111 erano candidati (spiegato).** Il file del 2026-08-07 ha 111 righe con un identificativo di composto, e 90 hanno un `pert_id`. Delle 111 ne restano 91 nelle 194, e dei 90 agganciati ne restano 77. Le 194 hanno 13 candidati nuovi, e 10 si agganciano. Tre entità `STR` con un nome certo si agganciano con un elenco a mano (`atra`, `nutlin 3a`, `1 25 oh 2d3`). Il conto fa 77 + 10 + 3 = 90: il 47% dell'handout veniva da 91 su 194, quindi era giusto per compensazione (`70-out.txt`).

**P6 smentita (spiegato).** L'handout conta 15 citochine da `kind_effective_resolved`. Le entità con identificativo `HGNC` sono 19, più `ifna`: 20, e tutte hanno una firma `trt_lig`. Solo 14 delle 20 hanno `kind = cytokine_stim`. Le altre 6 hanno `small_molecule` (2), `genetic_knockout` (2), `genetic_overexpression` (1) ed `environmental` (1) (`40-out.txt`). L'errore della colonna tocca anche altre entità: `g007_lk` è `disease_vs_normal`, `heart failure` è `environmental`. La classe di questo finding viene dall'identificativo e da un elenco scritto a mano per gli `STR`, da leggere come tale (`40-copertura.R`). **Rinvio** alla sessione sulle figure (S16): non dividere per `kind_effective_resolved`.

**Il soffitto dell'handout va riscritto.** Con le classi corrette le 194 sono 109 piccole molecole, 45 malattie, 20 ligandi, 8 patogeni, 5 ambientali, 5 biologici o aggregati, 2 genetiche. L'handout scriveva 107, 42, 15, 9, 11, 9, 1 per i valori di `kind`.

**DHT non è misurabile in LINCS (spiegato, resta come limite).** Ha 69 firme ma 0 linee attive. `R1881` non è in LINCS. Il controllo interno più forte del progetto non può entrare in questo test. Una causa possibile, che non ho misurato, è che LINCS usa soprattutto linee senza una risposta forte agli androgeni. Il valore si legge in `50-copertura-con-tahoe.csv`.

**Sei studi delle 194 citano TCGA o TARGET (spiegato).** Nessuno sta nei 6 gruppi confrontati con TCGA (`60-out.txt`).

Non resta nessun altro dubbio. Le scelte del PI sono cinque, §In breve.

# 4. Copertura

| classe | meta-analisi (40 / 132 / altre) | con firma LINCS | misurabili | anche in Tahoe | in TCGA |
|---|---:|---:|---:|---:|---:|
| piccola molecola | 109 (25 / 75 / 9) | 90 (20 / 61 / 9) | **80 (19 / 53 / 8)** | 34 (8 / 24 / 2) | 0 |
| ligando | 20 (6 / 10 / 4) | 20 | 16 (5 / 9 / 2) | 0 | 0 |
| malattia | 45 (8 / 31 / 6) | 0 | 0 | 0 | 6 (0 / 5 / 1) |
| patogeno | 8 (1 / 7 / 0) | 0 | 0 | 0 | 0 |
| ambientale | 5 (0 / 5 / 0) | 0 | 0 | 0 | 0 |
| biologico o aggregato | 5 (0 / 4 / 1) | 0 | 0 | 0 | 0 |
| genetica | 2 (0 / 0 / 2) | 0 | 0 | 0 | 0 |
| **totale** | **194** | 110 | **96 (24 / 62 / 10)** | 34 | 6 |

Misurabile vuol dire firme `exemplar` con `tas >= 0,2` in almeno 3 linee. Nel fondo passano 5.466 composti su 34.418, con 36.204 firme, e 164 ligandi su 329. Il valore 0,2 è vicino al quartile superiore di `tas` (0,193). Il 66,6% delle firme `exemplar` ha `qc_pass = 1`: `qc_pass` entra come sensibilità. Tutti i 978 landmark stanno nel deliverable, con una mediana di 971 per gruppo nelle 40 e un minimo di 833.

L'aggancio usa l'InChIKey completo per 71 degli 80 composti misurabili, il blocco di connettività per 3, un sinonimo esatto per 3, l'elenco a mano per 3. Un solo composto misurabile ha una lettera greca nel nome: `17β-estradiol`, nelle 19, per InChIKey (`65-out.txt`).

Tahoe-100M: 379 farmaci, di cui 142 hanno una firma misurabile in LINCS per nome normalizzato. Nessun campione del bacino cita `Tahoe` o `Vevo`. L'archivio pesa 428,8 GB, e la parte con i confronti già calcolati pesa 88,9 GB in 1.026 file. Ogni riga dà gene, `log2FoldChange`, `lfcSE`, `stat`, farmaco, concentrazione, linea, piastra. L'indice in `indici/` ha SHA-256 `7a04c7a6…28`.

TCGA, conte da GDC con `data_type = Gene Expression Quantification` e `workflow_type = STAR - Counts`: 16 progetti hanno almeno 10 normali, per 711 normali e circa 6 GB di coppie (`50-tcga-normali.txt`). `TCGA-PAAD` ha 4 normali: `pdac` resta fuori.

# 5. Circolarità

| controllo | risultato |
|---|---|
| serie LINCS note fra i 1.383 studi delle 194 | 0 |
| serie LINCS note nell'intero bacino ARCHS4 | 0 |
| piattaforme L1000 fra le 12 delle 194 | 0 |
| studi delle 194 che citano LINCS, L1000, CMap, `clue.io` o un identificativo `BRD-` | 0 |
| studi del bacino con una citazione | 1, 16 campioni, `L1000`, fuori dalle 194 |
| `GSE186341` (PANACEA) | **dentro le 194**: non è esterna |
| `GSE139944` (sci-Plex) | nel bacino, fuori dalle 194 |
| `GSE62944` (TCGA ridistribuita in GEO) | fuori dalle 194 |

**Sensibilità.** Il testo è quello dei campioni: titolo, sorgente, caratteristiche. Il riassunto della serie GEO non c'è. L'elenco delle serie LINCS è scritto a mano. Un risultato nullo non prova l'assenza. I dati L1000 non sono RNA-seq, quindi non possono stare nel nostro bacino come campioni: resta il dubbio sui geni inferiti, addestrati su dati GEO, e il disegno li esclude.

# 6. Le decisioni tecniche dell'agente

- **Solo landmark.** I geni inferiti dipendono da un modello addestrato su dati GEO.
- **Rango contro il fondo, e non correlazione nuda.** Il rango confronta il composto giusto con gli altri e il valore del caso si conosce.
- **Primo 10%.** È il criterio di Lim e Pavlidis, quindi il risultato si legge accanto ai loro 17% e 83%[^lim]. La loro interrogazione è una sola condizione, la nostra è una media.
- **Composti nel verdetto, ligandi fuori.** Il fondo dei ligandi è 164 contro 5.466, e la sessione sulle lettere greche (S9) non è ancora fatta.
- **Tahoe-100M invece di sci-Plex.** Tahoe-100M ha i confronti già calcolati e sta fuori da GEO.
- **Niente tessuti normali di GTEx contro TCGA.** Il confronto appaiato sullo stesso paziente evita la differenza fra i due progetti.

# Da dove vengono i numeri del riassunto

Cartella: `analysis/audit/2026-11-04-S6-validazione-disegno/`.

| frase | file | valore |
|---|---|---|
| 96 su 194, 24 delle 40 | `70-out.txt` | totali 62 + 24 + 10; 24 |
| 19 e 53 composti | `70-out.txt` | righe 13 e 14 della tabella |
| 164 voci contro 5.466 | `40-out.txt` | «ligandi misurabili», «5466 su 34418» |
| 16 senza validazione, 8 malattie | `70-out.txt` | elenco finale, 16 righe |
| 1.383 studi, nessuna citazione | `30-out.txt` | «studi distinti», «studi delle 194 con una citazione: 0» |
| 111, 90, 77; 90 su 194 | `70-out.txt` | «i 90 agganciati nelle 194: 77»; `40-out.txt` «P1» |
| ligandi 20 | `40-out.txt` | «P6» |
| TGFB1 piccola molecola | `05-out.txt` | riga 107 della stampa |
| 1 su 10, 17 e 83 su 100 | Lim e Pavlidis, Risultati | 99/588, 486/588, rango ≤ 68 |
| 379 farmaci, 8 delle 19 | `50-tahoe-out.txt` | «farmaci Tahoe», riga `40` della tabella |
| 6 tumori, nessuno nelle 40 | `60-out.txt` | tabella TCGA |
| 8 su 19, 82 su 100; 6 su 19; 11 su 19, 32 su 100; 16, 11, 24 su 53 | `60-soglie-potenza.csv` | righe `n`, `T`, `x_min`, `pot_0.5` |
| 978 geni su 21.758 | `40-out.txt` | «geni nel deliverable» |
| 2,1 h, 4,7 MB/s; 0,7 h, 35,7 MB/s | comandi `curl` della sessione, `curl -I` per le taglie | 35,52 + 0,41 GB; 88,86 GB |
| 15,1 minuti per 137 gruppi con 32 processori | `analysis/audit/2026-11-03-S5-gate-e-insiemi/74-out.txt` | «137 gruppi: 15.1 min»; `WORKERS=32` è nella testata dello script, il valore effettivo non è registrato |
| 35 e 7 ore | calcolo | 15,1 × 193/137 × 99 e × 19, in minuti |

[^previsioni]: `analysis/audit/2026-11-04-S6-validazione-disegno/00-previsioni.md`.
[^lim]: Lim N, Pavlidis P. Sci Rep 2021;11:17624.
