# test-stage3-anchor-biologics.R --- TDD Task 10 (biologici v6).
# Verifica che l'innesto recovery in .extract_anchor_segments() accetti
# override del kind anche per i kind biologici (cytokine_stim,
# pathogen_or_aggregate_exposure), non solo genetic_*. ADR-0018 / RED ALERT F6.

# ---------------------------------------------------------------------------
# Helper: fixture env mini-ontologia (identico a .fixt_env() in anchor-v31)
# ---------------------------------------------------------------------------
.fixt_env_bio10 <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

# Costruisce un sample_fact con perturbazione small_molecule + agente CHEBI
# risolto (carnitine CHEBI:17126 con kind="small_molecule" -> kind_effective
# ordinario = "small_molecule").
.make_fact_sm_chebi17126 <- function() {
  list(
    perturbations = list(list(
      kind             = "small_molecule",
      agent_normalized = list(
        id_database    = "CHEBI",
        id             = "17126",
        preferred_name = "carnitine",
        type           = "small_molecule"
      ),
      dose     = list(value_raw = "100ug/ml"),
      duration = list(value_raw = "24h"),
      phase    = "exposure"
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

# Costruisce un sample_fact disease con agent_id UNK (mesh_id_candidate = NULL)
# -> kind_effective ordinario = "disease_vs_normal", agent_id = "UNK".
.make_fact_unk_disease_bio10 <- function() {
  list(
    perturbations = list(),
    cell_context = list(
      cell_type_or_line_raw           = "PBMCs",
      cell_line_cellosaurus_candidate = NULL,
      context_kind                    = "primary_cells",
      cell_state                      = "proliferating",
      subcellular_fraction            = NULL,
      tissue                          = "blood",
      engineered_modifications        = list()
    ),
    disease_state = list(status = "case", mesh_id_candidate = NULL)
  )
}

# ---------------------------------------------------------------------------
# Test 1: pathogen_or_aggregate_exposure override del kind_effective small_molecule
# ---------------------------------------------------------------------------

test_that("bio recovery pathogen: kind small_molecule -> pathogen_or_aggregate_exposure", {
  env  <- .fixt_env_bio10()
  fact <- .make_fact_sm_chebi17126()
  rec  <- list(
    agent_id        = "CHEBI:16412",
    canonical_name  = "lipopolysaccharide",
    kind            = "pathogen_or_aggregate_exposure",
    recovery_source = "K3_MISTYPE_pathogen"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "treated", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # kind_effective aggiornato al valore biologico del recovery
  expect_equal(segs$kind_effective, "pathogen_or_aggregate_exposure")
  expect_equal(tm$kind_effective_resolved, "pathogen_or_aggregate_exposure")
  expect_true(tm$kind_recovered)
  expect_equal(tm$recovery_source, "K3_MISTYPE_pathogen")
})

# ---------------------------------------------------------------------------
# Test 2: cytokine_stim override del kind_effective small_molecule
# ---------------------------------------------------------------------------

test_that("bio recovery cytokine: kind small_molecule -> cytokine_stim", {
  env  <- .fixt_env_bio10()
  fact <- .make_fact_sm_chebi17126()
  rec  <- list(
    agent_id        = "HGNC:IFNB1",
    canonical_name  = "Interferon beta 1",
    kind            = "cytokine_stim",
    recovery_source = "K3_MISTYPE_cytokine"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "treated", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # kind_effective aggiornato a cytokine_stim
  expect_equal(segs$kind_effective, "cytokine_stim")
  expect_equal(tm$kind_effective_resolved, "cytokine_stim")
  expect_true(tm$kind_recovered)
  expect_equal(tm$recovery_source, "K3_MISTYPE_cytokine")
})

# ---------------------------------------------------------------------------
# Test 3: agent_id UNK + pathogen recovery -> entrambi (a) e (b) scattano
# ---------------------------------------------------------------------------

test_that("bio recovery pathogen su UNK disease: agent_id riscritto + kind corretto", {
  env  <- .fixt_env_bio10()
  fact <- .make_fact_unk_disease_bio10()
  rec  <- list(
    agent_id        = "CHEBI:16412",
    canonical_name  = "lipopolysaccharide",
    kind            = "pathogen_or_aggregate_exposure",
    recovery_source = "K3_MISTYPE_pathogen"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # (a) agent_id UNK -> CHEBI:16412 riscritto
  expect_equal(segs$agent_id, "CHEBI:16412")
  expect_true(tm$agent_id_recovered)

  # (b) kind_effective: disease_vs_normal -> pathogen_or_aggregate_exposure
  expect_equal(segs$kind_effective, "pathogen_or_aggregate_exposure")
  expect_equal(tm$kind_effective_resolved, "pathogen_or_aggregate_exposure")
  expect_true(tm$kind_recovered)
})

# ---------------------------------------------------------------------------
# Test 4: kind biologico UGUALE al kind_effective corrente -> kind_recovered = FALSE
# (nessuna sovrascrittura inutile)
# ---------------------------------------------------------------------------

test_that("bio recovery: kind == kind_effective ordinario -> kind_recovered = FALSE", {
  env  <- .fixt_env_bio10()
  fact <- .make_fact_sm_chebi17126()
  rec  <- list(
    agent_id        = "CHEBI:16412",
    canonical_name  = "lipopolysaccharide",
    kind            = "small_molecule",   # identico al kind_effective ordinario
    recovery_source = "GEO_TITLE_MESH"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "treated", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # kind_effective NON modificato (passo (b) non scatta se gia' uguale)
  expect_equal(segs$kind_effective, "small_molecule")
  expect_false(tm$kind_recovered)
})

# ---------------------------------------------------------------------------
# Test 5: retrocompat genetic_ ancora funziona con la nuova guardia (no regressione)
# (La condizione extended OR non deve rompere il passo K2 genetic_ esistente)
# ---------------------------------------------------------------------------

test_that("retrocompat: kind genetic_knockdown ancora sovrascrive kind_effective", {
  env  <- .fixt_env_bio10()
  fact <- .make_fact_unk_disease_bio10()
  rec  <- list(
    agent_id        = "MeSH:D001943",
    canonical_name  = "Breast Neoplasms",
    kind            = "genetic_knockdown",
    recovery_source = "GEO_CHARACTERISTICS_K2"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # Comportamento K2 genetic_ invariato
  expect_equal(segs$kind_effective, "genetic_knockdown")
  expect_equal(tm$kind_effective_resolved, "genetic_knockdown")
  expect_true(tm$kind_recovered)
  expect_equal(tm$recovery_source, "GEO_CHARACTERISTICS_K2")
})

# ---------------------------------------------------------------------------
# Test 6: cytokine_stim recovery su UNK disease + agent_id riscritto
# ---------------------------------------------------------------------------

test_that("bio recovery cytokine su UNK disease: agent_id riscritto + kind = cytokine_stim", {
  env  <- .fixt_env_bio10()
  fact <- .make_fact_unk_disease_bio10()
  rec  <- list(
    agent_id        = "HGNC:IFNB1",
    canonical_name  = "Interferon beta 1",
    kind            = "cytokine_stim",
    recovery_source = "K3_MISTYPE_cytokine"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # (a) agent_id riscritto
  expect_equal(segs$agent_id, "HGNC:IFNB1")
  expect_true(tm$agent_id_recovered)

  # (b) kind corretto a cytokine_stim
  expect_equal(segs$kind_effective, "cytokine_stim")
  expect_true(tm$kind_recovered)
})

# ---------------------------------------------------------------------------
# Test 7: recovery$kind biologico + recovery = NULL -> nessuna modifica (retrocompat)
# ---------------------------------------------------------------------------

test_that("senza recovery, kind_effective ordinario invariato (retrocompat recovery=NULL)", {
  env  <- .fixt_env_bio10()
  fact <- .make_fact_sm_chebi17126()

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "treated", ontology_env = env, recovery = NULL
  )
  tm <- attr(segs, "tracking_meta")

  # kind_effective = small_molecule, nessun campo kind_recovered
  expect_equal(segs$kind_effective, "small_molecule")
  expect_false("kind_recovered" %in% names(tm))
  # tracking_meta ha solo i 12 campi originali
  expect_length(tm, 12L)
})
