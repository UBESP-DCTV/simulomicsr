test_that("stage4_default_config restituisce list con campi essenziali", {
  cfg <- stage4_default_config()

  expect_type(cfg, "list")
  expect_named(cfg, c("qc", "de_engine", "pooling", "compute", "schema_versions"),
               ignore.order = TRUE)
})

test_that("qc threshold lib_size_min e' 500000 di default", {
  cfg <- stage4_default_config()
  expect_equal(cfg$qc$lib_size_min, 500000L)
})

test_that("de_engine specifica limma-voom per REM e dream per MEGA", {
  cfg <- stage4_default_config()
  expect_equal(cfg$de_engine$rem, "limma-voom+eBayes")
  expect_equal(cfg$de_engine$mega, "dream")
  expect_equal(cfg$de_engine$mega_aug, "dream")
})

test_that("pooling specifica REML come metodo default con DL fallback per REM", {
  cfg <- stage4_default_config()
  expect_equal(cfg$pooling$rem_method, "REML")
  expect_equal(cfg$pooling$rem_fallback, "DL")
  expect_equal(cfg$pooling$fdr, "BH_within_cluster")
})

test_that("compute$workers usa availableCores - 10 di default", {
  cfg <- stage4_default_config()
  expect_type(cfg$compute$workers_offset, "integer")
  expect_equal(cfg$compute$workers_offset, 10L)
})

test_that("compute$dream_workers default e' NA (auto-detect)", {
  cfg <- stage4_default_config()
  expect_true(is.na(cfg$compute$dream_workers))
  expect_equal(cfg$compute$dream_workers_cap, 100L)
})

test_that(".resolve_dream_workers auto-detect cap a dream_workers_cap", {
  cfg <- stage4_default_config()
  w <- .resolve_dream_workers(cfg)
  expect_type(w, "integer")
  expect_gte(w, 1L)
  expect_lte(w, cfg$compute$dream_workers_cap)
})

test_that(".resolve_dream_workers usa valore esplicito se non-NA", {
  cfg <- stage4_default_config()
  cfg$compute$dream_workers <- 4L
  expect_equal(.resolve_dream_workers(cfg), 4L)

  # Cap applicato anche al valore esplicito
  cfg$compute$dream_workers <- 1000L
  expect_equal(.resolve_dream_workers(cfg), cfg$compute$dream_workers_cap)
})

test_that("schema_versions include stage4_algorithm v1", {
  cfg <- stage4_default_config()
  expect_equal(cfg$schema_versions$stage4_algorithm, "v1")
})
