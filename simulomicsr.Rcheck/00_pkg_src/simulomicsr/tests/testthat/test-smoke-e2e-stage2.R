test_that("smoke E2E classify_study contro gpt-5.5 produce study_design valido (gated OPENAI_API_KEY)", {
  skip_if(Sys.getenv("OPENAI_API_KEY") == "")
  skip_if_not_installed("rentrez")

  facts_path <- system.file(
    "extdata/stage2-fixtures-mini/GSE145941-sample-facts.json",
    package = "simulomicsr"
  )
  summary_path <- system.file(
    "extdata/stage2-fixtures-mini/GSE145941-study-summary.json",
    package = "simulomicsr"
  )
  skip_if(!nzchar(facts_path) || !nzchar(summary_path),
          "fixture stage2-fixtures-mini non trovate (rebuild pacchetto?)")

  facts_list <- jsonlite::read_json(facts_path, simplifyVector = FALSE)
  study_summary <- jsonlite::read_json(summary_path, simplifyVector = FALSE)

  cache <- cache_init(withr::local_tempdir(), namespace = "stage2-smoke")
  result <- classify_study(
    series_id = "GSE145941",
    sample_facts_list = facts_list,
    study_summary = study_summary,
    provider = "openai", model = "gpt-5.5",
    cache = cache
  )

  expect_null(result$.invalid_reason)
  expect_equal(result$series_id, "GSE145941")
  expect_equal(result$extraction$schema_version, "stage2.v1")
  expect_true(result$extraction$confidence >= 0 && result$extraction$confidence <= 1)
  expect_true(length(result$replicate_groups) >= 1L)

  # Validazione schema esplicita
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  validator <- compile_schema(schema_path)
  validation <- validate_json(result, validator = validator)
  expect_true(validation$valid,
              info = paste(validation$errors, collapse = "\n"))
})
