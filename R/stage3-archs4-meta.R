#' Carica ARCHS4 metadata (sample_id, series_id, gpl, biosample_id) da H5
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
#'   \item Il campo \code{biosample_id} (FASE E0 ADR-0019 D9) e' parsato
#'     da \code{meta/samples/relation} via \code{parse_biosample_id()}.
#'     Coverage attesa ~99.98% sul dataset rescued (A7).
#' }
#'
#' Cache key versionata: il prefisso schema \code{v2_biosample} invalida
#' automaticamente i file cache pre-E0 (senza colonna biosample_id).
#'
#' @param h5_path string path al file H5 ARCHS4 (es.
#'   \code{"analysis/input/human_gene_v2.5.h5"}).
#' @param cache_dir directory di cache opzionale. Default:
#'   \code{tools::R_user_dir("simulomicsr", "cache")}.
#' @param use_cache logical, default \code{TRUE}. Se \code{FALSE} salta
#'   lettura e scrittura cache.
#' @return Tibble con colonne \code{sample_id}, \code{series_id},
#'   \code{gpl}, \code{biosample_id}.
#' @export
load_archs4_metadata <- function(h5_path,
                                  cache_dir = NULL,
                                  use_cache = TRUE) {
  stopifnot(file.exists(h5_path))

  if (is.null(cache_dir)) {
    cache_dir <- tools::R_user_dir("simulomicsr", which = "cache")
  }
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  # Chiave cache: path + mtime + schema_version. La componente schema_version
  # invalida cache pre-E0 (schema senza biosample_id) e impedisce
  # silent corruption se la struttura cambia in futuro.
  cache_key  <- digest::digest(
    list(h5_path        = normalizePath(h5_path),
         mtime          = file.info(h5_path)$mtime,
         schema_version = "v2_biosample"),
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

  # FASE E0 ADR-0019 D9: parse BioSample SAMN da meta/samples/relation.
  # Fallback graceful se il dataset non esiste (H5 legacy / non-ARCHS4):
  # biosample_id ritorna vector di NA della stessa lunghezza di sample_id.
  relation <- tryCatch(
    as.character(rhdf5::h5read(h5_path, "meta/samples/relation")),
    error = function(e) rep(NA_character_, length(sample_id))
  )
  # parse_biosample_id() definita in R/etl-archs4-utils.R, regex SAMN\d+.
  biosample_id <- parse_biosample_id(relation)

  rhdf5::H5close()

  meta <- tibble::tibble(
    sample_id    = sample_id,
    series_id    = series_id,
    gpl          = gpl,
    biosample_id = biosample_id
  )

  if (use_cache) {
    saveRDS(meta, cache_file)
  }

  meta
}
