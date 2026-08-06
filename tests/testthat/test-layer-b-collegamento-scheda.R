# test-layer-b-collegamento-scheda.R --- TDD: la scheda nuova (.summary_card_v2())
# e la bozza di narrativa (.narrativa_bozza()) arrivano DAVVERO nel bundle.
#
# PERCHE' ESISTE (Task 7bis, aggiunto 2026-08-05 in corso d'opera). La
# revisione del Task 6 ha trovato che .summary_card_v2() era codice
# IRRAGGIUNGIBILE: R/layer-b-build.R continuava a chiamare la vecchia scheda
# (.build_summary_card()). Stessa sorte toccava alla narrativa: la funzione
# che scrive narrative.qmd (.write_narrative_template(), in
# R/layer-b-summary-card.R) non chiamava .narrativa_bozza(). DUE punti di
# collegamento, non uno -- e' la trappola gia' scattata sulla scheda.
#
# Questo file verifica il collegamento SULL'ARTEFATTO scritto su disco (non
# solo che le funzioni pure esistano: quelle sono gia' testate in
# test-layer-b-summary-card-v2.R e test-layer-b-narrative.R), piu' il
# ripiego DICHIARATO quando il deliverable annotato non e' disponibile.

test_that(".bersagli_trovati riporta solo i bersagli presenti, coi loro valori", {
  # Test letterale del brief (Step 1).
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

test_that(".bersagli_trovati ritorna 0 righe (non un errore) quando non ce ne sono", {
  cp <- data.frame(
    gene_symbol = c("SMAD7", "ACTB"),
    logFC_pool = c(1.41, 0.02),
    FDR_BH_within_cluster = c(1e-22, 0.9),
    stringsAsFactors = FALSE)
  out_vuoto_attesi <- simulomicsr:::.bersagli_trovati(cp, character(0))
  expect_equal(nrow(out_vuoto_attesi), 0L)
  out_nessun_match <- simulomicsr:::.bersagli_trovati(cp, "ASSENTE")
  expect_equal(nrow(out_nessun_match), 0L)
  expect_named(out_vuoto_attesi, c("gene", "logFC", "FDR"))
})

test_that(".bersagli_trovati deduplica per gene_symbol (artefatto multi-Ensembl, rilievo I8)", {
  # ARCHS4 mappa piu' Ensembl gene_id sullo stesso simbolo HGNC (paraloghi):
  # SMAD7 compare due volte, con FDR diverso. Senza dedup il bersaglio
  # comparirebbe due volte nella scheda/narrativa -- lo stesso difetto gia'
  # corretto per tabella/heatmap/forest/volcano via .rank_and_dedup_genes(),
  # rimasto latente qui finche' nessun cluster raggiungeva questa funzione
  # (rilievo C1: il provider non era mai collegato).
  cp <- data.frame(
    gene_symbol = c("SMAD7", "SMAD7", "SERPINE1"),
    logFC_pool = c(1.41, 1.38, 2.43),
    FDR_BH_within_cluster = c(1e-22, 1e-5, 1e-19),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.bersagli_trovati(cp, c("SMAD7", "SERPINE1"))
  expect_equal(nrow(out), 2L)
  expect_equal(sum(out$gene == "SMAD7"), 1L)
  # tiene la riga PIU significativa (FDR minimo), non la prima incontrata
  expect_equal(out$logFC[out$gene == "SMAD7"], 1.41)
  expect_equal(out$FDR[out$gene == "SMAD7"], 1e-22)
})

test_that("il bundle usa la scheda nuova: niente cgroup_L5_ nel corpo, e la narrativa e' la bozza", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  # Cluster mega col cluster_id nella forma VERA (cgroup_L5_...): il difetto
  # che questo test previene si vede solo con un ID che la vecchia scheda
  # avrebbe stampato per intero (.build_summary_card() scrive `**Cluster
  # ID:** cluster_id` nel corpo).
  stage4_dir <- make_fake_layer_a_dir(
    cluster_ids = c("cgroup_L5_2e16719f", "cl_aug_1"),
    con_deliverable_annotato = TRUE
  )
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cgroup_L5_2e16719f", "cl_aug_1"))
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }
  selection <- tibble::tibble(
    cluster_id = c("cgroup_L5_2e16719f", "cl_aug_1"),
    label_paper = c("TGF-beta1 (fixture)", "AugTest"),
    priority = c(1L, 2L),
    notes = c("", "")
  )
  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  # bersagli_attesi_provider: argomento del CHIAMANTE, non una tabella
  # interna al pacchetto (vedi .narrativa_bozza()) -- qui dichiaro HGNC1 per
  # il cluster mega, che e' fra i gene_symbol della fixture
  # (make_fake_layer_a_dir() li chiama "HGNC1".."HGNC100").
  bersagli_attesi_provider <- function(cluster_id) {
    if (cluster_id == "cgroup_L5_2e16719f") c("HGNC1", "HGNC2") else character(0)
  }

  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    bersagli_attesi_provider = bersagli_attesi_provider,
    config = cfg,
    out_dir = tempfile("lb_out_collegamento_")
  )

  bundle_dir <- file.path(result$dir, "cgroup_L5_2e16719f")

  # --- scheda nuova: niente cgroup_L5_ nel corpo (test letterale del brief) -
  md <- readLines(file.path(bundle_dir, "summary_card.md"))
  corpo <- md[seq_len(which(grepl("PROVENANCE", md))[1] - 1L)]
  expect_false(any(grepl("cgroup_L5_", corpo)))
  # ma l'ID grezzo del contrasto (contrast_entity), che e' informazione, resta
  # visibile in PROVENANCE -- verificato che il blocco esista davvero.
  expect_true(any(grepl("PROVENANCE", md)))

  # --- narrativa: nessun provider passato qui -> assenza DICHIARATA, mai uno
  # stub TODO e mai un testo generato dal deliverable (era `.narrativa_bozza()`,
  # rimossa il 2026-08-06: nove testi formalmente corretti e senza contenuto
  # scientifico non reggono in un articolo).
  narr_txt <- paste(readLines(file.path(bundle_dir, "narrative.qmd")), collapse = "\n")
  expect_match(narr_txt, "not available")
  expect_false(grepl("TODO", narr_txt))
  expect_false(grepl("BOZZA", narr_txt))

  # --- nessuna nota di ripiego: il deliverable annotato C'ERA per questo
  # cluster, quindi non deve comparire alcuna dichiarazione di ripiego.
  expect_false(grepl("Nota.*scheda usa la versione precedente", narr_txt))
})

