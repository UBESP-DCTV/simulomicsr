# S12p, quarta parte — l'errore a monte e il prompt nuovo: cancelli e previsioni

**Depositate:** 2026-11-08, prima di ogni calcolo di questa parte e prima di scrivere il prompt nuovo.
**Richiesta del PI (2026-11-08):** «Bisogna trovare un modo per non farlo sbagliare a monte»; poi «misura, ma poi dimmi
esattamente cosa dice il prompt. Forse basta cambiare quello. Prova anche quest'ultima soluzione».

**Riferimento per questa parte.** Il riferimento allargato: i 193 difetti di S11 più i 280 confermati da due letture
(`94-difetti-finali.csv`), 473 su 1.903; puliti 1.430. Non è cieco per Gemma e Mistral (i 280 sono stati cercati fra le
loro accuse), e il prompt nuovo è scritto dopo aver visto gli errori: **nessun numero di questa parte è una prova
cieca**. Serve a dire se le due strade possono funzionare; la prova vera andrà fatta su confronti nuovi.
**Unità:** il confronto; intervallo di Wilson al 95%; seme 20261108.

## A. La misura senza modello (`100-senza-modello.R`)

Per ogni confronto, i campi `characteristics_ch1` dell'H5 di ogni campione si dividono in coppie «chiave: valore» (una
virgola seguita da «chiave: » separa due coppie), più `source_name_ch1` come chiave a sé. Per ogni chiave il codice
confronta gli insiemi di valori dei due bracci: uguali, in parte comuni, senza valori comuni.
- **Chiavi escluse**, per costruzione e non per elenco: le chiavi i cui valori sono diversi in ogni campione dei due
  bracci (identificativi), e le chiavi di replica (il nome contiene «replicate», «rep», «batch», «sample», «id»).
- **Chiave dell'entità**: una chiave diversa fra i bracci i cui valori del trattato contengono una parola dell'entità
  proposta o dell'etichetta del trattato (dopo minuscole e senza punteggiatura). Si esclude dal giudizio.
- **Accusa senza modello**: almeno una chiave non esclusa con insiemi diversi fra i bracci, oltre alla chiave
  dell'entità; oppure la tecnica dell'H5 diversa (`.s2b_tecnica_h5()`).
- **Braccio mescolato**: almeno una chiave non esclusa (e non dell'entità) con più di un valore dentro lo stesso
  braccio.

| # | quantità | atteso | intervallo di rilevanza | motivo |
|---|---|---|---|---|
| A1 | difetti presi dall'accusa senza modello, su 473 | 55% | da 70% a 100% | giudizio: sopra il 70% il confronto per codice vede da solo la maggior parte dei difetti, e il disegno «il codice confronta» merita di essere scritto |
| A2 | puliti accusati senza modello, su 1.430 | 20% | da 0% a 10% | giudizio: sotto il 10% il codice accusa meno di Gemma (9,7% sul riferimento allargato); sopra, il parsing da solo non basta |
| A3 | difetti con un braccio mescolato, su 473 | 60% | — (descrittiva) | dice quanti difetti nascono da bracci costruiti male |
| A4 | puliti con un braccio mescolato, su 1.430 | 25% | — (descrittiva) | il confronto con A3 dice se il braccio mescolato distingue i difetti |
| A5 | confronti con almeno 2 chiavi strutturate in ogni campione | 70% | — (descrittiva) | copertura: dove il dato non è strutturato il codice non vede niente |

## B. Il prompt nuovo per Mistral (`inst/prompts/stage2b-v2.md`)

Cambia **solo il prompt**: schema, regola, tabella degli esiti, ingresso e configurazione restano quelli della prova.
Il prompt v2 cambia due punti, le due cause trovate: (1) la malattia o la condizione dei donatori scritta come agente;
(2) la voce aperta «altre differenze». Nessun esempio preso dai confronti del deliverable. Stesso lancio (`poddgx02`,
4 GPU, `VLLM_BATCH_INVARIANT=1`, cascata di recupero), solo Mistral.

| # | quantità | v1 (misurato) | atteso v2 | intervallo di rilevanza | motivo |
|---|---|---|---|---|---|
| B1 | puliti accusati, su 1.430 | 700 | 300 | da 0 a 40 | il cancello di ADR-0028; sopra 40 il prompt da solo non chiude il passo |
| B2 | difetti presi, su 473 | 451 | 420 | da 317 a 473 | stessa proporzione del cancello (130 su 193 = 67%) |
| B3 | confronti con `CONDIZIONE_CON_AGENTE` | 347 | 50 | da 0 a 35 | giudizio: sotto il 10% di v1 il prompt ha tolto la causa; sopra, la causa resta |
| B4 | confronti con `ALTRA_DIFFERENZA` | 707 | 300 | da 0 a 70 | giudizio: lo stesso, 10% di v1 |
