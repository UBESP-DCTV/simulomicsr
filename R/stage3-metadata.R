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

#' Arricchisce cluster metadata con gpl_platforms, studies_in_cluster,
#' n_distinct_donors derivati dai records del cluster.
#'
#' @param cluster_records list of records nel cluster (each con \code{$series_id},
#'   \code{$stage1_facts}).
#' @param archs4_metadata tibble (series_id, gpl, library_strategy opzionale) opzionale.
#'   Se NULL, \code{gpl_platforms = character(0)} e \code{n_gpl_distinct = NA}.
#'   IGNORATO se \code{gpl_lookup} e' fornito.
#' @param gpl_lookup named list pre-costruita series_id -> character(gpl) (output di
#'   \code{.build_gpl_lookup()}). Preferito per performance quando chiamato in loop
#'   su molti cluster: evita di ri-scannerare archs4_metadata ad ogni chiamata.
#' @return list con \code{studies_in_cluster}, \code{n_studies}, \code{gpl_platforms},
#'   \code{n_gpl_distinct}, \code{n_distinct_donors}.
#' @keywords internal
.enrich_cluster_metadata <- function(cluster_records,
                                       archs4_metadata = NULL,
                                       gpl_lookup = NULL) {
  series_ids <- unique(vapply(cluster_records, function(r) {
    r$series_id %||% NA_character_
  }, character(1L)))
  series_ids <- series_ids[!is.na(series_ids)]

  # Donors
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
    studies_in_cluster = series_ids,
    n_studies          = length(series_ids),
    gpl_platforms      = gpl_platforms,
    n_gpl_distinct     = n_gpl_distinct,
    n_distinct_donors  = n_distinct_donors
  )
}
