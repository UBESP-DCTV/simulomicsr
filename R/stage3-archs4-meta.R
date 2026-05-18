#' Carica ARCHS4 metadata (sample_id, series_id, gpl) da H5
#'
#' Legge i field necessari da \code{/meta/samples/} dell'H5 ARCHS4 v2.5 e li
#' restituisce come tibble. Costoso (H5 da 47GB), supporta cache via RDS
#' in \code{tools::R_user_dir("simulomicsr", "cache")}.
#'
#' Nota schema ARCHS4 v2.5 (verificato su human_gene_v2.5.h5):
#' \itemize{
#'   \item Il campo GPL (\code{gpl}) mappa a \code{meta/samples/platform_id}
#'     (es. "GPL15433"), NON a \code{meta/samples/instrument_model} che
#'     contiene il modello del sequenziatore (es. "Illumina HiSeq 1000").
#'   \item \code{library_strategy} e' disponibile in v2.5 ma non viene
#'     restituito da questa funzione (necessario solo per ETL stage1).
#' }
#'
#' @param h5_path string path al file H5 ARCHS4 (es.
#'   \code{"analysis/input/human_gene_v2.5.h5"}).
#' @param cache_dir directory di cache opzionale. Default:
#'   \code{tools::R_user_dir("simulomicsr", "cache")}.
#' @param use_cache logical, default \code{TRUE}. Se \code{FALSE} salta
#'   lettura e scrittura cache.
#' @return Tibble con colonne \code{sample_id}, \code{series_id}, \code{gpl}.
#' @export
load_archs4_metadata <- function(h5_path,
                                  cache_dir = NULL,
                                  use_cache = TRUE) {
  stopifnot(file.exists(h5_path))

  if (is.null(cache_dir)) {
    cache_dir <- tools::R_user_dir("simulomicsr", which = "cache")
  }
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  # Chiave cache: path + mtime per invalidazione automatica
  cache_key  <- digest::digest(
    list(h5_path = normalizePath(h5_path),
         mtime   = file.info(h5_path)$mtime),
    algo = "xxhash32"
  )
  cache_file <- file.path(cache_dir,
                           sprintf("archs4-metadata-%s.rds", cache_key))

  if (use_cache && file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  # Lettura diretta H5: platform_id contiene l'accession GPL (es. "GPL15433")
  sample_id <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
  series_id <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
  gpl       <- as.character(rhdf5::h5read(h5_path, "meta/samples/platform_id"))
  rhdf5::H5close()

  meta <- tibble::tibble(
    sample_id = sample_id,
    series_id = series_id,
    gpl       = gpl
  )

  if (use_cache) {
    saveRDS(meta, cache_file)
  }

  meta
}
