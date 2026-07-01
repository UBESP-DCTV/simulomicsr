# test-ontology-lookup-biologics.R --- TDD Task 1: indice + accessor NCBI Taxonomy
#
# Testa .build_taxonomy_index, .taxonomy_lookup_name, .taxonomy_rollup_to_species
# in isolamento: l'env viene costruito localmente senza il loader completo
# (.load_ontology_dicts), che verra' esteso al Task 4.
# La mini-fixture e' in inst/extdata/ontology-fixtures-mini/taxonomy-mini.rds.

fx <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")

test_that(".build_taxonomy_index restituisce la struttura attesa (by_name, by_taxid, meta)", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  expect_type(idx, "list")
  expect_named(idx, c("by_name", "by_taxid", "meta"), ignore.order = FALSE)
  expect_true(is.environment(idx$by_name))
  expect_true(is.environment(idx$by_taxid))
  expect_equal(idx$meta$source, "taxdump")
})

test_that(".taxonomy_lookup_name trova SARS-CoV-2 per nome normalizzato (synonym)", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  env <- new.env(parent = emptyenv()); env$taxonomy <- idx
  # "SARS-CoV-2" -> normalize_biological_mention -> "sarscov2" (sinonimo nel fixture)
  hit <- .taxonomy_lookup_name("SARS-CoV-2", env = env)
  expect_false(is.null(hit))
  expect_equal(hit$taxid, 2697049L)
  expect_equal(hit$name_class, "synonym")
})

test_that(".taxonomy_lookup_name trova anche il sinonimo sarscov2", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  env <- new.env(parent = emptyenv()); env$taxonomy <- idx
  # "SARS-CoV-2" dopo normalize_biological_mention diventa "sarscov2"
  # (rimuove trattini e maiuscole)
  hit <- .taxonomy_lookup_name("SARSCoV2", env = env)
  expect_false(is.null(hit))
  expect_equal(hit$taxid, 2697049L)
})

test_that(".taxonomy_lookup_name restituisce NULL per termine sconosciuto", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  env <- new.env(parent = emptyenv()); env$taxonomy <- idx
  expect_null(.taxonomy_lookup_name("definitely-not-an-organism", env = env))
  expect_null(.taxonomy_lookup_name(NA_character_, env = env))
  expect_null(.taxonomy_lookup_name("", env = env))
})

test_that(".taxonomy_rollup_to_species sale dal sierotipo alla specie (211044 -> 11320)", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  env <- new.env(parent = emptyenv()); env$taxonomy <- idx
  # 211044L = "Influenza A virus (A/PR/8/34(H1N1))", rank=serotype, parent=11320
  # 11320L  = "Influenza A virus", rank=species
  expect_equal(.taxonomy_rollup_to_species(211044L, env = env), 11320L)
})

test_that(".taxonomy_rollup_to_species ritorna invariato per taxid gia' a livello specie", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  env <- new.env(parent = emptyenv()); env$taxonomy <- idx
  expect_equal(.taxonomy_rollup_to_species(1773L, env = env), 1773L)
  expect_equal(.taxonomy_rollup_to_species(2697049L, env = env), 2697049L)
})

test_that(".taxonomy_rollup_to_species e' difensivo su taxid assente nell'indice", {
  raw <- readRDS(file.path(fx, "taxonomy-mini.rds"))
  idx <- .build_taxonomy_index(raw)
  env <- new.env(parent = emptyenv()); env$taxonomy <- idx
  # taxid inesistente: rollup ritorna taxid invariato (non crasha)
  result <- .taxonomy_rollup_to_species(9999999L, env = env)
  expect_equal(result, 9999999L)
})

test_that(".taxonomy_lookup_name gestisce env senza taxonomy (NULL) in modo difensivo", {
  env_vuoto <- new.env(parent = emptyenv())
  # env$taxonomy assente => NULL, accessor deve tornare NULL senza crash
  expect_null(.taxonomy_lookup_name("SARS-CoV-2", env = env_vuoto))
})

test_that(".taxonomy_rollup_to_species gestisce env senza taxonomy (NULL) in modo difensivo", {
  env_vuoto <- new.env(parent = emptyenv())
  # env$taxonomy assente => NULL, accessor deve tornare taxid invariato
  expect_equal(.taxonomy_rollup_to_species(1773L, env = env_vuoto), 1773L)
})
