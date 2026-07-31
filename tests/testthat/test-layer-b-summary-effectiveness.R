# test-layer-b-summary-effectiveness.R --- TDD: la scheda del case study deve
# dire anche quanto il pooling e' efficace.
#
# PERCHE' ESISTE. Le colonne misurate il 2026-07-31 (k_kish, quota_top1,
# materiale) stanno nel deliverable ma NON nella scheda che finisce accanto alla
# figura. Chi legge il case study di Parkinson vede `k_effective: 10` e non vede
# che gli studi efficaci sono 1,8 e che il 73% del peso viene da uno studio che
# non e' cervello di paziente ma neuroni derivati da iPSC. Sono esattamente i due
# numeri che smontano quel case study.
#
# LA COSA CHE QUESTI TEST DIFENDONO: la retrocompatibilita'. Se le misure non
# arrivano, la scheda deve uscire COME PRIMA — non con righe vuote, non con
# "NA", non con un errore. Un bundle costruito senza annotazione resta leggibile.

.cp_eff_fixture <- function() {
  tibble::tibble(
    cluster_id = "cl_e", gene_id = c("G1", "G2"), gene_symbol = c("A", "B"),
    method = "rem_group", logFC_pool = c(1, 2), SE_pool = 0.1,
    p_value_pool = 1e-5, tau2 = 0.01, I2 = 50, Q = NA_real_, Q_pval = NA_real_,
    k_effective = c(9L, 10L), n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = c(1e-4, 1e-4), direction_applied = "none")
}

.card <- function(eff = NULL) {
  out_dir <- tempfile("sc_eff_"); dir.create(out_dir)
  res <- simulomicsr:::.build_summary_card(
    cluster_id = "cl_e",
    layer_a_subset = list(cluster_pooled = .cp_eff_fixture(),
                          per_study_de = .cp_eff_fixture()[0L, ]),
    stage3_metadata = tibble::tibble(cluster_id = "cl_e", kind_effective = "contrast/gain",
                                     agent_id = "MeSH:D010300", tissue = "control=x",
                                     safety_min = 0.5),
    selection_row = tibble::tibble(cluster_id = "cl_e", label_paper = "Test",
                                   priority = 1L, notes = ""),
    config = layer_b_default_config(), out_dir = out_dir,
    pooling_effectiveness = eff)
  txt <- readLines(res$md_path)
  unlink(out_dir, recursive = TRUE)
  txt
}

.eff_fixture <- function() {
  data.frame(cluster_id = "cl_e", k_studies = 10L, k_kish = 1.8,
             quota_top1 = 0.732, frazione_efficace = 0.18, dominato = TRUE,
             studio_dominante = "GSE181029", materiale_misto = TRUE,
             classe_studio_dominante = "model", dominato_da_modello = TRUE,
             n_studi_model = 2L, n_studi_primary = 8L, n_studi_unknown = 0L,
             stringsAsFactors = FALSE)
}

test_that("con le misure, la scheda riporta studi efficaci e chi domina", {
  txt <- paste(.card(.eff_fixture()), collapse = "\n")

  expect_match(txt, "1\\.8")          # studi efficaci
  expect_match(txt, "73")             # quota del primo studio, in percentuale
  expect_match(txt, "GSE181029")      # QUALE studio domina
})

test_that("la scheda dichiara materiale misto e dominanza di un modello in vitro", {
  txt <- paste(.card(.eff_fixture()), collapse = "\n")
  expect_match(txt, regex_or <- "in vitro|model|modello")
  expect_match(txt, "2")   # n studi in vitro
  expect_match(txt, "8")   # n studi di paziente
})

test_that("senza le misure la scheda esce COME PRIMA, senza righe vuote", {
  senza <- .card(NULL)
  con   <- .card(.eff_fixture())

  # tutte le righe della versione senza misure devono esistere identiche in
  # quella con: l'aggiunta e' additiva, non riscrive nulla
  expect_true(all(senza %in% con))
  # e non deve comparire nessun "NA" o riga di efficacia vuota
  expect_false(any(grepl("k_kish|efficaci|NA%", senza)))
})

test_that("un cluster assente dalla tabella delle misure non rompe la scheda", {
  eff <- .eff_fixture(); eff$cluster_id <- "un_altro_cluster"
  txt <- .card(eff)
  expect_true(length(txt) > 5L)
  expect_false(any(grepl("NA", grep("efficaci", txt, value = TRUE))))
})

test_that("un gruppo NON dominato non viene descritto come dominato", {
  eff <- .eff_fixture()
  eff$k_kish <- 45.1; eff$quota_top1 <- 0.026; eff$dominato <- FALSE
  eff$frazione_efficace <- 0.92; eff$dominato_da_modello <- FALSE
  eff$materiale_misto <- FALSE; eff$studio_dominante <- "GSE155832"
  txt <- paste(.card(eff), collapse = "\n")

  expect_match(txt, "45\\.1")
  expect_false(grepl("dominated by a single study|dominato", txt, ignore.case = TRUE))
})
