# analysis/audit/2026-07-31-layer-b-v13/40-dominanza-forest.R
# Un gruppo da 49 studi e' davvero 49, o e' dominato da pochi?
#
# In un random-effects il peso dello studio i su un gene e' 1/(SE_i^2 + tau^2).
# Il "numero efficace di studi" e' il numero di Kish: (sum w)^2 / sum w^2 — se
# tutti pesano uguale vale k, se uno domina tende a 1. Si calcola sui geni
# significativi, che sono quelli che il paper mostra.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/40-dominanza-forest.R

suppressPackageStartupMessages({
  library(dplyr)
  library(cli)
})

STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
SEL    <- "analysis/layer-b-selection-v13.csv"
OUTDIR <- "analysis/audit/2026-07-31-layer-b-v13"

sel <- read.csv(SEL, stringsAsFactors = FALSE)

# tau^2 per gene, solo geni significativi
cp <- arrow::open_dataset(file.path(STAGE4, "cluster_pooled.parquet")) |>
  filter(cluster_id %in% sel$cluster_id, FDR_BH_within_cluster < 0.05) |>
  select(cluster_id, gene_id, tau2, k_effective) |>
  collect()
cli_alert_info("geni significativi nei 12 cluster: {nrow(cp)}")

ps <- arrow::open_dataset(file.path(STAGE4, "per_study_de.parquet")) |>
  filter(cluster_id %in% sel$cluster_id) |>
  select(cluster_id, study_id, gene_id, SE) |>
  collect()
cli_alert_info("righe per-studio: {nrow(ps)}")

# ⚠️ CORREZIONE DI UN MIO ERRORE DI MISURA. `per_study_de` ha una riga per
# BRACCIO, non per studio: TGF-beta1 ha 83 righe mediane per 49 studi. Il ramo
# rem_group collassa i bracci dentro lo studio (.collapse_arms_by_study,
# inverse-variance a effetti fissi) PRIMA del random-effects. Pesare i bracci
# invece degli studi misura un'altra cosa. Qui si collassa prima, e si verifica
# che il conteggio risultante coincida col k_effective del pool.
collassato <- ps |>
  filter(!is.na(SE), SE > 0) |>
  group_by(cluster_id, gene_id, study_id) |>
  summarise(SE_studio = sqrt(1 / sum(1 / SE^2)), .groups = "drop")

j <- collassato |>
  inner_join(cp, by = c("cluster_id", "gene_id")) |>
  filter(!is.na(tau2)) |>
  mutate(w = 1 / (SE_studio^2 + tau2))

# Controllo che l'unita' sia quella giusta: n studi collassati == k_effective.
verifica <- j |>
  group_by(cluster_id, gene_id) |>
  summarise(n_studi = n(), k_eff = unique(k_effective), .groups = "drop")
disallineati <- sum(verifica$n_studi != verifica$k_eff)
cli_alert_info(paste0(
  "verifica unita': geni con n_studi collassati != k_effective: ",
  disallineati, " su ", nrow(verifica),
  sprintf(" (%.2f%%)", 100 * disallineati / nrow(verifica))))

# --- numero efficace di studi (Kish), per gene poi mediana per cluster -------
per_gene <- j |>
  group_by(cluster_id, gene_id) |>
  summarise(
    k_reale  = n(),
    k_kish   = sum(w)^2 / sum(w^2),
    quota_top1 = max(w) / sum(w),
    quota_top2 = sum(sort(w, decreasing = TRUE)[1:2], na.rm = TRUE) / sum(w),
    .groups = "drop"
  )

per_cluster <- per_gene |>
  group_by(cluster_id) |>
  summarise(
    n_geni_sig    = n(),
    k_reale_med   = median(k_reale),
    k_kish_med    = round(median(k_kish), 1),
    quota_top1_med = round(100 * median(quota_top1), 1),
    quota_top2_med = round(100 * median(quota_top2), 1),
    .groups = "drop"
  ) |>
  left_join(sel |> select(cluster_id, label_paper), by = "cluster_id") |>
  mutate(perdita_pct = round(100 * (1 - k_kish_med / k_reale_med), 0)) |>
  arrange(desc(k_reale_med))

cli_h2("Numero efficace di studi (Kish) sui geni significativi")
print(as.data.frame(per_cluster |>
  select(label_paper, k_reale_med, k_kish_med, perdita_pct,
         quota_top1_med, quota_top2_med)), row.names = FALSE)

cat("\nLegenda: k_kish_med = studi 'efficaci' mediani; perdita_pct = quanto si\n",
    "perde rispetto al k nominale; quota_top1/2 = % di peso dei primi 1 e 2 studi.\n", sep = "")

write.csv(per_cluster, file.path(OUTDIR, "dominanza-forest.csv"), row.names = FALSE)
cli_alert_success("Scritta dominanza-forest.csv")
