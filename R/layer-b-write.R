#' Scrive bundle Layer B su directory
#'
#' Scrive `selection_resolved.csv`, `run_metadata.json` + un `captions.json`
#' per ogni cluster bundle (mappa filename -> caption). Assume che i file
#' plot per-cluster siano gia stati scritti in place dalla pipeline di
#' generazione (delegata a `build_layer_b_results()`).
#'
#' @param lb oggetto `layer_b_result` (S3 list).
#' @param dir character path al dir di output (creato se non esiste).
#'
#' @return invisible(`dir`).
#' @export
write_layer_b_to_dir <- function(lb, dir) {
  stopifnot(inherits(lb, "layer_b_result"))
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

  readr::write_csv(lb$selection_resolved, file.path(dir, "selection_resolved.csv"))
  jsonlite::write_json(
    lb$run_metadata,
    file.path(dir, "run_metadata.json"),
    auto_unbox = TRUE, pretty = TRUE
  )

  # captions.json per ogni cluster bundle (mappa nome-plot -> caption string)
  for (cl_id in names(lb$cluster_bundles)) {
    bundle <- lb$cluster_bundles[[cl_id]]
    cl_dir <- file.path(dir, cl_id)
    if (!dir.exists(cl_dir)) dir.create(cl_dir, recursive = TRUE)
    captions <- lapply(bundle$plots, function(p) p$caption)
    names(captions) <- names(bundle$plots)
    jsonlite::write_json(
      captions,
      file.path(cl_dir, "captions.json"),
      auto_unbox = TRUE, pretty = TRUE
    )
  }

  invisible(dir)
}

#' Carica bundle Layer B da directory
#'
#' Rilegge `selection_resolved.csv` + `run_metadata.json`, ricostruisce uno
#' scheletro `layer_b_result` con elenco dei file per-cluster + captions
#' deserializzate. NON ricarica binari (immagini PNG/SVG, tabelle CSV/LaTeX
#' restano come puri path su disco).
#'
#' @param dir character path al dir bundle Layer B.
#'
#' @return oggetto S3 `layer_b_result` con:
#'   \describe{
#'     \item{cluster_bundles}{list per cluster_id con `cluster_id`, `cluster_dir`,
#'       `plot_files` (character vector di path), `captions` (list).}
#'     \item{selection_resolved}{tibble.}
#'     \item{run_metadata}{list deserializzata da JSON.}
#'     \item{dir}{character path al dir di origine.}
#'   }
#' @export
load_layer_b <- function(dir) {
  sel_path <- file.path(dir, "selection_resolved.csv")
  meta_path <- file.path(dir, "run_metadata.json")
  if (!file.exists(sel_path) || !file.exists(meta_path)) {
    cli::cli_abort(
      "Layer B dir incomplete: missing {.path selection_resolved.csv} or {.path run_metadata.json}"
    )
  }

  sel <- readr::read_csv(sel_path, show_col_types = FALSE)
  meta <- jsonlite::read_json(meta_path)

  cluster_ids <- sel$cluster_id
  bundles <- lapply(cluster_ids, function(cl_id) {
    cl_dir <- file.path(dir, cl_id)
    captions_path <- file.path(cl_dir, "captions.json")
    captions <- if (file.exists(captions_path)) jsonlite::read_json(captions_path) else list()

    list(
      cluster_id = cl_id,
      cluster_dir = cl_dir,
      plot_files = list.files(
        cl_dir,
        pattern = "\\.(png|svg|csv|tex|md|qmd|json)$",
        full.names = TRUE
      ),
      captions = captions
    )
  })
  names(bundles) <- cluster_ids

  structure(
    list(
      cluster_bundles = bundles,
      selection_resolved = sel,
      run_metadata = meta,
      dir = dir
    ),
    class = "layer_b_result"
  )
}
