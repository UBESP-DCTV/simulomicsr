# Pulizia-nomi (scope A): relabel della coda mal-etichettata via Mistral +
# risoluzione ontologica deterministica. Vedi
# docs/superpowers/specs/2026-07-06-name-cleanup-mistral-design.md.

.NAME_CLEANUP_CACHE_VERSION <- "nameclean.v1"

# Entità HTML comuni nei nomi ChEBI -> unicode.
.NAME_MARKUP_ENTITIES <- c(
  "&alpha;" = "α", "&beta;" = "β", "&gamma;" = "γ", "&delta;" = "δ",
  "&#945;" = "α", "&#946;" = "β", "&#947;" = "γ", "&middot;" = "·", "&amp;" = "&")

#' @keywords internal
#' @noRd
.strip_name_markup <- function(x) {
  s <- .normalize_key_chr(x)
  if (is.na(s)) return(NA_character_)
  s <- gsub("<[^>]+>", "", s)                    # tag HTML
  for (e in names(.NAME_MARKUP_ENTITIES)) s <- gsub(e, .NAME_MARKUP_ENTITIES[[e]], s, fixed = TRUE)
  s <- gsub("&#[0-9]+;", "", s)                  # entità numeriche residue
  s <- trimws(s)
  if (!nzchar(s)) NA_character_ else s
}
