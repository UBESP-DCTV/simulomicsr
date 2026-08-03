# HANDOUT — v15 è pronto per il lancio. Che cosa fare, in ordine, e dove sono le trappole

**Scritto:** 2026-08-03 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato, nessun push
**Mandato dell'utente, invariato:** *«Il re-cluster v15 deve essere l'ultimo, altrimenti il progetto viene
dichiarato fallito.»*

> **Questo file è autosufficiente.** Non serve leggere la conversazione precedente. Contiene lo stato
> provato, i comandi esatti, l'atteso scritto **prima** del run, e le trappole con la loro misura.

---

## 0. LA COSA PIÙ IMPORTANTE

**Il lavoro di preparazione è finito e verificato. Il cancello è passato.** Restano tre cose, in
quest'ordine: lanciare il re-cluster (~9 h), verificare l'output, lanciare il re-pool (~28 h).

**Non c'è più niente da correggere prima di lanciare.** Se ti viene il dubbio di aggiungere «un'ultima
cosa», rileggi il §7: le cose che restano aperte sono elencate lì, e nessuna blocca il run.

---

## 1. STATO PROVATO — che cosa è cambiato dal 2026-08-01

27 commit su `review-scientific-consistency-2026-06-10`, albero pulito. Tredici task in TDD, ciascuno
con revisione indipendente, più una revisione finale sull'intero ramo e la rilettura dei 49 gruppi.

### Le correzioni che contano

| # | che cosa | perché contava |
|---|---|---|
| 1 | **glioblastoma tolto** dalle fusioni: restano `tgfb`→`HGNC:11766` e `il17`→`HGNC:5981` | dei 40 membri candidati, **39** avevano già l'entità dal ramo `anchor`; al ripiego ne arrivava **uno**, con una chiave di controllo assente nel gruppo bersaglio |
| 2 | **`record_id` reso univoco** (`<serie>__<comparison_id>__<indice>`) | lo Stadio 2 emette lo stesso `comparison_id` più volte su **bracci diversi** (291 studi). Si poolava sempre il primo: il gruppo del 17β-estradiolo poolava **14 righe su 44** di un altro composto, e **7 gruppi** perdevano uno studio intero (fra cui IFN-γ e JQ1, due case study) |
| 3 | **dedup su `contrast_entity`** invece che sull'anchor del primo membro | buttava **53 gruppi**, 49 dei quali orfani, con **zero record in comune** col gruppo che li assorbiva: tamoxifene ucciso da afimoxifene (k più piccolo!), testosterone dal suo antagonista, due gruppi di tubercolosi da un gruppo che si chiama «tubercolosi» ed è COVID |
| 4 | **verdetti mancanti = `NA`**, non «coerente» | il deliverable dichiarava tutti i gruppi coerenti **e** attestava una rilettura umana mai avvenuta |
| 5 | **re-pool fatale al minuto zero** se manca `VERDETTI_PATH` | il default puntava a un file inesistente e lo `stop()` sugli orfani era dentro un `tryCatch` che lo declassava a warning |
| 6 | **gate sulla de-frammentazione** nel re-cluster + smoke che la esercita | l'intersezione fra gli studi dello smoke e quelli toccati era **zero**; il pavimento di TGFB1 era 61 mentre v13 dà già 65 → un run con la regola inerte stampava «OK» |
| 7 | **provenienza** nell'artefatto (`run_id`, `dir`, `sha256` dei cluster) | non c'era modo di sapere da quale Stadio 3 venisse un risultato |
| 8 | script di re-pool **rinominato** e token derivato dall'ingresso | si autodichiarava v13, pretendeva v15, scriveva in `stage4-v14` — una cartella che punta al re-cluster **abbandonato** |

### Due difetti trovati solo dalla revisione finale, che nessuna revisione per-task poteva vedere

Il Task 4 aveva corretto la risoluzione degli identificatori **nel pacchetto**, ma lo script di re-pool
ne aveva **una copia propria**:

- `collect_sids()` restituiva **0 campioni invece di 2813** → il re-pool sarebbe girato a vuoto;
- il blocco di annotazione non agganciava mai nulla → **nove colonne** del deliverable uscivano NA in
  silenzio, e sono proprio quelle che misurano l'efficacia del pooling.

Corretti: `0 → 587` campioni, `0/102 → 102/102` identificatori agganciati.

### Il cancello, provato sui file

