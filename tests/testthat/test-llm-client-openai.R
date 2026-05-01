withr::local_envvar(OPENAI_API_KEY = "sk-fake-for-tests")

test_that(".openai_chat_structured costruisce request con body json_schema strict=true", {
  # Captura la request senza colpire la rete
  req <- .openai_build_request(
    model = "gpt-5.4-mini",
    messages = list(list(role = "user", content = "Say pong as JSON.")),
    response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
    schema_name = "llm_call_envelope_v1"
  )

  # url
  expect_match(req$url, "^https://api\\.openai\\.com/v1/chat/completions$")
  # auth header presente (httr2 1.2.2 redige Authorization di default)
  hdrs <- httr2::req_get_headers(req, redacted = "reveal")
  auth <- hdrs[["Authorization"]]
  expect_match(auth, "^Bearer sk-fake-for-tests$")

  # body
  body <- jsonlite::fromJSON(rawToChar(req$body$data), simplifyVector = FALSE)
  expect_equal(body$model, "gpt-5.4-mini")
  expect_equal(body$response_format$type, "json_schema")
  expect_true(isTRUE(body$response_format$json_schema$strict))
  expect_equal(body$response_format$json_schema$name, "llm_call_envelope_v1")
  expect_equal(body$messages[[1]]$role, "user")
})

test_that(".openai_chat_structured parsifica una risposta finta in oggetto R", {
  # Risposta OpenAI tipica: choices[[1]]$message$content è la stringa JSON
  fake_response <- list(
    choices = list(list(
      message = list(
        role = "assistant",
        content = '{"question":"ping","answer":"pong","confidence":0.9}'
      ),
      finish_reason = "stop"
    )),
    model = "gpt-5.4-mini-2026"
  )
  parsed <- .openai_parse_response(fake_response)

  expect_equal(parsed$question, "ping")
  expect_equal(parsed$answer,   "pong")
  expect_equal(parsed$confidence, 0.9)
})

test_that(".openai_parse_response solleva errore tipizzato se finish_reason != 'stop'", {
  bad <- list(
    choices = list(list(
      message = list(content = "{}"),
      finish_reason = "length"
    ))
  )
  expect_error(
    .openai_parse_response(bad),
    class = "simulomicsr_openai_truncated"
  )
})

test_that(".openai_parse_response solleva errore tipizzato se manca content", {
  bad <- list(choices = list(list(message = list(role = "assistant"), finish_reason = "stop")))
  expect_error(
    .openai_parse_response(bad),
    class = "simulomicsr_openai_no_content"
  )
})

test_that("missing OPENAI_API_KEY -> errore tipizzato", {
  withr::local_envvar(OPENAI_API_KEY = "")
  expect_error(
    .openai_build_request(
      model = "gpt-5.4-mini",
      messages = list(list(role = "user", content = "x")),
      response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
      schema_name = "x"
    ),
    class = "simulomicsr_openai_missing_key"
  )
})

test_that("llm_call_structured(provider='openai') intercetta tramite .mock_adapter", {
  schema <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  withr::local_envvar(OPENAI_API_KEY = "sk-fake")

  res <- llm_call_structured(
    provider = "openai",
    model = "gpt-5.4-mini",
    messages = list(list(role = "user", content = "Say pong.")),
    response_schema = schema,
    .mock_adapter = function(model, messages, response_schema, ...) {
      list(question = "Say pong.", answer = "pong", confidence = 0.95)
    }
  )

  expect_true(res$validated)
  expect_equal(res$value$answer, "pong")
})
