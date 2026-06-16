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
