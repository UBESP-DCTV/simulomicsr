#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-inversioni-194/50-effetto-su-HCC.R
# Che cosa cambia in «Carcinoma, Hepatocellular» col segno di GSE144269 raddrizzato:
# stessa catena di produzione (.collapse_arms_by_study + .pool_rem_cluster). Prima si
# riproduce il deliverable, poi si inverte il solo logFC di quello studio. Solo misura:
# il deliverable non viene toccato.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(arrow); library(dplyr); devtools::load_all(".", quiet = TRUE) })
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"; CID <- "cgroup_L5_bd19fe42"
x <- as.data.frame(open_dataset(file.path(POOL, "per_study_de.parquet")) |> filter(cluster_id == CID) |> collect())
vero <- as.data.frame(open_dataset(file.path(POOL, "cluster_pooled.parquet")) |> filter(cluster_id == CID) |> collect())
gcol <- intersect(c("gene_id", "gene"), names(vero))[1]
sig <- function(p) sum(p$FDR_BH_within_cluster < 0.05, na.rm = TRUE)
pool <- function(d) as.data.frame(.pool_rem_cluster(.collapse_arms_by_study(d)))
A <- pool(x); B <- x; B$logFC[B$study_id == "GSE144269"] <- -B$logFC[B$study_id == "GSE144269"]
if ("t_stat" %in% names(B)) B$t_stat[B$study_id == "GSE144269"] <- -B$t_stat[B$study_id == "GSE144269"]
B <- pool(B)
cat(sprintf("deliverable su disco: geni %d, significativi %d\n", nrow(vero), sig(vero)))
cat(sprintf("riprodotto:           geni %d, significativi %d\n", nrow(A), sig(A)))
cat(sprintf("segno raddrizzato:    geni %d, significativi %d\n", nrow(B), sig(B)))
g <- intersect(names(A), c("gene_id", "gene"))[1]; m <- match(A[[g]], B[[g]])
cat(sprintf("I2 mediano: %.1f -> %.1f\n", median(A$I2, na.rm = TRUE), median(B$I2, na.rm = TRUE)))
cat(sprintf("Spearman logFC poolati, prima contro dopo: %.2f\n", cor(A$logFC_pool, B$logFC_pool[m], method = "spearman", use = "complete.obs")))
if ("gene_symbol" %in% names(x)) {
  simb <- x$gene_symbol[match(A[[g]], x$gene_id)]
  for (s in c("GPC3","AFP","MKI67","TOP2A","CDC20","CCNB1","CYP2E1","CYP3A4","ALB","APOA1","CRP","SAA1")) {
    i <- which(simb == s)[1]; if (is.na(i)) next
    cat(sprintf("  %-7s logFC %+.2f FDR %.3g  ->  %+.2f FDR %.3g\n", s, A$logFC_pool[i], A$FDR_BH_within_cluster[i], B$logFC_pool[m[i]], B$FDR_BH_within_cluster[m[i]]))
  }
}
