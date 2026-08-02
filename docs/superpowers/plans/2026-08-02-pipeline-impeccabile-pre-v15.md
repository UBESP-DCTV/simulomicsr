# Rendere impeccabili codice e pipeline prima del re-cluster v15 — piano di implementazione

> **Per chi esegue:** SOTTO-SKILL RICHIESTA: usare `superpowers:subagent-driven-development`
> (consigliata) oppure `superpowers:executing-plans` per eseguire questo piano task per task.
> I passi usano caselle (`- [ ]`) per il tracciamento.

**Obiettivo:** chiudere i difetti confermati dal protocollo dei 137 agenti (2026-08-02) in modo
che il re-cluster v15 e il re-pool che lo segue producano un deliverable corretto, auditabile e
distinguibile dai run precedenti — senza che serva un sedicesimo re-cluster.

**Architettura:** tre blocchi indipendenti. (A) Lo **Stadio 3**, che va toccato ADESSO perché
v15 è l'ultimo re-cluster consentito: la lista delle fusioni e l'univocità del `record_id`.
(B) Lo **Stadio 4**, che gira dopo e si può correggere mentre v15 è in esecuzione: la dedup, i
verdetti di coerenza, la provenienza. (C) Gli **script e i documenti**, che non toccano il
calcolo ma decidono se ci accorgeremmo di un fallimento.

**Tecnologie:** R, testthat 3e, devtools, arrow. Nessuna dipendenza nuova.

## Vincoli globali

- Branch `review-scientific-consistency-2026-06-10`. **Master invariato. Mai `git push`.**
- **TDD obbligatorio**: test che fallisce → codice minimo → test che passa → commit. Ogni task
  finisce con un commit atomico.
- Commenti, messaggi di commit e messaggi d'errore **in italiano**, ASCII per gli accenti nei
  file `.Rd` generati da roxygen.
- `Rscript` **senza** `--vanilla` (renv gestisce i libpath). Lo warning «project is out-of-sync»
  è normale.
- La suite si esegue con `devtools::load_all(".")` + `testthat::test_file(...)`. ⚠️ In
  `test_dir` i dizionari sono fixture: vedi Task 3, che è il motivo per cui questa distinzione
  esiste.
- **Nessun run pesante** durante l'esecuzione di questo piano. Il re-cluster si lancia solo dopo
  il Task 13.
- Decisioni dell'utente del 2026-08-02, già prese e non da ridiscutere:
  1. **glioblastoma esce** da `.CA_DEFRAG_ACCEPT` (restano `tgfb` e `il17`);
  2. la **dedup ADR-0022 si corregge** prima del re-pool, con registro degli scarti;
  3. il **`record_id` diventa univoco** adesso — è l'ultima finestra.

---

## Struttura dei file

| file | responsabilità | task |
|---|---|---|
| `R/stage3-defrag-alias.R` | la lista delle fusioni autorizzate; verità del commento | 1, 12 |
| `tests/testthat/test-stage3-defrag-alias.R` | difendere le fusioni e i NON-eventi | 1, 3 |
| `tests/testthat/test-stage3-config.R`, `-build.R` | schema_versions attese | 2 |
| `R/stage3-build.R` | emissione del `record_id` univoco | 4 |
| `R/stage4-dispatch.R` | risoluzione del `record_id` (compatibile all'indietro) | 4 |
| `R/stage4-qc.R` | chiave della dedup + registro degli scarti | 5 |
| `R/stage4-deliverable-annotation.R` | assenza di verdetti = NA, non «coherent» | 6 |
| `analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R` (rinominato dal Task 9, era `-v14.R`) | verdetti fatali, out_dir v15, provenienza | 6, 7, 9, 11 |
| `analysis/p4-fase-f12-stage3-v15-defrag.R` | gate sulla de-frammentazione, smoke che la esercita | 8 |
| `analysis/p5-stage4-layer-b-build-v13.R` | deliverable dal run corrente | 10 |
| `R/stage4-build.R`, `R/stage4-io.R` | impronta dello Stadio 3 nell'artefatto | 11 |

---

## Task 1: la regola fonde due entità, non tre

**File:**
- Modifica: `R/stage3-defrag-alias.R:318-329` (`.CA_DEFRAG_ACCEPT`) e `:281-317` (il roxygen)
- Test: `tests/testthat/test-stage3-defrag-alias.R`

**Interfacce:**
- Consuma: niente.
- Produce: `.CA_DEFRAG_ACCEPT` con **due** voci (`tgfb` → `HGNC:11766`, `il17` → `HGNC:5981`).
  I task 8 e 12 dipendono da questo numero.

**Perché:** misurato dal protocollo — dei 40 membri candidati per `glioblastoma`, **39 non
arrivano nemmeno alla regola** (l'entità gliela assegna il ramo `anchor`, che precede la
de-frammentazione). Al ramo di ripiego arriva **un solo record** (GSE241396) e ha una chiave di
controllo diversa (`non tumor`), quindi finisce in un gruppo isolato a k=1. La fusione non
chiude lo split (`STR:glioblastoma` k=6 resta accanto a `MeSH:D005909`) e farebbe entrare nel
deliverable una meta-analisi a k=3 esatti mai letta da nessuno.

- [ ] **Passo 1: scrivere il test che fallisce**

In `tests/testthat/test-stage3-defrag-alias.R`, aggiungere in fondo:

```r
test_that("la lista autorizzata contiene DUE entita': glioblastoma e' stato tolto", {
  # Decisione utente 2026-08-02. Misurato: dei 40 membri candidati, 39 hanno gia'
  # l'entita' dal ramo `anchor` (che precede la de-frammentazione) e al ripiego ne
  # arriva UNO, con una chiave di controllo che non esiste nel gruppo bersaglio.
  # La fusione non chiudeva lo split e faceva entrare una meta-analisi a k=3 esatti
  # mai censita.
  expect_length(simulomicsr:::.CA_DEFRAG_ACCEPT, 2L)
  expect_setequal(names(simulomicsr:::.CA_DEFRAG_ACCEPT), c("tgfb", "il17"))
  expect_false("glioblastoma" %in% names(simulomicsr:::.CA_DEFRAG_ACCEPT))
})

test_that("glioblastoma NON si fonde piu', in nessuna forma", {
  oe <- simulomicsr:::.load_ontology_dicts()
  for (tk in c("glioblastoma", "Glioblastoma", "GLIOBLASTOMA")) {
    expect_true(is.na(simulomicsr:::.ca_defrag_entity(tk, "disease", oe)),
                info = tk)
  }
})

test_that("le due fusioni tenute continuano a funzionare su tutte le grafie del corpus", {
  oe <- simulomicsr:::.load_ontology_dicts()
  for (tk in c("tgfb", "TGFb", "TGF-B", "tgf_b", "TGF-b"))
    expect_identical(simulomicsr:::.ca_defrag_entity(tk, "drug", oe), "HGNC:11766", info = tk)
  for (tk in c("il17", "IL-17", "il_17", "IL17"))
    expect_identical(simulomicsr:::.ca_defrag_entity(tk, "drug", oe), "HGNC:5981", info = tk)
})
```

- [ ] **Passo 2: eseguire il test e vederlo fallire**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-defrag-alias.R")'
```

Atteso: FAIL su `expect_length(..., 2L)` (ne trova 3) e su `expect_true(is.na(...))` per
glioblastoma (restituisce `MeSH:D005909`).

- [ ] **Passo 3: togliere la voce**

In `R/stage3-defrag-alias.R`, sostituire il blocco `.CA_DEFRAG_ACCEPT` (righe 318-329) con:

```r
.CA_DEFRAG_ACCEPT <- c(
  # TGF-beta1: `tgfb`, `TGF-B`, `tgf_b` normalizzano tutti a "tgfb". Misurato:
  # nessuna entita' oltre TGFB1 ha "tgfb" nudo fra gli alias (TGFB2 e TGFB3
  # hanno "tgfb2"/"tgfb3"). E' la figura 2 del main paper: studi-slot CENSITI
  # 65 -> 78; studi POOLATI attesi 49 -> 59 (i due numeri sono grandezze
  # DIVERSE: il primo e' il k dello Stadio 3, il secondo quello che la scheda
  # del case study mostra. Verificato che i tre insiemi di studi poolabili sono
  # disgiunti).
  "tgfb" = "HGNC:11766",
  # IL17A: "il17" aggancia solo HGNC:5981 fra i geni. Nel corpus esiste un solo
  # gruppo IL17. Misurato: 11 membri su 5 studi, k censito 8 -> 12.
  "il17" = "HGNC:5981"
  # ⚠️ GLIOBLASTOMA TOLTO (decisione utente 2026-08-02). Era autorizzato dalla
  # decisione del 2026-07-31, ma la misura fatta dopo mostra che non comprava
  # nulla: dei 40 membri candidati 39 hanno gia' l'entita' dal ramo `anchor`
  # (R/stage3-contrast-anchor.R:700-702), che PRECEDE questo ripiego e che la
  # regola non puo' vedere. Al ramo di ripiego arrivava UN solo record
  # (GSE241396), con chiave di controllo `non tumor` assente nel gruppo
  # bersaglio: sarebbe finito in un gruppo isolato a k=1. In piu' la fusione
  # non chiudeva lo split (in v13 convivono gia' `STR:glioblastoma` k=6, fonte
  # anchor, e `MeSH:D005909` k=3, stesso verso e stesso controllo) e avrebbe
  # fatto entrare nel deliverable una meta-analisi a k=3 ESATTI mai censita,
  # nella fascia in cui il progetto ha misurato l'80% di gruppi dominati da un
  # solo studio.
)
```

Poi, nel roxygen sopra la costante (righe ~281-317), sostituire la frase
«Nessuno di questi difetti tocca le tre fusioni qui sotto: sono sostenute dal nome primario,
adjudicate una per una, e **nessuna e' fra le entita' colpite dallo split del ramo anchor**
(verificato sull'output v14).» con:

```
#' Nessuno di questi difetti tocca le DUE fusioni qui sotto. ⚠️ RETTIFICA
#' 2026-08-02: la versione precedente diceva «nessuna e' fra le entita' colpite
#' dallo split del ramo anchor» ed era FALSA per glioblastoma — lo smentiva
#' proprio l'output v14 che citava (`MeSH:D005909` k=7 accanto a
#' `STR:glioblastoma` k=2, stesso verso, stessa chiave di controllo). Per quello
#' glioblastoma e' stato tolto. Per `tgfb` e `il17` la verifica regge: nel
#' corpus non esiste NESSUN ancoraggio `STR:` che normalizzi a quei due token
#' (misurato su v13, residuo anchor zero per entrambi).
```

- [ ] **Passo 4: eseguire il test e vederlo passare**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-defrag-alias.R")'
```

Atteso: 0 FAIL. Alcune asserzioni preesistenti su glioblastoma falliranno: vanno **cambiate**
nello stesso passo, capovolgendo l'attesa (da «si fonde» a «non si fonde piu'»), con accanto il
commento della decisione. Non vanno cancellate.

