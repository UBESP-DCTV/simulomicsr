#!/usr/bin/env Rscript
# Numeri derivati per il finding: successi minimi con la soglia effettiva, differenza appaiata contro Tahoe, verifica dei conteggi.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
V <- fread(file.path(E7, "70-verdetto.csv"))
minx <- function(n, T) { for (x in 0:n) if (cp_lim(x, n, "lo") > T) return(x); NA_integer_ }
for (i in 1:2) cat(V$insieme[i], ": T_eff", round(V$T_eff[i], 4), "; successi minimi", minx(V$n[i], V$T_eff[i]), "; con T = 17%:", minx(V$n[i], .17), "; limite inferiore", round(V$H_lo[i], 4), "\n")
tr <- fread(file.path(E7, "74-triangolo-per-composto.csv"))
set.seed(SEME); d <- replicate(BOOT, { i <- sample(nrow(tr), replace = TRUE); mean(tr$P_L_a_T[i] >= .9) - mean(tr$P_T[i] >= .9) })
cat("L1000 contro Tahoe meno stime contro Tahoe, stessi 32 composti:", round(mean(tr$P_L_a_T >= .9) - mean(tr$P_T >= .9), 3), "IC95", round(quantile(d, c(.025, .975)), 3), "\n")
set.seed(SEME); d2 <- replicate(BOOT, { i <- sample(nrow(tr), replace = TRUE); mean(tr$P_L1000[i] >= .9) - mean(tr$P_T[i] >= .9) })
cat("stime contro L1000 meno stime contro Tahoe:", round(mean(tr$P_L1000 >= .9) - mean(tr$P_T >= .9), 3), "IC95", round(quantile(d2, c(.025, .975)), 3), "\n")
cat("successi del caso contro Tahoe, 11 su 32: IC95", round(cp_lim(11L, 32L, "lo"), 3), round(cp_lim(11L, 32L, "hi"), 3), "\n")
P <- fread(file.path(E7, "70-P-per-metanalisi.csv")); cat("righe:", nrow(P), "; successi:", P[insieme == "40", sum(successo)], P[insieme == "132", sum(successo)], "; sotto 0,10:", P[insieme %in% c("40","132") & P < .10, nome], "\n")
cat("fuori dai due insiemi:", P[insieme == "fuori", sum(successo)], "su", P[insieme == "fuori", .N], "\n")
L <- fread(file.path(E7, "71-ligandi.csv")); cat("ligandi nel primo 10%:", sum(L$P >= .9), "su", nrow(L), "; nelle 40:", L[insieme == "40", sum(P >= .9)], "su", L[insieme == "40", .N], "\n")
