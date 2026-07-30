# test-stage3-entity-label.R --- TDD per R/stage3-entity-label.R
#
# L'etichetta mostrata dei gruppi (`canonical_name`) e' ereditata dall'anchor
# vecchio e su decine di gruppi e' sbagliata mentre l'ID (`contrast_entity`) e'
# giusto: CHEBI:63637 mostrato "sodium aurothiomalate" e' vemurafenib,
# CHEBI:5931 "chloride" e' insulina, MeSH:D008180 "cancer" e' il lupus.
# Queste funzioni risolvono l'etichetta DALL'ID, in una colonna NUOVA, senza
# toccare `canonical_name` (la provenienza resta tracciabile).
#
# Le fixture mini-dict sono in inst/extdata/ontology-fixtures-mini/.

.fixture_dir_label <- function() {
  d <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (nzchar(d) && dir.exists(d)) return(d)
  testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
}

.env_label <- function() {
  .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir_label())
}

# --- risoluzione per ontologia ----------------------------------------------

test_that("CHEBI risolve al primary_name di ChEBI", {
  res <- .resolve_contrast_entity_label("CHEBI:16236", env = .env_label())
  expect_equal(res$label, "ethanol")
  expect_equal(res$label_source, "chebi")
})

test_that("HGNC risolve al simbolo del gene", {
  res <- .resolve_contrast_entity_label("HGNC:6018", env = .env_label())
  expect_equal(res$label, "IL6")
  expect_equal(res$label_source, "hgnc")
})

test_that("MeSH risolve al main heading", {
  res <- .resolve_contrast_entity_label("MeSH:D011471", env = .env_label())
  expect_equal(res$label, "Prostatic Neoplasms")
  expect_equal(res$label_source, "mesh")
})

test_that("CHEMBL risolve al pref_name", {
  res <- .resolve_contrast_entity_label("CHEMBL:CHEMBL_ENZA", env = .env_label())
  expect_equal(res$label, "Enzalutamide")
  expect_equal(res$label_source, "chembl")
})

test_that("NCBITaxon risolve al nome scientifico e dichiara che e' normalizzato", {
  # Il dizionario in cache conserva solo il nome NORMALIZZATO (senza spazi):
  # l'etichetta va riletta a mano, e la fonte lo dice.
  res <- .resolve_contrast_entity_label("NCBITaxon:2697049", env = .env_label())
  expect_equal(res$label, "severeacuterespiratorysyndromecoronavirus2")
  expect_equal(res$label_source, "ncbitaxon_normalized")
})

test_that("il markup tipografico di ChEBI non entra nell'etichetta", {
  # I primary_name ChEBI contengono markup HTML per stereodescrittori e pedici
  # ("bleomycin A<small><sub>2</sub></small>"): i tag vanno via, il testo resta.
  e <- .env_label()
  fake <- list(chebi_id = 1L, primary_name = "bleomycin A<small><sub>2</sub></small>")
  assign("999001", fake, envir = e$chebi$by_id)
  res <- .resolve_contrast_entity_label("CHEBI:999001", env = e)
  expect_equal(res$label, "bleomycin A2")
  expect_equal(res$label_source, "chebi")
})

# --- entita' senza nome ontologico ------------------------------------------

test_that("STR resta la stringa letterale, dichiarata come tale", {
  res <- .resolve_contrast_entity_label("STR:tgf_b", env = .env_label())
  expect_equal(res$label, "tgf_b")
  expect_equal(res$label_source, "str_literal")
})

test_that("COMBO unisce le parti della combinazione", {
  res <- .resolve_contrast_entity_label("COMBO:il-13+il-4", env = .env_label())
  expect_equal(res$label, "il-13 + il-4")
  expect_equal(res$label_source, "combo_parts")
})

# --- fallimenti dichiarati, mai silenziosi ----------------------------------

test_that("ID valido ma assente dal dizionario NON inventa un'etichetta", {
  res <- .resolve_contrast_entity_label("CHEBI:999999999", env = .env_label())
  expect_true(is.na(res$label))
  expect_equal(res$label_source, "unresolved")
})

test_that("prefisso sconosciuto resta non risolto", {
  res <- .resolve_contrast_entity_label("PIPPO:123", env = .env_label())
  expect_true(is.na(res$label))
  expect_equal(res$label_source, "unknown_prefix")
})

test_that("il prefisso e' riconosciuto qualunque sia il maiuscolo/minuscolo", {
  # Difetto storico noto: lo stesso prefisso e' stato scritto `CHEMBL:` e
  # `ChEMBL:` su cluster diversi (~20 cluster, CLAUDE.md 2026-06-29).
  e <- .env_label()
  expect_equal(.resolve_contrast_entity_label("ChEMBL:CHEMBL_ENZA", env = e)$label,
               "Enzalutamide")
  expect_equal(.resolve_contrast_entity_label("chebi:16236", env = e)$label, "ethanol")
  expect_equal(.resolve_contrast_entity_label("MESH:D011471", env = e)$label,
               "Prostatic Neoplasms")
})

test_that("input degenere (NA, vuoto, senza prefisso) resta non risolto", {
  e <- .env_label()
  expect_true(is.na(.resolve_contrast_entity_label(NA_character_, env = e)$label))
  expect_true(is.na(.resolve_contrast_entity_label("", env = e)$label))
  expect_equal(.resolve_contrast_entity_label("", env = e)$label_source, "unknown_prefix")
  expect_true(is.na(.resolve_contrast_entity_label("vemurafenib", env = e)$label))
})

# --- versione vettoriale (serve per la tabella dei 305 gruppi) --------------

test_that("la versione vettoriale conserva ordine e lunghezza dell'input", {
  ids <- c("CHEBI:16236", "STR:tgf_b", "HGNC:6018", NA_character_)
  out <- .resolve_contrast_entity_labels(ids, env = .env_label())
  expect_equal(nrow(out), 4L)
  expect_equal(out$contrast_entity, ids)
  expect_equal(out$contrast_entity_label, c("ethanol", "tgf_b", "IL6", NA_character_))
  expect_equal(out$contrast_entity_label_source,
               c("chebi", "str_literal", "hgnc", "unknown_prefix"))
})

test_that("un ID ripetuto riceve sempre la stessa etichetta", {
  out <- .resolve_contrast_entity_labels(
    c("CHEBI:16236", "CHEBI:16236", "CHEBI:16412"), env = .env_label())
  expect_equal(out$contrast_entity_label, c("ethanol", "ethanol", "lipopolysaccharide"))
})

test_that("la versione vettoriale accetta un input vuoto senza errori", {
  out <- .resolve_contrast_entity_labels(character(0), env = .env_label())
  expect_equal(nrow(out), 0L)
  expect_true(all(c("contrast_entity", "contrast_entity_label",
                    "contrast_entity_label_source") %in% names(out)))
})
