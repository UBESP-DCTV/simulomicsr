#' Costruisce la stringa input stage1 in formato B (ADR-spec P4 beta).
#'
#' @param title Sample title da ARCHS4 H5 `/meta/samples/title`.
#' @param source_name_ch1 Sample source name da ARCHS4 H5 `/meta/samples/source_name_ch1`.
#' @param characteristics_ch1 Characteristics_ch1 da ARCHS4 H5 `/meta/samples/characteristics_ch1`.
#' @return Stringa concatenata pronta per stage1 prompt.
#' @keywords internal
build_sample_string_format_B <- function(title, source_name_ch1, characteristics_ch1) {
  parts <- c()
  if (!is.na(title) && nzchar(title)) parts <- c(parts, paste0("title: ", title))
  if (!is.na(source_name_ch1) && nzchar(source_name_ch1)) parts <- c(parts, paste0("source: ", source_name_ch1))
  if (!is.na(characteristics_ch1) && nzchar(characteristics_ch1)) parts <- c(parts, characteristics_ch1)
  paste(parts, collapse = ",")
}

#' Filtra un sample per inclusione nella pipeline P4 beta (human, bulk RNA-seq, metadata non-trivial).
#'
#' @param organism Organism da ARCHS4 (`organism_ch1`).
#' @param library_strategy Library strategy (`library_strategy`).
#' @param string Stringa format B ricostruita.
#' @return Logical TRUE se passa i filtri.
#' @keywords internal
is_sample_classifiable <- function(organism, library_strategy, string) {
  if (is.na(organism) || organism != "Homo sapiens") return(FALSE)
  if (is.na(library_strategy) || library_strategy != "RNA-Seq") return(FALSE)
  if (is.na(string) || nchar(string) < 20) return(FALSE)
  TRUE
}
