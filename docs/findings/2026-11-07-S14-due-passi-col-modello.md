---
type: Finding
title: "Il modello rifà da zero tutti gli studi: il run è completo e ripete i record già rigenerati"
description: "Stadio 1 e Stadio 2 rifatti da zero su 508.037 campioni e 24.393 studi, in un solo run su poddgx02. I record già rigenerati sono identici (211.484 su 211.484 e 8.565 studi su 8.566); l'unico studio diverso ha avuto ad agosto un input di recupero in un altro formato."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-07T04:00:07+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-05-S14-re-run-modello/00-previsioni.md", title: "Cancelli e previsioni depositati prima del run"}
- {id: log, resource: "analysis/audit/2026-11-05-S14-re-run-modello/log/catena.log", title: "Log della catena dei due passi col modello"}
- {id: c5s1, resource: "analysis/audit/2026-11-05-S14-re-run-modello/30-cancello5-s1.txt", title: "Cancello 5, Stadio 1, primi due blocchi"}
- {id: c5s2, resource: "analysis/audit/2026-11-05-S14-re-run-modello/31-cancello5-s2.txt", title: "Cancello 5, Stadio 2, prima parte"}
- {id: s1, resource: "analysis/audit/2026-11-05-S14-re-run-modello/60-s1-confronto.txt", title: "Confronto dello Stadio 1 con il riferimento"}
- {id: s2in, resource: "analysis/audit/2026-11-05-S14-re-run-modello/61-s2-input.txt", title: "Input dello Stadio 2 contro il riferimento"}
- {id: s2, resource: "analysis/audit/2026-11-05-S14-re-run-modello/62-s2-confronto.txt", title: "Confronto dello Stadio 2 con il riferimento"}
- {id: chiusura, resource: "analysis/audit/2026-11-05-S14-re-run-modello/90-chiusura.txt", title: "Controlli di chiusura: manifesto, riferimenti, job, flag, copia"}
- {id: sacct, resource: "analysis/audit/2026-11-05-S14-re-run-modello/90-sacct.txt", title: "Tutti i job della sessione con stato, durata e nodo"}
- {id: anomalie, resource: "analysis/audit/2026-11-05-S14-re-run-modello/91-anomalie.txt", title: "Spiegazione delle anomalie viste a fine catena"}
- {id: sha, resource: "analysis/audit/2026-11-05-S14-re-run-modello/90-master-sha256.txt", title: "SHA-256 dei master nuovi"}
- {id: s8b, resource: "docs/findings/2026-11-05-S8b-prova-re-run.md", title: "La prova e la decisione del PI sul re-run"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi, non toccato"}
---

# In breve

## In breve: il run nuovo del modello è completo e ripete i record già rigenerati?

**A cosa serviva.** Hai scelto di rifare da zero, in un solo run, i due passi in cui il modello legge i metadati di GEO: il passo sui campioni e il passo sul disegno degli studi. Così tutti gli studi vengono dallo stesso modello ripetibile, non solo quelli rigenerati ad agosto e nella prova. Abbiamo controllato che il run copra tutti gli studi e che ripeta i record già rigenerati.

**Cosa abbiamo trovato.**

1. **Il run è completo: tutti i 508.037 campioni e tutti i 24.393 studi hanno un record.** Solo 3 campioni restano senza un record valido. Sono gli stessi 3 campioni della prova, e il loro studio ha comunque un record.
   - I master vecchi hanno uno studio in più, e questo studio non esiste. A maggio il modello ha scritto male la sigla dello studio di 3 campioni, e il vecchio programma ha creato uno studio falso. Il run nuovo prende la sigla dai dati di GEO.
2. **Il modello ripete i record già rigenerati.** Nel passo sui campioni sono identici 211.484 record su 211.484. Nel passo sul disegno sono identici 8.565 studi su 8.566.
   - Tutte e sette le attese depositate prima del run sono confermate. Tre margini venivano da un mio giudizio e non da una misura: i campioni persi, gli studi persi e gli studi da rifare.
3. **L'unico studio diverso ha avuto ad agosto un input diverso, non un'uscita diversa del modello.** Lo studio GSE157657 non ha avuto una risposta valida al primo tentativo, quindi il programma l'ha rifatto in pezzi più piccoli, come ad agosto. Ad agosto questi pezzi avevano un formato diverso da quello di produzione. Nel run nuovo hanno il formato di produzione. Quattro studi rifatti nello stesso modo anche nella prova hanno lo stesso input e lo stesso record.
4. **Un job si è fermato per un'ora, e l'ho rilanciato con un limite di lunghezza più alto.** Cinque campioni hanno descrizioni di circa 9.800 caratteri, oltre il limite della prova. Con questi testi il programma che fa girare il modello si blocca senza errori, come a maggio. Ho rifatto i 25 campioni più lunghi con il limite del run di maggio. Le attese depositate non prevedevano questo cambio. Venti di questi campioni stanno nella prova e hanno record identici, quindi il limite non cambia le risposte.
5. **Rispetto ai master vecchi cambia molto.** Fra gli studi mai rigenerati prima, solo il 16% ha lo stesso record nel passo sul disegno. Il run vecchio non era ripetibile, quindi questo cambio è atteso. Per questo motivo le meta-analisi possono cambiare quando ricostruiremo i gruppi.

**Comunque:**

- i due master nuovi sono salvati con la loro impronta SHA-256, anche su un secondo disco, e il deliverable e i master vecchi non sono cambiati;
- ricostruiremo i gruppi, il pooling e l'annotazione su questi master solo dopo il rilevatore degli errori nelle etichette e dopo la correzione dei ruoli;
- la scelta sulle tabelle che correggono i nomi viene dopo una misura su tutte le loro righe, e con questi master la misura è possibile;
- i record identici provano che il modello è ripetibile, non che i record sono corretti, e abbiamo provato un solo nodo.

Non c'è nulla da decidere: se non hai dubbi, la sessione è chiusa.

**Sui tempi di calcolo.** I tempi sono misure mie, su un solo nodo con due job da 4 GPU alla volta. Il run è durato 33 ore e 15 minuti, contro le circa 40 ore stimate. Il passo sui campioni ha richiesto circa 9 ore, con il recupero e con l'ora persa per il job fermo. Il passo sul disegno ha richiesto 43,0 ore di job in 12 parti, più un'ora per il recupero.

# 1. Che cosa è stato fatto

Decisione del PI del 2026-11-05 (finding S8b, «Decisioni del PI»): i 24.394 studi da zero, Stadio 1 e Stadio 2, in un solo run, senza innesti. Frase di apertura «solo i due passi col modello» (handout, S14, punto 4): la sessione si ferma ai due master. Previsioni e catena committate prima di ogni invio (`aa70364`); il PI ha approvato il lancio e il controllo dentro il run al posto della prova di invarianza separata (`ade5d65`).

**Catena.** `analysis/audit/2026-11-05-S14-re-run-modello/50-catena.R`, lanciata con `setsid`, un file di stato per passo. Primo invio 2026-11-05 17:46:29, «CATENA FINITA» 2026-11-07 03:01:32: 33,25 ore[^anomalie].

| passo | che cosa | risultato | fonte |
|---|---|---|---|
| Stadio 1, blocchi | mescolamento seme 42, outlier sopra 3.500 caratteri a parte, blocchi da 10.000 | 508.037 record, 25 outlier, 51 blocchi, identici all'input | `catena.log` riga 3 |
| Stadio 1, run | 51 blocchi + outlier, `VLLM_BATCH_INVARIANT=1` | raccolti 508.037, mancanti 0, estranei 0, duplicati 0, validi 506.534 | riga 335 |
| Stadio 1, recupero | 1.2/4096/8192 → 1.3/8192/16384 → 1.4/8192/16384 | 1.503 → 158 → 26 → 3 | righe 338-382 |
| Stadio 1, master | ordine dei record del master di maggio | 508.037 record, assenti 0 | riga 385 |
| Stadio 2, input | `series_id` dall'input dello Stadio 1 | 24.983 record, 24.393 studi | `61-s2-input.txt` |
| Stadio 2, run | 12 parti, due alla volta, `tiered_max_tokens` | validi 24.966, errori 17 (12 studi) | righe 713-717 |
| Stadio 2, recupero | tetto 12 trattati, `max_tokens` 32768, `rep_pen` 1,2 | 472 record, 472 validi, secondo giro 0 | righe 718-755 |
| Stadio 2, master | un record per studio | 24.393 studi, 0 senza record, guardia OK, 489.428 campioni nei gruppi di repliche | `log/assemblaggio-s2.log` |

**Master nuovi** (gitignored, SHA-256 in `90-master-sha256.txt`):

- `analysis/p4-output/S14-stage1-master.jsonl` (508.037 record);
- `analysis/p4-output/S14-stage2-master.jsonl` (24.393 studi);
- copia verificata in `/mnt/micron/simulomicsr-salvataggio/S14-master-2026-11-07/` con il suo `SHA256SUMS.txt` (`sha256sum -c`: OK per entrambi)[^chiusura]. Il manifesto della copia S2 non è stato toccato.

# 2. Cancelli

| # | cancello | esito | fonte |
|---|---|---|---|
| 1 | manifesto SHA-256 del deliverable all'inizio e alla fine; SHA-256 dei master di riferimento invariati | passato: «VERIFICA OK» due volte; 13 file su 13 con lo stesso SHA-256 | `10-manifesto-inizio.txt`, `90-manifesto-fine.txt`, `90-chiusura.txt` |
| 2 | copertura | passato: blocchi = 508.037 righe senza duplicati; raccolta senza estranei né duplicati; master dello Stadio 2 con un record per studio e 0 studi di input senza record | `catena.log` righe 3, 335; `62-s2-confronto.txt`; `studi-senza-record-s2.txt` vuoto |
| 3 | configurazione | passato: `VLLM_BATCH_INVARIANT=1` in 71 run su 71, anche nel job fermato; 71 job su 71 su `poddgx02`; prompt, schema e `generation.json` uguali ai bundle della prova, con un'eccezione dichiarata (§4.2) | `90-flag.txt`, `90-sacct.txt`, `catena.log` riga 224 |
| 4 | lo strumento vede le differenze | passato su entrambi gli stadi: negativo 101.300 su 211.484 (Stadio 1) e 1.229 su 8.566 (Stadio 2); positivo 1 differenza piantata vista su 1 | `60-s1-confronto.txt`, `62-s2-confronto.txt` |
| 5 | identità sui primi job | passato: Stadio 1 7.795 su 7.795 (soglia 99,9%); Stadio 2 763 su 763 (soglia 98,8%) | `30-cancello5-s1.txt`, `31-cancello5-s2.txt` |

Il job non registrato dalla catena in `90-sacct.txt` è 451629, `bash`, 2 secondi alle 17:09 del 5 novembre: il controllo del mount con `srun` prima del primo invio (`CLAUDE.md` §7).

# 3. Previsioni

| # | quantità | atteso | intervallo | misura (IC 95%) | verdetto |
|---|---|---:|---:|---|---|
| Q1 | record Stadio 1 con `raw_output` identico al riferimento | 100% | ≥ 99,9% | 211.484 su 211.484 = 100% [99,998; 100] | confermata |
| Q2 | studi con record Stadio 2 assemblato identico al riferimento | 100% | ≥ 98,8% | 8.565 su 8.566 = 99,988% [99,935; 100] | confermata |
| Q3 | campioni senza record valido dopo il recupero dello Stadio 1 | 11 | ≤ 51 | 3 | confermata |
| Q4 | studi nel master dello Stadio 2 | 24.394 (vedi §4.3) | ≥ 24.389 | 24.393 | confermata |
| Q5 | studi da recuperare nello Stadio 2 | 16 | da 5 a 50 | 12 | confermata |
| Q6 | ore di job dello Stadio 2, senza recupero | 54,4 | da 36,3 a 84,6 | 42,96 | confermata |
| Q7 | ore effettive dello Stadio 1, recupero compreso | 8,9 | da 6 a 14 | 8,95 | confermata |

Q3, Q4 e Q5 usano un margine motivato da un giudizio (`00-previsioni.md`): lo dice il riassunto. Q7 contiene i 61,5 minuti persi per il job fermo (§4.2): senza la fermata sarebbe circa 7,9 ore.

**Durate delle 12 parti dello Stadio 2** (`90-sacct.txt`): da 2:45:57 a 4:01:16, più la parte 4 con 5:44:15. Nella parte 4 il gruppo di 50 studi 351-400 ha richiesto circa 10.000 secondi per worker, contro 500-2.400 dei gruppi precedenti; alle 09:44 e alle 10:46 le 4 GPU erano al 100% e le barre di vLLM avanzavano (43-46 su 50), quindi il job lavorava e non era fermo. Dei 12 studi recuperati nello Stadio 2 uno solo viene dalla parte 4 (`GSE249377`): il gruppo lento ha dato risposte lunghe e valide, non errori.

# 4. Le anomalie e come si chiudono

## 4.1 GSE157657, l'unico studio di riferimento diverso: spiegato

`62-s2-confronto.txt` dà 8.565 studi identici su 8.566; quello diverso è `GSE157657`, uno studio di agosto. Fatti, da `91-anomalie.txt` §1:

- nel run principale i suoi 17 record validi su 18 sono identici ad agosto (`raw_output` 17 su 17); il diciottesimo manca in entrambi i run, quindi lo studio va al recupero in entrambi;
- l'input di recupero ha 57 record in entrambi i run, con gli stessi campioni nello stesso ordine e lo stesso `study_summary`, ma **nessuna riga è identica**: ad agosto il campione aveva le chiavi `condition_id` (in testa), `signature` e `n_char`, gli scalari di `sample_facts` non erano in array e il record non aveva `chunk_metadata`;
- il formato del run nuovo è quello del recupero di produzione (`archs4-human-stage2-rescue-v3.jsonl`), del recupero della prova e dell'input principale dello Stadio 2. Il recupero di agosto è l'unico con l'altro formato. Lo script che lo ha costruito non è nel repository (commit `ebf21e5`);
- **controllo positivo:** i 4 studi recuperati sia nella prova sia nel run nuovo (`GSE192861`, `GSE233774`, `GSE249377`, `GSE253260`, 320 record) hanno input di recupero identico e record assemblato identico al riferimento.

Conclusione: lo studio diverso ha avuto un prompt diverso ad agosto. Non è una mancata ripetibilità del modello. Il record nuovo è quello costruito come in produzione. Il deliverable attuale è costruito sul master di agosto; la seconda parte di S14 userà il record nuovo.

## 4.2 Il job degli outlier fermo: corretto, con una deviazione dalle attese

Il job 452113 (25 outlier dello Stadio 1, `max_model_len` 4096 come nella prova) è rimasto fermo 1:07:14 senza errori, con le GPU allo 0%. Causa: 5 record di `GSE50445` da circa 9.800 caratteri, assenti nella prova. Con un prompt oltre `max_model_len` vLLM si ferma in silenzio (Issue #39734), come a maggio con il job 20705. Il run di produzione F2 aveva fatto gli stessi 25 record con `max_model_len` 32768 (`analysis/p4-beta-stage1-outliers.R`).

Correzione (commit `890ad8f`), presa da me di notte senza il PI e dichiarata al PI nell'aggiornamento orario: solo per gli outlier `max_model_len` 32768; `generation.json` uguale al bundle della prova a meno di `max_model_len` (cancello 3, `catena.log` riga 224, con controllo positivo e negativo del confronto); job 455951, 2:29, 25 validi su 25. Il job fermo sta in `jobs/fermati/`. Aggiunta una guardia nel recupero dello Stadio 1: un record oltre 5.000 caratteri da rifare con `max_model_len` 8192 ferma la catena in modo visibile. Non è scattata.

**Deviazione dalle attese:** `00-previsioni.md` diceva «configurazione identica alla prova». Il cambio tocca solo `max_model_len`, che decide se il prompt entra, non come il modello genera. Misura (`91-anomalie.txt` §3): i 20 outlier di `GSE212990`, nel riferimento, hanno record identici alla prova, fatta con 4096. I 5 di `GSE50445` non hanno riferimento. Costo: 61,5 minuti di ritardo sullo Stadio 1 (blocchi finiti 01:02:49, outlier finiti 02:04:20).

**Per il prossimo run sul corpus:** gli outlier dello Stadio 1 vanno con `max_model_len` 32768, come in F2. La catena lo fa; i default di `dgx_p4_build_bundle()` no. Annotato nell'handout, S14.

## 4.3 GSE9135, l'ordine e l'atteso di Q4: spiegati

- `62-s2-confronto.txt` riga 1 dice «persi 1, nuovi 0, stesso ordine FALSE». Lo studio perso è `GSE9135`; tolto quello, l'ordine dei 24.393 studi è identico ai master vecchi (`91-anomalie.txt` §2). `identical()` era FALSE solo per la lunghezza.
- `GSE9135` non esiste nell'input dello Stadio 1. Nel run di maggio il modello ha scritto `GSE9135` al posto di `GSE91395` per `GSM2422631/2/4`, e il vecchio costruttore dell'input dello Stadio 2 prendeva la sigla dal modello. Il modello nuovo fa lo stesso errore (`S14-stage2-input.jsonl.series-divergenti.csv`), ma il costruttore prende la sigla dall'input (scelta tecnica 3 di `00-previsioni.md`). Era già previsto in A3 (P1 e P2 di `PREVISIONI-A3-PRIMA-DEL-RUN.md`: 24.393 studi).
- **Errore mio nelle attese:** `00-previsioni.md` scrive 24.394 come atteso di Q4. Il valore giusto, per la scelta tecnica 3, era 24.393. L'intervallo (≥ 24.389) lo contiene, il verdetto non cambia, e le attese restano come sono state depositate.

## 4.4 Altre anomalie del lavoro, tutte senza effetto sui record

- **Falso FERMO della prova breve** (5 novembre, 17:26, `catena.log` riga 15): il cancello 3 confrontava `generation.json` della prova dello Stadio 2 con quello della parte 1 della prova S8b, ma 12 record piccoli sono tutti di tier S e il `max_tokens` globale vale 4096. Corretto nel commit `5d3ea66`: per la prova si confrontano solo prompt e schema. È l'unica riga FERMO del log.
- **Errori ssh all'invio:** 12 righe `kex_exchange_identification: Connection reset by peer` in `log/catena.out`, con `sbatch` in stato 255. La catena ha ripetuto l'invio. Nessun job doppio: in `sacct` dell'utente per tutto il periodo c'è un solo job non registrato, il controllo del mount (§2).
- **`git mv -k` non ha spostato l'oggetto del job fermato** (file non tracciato): lo script orario lo contava come CANCELLED. Spostato con `mv`. La catena legge i job per slug, quindi non ne è stata toccata.
- **Temperatura del processore locale** fino a 84,9 °C fra le 09:12 e le 11:13 del 6 novembre e sopra 70 °C la sera: carico di altri lavori sulla macchina (il benchmark S2.3 di `geo_spatialtrans` e 45 processi R di un altro utente). La catena fa solo un controllo ogni 5 minuti; i job girano sulla DGX.

# 5. Quanto cambia rispetto ai master vecchi (descrittivo)

- Stadio 1: sui 211.484 record di riferimento il master vecchio, senza flag, coincide con il run nuovo in 101.300 casi (47,9%) (`60-s1-confronto.txt`).
- Stadio 2: sugli 8.566 studi di riferimento il master vecchio coincide in 1.229 casi (14,3%). Sui 15.827 studi mai rigenerati prima, il record nuovo coincide con il vecchio in 2.599 casi: 16,421% [15,847; 17,008] (`62-s2-confronto.txt`).

Il cambio è atteso: il run vecchio non era ripetibile, e un record di studio aggrega molti record di campione. Che cosa ne segue per i gruppi e le meta-analisi si misura nella seconda parte di S14.

# 6. Che cosa questa sessione non vede

- L'identità con un run precedente prova la ripetibilità, non la correttezza dei record.
- Un solo nodo, `poddgx02`.
- Nessuna misura sui gruppi, sul pooling o sulle meta-analisi: la sessione si ferma ai master.
- Nulla sulle tabelle dei nomi, che non entrano nei master.
- La prova di invarianza separata non è stata fatta: l'ha sostituita il cancello 5 dentro il run, per scelta del PI (`00-previsioni.md`, «Decisioni del PI»).

# 7. Che cosa resta, e dove

- **Seconda parte di S14**, dopo S12 e dopo l'assegnazione dei ruoli per nome (S13, punto 1): ricostruzione dei gruppi, pooling e annotazione sui due master nuovi. Al termine decadono la scelta delle 40 e delle 132 (S5) e il numero della validazione esterna (S7) viene dal deliverable nuovo.
- **Tabelle dei nomi:** la misura di S10 su tutte le righe (quante puntano a un gruppo con un contenuto diverso nel run nuovo) ora si può fare, perché il master esiste.
- **Outlier dello Stadio 1 con `max_model_len` 32768** in ogni run futuro sul corpus (§4.2).

Nessun dubbio di questa sessione resta aperto: §4.1 e §4.3 sono spiegati, §4.2 è corretto e misurato, §4.4 non tocca i record.

# Da dove vengono i numeri del riassunto

| Nel riassunto | Fonte | Valore letto |
|---|---|---|
| «508.037 campioni» | `catena.log` righe 3, 335, 385 | 508.037 |
| «24.393 studi hanno un record» | `62-s2-confronto.txt` righe 1-2 | 24.393; senza record 0 |
| «Solo 3 campioni ... gli stessi 3 della prova» | `residui-stadio1.txt`; `91-anomalie.txt` §4 | 3; «stessi residui della prova: True» |
| «il loro studio ha comunque un record» | `91-anomalie.txt` §4; `62-s2-confronto.txt` riga 2 | `GSE157354`; studi senza record 0 |
| «uno studio in più ... 3 campioni» | `62-s2-confronto.txt` riga 1; `91-anomalie.txt` §2 | persi 1 (`GSE9135`); `GSM2422631/2/4` |
| «211.484 record su 211.484» | `60-s1-confronto.txt` riga 1 | 211484 su 211484 |
| «8.565 studi su 8.566» | `62-s2-confronto.txt` riga 3 | 8565 su 8566 |
| «sette le attese ... confermate» | §3 di questo finding | Q1-Q7 confermate |
| «Tre margini ... giudizio» | `00-previsioni.md`, «Margini» | Q3, Q4, Q5 |
| «GSE157657 ... in pezzi più piccoli, come ad agosto» | `studi-recupero-s2.txt`; `91-anomalie.txt` §1 | 57 record di recupero in entrambi i run |
| «un formato diverso» | `91-anomalie.txt` §1 | righe identiche 0; chiavi e tipi diversi |
| «Quattro studi ... stesso input e stesso record» | `91-anomalie.txt` §1, controllo positivo | 4 su 4 True, input e record |
| «Un job si è fermato per un'ora» | `90-sacct.txt` | 452113, 01:07:14, CANCELLED |
| «circa 9.800 caratteri» | `50-catena.R`, commento sopra `OUTL_SLUG` | circa 9.800, 5 record di `GSE50445` |
| «i 25 campioni più lunghi» | `catena.log` riga 3; `91-anomalie.txt` §3 | outlier 25 |
| «Venti ... record identici» | `91-anomalie.txt` §3 | `GSE212990`: 20 su 20 |
| «solo il 16%» | `62-s2-confronto.txt` riga 7 | 2599 su 15827 = 16,421% |
| «anche su un secondo disco» | `90-chiusura.txt` ultima riga | S14-stage1-master.jsonl: OK; S14-stage2-master.jsonl: OK |
| «il deliverable e i master vecchi non sono cambiati» | `90-chiusura.txt` righe 1-2 | VERIFICA OK; 13 su 13 |
| «33 ore e 15 minuti» | `91-anomalie.txt` §5 | 33,25 h |
| «circa 40 ore stimate» | `00-previsioni.md`, «Esecuzione» | circa 40 ore |
| «circa 9 ore» | `91-anomalie.txt` §5 | 8,95 |
| «43,0 ore di job in 12 parti» | `catena.log` riga 714 | 42.96 |
| «un'ora per il recupero» | `90-sacct.txt` | 467566, 01:03:56 |

[^anomalie]: `analysis/audit/2026-11-05-S14-re-run-modello/91-anomalie.txt`, prodotto da `91-anomalie.py`.
[^chiusura]: `analysis/audit/2026-11-05-S14-re-run-modello/90-chiusura.txt`, prodotto da `90-chiusura.R`.
