# Ridisegno del report Layer B — piano di implementazione

> **Per chi esegue:** SOTTO-SKILL RICHIESTA: usare `superpowers:subagent-driven-development`
> (consigliata) o `superpowers:executing-plans` per eseguire il piano task per task.
> Gli step usano le caselle (`- [ ]`) per il tracciamento.

**Obiettivo:** rifare il report Layer B in modo che sia la vetrina del progetto — leggibile
in trenta secondi e verificabile riga per riga — senza toccare nulla a monte delle figure.

**Architettura:** si resta in R/Quarto. Si introduce **un tema grafico unico** che tutte le
figure usano (oggi ognuna ha il suo), si rifanno forest e volcano, si ripulisce la heatmap,
si riscrive la scheda, si corregge la gerarchia del template e si aggiungono apertura,
quadro d'insieme e appendice. Il documento resta statico e riproducibile con un comando.

**Stack:** R, ggplot2, ComplexHeatmap, patchwork, Quarto, testthat.

**Spec:** `docs/superpowers/specs/2026-08-05-layer-b-redesign-design.md`

## Vincoli globali

- **Italiano** in commenti, docstring, messaggi di errore e commit. ASCII nei file `.Rd`
  generati da roxygen.
- **TDD bite-sized**: test → fallimento verificato → implementazione minima → verde → commit.
- **Nessun taglio silenzioso**: ogni filtro applicato a una figura va **dichiarato nella
  didascalia**. È una regola già in vigore nel progetto (`.coverage_filter_note()`).
- **Non si tocca nulla a monte**: né pooling, né deliverable, né verdetti. Solo presentazione.
- **Funzioni interne** con `@keywords internal`; solo i veri entry point sono `@export`.
- **Branch** `review-scientific-consistency-2026-06-10`, master invariato, **no push**.
- **Dati veri per la verifica finale**:
  - Layer A: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7`
  - Stadio 3: `analysis/p4-output/20260803T164558Z-stage3-v15-7f986159`
  - selezione: `analysis/layer-b-selection-v15.csv`
- **Comandi R**: `Rscript` **senza** `--vanilla` (renv del progetto).

## Struttura dei file

| file | responsabilità |
|---|---|
| `R/layer-b-theme.R` (**nuovo**) | tema ggplot2 unico, palette, funzione per il titolo delle figure |
| `R/layer-b-plot-forest.R` | riscritto: filtro sul k, pannello dei bersagli, gene in dettaglio |
| `R/layer-b-plot-volcano.R` | etichette filtrate per k, compressione dichiarata dell'asse |
| `R/layer-b-plot-heatmap.R` | via la legenda degli studi e la fascia multicolore |
| `R/layer-b-summary-card.R` | riscritta: cinque domande, provenienza in fondo |
| `R/layer-b-config.R` | tre parametri nuovi |
| `R/layer-b-build.R` | MA ed eterogeneità fuori dal bundle |
| `inst/templates/layer-b-report.qmd` | gerarchia dei titoli, apertura, quadro d'insieme, appendice |
| `R/layer-b-narrative.R` (**nuovo**) | genera la bozza di narrativa dai numeri del deliverable |

---

### Task 1: Tema grafico unico

**File:**
- Crea: `R/layer-b-theme.R`
- Test: `tests/testthat/test-layer-b-theme.R`

**Interfacce:**
- Consuma: niente.
- Produce: `.lb_theme()` → oggetto `theme` di ggplot2; `.lb_titolo(entita, k, extra = NULL)`
  → `character(1)`; `.LB_COLORI` → lista con `su`, `giu`, `neutro`, `evidenza`.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that(".lb_titolo mette entita e numero di studi nel titolo", {
  expect_equal(simulomicsr:::.lb_titolo("TGF-beta1", 59L),
               "TGF-beta1 · 59 studi")
  expect_equal(simulomicsr:::.lb_titolo("TGF-beta1", 59L, "geni piu' forti"),
               "TGF-beta1 · 59 studi · geni piu' forti")
  expect_equal(simulomicsr:::.lb_titolo("X", 1L), "X · 1 studio")
})

test_that(".lb_theme e' un tema ggplot2 e .LB_COLORI ha le quattro tinte", {
  expect_s3_class(simulomicsr:::.lb_theme(), "theme")
  expect_setequal(names(simulomicsr:::.LB_COLORI),
                  c("su", "giu", "neutro", "evidenza"))
})
```

