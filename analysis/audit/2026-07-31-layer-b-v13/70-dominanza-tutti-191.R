#!/usr/bin/env Rscript
# 70-dominanza-tutti-191.R --- quante delle 191 meta-analisi sono, di fatto,
# uno studio solo con altri intorno?
#
# Il numero efficace di studi (Kish) su TUTTI e 191, non su un campione:
# (sum w)^2 / sum w^2 con w = 1/(SE_studio^2 + tau^2), sui geni significativi,
# dopo il collasso dei bracci dentro lo studio (l'unita' su cui gira il REM).
#
# Nasce dal Layer B: il gruppo Parkinson ha k=10 ma 1,8 studi efficaci, e il
# 73% del peso viene da un modello cellulare. Se il fenomeno e' diffuso, e' un
# numero da Methods; se e' raro, e' un caveat su pochi gruppi. Si misura.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/70-dominanza-tutti-191.R

suppressPackageStartupMessages({ library(dplyr); library(cli) })

STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
OUTDIR <- "analysis/audit/2026-07-31-layer-b-v13"

d <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
cli_alert_info("cluster nel deliverable: {nrow(d)}")

cp <- arrow::open_dataset(file.path(STAGE4, "cluster_pooled.parquet")) |>
  filter(FDR_BH_within_cluster < 0.05) |>
  select(cluster_id, gene_id, tau2) |> collect()
cli_alert_info("geni significativi: {nrow(cp)}")

ps <- arrow::open_dataset(file.path(STAGE4, "per_study_de.parquet")) |>
  select(cluster_id, study_id, gene_id, SE) |> collect()
cli_alert_info("righe per-braccio: {nrow(ps)}")

per_gene <- ps |>
  filter(!is.na(SE), SE > 0) |>
  group_by(cluster_id, gene_id, study_id) |>
  summarise(SE_studio = sqrt(1 / sum(1 / SE^2)), .groups = "drop") |>
  inner_join(cp, by = c("cluster_id", "gene_id")) |>
  filter(!is.na(tau2)) |>
  mutate(w = 1 / (SE_studio^2 + tau2)) |>
  group_by(cluster_id, gene_id) |>
  summarise(k_reale = n(),
            k_kish  = sum(w)^2 / sum(w^2),
            quota_top1 = max(w) / sum(w),
            .groups = "drop")
rm(ps); gc(verbose = FALSE)

per_cluster <- per_gene |>
  group_by(cluster_id) |>
  summarise(n_geni_sig = n(),
            k_reale_med = median(k_reale),
            k_kish_med  = median(k_kish),
            quota_top1_med = median(quota_top1),
            .groups = "drop") |>
  left_join(d |> select(cluster_id, contrast_entity, contrast_entity_label,
                        k_effective, n_sig, I2_med, coherence_verdict),
            by = "cluster_id") |>
  mutate(frazione_efficace = k_kish_med / k_reale_med,
         dominato = quota_top1_med >= 0.5)

cli_h2("Distribuzione della frazione efficace (k_kish / k) sui 191")
print(summary(per_cluster$frazione_efficace))

cli_h2("Quanti gruppi sono dominati da un solo studio (>=50% del peso)")
cat(sprintf("  dominati:      %d su %d (%.1f%%)\n",
            sum(per_cluster$dominato), nrow(per_cluster),
            100 * mean(per_cluster$dominato)))
cat(sprintf("  >=70%% da uno:  %d (%.1f%%)\n",
            sum(per_cluster$quota_top1_med >= 0.7),
            100 * mean(per_cluster$quota_top1_med >= 0.7)))
cat(sprintf("  k_kish < 2:    %d (%.1f%%)  <- una meta-analisi che vale meno di due studi\n",
            sum(per_cluster$k_kish_med < 2), 100 * mean(per_cluster$k_kish_med < 2)))

cli_h2("Dominazione per fascia di k")
per_cluster$fascia <- cut(per_cluster$k_effective, c(2, 4, 6, 10, 20, 50),
                          include.lowest = TRUE,
                          labels = c("k=3-4", "k=5-6", "k=7-10", "k=11-20", "k=21-49"))
print(as.data.frame(per_cluster |> group_by(fascia) |> summarise(
  n = n(),
  frazione_efficace_med = round(median(frazione_efficace), 2),
  dominati = sum(dominato),
  dominati_pct = round(100 * mean(dominato), 0), .groups = "drop")), row.names = FALSE)

cli_h2("I 15 piu' dominati")
top <- per_cluster |> arrange(desc(quota_top1_med)) |> head(15)
for (i in seq_len(nrow(top))) {
  cat(sprintf("  %-38s k=%2d  efficaci=%4.1f  top1=%4.1f%%  n_sig=%5d  %s\n",
              substr(top$contrast_entity_label[i], 1, 38), top$k_effective[i],
              top$k_kish_med[i], 100 * top$quota_top1_med[i], top$n_sig[i],
              top$coherence_verdict[i]))
}

cli_h2("Gruppi di MALATTIA (MeSH), ordinati per studi efficaci")
mal <- per_cluster |> filter(grepl("^MeSH:", contrast_entity)) |>
  arrange(desc(k_kish_med))
for (i in seq_len(nrow(mal))) {
  cat(sprintf("  %-38s k=%2d  efficaci=%4.1f  top1=%4.1f%%  n_sig=%5d  I2=%4.1f  %s\n",
              substr(mal$contrast_entity_label[i], 1, 38), mal$k_effective[i],
              mal$k_kish_med[i], 100 * mal$quota_top1_med[i], mal$n_sig[i],
              mal$I2_med[i], mal$coherence_verdict[i]))
}

write.csv(per_cluster |> select(-fascia),
          file.path(OUTDIR, "dominanza-tutti-191.csv"), row.names = FALSE)
cli_alert_success("Scritta dominanza-tutti-191.csv")
