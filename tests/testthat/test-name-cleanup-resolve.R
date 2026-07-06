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
