# Endpoint costante
.OPENROUTER_CHAT_URL <- "https://openrouter.ai/api/v1/chat/completions"

#' Costruisce (senza inviare) la `httr2` request per OpenRouter chat.
#' OpenRouter e' OpenAI-compatible: stessa shape di body, ma response_format
#' usa "json_object" (universale, supportato da tutti i modelli backend) invece
#' di "json_schema" strict (supportato solo da OpenAI). Lo schema viene incluso
#' nel system prompt come istruzione testuale e validato client-side.
#'
#' @keywords internal
.openrouter_build_request <- function(model,
                                      messages,
                                      response_schema,
                                      schema_name,
                                      temperature = NULL,
                                      max_tokens = NULL,
                                      api_key = NULL) {
  api_key <- api_key %||% Sys.getenv("OPENROUTER_API_KEY", unset = "")
  if (!nzchar(api_key)) {
    rlang::abort(
      "OPENROUTER_API_KEY non impostata. Vedi `.Renviron.local` (gitignored).",
      class = "simulomicsr_openrouter_missing_key"
    )
  }

  schema_text <- readr::read_file(response_schema)

  # Aggiungiamo lo schema come ultimo messaggio system (instruction-augment)
  schema_msg <- list(
    role = "system",
    content = paste0(
      "OUTPUT REQUIREMENT: respond with a single valid JSON object that ",
      "conforms strictly to the JSON Schema below. No markdown fences, ",
      "no commentary, no extra text. The object MUST use only the fields ",
      "and enums declared in the schema.\n\nJSON Schema (",
      schema_name, "):\n", schema_text
    )
  )
  augmented_messages <- c(messages, list(schema_msg))

  body <- list(
    model = model,
    messages = augmented_messages,
    response_format = list(type = "json_object")
  )
  if (!is.null(temperature)) body$temperature <- temperature
  if (!is.null(max_tokens)) body$max_tokens <- max_tokens

  httr2::request(.OPENROUTER_CHAT_URL) |>
    httr2::req_method("POST") |>
    httr2::req_headers(
      Authorization  = paste("Bearer", api_key),
      `Content-Type` = "application/json",
      `HTTP-Referer` = "https://github.com/UBESP-DCTV/simulomicsr",
      `X-Title`      = "simulomicsr"
    ) |>
    httr2::req_body_raw(
      charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")),
      type = "application/json"
    ) |>
    httr2::req_user_agent("simulomicsr (https://github.com/UBESP-DCTV/simulomicsr)") |>
    httr2::req_timeout(seconds = 180) |>
    httr2::req_retry(
      max_tries = 3L,
      backoff = function(i) min(60, 2 ^ i),
      is_transient = function(resp) {
        s <- httr2::resp_status(resp)
        s == 429L || s >= 500L
      }
    )
}

#' Estrae l'oggetto R dalla risposta OpenRouter.
#'
#' OpenRouter mirroriza la shape di OpenAI: choices[[1]]$message$content
#' contiene la stringa JSON. Errori tipizzati:
#' - `simulomicsr_openrouter_truncated` se finish_reason != "stop"
#' - `simulomicsr_openrouter_no_content` se manca message.content
#' - `simulomicsr_openrouter_bad_json` se content non e' JSON parsabile
#'
#' @keywords internal
.openrouter_parse_response <- function(resp_body) {
  stopifnot(is.list(resp_body), length(resp_body$choices) >= 1L)
  ch <- resp_body$choices[[1]]

  fr <- ch$finish_reason %||% "unknown"
  if (!fr %in% c("stop", "end_turn")) {
    rlang::abort(
      glue::glue("OpenRouter ha terminato con finish_reason='{fr}', non 'stop'."),
      class = "simulomicsr_openrouter_truncated",
      finish_reason = fr
    )
  }

  content <- ch$message$content
  if (is.null(content) || !nzchar(content)) {
    rlang::abort(
      "Risposta OpenRouter senza message.content.",
      class = "simulomicsr_openrouter_no_content"
    )
  }

  # Alcuni modelli wrappano il JSON in fence ```json...```. Strippiamoli.
  content_clean <- gsub("^\\s*```(?:json)?\\s*|\\s*```\\s*$", "", content)

  parsed <- tryCatch(
    jsonlite::fromJSON(content_clean, simplifyVector = FALSE),
    error = function(e) {
      rlang::abort(
        glue::glue("OpenRouter ha ritornato content non-JSON: {conditionMessage(e)}"),
        class = "simulomicsr_openrouter_bad_json",
        raw_content = content
      )
    }
  )
  parsed
}

#' Esegue la chiamata HTTP completa OpenRouter e ritorna l'oggetto R parsed.
#'
#' Chiamato da `llm_call_structured()` quando `provider == "openrouter"`.
#'
#' @keywords internal
.openrouter_chat_structured <- function(model,
                                        messages,
                                        response_schema,
                                        schema_name = "response",
                                        temperature = NULL,
                                        max_tokens = NULL,
                                        api_key = NULL,
                                        ...) {
  req <- .openrouter_build_request(
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
  .openrouter_parse_response(body)
}
