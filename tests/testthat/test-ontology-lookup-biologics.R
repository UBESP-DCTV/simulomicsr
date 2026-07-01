# test-ontology-lookup-biologics.R --- TDD Task 1+2: NCBI Taxonomy + ImmPort
#
# Task 1: .build_taxonomy_index, .taxonomy_lookup_name, .taxonomy_rollup_to_species
# Task 2: .build_immport_index, .immport_lookup_synonym, .is_cytokine_symbol
#
# Tutti in isolamento: env costruiti localmente senza il loader completo.
# Fixture mini in inst/extdata/ontology-fixtures-mini/.

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

# ---------------------------------------------------------------------------
# Task 2: ImmPort — indice sinonimi citochine + whitelist HGNC
# ---------------------------------------------------------------------------

test_that(".build_immport_index restituisce struttura attesa (by_synonym, cytokine_symbols, meta)", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  idx <- .build_immport_index(raw)
  expect_type(idx, "list")
  expect_named(idx, c("by_synonym", "cytokine_symbols", "meta"), ignore.order = FALSE)
  expect_true(is.environment(idx$by_synonym))
  expect_true(is.environment(idx$cytokine_symbols))
  expect_equal(idx$meta$source, "immport-registry-2015+lkProteinName+GO")
})

test_that(".immport_lookup_synonym trova IFN-beta tramite normalizzazione greca", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$immport <- .build_immport_index(raw)
  # "IFN-beta" normalizzato -> "ifnbeta" (Greek letter + trattino rimossi)
  hit <- .immport_lookup_synonym("IFN-β", env = env)
  expect_false(is.null(hit))
  expect_equal(hit$hgnc_int, 5434L)
  expect_equal(hit$primary_symbol, "IFNB1")
})

test_that(".immport_lookup_synonym trova riferimento_name per IFN-beta", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$immport <- .build_immport_index(raw)
  hit <- .immport_lookup_synonym("IFN-β", env = env)
  expect_equal(hit$reference_name, "Interferon-beta")
})

test_that(".immport_lookup_synonym trova IL-6 per nome completo", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$immport <- .build_immport_index(raw)
  hit <- .immport_lookup_synonym("interleukin6", env = env)
  expect_false(is.null(hit))
  expect_equal(hit$hgnc_int, 6018L)
  expect_equal(hit$primary_symbol, "IL6")
})

test_that(".immport_lookup_synonym restituisce NULL per termine non-citochina (aspirin)", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$immport <- .build_immport_index(raw)
  expect_null(.immport_lookup_synonym("aspirin", env = env))
  expect_null(.immport_lookup_synonym(NA_character_, env = env))
  expect_null(.immport_lookup_synonym("", env = env))
})

test_that(".is_cytokine_symbol TRUE per HGNC ID in whitelist", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$immport <- .build_immport_index(raw)
  expect_true(.is_cytokine_symbol(5434L, env = env))   # IFNB1
  expect_true(.is_cytokine_symbol(6018L, env = env))   # IL6
  expect_true(.is_cytokine_symbol(11892L, env = env))  # TNF
})

test_that(".is_cytokine_symbol FALSE per HGNC ID non in whitelist", {
  raw <- readRDS(file.path(fx, "immport-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$immport <- .build_immport_index(raw)
  expect_false(.is_cytokine_symbol(99999L, env = env))
  expect_false(.is_cytokine_symbol(1L, env = env))
})

test_that(".immport_lookup_synonym e .is_cytokine_symbol difensivi su env senza immport", {
  env_vuoto <- new.env(parent = emptyenv())
  # env$immport assente -> NULL guard -> ritorna NULL / FALSE
  expect_null(.immport_lookup_synonym("IFN-β", env = env_vuoto))
  expect_false(.is_cytokine_symbol(5434L, env = env_vuoto))
})

# ---------------------------------------------------------------------------
# Task 3: UniProt --- indice sinonimi proteina -> HGNC
# ---------------------------------------------------------------------------

test_that(".build_uniprot_index restituisce struttura attesa (by_name, meta)", {
  raw <- readRDS(file.path(fx, "uniprot-mini.rds"))
  idx <- .build_uniprot_index(raw)
  expect_type(idx, "list")
  expect_named(idx, c("by_name", "meta"), ignore.order = FALSE)
  expect_true(is.environment(idx$by_name))
  expect_equal(idx$meta$source, "uniprot-sprot")
})

test_that(".uniprot_lookup_name trova interferon beta per hgnc_int e accession", {
  raw <- readRDS(file.path(fx, "uniprot-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$uniprot <- .build_uniprot_index(raw)
  # "interferon beta" normalizzato -> "interferonbeta" (chiave nel fixture)
  hit <- .uniprot_lookup_name("interferon beta", env = env)
  expect_false(is.null(hit))
  expect_equal(hit$hgnc_int, 5434L)
  expect_equal(hit$accession, "P01574")
})

test_that(".uniprot_lookup_name restituisce NULL per termine sconosciuto", {
  raw <- readRDS(file.path(fx, "uniprot-mini.rds"))
  env <- new.env(parent = emptyenv())
  env$uniprot <- .build_uniprot_index(raw)
  expect_null(.uniprot_lookup_name("aspirin", env = env))
  expect_null(.uniprot_lookup_name(NA_character_, env = env))
  expect_null(.uniprot_lookup_name("", env = env))
})

test_that(".uniprot_lookup_name difensivo su env senza uniprot (NULL)", {
  env_vuoto <- new.env(parent = emptyenv())
  # env$uniprot assente -> NULL guard -> ritorna NULL senza crash
  expect_null(.uniprot_lookup_name("interferon beta", env = env_vuoto))
})
