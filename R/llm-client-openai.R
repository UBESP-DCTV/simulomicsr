# Endpoint costante
.OPENAI_CHAT_URL <- "https://api.openai.com/v1/chat/completions"

#' Costruisce (senza inviare) la `httr2` request per chat/completions con
#' Structured Outputs (strict json_schema).
#'
#' @keywords internal
.openai_build_request <- function(model,
                                  messages,
                                  response_schema,
                                  schema_name,
                                  temperature = NULL,
                                  max_tokens = NULL,
                                  api_key = NULL) {
  api_key <- api_key %||% Sys.getenv("OPENAI_API_KEY", unset = "")
  if (!nzchar(api_key)) {
    rlang::abort(
      "OPENAI_API_KEY non impostata. Vedi `.Renviron.local` (gitignored) o `Sys.setenv()`.",
      class = "simulomicsr_openai_missing_key"
    )
  }

  schema_json <- jsonlite::fromJSON(
    readr::read_file(response_schema),
    simplifyVector = FALSE
  )

  # `temperature` e' opzionale: i modelli "reasoning" (gpt-5.5+) accettano
  # solo il default API (1) e ritornano 400 se inviato qualunque valore
  # esplicito. Per i modelli storici (gpt-4o, gpt-5.4-mini) il chiamante
  # puo' passare `temperature = 0` per output deterministici.
  body <- list(
    model = model,
    messages = messages,
    response_format = list(
      type = "json_schema",
      json_schema = list(
        name   = schema_name,
        strict = TRUE,
        schema = schema_json
      )
    )
  )
  if (!is.null(temperature)) body$temperature <- temperature
  if (!is.null(max_tokens)) body$max_tokens <- max_tokens

  httr2::request(.OPENAI_CHAT_URL) |>
    httr2::req_method("POST") |>
    httr2::req_headers(
      Authorization  = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ) |>
    httr2::req_body_raw(
      charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")),
      type = "application/json"
    ) |>
    httr2::req_user_agent("simulomicsr (https://github.com/UBESP-DCTV/simulomicsr)") |>
    httr2::req_timeout(seconds = 120) |>
    httr2::req_retry(
      max_tries = 3L,
      backoff = function(i) min(60, 2 ^ i),
      is_transient = function(resp) {
        s <- httr2::resp_status(resp)
        s == 429L || s >= 500L
      }
    )
}

#' Estrae l'oggetto R dalla risposta OpenAI.
#'
#' Errori tipizzati:
#' - `simulomicsr_openai_truncated` se finish_reason != "stop"
#' - `simulomicsr_openai_no_content` se manca message.content
#' - `simulomicsr_openai_bad_json` se content non e' JSON parsabile
#'
#' @keywords internal
.openai_parse_response <- function(resp_body) {
  stopifnot(is.list(resp_body), length(resp_body$choices) >= 1L)
  ch <- resp_body$choices[[1]]

  fr <- ch$finish_reason %||% "unknown"
  if (!identical(fr, "stop")) {
    rlang::abort(
      glue::glue("OpenAI ha terminato con finish_reason='{fr}', non 'stop'."),
      class = "simulomicsr_openai_truncated",
      finish_reason = fr
    )
  }

  content <- ch$message$content
  if (is.null(content) || !nzchar(content)) {
    rlang::abort(
      "Risposta OpenAI senza message.content.",
      class = "simulomicsr_openai_no_content"
    )
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(content, simplifyVector = TRUE),
    error = function(e) {
      rlang::abort(
        glue::glue("OpenAI ha ritornato content non-JSON: {conditionMessage(e)}"),
        class = "simulomicsr_openai_bad_json",
        raw_content = content
      )
    }
  )
  parsed
}

#' Esegue la chiamata HTTP completa e ritorna l'oggetto R parsed.
#'
#' Chiamato da `llm_call_structured()` quando `provider == "openai"`.
#'
#' @keywords internal
.openai_chat_structured <- function(model,
                                    messages,
                                    response_schema,
                                    schema_name = "response",
                                    temperature = NULL,
                                    max_tokens = NULL,
                                    api_key = NULL,
                                    ...) {
  req <- .openai_build_request(
    model = model,
    messages = messages,
    response_schema = response_schema,
    schema_name = schema_name,
    temperature = temperature,
    max_tokens = max_tokens,
    api_key = api_key
  )
  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  .openai_parse_response(body)
}
