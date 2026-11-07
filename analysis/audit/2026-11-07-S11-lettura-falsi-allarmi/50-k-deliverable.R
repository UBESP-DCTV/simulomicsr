#!/usr/bin/env Rscript
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/50-k-deliverable.R
# k, k_effective e n_sig delle 194 meta-analisi del deliverable, per il cancello C2(c) e il conto sotto 3 studi.
# Rscript SENZA --vanilla.
d <- readRDS("/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d/deliverable-annotato.rds")
write.csv(as.data.frame(d)[, c("cluster_id", "k", "k_effective", "n_sig")],
          "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/50-k-deliverable.csv", row.names = FALSE)
