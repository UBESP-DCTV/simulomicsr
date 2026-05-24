#' Render Quarto aggregate report Layer B (HTML standalone)
#'
#' Compila il template `inst/templates/layer-b-report.qmd` per produrre un
#' HTML auto-contenuto (embed-resources) che aggrega tutti i case studies
#' Layer B (selection table, config snapshot, per-cluster summary card +
#' PNG plots + top-gene table + narrative).
#'
#' Quarto richiede una working directory locale: il template viene copiato
#' in una tmpdir, renderizzato la, e l'HTML risultante viene copiato al
#' `out_path` finale.
#'
#' @param lb `layer_b_result` (output di [build_layer_b_results()] o
#'   [load_layer_b()]).
#' @param out_path character path output HTML. Default: `lb$dir/layer_b_report.html`.
#' @param template character path al .qmd template. Default: incluso nel pacchetto.
#'
#' @return invisible(out_path).
#' @export
render_layer_b_report <- function(lb, out_path = NULL, template = NULL) {
  stopifnot(inherits(lb, "layer_b_result"))
  if (is.null(out_path)) {
    out_path <- file.path(lb$dir, "layer_b_report.html")
  }
  if (is.null(template)) {
    template <- system.file("templates/layer-b-report.qmd", package = "simulomicsr")
    if (template == "") {
      cli::cli_abort("Template layer-b-report.qmd not found in installed package")
    }
  }

  # Quarto richiede di lavorare in una working dir; copia template a tmpdir
  tmpd <- tempfile("lb_render_")
  dir.create(tmpd)
  on.exit(unlink(tmpd, recursive = TRUE))
  qmd_local <- file.path(tmpd, "layer-b-report.qmd")
  file.copy(template, qmd_local, overwrite = TRUE)

  quarto::quarto_render(
    input = qmd_local,
    output_file = "layer_b_report.html",
    execute_params = list(layer_b_dir = normalizePath(lb$dir)),
    quiet = TRUE
  )

  rendered_html <- file.path(tmpd, "layer_b_report.html")
  if (!file.exists(rendered_html)) {
    cli::cli_abort(
      "Quarto render did not produce expected output: {.path {rendered_html}}"
    )
  }
  file.copy(rendered_html, out_path, overwrite = TRUE)

  invisible(out_path)
}
