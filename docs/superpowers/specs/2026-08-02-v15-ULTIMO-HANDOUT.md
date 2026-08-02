# HANDOUT — il re-cluster v15 è l'ULTIMO. Come arrivarci senza sbagliare di nuovo

**Scritto:** 2026-08-01 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Mandato dell'utente, testuale:** *«Il re-cluster v15 deve essere l'ultimo, altrimenti il progetto
viene dichiarato fallito.»* · *«Ti rammento il numero QUINDICI. 15 versioni.»*

> **Questo file è autosufficiente.** Non serve leggere la conversazione precedente. Contiene lo
> stato provato, ciò che è stato ritrattato, i difetti aperti, e il protocollo obbligatorio da
> eseguire PRIMA di lanciare qualunque cosa.

---

## 0. LA COSA PIÙ IMPORTANTE, PRIMA DI TUTTO IL RESTO

Il 2026-08-01, in una sola giornata, la sessione precedente ha dichiarato **quattro volte** che il
lavoro era pronto per il lancio. **Quattro volte era falso**, e ogni volta lo hanno dimostrato i
dati, non un ragionamento:

| # | «pronto» | che cosa ha smentito |
|---|---|---|
| 1 | regola scritta, 43 test verdi | leggendo il codice a valle: due guardie si spegnevano sui membri fusi |
| 2 | fix applicato, misura fatta, smoke PASS, **run v14 lanciato e completato (9h11m)** | leggendo l'output: la regola **frammentava** 6 entità invece di unirle |
| 3 | fix dell'ordine unico, 90 test verdi | un agente: lo split **non era chiuso** (il ramo `anchor` lo aggira, 427 cluster) |
| 4 | 63 fusioni sbagliate rimosse a mano | un agente: ne restavano **68** fra le 682 mai lette, più 3 difetti strutturali nuovi |

**La lezione operativa: in questo progetto, "i test passano" e "la misura torna" NON sono
sufficienti a lanciare.** Ciò che ha trovato ogni difetto è stato **leggere l'oggetto prodotto** —
il file dei gruppi, le coppie di fusione, il codice a valle — non un aggregato.

**Perciò l'utente ha imposto un protocollo, ed è vincolante:** prima di lanciare v15 vanno
sguinzagliati **almeno 10 agenti** su fronti diversi, **più una verifica avversariale (GAN)** sui
risultati degli agenti stessi. Il dettaglio è nel §5. Non è facoltativo e non è negoziabile per
fretta.

---

## 1. DOVE SIAMO — stato provato

### Il deliverable che esiste oggi (e che si tiene se v15 fallisce)

| cosa | dove |
|---|---|
| Stadio 3 **v13** (buono, in uso) | `analysis/p4-output/20260728T151529Z-stage3-v13-364547a7` |
| Stadio 4 **v13** poolato (191 meta-analisi) | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296` |
| deliverable annotato | `analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.{csv,rds}` |
| 9 bundle Layer B | `analysis/p4-output/20260731T113513Z-layer-b-828b020d` |
| verdetti di coerenza (6 incoerenti) | `analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv` |

**Il deliverable v13 è valido**: 191 meta-analisi, I²/τ² su tutte le righe, validato biologicamente
(DHT agonista e enzalutamide antagonista danno segni opposti sugli stessi bersagli). Se v15 non
parte, non si perde nulla di scientifico: si perde solo la de-frammentazione, che resta un limite
dichiarato nei Methods.

### Il run v14 (fatto, e da NON usare)

`analysis/p4-output/20260801T081819Z-stage3-v14-364547a7` — 9h11m, `EXIT=0`, invarianti strutturali
pulite. **NON è utilizzabile** perché è stato prodotto con la regola generale, poi abbandonata.
⚠️ **v14 non è nemmeno un proxy di v15**: il codice è cambiato dopo il run (`R/stage3-defrag-alias.R`
riscritto alle 14:36, `clusters.rds` è delle 10:18). **Tutte le misure fatte su v14 vanno rifatte**:
il confronto degli insiemi `50-confronto-insiemi-v13-v14.csv`, i «46 gruppi da rileggere»
(`60-da-rileggere.txt`), i quattro numeri bandiera.

### Il codice, adesso

Non committato. `git status` al momento della scrittura:

```
 M R/resolver-guards.R              # + collisione "mito|NCBITaxon:262676"
 M R/stage3-config.R                # + schema_versions$contrast_defrag = "v2"
 M R/stage3-contrast-anchor.R       # innesto della regola + 3 fix delle guardie
 M docs/superpowers/plans/2026-07-31-programma-fix-e-rerun.md
