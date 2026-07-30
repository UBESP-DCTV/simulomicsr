#!/usr/bin/env Rscript
# 80-heatmap-verifica.R --- la heatmap del case study mostra biologia o studi?
#
# Nella heatmap del DHT alcune righe (AFP, COL22A1, RIMBP2, NSG2) hanno una
# banda rossa verticale confinata a poche colonne e vaste zone piatte. Sono
# proprio i geni con k basso (2-6 studi su 23). Ipotesi: quei geni sono
# espressi/misurati solo in pochi studi, e la banda e' lo studio, non l'effetto.
#
# Si verifica con i conteggi veri, non guardando l'immagine: per i 30 geni della
# tabella si misura (a) la quota di campioni a conteggio zero, (b) quanta
# varianza spiega lo STUDIO e quanta il TRATTAMENTO (R^2 di un modello a un
# fattore per volta, sui log-CPM).
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/80-heatmap-verifica.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE); library(dplyr); library(cli)
})

STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
STAGE3 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
H5     <- "analysis/input/human_gene_v2.5.h5"
OUTDIR <- "analysis/audit/2026-07-31-layer-b-v13"

sel <- read.csv("analysis/layer-b-selection-v13.csv", stringsAsFactors = FALSE)
CIDS <- c("cgroup_L5_930c8dcf", "cgroup_L5_c0d1d837", "cgroup_L5_87c40ebb",
          "cgroup_L5_2e16719f")

s3 <- load_stage3(STAGE3)
meta <- s3$clusters[s3$clusters$cluster_id %in% CIDS, ]
meta$method <- "rem_group"
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
disp <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
  meta, s3$assignments, s2, n_min = 2L)
rm(s2); gc(verbose = FALSE)

# stessa fetch che usa build_layer_b_results (R/layer-b-build.R:46): riusa la
# cache del Layer A, non rilegge l'H5 se non serve.
fetch <- function(g, s) simulomicsr:::.fetch_counts_cached(g, s, h5_path = H5)

risultati <- list()
for (cid in CIDS) {
  lab <- sel$label_paper[match(cid, sel$cluster_id)]
  # 30 geni della tabella, stesso ordinamento del Layer B (FDR crescente)
  top <- arrow::open_dataset(file.path(STAGE4, "cluster_pooled.parquet")) |>
    filter(cluster_id == cid, !is.na(FDR_BH_within_cluster)) |>
    select(gene_id, gene_symbol, FDR_BH_within_cluster, k_effective) |>
    collect() |> arrange(FDR_BH_within_cluster) |> head(30)

  campioni <- do.call(rbind, lapply(disp[[cid]], function(it) data.frame(
    sample_id = c(it$treated, it$control), study_id = it$study_id,
    treatment = c(rep("treated", length(it$treated)), rep("control", length(it$control))),
    stringsAsFactors = FALSE)))
  campioni <- campioni[!duplicated(campioni$sample_id), ]

  cm <- simulomicsr:::.assemble_cluster_counts(cid, campioni, fetch)
  counts <- cm$counts; md <- cm$metadata

  # Si replica ESATTAMENTE la catena della heatmap (R/layer-b-plot-heatmap.R):
  # VST -> ComBat(batch=studio, mod=~trattamento). Misurare sul log-CPM grezzo
  # sovrastimerebbe la quota dello studio, perche' la figura e' gia' corretta.
  cnt <- round(as.matrix(counts))
  vst <- tryCatch(DESeq2::varianceStabilizingTransformation(cnt, blind = TRUE),
                  error = function(e) log2(t(t(cnt) / pmax(colSums(cnt), 1)) * 1e6 + 1))
  g <- intersect(top$gene_id, rownames(vst))
  vst_sub <- vst[g, , drop = FALSE]
  combat <- tryCatch(
    sva::ComBat(dat = vst_sub, batch = md$study_id,
                mod = stats::model.matrix(~ treatment, data = md)),
    error = function(e) { cli_alert_warning("ComBat fallito: {conditionMessage(e)}"); vst_sub })

  righe <- lapply(g, function(gg) {
    zero <- mean(counts[gg, ] == 0)
    r2 <- function(y, f) {
      if (length(unique(f)) < 2L || stats::sd(y) == 0) return(NA_real_)
      summary(stats::lm(y ~ factor(f)))$r.squared
    }
    data.frame(gene = top$gene_symbol[match(gg, top$gene_id)],
               k = top$k_effective[match(gg, top$gene_id)],
               zeri_pct = round(100 * zero, 1),
               R2_studio_pre = round(r2(vst_sub[gg, ], md$study_id), 2),
               R2_studio = round(r2(combat[gg, ], md$study_id), 2),
               R2_trattamento = round(r2(combat[gg, ], md$treatment), 2),
               stringsAsFactors = FALSE)
  })
  df <- do.call(rbind, righe)
  df$cluster <- lab
  risultati[[cid]] <- df

  cli_h2(lab)
  cat(sprintf("  campioni=%d  studi=%d  geni trovati=%d/30\n",
              ncol(counts), length(unique(md$study_id)), length(g)))
  cat(sprintf("  R2 mediano STUDIO: pre-ComBat=%.2f  post-ComBat=%.2f | TRATTAMENTO=%.2f\n",
              median(df$R2_studio_pre, na.rm = TRUE),
              median(df$R2_studio, na.rm = TRUE),
              median(df$R2_trattamento, na.rm = TRUE)))
  cat(sprintf("  geni con >50%% campioni a zero: %d/30 | k mediano dei 30: %.0f\n",
              sum(df$zeri_pct > 50), median(df$k)))
  peggio <- df[order(-df$zeri_pct), ][1:6, ]
  for (i in seq_len(nrow(peggio))) {
    cat(sprintf("    %-14s k=%2d zeri=%5.1f%% R2_studio=%.2f R2_tratt=%.2f\n",
                peggio$gene[i], peggio$k[i], peggio$zeri_pct[i],
                peggio$R2_studio[i], peggio$R2_trattamento[i]))
  }
}

out <- do.call(rbind, risultati)
write.csv(out, file.path(OUTDIR, "heatmap-verifica.csv"), row.names = FALSE)
cli_alert_success("Scritta heatmap-verifica.csv")
