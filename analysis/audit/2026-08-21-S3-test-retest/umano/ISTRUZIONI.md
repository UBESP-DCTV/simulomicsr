# Lettura cieca di 20 meta-analisi — istruzioni

Seme dell'estrazione: **20260821** (`10-campione-umano.py`). Le 20 sono estratte a
caso dalle 194; l'ordine dei file e' rimescolato. **Il verdetto del modello non e'
scritto da nessuna parte in questa cartella**: non aprire `verdetti-194.csv`,
`INDICE-194.csv`, `quadro-194.csv`, i `disaccordi-*.csv` né i §3–§4 del finding `docs/findings/2026-08-21-S3-il-metro-concorda.md` prima di aver finito.

Per ogni scheda `NN-nome.txt`, compila la riga corrispondente di `RISPOSTE.csv`:

| colonna | che cosa scrivere |
|---|---|
| `verdetto_parte1` | `corretta` / `difettosa` / `incerta`, letto sulla **PARTE 1** (le etichette, come il modello) |
| `studi_difettosi_parte1` | gli `GSE` che accusi, separati da `;` (vuoto se nessuno) |
| `verdetto_dopo_parte2` | lo stesso verdetto DOPO aver letto le stringhe grezze, **solo se cambia** (altrimenti vuoto) |
| `note` | libere |

Le regole sono quelle del modello (`C1-workflow-rilettura.js`, blocco REGOLE): una
meta-analisi e' *corretta* se tutti i confronti poolati misurano lo stesso
contrasto (stessa entita', stessa direzione, stesso tipo di controllo) e i due
bracci di ciascun confronto sono appaiati; *difettosa* se almeno un confronto ha
un difetto leggibile nell'etichetta; *incerta* se le etichette non bastano.
Nei caso-controllo di malattia i soggetti diversi sono il disegno, non un difetto.

Quando hai finito (anche con meno di 20: il conteggio e' su quante ne hai lette):

    python3 analysis/audit/2026-08-21-S3-test-retest/40-accordo-umano.py
