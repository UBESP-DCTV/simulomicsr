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
