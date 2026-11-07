#!/usr/bin/env Rscript
# 46-opzioni.R — S10b: le opzioni per la lettura (decisione del PI), con lo stesso bootstrap di 40-misura.R.
#
# Dopo la misura: non cambia la regola ne' la scelta depositata. Riporta, per ogni combinazione che il PI
# puo' mandare alla lettura, difettosi presi, falsi allarmi, altri negativi e righe da leggere.
# Uso: Rscript analysis/audit/2026-11-07-S10b-metadati-campioni/46-opzioni.R   (senza --vanilla)
suppressPackageStartupMessages(library(data.table))
OUT <- "analysis/audit/2026-11-07-S10b-metadati-campioni"
x <- fread(file.path(OUT, "40-esiti.csv"), encoding = "UTF-8")
stopifnot(nrow(x) == 1903L)
un <- function(cols) as.integer(rowSums(as.matrix(x[, ..cols])) > 0L)
OPZ <- list(
  "a. proposta dal criterio: R1 + R2a + R2b + R6 + S10 pulita" = c("R1", "R2a", "R2b", "R6", "S10_pulita"),
  "b. proposta + materiale (R4a)" = c("R1", "R2a", "R2b", "R6", "S10_pulita", "R4a"),
  "c. M intera (12 sotto-regole)" = "M",
  "d. M + S10 V3" = c("M", "S10_V3"),
  "e. S10 V3 (la regola sulle etichette)" = "S10_V3")
set.seed(20261107L)
studi <- unique(x$study)
idx <- split(seq_len(nrow(x)), x$study)
bi <- replicate(2000L, unlist(idx[sample(studi, length(studi), replace = TRUE)], use.names = FALSE),
                simplify = FALSE)
nP <- sum(x$insieme == "pulito"); nD <- sum(x$insieme == "difettoso")
res <- rbindlist(lapply(names(OPZ), function(o) {
  s <- un(OPZ[[o]])
  b <- vapply(bi, function(i) {
    ins <- x$insieme[i]; si <- s[i]
    c(sum(si == 1L & ins == "difettoso") / sum(ins == "difettoso"), sum(si == 1L & ins == "pulito") / sum(ins == "pulito"))
  }, numeric(2))
  qs <- quantile(b[1, ], c(.025, .975)); qf <- nP * quantile(b[2, ], c(.025, .975))
  data.table(opzione = o,
             difettosi = sprintf("%d/%d (%.1f%%)", sum(s & x$insieme == "difettoso"), nD,
                                 100 * mean(s[x$insieme == "difettoso"])),
             sens_IC95 = sprintf("[%.1f; %.1f]", 100 * qs[1], 100 * qs[2]),
             falsi_allarmi = sum(s & x$insieme == "pulito"), fa_IC95 = sprintf("[%.0f; %.0f]", qf[1], qf[2]),
             altri_negativi = sum(s & x$insieme == "altro_negativo"),
             da_leggere = sum(s & x$insieme != "difettoso"),
             meta_analisi_con_falsi_allarmi = uniqueN(x[s == 1L & insieme == "pulito", cluster_id]))
}))
sink(file.path(OUT, "46-out.txt"), split = TRUE)
options(width = 200)
print(res)
sink()
