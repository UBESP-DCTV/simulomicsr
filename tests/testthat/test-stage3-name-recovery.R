test_that(".parse_characteristics_kv: estrae coppie chiave:valore", {
  kv <- .parse_characteristics_kv("tissue: Blood, disease state: AD, cell type: PBMC")
  expect_equal(unname(kv[["disease state"]]), "ad")
  expect_equal(unname(kv[["tissue"]]), "blood")
  expect_equal(length(kv), 3L)
})

test_that(".parse_characteristics_kv: input vuoto/NA -> character(0)", {
  expect_length(.parse_characteristics_kv(NA_character_), 0L)
  expect_length(.parse_characteristics_kv(""), 0L)
})

test_that(".extract_disease_term: prende la malattia dalle characteristics", {
  d <- .extract_disease_term("Blood", "tissue: Blood, disease: Juvenile Dermatomyositis", "sample 1")
  expect_equal(d, "juvenile dermatomyositis")
})

test_that(".extract_disease_term: valori di controllo -> NA", {
  expect_true(is.na(.extract_disease_term("PBMC", "disease state: healthy", "ctrl")))
})

test_that(".extract_disease_term: fallback su source/title se niente chiave", {
  d <- .extract_disease_term("Breast Tumor", "tissue id: BRB123", "FFPE Breast Tumor sample")
  expect_equal(d, "breast tumor")
})

test_that(".extract_agent_term: prende il composto dal trattamento", {
  a <- .extract_agent_term("cells", "treatment: Bleomycin, time: 24h", "rep1")
  expect_equal(a, "bleomycin")
})

test_that(".extract_agent_term: veicolo/controllo -> NA", {
  expect_true(is.na(.extract_agent_term("cells", "treatment: DMSO", "vehicle 1")))
  expect_true(is.na(.extract_agent_term("cells", "treatment: control", "ctrl")))
})

test_that(".detect_genetic_perturbation: dTAG/degron -> genetico, non small_molecule", {
  r <- .detect_genetic_perturbation("HCT116", "cell line: HCT116", "POINT-Seq XRN2-dTAG minus dTAG rep1")
  expect_true(r$is_genetic)
  expect_match(r$genetic_kind, "genetic_")
  expect_equal(toupper(r$target), "XRN2")
})

test_that(".detect_genetic_perturbation: shRNA knockdown", {
  r <- .detect_genetic_perturbation("cells", "treatment: shTP53", "shRNA knockdown TP53")
  expect_true(r$is_genetic)
  expect_equal(r$genetic_kind, "genetic_knockdown")
})

test_that(".detect_genetic_perturbation: farmaco normale -> non genetico", {
  r <- .detect_genetic_perturbation("cells", "treatment: bleomycin", "Bleomycin 24h")
  expect_false(r$is_genetic)
})

# ---------------------------------------------------------------------------
# Canary C1 (review fix): la detection K2 deve essere case-SENSITIVE sui
# pattern di forma sh[A-Z]/si[A-Z]. Con ignore.case=TRUE molti composti/parole
# innocenti ("simvastatin", "sirolimus", "Resiquimod", "single cell",
# "serum depletion", "signal transduction") venivano flippati a genetic_*.
# ---------------------------------------------------------------------------

test_that("canary C1 NON-genetici: sh/si minuscolo non flippa a genetic", {
  not_genetic <- c(
    "simvastatin 10uM",
    "sirolimus",
    "Resiquimod TLR7/8 agonist",
    "single cell RNA-seq of lung",
    "serum depletion",
    "signal transduction"
  )
  for (txt in not_genetic) {
    r <- .detect_genetic_perturbation("cells", "treatment: sample", txt)
    expect_false(r$is_genetic, info = paste("falso positivo genetic su:", txt))
  }
})

test_that("canary C1 genetici: segnali inequivocabili restano genetic", {
  genetic <- c(
    "shXRN2 knockdown",
    "siTP53 siRNA",
    "XRN2-dTAG minus dTAG",
    "degron depletion",
    "CRISPR KO of TP53",
    "shRNA knockdown"
  )
  for (txt in genetic) {
    r <- .detect_genetic_perturbation("cells", "cell line: HCT116", txt)
    expect_true(r$is_genetic, info = paste("falso negativo genetic su:", txt))
  }
  # target estratto per il caso degron
  r_xrn2 <- .detect_genetic_perturbation("HCT116", "cell line: HCT116",
                                         "XRN2-dTAG minus dTAG")
  expect_equal(toupper(r_xrn2$target), "XRN2")
})

# ---------------------------------------------------------------------------
# Task 5 -- .normalize_disease_to_mesh
# ---------------------------------------------------------------------------

.fixt_mesh <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

