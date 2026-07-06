#' Client structured-output verso l'endpoint Mistral self-hosted (vLLM OpenAI-compatible)
#'
#' Riusa il pattern httr2 di `analysis/audit/name-recovery-llm-benchmark.R` ma come
#' adapter di pacchetto, cosi' passa per la cache di `llm_call_structured()`. Lo schema
#' non viene iniettato come `json_schema` strict (non universalmente supportato da vLLM):
#' usiamo `response_format=json_object` + validazione client-side a valle nel dispatcher
#' (coerente con l'adapter OpenRouter, che e' anch'esso OpenAI-compatible generico).
#'
#' Config Mistral uniforme (vedi memoria `feedback_pipeline_config_uniformity`):
#' `temperature=0` + `repetition_penalty=1.1`, stessa famiglia modello della pipeline.
#'
#' @param model nome del modello servito da vLLM (es. "mistralai/Mistral-Small-3.2-24B-Instruct-2506").
#' @param messages lista di messaggi schema OpenAI (`role` + `content`).
#' @param response_schema path allo schema JSON (non usato per costruire il body qui;
#'   la validazione avviene a valle in `llm_call_structured()`). Accettato per coerenza
#'   di firma con gli altri adapter del pacchetto.
#' @param schema_name nome descrittivo dello schema (non incluso nel body; riservato
#'   per eventuale uso futuro / logging).
#' @param temperature default 0 (config Mistral uniforme).
#' @param max_tokens cap sui token generati. Default 1024 (un `canonical_name`
#'   + breve `evidence` ci sta comodo; alzato da 256 per ridurre la frequenza
#'   di troncamento su risposte reali dell'endpoint vLLM).
#' @param repetition_penalty default 1.1 (config Mistral uniforme).
#' @param base_url endpoint chat completions vLLM. Default da `VLLM_BASE_URL` o
#'   `http://localhost:8000/v1/chat/completions`.
#' @param api_key bearer token. Default da `VLLM_API_KEY` o `"EMPTY"` (vLLM self-hosted
#'   spesso non richiede auth reale).
#' @param timeout timeout httr2 in secondi.
#' @param ... ignorato (assorbe parametri provider-specifici passati dal dispatcher).
#'
#' @return lista con `content_json` (oggetto R parsed dal JSON di risposta) e `raw`
#'   (stringa JSON grezza, per audit/debug).
#' @keywords internal
#' @noRd
.vllm_chat_structured <- function(model, messages, response_schema,
                                  schema_name = "response",
                                  temperature = 0, max_tokens = 1024L,
                                  repetition_penalty = 1.1,
                                  base_url = NULL, api_key = NULL,
                                  timeout = 60L, ...) {
  base_url <- base_url %||% Sys.getenv("VLLM_BASE_URL",
                                       "http://localhost:8000/v1/chat/completions")
  api_key  <- api_key  %||% Sys.getenv("VLLM_API_KEY", "EMPTY")

  body <- list(model = model, messages = messages,
               response_format = list(type = "json_object"),
               temperature = temperature, max_tokens = max_tokens,
               repetition_penalty = repetition_penalty)

  req <- httr2::request(base_url) |>
    httr2::req_method("POST") |>
    httr2::req_headers(Authorization = paste("Bearer", api_key),
                       `Content-Type` = "application/json") |>
    httr2::req_body_raw(
      charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")),
      type = "application/json") |>
    httr2::req_timeout(seconds = timeout) |>
    httr2::req_retry(max_tries = 2L, backoff = function(i) 5)

  resp <- httr2::req_perform(req)
  body_json <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  .vllm_parse_response(body_json)
}

#' Estrae l'oggetto R dalla risposta vLLM (mirror di `.openai_parse_response`).
#'
#' Errori tipizzati:
#' - `simulomicsr_vllm_truncated` se `finish_reason` presente e != "stop"
#'   (es. "length": il JSON e' tagliato a meta', non parsarlo).
#' - `simulomicsr_vllm_no_content` se manca/e' vuoto `message.content`.
#' - `simulomicsr_vllm_bad_json` se `content` non e' JSON parsabile.
#'
#' @keywords internal
#' @noRd
.vllm_parse_response <- function(resp_body) {
  stopifnot(is.list(resp_body), length(resp_body$choices) >= 1L)
  ch <- resp_body$choices[[1L]]

  fr <- ch$finish_reason %||% "unknown"
  if (!identical(fr, "unknown") && !identical(fr, "stop")) {
    rlang::abort(
      glue::glue("vLLM ha terminato con finish_reason='{fr}', non 'stop'."),
      class = "simulomicsr_vllm_truncated",
      finish_reason = fr
    )
  }

  content <- ch$message$content
  if (is.null(content) || !nzchar(content)) {
    rlang::abort(
      "Risposta vLLM senza message.content.",
      class = "simulomicsr_vllm_no_content"
    )
  }

  parsed <- tryCatch(
    jsonlite::fromJSON(content, simplifyVector = FALSE),
    error = function(e) {
      rlang::abort(
        glue::glue("vLLM ha ritornato content non-JSON: {conditionMessage(e)}"),
        class = "simulomicsr_vllm_bad_json",
        raw_content = content
      )
    }
  )

  list(content_json = parsed, raw = content)
}
