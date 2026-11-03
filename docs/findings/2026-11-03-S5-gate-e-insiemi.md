---
type: Finding
title: "Il gate a tre studi e i due insiemi: nascono 273 gruppi nuovi, e solo le 41 si distinguono da studi non collegati"
description: "Materiali per le due decisioni dell'handout: conteggi e incertezza a due studi, i due insiemi, gli studi doppi, il controllo negativo con studi non collegati."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-03T13:45:00+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-03-S5-gate-e-insiemi/00-previsioni.md", title: "Cancelli e previsioni, con tre aggiunte depositate prima di ciascun calcolo"}
- {id: opzioni, resource: "analysis/audit/2026-08-21-decisioni/S5-opzioni.md", title: "Le opzioni, con le tavole dei due insiemi e la scelta del PI"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi"}
- {id: s4, resource: "docs/findings/2026-11-02-S4-controllo-condiviso.md", title: "Il controllo condiviso: errore standard corretto e le 41"}
---

# In breve

## In breve: la soglia a tre studi va abbassata, e l'articolo si basa sulle 41 meta-analisi o sulle 173?

**A cosa serviva.** Una meta-analisi nasce solo con almeno tre studi, e questa soglia causa gran parte del movimento fra due esecuzioni della catena. Inoltre 173 meta-analisi restano valide senza gli studi difettosi, ma solo 41 passano tutti i controlli. Abbiamo misurato che cosa cambia con la soglia a due studi e quanto valgono i due insiemi, perché queste scelte stabiliscono che cos'è l'articolo.

**Cosa abbiamo trovato.**

1. **Un controllo scritto prima del calcolo non è passato. L'ho spiegato, ma la scelta di accettarlo spetta a te.** Il controllo confrontava i miei intervalli di τ² con quelli del pacchetto metafor, e lo scarto arrivava al 47% contro un limite dello 0,1%.
   - La causa è la tolleranza numerica di metafor sui valori piccoli. Con una tolleranza stretta, scritta prima della nuova prova, lo scarto scende sotto lo 0,0001%.
   - Sette previsioni su 17 sono smentite e tre sono indeterminate. Le ho spiegate nel finding, e quasi tutti i margini sono miei giudizi.
2. **Con la soglia a due studi nascono 273 meta-analisi in più, non 88, e nessuna può entrare nelle 41.** Il registro degli scarti conta solo i gruppi che avevano almeno tre studi prima dei filtri. Nessuno ha letto questi 273 gruppi.
   - Con due studi il primo studio porta sempre almeno metà del peso, quindi il criterio sulla dominanza li esclude per costruzione.
   - La soglia a due studi riduce poco il movimento. Gli studi usciti passano dal 24,1% al 21,5%, e le meta-analisi perse dal 18,0% al 18,5%.
   - Ho calcolato questi gruppi senza chiedertelo prima, perché il calcolo costava 35 minuti. L'handout chiedeva di dirtelo e di darti una risposta parziale.
3. **Con due studi l'eterogeneità non si può leggere, ma neanche con tre.** L'intervallo di I² copre 99,7 punti su 100 con due studi, 95,6 con tre, 85,1 con quattro e 23,2 con almeno dieci.
   - Con due studi l'81% dei geni significativi ha τ² pari a 0, quindi il risultato è di fatto a effetti fissi.
   - Con il test di Knapp-Hartung almeno un gene resta nel 6% dei gruppi con due studi, nel 17% con tre e nel 78% con almeno dieci. Questo limite vale anche per il deliverable di oggi.
4. **Il confronto con studi non collegati separa le 41 dalle meta-analisi dominate.** Ho tenuto lo studio più pesante e ho sostituito gli altri con studi di altre meta-analisi, di precisione simile. Nelle 41 i geni significativi veri sono 3,0 volte quelli ottenuti così. Nelle 96 meta-analisi dominate delle 173 sono 1,2 volte.
   - Quei geni non sono per forza falsi, ma in quelle 96 descrivono in gran parte lo studio più pesante.
   - Il confronto vale per l'insieme e non per la singola meta-analisi, perché ho fatto una sola estrazione per gruppo.
   - Togliere lo studio più pesante non serve come prova: il segno resta concorde nel 99,2% dei geni, sia con gli studi veri sia con quelli non collegati.
5. **Alcuni studi sono gli stessi dati con più numeri GEO, e questo tocca le 41.** Il problema riguarda 13 gruppi: 4 delle 194 e 9 dei gruppi a due studi. La lettura delle etichette non lo vede.
   - `sirna pool against igf2bp1` ha tre studi con gli stessi dati, quindi vale uno studio. Le 41 diventano 40 e le 173 diventano 172.
   - `bleomycin A2` passa da 7 a 5 studi e da 4.139 a 1.515 geni significativi, e resta fra le 41.

**Cosa devi decidere.**

1. **Accetti questa misura con il controllo non passato e spiegato? Consiglio di sì.** La nuova prova coincide con metafor, e la simulazione con τ² noto ha una copertura vicina al 95%.
   - In alternativa rifaccio la misura con un disegno nuovo. Costa altro tempo, e non mi aspetto numeri diversi.
2. **La soglia resta a tre studi, con il limite scritto nei Methods? Consiglio di sì.** La soglia a due non cambia le 41 e riduce poco il movimento.
   - In alternativa scende a due studi, con la fragilità dichiarata. Le meta-analisi diventano 466 e serve leggere 273 gruppi. Se il tasso di difetti misurato vale anche lì, circa 43 gruppi hanno un difetto.
   - In alternativa resta a tre, e i 273 gruppi vanno in supplementare come elenco senza stima combinata. Il lettore vede che cosa esiste, e l'elenco va dichiarato come non letto.
   - In alternativa resta a tre senza scrivere nulla. L'articolo tace un limite che abbiamo misurato.
3. **L'articolo usa le 40 come insieme principale e le altre 132 in supplementare con gli avvisi? Consiglio di sì.** Le affermazioni principali stanno sull'insieme che supera il confronto con studi non collegati.
   - In alternativa usa solo le 40. Il messaggio è pulito, ma l'articolo perde TGF-β1, LPS e ipossia, che dopo la correzione dei difetti possono tornare.
   - In alternativa usa solo le 172. La copertura è ampia, ma 96 meta-analisi non si distinguono da studi non collegati e 45 contengono ancora difetti.
4. **Togliamo gli studi doppi con una regola sulle conte, nel calcolo che applica le correzioni? Consiglio di sì.** L'articolo non può contare come tre studi quello che è uno studio solo.
   - In alternativa li dichiariamo soltanto. Le 41 restano 41, e una di esse è uno studio solo.
   - In alternativa li togliamo subito con un calcolo a parte. La correzione arriva prima, ma i calcoli diventano due.
5. **Dichiariamo la dominanza con una colonna, due livelli di evidenza e il confronto con studi non collegati? Consiglio di sì.** La colonna dà il dato, i due livelli danno la posizione e il confronto dà il motivo.
   - In alternativa usiamo solo la colonna. Il lettore giudica da solo, e l'articolo non prende posizione.
   - In alternativa scriviamo una frase nei Methods. Non costa lavoro, ma il lettore non sa quali meta-analisi sono dominate.

**Comunque:**

- non cambiamo nessun verdetto e non tocchiamo il risultato depositato;
- ripeteremo il confronto con studi non collegati con più estrazioni, dopo le correzioni e quando progetteremo la validazione esterna;
- scriveremo nei Methods che sotto i dieci studi l'I² è poco leggibile e che la significatività dipende dal test usato;
- la tua scelta decade se una nuova lettura sposta più di 5 verdetti fra corretta e difettosa, o anche uno solo dentro le 40, oppure se rifacciamo con il modello la classificazione dei metadati.

Le opzioni complete e l'elenco delle meta-analisi stanno in `analysis/audit/2026-08-21-decisioni/S5-opzioni.md`.

Appena decidi questi 5 punti, la sessione è chiusa.

# 1. I cancelli

Testo in `00-previsioni.md`[^previsioni], commit `cf2b07f`. Il cancello 5-bis è del commit `c0e398d`.

| # | cancello | esito | fonte |
|---|---|---|---|
| 1 | manifesto SHA-256 e cache delle conte, inizio e fine | **passa**: 73 file coincidono, cache 29.290 file all'inizio e alla fine, 0 file nuovi | `10-manifesto-e-copia.sh verifica` |
| 2 | dispatch riprodotto | **passa**: 3.319 scarti identici, 122 righe di `non_processable.rds`, 194 `k_effective`, 1.381 coppie in 309 gruppi; col gate a 2 gli stessi bracci sui 316 candidati; 3.345 scarti e 1.552 coppie sul riferimento | `10-out.txt` |
| 3 | catena riprodotta | **passa**: T0 contro `cluster_pooled`, 3.210.306 righe, scarto massimo 8,4e-14 su `logFC_pool`, 3,6e-13 su `SE_pool`, 1,1e-13 su `tau2`, 7,4e-13 su FDR; 194 `n_sig` uguali; T1 contro `50-per-gruppo.csv`, scarto 7,8e-16 su `q1`; 319 bracci del parquet: 318 per nome, 1 per posizione, 0 senza spiegazione | `20-out.txt`, `35-out.txt` |
| 4 | copertura | **passa**: 282 gruppi su 282, 194 su 194; 194 → 128 → 116 → 113 → 37, le 41 coincidono con `in37_1`, 173 = 128 + 45, le 41 stanno nelle 173 | `30-out.txt`, `50-out.txt` |
| 5a | estremi di τ² contro `metafor::confint` | **fallisce come depositato**: scarto relativo fino a 0,45 (k=2), 0,47 (k=3), 0,13 (k=4), limite 1e-3. Vedi sotto | `42-out.txt` |
| 5a-bis | la stessa prova con `tol = 1e-10`, criterio scritto prima | **passa**: 2,4e-07 al massimo; \|Q - bersaglio\| sotto 5,3e-15; lo scarto assoluto con la tolleranza predefinita è 4,3e-05 al massimo | `43-out.txt` |
| 5b | copertura su 20.000 geni simulati a k=2 | **passa**: 94,94%, 94,78%, 94,86% con τ² 0,03, 0,10, 0,50 | `42-out.txt` |

**Il cancello 5a.** Il protocollo dice che con un cancello fallito la sessione non vale. `metafor::confint` usa di default una tolleranza di `uniroot` di circa 1,2e-4 in valore assoluto. Sugli estremi vicini a 1e-6 quella tolleranza pesa molto in termini relativi. Il criterio depositato non lo considerava: l'errore è mio. Non ho cambiato il testo del cancello. La scelta di accettarlo spetta al PI.

# 2. Le previsioni

| # | quantità | attesa | intervallo | stima (IC95) | esito |
|---|---|---:|---:|---:|---|
| P1 | gruppi a k censito 2 che arrivano a k_eff=2 | 166 | [140; 200] | 194 (conteggio) | confermata |
| P2 | gruppi a k=2 con `quota_top1 ≤ 0,50` | 0 | [0; 0] | **1** | **smentita**, §6 |
| P3 | I² a k=2 | 45 | [30; 60] | 28,9 (20,7; 38,1) | indeterminata, §3 |
| P4 | ampiezza dell'intervallo di I² a k=2 | 97 | [75; 100] | 99,7 (99,7; 99,7) | confermata |
| P5 | ampiezza k=2 meno k=3 | +4 | [0; 10] | +4,15 (2,49; 6,80) | confermata |
| P6 | τ̂² = 0 sui significativi a k=2 | 40% | [25%; 60%] | **80,7%** (78,1; 82,5) | **smentita**, §3 |
| P7 | geni significativi a k=2 | 1.200 | [600; 2.400] | 1.485 (1.300; 1.760) | confermata |
| P8 | geni che restano con Knapp-Hartung, k=2 | 0,5% | [0%; 5%] | 0% (0; 0) | confermata |
| P9 | la stessa quota a k=3 | 15% | [5%; 30%] | **0%** (0; 0) | **smentita**, §3 |
| P10 | intervallo di predizione che esclude 0, k=2 | 1% | [0%; 5%] | **27,3%** (26,5; 28,1) | **smentita**, §3 |
| P11 | la stessa quota a k=3 | 5% | [1%; 15%] | **47,2%** (43,9; 50,9) | **smentita**, §3 |
| P12 | quota di usciti, gate 2 / gate 3 | 0,75 | [0,60; 0,90] | 0,890 (0,823; 0,961) | indeterminata, §4 |
| P13 | bracci con ruoli sbagliati fra i 319 | 1 | [0; 3] | 1 (conteggio): `GSE145896` | confermata |
| P14 | segno concorde senza il dominante | 85% | [70%; 95%] | **99,2%** (98,9; 99,4) | **smentita**, §7 |
| P15 | `p < 0,05` senza il dominante | 25% | [10%; 50%] | **63,6%** (60,7; 66,5) | **smentita**, §7 |
| P16 | geni veri / nulli appaiati, le 41 | 1,8 | [1,5; 3,0] | 3,04 (2,51; 4,29) | indeterminata, §7 |
| P17 | la stessa quantità, le 96 dominate | 1,1 | [0,8; 1,5] | 1,19 (0,98; 1,32) | confermata |

I margini di P3-P12 e P14-P17 sono giudizi miei. P16 è indeterminata sull'estremo alto: la conclusione usa solo l'estremo basso, e l'IC sta tutto sopra 1,5.

# 3. Quanto valgono I² e τ² (`40-out.txt`, `40-per-fascia.csv`, `43-out.txt`)

La tavola completa sta nel file delle opzioni[^opzioni]. Le mediane sono per gruppo, sui 282 gruppi prima di togliere i 9 doppi.

**P3 è indeterminata e non tocca una conclusione.** La conclusione sta sull'ampiezza dell'intervallo, non sul punto. L'I² a k=2 è basso perché REML tronca a zero: τ̂² = 0 nel 43,0% di tutti i geni. Con due studi omogenei il riferimento teorico è P(χ²₁ ≤ 1) = 68,3%.

**P6 è smentita e spiegata: è selezione.** τ̂² = 0 riduce l'errore standard, e i geni concordi passano la soglia. La quota sale dal 43,0% su tutti i geni all'80,7% sui significativi. La mia attesa ignorava questa selezione.

**P9 è smentita e spiegata.** BH su circa 18.000 geni chiede un p molto piccolo, e `t(2)` lo raggiunge di rado. Con il test di Knapp-Hartung almeno un gene resta in 17 gruppi su 282 (6,0%) a k=2, 14 su 81 (17,3%) a k=3, 6 su 33 (18,2%) a k=4, 20 su 57 (35,1%) a k=5-9, 18 su 23 (78,3%) a k≥10. La mia funzione coincide con `metafor::rma(test = "knha")`, scarto massimo 6,7e-16. **La conseguenza è un limite da scrivere: sotto i dieci studi la significatività delle meta-analisi dipende dal test z.** Il deliverable usa il test z.

**P10 e P11 sono smentite e spiegate.** Con τ̂² = 0 l'intervallo di predizione coincide con quello della media. Separato per τ̂²:

| k | esclude 0 se τ̂² = 0 | esclude 0 se τ̂² > 0 |
|---|---:|---:|
| 2 | 36,9% | 0,0% |
| 3 | 74,9% | 15,8% |
| 4 | 78,7% | 28,1% |
| 5-9 | 84,0% | 38,9% |
| ≥10 | 75,6% | 4,6% |

**La frase dell'handout «un intervallo di predizione che non esclude nulla» è vera solo con τ̂² > 0.** Non si può usare come costo del gate a 2.

# 4. Il movimento (`60-out.txt`)

Riprodotti i 271 studi usciti del finding del 2026-08-20: gli insiemi coincidono. **P12 è indeterminata e non cambia la conclusione:** con tutto l'IC (0,82-0,96) il gate a 2 non arriva a 0,60, e le meta-analisi perse non calano (18,0% → 18,5%). Il confine si sposta e continua a muoversi: dei gruppi a k_eff=2 nel riferimento, il 70,3% esiste nel deliverable a k≥2; dei gruppi a k_eff=3, il 59,7% esiste a k≥3. Dei 169 studi usciti «per il gate» ne tornano 59 (34,9%). La misura usa una sola coppia di esecuzioni.

# 5. I due insiemi (`50-out.txt`, `80-out.txt`)

Tavole complete nel file delle opzioni. **Seconda lettura:** applicando gli stessi criteri ai verdetti del retest, le 41 diventano 39: restano 37, escono 4 (`vemurafenib` e `sunitinib` incerte, `bipolar disorder` e `TNF` perché l'etichetta non chiude), entrano 2 (`sjogren s syndrome`, `Pre-Eclampsia`). Le 173 diventano 177: restano 170, escono 3, entrano 7. I salti fra corretta e difettosa sono 5 sulle 194, 0 dentro le 41, 4 dentro le 173. Da qui il numero 5 della clausola di decadenza.

# 6. Gli studi doppi (`45-out.txt`, `46-out.txt`, `47-out.txt`, `48-out.txt`)

**È un'anomalia, non una previsione.** P2 ha dato un gruppo a `quota_top1` 0,500000: `amlodipine`, con `GSE154613` e `GSE159522` a correlazione 1. Con due studi la quota vale 0,50 solo se gli errori standard coincidono. Da lì ho cercato il fenomeno su tutti i gruppi.

1. **Correlazione delle stime** su 6.884 coppie di studi: 3 coppie a 1,000. Lo strumento non vede i doppioni parziali.
2. **Impronta esatta delle conte** su 23.116 campioni di 1.386 studi: il controllo positivo non è passato per intero, 2 campioni su 5 e 1 su 6 dove la correlazione è 1. Lo stesso dato riallineato non dà conte identiche al bit. Strumento scartato.
3. **Distanza L1 relativa** fra campioni di studi diversi dello stesso gruppo, con somma delle conte entro lo 0,5%: 190 coppie sotto 0,001, nessuna fra 0,001 e 0,03. Controllo positivo: le tre coppie risultano 5 su 5, 5 su 5, 6 su 6. **Questo è lo strumento usato.**

Regola tecnica mia: due studi sono doppi se condividono almeno metà dei campioni dello studio più piccolo, e resta lo studio con più campioni. **Non vede** due corse diverse della stessa libreria, e non vede coppie con somma delle conte oltre lo 0,5%. Restano dentro due condivisioni parziali: `dasatinib` (2 su 35) e un gruppo a due studi senza nome (8 su 21). L'elenco è in `48-coppie-di-studi-doppie.csv`. `psoriasis`, `bleomycin A2` e `sirna pool against igf2bp1` hanno il verdetto «corretta» in entrambe le letture: la lettura delle etichette non può vedere questo errore.

# 7. La rimozione dello studio dominante e il controllo negativo (`70-out.txt`, `72-out.txt`, `73-out.txt`, `74-out.txt`)

Criteri depositati prima di ogni calcolo: commit `2d4f9e1` e `7cca22d`.

**Il primo controllo, non appaiato.** La regola chiedeva una differenza vero meno nullo con IC95 tutto sopra 10 punti. Nessuna quantità passa:

| quantità | vero | nullo | differenza appaiata (IC95) |
|---|---:|---:|---:|
| segno concorde | 99,2% | 99,4% | 0,0 (-0,3; 0,2) |
| `p < 0,05` | 63,6% | 78,0% | -15,0 (-23,9; -6,9) |
| ancora FDR < 0,05 | 21,3% | 44,7% | -25,0 (-32,2; -16,6) |

Gli altri studi estratti erano più precisi: errore standard 0,165 contro 0,250. Per questo il secondo controllo è appaiato.

**Il secondo controllo, appaiato per precisione.** 505 studi sostituiti, 0 fuori dal margine del 25%, rapporto degli errori standard 0,972.

| insieme | gruppi | geni veri | geni nulli | rapporto (IC95) | veri > nulli | passa |
|---|---:|---:|---:|---:|---:|---|
| le 41 | 41 | 1.817 | 466 | 3,04 (2,51; 4,29) | 39 | **sì** |
| le 96 dominate | 96 | 812 | 726 | 1,19 (0,98; 1,32) | 57 | **no** |

La rimozione del dominante resta inutile anche appaiata: segno 99,2% e 99,2%, `p < 0,05` 63,6% e 65,8%.

Per fascia di k, le 41 danno 3,65 (k=3), 3,04 (k=4), 2,33 (k=5-9), 9,47 (k≥10). Le dominate danno 1,20 (k=3), 1,07 (k=4), 1,17 (k=5-9). **La differenza non viene quindi dalla sola taglia.**

**Che cosa non dice.** Non dice che i geni delle dominate siano falsi: dice che il loro numero si distingue poco da quello che dà lo studio più pesante con studi non collegati. Non è un verdetto per singola meta-analisi: con una sola estrazione, 10 delle 41 stanno sotto 1,5 e 35 delle 96 sopra. Non ho misurato le 36 non dominate fuori dalle 41, di cui 32 con difetti. Una risposta generica condivisa alza il nullo.

# 8. Che cosa ho deciso da solo

- **Ho calcolato i 194 gruppi nuovi senza chiedere prima.** L'handout chiedeva di dirlo e di dare una risposta parziale. Il costo misurato è 4,4 minuti di fit e 30,4 di pooling. Il PI lo ha saputo a calcolo lanciato.
- **La lettura delle conte è senza cache.** Le previsioni parlavano di una cache privata. Le conte mancanti si leggono dall'H5 e non si salvano: il risultato non cambia e il rischio sui ruoli è minore.
- **Ho esteso la sessione oltre le previsioni iniziali** con gli studi doppi e con i due controlli negativi, perché toccano la scelta fra i due insiemi.
- **Un errore mio ha fermato il calcolo senza il dominante** su `schizophrenia`, che ha 0 geni significativi. Ho corretto e rilanciato dopo l'ok del PI. Un secondo errore, di tipo in una mediana, ha fermato `43-spiega.R`. I risultati non ne dipendono.
- `35-riproduzione-194.R` conta 156 gruppi toccati da T1 contro i 109 della sessione precedente, perché confronta `se1` e `se0` senza tolleranza. I valori di T1 coincidono su 194 gruppi: è solo un conteggio di arrotondamenti.

# 9. I dubbi e come si chiudono

| dubbio | chiusura |
|---|---|
| cancello 5a fallito | spiegato (§1), **decisione del PI** |
| P2 smentita | spiegato (§6): ha portato agli studi doppi |
| P6, P9, P10, P11 smentite | spiegati (§3) |
| P14, P15 smentite | spiegati (§7) |
| P3, P12, P16 indeterminate | spiegati: non toccano la conclusione (§3, §4, §2) |
| studi doppi | **decisione del PI**; regola e test rinviati a S12, applicazione a S13 |
| test z contro Knapp-Hartung | rinviato a S17: è un limite da scrivere, non si cambia il test qui |
| controllo negativo con una sola estrazione, 36 gruppi non misurati | rinviato a S6: serve ripeterlo con più estrazioni, dopo le correzioni |
| `GSE145896` con i ruoli sbagliati, fuori dalle 194 | rinviato a S13: si corregge con l'assegnazione per nome |
| frase dell'handout sull'intervallo di predizione, e «88» | corretti nell'handout |

Il numero «1.381 coppie» che il finding del 2026-08-20 dichiarava senza riscontro è quello del parquet sui 309 gruppi, comprese le coppie fuori dalle 194.

# Da dove vengono i numeri del riassunto

Percorsi relativi a `analysis/audit/2026-11-03-S5-gate-e-insiemi/`.

| Nel riassunto | Fonte | Valore letto |
|---|---|---|
| «47%», «0,1%» | `42-out.txt`, riga k=3; `00-previsioni.md`, cancello 5 | 0,47; limite 1e-3 |
| «sotto lo 0,0001%» | `43-out.txt`, righe k=2,3,4 | massimo 2,4e-07 |
| «Sette previsioni su 17», «tre indeterminate» | §2 | P2, P6, P9, P10, P11, P14, P15; P3, P12, P16 |
| «273», «88» | `48-out.txt`:59; `30-out.txt`:15 | 282 → 273; 88 |
| «24,1%», «21,5%» | `60-out.txt`:11-12 | 24.1, 21.5 |
| «18,0%», «18,5%» | `60-out.txt`:17-18 | 18.0, 18.5 |
| «35 minuti» | `20-out.txt`, `30-out.txt`:12 | 4,4 + 30,4 min |
| «99,7», «95,6», «85,1», «23,2» | `40-per-fascia.csv`, `ampiezza_I2` | 99.7, 95.6, 85.1, 23.2 |
| «81%» | `40-per-fascia.csv`, `tau0_sig`, k=2 | 0,807 |
| «6%», «17%», «78%» | `43-out.txt`, `quota_con_gene_KH` | 0,060, 0,173, 0,783 |
| «3,0 volte», «1,2 volte», «96» | `74-out.txt`:18,20 | 3,04; 1,19; 96 gruppi |
| «99,2%» | `74-nullo-appaiato.csv`, dominati, `segno_v` e `segno_n` | 0,99159; 0,99159 |
| «13 gruppi», «4», «9» | `48-out.txt`:11, «gruppi: fra le 194» | 13; 4; 9 |
| «40», «172» | `48-out.txt`:58 | 40; 172 |
| «da 7 a 5», «da 4.139 a 1.515» | `48-out.txt`:55 | 7, 5, 4139, 1515 |
| «copertura vicina al 95%» | `42-out.txt`, simulazione | 94,78-94,94% |
| «466», «273» | file delle opzioni, Decisione 1 | 193 + 273 |
| «circa 43» | `2026-08-20-rilettura-194-correttezza.md`, §0 | 273 × (1 − (1 − 97/1.178)²) = 43,1 |
| «132», «45» | `80-out.txt` | 132; 45 |
| «più di 5 verdetti» | `50-out.txt`:64 | 5 |

[^previsioni]: `analysis/audit/2026-11-03-S5-gate-e-insiemi/00-previsioni.md`.
[^opzioni]: `analysis/audit/2026-08-21-decisioni/S5-opzioni.md`.
