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

test_that(".sign_concordance: frazione direzione-concorde sui soli geni sig", {
  a   <- c( 2,  -1,  3, -2,  1)
  b   <- c( 1,  -2,  3,  2, -1)   # concordi: idx 1,2,3 ; discordi: 4,5
  sig <- c(TRUE, TRUE, TRUE, TRUE, FALSE)  # gene5 non-sig -> escluso
  res <- .sign_concordance(a, b, sig)
  expect_equal(res$n_used, 4L)
  expect_equal(res$concordance, 3/4)
})

test_that(".sign_concordance: logFC 0/NA esclusi dal denominatore", {
  res <- .sign_concordance(c(2, 0, NA), c(1, 1, 1), c(TRUE, TRUE, TRUE))
  expect_equal(res$n_used, 1L); expect_equal(res$concordance, 1)
})

test_that(".sign_concordance: nessun gene sig usabile -> NA", {
  res <- .sign_concordance(c(2, 3), c(1, 2), c(FALSE, FALSE))
  expect_true(is.na(res$concordance)); expect_equal(res$n_used, 0L)
})

test_that(".consistency_score: mega/rem = 1 - eterogeneita', clamp [0,1]", {
  expect_equal(.consistency_score("mega", median_heterogeneity = 0.3), 0.7)
  expect_equal(.consistency_score("rem", median_heterogeneity = 0.45), 0.55)
  expect_equal(.consistency_score("mega", median_heterogeneity = 1.2), 0) # clamp
})

test_that(".consistency_score: mega_aug = sign_concordance", {
  expect_equal(.consistency_score("mega_aug", sign_concordance = 0.8), 0.8)
})

test_that(".consistency_score: componenti NA -> NA", {
  expect_true(is.na(.consistency_score("mega", median_heterogeneity = NA_real_)))
  expect_true(is.na(.consistency_score("mega_aug", sign_concordance = NA_real_)))
})

test_that(".rem_consistency_from_i2: I2 su scala percento (0-100) -> consistenza 1 - I2/100", {
  # metafor::rma riporta I2 come percentuale: 40% di eterogeneita' -> consistenza 0.60.
  # Il bug originale trattava 40 come frazione (1 - 40 = -39 -> clamp 0). Questo test
  # lo avrebbe beccato.
  expect_equal(.rem_consistency_from_i2(40), 0.6)
  expect_equal(.rem_consistency_from_i2(0), 1)
  expect_equal(.rem_consistency_from_i2(100), 0)
  expect_true(is.na(.rem_consistency_from_i2(NA_real_)))
})
