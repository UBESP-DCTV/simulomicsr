suppressPackageStartupMessages({library(arrow); library(dplyr)})
S4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
np <- readRDS(file.path(S4, "non_processable.rds"))
psd <- arrow::open_dataset(file.path(S4,"per_study_de.parquet"))
# quali dei 137 cluster hanno righe in per_study_de?
d <- psd |> filter(cluster_id %in% np$cluster_id) |>
  select(cluster_id, study_id) |> distinct() |> collect()
cat("cluster scartati con righe in per_study_de:", length(unique(d$cluster_id)), "su", nrow(np), "\n")
cat("coppie (cluster,studio) distinte:", nrow(d), "\n")
k <- d |> count(cluster_id, name="k_psd")
m <- merge(as.data.frame(np)[,c("cluster_id","qc_final_k")], k, by="cluster_id", all.x=TRUE)
m$k_psd[is.na(m$k_psd)] <- 0L
cat("\nconfronto qc_final_k vs n studi in per_study_de:\n")
print(table(qc_final_k=m$qc_final_k, k_per_study_de=m$k_psd))
cat("\naccordo esatto:", sum(m$qc_final_k==m$k_psd), "/", nrow(m), "\n")
saveRDS(d, "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna/scartati-psd-cluster-studio.rds")
