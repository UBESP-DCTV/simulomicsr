# Endpoint costante
.ANTHROPIC_MESSAGES_URL <- "https://api.anthropic.com/v1/messages"
.ANTHROPIC_API_VERSION  <- "2023-06-01"

#' Costruisce (senza inviare) la `httr2` request per Anthropic Messages
#' con structured output via tool_use forzato.
#'
#' @keywords internal
.anthropic_build_request <- function(model,
                                     messages,
                                     response_schema,
                                     schema_name,
                                     max_tokens = 4096L,
                                     api_key = NULL) {
  api_key <- api_key %||% Sys.getenv("ANTHROPIC_API_KEY", unset = "")
  if (!nzchar(api_key)) {
    rlang::abort(
      "ANTHROPIC_API_KEY non impostata. Vedi `.Renviron.local` (gitignored) o `Sys.setenv()`.",
      class = "simulomicsr_anthropic_missing_key"
    )
  }

  schema_json <- jsonlite::fromJSON(
    readr::read_file(response_schema),
    simplifyVector = FALSE
  )

  # Anthropic supporta solo messages role=user/assistant. Eventuali system
  # messages OpenAI-style vengono separati nel campo top-level `system`.
  sys_blocks <- vapply(messages, function(m) identical(m$role, "system"), logical(1))
  system_text <- if (any(sys_blocks)) {
    paste(vapply(messages[sys_blocks], function(m) m$content, character(1)),
          collapse = "\n\n")
  } else NULL
  user_messages <- messages[!sys_blocks]

  body <- list(
    model = model,
    max_tokens = as.integer(max_tokens),
    messages = user_messages,
    tools = list(list(
      name = schema_name,
      description = paste0("Return structured response conforming to schema ", schema_name),
      input_schema = schema_json
    )),
    tool_choice = list(type = "tool", name = schema_name)
  )
  if (!is.null(system_text)) body$system <- system_text

  httr2::request(.ANTHROPIC_MESSAGES_URL) |>
    httr2::req_method("POST") |>
    httr2::req_headers(
      `x-api-key`         = api_key,
      `anthropic-version` = .ANTHROPIC_API_VERSION,
      `Content-Type`      = "application/json"
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

#' Estrae l'oggetto R dalla risposta Anthropic (tool_use block).
#'
#' Errori tipizzati:
#' - `simulomicsr_anthropic_truncated` se stop_reason non e' tool_use/end_turn
#' - `simulomicsr_anthropic_no_tool_use` se manca il tool_use block
#'
#' @keywords internal
.anthropic_parse_response <- function(resp_body) {
  stopifnot(is.list(resp_body))

  sr <- resp_body$stop_reason %||% "unknown"
  if (!sr %in% c("tool_use", "end_turn")) {
    rlang::abort(
      glue::glue("Anthropic stop_reason='{sr}', non 'tool_use' o 'end_turn'."),
      class = "simulomicsr_anthropic_truncated",
      stop_reason = sr
    )
  }

  blocks <- resp_body$content %||% list()
  tool_use_idx <- which(vapply(blocks, function(b) identical(b$type, "tool_use"), logical(1)))
  if (length(tool_use_idx) == 0L) {
    rlang::abort(
      "Anthropic non ha incluso un tool_use block (modello non ha chiamato il tool).",
      class = "simulomicsr_anthropic_no_tool_use"
    )
  }
  blocks[[tool_use_idx[1]]]$input
}

#' Esegue la chiamata HTTP completa Anthropic e ritorna l'oggetto R parsed.
#'
#' Chiamato da `llm_call_structured()` quando `provider == "anthropic"`.
#'
#' @keywords internal
.anthropic_chat_structured <- function(model,
                                       messages,
                                       response_schema,
                                       schema_name = "response",
                                       max_tokens = 4096L,
                                       api_key = NULL,
                                       ...) {
  req <- .anthropic_build_request(
    model = model,
    messages = messages,
    response_schema = response_schema,
    schema_name = schema_name,
    max_tokens = max_tokens,
    api_key = api_key
  )
  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  .anthropic_parse_response(body)
}
