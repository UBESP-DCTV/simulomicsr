test_that(".vllm_chat_structured posta il body giusto e parsa il content", {
  captured <- NULL
  fake_perform <- function(req) {
    captured <<- req
    structure(list(), class = "httr2_response")
  }
  fake_body <- function(resp, simplifyVector = FALSE) {
    list(choices = list(list(message = list(
      content = '{"canonical_name":"lipopolysaccharide","kind":"pathogen_or_aggregate_exposure","confidence":"high","evidence":"lps in characteristics"}'))))
  }
  msgs <- list(list(role = "system", content = "sys"),
               list(role = "user", content = "usr"))
  out <- testthat::with_mocked_bindings(
    .vllm_chat_structured(model = "m", messages = msgs,
                          response_schema = NULL, base_url = "http://x/v1/chat/completions",
                          api_key = "k"),
    req_perform = fake_perform,
    resp_body_json = fake_body,
    .package = "httr2"
  )
  expect_equal(out$content_json$canonical_name, "lipopolysaccharide")
  # il body deve includere temperature=0 e repetition_penalty=1.1
  body_txt <- rawToChar(captured$body$data)
  expect_match(body_txt, '"temperature":0')
  expect_match(body_txt, '"repetition_penalty":1.1')
})

test_that(".vllm_chat_structured alza errore tipizzato su finish_reason troncato", {
  fake_perform <- function(req) structure(list(), class = "httr2_response")
  fake_body <- function(resp, simplifyVector = FALSE) {
    list(choices = list(list(finish_reason = "length",
                             message = list(content = '{"canonical_name":"asp'))))
  }
  msgs <- list(list(role = "user", content = "usr"))
  expect_error(
    testthat::with_mocked_bindings(
      .vllm_chat_structured(model = "m", messages = msgs, response_schema = NULL,
                            base_url = "http://x/v1/chat/completions", api_key = "k"),
      req_perform = fake_perform, resp_body_json = fake_body, .package = "httr2"
    ),
    class = "simulomicsr_vllm_truncated"
  )
})

test_that(".vllm_chat_structured alza errore tipizzato su content vuoto/mancante", {
  fake_perform <- function(req) structure(list(), class = "httr2_response")
  fake_body <- function(resp, simplifyVector = FALSE) {
    list(choices = list(list(finish_reason = "stop", message = list(content = ""))))
  }
  msgs <- list(list(role = "user", content = "usr"))
  expect_error(
    testthat::with_mocked_bindings(
      .vllm_chat_structured(model = "m", messages = msgs, response_schema = NULL,
                            base_url = "http://x/v1/chat/completions", api_key = "k"),
      req_perform = fake_perform, resp_body_json = fake_body, .package = "httr2"
    ),
    class = "simulomicsr_vllm_no_content"
  )
})

test_that(".vllm_chat_structured alza errore tipizzato su content non-JSON", {
  fake_perform <- function(req) structure(list(), class = "httr2_response")
  fake_body <- function(resp, simplifyVector = FALSE) {
    list(choices = list(list(finish_reason = "stop",
                             message = list(content = "questo non e' JSON"))))
  }
  msgs <- list(list(role = "user", content = "usr"))
  expect_error(
    testthat::with_mocked_bindings(
      .vllm_chat_structured(model = "m", messages = msgs, response_schema = NULL,
                            base_url = "http://x/v1/chat/completions", api_key = "k"),
      req_perform = fake_perform, resp_body_json = fake_body, .package = "httr2"
    ),
    class = "simulomicsr_vllm_bad_json"
  )
})

test_that("llm_call_structured instrada provider vllm", {
  msgs <- list(list(role = "user", content = "x"))
  res <- llm_call_structured(
    provider = "vllm", model = "m", messages = msgs, response_schema = NULL,
    .mock_response = list(canonical_name = "aspirin", kind = "small_molecule",
                          confidence = "high", evidence = "e"))
  expect_equal(res$provider, "vllm")
  expect_equal(res$value$canonical_name, "aspirin")
})
