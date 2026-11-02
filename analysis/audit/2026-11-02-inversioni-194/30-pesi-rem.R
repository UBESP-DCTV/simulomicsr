#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-inversioni-194/30-pesi-rem.R
# Peso REM vero degli studi dei gruppi indicati (bracci collassati, poi tau^2, poi
# quota dentro il gene: .compute_study_gene_weights), non l'approssimazione 1/SE^2.
# Uso: GRUPPI=<cluster_id,...> Rscript analysis/audit/2026-11-02-inversioni-194/30-pesi-rem.R [file.csv]
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(arrow); library(data.table); devtools::load_all(".", quiet = TRUE) })
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
G <- strsplit(Sys.getenv("GRUPPI"), ",")[[1]]; stopifnot(length(G) > 0L)
x <- as.data.table(read_parquet(file.path(POOL, "per_study_de.parquet"), col_select = c("cluster_id", "study_id", "gene_id", "SE")))
x <- x[cluster_id %in% G & is.finite(SE) & SE > 0]
t2 <- as.data.table(read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id", "gene_id", "tau2")))
t2 <- t2[cluster_id %in% G]
w <- as.data.table(.compute_study_gene_weights(as.data.frame(x), as.data.frame(t2)))
o <- w[, .(quota_mediana = median(quota), n_geni = .N), by = .(cluster_id, study_id)][order(cluster_id, -quota_mediana)]
print(o[, .(cluster_id, study_id, quota_pct = round(100 * quota_mediana, 1), n_geni)])
a <- commandArgs(TRUE); if (length(a)) fwrite(o, a[1])
