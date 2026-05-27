# test-stage4-e0b-schema-version.R — FASE E0b ADR-0019 D9 (integrazione T5)
#
# Test che stage4_default_config()$schema_versions registra la strategia
# di SAMN dedupe scelta in E0b (decisione utente 2026-05-27 su evidence
# A7b): drop deterministico con criterio max lib_size, tie-break GSM
# alfabetico. La stringa registrata e' propagata in run_metadata.json
# dal write-out Stage 4.

test_that("E0b T5 stage4_default_config schema_versions contiene samn_dedupe_strategy", {
  cfg <- simulomicsr::stage4_default_config()
  expect_true("samn_dedupe_strategy" %in% names(cfg$schema_versions))
  expect_equal(cfg$schema_versions$samn_dedupe_strategy,
               "max_libsize_alphabetic_tiebreak")
})
