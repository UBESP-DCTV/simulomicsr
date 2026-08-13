# I tre cambi del re-run: implementati, e misurati sui dati veri

**Data:** 2026-08-13 · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun push · NESSUN RUN LANCIATO**

Implementazione delle decisioni D1-D7 dell'handout
`docs/superpowers/specs/2026-08-13-DECISIONI-E-HANDOUT-RERUN-COMPLETO.md`, con
la misura di ciascuna sui dati veri di v15. Evidenza:
`analysis/audit/2026-08-13-rerun-prep/`.

---

## 0. Le tre cose da sapere subito

1. **Due attese dell'handout non reggono alla misura** (§4): infigratinib **non
   nasce** come meta-analisi (k_eff 2, non 3), e l'effetto di D2 sul deliverable
   è **zero** (non «Nutlin-3a k=8 → 7»). Il deliverable previsto è **212**, non
   213.
2. **La voce `normoxia` generale portava dentro una fusione non voluta** (§3): il
   gruppo ATRA, con guadagno zero e doppio conteggio degli stessi campioni. È
   uno dei casi che la decisione D4 escludeva. Ora la voce è condizionata
   all'entità, come già lo era `uninfected`.
3. **Un difetto del mio strumento, trovato e corretto prima di usarlo** (§5): il
   riconoscimento di `chiave=valore` tagliava tutto ciò che precedeva un `=`, e
   `LNCaP-abl shKDM3B1 t=7` diventava `7`. Mutilava 115 etichette del corpus.

---

## 1. D1 — le corsie: acceso, e verificato nelle due direzioni

`stage4_default_config()$rem_group$collapse_technical_lanes` da `FALSE` a `TRUE`.

**Accettazione positiva** (`D1-accensione-corsie.R`, sui dati veri, con la
corrispondenza costruita come la costruisce il build dai metadati H5):

- dispatch **2.152 → 2.146** entry;
- **6 cluster** col `k` cambiato, e sono **esattamente i 6** previsti
  (`50-k-prima-dopo.csv`): *S. epidermidis* 3→2, IMPDH2 6→5, IL4 10→9, IFNG
  20→19, *S. aureus* 4→3, IL5RA 12→11;
- deliverable **214 → 213** (esce *S. epidermidis*).

**Accettazione negativa:** con l'interruttore spento il dispatch è identico a
quello di produzione, entry per entry e GSM per GSM (2.152).

La corrispondenza copre 5.721 campioni in 1.810 librerie. Le 93 librerie in più
rispetto alla misura a mano del 12 agosto (1.717) sono quelle scritte `lane N`
per esteso, già spiegate in `95-diff-regole.R`.

## 2. D2 — il confine del marcatore genetico: scritto, con tre trappole chiuse

`R/stage3-row-pairing.R`. Il confine `\b` pretende un carattere non-parola PRIMA
del marcatore; in `p63shRNA` prima di `sh` c'è una **cifra**. Ora il confine è
«inizio, oppure un carattere che non sia una lettera», e la maiuscola che segue
(`sh[A-Z]`) resta la guardia che tiene fuori `sigmoid`, `simvastatin`, `shear`.

Le tre trappole dell'handout, chiuse nei test (121 asserzioni verdi):

1. **KO/KD solo in maiuscolo** — in minuscolo prendono `Kd measurement` e `kd of
   5 nM`, la costante di dissociazione;
2. **il marcatore guarda i VALORI, non il nome del campo** —
   `genetic_knockdown=no knockdown` non è un knockdown;
3. **i valori che negano** (`none`, `wild-type`, `scramble`, `parental`…) e la
   negazione davanti al marcatore (`no knockdown`, `without transgene`,
   `Non-Knockout`, `non-silencing control`).

`empty vector` resta un marcatore: sono cellule trasfettate, ed è ciò che rende
**simmetrico** il confronto con un braccio shRNA.

### L'effetto misurato, e perché non è quello previsto

| | atteso dall'handout | misurato |
|---|---|---|
| confronti segnalati nel deliverable | 3, in 2 gruppi | **5, in 3 gruppi** |
| di questi, POOLATI | — | **0** |
| effetto sul `k_eff` | ATRA resta 4, Nutlin 8 → 7 | **nessun gruppo cambia** |
| effetto sul `k` di Stadio 3 | — | bleomicina 10 → 9 |

I 3 attesi ci sono tutti. I 2 in più sono `GSE156472` dentro il gruppo della
bleomicina, e li ho letti: `Bleomycin with transgene` contro `Control without
transgene`. Sono veri positivi **della regola** — un braccio dichiara il
transgene, l'altro lo nega — ma **nei metadati GEO di quello studio il transgene
non esiste**: nove campioni, `treatment: control/bleomycin/bleomycin+curcumin`,
nient'altro. La parola «transgene» e la divisione dei tre campioni trattati in
tre gruppi da uno sono **invenzioni dello Stadio 2**. Il difetto è a monte; la
regola fa il suo mestiere.

