# test-stage3-entity-label-display.R --- TDD per l'etichetta LEGGIBILE.
#
# L'etichetta risolta dall'ID e' corretta ma non sempre pubblicabile: il
# dizionario della tassonomia conserva il nome scientifico senza spazi
# ("severeacuterespiratorysyndromecoronavirus2") e ChEBI usa i nomi sistematici
# ("17beta-hydroxy-5alpha-androstan-3-one" per il DHT). Serve un passaggio umano,
# tenuto in un file di dati e non nel codice.

.fixture_dir_disp <- function() {
  d <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (nzchar(d) && dir.exists(d)) return(d)
  testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
}
.env_disp <- function() {
  .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir_disp())
}
.ovr_finto <- function() {
  data.frame(contrast_entity = c("NCBITaxon:2697049", "CHEBI:16236"),
             label = c("SARS-CoV-2", "etanolo"),
             nota = c("senza spazi nel dizionario", "prova"),
             stringsAsFactors = FALSE)
}

test_that("un override sostituisce il nome ontologico e lo dichiara", {
  r <- .display_entity_label("NCBITaxon:2697049", env = .env_disp(),
                             overrides = .ovr_finto())
  expect_equal(r$label, "SARS-CoV-2")
  expect_equal(r$label_source, "override")
})

test_that("senza override resta il nome ontologico, con la sua fonte", {
  r <- .display_entity_label("CHEBI:16412", env = .env_disp(),
                             overrides = .ovr_finto())
  expect_equal(r$label, "lipopolysaccharide")
  expect_equal(r$label_source, "chebi")
})

test_that("nelle entita' STR gli underscore diventano spazi", {
  # "idiopathic_pulmonary_fibrosis" e' la stringa grezza del delta: come
  # etichetta va letta, non decorata.
  r <- .display_entity_label("STR:idiopathic_pulmonary_fibrosis",
                             env = .env_disp(), overrides = .ovr_finto())
  expect_equal(r$label, "idiopathic pulmonary fibrosis")
  expect_equal(r$label_source, "str_literal")
})

test_that("un override vale anche quando l'ID non e' risolvibile", {
  ovr <- data.frame(contrast_entity = "CHEBI:999999999", label = "composto X",
                    nota = "", stringsAsFactors = FALSE)
  r <- .display_entity_label("CHEBI:999999999", env = .env_disp(), overrides = ovr)
  expect_equal(r$label, "composto X")
  expect_equal(r$label_source, "override")
})

test_that("una tabella di override vuota non cambia nulla", {
  vuota <- data.frame(contrast_entity = character(0), label = character(0),
                      nota = character(0), stringsAsFactors = FALSE)
  r <- .display_entity_label("CHEBI:16412", env = .env_disp(), overrides = vuota)
  expect_equal(r$label, "lipopolysaccharide")
})

test_that("la versione vettoriale conserva ordine e riporta la nota", {
  out <- .display_entity_labels(c("NCBITaxon:2697049", "CHEBI:16412"),
                                env = .env_disp(), overrides = .ovr_finto())
  expect_equal(out$contrast_entity_label, c("SARS-CoV-2", "lipopolysaccharide"))
  expect_equal(out$contrast_entity_label_source, c("override", "chebi"))
  expect_equal(out$contrast_entity_label_note[1], "senza spazi nel dizionario")
  expect_true(is.na(out$contrast_entity_label_note[2]))
})
