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

#' Riassembla i chunk Stadio 2 in un record per studio
#'
#' Uno studio grande viene classificato dallo Stadio 2 in piu' chunk (cs50, per
#' il limite di contesto LLM): nel master compare come N record con la stessa
#' `series_id`. La pipeline a valle assume un record per studio (record_id =
#' `series__group`, indice Stadio 4 per `series_id` last-wins) -> di uno studio
#' chunked sopravvive solo l'ultimo chunk, gli altri campioni vengono persi o
#' misrisolti (vedi finding 2026-06-01). Questa funzione ripristina l'invariante:
#' fonde i record con la stessa `series_id` in UN record.
#'
#' Strategia **namespacing-per-chunk**, non union-per-id: sui dati reali 639
#' group_id omonimi tra chunk hanno `primary_role` in conflitto e 831
#' comparison_id riferiscono treated/control diversi. Unire per id li
#' corromperebbe. Invece ogni chunk mantiene i suoi gruppi/comparison con id resi
#' unici (suffisso `#chunk<k>`); i riferimenti delle comparison vengono riscritti
#' coerentemente entro lo stesso chunk. Il merge biologico (due chunk dello stesso
#' gruppo) lo fa il clustering per-anchor a valle, non questa funzione.
#'
#' Idempotente: applicata a un master gia' riassemblato (un record per series) e'
#' un no-op. Le series a chunk singolo restano invariate (nessun rename).
#'
#' @param stage2_master list di study records (output di `.load_stage2_master`).
#' @return `list(stage2_master = <riassemblato>, report = list(n_records_in,
#'   n_records_out, n_series_multichunk))`.
#' @keywords internal
.reassemble_stage2_chunks <- function(stage2_master) {
  n_in <- length(stage2_master)
  # Raggruppa per series_id preservando l'ordine di apparizione (= ordine
  # last-wins di .index_stage2_master). I record senza series_id restano singoli.
  sids <- vapply(stage2_master, function(s) {
    v <- s$series_id
    if (is.null(v) || length(v) == 0L || is.na(v[[1L]])) NA_character_
    else as.character(v[[1L]])
  }, character(1L))

  order_keys <- unique(sids)
  out <- vector("list", 0L)
  n_multichunk <- 0L

  for (key in order_keys) {
    idx <- which(sids == key | (is.na(sids) & is.na(key)))
    chunks <- stage2_master[idx]
    if (length(chunks) == 1L) {           # series non chunked: invariata
      out[[length(out) + 1L]] <- chunks[[1L]]
      next
    }
    n_multichunk <- n_multichunk + 1L

    merged_groups <- list()
    merged_cmps   <- list()
    for (k in seq_along(chunks)) {
      ch <- chunks[[k]]
      suffix <- paste0("#chunk", k)
      rename <- character(0)              # group_id originale -> namespaced
      for (rg in (ch$replicate_groups %||% list())) {
        new_gid <- paste0(rg$group_id %||% "", suffix)
        rename[rg$group_id %||% ""] <- new_gid
        rg$group_id <- new_gid
        merged_groups[[length(merged_groups) + 1L]] <- rg
      }
      for (cmp in (ch$comparisons %||% list())) {
        cmp$comparison_id <- paste0(cmp$comparison_id %||% "", suffix)
        tg <- cmp$treated_group %||% ""
        cg <- cmp$control_group %||% ""
        if (!is.null(rename[[tg]]) && !is.na(rename[tg])) cmp$treated_group <- rename[[tg]]
        if (!is.null(rename[[cg]]) && !is.na(rename[cg])) cmp$control_group <- rename[[cg]]
        merged_cmps[[length(merged_cmps) + 1L]] <- cmp
      }
    }
    # Record riassemblato: parte dal primo chunk (preserva campi top-level
    # inerti a valle: design_kind/summary/factors/extraction) e sostituisce
    # i tre campi consumati.
    rec <- chunks[[1L]]
    rec$series_id        <- key
    rec$replicate_groups <- merged_groups
    rec$comparisons      <- merged_cmps
    out[[length(out) + 1L]] <- rec
  }

  list(
    stage2_master = out,
    report = list(
      n_records_in       = n_in,
      n_records_out      = length(out),
      n_series_multichunk = n_multichunk
    )
  )
}

#' Costruisce la mappa series_id -> GSM in input dall'input Stadio 2
#'
#' Legge uno o piu' file JSONL di input Stadio 2 (formato
#' `{record_id, series_id, samples: [{geo_accession, ...}]}`) e restituisce una
#' named list `series_id -> character vector dei GSM` di quello studio. I chunk
#' di uno stesso studio (record_id "GSE100#1of2", "GSE100#2of2", ...) vengono
#' UNITI per series, coerente con il riassemblaggio
#' (\code{\link{.reassemble_stage2_chunks}}): il completeness guard a valle gira
#' per-studio. L'union di piu' file copre l'input originale + i rescue (resplit
#' cs25, cascade).
#'
#' @param paths character vector di path JSONL input Stadio 2.
#' @return named list series_id -> character vector di GSM (union sui chunk).
#' @keywords internal
.build_stage2_input_lookup <- function(paths) {
  lookup <- list()
  for (path in paths) {
    if (!file.exists(path)) stop("stage2_input path non esiste: ", path)
    lines <- readLines(path, warn = FALSE)
    for (line in lines) {
      if (!nzchar(trimws(line))) next
      rec <- jsonlite::fromJSON(line, simplifyVector = FALSE)
      sid <- rec$series_id %||% sub("(#|--).*$", "", rec$record_id %||% "")
      if (is.null(sid) || is.na(sid) || !nzchar(sid)) next
      gsms <- vapply(
        rec$samples %||% list(),
        function(s) s$geo_accession %||% NA_character_,
        character(1L)
      )
      lookup[[sid]] <- union(lookup[[sid]], as.character(gsms[!is.na(gsms)]))
    }
  }
  lookup
}

#' Applica il completeness guard per-studio (post-riassemblaggio)
#'
#' Driver del completeness guard sui record gia' riassemblati (un record per
#' series). Per ogni studio confronta i sample coperti dai replicate_groups con
#' i GSM in input a quello studio (\code{input_by_series}, union sui chunk) e
#' aggiunge gli scoperti a un gruppo sintetico `unclear` via
#' \code{\link{complete_stage2_coverage}}.
#'
#' @param stage2_master list di study records riassemblati (parsed_json).
#' @param input_by_series named list series_id -> GSM in input (da
#'   \code{\link{.build_stage2_input_lookup}}).
#' @return list(records = completati, report = list(n_uncovered_total,
#'   n_records_affected)).
#' @keywords internal
.apply_stage2_completeness_by_series <- function(stage2_master, input_by_series) {
  n_total <- 0L; n_aff <- 0L
  for (i in seq_along(stage2_master)) {
    sid <- stage2_master[[i]]$series_id
    sid <- if (is.null(sid) || length(sid) == 0L) NA_character_ else as.character(sid[[1L]])
    inp <- if (!is.na(sid)) input_by_series[[sid]] else NULL
    if (is.null(inp)) next
    res <- complete_stage2_coverage(stage2_master[[i]], inp)
    stage2_master[[i]] <- res$parsed_json
    if (res$n_added > 0L) { n_total <- n_total + res$n_added; n_aff <- n_aff + 1L }
  }
  list(records = stage2_master,
       report = list(n_uncovered_total = n_total, n_records_affected = n_aff))
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
