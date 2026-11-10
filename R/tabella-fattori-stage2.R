# La pipeline di oggi (Stadio 2) nella forma comune delle misure (ADR-0029).
#
# Le misure contro Expression Atlas (R/tabella-fattori-misure.R) leggono una
# partizione dei campioni e una tabella di confronti. Questo adattatore porta
# in quella forma un record dello Stadio 2 (`study_design.stage2.v3`), senza
# interpretarlo: i gruppi e i confronti restano quelli scritti dal modello.

# `sample_ids` nei JSON e' uno scalare quando il gruppo ha un campione solo,
# una lista altrimenti (CLAUDE.md §4, scalari-come-array).
.tf_stage2_campioni <- function(x) {
  x <- unlist(x, use.names = FALSE)
  if (is.null(x)) character(0) else as.character(x)
}

#' Un record dello Stadio 2 nella forma comune delle misure
#'
#' @param record Lista: un record del master dello Stadio 2 letto con
#'   `jsonlite::fromJSON(riga, simplifyVector = FALSE)`. Usa `series_id`,
#'   `replicate_groups` (`group_id`, `sample_ids`) e `comparisons`
#'   (`comparison_id`, `treated_group`, `control_group`).
#' @return Lista con `partizione` (vettore chr con nome: GSM -> gruppo) e
#'   `confronti` (`data.frame` con `studio`, `id`, `trattato`, `controllo`;
#'   le ultime due sono colonne-lista di GSM ordinati).
#' @keywords internal
tf_da_stage2 <- function(record) {
  if (!is.list(record) || !is.character(record$series_id) || length(record$series_id) != 1L) {
    .tf_abort("`record` deve essere una lista con `series_id` (una stringa).",
              "stage2_record_non_valido")
  }
  studio <- record$series_id
  gruppi <- record$replicate_groups
  if (is.null(gruppi)) gruppi <- list()
  id_gruppi <- vapply(gruppi, function(g) as.character(g$group_id), character(1))
  if (anyDuplicated(id_gruppi)) {
    .tf_abort(sprintf("%s: `group_id` ripetuti: %s.", studio,
                      .tf_elenca(unique(id_gruppi[duplicated(id_gruppi)]))),
              "stage2_record_non_valido")
  }
  campioni <- lapply(gruppi, function(g) sort(unique(.tf_stage2_campioni(g$sample_ids))))
  names(campioni) <- id_gruppi
  tutti <- unlist(campioni, use.names = FALSE)
  di_gruppo <- rep(id_gruppi, lengths(campioni))
  if (anyDuplicated(tutti)) {
    doppi <- unique(tutti[duplicated(tutti)])
    .tf_abort(sprintf("%s: %d campioni stanno in due gruppi dello Stadio 2: %s.", studio,
                      length(doppi), .tf_elenca(doppi)),
              "stage2_campione_in_due_gruppi")
  }
  partizione <- if (length(tutti)) stats::setNames(di_gruppo, tutti) else
    stats::setNames(character(0), character(0))

  conf <- record$comparisons
  if (is.null(conf)) conf <- list()
  id <- vapply(conf, function(k) as.character(k$comparison_id), character(1))
  trattato <- vapply(conf, function(k) as.character(k$treated_group), character(1))
  controllo <- vapply(conf, function(k) as.character(k$control_group), character(1))
  ignoti <- setdiff(c(trattato, controllo), id_gruppi)
  if (length(ignoti)) {
    .tf_abort(sprintf("%s: i confronti dello Stadio 2 citano gruppi che non esistono: %s.",
                      studio, .tf_elenca(ignoti)),
              "stage2_gruppo_ignoto")
  }
  confronti <- data.frame(studio = rep(studio, length(conf)), id = id, stringsAsFactors = FALSE)
  confronti$trattato <- unname(campioni[trattato])
  confronti$controllo <- unname(campioni[controllo])
  list(partizione = partizione, confronti = confronti)
}