test_that("senza deliverable-annotato.rds il build non fallisce: ripiega e lo dichiara nel bundle", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  # make_fake_layer_a_dir() di default NON scrive deliverable-annotato.rds
  # (con_deliverable_annotato = FALSE): e' esattamente lo scenario del
  # ripiego, ed e' lo stesso fixture gia' usato da test-layer-b-build.R.
  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }
  selection <- tibble::tibble(
    cluster_id = c("cl_mega_1", "cl_aug_1"),
    label_paper = c("MegaTest", "AugTest"),
    priority = c(1L, 2L),
    notes = c("", "")
  )
  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  # Non deve fallire (expect_no_error via risultato assegnato con successo).
  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("lb_out_ripiego_")
  )
  expect_s3_class(result, "layer_b_result")

  # --- il ripiego e' dichiarato nel run_metadata.json (per l'audit) ---------
  expect_false(result$run_metadata$input_files$deliverable_annotato$disponibile)
  expect_match(
    result$run_metadata$input_files$deliverable_annotato$motivo_assenza,
    "deliverable-annotato.rds assente"
  )
  expect_setequal(
    result$run_metadata$input_files$deliverable_annotato$cluster_id_ripiego,
    c("cl_mega_1", "cl_aug_1")
  )

  # --- il ripiego e' dichiarato anche nel narrative.qmd (per chi legge il
  # bundle senza aprire il JSON). La narrativa segue la propria regola: senza
  # provider, assenza dichiarata -- mai stub "TODO", mai testo generato.
  narr_txt <- paste(
    readLines(file.path(result$dir, "cl_mega_1", "narrative.qmd")),
    collapse = "\n"
  )
  expect_match(narr_txt, "the summary card below is the earlier version")
  expect_match(narr_txt, "not available")
  expect_false(grepl("TODO", narr_txt))
  expect_false(grepl("BOZZA", narr_txt))

  # --- run_metadata.json scritto su disco riporta la stessa cosa (rilettura
  # dall'artefatto, non solo dall'oggetto R in memoria)
  meta_su_disco <- jsonlite::read_json(file.path(result$dir, "run_metadata.json"))
  expect_false(isTRUE(meta_su_disco$input_files$deliverable_annotato$disponibile))
})

test_that("con deliverable-annotato.rds presente ma il cluster assente dalla tabella, si ripiega solo per quel cluster", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  stage4_dir <- make_fake_layer_a_dir(
    cluster_ids = c("cl_mega_2", "cl_aug_2"),
    con_deliverable_annotato = TRUE  # riga scritta SOLO per "cl_mega_2"
  )
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_2", "cl_aug_2"))
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }
  selection <- tibble::tibble(
    cluster_id = c("cl_mega_2", "cl_aug_2"),
    label_paper = c("MegaTest2", "AugTest2"),
    priority = c(1L, 2L),
    notes = c("", "")
  )
  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("lb_out_parziale_")
  )

  # deliverable-annotato.rds C'ERA (file presente): disponibile = TRUE
  expect_true(result$run_metadata$input_files$deliverable_annotato$disponibile)
  # ma solo "cl_aug_2" (che non ha una riga nella tabella) e' finito sul ripiego
  expect_equal(
    result$run_metadata$input_files$deliverable_annotato$cluster_id_ripiego,
    "cl_aug_2"
  )

  narr_mega <- paste(
    readLines(file.path(result$dir, "cl_mega_2", "narrative.qmd")), collapse = "\n")
  expect_match(narr_mega, "not available")

  narr_aug <- paste(
    readLines(file.path(result$dir, "cl_aug_2", "narrative.qmd")), collapse = "\n")
  expect_match(narr_aug, "non e' una riga di")
  # Anche il ramo di ripiego passa dal provider di narrative: senza provider
  # l'assenza e' DICHIARATA, non riempita con stub "TODO" (testo di processo
  # dentro un documento da articolo).
  expect_match(narr_aug, "not available")
  expect_false(grepl("TODO", narr_aug))
})
