#' Converte la side-table del name-cleanup in overlay GSM -> identita' corretta.
#' Solo le righe action=="override" (precision-gate). L'overlay si sovrappone
#' al recovery_lookup deterministico (Task 5); e' agganciato ai GSM membri dei
#' cluster rivisti -> nessun rischio di over-correction globale sul nome.
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
