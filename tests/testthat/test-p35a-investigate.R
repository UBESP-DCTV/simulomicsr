test_that("compare_with_gold produce shape attesa", {
  verbose_design <- list(
    series_id = "GSE145941",
    replicate_groups = list(
      list(group_id = "g1", sample_ids = c("GSM1", "GSM2"),
           design_role = "perturbed"),
      list(group_id = "g2", sample_ids = c("GSM3", "GSM4"),
           design_role = "untreated_control")
    ),
    design_kind = "treatment_vs_untreated",
    .reasoning = "extended chain-of-thought from gpt-5.5"
  )
  gold_xlsx <- tibble::tibble(
    geo_accession = c("GSM1", "GSM2", "GSM3", "GSM4"),
    series_id = "GSE145941",
    string = c("10Gy", "10Gy", "0Gy", "0Gy"),
    gold_binary = c("treated", "treated", "control", "control")
  )
  original_design <- list(
    series_id = "GSE145941",
    replicate_groups = list(
      list(group_id = "g1", sample_ids = c("GSM1"),
           design_role = "perturbed"),
      list(group_id = "g2", sample_ids = c("GSM2", "GSM3", "GSM4"),
           design_role = "untreated_control")
    )
  )
  out <- compare_with_gold(verbose_design, gold_xlsx, original_design)
  expect_true(all(c("geo_accession", "gold_binary",
                    "simulomicsr_p3_role", "simulomicsr_reclassify_role",
                    "p3_predicted_binary", "reclassify_predicted_binary",
                    "agreement") %in% names(out)))
  expect_equal(nrow(out), 4L)
  expect_true(out$agreement[out$geo_accession == "GSM1"])
})

test_that("reclassify_verbose mocked ritorna struttura design+reasoning", {
  fake_design <- list(
    series_id = "GSE145941",
    replicate_groups = list(),
    .reasoning = "fake CoT"
  )
  testthat::with_mocked_bindings(
    classify_study = function(...) fake_design,
    .package = "simulomicsr",
    {
      result <- reclassify_verbose(
        series_id = "GSE145941",
        sample_facts_list = list(),
        study_summary = list(),
        cache = NULL
      )
      expect_equal(result$series_id, "GSE145941")
      expect_true(!is.null(result$.reasoning))
    }
  )
})
