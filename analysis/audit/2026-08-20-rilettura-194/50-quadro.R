#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/50-quadro.R
#
# Il quadro d'insieme: i verdetti incrociati con la dimensione dei gruppi, col
# verdetto che il deliverable si era gia' dato, e con la divergenza fra le due
# esecuzioni.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/50-quadro.R

suppressPackageStartupMessages({ library(cli) })
OUT <- "analysis/audit/2026-08-20-rilettura-194"
A3  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"

v <- read.csv(file.path(OUT, "verdetti-194.csv"), stringsAsFactors = FALSE)
d <- readRDS(file.path(A3, "deliverable-annotato.rds"))
m <- merge(v, d[, c("cluster_id", "k_effective", "k_kish", "quota_top1", "n_sig",
                    "I2_med", "coherence_verdict", "contrast_entity",
                    "contrast_entity_label")], by = "cluster_id")
stopifnot(nrow(m) == nrow(v))

cli_h2("Il verdetto, per dimensione del gruppo")
m$fascia <- cut(m$k_effective, breaks = c(2, 4, 9, 14, Inf),
                labels = c("k = 3-4", "k = 5-9", "k = 10-14", "k >= 15"))
t <- table(m$fascia, m$verdetto_finale)
t <- cbind(t, totale = rowSums(t))
t <- cbind(t, "% difettose" = round(100 * t[, "difettosa"] / t[, "totale"], 1))
print(t)

cli_h2("Il verdetto contro quello che il deliverable dichiarava")
print(table(dichiarato = m$coherence_verdict, letto = m$verdetto_finale))

cli_h2("Le 14 meta-analisi piu' grandi, una per una")
g <- m[order(-m$k_effective), ][1:14, ]
for (i in seq_len(nrow(g))) cli_alert(sprintf(
  "k=%2d  %-11s  %-22s  %s", g$k_effective[i], g$verdetto_finale[i],
  substr(g$contrast_entity_label[i], 1, 22), g$cluster_id[i]))

cli_h2("Quanto pesano i difetti dentro il gruppo")
dif <- read.csv(file.path(OUT, "difetti.csv"), stringsAsFactors = FALSE)
n_per_gruppo <- table(dif$cluster_id)
m$n_difetti <- as.integer(n_per_gruppo[m$cluster_id]); m$n_difetti[is.na(m$n_difetti)] <- 0L
sel <- m[m$verdetto_finale == "difettosa", ]
sel$quota <- sel$n_difetti / sel$k_effective
cli_alert_info("nelle {nrow(sel)} difettose: studi accusati su studi poolati, mediana {sprintf('%.0f%%', 100*stats::median(sel$quota))}, massimo {sprintf('%.0f%%', 100*max(sel$quota))}")
cli_alert_info("difettose con UN SOLO studio accusato: {sum(sel$n_difetti == 1)} su {nrow(sel)}")

cli_h2("I verdetti che l'etichetta non ha chiuso")
print(table(m$verdetto_finale[m$etichetta_non_chiude == "True"]))

utils::write.csv(m[order(-m$k_effective), ], file.path(OUT, "quadro-194.csv"), row.names = FALSE)
cli_alert_success("Scritto quadro-194.csv")
