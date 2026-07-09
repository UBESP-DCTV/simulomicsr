# test-stage3-anchor-v31.R --- Integration test per anchor v3.1 (ADR-0018).
# Verifica che .extract_anchor_segments() produca tracking_meta corretto su
# casi paradigmatici dell'audit 2026-05-24 (field-swap, kind override,
# disease MeSH, mediated_effect HGNC).

.fixt_env <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

# Costruisce un sample_fact compatibile con stage1.v3 con perturbation custom.
.make_fact_with_perturbation <- function(agent_normalized, kind = "small_molecule") {
  list(
    perturbations = list(list(
      kind             = kind,
      agent_normalized = agent_normalized,
      dose             = list(value_raw = "100ng/ml"),
      duration         = list(value_raw = "6h"),
      phase            = "exposure"
    )),
    cell_context = list(
      cell_type_or_line_raw           = "HEK293",
      cell_line_cellosaurus_candidate = "CVCL_0045",
      context_kind                    = "cell_line",
      cell_state                      = "proliferating",
      subcellular_fraction            = NULL,
      tissue                          = "kidney",
      engineered_modifications        = list()
    ),
    disease_state = list(status = "healthy", mesh_id_candidate = NULL)
  )
}

# --- Caso paradigmatico 1: CHEBI field-swap Carnitine-as-pathogen ------------

test_that("Carnitine field-swap + LLM=pathogen --> resolved CHEBI:17126 + kind OVERRIDE", {
  env <- .fixt_env()
  # LLM emette CHEBI:NULL + preferred_name="17126" (numero nel campo sbagliato)
  # + kind="pathogen_or_aggregate_exposure" (wrong, Carnitine e' metabolite)
  agent <- list(id_database = "CHEBI", id = NULL,
                preferred_name = "17126",
                type = "small_molecule")
  fact <- .make_fact_with_perturbation(agent, kind = "pathogen_or_aggregate_exposure")

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "CHEBI:17126")
  expect_equal(tm$resolution_source, "CHEBI_FIELDSWAP")
  expect_equal(tm$canonical_name, "carnitine")

  # Kind override: LLM=pathogen ma roles=metabolite -> LLM_CONTRADICTION_DETECTED
  expect_equal(segs$kind_effective, "small_molecule")
  expect_equal(tm$kind_effective_llm_original, "pathogen_or_aggregate_exposure")
  expect_equal(tm$kind_effective_resolved, "small_molecule")
  expect_true(tm$kind_overridden)
  expect_equal(tm$kind_override_reason, "LLM_CONTRADICTION_DETECTED")
  expect_equal(tm$kind_confidence, "WEAK")
})

# --- Caso paradigmatico 2: Ethanol-as-cytokine LLM error ---------------------

test_that("Ethanol CHEBI:16236 + LLM=cytokine_stim --> STRONG vehicle_only OVERRIDE", {
  env <- .fixt_env()
  agent <- list(id_database = "CHEBI", id = "16236",
                preferred_name = "ethanol",
                type = "cytokine")
  fact <- .make_fact_with_perturbation(agent, kind = "cytokine_stimulation")

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "CHEBI:16236")
  expect_equal(tm$resolution_source, "CHEBI_DIRECT")
  expect_equal(segs$kind_effective, "vehicle_only")
  expect_true(tm$kind_overridden)
  expect_equal(tm$kind_override_reason, "ONTOLOGY_OVERRIDE_STRONG")
  expect_equal(tm$kind_confidence, "STRONG")
})

# --- Caso paradigmatico 3: DMSO LLM=vehicle_only match -----------------------

test_that("DMSO CHEBI:28262 + LLM=vehicle_only --> MATCH (no override)", {
  env <- .fixt_env()
  agent <- list(id_database = "CHEBI", id = "28262",
                preferred_name = "DMSO",
                type = "vehicle")
  # Per type="vehicle" + preferred_name non-empty triggera LLM_VEHICLE_LITERAL
  # NON il path ChEBI canonical. Resta come "STR:dmso" con kind=vehicle_only.
  fact <- .make_fact_with_perturbation(agent, kind = "vehicle_only")

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "STR:dmso")
  expect_equal(tm$resolution_source, "LLM_VEHICLE_LITERAL")
  # kind preserved (no role evidence per STR:)
  expect_equal(segs$kind_effective, "vehicle_only")
})

# --- Caso paradigmatico 4: Resiquimod 0 roles --> NONE, LLM preserved -------

