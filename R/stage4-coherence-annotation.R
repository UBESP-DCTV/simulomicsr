# R/stage4-coherence-annotation.R --- marca i gruppi giudicati incoerenti
#
# I gruppi che il censimento ha giudicato incoerenti (lettura dei bundle, uno
# per uno) NON vengono scartati dalla pipeline. Scartarli richiederebbe una
# lista di identificativi scritta a mano: chi rifacesse la pipeline sul corpus
# otterrebbe un numero diverso senza trovare nessuna regola che spieghi la
# differenza. Vengono poolati e MARCATI: la selezione resta visibile a chi
# legge, e il numero prodotto resta quello che la pipeline produce davvero.
#
# Il verdetto e' un giudizio di lettura, non l'output di una regola: per questo
# la sua provenienza viaggia nel dato (`coherence_source`).

#' Marca i gruppi giudicati incoerenti dal censimento
#'
#' @param clusters data.frame con \code{cluster_id} e la chiave del contrasto:
#'   o la colonna \code{ckey} gia' pronta, o le tre colonne
#'   \code{contrast_entity}, \code{contrast_direction},
#'   \code{contrast_control_key} da cui viene costruita.
#' @param verdicts data.frame con \code{ckey} e \code{motivo}: i gruppi
#'   giudicati incoerenti. Ogni verdetto DEVE trovare almeno un gruppo.
#' @param source character(1) da dove viene il giudizio (es.
#'   \code{"censimento-2026-07-28"}).
#' @return \code{clusters} con tre colonne in piu': \code{coherence_verdict}
#'   (\code{"coherent"}/\code{"incoherent"}), \code{coherence_reason} e
#'   \code{coherence_source}. Righe e ordine invariati.
#' @keywords internal
.annotate_coherence <- function(clusters, verdicts, source) {
  if (!"cluster_id" %in% names(clusters)) {
    stop("annotate_coherence: manca la colonna 'cluster_id'.")
  }
  ckey <- if ("ckey" %in% names(clusters)) {
    as.character(clusters$ckey)
  } else {
    need <- c("contrast_entity", "contrast_direction", "contrast_control_key")
    if (!all(need %in% names(clusters))) {
      stop(sprintf(
        "annotate_coherence: serve la colonna 'ckey' oppure le colonne %s.",
        paste(need, collapse = ", ")))
    }
    paste0(clusters$contrast_entity, "||", clusters$contrast_direction, "||",
           clusters$contrast_control_key)
  }

  v_key <- as.character(verdicts$ckey)
  # Un verdetto che non attacca lascerebbe un gruppo incoerente marcato
  # "coerente": fallimento silenzioso, e per giunta a favore della conclusione
  # che fa comodo. Si ferma qui.
  orfani <- setdiff(v_key, ckey)
  if (length(orfani) > 0L) {
    stop(sprintf(
      "annotate_coherence: %d verdetti non trovano nessun gruppo: %s",
      length(orfani), paste(orfani, collapse = "; ")))
  }

  hit <- match(ckey, v_key)
  clusters$coherence_verdict <- ifelse(is.na(hit), "coherent", "incoherent")
  clusters$coherence_reason  <- ifelse(is.na(hit), NA_character_,
                                       as.character(verdicts$motivo)[hit])
  clusters$coherence_source  <- rep(as.character(source), nrow(clusters))
  clusters
}
