# S12r6 — Il lettore dello studio con i modelli Claude via API: carta, cancelli e previsioni

Depositate il 2026-11-14, **prima di ogni corsa misurata**. Dopo il risultato non si cambiano. La prova è ordinata
dal PI (ADR-0030, aggiornamento 2026-11-14) ed è **di sola misura**: il progetto resta chiuso, la pipeline non
cambia, gli 82 studi di giudizio restano chiusi, «nessun Claude nella pipeline né nella validazione pubblicata»
resta scritto. Niente di questa prova entra nel deliverable o in un articolo.

**Unità:** lo studio. **Incertezza:** bootstrap sugli studi, B = 2.000, seme 20261114. I confronti fra un modello
Claude e Mistral-Small 3.2 nella stessa forma, e fra un modello Claude e la pipeline di oggi, sono appaiati sugli
studi.

**Gli studi.** Gli stessi 47 studi di sviluppo (`analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv`),
letti per la sesta volta. Il risultato vale per lo sviluppo e non è un giudizio.

## 1. Che cosa è cambiato rispetto all'ordine del PI, e perché

L'ADR-0030 dice «forma `B0` congelata». L'API di Anthropic non accetta lo schema `B0` come vincolo dell'uscita:
rifiuta `prefixItems` e `minItems` oltre 1, e dopo due riscritture equivalenti risponde «the compiled grammar is
too large» per 45 studi su 47 (`05-esplorazione/`: `varianti.py`, `quanti.py`). Il PI ha scelto il 2026-11-14 di
fare **tutte e due** le strade possibili:

- **Forma T, «schema `B0` come testo».** Sistema: il prompt v2, senza cambi
  (`analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md`). Utente: il testo dello studio, due righe
  vuote, la frase fissa `20-frase-schema.md`, lo schema `B0` dello studio in JSON compatto. L'API non vincola
  l'uscita. Un programma valida l'uscita contro lo schema `B0` originale (l'adattatore `B0` di S12r4, senza
  cambi): un'uscita non valida è uno studio non chiuso, senza seconda chiamata. Mistral non vedeva lo schema: lo
  subiva come vincolo. Qui il modello lo legge. **Non è la stessa forma di Mistral**, è la più vicina possibile.
- **Forma V, «schema v1 vincolato».** Sistema: il prompt v1, senza cambi
  (`analysis/audit/2026-11-10-S12r2-prova-ripetuta/21-prompt-v1.md`). Utente: il testo dello studio. L'API vincola
  l'uscita allo schema v1 (`20-schema-v1.json`, intero: compila sui quattro modelli, `05-esplorazione/probe_v1.py`).
  È la forma della prova ripetuta (S12r2), adattatore `A0` di S12r4.

Il testo dello studio è lo stesso nelle due forme (47 su 47 uguali al carattere) ed è la vista v0, senza cambi.

## 2. Che cosa è già stato visto

- **Tutte le prove di prima (S12r-S12r5):** le uscite di Mistral sui 47 studi in tutte le forme, la curazione di
  Atlas, ogni disaccordo con la sua causa, i 9 errori di lettura di `B0` più `GSE147507`. L'agente che scrive
  queste previsioni e che leggerà i disaccordi (Claude Fable 5, in Claude Code) le conosce. I modelli chiamati via
  API non ricevono niente di tutto questo: ricevono solo il prompt e il testo dello studio.
- **Prove di esplorazione con la chiave del PI, prima del deposito** (`05-esplorazione/`): conto dei token dei 47
  ingressi (nessuna uscita); prove di compilazione degli schemi con messaggio neutro o con `max_tokens = 1` (un
  token di uscita, non letto); **due uscite di Haiku sul testo di un solo studio, `GSE67812`**, con due riscritture
  dello schema `B0` vincolate dall'API (`crea.py`; uscite in `prova-V2-GSE67812.json` e `prova-V3-GSE67812.json`).
  Di quelle due uscite l'agente ha visto se erano valide per lo schema `B0` (la prima sì, la seconda no: ricontrollato
  con `jsonschema` prima del deposito) e non le ha misurate
  contro Atlas. Nessuna è nelle forme T o V.
- **La prova del percorso** (`23-lancia.py --prova`): un messaggio neutro («una tabella dei fattori vuota per
  `GSE0`»), senza il testo di uno studio, per Haiku e Fable nelle due forme.
- **I termini di paragone** qui sotto sono misure di prima, non previsioni.
- **Non esiste prima del deposito:** un'uscita di un modello Claude sul testo di uno studio nella forma T o V, e
  ogni uscita di Sonnet, Opus e Fable sul testo di uno studio.

## 3. Le misure e i termini di paragone