**Nessuno dei 5 confronti era poolato**: hanno tutti un braccio con meno di due
campioni e cadevano già a `n_min`. È di nuovo la lezione del 10 agosto — *il
censito non è il poolato* — e il motivo per cui l'attesa «Nutlin 8 → 7» non
regge: il `k=8` è il `k_eff`, e GSE111009 continua a portare i suoi 2 confronti
poolabili, che non sono quelli segnalati.

**Sul corpus intero** (87.092 confronti, 99.542 etichette distinte): 232
etichette acquistano il marcatore, 92 lo perdono (38 per il solo cambio di case,
54 perché sono negazioni). In confronti: **+271** segnalazioni, **−77**, in 132
studi. Le 77 perse sono in gran parte un guadagno di precisione: `sh Dap5` contro
`non-silencing (NS) construct` era segnalato come difetto e non lo è.

## 3. D3+D4 — le mappe: popolate, e una fusione non voluta trovata misurando

`entity_canonical` 5 voci, `control_canonical` 2. Le candidate non sono scritte a
mano: le genera la regola del ponte fra registri, il giudizio umano ne ha
respinte 3 (IL-10 verso invertito, GM-CSF differenziazione, «Compound 4» molecole
diverse). Le tre respinte sono ora **nei test**, per nome.

**Le 7 fusioni applicate, misurate col dispatch di produzione:**

| gruppo | k_eff prima | dopo |
|---|---:|---:|
| TNF `HGNC:11892` | 32 | **38** |
| ipossia `STR:hypoxia` | 25 | **33** |
| SARS-CoV-2 `NCBITaxon:2697049` | 34 | **36** |
| IL-6 `HGNC:6018` | 10 | **11** |
| IL-15 `HGNC:5977` | 3 | **5** |
| endotelina-1 `CHEBI:80240` | 1 | 2 |
| infigratinib `CHEBI:63451` | 1 | 2 |

I tre numeri della decisione (+6, +8, +2) tornano alla cifra. IL-6 e IL-15, che
l'handout dava per non misurati, guadagnano davvero +1 e +2.

### La fusione che non doveva esserci

Con `normoxia` come voce **generale** le fusioni erano **8**, non 7. L'ottava:
`cgroup_L5_06b5da4a` (entità `STR:atra`, chiave `normoxia`, k=1) dentro il gruppo
ATRA. Il suo unico studio, **GSE202458, è già nel gruppo vincente**: il `k` resta
9 e i due membri portano gli **stessi campioni trattati** contro due controlli
diversi dello stesso studio. È il **doppio conteggio** per cui ATRA era già stata
esclusa fra le 10 fusioni di `uninfected`.

Nel corpus la chiave `normoxia` sta su **14 cluster di 14 entità diverse**. La
voce è quindi condizionata anche lei: `STR:hypoxia||normoxia`. Non è una
decisione nuova — D4 dice «solo ipossia + SARS-CoV-2», e ATRA è fra le escluse.

Il meccanismo del condizionamento è codice nuovo (`R/stage4-qc.R`, 6 test): senza
di esso la decisione D4 **non era esprimibile**, perché `uninfected` da solo
produce 10 fusioni fra cui due a doppio conteggio e un minestrone.

## 4. Due attese dell'handout che la misura smentisce

1. **Infigratinib non nasce.** La fusione porta il suo `k` di Stadio 3 da 2 a 3,
   quindi entra fra i 351 candidati; ma il suo `k_eff` va da 1 a **2**, e il gate
   del pooling è `k_eff >= 3`. Finisce fra i non processabili. L'audit dell'8
   agosto lo aveva scritto — «k3 fuso=3, **gate ignoto**» — e l'handout ha letto
   quel 3 come una meta-analisi. Ora il gate è misurato.
2. **D2 non tocca il deliverable.** Zero righe, zero `k_eff` (§2).

Deliverable previsto: **212**, non 213. La terza differenza rispetto all'handout
è che il conteggio non teneva la riga TNF assorbita dalla fusione — che è
l'obiettivo stesso di D3, non una perdita.

## 5. Due difetti dei miei strumenti, dichiarati

1. **Il riconoscimento di `chiave=valore`.** La prima versione tagliava tutto ciò
   che precedeva il primo `=`. Così `LNCaP-abl shKDM3B1 t=7` diventava `7`,
   `TRIM6 Knockout WNV Infection (MOI = 5)` diventava `5)`, e il marcatore
   spariva: **115 etichette del corpus mutilate**, quasi tutte per un tempo o una
   MOI dentro un'etichetta umana. Ora una chiave è riconosciuta come tale solo se
   è un **nome di campo** (una o due parole, senza punteggiatura di frase). Quattro
   casi di accettazione lo fissano.
2. **I «36 flag senza evidenza» dello Stadio 1 non esistono.** Contando i
   `is_zero_timepoint` accesi nell'input v3 ne risultavano 36 senza evidenza
   temporale. Falso: nell'input v3 `value_hours` è scritto come **array di un
   elemento**, `is.numeric(list(0))` è FALSE, e
   `.has_zero_timepoint_evidence()` ricadeva sul ramo testuale, dove `0R` e `0hpi`
   non matchano. Letti tutti e 36: hanno `value_hours = 0`, cioè l'evidenza
   autoritativa. È la trappola dichiarata degli scalari-come-array, commessa da me
   dopo averla letta.

