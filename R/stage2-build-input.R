# Costruzione dell'input Stadio 2 v3 a condizioni deduplicate (ADR-0020, opzione C).
#
# Raggruppa i campioni di uno studio per design_signature in condizioni di
# disegno distinte, ciascuna con un rappresentante deterministico, il numero di
# repliche e la lista dei campioni membri. Sostituisce il chunking per-campione
# (cs50) che frammentava il disegno (finding 2026-06-01).

#' Raggruppa i campioni di uno studio in condizioni di disegno distinte
#'
#' Ogni campione e' ridotto alla sua \code{\link{design_signature}}; i campioni
#' con la stessa firma sono repliche della stessa condizione. Per ogni condizione
#' si emette: \code{condition_id} stabile (rank della firma ordinata),
#' \code{geo_accession} del rappresentante (GSM minimo alfabetico),
#' \code{sample_facts} del rappresentante, \code{n_replicates} e
#' \code{member_sample_ids} (ordinati). L'ordine delle condizioni e'
#' deterministico (per firma), indipendente dall'ordine dei campioni in input.
#'
#' @param samples Lista di campioni di UNO studio; ciascuno una lista con
#'   \code{geo_accession} e \code{sample_facts} (schema stage1.v3).
#' @return Lista di condizioni (vedi sopra). Lista vuota se nessun campione.
#' @keywords internal
.build_study_conditions <- function(samples) {
  if (length(samples) == 0L) return(list())

  geos <- vapply(samples, function(s) as.character(s$geo_accession)[[1]],
                 character(1))
  sigs <- vapply(samples, function(s) design_signature(s$sample_facts),
                 character(1))

  usig <- sort(unique(sigs))
  width <- max(4L, nchar(length(usig)))

  lapply(seq_along(usig), function(i) {
    sg <- usig[[i]]
    idx <- which(sigs == sg)
    members <- sort(geos[idx])
    rep_geo <- members[[1]]
    rep_sample <- samples[[ idx[which(geos[idx] == rep_geo)[1]] ]]
    list(
      condition_id = sprintf("cond_%0*d", width, i),
      geo_accession = rep_geo,
      sample_facts = rep_sample$sample_facts,
      n_replicates = length(idx),
      member_sample_ids = as.list(members),
      signature = sg
    )
  })
}
