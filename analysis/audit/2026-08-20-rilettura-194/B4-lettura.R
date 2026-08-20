#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/B4-lettura.R
#
# LEGGERE LE TRE MISURE INSIEME, separando l'aritmetica dall'influenza.
#
# B2 dice «geni significativi persi: mediana 39,7%, e 21 gruppi su 66 ne perdono
# piu' della meta'». Preso da solo il numero inganna, perche' mescola due cose:
#
#   (a) ARITMETICA — un gruppo a k=3 che perde uno studio resta a k=2, sotto la
#       soglia del pooling: perde il 100% per costruzione, non perche' lo studio
#       fosse influente. Sono 16 gruppi su 66.
#   (b) INFLUENZA VERA — il gruppo sopravvive e il risultato si sposta comunque.
#
# Solo (b) e' una misura. (a) e' la fragilita' di k=3, che e' un fatto sul GATE,
# non sul difetto — ed e' lo stesso fatto trovato ieri sul movimento fra le due
# esecuzioni (il 62,4% degli studi che escono aveva la chiave identica).
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/B4-lettura.R

suppressPackageStartupMessages({ library(cli) })
OUT  <- "analysis/audit/2026-08-20-rilettura-194"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"

d  <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
W  <- utils::read.csv(file.path(OUT, "B1-peso-contaminato.csv"), stringsAsFactors = FALSE)
I  <- utils::read.csv(file.path(OUT, "B2-influenza-loo.csv"), stringsAsFactors = FALSE)
N  <- if (file.exists(file.path(OUT, "B3-nulli.csv")))
        utils::read.csv(file.path(OUT, "B3-nulli.csv"), stringsAsFactors = FALSE) else NULL

M <- merge(W[, c("cluster_id","entita","k","n_studi_accusati","peso_contaminato","verdetto")],
           I[, c("cluster_id","esito","n_studi_tolti","spearman","n_sig_pieno","n_sig_persi",
                 "pct_sig_persi","max_abs_delta_logFC","k_pieno","k_ridotto")],
           by = "cluster_id", all.x = TRUE)
M$sopravvive <- !is.na(M$k_ridotto) & M$k_ridotto >= 3

cli_h1("Le 194, con le tre misure")
cli_alert_info("senza accuse: {sum(M$n_studi_accusati == 0)} | con accuse: {sum(M$n_studi_accusati > 0)}")

acc <- M[M$n_studi_accusati > 0 & !is.na(M$esito) & M$esito == "ok", ]
cli_h2("Aritmetica o influenza?")
cli_alert_info("gruppi accusati misurati: {nrow(acc)}")
cli_alert_info("  la meta-analisi MUORE (k scende sotto 3): {sum(!acc$sopravvive)}")
cli_alert_info("  la meta-analisi SOPRAVVIVE: {sum(acc$sopravvive)}")

viv <- acc[acc$sopravvive, ]
cli_h2("Solo dove la meta-analisi sopravvive — la misura che vale")
cli_alert_info("  Spearman: mediana {sprintf('%.3f', stats::median(viv$spearman, na.rm=TRUE))} | 1o quartile {sprintf('%.3f', stats::quantile(viv$spearman, .25, na.rm=TRUE))}")
cli_alert_info("  geni significativi persi: mediana {sprintf('%.1f%%', stats::median(viv$pct_sig_persi, na.rm=TRUE))} | massimo {sprintf('%.1f%%', max(viv$pct_sig_persi, na.rm=TRUE))}")
cli_alert_info("  max |delta logFC|: mediana {sprintf('%.3f', stats::median(viv$max_abs_delta_logFC, na.rm=TRUE))}")
cli_alert_info("  peso contaminato: mediana {sprintf('%.1f%%', stats::median(viv$peso_contaminato))}")

cli_h2("Tutto per fascia di k — e' qui che si vede il meccanismo")
acc$fascia <- cut(acc$k, c(2,4,9,14,Inf), labels = c("k=3-4","k=5-9","k=10-14","k>=15"))
tab <- do.call(rbind, lapply(levels(acc$fascia), function(f) {
  s <- acc[acc$fascia == f, ]
  if (!nrow(s)) return(NULL)
  data.frame(fascia = f, gruppi = nrow(s),
             muoiono = sum(!s$sopravvive),
             peso_contaminato_mediano = round(stats::median(s$peso_contaminato), 1),
             sig_persi_mediana = round(stats::median(s$pct_sig_persi, na.rm = TRUE), 1),
             spearman_mediana = round(stats::median(s$spearman, na.rm = TRUE), 3),
             stringsAsFactors = FALSE)
}))
print(tab, row.names = FALSE)

cli_h2("Il quadro sull'intero deliverable")
cli_alert_info("meta-analisi senza alcun difetto letto: {sum(M$n_studi_accusati == 0)} su 194 ({sprintf('%.0f%%', 100*mean(M$n_studi_accusati == 0))})")
cli_alert_info("con difetti, ma che sopravvivono togliendoli: {sum(acc$sopravvive)}")
cli_alert_info("con difetti, e che non sopravvivono: {sum(!acc$sopravvive)}")
cli_alert_info("=> meta-analisi che restano in piedi togliendo TUTTI i difetti: {sum(M$n_studi_accusati == 0) + sum(acc$sopravvive)} su 194")

if (!is.null(N)) {
  cli_h2("E i nulli: e' il difetto o e' il togliere dati?")
  nn <- N[N$esito == "ok", ]
  cli_alert_info("gruppi con nullo costruibile: {nrow(nn)}")
  for (v in c("percentile_sig","percentile_spearman","percentile_delta")) {
    p <- nn[[v]]
    w <- suppressWarnings(stats::wilcox.test(p, mu = 0.5))
    cli_alert_info("  {v}: mediana {sprintf('%.3f', stats::median(p, na.rm=TRUE))} | Wilcoxon vs 0,50 p = {sprintf('%.4f', w$p.value)}")
  }
  M <- merge(M, N[, c("cluster_id","percentile_sig","percentile_spearman","percentile_delta",
                      "n_nulli","bracci_accusati","bracci_nulli_mediana")],
             by = "cluster_id", all.x = TRUE)
}

utils::write.csv(M[order(-M$peso_contaminato), ], file.path(OUT, "B4-quadro-influenza.csv"), row.names = FALSE)
cli_alert_success("Scritto B4-quadro-influenza.csv")
