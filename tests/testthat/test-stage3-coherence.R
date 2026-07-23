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

test_that(".cluster_coherence_signals conta i tipi di controllo distinti e i degeneri", {
  df <- data.frame(
    study_id = c("A","B","C"),
    treated_label = c("drugX","drugX","drugX"), treated_fl = c("t=x","t=x","t=x"),
    control_label = c("DMSO","vehicle","control diet"),   # 2 tipi: vehicle_untreated + diet
    control_fl    = c("c=dmso","c=veh","c=x"),
    design_kind = c("treatment_vs_vehicle","treatment_vs_vehicle","dietary"),
    stringsAsFactors = FALSE)
  s <- simulomicsr:::.cluster_coherence_signals(df)
  expect_equal(s$n_resolved, 3L)
  expect_equal(s$n_control_types, 2L)
  expect_equal(s$n_design_kinds, 2L)
  expect_equal(s$n_degenerate, 0L)
})

test_that(".cluster_coherence_signals flagga i membri degeneri (treated==control)", {
  df <- data.frame(
    study_id = "A", treated_label = "case", treated_fl = "g=case",
    control_label = "case", control_fl = "g=case",
    design_kind = "case_control_disease", stringsAsFactors = FALSE)
  s <- simulomicsr:::.cluster_coherence_signals(df)
  expect_equal(s$n_degenerate, 1L)
  expect_equal(s$frac_degenerate, 1.0)
})

test_that(".coherence_verdict: D2 e' autoritativo (one_contrast => coherent anche con control-type>1)", {
  # senza deep-dive, control eterogeneo (floor) => minestrone
  s <- list(n_resolved=6L, n_control_types=8L, control_homogeneity=1/8,
            n_design_kinds=3L, n_degenerate=0L, frac_degenerate=0)
  expect_equal(simulomicsr:::.coherence_verdict(s), "minestrone")
  # ma se D2 dice one_contrast, e' AUTORITATIVO => coherent (il floor non lo declassa)
  expect_equal(simulomicsr:::.coherence_verdict(s, deepdive="one_contrast"), "coherent")
  # D2 multi_contrast => minestrone
  expect_equal(simulomicsr:::.coherence_verdict(s, deepdive="multi_contrast"), "minestrone")
})
test_that(".coherence_verdict: degenere prevale su tutto", {
  s <- list(n_resolved=4L, n_control_types=1L, control_homogeneity=1,
            n_design_kinds=1L, n_degenerate=3L, frac_degenerate=0.75)
  expect_equal(simulomicsr:::.coherence_verdict(s, deepdive="one_contrast"), "degenerate")
})
test_that(".coherence_verdict: control-omogeneo deterministico => coherent; copertura bassa => uncertain", {
  s1 <- list(n_resolved=5L, n_control_types=1L, control_homogeneity=1,
             n_design_kinds=1L, n_degenerate=0L, frac_degenerate=0)
  expect_equal(simulomicsr:::.coherence_verdict(s1), "coherent")
  s2 <- list(n_resolved=1L, n_control_types=1L, control_homogeneity=1,
             n_design_kinds=1L, n_degenerate=0L, frac_degenerate=0)
  expect_equal(simulomicsr:::.coherence_verdict(s2), "uncertain")
})
test_that(".meta_analysis_valid: AND multi-asse (consistenza NON salva un minestrone)", {
  # minestrone consistente 0.98 (breast docet) => NON valido
  expect_false(simulomicsr:::.meta_analysis_valid("minestrone", frac_degenerate=0, consistency=0.98))
  # coerente + non-degenere + consistente => valido
  expect_true(simulomicsr:::.meta_analysis_valid("coherent", frac_degenerate=0, consistency=0.7))
  # coerente ma consistenza bassa (I2 alto) => NON valido
  expect_false(simulomicsr:::.meta_analysis_valid("coherent", frac_degenerate=0, consistency=0.3))
  # coerente ma consistenza mancante => NON valido (serve la prova)
  expect_false(simulomicsr:::.meta_analysis_valid("coherent", frac_degenerate=0, consistency=NA_real_))
})
