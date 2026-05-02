#' Legge il xlsx classificato in un tibble normalizzato
#'
#' Le colonne attese sono quelle documentate in `data-raw/README.md`.
#' Tutto viene letto come `character` (stabile), il caller converte se serve.
#'
#' @param path path al file xlsx
#' @param n_max numero massimo di righe da leggere (default `Inf`)
#' @return tibble con colonne `geo_accession`, `series_id`, `string`,
#'   `trtctr_EP`, `trtctr`, `treat`, `gold`
#' @keywords internal
read_samples_input <- function(path, n_max = Inf) {
  if (!fs::file_exists(path)) {
    rlang::abort(
      glue::glue("File non trovato: {path}"),
      class = "simulomicsr_eval_sampling_missing_file",
      path = path
    )
  }

  df <- readxl::read_excel(path, n_max = n_max)
  required <- c("geo_accession", "series_id", "string",
                "trtctr_EP", "trtctr", "treat", "gold")
  missing  <- setdiff(required, names(df))
  if (length(missing) > 0L) {
    rlang::abort(
      glue::glue("xlsx manca colonne attese: {paste(missing, collapse = ', ')}"),
      class = "simulomicsr_eval_sampling_bad_schema",
      missing = missing
    )
  }

  tibble::tibble(
    geo_accession = as.character(df$geo_accession),
    series_id     = as.character(df$series_id),
    string        = as.character(df$string),
    trtctr_EP     = as.character(df$trtctr_EP),
    trtctr        = as.character(df$trtctr),
    treat         = as.character(df$treat),
    gold          = as.character(df$gold)
  )
}
