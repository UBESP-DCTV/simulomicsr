---
type: Finding
title: "La prova piccola del lettore dello studio: 47 studi contro la curazione di Expression Atlas"
description: "La prima versione del lettore (un modello, un prompt) non fa meglio della pipeline di oggi sui 47 studi di sviluppo: la regola di esito non è soddisfatta e decide il PI."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-10T14:33:19+01:00}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-09-lettore-studio/00-previsioni.md", title: "Cancelli K1-K5 e previsioni P1-P8, depositati prima del calcolo"}
- {id: legame, resource: "analysis/audit/2026-11-09-lettore-studio/33-out.txt", title: "Legame fra i run di Atlas e i campioni GEO, 129 studi (K1)"}
- {id: oggi, resource: "analysis/audit/2026-11-09-lettore-studio/40-out.txt", title: "Controllo positivo dello strumento (K2) e misura della pipeline di oggi (K3, P1, P2, P8)"}
- {id: vista, resource: "analysis/audit/2026-11-09-lettore-studio/60-out.txt", title: "La vista v0 dei 47 studi di sviluppo"}
- {id: corsa, resource: "analysis/audit/2026-11-09-lettore-studio/63-out.txt", title: "Le due corse del lettore v0 su poddgx02 (K4)"}
- {id: lettore, resource: "analysis/audit/2026-11-09-lettore-studio/64-out.txt", title: "Misura del lettore v0 contro Atlas (P3-P7)"}
- {id: disaccordi, resource: "analysis/audit/2026-11-09-lettore-studio/65-disaccordi.md", title: "Lettura di tutti i 145 disaccordi, con la causa (audit interno)"}
- {id: righe, resource: "analysis/audit/2026-11-09-lettore-studio/65-disaccordi-righe.csv", title: "Una riga per disaccordo"}
- {id: revisione, resource: "analysis/audit/2026-11-09-lettore-studio/67-out.txt", title: "Conti chiesti dalla revisione finale del branch: lettura stretta del fattore non scritto, unità per esito, studi per causa (dopo i numeri)"}
- {id: forma, resource: "analysis/audit/2026-11-09-lettore-studio/66-forma-out.txt", title: "Sensibilità sulla forma delle voci, dichiarata dopo i numeri"}
- {id: bacino, resource: "analysis/audit/2026-11-09-lettore-studio/10-out.txt", title: "Token della tabella dei campioni su tutti i 24.393 studi"}
- {id: spec, resource: "docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md", title: "Disegno del lettore dello studio (regola di esito §5.6, modelli §5.7, concorrenti §6)"}
- {id: piano, resource: "docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md", title: "Piano in quattro parti, Parte B (Piano 1)"}
- {id: adr29, resource: "docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md", title: "ADR-0029"}
- {id: s12p, resource: "docs/findings/2026-11-08-S12p-prova-cieca-stadio2b.md", title: "La prova cieca dello Stadio 2b e la diagnosi di dove nasce il difetto (§14)"}
- {id: geoagent, resource: "https://doi.org/10.64898/2026.06.06.730646", title: "Zhao Y, Cai Q, Chen D, Chen J. GEOAgent. bioRxiv, 2026-06-10"}
- {id: rs, resource: "https://doi.org/10.21203/rs.3.rs-10844781/v1", title: "Szczepaniak M, Wren JD. Context-aware LLM extraction and controlled-vocabulary normalization of GEO transcriptomic sample metadata. Research Square, 2026-08-31"}
- {id: copie, resource: "analysis/input/concorrenti-2026-11-10/", title: "Copie locali dei due lavori concorrenti (dati non fidati, fuori dal repository)"}
---

# In breve

## In breve: il modello sa scrivere i fattori di uno studio meglio di come la pipeline di oggi forma i confronti?

**A cosa serviva.** Il 9 novembre hai deciso di sostituire i due passi del modello con un passo solo, il lettore dello studio. Il lettore legge il testo dello studio e scrive i fattori dell'esperimento. Poi un programma senza modello forma i confronti fra trattato e controllo. Prima di portare il lettore nel pacchetto abbiamo fatto una prova piccola: 47 studi che hanno anche la curazione manuale di Expression Atlas, un solo modello e un solo prompt. Abbiamo misurato nello stesso modo la pipeline di oggi.

**Cosa abbiamo trovato.**

1. **La prima versione del lettore non fa meglio della pipeline di oggi.** Il lettore forma gli stessi gruppi dei curatori in 14 studi su 47, come la pipeline di oggi. Dei 93 confronti dei curatori che rispettano la nostra definizione, il lettore ne ritrova 10 e la pipeline di oggi 19. La regola scritta prima della prova chiedeva un lettore migliore di oggi: la regola non è soddisfatta.
2. **Il lettore non completa 24 studi su 47, e in 18 la causa è la forma della risposta.** Lo schema chiede al modello una lista di valori per ogni livello, e il modello scrive liste di lunghezza sbagliata. Se il programma tollera quella forma, il lettore completa 33 studi, forma gli stessi gruppi dei curatori in 20 e ritrova 15 confronti. Ho fatto questo controllo dopo aver visto i numeri, quindi non è una misura.
3. **Tolta la forma, restano errori di lettura del modello.** Ho letto tutti i 145 disaccordi fra il lettore e i curatori. In 13 studi il modello scrive un fattore preso dal titolo del campione, con un livello per ogni campione. Un fattore così divide ogni gruppo in campioni singoli. In 4 studi un fattore esiste solo dentro un livello di un altro, per esempio lo stadio dentro la malattia, e lo schema non dice come scriverlo.
4. **Dove il lettore forma gli stessi gruppi dei curatori, 12 dei 16 confronti che mancano sono scelte dei curatori.** In quei 14 studi i curatori hanno 26 confronti e il lettore ne ritrova 10. Dei 16 che mancano, 10 usano il tempo zero come controllo e 2 usano un riferimento che non è un controllo. Le tue regole vietano il tempo zero come controllo. La pipeline di oggi ritrova 6 di quei confronti, e li conta fra i suoi 19.
5. **Anche la pipeline di oggi è lontana dai curatori.** Ritrova 19 confronti su 93, e 19 dei suoi 79 confronti giudicabili sono errori. Nei 14 studi dove forma gli stessi gruppi dei curatori ritrova 16 confronti su 19. Negli altri 33 studi ne ritrova 3 su 74, perché divide i campioni in più gruppi dei curatori.

