test_that(".assemble_mega_aug_metadata dedupa sample + usa study map esplicita (regression bug fullrun 2026-05-20)", {
  # Caso scoperto al fullrun Layer A: GSM duplicato in pair_treated quando
  # un pair cluster ha 2 comparison-record dallo stesso studio che condividono
  # treated_group (es. "treated vs vehicle" + "treated vs DMSO" stesso treated
  # rg, clusterati insieme dallo anchor_key). + bug latente: cyclic
  # rep(studies_in_cluster, length.out=...) sbaglia il mapping sample->study.
  pair_cluster <- list(
    cluster_id = "pair_dupbug",
    mode = "pair",
    level = 0L,
    treated_anchor_key = "T_KEY",
    control_anchor_key = "C_KEY",
    studies_in_cluster = c("GSE_a", "GSE_b"),
    # GSM_a1, GSM_a2 da GSE_a (treated, 2 sample); GSM_b1, GSM_b2 da GSE_b
    treated_samples = list(c("GSM_a1", "GSM_a2", "GSM_b1", "GSM_b2")),
    control_samples = list(c("GSM_a3", "GSM_a4", "GSM_b3", "GSM_b4")),
    # NEW required: per-sample study map parallela ai vettori sopra
    treated_sample_studies = list(c("GSE_a", "GSE_a", "GSE_b", "GSE_b")),
    control_sample_studies = list(c("GSE_a", "GSE_a", "GSE_b", "GSE_b"))
  )

  group_baseline <- tibble::tibble(
    cluster_id = "group_baseline",
    mode = "group",
    level = 0L,
    anchor_key = "C_KEY",
    studies_in_cluster = list(c("GSE_baseline")),
    sample_ids = list(c("GSM_bl1", "GSM_bl2")),
    sample_studies = list(c("GSE_baseline", "GSE_baseline"))
  )

  result <- .assemble_mega_aug_metadata(pair_cluster, group_baseline)
  m <- result$metadata

  # 4 treated + 4 control + 2 baseline = 10 sample, NO duplicati
  expect_equal(nrow(m), 10L)
  expect_equal(length(unique(m$sample_id)), 10L)

  # Study mapping corretto (NON ciclico): GSM_a1/a2 -> GSE_a, GSM_b1/b2 -> GSE_b
  expect_equal(as.character(m$study[m$sample_id == "GSM_a1"]), "GSE_a")
  expect_equal(as.character(m$study[m$sample_id == "GSM_a2"]), "GSE_a")
  expect_equal(as.character(m$study[m$sample_id == "GSM_b1"]), "GSE_b")
  expect_equal(as.character(m$study[m$sample_id == "GSM_b2"]), "GSE_b")
  expect_equal(as.character(m$study[m$sample_id == "GSM_a3"]), "GSE_a")
  expect_equal(as.character(m$study[m$sample_id == "GSM_b4"]), "GSE_b")
  expect_equal(as.character(m$study[m$sample_id == "GSM_bl1"]), "GSE_baseline")
})

test_that(".assemble_mega_aug_metadata combina pair + baseline pool", {
  # Fixture: pair cluster (2 studi) + 3 group cluster baseline shared
  pair_cluster <- list(
    cluster_id = "pair_L0_aug123",
    mode = "pair",
    level = 0L,
    treated_anchor_key = "TREATED_KEY",
    control_anchor_key = "CONTROL_KEY",
    studies_in_cluster = c("GSE_pair_a", "GSE_pair_b"),
    treated_samples = list(c("GSM001", "GSM002", "GSM003",
                              "GSM010", "GSM011", "GSM012")),
    control_samples = list(c("GSM004", "GSM005", "GSM006",
                              "GSM013", "GSM014", "GSM015")),
    treated_sample_studies = list(c("GSE_pair_a", "GSE_pair_a", "GSE_pair_a",
                                     "GSE_pair_b", "GSE_pair_b", "GSE_pair_b")),
    control_sample_studies = list(c("GSE_pair_a", "GSE_pair_a", "GSE_pair_a",
                                     "GSE_pair_b", "GSE_pair_b", "GSE_pair_b"))
  )

  # Group clusters: 3 cluster con stesso control_anchor_key
  group_baseline <- tibble::tibble(
    cluster_id = c("group_L0_aaa", "group_L0_bbb", "group_L0_ccc"),
    mode = "group",
    level = 0L,
    anchor_key = c("CONTROL_KEY", "CONTROL_KEY", "OTHER_KEY"),  # 2 match + 1 no match
    studies_in_cluster = list(
      c("GSE_baseline_1", "GSE_baseline_2"),
      c("GSE_baseline_3"),
      c("GSE_unrelated")
    ),
    sample_ids = list(
      c("GSM101", "GSM102", "GSM103", "GSM104"),
      c("GSM201", "GSM202"),
      c("GSM999")
    ),
    sample_studies = list(
      c("GSE_baseline_1", "GSE_baseline_1", "GSE_baseline_2", "GSE_baseline_2"),
      c("GSE_baseline_3", "GSE_baseline_3"),
      c("GSE_unrelated")
    )
  )

  result <- .assemble_mega_aug_metadata(pair_cluster, group_baseline)

  # Expected metadata:
  # 6 treated (from pair treated_samples)
  # 6 control (from pair control_samples)
  # 4 + 2 = 6 baseline (CONTROL_KEY group_baseline, deduped no overlap with pair)
  # Total: 18 sample, n_baseline_studies_augmented = 3 (2 from cluster aaa + 1 from bbb)

  expect_s3_class(result$metadata, "tbl_df")
  expect_equal(nrow(result$metadata), 18L)
  expect_equal(sum(result$metadata$treatment == "treated"), 6L)
  expect_equal(sum(result$metadata$treatment == "control"), 12L)  # 6 pair + 6 baseline
  expect_equal(result$n_baseline_studies_augmented, 3L)
})