?? R/stage3-defrag-alias.R          # la regola
?? tests/testthat/test-stage3-defrag-alias.R
?? analysis/p4-fase-f12-stage3-v15-defrag.R          # re-cluster v15 (da lanciare)
?? analysis/p4-fase-f5-stage4-layer-a-rebuild-v14.R  # re-pool (dopo v15)
?? analysis/audit/2026-07-31-defrag/                 # tutte le misure
?? docs/findings/2026-07-31-defrag-regola-e-misura.md
```

**Prima cosa da fare nella prossima sessione: COMMITTARE.** Il run v14 è girato per 9 ore su un
bersaglio mobile (il codice è cambiato mentre girava). Non si ripete.

### La regola, com'è adesso

⚠️ **AGGIORNATO 2026-08-02**: quando questo handout fu scritto (2026-08-01) la regola fondeva tre
entità. **Da allora `glioblastoma` è uscita** (decisione utente 2026-08-02): la misura fatta dopo
ha mostrato che non comprava nulla — dei 40 membri candidati **39 avevano già l'entità dal ramo
`anchor`** (che precede questo ripiego e che la regola non può vedere), al ripiego arrivava **un
solo record** (GSE241396), con una chiave di controllo assente nel gruppo bersaglio: sarebbe finito
isolato a k=1. In più la fusione non chiudeva lo split (in v13 convivono già `STR:glioblastoma` k=6
e `MeSH:D005909` k=3, stesso verso e stesso controllo — vedi riga sotto sul difetto "lo split non
era chiuso", che per questa entità NON era chiuso come la tabella diceva).

`R/stage3-defrag-alias.R` fonde **DUE entità e basta** (`.CA_DEFRAG_ACCEPT`):

| token (normalizzato) | ID | perché |
|---|---|---|
| `tgfb` (copre `TGFb`, `TGF-B`, `tgf_b`) | `HGNC:11766` | figura 2 del main paper, k 65 → 78 |
| `il17` | `HGNC:5981` | IL17A |

**Test:** `tests/testthat/test-stage3-defrag-alias.R` → **119 PASS / 0 FAIL** sui dizionari VERI
(2026-08-01 18:0x). ⚠️ In `test_dir` i dizionari sono fixture e i test end-to-end **si saltano**:
vanno lanciati con `testthat::test_file()` dopo `devtools::load_all(".")`, altrimenti la suite è
verde senza aver provato nulla.

Sei asserzioni sono state **cambiate** con la restrizione (`sepsis`, `arac`, `r837`, `4oht`, `zikv`
non si fondono più): il cambiamento è dichiarato nei commenti dei test, non nascosto. Erano fusioni
**corrette** della regola generale, e servivano a provare che nessun filtro meccanico le separa
dalle sbagliate — quella dimostrazione resta valida ed è il motivo per cui la regola generale è
stata abbandonata.

Sono **due delle tre** entità che la decisione dell'utente del 2026-07-31
(`docs/superpowers/specs/2026-07-31-decisione-rerun.md`) aveva autorizzato — la terza,
`glioblastoma`, è uscita con la decisione del 2026-08-02 (vedi riquadro sopra). La versione
precedente ne fondeva **923**: quella generalizzazione non era stata decisa da nessuno ed è la causa
di tutti i difetti del §3.

---

## 2. I 15 NUMERI DI VERSIONE — perché siamo qui

Serve saperlo per capire il peso del mandato: **ogni versione è un run da ore.**

v3 (giugno) → v4 → v5 (ChEMBL) → v6 → v7 (patogeni) → v8 (ramo `rem_group`) → v9 (de-frag LLM) →
v10 (fallback) → v12 (ancoraggio dal contrasto) → v13 (sei regole, **quello buono**) → v14
(de-frag generale, **buttato**) → **v15 (l'ultimo consentito)**.

---

## 3. I DIFETTI — provati, con la loro evidenza

### 3a. CHIUSI dalla restrizione alle due entità (non da una correzione: per costruzione)

⚠️ **AGGIORNATO 2026-08-02** — due righe di questa tabella erano sbagliate, non solo datate dal
"tre"→"due": il numero «130 su 923» non è mai stato sostenuto da nessun log dell'audit (verificato
contando `.CA_DEFRAG_REJECT`, `90-adjudica.txt`, `80-da-leggere-identita.csv`, `80-screen.log`:
i numeri veri sono **682 fusioni sostenute dal nome primario e mai lette, 241 lette una per una,
61 sbagliate**), e la riga sullo split diceva che **nessuna** delle tre entità autorizzate ne era
colpita — falso per `glioblastoma`, che infatti per quello è uscita (vedi §1).

| difetto | misura | perché sparisce (per `tgfb`/`il17`) |
|---|---|---|
| **identità sbagliate**: delle 923 coppie prodotte dalla regola generale, 682 sostenute dal nome primario e mai lette; delle 241 lette una per una, **61** sbagliate | `msa_p`→MTAP (è l'atrofia multisistemica), `copd`→ARCN1, `rela`→carisoprodol su `RELA-/-`, `ifn_i`→**il Marocco**, `mito`→una pianta | le 61 sono tutte **fuori** dalle due autorizzate |
| **lo split non era chiuso** | in v14: `STR:hypoxia` k=33 **e** `MeSH:D000860` k=10 — stessa entità, stesso verso, stesso controllo. 427 cluster con entità `STR:` dal ramo `anchor`, 67 coppie compresenti. Su v13, **415** cluster `cgroup` hanno un'entità `STR:` dal ramo anchor | `tgfb`/`il17` non sono fra le colpite (residuo anchor zero, misurato su v13) — **`glioblastoma` invece lo era** (`STR:glioblastoma` k=6 accanto a `MeSH:D005909` k=3 in v13), motivo per cui è uscita |
| **la regola CANCELLAVA dati** | `tnfa` → TNF di *zebrafish* (`CHEBI:197439`, in blacklist) → **17 confronti TNFα prima tenuti venivano scartati** | `tnfa` non è nella lista |
| **asse clinico-vs-sperimentale spento** sui membri fusi | il `control_key` si calcola PRIMA dell'entità: `ck_off == ck_on` su **87.092/87.092** righe | nessuna delle due è un patogeno |

### 3b. CORRETTI nel codice (verificare che i fix reggano)

1. **Tre guardie si spegnevano sui membri fusi**, perché per un membro fuso `res$name` è `NA` e
   `raw` vale l'ID: token dell'entità nel rilevatore di riga, sonda «entità tenuta costante»,
   induttore/ombrello/nome generico. Corretti passando `defrag_tk`.
2. **Il re-pool leggeva lo Stadio 3 v13.** `analysis/p4-fase-f5-stage4-layer-a-rebuild-v14.R`: la
   copia aveva aggiornato la dir di USCITA ma non quella di INGRESSO. Avrebbe poolato per **28 ore**
   i cluster vecchi scrivendoli in una cartella etichettata v14, e **nessuno dei due gate lo
   intercetta** (controllano `rem_group` e il prefisso `cgroup_L5_`, veri anche per v13). Ora
   `STAGE3_DIR` è obbligatoria e il nome deve contenere `-stage3-v15-`.
3. **Il pre-filtro dei verdetti disinnescava la difesa sugli orfani.** Lo script toglieva i verdetti
   orfani prima di passarli a `.annotate_coherence()`, che quindi non li vedeva mai. **Provato: con
   il pre-filtro l'annotazione riusciva e il gruppo `adenoma`, che ha un verdetto di INCOERENZA,
   usciva marcato `coherent`.** Tolto il pre-filtro. ⚠️ Il piano diceva «l'annotazione si ferma»:
   era **falso**, proseguiva. ⚠️ **AGGIORNATO 2026-08-02**: qui si scriveva «Ora lo script si
   ferma» — non era ancora vero: lo `stop()` sugli orfani restava dentro un `tryCatch` che lo
   declassava a warning, quindi anche dopo questo fix lo script proseguiva comunque. Reso vero
   solo dal Task 7 (2026-08-02), portando il controllo in testa allo script, fuori dal `tryCatch`.
4. **`run_metadata.json` non distingueva i run.** Il diff fra i metadati di v13 e v14 mostrava solo
   il timestamp e tre conteggi, benché v14 avesse introdotto la regola. Aggiunto
   `schema_versions$contrast_defrag`.

### 3c. APERTI — pre-esistenti, NON introdotti dalla de-frammentazione. Da decidere, non da subire

| # | difetto | misura | dove |
|---|---|---|---|
| A | **La dedup ADR-0022 è chiavata sull'anchor vecchio**, non su `contrast_entity` (che differisce in **147 dei 304 gruppi, 48%**). Butta dal deliverable **49 entità in v13, 53 in v14**, fra cui **tamoxifene `CHEBI:41774` k=7**. Cambiare i k con una fusione **cambia chi sopravvive**. | provato rifacendo filtro+dedup sui due output | `R/stage4-qc.R:33-47` |
| B | **`.CG_INDUCERS` non aggancia `dtag13`**: il confronto è a confini di parola e le cifre sono caratteri di parola, quindi `\bdtag\b` non matcha `dtag13`. **64 membri** stanno nel corpus sotto il nome di un induttore di degron. | misurato sul corpus | `R/stage3-contrast-gate.R:54-60` |
| C | **Il Layer B incolla misure vecchie su pool nuovi**, e il join RIESCE in silenzio perché i `cluster_id` dei `cgroup` sono stabili: le schede stamperebbero `k_kish`, `quota_top1`, `studio_dominante` del pool **v13** accanto a figure calcolate sul pool **v15**. | provato: tutti e 9 i case study hanno lo stesso `cluster_id` in v13 e v14 | `analysis/p5-stage4-layer-b-build-v13.R:220` |
| D | **Non esiste modo di sapere, dall'artefatto, quale Stadio 3 sia stato poolato.** Il `run_id` è deterministico dagli input e vale `364547a7` per v13, v14 e v15; lo Stadio 4 registra solo quello, non il percorso. | provato leggendo i `run_metadata.json` | `R/stage4-build.R:92` |
| F | **La stessa entità sotto due ID di ontologie diverse** — due meta-analisi della stessa cosa. Visti: `PD325901`→`CHEBI:88249` contro `PD901`→`CHEMBL:CHEMBL507361` (stesso farmaco, mirdametinib); `1,25(OH)2D3`→`MeSH:D002117` (18 membri) contro `CHEBI:17823` (77, dal resolver). **Con la restrizione non si producono più** (quei token non fondono), ma il fenomeno pre-esiste nel corpus e non è stato quantificato: un agente dedicato non ha fatto in tempo a riferire. Fronte #4 e #8 del §5. | non quantificato | — |
| E | **La soglia k resta 3?** Misurato: k≥5 costerebbe il 55% del deliverable e lascerebbe comunque **21 meta-analisi dominate** su 86; a parità di sopravvissuti il filtro diretto `quota_top1<0,5` ne lascia **0**. Parkinson (k=10, 1,8 studi efficaci, 73% su un modello iPSC) **passerebbe** k≥5. | `docs/superpowers/plans/2026-07-31-programma-fix-e-rerun.md` §D0quater | decisione utente |

### 3d. RITRATTAZIONI — cose che la sessione precedente ha SCRITTO e che sono FALSE

Sono elencate perché un lettore potrebbe trovarle in commenti o documenti e crederci.

1. «I 22 membri `dTAG-13` oggi sono scartati e con la regola rientrerebbero» — **falso**: erano già
   tenuti prima e restano tenuti dopo. Dedotto da un commento invece che contato.
2. «L'ordine unico elimina lo split **per costruzione**» (docstring di
   `.CA_DEFRAG_ONTOLOGY_ORDER`) — **falso**: elimina lo split *fra classi*, non quello *fra rami*.
   Le sei entità citate nella docstring erano **esattamente** quelle ancora spezzate in v14.
3. «Senza la fase D0ter l'annotazione **si ferma**» (piano §D0ter) — **falso**: prosegue e marca un
   gruppo incoerente come coerente. È peggio.
4. «`Recurrence`, `PTSD`, `CSF2` hanno già un ID ontologico e non sono toccati» (finding §6ter) —
   **falso**: `STR:ptsd` era nel Layer A v13 e in v14 non c'è più.
5. Un test che «difendeva» la guardia sull'entità costante usava uno scenario intercettato prima dal
   ramo delle **combinazioni**: era verde/rosso per la ragione sbagliata. Stessa classe: un caso
   (`ugml`) che doveva esercitare la tabella delle collisioni non agganciava nulla.

---

## 4. LE MISURE ESISTENTI — cosa vale e cosa no

Tutto in `analysis/audit/2026-07-31-defrag/`.

| file | vale ancora? |
|---|---|
| `impatto-membri-v6.rds` | **NON ESISTE**: la misura è FALLITA, e per la ragione giusta — vedi il riquadro qui sotto. |
| `impatto-membri-v3/v4/v5.rds` | **NO**: misurano la regola generale, abbandonata. Utili solo come evidenza storica dei difetti. |
| `50-confronto-insiemi-v13-v14.csv`, `60-da-rileggere.txt` | **NO**: relativi a v14, che non è proxy di v15. Da rifare su v15. |
| `70-fusioni-da-leggere.txt`, `90-adjudica.txt`, `80-da-leggere-identita.csv` | **SÌ come evidenza.** ⚠️ **AGGIORNATO 2026-08-03**: qui si scriveva che le 923 fusioni erano state «lette una per una» e che questo materiale «ha provato il 14,1%» — falso su entrambi i punti (stessa famiglia del «130 su 923» corretto altrove in questo file). Le 923 **non sono state lette una per una**: `70-fusioni-da-leggere.txt` le elenca tutte e 923 (token, ID, conteggio membri, un'etichetta di esempio), ma solo le **241** senza sostegno del nome primario sono state **effettivamente lette** una per una con le etichette vere (`90-adjudica.txt`, da `80-da-leggere-identita.csv`); le altre 682 sono sostenute dal nome primario e non sono mai state lette. «14,1%» era una percentuale derivata dal numero infondato «130 su 923» e va tolta, non ricalcolata. Ciò che questo materiale prova davvero: **241 coppie adjudicate, 61 giudicate sbagliate.** |
| `50-antistale-v14.R`, `60-bundle-da-rileggere.R`, `70/80/90-*.R` | **SÌ come strumenti**: vanno ri-puntati alla dir v15. |

### ⚠️ LA MISURA È ROTTA DALLA RESTRIZIONE, e va riparata prima del cancello §6.3

`10-impatto-su-tutti.R` produce i due regimi (regola ON / regola OFF) **nella stessa passata**
pre-seminando `ontology_env$.defrag_index` con indici VUOTI: senza indice, la regola non trovava
nulla e riproduceva il comportamento di prima.

**Con la restrizione quel meccanismo non funziona più**, perché `.ca_defrag_entity()` non consulta
più l'indice: legge `.CA_DEFRAG_ACCEPT`. Quindi il regime "OFF" fonde comunque, e lo script si è
fermato da solo:

```
Error: is.na(simulomicsr:::.ca_defrag_entity("tgfb", "drug", oe_off)) is not TRUE
```

**È il comportamento voluto**: l'asserzione era stata scritta perché «il file non possa essere
etichettato male», e ha impedito una misura falsa. Non aggirarla.

**La riparazione** (poche righe, in `10-impatto-su-tutti.R`): ottenere il regime OFF sostituendo la
funzione invece dell'indice, per esempio con
`testthat::with_mocked_bindings(.ca_defrag_entity = function(...) NA_character_, .package = "simulomicsr", { ... })`
attorno alla chiamata `a <- .ca_member_contrast(...)`; poi **lasciare in piedi le tre asserzioni**
(ON fonde `tgfb`, OFF no, `ifna` mai) adattate al nuovo meccanismo. Costo della misura: ~55 min.

---

## 5. IL PROTOCOLLO OBBLIGATORIO PRIMA DI LANCIARE v15

**≥10 agenti in parallelo, poi una verifica avversariale sui loro risultati.** L'utente ha
autorizzato esplicitamente i workflow multi-agente («ultracode») e tutte le risorse.

**Regole per ogni agente:** niente run pesanti (>5 min), mai `pkill`, non modificare file in `R/` o
`analysis/*.R` se qualcosa è in esecuzione, script nuovi solo nella scratchpad. Ogni agente deve
distinguere **PROVATO sui dati** da **sospetto**, e se non trova nulla deve dirlo con i numeri
invece di inventare.

### I dieci fronti

1. **Le due fusioni autorizzate, una per una.** ⚠️ **AGGIORNATO 2026-08-02**: erano tre quando
   questo fronte fu scritto; `glioblastoma` è uscita proprio perché il fronte 2 qui sotto, eseguito,
   l'ha trovata colpita dallo split. Verificare su TUTTI i membri che `tgfb`, `il17` fondano ciò che
   devono e nulla di più: leggere le etichette di ogni membro che cambia entità, e provare che
   nessuno di essi misura un'altra cosa.
2. **Lo split del ramo `anchor`, per le due entità rimaste.** È il difetto che ha bruciato v14 —
   ed è il difetto per cui `glioblastoma` (terza entità originaria) è uscita: eseguito su tutte e
   tre, ha trovato `STR:glioblastoma` k=6 accanto a `MeSH:D005909` k=3 in v13 (esattamente lo split
   che questo fronte cerca). Verificare sull'output che nessuna delle due rimaste (`tgfb`, `il17`)
   compaia contemporaneamente come `STR:` (dal ramo anchor) e come ID. Misurare, non assumere.
3. **Le guardie a valle** (`R/stage3-contrast-anchor.R`, `R/stage3-row-pairing.R`,
   `R/stage3-contrast-gate.R`): trovare ogni punto in cui la forma dell'entità (ID contro `STR:`)
   cambia il comportamento. Ne sono già stati trovati e corretti tre; il quarto lo ha trovato un
   agente.
3bis. **`control_key` e `is_pathogen`**: sono calcolati PRIMA dell'entità. Nessuna delle due
   autorizzate è un patogeno, ma va **provato**, non dedotto.
4. **I consumatori a valle**: `R/stage4-*.R`, `R/layer-b-*.R`, gli script di build, i CSV di
   selezione, i file in `inst/extdata/`. Criterio di ordinamento: **quanto tardi ce ne
   accorgeremmo** (subito / dopo 9h / dopo 37h).
5. **Gli script del run** (`p4-fase-f12-stage3-v15-defrag.R`, `p4-fase-f5-...-rebuild-v15.R`,
   rinominato dal Task 9, era `-v14.R`):
   `diff` contro i predecessori — le differenze devono essere SOLO il token di versione e le
   directory. Più: cache, percorsi, spazio, assert tardivi.
6. **Le cache**: la domanda precisa è *«una cache può far girare v15 per nove ore producendo
   l'output di prima?»*. Nella sessione precedente la risposta era **no** (catena tracciata: la
   memoizzazione della regola è in memoria e si ricostruisce ogni sessione), ma il codice è cambiato
   e va **riverificato**.
7. **La provenienza dell'artefatto** (difetto 3c-D): progettare e verificare un'impronta che
   distingua v15 da v13/v14 nei file prodotti — il `run_id` non lo fa.
8. **La dedup ADR-0022** (difetto 3c-A): quantificare quante entità il deliverable v15 perderebbe e
   quali, e produrre la lista degli scartati da affiancare al deliverable.
9. **La catena dei verdetti di coerenza**: quali dei 6 verdetti sopravvivono a v15, quali gruppi
   cambiano composizione, e che cosa serve per la fase D0ter. ⚠️ **AGGIORNATO 2026-08-02**: qui si
   scriveva «il pre-filtro ora fa fallire lo script (corretto), quindi senza D0ter il re-pool si
   ferma davvero» — non era ancora vero (lo `stop()` restava dentro un `tryCatch` che lo
   declassava a warning). **Ora, grazie al Task 7 (2026-08-02), è vero davvero**: il controllo è
   in testa allo script, fuori dal `tryCatch`.
10. **Il Layer B** (difetto 3c-C): il join con le misure vecchie riesce in silenzio. Verificare e
    proporre il fix (leggere il deliverable dalla `out_dir` del run nuovo).
11. **Un agente che rilegge le RITRATTAZIONI del §3d** e verifica che nessuna affermazione falsa sia
    rimasta in un commento, in un test o in un documento.

### La verifica avversariale (GAN)

Dopo i dieci, **almeno due agenti il cui compito è REFUTARE**, non confermare: prendono i difetti
riportati e cercano di dimostrare che sono falsi allarmi, con l'istruzione esplicita di dichiarare
«confutato» in caso di dubbio. Sopravvive solo ciò che regge. Serve perché la lista dei difetti non
si gonfi di cose inventate, che sarebbero solo un altro modo di perdere tempo.

---

## 6. IL CANCELLO — quando si può lanciare v15

Tutte queste condizioni, **provate sui file, non sul log**:

1. il codice è **committato** (il run non gira su un bersaglio mobile);
2. la suite `test-stage3-defrag-alias.R` è verde sui **dizionari veri** (in `test_dir` le fixture la
   fanno saltare: va lanciata con `test_file`);
3. la misura sulla regola ristretta torna: **membri cambiati nell'ordine delle centinaia, non
   migliaia** · invariante «0 membri cambiano partendo da un'entità già risolta» · **0 membri persi**
   · **nessuno split** · le due entità (`tgfb`, `il17`) crescono, nient'altro cambia;
4. i dieci agenti hanno riferito e la verifica avversariale ha ripulito la lista;
5. **ogni difetto sopravvissuto è o corretto o dichiarato per iscritto** con il suo numero;
6. lo SMOKE del re-cluster (12,8 min) è PASS.

Solo allora: `setsid`, SID==PID, `Rscript` **senza** `--vanilla`, aggiornamento orario.

---

## 7. DOPO v15 — in questo ordine, senza saltare

1. **Verifica anti-stale letta dai file** (`50-antistale-v14.R` ri-puntato): prefisso `cgroup_L5_`,
   le tre colonne del contrasto popolate, entità bandiera contro i pavimenti di v13 (SARS 38,
   TGFB1 **≥78**, LPS 50, enzalutamide 29, vemurafenib 20), e il confronto degli **insiemi** dei
   membri v13→v15.
2. **FASE D0ter**: rileggere i gruppi che cambiano composizione e produrre
   `verdetti-poolato-v15.csv`. **Senza questo il re-pool si ferma** — davvero **solo dal
   2026-08-02** (Task 7): prima di allora lo `stop()` sugli orfani era dentro un `tryCatch` che lo
   declassava a warning, e "si ferma" era una previsione, non un fatto verificato.
3. **Decisione dell'utente sulla soglia k** (§3c-E), da prendere sui numeri nuovi.
4. **Re-pool** (~28 h): `STAGE3_DIR=<dir v15> setsid nohup Rscript
   analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R > analysis/audit/v15-repool-full.log 2>&1 &`
   (rinominato dal Task 9, era `-v14.R`)
5. **Layer B** ricostruito sul pool nuovo, col fix del difetto 3c-C.
6. Narrative e Methods.

---

## 8. SE v15 FALLISCE

Non è la fine del progetto: **il deliverable v13 resta valido e completo**. Si tiene quello, la
frammentazione va nei Methods come limite dichiarato (è una frase di due righe), e tutti i difetti
pre-esistenti trovati in questa caccia — la dedup sull'anchor, il re-pool che puntava a v13, il
pre-filtro dei verdetti, il Layer B con le misure vecchie — **valgono comunque e vanno corretti**.
Quella è la vera resa del lavoro di questi due giorni, indipendentemente da come va la fusione.
