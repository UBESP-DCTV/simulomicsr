#!/usr/bin/env Rscript
# 65-appaiato-sui-bracci.R --- il test decisivo: l'accusato contro i puliti dello
# STESSO gruppo che tolgono ALTRETTANTI BRACCI.
#
# 60-per-studio.R ha trovato che gli studi accusati spostano il risultato piu' dei
# puliti (percentile mediano 0,667, p = 0,016). Ma ha trovato anche il confondente
# che l'handout §4.4 aveva previsto: gli accusati tolgono piu' dati (mediana 2
# bracci contro 1, p = 0,036). Senza appaiare sui bracci non si distingue «lo
# studio e' difettoso» da «lo studio e' grande».
#
# Qui il riferimento di ogni accusato sono i soli puliti del suo gruppo con lo
# stesso numero di bracci. Dove non ce ne sono abbastanza, l'accusato NON entra
# nel test e viene dichiarato, invece di rilassare il criterio fino a farlo entrare.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli) })
OUT <- "analysis/audit/2026-08-10-sensitivity"
I <- utils::read.csv(file.path(OUT, "40-influenza-tutti.csv"), stringsAsFactors = FALSE)
S <- I[I$tipo %in% c("accusato (LOO)", "pulito (LOO)"), ]
S$accusato <- S$tipo == "accusato (LOO)"
MIN_RIF <- 3L

R <- do.call(rbind, lapply(split(S, S$cluster_id), function(x) {
  a <- x[x$accusato, ]; p <- x[!x$accusato, ]
  if (!nrow(a)) return(NULL)
  do.call(rbind, lapply(seq_len(nrow(a)), function(i) {
    rif <- p[p$bracci_tolti == a$bracci_tolti[i], ]
    data.frame(cluster_id = x$cluster_id[1], entita = x$entita[1], chi = a$chi[i],
      bracci = a$bracci_tolti[i], n_rif = nrow(rif),
      usabile = nrow(rif) >= MIN_RIF,
      pct_d  = if (nrow(rif) >= MIN_RIF) mean(rif$max_abs_delta_logFC <= a$max_abs_delta_logFC[i], na.rm = TRUE) else NA_real_,
      pct_sp = if (nrow(rif) >= MIN_RIF) mean(rif$spearman >= a$spearman[i], na.rm = TRUE) else NA_real_,
      stringsAsFactors = FALSE)
  }))
}))

cli_h2("Copertura del test appaiato")
cli_alert_info("studi accusati: {nrow(R)} | con almeno {MIN_RIF} puliti a pari bracci: {sum(R$usabile)}")
cli_alert_info("esclusi per mancanza di riferimento: {sum(!R$usabile)} ({paste(unique(R$entita[!R$usabile]), collapse=', ')})")

U <- R[R$usabile, ]
cli_h2("Il test, appaiato sui bracci rimossi")
for (v in c("pct_d", "pct_sp")) {
  m <- stats::median(U[[v]]); tt <- stats::wilcox.test(U[[v]] - 0.5)
  cli_alert_info("{v}: percentile mediano {sprintf('%.3f', m)} (0,5 = indistinguibile) | Wilcoxon p = {format.pval(tt$p.value, digits=3)}")
}
cli_alert_info("oltre il 90esimo percentile dei puliti a pari bracci: {sum(U$pct_d >= 0.9)}/{nrow(U)} (attesi {sprintf('%.1f', 0.1*nrow(U))})")

cli_h2("Confronto: senza e con l'appaiamento")
N <- utils::read.csv(file.path(OUT, "60-per-studio-percentili.csv"), stringsAsFactors = FALSE)
cli_alert_info("NON appaiato (tutti i puliti del gruppo): mediana {sprintf('%.3f', stats::median(N$pct_d))}, p = {format.pval(stats::wilcox.test(N$pct_d - 0.5)$p.value, digits=3)}")
cli_alert_info("APPAIATO sui bracci:                       mediana {sprintf('%.3f', stats::median(U$pct_d))}, p = {format.pval(stats::wilcox.test(U$pct_d - 0.5)$p.value, digits=3)}")

utils::write.csv(R, file.path(OUT, "65-appaiato-sui-bracci.csv"), row.names = FALSE)
print(U[order(-U$pct_d), c("entita","chi","bracci","n_rif","pct_d","pct_sp")], row.names = FALSE, digits = 3)
