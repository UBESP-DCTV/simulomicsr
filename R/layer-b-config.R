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
#'   \item{top_genes_min_k_frac}{`numeric(1)` --- frazione minima del `k` del cluster perche' un gene entri nella top-gene table e nella heatmap (default 0.5). Con k basso il random-effects stima tau^2 = 0, l'errore standard collassa e geni misurati in due studi finiscono in cima all'ordinamento per FDR: misurato sui bundle v13 il 2026-07-31. 0 disattiva il filtro.}
#'   \item{heatmap_mostra_studi}{`logical(1)` --- annotare le colonne della heatmap anche per `study_id` (default FALSE). Su TGF-beta1 la fascia "Study" e' 47 colori indistinguibili e la legenda che li spiega occupa un terzo della figura (misurato il 2026-08-05): di default resta solo l'annotazione Treatment (trattato/controllo), che e' cio' che la figura deve mostrare. TRUE ripristina anche Study, per chi la vuole comunque.}
#'   \item{figure_escluse}{`character()` --- nomi delle figure da NON generare nel bundle (default `c("ma", "heterogeneity")`). E' una SELEZIONE, non una cancellazione: il codice di `.build_ma_plot()`/`.build_heterogeneity_panel()` resta nel pacchetto (stessa decisione gia' presa per il ramo `mega` in ADR-0026) -- togliere un nome dal vettore lo riattiva.}
#'   \item{volcano_quota_asse}{`numeric(1)` --- soglia usata da `.volcano_soglia_asse()`: se il 99-esimo percentile dei punti copre meno di questa frazione del massimo, l'asse verticale del volcano viene compresso in modo dichiarato (default 0.6, lo stesso valore gia' usato come default della funzione).}
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
    max_heatmap_samples  = 100L,
    top_genes_min_k_frac = 0.5,
    heatmap_mostra_studi = FALSE,
    figure_escluse       = c("ma", "heterogeneity"),
    volcano_quota_asse   = 0.6
  )
}
