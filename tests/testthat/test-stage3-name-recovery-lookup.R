# test-stage3-name-recovery-lookup.R — TDD per build_name_recovery_lookup (Task 8)
#
# Copre: (a) GSM malattia -> agent_id MeSH/STR; (b) GSM degron mal-etichettato
# -> kind genetic_*; (c) GSM povero -> agent_id NA; (d) GSM assente dall'H5 ->
# assente dall'env; (e) kind_by_gsm mancante -> NA_character_ llm_kind;
# (f) struttura output; (g) cache su disco.

# ---------------------------------------------------------------------------
# Helper fixture ontologie (pattern identico a .test_ontology_env_min()
# in test-stage3-name-recovery.R e a .fixt_env() in test-stage3-anchor-v31.R)
# ---------------------------------------------------------------------------

.fixt_env_nrl <- function() {
  fixture_dir <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")
  if (!nzchar(fixture_dir) || !dir.exists(fixture_dir)) {
    fixture_dir <- testthat::test_path("..", "..", "inst", "extdata",
                                       "ontology-fixtures-mini")
  }
  .load_ontology_dicts(refresh = TRUE, fixture_dir = fixture_dir)
}

# ---------------------------------------------------------------------------
# Mock read_fn: inietta i 5 vettori senza leggere un H5 reale.
# GSM001: prostate cancer (disease_vs_normal) -> MeSH:D011471 o STR:
# GSM002: XRN2-dTAG (mal-etichettato small_molecule) -> K2 genetic_knockdown
# GSM003: campione povero (nessun termine estraibile) -> NO_RECOVERY
# ---------------------------------------------------------------------------

.mock_h5_reader_nrl <- function(h5_path) {
  list(
    geo_accession       = c("GSM001", "GSM002", "GSM003"),
    series_id           = c("GSE001", "GSE001", "GSE001"),
    source_name_ch1     = c("prostate", "HCT116", "lung tissue"),
    characteristics_ch1 = c(
      "tissue: prostate, disease: prostate cancer",
      "cell line: HCT116",
      "tissue: lung"
    ),
    title = c(
      "Patient prostate cancer sample",
      "POINT-Seq XRN2-dTAG minus dTAG rep1",
      "lung normal sample"
    )
  )
}

# ---------------------------------------------------------------------------
# (a) GSM malattia: prostate cancer + kind=disease_vs_normal -> agent_id MeSH/STR
# ---------------------------------------------------------------------------

test_that("build_name_recovery_lookup (a): GSM malattia -> agent_id MeSH/STR", {
  env <- .fixt_env_nrl()
  lookup <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM001",
    kind_by_gsm  = list(GSM001 = "disease_vs_normal"),
    ontology_env = env,
    read_fn      = .mock_h5_reader_nrl
  )
  expect_true(is.environment(lookup))
  res <- lookup[["GSM001"]]
  expect_false(is.null(res))
  expect_equal(res$kind, "disease_vs_normal")
  # prostate cancer e' nella fixture MeSH (D011471) -> MeSH:, ma STR: e' accettabile
  expect_true(startsWith(res$agent_id, "MeSH:") || startsWith(res$agent_id, "STR:"))
  expect_false(is.null(res$recovery_source))
})

# Caso specifico: fixture mini-MeSH contiene D011471 -> "Prostatic Neoplasms"
test_that("build_name_recovery_lookup (a2): prostate cancer -> MeSH:D011471 con fixture", {
  env <- .fixt_env_nrl()
  lookup <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM001",
    kind_by_gsm  = list(GSM001 = "disease_vs_normal"),
    ontology_env = env,
    read_fn      = .mock_h5_reader_nrl
  )
  res <- lookup[["GSM001"]]
  expect_equal(res$agent_id, "MeSH:D011471")
  expect_equal(res$recovery_source, "MESH_NAME")
})

# ---------------------------------------------------------------------------
# (b) GSM degron mal-etichettato small_molecule -> K2 correzione genetic_*
# ---------------------------------------------------------------------------

test_that("build_name_recovery_lookup (b): GSM degron K2 -> kind genetic_*", {
  env <- .fixt_env_nrl()
  lookup <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM002",
    kind_by_gsm  = list(GSM002 = "small_molecule"),
    ontology_env = env,
    read_fn      = .mock_h5_reader_nrl
  )
  res <- lookup[["GSM002"]]
  expect_false(is.null(res))
  expect_match(res$kind, "^genetic_")
  expect_equal(res$recovery_source, "K2_GENETIC")
  # agent_id deve essere HGNC:XRN2 o almeno HGNC:
  expect_true(startsWith(res$agent_id, "HGNC:"))
})

# ---------------------------------------------------------------------------
# (c) GSM povero (nessun termine estraibile) -> agent_id NA, NO_RECOVERY
# ---------------------------------------------------------------------------

test_that("build_name_recovery_lookup (c): GSM povero -> agent_id NA, NO_RECOVERY", {
  env <- .fixt_env_nrl()
  lookup <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM003",
    kind_by_gsm  = list(GSM003 = "disease_vs_normal"),
    ontology_env = env,
    read_fn      = .mock_h5_reader_nrl
  )
  res <- lookup[["GSM003"]]
  expect_false(is.null(res))
  expect_true(is.na(res$agent_id))
  expect_equal(res$recovery_source, "NO_RECOVERY")
  expect_equal(res$kind, "disease_vs_normal")
})

