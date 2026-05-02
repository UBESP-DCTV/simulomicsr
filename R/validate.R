#' Compila uno schema JSON Schema (draft-07) in un validatore richiamabile
#'
#' Wrapper su `jsonvalidate::json_validator()` con backend Ajv. Il validatore
#' ritornato è una funzione che accetta una stringa JSON e ritorna TRUE/FALSE
#' (con attribute `errors` se invalido).
#'
#' @param schema_path path a un file `.json` con lo schema
#' @return funzione validatrice
#' @export
compile_schema <- function(schema_path) {
  stopifnot(fs::file_exists(schema_path))
  jsonvalidate::json_validator(
    schema = readr::read_file(schema_path),
    engine = "ajv"
  )
}

#' Valida un oggetto R o una stringa JSON contro un validatore compilato
#'
#' @param x lista R (verrà serializzata) oppure stringa JSON
#' @param validator funzione ritornata da `compile_schema()`
#' @return lista con `valid` (logico) e `errors` (character vector, vuoto se valid)
#' @export
validate_json <- function(x, validator) {
  stopifnot(is.function(validator))
  json <- if (is.character(x) && length(x) == 1L) {
    x
  } else {
    jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null")
  }

  res <- validator(json, verbose = TRUE, greedy = TRUE)
  if (isTRUE(res)) {
    list(valid = TRUE, errors = character())
  } else {
    err_df <- attr(res, "errors")
    msgs <- if (is.data.frame(err_df) && nrow(err_df) > 0L) {
      vapply(seq_len(nrow(err_df)), function(i) {
        paste0(err_df$instancePath[i] %||% err_df$dataPath[i] %||% "",
               " ", err_df$message[i] %||% "(no message)")
      }, character(1))
    } else {
      "validation failed without structured errors"
    }
    list(valid = FALSE, errors = msgs)
  }
}

# Operatore null-coalescing privato (evita dipendenza da rlang::%||% pubblico)
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
