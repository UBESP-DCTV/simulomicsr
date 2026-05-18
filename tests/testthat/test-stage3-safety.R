test_that("safety_min = 1.0 quando nessun segmento droppato (L0)", {
  cluster_records <- list(
    list(dose_canonical = "10nM", duration_canonical = "24h"),
    list(dose_canonical = "10nM", duration_canonical = "24h")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = character()
  )
  expect_equal(result$safety_min, 1.0)
  expect_equal(result$safety_geom_mean, 1.0)
  expect_equal(length(result$safety_per_segment), 0L)
})

test_that("safety per single dropped segment: tutti uguali -> safety=1.0", {
  cluster_records <- list(
    list(dose_canonical = "10nM"),
    list(dose_canonical = "10nM"),
    list(dose_canonical = "10nM")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = "dose_canonical"
  )
  expect_equal(result$safety_min, 1.0)
  expect_equal(result$safety_per_segment$dose_canonical, 1.0)
})

test_that("safety modal frequency = 2/3 per 3 records con 2-1 split", {
  cluster_records <- list(
    list(dose_canonical = "10nM"),
    list(dose_canonical = "10nM"),
    list(dose_canonical = "100nM")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = "dose_canonical"
  )
  expect_equal(result$safety_min, 2/3, tolerance = 1e-9)
  expect_equal(result$safety_per_segment$dose_canonical, 2/3, tolerance = 1e-9)
})

test_that("safety_min usa weakest-link semantics su segmenti multipli", {
  # 4 records, 4 dropped segs: 3 con safety alta, 1 con safety bassa
  cluster_records <- list(
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "proliferating", has_engineered = "false"),
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "proliferating", has_engineered = "false"),
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "proliferating", has_engineered = "true"),
    list(dose_canonical = "10nM", duration_canonical = "24h",
         cell_state = "quiescent", has_engineered = "true")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = c("dose_canonical", "duration_canonical",
                          "cell_state", "has_engineered")
  )
  # safety_per_segment: dose=1.0, duration=1.0, cell_state=3/4=0.75,
  #                     has_engineered=2/4=0.5
  expect_equal(result$safety_per_segment$dose_canonical, 1.0)
  expect_equal(result$safety_per_segment$has_engineered, 0.5)
  expect_equal(result$safety_min, 0.5)
  # geom_mean = (1 * 1 * 0.75 * 0.5)^(1/4) ~ 0.66
  expect_equal(result$safety_geom_mean, (1 * 1 * 0.75 * 0.5)^(1/4),
               tolerance = 1e-9)
})

test_that("safety con cluster di 1 record sempre 1.0 (no eterogeneita' possibile)", {
  cluster_records <- list(
    list(dose_canonical = "10nM")
  )
  result <- simulomicsr:::.compute_pooling_safety(
    cluster_records = cluster_records,
    dropped_segments = "dose_canonical"
  )
  expect_equal(result$safety_min, 1.0)
  expect_equal(result$safety_per_segment$dose_canonical, 1.0)
})
