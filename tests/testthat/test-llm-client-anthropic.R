withr::local_envvar(ANTHROPIC_API_KEY = "sk-ant-fake-for-tests")

test_that(".anthropic_build_request costruisce request con tool_use forzato", {
  req <- .anthropic_build_request(
    model = "claude-haiku-4-5",
    messages = list(list(role = "user", content = "Say pong as JSON.")),
    response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
    schema_name = "llm_call_envelope_v1"
  )

  expect_match(req$url, "^https://api\\.anthropic\\.com/v1/messages$")

  hdrs <- httr2::req_get_headers(req, redacted = "reveal")
  expect_equal(hdrs[["x-api-key"]], "sk-ant-fake-for-tests")
  expect_equal(hdrs[["anthropic-version"]], "2023-06-01")

  body <- jsonlite::fromJSON(rawToChar(req$body$data), simplifyVector = FALSE)
  expect_equal(body$model, "claude-haiku-4-5")
  expect_equal(length(body$tools), 1L)
  expect_equal(body$tools[[1]]$name, "llm_call_envelope_v1")
  expect_true(!is.null(body$tools[[1]]$input_schema))
  expect_equal(body$tool_choice$type, "tool")
  expect_equal(body$tool_choice$name, "llm_call_envelope_v1")
  expect_equal(body$messages[[1]]$role, "user")
})

test_that(".anthropic_parse_response estrae il payload da content[[i]]$type=='tool_use'", {
  fake_response <- list(
    id = "msg_x",
    type = "message",
    role = "assistant",
    model = "claude-haiku-4-5",
    stop_reason = "tool_use",
    content = list(
      list(type = "text", text = "Reasoning step omitted."),
      list(
        type = "tool_use",
        id = "toolu_x",
        name = "llm_call_envelope_v1",
        input = list(question = "ping", answer = "pong", confidence = 0.9)
      )
    )
  )
  parsed <- .anthropic_parse_response(fake_response)

  expect_equal(parsed$question, "ping")
  expect_equal(parsed$answer, "pong")
  expect_equal(parsed$confidence, 0.9)
})

test_that(".anthropic_parse_response solleva errore tipizzato se stop_reason non e' 'tool_use' o 'end_turn'", {
  bad <- list(
    stop_reason = "max_tokens",
    content = list(list(type = "text", text = "incomplete"))
  )
  expect_error(
    .anthropic_parse_response(bad),
    class = "simulomicsr_anthropic_truncated"
  )
})

test_that(".anthropic_parse_response solleva errore tipizzato se manca tool_use block", {
  bad <- list(
    stop_reason = "end_turn",
    content = list(list(type = "text", text = "I will not call the tool."))
  )
  expect_error(
    .anthropic_parse_response(bad),
    class = "simulomicsr_anthropic_no_tool_use"
  )
})

test_that("missing ANTHROPIC_API_KEY -> errore tipizzato", {
  withr::local_envvar(ANTHROPIC_API_KEY = "")
  expect_error(
    .anthropic_build_request(
      model = "claude-haiku-4-5",
      messages = list(list(role = "user", content = "x")),
      response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
      schema_name = "x"
    ),
    class = "simulomicsr_anthropic_missing_key"
  )
})

test_that(".anthropic_build_request setta max_tokens (Anthropic richiede sempre max_tokens)", {
  req <- .anthropic_build_request(
    model = "claude-haiku-4-5",
    messages = list(list(role = "user", content = "x")),
    response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
    schema_name = "x"
  )
  body <- jsonlite::fromJSON(rawToChar(req$body$data), simplifyVector = FALSE)
  expect_true(body$max_tokens >= 1024L)
})

test_that(".anthropic_build_request separa system messages dal body messages array", {
  req <- .anthropic_build_request(
    model = "claude-haiku-4-5",
    messages = list(
      list(role = "system", content = "Sei un assistente."),
      list(role = "user",   content = "Dimmi pong.")
    ),
    response_schema = system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr"),
    schema_name = "x"
  )
  body <- jsonlite::fromJSON(rawToChar(req$body$data), simplifyVector = FALSE)
  expect_equal(body$system, "Sei un assistente.")
  expect_equal(length(body$messages), 1L)
  expect_equal(body$messages[[1]]$role, "user")
})
