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

#' Sign-concordance dei logFC di 2 studi sui geni sig (proxy consistenza k=2)
#'
#' Per i cluster mega_aug (k=2) l'eterogeneita' non e' stimabile: la frazione di
#' geni sig su cui i 2 studi concordano nella direzione del logFC e' il proxy di
#' riproducibilita' raccomandato a k basso. logFC 0/NA esclusi dal denominatore.
#'
#' @param logFC_a,logFC_b logFC per-gene dei 2 studi (stessa lunghezza/ordine geni).
#' @param sig_mask logical, gene FDR-significativo nel pooled (stessa lunghezza).
#' @return list(concordance, n_used). concordance = NA se nessun gene usabile.
#' @keywords internal
.sign_concordance <- function(logFC_a, logFC_b, sig_mask) {
  stopifnot(length(logFC_a) == length(logFC_b), length(sig_mask) == length(logFC_a))
  use <- sig_mask & is.finite(logFC_a) & is.finite(logFC_b) &
         logFC_a != 0 & logFC_b != 0
  if (!any(use)) return(list(concordance = NA_real_, n_used = 0L))
  agree <- sign(logFC_a[use]) == sign(logFC_b[use])
  list(concordance = mean(agree), n_used = sum(use))
}

#' Asse unico di consistenza (scala 0-1) per metodo
#'
#' mega/rem: 1 - frazione varianza between-study (VPC_study mediano / I2 mediano).
#' mega_aug: sign_concordance. NA se la componente rilevante e' NA. Clamp a 0-1.
#'
#' @param method "mega" | "rem" | "mega_aug".
#' @param median_heterogeneity mediana VPC_study (mega) o I2 (rem) sui geni sig.
#' @param sign_concordance frazione direzione-concorde (mega_aug).
#' @return numeric scalare nella scala 0-1, o NA.
#' @keywords internal
.consistency_score <- function(method, median_heterogeneity = NA_real_,
                               sign_concordance = NA_real_) {
  s <- switch(method,
    mega     = 1 - median_heterogeneity,
    rem      = 1 - median_heterogeneity,
    mega_aug = sign_concordance,
    NA_real_)
  if (length(s) != 1L || is.na(s)) return(NA_real_)
  max(0, min(1, s))
}
