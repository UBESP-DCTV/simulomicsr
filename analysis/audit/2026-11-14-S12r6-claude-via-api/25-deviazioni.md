# S12r6: deviazioni dalla carta, scritte quando sono successe

## 1. Il limite di spesa della chiave ha fermato le chiamate (2026-11-14T18:45:10Z)

Scritto il 2026-11-14 dopo il congelamento delle 8 corse 1 e **prima di ogni misura**.

- Alle 18:45:10Z l'API ha cominciato a rispondere 400 `invalid_request_error`: «You have reached your specified API
  usage limits. You will regain access on 2026-12-01 at 00:00 UTC». È il limite di spesa impostato sulla chiave del
  PI, non un errore della richiesta. La spesa a listino delle 8 corse 1 è 24,99 dollari (più le prove di
  esplorazione).
- Sette corse 1 erano già complete. Nella corsa 1 di Fable con lo schema v1 vincolato (`V-fable-corsa1`) tre studi
  non hanno avuto risposta: `GSE83415`, `GSE83687`, `GSE93624`. Il programma di lancio li ha scritti con
  `saltato = errore_400`, come dice la regola 3 della carta. Lo studio `GSE147507`, già in flusso, è arrivato intero.
- La regola 3 («un errore 400 è della richiesta: lo studio non è chiuso e non si ritenta») era scritta per una
  richiesta che l'API non accetta. Qui la richiesta è la stessa che l'API accetta per gli altri modelli.
- Le 8 corse 2 non sono partite.

**Che cosa si fa (decisione tecnica dell'agente, dichiarata):**

1. Le 8 corse 1 si misurano come sono. In `V-fable-corsa1` i tre studi contano come non chiusi (lettera della
   regola 3). Ogni numero di Fable con lo schema v1 si riporta con la nota «3 studi fermati dal limite di spesa».
2. Se il PI alza il limite o dà un'altra chiave: i tre studi si chiamano **una volta** con lo stesso programma, le
   stesse impostazioni e lo stesso ingresso (non hanno mai avuto una risposta: la regola 1 non è violata). Il file
   completato prende un altro nome (`V-fable-corsa1b`), il file di adesso resta com'è, e le due misure si riportano
   una accanto all'altra. Poi partono le corse 2.
3. Se il limite resta: la ripetibilità (P14, P15, punto 4 delle quattro risposte) non è misurata per nessun
   modello, e si dice.

## 2. La misura delle corse 1 (2026-11-14): una riga di stampa del programma di misura non funziona

`24-misura.R` è quello del commit `ed52296`, senza cambi. Nella corsa vera una riga di sola stampa (il commit del
programma stesso, `git log -1 --format=%h %cI`) dà `fatal: bad revision '%cI'`: `system2()` spezza l'argomento allo
spazio. La riga non entra in nessun numero e in nessun cancello. Non correggo il programma: per la carta il programma
di misura resta quello depositato prima delle corse. I cancelli K1, K3 e K4 passano (`24-out.txt`); il cancello K2
(prova a secco) è passato prima del deposito (`22-out.txt`).

La colonna `rilevanza` di P6 in `24-previsioni.csv` è scritta come quota (0,5106-1): è 24-47 studi su 47, come nella carta.

La spesa in `24-corse.csv` (25,06 dollari) applica a Haiku il prezzo oltre 100.000 token di ingresso dove vale; il conto
fatto a mano prima della misura dava 24,99.

## 3. Il PI ha alzato il limite di spesa: i tre studi completati e le 8 corse 2 (2026-11-14, dalle 19:31Z)

Scritto dopo il congelamento delle 8 corse 2 e del file completato, **prima di ogni loro misura**.

- Il PI ha portato il limite di spesa della chiave a 150 dollari («Limite di spesa portato a 150$, puoi fare altre
  prove»). Dalle 19:31Z circa l'API risponde di nuovo. Il tetto della carta (300 dollari) non cambia.
- **I tre studi di Fable con lo schema v1 vincolato** (`GSE83415`, `GSE83687`, `GSE93624`) sono stati chiamati una
  volta, come scritto al punto 1 (19:32-19:33Z, tre risposte `end_turn`). Programma: `23b-completa.py`, che importa
  `23-lancia.py` senza cambi (stessa richiesta, stesse impostazioni, stesso ingresso) e verifica lo SHA-256 del file
  di partenza, dell'ingresso, del prompt e dello schema. Il file completato è `V-fable-corsa1b.jsonl` (44 righe
  copiate da `V-fable-corsa1.jsonl`, 3 nuove); SHA-256 in `23b-uscita-sha256.txt`, log in `23-log/`. Il file
  `V-fable-corsa1.jsonl` resta com'è.
