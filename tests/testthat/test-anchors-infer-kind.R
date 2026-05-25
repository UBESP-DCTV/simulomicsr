# test-anchors-infer-kind.R --- TDD per infer_kind_from_ontology() +
# infer_kind_with_override() (override policy) in R/anchors.R.
#
# Decision tables spec sezione 4.3.

.fixt <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

# --- infer_kind_from_ontology: pure inference --------------------------------

test_that("Imiquimod CHEBI:36704 ('interferon inducer') --> cytokine_stim STRONG", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:36704", env = env)
  expect_equal(res$kind_resolved, "cytokine_stim")
  expect_equal(res$confidence, "STRONG")
  expect_match(res$role_evidence, "interferon inducer")
})

test_that("poly(I:C) CHEBI:84491 ('immunological adjuvant') --> pathogen STRONG", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:84491", env = env)
  expect_equal(res$kind_resolved, "pathogen_or_aggregate_exposure")
  expect_equal(res$confidence, "STRONG")
  expect_match(res$role_evidence, "adjuvant")
})

test_that("DMSO CHEBI:28262 ('polar aprotic solvent') --> vehicle_only STRONG", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:28262", env = env)
  expect_equal(res$kind_resolved, "vehicle_only")
  expect_equal(res$confidence, "STRONG")
  expect_match(res$role_evidence, "solvent")
})

test_that("Ethanol CHEBI:16236 ('polar solvent' + altre) --> vehicle_only STRONG (solvent vince su antiseptic)", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:16236", env = env)
  expect_equal(res$kind_resolved, "vehicle_only")
  expect_equal(res$confidence, "STRONG")
})

test_that("Doxorubicin CHEBI:28748 ('E. coli metabolite' only) --> small_molecule WEAK", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:28748", env = env)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$confidence, "WEAK")
  expect_match(res$role_evidence, "metabolite")
})

test_that("Carnitine CHEBI:17126 ('human metabolite') --> small_molecule WEAK", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:17126", env = env)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$confidence, "WEAK")
})

test_that("Heparin CHEBI:28304 ('anticoagulant' only) --> small_molecule MEDIUM (drug pattern)", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:28304", env = env)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$confidence, "MEDIUM")
})

test_that("Resiquimod CHEBI:36706 (0 roles, compound exists) --> ZERO_ROLES confidence (v3.1.1)", {
  # Resolver v3.1.1 (S1bis 2026-05-25): distinguere compound-non-existent (NONE)
  # da compound-exists-with-zero-roles (ZERO_ROLES). Quest'ultimo flag e' consumato
  # da infer_kind_with_override per emettere kind_chebi_zero_roles=TRUE su
  # tracking columns, senza override deterministico (sarebbe sbagliato per casi
  # legit come Resiquimod TLR7/8 agonist o poly(I:C) immunological adjuvant
  # che hanno annotazione role minima ma sono genuine pathogen/cytokine).
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:36706", env = env)
  expect_equal(res$confidence, "ZERO_ROLES")
  expect_true(is.na(res$kind_resolved))
})

test_that("dihydroxyphthalic CHEBI:17199 (0 roles) --> ZERO_ROLES confidence (v3.1.1)", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:17199", env = env)
  expect_equal(res$confidence, "ZERO_ROLES")
  expect_true(is.na(res$kind_resolved))
})

test_that("CHEBI:99999999 (compound non-existent) --> NONE (v3.1.1: NONE != ZERO_ROLES)", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:99999999", env = env)
  expect_equal(res$confidence, "NONE")
  expect_true(is.na(res$kind_resolved))
})

test_that("Epicatechin CHEBI:90 ('antioxidant') --> small_molecule MEDIUM (drug pattern)", {
  env <- .fixt()
  res <- infer_kind_from_ontology("CHEBI:90", env = env)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$confidence, "MEDIUM")
})

# --- MeSH inference: tree-based ----------------------------------------------

test_that("MeSH:D011471 Prostatic Neoplasms tree C --> disease_vs_normal STRONG", {
  env <- .fixt()
  res <- infer_kind_from_ontology("MeSH:D011471", env = env)
  expect_equal(res$kind_resolved, "disease_vs_normal")
  expect_equal(res$confidence, "STRONG")
})

test_that("MeSH:D011279 Pregnanetriol tree D (chemicals) --> small_molecule MEDIUM", {
  env <- .fixt()
  res <- infer_kind_from_ontology("MeSH:D011279", env = env)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$confidence, "MEDIUM")
})

test_that("MeSH UI inesistente --> NONE", {
  env <- .fixt()
  res <- infer_kind_from_ontology("MeSH:D999999", env = env)
  expect_equal(res$confidence, "NONE")
  expect_true(is.na(res$kind_resolved))
})

