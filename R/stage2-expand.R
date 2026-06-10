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

#' Assembla lo study_design finale di UNO studio dai record input + output LLM
#'
#' Compone i tre passi: fusione dei chunk (\code{\link{.merge_chunked_designs}}),
#' mappa rappresentante->membri (\code{\link{.build_member_lookup}}), espansione
#' (\code{\link{.expand_study_design}}). Restituisce NULL se nessun record dello
#' studio ha un output LLM valido.
#'
#' @param input_records Lista dei record input v3 dello studio (1 o N chunk).
#' @param llm_outputs Named list \code{record_id} -> study_design (parsed_json).
#' @return Lo study_design finale a campioni reali, o NULL.
#' @keywords internal
.assemble_stage2_study <- function(input_records, llm_outputs) {
  rids <- vapply(input_records, function(r) as.character(r$record_id)[[1L]],
                 character(1))
  designs <- Filter(Negate(is.null), lapply(rids, function(rid) llm_outputs[[rid]]))
  if (length(designs) == 0L) return(NULL)
  merged <- .merge_chunked_designs(designs)
  lookup <- .build_member_lookup(input_records)
  .expand_study_design(merged, lookup)
}

#' Fonde gli study_design dei chunk di uno studio in uno solo
#'
#' Per gli studi chunkati (coda D2) ogni chunk produce uno study_design a
#' rappresentanti. I controlli sono broadcastati in ogni chunk, quindi lo stesso
#' gruppo (per insieme di rappresentanti) compare in piu' chunk: va deduplicato.
#' I \code{group_id} per-chunk collidono -> rigenerati canonici (\code{mg1},
#' \code{mg2}, ...); i \code{comparisons} si uniscono, rimappano e deduplicano.
#' I confronti sono gia' intra-chunk (controllo presente per broadcast): nessuna
#' ricostruzione cross-chunk. Conflitti su campi a basso impatto:
#' \code{primary_role} del controllo deduplicato = \code{control} se almeno un
#' chunk lo dice, altrimenti la moda non-\code{unclear}; \code{design_kind} =
#' moda non-\code{unclear} tra i chunk; gli altri campi studio
#' (design_summary, factors, extraction) dal chunk con piu' comparisons.
#'
#' @param designs Lista di study_design (uno per chunk).
#' @return Un singolo study_design fuso (a rappresentanti, pre-espansione).
#' @keywords internal
.merge_chunked_designs <- function(designs) {
  if (length(designs) == 1L) return(designs[[1L]])

  key_of <- function(rg) {
    paste(sort(as.character(unlist(rg$sample_ids))), collapse = "")
  }

  canon <- list()          # key -> list(gid, group, roles)
  order_keys <- character(0)
  for (d in designs) for (rg in d$replicate_groups) {
    k <- key_of(rg)
    role <- as.character(rg$primary_role %||% "unclear")
    if (is.null(canon[[k]])) {
      order_keys <- c(order_keys, k)
      g <- rg
      g$group_id <- sprintf("mg%d", length(order_keys))
      canon[[k]] <- list(gid = g$group_id, group = g, roles = role)
    } else {
      canon[[k]]$roles <- c(canon[[k]]$roles, role)
    }
  }

  resolve_role <- function(roles) {
    if ("control" %in% roles) return("control")
    nz <- roles[roles != "unclear"]
    if (length(nz)) return(names(sort(table(nz), decreasing = TRUE))[1L])
    roles[1L]
  }
  merged_groups <- lapply(order_keys, function(k) {
    g <- canon[[k]]$group
    g$primary_role <- resolve_role(canon[[k]]$roles)
    g
  })

  # comparisons: rimappa group_id locali ai canonici, deduplica
  seen <- character(0)
  merged_comps <- list()
  for (d in designs) {
    local_map <- list()
    for (rg in d$replicate_groups) {
      local_map[[as.character(rg$group_id)]] <- canon[[key_of(rg)]]$gid
    }
    for (cmp in d$comparisons) {
      tg <- local_map[[as.character(cmp$treated_group)]]
      cg <- local_map[[as.character(cmp$control_group)]]
      if (is.null(tg) || is.null(cg)) next  # riferimento non risolvibile
      dk <- paste(tg, cg, as.character(cmp$control_type %||% ""), sep = "")
      if (dk %in% seen) next
      seen <- c(seen, dk)
      cmp$treated_group <- tg
      cmp$control_group <- cg
      merged_comps[[length(merged_comps) + 1L]] <- cmp
    }
  }

  kinds <- vapply(designs, function(d) as.character(d$design_kind %||% "unclear"),
                  character(1))
  nzk <- kinds[kinds != "unclear"]
  design_kind <- if (length(nzk)) names(sort(table(nzk), decreasing = TRUE))[1L] else "unclear"

  ncomp <- vapply(designs, function(d) length(d$comparisons), integer(1))
  out <- designs[[which.max(ncomp)]]
  out$series_id <- designs[[1L]]$series_id
  out$replicate_groups <- merged_groups
  out$comparisons <- merged_comps
  out$design_kind <- design_kind
  out
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
