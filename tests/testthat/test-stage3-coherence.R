test_that(".normalize_control_type collassa sinonimi di veicolo/controllo alla stessa classe", {
  syn <- c("DMSO", "vehicle", "vehicle control", "untreated", "untreated control",
           "control", "mock", "PBS", "0.1% DMSO")
  cls <- vapply(syn, simulomicsr:::.normalize_control_type, character(1))
  expect_equal(length(unique(cls)), 1L)  # tutti -> stessa classe "vehicle_untreated"
})

test_that(".normalize_control_type tiene distinti controlli SEMANTICAMENTE diversi", {
  expect_false(identical(
    simulomicsr:::.normalize_control_type("normoxia (20% O2)"),
    simulomicsr:::.normalize_control_type("control diet")))
  expect_false(identical(
    simulomicsr:::.normalize_control_type("scrambled shRNA"),
    simulomicsr:::.normalize_control_type("DMSO")))
})

test_that(".normalize_control_type ignora dose/unita'/numeri nella stessa classe biologica", {
  expect_equal(
    simulomicsr:::.normalize_control_type("10 nM tamoxifen"),
    simulomicsr:::.normalize_control_type("100 nM tamoxifen"))
})

test_that(".reconstruct_cluster_contrasts ricostruisce >=1 contrasto per un cluster poolato noto", {
  # Path relativi a tests/testthat/ (working dir di testthat durante il run,
  # vedi test-stage3-perf-budget.R per lo stesso pattern).
  S3 <- testthat::test_path("..", "..", "analysis", "p4-output",
                             "20260720T180625Z-stage3-v10-364547a7")
  S2 <- testthat::test_path("..", "..", "analysis", "p4-output",
                             "p4-fase-f4-stage2-master-v3.jsonl")
  skip_if_not(dir.exists(S3))
  asg <- arrow::read_parquet(file.path(S3, "assignments.parquet"))
  s2  <- simulomicsr:::.load_stage2_master(S2)
  s2_idx <- simulomicsr:::.index_stage2_master(s2)
  asg_by <- split(asg$record_id, asg$cluster_id)
  df <- simulomicsr:::.reconstruct_cluster_contrasts(
    "group_L4_b6a3eabd", "group", asg_by, s2_idx)   # SARS-CoV-2 poolato
  expect_gt(nrow(df), 1L)
  expect_true(all(c("study_id","treated_label","control_label","design_kind") %in% names(df)))
})
