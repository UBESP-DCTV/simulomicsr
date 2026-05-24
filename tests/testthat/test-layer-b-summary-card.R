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
