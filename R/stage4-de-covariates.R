#' Helper interni: covariate batch nel design DE (FASE E3 ADR-0019 D8)
#'
#' Implementa la decisione utente per il rebuild Stadio 4 v2: il design
#' lineare DE per-studio (limma-voom) + cross-study mega (dream) ora
#' include covariate tecniche batch (\code{instrument_model} +
#' \code{aligner_class} di default) oltre a treatment + study(random
#' per dream).
#'
#' Edge case gestiti (paper-grade):
#' \itemize{
#'   \item Covariata \strong{single-level} (es. cluster con un solo
#'     valore distinto) -> drop con warning. Aggiungerla al design
#'     renderebbe la model matrix rank-deficient.
#'   \item Covariata \strong{missing} dal metadata input (es.
#'     h5_metadata pre-E3 senza il campo) -> skip + warning.
#'   \item \strong{NA partial} nella covariata -> convertita a livello
#'     factor \code{"unknown"} (preserva sample, evita drop silenzioso).
#'   \item Covariates \code{NULL} / \code{character(0)} -> no-op,
#'     design treatment-only.
#' }
#'
#' I drop/skip sono registrati nel \code{drop_log} ritornato per
#' propagazione al \code{qc_report$pooling_warnings} (tracciabilita'
#' paper-grade).
#'
#' @keywords internal
NULL

#' Aggiunge covariate batch al design DE con gestione edge case
#'
#' @param metadata data.frame sample-level (deve contenere
#'   \code{sample_id} + \code{treatment} + le covariate richieste).
#' @param covariates character vector di nomi covariate da includere
#'   (es. \code{c("instrument_model", "aligner_class")}). NULL o
#'   character(0) = no-op.
#' @param cluster_id chr ID del cluster per logging diagnostico.
#' @return list con:
#'   \describe{
#'     \item{\code{formula_terms}}{stringa formula da concatenare a
#'       \code{~ treatment} (es. "instrument_model + aligner_class")
#'       o "" se nessuna covariata aggiunta.}
#'     \item{\code{metadata_aug}}{metadata con le covariate convertite
#'       a factor (NA -> 'unknown' come livello).}
#'     \item{\code{covariates_used}}{character vector covariate
#'       effettivamente aggiunte al design.}
#'     \item{\code{covariates_dropped}}{character vector droppate (per
#'       qualunque causa).}
#'     \item{\code{drop_log}}{tibble \code{(cluster_id, covariate,
#'       reason, detail)} per propagazione a qc_report.}
#'   }
#' @keywords internal
.augment_de_design <- function(metadata, covariates, cluster_id) {
  empty_log <- tibble::tibble(
    cluster_id = character(0),
    covariate  = character(0),
    reason     = character(0),
    detail     = character(0)
  )

  if (is.null(covariates) || length(covariates) == 0L) {
    return(list(
      formula_terms      = "",
      metadata_aug       = metadata,
      covariates_used    = character(0),
      covariates_dropped = character(0),
      drop_log           = empty_log
    ))
  }

  used   <- character(0)
  dropped <- character(0)
  log_rows <- list()
  meta_aug <- metadata

  for (cov in covariates) {
    # 1. Missing dal metadata -> skip + warning + log
    if (!cov %in% names(metadata)) {
      warning(sprintf(
        "cluster %s: covariata '%s' richiesta ma assente dal metadata input -> skip",
        cluster_id, cov
      ), call. = FALSE)
      dropped <- c(dropped, cov)
      log_rows[[length(log_rows) + 1L]] <- tibble::tibble(
        cluster_id = cluster_id,
        covariate  = cov,
        reason     = "missing_from_metadata",
        detail     = sprintf("colonna '%s' assente da metadata", cov)
      )
      next
    }

    # 2. NA partial -> 'unknown' livello (preserva sample)
    col_chr <- as.character(metadata[[cov]])
    n_na <- sum(is.na(col_chr))
    if (n_na > 0L) {
      col_chr[is.na(col_chr)] <- "unknown"
    }
    levs <- unique(col_chr)

    # 3. Single-level -> drop (rank-deficient se aggiunto al design)
    if (length(levs) < 2L) {
      warning(sprintf(
        "cluster %s: covariata '%s' single-level ('%s') -> drop (rank-deficient)",
        cluster_id, cov, levs[1L]
      ), call. = FALSE)
      dropped <- c(dropped, cov)
      log_rows[[length(log_rows) + 1L]] <- tibble::tibble(
        cluster_id = cluster_id,
        covariate  = cov,
        reason     = "single_level",
        detail     = sprintf("solo 1 livello '%s' su %d sample",
                              levs[1L], length(col_chr))
      )
      next
    }

    # 4. Multi-level -> kept, factor con NA-as-'unknown'
    meta_aug[[cov]] <- factor(col_chr)
    used <- c(used, cov)
  }

  drop_log <- if (length(log_rows) > 0L) {
    dplyr::bind_rows(log_rows)
  } else empty_log

  formula_terms <- if (length(used) == 0L) "" else paste(used, collapse = " + ")

  list(
    formula_terms      = formula_terms,
    metadata_aug       = meta_aug,
    covariates_used    = used,
    covariates_dropped = dropped,
    drop_log           = drop_log
  )
}