# --- HGNC / STR / UNK: NONE confidence ---------------------------------------

test_that("HGNC:11998 (TP53 gene): kind_resolved=NA confidence=NONE", {
  env <- .fixt()
  res <- infer_kind_from_ontology("HGNC:11998", env = env)
  expect_true(is.na(res$kind_resolved))
  expect_equal(res$confidence, "NONE")
})

test_that("STR:hypoxia --> NONE (no role inference da stringa libera)", {
  env <- .fixt()
  res <- infer_kind_from_ontology("STR:hypoxia", env = env)
  expect_equal(res$confidence, "NONE")
})

test_that("UNK --> NONE", {
  env <- .fixt()
  res <- infer_kind_from_ontology("UNK", env = env)
  expect_equal(res$confidence, "NONE")
})

test_that("NULL / empty input --> NONE", {
  env <- .fixt()
  expect_equal(infer_kind_from_ontology(NULL, env = env)$confidence, "NONE")
  expect_equal(infer_kind_from_ontology("", env = env)$confidence, "NONE")
  expect_equal(infer_kind_from_ontology(NA_character_, env = env)$confidence, "NONE")
})

# --- infer_kind_with_override: full override policy --------------------------

test_that("Ethanol LLM=cytokine_stim + STRONG vehicle_only --> OVERRIDE", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:16236", llm_kind = "cytokine_stim", env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "vehicle_only")
  expect_equal(res$override_reason, "ONTOLOGY_OVERRIDE_STRONG")
})

test_that("DMSO LLM=vehicle_only + STRONG vehicle_only --> MATCH (no override)", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:28262", llm_kind = "vehicle_only", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "vehicle_only")
  expect_true(is.na(res$override_reason))
  expect_equal(res$confidence, "STRONG")
})

test_that("DMSO LLM=small_molecule + STRONG vehicle_only --> OVERRIDE", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:28262", llm_kind = "small_molecule", env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "vehicle_only")
  expect_equal(res$override_reason, "ONTOLOGY_OVERRIDE_STRONG")
})

test_that("Imiquimod LLM=small_molecule + STRONG cytokine_stim --> OVERRIDE", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:36704", llm_kind = "small_molecule", env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "cytokine_stim")
  expect_equal(res$override_reason, "ONTOLOGY_OVERRIDE_STRONG")
})

test_that("poly(I:C) LLM=pathogen + STRONG pathogen --> MATCH (no override)", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:84491",
                                  llm_kind = "pathogen_or_aggregate_exposure",
                                  env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "pathogen_or_aggregate_exposure")
})

# --- LLM_CONTRADICTION_DETECTED: WEAK/MEDIUM evidence + LLM strong assertion -

test_that("Carnitine LLM=pathogen + WEAK metabolite --> OVERRIDE (LLM_CONTRADICTION)", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:17126",
                                  llm_kind = "pathogen_or_aggregate_exposure",
                                  env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$override_reason, "LLM_CONTRADICTION_DETECTED")
})

test_that("Carnitine LLM=small_molecule + WEAK metabolite --> MATCH (no override, compatible)", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:17126",
                                  llm_kind = "small_molecule", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "small_molecule")
})

test_that("Doxorubicin LLM=cytokine_stim + WEAK metabolite --> OVERRIDE", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:28748",
                                  llm_kind = "cytokine_stim", env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$override_reason, "LLM_CONTRADICTION_DETECTED")
})

test_that("Heparin LLM=cytokine_stim + MEDIUM small_molecule (anticoagulant) --> OVERRIDE", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:28304",
                                  llm_kind = "cytokine_stim", env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$override_reason, "LLM_CONTRADICTION_DETECTED")
})

test_that("Heparin LLM=differentiation + MEDIUM small_molecule --> no override (LLM non-strong)", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:28304",
                                  llm_kind = "differentiation", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "differentiation")
})

# --- NONE confidence: LLM preserved + kind_unvalidatable --------------------

test_that("Resiquimod (0 roles) LLM=pathogen --> preserved + kind_chebi_zero_roles=TRUE (v3.1.1)", {
  # v3.1.1: ZERO_ROLES NON triggera override (sarebbe sbagliato per Resiquimod
  # TLR agonist legit). LLM preserved. Flag kind_chebi_zero_roles=TRUE consumato
  # da Layer B shortlist per esclusione candidati a rischio.
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:36706",
                                  llm_kind = "pathogen_or_aggregate_exposure",
                                  env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "pathogen_or_aggregate_exposure")
  expect_equal(res$confidence, "ZERO_ROLES")
  expect_true(isTRUE(res$kind_chebi_zero_roles))
  expect_true(isTRUE(res$kind_unvalidatable))
})

