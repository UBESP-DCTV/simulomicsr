# test-stage3-anchor-name-recovery.R --- TDD Task 9 (FASE 3 rework Stadio 3).
# Verifica che .extract_anchor_segments() consulti il record `recovery`
# (prodotto da Task 8 / build_name_recovery_lookup) per correggere
# agent_id UNK e kind genetico (K2). Retrocompat con recovery = NULL garantita.

# ---------------------------------------------------------------------------
# Helper: fixture env mini-ontologia (identico a .fixt_env() in anchor-v31)
# ---------------------------------------------------------------------------
.fixt_env_nr <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata", "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

# Costruisce un sample_fact che produce agent_id == "UNK":
# design disease senza MeSH (mesh_id_candidate = NULL -> "unknown" -> NO_AGENT).
.make_fact_unk_disease <- function() {
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

# Record recovery tipico per il caso disease UNK -> MeSH corretto.
.recovery_disease <- function() {
  list(
    agent_id       = "MeSH:D001943",
    canonical_name = "Breast Neoplasms",
    kind           = "disease_vs_normal",
    recovery_source = "GEO_TITLE_MESH"
  )
}

# ---------------------------------------------------------------------------
# Caso 1: recovery applicato -- agent_id UNK diventa MeSH:D001943
# ---------------------------------------------------------------------------

test_that("recovery: agent_id UNK + recovery$agent_id valido -> segmento corretto", {
  env <- .fixt_env_nr()
  fact <- .make_fact_unk_disease()
  rec  <- .recovery_disease()

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # Segmento agent_id aggiornato
  expect_equal(segs$agent_id, "MeSH:D001943")

  # tracking_meta riflette il recovery
  expect_equal(tm$agent_id_resolved, "MeSH:D001943")
  expect_equal(tm$canonical_name,    "Breast Neoplasms")

  # agent_id_llm_original preserva il valore pre-recovery (audit trace)
  expect_equal(tm$agent_id_llm_original, "unknown")

  # Traccia recovery
  expect_true(tm$agent_id_recovered)
  expect_false(tm$kind_recovered)
  expect_equal(tm$recovery_source, "GEO_TITLE_MESH")
})

# ---------------------------------------------------------------------------
# Caso 2: retrocompat -- senza recovery, agent_id resta UNK, tracking_meta 12 campi
# ---------------------------------------------------------------------------

test_that("retrocompat: recovery = NULL -> agent_id resta UNK, tracking_meta 12 campi", {
  env <- .fixt_env_nr()
  fact <- .make_fact_unk_disease()

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = NULL
  )
  tm <- attr(segs, "tracking_meta")

  # Nessuna modifica all'agent_id
  expect_equal(segs$agent_id, "UNK")

  # tracking_meta ha ESATTAMENTE i 12 campi attesi (nessun campo recovery aggiunto)
  expect_named(tm, c(
    "agent_id_llm_original", "agent_id_resolved", "resolution_source",
    "canonical_name",
    "kind_effective_llm_original", "kind_effective_resolved",
    "kind_overridden", "kind_override_reason",
    "kind_role_evidence", "kind_confidence", "kind_unvalidatable",
    "kind_chebi_zero_roles"
  ))

  # 12 campi esatti
  expect_length(tm, 12L)
})

# ---------------------------------------------------------------------------
# Caso 3: correzione K2 -- recovery$kind genetico differisce -> kind_effective
# ---------------------------------------------------------------------------

test_that("recovery K2: kind genetico differisce da kind attuale -> segs$kind_effective corretto", {
  env <- .fixt_env_nr()
  fact <- .make_fact_unk_disease()
  # Recovery indica che il campione era un knockdown, non disease_vs_normal
  rec_k2 <- list(
    agent_id        = "MeSH:D001943",
    canonical_name  = "Breast Neoplasms",
    kind            = "genetic_knockdown",
    recovery_source = "GEO_CHARACTERISTICS_K2"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec_k2
  )
  tm <- attr(segs, "tracking_meta")

  # (a) agent_id corretto
  expect_equal(segs$agent_id, "MeSH:D001943")
  expect_true(tm$agent_id_recovered)

  # (b) kind_effective corretto (era disease_vs_normal, recovery dice genetic_knockdown)
  expect_equal(segs$kind_effective, "genetic_knockdown")
  expect_equal(tm$kind_effective_resolved, "genetic_knockdown")
  expect_true(tm$kind_recovered)
  expect_equal(tm$recovery_source, "GEO_CHARACTERISTICS_K2")
})

# ---------------------------------------------------------------------------
# Caso 4: recovery$agent_id = NA con segmento UNK -> resta UNK (non sostituire)
# ---------------------------------------------------------------------------

test_that("recovery$agent_id = NA -> agent_id resta UNK, agent_id_recovered = FALSE", {
  env <- .fixt_env_nr()
  fact <- .make_fact_unk_disease()
  rec_na <- list(
    agent_id        = NA_character_,
    canonical_name  = NA_character_,
    kind            = "disease_vs_normal",
    recovery_source = "GEO_TITLE_UNRESOLVED"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec_na
  )
  tm <- attr(segs, "tracking_meta")

  # Non sostituisce con NA
  expect_equal(segs$agent_id, "UNK")
  expect_false(tm$agent_id_recovered)
  # I 3 campi traccia sono presenti (recovery non-NULL)
  expect_true("recovery_source" %in% names(tm))
  expect_equal(tm$recovery_source, "GEO_TITLE_UNRESOLVED")
  expect_length(tm, 15L)  # 12 originali + 3 recovery
})