- [ ] **Step 2: eseguire il test e vederlo fallire**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-theme.R")'`
Atteso: FAIL, `.lb_titolo` non esiste.

- [ ] **Step 3: implementare**

```r
#' Tinte del Layer B
#'
#' Una sola definizione per tutte le figure: oggi ogni funzione sceglie i propri
#' colori, ed e' uno dei motivi per cui il report non sembra un solo oggetto.
#' @keywords internal
.LB_COLORI <- list(
  su       = "#B2182B",  # effetto positivo
  giu      = "#2166AC",  # effetto negativo
  neutro   = "#BFBFBF",  # non significativo
  evidenza = "#1A1A1A"   # stime poolate, testo forte
)

#' Tema comune delle figure del Layer B
#' @keywords internal
.lb_theme <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = base_size * 1.15),
      plot.subtitle = ggplot2::element_text(colour = "grey35"),
      plot.caption = ggplot2::element_text(colour = "grey35", hjust = 0),
      axis.title = ggplot2::element_text(colour = "grey25"),
      legend.position = "bottom"
    )
}

#' Titolo di una figura: quale gruppo, su quanti studi
#'
#' Nessuna figura del report attuale dice a quale gruppo appartiene: aperta da
#' sola non e' interpretabile.
#' @keywords internal
.lb_titolo <- function(entita, k, extra = NULL) {
  studi <- if (isTRUE(k == 1L)) "1 studio" else sprintf("%d studi", as.integer(k))
  parti <- c(as.character(entita), studi, extra)
  paste(parti[nzchar(parti) & !is.na(parti)], collapse = " · ")
}
```

- [ ] **Step 4: eseguire il test e vederlo passare**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-theme.R")'`
Atteso: PASS.

- [ ] **Step 5: commit**

```bash
git add R/layer-b-theme.R tests/testthat/test-layer-b-theme.R
git commit -m "Un tema grafico solo per tutte le figure del Layer B"
```

---

### Task 2: il forest smette di mostrare geni misurati su due studi

**File:**
- Modifica: `R/layer-b-plot-forest.R:41-43`
- Test: `tests/testthat/test-layer-b-forest-coverage.R`

**Interfacce:**
- Consuma: `.filter_genes_by_coverage(sig, min_k_frac, k_max)` e `.coverage_filter_note(filtro)`
  da `R/layer-b-utils.R` (già esistenti e testate), `config$top_genes_min_k_frac`.
- Produce: nessuna firma nuova; `.build_forest()` cambia comportamento e la sua
  `caption` contiene la nota del filtro.

