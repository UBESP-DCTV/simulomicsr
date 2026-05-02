#' Legge il TSV di fixture sample mini bundled nel pacchetto
#'
#' Per test e vignette: 8 sample stratificati estratti dal xlsx
#' (script in `data-raw/build-sample-fixtures-mini.R`).
#'
#' @return tibble con colonne `geo_accession`, `series_id`, `string`,
#'   `trtctr_EP`, `trtctr`, `treat`, `gold`, `stratum`
#' @keywords internal
read_sample_fixtures_mini <- function() {
  path <- system.file("extdata/sample-fixtures-mini.tsv",
                      package = "simulomicsr")
  if (!nzchar(path) || !fs::file_exists(path)) {
    rlang::abort(
      "Fixture sample-fixtures-mini.tsv non trovato. Run data-raw/build-sample-fixtures-mini.R",
      class = "simulomicsr_fixtures_missing"
    )
  }
  readr::read_tsv(
    path,
    show_col_types = FALSE,
    progress = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
}
