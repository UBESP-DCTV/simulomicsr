#' Chiama un LLM con output strutturato validato e cache opzionale
#'
#' Punto d'ingresso pubblico del client LLM. Dispatcha sul provider corretto,
#' valida la risposta contro `response_schema`, e (se `cache` e' fornita)
#' serve dalla cache su hit.
#'
#' @param provider stringa: `"openai"`, `"anthropic"`, o `"mock"` (per i test).
#' @param model nome del modello (es. `"gpt-5.4-mini"`)
#' @param messages lista di messaggi nello schema OpenAI (`role` + `content`)
#' @param response_schema path a un file JSON Schema; la risposta dell'LLM
#'   viene validata contro questo schema
#' @param cache oggetto ritornato da `cache_init()`, o `NULL` per bypass
#' @param cache_namespace_version stringa che entra nella cache key (es.
#'   `"stage1.v3"`); cambiare questo invalida la cache
#' @param ... parametri provider-specifici inoltrati all'adapter
#' @param .mock_response (test only) risposta da iniettare se `provider="mock"`
#' @param .mock_adapter (test only) function da chiamare al posto dell'adapter
#'   reale; ha precedenza su `.mock_response`
#'
#' @return lista con: `value` (oggetto R parsed dal JSON), `provider`, `model`,
#'   `validated` (logico), `cache_hit` (logico), `raw_response` (lista grezza).
#' @export
llm_call_structured <- function(provider,
                                model,
                                messages,
                                response_schema,
                                cache = NULL,
                                cache_namespace_version = "v0",
                                ...,
                                .mock_response = NULL,
                                .mock_adapter  = NULL) {
  stopifnot(is.character(provider), length(provider) == 1L)
  stopifnot(is.character(model),    length(model)    == 1L)
  stopifnot(is.list(messages), length(messages) >= 1L)

  # 1) Compila lo schema una volta sola
  validator <- compile_schema(response_schema)

  # 2) Costruisci la cache key se la cache e' attiva
  cache_key <- NULL
  if (!is.null(cache)) {
    payload <- jsonlite::toJSON(
      list(provider = provider, model = model, messages = messages),
      auto_unbox = TRUE
    )
    cache_key <- cache_key_for(cache_namespace_version, as.character(payload))

    if (cache_has(cache, cache_key)) {
      hit <- cache_get(cache, cache_key)
      return(list(
        value        = hit$value,
        provider     = provider,
        model        = model,
        validated    = TRUE,
        cache_hit    = TRUE,
        raw_response = hit$metadata$raw_response %||% NULL
      ))
    }
  }

  # 3) Dispatch
  raw <- if (!is.null(.mock_adapter)) {
    .mock_adapter(model = model, messages = messages, response_schema = response_schema, ...)
  } else if (provider == "mock") {
    if (is.null(.mock_response)) {
      rlang::abort(
        "provider='mock' richiede `.mock_response` o `.mock_adapter`",
        class = "simulomicsr_mock_error"
      )
    }
    .mock_response
  } else if (provider == "openai") {
    .openai_chat_structured(model = model, messages = messages,
                            response_schema = response_schema, ...)
  } else if (provider == "anthropic") {
    .anthropic_chat_structured(model = model, messages = messages,
                               response_schema = response_schema, ...)
  } else if (provider == "openrouter") {
    .openrouter_chat_structured(model = model, messages = messages,
                                response_schema = response_schema, ...)
  } else {
    rlang::abort(
      glue::glue("Provider sconosciuto: '{provider}'. Supportati: 'openai', 'anthropic', 'openrouter', 'mock'."),
      class = "simulomicsr_unknown_provider"
    )
  }

  # 4) Valida
  vres <- validate_json(raw, validator = validator)
  if (!vres$valid) {
    rlang::abort(
      glue::glue(
        "Risposta LLM NON conforme allo schema. Errori: {paste(vres$errors, collapse = ' | ')}"
      ),
      class = "simulomicsr_schema_error",
      errors = vres$errors,
      raw_response = raw
    )
  }

  # 5) Persisti in cache
  if (!is.null(cache)) {
    cache_put(cache, cache_key, value = raw,
              metadata = list(provider = provider, model = model))
  }

  list(
    value        = raw,
    provider     = provider,
    model        = model,
    validated    = TRUE,
    cache_hit    = FALSE,
    raw_response = raw
  )
}

# Nota: l'adapter reale `.openai_chat_structured` vive in
# `R/llm-client-openai.R` (Task 5). La forward declaration stub e' stata
# rimossa perche' R sourcea i file in ordine alfabetico
# (`llm-client-openai.R` < `llm-client.R`), quindi la stub avrebbe
# sovrascritto l'adapter reale.
