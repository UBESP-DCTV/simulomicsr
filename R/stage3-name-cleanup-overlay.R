#' Converte la side-table del name-cleanup in overlay GSM -> identita' corretta.
#' Solo le righe action=="override" (precision-gate). L'overlay si sovrappone
#' al recovery_lookup deterministico (Task 5); e' agganciato ai GSM membri dei
#' cluster rivisti -> nessun rischio di over-correction globale sul nome.
#'
#' @param side_table data.frame/tibble con almeno le colonne
#'   \code{cluster_id}, \code{new_id}, \code{new_canonical}, \code{new_kind}
#'   e \code{action}. Solo le righe con \code{action == "override"} e
#'   \code{new_id} non-NA vengono usate (precision-gate: \code{flag_review},
#'   \code{keep} e \code{noop} sono escluse).
#' @param assignments data.frame/tibble con le colonne \code{cluster_id} e
#'   \code{record_id}, che mappano ogni cluster ai record Stadio 2 assegnati.
#' @param record_to_gsms function(record_id) -> character vector di GSM
#'   accession membri di quel record (risoluzione record -> campioni).
#' @return named list: chiave = GSM accession, valore = lista
#'   \code{(kind, agent_id, canonical_name, recovery_source)} con
#'   \code{recovery_source = "LLM_NAME_CLEANUP"}. Solo i GSM dei cluster
#'   override compaiono nella lista.
#' @keywords internal
.side_table_to_recovery_overlay <- function(side_table, assignments, record_to_gsms) {
  ov <- list()
  keep <- side_table[side_table$action == "override" & !is.na(side_table$new_id), , drop = FALSE]
  asg_by <- split(assignments$record_id, assignments$cluster_id)
  for (i in seq_len(nrow(keep))) {
    cid <- keep$cluster_id[i]
    rids <- asg_by[[cid]]; if (is.null(rids)) next
    ident <- list(kind = keep$new_kind[i], agent_id = keep$new_id[i],
                  canonical_name = keep$new_canonical[i], recovery_source = "LLM_NAME_CLEANUP")
    for (rid in rids) for (g in record_to_gsms(rid)) ov[[g]] <- ident
  }
  ov
}

#' Sovrappone l'overlay LLM al recovery_lookup deterministico (in-place).
#' Per ogni GSM nell'overlay, l'identita' LLM sostituisce quella deterministica.
#'
#' @param recovery_lookup_env environment hash GSM -> identita', come
#'   costruito da \code{build_name_recovery_lookup()}. Mutato in-place: i
#'   GSM presenti in \code{overlay} vengono riassegnati, gli altri restano
#'   invariati.
#' @param overlay named list GSM -> identita' (tipicamente l'output di
#'   \code{.side_table_to_recovery_overlay()}).
#' @return lo stesso \code{recovery_lookup_env}, con le identita' dei GSM
#'   in \code{overlay} sostituite da quelle LLM.
#' @keywords internal
.overlay_recovery_lookup <- function(recovery_lookup_env, overlay) {
  for (g in names(overlay)) assign(g, overlay[[g]], envir = recovery_lookup_env)
  recovery_lookup_env
}
