# Test integration end-to-end per build_layer_b_results().
# Helper make_fake_layer_a_dir() / make_fake_counts_cache() definiti
# inline (NON in helper-layer-b-fixtures.R) per evitare di sporcare
# gli altri test del modulo layer-b.

make_fake_layer_a_dir <- function() {
  d <- tempfile("stage4_full_")
  dir.create(d)

  # Cluster pooled: 2 cluster (1 mega + 1 mega_aug), 100 geni ciascuno
  set.seed(42)
  build_cp_chunk <- function(cluster_id, method, n_genes = 100, n_sig = 25) {
    logFC <- c(rnorm(n_sig, 0, 3), rnorm(n_genes - n_sig, 0, 0.3))
    pv <- c(runif(n_sig, 1e-10, 0.001), runif(n_genes - n_sig, 0.05, 1))
    # Pre-calcola scalari fuori da tibble() per evitare data-mask shadowing
    # del nome `method` (tidy-eval lo risolverebbe come colonna appena costruita).
    k_eff_scalar <- if (method == "mega") 5L else 2L
    n_aug_scalar <- if (method == "mega_aug") 8L else NA_integer_
    tibble::tibble(
      cluster_id = cluster_id,
      gene = paste0("HGNC", seq_len(n_genes)),
      method = method,
      logFC_pool = logFC,
      SE_pool = abs(logFC) / 5 + 0.1,
      p_value_pool = pv,
      tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
      k_effective = k_eff_scalar,
      n_baseline_studies_augmented = n_aug_scalar,
      FDR_BH_within_cluster = p.adjust(pv, "BH"),
      direction_applied = "none"
    )
  }
  cp <- dplyr::bind_rows(
    build_cp_chunk("cl_mega_1", "mega"),
    build_cp_chunk("cl_aug_1", "mega_aug")
  )
  arrow::write_parquet(cp, file.path(d, "cluster_pooled.parquet"))

  # Per-study DE solo per mega_aug
  ps <- tibble::tibble(
    cluster_id = rep("cl_aug_1", 200L),
    study_id   = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 100L),
    gene       = rep(paste0("HGNC", 1:100), 2L),
    logFC      = rnorm(200, 0, 1),
    SE         = abs(rnorm(200, 0.3, 0.1)),
    p_value    = runif(200, 0, 1),
    t_stat     = rnorm(200, 0, 2),
    n_treated  = 3L, n_control = 3L,
    direction_applied = "none"
  )
  arrow::write_parquet(ps, file.path(d, "per_study_de.parquet"))

  qc <- list(
    qc_drops_sample = tibble::tibble(),
    qc_drops_study = tibble::tibble(),
    qc_drops_cluster = tibble::tibble(),
    pooling_warnings = tibble::tibble(),
    mega_aug_diagnostics = tibble::tibble(
      cluster_id = "cl_aug_1", bidir_collapsed_to_mono = FALSE,
      comparison_kind_overall = "direct_overlap"
    )
  )
  saveRDS(qc, file.path(d, "qc_report.rds"))
  saveRDS(tibble::tibble(), file.path(d, "non_processable.rds"))

  meta <- list(
    run_id = "fakea4ce",
    config = list(de_engine = list(mega = "dream"))
  )
  jsonlite::write_json(meta, file.path(d, "run_metadata.json"), auto_unbox = TRUE)

  d
}

make_fake_counts_cache <- function(cluster_ids, samples_per_study = 6L) {
  cache_dir <- tempfile("counts_cache_")
  dir.create(cache_dir)

  manifest <- list()
  for (cl_id in cluster_ids) {
    studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
    manifest[[cl_id]] <- list()
    for (s in studies) {
      counts <- matrix(
        rpois(100 * samples_per_study, lambda = 100),
        nrow = 100,
        dimnames = list(
          paste0("HGNC", 1:100),
          paste0(s, "_GSM", 1:samples_per_study)
        )
      )
      path <- file.path(cache_dir, sprintf("%s_%s.rds", cl_id, s))
      saveRDS(counts, path)
      manifest[[cl_id]][[s]] <- path
    }
  }
  list(dir = cache_dir, manifest = manifest)
}

test_that("build_layer_b_results end-to-end on mini fixture", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("clusterProfiler")

  stage4_dir <- make_fake_layer_a_dir()
  on.exit(unlink(stage4_dir, recursive = TRUE), add = TRUE)

  cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))
  on.exit(unlink(cache$dir, recursive = TRUE), add = TRUE)

  # Build per_cluster_samples: 2 study x 3 sample per study x 2 treatment
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
  cfg$go_enrichment <- FALSE  # skip in test (slow + needs real symbols)

  result <- build_layer_b_results(
    stage4_dir = stage4_dir,
    selection = selection,
    counts_cache_manifest = cache$manifest,
    per_cluster_samples_provider = per_cluster_samples_provider,
    config = cfg,
    out_dir = tempfile("lb_out_")
  )

  expect_s3_class(result, "layer_b_result")
  expect_equal(length(result$cluster_bundles), 2L)
  expect_true(file.exists(file.path(result$dir, "selection_resolved.csv")))
  expect_true(file.exists(file.path(result$dir, "cl_mega_1", "volcano.png")))
  expect_true(file.exists(file.path(result$dir, "cl_aug_1", "forest.png")))
  # mega should NOT have forest png (skip-graceful)
  expect_false(file.exists(file.path(result$dir, "cl_mega_1", "forest.png")))
  expect_match(result$run_metadata$run_id, "^[a-f0-9]{8}$")
})
