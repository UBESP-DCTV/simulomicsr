#!/usr/bin/env Rscript
# S8b: aggiunte non depositate. Le tabelle di correzione dei nomi abbassano la stima? Quante meta-analisi toccherebbe il corpus? Quanto manca?
suppressPackageStartupMessages({ library(arrow); library(data.table) })
DIR <- "analysis/audit/2026-11-04-S8b-prova"; sink(file.path(DIR, "82-out.txt"), split = TRUE)
S3R <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"; S3A <- "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159"; S3P <- readLines(file.path(DIR, "stadio3-prova.txt"))
NUOVI <- readLines(file.path(DIR, "campione-nuovi.txt")); A3 <- readLines("analysis/audit/2026-08-16-A3/A3-studi.txt")
coppie <- function(d) { cl <- as.data.table(readRDS(file.path(d, "clusters.rds")))[mode == "cgroup", .(cluster_id, e = contrast_entity, v = contrast_direction, c = contrast_control_key)]
  a <- as.data.table(read_parquet(file.path(d, "assignments.parquet"), col_select = c("record_id", "cluster_id", "mode")))[mode == "cgroup"]; a[, s := sub("__.*$", "", record_id)]
  x <- unique(merge(a[, .(s, cluster_id)], cl, by = "cluster_id")); x[, ck := paste(e, v, c, sep = "||")]; x }
PR <- coppie(S3R); PA <- coppie(S3A); PP <- coppie(S3P)
nom <- function(x) mean(grepl("^(STR|UNK)", x$e))
cat("== QUOTA DI ENTITA' SENZA IDENTIFICATORE (STR o UNK), per coppia ==\n")
cat(sprintf("2.566 studi: run vecchio %.1f%%, run di agosto %.1f%%\n6.000 studi: run vecchio %.1f%% (%d coppie), prova %.1f%% (%d coppie)\n", 100 * nom(PR[s %in% A3]), 100 * nom(PA[s %in% A3]), 100 * nom(PA[s %in% NUOVI]), nrow(PA[s %in% NUOVI]), 100 * nom(PP[s %in% NUOVI]), nrow(PP[s %in% NUOVI])))
sim <- function(o, n, st) { a <- o[s %in% st, .(a = paste(sort(unique(ck)), collapse = "|")), by = s]; b <- n[s %in% st, .(b = paste(sort(unique(ck)), collapse = "|")), by = s]; m <- merge(a, b, by = "s"); c(comuni = nrow(m), stesse = sum(m$a == m$b)) }
s1 <- sim(PR, PA, A3); s2 <- sim(PA, PP, NUOVI)
cat(sprintf("\nstudi con le stesse chiavi dopo la rigenerazione, fra chi ha coppie nei due run:\n2.566 studi: %d su %d = %.1f%%\n6.000 studi: %d su %d = %.1f%%\n", s1[2], s1[1], 100 * s1[2] / s1[1], s2[2], s2[1], 100 * s2[2] / s2[1]))
d <- as.data.table(readRDS("/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d/deliverable-annotato.rds"))
cat("\n== META-ANALISI TOCCATE, proporzionale ai loro studi ==\n")
tot <- 12L; n <- d$n_studi_poolati; ok <- function(T) sum(1 - exp(-T * n / sum(n)))
# trova il numero di arrivi che nel campione ne tocca 12, poi lo scala
Ts <- uniroot(function(T) ok(T) - tot, c(1, 500))$root; cat(sprintf("arrivi coerenti con 12 toccate nel campione: %.1f; scalati per 3,638: %.1f; meta-analisi toccate nel corpus: %.0f su 194\n", Ts, Ts * 21828 / 6000, ok(Ts * 21828 / 6000)))
sink()
