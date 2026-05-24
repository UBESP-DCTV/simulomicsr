#' Default config for Layer B case study generator
#'
#' Returns a plain list of defaults used by [build_layer_b_results()] e
#' funzioni interne. Tutti i campi sono override-abili passando una list
#' parziale al `config` argument: i campi mancanti restano ai default.
#'
#' @return Lista con i seguenti elementi:
#' \describe{
#'   \item{top_n_forest}{`integer(1)` --- top-N geni nel forest plot (default 10).}
#'   \item{top_n_heatmap}{`integer(1)` --- top-N geni nella heatmap (default 30).}
#'   \item{top_n_table}{`integer(1)` --- top-N geni nella top-gene table (default 30).}
#'   \item{top_n_volcano_labels}{`integer(1)` --- top-N geni labellati nel volcano (default 15).}
#'   \item{fdr_threshold}{`numeric(1)` --- soglia FDR per significativita (default 0.05).}
#'   \item{palette}{`character(1)` --- palette colore base (default "viridis").}
#'   \item{language}{`character(1)` --- lingua caption/narrative ("en" o "it", default "en").}
#'   \item{heatmap_normalize}{`logical(1)` --- applicare vst+ComBat alla heatmap (default TRUE).}
#'   \item{go_enrichment}{`logical(1)` --- generare GO enrichment plot (default TRUE).}
#'   \item{save_svg}{`logical(1)` --- salvare anche SVG oltre PNG (default TRUE).}
#'   \item{dpi}{`integer(1)` --- DPI per output PNG (default 300).}
#'   \item{min_genes_for_go_ora}{`integer(1)` --- soglia minima geni nell'universo per ORA (default 200; sotto skip-graceful).}
#'   \item{max_heatmap_samples}{`integer(1)` --- max sample plottati nella heatmap (default 100; sopra subsample stratificato).}
#' }
#'
#' @export
#' @examples
#' config <- layer_b_default_config()
#' # Override solo top_n_forest:
#' config$top_n_forest <- 20L
layer_b_default_config <- function() {
  list(
    top_n_forest         = 10L,
    top_n_heatmap        = 30L,
    top_n_table          = 30L,
    top_n_volcano_labels = 15L,
    fdr_threshold        = 0.05,
    palette              = "viridis",
    language             = "en",
    heatmap_normalize    = TRUE,
    go_enrichment        = TRUE,
    save_svg             = TRUE,
    dpi                  = 300L,
    min_genes_for_go_ora = 200L,
    max_heatmap_samples  = 100L
  )
}
