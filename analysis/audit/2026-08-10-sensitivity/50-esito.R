#!/usr/bin/env Rscript
# 50-esito.R --- l'esito del programma di sensitivity, e il conto delle previsioni.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli) })
OUT <- "analysis/audit/2026-08-10-sensitivity"
I <- utils::read.csv(file.path(OUT, "40-influenza-tutti.csv"), stringsAsFactors = FALSE)
P <- utils::read.csv(file.path(OUT, "20-peso-contaminato.csv"), stringsAsFactors = FALSE)

cli_h1("1. Il blocco accusato contro il nullo appaiato")
T <- do.call(rbind, lapply(split(I, I$cluster_id), function(x) {
  bl <- x[x$tipo == "accusati (blocco)", ]
  if (!nrow(bl)) bl <- x[x$tipo == "accusato (LOO)", ][1, ]   # gruppi con 1 solo accusato
  nu <- x[x$tipo == "nullo appaiato", ]
  data.frame(
    entita = x$entita[1], k = max(x$k_pieno, na.rm = TRUE),
    bracci_tolti = bl$bracci_tolti[1],
    bracci_nullo = stats::median(nu$bracci_tolti),
    sp_acc = bl$spearman[1], sp_nullo_med = stats::median(nu$spearman),
    d_acc = bl$max_abs_delta_logFC[1], d_nullo_med = stats::median(nu$max_abs_delta_logFC),
    d_nullo_p90 = stats::quantile(nu$max_abs_delta_logFC, 0.90, names = FALSE),
    sig_persi_acc = bl$n_sig_persi[1], sig_persi_nullo = stats::median(nu$n_sig_persi),
    sig_pieno = bl$n_sig_pieno[1],
    # percentile dell'accusato nella distribuzione nulla (1 = piu' estremo di tutti)
    pct_d = mean(nu$max_abs_delta_logFC <= bl$max_abs_delta_logFC[1]),
    pct_sp = mean(nu$spearman >= bl$spearman[1]),
    stringsAsFactors = FALSE)
}))
T <- T[order(-T$k), ]
print(T[, c("entita","k","bracci_tolti","bracci_nullo","sp_acc","sp_nullo_med","d_acc","d_nullo_med","pct_d")],
      row.names = FALSE, digits = 3)

cli_h2("Il blocco accusato e' piu' influente di una rimozione equivalente a caso?")
cli_alert_info("gruppi in cui l'accusato supera la MEDIANA del nullo (max|dlogFC|): {sum(T$d_acc > T$d_nullo_med)}/{nrow(T)}")
cli_alert_info("gruppi in cui supera il 90esimo percentile del nullo: {sum(T$d_acc > T$d_nullo_p90)}/{nrow(T)}")
cli_alert_info("percentile mediano dell'accusato nel nullo: {sprintf('%.2f', stats::median(T$pct_d))} (0,50 = indistinguibile)")
w <- suppressWarnings(stats::wilcox.test(T$d_acc, T$d_nullo_med, paired = TRUE))
cli_alert_info("Wilcoxon appaiato accusato vs nullo (max|dlogFC|): p = {format.pval(w$p.value, digits=3)}")

cli_h1("2. Quanto si sposta il deliverable togliendo TUTTI gli studi accusati")
T$sig_persi_pct <- 100 * T$sig_persi_acc / T$sig_pieno
print(T[, c("entita","k","sp_acc","d_acc","sig_pieno","sig_persi_acc","sig_persi_pct")],
      row.names = FALSE, digits = 3)
cli_alert_info("Spearman: mediana {sprintf('%.3f', stats::median(T$sp_acc))} | minimo {sprintf('%.3f', min(T$sp_acc))}")
cli_alert_info("max|dlogFC| sui primi 30: mediana {sprintf('%.3f', stats::median(T$d_acc))} | massimo {sprintf('%.3f', max(T$d_acc))}")
cli_alert_info("geni significativi persi: mediana {sprintf('%.1f%%', stats::median(T$sig_persi_pct))} | massimo {sprintf('%.1f%%', max(T$sig_persi_pct))}")

cli_h1("3. Il conto delle previsioni")
p1 <- sum(T$sp_acc >= 0.95)
cli_alert_info("P1 (Spearman>=0,95 in >=9/11): {p1}/11 -> {ifelse(p1>=9,'CENTRATA','FALSIFICATA')}")
p2 <- sum(T$sp_acc >= 0.99 & T$d_acc > 1.0)
cli_alert_info("P2 (>=1 gruppo con Spearman>=0,99 e max|d|>1): {p2} -> {ifelse(p2>=1,'CENTRATA','FALSIFICATA')}")
m <- merge(T, P[, c("entita","peso_CORRETTO")], by = "entita")
r3 <- suppressWarnings(stats::cor(m$peso_CORRETTO, m$d_acc, method = "spearman"))
cli_alert_info("P3 (corr peso contaminato ~ max|d| > 0): rho = {sprintf('%.3f', r3)} -> {ifelse(r3>0,'CENTRATA','FALSIFICATA')}")
p4 <- sum(T$pct_d <= 0.95 & T$pct_sp <= 0.95)
cli_alert_info("P4 (nullo indistinguibile in >=6/8 con potenza): {p4}/11 gruppi non estremi -> {ifelse(p4>=6,'CENTRATA','FALSIFICATA')}")
p5 <- sum(T$sig_persi_acc > 0, na.rm = TRUE)
cli_alert_info("P5 (segno negativo, cioe' si PERDONO significativi, in >=9/11): {p5}/11 -> {ifelse(p5>=9,'CENTRATA','FALSIFICATA')}")

utils::write.csv(T, file.path(OUT, "50-esito.csv"), row.names = FALSE)

cli_h1("4. Curva a gradini: quanti gruppi sopravvivono a una soglia sull'influenza")
for (s in c(0.999, 0.99, 0.95, 0.90)) cli_alert_info("soglia Spearman >= {s}: {sum(T$sp_acc >= s)}/11 gruppi")
for (s in c(0.1, 0.25, 0.5, 1.0)) cli_alert_info("soglia max|dlogFC| <= {s}: {sum(T$d_acc <= s)}/11 gruppi")