**Perché:** oggi il forest ordina per `abs(logFC_pool)` senza guardare `k_effective`.
Su TGF-β1 (59 studi) sceglie CD300C e PROK2, misurati su **5 e 2 studi**. Il filtro esiste
già ed è usato da tabella e heatmap: il forest non lo chiama.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that(".build_forest scarta i geni misurati in pochi studi", {
  skip_if_not_installed("metafor")
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 20, cluster_id = "cl_cov")
  cp$method <- "rem_group"
  cp$k_effective <- 10L
  # due geni con effetto enorme ma misurati in 2 studi soli: sono la trappola
  cp$k_effective[1:2] <- 2L
  cp$logFC_pool[1:2] <- c(9, -9)
  cp$FDR_BH_within_cluster[1:2] <- 1e-30
  ps <- make_fake_per_study_de(cluster_id = "cl_cov", n_genes = 40, n_studies = 10)

  out_dir <- tempfile("forest_cov_"); dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_forest(ps, cp, "rem_group", out_dir,
                                     layer_b_default_config())
  expect_false(any(res$genes_mostrati %in% cp$gene_id[1:2]))
  expect_match(res$caption, "meta")   # la nota del filtro e' dichiarata
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-forest-coverage.R")'`
Atteso: FAIL — `res$genes_mostrati` è NULL e i due geni trappola sono nel plot.

- [ ] **Step 3: implementare**

In `R/layer-b-plot-forest.R`, sostituire le righe 41-43:

```r
  # Il filtro di copertura e' lo STESSO usato da tabella e heatmap dal
  # 2026-07-31: il forest era rimasto fuori, e per questo mostrava geni
  # misurati in due studi su 59 (CD300C, PROK2 su TGF-beta1, misurato il
  # 2026-08-05). Il k del cluster va passato esplicitamente: dedurlo dai soli
  # geni significativi abbasserebbe la soglia proprio dove serve di piu'.
  k_cluster <- .cluster_k_effective(cp)
  filtro <- .filter_genes_by_coverage(cp[cp$is_sig, , drop = FALSE],
                                      config$top_genes_min_k_frac,
                                      k_max = k_cluster)
  top_genes <- filtro$genes
  top_genes <- top_genes[order(abs(top_genes$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top_genes <- head(top_genes, top_n)
```

e, nel valore di ritorno, aggiungere i geni mostrati e la nota:

```r
    genes_mostrati = top_genes$gene_id,
    caption = paste0(caption_base, .coverage_filter_note(filtro))
```

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-forest-coverage.R")'`
Atteso: PASS.

- [ ] **Step 5: non-regressione sui test forest esistenti**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-forest.R")'`
Atteso: 0 FAIL. Se un test esistente si aspettava geni ora filtrati, **aggiornare
l'attesa e spiegare nel commit perché la vecchia era sbagliata** — non allentare il filtro.

- [ ] **Step 6: commit**

```bash
git add R/layer-b-plot-forest.R tests/testthat/test-layer-b-forest-coverage.R
git commit -m "Il forest applica il filtro di copertura come tabella e heatmap"
```

---

### Task 3: forest a due pannelli

**File:**
- Modifica: `R/layer-b-plot-forest.R`
- Test: `tests/testthat/test-layer-b-forest-pannelli.R`

**Interfacce:**
- Consuma: `.lb_theme()`, `.lb_titolo()`, `.LB_COLORI` (Task 1); `top_genes` filtrati (Task 2).
- Produce: `.forest_gene_rappresentativo(top_genes, k_cluster)` → `character(1)` con il
  `gene_id` scelto, o `NA_character_` se nessun gene ha copertura piena.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that(".forest_gene_rappresentativo prende l'effetto piu' grande fra i k pieni", {
  tg <- data.frame(
    gene_id = c("G1", "G2", "G3"),
    logFC_pool = c(1.0, -4.0, 3.0),
    k_effective = c(10L, 4L, 10L),   # G2 ha l'effetto piu' grande ma k basso
    stringsAsFactors = FALSE
  )
  expect_equal(simulomicsr:::.forest_gene_rappresentativo(tg, k_cluster = 10L), "G3")
})

test_that(".forest_gene_rappresentativo restituisce NA se nessun gene ha k pieno", {
  tg <- data.frame(gene_id = "G1", logFC_pool = 2, k_effective = 3L,
                   stringsAsFactors = FALSE)
  expect_true(is.na(simulomicsr:::.forest_gene_rappresentativo(tg, k_cluster = 10L)))
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-forest-pannelli.R")'`
Atteso: FAIL, funzione inesistente.

- [ ] **Step 3: implementare la scelta del gene**

```r
#' Il gene da mostrare studio per studio nel pannello inferiore del forest
#'
#' Regola DICHIARATA (va in didascalia): fra i geni misurati in TUTTI gli studi
#' del cluster, quello con l'effetto assoluto maggiore. Se nessun gene ha
#' copertura piena si restituisce NA e il pannello inferiore si omette, invece di
#' ripiegare in silenzio su un gene a bassa copertura -- che e' il difetto che
#' questo ridisegno corregge.
#' @keywords internal
.forest_gene_rappresentativo <- function(top_genes, k_cluster) {
  if (nrow(top_genes) == 0L || is.null(top_genes$k_effective)) return(NA_character_)
  pieni <- top_genes[!is.na(top_genes$k_effective) &
                       top_genes$k_effective >= as.integer(k_cluster), , drop = FALSE]
  if (nrow(pieni) == 0L) return(NA_character_)
  pieni$gene_id[which.max(abs(pieni$logFC_pool))]
}
```

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-forest-pannelli.R")'`
Atteso: PASS.

- [ ] **Step 5: comporre i due pannelli**

Sostituire il ramo `rem`/`rem_group` di `.build_forest()` con una figura `patchwork`:
pannello superiore = `top_genes` (fino a `config$top_n_forest`) con stima e intervallo
`logFC_pool ± 1.96 * SE_pool`, ordinati per effetto, colorati con `.LB_COLORI$su`/`$giu`;
pannello inferiore = il gene di `.forest_gene_rappresentativo()` con una riga per studio da
`per_study_de_subset` e la stima poolata in fondo con un rombo. Titolo da `.lb_titolo()`.
Se il gene rappresentativo è `NA`, si produce il solo pannello superiore e la didascalia lo
dichiara.

- [ ] **Step 6: verificare che il PNG esista e la suite forest sia verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="layer-b-forest")'`
Atteso: 0 FAIL.

- [ ] **Step 7: commit**

```bash
git add R/layer-b-plot-forest.R tests/testthat/test-layer-b-forest-pannelli.R
git commit -m "Forest a due pannelli: i bersagli in alto, un gene studio per studio sotto"
```

---

### Task 4: volcano leggibile

**File:**
- Modifica: `R/layer-b-plot-volcano.R`
- Test: `tests/testthat/test-layer-b-volcano-asse.R`

**Interfacce:**
- Consuma: `.filter_genes_by_coverage()`, `.lb_theme()`, `.lb_titolo()`, `.LB_COLORI`.
- Produce: `.volcano_soglia_asse(y, quota = 0.6)` → `numeric(1)`: il valore oltre il quale
  l'asse va compresso, o `Inf` se nessun punto domina.

**Perché:** su TGF-β1 un solo punto a `-log10 p ≈ 310` comprime il 99% dei geni in una
striscia sul fondo, e le etichette pescano geni misurati in pochi studi.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that(".volcano_soglia_asse scatta solo quando un punto domina davvero", {
  y_normale <- c(1, 2, 3, 4, 5)
  expect_true(is.infinite(simulomicsr:::.volcano_soglia_asse(y_normale)))

  y_dominato <- c(rep(5, 99), 310)
  s <- simulomicsr:::.volcano_soglia_asse(y_dominato)
  expect_true(is.finite(s))
  expect_lt(s, 310)
  expect_gt(s, 5)
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-volcano-asse.R")'`
Atteso: FAIL, funzione inesistente.

- [ ] **Step 3: implementare**

```r
#' Soglia oltre la quale l'asse del volcano va compresso
#'
#' Un solo gene a -log10 p = 310 schiaccia tutti gli altri in una striscia
#' illeggibile (misurato su TGF-beta1 il 2026-08-05). La compressione e' una
#' manipolazione visiva e va DICHIARATA in didascalia ogni volta che scatta:
#' un taglio silenzioso e' esattamente cio' che questo progetto ha deciso di non
#' fare mai.
#'
#' @param y vettore dei valori sull'asse (-log10 p).
#' @param quota se il 99-esimo percentile copre meno di questa frazione del
#'   massimo, l'asse e' dominato da pochi punti e va compresso.
#' @return la soglia, oppure Inf se non serve comprimere.
#' @keywords internal
.volcano_soglia_asse <- function(y, quota = 0.6) {
  y <- y[is.finite(y)]
  if (length(y) < 10L) return(Inf)
  p99 <- stats::quantile(y, 0.99, names = FALSE)
  if (p99 >= quota * max(y)) return(Inf)
  as.numeric(p99)
}
```

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-volcano-asse.R")'`
Atteso: PASS.

- [ ] **Step 5: usarla nella figura, con le etichette filtrate**

In `.build_volcano()`: applicare `.filter_genes_by_coverage()` **alla scelta delle
etichette** (non ai punti: tutti i geni restano nel grafico); quando
`.volcano_soglia_asse()` è finito, comprimere l'asse e aggiungere alla didascalia la
frase «asse verticale compresso sopra <soglia>: N geni oltre la soglia»; titolo da
`.lb_titolo()`.

- [ ] **Step 6: suite volcano verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="layer-b-volcano")'`
Atteso: 0 FAIL.

- [ ] **Step 7: commit**

```bash
git add R/layer-b-plot-volcano.R tests/testthat/test-layer-b-volcano-asse.R
git commit -m "Volcano: asse compresso in modo dichiarato, etichette solo sui geni ben misurati"
```

---

### Task 5: heatmap senza la legenda dei codici GSE

**File:**
- Modifica: `R/layer-b-plot-heatmap.R:45` e l'annotazione delle colonne
- Test: `tests/testthat/test-layer-b-heatmap-legenda.R`

**Interfacce:**
- Consuma: `config$heatmap_mostra_studi` (nuovo, Task 8).
- Produce: nessuna firma nuova.

**Perché:** su TGF-β1 un terzo della figura è una legenda con 47 codici GSE illeggibili, e
la fascia "Study" è una banda di 47 colori indistinguibili. La biologia è già corretta.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that("la heatmap non annota gli studi quando heatmap_mostra_studi = FALSE", {
  cfg <- layer_b_default_config()
  expect_false(cfg$heatmap_mostra_studi)
  ann <- simulomicsr:::.heatmap_annotazione_colonne(
    data.frame(study_id = paste0("GSE", 1:47),
               treatment = rep(c("treated", "control"), length.out = 47),
               stringsAsFactors = FALSE),
    mostra_studi = FALSE)
  expect_false("Study" %in% names(ann))
  expect_true("Treatment" %in% names(ann))
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-heatmap-legenda.R")'`
Atteso: FAIL.

- [ ] **Step 3: estrarre la costruzione dell'annotazione in `.heatmap_annotazione_colonne()`**

che restituisce una lista con `Treatment` sempre e `Study` solo se `mostra_studi = TRUE`,
e usarla in `.build_heatmap()`.

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="layer-b-heatmap")'`
Atteso: 0 FAIL.

- [ ] **Step 5: commit**

```bash
git add R/layer-b-plot-heatmap.R tests/testthat/test-layer-b-heatmap-legenda.R
git commit -m "La heatmap perde la legenda dei 47 codici GSE e guadagna un terzo di spazio"
```

---

### Task 6: la scheda risponde a cinque domande

**File:**
- Riscrive: `R/layer-b-summary-card.R`
- Test: `tests/testthat/test-layer-b-summary-card-v2.R`

**Interfacce:**
- Consuma: la riga del deliverable annotato (colonne `k_effective`, `k_kish`, `I2_med`,
  `n_sig`, `quota_top1`, `studio_dominante`, `materiale_misto`, `coherence_verdict`).
- Produce: `.summary_card_v2(riga, bersagli_trovati, confronti_imperfetti)` → `character(1)`
  in markdown.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that(".summary_card_v2 risponde alle cinque domande e nasconde gli id interni", {
  riga <- data.frame(
    cluster_id = "cgroup_L5_2e16719f", contrast_entity = "HGNC:11766",
    contrast_entity_label = "TGF-beta1", k_effective = 59L, k_kish = 54.5,
    I2_med = 93.5, n_sig = 7909L, quota_top1 = 0.021,
    studio_dominante = "GSE155832", materiale_misto = TRUE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(
    riga,
    bersagli_trovati = c("SMAD7 +1,41", "SERPINE1 +2,43"),
    confronti_imperfetti = list(n = 29L, tot = 145L, peso = 0.067))

  expect_match(md, "59")            # su quanti studi
  expect_match(md, "54")            # quanto pesano davvero
  expect_match(md, "SMAD7")         # cosa si trova
  expect_match(md, "6,7|6\\.7")     # quanto e' sporco
  # gli identificativi interni non stanno nel corpo, ma nel blocco provenienza
  corpo <- sub("(?s)PROVENIENZA.*", "", md, perl = TRUE)
  expect_false(grepl("cgroup_L5_", corpo))
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-summary-card-v2.R")'`
Atteso: FAIL.

- [ ] **Step 3: implementare** `.summary_card_v2()` con le cinque righe (cosa è stato
confrontato · su quanti studi e quanto pesano · quanto concordano · cosa si trova ·
quanto è sporco) e un blocco finale `PROVENIENZA` con `cluster_id`, `run_id` e sha256.
**Rimuovere** `safety_min`, `direction_applied distribution`,
`n_baseline_studies_augmented`, il blocco `User notes` e `Top gene` scelto per solo FDR.

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="layer-b-summary")'`
Atteso: 0 FAIL.

- [ ] **Step 5: commit**

```bash
git add R/layer-b-summary-card.R tests/testthat/test-layer-b-summary-card-v2.R
git commit -m "La scheda risponde a cinque domande invece di elencare campi tecnici"
```

---

### Task 7: narrative in bozza, ancorate ai numeri

**File:**
- Crea: `R/layer-b-narrative.R`
- Test: `tests/testthat/test-layer-b-narrative.R`

**Interfacce:**
- Consuma: la riga del deliverable, i bersagli attesi per entità, il conteggio dei
  confronti imperfetti.
- Produce: `.narrativa_bozza(riga, bersagli_attesi, trovati, imperfetti)` → `character(1)`
  markdown con tre paragrafi e l'intestazione `> BOZZA — da rivedere`.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that(".narrativa_bozza e' marcata come bozza e cita solo numeri passati", {
  riga <- data.frame(contrast_entity_label = "TGF-beta1", k_effective = 59L,
                     k_kish = 54.5, I2_med = 93.5, n_sig = 7909L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(
    riga,
    bersagli_attesi = c("SERPINE1", "SMAD7"),
    trovati = data.frame(gene = c("SERPINE1", "SMAD7"), logFC = c(2.43, 1.41),
                         stringsAsFactors = FALSE),
    imperfetti = list(n = 29L, tot = 145L, peso = 0.067))
  expect_match(txt, "BOZZA")
  expect_match(txt, "SERPINE1")
  expect_match(txt, "2,43|2\\.43")
  expect_match(txt, "29")
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-narrative.R")'`
Atteso: FAIL.

- [ ] **Step 3: implementare** i tre paragrafi (contesto · cosa si vede · limiti di questo
gruppo). **Vincolo:** la funzione compone frasi solo dai valori che riceve; non inventa
affermazioni biologiche. Le attese di letteratura arrivano da `bersagli_attesi`, che è un
argomento, non una tabella interna.

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-narrative.R")'`
Atteso: PASS.

- [ ] **Step 5: commit**

```bash
git add R/layer-b-narrative.R tests/testthat/test-layer-b-narrative.R
git commit -m "Bozze di narrativa costruite dai numeri del deliverable, marcate come bozza"
```

---

### Task 7bis: collegare scheda e narrativa al build (AGGIUNTO 2026-08-05 in corso d'opera)

**Perché esiste:** la revisione del Task 6 ha trovato che `.summary_card_v2()` era **codice
irraggiungibile** — `R/layer-b-build.R` continuava a chiamare la vecchia scheda. Stessa sorte
toccherebbe alla narrativa del Task 7. Nessuno dei dieci task originali si intestava il
collegamento: è un buco del piano, non dell'esecuzione. Senza questo task il piano può
dichiararsi completo lasciando **insoddisfatti i criteri 3 e 6** della spec §9.

Scheda e narrativa hanno bisogno degli **stessi due dati calcolati**, ed è il motivo per cui
stanno in un task solo invece di due: costruire due volte la stessa pipeline sarebbe il modo
per farle divergere.

**File:**
- Modifica: `R/layer-b-build.R`
- Modifica: `R/layer-b-write.R` (se la scrittura della scheda passa di lì)
- Test: `tests/testthat/test-layer-b-collegamento-scheda.R`

**Interfacce:**
- Consuma: `.summary_card_v2(riga, bersagli_trovati, confronti_imperfetti)` (Task 6),
  `.narrativa_bozza(riga, bersagli_attesi, trovati, imperfetti)` (Task 7),
  il deliverable annotato `deliverable-annotato.rds` nella directory dello Stadio 4.
- Produce: `.bersagli_trovati(cp, bersagli_attesi)` → data.frame con `gene`, `logFC`, `FDR`
  per i soli bersagli attesi presenti fra i geni misurati.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that(".bersagli_trovati riporta solo i bersagli presenti, coi loro valori", {
  cp <- data.frame(
    gene_symbol = c("SMAD7", "SERPINE1", "ACTB"),
    logFC_pool = c(1.41, 2.43, 0.02),
    FDR_BH_within_cluster = c(1e-22, 1e-19, 0.9),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.bersagli_trovati(cp, c("SMAD7", "SERPINE1", "ASSENTE"))
  expect_equal(nrow(out), 2L)
  expect_setequal(out$gene, c("SMAD7", "SERPINE1"))
  expect_equal(out$logFC[out$gene == "SMAD7"], 1.41)
})

test_that("il bundle usa la scheda nuova: niente cgroup_L5_ nel corpo", {
  # il corpo e' tutto cio' che precede il blocco PROVENIENZA
  md <- readLines(file.path(bundle_dir, "summary_card.md"))
  corpo <- md[seq_len(which(grepl("PROVENIENZA", md))[1] - 1L)]
  expect_false(any(grepl("cgroup_L5_", corpo)))
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-collegamento-scheda.R")'`
Atteso: FAIL, `.bersagli_trovati` non esiste.

- [ ] **Step 3: implementare `.bersagli_trovati()`** e collegare in `R/layer-b-build.R`:
carica il deliverable annotato dalla directory dello Stadio 4, prendi la riga del cluster in
lavorazione, calcola i bersagli trovati e i confronti imperfetti, e passa tutto a
`.summary_card_v2()` e `.narrativa_bozza()` al posto delle chiamate vecchie.

⚠️ **DUE PUNTI DI COLLEGAMENTO, NON UNO.** Segnalato dall'implementatore del Task 7, ed è la
stessa trappola già scattata sulla scheda:

1. `.build_summary_card()` → sostituita da `.summary_card_v2()`;
2. **`.write_narrative_template()`** (in `R/layer-b-summary-card.R`) → è la funzione che oggi
   scrive gli stub `TODO` nel file `narrative.qmd` del bundle. Se non viene collegata a
   `.narrativa_bozza()`, la narrativa resta codice irraggiungibile esattamente come lo era la
   scheda, **e il criterio 6 della spec §9 resta insoddisfatto anche dopo questo task**.

Verificare esplicitamente, a collegamento fatto, che il `narrative.qmd` scritto su disco
contenga la bozza e non più gli stub.

**I bersagli attesi arrivano dal chiamante**, non da una tabella interna al pacchetto: sono
attese di letteratura, e vanno dichiarate come tali. Se per un cluster non ce ne sono, la
scheda lo dice invece di tacere.

**Se il deliverable annotato non è disponibile**, il build non deve fallire: ripiega sulla
scheda vecchia e **lo dichiara** nel bundle. Un ripiego silenzioso qui vanificherebbe la
verifica del Task 10, che troverebbe la scheda vecchia senza sapere perché.

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="layer-b-collegamento|layer-b-build")'`
Atteso: 0 FAIL.

- [ ] **Step 5: commit**

```bash
git add R/layer-b-build.R tests/testthat/test-layer-b-collegamento-scheda.R
git commit -m "La scheda nuova e la narrativa arrivano davvero nel bundle"
```

---

### Task 8: configurazione e figure escluse

**File:**
- Modifica: `R/layer-b-config.R:45`, `R/layer-b-build.R`
- Test: `tests/testthat/test-layer-b-config.R` (esistente, da estendere)

**Interfacce:**
- Produce: `layer_b_default_config()` con tre chiavi nuove: `heatmap_mostra_studi = FALSE`,
  `figure_escluse = c("ma", "heterogeneity")`, `volcano_quota_asse = 0.6`.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that("la config porta le tre chiavi del ridisegno", {
  cfg <- layer_b_default_config()
  expect_false(cfg$heatmap_mostra_studi)
  expect_setequal(cfg$figure_escluse, c("ma", "heterogeneity"))
  expect_equal(cfg$volcano_quota_asse, 0.6)
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-config.R")'`
Atteso: FAIL.

- [ ] **Step 3: aggiungere le tre chiavi** alla config e, in `.build_cluster_bundle()`,
saltare le figure elencate in `figure_escluse`. **Il codice di `.build_ma()` e
`.build_heterogeneity_panel()` non si rimuove**: è selezione, non cancellazione — come già
deciso per il ramo `mega` in ADR-0026.

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_dir("tests/testthat", filter="layer-b")'`
Atteso: 0 FAIL.

- [ ] **Step 5: commit**

```bash
git add R/layer-b-config.R R/layer-b-build.R tests/testthat/test-layer-b-config.R
git commit -m "Config del ridisegno: niente legenda studi, MA ed eterogeneita fuori dal bundle"
```

---

### Task 9: il template — apertura, quadro d'insieme, gerarchia, appendice

**File:**
- Modifica: `inst/templates/layer-b-report.qmd`
- Test: `tests/testthat/test-layer-b-report-struttura.R`

**Interfacce:**
- Consuma: i bundle prodotti dai task precedenti.
- Produce: un HTML la cui struttura è verificabile.

- [ ] **Step 1: scrivere il test che fallisce**

```r
test_that("il template non stampa gli identificativi interni nelle intestazioni", {
  qmd <- readLines(system.file("templates", "layer-b-report.qmd",
                               package = "simulomicsr"))
  intestazioni <- grep("^#{1,3} ", qmd, value = TRUE)
  expect_false(any(grepl("cluster_id|cgroup_L5_", intestazioni)))
})

test_that("il template ha l'apertura, il quadro d'insieme e l'appendice", {
  qmd <- paste(readLines(system.file("templates", "layer-b-report.qmd",
                                     package = "simulomicsr")), collapse = "\n")
  expect_match(qmd, "Apertura|apertura")
  expect_match(qmd, "corpus|Il corpus")
  expect_match(qmd, "Appendice|appendice")
})
```

- [ ] **Step 2: eseguire e vedere il fallimento**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-report-struttura.R")'`
Atteso: FAIL.

- [ ] **Step 3: riscrivere il template**: un solo `#` per il documento, `##` per le sezioni
(Apertura, Il corpus, I case study, Appendice), `###` per ogni case study **con la sola
etichetta leggibile** nel titolo. Ogni case study: scheda → narrativa → figure → numeri.
L'appendice riporta metodo e tabella dei confronti imperfetti e rimanda a
`docs/findings/2026-08-05-confronti-imperfetti.md`.

- [ ] **Step 4: eseguire e vedere il verde**

Comando: `Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-layer-b-report-struttura.R")'`
Atteso: PASS.

- [ ] **Step 5: commit**

```bash
git add inst/templates/layer-b-report.qmd tests/testthat/test-layer-b-report-struttura.R
git commit -m "Il template: apertura, quadro d'insieme, gerarchia sana, appendice"
```

---

### Task 10: build sui dati veri e verifica dei sette criteri

**File:**
- Crea: `analysis/audit/2026-08-05-layer-b-v2/10-verifica-criteri.R`

**Interfacce:**
- Consuma: il bundle prodotto dal build.
- Produce: un rapporto con i sette criteri della spec §9, ciascuno PASS/FAIL.

- [ ] **Step 1: suite intera verde prima del build**

Comando: `Rscript -e 'devtools::test()'`
Atteso: 0 FAIL. **Non lanciare il build mentre la suite gira.**

- [ ] **Step 2: build sui dati veri**

```bash
STAGE4_DIR=/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7 \
STAGE3_DIR=analysis/p4-output/20260803T164558Z-stage3-v15-7f986159 \
LAYER_B_SELECTION=analysis/layer-b-selection-v15.csv \
setsid nohup Rscript analysis/p5-stage4-layer-b-build-v13.R \
  > analysis/audit/2026-08-05-layer-b-v2/20-build.log 2>&1 < /dev/null &
```

Attendere sul **PID** (mai su un pattern di testo: un ciclo che cerca i processi per nome
trova se stesso e non esce mai).

- [ ] **Step 3: verificare i sette criteri SULL'ARTEFATTO**

Lo script misura, sui PNG e sull'HTML prodotti:

1. i geni del forest di TGF-β1 hanno tutti `k_effective >= 30`;
2. nel volcano nessun punto singolo comprime gli altri, e ogni etichetta ha k ≥ metà;
3. `grep -c "cgroup_L5_"` sulle intestazioni dell'HTML **= 0**;
4. ogni figura ha il titolo col gruppo e il numero di studi;
5. la heatmap non contiene i codici GSE in legenda;
6. ogni case study ha la narrativa (non uno stub) e la riga dei confronti imperfetti;
7. la prima figura del documento è la prova agonista/antagonista.

- [ ] **Step 4: guardare le figure**

Aprire almeno forest, volcano e heatmap di TGF-β1 e giudicarle a occhio. **Un criterio
automatico che passa non garantisce che la figura sia bella**: questa è la vetrina, e il
giudizio finale è visivo.

- [ ] **Step 5: commit del rapporto**

```bash
git add analysis/audit/2026-08-05-layer-b-v2/
git commit -m "Il report ridisegnato, e i sette criteri misurati sull'artefatto"
```

---

## Auto-revisione del piano

**Copertura della spec:** §3 struttura → Task 9 · §4.1 forest → Task 2 e 3 · §4.2 volcano →
Task 4 · §4.3 heatmap → Task 5 · §4.5 figure eliminate → Task 8 · §5 scheda → Task 6 ·
§6 narrative → Task 7 · §9 criteri → Task 10 · §9bis tema comune → Task 1. Nessuna sezione
scoperta.

**Segnaposto:** nessun TBD o TODO; ogni step di codice ha il codice.

**Coerenza dei nomi:** `.lb_theme()`, `.lb_titolo()`, `.LB_COLORI` (Task 1) sono usati con
gli stessi nomi nei Task 3 e 4; `.filter_genes_by_coverage()` e `.coverage_filter_note()`
sono le funzioni esistenti in `R/layer-b-utils.R`, non nomi nuovi;
`.forest_gene_rappresentativo()` (Task 3) e `.volcano_soglia_asse()` (Task 4) sono definite
prima dell'uso; `.cluster_k_effective()` (Task 2) esiste già da FASE A1 del 2026-07-31.

**Ordine:** il Task 8 (config) introduce `heatmap_mostra_studi`, usato dal Task 5. Chi esegue
in ordine stretto trova la chiave mancante: **il Task 5 deve aggiungere la chiave alla
config se non c'è ancora**, e il Task 8 la lascia invariata se già presente. Segnalato qui
per non farlo scoprire a metà lavoro.