test_that("dihydroxyphthalic (0 roles) LLM=pathogen --> preserved + flag kind_chebi_zero_roles (v3.1.1)", {
  # v3.1.1: stesso treatment di Resiquimod ma per compound chimico semplice
  # (acid). Layer B shortlist usera' il flag per escludere se altre evidence
  # mancano. Non distinguibile da Resiquimod via ChEBI alone (entrambi 0 roles).
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:17199",
                                  llm_kind = "pathogen_or_aggregate_exposure",
                                  env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "pathogen_or_aggregate_exposure")
  expect_equal(res$confidence, "ZERO_ROLES")
  expect_true(isTRUE(res$kind_chebi_zero_roles))
})

test_that("Resiquimod LLM=small_molecule + 0 roles --> preserved + flag (compatible)", {
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:36706",
                                  llm_kind = "small_molecule", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_true(isTRUE(res$kind_chebi_zero_roles))
})

test_that("CHEBI compound non-existent (no by_id hit) LLM=pathogen --> preserved + kind_chebi_zero_roles=FALSE", {
  # NONE != ZERO_ROLES. Compound non in ChEBI dict = HALLUCINATED prima
  # (gestito in resolve_agent_canonical), o solo prefix CHEBI: senza match.
  # infer_kind si limita a riportare NONE senza flag chebi_zero_roles.
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:99999999",
                                  llm_kind = "pathogen_or_aggregate_exposure",
                                  env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$confidence, "NONE")
  expect_false(isTRUE(res$kind_chebi_zero_roles))
})

test_that("HGNC:11998 (gene) LLM=genetic_overexpression --> preserved (gene kind_unvalidatable)", {
  env <- .fixt()
  res <- infer_kind_with_override("HGNC:11998",
                                  llm_kind = "genetic_overexpression", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "genetic_overexpression")
  expect_equal(res$confidence, "NONE")
})

# --- MeSH disease branch + LLM disease_vs_normal -----------------------------

test_that("MeSH:D011471 (tree C) + LLM=disease_vs_normal --> MATCH", {
  env <- .fixt()
  res <- infer_kind_with_override("MeSH:D011471",
                                  llm_kind = "disease_vs_normal", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "disease_vs_normal")
  expect_equal(res$confidence, "STRONG")
})

test_that("MeSH:D011279 Pregnanetriol (tree D) + LLM=disease_vs_normal --> OVERRIDE a small_molecule (v3.1.1)", {
  # v3.1.1 (S1bis 2026-05-25, audit case Pregnanetriol):
  # MeSH tree D = chemicals/drugs branch. Se LLM dichiara disease_vs_normal
  # ma MeSH tree_top indica chemicals (non disease), e' una contraddizione
  # paper-grade riconoscibile deterministicamente. OVERRIDE a kind ontology
  # con reason DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY.
  env <- .fixt()
  res <- infer_kind_with_override("MeSH:D011279",
                                  llm_kind = "disease_vs_normal", env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$override_reason, "DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY")
  expect_equal(res$confidence, "MEDIUM")
})

test_that("MeSH:D016899 Interferon-beta (tree D) + LLM=cytokine_stim --> no override (LLM non disease)", {
  # Regression: la nuova rule DISEASE_KIND_CONTRADICTED triggera SOLO quando
  # LLM=disease_vs_normal. Per altri LLM kinds, behavior invariato.
  env <- .fixt()
  res <- infer_kind_with_override("MeSH:D016899",
                                  llm_kind = "cytokine_stim", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "cytokine_stim")
})

test_that("CHEBI:17126 Carnitine + LLM=disease_vs_normal --> OVERRIDE small_molecule (drug pattern hits)", {
  # Carnitine ha 2 ChEBI roles: human metabolite, mouse metabolite --> WEAK
  # small_molecule. La rule DISEASE_KIND_CONTRADICTED triggera anche per CHEBI
  # (non solo MeSH) quando LLM=disease_vs_normal e onto inferisce kind diverso.
  env <- .fixt()
  res <- infer_kind_with_override("CHEBI:17126",
                                  llm_kind = "disease_vs_normal", env = env)
  expect_true(res$kind_overridden)
  expect_equal(res$kind_resolved, "small_molecule")
  expect_equal(res$override_reason, "DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY")
})

# --- STR / UNK input --------------------------------------------------------

test_that("STR:hypoxia + LLM=environmental --> preserved (NONE confidence)", {
  env <- .fixt()
  res <- infer_kind_with_override("STR:hypoxia",
                                  llm_kind = "environmental", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "environmental")
  expect_equal(res$confidence, "NONE")
})

test_that("UNK + LLM=none --> preserved", {
  env <- .fixt()
  res <- infer_kind_with_override("UNK", llm_kind = "none", env = env)
  expect_false(res$kind_overridden)
  expect_equal(res$kind_resolved, "none")
})
