# test-layer-b-v3-report.R --- TDD per la v3 del report Layer B: documento
# neutro, in inglese, pubblicabile.
#
# PERCHE' ESISTE. La v2 aveva figure corrette ma un contenuto testuale che non
# regge in un articolo: apertura sul processo interno, testo in italiano,
# elenco delle figure dentro ogni case study, e -- il difetto peggiore -- un
# numero inaffidabile pubblicato come se fosse una misura. Questi test fissano
# le quattro regole che la v3 deve rispettare.

# --- 1. il numero che non va pubblicato --------------------------------------
# `peso_citati` (la quota di peso degli studi CITATI nelle motivazioni) e' una
# stima che il progetto stesso ha dichiarato cieca (mediana 87%: prende anche
# gli studi citati come puliti). Quando il conteggio confronto-per-confronto
# NON e' stato fatto per un gruppo, la riga non deve stampare il peso con dei
# punti di domanda accanto: deve dichiarare che la misura non c'e'.

test_that("senza conteggio, la clausola dichiara 'not measured' e NON pubblica il peso", {
  txt <- simulomicsr:::.lb_confronti_imperfetti_txt(
    list(n = NA_integer_, tot = NA_integer_, peso = 1.0))
  expect_match(txt, "not measured", ignore.case = TRUE)
  expect_false(grepl("100", txt, fixed = TRUE))
  expect_false(grepl("?", txt, fixed = TRUE))
})

test_that("senza il provider (NULL) la clausola dichiara comunque 'not measured'", {
  txt <- simulomicsr:::.lb_confronti_imperfetti_txt(NULL)
  expect_match(txt, "not measured", ignore.case = TRUE)
})

test_that("col conteggio, la clausola riporta n, totale e peso in inglese", {
  txt <- simulomicsr:::.lb_confronti_imperfetti_txt(
    list(n = 29L, tot = 145L, peso = 0.067))
  expect_match(txt, "29")
  expect_match(txt, "145")
  expect_match(txt, "6\\.7")
  expect_false(grepl("confronti", txt, fixed = TRUE))
})

test_that("un conteggio senza peso resta pubblicabile e dichiara il peso mancante", {
  txt <- simulomicsr:::.lb_confronti_imperfetti_txt(
    list(n = 5L, tot = 7L, peso = NA_real_))
  expect_match(txt, "5")
  expect_match(txt, "7")
  expect_match(txt, "weight not available", ignore.case = TRUE)
})

# --- 2. la scheda e' in inglese e non giudica --------------------------------

