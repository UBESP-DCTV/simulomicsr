test_that(".pool_all_clusters MEGA dedupa sample condivisi tra rg + skippa cluster rank-deficient", {
  # Regression del 2026-05-20 fullrun: due rg dello stesso cluster MEGA
  # condividevano GSM4556584 -> unlist produce duplicati -> dream crash
  # con duplicate row.names. Anche MEGA con solo treated o solo control
  # (design rank-deficient) deve essere skippato senza crash.
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")

  eligible <- tibble::tibble(
    cluster_id = c("mega_dup", "mega_singleton", "mega_ok"),
    method     = c("mega", "mega", "mega"),
    level      = c(0L, 0L, 0L),
    mode       = factor("group", levels = c("pair", "group")),
    anchor_key = c("KEY1", "KEY2", "KEY3"),
    direction_check = factor(rep("na", 3L),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    studies_in_cluster = list(c("GSE_a", "GSE_b"),
                                c("GSE_c"),
                                c("GSE_d", "GSE_e"))
  )

  attr(eligible, "group_dispatch") <- list(
    # mega_dup: 2 rg condividono GSM_shared1 (same study)
    mega_dup = list(
      list(study_id = "GSE_a",
           sample_ids = c("GSM_a1", "GSM_shared1", "GSM_a3"),
           treatment = rep("treated", 3L)),
      list(study_id = "GSE_a",
           sample_ids = c("GSM_shared1", "GSM_a4"),  # GSM_shared1 dup
           treatment = rep("treated", 2L)),
      list(study_id = "GSE_b",
           sample_ids = c("GSM_b1", "GSM_b2"),
           treatment = rep("control", 2L))
    ),
    # mega_singleton: solo "treated" rgs -> rank deficient -> skip
    mega_singleton = list(
      list(study_id = "GSE_c",
           sample_ids = c("GSM_c1", "GSM_c2"),
           treatment = rep("treated", 2L))
    ),
    # mega_ok: well-balanced
    mega_ok = list(
      list(study_id = "GSE_d",
           sample_ids = c("GSM_d1", "GSM_d2"),
           treatment = rep("treated", 2L)),
      list(study_id = "GSE_e",
           sample_ids = c("GSM_e1", "GSM_e2"),
           treatment = rep("control", 2L))
    )
  )
  attr(eligible, "study_dispatch") <- list()

  mock_fetch <- function(gse, sample_ids) {
    set.seed(nchar(gse) * 100 + length(sample_ids))
    m <- matrix(rnbinom(60 * length(sample_ids), size = 5, mu = 200),
                nrow = 60, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:60))
    colnames(m) <- sample_ids
    m
  }

  # stage3_clusters minimo per mega_aug (non usato qui ma richiesto da signature)
  stage3_clusters <- tibble::tibble(
    cluster_id = character(0L),
    mode = factor(character(0L), levels = c("pair", "group")),
    level = integer(0L),
    anchor_key = character(0L),
    studies_in_cluster = list(),
    sample_ids = list(),
    sample_studies = list()
  )

  expect_no_error(
    pooled <- .pool_all_clusters(
      per_study_de = .empty_per_study_de(),
      eligible_clusters = eligible,
      fetch_fn = mock_fetch,
      stage3_clusters = stage3_clusters,
      workers = 1L,
      dream_workers_cap = 2L
    )
  )

  # mega_dup deve produrre output (dedup ha salvato il run)
  expect_true("mega_dup" %in% pooled$cluster_id)
  # mega_singleton skippato (rank deficient): NO righe in pooled
  expect_false("mega_singleton" %in% pooled$cluster_id)
  # mega_ok ok
  expect_true("mega_ok" %in% pooled$cluster_id)
})

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
