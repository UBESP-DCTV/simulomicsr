test_that("layer_b_default_config returns expected schema", {
  config <- layer_b_default_config()

  # Top-level keys
  expect_named(
    config,
    c("top_n_forest", "top_n_heatmap", "top_n_table", "top_n_volcano_labels",
      "fdr_threshold", "palette", "language", "heatmap_normalize",
      "go_enrichment", "save_svg", "dpi", "min_genes_for_go_ora",
      "max_heatmap_samples", "top_genes_min_k_frac", "heatmap_mostra_studi",
      "figure_escluse", "volcano_quota_asse"),
    ignore.order = TRUE
  )

  # Default values (consolidati nel brainstorming)
  expect_equal(config$top_n_forest, 10L)
  expect_equal(config$top_n_heatmap, 30L)
  expect_equal(config$top_n_table, 30L)
  expect_equal(config$top_n_volcano_labels, 15L)
  expect_equal(config$fdr_threshold, 0.05)
  expect_equal(config$palette, "viridis")
  expect_equal(config$language, "en")
  expect_true(config$heatmap_normalize)
  expect_true(config$go_enrichment)
  expect_true(config$save_svg)
  expect_equal(config$dpi, 300L)
  expect_equal(config$min_genes_for_go_ora, 200L)
  expect_equal(config$max_heatmap_samples, 100L)
  expect_false(config$heatmap_mostra_studi)
})

test_that("layer_b_default_config returns plain list (serializable to JSON)", {
  config <- layer_b_default_config()
  json <- jsonlite::toJSON(config, auto_unbox = TRUE)
  parsed <- jsonlite::fromJSON(json)
  expect_equal(parsed$top_n_forest, 10L)
  expect_equal(parsed$fdr_threshold, 0.05)
})

# --- Task 8 del ridisegno: config del ridisegno -----------------------------
# `heatmap_mostra_studi` era gia' presente (Task 5): il test sopra copre gia'
# il suo default. Qui solo le due chiavi NUOVE di questo task.

test_that("la config porta le tre chiavi del ridisegno", {
  cfg <- layer_b_default_config()
  expect_false(cfg$heatmap_mostra_studi)
  expect_setequal(cfg$figure_escluse, c("ma", "heterogeneity"))
  expect_equal(cfg$volcano_quota_asse, 0.6)
})

test_that("build_layer_b_results non genera ma.png/heterogeneity.png con la config di default", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)
  cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))
  per_cluster_samples_provider <- function(cluster_id) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    tibble::tibble(
      sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6), paste0("GSE_PAIR_B_GSM", 1:6)),
      study_id  = rep(studies, each = 6L),
      treatment = rep(c("control", "control", "control", "treated", "treated", "treated"), 2L)
    )
  }
  selection <- tibble::tibble(
    cluster_id = c("cl_mega_1", "cl_aug_1"),
    label_paper = c("MegaTest", "AugTest"),
    priority = c(1L, 2L),
    notes = c("", "")
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
    out_dir = tempfile("lb_out_config_")
  )

  # figure escluse di default: nessun ma.png/heterogeneity.png nel bundle,
  # su nessuno dei due cluster.
  for (cl_id in c("cl_mega_1", "cl_aug_1")) {
    expect_false(file.exists(file.path(result$dir, cl_id, "ma.png")))
    expect_false(file.exists(file.path(result$dir, cl_id, "heterogeneity.png")))
  }
  # ma la selezione non tocca il codice: chiamate dirette continuano a
  # funzionare (verificato dalla suite ma/heterogeneity esistente, non qui).

  # Con figure_escluse svuotato, le due figure tornano (per il cluster
  # rem/mega_aug che le supporta): e' selezione, non cancellazione.
  cfg2 <- cfg
  cfg2$figure_escluse <- character(0)
  result2 <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    h5_path = NULL,
    fetch_counts_fn = cache$fetch_counts_fn,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg2,
    out_dir = tempfile("lb_out_config2_")
  )
  expect_true(file.exists(file.path(result2$dir, "cl_aug_1", "heterogeneity.png")))
})
