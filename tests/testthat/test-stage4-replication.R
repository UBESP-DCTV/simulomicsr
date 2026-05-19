test_that("build_stage4_results e' idempotente su stesso input", {
  skip_if_not_installed("limma")
  skip_if_not_installed("arrow")

  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  mock_fetch <- function(gse, sample_ids) {
    set.seed(nchar(gse) * 100)
    m <- matrix(rnbinom(50 * length(sample_ids), size = 5, mu = 200),
                nrow = 50, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:50))
    colnames(m) <- sample_ids
    m
  }

  r1 <- build_stage4_results(input$clusters, input$h5_metadata, cfg,
                               fetch_fn = mock_fetch,
                               stage3_run_id = "fixed_test",
                               dry_run_inputs_only = TRUE)
  r2 <- build_stage4_results(input$clusters, input$h5_metadata, cfg,
                               fetch_fn = mock_fetch,
                               stage3_run_id = "fixed_test",
                               dry_run_inputs_only = TRUE)

  expect_equal(r1$run_metadata$run_id, r2$run_metadata$run_id)
})

test_that("write_stage4_to_dir produce parquet byte-equal per stesso input", {
  skip_if_not_installed("arrow")

  tmp1 <- withr::local_tempdir()
  tmp2 <- withr::local_tempdir()

  s4 <- list(
    per_study_de = tibble::tibble(
      cluster_id = "c1", study_id = "GSE001", gene = "G1",
      logFC = 1.0, SE = 0.1, p_value = 0.001, t_stat = 10.0,
      n_treated = 3L, n_control = 3L, direction_applied = "none"
    ),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "abc12345", timestamp = "2026-05-19T12:00:00Z")
  )

  write_stage4_to_dir(s4, tmp1)
  write_stage4_to_dir(s4, tmp2)

  # Parquet bytes equal (timestamp e' fissato esplicitamente)
  bytes1 <- readBin(file.path(tmp1, "per_study_de.parquet"), "raw", n = 1e6)
  bytes2 <- readBin(file.path(tmp2, "per_study_de.parquet"), "raw", n = 1e6)
  expect_identical(bytes1, bytes2)
})
