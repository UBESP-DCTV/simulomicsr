# Recupero deterministico di identita' (malattia/composto/gene) dai metadati GEO
# grezzi + correzione tipi palesemente sbagliati (K2). Spec:
# docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md

#' Parsa "key: value, key: value" in vettore nominato (chiavi/valori lowercased)
#' @keywords internal
.parse_characteristics_kv <- function(text) {
  if (length(text) != 1L || is.na(text) || !nzchar(text)) return(character(0))
  pairs <- strsplit(text, ",", fixed = TRUE)[[1L]]
  out <- character(0)
  for (p in pairs) {
    kv <- strsplit(p, ":", fixed = TRUE)[[1L]]
    if (length(kv) >= 2L) {
      k <- tolower(trimws(kv[1L]))
      v <- tolower(trimws(paste(kv[-1L], collapse = ":")))
      if (nzchar(k) && nzchar(v)) out[[k]] <- v
    }
  }
  out
}
