make_fake_stage4_dir <- function() {
  d <- tempfile("stage4_")
  dir.create(d)

  cp <- tibble::tibble(
    cluster_id = rep(c("cl_a", "cl_b", "cl_c"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 3),
    method = rep(c("mega", "mega_aug", "mega"), each = 3),
    logFC_pool = c(0.5, 1.2, -0.8, 2.0, 0.3, -1.5, 0.1, 0.2, 0.3),
    SE_pool = 0.1,
    p_value_pool = c(0.001, 0.5, 0.02, 0.0001, 0.6, 0.005, 0.9, 0.8, 0.7),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = c(5L, 5L, 5L, 2L, 2L, 2L, 6L, 6L, 6L),
    n_baseline_studies_augmented = c(NA, NA, NA, 8L, 8L, 8L, NA, NA, NA),
    FDR_BH_within_cluster = c(0.005, 0.6, 0.04, 0.0003, 0.7, 0.015, 0.9, 0.9, 0.9),
    direction_applied = "none"
  )
  arrow::write_parquet(cp, file.path(d, "cluster_pooled.parquet"))

  ps <- tibble::tibble(
    cluster_id = rep("cl_b", 6),  # only mega_aug ha per_study
    study_id = rep(c("GSE1", "GSE2"), each = 3),
    gene = rep(c("G1", "G2", "G3"), 2),
    logFC = c(2.1, 0.4, -1.4, 1.9, 0.2, -1.6),
    SE = 0.15,
    p_value = 0.001,
    t_stat = 8.0,
    n_treated = 3L, n_control = 3L,
    direction_applied = "none"
  )
  arrow::write_parquet(ps, file.path(d, "per_study_de.parquet"))

  qc <- list(
    qc_drops_sample = tibble::tibble(),
    qc_drops_study = tibble::tibble(),
    qc_drops_cluster = tibble::tibble(
      cluster_id = "cl_z",
      original_k = NA_integer_, qc_final_k = NA_integer_,
      original_n_studies = NA_integer_, qc_final_n_studies = NA_integer_,
      reason = "mega_rank_deficient"
    ),
    pooling_warnings = tibble::tibble(),
    mega_aug_diagnostics = tibble::tibble(cluster_id = "cl_b", bidir_collapsed_to_mono = FALSE)
  )
  saveRDS(qc, file.path(d, "qc_report.rds"))

  meta <- list(run_id = "deadbeef", config = list(de_engine = list(mega = "dream")))
  jsonlite::write_json(meta, file.path(d, "run_metadata.json"), auto_unbox = TRUE)

  d
}

test_that(".fetch_layer_a_subset returns subset for requested cluster_ids", {
  d <- make_fake_stage4_dir()
  on.exit(unlink(d, recursive = TRUE))

  sub <- simulomicsr:::.fetch_layer_a_subset(d, c("cl_a", "cl_b"))

  expect_named(sub, c("cluster_pooled", "per_study_de", "qc_report_subset",
                       "mega_aug_diagnostics", "stage4_run_id"),
               ignore.order = TRUE)
  expect_equal(sort(unique(sub$cluster_pooled$cluster_id)), c("cl_a", "cl_b"))
  expect_equal(sort(unique(sub$per_study_de$cluster_id)), "cl_b")  # cl_a is mega, no per_study
  expect_equal(sub$stage4_run_id, "deadbeef")
  expect_equal(nrow(sub$mega_aug_diagnostics), 1L)
})

test_that(".fetch_layer_a_subset error if stage4_dir missing files", {
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  expect_error(
    simulomicsr:::.fetch_layer_a_subset(d, "cl_a"),
    "cluster_pooled.parquet not found"
  )
})

test_that(".assemble_cluster_counts builds matrix + metadata for a cluster", {
  skip_if_not_installed("rhdf5")

  # Create synthetic counts matrix: 50 genes × 6 samples
  set.seed(42)
  counts <- matrix(rpois(50 * 6, lambda = 100), nrow = 50,
                   dimnames = list(paste0("G", 1:50), paste0("GSM", 1:6)))

  # Cluster assignment: 2 studies × 3 sample × (treatment | control)
  cluster_id <- "test_cl"
  per_cluster_samples <- tibble::tibble(
    sample_id = paste0("GSM", 1:6),
    study_id  = c("GSE1", "GSE1", "GSE1", "GSE2", "GSE2", "GSE2"),
    treatment = c("treated", "treated", "control", "treated", "control", "control")
  )

  # Fake counts cache: pre-saved RDS keyed by study
  cache_dir <- tempfile("counts_cache_")
  dir.create(cache_dir)
  on.exit(unlink(cache_dir, recursive = TRUE))

  # Save counts per (cluster, study) — mimic Stage 4 cache structure
  cache_manifest <- list(
    test_cl = list(
      GSE1 = file.path(cache_dir, "test_cl_GSE1.rds"),
      GSE2 = file.path(cache_dir, "test_cl_GSE2.rds")
    )
  )
  saveRDS(counts[, 1:3], cache_manifest$test_cl$GSE1)
  saveRDS(counts[, 4:6], cache_manifest$test_cl$GSE2)

  result <- simulomicsr:::.assemble_cluster_counts(
    cluster_id = "test_cl",
    per_cluster_samples = per_cluster_samples,
    cache_manifest = cache_manifest
  )

  expect_named(result, c("counts", "metadata"), ignore.order = TRUE)
  expect_equal(dim(result$counts), c(50L, 6L))
  expect_equal(colnames(result$counts), paste0("GSM", 1:6))
  expect_equal(rownames(result$counts), paste0("G", 1:50))
  expect_s3_class(result$metadata, "tbl_df")
  expect_equal(nrow(result$metadata), 6L)
  expect_equal(result$metadata$treatment,
               c("treated", "treated", "control", "treated", "control", "control"))
})
