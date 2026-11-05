# Il re-run dei due passi col modello (S14, prima parte): cancelli e previsioni

Scritto il 2026-11-05, prima di ogni sottomissione. Dopo il risultato questo file non cambia. Decisione del PI: finding `2026-11-05-S8b-prova-re-run`, «Decisioni del PI», e frase di apertura «solo i due passi col modello» (handout S14, punto 4).

**Oggetti.** Input `analysis/input/archs4-human-stage1-input-v2.jsonl` (508.037 record). Uscite, tutte nuove: `analysis/p4-output/S14-stage1-master.jsonl` e `analysis/p4-output/S14-stage2-master.jsonl`. Deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`, che non cambia. I master di agosto e della prova non cambiano. La sessione si ferma ai due master. Raggruppamento, pooling e annotazione restano dopo S12 e dopo l'assegnazione dei ruoli per nome.

## Il disegno

**Da zero, un solo run, nessun innesto.** Nessun record viene dai run precedenti. I run precedenti servono solo come riferimento nel confronto.

**Configurazione.** Identica ad agosto e alla prova: `VLLM_BATCH_INVARIANT=1`, solo `poddgx02`, due job da 4 GPU alla volta. Stadio 1 con mescolamento seme 42, outlier sopra 3.500 caratteri a parte, blocchi da 10.000. Recupero Stadio 1: 1.2/4096/8192, poi 1.3/8192/16384, poi 1.4/8192/16384. Stadio 2 con `tiered_max_tokens`. Recupero Stadio 2: tetto 12 trattati per blocco, `max_tokens` 32768, `rep_pen` 1,2. Se restano record: 1,3 e poi 1,4, sugli stessi blocchi (`CLAUDE.md` §6).

**Scelte tecniche, tutte senza effetto atteso sui record.**

1. **Lo Stadio 2 va in 12 parti, non in 2.** Le parti sono bilanciate per caratteri su un ordine casuale degli studi, seme 20261105. Nella prova le due parti hanno richiesto 5,6 e 8,2 ore, quindi un job è rimasto fermo. Con 12 parti la coda riempie i due posti e una caduta del nodo costa meno.
2. **Il master dello Stadio 1 ha l'ordine dei record del master di maggio.** L'ordine entra nel prompt dello Stadio 2, perché determina l'ordine dei campioni dentro lo studio. Con un altro ordine gli input cambierebbero senza motivo e il confronto con agosto non varrebbe. Non è un innesto: da quel master viene solo l'ordine.
3. **Il costruttore del recupero prende `series_id` dall'input.** La copia della prova la prendeva dal modello, come il build prima del 16 agosto. Un campione con la sigla alterata uscirebbe in silenzio dallo studio recuperato. Aggiungo un caso di accettazione: i campioni dello studio nel recupero coincidono con quelli dell'input.
4. **La prova di invarianza non gira a parte.** La sostituisce il cancello 5, dentro il run, più la prova breve qui sotto. Motivo: la prova della sera del 2026-11-04 ha già confrontato 10.220 record e 300 studi con lotti diversi, e il cancello 5 ne confronta circa 8.000 sui primi due blocchi prima di spendere il resto. Costo aggiuntivo: nessuno. La prova separata costerebbe circa 2 ore e riguarderebbe 1.000 record. **Questa scelta cambia una tappa scritta nell'handout, quindi la porto al PI insieme agli script.**

**Prova breve, prima di tutto.** 200 record dello Stadio 1 e 12 record dello Stadio 2, presi a caso fra quelli già rigenerati, seme 20261105. Verifica il percorso del codice nuovo. Risultato in `20-prova-breve.txt`. Non è una stima.

**Riferimento per il confronto.** Gli 8.566 studi già rigenerati: i 2.566 di agosto (`A3-*`) e i 6.000 della prova (`S8b-*`). Per lo Stadio 1 sono 211.484 record attesi (86.898 + 124.586). I 300 studi rigenerati due volte valgono una volta sola, col dato di agosto.

**Che cosa questa sessione non vede.** L'identità con un run precedente prova la ripetibilità, non la correttezza dei record. Un solo nodo. Non misura che cosa cambia nei gruppi: quella è la parte dopo S12. Non dice nulla sulle tabelle dei nomi.

## Le tabelle dei nomi (handout S14, punto 7)

**Non si rigenerano in questa sessione.** Non entrano nei due master: agiscono solo nel raggruppamento, che qui non gira. Il costo non è misurato. La decisione spetta alla parte di S14 dopo S12, e serve prima la misura di S10: su tutte le righe delle tabelle, quante puntano a un gruppo con un contenuto diverso nel run nuovo. Questa misura richiede il master di questa sessione, quindi diventa possibile alla fine.

## Cancelli

1. Il manifesto SHA-256 del deliverable passa, all'inizio e alla fine. Gli SHA-256 dei master di riferimento non cambiano (`10-riferimenti-inizio.txt` e `90-riferimenti-fine.txt`).
2. Copertura. I blocchi dello Stadio 1 contengono tutte e sole le 508.037 righe di input, senza duplicati. La raccolta non ha record estranei o duplicati. Il master dello Stadio 2 ha un record per studio e nessuno studio di input senza record, salvo un elenco scritto.
3. Configurazione. `container-env.txt` contiene `VLLM_BATCH_INVARIANT=1` in tutti i job. `sacct` dà `poddgx02` per tutti i job. Prompt, schema e `generation.json` coincidono byte per byte con i bundle della prova corrispondenti.
4. Lo strumento di confronto vede le differenze. Negativo: sui record di riferimento il master vecchio senza flag differisce. Positivo: una differenza piantata a mano viene vista.
5. Identità sui primi job, prima di spendere il resto. Sui primi due blocchi dello Stadio 1: almeno il 99,9% dei record validi di riferimento ha `raw_output` identico. Sulla prima parte dello Stadio 2: almeno il 98,8% degli studi di riferimento. Sotto queste soglie la catena toglie dalla coda tutti i job e si ferma.

## Previsioni

Unità: il record per Q1 e Q3, lo studio per le altre. Intervalli di confidenza esatti di Clopper-Pearson. Nessuna estrazione casuale nelle stime, quindi nessun B. Seme 20261105 per le parti e per la prova breve.

| # | quantità | atteso | intervallo di rilevanza | da dove viene l'intervallo |
|---|---|---:|---:|---|
| Q1 | record Stadio 1 con `raw_output` identico al riferimento, su circa 211.484 | 100% | ≥ 99,9% | variabilità misurata: nella prova 10.220 su 10.220, limite inferiore 99,964% |
| Q2 | studi con record Stadio 2 assemblato identico al riferimento, su 8.566 | 100% | ≥ 98,8% | variabilità misurata: nella prova 300 su 300, limite inferiore 98,8% |
| Q3 | campioni senza record valido dopo il recupero dello Stadio 1 | 11 | ≤ 51 | atteso: 3 su 134.806 della prova. Giudizio: 51 è lo 0,01% dei 508.037. Sopra, i Methods devono dichiarare la perdita come un limite |
| Q4 | studi nel master dello Stadio 2 | 24.394 | ≥ 24.389 | atteso: i master vecchi. Giudizio: oltre 5 studi persi senza recupero, la perdita va spiegata studio per studio |
| Q5 | studi da recuperare nello Stadio 2 | 16 | da 5 a 50 | atteso: 4 su 6.300 della prova. Giudizio: sopra 50 il recupero supera circa 10 ore e cambia il costo dichiarato |
| Q6 | ore di job dello Stadio 2, senza recupero | 54,4 | da 36,3 a 84,6 | stessa proporzione della prova: sopra il limite il costo supera la stima alta. `84-out.txt` della prova |
| Q7 | ore effettive dello Stadio 1, recupero compreso | 8,9 | da 6 a 14 | stessa proporzione. Sopra, il costo dichiarato al PI va corretto |

**Se Q1 o Q2 cade fuori:** il run nuovo non riproduce gli 8.566 studi. Mi fermo e porto la differenza al PI, anche se il cancello 5 è passato.

**Margini.** Q3, Q4 e Q5 usano un giudizio motivato. Lo dico al PI nel riassunto.

## Esecuzione

Script `50-catena.R`, lanciato con `setsid`, solo dopo l'approvazione del PI. Costruttore del recupero `45-rescue-build-s2.R`. Ogni passo scrive un file di stato. La catena riparte dall'ultimo passo finito (`RIPRESA.md`). Durata stimata circa 40 ore: 39,1 ore di modello da `84-out.txt` più l'input e i confronti.
