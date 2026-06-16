# TDD per gli helper della metrica di consistenza cross-studio (F6 Fase A, ADR-0021).
# Vedi docs/superpowers/specs/2026-06-15-f6-reproducibility-consistency-metric-design.md

test_that(".summarize_consistency_over_sig: mediana/IQR sui soli geni FDR-sig non-NA", {
  vals <- c(0.1, 0.5, 0.9, 0.3, NA)
  fdr  <- c(0.01, 0.2, 0.04, 0.001, 0.001)  # sig: idx 1,3,4 (idx5 sig ma val NA)
  res <- .summarize_consistency_over_sig(vals, fdr, threshold = 0.05)
  expect_equal(res$n_used, 3L)
  expect_equal(res$median, median(c(0.1, 0.9, 0.3)))
  expect_equal(res$iqr, IQR(c(0.1, 0.9, 0.3)))
})

test_that(".summarize_consistency_over_sig: nessun gene sig -> NA + n_used 0", {
  res <- .summarize_consistency_over_sig(c(0.2, 0.3), c(0.4, 0.9), threshold = 0.05)
  expect_true(is.na(res$median)); expect_equal(res$n_used, 0L)
})

test_that(".rem_prediction_interval: studi concordi e precisi -> PI esclude 0", {
  res <- .rem_prediction_interval(logFC = c(2.0, 2.2, 1.9, 2.1),
                                  SE = c(0.1, 0.12, 0.09, 0.11))
  expect_true(res$pi_lower > 0)
  expect_true(isTRUE(res$excl0))
  expect_true(is.finite(res$tau2))
})

test_that(".rem_prediction_interval: studi discordi -> PI include 0", {
  res <- .rem_prediction_interval(logFC = c(2.0, -1.8, 1.5, -2.2),
                                  SE = c(0.3, 0.3, 0.3, 0.3))
  expect_true(res$pi_lower < 0 && res$pi_upper > 0)
  expect_false(isTRUE(res$excl0))
})

test_that(".rem_prediction_interval: <2 studi -> NA", {
  res <- .rem_prediction_interval(logFC = c(2.0), SE = c(0.1))
  expect_true(is.na(res$pi_lower)); expect_true(is.na(res$excl0))
})
