# HANDOUT — che cosa resta, in sequenza

**Scritto:** 2026-08-16 · **Branch:** `review-scientific-consistency-2026-06-10` (pushato)
**master invariato** · Commit di riferimento: `d92f505`..`d7d6888`

> **Autosufficiente.** Non serve la conversazione precedente. Va letto per intero
> prima di toccare qualsiasi cosa.

---

## 0. DOVE SIAMO

Il ciclo Stadio 3 + Stadio 4 è stato **rifatto per intero e verificato**.

| | |
|---|---|
| Stadio 3 | `analysis/p4-output/20260814T025911Z-stage3-v16-7f986159` (9 h 21 m) e `20260815T231154Z-stage3-v16-7f986159` (2 h 28 m, parallelo) — **`identical()` fra i due** |
| Stadio 4 | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d` |
| deliverable | **211 meta-analisi** (v15: 214), 200 coerenti + 11 incoerenti dichiarate, 0 NA |

**Tutte le previsioni depositate prima del run sono tornate**: 211 righe e dodici
`k_eff` su dodici (TNF 38, ipossia 33, SARS-CoV-2 36, IL-6 11, IL-15 5, IFN-β 6,
IFN-γ 19, IL-4 9, IL5RA 11, IMPDH2 5, *S. aureus* 3, TGF-β1 59). Le tre righe
uscite rispetto a v15 sono tutte spiegate: *S. epidermidis* sotto il gate per le
corsie, TNF-CHEMBL e `STR:ifnb` **assorbiti** dalle fusioni (i loro studi sono
dentro i vincenti).

Finding: `docs/findings/2026-08-13-tre-cambi-implementati.md`.
Evidenza e script: `analysis/audit/2026-08-13-rerun-prep/` (README con l'ordine).
Previsioni depositate + la loro correzione: `PREVISIONI-PRIMA-DEL-RUN.md`.

---

## 1. CHE COSA RESTA, IN SEQUENZA

### PASSO 1 — Layer B sul deliverable nuovo (mezza giornata)

La vetrina attuale (`20260806T022106Z-layer-b-81f379d3`, 9 bundle) è costruita su
**v15**: numeri e composizione dei gruppi non sono più quelli. Va rigenerata.

1. **Rigenerare la selezione DAL DELIVERABLE**, non riusare il CSV vecchio: il
   2026-08-05 il CSV di v13 portava 181 numeri scritti a mano nelle note, e le
   note sono l'unico canale che nessuna guardia intercetta perché è testo libero.
   Script: `analysis/70-selection-v15.R` (da adattare al percorso v16b).
2. Le nove scelte di **ADR-0027** vanno **ri-verificate sui k nuovi**, non
   riconfermate: TGF-β1 resta 59, ma TNF passa da due righe a una da 38 studi e
   IFN-β da 3 a 6 — la vetrina potrebbe cambiare.
3. **Aprire i PNG.** I sette criteri automatici erano tutti PASS mentre il forest
   mostrava i geni sbagliati (2026-08-06). I criteri sono misure, non garanzie.
4. Le **narrative** dei bundle sono bozze e vanno riscritte sui numeri nuovi.

### PASSO 2 — I Methods (una giornata)

Il materiale è tutto misurato, manca la scrittura. Ci vanno, come limiti
dichiarati e non come note a piè di pagina:

* **la dominanza**: 119 righe su 211 hanno uno studio che pesa più della metà, 75
  valgono meno di due studi efficaci (`k_kish`);
* **i confronti imperfetti**: 38 su 533 poolati = 7,1%, peso contaminato mediano
  8,8%, estremi 0,0–15,9%, il peggiore è **LPS**;
* **il gate seleziona per controllo interno, non per correttezza biologica**: può
  concentrare l'errore;
* **le corsie**: 7 confronti tolti, e la ragione (un solo campione biologico per
  condizione in GSE173902);
* **la genetica su un braccio solo**: 5 confronti scartati, di cui 2 da uno studio
  in cui la parola «transgene» è **inventata dallo Stadio 2** (GSE156472: nei
  metadati GEO non esiste);
* **le fusioni**: 5 entità e 2 controlli, con le tre respinte e il perché.

⚠️ **Sei documenti riportano ancora il peso contaminato SBAGLIATO** (`0,7–33,7%`,
«il peggiore è IL1B»). I numeri veri sono sopra. Vanno corretti prima di scrivere:
`grep -rn "33,7" docs/ analysis/`.

### PASSO 3 — Il re-run degli stadi LLM (decisione utente, poi 2 giorni)

È il pezzo mancante del mandato originale: Stadio 1 e 2 su DGX con
`VLLM_BATCH_INVARIANT=1`.

⚠️ **Prima di lanciarlo, sapere questo**: la flag rende riproducibile il run
**nuovo**, non fa coincidere il nuovo col vecchio. Senza flag due esecuzioni
identiche dello Stadio 1 davano lo stesso record nel **40,4%** dei casi (Stadio 2
62,0%; `agent_normalized.id` 86,0%; confronti per identità dei campioni 92,0%).
Quindi **il deliverable cambierà per motivi indipendenti dai fix**, e le previsioni
di questa sessione non valgono più: ne va depositata una nuova, con il suo
strumento.

Ordine: Stadio 1 → Stadio 2 → re-cluster → re-pool → confronto con v16b.
⚠️ `sinfo` che dice `idle` **non basta**: verificare il mount con un `srun` breve.

### PASSO 4 — Le pendenze piccole

1. **Avanzamento per blocco nel ramo parallelo dello Stadio 3**: oggi durante la
   fase 6 si vede solo che i worker sono vivi (con 32 worker le righe di
   avanzamento arriverebbero fuori ordine, quindi le ho tolte). Serve un
   contatore per blocco.
2. **158 MB di binari nella storia del branch**: tolti dall'indice
   (commit `ac889bb`) ma ancora nei commit precedenti. Toglierli davvero
   richiede una riscrittura della storia: **decisione utente**.
3. `covariate_drops` è nuovo in `qc_report` (4.950 righe): nessuno lo ha ancora
   letto. Potrebbe dire qualcosa sulle covariate batch.

---

## 2. COME SI LANCIANO I RUN, CON I DEFAULT MISURATI

```bash
# RE-CLUSTER Stadio 3 — ~2 h 30 m con 32 worker (9 h 21 m in serie)
SMOKE=0 setsid nohup Rscript analysis/p4-fase-f13-stage3-v16-tre-cambi.R \
  > analysis/audit/<data>/recluster.log 2>&1 < /dev/null &
