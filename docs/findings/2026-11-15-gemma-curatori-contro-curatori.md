---
type: Finding
title: "Due gruppi di curatori sugli stessi studi: quanto concordano Gemma (UBC) ed Expression Atlas, e dove sta il lettore"
description: "Sui 21 studi di sviluppo curati da tutti e due, Gemma ha i gruppi di Atlas in 15 studi e ritrova 28 confronti di Atlas su 49; Mistral-Small 3.2 nella forma B0 ne ha 16 e 33. La differenza fra i due non si distingue da zero. I 21 confronti che Gemma perde vengono da scelte diverse dei curatori, non da errori."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-15T12:40:00+01:00}
sources:
- {id: carta, resource: "analysis/audit/2026-11-15-gemma-riferimento/00-previsioni.md", title: "Carta e previsioni: regole dell'adattatore 1-7, cancelli K1-K5, misure m1-m5, previsioni P1-P6 (commit 2aaccb9)"}
- {id: adattatore, resource: "analysis/audit/2026-11-15-gemma-riferimento/30-adattatore-gemma.R", title: "L'adattatore dai disegni di Gemma alla tabella dei fattori; 30-out.txt e 30-esiti.csv per le 3.170 voci"}
- {id: misura, resource: "analysis/audit/2026-11-15-gemma-riferimento/31-out.txt", title: "La misura curatori contro curatori sui 21 studi di sviluppo: cancelli, misure, appaiati, previsioni"}
- {id: perstudio, resource: "analysis/audit/2026-11-15-gemma-riferimento/31-per-studio.csv", title: "Una riga per studio: classe dei gruppi e confronti ritrovati, Gemma e Mistral B0"}
- {id: riassunto, resource: "analysis/audit/2026-11-15-gemma-riferimento/31-riassunto.csv", title: "Le misure con gli intervalli (ricampionamento sugli studi)"}
- {id: appaiato, resource: "analysis/audit/2026-11-15-gemma-riferimento/31-appaiato.csv", title: "Differenze appaiate Gemma meno Mistral B0"}
- {id: schede, resource: "analysis/audit/2026-11-15-gemma-riferimento/31-schede/", title: "Una scheda di lettura per studio (21)"}
- {id: letti, resource: "analysis/audit/2026-11-15-gemma-riferimento/33-disaccordi-letti.csv", title: "I disaccordi letti, uno per riga, con la causa"}
- {id: sens, resource: "analysis/audit/2026-11-15-gemma-riferimento/32-out.txt", title: "Sensibilità dichiarata dopo i numeri: la base di Gemma anche per i fattori di contesto e di tempo"}
---

# In breve

## In breve: due gruppi di curatori umani formano gli stessi gruppi e gli stessi confronti?

**A cosa serviva.** Finora abbiamo misurato il lettore dello studio contro una sola curazione umana, quella di Expression Atlas. Gemma, la banca dati dell'università della British Columbia, ha curato a mano 21 dei nostri 47 studi di sviluppo. Abbiamo misurato quanto i due gruppi di curatori concordano fra loro, perché questo accordo dice quanto può valere al massimo un lettore. Serve anche per decidere se la curazione di Gemma è un buon riferimento per i circa 3.100 studi che Atlas non copre.

**Cosa abbiamo trovato.**

1. **I due gruppi di curatori concordano sui gruppi in 15 studi su 21.** Dalla curazione di Gemma si ritrovano 28 confronti di Atlas su 49. Due curatori esperti non danno quindi lo stesso disegno in circa uno studio su tre.
2. **Il lettore con Mistral sta allo stesso livello dei curatori.** Sugli stessi 21 studi ha i gruppi di Atlas in 16 studi e ritrova 33 confronti su 49. La differenza con Gemma è di 10 punti a favore del lettore, ma con 21 studi non si distingue da zero. Questi 21 studi sono serviti per sviluppare il lettore, quindi il confronto lo favorisce.
3. **I 21 confronti che Gemma perde vengono da scelte dei curatori, non da errori.** In 9 confronti Gemma tiene un fattore in più (il sesso, la linea cellulare). In 6 unisce due livelli che Atlas separa. In 4 sceglie un altro gruppo come controllo. In 2 pesa una regola del nostro adattatore.
4. **Dove il lettore sbaglia, i curatori concordano fra loro in 3 studi su 4.** Sono i 4 studi con un errore di lettura del modello che costa confronti. In 3 Gemma ha gli stessi gruppi di Atlas, quindi l'errore è del modello. Nel quarto (`GSE57945`) anche i curatori di Gemma usano il sesso come fattore, come ha fatto il modello.
5. **La curazione di Gemma è usabile come riferimento sui 3.100 studi.** L'adattatore dà una tabella per 3.107 voci su 3.170 e almeno un confronto per 2.573. La misura sui gruppi è più solida di quella sui confronti, perché i confronti dipendono dal gruppo che ogni curatore sceglie come controllo.

