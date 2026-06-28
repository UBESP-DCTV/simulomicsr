# test-ontology-lookup.R --- TDD copertura per R/ontology-lookup.R
#
# Verifica loader (.load_ontology_dicts), accessor ChEBI/HGNC/MeSH,
# refresh policy, meta release.
#
# Le fixture mini-dict sono in inst/extdata/ontology-fixtures-mini/
# (build da analysis/p5-build-ontology-fixtures.R).

.fixture_dir <- function() {
  # Priorita': system.file (works during R CMD check on installed package
  # AND devtools::test che gestisce inst/ magic).
  d <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (nzchar(d) && dir.exists(d)) return(d)
  # Fallback per esecuzione raw (es. testthat::test_file diretto)
  testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
}

test_that(".load_ontology_dicts carica fixture mini e popola env", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_true(isTRUE(env$loaded))
  expect_true(!is.null(env$chebi))
  expect_true(!is.null(env$hgnc))
  expect_true(!is.null(env$mesh))
})

test_that(".load_ontology_dicts caching: refresh=FALSE riusa env, refresh=TRUE reload", {
  env1 <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  env2 <- .load_ontology_dicts(refresh = FALSE)
  expect_identical(env1, env2)  # stesso singleton
  # refresh=TRUE deve forzare reload (chebi$meta$built_at presente)
  env3 <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_true(!is.null(env3$chebi$meta$built_at))
})

# --- ChEBI accessor ----------------------------------------------------------

test_that(".chebi_lookup_id ritorna primary_name + ascii_name + is_obsolete", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  carn <- .chebi_lookup_id(17126L, env = env)
  expect_equal(carn$primary_name, "carnitine")
  expect_equal(carn$ascii_name, "carnitine")
  expect_false(carn$is_obsolete)
  expect_true(is.na(carn$parent_id))
})

test_that(".chebi_lookup_id ritorna NULL per chebi_id inesistente", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_null(.chebi_lookup_id(999999999L, env = env))
})

test_that(".chebi_lookup_id accetta integer numerico o character", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_equal(.chebi_lookup_id(17126L, env = env)$primary_name, "carnitine")
  expect_equal(.chebi_lookup_id("17126", env = env)$primary_name, "carnitine")
})

test_that(".chebi_lookup_alias ethanol --> 16236", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  res <- .chebi_lookup_alias("ethanol", env = env)
  expect_equal(res$chebi_id, 16236L)
  # Tipi alias ChEBI: PRIMARY, SYNONYM, IUPAC NAME, UNIPROT NAME, BRAND NAME, INN, ASCII NAME
  expect_true(is.character(res$type) && nzchar(res$type))
})

test_that(".chebi_lookup_alias case-insensitive ('Ethanol' --> 16236)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_equal(.chebi_lookup_alias("Ethanol", env = env)$chebi_id, 16236L)
  expect_equal(.chebi_lookup_alias("ETHANOL", env = env)$chebi_id, 16236L)
})

test_that(".chebi_lookup_alias resiquimod --> 36706", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_equal(.chebi_lookup_alias("resiquimod", env = env)$chebi_id, 36706L)
})

test_that(".chebi_lookup_alias polyinosinic-polycytidylic acid --> 84491", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_equal(
    .chebi_lookup_alias("polyinosinic-polycytidylic acid", env = env)$chebi_id,
    84491L
  )
})

test_that(".chebi_lookup_alias NULL per alias inesistente", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_null(.chebi_lookup_alias("nonexistent-compound-xyz-abc", env = env))
})

test_that(".chebi_roles ritorna character vector per Ethanol (polar solvent + altre)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  roles <- .chebi_roles(16236L, env = env)
  expect_true(is.character(roles))
  expect_true("polar solvent" %in% roles)
  expect_true("neurotoxin" %in% roles)
})

test_that(".chebi_roles ritorna 'human metabolite' per Carnitine", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  roles <- .chebi_roles(17126L, env = env)
  expect_true("human metabolite" %in% roles)
})

test_that(".chebi_roles ritorna character(0) per compound senza roles (Resiquimod)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  roles <- .chebi_roles(36706L, env = env)
  expect_true(is.character(roles))
  expect_equal(length(roles), 0L)
})

test_that(".chebi_roles ritorna character(0) per chebi_id inesistente (non NULL)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  roles <- .chebi_roles(999999999L, env = env)
  expect_true(is.character(roles))
  expect_equal(length(roles), 0L)
})

test_that(".chebi_secondary_redirect 18484 --> 90 (epicatechin)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_equal(.chebi_secondary_redirect(18484L, env = env), 90L)
})

test_that(".chebi_secondary_redirect NULL per id non-secondary", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  # 17126 e' primary (Carnitine), non secondary
  expect_null(.chebi_secondary_redirect(17126L, env = env))
})

# --- HGNC accessor -----------------------------------------------------------

test_that(".hgnc_lookup_hgnc 11998 --> TP53 + entrez 7157", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  res <- .hgnc_lookup_hgnc(11998L, env = env)
  expect_equal(res$symbol, "TP53")
  expect_equal(res$entrez_int, 7157L)
  expect_equal(res$locus_group, "protein-coding gene")
})

