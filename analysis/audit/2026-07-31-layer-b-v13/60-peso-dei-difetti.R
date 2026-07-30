#!/usr/bin/env Rscript
# 60-peso-dei-difetti.R --- quanto pesano, nella meta-analisi, gli studi con un
# difetto di appaiamento o di materiale?
#
# Leggendo a testo intero i membri poolati dei 12 case study
# (membri-case-study.txt) sono emersi studi il cui confronto non e' quello che
# il gruppo dichiara. Sapere che ci sono non basta: se pesano l'1% il risultato
# regge, se pesano il 70% no. Qui si misura il peso, con la stessa formula del
# random-effects (1/(SE^2+tau^2)) sull'unita' giusta (studio, dopo il collasso
# dei bracci), sui geni significativi.
#
# La lista dei difetti e' una LETTURA UMANA, dichiarata riga per riga con il
# motivo: non e' l'output di una regola, e va letta come tale.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/60-peso-dei-difetti.R

suppressPackageStartupMessages({ library(dplyr); library(cli) })

STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
OUTDIR <- "analysis/audit/2026-07-31-layer-b-v13"
sel <- read.csv("analysis/layer-b-selection-v13.csv", stringsAsFactors = FALSE)

difetti <- rbind(
  data.frame(cluster_id = "cgroup_L5_85083e38", study_id = "GSE181029",
             motivo = "modello cellulare (neuroni/progenitori da iPSC, PARK2) dove gli altri sono cervello post-mortem"),
  data.frame(cluster_id = "cgroup_L5_85083e38", study_id = "GSE90469",
             motivo = "neuroni dopaminergici derivati da paziente in coltura, non tessuto"),
  data.frame(cluster_id = "cgroup_L5_bd19fe42", study_id = "GSE120663",
             motivo = "PBMC (sangue) dove gli altri sono tessuto epatico"),
  data.frame(cluster_id = "cgroup_L5_bd19fe42", study_id = "GSE77509",
             motivo = "un solo controllo ('Adjacent Normal #3') per tumori di pazienti diversi; include PVTT (trombo portale)"),
  data.frame(cluster_id = "cgroup_L5_871ae09e", study_id = "GSE169241",
             motivo = "cuore di paziente COVID contro macrofago da cellule ES: materiale diverso (gia' dichiarato 2026-07-30)"),
  data.frame(cluster_id = "cgroup_L5_871ae09e", study_id = "GSE151803",
             motivo = "'COVID-19 Lung' contro 'hESC Mock': materiale diverso fra i bracci"),
  data.frame(cluster_id = "cgroup_L5_c0d1d837", study_id = "GSE225481",
             motivo = "LAPC4_ENZA e LNCaP_ENZA contro VCaP_DMSO: linea cellulare diversa (gia' dichiarato 2026-07-30)"),
  data.frame(cluster_id = "cgroup_L5_2e16719f", study_id = "GSE210984",
             motivo = "trattato = MSC derivate da iPSC, controllo = MSC primarie: fonte cellulare diversa"),
  data.frame(cluster_id = "cgroup_L5_2e16719f", study_id = "GSE161176",
             motivo = "Passage 24 contro Passage 6 (gia' dichiarato 2026-07-30)"),
  data.frame(cluster_id = "cgroup_L5_2e16719f", study_id = "GSE97358",
             motivo = "un confronto (Chinese) contro (Malay) (gia' dichiarato 2026-07-30)"),
  data.frame(cluster_id = "cgroup_L5_b71a25a2", study_id = "GSE78801",
             motivo = "DIPG 'pons' contro DIPG 'brain': sede anatomica diversa fra i bracci"),
  data.frame(cluster_id = "cgroup_L5_930c8dcf", study_id = "GSE130247",
             motivo = "'DHT and ENZ' = DHT + antagonista, dentro il gruppo dell'agonista"),
  data.frame(cluster_id = "cgroup_L5_930c8dcf", study_id = "GSE99626",
             motivo = "'E2 and DHT' = estradiolo + DHT, combinazione non catturata"),
  data.frame(cluster_id = "cgroup_L5_87c40ebb", study_id = "GSE124939",
             motivo = "IFNg control_4 e control_5 confrontati contro control_1: soggetto diverso")
)

cp <- arrow::open_dataset(file.path(STAGE4, "cluster_pooled.parquet")) |>
  filter(cluster_id %in% sel$cluster_id, FDR_BH_within_cluster < 0.05) |>
  select(cluster_id, gene_id, tau2) |> collect()
ps <- arrow::open_dataset(file.path(STAGE4, "per_study_de.parquet")) |>
  filter(cluster_id %in% sel$cluster_id) |>
  select(cluster_id, study_id, gene_id, SE) |> collect()

pesi <- ps |>
  filter(!is.na(SE), SE > 0) |>
  group_by(cluster_id, gene_id, study_id) |>
  summarise(SE_studio = sqrt(1 / sum(1 / SE^2)), .groups = "drop") |>
  inner_join(cp, by = c("cluster_id", "gene_id")) |>
  filter(!is.na(tau2)) |>
  mutate(w = 1 / (SE_studio^2 + tau2)) |>
  group_by(cluster_id, gene_id) |>
  mutate(quota = w / sum(w)) |>
  ungroup()

quota_studio <- pesi |>
  group_by(cluster_id, study_id) |>
  summarise(quota_med = median(quota), .groups = "drop")

res <- difetti |>
  left_join(quota_studio, by = c("cluster_id", "study_id")) |>
  left_join(sel |> select(cluster_id, label_paper), by = "cluster_id") |>
  mutate(quota_pct = round(100 * quota_med, 1))

# quota cumulata dei difetti per cluster
cum <- res |>
  group_by(cluster_id, label_paper) |>
  summarise(n_studi_difettosi = n(),
            quota_totale_pct = round(100 * sum(quota_med, na.rm = TRUE), 1),
            .groups = "drop") |>
  arrange(desc(quota_totale_pct))

cli_h2("Peso mediano dei membri difettosi, per cluster")
print(as.data.frame(cum), row.names = FALSE)

cli_h2("Dettaglio, studio per studio")
for (i in seq_len(nrow(res))) {
  cat(sprintf("  %-42s %-11s %5.1f%%  %s\n",
              res$label_paper[i], res$study_id[i], res$quota_pct[i], res$motivo[i]))
}

write.csv(res, file.path(OUTDIR, "peso-dei-difetti.csv"), row.names = FALSE)
write.csv(cum, file.path(OUTDIR, "peso-dei-difetti-per-cluster.csv"), row.names = FALSE)
cli_alert_success("Scritte peso-dei-difetti.csv e -per-cluster.csv")
