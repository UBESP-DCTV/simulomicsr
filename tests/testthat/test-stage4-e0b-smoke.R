# test-stage4-e0b-smoke.R — FASE E0b ADR-0019 D9 (integrazione T6)
#
# Smoke end-to-end: chiamata diretta a .pool_all_clusters con lookup SAMN
# attivi su un cluster MEGA sintetico contenente un duplicato cross-GSE
# su stesso SAMN. Verifica che:
#   - pool non crasha;
#   - il GSM con lib_size minore viene effettivamente droppato dal pool;
#   - il drop e' registrato nei pooling_warnings come "cross_gse_samn_dedupe".

# Helper fixture: mock counts fetch_fn deterministico
.mk_fetch_for_smoke <- function() {
  function(gse, sample_ids) {
    # 60 geni, counts NB con seed dipendente da gse per riproducibilita'.
    set.seed(nchar(gse) * 100 + length(sample_ids))
    m <- matrix(rnbinom(60 * length(sample_ids), size = 5, mu = 200),
                nrow = 60, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:60))
    colnames(m) <- sample_ids
    m
  }
}

# ============================================================================
# T6 — MEGA pure: SAMN dedupe rimuove GSM con lib_size minore + log warning
# ============================================================================

test_that("E0b T6 MEGA pure con SAMN dedupe attivo: GSM duplicato cross-GSE droppato + conflict logged", {
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")
  skip_if_not_installed("edgeR")

  # Cluster MEGA con 5 sample da 3 GSE. GSM_a1 e GSM_c1 condividono SAMN_X
  # cross-GSE (GSE_a vs GSE_c). Libsize: a1=1e6, c1=5e6 -> tenuto c1.
  eligible <- tibble::tibble(
    cluster_id = "mega_samn_x",
    method     = "mega",
    level      = 0L,
    mode       = factor("group", levels = c("pair", "group")),
    anchor_key = "ANCHOR_SAMN",
    direction_check = factor("na",
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    studies_in_cluster = list(c("GSE_a", "GSE_b", "GSE_c"))
  )
  attr(eligible, "group_dispatch") <- list(
    mega_samn_x = list(
      list(study_id = "GSE_a",
           sample_ids = c("GSM_a1", "GSM_a2"),
           treatment  = rep("treated", 2L)),
      list(study_id = "GSE_b",
           sample_ids = c("GSM_b1", "GSM_b2"),
           treatment  = rep("control", 2L)),
      list(study_id = "GSE_c",
           sample_ids = "GSM_c1",
           treatment  = "treated")
    )
  )
  attr(eligible, "study_dispatch") <- list()

  stage3_clusters <- tibble::tibble(
    cluster_id = character(0L),
    mode = factor(character(0L), levels = c("pair", "group")),
    level = integer(0L),
    anchor_key = character(0L),
    studies_in_cluster = list(),
    sample_ids = list(),
    sample_studies = list()
  )

  bio_lk <- setNames(
    c("SAMN_X", "SAMN_A2", "SAMN_B1", "SAMN_B2", "SAMN_X"),
    c("GSM_a1", "GSM_a2", "GSM_b1", "GSM_b2", "GSM_c1")
  )
  lib_lk <- setNames(
    c(1e6, 1e6, 1e6, 1e6, 5e6),
    c("GSM_a1", "GSM_a2", "GSM_b1", "GSM_b2", "GSM_c1")
  )

  pooled <- simulomicsr:::.pool_all_clusters(
    per_study_de      = simulomicsr:::.empty_per_study_de(),
    eligible_clusters = eligible,
    fetch_fn          = .mk_fetch_for_smoke(),
    stage3_clusters   = stage3_clusters,
    workers           = 1L,
    dream_workers_cap = 1L,
    biosample_lookup  = bio_lk,
    libsize_lookup    = lib_lk
  )

  # Non crashato + ha prodotto righe DE
  expect_s3_class(pooled, "tbl_df")
  expect_gt(nrow(pooled), 0L)

  # Il conflict cross_gse_samn_dedupe e' nei pooling_warnings.
  pw <- attr(pooled, "pooling_warnings")
  expect_true(!is.null(pw) && nrow(pw) > 0L)
  samn_warn <- pw[grepl("^cross_gse_samn_dedupe", pw$conflict_type), ]
  expect_equal(nrow(samn_warn), 1L)
  expect_equal(samn_warn$sample_id, "GSM_a1")   # droppato (lib 1e6 < 5e6)
  expect_match(samn_warn$conflict_type, "cross_gse_samn_dedupe_kept_GSM_c1")
})

# ============================================================================
# T6b — Stesso setup ma lookup NULL: nessun drop SAMN, no conflict (retrocompat)
# ============================================================================

test_that("E0b T6b lookup NULL: nessun dedupe SAMN, nessun conflict cross_gse", {
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")
  skip_if_not_installed("edgeR")

  eligible <- tibble::tibble(
    cluster_id = "mega_samn_x_b",
    method     = "mega",
    level      = 0L,
    mode       = factor("group", levels = c("pair", "group")),
    anchor_key = "ANCHOR_SAMN",
    direction_check = factor("na",
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    studies_in_cluster = list(c("GSE_a", "GSE_b", "GSE_c"))
  )
  attr(eligible, "group_dispatch") <- list(
    mega_samn_x_b = list(
      list(study_id = "GSE_a",
           sample_ids = c("GSM_a1", "GSM_a2"),
           treatment  = rep("treated", 2L)),
      list(study_id = "GSE_b",
           sample_ids = c("GSM_b1", "GSM_b2"),
           treatment  = rep("control", 2L)),
      list(study_id = "GSE_c",
           sample_ids = "GSM_c1",
           treatment  = "treated")
    )
  )
  attr(eligible, "study_dispatch") <- list()

  stage3_clusters <- tibble::tibble(
    cluster_id = character(0L),
    mode = factor(character(0L), levels = c("pair", "group")),
    level = integer(0L),
    anchor_key = character(0L),
    studies_in_cluster = list(),
    sample_ids = list(),
    sample_studies = list()
  )

  pooled <- simulomicsr:::.pool_all_clusters(
    per_study_de      = simulomicsr:::.empty_per_study_de(),
    eligible_clusters = eligible,
    fetch_fn          = .mk_fetch_for_smoke(),
    stage3_clusters   = stage3_clusters,
    workers           = 1L,
    dream_workers_cap = 1L
    # lookup omessi (NULL default)
  )

  expect_s3_class(pooled, "tbl_df")
  pw <- attr(pooled, "pooling_warnings")
  if (!is.null(pw) && nrow(pw) > 0L) {
    expect_equal(sum(grepl("^cross_gse_samn_dedupe", pw$conflict_type)), 0L)
  } else {
    succeed()
  }
})
