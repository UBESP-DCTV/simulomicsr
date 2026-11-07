# S10, il rilevatore dei confronti mal appaiati: cancelli e previsioni

Depositato il 2026-11-07, prima di ogni calcolo sui 1.903 confronti e prima di leggere le righe di `difetti.csv` oltre le
quattro citate nell'handout. Dopo il risultato questo file non cambia.

## Oggetto

- Deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d` (194 meta-analisi).
- I 1.903 confronti poolati: `analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds`, elemento `tenuti`.
- Il riferimento: `analysis/audit/2026-08-20-rilettura-194/difetti.csv`, 97 righe, 94 coppie (gruppo, studio), 199 confronti.
- Gli ingressi della chiave di ogni confronto: `analysis/audit/2026-11-07-S9-greche-e-corsie/20-ingressi.rds` (S9).
- La regola corretta: `10-regola-v2.R`, congelata con questo commit. Quattro varianti cumulative, ognuna cambia una cosa:
  - **V0** la regola di produzione `.rp_row_defect()`, con gli ingressi veri catturati da `20-ingressi-regola.R`;
  - **V1** V0 + traduzione delle lettere greche (insieme G e traduzione della S9) nelle etichette e nei token dell'entità;
  - **V2** V1 + soglia: almeno un agente in più nel trattato dopo aver tolto l'entità del gruppo (definizione in testa al file);
  - **V3** V2 + regola nuova `materiale_diverso`: i due bracci dichiarano sistemi biologici senza uno in comune.
- `R/stage3-row-pairing.R` e tutto `R/` non cambiano.

## Decisioni del PI (2026-11-07, prima della misura)

1. **N = 85.** Se la regola V3 dà più di 85 falsi allarmi sui 1.704 confronti puliti, la regola è dichiarata non
   recuperabile: la sessione chiude qui, la lettura dei falsi allarmi (S11) e il passaggio in produzione (S12) non si
   aprono, il difetto va nei Methods. 85 è il 5% di 1.704.
2. **Lettura a blocchi.** Se i falsi allarmi superano 150, la lettura si divide in sessioni da al massimo 150.

## Definizioni

- **Confronti difettosi (D).** I confronti dei 1.903 che una riga di `difetti.csv` nomina come colpevoli. Si costruiscono
  in `30-riferimento.*`: una coppia con un solo confronto si aggancia da sola; per le altre un parser legge le etichette
  citate nei cinque formati (`'…'`, `«…»`, `"…"`, backtick, più confronti in una riga), con le greche tradotte; ciò che il
  parser non chiude lo attribuisco io leggendo la riga, e scrivo il motivo. Il testo dopo «a fronte di» nomina un
  confronto di paragone, non il colpevole. **Il conto (agganciati dal parser, a mano, non agganciabili) si scrive in
  `30-conto.txt` e si committa prima di `40-misura.R`.**
- **Puliti (1.704).** I confronti delle coppie (gruppo, studio) che `difetti.csv` non accusa. Il valore N vale qui.
- **Altri negativi.** I confronti delle 94 coppie accusate che nessuna riga nomina. Il loro esito si riporta a parte e va
  nell'elenco per la lettura.
- **Sensibilità** = confronti difettosi segnalati / D. **Misura secondaria**: segnalati fra i 199 confronti delle coppie accusate.
- **Famiglie**: quelle di `30-consolida.py` (funzione `famiglia()`), sulla categoria della riga.
- **Incertezza.** Unità = studio. Bootstrap degli studi, B = 2000, seme 20261107, percentili 2,5 e 97,5. La regola di N
  si applica al conteggio, che è un censimento di tutti i 1.704 confronti.

## Cancelli

| # | cancello | passa se |
|---|---|---|
| C1 | manifesto SHA-256 del deliverable, a inizio e a fine sessione | `VERIFICA OK` entrambe le volte |
| C2 | riproduzione | (a) 1.903 confronti su 1.903 arrivano alla regola di riga una volta sola, con esito "" in produzione e in V0; (b) con gli ingressi dello script di agosto la regola di produzione segnala 2 confronti |
| C3 | copertura | 97 righe su 97 hanno uno stato nel riferimento, e il conto è committato prima della misura; 1.903 su 1.903 hanno un esito per V0-V3 |
| C4 | controlli, prima della misura (`20-controlli.csv`) | V3 segnala `GSE97744` «Circulating macrophage + IFN-γ and LPS» e `GSE210984` «MSC iPSC-derived TGF-β 21 days»; tace su `GSE139963` «TGF-β1» e su `GSE210984` «MSC Primary Culture TGF-β 14 days» |
| C5 | codice di produzione intatto | `git diff --stat R/` vuoto a fine sessione |

## Previsioni

| # | quantità | atteso | intervallo di rilevanza e motivo |
|---|---|---|---|
| P1 | falsi allarmi di V3 sui 1.704 puliti | 45 | ≤ 85, la soglia del PI. Sopra, la regola non è recuperabile |
| P2 | sensibilità di V3 sui confronti difettosi D | 30% | [20%; 50%]. **Giudizio mio**: sotto il 20% i Methods direbbero che il rilevatore vede una piccola minoranza dei difetti; sopra il 50% che ne vede la maggior parte. Dentro, la frase è «una parte» |
| P3 | guadagno per correzione | V1 aggiunge al massimo 3 confronti difettosi a V0; V2 aggiunge più di V1 e più di V3 | una correzione che aggiunge 0 difetti e almeno un falso allarme non va in produzione (S12) |
| P4 | casi dell'handout che restano invisibili | V3 tace su `GSE139963` «Hypoxia + TGF-β1» (l'ipossia non è un agente per i resolver) e su `GSE240476` «TGFB+AR» (AR ha due caratteri) | se V3 li segnala, la regola fa una cosa che non ho capito: si spiega prima di andare avanti |
| P5a | record_id dei run v9 trovati nel master vecchio | ≥ 99% | sotto, la misura P5 usa il master sbagliato e non vale |
| P5b | record agganciati alle righe override con campioni diversi fra master vecchio e master del deliverable | 3% | [0%; 1%]. **Giudizio mio**: sopra l'1% l'aggancio per `record_id` va corretto prima del calcolo che applica le correzioni (S13) |
| P5c | confronti del deliverable con un campione trattato che ha ricevuto un nome da un record con contenuto diverso | 5 | 0 = il deliverable non ne risente. Da 1 in su il PI decide come correggere l'aggancio |
| P5d | record agganciati alle righe override con campioni diversi o assenti nel master rifatto da zero (S14) | 30% | [0%; 1%]. **Giudizio mio**: sopra l'1% le tabelle vanno riagganciate o rigenerate prima del raggruppamento sul re-run, e la scelta è del PI |

## Che cosa non si fa

- Non si leggono i falsi allarmi: si produce l'elenco e il numero (`40-falsi-allarmi.csv`).
- Non si cambia la regola dopo questo commit. Se un controllo C4 fallisce, ci si ferma e si spiega.
- Non si modifica `difetti.csv`: le attribuzioni a mano stanno in un file a parte.
