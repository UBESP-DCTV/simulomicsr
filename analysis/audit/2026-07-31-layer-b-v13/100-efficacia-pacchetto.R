#!/usr/bin/env Rscript
# 100-efficacia-pacchetto.R --- il codice di pacchetto riproduce la misura?
#
# `compute_pooling_effectiveness()` (R/stage4-pooling-effectiveness.R) e' la
# versione testata della misura fatta a mano in 70-dominanza-tutti-191.R. Prima
# di metterla nel deliverable si verifica che dia gli STESSI numeri sui dati
# veri: un helper testato su fixture che diverge sui dati reali e' peggio di
# nessun helper.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/100-efficacia-pacchetto.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE); library(dplyr); library(cli)
})

STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
OUTDIR <- "analysis/audit/2026-07-31-layer-b-v13"

tau2 <- arrow::open_dataset(file.path(STAGE4, "cluster_pooled.parquet")) |>
  filter(FDR_BH_within_cluster < 0.05) |>
  select(cluster_id, gene_id, tau2) |> collect()
per_arm <- arrow::open_dataset(file.path(STAGE4, "per_study_de.parquet")) |>
  select(cluster_id, gene_id, study_id, SE) |> collect()
cli_alert_info("geni significativi: {nrow(tau2)} | righe per-braccio: {nrow(per_arm)}")

t0 <- Sys.time()
eff <- compute_pooling_effectiveness(per_arm, tau2)
cli_alert_success("calcolata in {round(as.numeric(difftime(Sys.time(), t0, units='secs')))}s: {nrow(eff)} cluster")
rm(per_arm); gc(verbose = FALSE)

# --- confronto con la misura a mano del 70- --------------------------------
vecchia <- read.csv(file.path(OUTDIR, "dominanza-tutti-191.csv"), stringsAsFactors = FALSE)
cmp <- eff |> inner_join(vecchia |> select(cluster_id, k_kish_med, quota_top1_med,
                                           k_reale_med), by = "cluster_id")
cli_h2("Confronto pacchetto vs misura a mano")
cat(sprintf("  cluster confrontati: %d su %d\n", nrow(cmp), nrow(eff)))
cat(sprintf("  scarto massimo su k_kish:     %.10f\n", max(abs(cmp$k_kish - cmp$k_kish_med))))
cat(sprintf("  scarto massimo su quota_top1: %.10f\n", max(abs(cmp$quota_top1 - cmp$quota_top1_med))))
cat(sprintf("  k_studies identico:           %d su %d\n",
            sum(cmp$k_studies == cmp$k_reale_med), nrow(cmp)))

# --- e col k del deliverable? ----------------------------------------------
d <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
m <- eff |> inner_join(d |> select(cluster_id, k_effective, contrast_entity_label,
                                   coherence_verdict), by = "cluster_id")
cli_h2("Il deliverable copre tutti i cluster misurati?")
cat(sprintf("  nel deliverable: %d | misurati: %d | in comune: %d\n",
            nrow(d), nrow(eff), nrow(m)))
cat(sprintf("  k_studies (mediana sui geni) <= k_effective: %d su %d\n",
            sum(m$k_studies <= m$k_effective), nrow(m)))

cli_h2("Riepilogo sui 191")
cat(sprintf("  dominati (top1 >= 50%%):        %d (%.1f%%)\n",
            sum(m$dominato), 100 * mean(m$dominato)))
cat(sprintf("  meno di 2 studi efficaci:      %d (%.1f%%)\n",
            sum(m$k_kish < 2), 100 * mean(m$k_kish < 2)))
cat(sprintf("  frazione efficace mediana:     %.2f\n", median(m$frazione_efficace)))

saveRDS(eff, file.path(OUTDIR, "efficacia-pooling-191.rds"))
write.csv(eff, file.path(OUTDIR, "efficacia-pooling-191.csv"), row.names = FALSE)
cli_alert_success("Scritte efficacia-pooling-191.rds e .csv")
