---
type: Finding
title: "La terza prova piccola del lettore dello studio: schema delle uscite a elenco chiuso, Mistral-Small 3.2, gli stessi 47 studi contro Expression Atlas"
description: "Con lo schema delle uscite generato per ogni studio il lettore chiude 45 studi su 47 (erano 34), forma gli stessi gruppi dei curatori in 36 studi su 47 e ritrova 68 confronti su 95 contro i 13 della pipeline di oggi, con due corse identiche; restano errori di lettura del modello in 4 studi (gruppi sbagliati in 3), quindi la regola di esito depositata dà no per il solo punto 4 e decide il PI."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-11T23:09:19+01:00}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/00-previsioni.md", title: "Cancelli K1-K5, previsioni E1-E15, regola di esito a cinque punti e attese per i 13 studi, depositati prima di ogni corsa sui testi degli studi (commit eae86a4)"}
- {id: grandezza, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/11-grandezza-schema.csv", title: "Grandezza dello schema generato per ognuno dei 47 studi (misura senza modello)"}
- {id: compila, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/12-out.txt", title: "Prova di compilazione dello schema con un messaggio neutro: tre forme, due scartate"}
- {id: paragone, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/15-out.txt", title: "Riferimento con la regola del contesto (95 confronti), controllo positivo (K2 i), riproduzione di S12r2 (K1), pipeline di oggi e lettore v1 nelle quattro misure"}
- {id: corse, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/23-out.txt", title: "Registro delle due corse su poddgx02 (K4)"}
- {id: misura, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-out.txt", title: "Misura delle due corse nelle quattro misure, previsioni E1-E15, regola di esito punti 1, 2, 3 e 5"}
- {id: fattori, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-M-fattori.csv", title: "I fattori scritti dal lettore con lo schema nuovo, uno per riga"}
- {id: fattoriv1, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/24-M-fattori.csv", title: "I fattori scritti dal lettore con lo schema v1 (S12r2), uno per riga"}
- {id: nonelencati, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-M-non-elencati.csv", title: "I confronti del lettore che Atlas non elenca, con il giudizio"}
- {id: disaccordi, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-disaccordi.md", title: "Lettura di tutti i 40 disaccordi, con la causa e chi la può togliere (audit interno)"}
- {id: conti, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-out.txt", title: "Conti delle unità di disaccordo per causa ed esito, E12, che cosa è cambiato, regola di esito punto 4"}
- {id: righe, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-disaccordi-M-righe.csv", title: "Una riga per unità di disaccordo"}
- {id: sens, resource: "analysis/audit/2026-11-11-S12r3-elenco-chiuso/27-out.txt", title: "Sensibilità sulle due forme che lo schema non lega, dichiarata dopo i numeri"}
- {id: spec, resource: "docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md", title: "Disegno del lettore dello studio; blocco «Aggiornamento 2026-11-11 (S12r3)» nel §5.2, riferimento §5.5, regola di esito §5.6"}
- {id: adr29, resource: "docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md", title: "ADR-0029 e aggiornamento del 2026-11-11 (confronto fra due contesti)"}
- {id: s12r2, resource: "docs/findings/2026-11-10-S12r2-prova-ripetuta-lettore-studio.md", title: "La prova ripetuta del lettore con lo schema v1 (S12r2)"}
---

# In breve

## In breve: con la forma dell'uscita costruita per ogni studio, il lettore chiude gli studi e scrive i fattori senza errori?

**A cosa serviva.** Il lettore dello studio è un solo passo del modello: legge uno studio e scrive la tabella dei suoi fattori. Poi un programma senza modello forma i confronti.

Nella prova precedente 13 studi su 47 non davano nessun confronto, perché la tabella del modello non copriva tutti i campioni. Per questa prova un programma ha costruito per ogni studio la forma dell'uscita, con le sole colonne e i soli valori che esistono. Abbiamo ripetuto la prova sugli stessi 47 studi, contro i confronti scritti dai curatori di Expression Atlas. Il risultato serve a decidere se scriviamo il piano che mette il lettore nella pipeline.

**Cosa abbiamo trovato.**

1. **Con la forma nuova il lettore ritrova 68 dei 95 confronti dei curatori. Con la forma precedente ne ritrovava 50, e la pipeline di oggi ne ritrova 13.** Il lettore forma gli stessi gruppi dei curatori in 36 studi su 47, la pipeline di oggi in 14. Due corse del lettore danno uscite uguali al carattere in 47 studi su 47. Il riferimento ha 95 confronti e non 97, perché due confronti fra tipi cellulari sono usciti con la regola che hai deciso.
2. **Gli studi che non danno nessun confronto scendono da 13 a 2, sotto la soglia di 7 scritta prima.** In tutti e due il modello scrive il nome di un livello in un modo che la forma dell'uscita non controlla. La correzione sta nella forma dell'uscita e ha un nome. Un calcolo fatto dopo i numeri dice che con la correzione chiudono 47 studi su 47, e i confronti ritrovati diventano 71 su 95.
3. **Abbiamo letto tutti i 40 disaccordi: 13 sono errori di lettura del modello, in 4 studi. In 3 di questi studi i gruppi sono sbagliati.** Altri 21 disaccordi restano anche con un lettore senza errori, perché nascono da scelte o errori dei curatori. Altri 6 nascono dalla forma dell'uscita. In uno studio (GSE57945) il modello scrive il sesso come fattore, e forma 14 gruppi dove i curatori ne hanno 7. In uno (GSE46665) scrive le sigle dei 9 pazienti come malattie. In uno (GSE60340) non vede la colonna del trattamento, e unisce tre trattamenti in un gruppo. Nel quarto (GSE49155) i gruppi sono giusti, ma un secondo fattore ripete il primo. Per questi errori il lettore perde 10 confronti dei curatori.
4. **Tre di questi 4 errori non c'erano nelle tabelle scritte con la forma precedente, e gli errori di lettura della prova precedente sono spariti.** Quindi l'errore di lettura cambia con la forma dell'uscita. Non sappiamo ancora dove nasce ogni errore: nel modello, nella forma dell'uscita o nel testo che il modello riceve.
5. **La regola scritta prima della prova dà «no», per una sola condizione su cinque.** Il lettore è ripetibile, fa meglio di oggi nelle tre misure e chiude abbastanza studi. L'ultima condizione chiede che ogni errore del lettore abbia un rimedio con un nome, nella forma dell'uscita o nel testo. Per gli errori di lettura questo rimedio non c'è. Prima delle corse avevo scritto che mi aspettavo questo esito.

**Cosa devi decidere.**

1. **Scriviamo adesso il piano che mette il lettore nella pipeline? Raccomando di no: prima una sessione breve che cerca dove nasce ogni errore di lettura.** I motivi sono tre. La regola scritta prima dà «no». Hai deciso che nessun errore si accetta e che ogni causa si corregge. Tre errori su quattro sono comparsi con la forma nuova, quindi la causa può stare nella forma e non nel modello. La sessione confronta, per ognuno dei 4 studi, la tabella scritta con le due forme, e cambia una cosa per volta. Non cambia il prompt per coprire un errore, e non aggiunge regole che fanno il lavoro del modello. Il limite: i 47 studi servono una quarta volta, quindi cresce il rischio che il lettore sia adattato a questi studi. Solo gli 82 studi mai aperti misurano questo rischio. Un secondo limite: la sessione può dire che la causa sta nel modello. In quel caso torno da te con il conto degli errori e con le opzioni. Le alternative:
   - Scrivere il piano adesso, con la ricerca delle cause come primo passo del piano. Conseguenza: scriviamo il piano e il suo cancello prima di sapere se la forma dell'uscita cambia ancora. Se cambia, il piano si riscrive.
   - Scrivere il piano adesso con il lettore com'è, e dichiarare gli errori di lettura come limite. Conseguenza: questa strada va contro la tua regola che nessun errore si accetta. In questi 47 studi il lettore forma gruppi sbagliati in 3 studi.
   - Fermare il lettore e tenere la pipeline di oggi. Conseguenza: restano 13 confronti ritrovati su 95, contro i 68 del lettore.

**Comunque.** Le due correzioni alla forma dell'uscita entrano nel passo seguente, qualunque sia. Gli 82 studi del giudizio restano chiusi. Il deliverable e i master non cambiano. Il lettore non entra nella pipeline prima della tua decisione.

Appena decidi questo punto, la sessione è chiusa.

**Sui tempi di calcolo.** La stima è dell'agente. In questa sessione una corsa del lettore sui 47 studi è durata 4 minuti e 9 secondi, su 4 GPU. La sessione sulle cause chiede poche corse come questa, quindi meno di un'ora di calcolo.

---

# 1. Che cosa è stato fatto

Sessione S12r3 dell'handout `2026-11-07-HANDOUT-PIANO-RIVISTO.md`, branch `p6-tabella-dei-fattori`, un solo agente.
Una sola configurazione, **M** = `mistralai/Mistral-Small-3.2-24B-Instruct-2506` (revisione `95a6d26c…`) con
`repetition_penalty` 1,1, due corse. «Schema nuovo» o «v2» = lo schema JSON delle uscite generato per ogni studio a
elenco chiuso; «schema v1» = lo schema unico di S12r2. «Oggi» = la pipeline di oggi, cioè il master S14 dello Stadio 2
portato alla stessa misura con `tf_da_stage2()`.

| passo dell'handout | che cosa | commit |
|---|---|---|
| 2. Misura senza modello | generatore dello schema (`10-schema-per-studio.R`), grandezza sui 47 studi[^grandezza], prova di compilazione con un messaggio neutro (tre forme, due scartate)[^compila]; runner vLLM con uno schema per record | `c46ae38`, `e431165` |
| 1. Carta | spec §5.2 (blocco «Aggiornamento 2026-11-11 (S12r3)», 8 punti) e §5.5; ADR-0029: decisione del PI sul confronto fra due contesti[^spec][^adr29] | `8d7912d` |
| 3. Termini di paragone | marca `solo_contesto` e parametro `contesto_fuori` nel pacchetto (TDD); riferimento a 95 confronti, controllo positivo, riproduzione di S12r2, oggi e lettore v1 nelle quattro misure[^paragone] | `fc2e9bf`, `df4e330` |
| 3. Deposito | cancelli, previsioni, regola di esito, attese per i 13 studi[^previsioni] | `eae86a4` |
| 4. Codice da buttare | prompt v2, adattatore v2 (controllo positivo passato), script di lancio | `6a00e1e` |
| 5. Corse | due corse su `poddgx02`, congelate con SHA-256 prima di ogni misura[^corse]; script di misura e di lettura scritti prima | `c8ac545` |
| 6. Misura e lettura | misura nelle quattro misure[^misura]; lettura di tutti i 40 disaccordi[^disaccordi][^conti]; sensibilità dichiarata dopo i numeri[^sens] | `91dd28e`, `7389804` |

L'ordine dei primi due passi è invertito rispetto all'handout: la prova di compilazione ha scartato due forme dello
schema, e la carta descrive la terza, quella che compila (§10). Carta e deposito precedono ogni corsa sui testi
degli studi.

Ingresso: `analysis/input/S12r3-lettore-v2-ingresso.jsonl`, 47 studi, SHA-256 `36285df3…`. La vista è la vista v0,
senza cambi (i 47 testi sono uguali alle viste, controllato per ogni corsa). Cambiano lo schema, uno per studio, e il
prompt.[^corse]

**Decisione del PI presa durante la sessione (2026-11-11), prima del deposito.** Un fattore di contesto (tipo
cellulare, linea cellulare, tessuto) non ha livello di base: la regola del costruttore resta. I confronti di Atlas in
cui cambia solo `cell type`, `cell line` o `organism part` escono dal riferimento, con una regola scritta prima e per
costruzione; la misura sul riferimento a 97 confronti si riporta accanto. La regola toglie 2 confronti, tutti e due
di `GSE75852` (cellule staminali neurali contro cellule staminali pluripotenti indotte, nei sani e nei
malati).[^paragone]

# 2. Cancelli

| cancello | esito | dove |
|---|---|---|
| K1. Riproduzione prima del cambio | **passato** prima del deposito: il codice aggiornato, senza la regola del contesto, ridà studio per studio oggi 14/47 e 13/97, lettore v1 34 chiusi, 31/47, 50/97, 0/4 | `15-out.txt` r.110-112 |
| K2. Controllo positivo | **passato**: (i) Atlas contro Atlas 47/47 nelle quattro misure, ritrovati 95/95, 97/97, 93/93, 84/84; la marca `solo_contesto` vede `GSE75852`; (ii) l'adattatore v2 legge lo studio finto `GSE0` (6 gruppi, 7 confronti) e ogni motivo di «non chiuso» si vede con un'uscita rotta apposta | `15-out.txt` r.13-17, r.28; `24-out.txt` r.12 |
| K3. Copertura | **passato**: le due corse coprono 47 studi su 47 | `24-out.txt` r.15 |
| K4. Le corse | **passato**: `poddgx02`; `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` letti da `container-env.txt`; prompt uguale al file committato; 47 schemi uguali a quelli del generatore; 47 testi uguali alle viste; 20 file di uscita congelati prima di ogni misura | `23-out.txt` r.6-20; `24-out.txt` r.13-14 |
| K5. Giudizio chiuso | **passato**: gli script leggono solo i 47 studi di sviluppo (`solo_sviluppo()` ferma il resto) | `23-lancia.R`, `aiuti-misura-r3.R` |

# 3. Le misure e le previsioni

## 3.1 Il riferimento nelle quattro misure

| misura | che cosa è | confronti | decide? |
|---|---|---|---|
| **principale** | Atlas senza il tempo zero come controllo (S12r2) e senza i confronti di solo contesto (decisione del 2026-11-11) | **95** | sì |
| principale97 | la misura principale di S12r2: Atlas senza il tempo zero come controllo | 97 | no, si riporta accanto |
| intera | tutti i confronti di Atlas che rispettano la definizione, col tempo zero | 93 | no |
| stretta | la principale senza i confronti che differiscono in un fattore annidato | 84 | no |

Nei 95 confronti il fattore che cambia è: `disease` 47, `compound` 8, `phenotype` 8, `treatment` 8, `genotype` 7,
`RNA interference` 7, `clinical information` 3, `infect` 3, `biopsy site` 2, `disease staging` 1,
`growth condition` 1.[^paragone] `GSE50760` (`biopsy site`) e `GSE65335` (`growth condition`) restano nel
riferimento: la regola del contesto nomina tre fattori di Atlas e nessun altro.

Lo schema generato: campioni per studio 3 / 14 / 322 (minimo / mediana / massimo), colonne ammesse 1 / 4 / 12, voci
totali 3 / 26 / 797, grandezza dello schema 3.228 / 9.755 / 222.556 caratteri (massimo `GSE57945`).[^grandezza]
Nessuno schema è tagliato. Token del prompt: mediana 2.246, massimo 31.373; token dell'uscita: mediana 641, massimo
2.895; fine `stop` 47 su 47.[^corse]

## 3.2 Le misure, misura principale

Unità = lo studio; bootstrap sugli studi, B = 2.000, seme 20261111; le differenze sono appaiate sugli studi.
(a) = studi con gli stessi gruppi di Atlas; (b) = confronti di Atlas ritrovati; (c) = errori fra i confronti del
lettore che Atlas non elenca e che si possono giudicare.[^misura][^paragone]

| | lettore, schema nuovo | lettore, schema v1 | oggi |
|---|---|---|---|
| studi chiusi | **45 / 47** | 34 / 47 | (non si applica) |
| (a) gruppi identici | **36 / 47 = 76,6%** (63,8-87,2) | 31 / 47 = 66,0% | 14 / 47 = 29,8% |
| (b) confronti ritrovati | **68 / 95 = 71,6%** (54,8-85,5) | 50 / 95 = 52,6% | 13 / 95 = 13,7% |
| (c) errori fra i non elencati | **2 / 33 = 6,1%** (0-33,3) | 0 / 4 | 18 / 79 = 22,8% |

| differenza appaiata | (a) | (b) | (c) |
|---|---|---|---|
| schema nuovo meno oggi | +46,8 punti (+31,9, +61,7) | **+57,9 punti (+40,0, +73,2)** | −16,7 punti (−31,3, +8,9) |
| schema nuovo meno schema v1 | +10,6 punti (0,0, +21,3) | +18,9 punti (+2,6, +34,7) | +6,1 punti (0, +33,3; 227 ricampioni senza valore) |

Uscite identiche al carattere fra le due corse: 47 su 47. Il lettore forma 125 confronti in 38 studi. Classi di
partizione: identica 36, più fine 7, più grossa 1, incrociata 1, non chiuso 2. Nessun confronto ritrovato ha il verso
opposto.[^misura]

**I 49 confronti del lettore che Atlas non elenca.** Giudizio: coerente 30, fuori dall'universo di Atlas 16,
braccio misto 1 (`GSE50760`), più fattori 1 (`GSE56787`), nessuna differenza 1 (`GSE93624`, 27 contro 182
campioni). Giudicabili 33, in 7 studi: `GSE57945` 18, `GSE83687` 6, `GSE103501` 2, `GSE50760` 2, `GSE69597` 2,
`GSE93624` 2, `GSE56787` 1. I 16 fuori dall'universo: 10 in `GSE147507`, 3 in `GSE56787`, 1 in `GSE52946`,
`GSE57116`, `GSE68919`.[^nonelencati] I 2 errori contati dalla misura non sono errori del lettore (§3.6).

**Tabella degli stati, schema v1 in riga e schema nuovo in colonna.**[^misura]

| schema v1 ↓ / schema nuovo → | non chiuso | identica | diversa |
|---|---|---|---|
| non chiuso (13) | 1 | 6 | 6 |
| identica (31) | 1 | 30 | 0 |
| diversa (3) | 0 | 0 | 3 |

## 3.3 Le misure che non decidono

| misura | (b) schema nuovo | (b) meno oggi | (b) meno v1 | (c) schema nuovo |
|---|---|---|---|---|
| principale97 | 68 / 97 = 70,1% (53,8-83,8) | +56,7 (+38,8, +71,6) | +18,6 (+2,6, +34,1) | 2 / 33 |
| intera | 60 / 93 = 64,5% (48,1-78,7) | +44,1 (+17,5, +65,2) | +10,8 (−1,4, +25,3) | 13 / 33 = 39,4% (5,9-62,5) |
| stretta | 62 / 84 = 73,8% (56,6-88,2) | +59,5 (+39,7, +75,3) | +19,0 (+1,3, +36,6) | 2 / 33 |

Nella misura intera il tempo zero vale come controllo e un fattore annidato conta come una differenza ordinaria. I
13 errori di quella misura sono: `GSE57945` 9, `GSE69597` 2, `GSE50760` 1, `GSE56787` 1. Nella misura intera la
differenza col v1 ha un intervallo che contiene lo 0; nella principale e nelle altre due no.[^misura]

## 3.4 La forma delle uscite

Motivi di «non chiuso» (uno studio può averne più di uno): `livello_assente` 2, `base_assente` 1; `oltre_contesto`,
`troncata`, `non_valida`, `base_non_ammessa`, `livello_riservato`, `ruolo_incoerente`, `tf_tabella` 0.[^misura]

- `GSE50499`: il fattore `mov10` dichiara i livelli `knockdown` e `overexpression`, ma una voce e la base scrivono
  `control`, che non è nell'elenco dei livelli.
- `GSE63816`: tre fattori (`disease`, `genotype`, `knockdown`) scrivono il livello riservato «not applicable» come
  `not_applicable`, con il trattino basso.

Lo schema v2 lega le colonne e i valori, non il nome del livello: nelle voci e nella base il livello è una stringa
libera, non legata all'elenco `levels` dello stesso fattore né ai due nomi riservati. È il solo punto in cui
l'uscita può ancora contraddire se stessa.

Altre letture della forma: voci scritte 387; «not applicable» assegnato in 7 studi, «not stated» in 0; basi scritte
senza campioni 0; un fattore con un livello per campione in 1 studio (`GSE67812`: `disease_state` letto da `title`,
3 campioni tutti «control», un gruppo come Atlas: non è un errore); nota `soggetto_valori_mancanti` in 1
studio.[^misura]

## 3.5 Le previsioni con l'esito

| | quantità | atteso | rilevanza | misurato | esito |
|---|---|---|---|---|---|
| E1 | studi non chiusi | 2 | 0-7 | 2 | confermata |
| E2 | non chiusi per un'uscita finita che non rispetta lo schema dello studio | 0 | 0 | 0 | confermata |
| E3 | uscite troncate | 0 | 0-1 | 0 | confermata |
| E4 | studi fermi per `ruolo_incoerente` | 1 | 0-2 | 0 | confermata |
| E5 | uscite identiche fra le due corse | 47 | 47 | 47 | confermata |
| E6 | (a) partizione identica | 77% | 50-100% | 76,6% (63,8-87,2) | confermata |
| E7 | schema nuovo meno v1, (a) | +10,6 punti | intervallo sopra 0 | +10,6 (0,0, +21,3) | **indeterminata** |
| E8 | lettore meno oggi, (b) | +52 punti | intervallo sopra 0 | +57,9 (+40,0, +73,2) | confermata |
| E9 | schema nuovo meno v1, (b) | +13 punti | intervallo sopra 0 | +18,9 (+2,6, +34,7) | confermata |
| E10 | (c) errori fra i non elencati | 5% | 0-10% | 6,1% (0-33,3) | **indeterminata** |
| E11 | dei 13 non chiusi col v1, quanti chiudono | 13 | 10-13 | 12 | confermata |
| E12 | dei 13, quanti chiudono con gruppi sbagliati per una causa del lettore | 3 (`GSE46665`, `GSE56787`, `GSE147507`) | 0 | 3 (`GSE46665`, `GSE57945`, `GSE60340`) | **smentita** (l'agente lo aveva scritto) |
| E13 | regressioni | 1 | 0-2 | 1 (`GSE50499`) | confermata |
| E14 | studi con un fattore con un livello per campione | 2 | 0-2 | 1 (`GSE67812`) | confermata |
| E15 | studi con una base scritta senza campioni | 2 | 0-2 | 0 | confermata |

Attese per i 13 studi, una per studio: giuste 8 su 13 (solo lo stato: 10 su 13). Sbagliate: `GSE147507` (attesa
diversa con gruppi sbagliati, osservata identica), `GSE56787` (i gruppi diversi non sono un errore del lettore),
`GSE57116` (attesi confronti non ritrovati, osservati 2 su 2), `GSE63816` (attesa diversa, osservato non chiuso),
`GSE83687` (attesa identica, osservata diversa).[^conti]

## 3.6 I dubbi aperti dalle previsioni e dalla lettura, e come sono chiusi

1. **E7 indeterminata — spiegata.** L'intervallo della differenza in (a) fra schema nuovo e v1 tocca lo 0. Il
   guadagno netto è di 5 studi: 6 passano da non chiuso a identica, 1 (`GSE50499`) da identica a non chiuso. Su 47
   studi la prova non mostra oltre il caso che l'elenco chiuso migliora i gruppi; lo mostra per i confronti (E9).
   Non tocca la regola di esito, che usa «lettore meno oggi».
2. **E10 indeterminata — spiegata.** I giudicabili sono 33 in 7 studi, 18 in uno solo: l'intervallo arriva al 33%.
   I 2 errori sono stati letti. `GSE50760`: il lettore forma 18 / 18 / 18 campioni come GEO, Atlas 19 normali e 17
   metastasi; il braccio «misto» nasce da un campione che Atlas mette nel gruppo sbagliato. `GSE56787`: Atlas
   scrive la stessa differenza come `disease` e come `genotype`, e la misura la conta come due fattori. Nessuno dei
   due è un errore del lettore.[^disaccordi]
3. **E12 smentita — è la decisione del PI** (§6). Tre studi chiudono con gruppi sbagliati per lettura del modello.
4. **Regressione `GSE50499` (1 → 0 confronti ritrovati) — spiegata, con un rimedio nominato.** È la forma del
   livello non dichiarato (§3.4); con la tolleranza della sensibilità lo studio torna identico e ritrova 1 su 1
   (§4).
5. **Perdita `GSE49155` (2 → 0 confronti ritrovati, partizione identica nelle due prove) — è un errore di lettura
   del modello, senza rimedio nominato** (§5.3).
6. **`GSE65335`, un confronto non ritrovato per la regola del costruttore — spiegato, e rinviato per la parte di
   disegno.** Atlas confronta la coltura all'interfaccia aria-liquido (giorno 14) contro la coltura sommersa
   (giorno 8). Il lettore scrive `growth_condition` come fattore di contesto, che per la regola decisa dal PI non ha
   livello di base. Il fattore di Atlas si chiama `growth condition`, che non è uno dei tre nomi della regola del
   riferimento: il confronto resta nel riferimento e conta contro il lettore. La regola non si cambia dopo i numeri.
   Chi scrive il cancello sugli 82 studi decide prima, e per costruzione, se la regola del riferimento segue i nomi
   di Atlas o il tipo del fattore (rinvio nell'handout).
7. **Due sottoclassi di causa aggiunte dopo la lettura — dichiarate.** La bozza della tabella delle cause, scritta
   prima delle uscite, non aveva `schema/livello_non_dichiarato` e `schema/riservato_altra_forma`. Sono le due forme
   del §3.4. La regola di esito non cambia, e senza le due sottoclassi il punto 4 resta no.
8. **`GSE147507` identica — spiegata, con un limite.** La vista porta 77 campioni, Atlas 14. Il modello ha letto
   ogni variabile da una colonna e ha scritto «not applicable» per le celle vuote: i gruppi sono identici sui
   campioni comuni e i 2 confronti si ritrovano. Gli altri 10 confronti dello studio stanno fuori dall'universo di
   Atlas e la prova non li giudica.

# 4. La sensibilità (dichiarata dopo i numeri, non una misura)

Due tolleranze applicate alle uscite congelate, senza una corsa nuova del modello. **T1**: un nome riservato scritto
in un'altra forma (`not_applicable`) vale il nome riservato. **T2**: un livello scritto in una voce e non dichiarato
entra nell'elenco dei livelli. Controllo positivo: senza tolleranze lo script ridà la misura. Uscite toccate: 2 su 47
(`GSE50499` con T2, `GSE63816` con T1 in tre fattori).[^sens]

| | misura | con le due tolleranze |
|---|---|---|
| studi chiusi | 45 / 47 | 47 / 47 |
| (a) gruppi identici | 36 / 47 = 76,6% | 37 / 47 = 78,7% (66,0-89,4) |
| (b) confronti ritrovati, principale | 68 / 95 = 71,6% | 71 / 95 = 74,7% (59,2-87,8) |
| (b) principale97 | 68 / 97 | 71 / 97 = 73,2% |
| (b) intera | 60 / 93 | 63 / 93 = 67,7% |
| (b) stretta | 62 / 84 | 63 / 84 = 75,0% |
| (c) errori fra i non elencati | 2 / 33 | 2 / 34 |

`GSE50499` diventa identica e ritrova 1 confronto su 1. `GSE63816` diventa più fine (5 gruppi contro 4) e ritrova 2
confronti su 3, senza errori. Questi numeri dicono quanto vale il rimedio nominato **se** funziona come la
tolleranza: non sono una corsa del modello con lo schema corretto.

# 5. Le cause

La lettura l'ha fatta l'agente sui metadati di GEO e sul materiale di ogni studio (`25-materiale-M.txt`). È audit
interno, non è cieca e non entra nell'articolo. Ogni unità ha una prima causa, il resto della catena e chi può
togliere la causa.[^disaccordi][^righe]

## 5.1 Le unità di disaccordo

40 unità in 15 studi su 47: studio non chiuso 2, partizione non identica 9, confronto di Atlas non ritrovato 27,
confronto del lettore contato come errore 2. In S12r2 le unità erano 63.[^conti]

## 5.2 Prima causa ed esito della catena

| prima causa | totale | non chiuso | partizione | non ritrovato | errore |
|---|---|---|---|---|---|
| curatore / fattore ignorato | 8 | 0 | 2 | 6 | 0 |
| curatore / errore di campione | 5 | 0 | 2 | 2 | 1 |
| curatore / livelli uniti | 2 | 0 | 1 | 1 | 0 |
| curatore / repliche | 2 | 0 | 1 | 1 | 0 |
| curatore / riferimento | 2 | 0 | 0 | 2 | 0 |
| strumento / fattori ridondanti | 1 | 0 | 0 | 0 | 1 |
| schema / riservato in altra forma | 4 | 1 | 0 | 3 | 0 |
| schema / livello non dichiarato | 2 | 1 | 0 | 1 | 0 |
| schema / contesto senza base | 1 | 0 | 0 | 1 | 0 |
| modello / ruolo di soggetto | 10 | 0 | 2 | 8 | 0 |
| modello / fattore doppio | 2 | 0 | 0 | 2 | 0 |
| modello / fattore non visto | 1 | 0 | 1 | 0 | 0 |
| **totale** | **40** | 2 | 9 | 27 | 2 |

| esito della catena | totale | non chiuso | partizione | non ritrovato | errore |
|---|---|---|---|---|---|
| non errore (resta anche con un lettore senza errori) | **21** | 0 | 6 | 13 | 2 |
| vista o schema | **6** | 2 | 0 | 4 | 0 |
| lettura del modello | **13** | 0 | 3 | 10 | 0 |

Dei 21 «non errore», 19 hanno i curatori come prima causa, 1 lo strumento, 1 lo schema con il resto ai curatori
(`GSE63816`, confronto g4_g1: anche a studio chiuso Atlas confronta due gruppi che differiscono in due fattori
veri). Dei 6 «vista o schema», 5 stanno nei due studi non chiusi e hanno un rimedio nominato; 1 è `GSE65335`, il cui
rimedio nominato è «nessuno: è la regola del costruttore decisa dal PI» (§3.6, punto 6). Le unità con una causa di
lettura del modello in un punto qualsiasi della catena sono 21, in 7 studi: le 13 con esito «modello», 7 «non
errore» con una lettura del modello in più (`GSE50760`, `GSE60340`, `GSE71595`), 1 «vista o schema»
(`GSE63816`).[^conti]

## 5.3 Gli errori di lettura del modello, studio per studio

| studio | che cosa scrive il modello | che cosa produce | con lo schema v1 |
|---|---|---|---|
| `GSE57945` | la colonna `Sex` come fattore di contesto (`female`, `male`), accanto a `disease`, `inflammation`, `deep_ulcer` | 14 gruppi contro i 7 di Atlas; 18 confronti coerenti, ognuno dentro un sesso; 0 confronti di Atlas ritrovati su 6; 7 unità | il fattore `sex` non c'era; lo studio non chiudeva |
| `GSE46665` | un fattore «disease» da `source_name_ch1` con 9 livelli, che sono le sigle dei 9 pazienti; un fattore `time` da `description` | 25 gruppi contro 3; 0 confronti formati; 0 su 2 ritrovati; 3 unità | lo stesso fattore «disease» a 9 livelli, letto da `description`; lo studio non chiudeva |
| `GSE60340` | un solo fattore da `sample group` (6 livelli); la colonna `treated with` giudicata non informativa | 5-aza, Adriamycin e H2O2 in un gruppo solo di 9 campioni; 6 gruppi contro 8; 0 confronti formati; 1 unità (i 2 confronti di Atlas non ritrovati hanno come prima causa il riferimento scelto dai curatori) | due fattori: `senescence_type` da `sample group` e `treatment` da `treated with` (5 livelli); lo studio non chiudeva |
| `GSE49155` | `pathology` (base `normal`) scritto bene; in più il contesto `cell_type` dalla colonna `cell type`, con la cella vuota scritta come `premalignant_lesion` | partizione identica; ogni confronto differisce in due fattori: 0 su 2 ritrovati; 2 unità | `cell_type` c'era con un solo livello dichiarato; partizione identica e 2 su 2 ritrovati |

Fonti: `26-disaccordi.md`, `24-M-fattori.csv` delle due sessioni.[^disaccordi][^fattori][^fattoriv1]

**Che cosa si vede, e che cosa non si sa.** In tre studi su quattro il fattore sbagliato non c'era nella tabella
scritta con lo schema v1 (`GSE57945`, `GSE60340`) o non faceva danno (`GSE49155`). Nella direzione opposta, le 5
unità di lettura del modello di S12r2 (`GSE57116`, `GSE75852`) non ci sono più: con lo schema nuovo i due studi
ritrovano 2 confronti su 2. L'errore di lettura quindi si sposta con la forma dell'uscita. Tre parti dello schema
nuovo sono candidate, e **nessuna è misurata**: la tupla `columns` chiede un ruolo per ogni colonna (in `GSE57945`
`Sex` riceve il ruolo `factor`); un fattore legge una sola colonna; la cella vuota è un valore che deve avere un
livello (`GSE49155`). Per `GSE57945` e `GSE60340` lo studio non chiudeva col v1, quindi i gruppi del v1 non si
conoscono: il confronto fra le due forme dice che il fattore è cambiato, non che il v1 leggeva bene. `GSE46665` ha
lo stesso errore con le due forme. Dire dove nasce ogni errore chiede corse che cambiano una cosa per volta: questa
sessione non le ha fatte, perché l'handout chiede lo STOP dopo la misura.

## 5.4 Gli studi con gruppi diversi che non sono errori del lettore

Studi con partizione diversa: 9. Gruppi sbagliati 3, tutti per lettura del modello (§5.3). Gli altri 6:[^conti]

| studio | gruppi lettore / Atlas | perché non è un errore del lettore |
|---|---|---|
| `GSE44379` | gruppi da 1 campione, 0 confronti | il lettore scrive le 8 frazioni come fattore tecnico (dal titolo); Atlas le tratta come repliche |
| `GSE50760` | incrociata | il lettore forma 18 / 18 / 18 come GEO; Atlas 19 normali e 17 metastasi (un campione nel gruppo sbagliato). In più il modello legge `source_name_ch1` come donatore |
| `GSE56787` | 6 / 5 | Atlas mette in «normal; myotube» un campione che GEO chiama «Control myoblasts» |
| `GSE69597` | 8 / 7 | Atlas unisce la brucellosi cronica sotto e sopra i 10 anni; 5 confronti su 6 ritrovati |
| `GSE83687` | 25 / 3 | il lettore scrive i 14 siti di biopsia (`source_name_ch1`), Atlas li ignora; 6 confronti coerenti dentro un sito, 0 su 2 ritrovati |
| `GSE93624` | più fine | il lettore scrive `progression to complication` (27 «yes»), Atlas la ignora; 0 su 1 ritrovati |

Questi giudizi favoriscono il lettore e la lettura non è cieca (§9).

## 5.5 Che cosa è cambiato rispetto a S12r2, studio per studio

Confronti di Atlas ritrovati sul riferimento a 95: con lo schema v1 → con lo schema nuovo (fra parentesi oggi, dove
è diverso da 0).[^conti][^misura]

| insieme in S12r2 | studio | stato v1 → nuovo | ritrovati v1 → nuovo | nota |
|---|---|---|---|---|
| 13 non chiusi | `GSE147507` | non chiuso → identica | 0/2 → 2/2 (oggi 1/2) | sui campioni comuni; 10 confronti fuori dall'universo di Atlas |
| | `GSE46665` | non chiuso → diversa | 0/2 → 0/2 | gruppi sbagliati, lettura del modello |
| | `GSE56787` | non chiuso → diversa | 0/0 | non errore (campione di Atlas) |
| | `GSE57116` | non chiuso → identica | 0/2 → 2/2 | |
| | `GSE57945` | non chiuso → diversa | 0/6 → 0/6 | gruppi sbagliati, lettura del modello |
| | `GSE59781` | non chiuso → identica | 0/1 → 1/1 (oggi 1/1) | |
| | `GSE60340` | non chiuso → diversa | 0/2 → 0/2 | gruppi sbagliati, lettura del modello |
| | `GSE63816` | non chiuso → non chiuso | 0/3 → 0/3 | forma del livello riservato; con la tolleranza 2/3 |
| | `GSE66207` | non chiuso → identica | 0/3 → 3/3 | |
| | `GSE69597` | non chiuso → diversa | 0/6 → 5/6 | non errore (livelli uniti da Atlas) |
| | `GSE71595` | non chiuso → identica | 0/4 → 2/4 (oggi 1/4) | i 2 confronti di malattia: fattore ignorato da Atlas, più una lettura del modello |
| | `GSE83415` | non chiuso → identica | 0/1 → 1/1 | |
| | `GSE83687` | non chiuso → diversa | 0/2 → 0/2 | non errore (siti di biopsia) |
| 3 partizione non identica | `GSE44379` | diversa → diversa | 0/1 → 0/1 | non errore |
| | `GSE50760` | diversa → diversa | 0/2 → 0/2 | non errore |
| | `GSE93624` | diversa → diversa | 0/1 → 0/1 | non errore |
| 4 soli confronti non ritrovati | `GSE112057` | identica → identica | 0/5 → 5/5 (oggi 1/5) | in S12r2 la stringa «NA» non dichiarata |
| | `GSE65335` | identica → identica | 1/2 → 1/2 | contesto senza base |
| | `GSE75852` | identica → identica | 2/2 → 2/2 (oggi 1/2) | i 2 confronti di solo contesto sono fuori dal riferimento |
| | `GSE77598` | identica → identica | 0/1 → 0/1 | non errore (aplotipo che coincide con la malattia) |
| senza unità in S12r2 | `GSE50499` | identica → non chiuso | 1/1 → 0/1 (oggi 1/1) | regressione: livello non dichiarato |
| | `GSE49155` | identica → identica | 2/2 → 0/2 | fattore doppio, lettura del modello |

Dei 13 studi non chiusi: 6 diventano identici, 6 diversi (3 con gruppi sbagliati, 3 non errore), 1 resta non
chiuso. Studi con unità in S12r2 e senza unità adesso: 7 (`GSE147507`, `GSE57116`, `GSE59781`, `GSE66207`,
`GSE83415`, `GSE112057`, `GSE75852`).

## 5.6 Chi può togliere le cause

| chi | unità | rimedio nominato | misurato? |
|---|---|---|---|
| nessuno serve (curatori, strumento) | 21 | restano anche con un lettore senza errori | (non si applica) |
| lo schema: livello non dichiarato | 2 | lo schema generato toglie l'elenco separato dei livelli e prende i livelli dalle voci; oppure l'adattatore fa entrare un livello scritto in una voce | no: calcolo della sensibilità (§4) |
| lo schema: nome riservato in altra forma | 3 (+1 non errore) | lo schema scrive i due nomi riservati come valori ammessi di `level`; oppure l'adattatore legge «_» e «-» come spazio | no: calcolo della sensibilità (§4) |
| la regola del costruttore: contesto senza base | 1 | nessuno: regola decisa dal PI | (non si applica) |
| **la lettura del modello** | **13** | **nessuno** | il modello è deciso; in S12r2 il modello più grande non toglieva questi errori |

# 6. La regola di esito, e che cosa dice la prova

La regola depositata dà **sì** solo con tutti e cinque i punti.[^previsioni]

| punto | che cosa chiede | misurato | esito |
|---|---|---|---|
| 1 | due corse identiche in 47 studi su 47 | 47 su 47 | sì |
| 2 | (b) lettore meno oggi con l'intervallo al 95% sopra 0 | +57,9 punti (+40,0, +73,2) | sì |
| 3 | meglio di oggi anche in (a) e in (c), come stima | (a) +46,8 punti; (c) −16,7 punti | sì |
| 4 | ogni disaccordo ha una causa; ogni causa del lettore ha un rimedio nominato nella vista o nello schema; nessuna unità e nessuno studio con gruppi sbagliati per lettura del modello | cause 40 su 40; causa del lettore 19: vista o schema 6, **lettura del modello 13 in 4 studi; gruppi sbagliati per lettura del modello in 3 studi** | **no** |
| 5 | studi non chiusi al massimo 7 | 2 | sì |

**La risposta della regola è no.** È l'esito che l'agente aveva scritto nel deposito: «I punti 1, 2, 3 e 5 sì; il
punto 4 no». Lo stesso deposito dice come si legge: «Un "no" per il solo punto 4 non dice che il lettore è peggiore
di oggi: dice che restano errori di lettura senza rimedio, e il PI vede quanti sono, in quali studi e che cosa
producono». Quanti, dove e che cosa producono sta nel §5.3.

Anche senza gli errori di lettura il punto 4 chiederebbe una nota: una delle 6 unità «vista o schema» (`GSE65335`)
ha come rimedio nominato «nessuno», perché nasce dalla regola del costruttore decisa dal PI.

**Che cosa la prova dice.** Lo schema a elenco chiuso fa ciò per cui è stato disegnato: gli studi non chiusi passano
da 13 a 2, e i due che restano hanno una causa di forma con un rimedio che ha un nome. Il lettore fa meglio di oggi
nelle tre misure e meglio del v1 nei confronti ritrovati. **Che cosa la prova non dice.** Non dice che gli errori di
lettura hanno un rimedio, e non dice dove nascono. Non dice che questi numeri valgono fuori dai 47 studi: è la terza
lettura degli stessi studi, con uno schema disegnato conoscendo i 13 che non chiudevano.

**La decisione è del PI:** se si scrive il Piano 2. Le opzioni e la raccomandazione dell'agente stanno nel «In
breve». L'agente non propone correzioni al prompt né regole che sostituiscono il modello per coprire i quattro
studi: prima va trovato dove nasce ogni errore.

# 7. Misure portate al passo seguente

- **Le due forme che lo schema non lega** (§3.4): 2 studi non chiusi, 5 unità. Rimedio nominato, non misurato come
  corsa.
- **Gli errori di lettura** (§5.3): 13 unità in 4 studi, 3 studi con gruppi sbagliati. Tre parti dello schema nuovo
  sono candidate come origine, nessuna misurata. Il materiale per il confronto fra le due forme c'è già: le uscite
  congelate di S12r2 e di questa sessione sugli stessi 47 studi.
- **Letture del modello che oggi non costano confronti**: `source_name_ch1` letta come donatore (`GSE50760`), un
  contesto che coincide con la diagnosi (`GSE71595`), un livello sbagliato a studio non chiuso (`GSE63816`:
  `disease` chiama «mutant» tutti i 12 campioni di mielodisplasia, anche i 4 senza mutazione). Sono 8 unità con una lettura del modello
  in più, fuori dalle 13.
- **La regola del riferimento per il contesto** (§3.6, punto 6): per nomi di Atlas o per tipo del fattore.
- **La variabile scritta su più colonne** (`GSE147507`): in questa prova non ha fatto danno; il limite della carta
  resta dichiarato.
- **`country` e `ancestry` come donatore**: annotati nella lettura, non contati.

# 8. Decisioni tecniche dell'agente

1. **Regola di esito a cinque punti**, con la lettura severa del punto 4 scritta prima dei numeri (in S12r2 era
   stata scelta dopo) e con la soglia dei 7 studi non chiusi portata dentro la regola.
2. **Forma 3 dello schema**, dopo due forme scartate nella prova di compilazione con un messaggio neutro (§10): le
   colonne sono una tupla a posizioni fisse; tipo di soggetto e valori mancanti esistono solo per il ruolo
   `subject`.
3. **Un fattore legge una sola colonna**, e **una colonna letta da un fattore non può essere anche soggetto**.
   Sono limiti dichiarati nella carta, non misurati come causa.
4. **Nessuna tolleranza di forma nell'adattatore v2.** Un'uscita troncata non si misura anche se è JSON valido.
5. **`max_tokens` 24.576 e `max_model_len` 65.536**: lo schema più grande è di 222.556 caratteri e nessuno schema
   si taglia.
6. **E2 si conta come motivo `non_valida`** con l'uscita finita (`stop`).
7. **Tabella delle cause in bozza prima delle uscite**; due sottoclassi di schema aggiunte dopo la lettura e
   dichiarate (§3.6, punto 7).
8. **Per uno studio non chiuso il resto della catena è `niente_letto`**: non si giudica una tabella che il
   costruttore non ha potuto usare. Fa eccezione ciò che la sensibilità mostra (`GSE63816`).
9. **Sensibilità dichiarata dopo i numeri** (§4), tenuta fuori dalle misure e dalla regola.
10. **Correzione di `scrivi_r3(NULL)` in `24-misura.R`** prima della misura (dichiarata nel commit `91dd28e`): era
    un errore di scrittura dei file, non tocca i numeri.
11. **Nel pacchetto**: la marca `solo_contesto` e il parametro `contesto_fuori` delle misure contro Atlas (TDD,
    `fc2e9bf`); il campo `schema` per record nel runner vLLM, con il suo test (`c46ae38`). Lo schema, il prompt e
    l'adattatore v2 restano materiale da buttare nella cartella di evidenza.

# 9. Limiti

1. **Terza lettura degli stessi 47 studi.** Lo schema nuovo è stato disegnato conoscendo i 13 studi che non
   chiudevano e le loro cause. I numeri valgono per lo sviluppo: il rischio di adattamento a questi studi cresce a
   ogni prova, e solo gli 82 studi di giudizio lo misurano.
2. **La lettura delle cause l'ha fatta l'agente, e non è cieca.** L'agente conosce il lettore e ne ha scritto lo
   schema. I 19 giudizi «curatore» favoriscono il lettore. Un secondo lettore non c'è stato.
3. **La misura (c) è debole.** 33 confronti giudicabili in 7 studi, 18 in uno solo; e in `GSE57945` i 18 confronti
   sono «coerenti» per la misura mentre i gruppi sono sbagliati per la lettura (divisi per sesso). La misura (c) non
   vede un fattore di troppo quando ogni confronto resta dentro un livello di quel fattore.
4. **La sensibilità è un calcolo dopo i numeri.** I rimedi di schema nominati non sono stati provati con una corsa.
5. **Gli errori di lettura non hanno un rimedio misurato**, e la loro origine non è diagnosticata (§5.3).
6. **Una sola fonte di curazione** (Expression Atlas), che in questi 47 studi sbaglia un campione in 2 studi e
   ignora una colonna di GEO in 4.
7. **Un solo modello e una sola configurazione.** La ripetibilità è misurata con 4 worker da 1 GPU e
   `VLLM_BATCH_INVARIANT=1`.

# 10. Anomalie viste durante il lavoro

1. **Due forme dello schema scartate prima della carta.** Forma 1: l'elenco `other_columns` era una lista aperta, e
   il modello ripeteva le stesse 5 colonne fino a `max_tokens`. Forma 2: `subject_kind` e `missing_values` erano
   liberi per ogni colonna, e 46 record su 48 finivano per `length` a 96 token. Forma 3: fine `stop` 48 su 48, JSON
   valido 47 su 48 con il messaggio neutro (il messaggio non dà nessun testo dello studio). La prova usa un
   messaggio neutro e lo studio finto `GSE0`: nessun testo degli studi è stato mandato al modello prima del
   deposito.[^compila]
2. **`rm -f renv/settings.json` ha cancellato un file tracciato.** In questo branch `renv/settings.json` è
   tracciato; `CLAUDE.md` §5 lo dava come non tracciato (riga corretta in questa sessione). Ripristinato con `git checkout -- renv/settings.json` prima
   del commit `7389804`, che non contiene la cancellazione. Regola per le sessioni seguenti: se il file è
   modificato, `git checkout --`, non `rm`.
3. **Refuso in `26-cause-M.txt`** corretto prima dell'esecuzione dello script di lettura.
4. **La previsione E12 nominava studi sbagliati.** L'agente aveva previsto gruppi sbagliati in `GSE46665`,
   `GSE56787` e `GSE147507`; gli studi sono `GSE46665`, `GSE57945` e `GSE60340`. Il numero è uguale per caso: 1
   studio su 3 è quello previsto.
5. **I server MCP `github` e `playwright` non erano connessi.** Non servivano.

# 11. Da dove vengono i numeri del riassunto

Cartella: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/`.

| frase del riassunto | file e riga | valore letto |
|---|---|---|
| nella prova precedente 13 studi su 47 senza confronti | `15-out.txt` r.68 | `lettore v1: chiusi 34` (47 − 34 = 13) |
| il lettore ritrova 68 dei 95 confronti | `24-out.txt` r.46 | `b_confronti_ritrovati 68 95 0.71579` |
| con la forma precedente 50 | `15-out.txt` r.68 | `lettore v1: … (b) 50/95` |
| la pipeline di oggi 13 | `15-out.txt` r.68 | `oggi: … (b) 13/95` |
| stessi gruppi in 36 studi su 47 | `24-out.txt` r.45 | `a_gruppi_identici 36 47 0.76596` |
| la pipeline di oggi in 14 | `15-out.txt` r.68 | `oggi: (a) 14/47` |
| uscite uguali in 47 studi su 47 | `24-out.txt` r.16 | `uscite identiche al carattere fra le due corse: 47 su 47` |
| 95 e non 97: due confronti fra tipi cellulari usciti | `15-out.txt` r.14-15, r.28 | `denominatore di (b) 95`; `97`; `solo_contesto … 2` |
| da 13 a 2 studi senza confronti | `24-out.txt` r.19 | `chiusi dal lettore: 45 su 47; non chiusi: 2` |
| soglia di 7 scritta prima | `00-previsioni.md` r.127, r.178 | `E1 … 0-7`; `al massimo 7` |
| in tutti e due il nome di un livello | `24-out.txt` r.28-29 | `livello_assente` (`mov10: control`; `not_applicable` in tre fattori) |
| con la correzione 47 su 47 e 71 su 95 | `27-out.txt` r.16, r.27 | `con le tolleranze 47 su 47`; `b_confronti_ritrovati 71 95` |
| 40 disaccordi | `26-out.txt` r.10 | `unita' di disaccordo 40 … in 15 studi su 47` |
| 13 errori di lettura in 4 studi; gruppi sbagliati in 3 | `26-out.txt` r.117, r.54 | `lettura del modello 13, in 4 studi`; `gruppi sbagliati 3 (per lettura del modello 3 …)` |
| 21 restano anche con un lettore senza errori; 6 dalla forma | `26-out.txt` r.43-46 (somme di colonna) | `non_errore` 6+13+2; `vista_schema` 2+4 |
| GSE57945: sesso come fattore, 14 gruppi contro 7 | `24-M-fattori.csv`; `24-out.txt` (tabella dei 13) | `sex contesto Sex`; `piu_fine 14 / 7` |
| GSE46665: sigle dei 9 pazienti come malattie | `24-M-fattori.csv`; `26-disaccordi.md` | `disease … 9 livelli … source_name_ch1` |
| GSE60340: colonna del trattamento non vista, tre trattamenti uniti | `26-disaccordi.md`; `24-M-fattori.csv` | `modello/fattore_non_visto`; un solo fattore da `sample group` |
| GSE49155: gruppi giusti, un secondo fattore ripete il primo | `26-disaccordi-M-righe.csv` | `modello/fattore_doppio`, «La partizione è identica» |
| il lettore perde 10 confronti dei curatori | `26-out.txt` r.45 | `atlas_non_ritrovato 10` (esito modello) |
| tre errori su 4 non c'erano con la forma precedente | `24-M-fattori.csv` di S12r2 e di S12r3 | §5.3, colonna «con lo schema v1» |
| gli errori di lettura della prova precedente sono spariti | `26-out.txt` r.84 | `senza unita' adesso: 7 (… GSE57116 … GSE75852)` |
| «no» per una condizione su cinque | `24-out.txt` r.242; `26-out.txt` r.117 | `(1) … si'; (2) … si'; (3) … si'; (5) … si'`; `punto 4 … -> NO` |
| avevo scritto che mi aspettavo questo esito | `00-previsioni.md` r.184 | `I punti 1, 2, 3 e 5 sì; il punto 4 no` |
| 82 studi mai aperti | `CLAUDE.md` §1 (ADR-0029) | 42 giudizio A + 40 giudizio B |
| una corsa: 4 minuti e 9 secondi, 4 GPU | `23-out.txt` r.8 | `slurm 490530 COMPLETED, durata 00:04:09` |
| meno di un'ora di calcolo (stima) | `23-out.txt` r.8, r.18 | durate misurate 00:04:09 e 00:04:07 |

# 12. Decisioni del PI dopo il riassunto (2026-11-12)

Il riassunto in testa resta come il PI lo ha letto. Dopo la lettura:

- **Decisione 1, decisa come raccomandato (2026-11-12, «ok sessione breve»):** il Piano 2 non si scrive adesso.
  Prima si fa una sessione breve che cerca dove nasce ogni errore di lettura del modello (sessione S12r4
  dell'handout), sugli stessi 47 studi di sviluppo e solo con Mistral-Small 3.2. Le due correzioni di forma dello
  schema (§5.6) entrano in quella sessione. ADR-0029 §Aggiornamento 2026-11-12. La sessione S12r3 è chiusa.

[^previsioni]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/00-previsioni.md`.
[^grandezza]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/11-grandezza-schema.csv`.
[^compila]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/12-out.txt`.
[^paragone]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/15-out.txt`.
[^corse]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/23-out.txt`.
[^misura]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-out.txt`.
[^fattori]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-M-fattori.csv`.
[^fattoriv1]: `analysis/audit/2026-11-10-S12r2-prova-ripetuta/24-M-fattori.csv`.
[^nonelencati]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-M-non-elencati.csv`.
[^disaccordi]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-disaccordi.md`.
[^conti]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-out.txt`.
[^righe]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-disaccordi-M-righe.csv`.
[^sens]: `analysis/audit/2026-11-11-S12r3-elenco-chiuso/27-out.txt`.
[^spec]: `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`.
[^adr29]: `docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md`.
[^s12r2]: `docs/findings/2026-11-10-S12r2-prova-ripetuta-lettore-studio.md`.
