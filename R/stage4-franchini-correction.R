#' Verifica se almeno un baseline_pool_id e' condiviso tra contrasti
#'
#' \code{NA} non e' considerato condiviso con se' stesso (i contrasti
#' senza augmentation hanno \code{pool_id = NA} e restano indipendenti).
#'
#' @param pool_ids character: \code{baseline_pool_id} per ciascun
#'   contrasto. \code{NA} ammessi.
#' @return logical(1).
#' @keywords internal
.has_shared_baseline <- function(pool_ids) {
  non_na <- pool_ids[!is.na(pool_ids)]
  if (length(non_na) <= 1L) return(FALSE)
  any(duplicated(non_na))
}

#' Costruisce la matrice V di covarianza Franchini 2012 per shared baseline
#'
#' Approssimazione block-correlation. Per ogni coppia di contrasti
#' \code{(i, j)} che condividono lo stesso \code{baseline_pool_id} (non NA),
#' la covarianza off-diagonal e' \code{rho * sqrt(vi * vj)}. Altrimenti
#' \code{V[i, j] = 0}. Diagonale = \code{vi}.
#'
#' Razionale (vedi findings sez. 4 Nodo 3 + 7): Franchini 2012 derivano
#' la matrice di covarianza esatta a partire dalle component variances
#' (within-arm SS). Dream non espone direttamente le component variances
#' del baseline pool, quindi qui approssimiamo con un correlation factor
#' \code{rho} unico (default 0.5, configurabile via
#' \code{config$mega_aug$franchini_rho}). E' un'approssimazione conservativa
#' che evita gli SE sottostimati del naive pooling REM ma sottostima a sua
#' volta la potenza statistica reale.
#'
#' Sensitivity reportata: il pipeline produce un secondo run con
#' \code{config$mega_aug$franchini_correction = FALSE} (no correction),
#' e il diff in SE / p-value e' incluso nei Results 6.4 del findings.
#'
#' @param yi numeric: effect-size per contrasto. NON usato dalla formula
#'   (solo passato per coerenza signature \code{metafor::rma.mv}).
#' @param vi numeric: sampling variance per contrasto (output dream).
#' @param baseline_pool_ids character: \code{baseline_pool_id} per ciascun
#'   contrasto, \code{NA} per contrasti non augmentati.
#' @param rho numeric(1) in (0, 1): correlation factor. Default 0.5.
#' @return matrice quadrata \code{length(vi) x length(vi)}.
#' @keywords internal
.build_franchini_V_matrix <- function(yi, vi, baseline_pool_ids, rho = 0.5) {
  n <- length(vi)
  if (length(yi) != n || length(baseline_pool_ids) != n) {
    stop("yi, vi e baseline_pool_ids devono avere stesso numero di elementi")
  }
  stopifnot(length(rho) == 1L, rho >= 0, rho < 1)

  V <- diag(vi, nrow = n)
  if (n < 2L) return(V)
  if (rho == 0) return(V)

  for (i in seq_len(n - 1L)) {
    pi <- baseline_pool_ids[i]
    if (is.na(pi)) next
    for (j in (i + 1L):n) {
      pj <- baseline_pool_ids[j]
      if (is.na(pj) || pi != pj) next
      cov_ij <- rho * sqrt(vi[i] * vi[j])
      V[i, j] <- cov_ij
      V[j, i] <- cov_ij
    }
  }
  V
}
