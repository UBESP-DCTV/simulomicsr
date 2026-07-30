# analysis/audit/2026-07-31-layer-b-v13/30-k-per-gene.R
# Quanto del segnale di ogni meta-analisi viene da geni misurati in POCHI studi?
#
# Nato da un'osservazione sul bundle DHT: la tabella dei top geni, ordinata per
# FDR, e' guidata da geni con k=2, 3, 5, 6 su 23 studi, mentre i bersagli noti
# del recettore androgenico (KLK3, TMPRSS2, FKBP5, NKX3-1) non compaiono.
# Con k=2 il random-effects non puo' stimare tau^2, lo pone a 0, e l'errore
# standard collassa: il gene sembra piu' certo di quanto sia.
#
# Qui si misura, non si suppone. Su TUTTI e 12 i case study.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/30-k-per-gene.R

suppressPackageStartupMessages({
  library(dplyr)
  library(cli)
})

STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
SEL    <- "analysis/layer-b-selection-v13.csv"
OUTDIR <- "analysis/audit/2026-07-31-layer-b-v13"

sel <- read.csv(SEL, stringsAsFactors = FALSE)

cp <- arrow::open_dataset(file.path(STAGE4, "cluster_pooled.parquet")) |>
  filter(cluster_id %in% sel$cluster_id) |>
  select(cluster_id, gene_symbol, gene_id, logFC_pool, SE_pool,
         FDR_BH_within_cluster, k_effective, tau2, I2) |>
  collect()

cli_alert_info("righe lette: {nrow(cp)}")

# --- 1. quota del segnale che viene da k basso -------------------------------
tab <- cp |>
  group_by(cluster_id) |>
  summarise(
    k_max        = max(k_effective, na.rm = TRUE),
    n_sig        = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
    sig_k2       = sum(FDR_BH_within_cluster < 0.05 & k_effective == 2, na.rm = TRUE),
    sig_k_lt_half = sum(FDR_BH_within_cluster < 0.05 &
                          k_effective < 0.5 * max(k_effective, na.rm = TRUE), na.rm = TRUE),
    sig_k_full   = sum(FDR_BH_within_cluster < 0.05 &
                         k_effective == max(k_effective, na.rm = TRUE), na.rm = TRUE),
    tau2_zero_k2 = sum(k_effective == 2 & tau2 == 0, na.rm = TRUE),
    n_k2         = sum(k_effective == 2, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    pct_sig_k2        = round(100 * sig_k2 / n_sig, 1),
    pct_sig_k_lt_half = round(100 * sig_k_lt_half / n_sig, 1),
    pct_sig_k_full    = round(100 * sig_k_full / n_sig, 1)
  ) |>
  left_join(sel |> select(cluster_id, label_paper), by = "cluster_id") |>
  arrange(desc(k_max))

cli_h2("Quota dei geni significativi per k")
print(as.data.frame(tab |> select(label_paper, k_max, n_sig,
                                  pct_sig_k2, pct_sig_k_lt_half, pct_sig_k_full)),
      row.names = FALSE)

# --- 2. i primi 20 per FDR: con che k? ---------------------------------------
cli_h2("Primi 20 geni per FDR: mediana del k, e quanti sotto meta' del k pieno")
top20 <- cp |>
  filter(!is.na(FDR_BH_within_cluster)) |>
  group_by(cluster_id) |>
  mutate(k_max = max(k_effective, na.rm = TRUE)) |>
  slice_min(FDR_BH_within_cluster, n = 20, with_ties = FALSE) |>
  summarise(
    k_max        = unique(k_max),
    k_mediano_top20 = median(k_effective, na.rm = TRUE),
    n_sotto_meta = sum(k_effective < 0.5 * unique(k_max), na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(sel |> select(cluster_id, label_paper), by = "cluster_id") |>
  arrange(desc(k_max))
print(as.data.frame(top20 |> select(label_paper, k_max, k_mediano_top20, n_sotto_meta)),
      row.names = FALSE)

# --- 3. dove stanno i bersagli attesi ----------------------------------------
# Geni scelti dalla letteratura PRIMA di guardare (stessi del controllo
# biologico del 2026-07-30, finding §7bis).
attesi <- list(
  cgroup_L5_930c8dcf = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1"),   # DHT
  cgroup_L5_c0d1d837 = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1"),   # enzalutamide
  cgroup_L5_2e16719f = c("SERPINE1", "CCN2", "SMAD7", "JUNB", "TGFBI", "COL1A1"),
  cgroup_L5_c548d053 = c("TNF", "IL6", "IL1B", "CXCL8", "CCL2", "NFKBIA"),
  cgroup_L5_871ae09e = c("IFIT1", "ISG15", "IFIT3", "CXCL10", "OAS1", "MX1"),
  cgroup_L5_87c40ebb = c("GBP1", "CXCL9", "CXCL10", "STAT1", "IDO1", "GBP5")
)

cli_h2("Rango dei bersagli attesi (ordinamento per FDR crescente)")
righe <- list()
for (cid in names(attesi)) {
  sub <- cp |>
    filter(cluster_id == cid, !is.na(FDR_BH_within_cluster)) |>
    arrange(FDR_BH_within_cluster)
  sub$rango <- seq_len(nrow(sub))
  lab <- sel$label_paper[match(cid, sel$cluster_id)]
  for (g in attesi[[cid]]) {
    r <- sub[which(sub$gene_symbol == g)[1L], ]
    if (nrow(r) == 0L || is.na(r$gene_symbol)) {
      cat(sprintf("  %-42s %-9s ASSENTE dal pool\n", lab, g)); next
    }
    cat(sprintf("  %-42s %-9s rango %5d/%5d  logFC=%+6.2f  k=%2d  I2=%5.1f  FDR=%.1e\n",
                lab, g, r$rango, nrow(sub), r$logFC_pool, r$k_effective, r$I2,
                r$FDR_BH_within_cluster))
    righe[[length(righe) + 1L]] <- data.frame(
      cluster_id = cid, label_paper = lab, gene = g, rango = r$rango,
      n_geni = nrow(sub), logFC = r$logFC_pool, k = r$k_effective,
      I2 = r$I2, FDR = r$FDR_BH_within_cluster, stringsAsFactors = FALSE)
  }
}

write.csv(tab, file.path(OUTDIR, "k-per-gene-quote.csv"), row.names = FALSE)
write.csv(do.call(rbind, righe), file.path(OUTDIR, "bersagli-attesi-rango.csv"),
          row.names = FALSE)
cli_alert_success("Scritte k-per-gene-quote.csv e bersagli-attesi-rango.csv")
