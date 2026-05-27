#' Pre-build named list lookup series_id -> unique gpl characters
#'
#' Costruito UNA volta in `.summarize_clusters()` e passato come `gpl_lookup`
#' a ogni chiamata di `.enrich_cluster_metadata()`. Trasforma il costo per-cluster
#' da O(N) scan su archs4_metadata a O(K) lookup hash su K=cluster_size.
#'
#' @keywords internal
.build_gpl_lookup <- function(archs4_metadata) {
  if (is.null(archs4_metadata)) return(NULL)
  split_gpl <- split(archs4_metadata$gpl, archs4_metadata$series_id)
  lapply(split_gpl, function(v) {
    u <- unique(v)
    u[!is.na(u)]
  })
}

#' Pre-build named character vector lookup geo_accession -> BioSample SAMN
#'
#' Implementa il lookup primario per il dedupe cross-studio (FASE E0,
#' ADR-0019 D9). Costruito UNA volta in `.summarize_clusters()` e passato
#' come `biosample_lookup` a `.enrich_cluster_metadata()`. Costo per
#' lookup: O(1) named-vector subscripting.
#'
#' La fonte canonica della colonna `biosample_id` e' lo schema esteso di
#' `load_archs4_metadata()` (P5 audit RED_ALERT C3 + E0) che legge
#' `meta/samples/relation` da H5 e applica `parse_biosample_id()`.
#'
#' @param archs4_metadata tibble/data.frame con colonne `sample_id` e
#'   `biosample_id`. Tollerato `NULL` (caller passa NULL quando metadata
#'   non disponibile -> fallback senza dedupe).
#' @return named character vector (`names = sample_id`, `values =
#'   biosample_id` con possibili NA) oppure NULL se input incompatibile.
#'   NA preservato by-design: il chiamante in `.enrich_cluster_metadata()`
#'   tratta NA come "identita' biologica ignota -> sample distinto".
#' @keywords internal
.build_biosample_lookup <- function(archs4_metadata) {
  if (is.null(archs4_metadata)) return(NULL)
  if (!all(c("sample_id", "biosample_id") %in% names(archs4_metadata))) {
    return(NULL)
  }
  setNames(
    as.character(archs4_metadata$biosample_id),
    as.character(archs4_metadata$sample_id)
  )
}

#' Pre-build named character vector lookup geo_accession -> donor_id (LLM)
#'
#' Implementa il sample-level donor lookup (FASE E0, fix paper-grade della
#' sotto-stima `n_distinct_donors` pre-E0 che leggeva donor dal SOLO primo
#' sample del gruppo, ignorando gli altri). Post-E0,
#' `.enrich_cluster_metadata()` itera tutti i `geo_accession` del cluster
#' e li mappa via questo lookup.
#'
#' Accetta sia named list che environment (post Phase 1.5 di
#' `build_stage3_clusters()` lo stage1_master e' convertito a environment
#' per O(1) hash lookup).
#'
#' @param stage1_master named list o environment indexed per GSM con
#'   campo `$donor$donor_id` (sample_facts.stage1.v3). NA o NULL accettati
#'   come "donor info assente" -> NA nel lookup.
#' @return named character vector (`names = GSM`, `values = donor_id` con
#'   possibili NA) oppure NULL se input vuoto/incompatibile.
#' @keywords internal
.build_donor_lookup <- function(stage1_master) {
  if (is.null(stage1_master)) return(NULL)
  if (is.environment(stage1_master)) {
    gsm_names <- ls(stage1_master, all.names = FALSE)
    if (length(gsm_names) == 0L) return(NULL)
    vals <- vapply(gsm_names, function(g) {
      rec <- get(g, envir = stage1_master, inherits = FALSE)
      d <- rec$donor
      if (is.null(d)) return(NA_character_)
      d$donor_id %||% NA_character_
    }, character(1L), USE.NAMES = FALSE)
    return(setNames(vals, gsm_names))
  }
  if (is.list(stage1_master)) {
    if (length(stage1_master) == 0L) return(NULL)
    vals <- vapply(stage1_master, function(rec) {
      d <- rec$donor
      if (is.null(d)) return(NA_character_)
      d$donor_id %||% NA_character_
    }, character(1L), USE.NAMES = FALSE)
    return(setNames(vals, names(stage1_master)))
  }
  NULL
}

