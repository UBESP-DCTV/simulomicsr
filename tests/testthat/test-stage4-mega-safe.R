# test-stage4-mega-safe.R — FASE E0b ADR-0019 D9 (integrazione T2)
#
# Test per .build_mega_metadata_safe(): retrocompat (lookup NULL = no-op) +
# nuovo dedupe SAMN cross-GSE quando i due lookup sono forniti.
#
# Riferimenti:
#   - R/stage4-mega-safe.R
#   - R/stage4-samn-dedupe.R (helper .dedupe_gsm_by_samn, FASE E0b T1)
#   - analysis/audit/A7b-samn-duplicate-analysis.md

# Helper costruttori test fixtures ---------------------------------------------

.mk_grp_entry <- function(study_id, sample_ids, treatment) {
  # Ogni entry rispetta lo schema atteso da .build_mega_metadata_safe:
  # study_id chr, sample_ids chr vec, treatment chr vec (lungo come sample_ids).
  list(
    study_id   = study_id,
    sample_ids = sample_ids,
    treatment  = rep(treatment, length(sample_ids))
  )
}

# ============================================================================
# T2.0 — Retrocompat: lookup default NULL -> behavior identico al pre-E0b
# ============================================================================

test_that("E0b T2.0 retrocompat: lookup NULL produce stessi sample del pre-E0b", {
  grp <- list(
    .mk_grp_entry("GSE_A", c("GSM_a1", "GSM_a2"), "treated"),
    .mk_grp_entry("GSE_B", c("GSM_b1", "GSM_b2"), "control")
  )
  res <- simulomicsr:::.build_mega_metadata_safe(grp, "cluster_test_t20")

  expect_setequal(res$metadata$sample_id,
                  c("GSM_a1", "GSM_a2", "GSM_b1", "GSM_b2"))
  expect_equal(nrow(res$conflicts), 0L)
})

# ============================================================================
# T2.1 — SAMN cross-GSE same-role: collassato a 1 GSM, conflict registrato
# ============================================================================

test_that("E0b T2.1 SAMN cross-GSE same-role: keep max libsize, conflict cross_gse_samn_dedupe", {
  # GSM_a1 (GSE_A treated) e GSM_b1 (GSE_B treated) condividono SAMN10.
  # Libsize: a1=1e6, b1=5e6 -> tenuto b1.
  grp <- list(
    .mk_grp_entry("GSE_A", "GSM_a1", "treated"),
    .mk_grp_entry("GSE_B", "GSM_b1", "treated"),
    .mk_grp_entry("GSE_C", c("GSM_c1", "GSM_c2"), "control")
  )
  bio_lk <- setNames(
    c("SAMN10", "SAMN10", "SAMN20", "SAMN30"),
    c("GSM_a1", "GSM_b1", "GSM_c1", "GSM_c2")
  )
  lib_lk <- setNames(
    c(1e6, 5e6, 2e6, 3e6),
    c("GSM_a1", "GSM_b1", "GSM_c1", "GSM_c2")
  )

  res <- simulomicsr:::.build_mega_metadata_safe(
    grp, "cluster_t21",
    biosample_lookup = bio_lk,
    libsize_lookup   = lib_lk
  )

  expect_setequal(res$metadata$sample_id,
                  c("GSM_b1", "GSM_c1", "GSM_c2"))
  # 1 conflict cross_gse_samn_dedupe per GSM_a1
  samn_conf <- res$conflicts[
    grepl("^cross_gse_samn_dedupe", res$conflicts$conflict_type), ]
  expect_equal(nrow(samn_conf), 1L)
  expect_equal(samn_conf$sample_id, "GSM_a1")
  expect_match(samn_conf$conflict_type, "cross_gse_samn_dedupe_kept_GSM_b1")
})

# ============================================================================
# T2.2 — NA SAMN preservato cross-GSE (identita' biologica ignota)
# ============================================================================