Le misure sono quelle della terza prova (S12r3), con lo stesso codice (`misura_forma()` di S12r4, caricata da
`aiuti-misura-r5.R`): (a) studi con partizione identica ad Atlas, su 47; (b) confronti di Atlas ritrovati con lo
stesso verso, misura principale su 95 confronti (accanto: 97); (c) errori fra i confronti del lettore che Atlas
non elenca e che si possono giudicare.

| | chiusi | (a) | (b) su 95 | (c) |
|---|---|---|---|---|
| pipeline di oggi (master S14) | | 14/47 | 13/95 | 18/79 |
| Mistral-Small 3.2, schema v1 vincolato (S12r2, corsa 1) | 34 | 31/47 | 50/95 | 0/4 |
| Mistral-Small 3.2, forma `B0` vincolata (S12r3, corsa 1) | 45 | 36/47 | 68/95 | 2/33 |

Errori di lettura di Mistral nella forma `B0`: 9 in 8 studi, 4 che costano gruppi o confronti (`GSE46665`,
`GSE57945`, `GSE60340`, `GSE49155`), più `GSE147507` trovato in S12r5. Nello schema v1: 5 unità in 2 studi
(`GSE57116`, `GSE75852`), più gli studi non chiusi.

## 4. Che cosa si corre

Quattro modelli: `claude-haiku-5-5`, `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-fable-5-1`. Due forme (T, V).
Due corse per modello e forma: **16 corse, 752 chiamate**. La misura principale è la corsa 1; la corsa 2 sta
accanto e misura la ripetibilità.