- **Le 8 corse 2** sono partite alle 19:33Z e sono finite fra le 19:34Z e le 19:37Z, 47 studi su 47 in ognuna.
  **Deviazione dall'ordine della carta:** la carta dice Haiku, poi Sonnet, Opus, Fable; le 8 corse 2 sono partite
  tutte insieme (8 chiamate in parallelo per corsa, come nella carta). L'ordine nella carta serviva alla proiezione
  della spesa, già fatta sulle corse 1. Nessuna chiamata ha avuto un errore del servizio (`tentativi = 1` dove il log
  lo scrive). Rifiuti nelle corse 2, dai log: Fable nella forma T `GSE147507` e `GSE71421`; Fable nella forma V
  `GSE71421`.
- Le 16 corse stanno in `23-uscite-sha256.txt` (le 8 righe delle corse 1 sono uguali a prima). Copia verificata di
  17 file in `/mnt/micron/simulomicsr-salvataggio/S12r6-claude-2026-11-14/`.

**Come si misura (decisione tecnica dell'agente, dichiarata prima della misura):**

1. `24-misura.R`, senza cambi, sulle 16 corse del registro: riscrive i file `24-*` (le righe delle corse 1 devono
   restare uguali a quelle del commit `98e259d`: lo verifico) e aggiunge la ripetibilità (P14, P15, punto 4).
   La misura principale resta la corsa 1 con `V-fable-corsa1` com'è (3 studi non chiusi).
2. `V-fable-corsa1b` non può stare nel registro: il programma accetta solo i nomi `corsa1` e `corsa2`. Si misura
   accanto con `24b-misura-1b.R`: esegue il testo di `24-misura.R` con **una sola riga sostituita** (la cartella di
   uscita e del registro, fuori dal repository), su un registro dove il file completato prende il posto di
   `V-fable-corsa1`. Le sue uscite si copiano qui col prefisso `24b-`. I due numeri di Fable con lo schema v1 si
   riportano uno accanto all'altro.
3. **Lettura.** La carta (§8) fa leggere i disaccordi della corsa 1. Le schede nuove dei tre studi completati le
   legge l'agente con le stesse regole; non hanno una revisione indipendente, e si dice. Per le corse 2 la carta non
   chiede una lettura: una scheda della corsa 2 uguale a una scheda già letta ne eredita la classe (è la stessa
   scheda); le schede nuove della corsa 2 si contano e, se l'agente le legge, lo scrive qui sotto prima di farlo.

## 4. La lettura delle schede nuove delle corse 2 e dei tre studi completati (2026-11-14, scritto prima di leggerle)

La misura delle 16 corse e la misura accanto (`24b-*`) sono fatte: i cancelli passano, le righe delle corse 1 sono
uguali a quelle del commit `98e259d`. Nelle 8 corse 2 e nel file completato ci sono 131 coppie studio-corsa con almeno
un disaccordo: 108 hanno una scheda già letta e ne ereditano la classe, **23 sono nuove (21 schede distinte in 14
studi)**. Per `GSE147507` ci sono altre 6 chiavi nuove senza disaccordo.

Il PI ha chiesto «chi sbaglia meno?». Una corsa sola per modello e forma non basta a rispondere, perché la
ripetibilità è bassa (25-41 studi su 47 con la stessa chiave fra le due corse). **Leggo quindi le 27 schede nuove**,
con le stesse regole delle corse 1 e con le quattro regole scritte dopo la revisione (`28-revisione.py`). Oltre la carta:

- la carta (§8) chiede la lettura delle corse 1; questa lettura è in più ed è dichiarata dopo i numeri delle corse 1;
- il materiale lo scrive `26b-materiale-nuove.R` (il testo di `26-materiale.R` con tre righe sostituite: l'elenco
  delle schede, la scelta delle schede, e il taglio dei testi lunghi portato da 70 a 400 caratteri);
- le classi stanno in `29-classi-nuove.csv`; i conti per le 16 corse e per il file completato in `29-conti.R`;
- la lettura è dell'agente, come le altre non è cieca al modello dopo l'unione con le corse, e **queste schede non
  hanno una revisione indipendente**. P13 resta giudicata sulle corse 1, come depositato.
