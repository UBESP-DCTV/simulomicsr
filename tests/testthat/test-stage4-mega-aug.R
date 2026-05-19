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
                              "GSM013", "GSM014", "GSM015"))
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
