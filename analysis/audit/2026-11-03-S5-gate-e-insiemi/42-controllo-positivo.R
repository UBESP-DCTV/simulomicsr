#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/42-controllo-positivo.R
# Cancello 5. (a) Gli estremi di tau2 e I2 coincidono con metafor::confint su 2.000 geni per k in {2,3,4}.
# (b) A k=2, su 20.000 geni simulati con tau2 noto, l'intervallo contiene il valore vero fra il 93% e il 97%.
# Uso: WORKERS=48 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/42-controllo-positivo.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/41-q-profile.R")
library(parallel)
tab <- fread(file.path(OUT5, "40-per-gruppo.csv"))
DIRS <- c("194" = "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio", "k2" = file.path(PES5, "studio-k2"))
prendi <- function(k_voluto, n = 2000L) {
  gg <- if (k_voluto == 2L) tab[fonte == "k2"] else tab[fonte == "194" & k == k_voluto]
  righe <- list()
  for (i in sample(nrow(gg))) {
    st <- readRDS(file.path(DIRS[[gg$fonte[i]]], paste0(gg$cluster_id[i], ".rds")))[is.finite(d0) & is.finite(se1)]
    pie <- st[, .N, by = gene_id][N == k_voluto]
    righe[[length(righe) + 1L]] <- st[gene_id %in% sample(pie$gene_id, min(50L, nrow(pie))), .(cluster_id, gene_id, study_id, d0, se1)]
    if (sum(lengths(lapply(righe, function(z) unique(paste(z$cluster_id, z$gene_id))))) >= n) break
  }
  rbindlist(righe)
}
set.seed(SEME)
for (kk in 2:4) {
  x <- prendi(kk)
  chiavi <- unique(x[, .(cluster_id, gene_id)]); chiavi <- chiavi[seq_len(min(.N, 2000L))]
  x <- x[chiavi, on = .(cluster_id, gene_id)]
  ris <- rbindlist(mclapply(seq_len(nrow(chiavi)), function(i) {
    z <- x[cluster_id == chiavi$cluster_id[i] & gene_id == chiavi$gene_id[i]]
    Y <- matrix(z$d0, 1L); V <- matrix(z$se1^2, 1L)
    q <- q_profile(Y, V)
    f <- tryCatch(metafor::rma(yi = z$d0, sei = z$se1, method = "REML"), error = function(e) NULL, warning = function(w) NULL)
    if (is.null(f)) return(NULL)
    ci <- tryCatch(suppressWarnings(metafor::confint.rma.uni(f, control = list(tau2.max = 1e7)))$random, error = function(e) NULL)
    if (is.null(ci)) return(NULL)
    data.table(t_lo = q$tau2_lo, t_hi = q$tau2_hi, m_lo = ci["tau^2", "ci.lb"], m_hi = ci["tau^2", "ci.ub"], i_lo = q$I2_lo, i_hi = q$I2_hi, mi_lo = ci["I^2(%)", "ci.lb"], mi_hi = ci["I^2(%)", "ci.ub"])
  }, mc.cores = WORKERS))
  rel <- function(a, b) { ok <- b > 1e-6; if (any(ok)) max(abs(a[ok] - b[ok]) / b[ok]) else 0 }
  cat(sprintf("k=%d: geni %d | scarto relativo massimo tau2 lo %.2g, hi %.2g | scarto assoluto massimo I2 lo %.2g, hi %.2g | estremi hi positivi %d\n",
              kk, nrow(ris), rel(ris$t_lo, ris$m_lo), rel(ris$t_hi, ris$m_hi), max(abs(ris$i_lo - ris$mi_lo)), max(abs(ris$i_hi - ris$mi_hi)), sum(ris$m_hi > 1e-6)))
}
# (b) simulazione: errori standard tratti da un gruppo vero a k=2
g <- tab[fonte == "k2"][order(-n_geni)][1L]
st <- readRDS(file.path(DIRS[["k2"]], paste0(g$cluster_id, ".rds")))[is.finite(se1)]
w <- dcast(st, gene_id ~ study_id, value.var = "se1"); w <- as.matrix(w[, -1L]); w <- w[stats::complete.cases(w), , drop = FALSE]
set.seed(SEME)
for (t2 in c(0.03, 0.1, 0.5)) {
  S <- w[sample(nrow(w), 20000L, replace = TRUE), ]
  Y <- matrix(stats::rnorm(40000L, 0, sqrt(as.vector(S)^2 + t2)), ncol = 2L)
  q <- q_profile(Y, S^2)
  cat(sprintf("simulazione k=2, tau2=%.2f: copertura %.2f%% | estremo inferiore 0 nel %.1f%% | ampiezza mediana di I2 %.1f punti\n",
              t2, 100 * mean(q$tau2_lo <= t2 & q$tau2_hi >= t2), 100 * mean(q$tau2_lo == 0), median(q$I2_hi - q$I2_lo)))
}