**Cosa devi decidere.**

1. **Che cosa facciamo del lettore dello studio? Raccomando di correggere lo schema e di ripetere la prova sugli stessi 47 studi, con il modello di oggi e con uno o due modelli più grandi.** La prova costa poco: una corsa dura 12 minuti. Scrivo le previsioni nuove prima della corsa. Gli 82 studi tenuti per il giudizio finale restano chiusi. Dopo la prova decidi il passo seguente sui numeri. Il limite è questo: gli stessi 47 studi servono una seconda volta, quindi il risultato vale per lo sviluppo e non come giudizio. Le alternative:
   - Portare subito il lettore nel pacchetto. Questa scelta va contro la regola scritta prima della prova, e oggi nessun numero dice che il lettore supera la pipeline.
   - Fermare il lettore e correggere i due passi di oggi. La prova dell'8 novembre ha mostrato che il difetto nasce dal compito dato a quei due passi. Questa scelta chiede di ritirare la decisione del 9 novembre.
2. **I curatori usano il tempo zero come controllo, e per te è sempre un errore: lo togliamo dal riferimento? Raccomando di sì, con una regola scritta prima della prossima prova.** Oggi un lettore senza difetti perde quei confronti, e la pipeline di oggi li guadagna. Riporto sempre anche la misura intera, accanto alla misura corretta. L'alternativa è lasciare il riferimento com'è. In quel caso la misura resta quella dei curatori, ma premia un confronto che le tue regole vietano.

**Comunque.** La decisione del 9 novembre e il risultato su disco restano come sono finché non decidi. Ho letto per intero i due lavori concorrenti usciti nel 2026. Nessuno dei due forma confronti fra trattato e controllo e nessuno fa una meta-analisi, quindi il nostro contributo resta. La seconda curazione che volevamo usare, quella dell'università UBC, non risponde alle richieste: resta fuori, e il documento lo dichiara come limite.

Appena decidi questi 2 punti, la sessione è chiusa.

**Sui tempi di calcolo.** I 12 minuti sono misurati: una corsa del modello di oggi sui 47 studi, con 4 processori grafici. Un modello più grande ha tempi diversi, e non li ho misurati.

---

# 1. Che cosa è stato fatto

La sessione S12r ha eseguito il Piano 1 «fondamenta e prova» (Parte B del piano[^piano], Task 1-11) sul branch
`p6-tabella-dei-fattori`, a valle di ADR-0029[^adr29]:

1. cancelli e previsioni depositati prima di ogni calcolo[^previsioni] (Task 1);
2. il costruttore deterministico dei confronti nel pacchetto, con TDD: `tf_tabella()`, `tf_gruppi()`,
   `tf_confronti()`, `tf_misura_studio()`, `tf_riassumi_misure()` e i lettori di Atlas (Task 2-7);
3. la misura della pipeline di oggi (master S14) contro Atlas sui 47 studi di sviluppo (Task 8);
4. la vista v0, lo schema v0 e il prompt v0 (Task 9), **prova da buttare**: nessun file in `R/`;
5. due corse uguali di Mistral-Small-3.2 su `poddgx02`, l'adattatore, la misura del lettore v0 e la lettura di
   tutti i disaccordi (Task 10);
6. questo documento (Task 11).

Gli 82 studi di giudizio (42 A, 40 B) non sono stati aperti: vedi K5.

# 2. Cancelli

| cancello | che cosa chiede | esito | prova |
|---|---|---|---|
| K1 | il legame SRR → GSM copre gli studi di sviluppo; ENA e `relation` dell'H5 concordano | **passato** | 6.253 run su 6.253 con un GSM, 6.143 con due fonti, 0 disaccordi; 47 studi di sviluppo su 47 con almeno un run legato[^legame] |
| K2 | controllo positivo dello strumento: Atlas dato allo strumento come se fosse l'uscita del lettore | **passato** | partizione identica in 47 studi su 47; 93 confronti che rispettano la definizione, 93 ritrovati uguali[^oggi] |
| K3 | la misura di oggi copre 47 studi su 47 | **passato** | master S14: 24.393 record, 47 studi di sviluppo su 47 con un record[^oggi] |
| K4 | job su `poddgx02`, `VLLM_BATCH_INVARIANT=1`, `HF_HUB_OFFLINE=1`, prompt e schema del bundle uguali ai file committati | **passato** | due corse `COMPLETED` su `poddgx02` (slurm 476642 e 476755); variabili lette da `container-env.txt`; SHA-256 di `prompt.txt` e `schema.json` uguali a `62-prompt-v0.md` e `61-schema-v0.json`[^corsa] |
| K5 | nessuno script riceve un contenuto di uno studio di giudizio | **passato** | vedi sotto |

