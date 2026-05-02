test_that("build_prompt_stage2 ritorna shape messages OpenAI", {
  facts_list <- list(
    jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  )
  study_summary <- list(
    series_id = "GSE41166",
    title = "VEGF time course HUVEC",
    summary = "Primary HUVEC stimulated with VEGF; t=0,1,6,24h.",
    overall_design = NA_character_
  )
  out <- simulomicsr:::build_prompt_stage2(
    series_id = "GSE41166",
    sample_facts_list = facts_list,
    study_summary = study_summary,
    model = "openai:gpt-5.5"
  )
  expect_type(out, "list")
  expect_named(out, c("messages", "schema_path"))
  expect_length(out$messages, 2L)
  expect_equal(out$messages[[1L]]$role, "system")
  expect_equal(out$messages[[2L]]$role, "user")
  expect_match(out$messages[[1L]]$content, "study_design", ignore.case = TRUE)
  expect_match(out$messages[[1L]]$content, "design_kind", ignore.case = TRUE)
  expect_match(out$messages[[2L]]$content, "GSE41166")
  expect_match(out$messages[[2L]]$content, "GSM1009636")
})

test_that("build_prompt_stage2 system prompt contiene vocabolari sec.4.1+sec.4.2", {
  facts_list <- list(jsonlite::read_json(
    testthat::test_path("fixtures/sample-facts-vegf-huvec.json")))
  study_summary <- list(series_id = "GSE41166", title = "x", summary = "y",
                       overall_design = NA_character_)
  out <- simulomicsr:::build_prompt_stage2("GSE41166", facts_list, study_summary,
                                           "openai:gpt-5.5")
  sys <- out$messages[[1L]]$content
  for (kind in c("treatment_vs_vehicle", "time_course", "knockdown_panel",
                 "factorial", "case_control_disease")) {
    expect_match(sys, kind, fixed = TRUE)
  }
  for (role in c("perturbed", "vehicle_control", "baseline_t0", "case", "comparison")) {
    expect_match(sys, role, fixed = TRUE)
  }
})

test_that("build_prompt_stage2 user prompt contiene tutti i sample_ids forniti", {
  facts_a <- jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  facts_b <- facts_a
  facts_b$geo_accession <- "GSM1009638"
  out <- simulomicsr:::build_prompt_stage2(
    "GSE41166", list(facts_a, facts_b),
    list(series_id = "GSE41166", title = "t", summary = "s", overall_design = NA),
    "openai:gpt-5.5"
  )
  expect_match(out$messages[[2L]]$content, "GSM1009636")
  expect_match(out$messages[[2L]]$content, "GSM1009638")
})

test_that("parse_stage2_response forza series_id da input (no trust LLM)", {
  raw <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))
  raw$series_id <- "GSE99999"  # LLM ha sbagliato
  parsed <- simulomicsr:::parse_stage2_response(
    raw, series_id = "GSE41166", sample_count = 4L,
    model = "openai:gpt-5.5"
  )
  expect_equal(parsed$series_id, "GSE41166")  # forzato dal chiamante
})

test_that("parse_stage2_response imposta input_sample_count e model", {
  raw <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))
  raw$extraction$input_sample_count <- 0L  # LLM ha sbagliato
  raw$extraction$model <- "wrong-model"
  parsed <- simulomicsr:::parse_stage2_response(
    raw, series_id = "GSE41166", sample_count = 12L,
    model = "openai:gpt-5.5"
  )
  expect_equal(parsed$extraction$input_sample_count, 12L)
  expect_equal(parsed$extraction$model, "openai:gpt-5.5")
})

test_that("parse_stage2_response garantisce schema_version='stage2.v1'", {
  raw <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))
  raw$extraction$schema_version <- "stage2.v0"
  parsed <- simulomicsr:::parse_stage2_response(
    raw, series_id = "GSE41166", sample_count = 4L,
    model = "openai:gpt-5.5"
  )
  expect_equal(parsed$extraction$schema_version, "stage2.v1")
})

test_that("classify_study orchestratore: chiama llm_call_structured con messages stage2", {
  facts_a <- jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  expected_design <- jsonlite::read_json(testthat::test_path("fixtures/stage2-valid-vegf-huvec.json"))

  cache <- cache_init(withr::local_tempdir(), namespace = "stage2")

  # Mock llm_call_structured: cattura input, ritorna fixture con shape reale
  captured <- list(messages = NULL)
  out <- withr::with_envvar(
    c(SIMULOMICSR_LLM_PROVIDER_FORCE_MOCK = "1"),
    {
      local_mocked_bindings(
        llm_call_structured = function(provider, model, messages, response_schema,
                                       cache = NULL, ...) {
          captured$messages <<- messages
          list(
            value     = expected_design,
            provider  = provider,
            model     = model,
            validated = TRUE,
            cache_hit = FALSE,
            raw_response = expected_design
          )
        },
        .package = "simulomicsr"
      )
      classify_study(
        series_id = "GSE41166",
        sample_facts_list = list(facts_a),
        study_summary = list(series_id = "GSE41166", title = "t", summary = "s",
                             overall_design = NA),
        provider = "openai",
        model = "gpt-5.5",
        cache = cache
      )
    }
  )
  expect_equal(out$series_id, "GSE41166")
  expect_equal(out$extraction$schema_version, "stage2.v1")
  expect_equal(out$extraction$input_sample_count, 1L)
  expect_match(out$extraction$model, "gpt-5.5")
  expect_equal(captured$messages[[1L]]$role, "system")
})

test_that("classify_study propaga errore LLM con .invalid_reason", {
  facts_a <- jsonlite::read_json(testthat::test_path("fixtures/sample-facts-vegf-huvec.json"))
  cache <- cache_init(withr::local_tempdir(), namespace = "stage2")
  out <- withr::with_envvar(
    c(SIMULOMICSR_LLM_PROVIDER_FORCE_MOCK = "1"),
    {
      local_mocked_bindings(
        llm_call_structured = function(...) {
          rlang::abort(
            "schema_validation_failed: design_kind not in enum",
            class = "simulomicsr_schema_error",
            errors = "design_kind not in enum"
          )
        },
        .package = "simulomicsr"
      )
      classify_study(
        series_id = "GSE41166",
        sample_facts_list = list(facts_a),
        study_summary = list(series_id = "GSE41166", title = "t", summary = "s",
                             overall_design = NA),
        provider = "openai", model = "gpt-5.5", cache = cache
      )
    }
  )
  expect_equal(out$series_id, "GSE41166")
  expect_match(out$.invalid_reason, "schema_validation_failed|llm_call_failed")
})
