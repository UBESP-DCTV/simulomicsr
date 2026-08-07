# test-layer-b-report-struttura.R --- TDD: il template ha la gerarchia sana
# (apertura, quadro d'insieme, case study, appendice) e non stampa gli
# identificativi interni nelle intestazioni.
#
# PERCHE' ESISTE (Task 9 del ridisegno). Il documento oggi ripete il titolo di
# ogni case study TRE volte (un ## del loop + due # embedded), con
# l'identificativo interno cgroup_L5_930c8dcf in ogni intestazione, e non ha
# ne' un'apertura ne' un quadro d'insieme: si apre direttamente su un dump di
# campi tecnici. Vedi docs/superpowers/specs/2026-08-05-layer-b-redesign-design.md
# §3 (i quattro tempi) e §9 (i sette criteri di riuscita).

test_that("il template non stampa gli identificativi interni nelle intestazioni", {
  qmd <- readLines(system.file("templates", "layer-b-report.qmd",
                               package = "simulomicsr"))
  intestazioni <- grep("^#{1,3} ", qmd, value = TRUE)
  expect_false(any(grepl("cluster_id|cgroup_L5_", intestazioni)))
})

test_that("il template ha introduzione, case study, quadro d'insieme e appendice", {
  qmd <- paste(readLines(system.file("templates", "layer-b-report.qmd",
                                     package = "simulomicsr")), collapse = "\n")
  expect_match(qmd, "## Introduction")
  expect_match(qmd, "Case study %d")
  expect_match(qmd, "## The full set of meta-analyses")
  expect_match(qmd, "## Appendix")
})

test_that("l'introduzione precede i case study, che precedono il quadro d'insieme e l'appendice", {
  # ORDINE CAMBIATO il 2026-08-06 su richiesta dell'utente: il documento non si
  # apre piu' con la prova agonista/antagonista ne' con la descrizione del
  # corpus (erano entrambe note di impianto in cima a un documento
  # scientifico). Si apre con una introduzione neutra, entra subito nei case
  # study, e descrive l'insieme completo DOPO, quando il lettore sa che cosa
  # sta guardando.
  qmd <- paste(readLines(system.file("templates", "layer-b-report.qmd",
                                     package = "simulomicsr")), collapse = "\n")
  pos_intro   <- regexpr("## Introduction", qmd, fixed = TRUE)
  pos_case    <- regexpr("Case study %d", qmd, fixed = TRUE)
  pos_corpus  <- regexpr("## The full set of meta-analyses", qmd, fixed = TRUE)
  pos_append  <- regexpr("## Appendix", qmd, fixed = TRUE)

  expect_true(all(c(pos_intro, pos_case, pos_corpus, pos_append) > 0))
  expect_lt(pos_intro, pos_case)
  expect_lt(pos_case, pos_corpus)
  expect_lt(pos_corpus, pos_append)
})

test_that("il template non cabla piu' numeri scientifici (l'apertura e' stata rimossa)", {
  # I numeri del controllo biologico (1.441 geni, 97,7% di segno opposto,
  # Spearman -0,938) stavano scritti a mano nell'apertura. L'apertura non
  # esiste piu', e nessun numero di risultato va cablato nel template: quelli
  # del corpus si CALCOLANO dal deliverable (.corpus_tabelle()), quelli dei
  # case study stanno nelle narrative firmate e nelle schede.
  qmd <- paste(readLines(system.file("templates", "layer-b-report.qmd",
                                     package = "simulomicsr")), collapse = "\n")
  expect_false(grepl("1.441|1441", qmd, perl = TRUE))
  expect_false(grepl("0,938|0\\.938", qmd))
  expect_false(grepl("97,7|97\\.7", qmd))
})

