# HANDOUT — De-frammentazione: ricontrollare tutto prima del re-pool

**Scritto:** 2026-08-08 a fine sessione · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun push · NESSUN re-cluster e NESSUN re-pool eseguiti**

> **Questo file è autosufficiente.** Non serve leggere la conversazione precedente.

---

## 0. Dove siamo, in tre righe

Il meccanismo per de-frammentare il deliverable **esiste, è testato e è SPENTO**
(default `NULL`: con le mappe assenti la pipeline si comporta in modo verificato
identico a prima). Esiste una misura del guadagno. **Non esiste il diritto di
lanciare il re-pool**, perché una parte dei numeri viene da letture di agenti che
la sessione precedente ha riferito senza verificare, e due volte quei numeri erano
gonfiati.

**Il compito di questa sessione non è lanciare. È ricontrollare.**

---

## 1. ⚠️ PERCHÉ VA RICONTROLLATO — tre errori di metodo, dichiarati

La sessione del 2026-08-08 ha riferito all'utente **tre affermazioni sbagliate**,
tutte scoperte dopo, e tutte gonfiate nella stessa direzione:

1. **«Due righe della vetrina hanno l'etichetta del gene sbagliata» (IL22 → «IMPDH2»,
   IL21 → «IL5»).** FALSO come difetto: quello è il valore di `canonical_name`, la
   colonna **legacy** che per scelta documentata non viene mai sovrascritta.
   `contrast_entity_label` — la colonna che le figure usano — dice IL22 e IL21,
   correttamente. Verificato aprendo il bundle del DHT: «4-maleylacetoacetate» non
   compare da nessuna parte, né in didascalie né in SVG.
2. **«Cinque righe di virus hanno il nome sbagliato».** FALSO per le due che stanno
   nel deliverable: `contrast_entity_label` dice «HCMV (human cytomegalovirus)» e
   «Influenza A virus», con `contrast_entity_label_source == "override"` — cioè il
   lavoro sulle etichette del 2026-07-30 aveva **già trovato e corretto a mano
   esattamente quei due casi**. Le altre tre non sono fra le 214.
3. **«Nel gruppo dell'influenza c'è uno studio che è fluvastatina e contribuisce
   alla stima».** Metà falso: `GSE134817` **è** fluvastatina (bracci `Ato`/`Ros`/
   `Sim`/`Statins`/`Flu`, riassunto «effects of various statins») ma **NON è fra i
   7 studi che contribuiscono** — cade al gate dei controlli interni. Ed era **già
   scritto** nel verdetto di coerenza dell'influenza, che lo nomina fra i due studi
   sperimentali caduti.

**La causa comune: relay senza verifica.** Gli agenti hanno prodotto letture utili
e in gran parte corrette, ma la sessione le ha riportate all'utente prima di
controllarle sull'artefatto. **Regola per questa sessione: nessun numero di un
agente entra in una decisione se non è stato rimisurato in modo indipendente.**

---

## 2. CHE COSA È SOLIDO — verificato sui dati veri, non sulle fixture

Ognuna di queste è stata misurata direttamente, e va **rifatta** come primo passo
(sono minuti, e sono la base di tutto il resto).

