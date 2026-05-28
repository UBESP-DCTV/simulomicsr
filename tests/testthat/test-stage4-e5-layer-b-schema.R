# test-stage4-e5-layer-b-schema.R — FASE E5 RED ALERT
#
# Verifica compatibilita' Layer B con il nuovo schema post-E1-E3:
#   - top_gene_table CSV ha colonne gene_id + gene_symbol (no 'gene' legacy)
#   - schema_versions Layer B bumpato a stage4_algorithm 'v2_ensembl_gene_axis'
#   - Layer B build end-to-end su fixture aggiornato produce PNG senza errori

test_that("E5 T1 build_layer_b_results schema_versions stage4_algorithm = v2_ensembl_gene_axis", {
  skip_if_not_installed("ComplexHeatmap")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache("cl_mega_1")
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6),
                     paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control",
                         "treated", "treated", "treated"), 2L)
    )
  }

  selection <- tibble::tibble(
    cluster_id = "cl_mega_1",
    label_paper = "MegaTest_E5",
    priority = 1L,
    notes = ""
  )

  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("e5_smoke_")
  )

  # schema_versions Layer B post-E5 bumpa stage4_algorithm
  meta_json <- jsonlite::read_json(file.path(result$dir, "run_metadata.json"))
  expect_equal(meta_json$schema_versions$stage4_algorithm,
               "v2_ensembl_gene_axis")
  expect_equal(meta_json$schema_versions$layer_b_algorithm, "v1")
})

test_that("E5 T2 top_gene_table CSV contiene gene_id + gene_symbol post-E1", {
  skip_if_not_installed("ComplexHeatmap")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache("cl_mega_1")
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6),
                     paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control",
                         "treated", "treated", "treated"), 2L)
    )
  }

  selection <- tibble::tibble(
    cluster_id = "cl_mega_1",
    label_paper = "MegaTest_E5_csv",
    priority = 1L,
    notes = ""
  )

  cfg <- layer_b_default_config()
  cfg$go_enrichment <- FALSE

  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("e5_csv_")
  )

  csv_path <- file.path(result$dir, "cl_mega_1", "top_genes.csv")
  expect_true(file.exists(csv_path))
  csv_df <- readr::read_csv(csv_path, show_col_types = FALSE)
  expect_true("gene_id" %in% names(csv_df))
  expect_true("gene_symbol" %in% names(csv_df))
  expect_false("gene" %in% names(csv_df))  # colonna legacy rimossa
  # gene_id prefisso ENSG
  expect_true(any(grepl("^ENSG", csv_df$gene_id)))
})