**Impostazioni, uguali per i quattro modelli** (`23-lancia.py`): `output_config.effort = "high"`; ragionamento di
default (il modello decide se e quanto ragionare; il testo del ragionamento non torna, i token sì); nessuna
`temperature` (l'API la rifiuta); nessun modello di riserva; `max_tokens = 64000`; flusso; 8 chiamate in
parallelo. Il modello che risponde deve essere quello chiesto.

**Regole della chiamata, scritte prima.**

1. Uno studio che ha ricevuto una risposta intera, con qualunque `stop_reason`, non si chiama una seconda volta in
   quella corsa.
2. Un errore di rete o del servizio senza risposta intera (429, 5xx, tempo scaduto, flusso interrotto) si
   ritenta, fino a 8 volte; poi la corsa si riprende dagli studi senza risposta.
3. Un errore 400 dell'API è della richiesta: lo studio è non chiuso e non si ritenta.
4. `stop_reason = max_tokens` è un'uscita troncata; `stop_reason = refusal` è un rifiuto. Tutti e due sono studi
   non chiusi.
5. Forma T: prima della validazione un programma toglie gli spazi ai bordi e **un solo** recinto di codice
   markdown che avvolge tutta l'uscita. Nessun'altra riparazione. Il testo com'è arrivato si conserva
   (`raw_api`) e si riporta quante uscite avevano il recinto. Forma V: nessuna estrazione.

**Studio non chiuso:** come in S12r3 e S12r4 (uscita non valida, troncata, oltre il contesto, motivi
dell'adattatore), più rifiuto ed errore 400. Conta zero gruppi identici e zero confronti, non si toglie.

**Ordine e spesa.** Prima Haiku (due forme, corsa 1): da quei token si calcola la spesa di tutta la prova. Il
tetto è **300 dollari** in tutto. Se la proiezione lo supera, l'agente si ferma e chiede al PI. Poi Sonnet, Opus,
Fable, poi le corse 2. Le uscite stanno in `analysis/p4-output/S12r6-claude/` e si congelano con SHA-256
(`23-uscite-sha256.txt`) prima di ogni misura. La chiave del PI sta solo in `.Renviron.local`, non si stampa e non
entra in nessun file del repository.

## 5. Cancelli

- **K1. Riproduzione prima del cambio.** Lo script di misura, sulle uscite congelate di Mistral, ridà: forma `B0`
  45 chiusi, 36/47, 68/95, 2/33; schema v1 34 chiusi, 31/47, 50/95, 0/4; oggi 14/47 e 13/95.
- **K2. Controllo positivo.** (i) Le uscite congelate di Mistral nella forma `B0`, avvolte in un recinto di codice
  e scritte nel formato del programma di lancio, danno gli stessi numeri di K1 (l'estrazione e il formato non
  cambiano la misura). (ii) Un'uscita rotta apposta (una graffa tolta; un valore fuori elenco) dà «non valida».
- **K3. Copertura.** Ogni corsa copre 47 studi su 47 con una riga per studio, e ogni misura copre 47 studi.
- **K4. Le corse.** I prompt, i due ingressi e lo schema v1 sono uguali per SHA-256 a quelli scritti in
  `23-lancia.py`; i 47 schemi dati come testo sono uguali a quelli contro cui l'adattatore `B0` valida; il modello
  che risponde è quello chiesto in 47 risposte su 47; frase fissa, programma di lancio e script di misura sono
  quelli del commit che precede la prima corsa; le uscite sono congelate con SHA-256 prima di ogni misura.
- **K5. Giudizio chiuso.** Nessuno script della sessione legge fattori, livelli, confronti o uscite di uno degli
  82 studi di giudizio.

## 6. Previsioni

Tutte sulla **corsa 1**, misura principale (95 confronti) dove non è detto altro. I valori attesi sono giudizio
motivato dell'agente: non esiste una misura di un modello Claude su questo compito. Ordine dei quattro numeri:
Haiku / Sonnet / Opus / Fable.

| | quantità | atteso, forma T | atteso, forma V | intervallo di rilevanza | perché |
|---|---|---|---|---|---|
| P1 | studi non chiusi, su 47 | 9 / 5 / 4 / 3 | 6 / 3 / 2 / 2 | 0-7 | la soglia depositata da S12r in poi. Mistral: `B0` 2, v1 13 |
| P2 | uscite non valide contro lo schema | 6 / 2 / 2 / 1 | 0 / 0 / 0 / 0 | T: 0-2; V: 0 | T: giudizio motivato, oltre 2 la forma «schema come testo» misura soprattutto la mancanza del vincolo. V: per costruzione, l'API vincola |
| P3 | rifiuti (`stop_reason = refusal`) | 0 / 0 / 0 / 1 | 0 / 0 / 0 / 1 | 0 | giudizio motivato: Fable ha misure di sicurezza in più e alcuni studi parlano di virus (`GSE147507`). Ogni rifiuto è un risultato da dire |
| P4 | uscite troncate | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 0 | Mistral scrive al massimo 2.895 token di uscita per studio; il limite qui è 64.000 |
| P5 | uscite con un recinto di codice | 0 / 0 / 0 / 0 | non si applica | 0-2 | la frase fissa lo vieta; oltre 2 la frase non è seguita |
| P6 | (a) studi con partizione identica | 31 / 36 / 38 / 39 | 33 / 37 / 39 / 39 | 24-47 | la soglia di S12r (50%). Mistral: `B0` 36, v1 31. Il massimo che Atlas permette è circa 41-43 |
| P7 | (b) confronti ritrovati, su 95 | 56 / 68 / 72 / 74 | 58 / 68 / 72 / 74 | vedi P8 | Mistral: `B0` 68, v1 50 |
| P8 | Claude meno Mistral nella stessa forma, (b), appaiato | −13 / 0 / +4 / +6 punti: nessun intervallo sopra 0 | +8 / +19 / +23 / +25 punti: Sonnet, Opus, Fable sopra 0, Haiku a cavallo | l'IC95 sta sopra 0 | se l'intervallo contiene lo 0 la prova non mostra che il modello Claude ritrova più confronti di Mistral in quella forma |
| P9 | Claude meno oggi, (b), appaiato | sopra 0 per i quattro | sopra 0 per i quattro | l'IC95 sta sopra 0 | criterio della spec §5.6 |
| P10 | (c) errori fra i non elencati | 3% | 3% | 0-10% | lo stesso intervallo di S12r2 e S12r3 |
| P11 | dei 4 errori di lettura di `B0` che costano, quanti presenti (predicati di S12r4) | 2 / 1 / 1 / 1 | non si applica | 0 | decisione del PI: nessuna soglia di errore accettata. **L'agente si aspetta che sia smentita** |
| P12 | dei 5 errori di lettura di `B0` che non costano, quanti presenti (predicati di S12r5) | 2 / 1 / 0 / 0 | non si applica | 0 | come P11 |
| P13 | studi con almeno un errore di lettura del modello che costa gruppi o confronti, dopo la lettura di tutti i disaccordi | 6 / 3 / 2 / 2 | 5 / 3 / 2 / 2 | 0 | come P11. Mistral `B0`: 5 studi (4 più `GSE147507`). **L'agente si aspetta che sia smentita** |
| P14 | studi con l'uscita identica al carattere fra le due corse | 15 / 15 / 15 / 15 | 15 / 15 / 15 / 15 | 47 | punto 1 della regola di S12r3. Senza `temperature = 0` l'agente si aspetta «no» per costruzione |
| P15 | studi con la stessa tabella dei fattori, gli stessi gruppi e gli stessi confronti fra le due corse | 38 / 41 / 42 / 42 | 38 / 41 / 42 / 42 | 43-47 | variabilità misurata: con una frase del prompt riscritta Mistral cambia la tabella in 5-9 studi su 47 (S12r4). Sotto 43 due corse uguali di Claude variano almeno quanto Mistral con il prompt riscritto |

**Per studio, senza intervallo** (i 4 errori che costano più `GSE147507`, forma T): `GSE46665` (sigle dei pazienti
come malattie) presente in Haiku, assente in Sonnet, Opus e Fable; `GSE57945` (sesso come fattore) presente nei
quattro; `GSE60340` (colonna del trattamento non vista) assente nei quattro; `GSE49155` (fattore doppio) assente
nei quattro; `GSE147507` (il tempo in due colonne, ne legge una) presente in Haiku e Sonnet, assente in Opus e
Fable. Sono le stesse attese di P11, scritte per studio. Si riporta quante attese su 20 sono giuste; uno studio
senza tabella dei fattori conta come attesa sbagliata. I primi 4 errori si contano con i predicati di S12r4.
`GSE147507` non ha un predicato: `24-misura.R` scrive per ogni corsa le colonne di fonte dei fattori
(`24-GSE147507-fonti.csv`) e l'agente giudica leggendo la scheda. L'errore è presente se il fattore tempo legge
una sola delle due colonne del tempo e i gruppi o i confronti cambiano per questo.

**Come si giudica.** La stima con il suo intervallo al 95%: tutta dentro l'intervallo di rilevanza = confermata;
tutta fuori = smentita; a cavallo = indeterminata. Per i conti: dentro = confermata, fuori = smentita.

## 7. Che cosa risponde la prova

Non c'è una regola di esito che apre un cancello: il progetto è chiuso e nessuna decisione è legata al risultato.
Per ogni modello e forma la prova dà quattro risposte, sì o no:

1. **Ritrova più confronti di Mistral-Small 3.2 nella stessa forma?** Sì quando l'IC95 della differenza appaiata
   in (b) sta sopra 0.
2. **Chiude gli studi?** Sì quando gli studi non chiusi sono al massimo 7.
3. **Legge senza errori che costano?** Sì quando nessuno studio ha un errore di lettura del modello che costa
   gruppi o confronti (P13 = 0).
4. **Due corse danno lo stesso risultato?** Sì quando tabella dei fattori, gruppi e confronti sono uguali in 47
   studi su 47 (P15 = 47). L'identità al carattere (P14) si riporta accanto.

La frase «un modello Claude legge gli studi senza errori» vale solo con quattro sì. **L'agente si aspetta il no
al punto 3 per tutti e quattro i modelli e il no al punto 4.**

## 8. Che cosa si legge dopo le corse

Tutti i disaccordi della corsa 1 delle 8 configurazioni: studio non chiuso, partizione non identica, confronto del
riferimento non ritrovato, confronto del lettore giudicato errore. L'unità di lettura è la scheda: uno studio con
una tabella dei fattori, gruppi e confronti dati; due configurazioni con la stessa chiave nello stesso studio
hanno la stessa scheda. Ogni scheda riceve una classe: non errore (scelta dei curatori), forma (schema o
validazione), vista, lettura del modello; e, per la lettura del modello, se costa gruppi o confronti. Una scheda
uguale a quella di Mistral nella stessa forma eredita la classe già scritta in S12r2-S12r5, e l'agente la
ricontrolla. I 9 errori noti di `B0` si contano con i predicati deterministici, anche dove non c'è disaccordo.

## 9. Limiti dichiarati prima

- **Chi legge.** La lettura dei disaccordi la fa un modello Claude (l'agente) su uscite di modelli Claude, e non è
  cieca: l'agente sa quale modello ha scritto ogni uscita. È audit interno.
- **Che cosa la lettura non vede.** Gli studi senza disaccordo con Atlas non si rileggono: un errore di lettura
  che non cambia gruppi e confronti, e che non è uno dei 9 noti, resta non visto (in S12r5 uno così è stato
  trovato in uno studio contato senza errori).
- **Atlas nei dati di addestramento.** La curazione di Expression Atlas è pubblica: un modello Claude può averla
  vista. La prova non lo può escludere. Lo stesso vale per Mistral.
- **Ripetibilità.** L'API non ammette `temperature = 0`, non fissa il seme e i modelli possono cambiare o essere
  ritirati: le uscite congelate sono la sola copia.
- **Forme non identiche a quelle di Mistral.** Forma T: lo schema è un'istruzione più un controllo, non un vincolo.
  In tutte e due le forme il ragionamento è acceso e Mistral non ne aveva.
- **Stessi 47 studi per la sesta volta**, con prompt e schemi scritti guardando questi studi e gli errori di
  Mistral, non quelli di Claude.
- **Una sola vista:** la vista v0 non cambia.
