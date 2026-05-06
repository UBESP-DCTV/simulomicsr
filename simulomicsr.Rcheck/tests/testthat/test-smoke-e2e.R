test_that("E2E reale: llm_call_structured contro OpenAI con cache", {
  skip_on_cran()
  skip_if(
    !nzchar(Sys.getenv("OPENAI_API_KEY")),
    "OPENAI_API_KEY non impostata, skip smoke E2E."
  )

  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  cache  <- cache_init(new_cache_dir(), namespace = "smoke")

  call_spec <- list(
    provider        = "openai",
    model           = "gpt-5.4-mini",
    messages        = list(
      list(role = "system",
           content = "Rispondi in JSON conforme allo schema. Tieni answer breve."),
      list(role = "user",
           content = "Domanda: 'qual e' la capitale d'Italia?'. Rispondi e dichiara confidenza 0..1.")
    ),
    response_schema = schema,
    schema_name     = "llm_call_envelope_v1",
    cache           = cache,
    cache_namespace_version = "smoke.v1"
  )

  r1 <- do.call(llm_call_structured, call_spec)
  expect_true(r1$validated)
  expect_false(r1$cache_hit)
  expect_match(r1$value$answer, "roma", ignore.case = TRUE)
  expect_gte(r1$value$confidence, 0)
  expect_lte(r1$value$confidence, 1)

  r2 <- do.call(llm_call_structured, call_spec)
  expect_true(r2$cache_hit)
  expect_equal(r2$value, r1$value)
})
