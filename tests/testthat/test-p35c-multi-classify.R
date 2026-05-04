test_that("multi_classify_study itera su tutti i model_specs e ritorna lista named", {
  model_specs <- list(
    list(provider = "mock", model = "m1", label = "model_1"),
    list(provider = "mock", model = "m2", label = "model_2")
  )

  fake_response <- list(
    series_id = "GSE0001",
    design_summary = "Fake study with treatment vs vehicle design for unit test.",
    extraction = list(
      schema_version = "stage2.v1",
      model = "mock:m1",
      confidence = 0.5,
      ambiguity_flags = list(),
      input_sample_count = 2L,
      input_truncated = FALSE
    ),
    factors = list(),
    replicate_groups = list(
      list(
        group_id = "g1",
        label_human = "treated group",
        design_role = "perturbed",
        sample_ids = list("GSM1", "GSM2"),
        factor_levels = list()
      )
    ),
    comparisons = list(),
    design_kind = "treatment_vs_vehicle"
  )

  out <- multi_classify_study(
    series_id = "GSE0001",
    sample_facts_list = list(
      list(geo_accession = "GSM1"), list(geo_accession = "GSM2")
    ),
    study_summary = list(title = "T", summary = "S", overall_design = "O"),
    model_specs = model_specs,
    cache = NULL,
    .mock_response = fake_response
  )

  expect_named(out, c("model_1", "model_2"))
  expect_equal(out$model_1$series_id, "GSE0001")
  expect_equal(out$model_1$extraction$model, "mock:m1")
  expect_equal(out$model_2$extraction$model, "mock:m2")
})

test_that("multi_classify_study ritorna invalid_record per il modello che fallisce", {
  model_specs <- list(
    list(provider = "mock", model = "m_ok", label = "ok"),
    list(provider = "mock", model = "m_fail", label = "fail")
  )

  out <- multi_classify_study(
    series_id = "GSE0002",
    sample_facts_list = list(list(geo_accession = "GSM1")),
    study_summary = list(title = "T", summary = "S", overall_design = "O"),
    model_specs = model_specs,
    cache = NULL,
    .mock_adapter_factory = function(label) {
      if (label == "fail") {
        function(...) stop("simulated llm error")
      } else {
        function(...) list(
          series_id = "GSE0002",
          design_summary = "Fake study with treatment vs vehicle design for unit test.",
          extraction = list(
            schema_version = "stage2.v1", model = "mock:m_ok",
            confidence = 0.5, ambiguity_flags = list(),
            input_sample_count = 1L, input_truncated = FALSE
          ),
          factors = list(),
          replicate_groups = list(list(
            group_id = "g1",
            label_human = "treated group",
            design_role = "perturbed",
            sample_ids = list("GSM1"),
            factor_levels = list()
          )),
          comparisons = list(),
          design_kind = "treatment_vs_vehicle"
        )
      }
    }
  )

  expect_named(out, c("ok", "fail"))
  expect_null(out$ok$.invalid_reason)
  expect_equal(out$fail$.invalid_reason, "llm_call_failed")
})
