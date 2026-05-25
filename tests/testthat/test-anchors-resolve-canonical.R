# test-anchors-resolve-canonical.R --- TDD per R/anchors.R::resolve_agent_canonical()
#
# Copertura completa della decision table (spec §4.2): CHEBI_DIRECT,
# CHEBI_FIELDSWAP, CHEBI_SECONDARY_REDIRECT, WRONG_DB_to_HGNC, HGNC_DIRECT,
# HGNC_FIELDSWAP, HGNC_ENTREZ_MAPPED, MESH_DIRECT, MESH_FIELDSWAP, MESH_NAKED,
# STRING_ALIAS_CHEBI / _HGNC / _MESH, LLM_VEHICLE_LITERAL, CHEMBL_NAKED_NOLOOKUP,
# HALLUCINATED_OR_FALLBACK, NO_AGENT.

.fixt <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

# --- CHEBI primary path ------------------------------------------------------

test_that("CHEBI_DIRECT: id_database=CHEBI, id=17126, preferred_name='carnitine' --> CHEBI:17126", {
  env <- .fixt()
  agent <- list(id_database = "CHEBI", id = "17126",
                preferred_name = "carnitine", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:17126")
  expect_equal(res$canonical_name, "carnitine")
  expect_equal(res$resolution_source, "CHEBI_DIRECT")
})

test_that("CHEBI_DIRECT: id field con prefix 'CHEBI:17126' stripped correttamente", {
  env <- .fixt()
  agent <- list(id_database = "CHEBI", id = "CHEBI:17126",
                preferred_name = "carnitine", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:17126")
  expect_equal(res$resolution_source, "CHEBI_DIRECT")
})

test_that("CHEBI_DIRECT: id_database casing variants ('chebi', 'ChEBI')", {
  env <- .fixt()
  for (db in c("chebi", "ChEBI", "CHEBI", "Chebi")) {
    agent <- list(id_database = db, id = "16236",
                  preferred_name = "ethanol", type = "small_molecule")
    res <- resolve_agent_canonical(agent, env = env)
    expect_equal(res$canonical_id, "CHEBI:16236", info = paste("db=", db))
    expect_equal(res$resolution_source, "CHEBI_DIRECT")
  }
})

test_that("CHEBI_FIELDSWAP: id empty AND preferred_name='17126' numerico --> CHEBI:17126", {
  env <- .fixt()
  agent <- list(id_database = "CHEBI", id = "",
                preferred_name = "17126", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:17126")
  expect_equal(res$canonical_name, "carnitine")
  expect_equal(res$resolution_source, "CHEBI_FIELDSWAP")
})

test_that("CHEBI_FIELDSWAP: id NULL AND preferred_name='17126' numerico --> CHEBI:17126", {
  env <- .fixt()
  agent <- list(id_database = "CHEBI", id = NULL,
                preferred_name = "17126", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:17126")
  expect_equal(res$resolution_source, "CHEBI_FIELDSWAP")
})

test_that("CHEBI_SECONDARY_REDIRECT: id_database=CHEBI, id='18484' (secondary --> primary 90)", {
  env <- .fixt()
  agent <- list(id_database = "CHEBI", id = "18484",
                preferred_name = "epicatechin", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:90")
  expect_equal(res$resolution_source, "CHEBI_SECONDARY_REDIRECT")
})

# --- HGNC primary path -------------------------------------------------------

test_that("HGNC_DIRECT: id_database=HGNC, id='11998' --> HGNC:11998 (TP53)", {
  env <- .fixt()
  agent <- list(id_database = "HGNC", id = "11998",
                preferred_name = "TP53", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "HGNC:11998")
  expect_equal(res$canonical_name, "TP53")
  expect_equal(res$resolution_source, "HGNC_DIRECT")
})

test_that("HGNC_FIELDSWAP: id_database=HGNC, id empty, preferred_name='11998'", {
  env <- .fixt()
  agent <- list(id_database = "HGNC", id = "",
                preferred_name = "11998", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "HGNC:11998")
  expect_equal(res$resolution_source, "HGNC_FIELDSWAP")
})

test_that("HGNC_ENTREZ_MAPPED: id_database=HGNC, id='7157' (Entrez TP53) --> HGNC:11998", {
  env <- .fixt()
  agent <- list(id_database = "HGNC", id = "7157",
                preferred_name = "TP53", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "HGNC:11998")
  expect_equal(res$resolution_source, "HGNC_ENTREZ_MAPPED")
})

# --- Cross-DB: WRONG_DB_to_HGNC ----------------------------------------------

test_that("WRONG_DB_to_HGNC: id_database=CHEBI ma id=11998 (TP53 in HGNC, NON in ChEBI)", {
  env <- .fixt()
  agent <- list(id_database = "CHEBI", id = "11998",
                preferred_name = "compound-x", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "HGNC:11998")
  expect_equal(res$resolution_source, "WRONG_DB_to_HGNC")
})

# --- MeSH primary path -------------------------------------------------------

test_that("MESH_DIRECT: id_database=MeSH, id='D011279' --> MeSH:D011279", {
  env <- .fixt()
  agent <- list(id_database = "MeSH", id = "D011279",
                preferred_name = "Pregnanetriol", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "MeSH:D011279")
  expect_equal(res$canonical_name, "Pregnanetriol")
  expect_equal(res$resolution_source, "MESH_DIRECT")
})

test_that("MESH_FIELDSWAP: id_database=MeSH, id empty, preferred_name='D011279'", {
  env <- .fixt()
  agent <- list(id_database = "MeSH", id = "",
                preferred_name = "D011279", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "MeSH:D011279")
  expect_equal(res$resolution_source, "MESH_FIELDSWAP")
})

test_that("MESH casing 'MESH' / 'mesh' / 'Mesh' tutti riconosciuti", {
  env <- .fixt()
  for (db in c("MESH", "mesh", "Mesh", "MeSH")) {
    agent <- list(id_database = db, id = "D011471",
                  preferred_name = "Prostatic Neoplasms", type = "disease")
    res <- resolve_agent_canonical(agent, env = env)
    expect_equal(res$canonical_id, "MeSH:D011471", info = paste("db=", db))
  }
})

# --- String alias resolution (id_database NULL/empty) ------------------------

test_that("STRING_ALIAS_CHEBI: id_database empty, preferred_name='resiquimod' --> CHEBI:36706", {
  env <- .fixt()
  agent <- list(id_database = "", id = "",
                preferred_name = "resiquimod", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:36706")
  expect_equal(res$resolution_source, "STRING_ALIAS_CHEBI")
})

test_that("STRING_ALIAS_CHEBI: id_database NULL, preferred_name 'Polyinosinic-polycytidylic acid'", {
  env <- .fixt()
  agent <- list(id_database = NULL, id = NULL,
                preferred_name = "polyinosinic-polycytidylic acid",
                type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:84491")
  expect_equal(res$resolution_source, "STRING_ALIAS_CHEBI")
})

test_that("STRING_ALIAS_HGNC: id_database empty, preferred_name='TP53' --> HGNC:11998", {
  env <- .fixt()
  agent <- list(id_database = "", id = "",
                preferred_name = "TP53", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "HGNC:11998")
  expect_equal(res$resolution_source, "STRING_ALIAS_HGNC")
})

test_that("STRING_ALIAS_HGNC via alias: preferred_name='il-6' --> HGNC:6018", {
  env <- .fixt()
  agent <- list(id_database = NULL, id = NULL,
                preferred_name = "il-6", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "HGNC:6018")
  expect_equal(res$canonical_name, "IL6")
  expect_equal(res$resolution_source, "STRING_ALIAS_HGNC")
})

test_that("STRING_ALIAS_MESH: preferred_name='interferon beta' --> MeSH:D016899", {
  env <- .fixt()
  agent <- list(id_database = "", id = "",
                preferred_name = "Interferon beta", type = "cytokine")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "MeSH:D016899")
  expect_equal(res$resolution_source, "STRING_ALIAS_MESH")
})

# --- MESH_NAKED (id_database empty, ma preferred_name = "D\\d+") -------------

test_that("MESH_NAKED: id_database empty, preferred_name='D011279' --> MeSH:D011279", {
  env <- .fixt()
  agent <- list(id_database = NULL, id = NULL,
                preferred_name = "D011279", type = "disease")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "MeSH:D011279")
  expect_equal(res$resolution_source, "MESH_NAKED")
})

# --- LLM_VEHICLE_LITERAL -----------------------------------------------------

test_that("LLM_VEHICLE_LITERAL: type=vehicle, preferred_name='DMSO' --> STR:dmso", {
  env <- .fixt()
  agent <- list(id_database = NULL, id = NULL,
                preferred_name = "DMSO", type = "vehicle")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "STR:dmso")
  expect_equal(res$resolution_source, "LLM_VEHICLE_LITERAL")
})

test_that("LLM_VEHICLE_LITERAL: type=vehicle, preferred_name='PBS' --> STR:pbs", {
  env <- .fixt()
  agent <- list(id_database = "", id = "",
                preferred_name = "PBS", type = "vehicle")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "STR:pbs")
  expect_equal(res$resolution_source, "LLM_VEHICLE_LITERAL")
})

# --- CHEMBL_NAKED_NOLOOKUP ---------------------------------------------------

test_that("CHEMBL_NAKED_NOLOOKUP: id_database=ChEMBL --> ChEMBL:<id>, opaque", {
  env <- .fixt()
  agent <- list(id_database = "ChEMBL", id = "CHEMBL1201626",
                preferred_name = "doxorubicin-hcl", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "ChEMBL:CHEMBL1201626")
  expect_equal(res$resolution_source, "CHEMBL_NAKED_NOLOOKUP")
})

# --- HALLUCINATED_OR_FALLBACK + STRING_NO_ALIAS_MATCH ------------------------

test_that("HALLUCINATED_OR_FALLBACK: CHEBI ID inesistente, preferred_name non-alias", {
  env <- .fixt()
  agent <- list(id_database = "CHEBI", id = "9999999",
                preferred_name = "9999999", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_match(res$canonical_id, "^STR:")
  expect_equal(res$resolution_source, "HALLUCINATED_OR_FALLBACK")
})

test_that("STRING_NO_ALIAS_MATCH: id_database empty, preferred_name 'Hypoxia' --> STR:hypoxia", {
  env <- .fixt()
  agent <- list(id_database = NULL, id = NULL,
                preferred_name = "Hypoxia", type = "environmental")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "STR:hypoxia")
  expect_equal(res$resolution_source, "STRING_NO_ALIAS_MATCH")
})

# --- NO_AGENT ----------------------------------------------------------------

test_that("NO_AGENT: agent_normalized NULL --> UNK", {
  env <- .fixt()
  res <- resolve_agent_canonical(NULL, env = env)
  expect_equal(res$canonical_id, "UNK")
  expect_true(is.na(res$canonical_name))
  expect_equal(res$resolution_source, "NO_AGENT")
})

test_that("NO_AGENT: type='none' --> UNK", {
  env <- .fixt()
  agent <- list(id_database = NULL, id = NULL,
                preferred_name = NULL, type = "none")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "UNK")
  expect_equal(res$resolution_source, "NO_AGENT")
})

test_that("NO_AGENT: tutti i campi empty --> UNK", {
  env <- .fixt()
  agent <- list(id_database = "", id = "", preferred_name = "", type = "")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "UNK")
  expect_equal(res$resolution_source, "NO_AGENT")
})

# --- Edge: id_database CHEBI ma preferred_name e' alias --------------------

test_that("id_database=CHEBI con id empty: prima prova fieldswap, poi alias", {
  env <- .fixt()
  # preferred_name "ethanol" e' alias di CHEBI 16236
  agent <- list(id_database = "CHEBI", id = "",
                preferred_name = "ethanol", type = "small_molecule")
  res <- resolve_agent_canonical(agent, env = env)
  expect_equal(res$canonical_id, "CHEBI:16236")
  expect_equal(res$resolution_source, "STRING_ALIAS_CHEBI")
})
