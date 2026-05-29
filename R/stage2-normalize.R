# Completeness guard sull'output Stadio 2 (study_design.stage2.v2).
#
# Motivazione (FASE F2, benchmark scalato 2026-05-28/29): lo Stadio 2 LLM a
# volte non assegna un replicate_group a ogni sample di input, violando la sua
# stessa REGOLA 4 ("DO NOT OMIT"; ~3.5% dei sample nel benchmark). I sample non
# coperti vengono silenziosamente esclusi dal clustering Stadio 3, perdendo
# tracciabilita'. Questo guard materializza la REGOLA 4 in modo deterministico:
# ogni sample di input non coperto viene raccolto in un replicate_group
# sintetico `primary_role='unclear'` (inerte al pooling treated/control, ma
# esplicito e auditabile). Chunk-aware: la copertura va confrontata con la
# lista di sample EFFETTIVAMENTE in input a quel record (non l'intera series),
# quindi il driver prende `input_by_record` keyed per record_id.

#' Aggiunge i sample di input non coperti a un replicate_group `unclear`
#'
#' @param parsed_json un record study_design.stage2.v2 (con `replicate_groups`).
#' @param input_sample_ids character vector dei GSM in input a QUESTO record.
#' @return list(parsed_json = completato, n_added = int, uncovered = char).
#' @keywords internal
complete_stage2_coverage <- function(parsed_json, input_sample_ids) {
  input_sample_ids <- unique(as.character(input_sample_ids))
  rgs <- parsed_json$replicate_groups
  covered <- if (is.null(rgs) || length(rgs) == 0L) character(0) else
    unique(as.character(unlist(lapply(rgs, function(rg) rg$sample_ids))))
  uncovered <- setdiff(input_sample_ids, covered)
  if (length(uncovered) > 0L) {
    synth <- list(
      group_id     = "completeness_uncovered",
      label_human  = "Sample non coperti da Stadio 2 (REGOLA 4 guard)",
      sample_ids   = as.list(uncovered),
      primary_role = "unclear",
      factor_levels = list()
    )
    parsed_json$replicate_groups <- c(rgs %||% list(), list(synth))
  }
  list(parsed_json = parsed_json, n_added = length(uncovered), uncovered = uncovered)
}

#' Applica il completeness guard a un set di record Stadio 2
#'
#' @param stage2_records list di record, ognuno con `record_id` + `parsed_json`.
#' @param input_by_record named list/env: record_id -> character vector dei GSM
#'   in input a quel record (dallo stage2 input, chunk-aware). Record senza
#'   entry vengono lasciati invariati (skip sicuro).
#' @return list(records = completati, n_uncovered_total, n_records_affected,
#'   report = data.frame(record_id, n_uncovered)).
#' @keywords internal
audit_stage2_coverage <- function(stage2_records, input_by_record) {
  n_total <- 0L; n_aff <- 0L
  rid_v <- character(0); nunc_v <- integer(0)
  for (i in seq_along(stage2_records)) {
    rec <- stage2_records[[i]]
    rid <- rec$record_id %||% rec$parsed_json$series_id %||% NA_character_
    inp <- if (!is.null(rid) && !is.na(rid)) input_by_record[[rid]] else NULL
    if (is.null(inp)) next
    res <- complete_stage2_coverage(rec$parsed_json, inp)
    stage2_records[[i]]$parsed_json <- res$parsed_json
    if (res$n_added > 0L) {
      n_total <- n_total + res$n_added; n_aff <- n_aff + 1L
      rid_v <- c(rid_v, rid); nunc_v <- c(nunc_v, res$n_added)
    }
  }
  list(records = stage2_records, n_uncovered_total = n_total,
       n_records_affected = n_aff,
       report = data.frame(record_id = rid_v, n_uncovered = nunc_v,
                           stringsAsFactors = FALSE))
}