test_that(".summary_card_v2 e' in inglese e non usa la parola 'dirty'", {
  riga <- data.frame(
    cluster_id = "cgroup_L5_x", contrast_entity = "HGNC:11766",
    contrast_entity_label = "TGFB1", k_effective = 59L, k_kish = 54.5,
    I2_med = 93.5, n_sig = 7909L, quota_top1 = 0.021,
    studio_dominante = "GSE155832", dominato = FALSE, materiale_misto = TRUE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  txt <- simulomicsr:::.summary_card_v2(riga, character(0), list(n = 29L, tot = 145L, peso = 0.067))
  expect_false(grepl("dirty", txt, ignore.case = TRUE))
  expect_false(grepl("sporco", txt, ignore.case = TRUE))
  expect_false(grepl("Cosa e' stato confrontato", txt, fixed = TRUE))
  expect_match(txt, "studies")
  expect_match(txt, "PROVENANCE")
})

test_that("la scheda dichiara il verdetto di incoerenza anche in inglese", {
  riga <- data.frame(
    cluster_id = "c", contrast_entity = "HGNC:5991", contrast_entity_label = "IL1A",
    k_effective = 4L, k_kish = 1.9, I2_med = 63, n_sig = 947L,
    quota_top1 = 0.67, studio_dominante = "GSE181229", dominato = TRUE,
    materiale_misto = FALSE, coherence_verdict = "incoherent",
    stringsAsFactors = FALSE)
  txt <- simulomicsr:::.summary_card_v2(riga)
  expect_match(txt, "INCOHERENT")
  expect_match(txt, "may not measure the same contrast", ignore.case = TRUE)
})

# --- 3. niente elenco delle figure dentro il case study ----------------------

test_that(".write_narrative_template non scrive piu' l'elenco delle figure", {
  sel <- tibble::tibble(cluster_id = "c1", label_paper = "X", priority = 1L, notes = "")
  d <- withr::local_tempdir()
  p <- simulomicsr:::.write_narrative_template(
    cluster_id = "c1", summary_card_path = NULL, selection_row = sel,
    config = layer_b_default_config(), out_dir = d,
    narrativa_bozza_md = "## Biological context\n\ntesto")
  txt <- paste(readLines(p), collapse = "\n")
  expect_false(grepl("## Figures", txt, fixed = TRUE))
  expect_false(grepl("figure-list", txt, fixed = TRUE))
  expect_false(grepl("volcano.svg", txt, fixed = TRUE))
})

# --- 4. la narrativa viene da un file firmato, e la sua assenza si dichiara ---

test_that(".narrativa_da_provider usa il testo del provider quando c'e'", {
  res <- simulomicsr:::.narrativa_da_provider(
    "c1", function(id) "## Biological context\n\nTGF-beta1 is a cytokine.")
  expect_true(res$disponibile)
  expect_match(res$md, "TGF-beta1 is a cytokine")
})

test_that(".narrativa_da_provider dichiara l'assenza invece di tacerla", {
  res <- simulomicsr:::.narrativa_da_provider("c1", function(id) NULL)
  expect_false(res$disponibile)
  expect_match(res$md, "not available", ignore.case = TRUE)
  expect_match(res$motivo, "c1")
})

test_that(".narrativa_da_provider senza provider non e' un errore ma un'assenza dichiarata", {
  res <- simulomicsr:::.narrativa_da_provider("c1", NULL)
  expect_false(res$disponibile)
  expect_match(res$md, "not available", ignore.case = TRUE)
})

# --- 5. la sezione sul corpus: tabelle calcolate, mai ricopiate ---------------

test_that(".corpus_tabelle calcola le tabelle dal deliverable, senza numeri cablati", {
  d <- data.frame(
    cluster_id = paste0("c", 1:6),
    contrast_entity = c("CHEBI:1", "HGNC:2", "NCBITaxon:3", "MeSH:4", "CHEBI:5", "STR:x"),
    contrast_entity_label = paste0("e", 1:6),
    k_effective = c(59L, 20L, 34L, 10L, 4L, 3L),
    k_kish = c(54.5, 18.2, 30.3, 6.9, 1.9, 1.2),
    I2_med = c(93.5, 90.5, 95.6, 62.9, 63, 10),
    n_sig = c(7909L, 3579L, 1933L, 3515L, 947L, 12L),
    dominato = c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE),
    materiale_misto = c(TRUE, FALSE, TRUE, FALSE, FALSE, FALSE),
    coherence_verdict = c(rep("coherent", 5), "incoherent"),
    stringsAsFactors = FALSE)

  tb <- simulomicsr:::.corpus_tabelle(d, top_n = 3L)

  expect_equal(tb$n_gruppi, 6L)
  # composizione per tipo di entita', dedotta dal prefisso dell'ID
  expect_true(all(c("Entity type", "Meta-analyses") %in% names(tb$composizione)))
  expect_equal(sum(tb$composizione$`Meta-analyses`), 6L)
  # potenza: dominati e sotto-due-efficaci contati, non ricopiati
  expect_equal(tb$n_dominati, 2L)
  expect_equal(tb$n_sotto_due_efficaci, 2L)
  expect_equal(tb$n_incoerenti, 1L)
  # la tabella delle piu' potenti e' ordinata e lunga top_n
  expect_equal(nrow(tb$piu_potenti), 3L)
  expect_equal(tb$piu_potenti[[1L]][1L], "e1")
})

test_that(".corpus_tabelle non crolla se mancano le colonne opzionali", {
  d <- data.frame(cluster_id = c("a", "b"), contrast_entity = c("CHEBI:1", "MeSH:2"),
                  contrast_entity_label = c("x", "y"), k_effective = c(3L, 4L),
                  I2_med = c(10, 20), n_sig = c(5L, 6L), stringsAsFactors = FALSE)
  tb <- simulomicsr:::.corpus_tabelle(d)
  expect_equal(tb$n_gruppi, 2L)
  expect_true(is.na(tb$n_dominati))
})

# --- 6. la figura del corpus parla inglese -----------------------------------

test_that(".build_corpus_overview scrive una didascalia in inglese", {
  d <- data.frame(k_effective = c(3L, 10L, 59L), I2_med = c(10, 50, 93),
                  n_sig = c(5L, 500L, 7909L))
  out <- withr::local_tempdir()
  res <- simulomicsr:::.build_corpus_overview(d, out_dir = out,
                                              config = layer_b_default_config())
  expect_true(file.exists(res$png_path))
  expect_match(res$caption, "meta-analyses")
  expect_false(grepl("Distribuzione", res$caption, fixed = TRUE))
})

# --- 7. il provider di narrative arriva davvero nel bundle -------------------
# Terzo caso, in un ramo dove il progetto ha gia' pagato due volte lo stesso
# difetto: una funzione scritta e mai chiamata (il fornitore dei confronti
# imperfetti, e quello dei bersagli attesi). Qui si verifica il COLLEGAMENTO,
# non la funzione: che il testo passato a build_layer_b_results() finisca
# nell'artefatto scritto su disco.

