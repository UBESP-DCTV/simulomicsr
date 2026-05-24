#' Parse anchor_key v3 in named list dei 13 segmenti canonical
#'
#' Data una stringa \code{anchor_key} pipe-delimited prodotta da
#' \code{.build_anchor_for_level()} + \code{level} + \code{tier_assignment},
#' ricostruisce il named list dei 13 segmenti canonical dell'anchor v3:
#' \code{kind_effective}, \code{agent_id}, \code{variant_label},
#' \code{dose_canonical}, \code{duration_canonical}, \code{phase_canonical},
#' \code{cell_id}, \code{context_kind}, \code{cell_state}, \code{subcellular},
#' \code{tissue}, \code{disease_status}, \code{has_engineered}.
#'
#' I segmenti droppati per il \code{level} corrente (vedi
#' \code{.dropped_segments_at_level()} per L0-L3 e \code{tier_assignment$S}
#' per L4) sono \code{NA_character_} nell'output, in modo che il consumer
#' possa indicizzare per nome senza preoccuparsi del livello.
#'
#' Inverso di \code{.build_anchor_key_from_segments()} /
#' \code{.build_anchor_for_level()} -- usato per esporre metadata anchor
#' leggibile (es. nelle summary card di Layer B per cluster a qualunque level,
#' dove l'indicizzazione positional L0 lascerebbe pair_L2/L3/L4 con
#' \code{kind_effective}, \code{agent_id} e \code{tissue} sbagliati o NA).
#'
#' La differenza con \code{parse_anchor_canonical()} (internal, modulo
#' Stage 4) e' che quest'ultima restituisce solo i segmenti presenti al
#' livello, mentre \code{parse_anchor_key()} restituisce sempre i 13 con NA
#' per i droppati: piu' ergonomico per uso downstream.
#'
#' @param anchor_key character(1): stringa pipe-delimited.
#' @param level integer(1) in \code{0:4}.
#' @param tier_assignment list (default = \code{stage3_default_config()$tier_assignment}).
#' @return named list di 13 elementi character (\code{NA_character_} se
#'   droppato a quel livello), nell'ordine canonical.
#' @seealso \code{\link{stage3_default_config}},
#'   \code{R/stage3-anchor-levels.R::.build_anchor_for_level},
#'   \code{R/stage4-anchor-matching.R::parse_anchor_canonical}.
#' @export
parse_anchor_key <- function(anchor_key, level, tier_assignment = NULL) {
  stopifnot(
    is.character(anchor_key), length(anchor_key) == 1L, !is.na(anchor_key),
    length(level) == 1L, level %in% 0L:4L
  )
  if (is.null(tier_assignment)) {
    tier_assignment <- stage3_default_config()$tier_assignment
  }

  # Ordine canonical dei 13 segmenti, identico a .extract_anchor_segments()
  # in R/stage3-anchor-levels.R.
  canonical_names <- c(
    "kind_effective", "agent_id", "variant_label",
    "dose_canonical", "duration_canonical", "phase_canonical",
    "cell_id", "context_kind", "cell_state",
    "subcellular", "tissue", "disease_status", "has_engineered"
  )

  # Calcolo dei segmenti tenuti a questo level. Mantieni l'ordine canonical
  # (NON l'ordine in cui tier_assignment$S e' definito in config), coerente
  # con .build_anchor_for_level().
  if (level == 4L) {
    kept_names <- canonical_names[canonical_names %in% tier_assignment$S]
  } else {
    dropped <- .dropped_segments_at_level(tier_assignment, level)
    kept_names <- canonical_names[!canonical_names %in% dropped]
  }

  segs <- strsplit(anchor_key, "|", fixed = TRUE)[[1L]]
  if (length(segs) != length(kept_names)) {
    stop(sprintf(
      "anchor_key ha %d segmenti, atteso %d a level %d",
      length(segs), length(kept_names), level
    ))
  }

  # Costruisci risultato con tutti i 13 nomi: valori dai segs per i kept,
  # NA_character_ per i droppati.
  out <- as.list(rep(NA_character_, length(canonical_names)))
  names(out) <- canonical_names
  out[kept_names] <- as.list(segs)
  out
}
