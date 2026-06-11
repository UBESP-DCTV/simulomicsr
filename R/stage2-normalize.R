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

#' Verifica l'invariante "un record per studio" del master Stadio 2 (opzione C)
#'
#' Lo Stadio 2 opzione C (ADR-0020) classifica le condizioni di disegno
#' deduplicate e l'espansione a valle produce UN record per studio. La pipeline
#' a valle assume questo invariante: lo Stadio 4 indicizza il master per
#' `series_id` (\code{.index_stage2_master}, last-wins) e lo Stadio 3 costruisce
#' `record_id = series__group`. Se il master contenesse piu' record con la stessa
#' `series_id` (input chunked inatteso), i record non-ultimi verrebbero persi o
#' misrisolti in silenzio (finding 2026-06-01).
#'
#' Questo guard FALLISCE rumorosamente in quel caso, invece di riassemblare in
#' silenzio. Sostituisce la vecchia \code{.reassemble_stage2_chunks} (namespacing
#' per-chunk), superata da opzione C: quel riassemblaggio perdeva i confronti
#' cross-chunk (~435 REM) ed era dichiarato inaccettabile in ADR-0020. Tenerla
#' come rete difensiva sarebbe peggio di niente: produrrebbe output sbagliato ma
#' schema-valido senza segnalare. Drop-in (ritorna il master invariato).
#'
#' I record senza `series_id` (anomalia separata) non innescano l'errore.
#'
#' @param stage2_master list di study records (output di `.load_stage2_master`).
#' @return `stage2_master` invariato se l'invariante regge; altrimenti \code{stop()}.
#' @keywords internal
.assert_stage2_one_record_per_series <- function(stage2_master) {
  sids <- vapply(stage2_master, function(s) {
    v <- s$series_id
    if (is.null(v) || length(v) == 0L || is.na(v[[1L]])) NA_character_
    else as.character(v[[1L]])
  }, character(1L))
  present <- sids[!is.na(sids)]
  dup <- unique(present[duplicated(present)])
  if (length(dup) > 0L) {
    stop(sprintf(paste0(
      "Invariante Stadio 2 violata: %d series_id compaiono in piu' record ",
      "(input chunked inatteso). Lo Stadio 2 opzione C (ADR-0020) deve produrre ",
      "UN record per studio. Esempi: %s. Vedi finding 2026-06-01."),
      length(dup), paste(utils::head(dup, 5L), collapse = ", ")),
      call. = FALSE)
  }
  stage2_master
}

#' Costruisce la mappa series_id -> GSM in input dall'input Stadio 2
#'
#' Legge uno o piu' file JSONL di input Stadio 2 (formato
#' `{record_id, series_id, samples: [{geo_accession, member_sample_ids, ...}]}`)
#' e restituisce una named list `series_id -> character vector dei GSM` di quello
#' studio. In v3 (opzione C) ogni sample e' una condizione: `geo_accession` e' il
#' rappresentante e `member_sample_ids` sono i GSM reali -> si raccolgono TUTTI i
#' membri (altrimenti i non-rappresentanti risulterebbero scoperti e finirebbero
#' in 'unclear'). Se `member_sample_ids` e' assente (input v2) si ricade su
#' `geo_accession` (retrocompatibile). I chunk
#' di uno stesso studio (record_id "GSE100#1of2", "GSE100#2of2", ...) vengono
#' UNITI per series: il completeness guard a valle gira per-studio, coerente con
#' l'invariante un-record-per-studio
#' (\code{\link{.assert_stage2_one_record_per_series}}). L'union di piu' file
#' copre l'input originale + i rescue (resplit cs25, cascade).
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
      # v3 (opzione C): ogni sample e' una condizione, geo_accession e' il
      # rappresentante e member_sample_ids sono i GSM reali -> il guard deve
      # contare TUTTI i membri, non il solo rappresentante. v2 (no
      # member_sample_ids): fallback a geo_accession (retrocompatibile).
      gsms <- unlist(lapply(rec$samples %||% list(), function(s) {
        m <- s$member_sample_ids
        if (!is.null(m) && length(m) > 0L) as.character(unlist(m))
        else if (!is.null(s$geo_accession)) as.character(s$geo_accession)
        else character(0L)
      }), use.names = FALSE)
      lookup[[sid]] <- union(lookup[[sid]], gsms[!is.na(gsms) & nzchar(gsms)])
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
