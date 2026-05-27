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

test_that("E0b T6.2 MEGA-AUG: samn_dedupe_log propagato nei pooling_warnings dell'orchestrator", {
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")
  skip_if_not_installed("edgeR")

  # Pair cluster + group baseline structs (riusati dal pattern in
  # test-stage4-mega-aug-bidir.R). GSM_BC_1 e GSM_BC_3 del baseline
  # condividono SAMN_BX cross-GSE GSE100 vs GSE102, libsize 1e6 vs 5e6
  # -> dedupe SAMN baseline tiene GSM_BC_3, drop GSM_BC_1.
  eligible <- tibble::tibble(
    cluster_id = "pair_L4_test_samn",
    method     = "mega_aug",
    level      = 4L,
    mode       = factor("pair", levels = c("pair", "group")),
    anchor_key = paste0("small_molecule|Parthenolide|stomach__VS__",
                         "vehicle_only|Dimethyl sulfoxide|stomach"),
    direction_check = factor("na",
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    studies_in_cluster = list(c("GSE001", "GSE002"))
  )
  attr(eligible, "study_dispatch") <- list(
    pair_L4_test_samn = list(
      list(study_id = "GSE001",
           sample_ids = c("GSM_PT_1", "GSM_PT_2"),
           treatment  = rep("treated", 2L)),
      list(study_id = "GSE002",
           sample_ids = c("GSM_PC_1", "GSM_PC_2"),
           treatment  = rep("control", 2L))
    )
  )
  attr(eligible, "group_dispatch") <- list()

  # stage3_clusters: 1 pair + 1 group baseline che matcha l'anchor control.
  stage3_clusters <- tibble::tibble(
    cluster_id = c("pair_L4_test_samn", "group_L4_ctrl_samn"),
    mode = factor(c("pair", "group"), levels = c("pair", "group")),
    level = c(4L, 4L),
    anchor_key = c(
      paste0("small_molecule|Parthenolide|stomach__VS__",
             "vehicle_only|Dimethyl sulfoxide|stomach"),
      "vehicle_only|Dimethyl sulfoxide|stomach"
    ),
    studies_in_cluster = list(c("GSE001", "GSE002"),
                                c("GSE100", "GSE101", "GSE102")),
    sample_ids = list(
      c("GSM_PT_1", "GSM_PT_2", "GSM_PC_1", "GSM_PC_2"),
      c("GSM_BC_1", "GSM_BC_2", "GSM_BC_3", "GSM_BC_4")
    ),
    sample_studies = list(
      c("GSE001", "GSE001", "GSE002", "GSE002"),
      c("GSE100", "GSE101", "GSE102", "GSE102")
    ),
    treated_samples = list(c("GSM_PT_1", "GSM_PT_2"), character(0L)),
    treated_sample_studies = list(c("GSE001", "GSE001"), character(0L)),
    control_samples = list(c("GSM_PC_1", "GSM_PC_2"), character(0L)),
    control_sample_studies = list(c("GSE002", "GSE002"), character(0L)),
    n_studies = c(2L, 3L),
    n_total   = c(4L, 4L)
  )

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

  cfg_mega_aug <- simulomicsr::stage4_default_config()$mega_aug
  cfg_mega_aug$legacy_monodirectional <- FALSE
  cfg_mega_aug$bidir_min_baseline <- 2L

  pooled <- simulomicsr:::.pool_all_clusters(
    per_study_de      = simulomicsr:::.empty_per_study_de(),
    eligible_clusters = eligible,
    fetch_fn          = .mk_fetch_for_smoke(),
    stage3_clusters   = stage3_clusters,
    workers           = 1L,
    dream_workers_cap = 1L,
    mega_aug_config   = cfg_mega_aug,
    biosample_lookup  = bio_lk,
    libsize_lookup    = lib_lk
  )

  # I drop SAMN dedupe MEGA-AUG sono propagati nei pooling_warnings.
  pw <- attr(pooled, "pooling_warnings")
  expect_true(!is.null(pw) && nrow(pw) > 0L)
  samn_warn <- pw[grepl("^cross_gse_samn_dedupe", pw$conflict_type), ]
  expect_gte(nrow(samn_warn), 1L)
  expect_true("GSM_BC_1" %in% samn_warn$sample_id)
  expect_true(any(grepl("kept_GSM_BC_3", samn_warn$conflict_type)))
})

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