#' Arricchisce cluster metadata con gpl_platforms, studies_in_cluster,
#' n_distinct_donors, n_distinct_biosamples derivati dai records del cluster.
#'
#' FASE E0 (ADR-0019 D9, paper-grade fix sotto-stima pre-E0):
#'   - aggiunge \code{n_distinct_biosamples} (count SAMN unique sample-level
#'     dal cluster) come metrica primaria di dedupe cross-studio.
#'   - estende il calcolo di \code{n_distinct_donors} a sample-level (era
#'     "primo sample di ogni record", sotto-stimava quando un gruppo
#'     conteneva piu' donor); fallback al pattern legacy preservato quando
#'     \code{donor_lookup} non e' fornito (retrocompat test pre-E0).
#'
#' La policy NA-non-collassante e' la stessa per entrambe le metriche:
#' un sample senza identita' nota (SAMN o donor_id assente) conta come
#' un'identita' biologica distinta (no false collapse). Coerente con A7
#' synthesis (0.02% sample senza SAMN non vanno fusi).
#'
#' @param cluster_records list of records nel cluster. Per il sample-level
#'   lookup (E0) ogni record deve esporre \code{$treated_sample_ids} +
#'   \code{$control_sample_ids} (output di \code{.build_pair_records()} +
#'   \code{.build_group_records()} post-E0).
#' @param archs4_metadata tibble (series_id, gpl, library_strategy opzionale) opzionale.
#'   Se NULL, \code{gpl_platforms = character(0)} e \code{n_gpl_distinct = NA}.
#'   IGNORATO se \code{gpl_lookup} e' fornito.
#' @param gpl_lookup named list pre-costruita series_id -> character(gpl) (output di
#'   \code{.build_gpl_lookup()}). Preferito per performance quando chiamato in loop
#'   su molti cluster: evita di ri-scannerare archs4_metadata ad ogni chiamata.
#' @param biosample_lookup named character pre-costruito geo_accession ->
#'   SAMN (output di \code{.build_biosample_lookup()}). Se NULL,
#'   \code{n_distinct_biosamples = NA_integer_}.
#' @param donor_lookup named character pre-costruito geo_accession ->
#'   donor_id (output di \code{.build_donor_lookup()}). Se NULL, fallback
#'   al pattern legacy (\code{stage1_facts$donor$donor_id} del primo
#'   sample del record).
#' @return list con \code{studies_in_cluster}, \code{n_studies},
#'   \code{gpl_platforms}, \code{n_gpl_distinct}, \code{n_distinct_donors},
#'   \code{n_distinct_biosamples}.
#' @keywords internal
.enrich_cluster_metadata <- function(cluster_records,
                                       archs4_metadata = NULL,
                                       gpl_lookup = NULL,
                                       biosample_lookup = NULL,
                                       donor_lookup = NULL) {
  series_ids <- unique(vapply(cluster_records, function(r) {
    r$series_id %||% NA_character_
  }, character(1L)))
  series_ids <- series_ids[!is.na(series_ids)]

  # Sample-level GSM collection (E0). Union treated + control attraverso
  # tutti i record del cluster. Per group-mode control_sample_ids =
  # character(0) -> non aggiunge nulla. NA / "" droppati prima del lookup.
  all_sample_ids <- c(
    unlist(lapply(cluster_records, function(r) {
      r$treated_sample_ids %||% character(0)
    }), use.names = FALSE),
    unlist(lapply(cluster_records, function(r) {
      r$control_sample_ids %||% character(0)
    }), use.names = FALSE)
  )
  all_sample_ids <- all_sample_ids[!is.na(all_sample_ids) & nzchar(all_sample_ids)]

  # Helper interno: count distinct identita' con policy NA-non-collassante.
  # `lookup` accetta NA per "sample assente dal lookup" (es. nuovo GSM non
  # ancora indicizzato): trattato come NA = identita' distinta.
  .count_distinct_non_collapsing_na <- function(values) {
    if (length(values) == 0L) return(NA_integer_)
    known <- values[!is.na(values)]
    n_na  <- sum(is.na(values))
    length(unique(known)) + n_na
  }

  # Donors: lookup sample-level (E0) o fallback legacy (pre-E0)
  if (!is.null(donor_lookup)) {
    donor_vals <- unname(donor_lookup[all_sample_ids])
    n_distinct_donors <- .count_distinct_non_collapsing_na(donor_vals)
  } else {
    donor_ids <- vapply(cluster_records, function(r) {
      d <- r$stage1_facts$donor
      if (is.null(d)) return(NA_character_)
      d$donor_id %||% NA_character_
    }, character(1L))
    donor_ids_present <- donor_ids[!is.na(donor_ids)]
    n_distinct_donors <- if (length(donor_ids_present) == 0L)
                           NA_integer_
                         else
                           length(unique(donor_ids_present))
  }

  # BioSamples (E0 NEW): sample-level SAMN lookup
  if (!is.null(biosample_lookup)) {
    samn_vals <- unname(biosample_lookup[all_sample_ids])
    n_distinct_biosamples <- .count_distinct_non_collapsing_na(samn_vals)
  } else {
    n_distinct_biosamples <- NA_integer_
  }

  # GPL enrichment: prefer pre-built lookup (O(K) per cluster).
  if (!is.null(gpl_lookup)) {
    matched_gpls <- unlist(gpl_lookup[series_ids], use.names = FALSE)
    gpl_platforms  <- unique(matched_gpls)
    gpl_platforms  <- gpl_platforms[!is.na(gpl_platforms)]
    n_gpl_distinct <- length(gpl_platforms)
  } else if (is.null(archs4_metadata)) {
    gpl_platforms  <- character()
    n_gpl_distinct <- NA_integer_
  } else {
    # Fallback: O(N) scan per call. Mantiene retro-compatibilita' API ma sconsigliato
    # per loop su molti cluster: usa .build_gpl_lookup() + gpl_lookup invece.
    matched <- archs4_metadata[archs4_metadata$series_id %in% series_ids, , drop = FALSE]
    gpl_platforms  <- unique(matched$gpl)
    gpl_platforms  <- gpl_platforms[!is.na(gpl_platforms)]
    n_gpl_distinct <- length(gpl_platforms)
  }

  list(
    studies_in_cluster    = series_ids,
    n_studies             = length(series_ids),
    gpl_platforms         = gpl_platforms,
    n_gpl_distinct        = n_gpl_distinct,
    n_distinct_donors     = n_distinct_donors,
    n_distinct_biosamples = n_distinct_biosamples
  )
}
