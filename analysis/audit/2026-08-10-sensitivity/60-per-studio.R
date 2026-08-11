#!/usr/bin/env Rscript
# 60-per-studio.R --- il confronto a livello di SINGOLO STUDIO: 25 accusati contro
# i puliti dello stesso gruppo. E' il test con la potenza vera (il confronto fra
# blocco e nullo appaiato ha 11 punti; questo ne ha 293), ed e' anche la forma in
# cui il risultato va riportato nei Results.
#
# La stratificazione per gruppo NON e' un dettaglio: i gruppi hanno k, numero di
# geni e livelli di influenza diversi, e confrontare gli accusati di TGF-beta1 con
# i puliti di cisplatino misurerebbe il gruppo, non l'accusa.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli) })
OUT <- "analysis/audit/2026-08-10-sensitivity"
I <- utils::read.csv(file.path(OUT, "40-influenza-tutti.csv"), stringsAsFactors = FALSE)

S <- I[I$tipo %in% c("accusato (LOO)", "pulito (LOO)"), ]
S$accusato <- S$tipo == "accusato (LOO)"
cli_alert_info("rimozioni di UN solo studio: {nrow(S)} ({sum(S$accusato)} accusati, {sum(!S$accusato)} puliti) su {length(unique(S$cluster_id))} gruppi")

cli_h2("Distribuzioni grezze (non stratificate: solo per orientarsi)")
for (v in c("spearman", "max_abs_delta_logFC", "n_sig_persi", "bracci_tolti")) {
  a <- S[[v]][S$accusato]; p <- S[[v]][!S$accusato]
  cli_alert_info("{v}: accusati mediana {sprintf('%.4g', stats::median(a, na.rm=TRUE))} | puliti {sprintf('%.4g', stats::median(p, na.rm=TRUE))}")
}

cli_h2("Il confondente: gli accusati tolgono piu' dati?")
w <- stats::wilcox.test(bracci_tolti ~ accusato, data = S)
cli_alert_info("bracci tolti, accusati vs puliti: Wilcoxon p = {format.pval(w$p.value, digits=3)}")
cli_alert_info("mediana bracci: accusati {stats::median(S$bracci_tolti[S$accusato])} | puliti {stats::median(S$bracci_tolti[!S$accusato])}")

cli_h2("Test stratificato per gruppo — rango dell'accusato dentro il suo gruppo")
# Per ogni studio accusato: la sua posizione (in percentile) nella distribuzione
# dei puliti DELLO STESSO gruppo. Se l'accusa non porta informazione, i percentili
# si distribuiscono uniformemente e la loro mediana e' 0,5.
R <- do.call(rbind, lapply(split(S, S$cluster_id), function(x) {
  p <- x[!x$accusato, ]; a <- x[x$accusato, ]
  if (!nrow(a) || nrow(p) < 3L) return(NULL)
  data.frame(cluster_id = x$cluster_id[1], entita = x$entita[1], chi = a$chi,
             pct_d  = vapply(a$max_abs_delta_logFC, function(v) mean(p$max_abs_delta_logFC <= v, na.rm = TRUE), numeric(1)),
             pct_sp = vapply(a$spearman, function(v) mean(p$spearman >= v, na.rm = TRUE), numeric(1)),
             pct_sig = vapply(a$n_sig_persi, function(v) mean(p$n_sig_persi <= v, na.rm = TRUE), numeric(1)),
             stringsAsFactors = FALSE)
}))
cli_alert_info("studi accusati con almeno 3 puliti nel gruppo: {nrow(R)}")
for (v in c("pct_d", "pct_sp", "pct_sig")) {
  m <- stats::median(R[[v]], na.rm = TRUE)
  tt <- stats::wilcox.test(R[[v]] - 0.5)
  cli_alert_info("{v}: percentile mediano {sprintf('%.3f', m)} | Wilcoxon contro 0,5: p = {format.pval(tt$p.value, digits=3)}")
}
cli_alert_info("accusati oltre il 90esimo percentile dei puliti del loro gruppo (max|d|): {sum(R$pct_d >= 0.9)}/{nrow(R)} (attesi per caso: {sprintf('%.1f', 0.1*nrow(R))})")

utils::write.csv(R, file.path(OUT, "60-per-studio-percentili.csv"), row.names = FALSE)

cli_h2("Quali studi accusati SI distinguono davvero")
print(R[order(-R$pct_d), c("entita", "chi", "pct_d", "pct_sp")][1:6, ], row.names = FALSE, digits = 3)

cli_h2("Grandezza assoluta dello spostamento, per riferimento nei Results")
q <- stats::quantile(S$max_abs_delta_logFC, c(.5, .9, .99), na.rm = TRUE)
cli_alert_info("max|dlogFC| togliendo UN studio qualsiasi: mediana {sprintf('%.3f', q[1])} | p90 {sprintf('%.3f', q[2])} | p99 {sprintf('%.3f', q[3])}")
cli_alert_info("Spearman togliendo UN studio qualsiasi: mediana {sprintf('%.3f', stats::median(S$spearman, na.rm=TRUE))}")
cli_alert_info("geni significativi persi (%): mediana {sprintf('%.1f', 100*stats::median(S$n_sig_persi/S$n_sig_pieno, na.rm=TRUE))}")