**Cosa devi decidere.** Niente adesso. Vado avanti come deciso: preparo i 3.100 studi di Gemma per il lettore con Mistral e per il secondo modello locale.

**Comunque.**

- Nell'articolo l'accordo fra i due curatori va accanto al numero del lettore: Atlas da solo non è la verità.
- Sui 3.100 studi riporto prima l'accordo sui gruppi, poi quello sui confronti, con la stessa regola scritta prima.
- I tre modelli candidati come secondo lettore sono in coda sul nodo `poddgx02`. La coda prevede l'avvio al più tardi il 17 novembre alle 10:36.

Non c'è nulla da decidere: se non hai dubbi, questa parte è chiusa e il lavoro continua.

# 1. Oggetto e metodo

L'oggetto e le regole stanno nella carta, scritta e committata prima di formare un gruppo dai disegni di Gemma.[^carta] In breve: i disegni curati di Gemma (3.170 voci scaricate il 2026-11-15, nessuno studio di giudizio) passano per un adattatore che scrive la tabella dei fattori; il costruttore del pacchetto (`tf_confronti()`, `n_min = 2`) forma i confronti con la stessa definizione che vale per il lettore; la misura è quella della terza prova (`misura_r3()`, riferimento di Atlas a 95 confronti sui 47 studi). I 21 studi sono quelli di sviluppo con un disegno di Gemma. Il termine di paragone è Mistral-Small 3.2 nella forma `B0` (corsa congelata), misurato sullo stesso universo di campioni di Gemma.

Unità: lo studio. Ricampionamento sugli studi, B = 10.000, seme 20261115.

# 2. Cancelli

Tutti passati.[^misura]

| cancello | esito |
|---|---|
| K1 riproduzione | Mistral `B0` sui 47 studi: 45 chiusi, 36 gruppi identici, 68/95 |
| K2 controllo positivo | passato: tabella, base, 2 confronti, blocco tolto, basi diverse, codici di uscita |
| K3 copertura | 3.170 voci, 3.170 esiti (`tabella` 3.107, `senza_fattori` 63); i 21 di sviluppo: 21 `tabella` |
| K4 solo sviluppo | 0 file di studi di giudizio; la misura legge 21 studi, tutti di sviluppo |
| K5 oggetto | stesse funzioni e stesso riferimento della terza prova |

Regola 7 (universo): 1 campione dell'universo di Atlas resta fuori dalla voce di Gemma (`GSE52778`, 1 su 14). 29 campioni di Gemma in 7 studi non stanno nell'universo di Atlas e non entrano nella misura.

# 3. Le misure

Misura principale, 21 studi, stesso universo per i due.[^riassunto][^appaiato]

| misura | Gemma | Mistral `B0` | differenza Gemma meno Mistral (IC95) |
|---|---|---|---|
| m1, studi con gruppi | 21/21 | 21/21 | |
| m2, gruppi identici ad Atlas | 15/21 (IC95 11-19) | 16/21 (IC95 12-19) | −4,8 punti (−23,8, +14,3) |
| m3, confronti di Atlas ritrovati | 28/49 = 57,1% (33,3-81,8) | 33/49 = 67,3% (41,9-89,7) | −10,2 punti (−36,1, +17,0) |
| verso opposto | 0/49 | 0/49 | |
| confronti non elencati da Atlas giudicati errori | 20/20 | 2/21 | |

Accanto: riferimento a 97 confronti 28/51 contro 33/51; riferimento intero 28/46 contro 33/46; stretto 26/45 contro 31/45. Mistral `B0` sull'universo intero di Atlas dà gli stessi numeri (16/21, 33/49).

