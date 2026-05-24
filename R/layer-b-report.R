#' Render Quarto aggregate report Layer B (HTML standalone)
#'
#' Compila il template `inst/templates/layer-b-report.qmd` per produrre un
#' HTML auto-contenuto (embed-resources) che aggrega tutti i case studies
#' Layer B (selection table, config snapshot, per-cluster summary card +
#' PNG plots + top-gene table + narrative).
#'
#' Quarto viene eseguito con `execute_dir = lb$dir` in modo che le immagini
#' referenziate nel template via path relative `cluster_id/plot.png`
#' vengano risolte da Pandoc e correttamente base64-embeddate
#' (`embed-resources: true`). Path assoluti farebbero scattare l'auto-prepend
#' `./` di Pandoc, generando `<img src="./home/user/...">` non risolvibili.
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

  # Copia il template DENTRO lb$dir come file temporaneo: Quarto risolve le
  # path relative del markdown rispetto a `execute_dir` (== lb$dir), quindi
  # le immagini cluster_id/plot.png vengono trovate e base64-embeddate.
  lb_dir_abs <- normalizePath(lb$dir, mustWork = TRUE)
  qmd_local <- file.path(lb_dir_abs, "_layer-b-report-template.qmd")
  file.copy(template, qmd_local, overwrite = TRUE)
  on.exit(unlink(qmd_local), add = TRUE)

  # Output del render (Quarto scrive accanto al .qmd di input)
  rendered_html_default <- file.path(
    lb_dir_abs, "_layer-b-report-template.html"
  )
  on.exit(unlink(rendered_html_default), add = TRUE)

  quarto::quarto_render(
    input = qmd_local,
    execute_params = list(layer_b_dir = lb_dir_abs),
    execute_dir = lb_dir_abs,
    quiet = TRUE
  )

  if (!file.exists(rendered_html_default)) {
    cli::cli_abort(
      "Quarto render did not produce expected output: {.path {rendered_html_default}}"
    )
  }

  # Sposta/copia l'HTML al destination finale (out_path puo essere fuori da lb$dir)
  out_path_abs <- if (dirname(out_path) == ".") {
    file.path(getwd(), basename(out_path))
  } else {
    out_path
  }
  if (normalizePath(rendered_html_default, mustWork = TRUE) !=
        suppressWarnings(normalizePath(out_path_abs, mustWork = FALSE))) {
    file.copy(rendered_html_default, out_path, overwrite = TRUE)
  }

  invisible(out_path)
}