test_that("SUPERATO: l'apertura citava il controllo biologico coi numeri cablati", {
  skip("L'apertura e' stata rimossa il 2026-08-06 su richiesta dell'utente.")
  # i numeri vengono da analysis/audit/2026-08-02-fix/90-controllo-biologico.log
  # (deliverable v15): NON vanno inventati ne' arrotondati diversamente.
  qmd <- paste(readLines(system.file("templates", "layer-b-report.qmd",
                                     package = "simulomicsr")), collapse = "\n")
  expect_match(qmd, "1.441|1441", perl = TRUE)
  expect_match(qmd, "1.408|1408", perl = TRUE)
  expect_match(qmd, "97,7|97\\.7")
  expect_match(qmd, "0,938|0\\.938")
  expect_match(qmd, "KLK3")
  expect_match(qmd, "TMPRSS2")
  expect_match(qmd, "FKBP5")
  expect_match(qmd, "NKX3-1")
})

test_that("ogni case study usa la sola etichetta leggibile nel titolo generato, mai il cluster_id", {
  # la riga del loop che stampa il titolo del case study deve interpolare
  # SOLO label_paper -- niente cl_id/cluster_id nella stringa del titolo.
  qmd <- readLines(system.file("templates", "layer-b-report.qmd",
                               package = "simulomicsr"))
  riga_titolo <- grep('Case study %d.*label_paper', qmd, value = TRUE, fixed = FALSE)
  expect_gt(length(riga_titolo), 0L)
  expect_false(any(grepl("cl_id|cluster_id", riga_titolo)))
})

test_that("render_layer_b_report produce un HTML con l'apertura prima delle immagini dei case study", {
  skip_if_not_installed("quarto")
  skip_if(Sys.which("quarto") == "")
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  stage4_dir <- make_fake_layer_a_dir(
    cluster_ids = c("cgroup_L5_930c8dcf", "cgroup_L5_c0d1d837"),
    con_deliverable_annotato = TRUE
  )
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)
  cache <- make_fake_counts_cache(c("cgroup_L5_930c8dcf", "cgroup_L5_c0d1d837"))
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }
  selection <- tibble::tibble(
    cluster_id = c("cgroup_L5_930c8dcf", "cgroup_L5_c0d1d837"),
    label_paper = c("DHT (dihydrotestosterone) -- AR agonist", "Enzalutamide -- AR antagonist"),
    priority = c(1L, 1L),
    notes = c("", "")
  )
  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  out_dir <- tempfile("lb_struttura_")
  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = out_dir
  )
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  lb <- load_layer_b(result$dir)
  out_html <- file.path(result$dir, "layer_b_report.html")
  render_layer_b_report(lb, out_html)
  expect_true(file.exists(out_html))

  html <- paste(readLines(out_html, warn = FALSE), collapse = "\n")
  pos_intro <- regexpr("Introduction", html, fixed = TRUE)
  pos_prima_immagine <- regexpr("<img", html, fixed = TRUE)
  # L'INTESTAZIONE vera, non la voce dell'indice: il sommario in cima al
  # documento cita la sezione molto prima che essa cominci, e cercare il solo
  # testo darebbe una posizione che non e' quella della sezione.
  pos_corpus <- regexpr("<h2[^>]*>\\s*The full set of meta-analyses", html, perl = TRUE)
  expect_true(pos_intro > 0)
  expect_true(pos_prima_immagine > 0)
  expect_lt(pos_intro, pos_prima_immagine)
  # il quadro d'insieme arriva DOPO le figure dei case study
  expect_lt(pos_prima_immagine, pos_corpus)

  # zero occorrenze del cluster_id grezzo nelle intestazioni HTML (<h1>..<h6>)
  intestazioni_html <- regmatches(html, gregexpr("<h[1-6][^>]*>.*?</h[1-6]>", html, perl = TRUE))[[1]]
  expect_false(any(grepl("cgroup_L5_", intestazioni_html)))
})

test_that("l'appendice non pubblica la colonna `notes` della selezione", {
  # `notes` contiene appunti di lavoro: italiano, gergo interno ('SUPP -
  # incoerente dichiarato'), e i numeri di un run precedente scritti a mano.
  # Il documento e' materiale da articolo: quelle note restano nel CSV.
  qmd <- paste(readLines(system.file("templates", "layer-b-report.qmd",
                                     package = "simulomicsr")), collapse = "\n")
  expect_match(qmd, "COLONNE_SELEZIONE", fixed = TRUE)
  expect_false(grepl("DT::datatable(lb$selection_resolved", qmd, fixed = TRUE))
})