**K5, la verifica.** (1) Da Atlas, per gli 82 studi di giudizio è stato scaricato solo il file di configurazione
(82 file), letto con `solo_id = TRUE` in `33-legame.R`; il file SDRF è stato scaricato solo per i 47 studi di
sviluppo (`31-manifesto-atlas.tsv`). (2) I testi GEO scaricati (`50-manifesto-geo.tsv`) riguardano 0 studi di
giudizio. (3) L'ingresso del modello, le due uscite e le viste hanno 47 record ciascuno, 0 di giudizio. (4) Nella
cartella dell'evidenza un identificativo di uno studio di giudizio compare solo in cinque file: `30-divisione.tsv`,
`31-manifesto-atlas.tsv`, `32-manifesto-ena.tsv`, `33-legame.tsv` (identificativi, impronte, legami run-campione) e
`20-atlas-studi-nostri.txt`, la perdita già dichiarata nelle previsioni (nomi dei tipi di fattore per i 129 studi,
commit 37c882b), i cui campi dal quinto in poi non sono stati letti. (5) `aiuti.R` ferma ogni script della prova se
riceve uno studio che non è di sviluppo (`solo_sviluppo()`).

Un'anomalia sul K4: il primo invio (slurm 476592) è fallito in 1 min 30 s, prima di generare, perché la cache KV
(8,36 GiB) non bastava per `max_model_len = 65536` (ne servivano 10,0). Corretto con
`gpu_memory_utilization = 0.95`; nessuna uscita è stata prodotta dal primo invio.

# 3. Le misure e le previsioni

Unità: lo studio. Intervalli: bootstrap sugli studi, B = 2.000, seme 20261109. I valori attesi delle previsioni
sono un giudizio motivato dell'agente, non una soglia del progetto[^previsioni].

- **(a) gruppi:** quota di studi in cui la partizione dei campioni è identica a quella di Atlas.
- **(b) confronti:** quota dei confronti di Atlas che rispettano la definizione (due gruppi uguali in tutti i
  fattori tranne uno, con uno dei due al livello di base) ritrovati con gli stessi campioni e lo stesso verso.
- **(c) errori:** quota dei nostri confronti non elencati da Atlas e giudicabili che lo strumento classifica come
  errore: un braccio misto, o più di un fattore di Atlas che cambia. Un nostro confronto senza nessuna differenza nei
  fattori di Atlas è giudicabile: sta nel denominatore e non conta come errore (oggi 4 su 79).