test_that("E0b T2.2 NA SAMN cross-GSE: 2 GSM con SAMN=NA restano distinti", {
  grp <- list(
    .mk_grp_entry("GSE_A", "GSM_a1", "treated"),
    .mk_grp_entry("GSE_B", "GSM_b1", "treated"),
    .mk_grp_entry("GSE_C", "GSM_c1", "control")
  )
  bio_lk <- setNames(
    c(NA_character_, NA_character_, "SAMN30"),
    c("GSM_a1", "GSM_b1", "GSM_c1")
  )
  lib_lk <- setNames(c(1e6, 2e6, 3e6), c("GSM_a1", "GSM_b1", "GSM_c1"))

  res <- simulomicsr:::.build_mega_metadata_safe(
    grp, "cluster_t22",
    biosample_lookup = bio_lk,
    libsize_lookup   = lib_lk
  )

  expect_setequal(res$metadata$sample_id,
                  c("GSM_a1", "GSM_b1", "GSM_c1"))
  expect_equal(nrow(res$conflicts), 0L)
})

# ============================================================================
# T2.3 — Role conflict ha priorita' su SAMN dedupe (sample droppato vince)
# ============================================================================

test_that("E0b T2.3 role_conflict ha priorita': SAMN dedupe non interferisce", {
  # GSM_a1 appare in GSE_A treated E GSE_B control -> role_conflict drop.
  # Lookup SAMN avrebbe collassato GSM_a1 con GSM_b2 (stesso SAMN) ma
  # GSM_a1 e' gia' droppato da role_conflict, quindi resta solo GSM_b2.
  grp <- list(
    .mk_grp_entry("GSE_A", "GSM_a1", "treated"),
    .mk_grp_entry("GSE_B", "GSM_a1", "control"),   # stesso GSM, ruolo diverso
    .mk_grp_entry("GSE_C", "GSM_b2", "treated")
  )
  bio_lk <- setNames(
    c("SAMN10", "SAMN10"),
    c("GSM_a1", "GSM_b2")
  )
  lib_lk <- setNames(c(1e6, 5e6), c("GSM_a1", "GSM_b2"))

  res <- simulomicsr:::.build_mega_metadata_safe(
    grp, "cluster_t23",
    biosample_lookup = bio_lk,
    libsize_lookup   = lib_lk
  )

  # GSM_a1 droppato da role_conflict, GSM_b2 sopravvive (SAMN dedupe non
  # collassa perche' GSM_a1 e' gia' fuori dal pool keep).
  expect_setequal(res$metadata$sample_id, "GSM_b2")
  role_conf <- res$conflicts[res$conflicts$conflict_type == "role_conflict_dropped", ]
  expect_equal(nrow(role_conf), 1L)
  expect_equal(role_conf$sample_id, "GSM_a1")
})

# ============================================================================
# T2.4 — SAMN dedupe interagisce correttamente con cross-study same-role dedup
# ============================================================================

test_that("E0b T2.4 cross-study same-role (GSM literal) + SAMN dedupe in catena", {
  # GSM_a1 appare in GSE_A treated E GSE_B treated -> cross_study_duplicate_kept_first
  # (gia' deduplicato a 1 occorrenza). POI SAMN dedupe trova che GSM_a1 e
  # GSM_c1 condividono SAMN10 cross-GSE -> tenuto quello con libsize max.
  grp <- list(
    .mk_grp_entry("GSE_A", "GSM_a1", "treated"),
    .mk_grp_entry("GSE_B", "GSM_a1", "treated"),  # stesso GSM, stesso role
    .mk_grp_entry("GSE_C", "GSM_c1", "treated"),
    .mk_grp_entry("GSE_D", "GSM_d1", "control")
  )
  bio_lk <- setNames(
    c("SAMN10", "SAMN10", "SAMN30"),
    c("GSM_a1", "GSM_c1", "GSM_d1")
  )
  lib_lk <- setNames(c(2e6, 5e6, 1e6), c("GSM_a1", "GSM_c1", "GSM_d1"))

  res <- simulomicsr:::.build_mega_metadata_safe(
    grp, "cluster_t24",
    biosample_lookup = bio_lk,
    libsize_lookup   = lib_lk
  )

  # GSM_a1 cross-study dedup (kept_first GSE_A o GSE_B), poi SAMN dedup
  # con GSM_c1 (libsize 5e6 > 2e6) -> GSM_a1 droppato, GSM_c1 kept.
  expect_setequal(res$metadata$sample_id, c("GSM_c1", "GSM_d1"))
  # Entrambi i conflict_type devono essere registrati
  expect_true(any(grepl("^cross_study_duplicate", res$conflicts$conflict_type)))
  expect_true(any(grepl("^cross_gse_samn_dedupe", res$conflicts$conflict_type)))
})