test_that("narrative_provider: il testo firmato finisce nel narrative.qmd del bundle", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("ComplexHeatmap")

  stage4_dir <- make_fake_layer_a_dir(
    cluster_ids = c("cgroup_L5_2e16719f", "cl_aug_1"),
    con_deliverable_annotato = TRUE)
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)
  cache <- make_fake_counts_cache(c("cgroup_L5_2e16719f", "cl_aug_1"))

  per_cluster_samples_provider <- function(cluster_id) {
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L))
  }
  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  res <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = tibble::tibble(
      cluster_id = c("cgroup_L5_2e16719f", "cl_aug_1"),
      label_paper = c("TGF-beta1 (fixture)", "AugTest"),
      priority = c(1L, 2L), notes = c("", "")),
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    narrative_provider = function(id) {
      if (id == "cgroup_L5_2e16719f") {
        "## Biological context\n\nSigned text for the first group."
      } else {
        NULL  # il secondo NON ha narrativa: l'assenza va dichiarata
      }
    },
    config = cfg,
    out_dir = tempfile("lb_out_narr_"))

  narr <- paste(readLines(file.path(res$dir, "cgroup_L5_2e16719f", "narrative.qmd")),
                collapse = "\n")
  expect_match(narr, "Signed text for the first group")
  expect_false(grepl("not available", narr))

  narr2 <- paste(readLines(file.path(res$dir, "cl_aug_1", "narrative.qmd")), collapse = "\n")
  expect_match(narr2, "not available")

  # il gruppo senza narrativa e' registrato nell'audit, non solo nella pagina
  expect_true(res$run_metadata$input_files$narrative$provider_fornito)
  expect_equal(res$run_metadata$input_files$narrative$cluster_id_senza_narrativa,
               "cl_aug_1")
})

# --- 8. le motivazioni delle incoerenti sono in inglese e brevi ---------------
# La colonna `coherence_reason` del deliverable e' un verbale di lettura umana:
# italiano, lungo, e in un caso cita la decisione presa da una persona in una
# data. In un documento da articolo non va stampata cosi'. La traduzione
# editoriale vive in inst/extdata/coherence-reason-en.csv (testo, non dato) e
# un gruppo senza traduzione NON ricade sull'italiano: si dichiara.

test_that(".corpus_tabelle usa la motivazione inglese quando c'e'", {
  d <- data.frame(
    cluster_id = c("cgroup_L5_3973fe03", "c2"),
    contrast_entity = c("HGNC:5991", "CHEBI:1"),
    contrast_entity_label = c("IL1A", "x"),
    k_effective = c(4L, 3L), I2_med = c(63, 10), n_sig = c(947L, 5L),
    coherence_verdict = c("incoherent", "coherent"),
    coherence_reason = c("PEGGIORATO dal pooling: i due studi IL-1alfa veri sono caduti", NA),
    stringsAsFactors = FALSE)
  tb <- simulomicsr:::.corpus_tabelle(d)
  expect_equal(nrow(tb$incoerenti), 1L)
  expect_match(tb$incoerenti$Reason[1L], "IL-1 beta")
  expect_false(grepl("PEGGIORATO", tb$incoerenti$Reason[1L]))
})

test_that(".corpus_tabelle non ripiega sull'italiano quando la traduzione manca", {
  d <- data.frame(
    cluster_id = "cgroup_L5_mai_visto", contrast_entity = "CHEBI:1",
    contrast_entity_label = "y", k_effective = 3L, I2_med = 10, n_sig = 5L,
    coherence_verdict = "incoherent",
    coherence_reason = "verbale interno in italiano, con nomi e date",
    stringsAsFactors = FALSE)
  tb <- simulomicsr:::.corpus_tabelle(d)
  expect_false(grepl("verbale", tb$incoerenti$Reason[1L]))
  expect_match(tb$incoerenti$Reason[1L], "not available", ignore.case = TRUE)
})

# --- 9. le etichette pubblicate sono in inglese ------------------------------
# `contrast_entity_label` arriva dal deliverable, che a sua volta applica
# inst/extdata/entity-label-overrides.csv. Una etichetta di quel file era in
# italiano ("antigen (classe-ombrello)") e finiva stampata nella tabella delle
# incoerenti. La correzione sta nel file (fonte unica delle etichette
# leggibili), ma il deliverable gia' materializzato porta ancora la vecchia:
# la tabella riapplica l'override al momento della pubblicazione.

test_that(".corpus_tabelle riapplica l'override delle etichette al momento della pubblicazione", {
  d <- data.frame(
    cluster_id = "c1", contrast_entity = "CHEBI:59132",
    contrast_entity_label = "antigen (classe-ombrello)",
    k_effective = 3L, I2_med = 10, n_sig = 5L,
    coherence_verdict = "incoherent", stringsAsFactors = FALSE)
  tb <- simulomicsr:::.corpus_tabelle(d)
  expect_equal(tb$incoerenti$Contrast[1L], "antigen (umbrella class)")
  expect_equal(tb$piu_potenti$Contrast[1L], "antigen (umbrella class)")
})

test_that("un'entita' senza override tiene l'etichetta del deliverable", {
  d <- data.frame(
    cluster_id = "c1", contrast_entity = "HGNC:11766",
    contrast_entity_label = "TGFB1", k_effective = 59L, I2_med = 93, n_sig = 7909L,
    stringsAsFactors = FALSE)
  tb <- simulomicsr:::.corpus_tabelle(d)
  expect_equal(tb$piu_potenti$Contrast[1L], "TGFB1")
})
