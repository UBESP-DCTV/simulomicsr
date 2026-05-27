# test-stage4-mega-aug-samn.R — FASE E0b ADR-0019 D9 (integrazione T3)
#
# Test per .assemble_mega_aug_metadata_bidir(): integrazione SAMN dedupe nel
# baseline pool MEGA-AUG, inclusa l'esclusione cross pair-baseline via
# exclude_samn (SAMN gia' presenti nel pair non possono comparire nel
# baseline augmentation).
#
# Riferimenti:
#   - R/stage4-mega-aug.R::.assemble_mega_aug_metadata_bidir
#   - R/stage4-samn-dedupe.R::.dedupe_gsm_by_samn (FASE E0b T1)
#   - analysis/audit/A7b-samn-duplicate-analysis.md

# Helper fixture builders -----------------------------------------------------

mk_pair_cluster_samn <- function() {
  list(
    cluster_id             = "pair_L4_samn_test",
    level                  = 4L,
    anchor_key             = paste0(
      "small_molecule|TEST|stomach__VS__",
      "vehicle_only|TEST|stomach"
    ),
    studies_in_cluster     = c("GSE001", "GSE002"),
    treated_samples        = list(c("GSM_PT_1", "GSM_PT_2")),
    control_samples        = list(c("GSM_PC_1", "GSM_PC_2")),
    treated_sample_studies = list(c("GSE001", "GSE001")),
    control_sample_studies = list(c("GSE002", "GSE002"))
  )
}

mk_group_baseline_samn <- function() {
  # Baseline ctrl pool: 4 GSM da 3 GSE -> sufficient per min_baseline_studies=2L.
  tibble::tibble(
    cluster_id         = "group_L4_ctrl_samn",
    mode               = "group",
    level              = 4L,
    anchor_key         = "vehicle_only|TEST|stomach",
    n_studies          = 3L,
    n_total            = 4L,
    studies_in_cluster = list(c("GSE100", "GSE101", "GSE102")),
    sample_ids         = list(c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4")),
    sample_studies     = list(c("GSE100", "GSE101", "GSE102", "GSE102"))
  )
}

# ============================================================================
# T3.0 — Retrocompat: lookup NULL produce return invariato + samn_dedupe_log empty
# ============================================================================

test_that("E0b T3.0 retrocompat: lookup NULL -> nessun dedupe SAMN, log tibble vuoto", {
  pair    <- mk_pair_cluster_samn()
  base    <- mk_group_baseline_samn()
  matcher <- simulomicsr:::make_anchor_matcher("strict")

  res <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
    pair, base, matcher,
    direction = "control",
    min_baseline_studies = 2L
  )

  expect_true("samn_dedupe_log" %in% names(res))
  expect_s3_class(res$samn_dedupe_log, "tbl_df")
  expect_equal(nrow(res$samn_dedupe_log), 0L)
  # I 4 GSM baseline restano (nessuno droppato)
  expect_setequal(
    res$metadata$sample_id[res$metadata$treatment == "control"],
    c("GSM_PC_1", "GSM_PC_2", "GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4")
  )
})

# ============================================================================
# T3.1 — Baseline cross-GSE SAMN duplicato -> dedupe, keep max libsize
# ============================================================================

test_that("E0b T3.1 baseline GSM cross-GSE su stesso SAMN: keep max libsize, droppato logged", {
  pair    <- mk_pair_cluster_samn()
  base    <- mk_group_baseline_samn()
  matcher <- simulomicsr:::make_anchor_matcher("strict")

  # GSM_BC_1 e GSM_BC_3 condividono SAMN_BX (cross-GSE GSE100 vs GSE102).
  # Libsize: BC_1=1e6, BC_3=5e6 -> tenuto BC_3.
  bio_lk <- setNames(
    c("SAMN_BX", "SAMN_BY", "SAMN_BX", "SAMN_BZ",
      "SAMN_PT1", "SAMN_PT2", "SAMN_PC1", "SAMN_PC2"),
    c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4",
      "GSM_PT_1", "GSM_PT_2", "GSM_PC_1", "GSM_PC_2")
  )
  lib_lk <- setNames(
    c(1e6, 2e6, 5e6, 3e6, 4e6, 4e6, 4e6, 4e6),
    c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4",
      "GSM_PT_1", "GSM_PT_2", "GSM_PC_1", "GSM_PC_2")
  )

  res <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
    pair, base, matcher,
    direction = "control",
    min_baseline_studies = 2L,
    biosample_lookup = bio_lk,
    libsize_lookup   = lib_lk
  )

  ctrl_sids <- res$metadata$sample_id[res$metadata$treatment == "control"]
  expect_true("GSM_BC_3" %in% ctrl_sids)
  expect_false("GSM_BC_1" %in% ctrl_sids)  # droppato

  # samn_dedupe_log registra il drop
  expect_equal(nrow(res$samn_dedupe_log), 1L)
  expect_equal(res$samn_dedupe_log$gsm_dropped, "GSM_BC_1")
  expect_equal(res$samn_dedupe_log$gsm_kept, "GSM_BC_3")
  expect_equal(res$samn_dedupe_log$samn, "SAMN_BX")
  expect_equal(res$samn_dedupe_log$arm, "control")
  expect_equal(res$samn_dedupe_log$reason, "lower_libsize")
})

