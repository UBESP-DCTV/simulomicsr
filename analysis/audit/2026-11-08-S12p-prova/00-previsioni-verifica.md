# S12p, terza parte — verifica dei 318 difetti trovati dalla prima lettura: cancelli e previsioni

**Depositate:** 2026-11-08, prima che un lettore apra un pacchetto della verifica.
**Perché.** La prima lettura (`00-previsioni-lettura.md`, risultati in `70-out.txt`) giudica non confrontabili 318
confronti che il riferimento di S11 dà per puliti. I lettori vedevano le affermazioni dei modelli, che possono
orientarli. Il PI non legge a mano (2026-11-08): la conferma la fa una seconda lettura indipendente.

**Che cosa si legge.** 438 pacchetti (`80-verifica-pacchetti.R`, cartella `/home/user/S12p-verifica-20261108/`, fuori
dal repository; impronte in `81-manifesto-verifica.sha256`). Ogni pacchetto contiene **solo** il testo del confronto
(etichette, entità proposta, metadati dei campioni), **senza** affermazioni dei modelli e senza giudizi della prima
lettura. Identificativi nuovi, ordine nuovo (seme 20261110).

| gruppo | n | perché |
|---|---|---|
| i 318 confronti puliti nel riferimento, non confrontabili per la prima lettura | 318 | la misura |
| difetti noti del riferimento (non «non provati»), presi a caso (seme 20261110) | 60 | controllo positivo |
| falsi allarmi giudicati confrontabili dalla prima lettura, presi a caso | 60 | controllo dell'altro verso |

**Lettori.** Agenti di revisione interna, 15 lotti da 29-30 pacchetti, nuovi agenti (nessuno ha letto la prima volta),
scheda `SCHEDA.md` (copia `81-scheda-verifica.md`): le stesse regole della prima lettura, solo la domanda «il confronto
è confrontabile?». **Unità:** il confronto; intervallo di Wilson al 95%; kappa di Cohen con bootstrap sui confronti
(B = 2.000, seme 20261108).

## Cancelli

| # | cancello | come si verifica |
|---|---|---|
| V1 | 438 letture valide su 438 | script di raccolta |
| V2 | Controllo positivo: almeno l'80% dei 60 difetti noti giudicati non confrontabili (la stessa soglia di L2) | script di raccolta |
| V3 | Ogni lettore apre solo la scheda, il suo lotto e i suoi pacchetti, e scrive solo il suo file | transcript, `71-cosa-hanno-letto.py` |

## Previsioni

**Q1 — I 318 difetti ritrovati senza le affermazioni.** Quantità: quota dei 318 giudicati «non confrontabili» dalla
seconda lettura. **Atteso: 75%.** **Intervallo di rilevanza: da 70% a 100%.** Motivo (giudizio): sopra il 70% i
difetti della prima lettura si ritrovano senza l'aiuto delle affermazioni, con un tasso vicino a quello dei difetti
noti, e quelli ritrovati due volte possono entrare nel riferimento (decisione del PI). Sotto il 50% la prima lettura era
orientata dalle affermazioni, e i 318 non sono affidabili.

**Q2 — I confrontabili restano confrontabili.** Quantità: quota dei 60 falsi allarmi «confrontabili» per la prima
lettura che la seconda giudica «non confrontabili». **Atteso: 15%.** **Intervallo di rilevanza: da 0% a 25%.** Motivo
(giudizio): sopra il 25% i lettori cambiano idea anche nell'altro verso, e la differenza fra le due letture viene dal
lettore, non dalle affermazioni.

**Q3 — Accordo fra le due letture.** Quantità: kappa di Cohen fra prima e seconda lettura sui 438, con «non
confrontabile» contro «confrontabile o incerto». **Atteso: 0,6.** **Intervallo di rilevanza: da 0,6 a 1.** Motivo: la
rilettura delle 194 meta-analisi ha misurato un test-retest con kappa 0,78; sotto 0,6 l'accordo è troppo basso per
usare una sola lettura come riferimento.

## Che cosa segue

I confronti giudicati non confrontabili da **tutte e due** le letture sono i candidati al riferimento allargato. Il PI
decide se entrano nel riferimento; non legge nulla. Ogni conto futuro contro il riferimento allargato dichiara che questi
difetti sono stati cercati fra le accuse di Gemma e Mistral.

## Aggiunta (2026-11-08, dopo la raccolta della verifica e prima della lettura mirata)

Dei 310 confronti non confrontabili per tutte e due le letture, 45 hanno come unico difetto, in tutte e due, il tipo
`soggetti`. La scheda dei lettori non diceva che, per decisione 3 del PI (S12, 2026-11-08), una sovrapposizione
**parziale** di donatori, sesso o età è un avviso e non un errore (`PARZIALE_DONATORE`, `PARZIALE_SESSO`,
`PARZIALE_ETA_STADIO`); un lettore lo ha segnalato (lotto 07 della verifica). Una lettura mirata (`93-soggetti-pacchetti.R`,
2 agenti nuovi, stessi pacchetti senza affermazioni) classifica ciascuno dei 45 in: **disgiunti** (nessun donatore, o
nessun valore di sesso o di età, in comune fra i bracci: difetto, `DIVERSO_*`) o **parziali** (avviso: esce dai
difetti). Nessuna previsione con intervallo di rilevanza: la lettura applica una regola già decisa dal PI. Controllo:
tre confronti con donatori del tutto diversi per costruzione della lettura precedente (note concordi «donatori diversi»,
uno per paziente) devono risultare disgiunti.