- [ ] **Passo 5: commit**

```bash
git add R/stage3-defrag-alias.R tests/testthat/test-stage3-defrag-alias.R
git commit -m "Glioblastoma esce dalle fusioni: comprava un membro su quaranta"
```

---

## Task 2: la suite torna verde

**File:**
- Modifica: `tests/testthat/test-stage3-config.R:62-70`, `tests/testthat/test-stage3-build.R:36-38`

**Interfacce:**
- Consuma: `stage3_default_config()$schema_versions`, che dal commit `f0907fc` ha 7 nomi.
- Produce: suite `stage3` con 0 FAIL — precondizione del Task 13.

**Perché:** `contrast_defrag` è stato aggiunto a `schema_versions` senza aggiornare i due test
che ne verificano l'elenco. **La suite è rossa, e il rosso è committato.**

- [ ] **Passo 1: riprodurre il fallimento**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-config.R")'
```

Atteso: `FAIL 1`, messaggio `Needs: "contrast_defrag"`.

- [ ] **Passo 2: aggiornare le due attese**

In `tests/testthat/test-stage3-config.R:62-64` aggiungere `"contrast_defrag"` all'elenco di
`expect_named`, e subito sotto la riga `expect_equal(cfg$schema_versions$anchor, "v3.1.1")`
aggiungere:

```r
  # Un run che cambia la regola di de-frammentazione DEVE essere distinguibile
  # dai suoi metadati: senza questo campo il run_id di v13, v14 e v15 sarebbe
  # identico (364547a7). Con "v2" v15 vale 7f986159.
  expect_equal(cfg$schema_versions$contrast_defrag, "v2")
```

Stessa aggiunta di `"contrast_defrag"` all'elenco in `tests/testthat/test-stage3-build.R:36-38`.

- [ ] **Passo 3: verificare il verde sull'intera suite stage3**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="stage3", stop_on_failure=FALSE)'
```

Atteso: `FAIL 0`. Annotare il numero di SKIP: serve al Task 3.

- [ ] **Passo 4: commit**

```bash
git add tests/testthat/test-stage3-config.R tests/testthat/test-stage3-build.R
git commit -m "I due test che il campo contrast_defrag aveva lasciato rossi"
```

---

## Task 3: i test smettono di saltare la regola

**File:**
- Modifica: `tests/testthat/test-stage3-defrag-alias.R` (le righe con `skip_if`)

**Interfacce:**
- Consuma: `.ca_defrag_entity`, che **non legge più** `ontology_env` (provato: gira con un
  ambiente vuoto, con `NULL` e con un indice avvelenato, dando sempre lo stesso risultato).
- Produce: un file di test in cui la regola è esercitata anche sotto `test_dir`.

**Perché:** misurato — sotto `test_dir` si saltano **21 blocchi su 25**, sparisce l'84% delle
asserzioni, e **nessuna delle superstiti chiama `.ca_defrag_entity`**, cioè l'unica funzione del
file che la produzione usa. Fra i saltati c'è l'asserzione che impedisce di ri-generalizzare la
regola. In più un test di mutazione ha mostrato che si possono togliere **tutte e quattro** le
guardie interne senza far fallire una sola asserzione, su 14.089 token del corpus vero: i test
che dicono di difenderle passano per la ragione sbagliata.

- [ ] **Passo 1: misurare i due regimi, per iscritto**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-defrag-alias.R")' 2>&1 | tail -3
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="stage3-defrag-alias", stop_on_failure=FALSE)' 2>&1 | tail -3
```

Annotare i due conteggi PASS/SKIP: sono la prova che il difetto esiste, e il Passo 4 li rifà.

- [ ] **Passo 2: togliere `skip_if` dai blocchi che non usano i dizionari**

I blocchi che chiamano **solo** `.ca_defrag_entity`, `.CA_DEFRAG_ACCEPT`, `.ca_defrag_norm` non
hanno bisogno dei dizionari veri: `.ca_defrag_entity` non legge `ontology_env`. Per ciascuno di
quei blocchi togliere la riga `skip_if(...)` e sostituire l'argomento `oe` con `NULL`,
aggiungendo in testa al file il commento:

```r
# NOTA (2026-08-02): i blocchi qui sotto NON saltano piu' sotto `test_dir`.
# `.ca_defrag_entity()` e' un lookup su `.CA_DEFRAG_ACCEPT` e non legge
# `ontology_env` (verificato: stesso esito con ambiente vuoto, NULL e indice
# avvelenato). Prima l'84% delle asserzioni spariva quando la suite girava
# insieme agli altri file di stage3, e nessuna delle superstiti chiamava la
# funzione che la produzione usa: la suite era verde senza provare nulla.
```

- [ ] **Passo 3: aggiungere il test che rende esplicita l'inerzia delle guardie**

```r
test_that("le guardie interne sono INERTI sulle chiavi autorizzate, ed e' dichiarato", {
  # Misurato con un test di mutazione: togliendo una qualsiasi delle quattro
  # guardie — o tutte e quattro — l'esito non cambia su 14.089 token del corpus.
  # Non e' un difetto: le due chiavi autorizzate le superano tutte per
  # costruzione. Va detto, altrimenti i test sembrano difendere qualcosa che non
  # possono difendere.
  for (k in names(simulomicsr:::.CA_DEFRAG_ACCEPT)) {
    expect_gte(nchar(k), simulomicsr:::.CA_DEFRAG_MIN_CHARS)
    expect_false(simulomicsr:::.is_unreliable_candidate(k), info = k)
    expect_false(simulomicsr:::.is_alias_collision(k, simulomicsr:::.CA_DEFRAG_ACCEPT[[k]]),
                 info = k)
  }
  # `.CA_DEFRAG_REJECT` non puo' scattare: nessuna delle sue chiavi e' fra le
  # autorizzate. E' materiale d'audit, non una guardia viva.
  rej_keys <- sub("\\|.*$", "", simulomicsr:::.CA_DEFRAG_REJECT)
  expect_length(intersect(rej_keys, names(simulomicsr:::.CA_DEFRAG_ACCEPT)), 0L)
})
```

- [ ] **Passo 4: verificare che i due regimi ora coincidano sulle asserzioni che contano**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="stage3-defrag-alias", stop_on_failure=FALSE)' 2>&1 | tail -3
```

