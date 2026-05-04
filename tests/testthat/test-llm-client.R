test_that("llm_call_structured chiama l'adapter del provider e ritorna il risultato parsed", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")

  res <- llm_call_structured(
    provider        = "mock",
    model           = "mock-1",
    messages        = list(list(role = "user", content = "ping")),
    response_schema = schema,
    cache           = NULL,
    .mock_response  = list(question = "ping", answer = "pong", confidence = 0.9)
  )

  expect_equal(res$value$answer, "pong")
  expect_equal(res$provider, "mock")
  expect_equal(res$model, "mock-1")
  expect_true(res$validated)
  expect_false(res$cache_hit)
})

test_that("llm_call_structured FALLISCE se la risposta non rispetta lo schema", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")

  expect_error(
    llm_call_structured(
      provider        = "mock",
      model           = "mock-1",
      messages        = list(list(role = "user", content = "ping")),
      response_schema = schema,
      cache           = NULL,
      .mock_response  = list(question = "ping", answer = "pong", confidence = 99) # > 1
    ),
    class = "simulomicsr_schema_error"
  )
})

test_that("llm_call_structured usa la cache: hit non chiama l'adapter", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  cache  <- cache_init(new_cache_dir(), namespace = "stage1")

  call_count <- 0L
  fake_adapter <- function(...) {
    call_count <<- call_count + 1L
    list(question = "ping", answer = "pong", confidence = 0.9)
  }

  args <- list(
    provider        = "mock",
    model           = "mock-1",
    messages        = list(list(role = "user", content = "ping")),
    response_schema = schema,
    cache           = cache,
    cache_namespace_version = "stage1.v3",
    .mock_adapter   = fake_adapter
  )

  r1 <- do.call(llm_call_structured, args)
  expect_false(r1$cache_hit)
  expect_equal(call_count, 1L)

  r2 <- do.call(llm_call_structured, args)
  expect_true(r2$cache_hit)
  expect_equal(call_count, 1L)  # adapter NON richiamato
  expect_equal(r2$value, r1$value)
})

test_that("llm_call_structured rifiuta provider sconosciuti con errore tipizzato", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  expect_error(
    llm_call_structured(
      provider = "ollama-not-supported",
      model    = "x",
      messages = list(list(role = "user", content = "?")),
      response_schema = schema
    ),
    class = "simulomicsr_unknown_provider"
  )
})

test_that("llm_call_structured(provider='anthropic') intercetta tramite .mock_adapter", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  withr::local_envvar(ANTHROPIC_API_KEY = "sk-ant-fake")

  res <- llm_call_structured(
    provider = "anthropic",
    model = "claude-haiku-4-5",
    messages = list(list(role = "user", content = "Say pong.")),
    response_schema = schema,
    .mock_adapter = function(model, messages, response_schema, ...) {
      list(question = "Say pong.", answer = "pong", confidence = 0.95)
    }
  )

  expect_true(res$validated)
  expect_equal(res$value$answer, "pong")
  expect_equal(res$provider, "anthropic")
})
