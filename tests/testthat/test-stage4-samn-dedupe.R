# test-stage4-samn-dedupe.R — FASE E0b ADR-0019 D9
#
# Test per helper .dedupe_gsm_by_samn(): collapse cross-GSE per BioSample SAMN
# nel pool Stadio 4 (decisione utente 2026-05-27 su evidence A7b: opzione
# (a) drop deterministico con criterio max lib_size, tie-break GSM alfabetico).
#
# Riferimenti:
#   - analysis/audit/A7b-samn-duplicate-analysis.md (decisione + evidence)
#   - docs/RED_ALERT.md §FASE E0b
#   - docs/decisions/0019-archs4-metadata-exploitation-v2.md §D9

# ============================================================================
# Helper costruttori lookup per i test
# ============================================================================

.mk_samn_lookup <- function(...) {
  args <- list(...)
  setNames(as.character(unlist(args)), names(args))
}

.mk_libsize_lookup <- function(...) {
  args <- list(...)
  setNames(as.numeric(unlist(args)), names(args))
}

# ============================================================================
# T1.1 — input vuoto
# ============================================================================

test_that("E0b T1.1 input vuoto -> kept e dropped vuoti con schema corretto", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = character(0),
    biosample_lookup = .mk_samn_lookup(),
    libsize_lookup   = .mk_libsize_lookup()
  )

  expect_type(res, "list")
  expect_named(res, c("kept", "dropped"))
  expect_identical(res$kept, character(0))
  expect_s3_class(res$dropped, "tbl_df")
  expect_equal(nrow(res$dropped), 0L)
  expect_equal(
    sort(names(res$dropped)),
    sort(c("gsm_dropped", "samn", "gsm_kept",
           "libsize_dropped", "libsize_kept", "reason"))
  )
})

# ============================================================================
# T1.2 — single GSM
# ============================================================================

test_that("E0b T1.2 single GSM -> kept invariato, nessun drop", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = "GSM1",
    biosample_lookup = .mk_samn_lookup(GSM1 = "SAMN10"),
    libsize_lookup   = .mk_libsize_lookup(GSM1 = 1e6)
  )
  expect_identical(res$kept, "GSM1")
  expect_equal(nrow(res$dropped), 0L)
})

# ============================================================================
# T1.3 — 2 GSM stesso SAMN, lib_size diversa: tieni max
# ============================================================================

test_that("E0b T1.3 2 GSM stesso SAMN, libsize diversa: keep max libsize", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = c("GSM1", "GSM2"),
    biosample_lookup = .mk_samn_lookup(GSM1 = "SAMN10", GSM2 = "SAMN10"),
    libsize_lookup   = .mk_libsize_lookup(GSM1 = 1e6, GSM2 = 3e6)
  )
  expect_identical(res$kept, "GSM2")
  expect_equal(nrow(res$dropped), 1L)
  expect_equal(res$dropped$gsm_dropped, "GSM1")
  expect_equal(res$dropped$gsm_kept, "GSM2")
  expect_equal(res$dropped$samn, "SAMN10")
  expect_equal(res$dropped$libsize_dropped, 1e6)
  expect_equal(res$dropped$libsize_kept, 3e6)
  expect_equal(res$dropped$reason, "lower_libsize")
})

# ============================================================================
# T1.4 — 2 GSM stesso SAMN, lib_size tied: tie-break alfabetico
# ============================================================================

test_that("E0b T1.4 2 GSM stesso SAMN, libsize tied: tie-break alfabetico", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = c("GSM2", "GSM1"),   # ordine input scrambled
    biosample_lookup = .mk_samn_lookup(GSM1 = "SAMN10", GSM2 = "SAMN10"),
    libsize_lookup   = .mk_libsize_lookup(GSM1 = 2e6, GSM2 = 2e6)
  )
  # GSM1 < GSM2 lessicale, libsize tied -> GSM1 vince
  expect_identical(res$kept, "GSM1")
  expect_equal(res$dropped$gsm_dropped, "GSM2")
  expect_equal(res$dropped$reason, "tie_alphabetic_loser")
})

# ============================================================================
# T1.5 — 3 GSM stesso SAMN: 1 keep, 2 drop
# ============================================================================

test_that("E0b T1.5 3 GSM stesso SAMN: tiene max libsize, droppa altri 2", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids = c("GSM1", "GSM2", "GSM3"),
    biosample_lookup = .mk_samn_lookup(
      GSM1 = "SAMN10", GSM2 = "SAMN10", GSM3 = "SAMN10"
    ),
    libsize_lookup = .mk_libsize_lookup(
      GSM1 = 1e6, GSM2 = 5e6, GSM3 = 3e6
    )
  )
  expect_identical(res$kept, "GSM2")
  expect_equal(nrow(res$dropped), 2L)
  expect_setequal(res$dropped$gsm_dropped, c("GSM1", "GSM3"))
  expect_true(all(res$dropped$gsm_kept == "GSM2"))
})