| misura | esito |
|---|---|
| suite intera | **0 FAIL / 4153 PASS** / 48 SKIP |
| suite della regola sui dizionari veri | **0 FAIL / 138 PASS / 0 SKIP** |
| smoke del re-cluster | **5 cluster de-frammentati**, 10,7 min, `run_id 7418a9a0` |
| impatto sul corpus (87.092 confronti) | **97 membri** (86 `tgfb` + 11 `il17`), cinque invarianti a **zero** |

---

## 2. LA FASE D0ter È GIÀ FATTA

I 49 gruppi che rientrano con la dedup corretta **non erano mai stati letti da nessuno**: il censimento
del 2026-07-28 non li ha visti perché erano già stati cancellati a monte.

Letti tutti, quattro lettori in parallelo, con le etichette **intere** (etichetta più lunga 85 caratteri,
nessun picco su 40/58/64 → non troncate). Esito: **31 coerenti, 17 incoerenti, 1 dubbio poi escluso
dall'utente**.

**Il file è pronto:** `analysis/audit/2026-08-02-fix/verdetti-poolato-v15.csv` — **24 verdetti di
incoerenza** (6 del censimento 2026-07-29 + 18 nuovi). È quello da passare al re-pool.

Recuperi veri che il deliverable non aveva: **crizotinib** (42 membri, tutti farmaco contro veicolo),
**tamoxifene**, **BRCA1 e BRCA2** come due meta-analisi distinte, fibrosi cistica, epatoblastoma.

Scarti, per meccanismo: entità che è una classe (4, fra cui un ID ChEMBL generico «INTERFERON» che
mescolava IFN-α e IFN-γ, e il segnaposto `unidentified`); il nome della categoria usato come entità (1);
clinico contro sperimentale (4); il controllo che non è un controllo (4, fra cui epatocarcinoma contro
**HepG2**, che è una linea di epatocarcinoma); materiali incompatibili (3).

---

## 3. I COMANDI, in ordine

### 3.1 Il re-cluster (~9 h)

```bash
cd /home/user/simulomicsr
setsid nohup env SMOKE=0 Rscript analysis/p4-fase-f12-stage3-v15-defrag.R \
  > analysis/audit/2026-08-02-fix/40-recluster-v15.log 2>&1 < /dev/null &
sleep 5; ps -eo pid,sid,args | grep 'f12-stage3-v15' | grep -v grep   # SID deve essere == PID
```

**Aggiornamento ORARIO obbligatorio** durante il run (preferenza dell'utente, memoria
`feedback_hourly_updates_during_long_runs`).

⚠️ **Per aspettare, usa il PID, mai un pattern di testo.** Un ciclo `while pgrep -f 'testthat|...'`
trova **se stesso** e non esce mai: è già successo in questa sessione e ha bloccato la lavorazione.
```bash
while ps -p <PID> >/dev/null 2>&1; do sleep 300; done
```

⚠️ **Non lanciare mai una suite di verifica mentre un run scrive i file**: `test_dir` legge i file di
test man mano e produce un misto di codice vecchio e test nuovi, cioè una misura senza significato.
Anche questo è già successo, e ha prodotto 5 fallimenti fantasma.

### 3.2 La verifica dell'output (subito dopo, ~30 min)

**Le cinque invarianti vanno ri-misurate sull'OUTPUT VERO**, non sul dump: il dump non vede il ramo
`anchor`, che precede la de-frammentazione. Sull'output `clusters.rds`:

1. `contrast_entity_source == "defrag"` su **più di zero** cluster (lo script si ferma da solo se è zero);
2. `HGNC:11766` (TGFB1): **k > 65**, atteso **78**;
3. `HGNC:5981` (IL17A): **k > 8**, atteso **12**;
4. **nessun** cluster con `contrast_entity` in `STR:tgfb`, `STR:tgf_b`, `STR:il17`, `STR:il_17`;
5. `MeSH:D005909` (glioblastoma) **invariato** rispetto a v13 (k=3): non deve crescere.

Più i pavimenti bandiera, che lo script controlla da solo: SARS 38, TGFB1 61, LPS 41, enzalutamide 29,
vemurafenib 19.

### 3.3 Il re-pool (~28 h)

```bash
STAGE3_DIR=<la dir v15 appena prodotta> \
VERDETTI_PATH=analysis/audit/2026-08-02-fix/verdetti-poolato-v15.csv \
setsid nohup Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R \
  > analysis/audit/2026-08-02-fix/50-repool-v15.log 2>&1 < /dev/null &
```

Entrambe le variabili sono **obbligatorie**: senza, lo script si ferma al minuto zero. È voluto.

