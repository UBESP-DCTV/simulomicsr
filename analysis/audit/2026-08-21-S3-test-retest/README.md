# 2026-08-21 — S3: il metro concorda con se stesso?

Evidenza della sessione S3 dell'handout `docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md`.
Finding: `docs/findings/2026-08-21-S3-il-metro-concorda.md`.

| file | che cos'è |
|---|---|
| `00-previsioni.md` | le previsioni e la soglia di decisione, scritte **prima** del run |
| `C3-workflow-retest.js` | il workflow del retest: `2026-08-20-rilettura-194/C1-workflow-rilettura.js` con prompt e schemi byte-identici; cambiano solo i blocchi (da `args`) e il modello, fissato a Opus 5 come nel run originale |
| `SHA256-blocchi-letti.txt` | impronte dei 15 `blocco-XX.txt` letti (identici a quelli del run originale) |
| `risultato-retest.json` | il risultato grezzo del retest (i 194 verdetti dell'arbitro) |
| `verdetti-retest.csv` · `difetti-retest.csv` | il retest consolidato come `verdetti-194.csv` / `difetti.csv` |
| `20-consolida-retest.py` | dal JSON ai due CSV |
| `30-accordo-metodo.py` | accordo originale–retest: grezzo, kappa con IC bootstrap, matrice 3×3, per blocco, per fascia di k, sulle coppie accusate |
| `10-campione-umano.py` | estrae **20** delle 194 a caso (seme dichiarato nel file) e scrive le **schede cieche** in `umano/` + il modulo `umano/RISPOSTE.csv` |
| `40-accordo-umano.py` | quando `RISPOSTE.csv` è compilato: accordo umano–originale e umano–retest, su quanti gruppi |

## Le due scelte dichiarate

1. **Retest su blocchi interi, e su tutti e 15.** Comporre un blocco nuovo coi venti
   estratti cambia il metodo (i critici vedono i verdetti del lettore di tutto il
   blocco, l'arbitro rilegge il blocco intero). Rifare i blocchi già letti tiene il
   metodo identico; rifarli **tutti** toglie anche la scelta di *quale* blocco, e
   costa ~35 minuti di macchina. I numeri si danno sulle 194.
2. **La lettura umana è su 20 schede cieche.** Le schede di `A0-schema-verificabile.R`
   portano in testa il verdetto del modello: qui sono rigenerate senza.