# ============================================================================
# T3.2 — Baseline GSM con SAMN gia' presente nel pair -> drop intero baseline GSM
# ============================================================================

test_that("E0b T3.2 baseline GSM con SAMN del pair: drop completo (excluded_samn)", {
  pair    <- mk_pair_cluster_samn()
  base    <- mk_group_baseline_samn()
  matcher <- simulomicsr:::make_anchor_matcher("strict")

  # GSM_BC_2 condivide SAMN_PC1 con GSM_PC_1 (pair control). E' lo stesso
  # campione biologico, presentato in due cluster diversi -> drop dal baseline.
  bio_lk <- setNames(
    c("SAMN_BX", "SAMN_PC1", "SAMN_BY", "SAMN_BZ",
      "SAMN_PT1", "SAMN_PT2", "SAMN_PC1", "SAMN_PC2"),
    c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4",
      "GSM_PT_1", "GSM_PT_2", "GSM_PC_1", "GSM_PC_2")
  )
  lib_lk <- setNames(
    c(1e6, 5e6, 2e6, 3e6, 4e6, 4e6, 4e6, 4e6),
    c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4",
      "GSM_PT_1", "GSM_PT_2", "GSM_PC_1", "GSM_PC_2")
  )

  res <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
    pair, base, matcher,
    direction = "control",
    min_baseline_studies = 2L,
    biosample_lookup = bio_lk,
    libsize_lookup   = lib_lk
  )

  ctrl_sids <- res$metadata$sample_id[res$metadata$treatment == "control"]
  # Pair conserva GSM_PC_1 (priorita' pair > baseline).
  expect_true("GSM_PC_1" %in% ctrl_sids)
  # GSM_BC_2 droppato perche' SAMN_PC1 e' nel pair
  expect_false("GSM_BC_2" %in% ctrl_sids)

  excl_rows <- res$samn_dedupe_log[res$samn_dedupe_log$reason == "excluded_samn", ]
  expect_equal(nrow(excl_rows), 1L)
  expect_equal(excl_rows$gsm_dropped, "GSM_BC_2")
  expect_equal(excl_rows$samn, "SAMN_PC1")
  expect_equal(excl_rows$arm, "control")
})

# ============================================================================
# T3.3 — NA SAMN preservato (no collapse)
# ============================================================================

test_that("E0b T3.3 NA SAMN nei baseline: GSM preservati distinti", {
  pair    <- mk_pair_cluster_samn()
  base    <- mk_group_baseline_samn()
  matcher <- simulomicsr:::make_anchor_matcher("strict")

  bio_lk <- setNames(
    c(NA_character_, NA_character_, NA_character_, NA_character_,
      "SAMN_PT1", "SAMN_PT2", "SAMN_PC1", "SAMN_PC2"),
    c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4",
      "GSM_PT_1", "GSM_PT_2", "GSM_PC_1", "GSM_PC_2")
  )
  lib_lk <- setNames(
    rep(1e6, 8),
    c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4",
      "GSM_PT_1", "GSM_PT_2", "GSM_PC_1", "GSM_PC_2")
  )

  res <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
    pair, base, matcher,
    direction = "control",
    min_baseline_studies = 2L,
    biosample_lookup = bio_lk,
    libsize_lookup   = lib_lk
  )

  ctrl_sids <- res$metadata$sample_id[res$metadata$treatment == "control"]
  # Tutti i 4 baseline GSM con SAMN NA restano
  expect_true(all(c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4") %in% ctrl_sids))
  expect_equal(nrow(res$samn_dedupe_log), 0L)
})
