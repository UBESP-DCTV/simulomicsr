test_that("stage3_default_config restituisce list con campi essenziali", {
  cfg <- stage3_default_config()

  expect_type(cfg, "list")
  expect_named(cfg, c("tier_assignment", "thresholds", "schema_versions"),
               ignore.order = TRUE)
})

test_that("tier_assignment include tutti e soli i 13 segmenti dell'anchor v3", {
  cfg <- stage3_default_config()
  ta <- cfg$tier_assignment

  expect_named(ta, c("S", "A", "B", "C", "D", "hard_filters"),
               ignore.order = TRUE)

  all_segments <- unlist(ta, use.names = FALSE)
  expected_13 <- c(
    "kind_effective", "agent_id", "variant_label", "dose_canonical",
    "duration_canonical", "phase_canonical", "cell_id", "context_kind",
    "cell_state", "subcellular", "tissue", "disease_status", "has_engineered"
  )

  expect_setequal(all_segments, expected_13)
  expect_equal(length(all_segments), 13L)  # nessun segmento ripetuto
})

test_that("tier S contiene esattamente i 3 segmenti inviolabili", {
  cfg <- stage3_default_config()
  expect_setequal(cfg$tier_assignment$S,
                  c("kind_effective", "agent_id", "tissue"))
})

test_that("hard_filters sono subcellular + context_kind", {
  cfg <- stage3_default_config()
  expect_setequal(cfg$tier_assignment$hard_filters,
                  c("subcellular", "context_kind"))
})

test_that("thresholds REM hanno k_min=2, k_recommended=3, k_gold=10", {
  cfg <- stage3_default_config()
  expect_equal(cfg$thresholds$rem$k_min, 2L)
  expect_equal(cfg$thresholds$rem$k_recommended, 3L)
  expect_equal(cfg$thresholds$rem$k_gold, 10L)
})

test_that("thresholds MEGA hanno n_studies 2/5/10 e n_total 30", {
  cfg <- stage3_default_config()
  expect_equal(cfg$thresholds$mega$n_studies_min, 2L)
  expect_equal(cfg$thresholds$mega$n_studies_recommended, 5L)
  expect_equal(cfg$thresholds$mega$n_studies_gold, 10L)
  expect_equal(cfg$thresholds$mega$n_total_recommended, 30L)
})

test_that("thresholds safety strict=0.7 relaxed=0.5", {
  cfg <- stage3_default_config()
  expect_equal(cfg$thresholds$safety$strict, 0.7)
  expect_equal(cfg$thresholds$safety$relaxed, 0.5)
})

test_that("schema_versions documenta tutte le versioni (anchor v3.1, ADR-0018)", {
  cfg <- stage3_default_config()
  expect_named(cfg$schema_versions,
               c("anchor", "stage3_algorithm", "sample_facts", "study_design",
                 "resolver"),
               ignore.order = TRUE)
  expect_equal(cfg$schema_versions$anchor, "v3.1")
  expect_equal(cfg$schema_versions$stage3_algorithm, "v1")
  expect_equal(cfg$schema_versions$sample_facts, "stage1.v3")
  expect_equal(cfg$schema_versions$study_design, "stage2.v2")
  expect_equal(cfg$schema_versions$resolver, "v1.0.0")
})

test_that(".dropped_segments_at_level produce drop monotonic", {
  ta <- stage3_default_config()$tier_assignment

  d0 <- simulomicsr:::.dropped_segments_at_level(ta, 0L)
  d1 <- simulomicsr:::.dropped_segments_at_level(ta, 1L)
  d2 <- simulomicsr:::.dropped_segments_at_level(ta, 2L)
  d3 <- simulomicsr:::.dropped_segments_at_level(ta, 3L)
  d4 <- simulomicsr:::.dropped_segments_at_level(ta, 4L)

  expect_length(d0, 0L)
  expect_setequal(d1, "has_engineered")
  expect_setequal(d2, c("has_engineered", "dose_canonical", "duration_canonical"))
  expect_setequal(d3, c("has_engineered", "dose_canonical", "duration_canonical",
                        "cell_state", "cell_id"))
  expect_setequal(d4, c("has_engineered", "dose_canonical", "duration_canonical",
                        "cell_state", "cell_id",
                        "variant_label", "disease_status", "phase_canonical"))

  # Monotonicity: d_i subset of d_{i+1}
  expect_true(all(d0 %in% d1))
  expect_true(all(d1 %in% d2))
  expect_true(all(d2 %in% d3))
  expect_true(all(d3 %in% d4))
})

test_that(".kept_segments_at_level always includes tier S", {
  ta <- stage3_default_config()$tier_assignment
  for (L in 0L:4L) {
    kept <- simulomicsr:::.kept_segments_at_level(ta, L)
    expect_true(all(ta$S %in% kept), info = sprintf("L%d", L))
  }
})

test_that(".kept_segments_at_level at L4 is exactly tier S", {
  ta <- stage3_default_config()$tier_assignment
  expect_setequal(simulomicsr:::.kept_segments_at_level(ta, 4L), ta$S)
})

test_that(".kept_segments_at_level at L0 is all droppable segments", {
  ta <- stage3_default_config()$tier_assignment
  expected <- unlist(ta[c("S", "A", "B", "C", "D")], use.names = FALSE)
  expect_setequal(simulomicsr:::.kept_segments_at_level(ta, 0L), expected)
})
