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

#' Carica i candidati alla pulizia-nomi dal triage CSV.
#'
#' Legge il triage (`cluster_id,name,kind,k,n_studies,homog,top_theme,name_ok,cls`)
#' e restituisce solo i cluster rilevanti per il relabel: `candidate` = coda
#' mal-etichettata (`OMOGENEO+MAL_nominato` o `ETEROGENEO(sospetto)`), `canary`
#' = gia' ben nominato (controllo di non-regressione). `vehicle/none` escluso
#' (non e' materia di pulizia-nomi).
#'
#' @keywords internal
#' @noRd
.load_name_cleanup_candidates <- function(triage_csv_path) {
  d <- utils::read.csv(triage_csv_path, stringsAsFactors = FALSE, check.names = FALSE)
  d <- d[d$cls != "vehicle/none", , drop = FALSE]
  d$role <- ifelse(d$cls == "OMOGENEO+ben_nominato", "canary", "candidate")
  tibble::tibble(cluster_id = as.character(d$cluster_id), name = as.character(d$name),
                 kind = as.character(d$kind), k = as.integer(d$k),
                 top_theme = as.character(d$top_theme), role = d$role)
}
