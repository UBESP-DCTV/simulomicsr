# test-layer-b-k-cluster.R --- TDD: il k mostrato deve essere quello del CLUSTER,
# non quello di un gene a caso.
#
# PERCHE' ESISTE. `k_effective` in `cluster_pooled.parquet` ha un valore PER
# GENE: un gene assente in alcuni studi ha meno studi che contribuiscono. Tre
# punti del Layer B ne pescavano uno arbitrario — `unique(...)[1L]` o
# `dplyr::first()` — e quindi mostravano il k di qualunque gene capitasse per
# primo nel parquet.
#
# Misurato sui 9 bundle prodotti il 2026-07-31: QUATTRO schede su nove
# riportavano un k sbagliato (IL1A 3 invece di 4, Parkinson 9 invece di 10,
# SARS-CoV-2 32 invece di 33, JQ1 22 invece di 24). E' un numero che finisce
# nelle figure del paper.
#
# Il valore giusto e' il MASSIMO sul cluster: stesso criterio del deliverable
# (`60-deliverable-annotato.R`) e del filtro di copertura.

.cp_k_fixture <- function() {
  tibble::tibble(
    cluster_id = "cl_k",
    gene_id = c("ENSG_1", "ENSG_2", "ENSG_3", "ENSG_4"),
    gene_symbol = c("A", "B", "C", "D"),
    method = "rem_group",
    logFC_pool = c(1, 1, 1, 1),
    SE_pool = 0.1,
    p_value_pool = 1e-5,
    tau2 = 0.01, I2 = 50, Q = NA_real_, Q_pval = NA_real_,
    # il gene messo per PRIMO ha il k piu' basso: se il codice prende il primo,
    # sbaglia in modo visibile
    k_effective = c(2L, 5L, 20L, 20L),
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = c(1e-4, 1e-4, 1e-4, 1e-4),
    direction_applied = "none"
  )
}

test_that(".cluster_k_effective prende il massimo, non il primo", {
  expect_equal(.cluster_k_effective(.cp_k_fixture()), 20L)
})

test_that("un solo gene: il k resta quello (non-regressione)", {
  cp <- .cp_k_fixture()[3L, ]
  expect_equal(.cluster_k_effective(cp), 20L)
})

test_that("gli NA non vincono e non propagano", {
  cp <- .cp_k_fixture()
  cp$k_effective <- c(NA_integer_, 5L, NA_integer_, 20L)
  expect_equal(.cluster_k_effective(cp), 20L)
})

test_that("tutti NA, colonna assente o input vuoto danno NA, non un errore", {
  cp <- .cp_k_fixture()
  cp$k_effective <- NA_integer_
  expect_true(is.na(.cluster_k_effective(cp)))

  cp2 <- .cp_k_fixture(); cp2$k_effective <- NULL
  expect_true(is.na(.cluster_k_effective(cp2)))

  expect_true(is.na(.cluster_k_effective(.cp_k_fixture()[0L, ])))
})

test_that("la summary card mostra il k del cluster, non quello del primo gene", {
  out_dir <- tempfile("sc_k_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE))
  res <- simulomicsr:::.build_summary_card(
    cluster_id = "cl_k",
    layer_a_subset = list(cluster_pooled = .cp_k_fixture(),
                          per_study_de = .cp_k_fixture()[0L, ]),
    stage3_metadata = tibble::tibble(cluster_id = "cl_k", kind_effective = "x",
                                     agent_id = "y", tissue = "z", safety_min = 0.5),
    selection_row = tibble::tibble(cluster_id = "cl_k", label_paper = "Test",
                                   priority = 1L, notes = ""),
    config = layer_b_default_config(), out_dir = out_dir)

  txt <- readLines(res$md_path)
  riga <- grep("k_effective", txt, value = TRUE)[1L]
  expect_match(riga, "20")
  expect_false(grepl("\\b2\\b", sub(".*k_effective:\\*\\* ", "", riga)))
})

test_that("la didascalia del forest riporta lo stesso k del cluster", {
  # Il forest disegna i primi N geni: il k in didascalia non deve essere quello
  # del gene che capita per primo fra quelli disegnati.
  ps <- tibble::tibble(
    cluster_id = "cl_k", study_id = paste0("GSE", 1:20),
    gene_id = "ENSG_3", gene_symbol = "C",
    logFC = rnorm(20), SE = 0.2, p_value = 0.01, t_stat = 1,
    n_treated = 3L, n_control = 3L, direction_applied = "none")
  out_dir <- tempfile("fo_k_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE))
  res <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = .cp_k_fixture(),
    method = "rem_group", out_dir = out_dir, config = layer_b_default_config())

  expect_match(res$caption, "k=20")
})

test_that("layer_b_validate_selection riporta il k del cluster", {
  # Non e' cosmetico: e' la tabella che si legge PRIMA di lanciare il build, cioe'
  # il momento in cui ci si accorgerebbe di aver scelto il cluster sbagliato.
  skip_if_not_installed("arrow")
  tmp <- tempfile("val_k_"); dir.create(tmp); on.exit(unlink(tmp, recursive = TRUE))
  arrow::write_parquet(.cp_k_fixture(), file.path(tmp, "cluster_pooled.parquet"))
  sel <- file.path(tmp, "sel.csv")
  utils::write.csv(data.frame(cluster_id = "cl_k", label_paper = "Test",
                              priority = 1L, notes = ""), sel, row.names = FALSE)

  out <- layer_b_validate_selection(sel, tmp)
  expect_equal(out$k_effective, 20L)
})
