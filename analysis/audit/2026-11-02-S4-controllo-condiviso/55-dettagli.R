#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/55-dettagli.R
# I numeri del finding che 50-efficacia-e-setaccio.R non stampa, da 50-per-gruppo.csv e 50-per-coppia.csv.
suppressPackageStartupMessages(library(data.table))
OUT <- "analysis/audit/2026-11-02-S4-controllo-condiviso"
tab <- fread(file.path(OUT, "50-per-gruppo.csv")); rap <- fread(file.path(OUT, "50-per-coppia.csv"))
tab[, dq := q1 - q0][, dp := qp - q0][, rs := (sig1 - sig0) / sig0][, rs3 := (sig3 - sig0) / sig0]
d <- tab[toccato == TRUE & sig0 > 0]
cat(sprintf("gruppi toccati con geni significativi: %d\n", nrow(d)))
cat("variazione relativa di n_sig con T1, quantili 0, 5, 25, 50, 75, 95, 100%:\n"); print(round(quantile(d$rs, c(0, .05, .25, .5, .75, .95, 1)), 3))
cat(sprintf("gruppi che perdono oltre il 20%% dei geni: T1 %d | T3 %d su %d\n", sum(d$rs < -.2), sum(d$rs3 < -.2), nrow(d)))
cat("i dieci che perdono di piu' con T1:\n")
print(d[order(rs)][1:10, .(nome = substr(nome, 1, 30), k, in113, in37_0, sig0, sig1, sig3, rs = round(rs, 3), q0 = round(q0, 3), q1 = round(q1, 3))])
cat(sprintf("geni significativi nei 37: T0 %d, T1 %d | somma: T0 %d, T1 %d (%.1f%%), T2 %d (%.1f%%), T3 %d (%.1f%%)\n",
            tab[in37_0 == TRUE, sum(sig0)], tab[in37_0 == TRUE, sum(sig1)], sum(tab$sig0), sum(tab$sig1), 100 * (sum(tab$sig1) / sum(tab$sig0) - 1),
            sum(tab$sig2), 100 * (sum(tab$sig2) / sum(tab$sig0) - 1), sum(tab$sig3), 100 * (sum(tab$sig3) / sum(tab$sig0) - 1)))
cat("gruppi senza misura:\n"); print(tab[is.na(q0) | is.na(q1) | is.na(q3), .(nome, k, sig0, sig1, sig3, q0, q1, q3, in113)])
q <- tab[in113 == TRUE & dom0_condivide == TRUE]
cat(sprintf("\nnei 113, dominante che condivide: %d | Δquota T1: mediana %.3f, minimo %.3f, massimo %.3f | canale pesi: mediana %.3f\n",
            nrow(q), median(q$dq), min(q$dq), max(q$dq), median(q$dp)))
cat("quei gruppi fuori dai 37 con T0:\n")
print(q[in37_0 == FALSE][order(q1)][, .(nome = substr(nome, 1, 26), k, dom0, q0 = round(q0, 3), q1 = round(q1, 3), q2 = round(q2, 3), q3 = round(q3, 3), qp = round(qp, 3))])
cat("\nnei 113, vicini al confine con T1, quota in [0,47; 0,53]:\n")
print(tab[in113 == TRUE & q1 >= .47 & q1 <= .53][order(q1)][, .(nome = substr(nome, 1, 26), k, condivide = dom0_condivide, q0 = round(q0, 3), q1 = round(q1, 3), q2 = round(q2, 3), q3 = round(q3, 3))])
cat("\nsu 194, chi attraversa 0,5 con T1:\n")
print(tab[(q0 <= .5) != (q1 <= .5)][, .(nome = substr(nome, 1, 26), k, in113, q0 = round(q0, 3), q1 = round(q1, 3))])
tl <- tab[in113 == FALSE & dom0_condivide == TRUE]
cat(sprintf("\ndominante che cambia con T1: %d gruppi | con T3: %d\n", tab[dom0 != dom1, .N], tab[dom0 != dom3, .N]))
cat(sprintf("coppie con condivisione: %d | SE T1/T0 mediana %.2f, IQR %.2f-%.2f, massimo per gene %.2f | sopra 1,10: %d\n",
            nrow(rap), median(rap$r1), quantile(rap$r1, .25), quantile(rap$r1, .75), max(rap$r1max), sum(rap$r1 > 1.10)))
