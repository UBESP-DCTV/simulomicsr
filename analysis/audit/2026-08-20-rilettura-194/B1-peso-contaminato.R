#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/B1-peso-contaminato.R
#
# QUANTO DEL POOLING VIENE DAI CONFRONTI DIFETTOSI — su tutte e 194.
#
# La misura esiste dal 2026-08-10 ma copriva 13 gruppi (i grandi) del deliverable
# v15, con la lista di accuse della rilettura del 5 agosto. Qui si rifa' con:
#   - il deliverable ATTUALE (A3 v16, 194 meta-analisi);
#   - la lista NUOVA (85 studi, 97 difetti, 66 gruppi), che viene dalla rilettura
#     di tutte e 194 e non dei soli gruppi grandi.
#
# LA REGOLA E' QUELLA DI PACCHETTO, non una scritta a mano. Il peso pubblicato il
# 5 agosto usava «mediana di 1/SE^2 per studio»: pesava i BRACCI senza collassarli
# per studio e ignorava tau^2, mentre il peso vero del random-effects e'
# 1/(SE_studio^2 + tau^2). `compute_pooling_weight_shares()` fa quello giusto.
#
# Uno studio accusato che nel pooling non porta peso contribuisce 0, non NA: e'
# il caso che conta, perche' un gruppo puo' avere accuse e peso contaminato zero.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/B1-peso-contaminato.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); devtools::load_all(".", quiet = TRUE)
})
OUT  <- "analysis/audit/2026-08-20-rilettura-194"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"

d   <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
dif <- utils::read.csv(file.path(OUT, "difetti.csv"), stringsAsFactors = FALSE)
lista <- unique(dif[, c("cluster_id", "study_id")])
cli_alert_info("meta-analisi: {nrow(d)} | studi accusati: {nrow(lista)} in {length(unique(lista$cluster_id))} gruppi")

cli_alert_info("leggo per_study_de e cluster_pooled...")
psd <- as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet"),
                                  col_select = c("cluster_id", "study_id", "gene_id", "SE")))
psd <- psd[psd$cluster_id %in% d$cluster_id & is.finite(psd$SE) & psd$SE > 0, ]
tau <- as.data.frame(read_parquet(file.path(POOL, "cluster_pooled.parquet"),
                                  col_select = c("cluster_id", "gene_id", "tau2")))
tau <- tau[tau$cluster_id %in% d$cluster_id, ]
cli_alert_info("righe per-braccio: {nrow(psd)} | righe poolate: {nrow(tau)}")

W <- compute_pooling_weight_shares(per_arm = psd, tau2 = tau, studi = lista)
cli_alert_info("cluster con un peso calcolato: {nrow(W)}")

T <- data.frame(
  cluster_id = d$cluster_id,
  entita     = ifelse(is.na(d$contrast_entity_label) | !nzchar(d$contrast_entity_label),
                      d$contrast_entity, d$contrast_entity_label),
  k          = d$k_effective,
  n_studi_accusati = as.integer(table(factor(lista$cluster_id, levels = d$cluster_id))),
  peso_contaminato = 100 * W$quota_mediana[match(d$cluster_id, W$cluster_id)],
  stringsAsFactors = FALSE)
T$peso_contaminato[is.na(T$peso_contaminato)] <- 0
T$verdetto <- utils::read.csv(file.path(OUT, "verdetti-194.csv"),
                              stringsAsFactors = FALSE)$verdetto_finale[
                                match(T$cluster_id, utils::read.csv(file.path(OUT, "verdetti-194.csv"),
                                      stringsAsFactors = FALSE)$cluster_id)]
T <- T[order(-T$peso_contaminato), ]

cli_h1("Peso contaminato, tutte e 194")
cli_alert_info("gruppi SENZA accuse: {sum(T$n_studi_accusati == 0)} -> peso 0 per costruzione")
con <- T[T$n_studi_accusati > 0, ]
cli_alert_info("gruppi CON accuse: {nrow(con)}")
cli_alert_info("  peso contaminato mediano: {sprintf('%.1f%%', stats::median(con$peso_contaminato))}")
cli_alert_info("  minimo {sprintf('%.1f%%', min(con$peso_contaminato))} | massimo {sprintf('%.1f%%', max(con$peso_contaminato))}")
cli_alert_info("  gruppi accusati ma con peso contaminato ZERO: {sum(con$peso_contaminato == 0)}")
cli_alert_info("  sopra il 50% del peso: {sum(con$peso_contaminato > 50)} | sopra il 25%: {sum(con$peso_contaminato > 25)}")

cli_h2("I venti gruppi piu' contaminati")
print(utils::head(T[, c("entita", "k", "n_studi_accusati", "peso_contaminato", "verdetto")], 20),
      row.names = FALSE, digits = 3)

cli_h2("Il peso contaminato cresce col numero di studi?")
T$fascia <- cut(T$k, c(2, 4, 9, 14, Inf), labels = c("k=3-4", "k=5-9", "k=10-14", "k>=15"))
agg <- stats::aggregate(peso_contaminato ~ fascia, data = T[T$n_studi_accusati > 0, ],
                        FUN = function(x) c(n = length(x), mediana = stats::median(x)))
print(agg)

utils::write.csv(T, file.path(OUT, "B1-peso-contaminato.csv"), row.names = FALSE)
cli_alert_success("Scritto B1-peso-contaminato.csv")
