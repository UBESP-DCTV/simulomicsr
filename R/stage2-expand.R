# Espansione collect -> master Stadio 2 v3 (ADR-0020, opzione C).
#
# Il modello classifica le CONDIZIONI deduplicate (rappresentanti). L'espansione
# sostituisce, nei replicate_group emessi, ogni rappresentante con i suoi
# member_sample_ids reali, ricostruendo uno study_design a campioni reali (schema
# stage2.v2 invariato) consumabile dallo Stadio 3.

#' Costruisce la mappa rappresentante -> member_sample_ids dai record input v3
#'
#' @param input_records Lista dei record input v3 di UNO studio (1 se non
#'   chunkato, N se chunkato; i controlli broadcast condividono lo stesso
#'   rappresentante e gli stessi membri -> idempotente).
#' @return Named list: \code{geo_accession} (rappresentante) ->
#'   \code{character} dei member_sample_ids.
#' @keywords internal
.build_member_lookup <- function(input_records) {
  lk <- list()
  for (rec in input_records) {
    for (s in rec$samples) {
      geo <- as.character(s$geo_accession)[[1]]
      lk[[geo]] <- as.character(unlist(s$member_sample_ids))
    }
  }
  lk
}

#' Espande i rappresentanti di uno study_design nei membri reali
#'
#' Per ogni \code{replicate_group}, sostituisce i rappresentanti in
#' \code{sample_ids} con la union dei loro \code{member_sample_ids} (via
#' \code{member_lookup}). Un rappresentante assente dalla mappa resta invariato
#' (robustezza). Tutti gli altri campi (\code{group_id}, \code{comparisons},
#' design_kind, ...) restano invariati.
#'
#' @param study_design Lista study_design.stage2.v2 emessa dal modello.
#' @param member_lookup Mappa da \code{\link{.build_member_lookup}}.
#' @return Lo study_design con \code{sample_ids} espansi a campioni reali.
#' @keywords internal
.expand_study_design <- function(study_design, member_lookup) {
  study_design$replicate_groups <- lapply(study_design$replicate_groups, function(rg) {
    reps <- as.character(unlist(rg$sample_ids))
    expanded <- unlist(lapply(reps, function(g) {
      m <- member_lookup[[g]]
      if (is.null(m)) g else as.character(m)
    }), use.names = FALSE)
    rg$sample_ids <- unique(expanded)
    rg
  })
  study_design
}
