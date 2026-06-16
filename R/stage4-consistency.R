# Helper per la metrica di consistenza cross-studio dei cluster Stadio 4 (F6 Fase A,
# ADR-0021). Asse unico [0,1]: mega = 1 - VPC(study); rem = 1 - I2 (+ prediction
# interval); mega_aug k=2 = sign-concordance. Sempre sui geni FDR-significativi.
# Spec: docs/superpowers/specs/2026-06-15-f6-reproducibility-consistency-metric-design.md

#' Riassume una metrica per-gene (VPC_study o I2) sui soli geni FDR-significativi
#'
#' @param values metrica per-gene (numeric).
#' @param fdr FDR per-gene (stessa lunghezza).
#' @param threshold soglia FDR (default 0.05).
#' @return list(median, iqr, n_used). median/iqr = NA se nessun gene sig non-NA.
#' @keywords internal
.summarize_consistency_over_sig <- function(values, fdr, threshold = 0.05) {
  stopifnot(length(values) == length(fdr))
  sig <- !is.na(fdr) & fdr < threshold & !is.na(values)
  if (!any(sig)) return(list(median = NA_real_, iqr = NA_real_, n_used = 0L))
  v <- values[sig]
  list(median = stats::median(v), iqr = stats::IQR(v), n_used = length(v))
}

#' Prediction interval 95% per-gene da logFC/SE per-studio (metafor REML + HKSJ)
#'
#' Risponde a "un nuovo studio replichera' l'effetto?" (IntHout 2016). Usa REML
#' per tau2 (Veroniki 2016) + correzione HKSJ (test="knha", IntHout 2014) per
#' l'inferenza. Fallback Paule-Mandel su non-convergenza REML.
#'
#' @param logFC,SE vettori per-studio (un gene).
#' @param level percentuale del PI (default 95).
#' @return list(pi_lower, pi_upper, tau2, excl0). NA se < 2 studi o non-convergenza.
#'   excl0 = TRUE se il PI 95% sta tutto da un lato di 0.
#' @keywords internal
.rem_prediction_interval <- function(logFC, SE, level = 95) {
  ok <- is.finite(logFC) & is.finite(SE) & SE > 0
  yi <- logFC[ok]; sei <- SE[ok]
  na <- list(pi_lower = NA_real_, pi_upper = NA_real_, tau2 = NA_real_, excl0 = NA)
  if (length(yi) < 2L) return(na)
  fit <- tryCatch(
    metafor::rma(yi = yi, sei = sei, method = "REML", test = "knha"),
    error = function(e) tryCatch(
      metafor::rma(yi = yi, sei = sei, method = "PM", test = "knha"),
      error = function(e2) NULL))
  if (is.null(fit)) return(na)
  pr <- tryCatch(stats::predict(fit, level = level), error = function(e) NULL)
  if (is.null(pr) || is.null(pr$pi.lb)) return(na)
  pil <- pr$pi.lb; piu <- pr$pi.ub
  list(pi_lower = pil, pi_upper = piu, tau2 = fit$tau2,
       excl0 = is.finite(pil) && is.finite(piu) && (pil > 0 || piu < 0))
}