test_that("Resiquimod CHEBI:36706 (0 roles) + LLM=pathogen --> preserved + kind_unvalidatable", {
  env <- .fixt_env()
  agent <- list(id_database = "CHEBI", id = "36706",
                preferred_name = "resiquimod",
                type = "small_molecule")
  fact <- .make_fact_with_perturbation(agent,
                                       kind = "pathogen_or_aggregate_exposure")

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "CHEBI:36706")
  expect_equal(tm$resolution_source, "CHEBI_DIRECT")
  expect_equal(segs$kind_effective, "pathogen_or_aggregate_exposure")
  expect_false(tm$kind_overridden)
  expect_true(tm$kind_unvalidatable)
  # v3.1.1: ZERO_ROLES emesso al posto di NONE quando compound esiste in ChEBI
  # ma ha 0 has_role (case Resiquimod TLR agonist legit). Tracking column
  # kind_chebi_zero_roles=TRUE consumato da Layer B shortlist filter.
  expect_equal(tm$kind_confidence, "ZERO_ROLES")
  expect_true(isTRUE(tm$kind_chebi_zero_roles))
})

# --- Caso paradigmatico 5: poly(I:C) STRONG match LLM=pathogen --------------

test_that("poly(I:C) CHEBI:84491 + LLM=pathogen --> STRONG match (no override)", {
  env <- .fixt_env()
  agent <- list(id_database = "CHEBI", id = "84491",
                preferred_name = "Polyinosinic-polycytidylic acid",
                type = "small_molecule")
  fact <- .make_fact_with_perturbation(agent,
                                       kind = "pathogen_or_aggregate_exposure")

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "CHEBI:84491")
  expect_equal(segs$kind_effective, "pathogen_or_aggregate_exposure")
  expect_false(tm$kind_overridden)
  expect_equal(tm$kind_confidence, "STRONG")
  expect_match(tm$kind_role_evidence, "adjuvant")
})

# --- Caso paradigmatico 6: disease_vs_normal MeSH ---------------------------

test_that("disease_vs_normal con MeSH:D011471 (Prostatic Neoplasms) --> resolved", {
  env <- .fixt_env()
  fact <- .make_fact_with_perturbation(agent_normalized = NULL, kind = "none")
  fact$disease_state$status <- "case"
  fact$disease_state$mesh_id_candidate <- "D011471"

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "case",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$kind_effective, "disease_vs_normal")
  expect_equal(segs$agent_id, "MeSH:D011471")
  expect_equal(tm$resolution_source, "MESH_DIRECT")
  expect_equal(tm$canonical_name, "Prostatic Neoplasms")
})

test_that("disease MeSH UI valido ma assente nella release --> MESH_NAKED_NOLOOKUP", {
  env <- .fixt_env()  # fixture mini-MeSH non ha D003920
  fact <- .make_fact_with_perturbation(agent_normalized = NULL, kind = "none")
  fact$disease_state$status <- "case"
  fact$disease_state$mesh_id_candidate <- "D003920"

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "case",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "MeSH:D003920")
  expect_equal(tm$resolution_source, "MESH_NAKED_NOLOOKUP")
})

# --- Caso paradigmatico 6bis (v3.1.1): Pregnanetriol MeSH D04 sterol --------

test_that("v3.1.1 audit fix: Pregnanetriol MeSH:D011279 tree D + LLM=disease --> OVERRIDE small_molecule", {
  # Audit case 4/4 (S1bis 2026-05-25): MeSH D011279 e' uno sterol (tree D04),
  # NON una disease (tree C). LLM assertava disease_vs_normal via role=case;
  # rule DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY (anchor v3.1.1) demote a
  # small_molecule per chiudere l'audit set.
  env <- .fixt_env()
  fact <- .make_fact_with_perturbation(agent_normalized = NULL, kind = "none")
  fact$disease_state$status <- "case"
  fact$disease_state$mesh_id_candidate <- "D011279"

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "case",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "MeSH:D011279")
  expect_equal(tm$resolution_source, "MESH_DIRECT")
  expect_equal(tm$canonical_name, "Pregnanetriol")
  expect_equal(segs$kind_effective, "small_molecule")
  expect_true(tm$kind_overridden)
  expect_equal(tm$kind_override_reason, "DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY")
  expect_false(isTRUE(tm$kind_chebi_zero_roles))
})

# --- Caso paradigmatico 4bis (v3.1.1): dihydroxyphthalic CHEBI 0 roles ------

test_that("v3.1.1 audit fix: dihydroxyphthalic CHEBI:17199 LLM=pathogen --> preserved + kind_chebi_zero_roles", {
  # Audit case 2/4 (S1bis 2026-05-25): CHEBI:17199 esiste ma ha 0 has_role
  # in ChEBI (acido organico senza role annotation). NOT distinguibile da
  # Resiquimod CHEBI:36706 (TLR7/8 agonist legit con 0 roles ChEBI) via
  # ChEBI alone. Soluzione: flag kind_chebi_zero_roles=TRUE (LLM preserved)
  # per Layer B shortlist filter, no override deterministico.
  env <- .fixt_env()
  agent <- list(id_database = "CHEBI", id = "17199",
                preferred_name = "4,5-dihydroxyphthalic acid",
                type = "small_molecule")
  fact <- .make_fact_with_perturbation(agent,
                                       kind = "pathogen_or_aggregate_exposure")

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "CHEBI:17199")
  expect_equal(tm$resolution_source, "CHEBI_DIRECT")
  expect_equal(segs$kind_effective, "pathogen_or_aggregate_exposure")  # preserved
  expect_false(tm$kind_overridden)
  expect_true(isTRUE(tm$kind_chebi_zero_roles))
  expect_equal(tm$kind_confidence, "ZERO_ROLES")
  expect_true(isTRUE(tm$kind_unvalidatable))
})

