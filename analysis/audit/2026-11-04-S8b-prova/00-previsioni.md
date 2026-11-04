# La prova prima del sì o no sul re-run completo (S8b): cancelli e previsioni

Scritto il 2026-11-04, prima di ogni sottomissione. Dopo il risultato questo file non cambia. Decisione del PI: finding `2026-11-04-S8-re-run-decisione`.

**Oggetti.** Deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`, Stadio 3 `analysis/p4-output/20260818T110906Z-stage3-v16-7f986159`,
master `analysis/p4-output/A3-stage{1,2}-master-innestato.jsonl`. Nessuno di questi file cambia: i master della prova sono file nuovi `analysis/p4-output/S8b-*`.

## Il disegno

**Campione.** 2.000 studi a caso semplice fra i 21.828 mai rigenerati e 300 a caso fra i 2.566 già rigenerati. Seme 20261104. Lista congelata con SHA-256 prima della sottomissione.

**Una sola variabile.** Nei master della prova entrano solo i 2.000 studi nuovi. I 300 servono solo al confronto e non entrano, quindi lo Stadio 3 cambia solo per i 2.000.

**Configurazione.** Identica ad A3: `VLLM_BATCH_INVARIANT=1`, nodo `poddgx02`, Stadio 1 in blocchi da 10.000 con gli stessi outlier, Stadio 2 con `tiered_max_tokens`. Recupero Stadio 1: 1.2/4096/8192, poi 1.3/8192/16384, poi 1.4/8192/16384. Recupero Stadio 2: tetto 12 trattati per blocco, `rep_pen` 1,2, `max_tokens` 32768.

**Catena.** Stadio 1 → recupero → innesto → input Stadio 2 → Stadio 2 → recupero → assemblaggio → innesto → re-cluster intero con 8 processi → misura. Il pooling non gira di notte.

**Che cosa conta come arrivo.** Uno studio dei 2.000 che nello Stadio 3 della prova ha almeno una coppia in una delle 194 chiavi del deliverable. È un limite superiore degli ingressi veri, perché nel run di agosto solo una parte degli arrivi è stata poolata.

**Applicazione della regola del PI.** Scala: 21.828 / 2.000 = 10,914. IC esatto di Clopper-Pearson sugli studi.

1. Se l'IC degli arrivi scalati sta tutto sotto 50: la risposta è **no**.
2. Altrimenti eseguo il re-pool (circa 1,6 h, decisione tecnica sotto le 4 ore) e applico la regola agli ingressi veri: IC tutto sotto 50 no, IC tutto sopra 250 sì, altrimenti decide il PI.

**Che cosa la prova non vede.** Gruppi nati da due studi nuovi insieme, perché il campione è il 9,2% dei 21.828. Fusioni a pieno regime. Rigenerazione delle tabelle di correzione dei nomi: si agganciano ai `record_id` del run vecchio, quindi un record nuovo può perdere la correzione, e la stima può essere bassa. La correttezza degli ingressi. Un nodo diverso.

## Cancelli

1. Il manifesto SHA-256 del deliverable passa, all'inizio e alla fine.
2. Il campione è congelato: 2.000 e 300 studi, insiemi disgiunti, tutti nel master. Le righe di input sono identiche all'input di produzione.
3. Il flag è arrivato al processo: `container-env.txt` contiene `VLLM_BATCH_INVARIANT=1` in tutti i job.
4. Lo strumento di confronto vede le differenze. Negativo: sui 300 studi il master vecchio senza flag differisce da A3. Positivo: una differenza piantata a mano viene vista.
5. L'input Stadio 2 degli studi fuori dal campione è byte-identico a quello di A3. Se non lo è, il build dipende da stato globale e la prova misura due cose.

## Previsioni

| # | quantità | atteso | intervallo di rilevanza | da dove viene l'intervallo |
|---|---|---:|---:|---|
| Q1 | record Stadio 1 con `raw_output` identico ad A3, nei 300 studi | 100% | ≥ 99% | variabilità misurata: 997 su 997 in agosto, limite inferiore 99,6% |
| Q2 | studi con record Stadio 2 identico ad A3, nei 300 | 95% | ≥ 90% | giudizio: sotto il 90% un secondo run sposta di nuovo i gruppi. Riferimento senza flag: 18,4% di studi identici |
| Q3 | arrivi fra i 2.000 | 8 (circa 87 scalati) | da 5 a 23 (da 50 a 250 scalati) | soglie del PI, divise per 10,914 |
| Q4 | studi dei 2.000 senza coppie in A3 che ne ottengono una, fra quelli senza coppie | 3% | da 1% a 10% | giudizio: misura la riserva di studi che le regole fermano oggi |
| Q5 | studi non rigenerati con chiavi cambiate nello Stadio 3 | 0% | ≤ 1% | giudizio: sopra l'1% le fusioni muovono studi non toccati e la scala non vale |
| Q6 | ore dello Stadio 2 per il job della prova | 4,5 | da 3 a 7 | sopra 7 ore il costo del re-run supera la stima alta di 70 ore |

Unità: lo studio. Intervalli di confidenza esatti, seme 20261104.

**Margini.** Q2, Q4 e Q5 usano un giudizio motivato. Lo dico al PI nel riassunto.
**Se Q2 cade sotto il 90%:** il sì perde il vantaggio principale, cioè un risultato ripetibile. La risposta torna al PI anche se gli ingressi superano 250.

## Esecuzione

Script `50-notte.R`, lanciato con `setsid`. Ogni passo scrive un file di stato e si ferma se un caso di accettazione fallisce. Il processore resta sotto il 90%: il re-cluster usa 8 processi. La temperatura si legge a ogni controllo.
