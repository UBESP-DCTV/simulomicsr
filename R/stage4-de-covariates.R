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

  # T6a Fix C1 (Codex review paper-grade): pre-fit rank check del design
  # ~ treatment + <covariates>. Se model.matrix produce design singolare
  # (rank < ncol), una o piu' covariate sono confounded con treatment
  # (es. tutti i treated su HiSeq, tutti i control su NovaSeq) -> il fit
  # produrra' coefficient NA per il termine aliasato, e il tryCatch
  # downstream catturerebbe solo l'errore generico senza distinguere
  # confound strutturale da rank deficiency campionaria.
  #
  # Approccio robust-first: se design rank-deficient, drop TUTTE le
  # covariate kept (conservativo) + log strutturato. Meglio fit
  # treatment-only che modello singolare con coef silenziosi.
  # In presenza di treatment factor con 2 livelli garantiti
  # (constraint del caller), design '~ treatment' senza covariate ha
  # sempre rank pieno (intercept + treatmenttreated, rank=2).
  if (length(used) > 0L && "treatment" %in% names(meta_aug)) {
    test_formula <- stats::as.formula(
      paste("~ treatment +", paste(used, collapse = " + "))
    )
    test_mm <- tryCatch(
      stats::model.matrix(test_formula, data = meta_aug),
      error = function(e) NULL
    )
    if (!is.null(test_mm) && qr(test_mm)$rank < ncol(test_mm)) {
      warning(sprintf(
        "cluster %s: design ~ treatment + %s e' rank-deficient (covariate confounded col treatment) -> drop covariate, fit treatment-only",
        cluster_id, paste(used, collapse = " + ")
      ), call. = FALSE)
      for (cov_drop in used) {
        log_rows[[length(log_rows) + 1L]] <- tibble::tibble(
          cluster_id = cluster_id,
          covariate  = cov_drop,
          reason     = "non_estimable_confounded_with_treatment",
          detail     = sprintf("design ~treatment+%s rank %d/%d",
                                paste(used, collapse = "+"),
                                qr(test_mm)$rank, ncol(test_mm))
        )
      }
      dropped <- c(dropped, used)
      used <- character(0)
      # Rimuovi colonne covariate da metadata_aug per coerenza
      for (cov_drop in dropped[dropped != ""]) {
        if (cov_drop %in% names(meta_aug) && cov_drop != "treatment") {
          # mantengo come char vec (no factor) - tanto non sara' nel design
          meta_aug[[cov_drop]] <- as.character(meta_aug[[cov_drop]])
        }
      }
    }
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