test_that(".normalize_disease_to_mesh: sinonimi mappano allo stesso MeSH (G2)", {
  env <- .fixt_mesh()
  a <- .normalize_disease_to_mesh("prostate cancer", env)
  b <- .normalize_disease_to_mesh("prostatic cancer", env)
  expect_equal(a$id, b$id)
  expect_true(startsWith(a$id, "MeSH:"))
  expect_equal(a$id, "MeSH:D011471")
})

test_that(".normalize_disease_to_mesh: termine ignoto -> STR slug", {
  env <- .fixt_mesh()
  r <- .normalize_disease_to_mesh("xyzzy nonexistent disease", env)
  expect_true(startsWith(r$id, "STR:"))
  expect_equal(r$id, "STR:xyzzy_nonexistent_disease")
  expect_equal(r$source, "STR_FALLBACK")
})

test_that(".normalize_disease_to_mesh: NA/vuoto -> NA", {
  env <- .fixt_mesh()
  expect_equal(.normalize_disease_to_mesh(NA_character_, env)$id, NA_character_)
  expect_equal(.normalize_disease_to_mesh("", env)$id, NA_character_)
  expect_equal(.normalize_disease_to_mesh(NA_character_, env)$source, "NO_TERM")
})

test_that(".normalize_disease_to_mesh: nome leggibile popolato da $mh (G2)", {
  env <- .fixt_mesh()
  r <- .normalize_disease_to_mesh("prostate cancer", env)
  expect_false(is.na(r$name))
  expect_equal(r$name, "Prostatic Neoplasms")
  expect_equal(r$source, "MESH_NAME")
})

# ---------------------------------------------------------------------------
# Task 6 -- .normalize_compound_to_chebi
# ---------------------------------------------------------------------------

.fixt_chebi <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

test_that(".normalize_compound_to_chebi: ethanol -> CHEBI:16236", {
  env <- .fixt_chebi()
  r <- .normalize_compound_to_chebi("ethanol", env)
  expect_equal(r$id, "CHEBI:16236")
  expect_true(startsWith(r$id, "CHEBI:"))
  expect_equal(r$source, "CHEBI_ALIAS")
})

test_that(".normalize_compound_to_chebi: composti diversi -> id diversi non-NA", {
  env <- .fixt_chebi()
  a <- .normalize_compound_to_chebi("ethanol", env)
  b <- .normalize_compound_to_chebi("(-)-epicatechin", env)
  expect_false(is.na(a$id))
  expect_false(is.na(b$id))
  expect_false(a$id == b$id)
  expect_equal(a$id, "CHEBI:16236")
  expect_equal(b$id, "CHEBI:90")
})

test_that(".normalize_compound_to_chebi: termine ignoto -> STR slug", {
  env <- .fixt_chebi()
  r <- .normalize_compound_to_chebi("xyzzy nonexistent compound", env)
  expect_true(startsWith(r$id, "STR:"))
  expect_equal(r$source, "STR_FALLBACK")
})

test_that(".normalize_compound_to_chebi: NA/vuoto -> NA (NO_TERM)", {
  env <- .fixt_chebi()
  expect_equal(.normalize_compound_to_chebi(NA_character_, env)$id, NA_character_)
  expect_equal(.normalize_compound_to_chebi("", env)$id, NA_character_)
  expect_equal(.normalize_compound_to_chebi(NA_character_, env)$source, "NO_TERM")
})

test_that(".normalize_compound_to_chebi: nome leggibile popolato da primary_name", {
  env <- .fixt_chebi()
  r <- .normalize_compound_to_chebi("ethanol", env)
  expect_false(is.na(r$name))
  expect_match(r$name, "ethanol", ignore.case = TRUE)
})

# ---------------------------------------------------------------------------
# Task 7 -- recover_identity (orchestratore)
# ---------------------------------------------------------------------------

.test_ontology_env_min <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

test_that("recover_identity: disease_vs_normal -> agent_id MeSH/STR, kind invariato", {
  env <- .test_ontology_env_min()
  r <- recover_identity(
    source          = "prostate",
    characteristics = "tissue: prostate, disease: prostate cancer",
    title           = "S1",
    llm_kind        = "disease_vs_normal",
    ontology_env    = env
  )
  expect_true(startsWith(r$agent_id, "MeSH:") || startsWith(r$agent_id, "STR:"))
  expect_equal(r$kind, "disease_vs_normal")
  expect_false(is.null(r$canonical_name))
  expect_false(is.null(r$recovery_source))
})

test_that("recover_identity: K2 genetico mal-etichettato small_molecule -> kind corretto, agent_id HGNC:/STR:", {
  env <- .test_ontology_env_min()
  r <- recover_identity(
    source          = "HCT116",
    characteristics = "cell line: HCT116",
    title           = "XRN2-dTAG minus dTAG",
    llm_kind        = "small_molecule",
    ontology_env    = env
  )
  expect_match(r$kind, "genetic_")
  expect_true(startsWith(r$agent_id, "HGNC:") || startsWith(r$agent_id, "STR:"))
  expect_equal(r$recovery_source, "K2_GENETIC")
})

