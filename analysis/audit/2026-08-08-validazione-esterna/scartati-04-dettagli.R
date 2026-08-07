suppressPackageStartupMessages({library(arrow); library(dplyr)})
S4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3 <- "/home/user/simulomicsr/analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
OUT<- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"
np <- as.data.frame(readRDS(file.path(S4,"non_processable.rds")))
del<- as.data.frame(readRDS(file.path(S4,"deliverable-annotato.rds")))
cl <- as.data.frame(readRDS(file.path(S3,"clusters.rds")))
sc <- merge(np, cl, by="cluster_id")

cat("=== L'UNICA ENTITA' CONDIVISA FRA I 137 E LE 214 ===\n")
sh <- intersect(sc$contrast_entity, del$contrast_entity); cat("entita':", sh, "\n\n")
cat("-- lato SCARTATO --\n")
print(sc[sc$contrast_entity %in% sh, c("cluster_id","qc_final_k","k","n_studies",
     "contrast_entity","contrast_direction","contrast_control_key","canonical_name")])
cat("\n-- lato DELIVERABLE --\n")
print(del[del$contrast_entity %in% sh, c("cluster_id","k_effective","n_sig",
     "contrast_entity","contrast_direction","contrast_control_key","contrast_entity_label")])

cat("\n=== DISTRIBUZIONE DEI 137 PER k SCARTATO E DIREZIONE ===\n")
print(table(qc_final_k=sc$qc_final_k, direzione=sc$contrast_direction))
cat("\nk stage3 (membri pre-QC) dei 137: mediana", median(sc$k), "range",
    min(sc$k), "-", max(sc$k), " somma", sum(sc$k), "\n")

cat("\n=== TOP 20 SCARTATI PER STUDI-SLOT SOPRAVVISSUTI (tutti k=2) ===\n")
t <- read.csv(file.path(OUT,"scartati-137-gruppi.csv"))
print(head(t[order(-t$qc_final_k, -t$n_gse_indipendenti),
   c("cluster_id","qc_final_k","n_membri_preqc","contrast_entity","canonical_name",
     "n_gse_indipendenti","liv")], 20))
