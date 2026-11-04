# Le opzioni per il gate e per i due insiemi (sessione S5)

**Stato (2026-11-04): il PI ha scelto.** La scelta è scritta nella sezione «La scelta del PI». Il testo
delle opzioni resta com'era quando il PI ha scelto. Deliverable:
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`.
Finding: `docs/findings/2026-11-03-S5-gate-e-insiemi.md`.
Evidenza: `analysis/audit/2026-11-03-S5-gate-e-insiemi/`.

## Due cose da sapere prima di scegliere

1. **La dominanza è già corretta.** La misura sul controllo condiviso (S4) è fatta: con l'errore
   standard corretto le 37 diventano 41. Questa sessione aggiunge gli studi doppi, trovati oggi: con
   quelli tolti le 41 diventano 40 e le 173 diventano 172. Tutte le stime di questo file usano l'errore
   standard corretto. Il deliverable su disco resta quello di prima fino al calcolo che applica le
   correzioni (S13).
2. **I verdetti possono cambiare ancora.** La lettura dei falsi allarmi del rilevatore (S11) può spostare
   righe di `difetti.csv`, da cui escono 128, 66, 173 e 41. Una seconda lettura delle stesse etichette
   ha già spostato 5 meta-analisi su 194 fra «corretta» e «difettosa». Vedi la clausola in fondo.

## Decisione 1: il gate

**Quante nascono.** Con il gate a 2 nascono **282 gruppi, non 88**. Il gate agisce due volte: sul numero
di studi del censimento, poi su quello dopo i filtri. `non_processable.rds` registra solo la seconda.

| | gruppi |
|---|---:|
| almeno 3 studi nel censimento, 2 dopo i filtri (i «88» dell'handout) | 88 |
| 2 studi nel censimento, 2 dopo i filtri | 194 |
| totale a 2 studi | **282** |
| con due numeri GEO per gli stessi dati, quindi un solo studio vero | 9 |
| **gruppi veri a 2 studi** | **273** |
| di questi, senza nessun gene significativo | 5 |

Elenco: `80-gruppi-a-due-studi.csv`. **Risposta completa, non parziale:** i 194 nuovi non avevano un fit su
disco. Fit e pooling sono costati 35 minuti, senza toccare deliverable e cache. Li ho eseguiti senza
chiedertelo prima, e lo dichiaro.

**Quanto valgono I² e τ²** (mediane per gruppo, IC95 bootstrap sui gruppi; errore standard corretto):

| | k=2 | k=3 | k=4 | k=5-9 | k≥10 |
|---|---:|---:|---:|---:|---:|
| gruppi | 282 | 81 | 33 | 57 | 23 |
| I² | 28,9 (20,7-38,1) | 57,7 (46,5-69,8) | 70,4 (50,2-81,1) | 68,5 (57,7-77,6) | 86,5 (81,0-91,0) |
| intervallo di I², estremi mediani | 0 - 99,9 | 0 - 99,4 | 1,1 - 98,9 | 12,3 - 97,6 | 70,5 - 97,1 |
| **ampiezza dell'intervallo di I², punti** | **99,7** | **95,6** | **85,1** | **79,6** | **23,2** |
| τ² | 0,012 | 0,029 | 0,062 | 0,066 | 0,118 |
| estremo superiore di τ² | 66,8 | 6,31 | 2,22 | 1,30 | 0,55 |
| τ̂² = 0 sui geni significativi | **80,7%** | 59,1% | 41,0% | 37,1% | 6,7% |
| τ̂² = 0 su tutti i geni | 43,0% | 25,3% | 15,3% | 13,8% | 3,9% |
| geni significativi | 1.485 | 1.146 | 1.203 | 837 | 1.877 |
| gruppi con almeno un gene col test di Knapp-Hartung | **6,0%** | 17,3% | 18,2% | 35,1% | 78,3% |
| geni con intervallo di predizione che esclude 0 | 27,3% | 47,2% | 46,7% | 56,2% | 9,6% |

Che cosa si legge:

- **A k=2 l'I² non dice nulla, ma il gate a 3 non risolve il problema.** L'intervallo diventa leggibile
  solo da 10 studi in su. Fra k=2 e k=3 la differenza è 4,2 punti (2,5-6,8).
- **A k=2 il risultato è di fatto a effetti fissi:** l'81% dei geni significativi ha τ̂² = 0.
- **La frase dell'handout «un intervallo di predizione che non esclude nulla» è sbagliata.** A k=2 esclude
  0 nel 27,3% dei geni significativi. Vale solo con τ̂² > 0 (0%), mentre con τ̂² = 0 esclude 0 nel 36,9%.
- **La significatività di quasi tutte le meta-analisi con meno di 10 studi dipende dal test z.** Vale anche
  per le 194. Va scritto nei Methods.

**Dominanza.** A k=2 il primo studio porta sempre almeno metà del peso, quindi **nessun gruppo a 2 studi può
entrare nelle 41**. L'unico caso a 0,50 esatto è `amlodipine`, che è un doppione.

**Stabilità.** Il gate a 2 non cura il movimento fra le due esecuzioni:

| | gate 3 | gate 2 |
|---|---:|---:|
| studi usciti | 271 su 1.123 (24,1%) | 330 su 1.537 (21,5%) |
| meta-analisi perse | 18,0% | 18,5% |
| coppie (meta-analisi, studio) perse | 26,4% | 24,6% |

Il rapporto fra le quote di studi usciti è 0,89 (0,82-0,96). Dei 169 studi usciti «per il gate» ne tornano 59.

**Le 21 che escono togliendo i difetti.** Con il gate a 2 ne restano 16, e 5 escono comunque.

| opzione | conseguenza |
|---|---|
| **A. Resta a 3, il limite si scrive nei Methods (raccomandata)** | 194 meta-analisi (193 senza gli studi doppi). L'articolo dice che 3 è una convenzione: da 3 a 9 studi l'I² resta poco leggibile. Nessuna lettura in più. |
| B. Scende a 2, con la fragilità dichiarata | 466 meta-analisi (193 + 273, senza gli studi doppi). Servono la lettura di 273 gruppi mai letti: se il tasso di 8,2% per studio vale anche lì, circa 43 hanno un difetto. Le 41 non cambiano. Il movimento cambia poco. |
| C. Resta a 3, e i 273 vanno in supplementare come elenco, senza stima combinata | Il lettore vede che cosa esiste. Nessuna stima fragile. L'elenco va dichiarato come non letto. |
| D. Resta a 3, senza scrivere nulla | Nessun lavoro. L'articolo tace un limite che abbiamo misurato. |

## Decisione 2: 40 o 172

**La misura nuova: il confronto con studi non collegati.** Ho tenuto lo studio che pesa di più e ho
sostituito gli altri con studi di altre meta-analisi, di precisione simile. Una estrazione per gruppo.

| | gruppi | geni veri | geni con studi non collegati | rapporto (IC95) |
|---|---:|---:|---:|---:|
| **le 41** | 41 | 1.817 | 466 | **3,04 (2,51-4,29)** |
| **le 96 dominate delle 173** | 96 | 812 | 726 | **1,19 (0,98-1,32)** |

Nelle 96 dominate il numero di geni significativi non si distingue da quello che si ottiene con studi non
collegati. **Non vuol dire che quei geni siano falsi:** vuol dire che descrivono in gran parte lo studio più
pesante. Il confronto vale per l'insieme, non per la singola meta-analisi: con una sola estrazione, 10 delle
41 stanno sotto 1,5 e 35 delle 96 stanno sopra. Non ho misurato le 36 non dominate fuori dalle 41.

**I due insiemi.**

| | le 40 | le 172 |
|---|---:|---:|
| k mediano | 5 | 4 |
| k=3 | 9 | 62 |
| k≥10 | 6 | 23 |
| geni significativi, mediana | 1.628 | 1.149 |
| un solo studio oltre metà del peso | 0 | 96 |
| contengono difetti | 0 | 45 (peso mediano 14,7%, massimo 47,7%) |
| seconda lettura: corretta | 38 su 40 | 110 su 172 |

Le 132 che stanno nelle 172 e fuori dalle 40, per primo criterio non passato: 72 dominate, 45 con difetti, 12
incerte, 3 dove l'etichetta non chiude il verdetto. **Le meta-analisi più grandi stanno fuori dalle 40:**
`TGFB1` (54), `lipopolysaccharide` (33), `hypoxia` (27), `SARS-CoV-2` (25), `JQ1` (25). Sono fuori per i
difetti, non per la dominanza. `TNF` (36) è l'unica fra le più grandi a restare dentro.

| opzione | conseguenza |
|---|---|
| **A. Tutte e due, con ruoli diversi: le 40 nelle figure principali, le altre 132 in supplementare con gli avvisi (raccomandata)** | Le affermazioni principali stanno sull'insieme che supera il confronto con studi non collegati. Nulla si perde. Il lavoro è una colonna di avvisi. |
| B. Solo le 40 | Messaggio pulito. L'articolo perde `TGFB1`, LPS, ipossia e le altre grandi entità, che dopo la correzione dei difetti possono tornare. |
| C. Solo le 172 | Copertura ampia. L'articolo pubblica 96 meta-analisi dove il numero di geni non si distingue da studi non collegati, e 45 con difetti ancora dentro fino alla correzione. |

**Se scegli il gate a 2:** le 40 non cambiano, le 172 diventano 188 (entrano le 16 a due studi dopo i difetti).

## Decisione 3: gli studi doppi

Due numeri GEO possono contenere gli stessi dati. Li ho trovati confrontando le conte campione per campione
(distanza sotto 0,001: 190 coppie di campioni, nessuna fra 0,001 e 0,03). 13 gruppi hanno almeno due studi con
almeno metà dei campioni uguali: 4 delle 194 e 9 dei 282.

| meta-analisi | studi | geni | primo studio | conseguenza |
|---|---:|---:|---:|---|
| `sirna pool against igf2bp1` | 3 → 1 | 6.177 | 0,49 | non è una meta-analisi: esce dalle 41 e dalle 173 |
| `bleomycin A2` | 7 → 5 | 4.139 → 1.515 | 0,16 → 0,22 | resta nelle 41 |
| `psoriasis` | 9 → 8 | 356 → 297 | 0,42 → 0,45 | resta nelle 41 |
| `R1881 (metribolone)` | 18 → 17 | 7.965 → 7.002 | 0,06 → 0,07 | resta nelle 173 |

| opzione | conseguenza |
|---|---|
| **A. Si tolgono nel calcolo che applica le correzioni, con una regola sulle conte e con i test (raccomandata)** | 41 → 40, 173 → 172. Regola, non lista: costruita e provata col rilevatore. |
| B. Si dichiarano soltanto | Le 41 restano 41, e una di esse è uno studio solo. L'articolo pubblica un conteggio di studi che sappiamo falso. |
| C. Si tolgono subito con un calcolo a parte | Arriva prima, ma i calcoli diventano due. |

Due casi di condivisione parziale restano dentro: `dasatinib` (2 campioni su 35) e un gruppo a due studi senza
nome (8 su 21). Lo strumento non vede due corse diverse della stessa libreria.

## Decisione 4: come dichiarare il limite della dominanza

**Una cosa da non usare.** Togliere lo studio più pesante sembra una prova, ma non lo è: il segno resta concorde
nel 99,2% dei geni nei gruppi veri e nel 99,2% con studi non collegati. Il modello penalizza i geni discordanti,
quindi i geni significativi sono concordi per selezione. Nessuna delle tre quantità ha passato la regola scritta
prima.

| modo | testo | conseguenza |
|---|---|---|
| **1. Una colonna per ogni meta-analisi (raccomandato)** | «Accanto a ogni meta-analisi riportiamo il peso del primo studio, il numero efficace di studi e il nome dello studio più pesante.» | Il lettore giudica da solo. Costa una colonna. |
| **2. Due livelli di evidenza (raccomandato)** | «Le meta-analisi in cui un solo studio porta più di metà del peso sono riportate a parte: il loro risultato descrive in gran parte quello studio.» | L'articolo prende posizione. Richiede la scelta A sopra. |
| **3. Il confronto con studi non collegati (raccomandato)** | «Con studi non collegati di precisione simile, i geni significativi sono un terzo nelle meta-analisi non dominate, e quasi uguali in quelle dominate.» | È l'argomento più forte. Va rifatto dopo le correzioni, con più estrazioni. |
| 4. Una sola frase nei Methods | «In una parte delle meta-analisi un solo studio porta la maggior parte del peso.» | Nessun lavoro. Il lettore non sa quali. |

## Clausola di decadenza

La scelta **decade** se succede una di queste cose:

- la lettura dei falsi allarmi sposta **più di 5** verdetti fra «corretta» e «difettosa» sulle 194 (5 è lo
  spostamento misurato fra due letture), **o anche uno solo dentro le 40**;
- si esegue il re-run completo degli stadi LLM (S14).

Il calcolo che applica le correzioni (S13) rigenera le liste, ma non fa decadere la scelta. Se una meta-analisi
passa il limite del 50%, la lista cambia e la regola resta. Quattro stanno vicine: `Parkinson Disease` 0,486,
`bipolar disorder` 0,491, `MIVEBRESIB` 0,491, `ykl 5 124` 0,497.

## La scelta del PI

**2026-11-04.** Il PI ha chiesto una forma più semplice delle 5 decisioni e a quella forma ha risposto
«si a tutte».

- Accettazione della misura con il cancello 5(a) fallito e spiegato: **accettata.** Il fallimento resta scritto
  nel finding, §1. Il cancello 5-bis non lo cancella.
- Gate: **opzione A.** Il gate resta a 3 studi e il limite si scrive nei Methods (S17).
- Insiemi: **opzione A.** Le 40 stanno nelle figure principali, le altre 132 in supplementare con gli avvisi.
- Studi doppi: **opzione A.** Si tolgono nel calcolo che applica le correzioni (S13), con una regola sulle conte
  e con i test. Quindi 41 → 40, 173 → 172, 194 → 193.
- Modo di dichiarare la dominanza: **modi 1, 2 e 3 insieme.** La colonna, i due livelli e il confronto con
  studi non collegati, da rifare con più estrazioni dopo le correzioni.
- Numero N della clausola: **5**, o anche uno solo dentro le 40. Il numero viene dal riassunto letto dal PI.
  Non era una delle 5 domande, e il PI non lo ha contestato.

## Tavola: le 40

Geni con l'errore standard corretto. «Primo studio» è il peso dello studio più pesante.

| meta-analisi | k | geni | primo studio | studi efficaci | I² | che cosa dichiarare |
|---|---:|---:|---:|---:|---:|---|
| TNF | 36 | 7.344 | 0,04 | 30,53 | 83 | nessun avviso |
| 5-aza-2'-deoxycytidine | 12 | 3.277 | 0,12 | 9,71 | 88 | nessun avviso |
| IL13 | 11 | 1.390 | 0,19 | 7,51 | 72 | nessun avviso |
| sorafenib | 11 | 575 | 0,34 | 4,18 | 89 | nessun avviso |
| tazemetostat | 10 | 1.439 | 0,15 | 8,31 | 86 | nessun avviso |
| IL6 | 10 | 198 | 0,40 | 3,97 | 41 | nessun avviso |
| crizotinib | 9 | 492 | 0,48 | 2,89 | 87 | nessun avviso |
| 17β-estradiol | 9 | 377 | 0,46 | 3,02 | 87 | nessun avviso |
| psoriasis | 9 | 356 | 0,42 | 2,98 | 61 | geni da 543 a 356 con l'errore standard corretto; studi doppi da togliere: GSE89725 (k=8, geni 297) |
| Parkinson Disease | 8 | 687 | 0,49 | 3,02 | 54 | GSE208347 ha un braccio sbagliato e i ruoli sbagliati (peso sotto 1%) |
| bleomycin A2 | 7 | 4.139 | 0,16 | 6,94 | 95 | studi doppi da togliere: GSE222279, GSE156184 (k=5, geni 1515) |
| sunitinib | 7 | 387 | 0,43 | 3,24 | 48 | alla seconda lettura: incerta |
| endometriosis | 7 | 62 | 0,45 | 3,23 | 41 | GSE135485 ha i ruoli sbagliati nel deliverable |
| valproic acid | 6 | 2.950 | 0,37 | 3,69 | 69 | nessun avviso |
| tunicamycin | 6 | 2.209 | 0,26 | 4,89 | 83 | nessun avviso |
| EGF | 6 | 2.088 | 0,22 | 5,46 | 91 | nessun avviso |
| GSK126 | 6 | 1.193 | 0,48 | 2,81 | 65 | nessun avviso |
| nash | 6 | 568 | 0,42 | 3,35 | 58 | nessun avviso |
| Colitis, Ulcerative | 5 | 2.808 | 0,42 | 3,17 | 52 | nessun avviso |
| vemurafenib | 5 | 2.348 | 0,32 | 3,88 | 89 | alla seconda lettura: incerta |
| selinexor | 5 | 2.090 | 0,46 | 2,86 | 83 | nessun avviso |
| atra | 5 | 869 | 0,48 | 2,80 | 94 | nessun avviso |
| Non-alcoholic Fatty Liver Disease | 5 | 613 | 0,34 | 4,00 | 82 | geni da 828 a 613 con l'errore standard corretto |
| rosiglitazone | 5 | 562 | 0,44 | 3,09 | 59 | nessun avviso |
| Zika virus | 4 | 3.428 | 0,43 | 2,84 | 63 | nessun avviso |
| thapsigargin | 4 | 3.190 | 0,35 | 3,61 | 84 | nessun avviso |
| Nutlin-3 | 4 | 2.916 | 0,43 | 2,98 | 50 | nessun avviso |
| romidepsin | 4 | 1.844 | 0,36 | 3,55 | 82 | nessun avviso |
| TWEAK (TNFSF12) | 4 | 1.437 | 0,37 | 3,41 | 74 | nessun avviso |
| keloid | 4 | 504 | 0,45 | 3,01 | 70 | nessun avviso |
| IL2 | 4 | 392 | 0,48 | 2,70 | 88 | nessun avviso |
| trichostatin A | 3 | 3.740 | 0,41 | 2,88 | 85 | nessun avviso |
| IPATASERTIB | 3 | 3.704 | 0,47 | 2,55 | 86 | nessun avviso |
| MIVEBRESIB | 3 | 3.477 | 0,49 | 2,60 | 85 | nessun avviso |
| calcium atom | 3 | 2.702 | 0,44 | 2,69 | 96 | nessun avviso |
| Abemaciclib | 3 | 2.435 | 0,41 | 2,87 | 91 | nessun avviso |
| dimethyloxalylglycine | 3 | 2.153 | 0,43 | 2,72 | 96 | nessun avviso |
| ykl 5 124 | 3 | 1.817 | 0,50 | 2,42 | 42 | nessun avviso |
| bipolar disorder | 3 | 1.089 | 0,49 | 2,58 | 66 | geni da 1551 a 1089 con l'errore standard corretto |
| pevonedistat | 3 | 1.050 | 0,46 | 2,69 | 88 | nessun avviso |

## Tavola: le altre 132 delle 172

| meta-analisi | k | geni | primo studio | studi efficaci | I² | che cosa dichiarare |
|---|---:|---:|---:|---:|---:|---|
| TGFB1 | 54 | 8.272 | 0,02 | 49,07 | 92 | 6 studi difettosi, 11% del peso |
| lipopolysaccharide | 33 | 5.102 | 0,04 | 29,14 | 85 | 3 studi difettosi, 10% del peso; GSE168468 ha un braccio sbagliato |
| hypoxia | 27 | 3.331 | 0,05 | 24,74 | 96 | 4 studi difettosi, 16% del peso |
| JQ1 | 25 | 9.292 | 0,05 | 23,71 | 96 | 1 studio difettoso, 4% del peso |
| SARS-CoV-2 | 25 | 832 | 0,05 | 21,93 | 92 | 1 studio difettoso, 4% del peso |
| IL1B | 19 | 1.840 | 0,08 | 15,25 | 81 | 1 studio difettoso, 1% del peso; verdetto incerta |
| R1881 (metribolone) | 18 | 7.965 | 0,06 | 17,37 | 95 | 1 studio difettoso, 4% del peso; studi doppi da togliere: GSE133876 (k=17, geni 7002); GSE222992 ha i ruoli sbagliati nel deliverable |
| enzalutamide | 18 | 3.381 | 0,07 | 16,24 | 87 | 2 studi difettosi, 11% del peso |
| DHT (5alpha-dihydrotestosterone) | 16 | 2.347 | 0,09 | 14,15 | 81 | 3 studi difettosi, 20% del peso |
| IFNG | 16 | 1.877 | 0,09 | 13,51 | 92 | 3 studi difettosi, 20% del peso |
| cisplatin | 16 | 1.029 | 0,08 | 14,05 | 97 | 1 studio difettoso, 6% del peso |
| doxorubicin | 15 | 6.308 | 0,09 | 12,93 | 94 | verdetto incerta; alla seconda lettura: corretta |
| palbociclib | 15 | 3.058 | 0,09 | 13,87 | 91 | 1 studio difettoso, 8% del peso; alla seconda lettura: incerta |
| schizophrenia | 13 | 0 | n.d. | n.d. | 14 | nessun gene significativo |
| dexamethasone | 11 | 612 | 0,24 | 6,44 | 81 | 2 studi difettosi, 13% del peso |
| poly(I:C) | 11 | 271 | 0,53 | 2,37 | 81 | un solo studio porta il 53% del peso; verdetto incerta; alla seconda lettura: difettosa |
| hydrogen peroxide | 10 | 1.283 | 0,28 | 4,96 | 83 | 2 studi difettosi, 1% del peso |
| fulvestrant | 9 | 3.720 | 0,13 | 8,87 | 87 | 1 studio difettoso, 11% del peso |
| osimertinib | 9 | 1.621 | 0,16 | 7,72 | 94 | 1 studio difettoso, 13% del peso |
| THZ1 | 9 | 609 | 0,16 | 7,21 | 98 | 1 studio difettoso, 12% del peso |
| HCMV (human cytomegalovirus) | 9 | 433 | 0,23 | 5,76 | 88 | 1 studio difettoso, 13% del peso |
| metformin | 9 | 329 | 0,22 | 6,15 | 92 | 2 studi difettosi, 18% del peso |
| trametinib | 8 | 5.760 | 0,17 | 6,78 | 92 | verdetto incerta |
| Crohn Disease | 8 | 2.867 | 0,30 | 4,91 | 62 | 1 studio difettoso, 7% del peso |
| Influenza A virus | 8 | 837 | 0,20 | 6,07 | 89 | 1 studio difettoso, 10% del peso |
| dasatinib | 8 | 317 | 0,55 | 2,50 | 58 | un solo studio porta il 55% del peso; 1 studio difettoso, 8% del peso; geni da 425 a 317 con l'errore standard corretto |
| sirolimus | 7 | 2.961 | 0,19 | 6,19 | 82 | 1 studio difettoso, 6% del peso |
| irradiation | 7 | 2.930 | 0,21 | 5,77 | 93 | 1 studio difettoso, 13% del peso |
| erlotinib | 7 | 2.284 | 0,20 | 6,34 | 92 | 1 studio difettoso, 17% del peso; alla seconda lettura: incerta |
| IFNB1 | 7 | 2.160 | 0,34 | 4,34 | 76 | 2 studi difettosi, 26% del peso |
| IL17A | 7 | 895 | 0,59 | 2,23 | 39 | un solo studio porta il 59% del peso |
| imatinib | 7 | 609 | 0,78 | 1,60 | 60 | un solo studio porta il 78% del peso; vale 1,60 studi efficaci; geni da 972 a 609 con l'errore standard corretto |
| lapatinib | 7 | 500 | 0,53 | 2,68 | 72 | un solo studio porta il 53% del peso |
| gefitinib | 7 | 142 | 0,63 | 1,98 | 58 | un solo studio porta il 63% del peso; vale 1,98 studi efficaci; alla seconda lettura: incerta |
| multiple sclerosis | 7 | 53 | 0,54 | 2,39 | 56 | un solo studio porta il 54% del peso; alla seconda lettura: incerta; geni da 1082 a 53 con l'errore standard corretto |
| Alzheimer Disease | 6 | 2.579 | 0,66 | 2,05 | 57 | un solo studio porta il 66% del peso |
| Pre-Eclampsia | 6 | 1.657 | 0,45 | 3,22 | 48 | 1 studio difettoso, 23% del peso; alla seconda lettura: corretta |
| 5-fluorouracil | 6 | 1.200 | 0,42 | 3,24 | 88 | 1 studio difettoso, 15% del peso |
| r5020 | 6 | 1.111 | 0,81 | 1,51 | 60 | un solo studio porta il 81% del peso; vale 1,51 studi efficaci; verdetto incerta |
| covid 19 | 6 | 809 | 0,46 | 3,02 | 72 | 1 studio difettoso, 21% del peso |
| olaparib | 6 | 358 | 0,57 | 2,00 | 94 | un solo studio porta il 57% del peso; vale 2,00 studi efficaci; verdetto incerta |
| ruxolitinib | 6 | 342 | 0,57 | 2,31 | 76 | un solo studio porta il 57% del peso; verdetto incerta |
| paclitaxel | 6 | 291 | 0,76 | 1,61 | 79 | un solo studio porta il 76% del peso; vale 1,61 studi efficaci |
| Carcinoma, Hepatocellular | 6 | 79 | 0,51 | 2,76 | 80 | un solo studio porta il 51% del peso; 1 studio difettoso, 19% del peso; alla seconda lettura: corretta; geni da 105 a 79 con l'errore standard corretto; GSE144269 ha i bracci invertiti: gruppo non citabile finché non è corretto |
| pcos | 6 | 27 | 0,53 | 2,44 | 35 | un solo studio porta il 53% del peso |
| heart failure | 5 | 3.104 | 0,78 | 1,58 | 41 | un solo studio porta il 78% del peso; vale 1,58 studi efficaci |
| Colorectal Neoplasms | 5 | 2.088 | 0,39 | 3,53 | 68 | 1 studio difettoso, 24% del peso |
| everolimus | 5 | 1.656 | 0,45 | 3,03 | 82 | 2 studi difettosi, 48% del peso; alla seconda lettura: incerta |
| IL22 | 5 | 1.286 | 0,53 | 2,55 | 40 | un solo studio porta il 53% del peso; 1 studio difettoso, 33% del peso; il difetto sposta il risultato oltre il caso, su tre statistiche |
| Stomach Neoplasms | 5 | 946 | 0,47 | 2,93 | 25 | 1 studio difettoso, 22% del peso |
| afimoxifene | 5 | 917 | 0,50 | 2,58 | 66 | un solo studio porta il 50% del peso |
| IL4 | 5 | 566 | 0,49 | 2,76 | 77 | 1 studio difettoso, 21% del peso |
| obese | 5 | 446 | 0,52 | 2,42 | 37 | un solo studio porta il 52% del peso; 1 studio difettoso, 35% del peso; il difetto sposta il risultato oltre il caso, su tre statistiche |
| sepsis | 5 | 204 | 0,63 | 2,01 | 76 | un solo studio porta il 63% del peso |
| sals | 5 | 45 | 0,67 | 1,95 | 36 | un solo studio porta il 67% del peso; vale 1,95 studi efficaci; 1 studio difettoso, 22% del peso; il difetto sposta il risultato oltre il caso, su tre statistiche |
| pinometostat | 5 | 40 | 0,83 | 1,40 | 0 | un solo studio porta il 83% del peso; vale 1,40 studi efficaci |
| oscc | 4 | 3.915 | 0,50 | 2,50 | 6 | un solo studio porta il 50% del peso; 1 studio difettoso, 0% del peso |
| etoposide | 4 | 3.549 | 0,61 | 2,11 | 79 | un solo studio porta il 61% del peso |
| 5-azacytidine | 4 | 2.414 | 0,52 | 2,18 | 89 | un solo studio porta il 52% del peso |
| sjogren s syndrome | 4 | 2.006 | 0,38 | 3,39 | 28 | l'etichetta non chiude il verdetto |
| trastuzumab | 4 | 1.927 | 0,52 | 2,43 | 82 | un solo studio porta il 52% del peso |
| bortezomib | 4 | 1.791 | 0,86 | 1,34 | 73 | un solo studio porta il 86% del peso; vale 1,34 studi efficaci |
| carfilzomib | 4 | 1.498 | 0,61 | 2,02 | 95 | un solo studio porta il 61% del peso; 1 studio difettoso, 26% del peso |
| Pladienolide B | 4 | 1.371 | 0,52 | 2,27 | 95 | un solo studio porta il 52% del peso |
| ionomycin + pma | 4 | 1.252 | 0,59 | 2,11 | 88 | un solo studio porta il 59% del peso |
| all-trans-retinoic acid | 4 | 1.203 | 0,52 | 2,31 | 89 | un solo studio porta il 52% del peso |
| nutlin 3a | 4 | 956 | 0,51 | 2,66 | 90 | un solo studio porta il 51% del peso |
| radiation | 4 | 799 | 0,53 | 2,51 | 73 | un solo studio porta il 53% del peso |
| staurosporine | 4 | 777 | 0,52 | 2,65 | 26 | un solo studio porta il 52% del peso; 1 studio difettoso, 32% del peso |
| TCDD | 4 | 665 | 0,74 | 1,75 | 44 | un solo studio porta il 74% del peso; vale 1,75 studi efficaci |
| cyclosporin A | 4 | 532 | 0,92 | 1,17 | 0 | un solo studio porta il 92% del peso; vale 1,17 studi efficaci |
| testosterone | 4 | 497 | 0,70 | 1,79 | 85 | un solo studio porta il 70% del peso; vale 1,79 studi efficaci; 1 studio difettoso, 19% del peso |
| cystic fibrosis | 4 | 496 | 0,77 | 1,61 | 17 | un solo studio porta il 77% del peso; vale 1,61 studi efficaci; 1 studio difettoso, 16% del peso; alla seconda lettura: incerta; geni da 710 a 496 con l'errore standard corretto |
| IL3 | 4 | 335 | 0,54 | 2,31 | 86 | un solo studio porta il 54% del peso; 1 studio difettoso, 26% del peso |
| PFOS | 4 | 220 | 0,73 | 1,71 | 3 | un solo studio porta il 73% del peso; vale 1,71 studi efficaci; geni da 302 a 220 con l'errore standard corretto |
| diabetic | 4 | 143 | 0,60 | 2,28 | 27 | un solo studio porta il 60% del peso; 1 studio difettoso, 20% del peso |
| calcitriol | 4 | 98 | 0,88 | 1,26 | 2 | un solo studio porta il 88% del peso; vale 1,26 studi efficaci; alla seconda lettura: incerta; geni da 189 a 98 con l'errore standard corretto |
| copd | 4 | 28 | 0,78 | 1,55 | 0 | un solo studio porta il 78% del peso; vale 1,55 studi efficaci; geni da 59 a 28 con l'errore standard corretto |
| hepatitis B virus | 4 | 11 | 0,67 | 1,93 | 7 | un solo studio porta il 67% del peso; vale 1,93 studi efficaci; 1 studio difettoso, 1% del peso; GSE93153 ha un braccio sbagliato |
| omacetaxine | 3 | 7.535 | 0,72 | 1,73 | 71 | un solo studio porta il 72% del peso; vale 1,73 studi efficaci |
| g007 lk | 3 | 6.194 | 0,98 | 1,05 | 0 | un solo studio porta il 98% del peso; vale 1,05 studi efficaci |
| sapanisertib | 3 | 5.498 | 0,98 | 1,04 | 4 | un solo studio porta il 98% del peso; vale 1,04 studi efficaci |
| vorinostat | 3 | 4.604 | 0,55 | 2,00 | 86 | un solo studio porta il 55% del peso; vale 2,00 studi efficaci; l'etichetta non chiude il verdetto |
| daunorubicin | 3 | 4.215 | 0,59 | 1,96 | 88 | un solo studio porta il 59% del peso; vale 1,96 studi efficaci |
| Carcinoma, Renal Cell | 3 | 3.870 | 0,55 | 2,09 | 76 | un solo studio porta il 55% del peso; alla seconda lettura: difettosa |
| docetaxel | 3 | 3.803 | 0,94 | 1,12 | 27 | un solo studio porta il 94% del peso; vale 1,12 studi efficaci |
| 4'-epidoxorubicin | 3 | 2.989 | 0,92 | 1,18 | 76 | un solo studio porta il 92% del peso; vale 1,18 studi efficaci |
| resveratrol | 3 | 2.984 | 0,56 | 2,27 | 79 | un solo studio porta il 56% del peso |
| Neoplasm Metastasis | 3 | 2.673 | 0,55 | 2,00 | 73 | un solo studio porta il 55% del peso; vale 2,00 studi efficaci; verdetto incerta; alla seconda lettura: corretta |
| neratinib | 3 | 2.672 | 0,57 | 2,00 | 76 | un solo studio porta il 57% del peso; vale 2,00 studi efficaci |
| DRB | 3 | 2.665 | 0,52 | 2,28 | 79 | un solo studio porta il 52% del peso |
| medulloblastoma | 3 | 2.619 | 0,56 | 2,06 | 84 | un solo studio porta il 56% del peso; verdetto incerta |
| BMP4 | 3 | 2.381 | 0,61 | 1,92 | 72 | un solo studio porta il 61% del peso; vale 1,92 studi efficaci; verdetto incerta |
| nicotinamide | 3 | 2.355 | 0,74 | 1,68 | 47 | un solo studio porta il 74% del peso; vale 1,68 studi efficaci |
| GSK-J4 | 3 | 2.311 | 0,61 | 2,03 | 47 | un solo studio porta il 61% del peso; verdetto incerta |
| DUBERMATINIB | 3 | 2.280 | 0,58 | 2,17 | 31 | un solo studio porta il 58% del peso |
| hemin | 3 | 1.820 | 0,55 | 2,12 | 70 | un solo studio porta il 55% del peso |
| ifna | 3 | 1.799 | 0,56 | 2,27 | 49 | un solo studio porta il 56% del peso |
| fshd | 3 | 1.674 | 0,64 | 1,98 | 84 | un solo studio porta il 64% del peso; vale 1,98 studi efficaci |
| liquiritigenin | 3 | 1.583 | 0,78 | 1,56 | 58 | un solo studio porta il 78% del peso; vale 1,56 studi efficaci |
| Nutlin | 3 | 1.429 | 0,69 | 1,84 | 85 | un solo studio porta il 69% del peso; vale 1,84 studi efficaci |
| cabozantinib | 3 | 1.428 | 0,85 | 1,36 | 55 | un solo studio porta il 85% del peso; vale 1,36 studi efficaci; l'etichetta non chiude il verdetto; alla seconda lettura: difettosa |
| digoxin | 3 | 1.262 | 0,94 | 1,12 | 12 | un solo studio porta il 94% del peso; vale 1,12 studi efficaci |
| methotrexate | 3 | 1.151 | 0,56 | 2,23 | 90 | un solo studio porta il 56% del peso |
| ponatinib | 3 | 1.146 | 0,85 | 1,34 | 16 | un solo studio porta il 85% del peso; vale 1,34 studi efficaci |
| gilteritinib | 3 | 1.094 | 0,55 | 2,08 | 87 | un solo studio porta il 55% del peso |
| Arthritis, Rheumatoid | 3 | 932 | 0,95 | 1,11 | 17 | un solo studio porta il 95% del peso; vale 1,11 studi efficaci; geni da 2833 a 932 con l'errore standard corretto |
| 1 25 oh 2d3 | 3 | 892 | 0,98 | 1,04 | 0 | un solo studio porta il 98% del peso; vale 1,04 studi efficaci |
| GSK-LSD1 | 3 | 870 | 0,70 | 1,80 | 49 | un solo studio porta il 70% del peso; vale 1,80 studi efficaci |
| nahs | 3 | 864 | 0,82 | 1,42 | 25 | un solo studio porta il 82% del peso; vale 1,42 studi efficaci |
| 5 aza | 3 | 824 | 0,58 | 2,06 | 89 | un solo studio porta il 58% del peso; verdetto incerta |
| Lupus Erythematosus, Systemic | 3 | 798 | 0,58 | 2,15 | 60 | un solo studio porta il 58% del peso |
| RITUXIMAB | 3 | 746 | 0,61 | 1,93 | 50 | un solo studio porta il 61% del peso; vale 1,93 studi efficaci |
| chloroquine | 3 | 698 | 0,78 | 1,56 | 78 | un solo studio porta il 78% del peso; vale 1,56 studi efficaci |
| Fusobacterium nucleatum | 3 | 663 | 0,68 | 1,88 | 77 | un solo studio porta il 68% del peso; vale 1,88 studi efficaci |
| pm2 5 | 3 | 602 | 0,59 | 2,10 | 70 | un solo studio porta il 59% del peso |
| forskolin | 3 | 476 | 0,76 | 1,63 | 65 | un solo studio porta il 76% del peso; vale 1,63 studi efficaci |
| vtp50469 | 3 | 450 | 0,57 | 1,99 | 94 | un solo studio porta il 57% del peso; vale 1,99 studi efficaci; GSE186709 ha un braccio sbagliato |
| tb positive | 3 | 402 | 0,76 | 1,64 | 0 | un solo studio porta il 76% del peso; vale 1,64 studi efficaci |
| tofacitinib | 3 | 334 | 0,62 | 2,05 | 63 | un solo studio porta il 62% del peso; alla seconda lettura: incerta |
| Pituitary Neoplasms | 3 | 213 | 0,65 | 1,90 | 17 | un solo studio porta il 65% del peso; vale 1,90 studi efficaci |
| Diabetes Mellitus, Type 1 | 3 | 173 | 0,64 | 1,94 | 58 | un solo studio porta il 64% del peso; vale 1,94 studi efficaci; geni da 356 a 173 con l'errore standard corretto |
| isoprenaline | 3 | 152 | 0,85 | 1,34 | 0 | un solo studio porta il 85% del peso; vale 1,34 studi efficaci |
| fluoxetine | 3 | 145 | 0,61 | 1,95 | 39 | un solo studio porta il 61% del peso; vale 1,95 studi efficaci |
| cteph | 3 | 136 | 0,69 | 1,77 | 49 | un solo studio porta il 69% del peso; vale 1,77 studi efficaci |
| Spondylitis, Ankylosing | 3 | 123 | 0,82 | 1,43 | 12 | un solo studio porta il 82% del peso; vale 1,43 studi efficaci |
| GSK343 | 3 | 90 | 0,78 | 1,56 | 16 | un solo studio porta il 78% del peso; vale 1,56 studi efficaci |
| regorafenib | 3 | 51 | 0,69 | 1,83 | 0 | un solo studio porta il 69% del peso; vale 1,83 studi efficaci |
| Diabetes, Gestational | 3 | 21 | 0,85 | 1,35 | 0 | un solo studio porta il 85% del peso; vale 1,35 studi efficaci; alla seconda lettura: incerta |
| idiopathic pulmonary fibrosis | 3 | 14 | 0,91 | 1,20 | 4 | un solo studio porta il 91% del peso; vale 1,20 studi efficaci |
| ptsd | 3 | 11 | 0,76 | 1,65 | 0 | un solo studio porta il 76% del peso; vale 1,65 studi efficaci; verdetto incerta; geni da 66 a 11 con l'errore standard corretto |
| Smokers | 3 | 3 | 0,93 | 1,15 | 48 | un solo studio porta il 93% del peso; vale 1,15 studi efficaci |
