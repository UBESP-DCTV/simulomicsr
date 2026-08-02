# Test integration mini end-to-end per build_stage4_results.
#
# v1 mini: usa dry_run_inputs_only = TRUE per saltare il path DE/pooling
# (le fixtures make_test_stage4_input non forniscono attribute `study_dispatch`
# atteso da .run_per_study_de_all). Full integration test viene in Task 12+
# con dispatch completo.

test_that("build_stage4_results end-to-end produce stage4_result list", {
  skip_if_not_installed("limma")
  skip_if_not_installed("arrow")

  # Mini fixture: 3 cluster, fetch_fn mock (non chiamato in dry_run)
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

  # v1 mini: dry_run path; full integration in Task 12+
  result <- build_stage4_results(
    stage3_clusters = input$clusters,
    h5_metadata = input$h5_metadata,
    config = cfg,
    fetch_fn = mock_fetch,
    stage3_run_id = "mocked3",
    h5_path_for_hash = NULL,
    dry_run_inputs_only = TRUE
  )

  expect_s3_class(result, "stage4_result")
  expect_named(result, c("per_study_de", "cluster_pooled", "eligible_clusters",
                         "qc_report", "non_processable", "config",
                         "run_metadata"),
               ignore.order = TRUE)
  expect_true(nchar(result$run_metadata$run_id) == 8L)
})

test_that("run_metadata dello Stadio 4 registra la provenienza dello Stadio 3", {
  skip_if_not_installed("limma")
  skip_if_not_installed("arrow")
  skip_if_not_installed("digest")

  # Provato il 2026-08-02: l'unica occorrenza di "stage3" nel run_metadata era
  # la chiave `stage3_algorithm`. Il run_id dello Stadio 3 entrava nell'hash e
  # veniva buttato: l'artefatto non sapeva da dove veniva.
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  # Fixture minimale su disco: l'impronta e' del CONTENUTO di clusters.rds,
  # non una stringa scritta a mano.
  tmp_dir <- withr::local_tempdir()
  saveRDS(input$clusters, file.path(tmp_dir, "clusters.rds"))
  sha <- digest::digest(file = file.path(tmp_dir, "clusters.rds"), algo = "sha256")

  result <- build_stage4_results(
    stage3_clusters = input$clusters,
    h5_metadata = input$h5_metadata,
    config = cfg,
    stage3_run_id = "364547a7",
    stage3_dir = tmp_dir,
    stage3_clusters_sha256 = sha,
    h5_path_for_hash = NULL,
    dry_run_inputs_only = TRUE
  )

  expect_identical(result$run_metadata$stage3$run_id, "364547a7")
  expect_identical(result$run_metadata$stage3$dir, tmp_dir)
  expect_identical(result$run_metadata$stage3$clusters_sha256, sha)
})

test_that("run_metadata dello Stadio 4 resta valido senza provenienza Stadio 3 (retrocompat)", {
  skip_if_not_installed("limma")
  skip_if_not_installed("arrow")

  # Chiamante pre-Task11: nessun stage3_dir / stage3_clusters_sha256 passato.
  # Il campo deve esistere comunque, con valore mancante, non un errore.
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  result <- build_stage4_results(
    stage3_clusters = input$clusters,
    h5_metadata = input$h5_metadata,
    config = cfg,
    stage3_run_id = "364547a7",
    h5_path_for_hash = NULL,
    dry_run_inputs_only = TRUE
  )

  expect_identical(result$run_metadata$stage3$run_id, "364547a7")
  expect_true(is.na(result$run_metadata$stage3$dir))
  expect_true(is.na(result$run_metadata$stage3$clusters_sha256))
})
