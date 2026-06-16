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
