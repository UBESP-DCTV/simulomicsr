test_that(".build_summary_card writes .md with all required fields", {
  cp <- make_fake_cluster_pooled(n_genes = 100, n_sig = 25, cluster_id = "pair_L0_test")
  cp$method <- "mega_aug"
  cp$n_baseline_studies_augmented <- 8L
  cp$k_effective <- 2L

  layer_a_subset <- list(
    cluster_pooled = cp,
    per_study_de = tibble::tibble(),
    qc_report_subset = list(),
    mega_aug_diagnostics = tibble::tibble(
      cluster_id = "pair_L0_test", bidir_collapsed_to_mono = FALSE
    ),
    stage4_run_id = "deadbeef"
  )

  stage3_meta <- tibble::tibble(
    cluster_id = "pair_L0_test",
    kind_effective = "treatment_vs_vehicle",
    agent_id = "CHEBI:17234",
    tissue = "A549",
    safety_min = 0.92
  )

  out_dir <- tempfile("sc_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  selection_row <- tibble::tibble(
    cluster_id = "pair_L0_test",
    label_paper = "IFN_A549_test",
    priority = 1L,
    notes = ""
  )

  result <- simulomicsr:::.build_summary_card(
    cluster_id = "pair_L0_test",
    layer_a_subset = layer_a_subset,
    stage3_metadata = stage3_meta,
    selection_row = selection_row,
    config = cfg,
    out_dir = out_dir
  )

  expect_true(file.exists(result$md_path))
  md_content <- readLines(result$md_path)
  joined <- paste(md_content, collapse = "\n")
  expect_match(joined, "pair_L0_test")
  expect_match(joined, "IFN_A549_test")
  expect_match(joined, "mega_aug")
  expect_match(joined, "k.*=.*2")
  expect_match(joined, "safety_min")
  expect_match(joined, "8")  # n_baseline_studies_augmented
})

test_that(".build_summary_card usa per_cluster_samples per n_total_samples (mega-strict)", {
  # Simula cluster mega-strict: per_study_de vuota (popolata solo per mega_aug),
  # ma per_cluster_samples passato esplicito -> n_total_samples deve essere il
  # nrow di quella tibble.
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 10,
                                 cluster_id = "mega_strict_test")
  cp$method <- "mega"
  cp$k_effective <- 7L

  layer_a_subset <- list(
    cluster_pooled = cp,
    per_study_de = tibble::tibble(),  # vuota: mega-strict path
    qc_report_subset = list(),
    mega_aug_diagnostics = tibble::tibble(),
    stage4_run_id = "deadbeef"
  )

  stage3_meta <- tibble::tibble(
    cluster_id = "mega_strict_test",
    kind_effective = "treatment_vs_vehicle",
    agent_id = "CHEBI:17234",
    tissue = "A549",
    safety_min = 0.95
  )

  per_cluster_samples <- tibble::tibble(
    sample_id = sprintf("GSM%07d", 1:6),
    study_id  = rep(c("GSE001", "GSE002"), each = 3L),
    treatment = rep(c("treated", "control"), 3L)
  )

  out_dir <- tempfile("sc_pcs_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  selection_row <- tibble::tibble(
    cluster_id = "mega_strict_test", label_paper = "MS_test",
    priority = 1L, notes = ""
  )

  res <- simulomicsr:::.build_summary_card(
    cluster_id = "mega_strict_test",
    layer_a_subset = layer_a_subset,
    stage3_metadata = stage3_meta,
    selection_row = selection_row,
    config = cfg,
    out_dir = out_dir,
    per_cluster_samples = per_cluster_samples
  )
  expect_true(file.exists(res$md_path))
  joined <- paste(readLines(res$md_path), collapse = "\n")
  # n_total_samples deve essere 6 (nrow(per_cluster_samples)), NON 'N/A'
  expect_match(joined, "n_total_samples:\\*\\*\\s*6")
  expect_false(grepl("n_total_samples:\\*\\*\\s*N/A", joined))
})

test_that(".build_summary_card fallback a per_study_de quando per_cluster_samples NULL", {
  # Backward-compat: caller legacy NON passa per_cluster_samples -> default NULL
  # -> path legacy via per_study_de.
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 5,
                                 cluster_id = "legacy_test")
  cp$method <- "mega_aug"
  cp$n_baseline_studies_augmented <- 4L
  cp$k_effective <- 2L

  layer_a_subset <- list(
    cluster_pooled = cp,
    per_study_de = tibble::tibble(
      cluster_id = "legacy_test",
      study_id   = c("GSE_A", "GSE_B"),
      n_treated  = c(3L, 4L),
      n_control  = c(3L, 2L)
    ),
    qc_report_subset = list(),
    mega_aug_diagnostics = tibble::tibble(
      cluster_id = "legacy_test", bidir_collapsed_to_mono = FALSE
    ),
    stage4_run_id = "deadbeef"
  )

  stage3_meta <- tibble::tibble(
    cluster_id = "legacy_test",
    kind_effective = "treatment_vs_vehicle",
    agent_id = "CHEBI:17234",
    tissue = "HEK293",
    safety_min = 0.88
  )

  out_dir <- tempfile("sc_legacy_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  selection_row <- tibble::tibble(
    cluster_id = "legacy_test", label_paper = "Legacy",
    priority = 1L, notes = ""
  )

  res <- simulomicsr:::.build_summary_card(
    cluster_id = "legacy_test",
    layer_a_subset = layer_a_subset,
    stage3_metadata = stage3_meta,
    selection_row = selection_row,
    config = cfg,
    out_dir = out_dir
    # per_cluster_samples = NULL (default) -> legacy path
  )
  expect_true(file.exists(res$md_path))
  joined <- paste(readLines(res$md_path), collapse = "\n")
  # Legacy: 3+4+3+2 = 12
  expect_match(joined, "n_total_samples:\\*\\*\\s*12")
})

test_that(".write_narrative_template writes .qmd with required TODO sections", {
  out_dir <- tempfile("nt_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  selection_row <- tibble::tibble(
    cluster_id = "cl_test", label_paper = "Test Case",
    priority = 1L, notes = ""
  )

  qmd_path <- simulomicsr:::.write_narrative_template(
    cluster_id = "cl_test",
    summary_card_path = NULL,
    selection_row = selection_row,
    config = cfg,
    out_dir = out_dir
  )
  expect_true(file.exists(qmd_path))
  content <- paste(readLines(qmd_path), collapse = "\n")
  expect_match(content, "Biological context")
  expect_match(content, "Findings")
  expect_match(content, "Discussion")
  expect_match(content, "TODO")
  expect_match(content, "Test Case")
})

# --- Task 9 (correzione pendente dal Task 8): la lista "## Figures" deve
# elencare SOLO le figure che il bundle produce davvero. Prima di questo fix
# elencava sempre ma.svg/heterogeneity.svg, anche se config$figure_escluse
# (default dal Task 8) le esclude dal build -- riferimenti a file che non
# esistono mai sul disco.

# I tre test che verificavano l'ELENCO DELLE FIGURE dentro narrative.qmd sono
# stati rimossi il 2026-08-06: l'elenco non esiste piu' (richiesta utente --
# ripeteva a parole i nomi dei file che il documento mostra subito sotto, per
# intero e con la loro didascalia). Al suo posto, test-layer-b-v3-report.R
# verifica che l'elenco NON venga piu' scritto.