Universo: 1.798 campioni nei gruppi di Atlas e nel nostro bacino (1.841 nei gruppi di Atlas). Atlas elenca 123
confronti nei 47 studi: 93 rispettano la definizione, 29 differiscono in più di un fattore di Atlas, 1 non è
formabile (un braccio fuori dall'universo).

**Il 93 dipende da una regola di lettura.** In 11 dei 93 confronti (6 studi) i curatori non scrivono un fattore per
uno dei due bracci, di solito la dose per il controllo. La misura segue la regola del costruttore: un fattore non
scritto in un braccio non conta come differenza. La regola è stata fissata prima di ogni misura, dopo che 6 studi si
erano fermati nella lettura di Atlas. Con la lettura stretta (non scritto = differenza) gli 11 passano a «più di un
fattore» e il denominatore è 82: oggi 18/82 (22,0%), lettore 8/82 (9,8%), differenza −12,2 punti contro −9,7
(`67-out.txt`, lettura fatta dopo i numeri, senza intervallo). La conclusione non cambia.

## 3.1 La pipeline di oggi e il lettore v0, 47 studi

| misura | oggi (master S14) | lettore v0 | lettore meno oggi, appaiato |
|---|---|---|---|
| (a) gruppi identici | 14/47 = 29,8% (17,0-42,6) | 14/47 = 29,8% (17,0-42,6) | 0,0 punti (−12,8, +12,8) |
| (b) confronti ritrovati | 19/93 = 20,4% (9,4-34,9) | 10/93 = 10,8% (3,9-19,3) | −9,7 punti (−25,3, +4,3) |
| (c) errori fra i non elencati | 19/79 = 24,1% (10,6-39,3) | 1/5 = 20,0% (0-100) | −4,1 punti (−32,0, +76,3) |
| confronti formati | 118 | 20, in 10 studi | |
| verso opposto | 1/93 | 0/93 | |
| confronti di Atlas con più fattori, formati anche da noi | 7/29 | 2/29 | |
| ARI mediana | 0,778 (47 studi) | 1,000 (23 studi chiusi) | |
| studi con almeno un confronto di Atlas ritrovato | 13 su 41 | 8 su 41 | |

Fonti: [^oggi], [^lettore]. Nel confronto appaiato di (c), 106 ricampioni su 2.000 non hanno un valore (il lettore
non ha confronti giudicabili nel ricampione).

Classi della partizione (righe: lettore; colonne: oggi):

| lettore \ oggi | identica | incrociata | più fine | totale |
|---|---|---|---|---|
| identica | 9 | 2 | 3 | 14 |
| non chiuso | 4 | 3 | 17 | 24 |
| più fine | 1 | 1 | 7 | 9 |
| totale | 14 | 6 | 27 | 47 |

Dei 20 confronti del lettore, 9 non hanno avvisi e 11 ne hanno (soggetti diversi 10, soggetti in parte 2). Il
fattore che cambia è una perturbazione in 9 e uno stato in 11. Tredici studi chiusi non hanno confronti.

## 3.2 Soli studi chiusi dal lettore (23)

| misura | lettore v0 | oggi, sugli stessi 23 | lettore meno oggi |
|---|---|---|---|
| (a) | 14/23 = 60,9% (39,1-78,3) | 10/23 = 43,5% (21,7-65,2) | +17,4 punti (0,0, +34,8) |
| (b) | 10/41 = 24,4% (10,5-42,1) | 14/41 = 34,1% (12,5-60,9) | −9,8 punti (−41,7, +18,5) |
| (c) | 1/5 | 5/21 = 23,8% | −3,8 punti (−31,6, +60,0) |

## 3.3 Le previsioni con l'esito

| previsione | atteso (rilevanza) | misurato | esito |
|---|---|---|---|
| P1 oggi, (b) | 35% (20-50%) | 19/93 = 20,4% (9,4-34,9) | **indeterminata** |
| P2 oggi, (a) | 30% (15-45%) | 14/47 = 29,8% (17,0-42,6) | **confermata** |
| P3 lettore meno oggi, (b) | +30 punti (IC95 sopra 0) | −9,7 punti (−25,3, +4,3) | **indeterminata**: l'intervallo contiene lo zero, la stima è negativa |
| P4 lettore, (a) | 65% (50-80%) | 14/47 = 29,8% (17,0-42,6) | **smentita** |
| P5 (c), lettore | 5% (0-10%) | 1/5 = 20,0% (0-100) | **indeterminata**: 5 confronti giudicabili |
| P5 (c), oggi | 25% (15-35%) | 19/79 = 24,1% (10,6-39,3) | **indeterminata** |
| P6 studi non chiusi | 4 su 47 (0-7) | 24 su 47 (23 per i sette esiti del piano) | **smentita** |
| P7 uscite identiche fra le due corse | 47 su 47 | 47 su 47 | **confermata** |
| P8 confronti di Atlas fuori dalla definizione (descrittiva) | 10% (5-20%) | 29/123 = 23,6% (9,6-38,2) | **indeterminata** |

**La regola di esito**[^spec] (§5.6): «Si passa al Piano 2 se P3 è confermata, se il lettore fa meglio di oggi anche
in (a) e in (c), e se ogni disaccordo del lettore ha una causa che la vista, lo schema o un modello più grande
possono togliere. In ogni altro caso il PI vede numeri e cause e decide.» P3 non è confermata, il lettore è pari a
oggi in (a), e in (c) ha 5 confronti giudicabili. **La regola non è soddisfatta: decide il PI.**

## 3.4 I dubbi aperti dalle previsioni, e come sono chiusi

- **P1 (oggi ritrova il 20%, attesi 35%).** Spiegato. La pipeline di oggi forma 411 gruppi nell'universo contro i
  172 di Atlas. Per classe della partizione (`40-per-studio-oggi.csv`): nei 14 studi con partizione identica ritrova
  16 confronti su 19; nei 6 con partizione incrociata 0 su 17; nei 27 con partizione più fine 3 su 57. Dove i
  gruppi sono quelli dei curatori i confronti tornano; dove sono più fini il confronto ha gli stessi nomi ma non gli
  stessi campioni, e la misura (b) chiede gli stessi campioni. Nove studi non hanno nessun confronto di oggi.
- **P8 (il 24% dei confronti di Atlas ha più di un fattore, attesi 10%).** Spiegato dalla lettura (§5.3): i 29
  confronti stanno in 8 studi. In 14 i curatori scrivono come due fattori una variabile annidata (malattia e stadio,
  malattia e sottotipo); in 5 usano un riferimento che non è un controllo; in 3 il tempo zero. Non è un errore di
  Atlas: è il suo modo di scrivere i fattori. Per noi vuol dire che una parte dei confronti dei curatori sta fuori
  dalla definizione di ADR-0029 per come loro scrivono la tabella, non per il disegno dello studio.
- **P4 e P6 (smentite) e P3 (indeterminata, tocca la conclusione).** Spiegate nelle cause (§5) e portate al PI
  (decisione 1).
- **P5.** Il lettore forma 20 confronti, 8 non elencati, 5 giudicabili: la misura (c) del lettore non dice niente
  finché il lettore non chiude più studi. L'unico errore contato (GSE56787, «più fattori») è un limite dello
  strumento: Atlas scrive la stessa differenza in due fattori ridondanti e la misura la conta due volte[^disaccordi].

# 4. La sensibilità sulla forma delle voci (dichiarata dopo i numeri, non una misura)

La causa più frequente dei 24 studi non chiusi è la forma delle voci di `assignment`: lo schema v0 vuole, per ogni
voce, tanti valori quante sono le colonne di fonte del fattore, e il modello ne scrive di più (per esempio 5 valori
dove la colonna è una). L'adattatore depositato non usa quelle voci. Dopo aver visto i numeri ho rifatto la misura
con un adattatore che legge anche quelle voci (`S12R_SENSIBILITA=forma`, `66-forma-*`). **È un'analisi in più,
dichiarata come tale: le misure depositate restano quelle del §3.**

| | misura depositata | sensibilità «forma» | oggi |
|---|---|---|---|
| studi chiusi | 23/47 | 33/47 | 47/47 |
| (a) | 14/47 = 29,8% | 20/47 = 42,6% (29,8-57,4) | 14/47 = 29,8% |
| (b) | 10/93 = 10,8% | 15/93 = 16,1% (6,9-27,3) | 19/93 = 20,4% |
| (c) | 1/5 | 2/7 | 19/79 |
| confronti formati | 20 in 10 studi | 31 in 15 studi | 118 |
| lettore meno oggi, (a) | 0,0 | +12,8 punti (−4,3, +29,8) | |
| lettore meno oggi, (b) | −9,7 | −4,3 punti (−21,7, +11,8) | |

Sui 33 studi chiusi nella sensibilità: lettore (a) 20/33 e (b) 15/63; oggi sugli stessi (a) 10/33 e (b) 15/63.
Anche tollerando la forma, il lettore v0 non supera oggi in (b)[^forma].

# 5. Le cause: lettura di tutti i 145 disaccordi

Audit interno: le cause le ha lette un agente Claude sul materiale dei 47 studi di sviluppo (vista, uscita del
modello, tabella di Atlas, incrocio dei gruppi, registro delle coppie). Non è una misura dell'articolo. Lo script
`65-disaccordi.R` prende le unità dalle tabelle della misura e si ferma se una resta senza causa[^disaccordi].

## 5.1 Le unità

| unità | numero |
|---|---|
| studio che il lettore non chiude | 24 |
| studio chiuso con partizione non identica | 9 |
| confronto di Atlas non ritrovato | 111 (83 nel denominatore di (b), 28 fuori) |
| confronto del lettore giudicato errore | 1 |
| **totale** | **145**, in 41 studi su 47 |

Senza disaccordi: GSE53280, GSE54846, GSE56235, GSE58326, GSE59781, GSE71421.

## 5.2 Prima causa e resto

Ogni unità ha una **prima causa** (il primo difetto che la misura incontra) e un **resto** (che cosa resta tolta la
prima causa). Prima causa: modello 120, curatore 22, strumento 2, schema 1, vista 0.

| causa | che cosa vuol dire | chi può toglierla | prima causa | resto | studi (prima causa, resto o nota «in più») |
|---|---|---|---|---|---|
| modello/forma delle voci | una voce di `assignment` porta più valori delle colonne di fonte | schema (effetto misurato, §4) | 68 | 0 | 18 |
| modello/fattore dal titolo | un fattore tecnico o di replica letto dal titolo: un livello per campione | modello | 27 | 18 | 13 |
| modello/combinazione non coperta | una combinazione di valori resta senza voce | modello | 15 | 0 | 4 |
| modello/livello | livello sbagliato per un gruppo | modello | 4 | 3 | 2 |
| modello/mappa ambigua | la stessa combinazione ha due livelli | modello | 3 | 0 | 1 |
| modello/fattore doppio | due fattori scritti dalla stessa informazione | modello | 1 | 11 | 5 |
| modello/ruolo di soggetto | una colonna di condizione letta come donatore, o il passaggio come fattore | modello | 1 | 0 | 3 |
| modello/base | livello di base non scritto dove c'è | modello | 1 | 0 | 1 |
| schema/fattore annidato | un fattore che esiste solo dentro un livello di un altro (sottotipo, stadio) | schema | 0 | 16 | 4 |
| schema/soggetto «NA» | lo schema non dice quali valori di una colonna di soggetto valgono «non scritto» | schema | 0 | 5 | 1 |
| schema/contesto senza base | un fattore di contesto non ha livello di base: due condizioni di coltura non si confrontano | schema | 1 | 2 | 2 |
| curatore/tempo zero | Atlas usa il tempo zero come controllo | non serve | 10 | 4 | 3 |
| curatore/riferimento | Atlas usa come riferimento un gruppo che non è un controllo | non serve | 7 | 0 | 1 |
| curatore/errore di campione | Atlas mette un campione nel gruppo sbagliato | non serve | 2 | 3 | 2 |
| curatore/fattore ignorato | Atlas ignora una colonna di GEO che distingue i campioni | non serve | 2 | 2 | 2 |
| curatore/repliche | Atlas tratta come repliche campioni che differiscono in una variabile | non serve | 0 | 2 | 1 |
| curatore/fattori combinati | Atlas confronta due gruppi che differiscono in due fattori veri | non serve | 1 | 0 | 1 |
| strumento/universo | un braccio del confronto di Atlas non ha campioni nell'universo | non serve | 1 | 0 | 1 |
| strumento/fattori ridondanti | la misura (c) conta due volte la stessa differenza scritta due volte da Atlas | strumento | 1 | 0 | 1 |

«Modello» nella colonna del rimedio vuol dire «serve un modello che legge meglio»: è una **ipotesi non misurata**,
perché questa prova ha un modello solo. «Schema» per la forma delle voci è misurato (§4); per le altre tre
sottoclassi è una proposta.

Che cosa resta nelle 68 unità la cui prima causa è la forma delle voci: niente (la sensibilità ritrova il confronto
o chiude lo studio con partizione identica) 14; non osservabile (lo studio non chiude nemmeno nella sensibilità) 15;
fattore dal titolo 15; fattore annidato 7; soggetto «NA» 5; tempo zero del curatore 4; errore di campione del
curatore 3; livello 3; repliche del curatore 2.

## 5.3 Esito della catena

| unità | basta la forma (misurato) | solo schema | serve un modello migliore (ipotesi) | non è un errore del lettore | ignoto | totale |
|---|---|---|---|---|---|---|
| studio non chiuso | 6 | 1 | 10 | 3 | 4 | 24 |
| partizione non identica | 0 | 0 | 6 | 3 | 0 | 9 |
| confronto di Atlas non ritrovato | 8 | 12 | 52 | 28 | 11 | 111 |
| confronto del lettore giudicato errore | 0 | 0 | 0 | 1 | 0 | 1 |

Per la regola di esito: non «ogni» disaccordo ha una causa che vista, schema o modello più grande possono togliere.
35 unità non sono errori del lettore (scelte o errori dei curatori, limiti della misura) e 15 restano di causa ignota
perché lo studio non chiude nemmeno nella sensibilità.

**Sugli 83 confronti del denominatore di (b) non ritrovati:** forma 5, schema 6, modello 44, non errore 17, ignoto
11. I 17 «non errore»: tempo zero come controllo 10 (GSE49608 6, GSE103501 4), riferimento che non è un controllo 2
(GSE60340), errore di campione 2 (GSE50760), fattore ignorato 2 (GSE93624, GSE77598), repliche 1 (GSE44379). La
pipeline di oggi ne ritrova 6, tutti in GSE49608 con il tempo zero come controllo. Lettura senza i 17 (**non una
misura**): denominatore 76, lettore 10, oggi 13.

**Nei 14 studi dove il lettore ha la partizione identica ad Atlas** (`64-per-studio-lettore.csv` incrociato con
`65-disaccordi-righe.csv`): 26 confronti di Atlas nel denominatore, 10 ritrovati, 16 no. Dei 16: tempo zero 10,
riferimento 2, modello 3 (base non scritta, fattore doppio, ruolo di soggetto), schema 1 (contesto senza base).

## 5.4 La classe «livello combinato»

Il piano chiedeva di contare a parte i casi in cui i curatori scrivono due agenti come un livello solo e il lettore
come due fattori. **Disaccordi di questa classe: 0.** Nei 47 studi c'è un solo livello di Atlas con due agenti
(GSE52778, «albuterol and dexamethasone»): il lettore lo scrive come un livello solo, come Atlas. La decisione
prevista dal piano («che cosa fare dei confronti con livello combinato, se sono molti») non serve.

La classe vicina è più frequente: i 29 confronti di Atlas con più di un fattore, in 8 studi (GSE52194 3, GSE56691
3, GSE56787 3, GSE57945 5, GSE60340 5, GSE65335 1, GSE66207 3, GSE69597 6). Il lettore ne ritrova 2 (5 nella
sensibilità). Dei 27 non ritrovati: fattore annidato 14 (GSE57945, GSE66207, GSE69597), riferimento 5 (GSE60340),
tempo zero 3 (GSE56691), forma delle voci 3 (GSE52194), errore di campione 1, fattori combinati 1.

# 6. Che cosa dice la prova, e che cosa non dice

1. **Il costruttore funziona.** Con la tabella di Atlas in ingresso ridà la partizione di Atlas in 47 studi su 47 e
   93 confronti su 93 (K2). Il difetto del lettore v0 non sta nel costruttore.
2. **Il lettore v0 non scrive la tabella in metà degli studi.** La causa che domina è nello schema: `values` è una
   lista libera allineata per posizione a `source_columns`, e il modello sbaglia la lunghezza. È un difetto del
   compito come l'ho scritto, non una pezza da mettere dopo il modello: si toglie rendendo la forma non sbagliabile
   nello schema.
3. **Tolta la forma, il lettore ha più gruppi identici di oggi ma non più confronti.** Nella sensibilità (a) passa
   a 20/47 contro 14/47, (b) resta a 15/93 contro 19/93. I confronti mancano per tre motivi: studi ancora non chiusi
   (14), fattori per campione letti dal titolo, e scelte dei curatori che la definizione esclude.
4. **Il riferimento non è neutro rispetto alle regole del PI.** Atlas usa il tempo zero come controllo; la regola
   del PI dice che è sempre un errore. Sei dei 19 confronti ritrovati da oggi sono di questo tipo.
5. **Che cosa la prova non dice.** Non dice se un modello più grande toglie gli errori di lettura (un solo modello).
   Non dice se un altro prompt cambia il risultato (un solo prompt). Non dice niente sugli 82 studi di giudizio.

# 7. Misure portate al passo seguente

| misura | valore | fonte |
|---|---|---|
| vista: studi costruiti | 47 su 47; 1.883 campioni del bacino; 0 cancellati da GEO; 76 campioni nel testo GEO fuori dal bacino (non entrano) | [^vista] |
| vista: token stimati | mediana 3.059, massimo 37.692; 0 studi oltre il limite del prompt (49.152) | [^vista] |
| prompt, token veri | minimo 1.075, mediana 1.825, media 3.314, massimo 30.952; totale 155.775 | [^lettore] |
| uscita, token veri | minimo 66, mediana 957, media 1.338, massimo 13.324 (GSE83687; limite 16.384); totale 62.872; fine `stop` in 47 su 47 | [^lettore] |
| tempo | job di 12 min 19 s; 4 worker (110, 141, 220, 647 s); 23,8 secondi-GPU per studio | [^lettore] |
| ripetibilità | uscite identiche al carattere fra le due corse, 47 su 47 | [^lettore] |
| studi oltre il contesto | 0 su 47. Nel bacino intero la tabella dei campioni supera 32.000 token in 49 studi su 24.393 e 64.000 in 21 | [^bacino] |

La stima dei token della vista (caratteri / 2,29) è prudente: il massimo vero è 30.952 contro 37.692 stimati.
L'uscita più lunga arriva all'81% del limite: su tutto il bacino `max_tokens` 16.384 non basterà per gli studi con
molti livelli. Una stima grezza per il bacino intero, **non misurata**: 24.393 studi × 23,8 s = 161 ore-GPU, circa
20 ore con 8 GPU. La media dei 47 studi è dominata da uno studio lungo, e il bacino ha studi molto più grandi.

# 8. I lavori concorrenti, letti per intero

Copie in `analysis/input/concorrenti-2026-11-10/`[^copie].

**GEOAgent**[^geoagent] (bioRxiv, 2026-06-10). Il DOI scritto nel piano (10.1101/…) non esiste: quello vero è
10.64898/2026.06.06.730646.

- *Che cosa fa.* Una piattaforma di **ricerca** di dataset GEO in linguaggio naturale (recupero a più stadi: indice
  testuale, database vettoriale, filtro con un modello, riordino) e di preparazione dei dati grezzi (allineamento e
  conte con Nextflow). Il modello classifica il tipo di saggio, rinomina i campioni e appaia campioni legati: il
  ChIP-seq con il suo input, l'RNA e l'ATAC dello stesso Multiome.
- *Su quali dati.* 181.760 serie di sequenziamento, 5.083.620 campioni, uomo e topo.
- *Con quale validazione.* 10 domande, i primi 10 risultati giudicati da due esperti e un terzo: 47 veri positivi su
  49. Tre compiti di curazione su 10 dataset ciascuno: 10 su 10.
- *Che cosa cambia per noi.* Niente sul contributo. «Resolves experimental design pairings» nell'abstract è
  l'appaiamento tecnico fra campioni, non il confronto fra trattato e controllo. L'espressione differenziale è citata
  come lavoro futuro. Nessuna validazione contro una curazione esterna dei confronti.

**Szczepaniak e Wren**[^rs] (Research Square, 2026-08-31).

- *Che cosa fa.* Una pipeline con un modello locale che annota **per campione** tessuto, condizione e trattamento
  (più sesso ed età). Prima estrae per campione; poi recupera le etichette mancanti dal testo dello studio e dalle
  etichette degli altri campioni dello studio; poi collega le etichette a MeSH e Cellosaurus.
- *Su quali dati.* 804.427 campioni GEO umani. Modello `gemma-4-12B-it` con vLLM.
- *Con quale validazione.* 1.500 campioni di CREEDS per tessuto e condizione, 1.500 per il trattamento, giudizio
  manuale di un autore. F1: tessuto 0,997, condizione 0,957, trattamento 0,907 (recall 0,847). Copertura del
  trattamento dopo il recupero: 45,91%. La riproducibilità al bit non è garantita. Un modello Claude fa da giudice
  nell'audit dei concetti fuori vocabolario.
- *Che cosa cambia per noi.* È il lavoro più vicino al nostro vecchio primo passo (fatti per campione, più il
  contesto dello studio), su più campioni dei nostri (804.427 contro 508.037) e con il collegamento a un vocabolario.
  **Non forma confronti, non decide trattato e controllo dentro lo studio, non calcola effetti né meta-analisi.** Il
  suo punto debole dichiarato è il trattamento, cioè il campo che decide i nostri confronti. Il nostro contributo
  resta la catena dal metadato al confronto appaiato e alla meta-analisi, con la validazione dei confronti contro una
  curazione esterna.

La frase della spec[^spec] (§6) resta vera dopo la lettura completa: non ho trovato lavori che uniscono confronti
estratti da un modello, meta-analisi a effetti casuali di RNA-seq e validazione contro una curazione umana.

**Gemma (UBC), seconda fonte di curazione.** Riprovata il 2026-11-10: tre richieste all'API
(`https://gemma.msl.ubc.ca/rest/v2/`) in timeout (40 s, 40 s, oltre 120 s), dopo i due timeout della sessione
precedente. Non entra come seconda fonte.

# 9. Limiti

- **47 studi.** Gli intervalli sono larghi: la differenza in (b) va da −25 a +4 punti. La prova distingue «molto
  meglio» da «non meglio», non differenze piccole.
- **Composizione.** Gli studi curati da Atlas sono più spesso malattia contro sano su tessuti che perturbazioni su
  linee cellulari: nei confronti del lettore il fattore è uno stato in 11 su 20. Il deliverable è fatto soprattutto di
  perturbazioni.
- **Un solo modello, un solo prompt, uno schema.** Nessuna delle ipotesi «un modello più grande legge meglio» è
  misurata.
- **Il riferimento ha scelte e errori dei curatori.** 22 unità su 145 hanno il curatore come prima causa. La lettura
  delle cause è un audit interno fatto da un agente, non una misura.
- **Una sola fonte di curazione.** Gemma non risponde.
- **Il conto degli studi per causa include le note.** «Fattore dal titolo in 13 studi» e «fattore annidato in 4 studi»
  contano anche lo studio dove la causa è solo una nota (GSE83415 e GSE63816). Come prima causa o resto sono 12 e 3
  (`67-out.txt` §3).
- **Il denominatore 93 dipende dalla regola sul fattore non scritto** (§3): con la lettura stretta è 82.
- **La penalità di ripetizione non è misurata.** Il lettore v0 gira con `repetition_penalty` 1,1, come la produzione.
  La penalità può disturbare la ripetizione di valori uguali nelle voci di `assignment`. Questa prova attribuisce la
  forma sbagliata delle voci allo schema e non separa le due cause: la prova ripetuta deve avere una corsa di
  controllo senza penalità, con la previsione scritta prima.
- **La causa «fattore annidato» è contata come limite dello schema.** Se si conta come scelta dei curatori, 16 unità
  (resto) passano da «schema» a «non è un errore del lettore».
- **La sensibilità sulla forma è stata decisa dopo aver visto i numeri.** Anche i conti di `67-out.txt`, chiesti
  dalla revisione finale del branch.
- **I valori attesi delle previsioni** erano un giudizio dell'agente, e due sono stati smentiti di molto (P4, P6):
  le attese sul lettore erano troppo ottimiste.

# 10. Anomalie viste durante il lavoro

- Primo invio del job fallito per la cache KV (§2), corretto prima di ogni uscita.
- Il log di vLLM cita un default «since v0.21.0» con il container v0.20.2: etichetta di versione, nessun effetto
  sulle uscite (identiche fra le due corse).
- `devtools::document()` stampa «stage4-samn-dedupe.R:17: Block must have a @name»: preesistente, non toccato.
- Il DOI di GEOAgent nel piano era sbagliato (§8).
- `container-env.txt` delle corse contiene il token di Hugging Face. Non è committato e non è in nessun file del
  branch. Il valore è comparso una volta nell'uscita di un comando della sessione.

# 11. Da dove vengono i numeri del riassunto

| frase del riassunto | file e riga | valore letto |
|---|---|---|
| stessi gruppi dei curatori in 14 studi su 47, lettore e oggi | `64-out.txt` righe 117 e 127 | `a_gruppi_identici 14 47` in entrambe |
| 93 confronti che rispettano la definizione; lettore 10, oggi 19 | `64-out.txt` righe 118 e 128 | `b_confronti_ritrovati 10 93`; `19 93` |
| il lettore non completa 24 studi su 47 | `64-out.txt` riga 20 | `studi chiusi dal lettore: 23 su 47 ; non chiusi: 24` |
| in 18 la causa è la forma della risposta | `65-out.txt` riga 32 | `modello/forma_voci 18` (colonna `studio_non_chiuso`) |
| con la forma tollerata: 33 studi, 20 con gli stessi gruppi, 15 confronti | `66-forma-out.txt` righe 22, 115, 116 | `33 su 47`; `a_gruppi_identici 20 47`; `b_confronti_ritrovati 15 93` |
| 145 disaccordi | `65-out.txt` riga 10 | `unita' di disaccordo: 145` |
| fattore dal titolo in 13 studi; fattore annidato in 4 studi | `65-disaccordi.md`, tabella «Le cause», colonna «studi (prima, resto o in più)»; `67-out.txt` §3 | `modello/fattore_dal_titolo … 13`; `schema/fattore_annidato … 4` |
| nei 14 studi con gli stessi gruppi: 26 confronti, 10 ritrovati | `64-per-studio-lettore.csv`, somma di `n_rispetta` e `n_rispetta_uguale` dove `classe_gruppi` = `identica` | 26; 10 |
| dei 16 che mancano, 10 tempo zero e 2 riferimento | `65-disaccordi-righe.csv`, righe `atlas_non_ritrovato` con `classe` = `rispetta` negli stessi 14 studi | `curatore/tempo_zero` 10 (GSE49608 6, GSE103501 4); `curatore/riferimento` 2 (GSE60340) |
| la pipeline di oggi ne ritrova 6 | `65-disaccordi-righe.csv`, colonna `oggi` = `uguale` nelle righe `curatore/tempo_zero` | 6 (GSE49608) |
| oggi: 19 su 93; 19 errori su 79 giudicabili | `40-out.txt` righe 49 e 50 | `b_confronti_ritrovati 19 93`; `c_errori_non_elencati 19 79` |
| oggi, 14 studi con gli stessi gruppi: 16 su 19; negli altri 33: 3 su 74 | `40-per-studio-oggi.csv`, somme per `classe_gruppi` | identica 14 studi, 19, 16; incrociata 6 studi, 17, 0; più fine 27 studi, 57, 3 |
| una corsa dura 12 minuti, 4 processori grafici | `63-out.txt` (slurm 476642, `COMPLETED 00:12:19`); `64-out.txt` riga 191 | `corsa1: 4 worker, 47 studi` |
| 82 studi tenuti per il giudizio | `30-divisione.tsv` | 42 `giudizio_A` + 40 `giudizio_B` |
| due lavori concorrenti, nessuno forma confronti | §8 di questo documento, dalle copie in `analysis/input/concorrenti-2026-11-10/` | lettura completa dei due testi |

[^previsioni]: `analysis/audit/2026-11-09-lettore-studio/00-previsioni.md`.
[^legame]: `analysis/audit/2026-11-09-lettore-studio/33-out.txt`.
[^oggi]: `analysis/audit/2026-11-09-lettore-studio/40-out.txt`.
[^vista]: `analysis/audit/2026-11-09-lettore-studio/60-out.txt`.
[^corsa]: `analysis/audit/2026-11-09-lettore-studio/63-out.txt`.
[^lettore]: `analysis/audit/2026-11-09-lettore-studio/64-out.txt`.
[^disaccordi]: `analysis/audit/2026-11-09-lettore-studio/65-disaccordi.md` e `65-disaccordi-righe.csv`.
[^forma]: `analysis/audit/2026-11-09-lettore-studio/66-forma-out.txt`.
[^bacino]: `analysis/audit/2026-11-09-lettore-studio/10-out.txt`.
[^spec]: `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`.
[^piano]: `docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md`.
[^adr29]: `docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md`.
[^geoagent]: Zhao Y, Cai Q, Chen D, Chen J. bioRxiv 2026, doi:10.64898/2026.06.06.730646.
[^rs]: Szczepaniak M, Wren JD. Research Square 2026, doi:10.21203/rs.3.rs-10844781/v1.
[^copie]: `analysis/input/concorrenti-2026-11-10/` (non nel repository).
