test_that("smoke E2E: classify_sample con gpt-5.5 produce sample_fact schema-valido (gated OPENAI_API_KEY)", {
  testthat::skip_if(!nzchar(Sys.getenv("OPENAI_API_KEY")),
                    "OPENAI_API_KEY non impostata")

  schema    <- system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr")
  validator <- compile_schema(schema)
  cache     <- cache_init(new_cache_dir(), namespace = "stage1")

  fix <- read_sample_fixtures_mini()
  row <- fix[fix$stratum == "easy_treated", , drop = FALSE][1, , drop = FALSE]

  res1 <- classify_sample(
    sample_string = row$string,
    geo_accession = row$geo_accession,
    series_id     = row$series_id,
    provider = "openai", model = "gpt-5.5",
    cache = cache
  )

  expect_true(res1$validated)
  expect_false(res1$cache_hit)
  expect_equal(res1$value$geo_accession, row$geo_accession)
  expect_equal(res1$value$series_id,     row$series_id)
  expect_equal(res1$value$extraction$schema_version, "stage1.v3")
  expect_match(res1$value$extraction$model, "^openai:gpt-5\\.5$")
  expect_match(res1$value$extraction$raw_input_hash, "^sha256:[0-9a-f]{64}$")

  v <- validate_json(res1$value, validator = validator)
  expect_true(v$valid, info = paste(v$errors, collapse = " | "))

  res2 <- classify_sample(
    sample_string = row$string,
    geo_accession = row$geo_accession,
    series_id     = row$series_id,
    provider = "openai", model = "gpt-5.5",
    cache = cache
  )
  expect_true(res2$cache_hit)
  expect_equal(res2$value, res1$value)
})