I 20 confronti di Gemma «giudicati errori» sono tutti bracci misti **secondo la partizione di Atlas**: stanno nei 4 studi dove Gemma unisce livelli o incrocia un fattore in più (`GSE57945` 16, `GSE71289` 2, `GSE51261` 1, `GSE56787` 1). Il giudizio è per costruzione relativo ad Atlas: non dice che Gemma sbaglia.

**m4.** Gemma e Mistral `B0` danno gli stessi gruppi in 14 studi su 21; 13 di questi sono identici ad Atlas. Il quattordicesimo è `GSE50760`: i due differiscono da Atlas nello stesso modo, per un campione. Tabella a due entrate (identico ad Atlas): tutti e due 13, solo Gemma 2, solo Mistral 3, nessuno 3.

**m5.** I 4 studi con un errore di lettura di Mistral che costa:

| studio | Gemma | Mistral `B0` |
|---|---|---|
| `GSE46665` | gruppi di Atlas, 2/2 | 25 gruppi di un campione, 0/2 |
| `GSE49155` | gruppi di Atlas, 2/2 | gruppi di Atlas, 0/2 |
| `GSE60340` | gruppi di Atlas, 0/2 (base diversa) | 6 gruppi contro 8, 0/2 |
| `GSE57945` | 12 gruppi contro 7, 0/6 (sesso e tre fattori di malattia) | 14 gruppi contro 7, 0/6 (sesso) |

# 4. Le previsioni

| | quantità | atteso (rilevanza) | misurato | esito |
|---|---|---|---|---|
| P1 | studi con gruppi su 21 | 20 (18-21) | 21 | confermata |
| P2 | Gemma identici ad Atlas | 11 (7-15) | 15 (IC 11-19) | indeterminata, al bordo alto |
| P3 | Mistral `B0` identici | 16 (13-19) | 16 (IC 12-19) | indeterminata |
| P4 | Gemma ritrovati | 45% (25-65%) | 57,1% (33,3-81,8) | indeterminata |
| P5 | differenza Gemma meno Mistral | −15 punti, IC tutto sotto 0 | −10,2 (−36,1, +17,0) | smentita: l'IC sta a cavallo di 0 |
| P6 | Gemma con i gruppi di Atlas nei 4 studi | 2 (1-3) | 3 | dentro l'intervallo (conta, senza IC) |

Le tre indeterminate non toccano la conclusione: i curatori concordano più di quanto prevedevo (15 contro 11), e questo rafforza l'uso di Gemma come riferimento. P5 smentita: con 21 studi non si può dire che il lettore superi l'accordo fra curatori; si può dire che non sta sotto in modo misurabile.

# 5. I disaccordi, letti tutti

Ho letto le 21 schede.[^schede] Una riga per disaccordo in `33-disaccordi-letti.csv`.[^letti]

**I 21 confronti di Atlas che Gemma non ritrova (7 studi):**

