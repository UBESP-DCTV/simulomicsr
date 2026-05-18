#' Arricchisce cluster metadata con gpl_platforms, studies_in_cluster,
#' n_distinct_donors derivati dai records del cluster.
#'
#' @param cluster_records list of records nel cluster (each con \code{$series_id},
#'   \code{$stage1_facts}).
#' @param archs4_metadata tibble (series_id, gpl, library_strategy opzionale) opzionale.
#'   Se NULL, \code{gpl_platforms = character(0)} e \code{n_gpl_distinct = NA}.
#' @return list con \code{studies_in_cluster}, \code{n_studies}, \code{gpl_platforms},
#'   \code{n_gpl_distinct}, \code{n_distinct_donors}.
#' @keywords internal
.enrich_cluster_metadata <- function(cluster_records, archs4_metadata = NULL) {
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

  # GPL enrichment
  if (is.null(archs4_metadata)) {
    gpl_platforms  <- character()
    n_gpl_distinct <- NA_integer_
  } else {
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
