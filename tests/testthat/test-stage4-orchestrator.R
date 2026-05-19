test_that(".run_per_study_de_all itera su REM + MEGA-AUG pair-side", {
  skip_if_not_installed("limma")

  # Fixture: 1 cluster REM (k=3) + 1 cluster MEGA-AUG (pair k=2).
  # Mock counts cache via fetch_fn injection.
  eligible <- tibble::tibble(
    cluster_id = c("rem_k3", "mega_aug_k2"),
    method = c("rem", "mega_aug"),
    direction_check = factor(c("canonical", "canonical"),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na"))
  )

  # Per-cluster (study_id, samples) dispatch table; v1 helper struct passato
  # via attribute on eligible.
  attr(eligible, "study_dispatch") <- list(
    rem_k3 = list(
      list(study_id = "GSE_a", treated = c("GSM001", "GSM002", "GSM003"),
           control = c("GSM004", "GSM005", "GSM006")),
      list(study_id = "GSE_b", treated = c("GSM007", "GSM008", "GSM009"),
           control = c("GSM010", "GSM011", "GSM012")),
      list(study_id = "GSE_c", treated = c("GSM013", "GSM014", "GSM015"),
           control = c("GSM016", "GSM017", "GSM018"))
    ),
    mega_aug_k2 = list(
      list(study_id = "GSE_d", treated = c("GSM100", "GSM101", "GSM102"),
           control = c("GSM103", "GSM104", "GSM105")),
      list(study_id = "GSE_e", treated = c("GSM200", "GSM201", "GSM202"),
           control = c("GSM203", "GSM204", "GSM205"))
    )
  )

  mock_fetch <- function(gse, sample_ids) {
    set.seed(nchar(gse) * 100)
    m <- matrix(rnbinom(50 * length(sample_ids), size = 5, mu = 200),
                nrow = 50, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:50))
    colnames(m) <- sample_ids
    m
  }

  result <- .run_per_study_de_all(eligible, fetch_fn = mock_fetch,
                                   workers = 1L)

  expect_s3_class(result, "tbl_df")
  expect_true("cluster_id" %in% names(result))
  expect_true("study_id" %in% names(result))
  expect_true(any(result$cluster_id == "rem_k3"))
  expect_true(any(result$cluster_id == "mega_aug_k2"))
  expect_equal(length(unique(result$study_id[result$cluster_id == "rem_k3"])), 3L)
})
