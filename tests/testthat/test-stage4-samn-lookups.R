# test-stage4-samn-lookups.R — FASE E0b ADR-0019 D9 (integrazione T4)
#
# Test per .build_samn_dedupe_lookups(): helper che ricava biosample_lookup +
# libsize_lookup dal tibble h5_metadata passato a build_stage4_results().
# Fallback graceful con warning se le colonne necessarie mancano.

# ============================================================================
# T4.1 — h5_metadata NULL -> entrambi lookup NULL
# ============================================================================

test_that("E0b T4.1 h5_metadata NULL -> entrambi lookup NULL", {
  res <- simulomicsr:::.build_samn_dedupe_lookups(NULL)
  expect_named(res, c("biosample_lookup", "libsize_lookup"))
  expect_null(res$biosample_lookup)
  expect_null(res$libsize_lookup)
})

# ============================================================================
# T4.2 — h5_metadata senza biosample_id -> warning + lookup NULL
# ============================================================================

test_that("E0b T4.2 h5_metadata senza biosample_id: warning + NULL", {
  meta <- tibble::tibble(
    sample_id = c("GSM1", "GSM2"),
    gse       = c("GSE1", "GSE2"),
    lib_size  = c(1e6, 2e6)
    # biosample_id mancante
  )
  expect_warning(
    res <- simulomicsr:::.build_samn_dedupe_lookups(meta),
    "biosample_id"
  )
  expect_null(res$biosample_lookup)
  expect_null(res$libsize_lookup)
})

# ============================================================================
# T4.3 — h5_metadata senza lib_size -> warning + lookup NULL
# ============================================================================

test_that("E0b T4.3 h5_metadata senza lib_size: warning + NULL", {
  meta <- tibble::tibble(
    sample_id    = c("GSM1", "GSM2"),
    gse          = c("GSE1", "GSE2"),
    biosample_id = c("SAMN1", "SAMN2")
    # lib_size mancante
  )
  expect_warning(
    res <- simulomicsr:::.build_samn_dedupe_lookups(meta),
    "lib_size"
  )
  expect_null(res$biosample_lookup)
  expect_null(res$libsize_lookup)
})

# ============================================================================
# T4.4 — h5_metadata completo -> lookup named vec corretti
# ============================================================================

test_that("E0b T4.4 h5_metadata completo: lookup named vec costruiti", {
  meta <- tibble::tibble(
    sample_id    = c("GSM1", "GSM2", "GSM3"),
    gse          = c("GSE1", "GSE1", "GSE2"),
    biosample_id = c("SAMN10", "SAMN20", "SAMN10"),
    lib_size     = c(1e6, 2e6, 5e6)
  )
  res <- simulomicsr:::.build_samn_dedupe_lookups(meta)
  expect_type(res$biosample_lookup, "character")
  expect_equal(res$biosample_lookup[["GSM1"]], "SAMN10")
  expect_equal(res$biosample_lookup[["GSM3"]], "SAMN10")
  expect_type(res$libsize_lookup, "double")
  expect_equal(res$libsize_lookup[["GSM3"]], 5e6)
  # Smoke: i lookup costruiti sono compatibili con .dedupe_gsm_by_samn
  sd <- simulomicsr:::.dedupe_gsm_by_samn(
    c("GSM1", "GSM2", "GSM3"),
    res$biosample_lookup, res$libsize_lookup
  )
  expect_setequal(sd$kept, c("GSM2", "GSM3"))  # GSM3 vince su GSM1 (5e6 > 1e6)
})

# ============================================================================
# T4.5 — h5_metadata con biosample_id NA preservato (legit input)
# ============================================================================

test_that("E0b T4.5 h5_metadata con NA biosample_id: lookup mantiene NA, no warning", {
  meta <- tibble::tibble(
    sample_id    = c("GSM1", "GSM2"),
    gse          = c("GSE1", "GSE2"),
    biosample_id = c("SAMN10", NA_character_),
    lib_size     = c(1e6, 2e6)
  )
  expect_silent(res <- simulomicsr:::.build_samn_dedupe_lookups(meta))
  expect_equal(res$biosample_lookup[["GSM1"]], "SAMN10")
  expect_true(is.na(res$biosample_lookup[["GSM2"]]))
})