ps -eo pid,sid,args | grep "[f]13-stage3"     # SID deve essere == PID

# RE-POOL Stadio 4 — ~75 min in 16 pezzi (32 h 30 m in un pezzo solo)
PD=/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16-pezzi
for i in $(seq 1 16); do
  PEZZO=$i N_PEZZI=16 PEZZI_DIR=$PD \
  STAGE3_DIR=<dir stadio 3> \
  VERDETTI_PATH=analysis/audit/2026-08-02-fix/verdetti-poolato-v15-applicabili.csv \
  setsid nohup Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R \
    > <log>-$i.log 2>&1 < /dev/null &
done
# poi, quando tutti e 16 hanno scritto:
PEZZI_DIR=$PD STAGE3_DIR=<dir> VERDETTI_PATH=<csv> \
  Rscript analysis/p4-fase-f5b-stage4-ricomponi-pezzi.R
```

**I default sono misurati, non scelti** (`E4-scaling-worker.csv`): 32 worker per
lo Stadio 3 (accelerazione 10,65×; a 64 peggiora, il collo è la raccolta dei
risultati via pipe), 16 pezzi per il re-pool (5–9 GB a pezzo; il limite vero è il
**cluster più lento, 48 minuti**).

⚠️ **I verdetti da passare sono quelli APPLICABILI** (11 righe), non tutti e 24:
13 riguardano gruppi che non superano il gate del pooling e la guardia — fatale e
giusta — ferma il run a fine corsa. Prova: `analysis/audit/2026-08-02-fix/81-verdetti-tolti-e-perche.md`.

---

## 3. COME COMPORTARSI CON L'UTENTE

**È uno scienziato, non un developer.** Non «chiudere un prodotto»: stabilire che
cosa è vero. Niente tempistiche se non le chiede. Raccomandare una strada per
merito scientifico, mai perché è più corta; se la più lunga è quella giusta, dire
quella.

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

**Prima di chiamare «nuovo» un difetto, cercarlo negli audit esistenti** (due
minuti di `grep`).

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

**Se spiega qualcosa da non addetto ai lavori**: niente gergo non spiegato, niente
rassicurazioni; i termini tecnici e i nomi di codice restano in originale, il
resto in italiano semplice.

**Vincoli fissi**: branch `review-scientific-consistency-2026-06-10`, **master
invariato**, il push lo fa l'utente (salvo richiesta esplicita). **Nessun
re-cluster e nessun re-pool senza un suo via.** `Rscript` senza `--vanilla`.

---

## 4. TRAPPOLE GIÀ PAGATE, IN QUESTO CODICE

**Sui dati e sulle regex**

* `\b` in R non vede il confine dopo `_` **né dopo una cifra**: `p63shRNA` non
  matcha. Pagata **cinque** volte.
* Il nome del campo non è il suo valore: `genetic_knockdown=no knockdown` non è
  una manipolazione genetica. Ma anche il contrario: **un `=` dentro una frase non
  è un campo** — `LNCaP-abl shKDM3B1 t=7` non va tagliato (115 etichette mutilate).
* Nei JSONL gli scalari sono array di un elemento: `isTRUE(list(FALSE))` è sempre
  FALSE. E `is.numeric(list(0))` pure — ha prodotto «36 flag senza evidenza» che
  non esistevano.
* `order()` ha un parametro `method`: `do.call(order, df[cols])` con una colonna
  che si chiama `method` esplode. Spogliare i nomi con `unname()`.

**Sul misurare**

* **Misurare l'oggetto reale, non quello simulato.** Il 13 agosto ho verificato le
  fusioni passando al dispatch l'unione dei record **a mano**: ho misurato ciò che
  volevo vedere, non ciò che il codice fa. Il difetto è emerso dopo 32 ore di
  calcolo.
* **I test devono guardare l'ultimo anello, non l'etichetta.** Quelli della
  fusione controllavano il `k` nel data.frame; nessuno controllava il dispatch,
  che è ciò da cui il pooling pesca.
* **Prima di depositare previsioni su un re-run, guardare il `git log` del codice
  dall'ultimo run.** Il fix IFN-β era entrato il 9 agosto con scritto «si
  materializza solo al prossimo re-cluster», e non l'avevo cercato.
* **Il censito non è il poolato**: `n_min` lascia fuori più della metà dei
  confronti assegnati.

**Sull'esecuzione**

* **Un `warning` fra cinquanta non è un avviso.** Un meccanismo che tocca le stime
  o è acceso o si ferma: la degradazione silenziosa è costata un re-pool intero.
* `devtools::load_all` fotografa il pacchetto all'avvio: la suite si lancia DOPO
  l'ultima modifica.
* Se si tocca il recupero-nome, bumpare `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`
  (oggi **v7**), o il re-cluster riusa la cache e produce output stale.
* Run lunghi con `setsid` (verificare SID==PID), **mai** in background del tool.
* `ps -eo args | grep Rscript` non trova i processi R: il comando reale è
  `/usr/lib/R/bin/exec/R --file=...`. Usare `pgrep -f`.
* `git add -A analysis/` porta dentro i binari di lavoro: 158 MB, uno da 64.

---

## 5. MATERIALE

* `docs/findings/2026-08-13-tre-cambi-implementati.md` — i tre cambi, le misure, i limiti
* `analysis/audit/2026-08-13-rerun-prep/` — script ed evidenza (`README.md` con l'ordine)
  * `PREVISIONI-PRIMA-DEL-RUN.md` — previsioni depositate + la correzione a 211
  * `E4-scaling-worker.csv` — lo scaling misurato dei worker
* `docs/findings/2026-08-12-corsie-non-repliche.md` · `2026-08-13-genetica-su-un-braccio-solo.md`
  · `2026-08-10-sensitivity-confronti-spuri.md`
* `analysis/audit/2026-08-08-deframmentazione/32-verdetti-8-fusioni.csv` e
  `38b-verdetti-10-fusioni-controllo.csv` — i verdetti sulle fusioni
* `CLAUDE.md` — lo stato in testa, aggiornato al 2026-08-16
