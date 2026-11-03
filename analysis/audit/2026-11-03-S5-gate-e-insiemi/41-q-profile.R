# analysis/audit/2026-11-03-S5-gate-e-insiemi/41-q-profile.R
# Intervallo Q-profile e Knapp-Hartung vettoriali. Y e V: matrici geni x studi, NA se manca.
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
q_stat <- function(Y0, V, oss, tau2) {
  W <- oss / (V + tau2); W[!oss] <- 0
  sw <- rowSums(W); mu <- rowSums(W * Y0) / sw
  rowSums(W * (Y0 - mu)^2)
}
risolvi <- function(Y0, V, oss, target) {
  # Q decresce in tau2: bisezione geometrica sugli indici dove la radice esiste
  n <- nrow(Y0); ris <- numeric(n)
  Q0 <- q_stat(Y0, V, oss, 0)
  da <- which(is.finite(target) & Q0 > target)
  ris[!is.finite(target)] <- NA_real_
  if (!length(da)) return(ris)
  lo <- rep(0, length(da)); hi <- rep(1, length(da))
  y <- Y0[da, , drop = FALSE]; v <- V[da, , drop = FALSE]; o <- oss[da, , drop = FALSE]; tg <- target[da]
  for (it in 1:60) { su <- q_stat(y, v, o, hi) > tg; if (!any(su)) break; hi[su] <- hi[su] * 4 }
  for (it in 1:80) {
    me <- (lo + hi) / 2
    su <- q_stat(y, v, o, me) > tg
    lo[su] <- me[su]; hi[!su] <- me[!su]
  }
  ris[da] <- (lo + hi) / 2
  ris
}
q_profile <- function(Y, V, livello = 0.95) {
  oss <- is.finite(Y) & is.finite(V) & V > 0
  Y0 <- Y; Y0[!oss] <- 0; V0 <- V; V0[!oss] <- 1
  k <- rowSums(oss); a <- 1 - livello
  bersaglio_lo <- ifelse(k >= 2L, stats::qchisq(1 - a / 2, pmax(k - 1L, 1L)), NA_real_)
  bersaglio_hi <- ifelse(k >= 2L, stats::qchisq(a / 2, pmax(k - 1L, 1L)), NA_real_)
  t_lo <- risolvi(Y0, V0, oss, bersaglio_lo); t_hi <- risolvi(Y0, V0, oss, bersaglio_hi)
  # varianza tipica di metafor: (k-1) / (somma w - somma w^2 / somma w), con w = 1/v
  w <- oss / V0; w[!oss] <- 0
  sw <- rowSums(w); vt <- (k - 1L) / (sw - rowSums(w^2) / sw)
  list(tau2_lo = t_lo, tau2_hi = t_hi, I2_lo = 100 * t_lo / (t_lo + vt), I2_hi = 100 * t_hi / (t_hi + vt), vt = vt, k = k)
}
knapp_hartung <- function(Y, V, tau2) {
  oss <- is.finite(Y) & is.finite(V) & V > 0
  Y0 <- Y; Y0[!oss] <- 0; V0 <- V; V0[!oss] <- 1
  W <- oss / (V0 + tau2); W[!oss] <- 0
  sw <- rowSums(W); mu <- rowSums(W * Y0) / sw; k <- rowSums(oss)
  s2 <- rowSums(W * (Y0 - mu)^2) / ((k - 1L) * sw)
  list(mu = mu, se = sqrt(s2), p = 2 * stats::pt(abs(mu) / sqrt(s2), pmax(k - 1L, 1L), lower.tail = FALSE))
}