test_that("recover_identity: K2 target validato vs HGNC -> HGNC: solo se gene reale (I2)", {
  env <- .test_ontology_env_min()
  # Target reale (TP53 in fixture) -> HGNC:<symbol canonico>
  r_real <- recover_identity(
    source          = "cells",
    characteristics = "cell line: HCT116",
    title           = "shTP53 knockdown",
    llm_kind        = "small_molecule",
    ontology_env    = env
  )
  expect_match(r_real$kind, "^genetic_")
  expect_equal(r_real$agent_id, "HGNC:TP53")
  expect_equal(r_real$canonical_name, "TP53")

  # Token non-gene (DTMYC da una linea dTAG-MYC, assente da HGNC) -> NON HGNC:
  r_fake <- recover_identity(
    source          = "cells",
    characteristics = "cell line: HCT116",
    title           = "DTMYC-dTAG degron",
    llm_kind        = "small_molecule",
    ontology_env    = env
  )
  expect_match(r_fake$kind, "^genetic_")
  expect_false(is.na(r_fake$agent_id))
  expect_false(startsWith(r_fake$agent_id, "HGNC:"))
  expect_true(startsWith(r_fake$agent_id, "STR:"))
})

test_that("recover_identity: niente estraibile disease_vs_normal -> agent_id NA (regime U1)", {
  env <- .test_ontology_env_min()
  r <- recover_identity(
    source          = "blood",
    characteristics = "tissue: blood",
    title           = "sample",
    llm_kind        = "disease_vs_normal",
    ontology_env    = env
  )
  expect_true(is.na(r$agent_id))
  expect_equal(r$kind, "disease_vs_normal")
  expect_equal(r$recovery_source, "NO_RECOVERY")
})

test_that("recover_identity: kind perturbativo con composto estraibile -> CHEBI o STR", {
  env <- .test_ontology_env_min()
  r <- recover_identity(
    source          = "cells",
    characteristics = "treatment: ethanol, time: 24h",
    title           = "ethanol exposure rep1",
    llm_kind        = "small_molecule",
    ontology_env    = env
  )
  expect_true(startsWith(r$agent_id, "CHEBI:") || startsWith(r$agent_id, "STR:"))
  expect_equal(r$kind, "small_molecule")
})

test_that("recover_identity: kind perturbativo senza composto estraibile -> agent_id NA", {
  env <- .test_ontology_env_min()
  r <- recover_identity(
    source          = "cells",
    characteristics = "tissue: lung",
    title           = "rep1",
    llm_kind        = "cytokine_stim",
    ontology_env    = env
  )
  expect_true(is.na(r$agent_id))
  expect_equal(r$kind, "cytokine_stim")
  expect_equal(r$recovery_source, "NO_RECOVERY")
})

test_that("recover_identity: kind non perturbativo -> NO_RECOVERY, agent_id NA", {
  env <- .test_ontology_env_min()
  r <- recover_identity(
    source          = "cells",
    characteristics = "time: 24h",
    title           = "time course",
    llm_kind        = "time_course",
    ontology_env    = env
  )
  expect_true(is.na(r$agent_id))
  expect_equal(r$kind, "time_course")
  expect_equal(r$recovery_source, "NO_RECOVERY")
})

# ---------------------------------------------------------------------------
# Task 2 -- .extract_compound_candidates
# ---------------------------------------------------------------------------

test_that(".extract_compound_candidates: termine pulito -> se stesso", {
  cs <- .extract_compound_candidates("icotinib")
  expect_true("icotinib" %in% cs)
})

test_that(".extract_compound_candidates: spoglia dose/tempo", {
  cs <- .extract_compound_candidates("osimertinib 2 um 9d")
  expect_true("osimertinib" %in% cs)
})

test_that(".extract_compound_candidates: combo -> sotto-candidati separati", {
  cs <- .extract_compound_candidates("10 um enzalutamide and 30 nm onvansertib")
  expect_true("enzalutamide" %in% cs)
  expect_true("onvansertib" %in% cs)
})

test_that(".extract_compound_candidates: nome con underscore/numero interno preservato intero", {
  cs <- .extract_compound_candidates("kj pyr 9")
  expect_true("kj pyr 9" %in% cs)   # la stringa intera resta un candidato
})

test_that(".extract_compound_candidates: name+code separati -> token singoli candidati", {
  cs <- .extract_compound_candidates("cobimetinib gdc0973")
  expect_true("cobimetinib gdc0973" %in% cs)  # frase intera
  expect_true("cobimetinib" %in% cs)          # token
  expect_true("gdc0973" %in% cs)              # token
})

test_that(".extract_compound_candidates: input vuoto/NA -> character(0)", {
  expect_length(.extract_compound_candidates(NA_character_), 0L)
  expect_length(.extract_compound_candidates(""), 0L)
})
