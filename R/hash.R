#' Calcola lo SHA-256 di una stringa testuale UTF-8
#'
#' @param x stringa di lunghezza 1
#' @return stringa esadecimale di 64 caratteri
#' @keywords internal
sha256_text <- function(x) {
  stopifnot(is.character(x), length(x) == 1L, !is.na(x))
  digest::digest(x, algo = "sha256", serialize = FALSE)
}

#' Costruisce una cache key canonica `<schema_version>:<sha256(payload)>`
#'
#' La presenza dello schema_version come prefisso garantisce che un bump
#' di schema invalidi automaticamente la cache esistente (vedi spec v5 §5.4).
#'
#' @param schema_version es. `"stage1.v3"`
#' @param payload stringa che identifica il contenuto da cacheare
#' @return stringa `"<schema_version>:<sha256>"`
#' @keywords internal
cache_key_for <- function(schema_version, payload) {
  stopifnot(is.character(schema_version), length(schema_version) == 1L)
  stopifnot(is.character(payload), length(payload) == 1L)
  paste0(schema_version, ":", sha256_text(payload))
}
