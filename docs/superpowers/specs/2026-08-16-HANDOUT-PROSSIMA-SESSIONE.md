# HANDOUT — il re-run completo, e quello che viene dopo

**Scritto:** 2026-08-16 · **Branch:** `review-scientific-consistency-2026-06-10` (pushato)
**master invariato** · Commit di riferimento: `d92f505`..`a53e408`

> **Autosufficiente.** Non serve la conversazione precedente. Va letto per intero
> prima di toccare qualsiasi cosa.

---

## 0. DOVE SIAMO

Il ciclo Stadio 3 + Stadio 4 è stato rifatto per intero, verificato, e la
biologia che produce è stata controllata.

| | |
|---|---|
| Stadio 3 | `analysis/p4-output/20260814T025911Z-stage3-v16-7f986159` |
| Stadio 4 | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d` |
| deliverable | **211 meta-analisi**, 200 coerenti + 11 incoerenti dichiarate, 0 NA (colonna `coherence_verdict`) |
| controllo biologico | **29 bersagli su 31** col segno giusto e significativi |

**Tutte le previsioni depositate prima del run sono tornate**: 211 righe e dodici
`k_eff` su dodici (TNF 38, ipossia 33, SARS-CoV-2 36, IL-6 11, IL-15 5, IFN-β 6,
IFN-γ 19, IL-4 9, IL5RA 11, IMPDH2 5, *S. aureus* 3, TGF-β1 59). Le tre righe
uscite rispetto a v15 sono spiegate: *S. epidermidis* sotto il gate per le corsie,
TNF-CHEMBL e `STR:ifnb` **assorbiti** dalle fusioni (i loro studi sono nei vincenti).

Il controllo che vale doppio regge: DHT contro enzalutamide, **1.266 geni su
1.299 di segno opposto (97,5%), Spearman −0,939**, su gruppi costruiti
separatamente. TGF-β1 6/6, SARS-CoV-2 4/4, IFN-γ 5/5 (CXCL9 +10,88), LPS 4/4. Le
due mancate sono su IL17A, che ha 3 soli studi efficaci: le stesse di v15.

**Non c'è un difetto sistematico noto** che il re-run riprodurrebbe: è la ragione
per cui il controllo biologico è stato fatto PRIMA e non dopo.

---

## 1. LA DECISIONE PRESA (utente, 2026-08-16)

**Si fa il re-run completo degli stadi LLM.** Non si chiude sul deliverable
attuale dichiarando la riproducibilità come limite: *«non concluderò mai niente
dichiarandone i limiti»*.

Ordine deciso, con i primi due **già fatti**:

1. ~~Controllo biologico su v16b~~ **FATTO** (29/31).
2. ~~Correzione dei documenti col peso contaminato sbagliato~~ **FATTO**
   (ma vedi §5.4: quello che era stato annunciato era in gran parte falso).
3. **Il re-run completo** — §2, è il lavoro della prossima sessione.
4. **Layer B e Methods una volta sola**, sui numeri definitivi — §3 e §4.

---

## 2. IL RE-RUN COMPLETO (la prossima sessione)

### 2.1 Che cosa comporta davvero

Non sono «due giorni di calcolo». Sono due giorni di calcolo **più la rilettura
dei giudizi umani**, e questo va messo nel conto prima di iniziare, non dopo.

⚠️ **La flag rende riproducibile il run NUOVO, non lo fa coincidere col vecchio.**
Misurato (`docs/superpowers/specs/2026-08-10-correttezza-passo-passo-HANDOUT.md` §1):
senza `VLLM_BATCH_INVARIANT=1`, due esecuzioni identiche davano lo stesso record
completo nel **40,4%** dei casi allo Stadio 1 e nel **62,0%** allo Stadio 2. Sui
campi che contano: `agent_normalized.id` 86,0%, `cell_context` 89,4%,
`is_zero_timepoint` 95,2%; allo Stadio 2, confronti per identità dei campioni
92,0% e `primary_role` 93,0%.

**Conseguenza diretta: il deliverable cambierà per motivi indipendenti dai fix**,
e i giudizi umani dati sulla composizione dei gruppi non saranno più stati dati
su quei gruppi:

* i **24 verdetti di coerenza** (`analysis/audit/2026-08-02-fix/verdetti-poolato-v15.csv`;
  **11 agganciano un gruppo poolato**, gli altri 13 riguardano gruppi che non
  superano il gate) sono stati letti sui membri *poolati* di allora. È già
  successo che una composizione cambiata ribaltasse il verdetto: il 27 luglio tre
  gruppi «coerenti» sono diventati incoerenti — non era cambiato il metro, era
  cambiata la loro composizione;
* la **rilettura dei 214** del 5 agosto (22 lettori + 22 contestatori, i confronti
  imperfetti contati uno per uno) è nella stessa condizione:
  `analysis/audit/2026-08-05-rilettura-214/`.

### 2.2 La sequenza

**Prima di lanciare qualunque cosa sul DGX**: `sinfo` che dice `idle` **non
basta**, va verificato il mount con un `srun` breve (memoria
`dgx_storage_projects_not_home`: un `/home` non montato dà `ExitCode 0:53` e
**zero log**).

1. **Stadio 1** — input già costruito (`analysis/input/archs4-human-stage1-input-v2.jsonl`,
   508.037 record). Sottomissione a chunk come in F2
   (`p4-fase-f2-stage1-chunk-build.R` → submit → `p4-fase-f2-stage1-merge.R`),
   **con `VLLM_BATCH_INVARIANT=1` nello script slurm**. Config invariata rispetto
   a F2 (ADR-0008): `temperature=0.0`, `repetition_penalty=1.1`.
   ⚠️ **Verificare che la flag sia arrivata al processo**, non che sia scritta
   nello script: `tr '\0' '\n' < /proc/<pid>/environ | grep VLLM` sul nodo, o il
   `generation.json` del run. Una variabile scritta e non passata è lo stesso
   modo di fallire del collasso delle corsie (§8).
2. **Stadio 2** — `p4-fase-f4-stage2-build-input-v3.R` (applica il guard
   `is_zero_timepoint`: sul master attuale corregge **12.967** flag) →
   `p4-fase-f4-stage2-fullrun-v3.R` → `p4-fase-f4-stage2-collect-v3.R` → master.
   Guardia obbligatoria: **un record per studio**
   (`.assert_stage2_one_record_per_series`).
3. **Re-cluster** (~2 h 30 m con 32 worker) e **re-pool** (~75 min in 16 pezzi):
   comandi in §6.
4. **Confronto con v16b**, che è il riferimento: quante righe, quali entrano e
   quali escono, e i dodici `k_eff` della tabella in §0.
5. **Controllo biologico** sul deliverable nuovo (comando in §6): è il gate che
   dice se la pipeline misura ancora la cosa giusta, e costa minuti.

### 2.3 Le previsioni da depositare PRIMA

Quelle della sessione scorsa **non valgono più** (valevano a parità di Stadio
1/2). Vanno depositate previsioni nuove, e serve uno strumento per farle: la sola
misura onesta disponibile è la variabilità run-to-run di §2.1, che dice quanto
cambia l'input, non quanto cambia il deliverable. **Il passaggio dall'una all'altro
non è lineare** e non è mai stato misurato.

Due modi, da proporre all'utente **prima** di lanciare:

* **misurarlo**: rifare Stadio 1+2 su un sottoinsieme (per esempio i soli studi
  dei 211 gruppi), ri-clusterizzare e ri-poolare solo quelli, e vedere quanto si
  sposta. Costa qualche ora e dà un numero;
* **non misurarlo** e depositare previsioni qualitative — che restano
  falsificabili e vanno scritte comunque, in tutti e due i casi:
  * i **pavimenti bandiera** dello Stadio 3 non devono scendere: SARS-CoV-2 38,
    TGFB1 78, LPS 50, enzalutamide 29, vemurafenib 20, IL17A 12 (sono i valori
    misurati su v16; lo script di re-cluster li controlla da solo e si ferma);
  * il **controllo biologico** deve restare sopra 29/31, e DHT-contro-enzalutamide
    deve restare sopra il 95% di geni discordanti con Spearman sotto −0,9;
  * i **gruppi di punta** devono sopravvivere: TGF-β1, TNF, ipossia, SARS-CoV-2,
    LPS, IFN-γ, DHT, enzalutamide.
  Se uno di questi cade, il re-run ha rotto qualcosa: fermarsi e leggerlo, non
  interpretarlo.

Il modello del documento da scrivere è
`analysis/audit/2026-08-13-rerun-prep/PREVISIONI-PRIMA-DEL-RUN.md`, che contiene
anche l'elenco di ciò che le falsificherebbe: quella parte è la più utile.

### 2.4 La rilettura, dopo

I verdetti non si «riportano»: si **rileggono** sui membri nuovi. Materiale e
metodo del 5 agosto: `docs/findings/2026-08-05-confronti-imperfetti.md` §1 (tre
passate: materiale con le etichette INTERE, lettori, contestatori). ⚠️ Il
contestatore era **spinto alla severità dal prompt** — 24 verdetti cambiati, tutti
verso il peggio, zero assoluzioni: un impianto migliore ha due critici simmetrici.

---

## 3. LAYER B (dopo il re-run)

La vetrina attuale (`analysis/p4-output/20260806T022106Z-layer-b-81f379d3`, 9
bundle) è costruita su **v15**: numeri e composizione non sono più quelli.

1. **Rigenerare la selezione DAL DELIVERABLE**, mai riusare il CSV vecchio: il
   5 agosto quel CSV portava **181 numeri di v13 scritti a mano** nelle note, e le
   note sono l'unico canale che nessuna guardia intercetta perché è testo libero.
2. Le nove scelte di **ADR-0027** vanno **ri-verificate sui k nuovi**, non
   riconfermate.
3. **Aprire i PNG.** I sette criteri automatici erano tutti PASS mentre il forest
   mostrava i geni sbagliati (2026-08-06): i criteri sono misure, non garanzie.
4. Le **narrative** dei bundle sono bozze: vanno riscritte sui numeri nuovi.

---

## 4. METHODS (per ultimo)

Il materiale è tutto misurato; manca la scrittura. Ci vanno **come risultati
dichiarati, non come note a piè di pagina**:

* **dominanza**: 119 righe su 211 hanno uno studio che pesa più della metà, 75
  valgono meno di due studi efficaci (`k_kish`);
* **confronti imperfetti**: 38 su 533 poolati = **7,1%**, peso contaminato
  mediano **8,8%**, estremi **0,0–15,9%**, il peggiore è **LPS**
  (⚠️ NON 10,1% / 12,0% / 0,7–33,7% / IL1B: quelli sono i numeri del 5 agosto,
  rimisurati il 10);
* **il gate seleziona per controllo interno, non per correttezza biologica**: può
  concentrare l'errore;
* **corsie**: 7 confronti tolti, e la ragione (un solo campione biologico per
  condizione in GSE173902);
* **genetica su un braccio solo**: 5 confronti scartati, di cui 2 da uno studio in
  cui la parola «transgene» è **inventata dallo Stadio 2** (GSE156472: nei
  metadati GEO non esiste);
* **fusioni**: 5 entità e 2 controlli, con le tre respinte e il perché;
* **riproducibilità**: la flag e la misura di §2.1.

---

## 5. LE PENDENZE PICCOLE

1. **Avanzamento per blocco nel ramo parallelo dello Stadio 3**: durante la fase 6
   si vede solo che i worker sono vivi (con 32 worker le righe di avanzamento
   arriverebbero fuori ordine, quindi sono state tolte). Serve un contatore per
   blocco.
2. **158 MB di binari nella storia del branch**: tolti dall'indice (`ac889bb`) ma
   ancora nei commit precedenti. Toglierli davvero richiede di riscrivere la
   storia: **decisione utente**.
3. **`qc_report$covariate_drops` è nuovo** (4.950 righe) e nessuno l'ha ancora
   letto: potrebbe dire qualcosa sulle covariate batch.
4. ⚠️ **Una mia affermazione del 2026-08-16, ritrattata**: avevo scritto che «sei
   documenti riportano ancora il peso contaminato sbagliato». **Falso**: aperti
   tutti, la correzione del 10 agosto c'era già. L'unico difetto vero era in
   `2026-08-10-sensitivity-confronti-spuri-HANDOUT.md`, che dava **11,5%
   (4,2–20,0%)** — la colonna `peso_regola_nuova_lista_vecchia`, uno stadio
   intermedio — invece di **8,8% (0,0–15,9%)**. Corretto.

---

## 6. COME SI LANCIANO I RUN, CON I DEFAULT MISURATI

```bash
# RE-CLUSTER Stadio 3 — ~2 h 30 m (9 h 21 m in serie), 32 worker di default
SMOKE=0 setsid nohup Rscript analysis/p4-fase-f13-stage3-v16-tre-cambi.R \
  > analysis/audit/<data>/recluster.log 2>&1 < /dev/null &
