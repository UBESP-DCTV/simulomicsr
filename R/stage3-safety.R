#' Calcola il pooling safety score per un cluster
#'
#' Per ogni segmento droppato, calcola la modal frequency (max p) nel cluster.
#' Aggrega via min (weakest-link, primary) e geom_mean (softer, secondary).
#' Mantiene per-segment scores nell'output per analisi custom.
#'
#' L0 case (no segments dropped): safety = 1.0 by convention.
#'
#' @param cluster_records list of list, ogni elemento e' un sample_fact o anchor segments
#'   con i segmenti droppati come keys.
#' @param dropped_segments character vector dei nomi dei segmenti droppati.
#' @return list con `safety_min`, `safety_geom_mean`, `safety_per_segment` (named list).
#' @keywords internal
.compute_pooling_safety <- function(cluster_records, dropped_segments) {
  if (length(dropped_segments) == 0L) {
    return(list(
      safety_min         = 1.0,
      safety_geom_mean   = 1.0,
      safety_per_segment = list()
    ))
  }

  per_segment <- vapply(dropped_segments, function(seg) {
    values <- vapply(cluster_records, function(r) {
      v <- r[[seg]]
      if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)
    }, character(1L))
    # Modal frequency: max(table) / total
    tbl <- table(values, useNA = "ifany")
    as.numeric(max(tbl) / length(values))
  }, numeric(1L))

  names(per_segment) <- dropped_segments

  list(
    safety_min         = min(per_segment),
    safety_geom_mean   = exp(mean(log(per_segment))),
    safety_per_segment = as.list(per_segment)
  )
}