## 6. Il controllo della pipeline, stadio per stadio

| stadio | controllo | esito |
|---|---|---|
| 1 | guard `is_zero_timepoint` sul master (508.037 record, 517.173 durate) | **12.967 flag corretti** (141 accesi, 12.826 spenti) — lo stesso numero del build storico. Nell'input v3 restano **2.882** accesi, **0 senza evidenza** |
| 2 | un record per studio | **PASS** — 24.394 studi, 0 duplicati, 87.168 confronti, 186.269 replicate_groups |
| 3 | le cinque invarianti di `60-invarianti-v15.R` | **tutte tornano**; TGFB1 78, IL17A 12, 0 residui `STR:` fusi, candidati 351 |
| 4 | funnel | 322.415 cluster → 11.536 `cgroup` → 11.300 ammissibili → **351** candidati → 214 + 137. **Zero orfani** (l'unico assente è il TNF assorbito, atteso) |
| — | guardie | conflitto di ruolo, collasso corsie, verdetti orfani, annotazione a fine run: **tutte invocate** |
| — | cache | `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` = **v7**, e resta v7: nessuno dei tre cambi tocca il recupero-nome |

## 7. D7 — il registro degli scarti

`qc_report$dispatch_drops` (nuovo, `R/stage4-dispatch.R` + `R/stage4-build.R`, 23
test): ogni confronto che non entra nel pooling lascia il suo motivo —
`n_min`, `n_min_dopo_collasso_corsie` (distinto: sono due difetti diversi),
`doppione_studio_braccio`, `confronto_non_trovato`, `braccio_non_trovato`,
`studio_assente_dallo_stadio2`, `record_id_non_risolto` — con i campioni e le
librerie di ciascun braccio.

`n_min` è la porta più selettiva della pipeline (sul deliverable v15 lascia fuori
**2.531 confronti su 4.726**) e fino a oggi lo faceva con un `next` silenzioso.
Il 10 agosto quel silenzio è costato una misura sbagliata.

Lo **Stadio 3** invece registrava già tutto: `non_clusterable.rds` di v15 ha
224.680 righe con il motivo, fra cui **4.482 `riga_genetica_asimmetrica`**.
Non serviva aggiungere nulla lì.

## 7bis. Lo smoke del re-cluster v16 NON esercita D2 — e come lo so

Lo smoke (`analysis/p4-fase-f13-stage3-v16-tre-cambi.R`, 10,8 min, 250 studi,
297 `cgroup`) produce un output **identico** a quello di v15: 3.052
`non_clusterable`, **69** `riga_genetica_asimmetrica`, zero `k` cambiati.

Due spiegazioni erano possibili, e la seconda è il difetto che questo progetto ha
già pagato tre volte: (a) il subset non contiene i casi toccati, (b) **il codice
nuovo non viene chiamato**. Distinte con `D2e-smoke-esercita.R`:

- **(b) è esclusa**: chiamando `.ca_member_contrast()` — la funzione del build,
  non il solo marcatore — sui due confronti veri di GSE111009, il verdetto è
  `riga_genetica_asimmetrica`. Con la regola vecchia passavano.
- **(a) è la spiegazione**: dei 132 studi toccati sul corpus, solo 3 sono nel
  subset smoke (GSE149035, GSE162186, GSE172506), e i loro 10 confronti
  interessati **non arrivano al gate**: non compaiono né fra gli assegnati né fra
  i `non_clusterable`, in nessuno dei due smoke.

Lo smoke vale quindi come **non-regressione** (il cambio non ha rotto nulla nel
percorso di produzione), non come prova che D2 funziona: quella sta nei 121 test
e nella misura sui dati veri.

## 8. Limiti dichiarati

1. **Le previsioni valgono a parità di Stadio 1 e 2.** Il re-run degli stadi LLM
   con `VLLM_BATCH_INVARIANT=1` produce un master **nuovo**, non il vecchio: senza
   la flag due esecuzioni identiche coincidevano nel 40,4% dei record.
   `analysis/audit/2026-08-13-rerun-prep/PREVISIONI-PRIMA-DEL-RUN.md` §⚠️.
2. **Effetti di secondo ordine del re-cluster non misurati.** I 271 confronti che
   D2 scarta in più cambiano i `k` di cluster fuori dal deliverable, e un `k` che
   cala può cambiare chi vince la dedup per entità. Misurabile solo col
   re-cluster.
3. **Il `k_eff` da dispatch è un limite superiore** (niente pre-filtro H5). Su v15
   lo scarto era 0 su 214.
4. **Il costo del case-sensitive su ko/kd non è nullo sul corpus**: 38 etichette
   con `ko`/`kd` minuscolo genuino (`A549_RB1_ko`, `HEPACAM2 ko`, `DHX34-kd`)
   perdono il marcatore, e 18 confronti perdono la segnalazione. Zero effetti sul
   deliverable poolato.
