test_that("usable_rem_strict TRUE: pair, L0, k=5, safety_min=0.8", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 0.8
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_true(flags$usable_rem_strict)
  expect_true(flags$usable_rem_relaxed)
})

test_that("usable_rem_strict FALSE: pair, L2 (level > 1)", {
  cluster_row <- list(
    mode = "pair", level = 2L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 0.8
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_rem_strict)
  expect_true(flags$usable_rem_relaxed)
})

test_that("usable_rem_strict FALSE: k=2 (< k_recommended=3)", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 2L, n_total = 10L,
    n_studies = 2L, safety_min = 0.9
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_rem_strict)
  expect_true(flags$usable_rem_relaxed)  # k>=2 (k_min) e safety>=0.5
})

test_that("usable_rem_relaxed FALSE: k=1 (< k_min=2)", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 1L, n_total = 3L,
    n_studies = 1L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_rem_strict)
  expect_false(flags$usable_rem_relaxed)
})

test_that("usable_mega_strict TRUE: group, L0, n_studies=5, n_total=30, safety=0.8", {
  cluster_row <- list(
    mode = "group", level = 0L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 0.8
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_true(flags$usable_mega_strict)
  expect_true(flags$usable_mega_relaxed)
})

test_that("usable_mega_relaxed FALSE: n_studies=1", {
  cluster_row <- list(
    mode = "group", level = 0L, k = 1L, n_total = 100L,
    n_studies = 1L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_mega_relaxed)
})

test_that("usable_mega_relaxed FALSE: n_total=5 (< 10)", {
  cluster_row <- list(
    mode = "group", level = 0L, k = 2L, n_total = 5L,
    n_studies = 2L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_mega_relaxed)
})

test_that("flags off-mode sono FALSE (mode=pair -> usable_mega_* FALSE)", {
  cluster_row <- list(
    mode = "pair", level = 0L, k = 5L, n_total = 30L,
    n_studies = 5L, safety_min = 1.0
  )
  cfg <- stage3_default_config()
  flags <- simulomicsr:::.tag_cluster_usability(cluster_row, cfg$thresholds)
  expect_false(flags$usable_mega_strict)
  expect_false(flags$usable_mega_relaxed)
})
