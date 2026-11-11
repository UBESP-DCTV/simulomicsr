# S12r3 — La terza prova piccola del lettore dello studio: cancelli e previsioni

Depositate il 2026-11-11, **prima di ogni corsa del modello sui testi degli studi**. Dopo il risultato non si
cambiano. La carta sta nella spec `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`
(§5.2, §5.5, §5.6, blocchi «Aggiornamento 2026-11-11 (S12r3)», commit `8d7912d`) e nell'ADR-0029 (aggiornamento
dello stesso giorno).

**Unità:** lo studio. **Incertezza:** bootstrap sugli studi, B = 2.000, seme 20261111. I confronti fra il lettore
e la pipeline di oggi, e fra lo schema nuovo e lo schema v1, sono appaiati sugli studi.

**Da dove vengono i valori attesi.** Sono giudizio motivato dell'agente, costruito sui numeri e sulle uscite
della prova ripetuta (finding `docs/findings/2026-11-10-S12r2-prova-ripetuta-lettore-studio.md`). Dove un margine
viene da una misura o da una soglia già depositata, la riga lo dice.

**Gli studi.** Gli stessi 47 studi di sviluppo (`analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv`),
letti per la terza volta. Il risultato vale per lo sviluppo e non è un giudizio. Gli 82 studi di giudizio restano
chiusi.

## Che cosa è già stato visto

- **Tutta la prova v0 e tutta la prova ripetuta:** le uscite del lettore sui 47 studi con lo schema v0 e v1, la
  curazione di Atlas degli stessi studi, i 145 e i 63 disaccordi con la loro causa, studio per studio.
- **Lo schema a elenco chiuso è stato disegnato conoscendo i 13 studi che non chiudevano** e il motivo di ognuno.
  È il rischio di adattamento ai 47 studi: il finding lo dichiara, e solo gli 82 studi di giudizio lo misurano.
- **La regola del contesto** (ADR-0029, decisione del PI del 2026-11-11) è scritta per nome del fattore di Atlas
  (`cell type`, `cell line`, `organism part`), senza elenco di studi. Prima del deposito l'agente ha misurato che
  cosa toglie: 2 confronti, tutti e due di `GSE75852`, che né la pipeline di oggi né il lettore v1 ritrovavano
  (`15-out.txt`). L'agente sapeva dal finding di S12r2 che la regola avrebbe toccato `GSE75852` e `GSE65335`; il
  confronto di `GSE65335` (`growth condition`) resta nel riferimento.
- **I termini di paragone sul riferimento nuovo** sono calcolati prima del deposito (`15-out.txt`, commit
  `df4e330`): stanno qui sotto come fatti, non come previsioni.
- **La prova di compilazione** (`12-out.txt`): il modello ha ricevuto i 47 schemi generati con un **messaggio
  neutro, senza il testo dello studio**, e ha scritto tabelle vuote. Tre forme dello schema provate; la terza è
  quella della carta. Nessuna uscita del modello sui testi degli studi con lo schema nuovo esiste prima di questo
  deposito.
- **Non calcolato prima del deposito:** ogni uscita del lettore con lo schema nuovo sui testi degli studi.

## Le misure

Le regole di lettura del riferimento sono quelle di S12r2 (tempo zero, fattore non scritto, fattore annidato,
«identica») più la regola del contesto. Un confronto di Atlas ha la marca `solo_contesto` quando rispetta la
definizione e il solo fattore che cambia ha uno dei tre nomi qui sopra.

| misura | tempo zero | solo contesto | fattore non scritto | fattore annidato | confronti di Atlas | uso |
|---|---|---|---|---|---|---|
| **principale** | fuori | fuori | non conta | regola di §5.3 | **95** | regola di esito |
| principale di S12r2 | fuori | dentro | non conta | regola di §5.3 | 97 | accanto (decisione del PI) |
| intera | dentro | dentro | non conta | differenza ordinaria | 93 | accanto |
| stretta | fuori | fuori | conta come differenza | regola di §5.3 | 84 | sensibilità, accanto |

(a) studi con partizione identica ad Atlas, su 47; (b) confronti di Atlas ritrovati con lo stesso verso, sul
denominatore della misura; (c) errori fra i confronti del lettore che Atlas non elenca e che si possono giudicare.

**Termini di paragone, misurati prima del deposito** (`15-out.txt`):

| | (a) | (b) principale, 95 | (b) su 97 | (b) intera, 93 | (b) stretta, 84 | (c) principale |
|---|---|---|---|---|---|---|
| pipeline di oggi (master S14) | 14/47 | 13/95 | 13/97 | 19/93 | 12/84 | 18/79 |
| lettore, schema v1 (S12r2, corsa 1) | 31/47 | 50/95 | 50/97 | 50/93 | 46/84 | 0/4 |

