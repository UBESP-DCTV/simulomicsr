# analysis/p5-stage4-debug-problemB-clustersize.R
# DEBUGGING Problema B (OOM) — passo 1: dimensione reale dell'input dream
# per OGNI cluster Layer A.
#
# Il killer dell'OOM e' il cluster piu' grande processato da .run_dream_mega.
# - mega       : n input = n sample del group cluster.
# - mega_aug   : n input = n righe metadata (pair + baseline pool post-dedup),
#                gia' calcolato dallo scan (colonna n_meta).
#
# Usa checkpoint + scan result. Stima anche il footprint memoria della count
# matrix e del voom object per il cluster top.
#
# Usage: Rscript analysis/p5-stage4-debug-problemB-clustersize.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })

cli_h1("Problema B — dimensione input dream per cluster Layer A")

ck <- readRDS("analysis/p5-stage4-debug-checkpoint.rds")
elig <- ck$elig; stage3_enriched <- ck$stage3_enriched
scan_df <- readRDS("analysis/p5-stage4-debug-scan-all-mega-aug-result.rds")

# ---- mega clusters: n sample dal group cluster -----------------------------
mega_ids <- elig$cluster_id[elig$method == "mega"]
se_idx <- match(mega_ids, stage3_enriched$cluster_id)
mega_n <- vapply(seq_along(mega_ids), function(k) {
  j <- se_idx[k]
  if (is.na(j)) return(NA_integer_)
  length(unlist(stage3_enriched$sample_ids[[j]]))
}, integer(1L))
mega_tbl <- data.frame(cluster_id = mega_ids, method = "mega",
                        level = elig$level[match(mega_ids, elig$cluster_id)],
                        n_input = mega_n, stringsAsFactors = FALSE)

# ---- mega_aug clusters: n_meta dallo scan ----------------------------------
aug_tbl <- data.frame(cluster_id = scan_df$cid, method = "mega_aug",
                       level = scan_df$level, n_input = scan_df$n_meta,
                       stringsAsFactors = FALSE)

all_tbl <- rbind(mega_tbl, aug_tbl)
all_tbl <- all_tbl[!is.na(all_tbl$n_input), ]

cli_h2("Distribuzione n_input (sample passati a dream)")
cli_alert_info("mega clusters    : {nrow(mega_tbl)}")
cli_alert_info("mega_aug clusters: {sum(!is.na(aug_tbl$n_input))}")
cat("\n-- summary n_input (tutti Layer A) --\n")
print(summary(all_tbl$n_input))
cat("\n-- summary n_input mega --\n")
print(summary(mega_tbl$n_input))
cat("\n-- summary n_input mega_aug --\n")
print(summary(aug_tbl$n_input[!is.na(aug_tbl$n_input)]))
cat("\n-- quantili 0.5/0.9/0.95/0.99/1.0 --\n")
print(quantile(all_tbl$n_input, c(.5, .9, .95, .99, 1), na.rm = TRUE))

cat("\n-- TOP 20 cluster per n_input --\n")
top <- all_tbl[order(-all_tbl$n_input), ][1:20, ]
print(top, row.names = FALSE)

n_big <- sum(all_tbl$n_input > 1000L)
n_huge <- sum(all_tbl$n_input > 3000L)
cli_alert_info("Cluster con n_input > 1000: {n_big}")
cli_alert_info("Cluster con n_input > 3000: {n_huge}")

# ---- Stima footprint memoria -----------------------------------------------
h5_path <- "analysis/input/human_gene_v2.5.h5"
n_genes <- length(rhdf5::h5read(h5_path, "meta/genes/symbol"))
cli_h2("Stima footprint memoria")
cli_alert_info("n geni ARCHS4 (pre-filterByExpr): {n_genes}")
n_max <- max(all_tbl$n_input)
counts_gb  <- n_genes * n_max * 4 / 1e9      # integer matrix
voomE_gb   <- n_genes * n_max * 8 / 1e9      # double matrix (E)
voomW_gb   <- n_genes * n_max * 8 / 1e9      # double matrix (weights)
cli_alert_info("cluster top n_input = {n_max}")
cli_alert_info("  count matrix integer  ~ {round(counts_gb,2)} GB")
cli_alert_info("  voom E + weights      ~ {round(voomE_gb + voomW_gb,2)} GB")
cli_alert_info("  base (counts+voom)    ~ {round(counts_gb + voomE_gb + voomW_gb,2)} GB")
cli_alert_danger("  x100 worker fork COW (worst case copia completa) ~ {round((counts_gb+voomE_gb+voomW_gb)*100,1)} GB")

saveRDS(all_tbl, "analysis/p5-stage4-debug-problemB-clustersize.rds")
cli_alert_success("Salvato analysis/p5-stage4-debug-problemB-clustersize.rds")
cli_h1("Problema B passo 1 completato")