| causa | confronti | studi |
|---|---|---|
| Gemma tiene un fattore in più | 9 | `GSE57945` (6: il sesso), `GSE52778` (3: la linea cellulare, gruppi di un campione) |
| Gemma unisce livelli che Atlas separa | 6 | `GSE71289` (4: due genotipi dell'esone 8), `GSE51261` (2: due shRNA) |
| Gemma dichiara un'altra base | 4 | `GSE50760` (2: base «colorectal cancer», più un campione diverso), `GSE60340` (2: base «young», Atlas le cellule immortali) |
| regola 5 dell'adattatore (fattore di tempo senza base) | 2 | `GSE57116` |

Gruppi diversi senza confronti persi: `GSE56787` (Gemma ha solo la malattia, Atlas anche genotipo e tessuto; denominatore 0).

**I 16 che Mistral `B0` non ritrova (6 studi)** erano già letti nelle sessioni di prima: `GSE46665` 2, `GSE49155` 2, `GSE60340` 2 (errori di lettura del modello; in tutti e tre Gemma ha i gruppi di Atlas), `GSE57945` 6 (sesso come fattore, come Gemma), `GSE50760` 2 (gli stessi gruppi di Gemma), `GSE71595` 2 (gruppi identici, la base della malattia non scritta; Gemma 4/4).

**Che cosa ne segue.** Nessun disaccordo di Gemma è un errore di trascrizione: sono scelte di grana (quali fattori tenere, quali livelli unire) e di controllo. Due osservazioni cambiano la lettura dei conti di prima:

- `GSE57945`: il sesso come fattore è contato come errore di lettura del modello contro Atlas. I curatori di Gemma fanno la stessa scelta. Contro Gemma non sarebbe un errore.
- `GSE50760`: il lettore dà i gruppi di Gemma, non quelli di Atlas. La differenza è un campione.

# 6. Sensibilità dichiarata dopo i numeri: la regola 5

La regola 5 della carta toglie la base ai fattori di contesto e di tempo, per coerenza con le due decisioni del PI sul riferimento di Atlas. Dopo i numeri ho misurato che cosa costa, usando la base che Gemma dichiara anche per quei fattori (`32-sensibilita-base-di-gemma.R`).[^sens] Non sta nella carta e non sostituisce la misura depositata.

- Confronti ritrovati: 30/49 invece di 28/49 (i 2 di `GSE57116`); 1 a verso opposto (`GSE60340`).
- Differenza con Mistral `B0`: −6,1 punti (IC95 −31,5, +20,4).
- Confronti di Gemma non elencati da Atlas e giudicati errori: 24/30.

La regola 5 costa quindi 2 confronti su 49. Sulle 3.170 voci tocca 440 note di base di contesto e 300 di base di tempo: sui 3.100 studi il suo peso può essere diverso, e va riportato accanto.

# 7. Decisioni tecniche dell'agente

- Mistral `B0` è misurato sullo stesso universo di Gemma (intersezione, regola 7) in ogni studio; i numeri sull'universo intero sono uguali.
- I campioni che Gemma marca come anomali restano nella tabella (nota `outlier_di_gemma`): toglierli cambierebbe i gruppi rispetto ad Atlas per una scelta di analisi, non di disegno.
- Il nome di un fattore è categoria più identificativo di Gemma, perché uno studio può avere più fattori della stessa categoria (`GSE57945`: tre `disease`).
- La base di un fattore di contesto o di tempo si registra (`base_gemma`) e non si usa, come dice la carta.
- Corretto durante il lavoro un errore del mio programma: il confronto dei gruppi fra Gemma e Mistral usava i nomi dei gruppi e dava 5/21; senza i nomi dà 14/21. Gli altri numeri non cambiano.

# 8. Limiti

- 21 studi, usati sei volte per sviluppare il lettore: gli intervalli sono larghi e il confronto favorisce Mistral `B0`.
- I confronti di Gemma sono quelli del nostro costruttore sulla sua tabella, non i contrasti del suo modello lineare.
- La base di Gemma viene da regole automatiche e da curatori insieme: l'API non li distingue.
- Un disaccordo fra curatori non dice chi ha ragione. La lettura delle schede è mia, senza una revisione indipendente.
- Il giudizio «errore» sui confronti non elencati è relativo alla partizione di Atlas.

# Da dove vengono i numeri del riassunto

| frase | file e riga | valore letto |
|---|---|---|
| gruppi uguali in 15 studi su 21 | `31-riassunto.csv` riga 2 | 15, 21 |
| 28 confronti di Atlas su 49 | `31-riassunto.csv` riga 3 | 28, 49 |
| il lettore: 16 studi | `31-riassunto.csv` riga 12 | 16, 21 |
| il lettore: 33 su 49 | `31-out.txt` riga 27 | 33/49 |
| differenza di 10 punti, non distinta da zero | `31-out.txt` riga 93 | −10,2 (−36,1, +17,0) |
| 21 confronti persi: 9, 6, 4, 2 | `33-disaccordi-letti.csv`, righe di `gemma` | 6+3, 4+2, 2+2, 2 |
| 3 studi su 4 con i gruppi di Atlas | `31-out.txt` riga 94 | 3 |
| `GSE57945`: il sesso come fattore in Gemma | `31-schede/GSE57945.txt` | `biological sex [22310]` con base |
| 3.107 voci su 3.170 con una tabella, 2.573 con un confronto | `30-out.txt` | 3.107, 3.170, 2.573 |
| avvio al più tardi il 17 novembre alle 10:36 | `squeue` del 2026-11-15 12:08 | 2026-11-17T10:36:42 |