| fatto | come si ricontrolla |
|---|---|
| **Lo strumento è calibrato.** Riproduce il funnel: 11.536 `cgroup` → 355 pre-dedup → **351 candidati** → **214 poolate + 137 scartate**, zero orfani. `k_eff` confrontato col deliverable vero: **214/214, scarto min 0 max 0**; 137/137 coerenti col motivo (`k_eff=0/1/2`). Il pre-filtro H5 costa **zero** studi su tutti e 351 | `analysis/audit/2026-08-08-deframmentazione/00-funnel-e-calibrazione.R`, `10-strumento-keff.R`. Confronto contro `deliverable-annotato.rds`, **non** contro i CSV degli agenti |
| **Non-regressione col codice nuovo e mappe spente**: 351 candidati, insieme dei `cluster_id` identico, `k` invariato su tutti | `.identify_layer_a_clusters(cl, stage4_default_config())` contro `02-keff-mio-351.csv` |
| **v14 fu davvero eseguito con la regola generale**: nell'output v14 ci sono **398 cluster** con `contrast_entity_source == "defrag"` su **356 entità** (in v15 sono 3 su 2). Esito: gruppi del deliverable Stadio 3 **305 → 304** | `analysis/p4-output/20260801T081819Z-stage3-v14-364547a7/clusters.rds`; `analysis/audit/2026-07-31-defrag/50-antistale-v14.log` |
| **Zero verdetti orfani** con entrambe le mappe accese (0 su 11). Un verdetto orfano fermerebbe l'annotazione a fine run | `analysis/audit/2026-08-02-fix/verdetti-poolato-v15-applicabili.csv` contro le chiavi post-fusione |
| **Il dispatch ha già la guardia contro il doppio conteggio**: salta la coppia (studio, gruppo trattato) già vista | `R/stage4-dispatch.R:377` |
| **Il match delle chiavi di controllo è sulla chiave INTERA** (`%in% names(...)`), quindi `uninfected_clin` e `vehicle_untreated_clin` **non** si fondono | `R/stage4-qc.R`, blocco «CHIAVE DI CONTROLLO CANONICA» |
| **Costo del re-pool: 31,0 ore** = somma dei tempi per cluster (mediana 448 s, massimo 2.809 s, 214 cluster). Cache dei conteggi: 27.940 voci, 9 GB → un re-pool sugli stessi cluster Stadio 3 non rilegge l'H5 | tempi in `analysis/audit/2026-08-02-fix/50-repool-v15.log` |
| **`canonical_name` diverge dall'etichetta risolta su 111 righe su 214**, 13 con marcatura HTML (`2<em>H</em>-azirine`). Non è un difetto aperto: è tracciabilità dell'output LLM. **Ma nessuna delle 111 è mostrata nelle figure** | `analysis/audit/2026-08-08-deframmentazione/40-canonical-name-ingannevole.csv` |

### La vetrina è stata sistemata, e questo è chiuso

Difetto trovato **aprendo la figura**: il forest del DHT (figura 1 del main paper)
mostrava `RBP5` **e** `RBP5.1` — lo stesso gene due volte — e in cambio perdeva
COPS3; la tabella dello stesso bundle mostrava RBP5 una volta sola. Causa:
`.rank_and_dedup_genes()` è chiamata da tabella, heatmap e volcano, e il forest ne
aveva **copiato solo l'ordinamento, non la deduplica**; il `make.unique()` a valle
mascherava il difetto. Ampiezza misurata sugli SVG: **2 su 9** (DHT `RBP5.1`, JQ1
`ZNF445.1`).

Corretto in TDD (commit `466c15d`), vetrina rigenerata in
`analysis/p4-output/20260808T063421Z-layer-b-81f379d3`, e **verificato
sull'artefatto**: zero doppioni in tutti e 9 i forest, il posto liberato va a un
gene vero (DHT → **COPS3**, JQ1 → **HIF1AN**), dieci geni distinti per figura.