# ---------------------------------------------------------------------------
# Caso 4b: recovery$agent_id valido (non-NA) + recovery$kind = NA_character_
# -> agent_id sostituito (a), kind NON corretto (b), nessun crash.
# Verifica il guard !is.na(recovery$kind) aggiunto come review fix Task 9.
# ---------------------------------------------------------------------------

test_that("recovery$kind = NA_character_ + agent_id valido -> no crash, (a) scatta, (b) no", {
  env <- .fixt_env_nr()
  fact <- .make_fact_unk_disease()
  rec_kind_na <- list(
    agent_id        = "MeSH:D001943",
    canonical_name  = "Breast Neoplasms",
    kind            = NA_character_,  # kind mancante (llm_kind assente in GSM)
    recovery_source = "GEO_TITLE_MESH"
  )

  # (i) Non deve generare errori (crash ante-fix: startsWith(NA, ...) -> if(NA))
  segs <- expect_no_error(
    simulomicsr:::.extract_anchor_segments(
      fact, stage2_role = "case", ontology_env = env, recovery = rec_kind_na
    )
  )
  tm <- attr(segs, "tracking_meta")

  # (ii) Caso (a): agent_id UNK -> MeSH:D001943 (recovery$agent_id e' non-NA)
  expect_equal(segs$agent_id, "MeSH:D001943")
  expect_true(tm$agent_id_recovered)

  # (iii) Caso (b) non scatta: kind_effective rimane disease_vs_normal (no K2)
  expect_equal(segs$kind_effective, "disease_vs_normal")

  # (iv) kind_recovered = FALSE (la correzione K2 non e' stata applicata)
  expect_false(tm$kind_recovered)
})

# ---------------------------------------------------------------------------
# Caso 5: recovery con kind NON-genetico diverso -> kind_effective invariato
# ---------------------------------------------------------------------------

test_that("recovery kind non-genetico diverso -> kind_effective invariato, kind_recovered=FALSE", {
  env <- .fixt_env_nr()
  fact <- .make_fact_unk_disease()
  # Recovery suggerisce small_molecule (non inizia con "genetic_") -> non applicato (K2 only)
  rec_sm <- list(
    agent_id        = "MeSH:D001943",
    canonical_name  = "Breast Neoplasms",
    kind            = "small_molecule",
    recovery_source = "GEO_TITLE_MESH"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec_sm
  )
  tm <- attr(segs, "tracking_meta")

  # kind_effective non modificato (solo K2 genetico applicato)
  expect_equal(segs$kind_effective, "disease_vs_normal")
  expect_false(tm$kind_recovered)
  # agent_id corretto (la correzione (a) avviene indipendentemente)
  expect_equal(segs$agent_id, "MeSH:D001943")
  expect_true(tm$agent_id_recovered)
})

# ---------------------------------------------------------------------------
# Caso 6: agent_id NON-UNK + recovery -> agent_id NON sostituito (solo UNK)
# ---------------------------------------------------------------------------

test_that("se agent_id e' gia' risolto (non UNK), recovery non lo sovrascrive", {
  env <- .fixt_env_nr()
  # Fact con MeSH esplicito -> agent_id = "MeSH:D011471" (non UNK)
  fact_mesh <- list(
    perturbations = list(),
    cell_context = list(
      cell_type_or_line_raw = "prostate cells",
      cell_line_cellosaurus_candidate = NULL,
      context_kind = "primary_cells",
      cell_state = "proliferating",
      subcellular_fraction = NULL,
      tissue = "prostate",
      engineered_modifications = list()
    ),
    disease_state = list(status = "case", mesh_id_candidate = "D011471")
  )
  rec <- list(
    agent_id        = "MeSH:D001943",  # diverso da D011471
    canonical_name  = "Breast Neoplasms",
    kind            = "disease_vs_normal",
    recovery_source = "GEO_TITLE_MESH"
  )

  segs <- simulomicsr:::.extract_anchor_segments(
    fact_mesh, stage2_role = "case", ontology_env = env, recovery = rec
  )
  tm <- attr(segs, "tracking_meta")

  # agent_id rimane quello calcolato dalla pipeline, NON sostituito
  expect_equal(segs$agent_id, "MeSH:D011471")
  expect_false(tm$agent_id_recovered)
})

# ---------------------------------------------------------------------------
# Caso 7: segs ha 13 elementi anche con recovery attivo
# ---------------------------------------------------------------------------

test_that("con recovery attivo, segs ha ancora 13 segmenti (tracking_meta in attr)", {
  env <- .fixt_env_nr()
  fact <- .make_fact_unk_disease()
  rec  <- .recovery_disease()

  segs <- simulomicsr:::.extract_anchor_segments(
    fact, stage2_role = "case", ontology_env = env, recovery = rec
  )

  # segs e' ancora un named list di 13 elementi
  expect_length(segs, 13L)
  expect_named(segs, c(
    "kind_effective", "agent_id", "variant_label", "dose_canonical",
    "duration_canonical", "phase_canonical", "cell_id", "context_kind",
    "cell_state", "subcellular", "tissue", "disease_status", "has_engineered"
  ))
  # tracking_meta ha 15 campi (12 + 3 recovery)
  tm <- attr(segs, "tracking_meta")
  expect_length(tm, 15L)
  expect_true(all(c("recovery_source", "agent_id_recovered", "kind_recovered") %in% names(tm)))
})
