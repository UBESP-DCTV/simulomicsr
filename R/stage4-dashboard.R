#' Render Quarto diagnostic dashboard per Stadio 4
#'
#' Wrapper attorno a \code{quarto::quarto_render()} che inietta il path
#' \code{stage4_dir} come parametro nel template. Esegue graceful
#' fallback se il pacchetto \code{quarto} non e' installato: emette un
#' warning e ritorna \code{NULL} invisibile, senza interrompere la
#' pipeline.
#'
#' Il template di default e' shipped con il pacchetto in
#' \code{inst/templates/stage4-dashboard.qmd}: viene copiato in un
#' tempfile per evitare side-effect sulla directory \code{inst/}
#' durante il rendering. L'output HTML viene poi spostato in
#' \code{out_path}.
#'
#' @param s4_dir directory output Stage 4 (con i 5 file canonici
#'   prodotti da \code{write_stage4_to_dir}).
#' @param out_path destinazione finale del file HTML. Default
#'   \code{file.path(s4_dir, "stage4_dashboard.html")}.
#' @param quarto_template path al template .qmd. Default usa quello
#'   shipped con il pacchetto (\code{inst/templates/stage4-dashboard.qmd}).
#' @return \code{invisible(out_path)} se il render ha successo,
#'   \code{invisible(NULL)} se \code{quarto} non disponibile o template
#'   mancante.
#' @export
render_stage4_dashboard <- function(s4_dir, out_path = NULL,
                                    quarto_template = NULL) {
  if (!requireNamespace("quarto", quietly = TRUE)) {
    warning("quarto package non installato; salto rendering dashboard. ",
            "Install con install.packages('quarto').")
    return(invisible(NULL))
  }

  if (is.null(quarto_template)) {
    quarto_template <- system.file("templates", "stage4-dashboard.qmd",
                                   package = "simulomicsr")
  }
  if (!nzchar(quarto_template) || !file.exists(quarto_template)) {
    warning(sprintf("Template Quarto non trovato: %s", quarto_template))
    return(invisible(NULL))
  }

  if (is.null(out_path)) {
    out_path <- file.path(s4_dir, "stage4_dashboard.html")
  }

  # Copia template a tempfile per non sporcare inst/templates/ durante
  # il rendering (Quarto scrive file accessori accanto al .qmd).
  tmp_qmd <- tempfile(fileext = ".qmd")
  file.copy(quarto_template, tmp_qmd, overwrite = TRUE)

  quarto::quarto_render(
    input = tmp_qmd,
    output_format = "html",
    output_file = basename(out_path),
    execute_params = list(stage4_dir = normalizePath(s4_dir)),
    quiet = TRUE
  )

  # Sposta output prodotto (accanto a tmp_qmd) verso out_path finale.
  produced <- file.path(dirname(tmp_qmd), basename(out_path))
  if (file.exists(produced)) file.rename(produced, out_path)

  invisible(out_path)
}