Lettore v1 meno oggi, (b) principale: +39,0 punti (IC95 +20,2, +59,4). Con lo schema v1 chiudono 34 studi su 47.

## Che cosa si corre

Vista: la vista v0, senza cambi (`analysis/audit/2026-11-09-lettore-studio/60-viste-v0.jsonl`, SHA-256
`2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e`). Cambiano lo schema delle uscite (uno per
studio, generato da `10-schema-per-studio.R`, forma 3 della carta) e il prompt (v2: dice la forma nuova e
nient'altro di nuovo sul compito). Prompt v2, adattatore v2 e script di lancio si committano prima del primo
invio.

Una sola configurazione, due corse: `mistralai/Mistral-Small-3.2-24B-Instruct-2506`, revisione
`95a6d26c4bfb886c58daf9d3f7332c857cb27b43`, `temperature = 0`, `repetition_penalty = 1,1`, uscite strutturate,
`VLLM_BATCH_INVARIANT=1`, `HF_HUB_OFFLINE=1`, `max_model_len = 65536`, `max_tokens = 24576`, contenitore di
produzione vLLM 0.20.2, solo `poddgx02`. Nessun altro modello.

**Studio non chiuso.** Uno studio è «non chiuso» quando l'uscita è oltre il contesto (`oltre_contesto`), troncata
(`troncata`), non valida (`non_valida`), oppure l'adattatore si ferma per `livello_assente`, `base_assente`,
`base_non_ammessa`, `livello_riservato`, `ruolo_incoerente` (nuovo: una colonna ha il ruolo `factor` e nessun
fattore la legge, o il contrario) o per un errore di `tf_tabella()`. Conta zero gruppi identici e zero confronti,
non si toglie. Nessuna tolleranza di forma: non esiste una misura «con la forma tollerata» in questa prova.

## Come si conta lo studio che chiude con gruppi sbagliati

Uno studio non chiuso è un errore che si vede: non dà confronti. Uno studio che chiude con gruppi sbagliati dà
confronti sbagliati senza avviso. Per questo si conta a parte, così:

1. **Per costruzione, senza lettura.** Ogni studio ha uno stato in S12r2 (schema v1, corsa 1) e uno in S12r3
   (corsa 1): `non chiuso`, `identica` (partizione identica ad Atlas), `diversa` (chiuso, partizione non
   identica). Si riporta la tabella 3 × 3 dei 47 studi. Le caselle che contano: `non chiuso → diversa` (i 13
   studi) e `identica → diversa` o `identica → non chiuso` (le **regressioni**).
2. **Con la lettura.** Ogni studio `diversa` si legge sui metadati di GEO. Vale **«gruppi sbagliati»** quando la
   prima causa della differenza è del lettore (modello, schema o vista). Vale «gruppi diversi, non errore» quando
   la prima causa è dei curatori (Atlas unisce livelli che GEO distingue, ignora una colonna, mette un campione
   nel gruppo sbagliato, tratta come repliche campioni diversi): le stesse categorie di S12r2. La lettura la fa
   l'agente, non è cieca, ed è audit interno.
3. **Che cosa si riporta per ogni studio con gruppi sbagliati:** quanti confronti il costruttore forma da quei
   gruppi (sono i confronti che entrerebbero in una corsa intera), quanti sono giudicati errore dalla misura (c),
   la causa e chi la può togliere.
4. **Nelle misure non cambia niente:** lo studio conta come non identico in (a), i suoi confronti contano in (b)
   e in (c) come quelli di ogni altro studio. Il conto a parte entra nella regola di esito col punto 4.

## Cancelli

- **K1. Riproduzione prima del cambio.** Il codice aggiornato, senza la regola del contesto, ridà studio per
  studio i numeri di S12r2: oggi 14/47 e 13/97; lettore v1 34 chiusi, 31/47, 50/97, 0/4. *Passato prima del
  deposito (`15-out.txt`).*
- **K2. Controllo positivo.** (i) In ognuna delle quattro misure, i gruppi e i confronti di Atlas dati allo
  strumento come uscita del lettore danno partizione identica in 47 studi su 47 e ritrovano tutti i confronti
  del denominatore; la marca `solo_contesto` vede il caso noto di `GSE75852`. *Passato prima del deposito.*
  (ii) L'adattatore v2 legge lo studio finto `GSE0` scritto nella forma nuova e ridà 6 gruppi e 7 confronti; per
  ogni motivo di «non chiuso» che l'adattatore può dare, un'uscita rotta apposta dà quel motivo.
- **K3. Copertura.** Ogni misura copre 47 studi su 47, per ognuna delle due corse.
- **K4. Le corse.** Ogni job gira su `poddgx02`, con `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` letti da
  `container-env.txt` (solo quelle due righe), con il prompt uguale per SHA-256 al file v2 committato, con i 47
  schemi uguali a quelli che il generatore committato produce dalla vista v0, con i 47 testi uguali alla vista
  v0 e con la revisione del modello fissata qui sopra. Le uscite si congelano con SHA-256 prima di ogni misura.
- **K5. Giudizio chiuso.** Nessuno script della sessione legge fattori, livelli, confronti o uscite di uno degli
  82 studi di giudizio.

## Previsioni

Tutte sul lettore con lo schema a elenco chiuso, Mistral-Small 3.2, **prima corsa**, misura principale (95
confronti) dove non è detto altro.

| | quantità | atteso | intervallo di rilevanza | perché |
|---|---|---|---|---|
| E1 | studi non chiusi, su 47 | 2 | 0-7 | la soglia depositata in S12r e in S12r2: oltre 7 lo schema va cambiato prima di ogni conclusione. Con lo schema v1: 13 |
| E2 | studi non chiusi per un valore senza voce, una mappa ambigua, una colonna o un valore non letterale | 0 | 0 | per costruzione: lo schema non li ammette. Se ne nasce uno, il generatore o vLLM non fanno ciò che la carta dice |
| E3 | uscite troncate (`finish_reason = length`) | 0 | 0-1 | misura senza modello: un solo studio (`GSE57945`, 322 campioni) può superare `max_tokens`, e solo se un fattore legge il titolo |
| E4 | studi fermi per `ruolo_incoerente` | 1 | 0-2 | giudizio motivato: è un vincolo nuovo fra due parti dell'uscita. Oltre 2 la tupla `columns` va ridisegnata prima di ogni conclusione |
| E5 | uscite identiche al carattere fra le due corse | 47 su 47 | 47 | misurato in S12r, S12r2 e S12p con questo modello su una GPU |
| E6 | (a) studi con partizione identica | 36 su 47 (77%) | 50-100% | la soglia di S12r: sotto il 50% «ordine» non è sostenibile. Schema v1: 31/47 |
| E7 | schema nuovo meno schema v1, (a), appaiato | +5 studi (+10,6 punti) | l'intervallo al 95% sta sopra 0 | giudizio motivato: se l'intervallo contiene lo 0, la prova non mostra che l'elenco chiuso migliora i gruppi |
| E8 | lettore meno oggi, (b), appaiato | +52 punti | l'intervallo al 95% sta sopra 0 | criterio del §5.6 della spec. Schema v1: +39,0 |
| E9 | schema nuovo meno schema v1, (b), appaiato | +13 punti (63/95 contro 50/95) | l'intervallo al 95% sta sopra 0 | come E7, per i confronti. La sensibilità di S12r2 con la forma tollerata dava 64/97 |
| E10 | (c) errori fra i non elencati | 5% | 0-10% | lo stesso intervallo di S12r2 (schema v1: 0 su 4). Più studi chiudono, più confronti si possono giudicare. Ogni errore si legge comunque |
| E11 | dei 13 studi non chiusi con lo schema v1, quanti chiudono | 13 | 10-13 | i motivi dei 13 (valore senza voce 8, forma delle voci 2, colonna o valore non letterale 2, condizione sulla colonna padre 1) sono forme che lo schema non ammette più; sotto 10 lo schema nuovo sposta il difetto invece di toglierlo |
| E12 | dei 13, quanti chiudono con **gruppi sbagliati** (lettura, causa del lettore) | 3 (`GSE46665`, `GSE56787`, `GSE147507`) | 0 | decisione del PI: nessuna soglia di errore accettata. **L'agente si aspetta che questa previsione sia smentita**: l'elenco chiuso non toglie gli errori di lettura. Con un valore sopra 0 ogni studio porta causa e rimedio al PI |
| E13 | regressioni: studi `identica` con lo schema v1 che ora sono `diversa` o `non chiuso` | 1 | 0-2 | giudizio motivato: la forma nuova (una colonna per fattore, tupla `columns`) può rompere uno studio che funzionava. Oltre 2 la forma va cambiata prima di ogni conclusione. Ogni regressione si legge |
| E14 | studi con un fattore con un livello per campione | 2 | 0-2 | intervallo di S12r2 (schema v1: 1). L'elenco chiuso obbliga a dare un livello a ogni valore di una colonna come `description` |
| E15 | studi con una base scritta senza campioni | 2 | 0-2 | intervallo di S12r2 (schema v1: 4, smentita). La forma nuova non lo impedisce |

**Per studio, senza intervallo.** Che cosa l'agente si aspetta per ognuno dei 13 studi che non chiudevano. Serve
a dire dopo che cosa è cambiato e quanto l'agente sapeva prevederlo; si riporta quante attese su 13 sono giuste.

| studio | perché non chiudeva (S12r2) | atteso con l'elenco chiuso |
|---|---|---|
| `GSE147507` | valori senza voce; la vista porta 77 campioni di più sotto-serie | chiude, `diversa`, gruppi sbagliati (variabile divisa su più colonne) |
| `GSE46665` | fattore letto da `description`, voci solo per i valori `_T0` | chiude, `diversa`, gruppi sbagliati (un livello per paziente) |
| `GSE56787` | tre fattori dalla sola colonna `tissue`, ognuno con voci parziali | chiude, `diversa`, gruppi sbagliati |
| `GSE57116` | valore «control» di `time` senza voce | chiude, `identica`; confronti non ritrovati (il fattore `time` ripete `treatment`) |
| `GSE57945` | valori senza voce in tre fattori; 322 campioni | chiude, `diversa` |
| `GSE59781` | voci con 4 valori ciascuna | chiude, `identica`, confronto ritrovato |
| `GSE60340` | valori senza voce in due fattori | chiude, `diversa`; Atlas usa un riferimento che non è un controllo |
| `GSE63816` | valore senza voce; voci col titolo scritto male | chiude, `diversa` |
| `GSE66207` | «not applicable» con una condizione sulla colonna del fattore padre | chiude, `identica`, confronti ritrovati |
| `GSE69597` | voci con più valori | chiude, `diversa` più fine (Atlas unisce livelli): non errore |
| `GSE71595` | fattore senza colonna di fonte | chiude, `identica` |
| `GSE83415` | valori che la colonna non contiene | chiude, `identica` |
| `GSE83687` | una voce su 14 mancante | chiude, `identica` |

**Come si giudica.** La stima con il suo intervallo al 95%: tutta dentro l'intervallo di rilevanza = confermata;
tutta fuori = smentita; a cavallo = indeterminata. Per i conti (E1-E5, E11-E15): dentro = confermata, fuori =
smentita.

## Regola di esito

La risposta è **sì** quando valgono tutte e cinque:

1. le due corse sono identiche al carattere in 47 studi su 47;
2. nella misura principale la differenza «lettore meno oggi» dei confronti ritrovati (b) ha l'intervallo al 95%
   sopra 0;
3. nella misura principale il lettore fa meglio di oggi anche in (a) e in (c), come stima;
4. ogni disaccordo del lettore ha una causa, e ogni causa del lettore ha chi la può togliere: **la vista o lo
   schema, con un rimedio nominato**. Un'unità la cui causa è la lettura del modello non ha chi la toglie: il
   modello è deciso (PI, 2026-11-10) e la prova ripetuta ha misurato che il modello più grande non la toglie.
   Con una sola unità così, o con un solo studio con gruppi sbagliati per lettura del modello, il punto 4 è no;
5. gli studi non chiusi sono al massimo 7 (E1).

In ogni altro caso la risposta è **no**. I punti 1-3 sono quelli della spec §5.6 e di S12r2. Il punto 4 è lo
stesso punto di S12r2 con la **lettura severa scritta prima** dei numeri: in S12r2 l'agente l'aveva scelta dopo.
Il punto 5 è la soglia già depositata, portata dentro la regola **[agente]**.

**Che cosa l'agente si aspetta dalla regola.** I punti 1, 2, 3 e 5 sì; il punto 4 no. Le 5 unità di S12r2 con
esito «modello» (`GSE57116`, `GSE75852`) non sono toccate dallo schema nuovo, ed E12 prevede 3 studi con gruppi
sbagliati. Un «no» per il solo punto 4 non dice che il lettore è peggiore di oggi: dice che restano errori di
lettura senza rimedio, e il PI vede quanti sono, in quali studi e che cosa producono. Le misure su 97, intera e
stretta si riportano accanto e non decidono. Con un sì o con un no il PI decide se si scrive il Piano 2.

## Che cosa si legge dopo le corse

Tutti i disaccordi, come in S12r2: studio non chiuso, partizione non identica, confronto del riferimento non
ritrovato, confronto del lettore giudicato errore. Ogni unità riceve una causa e chi la può togliere. Per ognuno
dei 16 studi che in S12r2 non chiudevano (13) o avevano una partizione non identica (3: `GSE44379`, `GSE50760`,
`GSE93624`), e per i 4 con soli confronti non ritrovati (`GSE112057`, `GSE65335`, `GSE75852`, `GSE77598`), il
finding dice che cosa è cambiato. La lettura la fa l'agente: è audit interno e non entra nell'articolo.
