# Revisione indipendente: rilettura di 38 schede (audit interno)

Sei un revisore indipendente. Leggi SOLO i file di questa cartella. Non aprire nessun altro file del computer
(niente repository, niente altre cartelle): un altro lettore ha già etichettato le stesse schede e tu non devi
vedere le sue etichette. Non usare la rete. Scrivi solo dentro `uscita/`.

## Il contesto in breve

Un modello linguistico (il «lettore») legge uno studio di espressione genica (GEO): il testo e la tabella dei
campioni. Scrive la **tabella dei fattori**: per ogni fattore del disegno il tipo (perturbation, state, time,
context, technical), le colonne lette, i livelli, il livello di base e l'assegnazione dei valori ai livelli. Le
altre colonne ricevono un ruolo (`uninformative`, `subject/donor`, `subject/sex`, `subject/age`, `subject/passage`...).
Un programma deterministico (il «costruttore») forma i gruppi e i confronti: due gruppi uguali in tutti i fattori
tranne uno, con uno dei due al livello di base; le colonne «subject» si confrontano come insiemi (insiemi disgiunti
tolgono il confronto). Il riferimento è la curazione di Expression Atlas («ATLAS»).

Lo stesso studio è stato letto 9 volte: `B0` (prompt di base) e `L1`-`L8` (lo stesso prompt con UNA frase
riscritta senza cambiare il senso). Una **scheda** è una lettura nuova (o più letture nuove con la stessa uscita)
che differisce da `B0` nella tabella dei fattori, nei gruppi o nei confronti.

## I file

- `schede/GSE*.txt`: un file per studio (24 studi). In testa lo studio (titolo, colonne con i valori distinti,
  fattori di Atlas), la legenda delle letture, gli errori di lettura già noti di `B0`, la scheda `BASE B0`, poi una
  o più `SCHEDA <id> | n letture: ...`. Ogni scheda mostra fattori, livelli, voci (valore → livello), campioni per
  livello, ruoli delle altre colonne, i confronti del lettore, l'esito dei confronti di Atlas (`uguale` = ritrovato),
  le unità di disaccordo, «rispetto a B0», lo stato degli errori di `B0` in quella lettura e, se la stessa tabella
  dei fattori era già stata letta in una sessione precedente (S12r4), l'etichetta di allora. Quell'etichetta è un
  punto di partenza, non l'esito: rileggi comunque la scheda e dissenti se serve.
- `schede-da-leggere.csv`: le 38 schede (id, studio, letture). Devi giudicarle tutte.
- `etichette-S12r4.txt`: le etichette di errore già usate per questi studi. Riusale quando l'errore è lo stesso.

## Che cosa scrivi per ogni scheda

Leggendo il testo dello studio, la tabella dei campioni, la lettura di `B0` e la lettura nuova:

1. **causa** della differenza, una fra:
   - `lettura del modello`: `B0` o la lettura nuova legge male il testo o la tabella (un fattore sbagliato, mancante
     o di troppo; un livello o una base sbagliati; un soggetto sbagliato);
   - `forma`: la lettura è la stessa (o è giusta), ma l'uscita è scritta in un modo che lo schema o il costruttore
     non legano (per esempio: un livello usato nelle voci manca dall'elenco dichiarato; una colonna ha ruolo factor
     ma nessun fattore la legge; il nome riservato scritto `not_applicable`);
   - `non errore`: le due letture sono diverse e tutte e due difendibili sul testo (per esempio una colonna
     equivalente, una scelta dei curatori).
2. **dove** sta l'errore di lettura che causa la differenza: `in B0`, `nella lettura nuova`, `in tutte e due`,
   `in nessuna`. Regole: causa `lettura del modello` ⇒ dove diverso da `in nessuna`; causa `forma` o `non errore` ⇒
   `in nessuna`.
3. **etichette** degli errori di lettura PRESENTI NELLA LETTURA NUOVA, separate da `;`, ognuna nella forma
   `GSE…:descrizione breve` (anche gli errori che `B0` ha già, se restano nella lettura nuova). Vuoto se la lettura
   nuova non ha errori di lettura. Con dove = `nella lettura nuova` o `in tutte e due` serve almeno un'etichetta.
4. **descrizione**: una o due frasi, con i fatti che hai visto (colonne, livelli, conti).

Giudica dai fatti della scheda, non dall'esito contro Atlas: una lettura può ritrovare i confronti e avere un
errore, o perderli senza errore. Se non sei sicuro, dillo nella descrizione e scegli comunque.

## Uscita

`uscita/26-letture-revisore.csv`, CSV con virgolette, intestazione
`scheda,studio,causa,dove,etichette,descrizione`, 38 righe, `scheda` identico all'id di `schede-da-leggere.csv`.

`uscita/note-revisore.md`: i casi dubbi, e l'elenco esatto dei file che hai letto.

Nel messaggio finale riporta: quante schede per causa, i casi dubbi, i file letti.
