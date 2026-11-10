---
type: Finding
title: "La prova ripetuta del lettore dello studio: schema v1, tre modelli, gli stessi 47 studi contro Expression Atlas"
description: "Con lo schema v1 il lettore con Mistral-Small 3.2 ritrova 50 confronti dei curatori su 97 contro i 13 della pipeline di oggi ed è ripetibile; 13 studi non chiudono (soglia depositata 7); il modello più grande misurato fa peggio e non è ripetibile; la regola di esito dà no per i tre modelli e decide il PI."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-10T18:32:02+01:00}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/00-previsioni.md", title: "Cancelli K1-K5, previsioni R1-R3, O1-O3, L1-L15 e regola di esito, depositati prima di ogni calcolo nuovo (commit 78355da)"}
- {id: prima, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/05-out.txt", title: "Le quattro letture fatte prima del deposito (05-08: diagnosi v0, forma delle voci, valori speciali di Atlas, campi di tempo)"}
- {id: oggi, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/10-out.txt", title: "Il riferimento nelle tre letture, il controllo positivo (K2) e la pipeline di oggi rimisurata (K1, K3, R1-R3, O1-O3)"}
- {id: v0, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/11-out.txt", title: "Il lettore v0 di S12r rimisurato col costruttore nuovo (K1)"}
- {id: corse, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/23-out.txt", title: "Registro delle corse su poddgx02 (K4)"}
- {id: tentativi, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/23-tentativi.md", title: "I tentativi dei modelli grandi, con la causa letta nel log"}
- {id: misura, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/24-out.txt", title: "Misura di M, M0 e G1 contro Atlas nelle tre letture, previsioni L1-L15, regola di esito punti 1-3"}
- {id: disaccordi, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/26-disaccordi.md", title: "Lettura di tutti i disaccordi di M, M0 e G1, con la causa e chi la può togliere (audit interno)"}
- {id: conti, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/26-out.txt", title: "Conti delle unità di disaccordo per causa ed esito, regola di esito punto 4"}
- {id: righe, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/26-disaccordi-M-righe.csv", title: "Una riga per unità di disaccordo (anche -M0- e -G1-)"}
- {id: forma, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/27-out-forma.txt", title: "Sensibilità `forma`, dichiarata dopo i numeri"}
- {id: formana, resource: "analysis/audit/2026-11-10-S12r2-prova-ripetuta/27-out-forma_na.txt", title: "Sensibilità `forma_na`, dichiarata dopo i numeri"}
- {id: spec, resource: "docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md", title: "Disegno del lettore dello studio (schema §5.2-§5.3, riferimento §5.5, regola di esito §5.6, modelli §5.7)"}
- {id: adr29, resource: "docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md", title: "ADR-0029 e §Aggiornamento del 2026-11-10"}
- {id: s12r, resource: "docs/findings/2026-11-09-S12r-prova-lettore-studio.md", title: "La prova piccola del lettore v0 (S12r)"}
- {id: minori, resource: "analysis/audit/2026-11-09-lettore-studio/68-decisioni-e-minori.md", title: "Decisioni tecniche e difetti minori rinviati da S12r"}
---

# In breve

## In breve: con lo schema corretto, il modello scrive i fattori di uno studio meglio di come la pipeline di oggi forma i confronti?

**A cosa serviva.** Il lettore dello studio è un solo passo del modello: legge uno studio e scrive la tabella dei suoi fattori. Poi un programma senza modello forma i confronti. Nella prima prova il lettore non faceva meglio della pipeline di oggi, soprattutto per la forma dello schema. Abbiamo corretto lo schema e abbiamo ripetuto la prova sugli stessi 47 studi, contro i confronti scritti dai curatori di Expression Atlas. Il risultato serve a decidere se il lettore entra nella pipeline, e con quale modello.

**Cosa abbiamo trovato.**

1. **Con lo schema corretto il lettore ritrova 50 dei 97 confronti dei curatori. La pipeline di oggi ne ritrova 13.** Il modello è quello di produzione, Mistral-Small 3.2. Il lettore forma gli stessi gruppi dei curatori in 31 studi su 47, la pipeline di oggi in 14. Due corse del lettore danno uscite uguali al carattere in 47 studi su 47. Fra i confronti del lettore che i curatori non elencano non abbiamo trovato errori, ma quelli giudicabili sono solo 4.
2. **In 13 studi su 47 la tabella del lettore non copre tutti i campioni, e lo studio non dà nessun confronto.** Prima della prova avevamo scritto che oltre 7 studi lo schema va cambiato prima di ogni conclusione. In 8 studi il modello non scrive una riga per ogni valore della colonna. In altri 3 studi il modello usa una forma che lo schema non ammette.
3. **Il modello più grande della stessa famiglia fa peggio e non è ripetibile.** Mistral-Small 4, che è cinque volte più grande, ritrova 32 confronti su 97. Due sue corse danno uscite uguali solo in 4 studi su 47. Il secondo modello grande, Qwen 3.5, non è partito in due tentativi, quindi non è misurato.
4. **Abbiamo letto tutti i 63 disaccordi del lettore, e ognuno ha una causa.** 12 restano anche con un lettore senza errori, perché nascono da scelte o errori dei curatori. 16 spariscono con due correzioni di forma, che abbiamo calcolato dopo i numeri. 30 chiedono un cambio dello schema che non abbiamo misurato. 5, in 2 studi, sono errori di lettura del modello, e il modello più grande ne toglie 1.
5. **La regola scritta prima della prova dà «no» per tutti e tre i modelli.** Mistral-Small 3.2 soddisfa tre condizioni su quattro: è ripetibile e fa meglio di oggi nelle tre misure. La quarta chiede che ogni errore abbia un rimedio. Per 4 errori di lettura il rimedio ammesso era un modello più grande, e la misura non lo conferma. Ho applicato la lettura più severa della regola: con la lettura più larga la risposta è «sì».

**Cosa devi decidere.**

1. **Scriviamo adesso il piano per mettere il lettore nella pipeline? Raccomando di no: prima una terza prova piccola, con uno schema costruito per ogni studio.** In quello schema le colonne e i valori sono un elenco chiuso, preso dalla tabella dei campioni, e ogni valore deve avere la sua riga. I motivi sono due. I 13 studi non chiusi superano la soglia di 7 scritta prima. Il rimedio non è misurato, e una corsa dura pochi minuti. Le due correzioni di forma porterebbero il lettore a 64 confronti su 97, ma questo numero è un calcolo fatto dopo, non una misura. Il limite: i 47 studi servono una terza volta, quindi il risultato vale per lo sviluppo. Il giudizio resta agli 82 studi mai aperti. Le alternative:
   - Scrivere il piano adesso, con il cambio dello schema come primo passo. Conseguenza: il piano poggia su un rimedio non misurato. Se il rimedio non funziona, il piano si riscrive.
   - Fermare il lettore e tenere la pipeline di oggi. Conseguenza: restano 13 confronti ritrovati su 97, contro i 50 del lettore.
2. **Con quale modello? Raccomando Mistral-Small 3.2, il modello di produzione.** È ripetibile e ritrova più confronti del modello più grande. La prova non mostra che la grandezza del modello è il limite. L'alternativa è Mistral-Small 4. Conseguenza: uscite non ripetibili e meno confronti ritrovati.
3. **Riproviamo Qwen 3.5? Raccomando di no, e di cancellare i suoi pesi dal DGX.** Il modello chiede tutte le 8 GPU del nodo, oppure un contesto più corto di quello fissato per la prova. Per questo modello il contenitore di produzione non offre il modo che rende le uscite ripetibili. Conseguenza del no: non sappiamo se un modello grande di un'altra famiglia legge meglio. L'alternativa è una prova nuova con 8 GPU. Conseguenza: i pesi, 268 GB, restano su un disco pieno all'85%, e la ripetibilità va misurata.

**Comunque.** La penalità di ripetizione resta com'è: senza penalità il lettore ritrova gli stessi 50 confronti su 97. Gli 82 studi del giudizio restano chiusi. Il deliverable e i master non cambiano. Il lettore non entra nella pipeline prima della tua decisione.

Appena decidi questi 3 punti, la sessione è chiusa.

**Sui tempi di calcolo.** La stima è dell'agente. La terza prova chiede due corse di circa 4 minuti l'una su 4 GPU. In questa sessione una corsa di Mistral-Small 3.2 sui 47 studi è durata 3 minuti e 19 secondi.

---

# 1. Che cosa è stato fatto

Sessione S12r2 dell'handout `2026-11-07-HANDOUT-PIANO-RIVISTO.md`, branch `p6-tabella-dei-fattori`, un solo agente.
Nomi delle corse: **M** = `mistralai/Mistral-Small-3.2-24B-Instruct-2506` con `repetition_penalty` 1,1 (due corse);
**M0** = lo stesso senza penalità (una corsa); **G1** = `mistralai/Mistral-Small-4-119B-2603`, ragionamento spento
(due corse); **G2** = `Qwen/Qwen3.5-122B-A10B` (non misurato). «Oggi» = la pipeline di oggi, cioè il master S14 dello
Stadio 2 portato alla stessa misura con `tf_da_stage2()`.

| passo dell'handout | che cosa | commit |
|---|---|---|
| 1. Carta | spec §5.2, §5.3, §5.5, §5.7 aggiornate: fattori prima dei ruoli, voci di `assignment` come condizioni colonna-valore, livelli «not stated» e «not applicable», regola del tempo zero per costruzione, tre letture del riferimento, modelli | `d59482c` |
| 2. Deposito | cancelli, previsioni e regola di esito[^previsioni]; le quattro letture fatte prima del deposito[^prima] | `78355da`, `d2d1141` |
| 3. Codice (TDD) | costruttore e misure secondo la spec: `TF_NON_APPLICABILE`, regola del fattore annidato in `tf_confronti()`, marca `tempo_zero`, tre letture, classe `identica_sui_comuni`, `tf_da_stage2()` diagnostico, avviso `soggetti_buco` | `e871711` |
| 2. Rimisura | il riferimento nelle tre letture e la pipeline di oggi rimisurata[^oggi]; il lettore v0 rimisurato[^v0] | `5bc0cfd` |
| 3-4. Materiale da buttare | schema, prompt e adattatore v1, script delle corse; `chat_template_kwargs` dal bundle al runner | `5f17056`, `08ca99b` |
| 4. Corse | M ×2, M0, G1 ×2 congelate prima di ogni misura[^corse]; G1 al secondo tentativo; G2 due tentativi falliti[^tentativi] | `2fd3dcd`, `4d02ee3`, `c4a2dba`, `9f6cc72`, `d38901f`, `d20bdb6` |
| 5. Misura e lettura | misura nelle tre letture[^misura], sensibilità sulla forma[^forma][^formana], lettura di tutti i disaccordi[^disaccordi] | `43226b6`, `2fff961` |

Ingresso: `analysis/input/S12r2-lettore-v1-ingresso.jsonl`, 47 studi, SHA-256 uguale all'ingresso di S12r: la vista
è la vista v0, senza cambi. Cambiano solo schema e prompt.[^corse]

**I 47 studi di sviluppo servono qui una seconda volta.** Lo schema v1 è stato scritto dopo aver letto i disaccordi
di S12r sugli stessi studi. Il risultato vale per lo sviluppo, non come giudizio. Il giudizio spetta agli 82 studi
chiusi, che questa sessione non ha aperto.

# 2. Cancelli

| cancello | che cosa chiede | esito | fonte |
|---|---|---|---|
| K1 | riproduzione prima del cambio: oggi e lettore v0 ridanno i numeri di S12r nella lettura intera (14/47, 19/93, 19/79; lettore v0 23 chiusi, 10/93) | **passato** | `10-out.txt` r.259-261, r.305; `11-out.txt` r.14, r.40, r.73 |
| K2 | controllo positivo nelle tre letture: Atlas contro Atlas dà 97/97, 93/93, 86/86, e la marca `tempo_zero` vede `GSE49608` | **passato** | `10-out.txt` r.29-31, r.207, r.222 |
| K3 | copertura 47 studi su 47 per oggi, M, M0, G1 | **passato** | `10-out.txt` r.306; `24-out.txt` r.16 |
| K4 | ogni job su `poddgx02`, `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` letti da `container-env.txt`, uscite congelate (44 file, SHA-256) prima della misura | **passato** per M, M0, G1 | `23-out.txt`; `24-out.txt` r.13 |
| K5 | i 82 studi di giudizio restano chiusi: ogni script legge solo `studi_di_sviluppo()` | **rispettato** | `aiuti-misura-r2.R` r.4, `23-lancia.R` r.89, `24-misura.R` r.50 |

Il secondo tentativo di G2 è stato inviato **in deroga dichiarata a K4** (senza `VLLM_BATCH_INVARIANT`, perché
vLLM 0.20.2 non lo ammette per gli strati GDN di Qwen 3.5). La deroga è stata scritta prima dell'invio (`d38901f`).
Il job è fallito per un'altra causa e non ha prodotto nessun record: **nessun numero di questo finding è in
deroga**.[^tentativi]

# 3. Le misure e le previsioni

## 3.1 Il riferimento nelle tre letture

Atlas elenca 123 confronti nei 47 studi. La regola nuova marca 13 confronti col tempo zero come controllo, per
costruzione (R1). Le letture:[^oggi]

| lettura | che cosa cambia | denominatore di (b) |
|---|---|---|
| **principale** (decide) | escono i confronti col tempo zero; «not applicable» di un fattore annidato non conta come seconda differenza | 97 |
| intera | il riferimento di S12r, senza la regola del tempo zero | 93 |
| stretta | come la principale, con la lettura stretta del fattore non scritto | 86 |

Misure: **(a)** studi in cui i gruppi sono identici a quelli di Atlas; **(b)** confronti di Atlas ritrovati, con lo
stesso verso; **(c)** errori fra i confronti formati che Atlas non elenca e che si possono giudicare. Intervalli al
95% dal bootstrap sugli studi, B = 2.000, seme 20261110.

## 3.2 Le misure, lettura principale

| | chiusi | (a) gruppi identici | (b) confronti ritrovati | (c) errori fra i non elencati | (b) meno oggi, punti |
|---|---|---|---|---|---|
| oggi | n.a. | 14/47 = 29,8% (17,0-42,6) | 13/97 = 13,4% (6,5-22,2) | 18/79 = 22,8% (8,6-37,5) | |
| lettore v0 (S12r, Mistral 3.2) | 23 | 14/47 | 10/97 = 10,3% (3,8-20,0) | 1/5 | −3,1 (−12,3; +7,0) |
| **M** (v1, Mistral 3.2) | 34 | **31/47 = 66,0%** (53,2-78,7) | **50/97 = 51,5%** (35,1-69,8) | 0/4 | **+38,1 (+19,0; +58,2)** |
| M0 (v1, senza penalità) | 33 | 30/47 = 63,8% (51,1-76,6) | 50/97 = 51,5% (34,5-69,2) | 0/4 | +38,1 (+20,0; +57,0) |
| G1 corsa 1 (v1, Mistral-Small 4) | 30 | 26/47 = 55,3% (42,6-68,1) | 32/97 = 33,0% (19,6-50,0) | 7/11 = 63,6% (0-100) | +19,6 (+5,6; +36,0) |
| G1 corsa 2 | 33 | 28/47 = 59,6% (46,8-74,5) | 25/97 = 25,8% (14,9-40,9) | 5/10 | +12,4 (+0,9; +27,3) |
| G2 | non misurato | | | | |

Fonti: oggi `10-out.txt` r.241-243; lettore v0 `11-out.txt` r.14, r.21-23, r.27; M `24-out.txt` r.18, r.60-62, r.66;
M0 r.111, r.154-156, r.160; G1 r.207, r.253-255, r.259; G1 corsa 2 r.303, r.346-348, r.352. Nessun confronto
ritrovato ha il verso opposto (M, M0, G1: 0).

Altre differenze, lettura principale: M meno oggi (a) +36,2 punti (+19,1; +53,2), (c) −22,8 (−37,2; −8,3) (r.65,
r.67); G1 meno oggi (a) +25,5 (+8,5; +42,6), (c) +40,9 (−13,9; +76,1) (r.258, r.260); **M0 meno M** (a) −2,1
(−10,6; +6,4), (b) 0,0 (−12,9; +12,6) (r.400-401); **G1 meno M** (a) −10,6 (−25,5; +4,3), (b) −18,6 (−40,4; +4,1)
(r.429-430).

## 3.3 Le letture intera e stretta (non decidono)

| | (b) intera | meno oggi | (b) stretta | meno oggi |
|---|---|---|---|---|
| oggi | 19/93 = 20,4% | | 12/86 = 14,0% | |
| M | 50/93 = 53,8% | +33,3 (+5,9; +57,0) | 46/86 = 53,5% | +39,5 (+19,2; +60,0) |
| M0 | 50/93 | +33,3 (+6,2; +57,0) | 44/86 = 51,2% | +37,2 (+17,7; +57,7) |
| G1 corsa 1 | 32/93 = 34,4% | +14,0 (−6,6; +33,3) | 27/86 = 31,4% | +17,4 (+2,4; +35,0) |
| G1 corsa 2 | 25/93 | +6,5 (−12,7; +25,0) | 20/86 | +9,3 (−3,5; +25,3) |

Fonti: `10-out.txt` r.260, r.278; `24-out.txt` r.79, r.84, r.97, r.102, r.173, r.178, r.191, r.196, r.272, r.277,
r.290, r.295, r.365, r.370, r.383, r.388. Per M e M0 il segno e l'intervallo sopra 0 tengono in tutte e tre le
letture. Per G1 l'intervallo contiene lo 0 nella lettura intera, e per la corsa 2 anche nella stretta.

## 3.4 La forma delle uscite

| | voci di `assignment` | di forma sbagliata | studi con un livello per campione | studi con una base senza campioni | uscite troncate | token dell'uscita, mediana e massimo | confronti formati |
|---|---|---|---|---|---|---|---|
| M | 306 | 20 in 5 studi | 1 | 4 | 0 | 616; 1.929 | 63 in 28 studi |
| M0 | 258 | 10 in 5 studi | 1 | 4 | 0 | 648; 2.867 | 63 in 28 studi |
| G1 | 302 | 19 in 4 studi | 0 | 4 | 0 | 591; 2.991 | 53 in 25 studi |

Fonte: `24-out.txt` r.49-53, r.143-147, r.242-246. Tutti gli studi non chiusi di M hanno il motivo `non_coperta`
(13 su 13, r.22): almeno un campione non riceve un livello in almeno un fattore. L'uscita più lunga è di 2.991
token su `max_tokens` 24.576 (12%): il rinvio di S12r sull'uscita all'81% del limite è chiuso.

## 3.5 Le previsioni con l'esito

| | quantità | atteso; intervallo di rilevanza | misurato | esito |
|---|---|---|---|---|
| R1 | confronti di Atlas con la marca `tempo_zero` | 13; 10-16 | 13 | confermata |
| R2 | denominatore di (b), principale | 97; 83-97 | 97 | confermata |
| R3 | denominatore di (b), stretta | 86; 72-86 | 86 | confermata |
| O1 | oggi, (b) principale | 15%; 8-25% | 13,4% (6,5-22,2) | indeterminata |
| O2 | oggi, (a) principale | 14; 14 | 14 | confermata |
| O3 | oggi, (c) principale | 22%; 10-35% | 22,8% (8,6-37,5) | indeterminata |
| L1 | M: studi non chiusi | 5; 0-7 | **13** | **smentita** |
| L2 | M: voci di forma sbagliata | 0; 0 | **20** | **smentita** |
| L3 | M: studi con un livello per campione | 1; 0-2 | 1 | confermata |
| L4 | M: studi con una base senza campioni | 1; 0-2 | **4** | **smentita** |
| L5 | M: (a) | 55%; 50-80% | 66,0% (53,2-78,7) | confermata |
| L6 | M meno oggi, (b) | +15 punti; intervallo sopra 0 | +38,1 (+19,0; +58,2) | confermata |
| L7 | M: (c) | 5%; 0-10% | 0/4 | confermata |
| L8 | M: uscite identiche fra le due corse | 47; 47 | 47 | confermata |
| L9 | M0 meno M, (b) | 0 punti; −5, +5 | 0,0 (−12,9; +12,6) | indeterminata |
| L10 | M0: uscite troncate | 0; 0-1 | 0 | confermata |
| L11 | G1: uscite identiche fra le due corse | 47; 47 | **4** | **smentita** |
| L12 | G1: studi non chiusi | 3; 0-7 | **17** | **smentita** |
| L13 | G1: (a) | 60%; 50-80% | 55,3% (42,6-68,1) | indeterminata |
| L14 | G1 meno oggi, (b) | +25 punti; intervallo sopra 0 | +19,6 (+5,6; +36,0) | confermata |
| L15 | G1 meno M, (b) | +10 punti; intervallo sopra 0 | −18,6 (−40,4; +4,1) | indeterminata |
| L11-L15 | G2 | | non misurato | senza esito |

Fonti: `10-out.txt` r.225-227, r.309-311; `24-out.txt` r.456-470.

## 3.6 I dubbi aperti dalle previsioni, e come sono chiusi

| dubbio | come è chiuso |
|---|---|
| **L1 smentita** (13 studi non chiusi, soglia 7) | **Scelta del PI** (decisione 1). Il testo depositato dice: «oltre 7 lo schema va cambiato prima di ogni conclusione». Prime cause dei 13: `modello/valore_senza_voce` 8, `modello/forma_voci` 2, `schema/annidato_colonna_padre` 1, `modello/colonna_non_letterale` 1, `modello/valore_non_letterale` 1 (§5.2). La sensibilità `forma` ne chiude 3 (`GSE59781`, `GSE66207`, `GSE69597`); per gli altri 10 il rimedio proposto non è misurato. |
| **L2 smentita** (20 voci di forma sbagliata) | **Spiegata.** Lo schema v1 toglie la lista per posizione, ma lascia due forme: una voce con più condizioni sulla stessa colonna (`GSE59781`, `GSE69597`) e, per un fattore annidato, la condizione sulla colonna del fattore padre (`GSE66207`, `GSE57945`). Con le due tolleranze della sensibilità `forma` resta 1 voce in 1 studio (`GSE71595`, voce senza condizione). Il cambio dello schema entra nella decisione 1. |
| **L4 smentita** (4 studi con una base senza campioni) | **Spiegata.** I 4 studi (`GSE147507`, `GSE59781`, `GSE63816`, `GSE83415`) sono tutti fra i 13 non chiusi: la base è scritta, ma la voce che la assegna manca o porta un valore che la colonna non contiene. Con la sensibilità `forma` ne restano 3. È la stessa causa di L1, non una causa nuova. |
| **L11 smentita** (G1: 4 studi identici su 47) | **Spiegata in parte, e decisa dalla regola.** G1 gira con `tensor_parallel_size = 4` e con `VLLM_BATCH_INVARIANT=1` letto sul processo. La variabile non basta a rendere ripetibile questo modello in questa configurazione. La causa dentro vLLM non è diagnosticata. Per la spec §5.7 «un modello non ripetibile non soddisfa la regola di esito»: G1 è no. La diagnosi serve solo se il PI sceglie un modello che chiede il parallelismo su più GPU (rinvio condizionato, scritto nell'handout). |
| **L12 smentita** (G1: 17 studi non chiusi) | **Spiegata.** Prime cause dei 17: `modello/valore_non_letterale` 6, `modello/valore_senza_voce` 5, `modello/fattori_uniti` 3, altre 3 (`26-out.txt` r.151-162). G1 scrive più spesso valori che la colonna non contiene. |
| O1, O3 indeterminate | **Non toccano una conclusione.** La regola di esito usa la differenza appaiata lettore meno oggi, non il valore di oggi. |
| L9 indeterminata | **Spiegata.** M0 e M ritrovano 50 confronti su 97 tutti e due. Cambiano 4 studi: M0 guadagna 6 confronti in 2 studi (`GSE71595`, `GSE83687`) e ne perde 6 in altri 2 (`GSE49155`, `GSE60585`). La prova non mostra un guadagno senza penalità; l'intervallo è largo e non esclude ±5 punti. Per la regola di uniformità della configurazione la penalità di produzione resta. Il PI lo legge nel riassunto. |
| L13 indeterminata | **Non tocca una conclusione:** G1 è no per i punti 1 e 3. |
| **L15 indeterminata** (G1 meno M: −18,6; −40,4, +4,1) | **Scelta del PI** (decisione 2). Per il testo depositato, se l'intervallo contiene lo 0 «la prova non mostra che la capacità del modello è il limite». La stima è negativa: M ritrova più confronti di G1 in 9 studi (27 confronti), G1 più di M in 4 studi (9 confronti). |
| G2 non misurato | **Scelta del PI** (decisione 3). Due tentativi, due cause lette nel log (§10). |

# 4. La sensibilità sulla forma (dichiarata dopo i numeri, non una misura)

Due varianti dell'adattatore, scritte dopo aver visto i numeri di §3 (`27-tollera.R`): **`forma`** = T1 (ammette la
condizione sulla colonna del fattore padre) + T2 (una voce con più condizioni sulla stessa colonna diventa una voce
per valore); **`forma_na`** = `forma` + T3 (la stringa «NA» in una colonna di soggetto vale come non scritto).
Dicono quanto del disaccordo è forma. Non sostituiscono la misura e non entrano nella regola di esito.

| lettura principale | chiusi | (a) | (b) | (c) | (b) meno oggi |
|---|---|---|---|---|---|
| M, misura | 34 | 31/47 | 50/97 | 0/4 | +38,1 |
| M, `forma` | 37 | 33/47 = 70,2% | 59/97 = 60,8% | 0/6 | +47,4 (+28,7; +66,7) |
| M, `forma_na` | 37 | 33/47 | 64/97 = 66,0% (49,4-81,0) | 0/6 | +52,6 (+34,1; +69,6) |
| M0, `forma` / `forma_na` | 36 | 32/47 | 56/97 / 61/97 | | |
| G1, `forma` e `forma_na` | 31 | 27/47 | 32/97 | 7/11 | |

Fonti: `27-out-forma.txt` e `27-out-forma_na.txt` r.19, r.58-60, r.64, r.109, r.147-148, r.200, r.243-245. Per G1
la forma non cambia i confronti ritrovati: i suoi disaccordi non sono di forma.

# 5. Le cause

**Audit interno.** Le cause le ha lette un agente Claude sul materiale di `25-materiale-<modello>.txt` (vista,
uscita del modello, tabella di Atlas, incrocio dei gruppi, registro delle coppie). Non è una misura dell'articolo.
Dettaglio, una riga per unità: `26-disaccordi.md` e `26-disaccordi-<modello>-righe.csv`.[^disaccordi][^righe]

## 5.1 Le unità di disaccordo

| modello | studi con unità | unità | studio non chiuso | partizione non identica | confronto del riferimento non ritrovato | confronto del lettore giudicato errore |
|---|---|---|---|---|---|---|
| M | 20 | 63 | 13 | 3 | 47 | 0 |
| M0 | 21 | 64 | 14 | 3 | 47 | 0 |
| G1 | 24 | 93 | 17 | 4 | 65 | 7 |

Fonte: `26-out.txt` r.11, r.81, r.148. Ogni unità ha una prima causa (il primo difetto che la misura incontra) e un
resto (che cosa resta quando la prima causa è tolta).

## 5.2 M: prima causa ed esito della catena

L'**esito** dice chi toglie l'unità alla fine della catena: `forma` = la sensibilità la toglie (misurato);
`vista_schema` = un cambio dello schema o della vista, proposto e non misurato; `modello` = resta una causa di
lettura del modello; `non_errore` = l'unità resta anche con un lettore senza errori, perché nasce da una scelta o
da un errore dei curatori.

| prima causa | che cosa vuol dire | unità | esito |
|---|---|---|---|
| `modello/valore_senza_voce` | un valore della colonna di fonte resta senza voce | 27 (8 studi) | `vista_schema` 22, `modello` 3, `non_errore` 2 |
| `modello/forma_voci` | una voce porta più valori della stessa colonna | 9 (2 studi) | `forma` 7, `non_errore` 2 |
| `modello/colonna_non_letterale` | un fattore dichiara una colonna che la tabella non ha, o nessuna | 5 (1 studio) | `vista_schema` 5 |
| `modello/mancante_non_dichiarato` | «NA» in una colonna di soggetto non dichiarato come mancante | 5 (1 studio) | `forma` 5 |
| `schema/annidato_colonna_padre` | «not applicable» scritto con una condizione sulla colonna del fattore padre | 4 (1 studio) | `forma` 4 |
| `schema/context_senza_base` | per schema un fattore di contesto non ha livello di base | 3 (2 studi) | `modello` 2, `vista_schema` 1 |
| `modello/valore_non_letterale` | una voce porta un valore che la colonna non contiene | 2 (1 studio) | `vista_schema` 2 |
| `modello/tipo_fattore` | tipo del fattore sbagliato | 2 (1 studio) | `non_errore` 2 |
| `curatore/fattore_ignorato`, `/repliche`, `/errore_campione` | scelte o errori dei curatori | 6 (4 studi) | `non_errore` 6 |
| **totale** | | **63** | `forma` 16, `vista_schema` 30, `modello` 5, `non_errore` 12 |

Fonti: `26-out.txt` r.14-45, r.58-70; incrocio prima causa × esito calcolato da `26-disaccordi-M-righe.csv`. Studi
per esito: `forma` 4, `vista_schema` 10, `modello` 2, `non_errore` 6 (uno studio può avere unità con esiti
diversi).

**Le 5 unità con esito `modello`** stanno in 2 studi. `GSE57116` (3 unità): manca la voce per il valore «control»
della colonna `time`, e il fattore `time` ripete il fattore `treatment`. `GSE75852` (2 unità): il tipo cellulare è
scritto come contesto senza base, e un fattore `time` ripete il tipo cellulare. G1 toglie 1 delle 5 (lo studio
`GSE57116` chiude con gruppi identici, i suoi 2 confronti restano non ritrovati); le altre 4 restano
(`26-out.txt` r.46-50, r.79).

**La stessa unità in G1.** Delle 63 unità di M, G1 ne toglie 13 e 50 restano: `forma` 7 su 16, `vista_schema` 3 su
30, `non_errore` 2 su 12, `modello` 1 su 5 (`26-out.txt` r.53-57). G1 ha però 93 unità sue.

**Una causa di lettura del modello in un punto qualsiasi della catena** (anche come nota): 16 unità in 6 studi
per M, 13 in 5 studi per M0, 53 in 12 studi per G1 (`26-out.txt` r.72, r.139, r.199).

## 5.3 M0 e G1

| | unità | `forma` | `vista_schema` | `modello` | `non_errore` |
|---|---|---|---|---|---|
| M0 | 64 | 13 | 31 | 8 (3 studi: `GSE49155`, `GSE57116`, `GSE75852`) | 12 |
| G1 | 93 | 1 | 50 | 28 (8 studi) | 14 |

Fonte: `26-out.txt` r.109-112, r.146, r.180-184, r.206. Prime cause principali di G1: `modello/valore_senza_voce`
24 unità, `modello/valore_non_letterale` 19, `modello/fattori_uniti` 13, `modello/fattore_non_visto` 7,
`modello/colonna_non_letterale` 7. I 7 confronti di G1 giudicati errore: 3 hanno esito `modello`, 4 `non_errore`
(3 per `strumento/fattori_ridondanti`: la misura (c) conta due volte la stessa differenza scritta due volte da
Atlas; 1 per un errore di campione dei curatori).

## 5.4 Chi può togliere le cause

| chi | cause | misurato? |
|---|---|---|
| schema (forma) | `modello/forma_voci`, `schema/annidato_colonna_padre`, `modello/colonna_fuori_fonti` | sì, dalla sensibilità `forma` (non è una corsa) |
| vista | `modello/mancante_non_dichiarato` (sensibilità `forma_na`), `vista/sotto_serie` (non misurato) | in parte |
| schema (elenco chiuso) | `modello/valore_senza_voce`, `modello/valore_non_letterale`, `modello/colonna_non_letterale` | **no**: è la proposta di §7 |
| schema (tipi) | `schema/context_senza_base` | no |
| modello | `modello/fattore_doppio`, `/fattori_uniti`, `/fattore_non_visto`, `/fattore_inventato`, `/ruolo_soggetto`, `/tipo_fattore` | per M: G1 ne toglie 1 unità su 5; G2 non misurato |
| nessuno (non serve) | `curatore/*` | |
| strumento | `strumento/fattori_ridondanti` (solo G1, 3 unità) | no |

# 6. La regola di esito, e che cosa dice la prova

| | 1. due corse identiche in 47/47 | 2. (b) meno oggi, intervallo sopra 0 | 3. meglio di oggi in (a) e in (c), come stima | 4. ogni disaccordo ha una causa, ogni causa ha chi la toglie | **esito** |
|---|---|---|---|---|---|
| **M** (Mistral-Small 3.2) | sì (47/47) | sì (+38,1; +19,0, +58,2) | sì ((a) +36,2; (c) −22,8) | 63 su 63 con una causa; **vedi sotto** | **no** (lettura severa del punto 4) |
| **G1** (Mistral-Small 4) | **no** (4/47) | sì (+19,6; +5,6, +36,0) | **no** ((a) +25,5; (c) +40,9) | 93 su 93 con una causa; 28 con esito `modello`, senza chi le toglie | **no** |
| **G2** (Qwen 3.5) | non misurato | | | | **no** (regola depositata: non parte in due tentativi) |

Fonti: `24-out.txt` r.473-474; `26-out.txt` r.79, r.206; `23-tentativi.md`.

**Il punto 4 per M ha due letture, e l'agente ha scelto dopo i numeri.** Il testo depositato dice: «ogni causa del
lettore ha chi la può togliere: la vista, lo schema o, per Mistral-Small 3.2, un modello più grande».

- **Lettura larga (alla lettera):** ogni causa di M ha una categoria ammessa che la toglie. La risposta è **sì**, e M
  soddisfa quattro condizioni su quattro.
- **Lettura severa:** «un modello più grande la può togliere» vale solo dove la misura lo mostra. Delle 5 unità con
  esito `modello`, G1 ne toglie 1 e G2 non è misurato: per 4 unità in 2 studi nessuno ha mostrato chi le toglie. La
  risposta è **no**.

L'agente riporta **no**. È una scelta fatta dopo i numeri, nella direzione sfavorevole al lettore, e il PI la può
rovesciare. In tutti e due i casi il passo seguente è lo stesso: per la spec §5.6 e per il testo depositato «con un
sì o con un no il PI vede numeri e cause e decide». In più, in tutte e due le letture, 30 unità di M hanno un
rimedio proposto e **non misurato**, e L1 è smentita con la conseguenza scritta prima.

**Che cosa dice la prova.**

- Con lo schema v1 e Mistral-Small 3.2 il lettore ritrova più confronti dei curatori della pipeline di oggi: +38,1
  punti, con l'intervallo sopra 0 nelle tre letture del riferimento.
- La gran parte del guadagno da v0 a v1 viene dallo schema: stesso modello, stessa vista, da 10/97 a 50/97.
- Il modello più grande della stessa famiglia non fa meglio. La prova non mostra che la capacità del modello è il
  limite.
- La penalità di ripetizione non cambia i confronti ritrovati (50/97 con e senza).

**Che cosa non dice.**

- Non è un giudizio: i 47 studi sono serviti due volte, e lo schema v1 è nato dalla lettura dei loro disaccordi.
- Non dice che il lettore è senza errori: (c) per M ha denominatore 4. Con 4 confronti giudicabili «0 errori» non
  esclude un tasso di errore alto.
- Non misura il rimedio per 30 unità su 63 (§7).
- Non dice niente di un modello grande di un'altra famiglia: G2 non è misurato.
- La curazione di Atlas è una sola fonte: 12 unità di M nascono da scelte o errori dei curatori.

# 7. Misure portate al passo seguente

**Proposta non misurata: lo schema generato per ogni studio, a elenco chiuso.** Per ogni studio lo schema delle
uscite strutturate elenca come valori ammessi le colonne vere della tabella dei campioni e, per ogni colonna, i
valori distinti veri. Ogni valore distinto della colonna di fonte deve avere la sua voce (una voce per valore). La
proposta toglie per costruzione le forme `modello/forma_voci`, `modello/valore_non_letterale` e
`modello/colonna_non_letterale`, e rende visibile `modello/valore_senza_voce` come uscita non valida. Non decide
al posto del modello quale livello corrisponde a quale valore: quella resta lettura del modello.

**Dove nasce la causa (diagnosi).** Nello schema v1 colonne e valori sono stringhe libere. Il modello li riscrive a
memoria dalla tabella nel prompt, e niente lo obbliga a coprire tutti i valori: in `GSE83687` scrive 13 voci su 14,
in `GSE63816` scrive i titoli senza il numero finale. Il vincolo sta nello schema, cioè a monte dell'uscita, non in
una frase del prompt e non in una regola che corregge l'uscita dopo.

**Che cosa resta aperto anche con quella proposta:** (i) `schema/context_senza_base`: un confronto fra due tipi
cellulari o due condizioni di coltura non ha una base per schema (3 unità in M, `GSE65335`, `GSE75852`); è una
scelta di disegno della spec, da portare al PI con la terza prova. (ii) `vista/sotto_serie`: in `GSE147507` la
vista porta 77 campioni di più sotto-serie contro i 14 dell'universo di Atlas. (iii) le 4 unità con esito
`modello`. (iv) studi con molte colonne e molti valori: la grandezza dello schema generato va misurata prima della
corsa (l'ingresso più lungo è di 31.271 token).

**Rinvii ricevuti da S12r, stato:** uscita all'81% di `max_tokens` chiuso (12%, §3.4); difetti minori M5, M6, M7
chiusi nel codice (`e871711`); M8, M9, M10, M11 riguardano file di S12r che non si riscrivono (il protocollo non è
retroattivo) e restano come scritti in `68-decisioni-e-minori.md`[^minori]; M12 (il token di Hugging Face comparso
una volta nell'uscita di un comando di S12r) resta una scelta del PI ed è segnalato di nuovo nel rapporto; Gemma
(UBC) riprovata una volta (§10), resta fuori.

# 8. Decisioni tecniche dell'agente

1. **G1 su 4 GPU al secondo tentativo.** Il primo (`tensor_parallel_size = 2`) fallisce per la memoria della cache;
   un solo cambio, `tensor_parallel_size = 4`. Il valore atteso dal cancello K4 è stato adeguato (`c4a2dba`): un
   rilancio fermato dal cancello prima dell'invio non è un tentativo.
2. **Deroga a K4 per il secondo tentativo di G2**, scritta prima dell'invio. Costo se sbagliata: una misura di G2
   non ripetibile per costruzione. Non ha prodotto numeri.
3. **Lettura severa del punto 4** della regola di esito per M (§6).
4. **La lettura dei disaccordi di G1 usa la prima corsa**, come la regola di esito; la corsa 2 è misurata e
   riportata accanto (§3.2). Le due corse di G1 danno numeri diversi: 32/97 e 25/97.
5. **La misura di M è partita mentre G1 era in corsa.** Le uscite di M erano già congelate (`2fd3dcd`); nessuna
   scelta su G1 è seguita ai numeri di M.
6. **Un confronto di Atlas ritrovato col tempo zero come controllo conta come non ritrovato** nella lettura
   principale (la regola del PI: il tempo zero non è un controllo).
7. **Le unità si contano sui confronti del denominatore di (b)**; la tassonomia delle cause è la v1 di S12r con tre
   sottoclassi nuove (`curatore/livelli_uniti`, `modello/colonna_fuori_fonti`, `strumento/fattori_ridondanti`) e la
   colonna `lettura_modello`.
8. **Le sensibilità `forma` e `forma_na`** sono dichiarate dopo i numeri e non entrano in nessuna regola.
9. **Pesi dei modelli.** I pesi di G1 sono cancellati dal DGX (spec §5.7). **I pesi di G2 (268 GB) restano sul DGX,
   in deviazione dalla spec §5.7**, finché il PI non decide se G2 si riprova: `/home/u0044` occupa 426 GB su 500.
10. **Due errori dello script del materiale** (`25-materiale.R`: una variabile `saltato` e il confronto con la
    stringa `"errore"`) corretti in sessione prima della lettura; la misura `24-*` non ne dipende.

# 9. Limiti

- **Sviluppo, non giudizio.** Gli stessi 47 studi sono serviti per scrivere lo schema v1 e per misurarlo.
- **(c) di M su 4 confronti giudicabili** (7 non elencati, 4 giudicabili): la misura non ha potenza.
- **La lettura delle cause è audit interno**, fatta da un agente Claude, una volta, senza seconda lettura.
- **30 unità su 63 hanno un rimedio proposto e non misurato**; l'esito `forma` è misurato da una sensibilità
  scritta dopo i numeri, non da una corsa con uno schema nuovo.
- **Un solo riferimento**, la curazione di Expression Atlas, con le sue scelte (12 unità di M).
- **G1 è misurato in una sola configurazione** (4 GPU, ragionamento spento) e non è ripetibile: i suoi numeri
  valgono per le due corse viste, e cambiano fra l'una e l'altra (32 e 25 confronti su 97).
- **G2 non è misurato:** la domanda «un modello grande di un'altra famiglia legge meglio?» resta senza risposta.
- **L'intervallo di M0 meno M è largo** (±13 punti): la prova non esclude un effetto piccolo della penalità.

# 10. Anomalie viste durante il lavoro

1. **G1 non è ripetibile anche con `VLLM_BATCH_INVARIANT=1`** (4 studi identici su 47). La variabile è letta sul
   processo (K4). Con `tensor_parallel_size = 4` la batch invarianza di vLLM 0.20.2 non dà uscite identiche per
   questo modello. Causa non diagnosticata (§3.6).
2. **G2 non parte con il contenitore di produzione**, per due cause indipendenti: vLLM 0.20.2 rifiuta la batch
   invarianza per gli strati GDN (`RuntimeError: VLLM batch_invariant mode is not supported for GDN_ATTN`), e su 4
   GPU la memoria per la cache non basta con `max_model_len = 65536` (0,8 GiB necessari, 0,23 disponibili;
   lunghezza massima stimata 15.840).[^tentativi]
3. **G1, primo tentativo fallito** con 2 GPU per motore (`No available memory for the cache blocks`).
4. **Il filtro che toglie il token dai log** (`hf_` seguito da lettere) nascondeva anche le righe con `HF_HOME` in
   minuscolo nei percorsi: corretto nel filtro con una lunghezza minima; nessun token stampato in questa sessione.
5. **Gemma (UBC) non risponde.** Riprovata una volta in questa sessione (2026-11-10T15:42:58Z, attesa di 120 s, 0
   byte ricevuti): resta fuori dalla prova, come in S12r. Questo fatto è visto in sessione e non è scritto in un
   file della cartella di evidenza.
6. **I token del prompt:** mediana 2.144 e massimo 31.271 per M e M0; mediana 2.156 e massimo 31.283 per G1 (un
   tokenizzatore diverso).[^corse]

# 11. Da dove vengono i numeri del riassunto

Cartella: `analysis/audit/2026-11-10-S12r2-prova-ripetuta/`.

| frase del riassunto | file e riga | valore letto |
|---|---|---|
| il lettore ritrova 50 dei 97 confronti | `24-out.txt` r.61 | `b_confronti_ritrovati 50 97 0.5155` |
| la pipeline di oggi ne ritrova 13 | `10-out.txt` r.242 | `b_confronti_ritrovati 13 97 0.13402` |
| stessi gruppi in 31 studi su 47 | `24-out.txt` r.60 | `a_gruppi_identici 31 47 0.6596` |
| la pipeline di oggi in 14 | `10-out.txt` r.241 | `a_gruppi_identici 14 47 0.29787` |
| uscite uguali in 47 studi su 47 | `24-out.txt` r.17 | `uscite identiche al carattere fra le due corse: 47 su 47` |
| nessun errore, giudicabili solo 4 | `24-out.txt` r.62 | `c_errori_non_elencati 0 4` |
| 13 studi su 47 non coprono tutti i campioni | `24-out.txt` r.18, r.22 | `chiusi: 34 su 47; non chiusi: 13`; `non_coperta` 13 |
| oltre 7 studi lo schema va cambiato | `00-previsioni.md` r.112 | `L1 … 5 su 47 … 0-7 … oltre 7 lo schema va cambiato prima di ogni conclusione` |
| in 8 studi manca una riga per un valore | `26-out.txt` r.23 | `modello/valore_senza_voce 8` (studio non chiuso) |
| in altri 3 studi una forma non ammessa | `26-out.txt` r.19, r.24 | `modello/forma_voci 2`, `schema/annidato_colonna_padre 1` |
| Mistral-Small 4 è cinque volte più grande | `00-previsioni.md` r.64, r.66 | 119B contro 24B (nomi dei modelli) |
| Mistral-Small 4 ritrova 32 su 97 | `24-out.txt` r.254 | `b_confronti_ritrovati 32 97 0.3299` |
| uscite uguali solo in 4 studi su 47 | `24-out.txt` r.205 | `uscite identiche al carattere fra le due corse: 4 su 47` |
| Qwen 3.5 non è partito in due tentativi | `23-tentativi.md`, sezioni G2; `24-out.txt` r.395 | `G2: prima corsa assente, non misurato` |
| 63 disaccordi, ognuno con una causa | `26-out.txt` r.79 | `unita' con una causa 63 su 63` |
| 12, 16, 30, 5 | `26-out.txt` r.41-45 (somme di colonna) | `non_errore` 1+3+8, `forma` 2+14, `vista_schema` 9+21, `modello` 1+4 |
| 5 in 2 studi, il modello più grande ne toglie 1 | `26-out.txt` r.79 | `esito «modello» 5 (in 2 studi); … tolte da un modello piu' grande misurato: 1` |
| tre condizioni su quattro | `24-out.txt` r.473 | `M: (1) … si'; (2) … si'; (3) … si'` |
| per 4 errori di lettura la misura non conferma | `26-out.txt` r.48-50 | `G1 1`, `nessuno 2 + 2` |
| le due correzioni di forma: 64 su 97 | `27-out-forma_na.txt` r.59 | `b_confronti_ritrovati 64 97 0.6598` |
| 82 studi mai aperti | `CLAUDE.md` §1 (ADR-0029) | 42 giudizio A + 40 giudizio B |
| 8 GPU oppure contesto più corto | `23-tentativi.md`, G2 secondo tentativo | `8 GPU … oppure max_model_len ≤ 15.840` |
| il contenitore non offre la ripetibilità per Qwen | `23-tentativi.md`, G2 primo tentativo | `VLLM batch_invariant mode is not supported for GDN_ATTN` |
| pesi 268 GB, disco pieno all'85% | `23-tentativi.md`, G2 secondo tentativo | `268 GB`; `426 GB su 500` (= 85,2%) |
| senza penalità gli stessi 50 su 97 | `24-out.txt` r.155 | `b_confronti_ritrovati 50 97 0.5155` |
| una corsa di Mistral-Small 3.2: 3 minuti e 19 secondi | `23-out.txt` r.8 | `durata 00:03:19` (slurm 478252) |
| circa 4 minuti per corsa (stima) | `23-out.txt` | durate misurate 00:03:19, 00:03:18, 00:04:04 |

[^previsioni]: `analysis/audit/2026-11-10-S12r2-prova-ripetuta/00-previsioni.md`.
[^prima]: `05-out.txt`, `06-out.txt`, `07-out.txt`, `08-out.txt` nella stessa cartella.
[^oggi]: `10-out.txt`.
[^v0]: `11-out.txt`.
[^corse]: `23-out.txt`.
[^tentativi]: `23-tentativi.md`.
[^misura]: `24-out.txt`.
[^disaccordi]: `26-disaccordi.md`, `26-out.txt`.
[^righe]: `26-disaccordi-M-righe.csv`, `26-disaccordi-M0-righe.csv`, `26-disaccordi-G1-righe.csv`.
[^forma]: `27-out-forma.txt`.
[^formana]: `27-out-forma_na.txt`.
[^minori]: `analysis/audit/2026-11-09-lettore-studio/68-decisioni-e-minori.md`, §«Difetti minori rinviati».
