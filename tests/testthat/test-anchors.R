test_that(".normalize_dose canonicalizza unita' SI", {
  expect_equal(simulomicsr:::.normalize_dose("10 nM"), "10nM")
  expect_equal(simulomicsr:::.normalize_dose("100 ng/ml"), "100ng/ml")
  expect_equal(simulomicsr:::.normalize_dose("1 uM"), "1uM")
  expect_equal(simulomicsr:::.normalize_dose("1 µM"), "1uM")  # micro symbol
  expect_equal(simulomicsr:::.normalize_dose("0.5 mM"), "0.5mM")
})

test_that(".normalize_dose mappa NULL/NA a 'nodose'", {
  expect_equal(simulomicsr:::.normalize_dose(NULL), "nodose")
  expect_equal(simulomicsr:::.normalize_dose(NA_character_), "nodose")
  expect_equal(simulomicsr:::.normalize_dose(""), "nodose")
})

test_that(".normalize_dose preserva 'standard' come placeholder", {
  expect_equal(simulomicsr:::.normalize_dose("standard"), "standard")
})

# .normalize_duration ------------------------------------------------------

test_that(".normalize_duration canonicalizza ore", {
  expect_equal(simulomicsr:::.normalize_duration("1 h"), "1h")
  expect_equal(simulomicsr:::.normalize_duration("24h"), "24h")
  expect_equal(simulomicsr:::.normalize_duration("3 hours"), "3h")
  expect_equal(simulomicsr:::.normalize_duration("90 min"), "1.5h")
  expect_equal(simulomicsr:::.normalize_duration("2 days"), "48h")
  expect_equal(simulomicsr:::.normalize_duration("6d"), "6d")  # giorni preservati per coltura lunga
})

test_that(".normalize_duration mappa NULL/NA a 'na'", {
  expect_equal(simulomicsr:::.normalize_duration(NULL), "na")
  expect_equal(simulomicsr:::.normalize_duration(NA_character_), "na")
  expect_equal(simulomicsr:::.normalize_duration(""), "na")
})

# .normalize_cell_id -------------------------------------------------------

test_that(".normalize_cell_id passa through Cellosaurus IDs", {
  expect_equal(simulomicsr:::.normalize_cell_id("CVCL_0030", "MCF-7"), "CVCL_0030")
})

test_that(".normalize_cell_id usa label_raw se Cellosaurus assente", {
  expect_equal(simulomicsr:::.normalize_cell_id(NULL, "HUVEC"), "HUVEC")
  expect_equal(simulomicsr:::.normalize_cell_id(NA_character_, "HEK293T"), "HEK293T")
})

test_that(".normalize_cell_id ritorna 'unclear' se entrambi vuoti", {
  expect_equal(simulomicsr:::.normalize_cell_id(NULL, NULL), "unclear")
  expect_equal(simulomicsr:::.normalize_cell_id("", ""), "unclear")
})

# make_anchor: casi base spec sec.4.3 ---------------------------------------

read_fact <- function(name) {
  jsonlite::read_json(testthat::test_path(paste0("fixtures/sample-facts-", name, ".json")))
}

test_that("make_anchor produce anchor canonico v3 per VEGF cytokine HUVEC 1h", {
  facts <- read_fact("vegf-huvec")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  expect_equal(
    anchor,
    "cytokine_stim|HGNC:12680|wt|nodose|1h|exposure|HUVEC|primary_culture|proliferating|whole_cell|vascular_endothelium|none|false"
  )
})

test_that("make_anchor R8 mediated_effect: agente di interesse = mediated_effect.target", {
  facts <- read_fact("dox-teto-sox17")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  expect_match(anchor, "^genetic_overexpression\\|HGNC:")
  expect_match(anchor, "SOX17")
  expect_false(grepl("Dox|small_molecule", anchor))
})

test_that("make_anchor R9 variant: segmento 3 espone label mutante", {
  facts <- read_fact("apobec1-mut")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_length(segments, 13L)
  expect_equal(segments[[3L]], "YTHmut")
})

test_that("make_anchor disease_vs_normal: disease_status segmento 12 = 'case' per stage2_role='case'", {
  facts <- read_fact("pd-ipsc-neurons")
  anchor <- make_anchor(facts, stage2_role = "case")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[1L]], "disease_vs_normal")
  expect_equal(segments[[12L]], "case")
})

test_that("make_anchor R24 phase=washout entra nell'anchor se dichiarato", {
  facts <- read_fact("vegf-huvec")
  facts$perturbations[[1L]]$kind <- "small_molecule"
  facts$perturbations[[1L]]$phase <- "washout"
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[6L]], "washout")
})

test_that("make_anchor R25 subcellular: default 'whole_cell' se NULL", {
  facts <- read_fact("vegf-huvec")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[10L]], "whole_cell")
})

test_that("make_anchor R31 cell_state: default 'proliferating' se NULL", {
  facts <- read_fact("vegf-huvec")
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[9L]], "proliferating")
})

test_that("make_anchor has_engineered_baseline=true se engineered_modifications non vuoto", {
  facts <- read_fact("vegf-huvec")
  facts$cell_context$engineered_modifications <- list(
    list(kind = "transgene_stable", label = "MYC", variant = NULL)
  )
  anchor <- make_anchor(facts, stage2_role = "perturbed")
  segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
  expect_equal(segments[[13L]], "true")
})

test_that("make_anchor anchor ha sempre 13 segmenti", {
  for (name in c("vegf-huvec", "knockdown-ocily1", "dox-teto-sox17",
                 "apobec1-mut", "pd-ipsc-neurons")) {
    facts <- read_fact(name)
    role <- if (name == "pd-ipsc-neurons") "case" else "perturbed"
    anchor <- make_anchor(facts, stage2_role = role)
    segments <- strsplit(anchor, "\\|", fixed = FALSE)[[1L]]
    expect_length(segments, 13L)
  }
})
