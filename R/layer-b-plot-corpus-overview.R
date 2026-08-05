#' Tre pannelli: distribuzione di k_effective, I2_med, n_sig sulle meta-analisi
#'
#' Risponde a colpo d'occhio a "quanto e' grande questa cosa" (spec del
#' ridisegno, §3.2 "Il corpus"): tre istogrammi affiancati (via
#' `patchwork::wrap_plots()`) col tema condiviso [.lb_theme()] e i colori di
#' [.LB_COLORI], uno per ciascuna delle tre colonne che il deliverable
#' annotato porta gia' (`annotate_stage4_deliverable()`). La funzione legge
#' SEMPRE dal data.frame che riceve -- nessun numero e' cablato qui dentro:
#' alla prossima esecuzione i pannelli riflettono il deliverable vero, non
#' una fotografia ricopiata a mano.
#'
#' L'asse dei geni significativi e' in scala log10 (dichiarato nel titolo del
#' pannello e nella didascalia, non un taglio silenzioso): la distribuzione e'
#' fortemente asimmetrica (da zero a centinaia di migliaia) e su scala lineare
#' schiaccerebbe quasi tutti i gruppi in una singola barra.
#'
#' @param deliverable_annotato data.frame/tibble, una riga per meta-analisi,
#'   con almeno le colonne `k_effective`, `I2_med`, `n_sig` (schema di
#'   `annotate_stage4_deliverable()`). Le righe con `NA` in una colonna sono
#'   escluse dal solo pannello di quella colonna (comportamento standard di
#'   `ggplot2::geom_histogram()`, che avvisa e non fa crashare).
#' @param out_dir character path dove salvare `corpus_overview.png` (+
#'   `corpus_overview.svg` se `config$save_svg`).
#' @param config list (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path` (`NA_character_` se
#'   `config$save_svg` e' `FALSE`), `caption`, `n_gruppi`.
#' @keywords internal
.build_corpus_overview <- function(deliverable_annotato, out_dir, config) {
  richieste <- c("k_effective", "I2_med", "n_sig")
  mancanti <- setdiff(richieste, names(deliverable_annotato))
  if (length(mancanti) > 0L) {
    cli::cli_abort(
      ".build_corpus_overview: mancano le colonne {.field {mancanti}} nel deliverable annotato.")
  }

  d <- deliverable_annotato
  n_gruppi <- nrow(d)

  p_k <- ggplot2::ggplot(d, ggplot2::aes(x = k_effective)) +
    ggplot2::geom_histogram(fill = .LB_COLORI$evidenza, bins = 30, na.rm = TRUE) +
    ggplot2::labs(title = "k effettivo", x = "studi poolati per gruppo", y = "meta-analisi") +
    .lb_theme(base_size = 10)

  p_i2 <- ggplot2::ggplot(d, ggplot2::aes(x = I2_med)) +
    ggplot2::geom_histogram(fill = .LB_COLORI$su, bins = 30, na.rm = TRUE) +
    ggplot2::labs(title = "eterogeneita' (I² mediano)", x = "I² (%)", y = NULL) +
    .lb_theme(base_size = 10)

  p_sig <- ggplot2::ggplot(d, ggplot2::aes(x = pmax(n_sig, 1))) +
    ggplot2::geom_histogram(fill = .LB_COLORI$giu, bins = 30, na.rm = TRUE) +
    ggplot2::scale_x_log10() +
    ggplot2::labs(title = "geni significativi", x = "n. geni (scala log10)", y = NULL) +
    .lb_theme(base_size = 10)

  p <- patchwork::wrap_plots(p_k, p_i2, p_sig, ncol = 3L) +
    patchwork::plot_annotation(
      title = sprintf("Il corpus: %d meta-analisi poolate", n_gruppi))

  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  png_path <- file.path(out_dir, "corpus_overview.png")
  svg_path <- file.path(out_dir, "corpus_overview.svg")

  ggplot2::ggsave(png_path, p, width = 10, height = 3.6, dpi = config$dpi)
  if (isTRUE(config$save_svg)) {
    ggplot2::ggsave(svg_path, p, width = 10, height = 3.6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    paste0("Distribuzione di k effettivo, I² mediano e geni significativi ",
           "(FDR<%g) sulle %d meta-analisi del deliverable poolato (asse dei ",
           "geni significativi in scala log10)."),
    config$fdr_threshold %||% 0.05, n_gruppi)

  list(png_path = png_path, svg_path = svg_path, caption = caption, n_gruppi = n_gruppi)
}

#' "Il corpus" letto dal bundle: la figura se il deliverable annotato e'
#' raggiungibile, altrimenti il perche' non lo e'
#'
#' Punto di ingresso usato dal template Quarto (`inst/templates/layer-b-report.qmd`).
#' Il deliverable annotato (`deliverable-annotato.rds`) NON e' copiato dentro
#' il bundle Layer B -- vive nella directory dello Stadio 4 -- ma il suo path
#' e' registrato in `run_metadata.json$input_files$deliverable_annotato`
#' (collegato al build dal Task 7bis). Questa funzione lo rilegge AL MOMENTO
#' DEL RENDER: se il file e' li' e ha le colonne giuste, produce la figura a
#' tre pannelli con [.build_corpus_overview()]; altrimenti dichiara il motivo
#' invece di lasciare un buco silenzioso o far fallire il render.
#'
#' Nessun taglio silenzioso: OGNI ramo che porta a `disponibile = FALSE` mette
#' una frase in `motivo` -- chiave assente da `run_metadata` (bundle
#' costruito prima del Task 7bis), file non trovato (spostato, disco esterno
#' non montato, mai stato disponibile al build), file illeggibile, o colonne
#' mancanti.
#'
#' @param lb oggetto `layer_b_result` (output di [load_layer_b()]).
#' @param out_dir character path dove scrivere `corpus_overview.png`/`.svg`
#'   quando la figura viene generata. Default `lb$dir` (la cartella del
#'   bundle: stessa convenzione dei path relativi usata dal template per le
#'   immagini per-cluster).
#'
#' @return list con `disponibile` (`logical(1)`) e, quando `TRUE`, `plot`
#'   (l'output di [.build_corpus_overview()]); quando `FALSE`, `motivo`
#'   (`character(1)`) e `plot = NULL`.
#' @keywords internal
.corpus_overview_from_bundle <- function(lb, out_dir = lb$dir) {
  .assente <- function(motivo) list(disponibile = FALSE, motivo = motivo, plot = NULL)

  info <- lb$run_metadata$input_files$deliverable_annotato
  path <- if (!is.null(info)) info$path else NULL
  if (is.null(path) || length(path) == 0L || is.na(path) || !nzchar(path)) {
    return(.assente(paste(
      "il run_metadata di questo bundle non registra un deliverable",
      "annotato (bundle costruito prima del collegamento scheda/narrativa)."
    )))
  }
  path <- as.character(path)[1L]

  if (!file.exists(path)) {
    motivo <- if (!isTRUE(info$disponibile)) {
      mot <- info$motivo_assenza
      if (is.null(mot) || length(mot) == 0L || is.na(mot) || !nzchar(mot)) {
        sprintf("il deliverable annotato non era disponibile al momento del build (%s).", path)
      } else {
        as.character(mot)[1L]
      }
    } else {
      sprintf(
        paste0("il file %s non e' raggiungibile da questo render (era disponibile ",
               "al momento del build, ma potrebbe essere stato spostato o vivere ",
               "su un disco non montato in questo ambiente)."),
        path)
    }
    return(.assente(motivo))
  }

  d <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(d) || !is.data.frame(d) || nrow(d) == 0L) {
    return(.assente(sprintf(
      "il file %s esiste ma non contiene un data.frame con righe leggibili.", path)))
  }

  richieste <- c("k_effective", "I2_med", "n_sig")
  mancanti <- setdiff(richieste, names(d))
  if (length(mancanti) > 0L) {
    return(.assente(sprintf(
      "il file %s non ha le colonne %s.", path, paste(mancanti, collapse = ", "))))
  }

  config <- lb$run_metadata$config
  if (is.null(config)) config <- layer_b_default_config()
  plot <- .build_corpus_overview(d, out_dir = out_dir, config = config)

  list(disponibile = TRUE, plot = plot, motivo = NA_character_)
}