# ============================================================================
# T1.6 — NA SAMN preservato (identita' ignota non collassa)
# ============================================================================

test_that("E0b T1.6 NA SAMN preservato: 2 GSM con SAMN=NA restano distinti", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = c("GSM1", "GSM2"),
    biosample_lookup = .mk_samn_lookup(GSM1 = NA_character_, GSM2 = NA_character_),
    libsize_lookup   = .mk_libsize_lookup(GSM1 = 1e6, GSM2 = 3e6)
  )
  expect_setequal(res$kept, c("GSM1", "GSM2"))
  expect_equal(nrow(res$dropped), 0L)
})

# ============================================================================
# T1.7 — NA lib_size: trattato come deprioritizzato vs non-NA
# ============================================================================

test_that("E0b T1.7 NA lib_size: il sample con NA libsize perde vs sample con libsize valido", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = c("GSM1", "GSM2"),
    biosample_lookup = .mk_samn_lookup(GSM1 = "SAMN10", GSM2 = "SAMN10"),
    libsize_lookup   = .mk_libsize_lookup(GSM1 = NA_real_, GSM2 = 2e6)
  )
  expect_identical(res$kept, "GSM2")
  expect_equal(res$dropped$gsm_dropped, "GSM1")
})

test_that("E0b T1.7b entrambi NA lib_size: tie-break alfabetico", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = c("GSM2", "GSM1"),
    biosample_lookup = .mk_samn_lookup(GSM1 = "SAMN10", GSM2 = "SAMN10"),
    libsize_lookup   = .mk_libsize_lookup(GSM1 = NA_real_, GSM2 = NA_real_)
  )
  expect_identical(res$kept, "GSM1")
  expect_equal(res$dropped$reason, "tie_alphabetic_loser")
})

# ============================================================================
# T1.8 — mix multi-SAMN: ogni SAMN deduplicato indipendentemente
# ============================================================================

test_that("E0b T1.8 mix multi-SAMN: dedupe indipendente per SAMN, ordine kept preservato", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids = c("GSM_A", "GSM_B", "GSM_C", "GSM_D", "GSM_E"),
    biosample_lookup = .mk_samn_lookup(
      GSM_A = "SAMN1",   # SAMN1: GSM_A da solo -> kept
      GSM_B = "SAMN2",   # SAMN2: GSM_B + GSM_C -> kept C (libsize maggiore)
      GSM_C = "SAMN2",
      GSM_D = "SAMN3",   # SAMN3: GSM_D + GSM_E -> kept D (libsize maggiore)
      GSM_E = "SAMN3"
    ),
    libsize_lookup = .mk_libsize_lookup(
      GSM_A = 1e6, GSM_B = 1e6, GSM_C = 5e6, GSM_D = 4e6, GSM_E = 2e6
    )
  )
  expect_setequal(res$kept, c("GSM_A", "GSM_C", "GSM_D"))
  expect_equal(nrow(res$dropped), 2L)
  expect_setequal(res$dropped$gsm_dropped, c("GSM_B", "GSM_E"))
})

# ============================================================================
# T1.9 — exclude_samn: drop entrambi i GSM del SAMN escluso
# ============================================================================

test_that("E0b T1.9 exclude_samn: GSM con SAMN escluso droppati completamente", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids       = c("GSM1", "GSM2", "GSM3"),
    biosample_lookup = .mk_samn_lookup(
      GSM1 = "SAMN10", GSM2 = "SAMN20", GSM3 = "SAMN10"
    ),
    libsize_lookup   = .mk_libsize_lookup(
      GSM1 = 1e6, GSM2 = 2e6, GSM3 = 3e6
    ),
    exclude_samn = "SAMN10"
  )
  # SAMN10 escluso -> sia GSM1 che GSM3 droppati. SAMN20 -> GSM2 kept.
  expect_identical(res$kept, "GSM2")
  expect_equal(nrow(res$dropped), 2L)
  expect_setequal(res$dropped$gsm_dropped, c("GSM1", "GSM3"))
  expect_true(all(res$dropped$reason[res$dropped$gsm_dropped %in% c("GSM1", "GSM3")] == "excluded_samn"))
})

# ============================================================================
# T1.10 — GSM missing in biosample_lookup: trattato come NA SAMN (preservato)
# ============================================================================

test_that("E0b T1.10 GSM mancante in biosample_lookup: trattato come NA SAMN, preservato", {
  res <- simulomicsr:::.dedupe_gsm_by_samn(
    sample_ids = c("GSM1", "GSM_orphan"),
    biosample_lookup = .mk_samn_lookup(GSM1 = "SAMN10"),  # GSM_orphan assente
    libsize_lookup   = .mk_libsize_lookup(GSM1 = 1e6, GSM_orphan = 2e6)
  )
  # GSM_orphan ha SAMN NA -> non collassa con nessuno -> preservato
  expect_setequal(res$kept, c("GSM1", "GSM_orphan"))
  expect_equal(nrow(res$dropped), 0L)
})