ps -eo pid,sid,args | grep "[f]13-stage3"      # SID deve essere == PID

# RE-POOL Stadio 4 — ~75 min in 16 pezzi (32 h 30 m in un pezzo solo)
PD=/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v17-pezzi
for i in $(seq 1 16); do
  PEZZO=$i N_PEZZI=16 PEZZI_DIR=$PD STAGE3_DIR=<dir stadio 3> \
  VERDETTI_PATH=<csv dei verdetti APPLICABILI> \
  setsid nohup Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R \
    > <log>-$i.log 2>&1 < /dev/null &
done
# quando tutti e 16 hanno scritto:
PEZZI_DIR=$PD STAGE3_DIR=<dir> VERDETTI_PATH=<csv> \
  Rscript analysis/p4-fase-f5b-stage4-ricomponi-pezzi.R

# CONTROLLO BIOLOGICO — minuti
POOL_DIR=<dir del re-pool> \
  Rscript analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R
```

**I default sono misurati, non scelti** (`analysis/audit/2026-08-13-rerun-prep/E4-scaling-worker.csv`):
32 worker per lo Stadio 3 (accelerazione 10,65×; a 64 **peggiora** — il collo è la
raccolta dei risultati via pipe, non i core; la memoria passa da 8,7 a 9,2 GB
perché `fork` condivide le pagine); 16 pezzi per il re-pool (processi separati,
memoria NON condivisa: 5–9 GB a pezzo; il limite vero è **il cluster più lento, 48
minuti**, sotto cui nessuna divisione scende).

⚠️ **I verdetti da passare sono quelli APPLICABILI** (11 righe,
`verdetti-poolato-v15-applicabili.csv`), non tutti e 24: 13 riguardano gruppi che
non superano il gate del pooling, e la guardia — fatale, e giusta — ferma il run
**a fine corsa**, dopo tutte le ore di calcolo. Prova:
`analysis/audit/2026-08-02-fix/81-verdetti-tolti-e-perche.md`.
Se il run si ferma lì, gli output pesanti sono già scritti: l'annotazione si rifà
**a freddo** con `analysis/audit/2026-08-02-fix/80-annotazione-a-freddo-v15.R`
(minuti, non ore).

---

## 7. COME COMPORTARSI CON L'UTENTE

**È uno scienziato, non un developer.** Non «chiudere un prodotto»: stabilire che
cosa è vero. Niente tempistiche se non le chiede. Raccomandare una strada per
merito scientifico, mai perché è più corta; se la più lunga è quella giusta, dire
quella. **Non proporre di concludere «dichiarando i limiti»**: un limite
dichiarato non è una conclusione, e questa strada è già stata rifiutata.

**Nessun numero prima che lo strumento abbia superato i suoi casi di accettazione,
positivi E negativi.** I negativi contano di più: sono la direzione in cui uno
strumento sbaglia senza dare segno. Se un caso fallisce, lo strumento è rotto
finché non si dimostra il contrario — anche se il numero sembra sensato.

**Aprire i dati prima di descriverli.** Una descrizione ripresa da un messaggio di
commit o da un finding è un'affermazione propria, e se ne risponde.

**Quando contesta un punto scientifico: misurare, poi rispondere** — non
assecondarlo e non difendersi.

**Un numero che contraddice l'attesa di ordini di grandezza: il primo sospettato è
lo strumento.** Sospettarlo è obbligatorio; aspettarsi che il sospetto assolva il
dato non lo è.

**Prima di chiamare «nuovo» un difetto, cercarlo negli audit esistenti** — due
minuti di `grep`. Costato di nuovo il 2026-08-16 (§5.4).

**Nessun numero prodotto da un agente entra in una decisione senza essere
rimisurato in modo indipendente.** Verificare sull'artefatto, non sul sorgente: le
figure si aprono e si guardano.

**Dire i propri errori per intero, senza attenuarli**, e ritrattare esplicitamente
quanto scritto prima. Niente scuse accumulate, niente ruminazione: la correzione,
il numero giusto, avanti.

**Mai la parola «validato» senza la misura accanto. Nessun taglio silenzioso:**
ogni omissione dichiarata. **Se un numero non torna, fermarsi e dirlo** — non
aggiustarlo.

**Quando si chiede una decisione**: linguaggio chiaro, poche parole, il numero
accanto a ogni opzione, la raccomandazione dichiarata. Domande in serie, non una
alla volta.

**Non narrare il lavoro mentre lo si fa.** Durante i run lunghi: aggiornamento
ogni ora, fatto più stima del residuo. Per il resto, scrivere quando c'è un
risultato o una decisione da chiedere.

**Se chiede di spiegare qualcosa da non addetto ai lavori**: niente gergo non
spiegato, niente rassicurazioni; i termini tecnici e i nomi di codice restano in
originale, il resto in italiano semplice.

**Vincoli fissi**: branch `review-scientific-consistency-2026-06-10`, **master
invariato**, il push lo fa l'utente salvo richiesta esplicita. **Nessun
re-cluster, nessun re-pool e nessuna sottomissione al DGX senza un suo via.**
`Rscript` senza `--vanilla`.

---

## 8. TRAPPOLE GIÀ PAGATE, IN QUESTO CODICE

**Strumenti che smettono di misurare senza dirlo** — la famiglia più costosa

* **Il controllo biologico ha detto «0/0» per sei giorni.** Dal 2026-08-10
  cercava i bersagli (`STAT1`, `IFIT1`, `KLK3`: **simboli**) nella colonna
  `gene_id` (Ensembl): nessun match, «non misurato» su tutti e trentuno. I gruppi
  venivano trovati e i `k` erano giusti, quindi lo 0/0 sembrava un esito.
  Corretto, con la guardia che si ferma se non trova NESSUN bersaglio.
* **Un `warning` fra cinquanta non è un avviso**: il collasso delle corsie è
  rimasto spento per un intero re-pool da 32 ore. Un meccanismo che tocca le stime
  o è acceso o si ferma.
* **Misurare l'oggetto reale, non quello simulato.** Le fusioni erano state
  «verificate» passando al dispatch l'unione dei record *a mano*: misurava il
  comportamento voluto, non quello del codice. Il difetto è emerso dopo 32 ore.
* **I test devono guardare l'ultimo anello.** Quelli della fusione controllavano
  il `k` nel data.frame; nessuno controllava il dispatch, da cui il pooling pesca.

**Sui dati e sulle regex**

* `\b` in R non vede il confine dopo `_` **né dopo una cifra**: `p63shRNA` non
  matcha. Pagata cinque volte. Ma nemmeno l'opposto: un `=` dentro una frase non è
  un nome di campo (`LNCaP-abl shKDM3B1 t=7` non va tagliato — 115 etichette
  mutilate).
* Il nome del campo non è il suo valore: `genetic_knockdown=no knockdown` non è
  una manipolazione genetica.
* Nei JSONL gli scalari sono array di un elemento: `isTRUE(list(FALSE))` e
  `is.numeric(list(0))` sono sempre FALSE (hanno prodotto «36 flag senza
  evidenza» che non esistevano).
* `order()` ha un parametro `method`: `do.call(order, df[cols])` con una colonna
  che si chiama `method` esplode. Spogliare i nomi con `unname()`.

**Sul metodo**

* **Il censito non è il poolato**: `n_min` lascia fuori più della metà dei
  confronti assegnati. Il 10 agosto è costato una misura sbagliata (85 accusati,
  47 dei quali non erano nel poolato).
* **Prima di depositare previsioni su un re-run, leggere il `git log` del codice
  dall'ultimo run.** Il fix IFN-β era entrato il 9 agosto con scritto «si
  materializza solo al prossimo re-cluster», e non era stato cercato: previsione
  212, misurato 211.

**Sull'esecuzione**

* `devtools::load_all` fotografa il pacchetto all'avvio: la suite si lancia DOPO
  l'ultima modifica.
* Se si tocca il recupero-nome, bumpare `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`
  (oggi **v7**), o il re-cluster riusa la cache e produce output stale.
* Run lunghi con `setsid` (verificare SID==PID), **mai** in background del tool.
* `ps -eo args | grep Rscript` non trova i processi R: il comando reale è
  `/usr/lib/R/bin/exec/R --file=...`. Usare `pgrep -f`.
* `sinfo` che dice `idle` sul DGX non basta: verificare il mount con un `srun`
  breve, o si ottiene `ExitCode 0:53` e zero log.
* `git add -A analysis/` porta dentro i binari di lavoro: 158 MB l'ultima volta.

---

## 9. MATERIALE

* `docs/findings/2026-08-13-tre-cambi-implementati.md` — i tre cambi, le misure, i limiti
* `analysis/audit/2026-08-13-rerun-prep/` — script ed evidenza (`README.md` con l'ordine)
  * `PREVISIONI-PRIMA-DEL-RUN.md` — il modello di come si deposita una previsione
  * `E4-scaling-worker.csv` — lo scaling misurato dei worker
* `docs/superpowers/specs/2026-08-10-correttezza-passo-passo-HANDOUT.md` §1 — la
  misura della riproducibilità con e senza la flag
* `docs/findings/2026-08-12-corsie-non-repliche.md` ·
  `2026-08-13-genetica-su-un-braccio-solo.md` ·
  `2026-08-10-sensitivity-confronti-spuri.md` · `2026-08-05-confronti-imperfetti.md`
* `analysis/audit/2026-08-08-deframmentazione/32-verdetti-8-fusioni.csv` e
  `38b-verdetti-10-fusioni-controllo.csv` — i verdetti sulle fusioni
* `CLAUDE.md` — lo stato in testa, aggiornato al 2026-08-16
