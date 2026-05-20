#' Default configuration per Stadio 4 DE per-studio + MEGA cross-study production
#'
#' Restituisce la configurazione di default che governa Stage 4: QC sample-level
#' (lib_size threshold), DE engine choice (limma-voom REM + dream MEGA),
#' pooling method (REML con DL fallback per REM), parallelism (workers offset),
#' versioning schema per riproducibilita'.
#'
#' @return list con 5 componenti: \code{qc}, \code{de_engine}, \code{pooling},
#'   \code{compute}, \code{schema_versions}.
#' @seealso \code{\link{build_stage4_results}}, ADR-0015.
#' @export
stage4_default_config <- function() {
  list(
    qc = list(
      lib_size_min = 500000L
    ),
    de_engine = list(
      rem      = "limma-voom+eBayes",
      mega     = "dream",
      mega_aug = "dream"
    ),
    pooling = list(
      rem_method   = "REML",
      rem_fallback = "DL",
      fdr          = "BH_within_cluster"
    ),
    compute = list(
      workers_offset   = 10L,
      dream_workers_cap = 100L,
      dream_workers    = NA_integer_  # NA = auto-detect (availableCores -
                                       # workers_offset, capped a
                                       # dream_workers_cap). Vedi
                                       # .resolve_dream_workers + ADR-0015.
    ),
    schema_versions = list(
      anchor             = "v3",
      stage3_algorithm   = "v1",
      stage4_algorithm   = "v1"
    )
  )
}

#' Risolve il numero di worker BiocParallel da config (auto-detect se NA)
#'
#' Logica:
#' \itemize{
#'   \item Se \code{config$compute$dream_workers} e' un integer, usa quello
#'         (cap a \code{dream_workers_cap}).
#'   \item Se \code{NA} (default), auto-detect via
#'         \code{parallelly::availableCores() - workers_offset}, cap a
#'         \code{dream_workers_cap}, floor a 1.
#' }
#'
#' @param config output di \code{stage4_default_config()}.
#' @return integer numero di worker per \code{BiocParallel::MulticoreParam}.
#' @keywords internal
.resolve_dream_workers <- function(config) {
  cap <- as.integer(config$compute$dream_workers_cap %||% 100L)
  w   <- config$compute$dream_workers
  if (is.null(w) || (length(w) == 1L && is.na(w))) {
    offset <- as.integer(config$compute$workers_offset %||% 10L)
    cores  <- if (requireNamespace("parallelly", quietly = TRUE)) {
      parallelly::availableCores()
    } else {
      parallel::detectCores(logical = TRUE)
    }
    w <- max(1L, as.integer(cores) - offset)
  }
  w <- as.integer(w)
  min(w, cap)
}