Delta completo del rebuild, dichiarato: 2 forest (la correzione) + 1 volcano (solo
pixel, etichette identiche — e fra le **due vetrine precedenti**, senza codice mio
in mezzo, ne differivano **otto**: non-determinismo pre-esistente) + 9 tabelle GO
(**1046 righe confrontate: zero differenze di statistiche, zero differenze negli
insiemi di geni**, cambia solo l'ordine dei nomi dentro una stringa). Tutto il
resto byte-identico.

⚠️ **Due difetti di tracciabilità trovati e non risolti**: (a) il `run_id` della
vetrina nuova è **identico** a quello della vecchia (nasce da run Stadio 4 +
selection + config + versioni di schema, e la correzione non ne cambia nessuno) →
due artefatti diversi con la stessa targa; (b) la `selection_sha256` nel
`run_metadata` è il digest di un **oggetto in memoria** e non è ricalcolabile dal
CSV scritto → non può provare che la selection è invariata (il confronto colonna
per colonna sì, ed è identico).

---

## 3. CHE COSA È RIFERITO E NON VERIFICATO — la lista da chiudere

**Questo è il cuore del compito.** Tutto quanto segue viene dal giudizio di agenti
che hanno letto etichette. I `k_eff` sono stati rimisurati; **i giudizi no**.

### 3a. La regola che genera i candidati
Mai eseguita in modo indipendente. Prodotta da un agente in
`analysis/audit/2026-08-08-deframmentazione/20-regola-risoluzione.R`.
Afferma: **1.367 equivalenze** fra registri nei dizionari, di cui **15 coppie con
entrambi gli ID nel corpus** → 13 entità spezzate, 43 cluster, 105 studi-slot.
Tier: T1 canonico↔canonico, T2 canonico↔alias, T3 alias↔alias.
**Da ricontrollare:** i 1.367; le 15; la classificazione in tier; e soprattutto
**la precisione dichiarata** (T1 20/20, T2 13/15, T3 3/5 su un campione di 40;
4-5 sbagliate su 15 applicate al corpus). Nessuna di queste cifre è stata
riprodotta.

### 3b. I verdetti di contrasto — 22 giudizi, nessuno riverificato
Tre agenti hanno letto le etichette **intere** di 200 + 237 + 123 confronti e dato
verdetti «stesso contrasto / contrasti diversi / incerto»:

- **8 fusioni di scrittura** (`32-verdetti-8-fusioni.csv`): 5 approvate, 3 bocciate
  — IL-10 (un membro ha come trattato «activated *in the absence of* IL-10»:
  verso invertito), GM-CSF (5 membri su 13 misurano differenziazione),
  «Compound 4» (identità sbagliata: il ponte è l'alias generico `compound4`; da un
  lato una serie med-chem, dall'altro WM-1119, inibitore KAT6A).
- **4 fusioni di controllo** (`36-verdetti-4-fusioni-dedup.csv`): ipossia e SARS
  stesso contrasto, epatite B incerto, obesi stesso contrasto (guadagno zero).
- **10 fusioni di controllo** (`38b-verdetti-10-fusioni-controllo.csv`): 7 stesso
  contrasto, RSV contrasti diversi, `STR:symptomatic` incerto, ATRA guadagno zero.

**Da ricontrollare:** i verdetti sui casi che **cambiano il deliverable**, cioè
sette righe (ipossia, TNF, SARS, IL15, CMV, IL6, influenza A) più il candidato
nuovo (KSHV). Gli altri quattordici non toccano il poolato e possono restare
riferiti, **dichiarandolo**.

### 3c. L'argomento che ha fatto ribaltare la normossia
Riferito: «il cluster vincente dell'ipossia poola già controlli scritti `Untreated`
e `Control`, e lo scartato ne ha tre che nominano la normossia, quindi il confine
non separa nulla». **L'utente ha autorizzato il ribaltamento sulla base di questo
argomento, che non è stato verificato.** Vale +8 studi, il guadagno più grande di
tutta la sessione: **va riletto per primo.**

### 3d. Misure minori mai riprodotte
`control_type` che dissente dalla chiave di controllo su 20 membri su 200 e 86 su
237; le identità tassonomiche dei virus; i conteggi del troncamento.

---

## 4. IL CODICE NUOVO — cosa fa, ed è spento

Tre commit su `review-scientific-consistency-2026-06-10`:

- `466c15d` — la deduplica dei geni nel forest (vetrina). **Già in effetto.**
- `432ef43` — l'evidenza della misura, 45 file d'audit.
- `ef0cf49` — **il meccanismo di fusione. Spento per default.**

`.dedup_rem_group_by_entity(rem_group_clusters, entity_canonical = NULL,
control_canonical = NULL)` in `R/stage4-qc.R`:

1. **PASSO 1 — FUSIONE.** Stessa entità canonica + stesso verso + stessa chiave di
   controllo canonica → i record del perdente vengono poolati **col** vincente. Il
   `k` del vincente diventa il numero di studi **distinti** dell'unione. Il
   vincente porta le chiavi **canoniche** (l'originale resta scritto in
   `attr(out, "fusioni")`).
   Condizione stretta: almeno **due coppie distinte** (`contrast_entity` grezzo,
   `contrast_control_key` grezza) e `contrast_entity` popolato su tutti i membri.
   Con le mappe assenti **non può accendersi**.
2. **PASSO 2 — lo SCARTO di sempre**, invariato.
3. **Il filtro `k >= 3` è stato spostato DOPO la fusione** in
   `.identify_layer_a_clusters()`. Prima stava prima, e le scritture piccole
   cadevano al gate senza che la dedup le vedesse: è il motivo per cui IL6 (k=10 +
   k=1) e IL15 (k=4 + k=2) non si fondevano.
4. Config: `stage4_default_config()$rem_group$entity_canonical` e
   `$control_canonical`, entrambe **NULL**.

**Test:** `tests/testthat/test-stage4-forest-dedup.R` (forest) e
`test-stage4-dedup-fusione.R` (fusione, **39 asserzioni**, viste fallire prima del
codice). ⚠️ **La suite `stage4` completa era ancora in corso a fine sessione (158
file, nessun fallimento fino a quel punto): va rieseguita e il suo esito va letto,
non assunto.** Comando: `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="stage4", reporter="summary")'` **senza** `head` in pipe (un `head` chiude la pipe e tronca la suite: è già successo).

---

## 5. I NUMERI PROPOSTI — da non usare finché non sono ricontrollati

Con entrambe le mappe accese, misurati con lo strumento calibrato:

| riga | k_eff ora | k_eff dopo | | coerenza dichiarata |
|---|---:|---:|---:|---|
| ipossia | 25 | 33 | +8 | coherent |
| TNF | 32 | 38 | +6 | coherent |
| SARS-CoV-2 | 34 | 36 | +2 | coherent |
| IL15 | 3 | 5 | +2 | coherent |
| citomegalovirus | 9 | 10 | +1 | coherent |
| IL6 | 10 | 11 | +1 | coherent |
| influenza A | 7 | 8 | +1 | **incoherent** |

**+21 studi su 7 righe** (20 su gruppi coerenti). Candidati 351 → 354. Righe del
deliverable **214 → 214**: −1 perché le due righe del TNF diventano una, +1 perché
nasce **KSHV a k=3**.

Le mappe usate per la misura (⚠️ **input di misura, non configurazione**):

    entity_canonical:
      CHEMBL:CHEMBL265582  -> HGNC:11892     TNF, gene e proteina ricombinante
      MeSH:D015850         -> HGNC:6018      IL-6, descrittore MeSH e gene
      CHEMBL:CHEMBL4297989 -> HGNC:5977      IL-15 ricombinante non glicosilata
      CHEMBL:CHEMBL437472  -> CHEBI:80240    endotelina-1
      CHEMBL:CHEMBL1852688 -> CHEBI:63451    infigratinib / BGJ-398
    control_canonical:
      normoxia   -> vehicle_untreated   (ribalta una scelta deliberata)
      uninfected -> vehicle_untreated   (dimenticanza: `mock` c'è, `uninfected` no)
      lean       -> vehicle_untreated   (dimenticanza: `normal`/`healthy` ci sono)

⚠️ **La mappa dei controlli è un VOCABOLARIO: si applica a tutto il corpus.** Il
primo lettore ne aveva giudicate 4, la correzione produce **13**. Le altre 9 sono
state lette dopo, ma questa è la forma esatta dell'errore che il progetto ha già
pagato tre volte (regola misurata su pochi casi, applicata a centinaia) e va
ricontrollata come tale.

---

## 6. LE DECISIONI APERTE (tutte dell'utente)

1. **Il ribaltamento della normossia** vale +8 ed è appeso a un argomento non
   verificato (§3c). Se l'argomento non regge, il guadagno totale scende da +21 a
   +13.
2. **KSHV**: nasce una meta-analisi a k=3 esatti, in un gruppo che è ancora un
   **frammento** (altre scritture KSHV non fuse), nella fascia in cui il progetto
   ha misurato l'80% di gruppi dominati da un solo studio. Tenerla fuori
   richiederebbe un'eccezione scritta a mano; accettarla contraddice la promessa
   «zero meta-analisi nuove». **La sessione precedente ha proposto di accettarla e
   lasciare che `k_kish`/`dominato` la dichiarino: è una proposta, non una
   decisione.**
3. **Vocabolario generale contro fusioni selettive.** `uninfected` produce 10
   fusioni. Tenerlo generale è coerente; restringerlo è un'eccezione.
4. **Ampiezza del re-pool.** La sessione ha proposto il re-pool **intero** (31 h)
   invece di uno mirato (~1 h), perché un re-pool parziale rende il deliverable
   **misto** (righe da due run, versioni di pacchetto diverse) e richiederebbe una
   macchina nuova per fondere i pezzi. Anche questa è una proposta.
5. **L'architettura della mappa.** La sessione ha concluso di **non** portare la
   regola generale in produzione, e di usare la forma di `.CA_DEFRAG_ACCEPT`:
   candidati generati da una regola + accettazione umana scritta con la prova +
   mappa accettata nel pacchetto. **È una lista rivista da un umano, e va detto
   così.** In produzione la regola generale ha già dato 923 fusioni, 61 identità
   sbagliate e un deliverable più piccolo.

---

## 7. IL MATERIALE

**Dati.** Stadio 3 v15: `analysis/p4-output/20260803T164558Z-stage3-v15-7f986159/`
(`clusters.rds` 322.415 cluster, `assignments.parquet`).
Deliverable v15:
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/`
(`deliverable-annotato.rds` 214 righe, `cluster_pooled.parquet`,
`per_study_de.parquet`, `non_processable.rds` 137).
Stadio 2: `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`.
Verdetti di coerenza (ingresso del run):
`analysis/audit/2026-08-02-fix/verdetti-poolato-v15-applicabili.csv`.
Vetrina corretta: `analysis/p4-output/20260808T063421Z-layer-b-81f379d3/`.

**Audit di questa sessione** — `analysis/audit/2026-08-08-deframmentazione/`:
`00`/`10`/`20-cecita` calibrazione e strumento · `20-regola-risoluzione.R` la regola
· `21`-`24` frammentazione · `25`/`28` canary e giudizi · `26` guardie e cecità ·
`30` le 8 fusioni entro il controllo · `31`/`32` materiale e verdetti (asse
scrittura) · `33`-`36` materiale e verdetti (asse controllo, 4 casi) ·
`37`-`39b` materiale, verdetti e k_eff (asse controllo, 10 casi) ·
`40` canonical_name ingannevole · **`50-atteso-prima-del-run.md` le previsioni
depositate**.

**Codice.** `R/stage4-qc.R` (fusione + gate), `R/stage4-config.R` (le due mappe),
`R/stage4-dispatch.R` (dispatch e guardia doppio conteggio), `R/stage3-coherence.R`
(`.normalize_control_type`, il vocabolario dei controlli),
`R/stage3-defrag-alias.R` (la regola generale del 2026-08-01 e la storia dei suoi
difetti — **da leggere per intero**), `R/layer-b-plot-forest.R`,
`R/layer-b-utils.R` (`.rank_and_dedup_genes`).

**Script di re-pool** (da NON lanciare senza decisione):
`analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R`. Richiede `STAGE3_DIR`,
`VERDETTI_PATH`; `DRY_RUN=1` si ferma dopo l'identificazione Layer A.

---

## 8. LE TRAPPOLE (tutte già pagate)

1. **Non fidarsi di un numero riferito da un agente.** È l'errore di questa
   sessione, tre volte.
2. **Le etichette sono sbagliate e gli ID sono giusti** — ma la colonna
   `contrast_entity_label` **è già corretta** e usata dalle figure. Il residuo sta
   in `canonical_name`, che è legacy per scelta. **Non ri-aprire quel lavoro.**
3. **Verifica sull'artefatto, non sul sorgente. Le figure si aprono e si
   guardano** — è così che è stato trovato il difetto del forest, che sette criteri
   automatici dichiaravano a posto.
4. **Lo strumento deve vedere il dato per intero.** Prima di giudicare, conta
   quante stringhe toccano il massimo: se sono molte e diverse è troncamento, se è
   una sola è una lunghezza naturale.
5. **Una regola misurata su pochi casi non si applica a centinaia** senza
   rimisurare l'ampiezza.
6. **Se tocchi il recupero-nome, bumpa `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`**, o
   il re-cluster riusa la cache e produce un output identico. Già costato 8 ore.
7. **Niente `head` in pipe su una suite di test**: chiude la pipe e la tronca. Già
   succeso in questa sessione.
8. **Un verdetto di coerenza orfano ferma l'annotazione a fine run.** Controllarlo
   PRIMA (fatto: 0 su 11, da rifare).

---

## 9. VINCOLI OPERATIVI

- Branch `review-scientific-consistency-2026-06-10`, **master invariato, il push lo
  fa l'utente**.
- `Rscript` **senza** `--vanilla`. Reinstallare il pacchetto prima di ogni render
  Quarto (`devtools::install(".", quick=TRUE, upgrade=FALSE)`).
- **Nessun re-cluster e nessun re-pool senza decisione esplicita dell'utente.**
- Run lunghi con `setsid` (verificare SID == PID), **mai** in background del tool.
- Durante un run multi-ora: **aggiornamento ogni ora**, fatto + stima del residuo.
- **Mai la parola «validato» senza la misura accanto.**
- Nessun taglio silenzioso: ogni omissione dichiarata.
- Se un numero non torna: **fermarsi e dirlo**, non aggiustare.
