suppressPackageStartupMessages({library(arrow); library(dplyr)})
S4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3 <- "/home/user/simulomicsr/analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"

np <- readRDS(file.path(S4, "non_processable.rds"))
cat("== non_processable ==\n"); print(dim(np)); print(names(np)); print(head(as.data.frame(np),3))
cat("\ntabella qc_final_k:\n"); print(table(np$qc_final_k, useNA="ifany"))
cat("somma qc_final_k:", sum(np$qc_final_k), "\n")
cat("reason unici (prefisso):", length(unique(sub(":.*","",np$reason))), unique(sub(":.*","",np$reason)), "\n")

del <- readRDS(file.path(S4, "deliverable-annotato.rds"))
cat("\n== deliverable ==\n"); print(dim(del)); print(names(del))
print(head(as.data.frame(del)[,1:min(8,ncol(del))],2))

cl <- readRDS(file.path(S3, "clusters.rds"))
cat("\n== clusters stage3 ==\n"); print(dim(cl)); print(names(cl))

asg <- arrow::open_dataset(file.path(S3,"assignments.parquet"))
cat("\n== assignments schema ==\n"); print(asg$schema)

psd <- arrow::open_dataset(file.path(S4,"per_study_de.parquet"))
cat("\n== per_study_de schema ==\n"); print(psd$schema)
