# 2026-08-21 — S3: il metro concorda con se stesso?

Evidenza della sessione S3 dell'handout `docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md`.
Finding: `docs/findings/2026-08-21-S3-il-metro-concorda.md`.

| file | che cos'è |
|---|---|
| `00-previsioni.md` | le previsioni e la soglia di decisione, scritte **prima** del run; in coda la nota sul retest 1 contaminato |
| `C3-workflow-retest.js` | il workflow del retest 1: `2026-08-20-rilettura-194/C1-workflow-rilettura.js` con prompt e schemi byte-identici; cambiano solo i blocchi (da `args`) e il modello, fissato a Opus 5 come nel run originale |
| `C4-workflow-retest-congelato.js` | il retest 2: come C3, ma la cartella del materiale è **congelata al 19/08** (solo i file che esistevano al momento del run originale, fuori dal repo) |
| `SHA256-blocchi-letti.txt` | impronte dei 15 `blocco-XX.txt` letti (identici in tutti i run) |
| `25-cosa-hanno-letto.py` · `25-out-*.txt` | per ruolo e per run: tool usati e fonti toccate **oltre** il blocco; è la misura che ha scoperto la contaminazione del retest 1 |
| `*-retest1-contaminato.*` | retest 1 (`wf_62d20ef5-167`): risultato grezzo, verdetti, difetti, disaccordi, accordo per blocco, report. **11 agenti su 60** hanno letto le stringhe grezze per campione e i verdetti originali: misura un metodo diverso, non il test-retest |
| `*-retest2.*` | retest 2 (`wf_a0a37108-046`), ambiente congelato: **il test-retest vero**, su cui si valutano le previsioni |
| `20-consolida-retest.py` | dal JSON ai CSV (`<wf.json> <suffisso>`) |
| `30-accordo-metodo.py` | accordo originale–retest: grezzo, kappa con IC bootstrap, matrice 3×3, per blocco, per fascia di k, sulle coppie accusate, previsioni valutate (`<verdetti> <difetti> <suffisso>`) |
| `10-campione-umano.py` | estrae **20** delle 194 a caso (seme dichiarato nel file) e scrive le **schede cieche** in `umano/` + il modulo `umano/RISPOSTE.csv` |
| `40-accordo-umano.py` | quando `RISPOSTE.csv` è compilato: accordo umano–originale e umano–retest, su quanti gruppi |

## Le tre scelte dichiarate

1. **Retest su blocchi interi, e su tutti e 15.** Comporre un blocco nuovo coi venti
   estratti cambia il metodo (i critici vedono i verdetti del lettore di tutto il
   blocco, l'arbitro rilegge il blocco intero). Rifare i blocchi già letti tiene il
   metodo identico; rifarli **tutti** toglie anche la scelta di *quale* blocco, e
   costa ~35 minuti di macchina. I numeri si danno sulle 194.
2. **La lettura umana è su 20 schede cieche.** Le schede di `A0-schema-verificabile.R`
   portano in testa il verdetto del modello: qui sono rigenerate senza.
3. **L'ambiente va congelato, non solo il prompt.** Gli agenti hanno strumenti: nel
   retest 1 hanno trovato nella cartella del blocco file scritti dopo il run
   originale e li hanno usati. Un test-retest richiede lo stesso materiale
   *raggiungibile*, e lo si verifica dopo (`25-cosa-hanno-letto.py`), non lo si assume.