# --- Caso paradigmatico 7: mediated_effect HGNC ------------------------------

test_that("mediated_effect target=TP53 --> resolved HGNC:11998 via STRING_ALIAS_HGNC", {
  env <- .fixt_env()
  agent <- list(id_database = "Tet-On", id = "doxycycline",
                preferred_name = "doxycycline", type = "small_molecule")
  fact <- list(
    perturbations = list(list(
      kind             = "small_molecule",
      agent_normalized = agent,
      mediated_effect  = list(
        kind    = "genetic_overexpression",
        targets = list("TP53")
      ),
      dose     = list(value_raw = "1ug/ml"),
      duration = list(value_raw = "24h"),
      phase    = "exposure"
    )),
    cell_context = list(
      cell_type_or_line_raw = "HEK293",
      cell_line_cellosaurus_candidate = "CVCL_0045",
      context_kind = "cell_line",
      cell_state = "proliferating",
      subcellular_fraction = NULL,
      tissue = "kidney",
      engineered_modifications = list()
    ),
    disease_state = list(status = "healthy", mesh_id_candidate = NULL)
  )

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  expect_equal(segs$agent_id, "HGNC:11998")
  expect_equal(tm$resolution_source, "STRING_ALIAS_HGNC")
  expect_equal(segs$kind_effective, "genetic_overexpression")
  expect_true(tm$kind_unvalidatable)  # gene HGNC kind=NONE
})

test_that("mediated_effect target=NONEXISTENT --> MEDIATED_STR_NO_LOOKUP fallback", {
  env <- .fixt_env()
  fact <- list(
    perturbations = list(list(
      kind             = "small_molecule",
      agent_normalized = list(id_database = "Tet-On", id = "dox",
                              preferred_name = "doxycycline",
                              type = "small_molecule"),
      mediated_effect  = list(
        kind    = "genetic_overexpression",
        targets = list("NONEXISTENT_GENE_XYZ")
      ),
      dose     = list(value_raw = "1ug/ml"),
      duration = list(value_raw = "24h"),
      phase    = "exposure"
    )),
    cell_context = list(
      cell_type_or_line_raw = "HEK293",
      cell_line_cellosaurus_candidate = "CVCL_0045",
      context_kind = "cell_line",
      cell_state = "proliferating",
      subcellular_fraction = NULL,
      tissue = "kidney",
      engineered_modifications = list()
    ),
    disease_state = list(status = "healthy", mesh_id_candidate = NULL)
  )

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)
  tm <- attr(segs, "tracking_meta")

  # Fix F6 v9 Task 1: target mediato ignoto a HGNC -> STR:<grezzo> (non piu'
  # HGNC:<grezzo> fabbricato), resolution_source MEDIATED_STR_NO_LOOKUP.
  expect_equal(segs$agent_id, "STR:NONEXISTENT_GENE_XYZ")
  expect_equal(tm$resolution_source, "MEDIATED_STR_NO_LOOKUP")
})

# --- 13-segment interface invariata + tracking_meta attribute ----------------

test_that("Output e' un named list di 13 segmenti (no pollution da tracking_meta)", {
  env <- .fixt_env()
  agent <- list(id_database = "CHEBI", id = "16236", preferred_name = "ethanol",
                type = "small_molecule")
  fact <- .make_fact_with_perturbation(agent)
  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated",
                                                 ontology_env = env)

  expect_length(segs, 13L)
  expect_named(segs, c(
    "kind_effective", "agent_id", "variant_label", "dose_canonical",
    "duration_canonical", "phase_canonical", "cell_id", "context_kind",
    "cell_state", "subcellular", "tissue", "disease_status", "has_engineered"
  ))
  # tracking_meta NON e' un name di segs (e' un attribute)
  expect_false("tracking_meta" %in% names(segs))
  expect_true(!is.null(attr(segs, "tracking_meta")))
  # tracking_meta ha 12 campi attesi (v3.1.1 aggiunge kind_chebi_zero_roles)
  tm <- attr(segs, "tracking_meta")
  expect_named(tm, c(
    "agent_id_llm_original", "agent_id_resolved", "resolution_source",
    "canonical_name",
    "kind_effective_llm_original", "kind_effective_resolved",
    "kind_overridden", "kind_override_reason",
    "kind_role_evidence", "kind_confidence", "kind_unvalidatable",
    "kind_chebi_zero_roles"
  ))
})