# ---------------------------------------------------------------------------
# (d) GSM assente dall'H5 -> assente dall'env (NULL)
# ---------------------------------------------------------------------------

test_that("build_name_recovery_lookup (d): GSM non in H5 -> NULL nell'env", {
  env <- .fixt_env_nrl()
  lookup <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = c("GSM001", "GSM999"),
    kind_by_gsm  = list(GSM001 = "disease_vs_normal", GSM999 = "disease_vs_normal"),
    ontology_env = env,
    read_fn      = .mock_h5_reader_nrl
  )
  expect_false(is.null(lookup[["GSM001"]]))   # GSM001 presente
  expect_null(lookup[["GSM999"]])              # GSM999 assente -> NULL
  # L'env deve contenere solo GSM001 (non GSM999)
  expect_equal(ls(lookup), "GSM001")
})

# ---------------------------------------------------------------------------
# (e) kind_by_gsm mancante -> NA_character_ come llm_kind -> NO_RECOVERY
# ---------------------------------------------------------------------------

test_that("build_name_recovery_lookup (e): kind_by_gsm assente -> NA llm_kind -> NO_RECOVERY", {
  env <- .fixt_env_nrl()
  lookup <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM001",
    kind_by_gsm  = list(),   # nessun kind definito
    ontology_env = env,
    read_fn      = .mock_h5_reader_nrl
  )
  res <- lookup[["GSM001"]]
  expect_false(is.null(res))
  # llm_kind=NA -> Passo 4 di recover_identity -> NO_RECOVERY, kind=NA
  expect_equal(res$recovery_source, "NO_RECOVERY")
  expect_true(is.na(res$kind))
  expect_true(is.na(res$agent_id))
})

# ---------------------------------------------------------------------------
# (f) Struttura output: environment hash con 4 campi per entry
# ---------------------------------------------------------------------------

test_that("build_name_recovery_lookup (f): output environment con 4 campi per entry", {
  env <- .fixt_env_nrl()
  lookup <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = c("GSM001", "GSM002"),
    kind_by_gsm  = list(GSM001 = "disease_vs_normal", GSM002 = "small_molecule"),
    ontology_env = env,
    read_fn      = .mock_h5_reader_nrl
  )
  expect_true(is.environment(lookup))
  expect_equal(sort(ls(lookup)), sort(c("GSM001", "GSM002")))

  res1 <- lookup[["GSM001"]]
  expect_named(res1, c("kind", "agent_id", "canonical_name", "recovery_source"))

  res2 <- lookup[["GSM002"]]
  expect_named(res2, c("kind", "agent_id", "canonical_name", "recovery_source"))
})

# ---------------------------------------------------------------------------
# (g) Cache su disco: la seconda chiamata identica non re-esegue read_fn
# ---------------------------------------------------------------------------

test_that("build_name_recovery_lookup (g): cache su disco evita rilettura H5", {
  env <- .fixt_env_nrl()
  tmp_dir <- tempfile("nrl-cache-")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  call_count <- 0L
  counting_reader <- function(h5_path) {
    call_count <<- call_count + 1L
    .mock_h5_reader_nrl(h5_path)
  }

  # Prima chiamata: legge da "H5" (mock) e scrive cache
  lookup1 <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM001",
    kind_by_gsm  = list(GSM001 = "disease_vs_normal"),
    ontology_env = env,
    cache_dir    = tmp_dir,
    read_fn      = counting_reader
  )
  expect_equal(call_count, 1L)

  # Seconda chiamata: DEVE caricare da cache, NON invocare counting_reader
  lookup2 <- build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM001",
    kind_by_gsm  = list(GSM001 = "disease_vs_normal"),
    ontology_env = env,
    cache_dir    = tmp_dir,
    read_fn      = counting_reader
  )
  expect_equal(call_count, 1L)   # invariato: cache hit

  # I risultati delle due chiamate sono identici
  expect_equal(lookup1[["GSM001"]]$kind,            lookup2[["GSM001"]]$kind)
  expect_equal(lookup1[["GSM001"]]$agent_id,         lookup2[["GSM001"]]$agent_id)
  expect_equal(lookup1[["GSM001"]]$recovery_source,  lookup2[["GSM001"]]$recovery_source)
})

# La chiave cache cambia se gsms cambiano -> nessun hit stale tra chiamate diverse
test_that("build_name_recovery_lookup (g2): chiave cache diversa per gsms diversi", {
  env <- .fixt_env_nrl()
  tmp_dir <- tempfile("nrl-cache2-")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  call_count <- 0L
  counting_reader <- function(h5_path) {
    call_count <<- call_count + 1L
    .mock_h5_reader_nrl(h5_path)
  }

  build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM001",
    kind_by_gsm  = list(GSM001 = "disease_vs_normal"),
    ontology_env = env,
    cache_dir    = tmp_dir,
    read_fn      = counting_reader
  )
  build_name_recovery_lookup(
    h5_path      = "fake.h5",
    gsms         = "GSM002",   # diverso!
    kind_by_gsm  = list(GSM002 = "small_molecule"),
    ontology_env = env,
    cache_dir    = tmp_dir,
    read_fn      = counting_reader
  )
  # Entrambe le chiamate devono aver letto dall'H5 (nessun hit stale)
  expect_equal(call_count, 2L)
})