Atteso: FAIL 0, e un numero di SKIP **inferiore** a quello annotato al Passo 1. I blocchi che
usano davvero i dizionari (quelli che interrogano l'indice degli alias) possono restare saltati.

- [ ] **Passo 5: commit**

```bash
git add tests/testthat/test-stage3-defrag-alias.R
git commit -m "I test della regola girano anche nella suite, e dicono la verita' sulle guardie"
```

---

## Task 4: il `record_id` diventa univoco

**File:**
- Modifica: `R/stage3-build.R:619` (emissione) e il loop che la contiene
- Modifica: `R/stage4-dispatch.R:64-69` (`.lookup_cmp`)
- Test: `tests/testthat/test-stage4-dispatch.R` (o file nuovo `test-stage3-record-id.R`)

**Interfacce:**
- Produce: `record_id` nella forma `<series>__<comparison_id>__<indice>` per i record `cgroup`.
  `.split_record_id` **non cambia** (splitta sul primo `__`, quindi `series_id` resta corretto)
  e `sub("__.*$", "", rid)` continua a dare la serie: gli script di audit esistenti non si
  rompono.
- Produce: `.lookup_cmp(study, suffix)` che risolve l'indice quando c'è e si comporta **come
  prima** quando non c'è — così gli output v13 restano leggibili.

**Perché:** misurato — **291 studi** emettono lo stesso `comparison_id` più volte, e in 746 casi
su 754 le copie puntano a **bracci diversi**. Poiché `.lookup_cmp` restituisce la prima
occorrenza, oggi: (a) il gruppo del 17β-estradiolo (k=10, 410 geni significativi, marcato
«coerente») ha **14 righe su 44 che risolvono a un braccio che non è estradiolo** (BPC, DCDPS,
bis(4-clorofenil)sulfone); (b) **sette gruppi del deliverable perdono uno studio intero** —
vemurafenib 8→9, gefitinib 7→8, ciclosporina A 3→4, IFN-γ 19→20, IL1B 17→18, gemcitabina 4→5,
JQ1 24→25 — e due di essi sono case study del Layer B. Correggerlo richiede un re-cluster: **v15
è l'ultima occasione.**

- [ ] **Passo 1: scrivere il test che fallisce**

Creare `tests/testthat/test-stage3-record-id.R`:

```r
test_that(".lookup_cmp risolve l'indice quando il record_id lo porta", {
  # Lo Stadio 2 emette lo stesso comparison_id piu' volte nello stesso studio
  # (291 studi, 746 casi su 754 con bracci DIVERSI). Senza indice si poola
  # sempre il primo braccio: misurato, 7 gruppi del deliverable perdono uno
  # studio intero e uno ne poola uno sbagliato.
  study <- list(comparisons = list(
    list(comparison_id = "cmp_a", treated_group = "g1", control_group = "g0"),
    list(comparison_id = "cmp_a", treated_group = "g2", control_group = "g0"),
    list(comparison_id = "cmp_b", treated_group = "g3", control_group = "g0")
  ))
  # con indice: pesca l'occorrenza giusta
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_a__1")$treated_group, "g1")
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_a__2")$treated_group, "g2")
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_b__1")$treated_group, "g3")
  # senza indice: comportamento IDENTICO a prima (retrocompatibilita' con v13)
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_a")$treated_group, "g1")
  expect_null(simulomicsr:::.lookup_cmp(study, "cmp_z"))
  # un indice fuori intervallo non deve inventare un braccio
  expect_null(simulomicsr:::.lookup_cmp(study, "cmp_a__9"))
  # un comparison_id che contiene "__" e finisce per numero NON va scambiato
  # per un indice se quell'id esiste tale e quale
  study2 <- list(comparisons = list(
    list(comparison_id = "grp_01__vs__grp_02", treated_group = "gX", control_group = "g0")))
  expect_identical(simulomicsr:::.lookup_cmp(study2, "grp_01__vs__grp_02")$treated_group, "gX")
})
```

- [ ] **Passo 2: eseguire e vedere fallire**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-record-id.R")'
```

Atteso: FAIL — `.lookup_cmp(study, "cmp_a__1")` restituisce `NULL` (nessun `comparison_id` si
chiama così).

- [ ] **Passo 3: implementare la risoluzione dell'indice**

In `R/stage4-dispatch.R` sostituire `.lookup_cmp` (righe 61-69) con:

```r
#' Lookup comparison da study via comparison_id, con indice opzionale
#'
#' Lo Stadio 2 puo' emettere lo STESSO \code{comparison_id} piu' volte dentro lo
#' stesso studio, e nel 99% dei casi le copie puntano a bracci DIVERSI (misurato:
#' 291 studi, 746 coppie su 754). Fino al 2026-08-02 questa funzione restituiva
#' sempre la PRIMA, quindi i membri che erano la seconda o la terza copia
#' poolavano i campioni della prima: 7 gruppi del deliverable perdevano uno
#' studio intero e il gruppo del 17-beta-estradiolo poolava 14 righe su 44 di un
#' altro composto.
#'
#' Dallo Stadio 3 v15 il \code{record_id} porta un terzo segmento con l'indice
#' 1-based dell'occorrenza. Il suffisso senza indice resta valido e si comporta
#' come prima: gli output v13/v14 restano leggibili.
#'
#' @keywords internal
.lookup_cmp <- function(study, comparison_id) {
  # Prima si prova il match ESATTO: un comparison_id puo' contenere "__" e
  # terminare con cifre, e in quel caso non e' un indice.
  for (cmp in study$comparisons) {
    if (identical(cmp$comparison_id, comparison_id)) return(cmp)
  }
  m <- regmatches(comparison_id, regexec("^(.*)__([0-9]+)$", comparison_id))[[1L]]
  if (length(m) != 3L) return(NULL)
  base <- m[2L]; idx <- as.integer(m[3L])
  hits <- Filter(function(cmp) identical(cmp$comparison_id, base), study$comparisons)
  if (idx < 1L || idx > length(hits)) return(NULL)
  hits[[idx]]
}
```

- [ ] **Passo 4: eseguire e vedere passare**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-record-id.R")'
```

Atteso: PASS.

- [ ] **Passo 5: emettere l'indice nello Stadio 3**

In `R/stage3-build.R`, nel loop sulle comparison che contiene la riga 619, mantenere un
contatore per `comparison_id` dentro lo studio. Prima del loop sulle comparison inserire:

```r
      # Lo stesso comparison_id puo' comparire piu' volte nello stesso studio, su
      # bracci diversi: senza un indice il record_id non e' una chiave e a valle
      # si poola sempre il primo braccio (misurato 2026-08-02: 7 gruppi del
      # deliverable perdono uno studio, uno ne poola uno sbagliato).
      cmp_seen <- new.env(hash = TRUE, parent = emptyenv())
```

e sostituire la riga 619 con:

```r
      n_seen <- (get0(cmp$comparison_id, envir = cmp_seen, ifnotfound = 0L)) + 1L
      assign(cmp$comparison_id, n_seen, envir = cmp_seen)
      rid <- sprintf("%s__%s__%d", sid, cmp$comparison_id, n_seen)
```

⚠️ Il contatore va incrementato **prima** del `next` del gate (riga 620-626), altrimenti gli
indici scivolano quando un confronto viene scartato: il codice sopra lo garantisce perché sta
sopra il `if (nzchar(v$drop_reason))`.

- [ ] **Passo 6: test di non-regressione sul formato**

Aggiungere a `tests/testthat/test-stage3-record-id.R`:

```r
test_that("il record_id nuovo resta parsabile dagli strumenti esistenti", {
  rid <- "GSE12345__grp_0002_vs_grp_0007__2"
  # `.split_record_id` splitta sul PRIMO "__": la serie resta corretta
  expect_identical(simulomicsr:::.split_record_id(rid)$series_id, "GSE12345")
  # la convenzione usata dagli script di audit continua a valere
  expect_identical(sub("__.*$", "", rid), "GSE12345")
  # e il suffisso porta l'indice fino a .lookup_cmp
  expect_identical(simulomicsr:::.split_record_id(rid)$suffix,
                   "grp_0002_vs_grp_0007__2")
})
```

- [ ] **Passo 7: suite stage3 + stage4 verdi**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="stage3", stop_on_failure=FALSE)' 2>&1 | tail -3
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="stage4", stop_on_failure=FALSE)' 2>&1 | tail -3
```

Atteso: FAIL 0 in entrambe. Se una fixture cabla un `record_id` a due segmenti, **non** cambiare
il codice: aggiornare la fixture, perché il ramo senza indice resta supportato.

- [ ] **Passo 8: commit**

```bash
git add R/stage3-build.R R/stage4-dispatch.R tests/testthat/test-stage3-record-id.R
git commit -m "Il record_id diventa una chiave: senza indice si poolava sempre il primo braccio"
```

---

## Task 5: la dedup usa l'identità del contrasto, e scrive chi butta

**File:**
- Modifica: `R/stage4-qc.R:33-47` (`.dedup_rem_group_by_entity`) e `:123-126` (chiamata)
- Test: `tests/testthat/test-stage4-qc.R`

**Interfacce:**
- Produce: `.dedup_rem_group_by_entity(rem_group_clusters)` che restituisce il data frame
  deduplicato **con attributo** `attr(x, "scartati")` = data frame degli scartati con motivo.
  Il Task 9 lo scrive in `non_processable`.

**Perché:** misurato su v13 — la chiave è `kind_effective_resolved || agent_id_resolved ||
contrast_direction`, e per i `cgroup` quei due campi vengono dal **primo membro** e non dal
contrasto (`agent_id_resolved != contrast_entity` in 188 casi su 358). Risultato: **53 gruppi
scartati, 49 dei quali orfani** — la loro entità non ricompare da nessuna parte. Tutte e 53 le
coppie perdente/vincente hanno **zero record in comune**: non sono doppioni. Fra le vittime
tamoxifene k=7 (ucciso da afimoxifene k=9: la funzione tiene il k *più piccolo*), testosterone
k=6 (ucciso dal suo antagonista enzalutamide) e due gruppi di tubercolosi, uccisi da un gruppo
che porta il nome «Mycobacterium tuberculosis» ed è COVID. **Nessuno dei 53 compare in
`non_processable.rds`**: la perdita non è registrata da nessuna parte.

⚠️ La chiave corretta è `contrast_entity || contrast_direction`. **Non** includere
`contrast_control_key`: sarebbe l'`anchor_key`, unica per costruzione (358 su 358), quindi la
dedup diventerebbe un no-op e riaprirebbe la frammentazione per tipo di controllo che ADR-0022
voleva chiudere. Con la chiave giusta i cluster passano da 305 a **354**: restano scartati
esattamente i **4** duplicati veri (fra cui `STR:hypoxia` k=14 contro k=37).

- [ ] **Passo 1: scrivere il test che fallisce**

```r
test_that("la dedup dei cgroup usa l'entita' del CONTRASTO, non l'anchor del primo membro", {
  # Misurato su v13: agent_id_resolved != contrast_entity in 188 cluster su 358.
  # Con la chiave vecchia il tamoxifene (k=7) veniva ucciso da afimoxifene (k=9)
  # perche' condividevano l'anchor, pur non avendo NESSUN record in comune.
  df <- data.frame(
    cluster_id = c("cgroup_L5_aaa", "cgroup_L5_bbb"),
    kind_effective_resolved = c("small_molecule", "small_molecule"),
    agent_id_resolved = c("CHEBI:44616", "CHEBI:44616"),   # stesso anchor, sbagliato
    contrast_entity = c("CHEBI:41774", "CHEBI:44616"),      # tamoxifene vs afimoxifene
    contrast_direction = c("gain", "gain"),
    k = c(7L, 9L), n_total = c(161L, 120L), level = c(5L, 5L),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.dedup_rem_group_by_entity(df)
  expect_equal(nrow(out), 2L)
  expect_setequal(out$contrast_entity, c("CHEBI:41774", "CHEBI:44616"))
})

test_that("la dedup toglie i duplicati VERI della stessa entita' e tiene il k massimo", {
  df <- data.frame(
    cluster_id = c("cgroup_L5_lo", "cgroup_L5_hi"),
    kind_effective_resolved = c("environmental", "environmental"),
    agent_id_resolved = c("STR:hypoxia", "STR:hypoxia"),
    contrast_entity = c("STR:hypoxia", "STR:hypoxia"),
    contrast_direction = c("gain", "gain"),
    k = c(14L, 37L), n_total = c(100L, 300L), level = c(5L, 5L),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.dedup_rem_group_by_entity(df)
  expect_equal(nrow(out), 1L)
  expect_equal(out$k, 37L)
  sc <- attr(out, "scartati")
  expect_equal(nrow(sc), 1L)
  expect_equal(sc$cluster_id, "cgroup_L5_lo")
  expect_match(sc$reason, "dedup_entita_duplicata")
})

test_that("i cluster legacy senza contrast_entity usano la chiave di prima", {
  df <- data.frame(
    cluster_id = c("group_L4_aaa", "group_L4_bbb"),
    kind_effective_resolved = c("disease_vs_normal", "disease_vs_normal"),
    agent_id_resolved = c("MeSH:D001943", "MeSH:D001943"),
    k = c(3L, 8L), n_total = c(30L, 80L), level = c(4L, 4L),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.dedup_rem_group_by_entity(df)
  expect_equal(nrow(out), 1L)
  expect_equal(out$k, 8L)
})
```

- [ ] **Passo 2: eseguire e vedere fallire**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage4-qc.R")'
```

Atteso: FAIL sul primo test (`nrow(out)` è 1, non 2) e sul terzo blocco per l'attributo mancante.

- [ ] **Passo 3: implementare**

Sostituire `.dedup_rem_group_by_entity` (righe 33-47) con:

```r
.dedup_rem_group_by_entity <- function(rem_group_clusters) {
  if (nrow(rem_group_clusters) == 0L) return(rem_group_clusters)
  direction <- .col_or_default(rem_group_clusters, "contrast_direction", NA_character_)
  direction[is.na(direction)] <- ""
  # ⚠️ 2026-08-02: per i cgroup l'identita' e' `contrast_entity`, NON l'anchor.
  # `agent_id_resolved` e `kind_effective_resolved` vengono dal PRIMO MEMBRO
  # (R/stage3-build.R:861-866) e per i cgroup l'invariante che li giustifica e'
  # falsa, perche' li' l'anchor_key nasce dal contrasto e non dall'anchor:
  # misurato, differiscono in 188 cluster su 358. La chiave vecchia buttava 53
  # gruppi, 49 dei quali ORFANI (entita' che non ricompare da nessuna parte), e
  # tutte e 53 le coppie perdente/vincente avevano ZERO record in comune —
  # tamoxifene ucciso da afimoxifene, testosterone dal suo antagonista, due
  # gruppi di tubercolosi da un gruppo che si chiama tubercolosi ed e' COVID.
  #
  # Il `contrast_control_key` resta FUORI dalla chiave: con lui dentro la chiave
  # coinciderebbe con l'anchor_key, unica per costruzione, e la dedup sarebbe un
  # no-op che riapre la frammentazione per tipo di controllo (l'intento di
  # ADR-0022 e' proprio fondere hypoxia-vs-vehicle e hypoxia-vs-normoxia al k
  # maggiore).
  ce <- .col_or_default(rem_group_clusters, "contrast_entity", NA_character_)
  entity <- ifelse(
    !is.na(ce) & nzchar(ce),
    paste0(ce, "||", direction),
    paste0(rem_group_clusters$kind_effective_resolved, "||",
           rem_group_clusters$agent_id_resolved, "||", direction))
  ord <- order(entity,
               -rem_group_clusters$k,
               -rem_group_clusters$n_total,
               -rem_group_clusters$level,
               rem_group_clusters$cluster_id)
  rg  <- rem_group_clusters[ord, , drop = FALSE]
  ent <- entity[ord]
  keep <- !duplicated(ent)
  out <- rg[keep, , drop = FALSE]
  # Una selezione silenziosa non e' auditabile: chi viene tolto lo si scrive,
  # con il gruppo che l'ha assorbito.
  sc <- rg[!keep, , drop = FALSE]
  attr(out, "scartati") <- if (nrow(sc) == 0L) {
    data.frame(cluster_id = character(0), reason = character(0),
               details = character(0), stringsAsFactors = FALSE)
  } else {
    data.frame(
      cluster_id = sc$cluster_id,
      reason     = "dedup_entita_duplicata",
      details    = paste0("assorbito da ", out$cluster_id[match(ent[!keep], ent[keep])],
                          " (chiave ", ent[!keep], ")"),
      stringsAsFactors = FALSE)
  }
  out
}
```

- [ ] **Passo 4: eseguire e vedere passare**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage4-qc.R")'
```

Atteso: PASS.

- [ ] **Passo 5: misurare l'effetto sui dati veri, prima di committare**

Scrivere in `analysis/audit/2026-08-02-fix/10-dedup-effetto.R` uno script che carichi
`clusters.rds` di v13, applichi `.identify_layer_a_clusters` e stampi: numero di cluster prima e
dopo la dedup, numero di scartati, e la lista delle entità che rientrano. Eseguirlo.

Atteso, dal protocollo: **da 305 a 354 cluster tenuti, 4 scartati** (contro i 53 di prima) e il
rientro di tamoxifene `CHEBI:41774`, testosterone `CHEBI:17347`, `NCBITaxon:1773`. Se i numeri
non tornano, **fermarsi**: la chiave non è quella giusta.

- [ ] **Passo 6: commit**

```bash
git add R/stage4-qc.R tests/testthat/test-stage4-qc.R analysis/audit/2026-08-02-fix/
git commit -m "La dedup del deliverable smette di buttare 49 meta-analisi distinte"
```

---

## Task 6: l'assenza di verdetti non è un verdetto

**File:**
- Modifica: `R/stage4-deliverable-annotation.R:104-110`
- Test: `tests/testthat/test-stage4-deliverable-annotation.R`

**Perché:** provato eseguendo la funzione — con `coherence_verdicts = NULL` il ramo di ripiego
**non lascia le colonne vuote**: scrive `coherence_verdict = "coherent"` su **ogni riga** e ci
mette accanto `coherence_source = "rilettura-sui-poolati-2026-07-30"`, cioè attesta nel dato una
rilettura umana mai avvenuta. I sei gruppi giudicati incoerenti (influenza, IL1A, IFN-α,
antigene, adenoma, IL3) uscirebbero indistinguibili dagli altri 185, e ADR-0027 chiede che
almeno uno dei sei sia in vetrina.

- [ ] **Passo 1: scrivere il test che fallisce**

```r
test_that("senza verdetti la coerenza resta NA, e la provenienza non viene attestata", {
  # Provato il 2026-08-02: il ramo NULL scriveva "coherent" su OGNI riga e ci
  # metteva sopra la provenienza di una rilettura umana mai avvenuta. Un
  # deliverable che dichiara 191/191 coerenti e' esattamente il fallimento
  # "a favore della conclusione che fa comodo" contro cui esiste il RED ALERT.
  d <- .fixture_deliverable_minimo()   # helper gia' presente nel file di test
  out <- annotate_stage4_deliverable(
    d$cluster_pooled, d$per_study_de, d$meta,
    coherence_verdicts = NULL,
    coherence_source   = "rilettura-sui-poolati-2026-07-30")
  expect_true(all(is.na(out$coherence_verdict)))
  expect_true(all(is.na(out$coherence_source)))
  expect_true("coherence_verdict" %in% names(out))   # la colonna c'e', vuota
})
```

Se `.fixture_deliverable_minimo()` non esiste, scriverla nello stesso file usando come modello
la fixture già usata dagli altri test di quel file.

- [ ] **Passo 2: eseguire e vedere fallire**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage4-deliverable-annotation.R")'
```

Atteso: FAIL — `coherence_verdict` vale `"coherent"`.

- [ ] **Passo 3: implementare**

Sostituire le righe 106-110 di `R/stage4-deliverable-annotation.R` con:

```r
  } else {
    # ⚠️ 2026-08-02: qui prima si scriveva "coherent" su OGNI riga, con la
    # `coherence_source` del chiamante — cioe' il deliverable ATTESTAVA una
    # rilettura umana che non era avvenuta, e i sei gruppi giudicati incoerenti
    # uscivano indistinguibili dagli altri. Un'assenza di giudizio non e' un
    # giudizio di coerenza: si scrive NA, e la provenienza resta vuota.
    d$coherence_verdict <- NA_character_
    d$coherence_reason  <- NA_character_
    d$coherence_source  <- NA_character_
  }
```

- [ ] **Passo 4: eseguire e vedere passare**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage4-deliverable-annotation.R")'
```

- [ ] **Passo 5: commit**

```bash
git add R/stage4-deliverable-annotation.R tests/testthat/test-stage4-deliverable-annotation.R
git commit -m "Nessun verdetto non vuol dire coerente: NA, e nessuna provenienza attestata"
```

---

## Task 7: il re-pool si ferma davvero

**File:**
- Modifica: `analysis/p4-fase-f5-stage4-layer-a-rebuild-v14.R:243` (default), `:298-302` (ramo
  else), `:242` e `:319-322` (il tryCatch che ingoia lo stop)

**Perché:** tre difetti sovrapposti, tutti provati. (a) Il default punta a
`analysis/audit/2026-07-31-defrag/verdetti-poolato-v14.csv`, che **non esiste**, e `VERDETTI_PATH`
non è impostata in **nessun punto del repo**. (b) L'handout chiede di produrre
`verdetti-poolato-v15.csv` mentre il default cerca il `v14`: anche facendo la fase D0ter
correttamente il file non verrebbe letto. (c) Lo `stop()` sui verdetti orfani sta **dentro** il
`tryCatch` che lo declassa a warning — quindi l'affermazione «senza D0ter il re-pool si ferma
davvero», scritta due volte nell'handout, è falsa in entrambi i rami.

- [ ] **Passo 1: riprodurre il comportamento attuale**

```
ls analysis/audit/2026-07-31-defrag/verdetti-poolato-v14.csv ; echo "exit=$?"
grep -rn "VERDETTI_PATH" --include=*.R --include=*.sh --include=*.md . | grep -v '^./docs/superpowers/plans/2026-08-02'
```

Atteso: il file non esiste; `VERDETTI_PATH` compare in **una sola** riga di tutto il repo.

- [ ] **Passo 2: rendere fatale l'assenza, in testa allo script**

Subito dopo il blocco che valida `STAGE3_DIR` (righe 43-54), aggiungere:

```r
# I verdetti di coerenza sono un INGRESSO del run, non un dettaglio
# dell'annotazione: si controllano qui, al minuto zero, non dopo 28 ore.
# Il default puntava a un file inesistente e il ramo di ripiego marcava
# `coherent` TUTTE le righe con la provenienza di una rilettura mai avvenuta.
verdetti_path <- Sys.getenv("VERDETTI_PATH", "")
if (!nzchar(verdetti_path) && !nzchar(Sys.getenv("VERDETTI_ASSENTI_OK"))) {
  stop("VERDETTI_PATH non impostata. Passare il file dei verdetti di coerenza ",
       "(per v15: analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv, ",
       "riusabile perche' nessuna delle 6 chiavi tocca le entita' fuse), oppure ",
       "chiedere esplicitamente un deliverable senza coerenza con VERDETTI_ASSENTI_OK=1.")
}
if (nzchar(verdetti_path) && !file.exists(verdetti_path)) {
  stop("VERDETTI_PATH indica un file che non esiste: ", verdetti_path)
}
```

Poi, alla riga 243, sostituire la vecchia assegnazione con un semplice riuso della variabile già
validata:

```r
  # gia' validata in testa allo script
```

- [ ] **Passo 3: portare la guardia sugli orfani fuori dal tryCatch**

Spostare il blocco che confronta le chiavi dei verdetti con quelle del deliverable **prima**
dell'apertura del `tryCatch` di riga 242, così il suo `stop()` ferma davvero. Nel commento
accanto scrivere:

```r
# ⚠️ 2026-08-02: questo controllo stava DENTRO il tryCatch che lo declassava a
# warning, quindi «senza D0ter il re-pool si ferma davvero» era falso. Qui fuori
# ferma sul serio — e ferma PRIMA delle 28 ore, non dopo.
```

- [ ] **Passo 4: correggere il testo del warning residuo**

Il messaggio del ramo di ripiego diceva «il deliverable uscira' SENZA le colonne di coerenza»,
che è falso (le colonne ci sono). Sostituirlo con: «le colonne di coerenza usciranno VUOTE (NA):
nessun gruppo sara' dichiarato coerente ne' incoerente».

- [ ] **Passo 5: verificare a secco**

```
DRY_RUN=1 STAGE3_DIR=analysis/p4-output/20260728T151529Z-stage3-v13-364547a7 timeout 280 Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v14.R 2>&1 | tail -20
```

Atteso: si ferma subito con il messaggio su `VERDETTI_PATH`. Poi rilanciare aggiungendo
`VERDETTI_PATH=analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv` e verificare
che superi il controllo (fallirà più avanti sul nome della dir, che il Task 9 sistema).

- [ ] **Passo 6: commit**

```bash
git add analysis/p4-fase-f5-stage4-layer-a-rebuild-v14.R
git commit -m "I verdetti sono un ingresso del run: si controllano al minuto zero, non dopo 28 ore"
```

---

## Task 8: il re-cluster si accorge se la regola non ha fatto niente

**File:**
- Modifica: `analysis/p4-fase-f12-stage3-v15-defrag.R`, blocco SANITY (righe ~494-537) e
  selezione smoke (righe ~168-229)

**Perché:** misurato — l'intersezione fra i 250 studi dello smoke e i **47** toccati dalla
de-frammentazione è **zero** (nel log di v14 lo smoke stampa letteralmente `TGFB1: k=0`). E il
gate del run pieno non copre il buco: il pavimento di TGFB1 è **61** mentre v13 ne dà già **65**,
quindi un run in cui la regola è completamente inerte stampa `OK`. Nessuna riga dello script
guarda `contrast_entity_source`.

- [ ] **Passo 1: aggiungere il gate sull'unica cosa nuova**

Nel blocco SANITY, subito prima dei pavimenti bandiera, inserire:

```r
# --- GATE DELLA DE-FRAMMENTAZIONE -------------------------------------------
# Senza questo, un run in cui la regola non fa NULLA passa verde: il pavimento
# di TGFB1 e' 61 e v13 ne da' gia' 65. Misurato il 2026-08-02.
if ("contrast_entity_source" %in% names(cl)) {
  n_dfg <- sum(cl$contrast_entity_source == "defrag", na.rm = TRUE)
  cli::cli_alert_info("cluster con entita' dalla de-frammentazione: {n_dfg}")
  if (!SMOKE && n_dfg == 0L)
    stop("La de-frammentazione non ha prodotto NULLA: 0 cluster con ",
         "contrast_entity_source=='defrag'. FERMARSI e capire perche'.")
} else {
  stop("colonna contrast_entity_source assente: impossibile verificare la ",
       "de-frammentazione. FERMARSI.")
}
# Post-condizioni falsificabili, misurate su v13 (dove valgono 65 e 8).
if (!SMOKE) {
  k_of <- function(id) {
    s <- is_cg & !is.na(cl$contrast_entity) & cl$contrast_entity == id
    if (any(s)) max(cl$k[s], na.rm = TRUE) else 0L
  }
  for (chk in list(list(id = "HGNC:11766", min = 66L, nome = "TGFB1"),
                   list(id = "HGNC:5981",  min = 9L,  nome = "IL17A"))) {
    kk <- k_of(chk$id)
    if (kk < chk$min)
      stop(sprintf("%s (%s): k=%d, atteso > %d. La fusione non e' avvenuta.",
                   chk$nome, chk$id, kk, chk$min - 1L))
    cli::cli_alert_success("{chk$nome}: k={kk} (atteso > {chk$min - 1L}) OK")
  }
  # Le forme STR: delle entita' fuse non devono sopravvivere.
  residui <- unique(cl$contrast_entity[is_cg & !is.na(cl$contrast_entity) &
    gsub("[^a-z0-9]", "", tolower(sub("^STR:", "", cl$contrast_entity))) %in%
      c("tgfb", "il17") & startsWith(cl$contrast_entity, "STR:")])
  if (length(residui) > 0L)
    stop("residui STR: delle entita' fuse: ", paste(residui, collapse = ", "))
}
```

- [ ] **Passo 2: far sì che lo smoke tocchi gli studi giusti**

Nel blocco di selezione smoke, dopo la parte che aggiunge le serie degli override fallback,
inserire:

```r
    # [v15] Lo smoke DEVE esercitare la de-frammentazione: senza questo la sua
    # intersezione con i 47 studi toccati e' ZERO (misurato sul subset di v14) e
    # lo smoke passa verde senza aver provato la sola cosa nuova del run.
    dfg_dump <- "analysis/audit/2026-07-31-defrag/impatto-membri-v5.rds"
    if (file.exists(dfg_dump)) {
      dd  <- readRDS(dfg_dump)
      tok <- gsub("[^a-z0-9]", "", tolower(sub("^STR:", "", dd$ent_off)))
      dfg_series <- unique(dd$study[!is.na(dd$src_off) & dd$src_off == "STR" &
                                      tok %in% c("tgfb", "il17")])
      smoke_target_series <- unique(c(dfg_series, smoke_target_series))
      cli::cli_alert_info("[v15] +{length(dfg_series)} serie che esercitano la de-frammentazione")
    } else {
      cli::cli_alert_warning("[v15] dump della de-frammentazione assente: lo smoke NON la esercita")
    }
```

⚠️ `dfg_series` va messo **per primo** nella concatenazione, perché più avanti la lista viene
troncata a `SMOKE_N`: se sta in coda viene tagliato.

- [ ] **Passo 3: eseguire lo smoke**

```
timeout 3000 Rscript analysis/p4-fase-f12-stage3-v15-defrag.R 2>&1 | tee analysis/audit/2026-08-02-fix/30-smoke-v15.log | tail -40
```

Atteso: PASS, con la riga `cluster con entita' dalla de-frammentazione: N` e **N > 0**. Se N è
zero, la regola non sta girando: fermarsi.

- [ ] **Passo 4: commit**

```bash
git add analysis/p4-fase-f12-stage3-v15-defrag.R analysis/audit/2026-08-02-fix/
git commit -m "Il re-cluster si ferma se la de-frammentazione non ha fatto niente, e lo smoke la esercita"
```

---

## Task 9: lo script di re-pool dice la verità su quale versione produce

**File:**
- Modifica: `analysis/p4-fase-f5-stage4-layer-a-rebuild-v14.R` righe 1, 2, 13, 34, 219-220, 337
- Rinomina: il file stesso in `analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R`

**Perché:** lo stesso file **si dichiara v13** (righe 1, 2, 34, 337), **pretende v15** in
ingresso (righe 45, 48) e **scrive v14** in uscita (righe 219-220). La cartella
`simulomicsr-stage4-v14` non esiste e verrebbe creata adesso, puntando per convenzione al
re-cluster **abbandonato**. Il commento di riga 13 è sbagliato su entrambe le cose.

- [ ] **Passo 1: derivare il token dalla dir d'ingresso invece di scriverlo**

Subito dopo la guardia su `STAGE3_DIR` (riga ~48) inserire:

```r
# Il nome dell'uscita non puo' piu' contraddire l'ingresso: si deriva.
v_token <- sub("^.*-stage3-(v[0-9]+)-.*$", "\\1", basename(stage3_dir))
stopifnot(grepl("^v[0-9]+$", v_token))
```

e alle righe 219-220 sostituire le due stringhe cablate con:

```r
  out_root <- file.path("/mnt/wwn-0x5000039d58caca35", paste0("simulomicsr-stage4-", v_token))
  out_dir  <- file.path(out_root, sprintf("%s-stage4-%s-%s", ts, v_token, run_id))
```

- [ ] **Passo 2: allineare le etichette testuali**

Sostituire «v13» con «v15» nelle righe 1, 2, 34, 337 e riscrivere il commento di riga 13 come:
«out_dir -> simulomicsr-stage4-<token>, con <token> derivato dal nome della dir di Stadio 3 in
ingresso».

- [ ] **Passo 3: rinominare il file**

```bash
git mv analysis/p4-fase-f5-stage4-layer-a-rebuild-v14.R analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R
grep -rn "rebuild-v14" --include=*.md docs/ | cat
```

Aggiornare i riferimenti trovati nei documenti allo stesso nome nuovo.

- [ ] **Passo 4: verifica a secco**

```
DRY_RUN=1 STAGE3_DIR=analysis/p4-output/20260728T151529Z-stage3-v13-364547a7 \
  VERDETTI_PATH=analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv \
  timeout 280 Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R 2>&1 | tail -20
```

Atteso: si ferma sul controllo `-stage3-v15-` (giusto: gli abbiamo dato una dir v13). Il
messaggio deve nominare v15.

- [ ] **Passo 5: commit**

```bash
git add -A analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R docs/
git commit -m "Il re-pool non si autodichiara piu' tre versioni diverse: il token viene dall'ingresso"
```

---

## Task 10: il Layer B legge i numeri del run che sta illustrando

**File:**
- Modifica: `analysis/p5-stage4-layer-b-build-v13.R:40-48` e `:220-235`

**Perché:** provato — il deliverable è cablato a `analysis/audit/2026-07-29-etichette-v13/
deliverable-v13-poolato.rds`, e poiché il `cluster_id` di un `cgroup` è l'hash della sola chiave
del contrasto, **il join riesce** proprio sul gruppo di figura 2 (TGF-β1, `cgroup_L5_2e16719f`,
lo stesso id in v13 e v14): la scheda stamperebbe `k_kish = 45,1` calcolato su 49 studi accanto
a un `k_effective` calcolato su ~59. Nessun errore, nessun NA, nessun avviso. Esiste inoltre un
**secondo canale**: la colonna `notes` del CSV di selezione contiene 181 numeri di v13 cablati a
mano, ristampati alla lettera sulla scheda — e il rimedio del primo canale non lo tocca.

- [ ] **Passo 1: portare i tre percorsi in testa e derivare il deliverable**

Sostituire il blocco delle righe 39-48 con:

```r
# I percorsi stanno TUTTI qui e il deliverable si DERIVA: prima era cablato 180
# righe piu' in basso, e chi aggiornava questi due non lo vedeva (misurato
# 2026-08-02: il join sarebbe riuscito in silenzio sulla figura 2 del paper).
stage4_dir  <- Sys.getenv("STAGE4_DIR", "")
stage3_dir  <- Sys.getenv("STAGE3_DIR", "")
if (!nzchar(stage4_dir) || !nzchar(stage3_dir))
  stop("STAGE4_DIR e STAGE3_DIR sono obbligatorie: il Layer B non deve poter ",
       "illustrare un run diverso da quello che misura.")
deliverable_path <- Sys.getenv("LAYER_B_DELIVERABLE",
                               file.path(stage4_dir, "deliverable-annotato.rds"))
selection_csv <- Sys.getenv("LAYER_B_SELECTION", "")
if (!nzchar(selection_csv))
  stop("LAYER_B_SELECTION e' obbligatoria: il CSV di v13 porta 181 numeri ",
       "cablati nelle note e finirebbero stampati sulle schede del run nuovo.")
```

- [ ] **Passo 2: trasformare il ripiego in un errore**

Alle righe ~228-236 sostituire il `cli_alert_warning` sui cluster mancanti con `cli::cli_abort`,
e aggiungere prima della lettura:

```r
if (!file.exists(deliverable_path))
  cli::cli_abort(c("Deliverable annotato assente in {.path {deliverable_path}}.",
                   i = "Le misure devono venire dallo stesso run delle figure: ",
                   i = "non si ripiega su un file di audit di un altro run."))
```

- [ ] **Passo 3: verifica sui dati di v13 (non distruttiva)**

```
STAGE4_DIR=/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296 \
STAGE3_DIR=analysis/p4-output/20260728T151529Z-stage3-v13-364547a7 \
LAYER_B_SELECTION=analysis/layer-b-selection-v13-finale.csv \
timeout 280 Rscript -e 'x <- readLines("analysis/p5-stage4-layer-b-build-v13.R"); cat("righe:", length(x), "\n")'
```

Poi verificare che il run v13 **non** contenga `deliverable-annotato.rds` (non lo produceva) e
che quindi lo script ora si fermi con il messaggio giusto invece di leggere il file di audit.
Questo è il comportamento voluto: dopo il re-pool di v15 quel file esisterà.

- [ ] **Passo 4: commit**

```bash
git add analysis/p5-stage4-layer-b-build-v13.R
git commit -m "Il Layer B legge le misure dal run che illustra, o si ferma"
```

---

## Task 11: l'artefatto dice da quale Stadio 3 viene

**File:**
- Modifica: `R/stage4-build.R` (dove si costruisce `run_metadata`), `R/stage4-io.R:42-73`
- Test: `tests/testthat/test-stage4-build.R`

**Perché:** provato — nel `run_metadata.json` dello Stadio 4 l'unica occorrenza della stringa
«stage3» è la chiave `stage3_algorithm`. Il `run_id` dello Stadio 3 entra nell'hash e viene
buttato. Fra sei mesi, davanti a una cartella, non c'è modo di sapere quale clustering l'ha
prodotta. (Il `run_id` di v15 sarà `7f986159` e quindi diverso da v13 — ma resta non mappabile
a uno Stadio 3 senza ricalcolare l'hash a tentativi.)

- [ ] **Passo 1: scrivere il test che fallisce**

```r
test_that("run_metadata dello Stadio 4 registra la provenienza dello Stadio 3", {
  # Provato il 2026-08-02: l'unica occorrenza di "stage3" nel run_metadata era
  # la chiave `stage3_algorithm`. Il run_id dello Stadio 3 entrava nell'hash e
  # veniva buttato: l'artefatto non sapeva da dove veniva.
  md <- .build_stage4_run_metadata_fixture(stage3_run_id = "364547a7",
                                           stage3_dir = "/tmp/x-stage3-v15-364547a7")
  expect_identical(md$stage3$run_id, "364547a7")
  expect_identical(md$stage3$dir, "/tmp/x-stage3-v15-364547a7")
  expect_true(nzchar(md$stage3$clusters_sha256))
})
```

- [ ] **Passo 2: implementare**

In `R/stage4-build.R`, dove oggi `stage3_hash` viene calcolato e usato solo dentro
`.run_id_for_stage4`, aggiungere al `run_metadata` finale:

```r
  # L'identita' di uno Stadio 3 e' lo SHA256 del CONTENUTO di clusters.rds:
  # si calcola dall'oggetto prodotto, non c'e' nessuna stringa da ricordare di
  # aggiornare — che e' esattamente il modo in cui questo progetto ha gia' perso
  # otto ore con .NAME_RECOVERY_LOOKUP_SCHEMA_VERSION.
  run_metadata$stage3 <- list(
    run_id          = stage3_run_id %||% NA_character_,
    dir             = stage3_dir %||% NA_character_,
    clusters_sha256 = stage3_clusters_sha256 %||% NA_character_
  )
```

Lo sha256 si calcola nello script di re-pool con
`digest::digest(file = file.path(stage3_dir, "clusters.rds"), algo = "sha256")` e si passa a
`build_stage4_results()` come parametro nuovo `stage3_clusters_sha256 = NULL` (default `NULL`
per retrocompatibilità).

- [ ] **Passo 3: propagare nel deliverable**

Nello script di re-pool, subito prima di `write.csv(deliverable, ...)`, aggiungere:

```r
deliverable$stage3_clusters_sha256 <- result$run_metadata$stage3$clusters_sha256
```

così un join fra tabelle di run diversi si vede a occhio.

- [ ] **Passo 4: test verde + commit**

```bash
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="stage4", stop_on_failure=FALSE)' 2>&1 | tail -3
git add R/stage4-build.R R/stage4-io.R tests/testthat/test-stage4-build.R analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R
git commit -m "L'artefatto dello Stadio 4 dice da quale Stadio 3 viene"
```

---

## Task 12: le affermazioni false escono dai commenti e dai documenti

**File:**
- Modifica: `R/stage3-defrag-alias.R:59-96` e `:1-36`; `docs/superpowers/plans/2026-07-31-programma-fix-e-rerun.md:274,359`;
  `docs/findings/2026-07-31-defrag-regola-e-misura.md:216-222,234-236`;
  `inst/extdata/layer-b-showcase-content.yaml:3`

**Perché:** sette affermazioni scritte come vere e misurate false. Nessuna cambia l'output, tutte
finirebbero nei Methods o farebbero saltare la fase sbagliata.

- [ ] **Passo 1: correggere il file della regola**

Nel roxygen di `.CA_DEFRAG_ONTOLOGY_ORDER` (righe 59-96), sostituire «Un ordine UNICO la elimina
**per costruzione**» con:

```
#' Un ordine UNICO elimina lo split FRA CLASSI: lo stesso token da' sempre lo
#' stesso ID qualunque sia la classe. ⚠️ NON elimina lo split FRA RAMI, e questo
#' va detto: il ramo `anchor` (R/stage3-contrast-anchor.R:700-702) precede la
#' de-frammentazione e puo' produrre esso stesso un'entita' `STR:`, che questo
#' codice non vede mai. Misurato su v13: 415 cluster cgroup hanno un'entita'
#' `STR:` dal ramo anchor. E' il motivo per cui glioblastoma e' stato tolto
#' dalla lista il 2026-08-02.
```

In testa al file (righe 1-36), sostituire «il token si prova contro l'ontologia pretendendo un
match UNIVOCO su un alias PER ESTESO» con la descrizione di cosa il codice fa davvero:

```
# LA REGOLA, COM'E' OGGI. Due fusioni autorizzate una per una (`.CA_DEFRAG_ACCEPT`).
# L'univocita' sull'ontologia e' stata la MISURA che le ha giustificate, NON la
# regola che gira: `.ca_defrag_entity()` e' un lookup su due voci e non legge
# ne' `ontology_env` ne' `contrast_class`. L'indice degli alias qui sotto
# (`.ca_defrag_index` e compagnia) e la tabella `.CA_DEFRAG_REJECT` sono
# materiale d'AUDIT, non sul percorso di produzione: verificato il 2026-08-02
# con un test di mutazione (togliendo tutte e quattro le guardie l'esito non
# cambia su 14.089 token del corpus).
```

- [ ] **Passo 2: correggere il piano e il finding**

Nel piano `2026-07-31-programma-fix-e-rerun.md` righe 274 e 359, e nel finding
`2026-07-31-defrag-regola-e-misura.md` righe 216-222, sostituire «l'annotazione si ferma» con:

```
l'annotazione NON si fermava: il chiamante pre-filtrava gli orfani e la difesa
non scattava mai — provato, il gruppo `adenoma`, che ha un verdetto di
INCOERENZA, usciva marcato `coherent`. E anche dopo il fix del pre-filtro lo
`stop()` restava dentro un `tryCatch` che lo declassava a warning. Chiuso il
2026-08-02 portando il controllo in testa allo script (Task 7).
```

Nel finding righe 234-236, correggere: `PTSD` **non** ha un ID ontologico, è `STR:ptsd`.

- [ ] **Passo 3: correggere il numero infondato**

In `R/stage3-defrag-alias.R:288-291` sostituire «**~63 assegnano un'identita' SBAGLIATA**» e ogni
occorrenza di «130 su 923» con:

```
#' Delle 923 coppie prodotte dalla regola generale, 682 erano sostenute dal nome
#' primario e NON sono state lette; le **241** che stavano in piedi solo su un
#' alias sono state lette una per una con le etichette vere (`90-adjudica.txt`),
#' e **61** assegnavano un'identita' sbagliata. ⚠️ Il numero «130 su 923», che
#' compariva qui e nel messaggio di commit f0907fc, non e' sostenuto da nessun
#' artefatto: non compare in nessun log dell'audit e contraddice questa stessa
#' tabella, che ha 61 voci.
```

- [ ] **Passo 4: il file orfano**

In `inst/extdata/layer-b-showcase-content.yaml` riga 3, sostituire «Consumato da
inst/templates/layer-b-report.qmd via system.file(...)» con:

```yaml
# NON e' consumato da nessuno: inst/templates/layer-b-report.qmd non lo legge
# (verificato con grep il 2026-08-02). E' materiale curato della vetrina v10,
# tenuto come sorgente per le narrative; se serve, va agganciato esplicitamente.
```

- [ ] **Passo 5: commit**

```bash
git add R/stage3-defrag-alias.R docs/ inst/extdata/layer-b-showcase-content.yaml
git commit -m "Le sette affermazioni false escono dai commenti e dai documenti"
```

---

## Task 13: il cancello, provato sui file

**File:** nessuna modifica. Questo task produce evidenza.

- [ ] **Passo 1: la suite intera**

```
timeout 3000 Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", stop_on_failure=FALSE)' 2>&1 | tail -5
```

Atteso: **0 FAIL, 0 ERROR**. Annotare PASS e SKIP.

- [ ] **Passo 2: la suite della regola sui dizionari veri**

```
timeout 900 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-stage3-defrag-alias.R")' 2>&1 | tail -3
```

Atteso: 0 FAIL, e il numero di SKIP **inferiore** a quello misurato nel Task 3.

- [ ] **Passo 3: la misura d'impatto con la regola a due entità**

```
OUT_DIR=analysis/audit/2026-08-02-fix IMPATTO_OUT=impatto-membri-v8.rds \
  setsid nohup Rscript /tmp/claude-1000/-home-user-simulomicsr/*/scratchpad/10-impatto-v7.R \
  > analysis/audit/2026-08-02-fix/10-impatto-v8.log 2>&1 &
```

⚠️ Prima di lanciarla, aggiornare le asserzioni dello script: `glioblastoma` ora deve dare
`NA` anche a regola accesa. Attesi: **~97 membri** cambiati (86 tgfb + 11 il17), 0 partiti da
un'entità già risolta, 0 persi, 0 chiavi di controllo divergenti, destinazioni solo
`HGNC:11766` e `HGNC:5981`.

- [ ] **Passo 4: lo smoke del re-cluster**

```
timeout 3000 Rscript analysis/p4-fase-f12-stage3-v15-defrag.R 2>&1 | tail -40
```

Atteso: PASS, con `cluster con entita' dalla de-frammentazione: N` e N > 0.

- [ ] **Passo 5: scrivere l'atteso del re-run, PRIMA di lanciarlo**

Creare `analysis/audit/2026-08-02-fix/00-atteso-v15.md` con i numeri da confrontare dopo:

```markdown
# Che cosa deve produrre v15 — scritto PRIMA del lancio

- run_id dello Stadio 3: **7f986159** (non 364547a7: `contrast_defrag` entra nell'hash)
- TGFB1 `HGNC:11766`: k censito **65 -> 78**; poolato atteso **49 -> 59**
- IL17A `HGNC:5981`: k censito **8 -> 12**; poolato atteso **7 -> 8**
- glioblastoma: **invariato** (fusione tolta il 2026-08-02)
- cluster con `contrast_entity_source == "defrag"`: **> 0**
- deliverable: **191 -> 190 righe** (`STR:tgfb`, oggi riga a se' con k_effective 9,
  confluisce in TGFB1). Con la dedup corretta (Task 5) il conteggio sale invece a
  circa **215-225**: i due effetti vanno riportati separati, altrimenti «191 -> 190»
  si legge come regressione.
- verdetti di coerenza: **6 incoerenti**, come in v13. Se sono 0, il file dei verdetti
  non e' stato letto.
```

- [ ] **Passo 6: commit finale**

```bash
git add analysis/audit/2026-08-02-fix/
git commit -m "Il cancello provato sui file, e l'atteso di v15 scritto prima del lancio"
```

---

## Auto-revisione del piano

**Copertura dei difetti confermati:** dedup → Task 5 · verdetti «coherent» → Task 6 · verdetti
path/stop → Task 7 · Layer B join → Task 10 · Layer B `notes` → Task 10 (passo 1, selezione
obbligatoria) · provenienza → Task 11 · etichette di versione → Task 9 · smoke cieco → Task 8 ·
suite rossa → Task 2 · test che saltano → Task 3 · guardie inerti → Task 3 · `record_id` →
Task 4 · affermazioni false → Task 12 · glioblastoma → Task 1.

**Difetti NON coperti, per scelta dichiarata:** (a) il dump `impatto-membri-v5.rds` resta un
sovrainsieme cieco al ramo `anchor` — si corregge l'intestazione nel Task 12, non si rifà la
misura; (b) la cache dei conteggi dello Stadio 4 non porta il path dell'H5: non attivo finché
l'H5 non cambia, va fatto dopo il re-pool; (c) il codice morto dell'indice degli alias resta,
dichiarato nel Task 12 — toccarlo a ridosso del lancio è il rischio che non vale la pena.

**Coerenza dei nomi:** `.dedup_rem_group_by_entity` (Task 5) restituisce l'attributo `scartati`,
consumato dal Task 9 nello script; `.lookup_cmp` (Task 4) mantiene la firma
`(study, comparison_id)`; `stage3_clusters_sha256` (Task 11) è lo stesso nome nel parametro,
nel `run_metadata` e nella colonna del deliverable.
