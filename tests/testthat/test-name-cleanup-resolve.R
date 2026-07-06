test_that(".resolve_canonical_to_id risolve small_molecule via ChEBI", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("aspirin", "small_molecule", env = list()),
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "aspirin"))
      list(chebi_id = 15365L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "CHEBI:15365")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id ritorna NONE su miss", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("qwerty", "small_molecule", env = list()),
    .chebi_lookup_alias = function(alias, env) NULL, .package = "simulomicsr")
  expect_true(is.na(res$resolved_id))
  expect_equal(res$match_strength, "NONE")
})

test_that(".resolve_canonical_to_id risolve disease via MeSH e pathogen via taxonomy", {
  d <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("Breast Neoplasms", "disease_vs_normal", env = list()),
    .mesh_lookup_term = function(term, env) list(ui = "D001943"), .package = "simulomicsr")
  expect_equal(d$resolved_id, "MeSH:D001943")
  p <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("SARS-CoV-2", "pathogen_or_aggregate_exposure", env = list()),
    .taxonomy_lookup_name = function(term, env) list(taxid = 2697049L), .package = "simulomicsr")
  expect_equal(p$resolved_id, "NCBITaxon:2697049")
})

test_that(".resolve_canonical_to_id su alias HGNC ritorna il simbolo canonico, non l'input grezzo", {
  # "BSF2" e' un alias storico di IL6: l'accessor risolve all'alias ma ritorna
  # il primary_symbol canonico. L'ID deve riflettere IL6, non "BSF2" (bug
  # critico: prima usava toupper(nm) sull'input grezzo, rompendo il dedup).
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("BSF2", "cytokine_stim", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) if (identical(tolower(symbol), "bsf2"))
      list(hgnc_int = 6015L, primary_symbol = "IL6", match_type = "ALIAS") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "HGNC:IL6")
  expect_equal(res$resolved_name, "IL6")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id cytokine_stim ricade su ChEBI quando HGNC non risolve", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("poly(I:C)", "cytokine_stim", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) NULL,
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "poly(i:c)"))
      list(chebi_id = 84491L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "CHEBI:84491")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id con kind character(0)/NA non va in errore (fallback catch-all)", {
  res0 <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("aspirin", character(0), env = list()),
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "aspirin"))
      list(chebi_id = 15365L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res0$resolved_id, "CHEBI:15365")

  resNA <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("aspirin", NA_character_, env = list()),
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "aspirin"))
      list(chebi_id = 15365L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(resNA$resolved_id, "CHEBI:15365")
})
