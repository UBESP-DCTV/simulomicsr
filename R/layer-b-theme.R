#' Tinte del Layer B
#'
#' Una sola definizione per tutte le figure: oggi ogni funzione sceglie i propri
#' colori, ed e' uno dei motivi per cui il report non sembra un solo oggetto.
#' @keywords internal
.LB_COLORI <- list(
  su         = "#B2182B",  # effetto positivo
  giu        = "#2166AC",  # effetto negativo
  neutro     = "#BFBFBF",  # non significativo (legenda del volcano)
  evidenza   = "#1A1A1A",  # stime poolate, testo forte
  per_studio = "#6E6E6E"   # stime PER-STUDIO nel forest (rilievo I6,
                           # 2026-08-06): NON $neutro. Il forest non ha
                           # legenda, ma chi ha appena letto il volcano
                           # leggerebbe lo stesso grigio come "non
                           # significativo" invece che "una stima per
                           # studio" -- due significati diversi in due
                           # figure adiacenti dello stesso case study.
)

#' Tema comune delle figure del Layer B
#' @keywords internal
.lb_theme <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = base_size * 1.15),
      plot.subtitle = ggplot2::element_text(colour = "grey35"),
      plot.caption = ggplot2::element_text(colour = "grey35", hjust = 0),
      axis.title = ggplot2::element_text(colour = "grey25"),
      legend.position = "bottom"
    )
}

#' Titolo di una figura: quale gruppo, su quanti studi
#'
#' Nessuna figura del report attuale dice a quale gruppo appartiene: aperta da
#' sola non e' interpretabile.
#' @keywords internal
.lb_titolo <- function(entita, k, extra = NULL) {
  studi <- if (isTRUE(k == 1L)) "1 studio" else sprintf("%d studi", as.integer(k))
  parti <- c(as.character(entita), studi, extra)
  paste(parti[nzchar(parti) & !is.na(parti)], collapse = " · ")
}