---

## 4. L'ATTESO, scritto PRIMA del run

Il documento completo è `analysis/audit/2026-08-02-fix/00-atteso-v15.md`. In sintesi, **tre effetti
distinti sul deliverable, che vanno riportati separati**:

| effetto | conseguenza |
|---|---|
| **1. de-frammentazione** | il deliverable perde **una riga**: `STR:tgfb` (oggi riga a sé, k_effective 9) confluisce in TGFB1. Da 191 a **190** |
| **2. dedup corretta** | i gruppi candidati passano da 305 a **354**; ne sopravvivono al gate del pooling una parte, stima **~215-225** righe finali |
| **3. `record_id` univoco** | **sette gruppi** cambiano k: vemurafenib 8→9, gefitinib 7→8, ciclosporina A 3→4, IFN-γ 19→20, IL1B 17→18, gemcitabina 4→5, JQ1 24→25. E il gruppo del 17β-estradiolo smette di poolare 14 righe di un altro composto |

⚠️ **Senza questa separazione, un conteggio finale diverso da 191 verrà letto come regressione** invece
che come il risultato voluto. È il modo più facile di arrivare a una sedicesima versione.

Altri numeri attesi: `run_id` dello Stadio 3 **diverso da `364547a7`** (lo smoke ha dato `7418a9a0`);
verdetti di incoerenza nel deliverable: **24**, non 6.

---

## 5. LE TRAPPOLE, con la loro misura

1. **Il dump `impatto-membri-*.rds` non vede il ramo `anchor`** e non modella la guardia di completezza:
   è un sovrainsieme di circa il doppio. Qualunque numero preso da lì va incrociato con
   `assignments.parquet`.
2. **`timeout 3000` non basta per lo smoke** (~11 min ma con contesa può superare): usare `setsid`.
3. **La cache dei conteggi dello Stadio 4** (8,9 GB) verrà riusata e **non contiene il percorso dell'H5**:
   finché l'H5 non cambia va bene, ma è un difetto latente dichiarato.
4. **Il Layer B va ricostruito col deliverable del run nuovo**: ora lo script si ferma se non lo trova,
   ma le **note del CSV di selezione** contengono 181 numeri di v13 scritti a mano, e vanno rigenerate
   dopo il re-pool. È il canale che nessuna guardia può intercettare, perché è testo libero.

---

## 6. LEZIONI DI METODO, da questa sessione

Tre errori, tutti della stessa famiglia — **lo strumento vede meno del dato**:

- un guardiano che cercava i processi per nome e trovava **se stesso**;
- una suite lanciata mentre un altro processo riscriveva i file, che ha misurato un albero a metà;
- una ricerca di affermazioni false per frase intera, che ha mancato la stessa affermazione **riscritta
  con parole diverse** (cercava «130 su 923», il residuo diceva solo «923» e «14,1%»).

Il rimedio che ha funzionato non è stare più attenti: è **far ricontrollare a qualcun altro con occhi
diversi**. La revisione finale ha trovato due difetti bloccanti che dodici revisioni per-task non
potevano vedere, perché nascevano dall'**interazione** fra task sviluppati separatamente.

---

## 7. CHE COSA RESTA APERTO — e non blocca il lancio

- le **note del CSV di selezione** Layer B (181 numeri v13), da rigenerare dopo il re-pool;
- `load_stage4()` non rilegge il campo di provenienza nel round-trip (si legge dal JSON);
- tre script di audit fuori dal pacchetto usano `== "coherent"` senza `na.rm`: ora che il valore può
  essere NA, darebbero NA visibile invece di un numero sbagliato;
- l'attributo degli scartati prodotto dalla dedup **non viene scritto in nessun file**: i 4 cluster
  tolti non compariranno da nessuna parte nel run v15;
- il messaggio del commit `f0907fc` contiene ancora il numero infondato «130 su 923»: la storia git non
  si riscrive, e tutti i file che quel commit ha introdotto ora lo smentiscono citandolo.

---

## 8. SE QUALCOSA VA STORTO

Il deliverable **v13 resta valido e completo** (191 meta-analisi, validate biologicamente: DHT agonista
ed enzalutamide antagonista danno segni opposti sugli stessi bersagli). Se v15 fallisce non si perde
nulla di scientifico: si perde la de-frammentazione, che diventa un limite dichiarato nei Methods, e
restano comunque acquisite tutte le correzioni di questa sessione — che valgono indipendentemente dalla
fusione.