test_that(".hgnc_lookup_hgnc NULL per hgnc_int inesistente", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_null(.hgnc_lookup_hgnc(999999L, env = env))
})

test_that(".hgnc_lookup_entrez 7157 --> TP53 (hgnc_int 11998)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  res <- .hgnc_lookup_entrez(7157L, env = env)
  expect_equal(res$symbol, "TP53")
  expect_equal(res$hgnc_int, 11998L)
})

test_that(".hgnc_lookup_symbol case-insensitive 'TP53' / 'tp53'", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_equal(.hgnc_lookup_symbol("TP53", env = env)$hgnc_int, 11998L)
  expect_equal(.hgnc_lookup_symbol("tp53", env = env)$hgnc_int, 11998L)
})

test_that(".hgnc_lookup_symbol risolve via alias (il-6 --> IL6 hgnc_int 6018)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  res <- .hgnc_lookup_symbol("il-6", env = env)
  expect_equal(res$hgnc_int, 6018L)
  expect_equal(res$primary_symbol, "IL6")
})

test_that(".hgnc_lookup_symbol NULL per simbolo inesistente", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_null(.hgnc_lookup_symbol("nonexistent-gene-xyz", env = env))
})

# --- MeSH accessor -----------------------------------------------------------

test_that(".mesh_lookup_ui D011279 (Pregnanetriol) tree_top=D", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  res <- .mesh_lookup_ui("D011279", env = env)
  expect_equal(res$mh, "Pregnanetriol")
  expect_equal(res$tree_top, "D")
})

test_that(".mesh_lookup_ui D011471 (Prostatic Neoplasms) tree_top=C", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  res <- .mesh_lookup_ui("D011471", env = env)
  expect_equal(res$mh, "Prostatic Neoplasms")
  expect_equal(res$tree_top, "C")
})

test_that(".mesh_lookup_ui NULL per UI inesistente", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_null(.mesh_lookup_ui("D999999", env = env))
})

test_that(".mesh_lookup_term 'interferon beta' --> D016899", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  res <- .mesh_lookup_term("interferon beta", env = env)
  expect_equal(res$ui, "D016899")
})

test_that(".mesh_lookup_term case-insensitive 'Interferon Beta'", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_equal(.mesh_lookup_term("Interferon Beta", env = env)$ui, "D016899")
})

test_that(".mesh_lookup_term NULL per termine inesistente", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_null(.mesh_lookup_term("nonexistent-mesh-term", env = env))
})

# --- Release meta ------------------------------------------------------------

test_that(".ontology_release_meta ritorna chebi + hgnc + mesh meta", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  meta <- .ontology_release_meta(env = env)
  expect_true("chebi" %in% names(meta))
  expect_true("hgnc"  %in% names(meta))
  expect_true("mesh"  %in% names(meta))
  expect_true(!is.null(meta$chebi$built_at))
  expect_true(meta$chebi$n_compounds > 0L)
  expect_true(meta$hgnc$n_genes > 0L)
  expect_true(meta$mesh$n_descriptors > 0L)
})

# --- ChEMBL accessor ---------------------------------------------------------

test_that(".load_ontology_dicts carica ChEMBL + accessor alias/id O(1)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_true(!is.null(env$chembl))
  # alias diretto -> molecola
  hit <- .chembl_lookup_alias("icotinib", env = env)
  expect_equal(hit$chembl_id, "CHEMBL_ICOTINIB")
  # case-insensitive
  expect_equal(.chembl_lookup_alias("ICOTINIB", env = env)$chembl_id, "CHEMBL_ICOTINIB")
  # research code -> stessa molecola
  expect_equal(.chembl_lookup_alias("gdc0973", env = env)$chembl_id, "CHEMBL_COBI")
  # by_id -> pref_name
  expect_equal(.chembl_lookup_id("CHEMBL_COBI", env = env)$pref_name, "Cobimetinib")
  # miss -> NULL
  expect_null(.chembl_lookup_alias("nonesiste_xyz", env = env))
  expect_null(.chembl_lookup_id("CHEMBL_ZZZ", env = env))
  # input degenere -> NULL (difensivo)
  expect_null(.chembl_lookup_alias(NA_character_, env = env))
  expect_null(.chembl_lookup_alias(character(0), env = env))
})

test_that(".ontology_release_meta include chembl", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  rel <- .ontology_release_meta(env)
  expect_true(!is.null(rel$chembl))
  expect_true(isTRUE(rel$chembl$fixture_subset))
})

# --- ChEMBL graceful (chembl=NULL) -------------------------------------------

test_that("ChEMBL graceful: accessor con env$chembl NULL -> NULL (no errore)", {
  fake <- list(chembl = NULL)
  expect_null(.chembl_lookup_alias("icotinib", env = fake))
  expect_null(.chembl_lookup_id("CHEMBL_X", env = fake))
})

test_that("ChEMBL caricato da fixture -> has_chembl TRUE", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fixture_dir())
  expect_true(isTRUE(env$has_chembl))
  expect_false(is.null(env$chembl))
})
