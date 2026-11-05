#!/usr/bin/env Rscript
# S8b: gli ingressi veri, dal re-pool della prova contro il deliverable. Attese: 00-previsioni.md, quarta aggiunta.
suppressPackageStartupMessages({ library(arrow); library(data.table) })
DIR <- "analysis/audit/2026-11-04-S8b-prova"
A3 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
PR <- sort(list.dirs("/mnt/micron/simulomicsr-prove/S8b/simulomicsr-stage4-v16", recursive = FALSE)); PR <- PR[length(PR)]
NUOVI <- readLines(file.path(DIR, "campione-nuovi.txt")); N <- length(NUOVI)
sink(file.path(DIR, "81-out.txt"), split = TRUE)
carica <- function(P) { d <- as.data.table(readRDS(file.path(P, "deliverable-annotato.rds"))); d[, ck := paste(contrast_entity, contrast_direction, contrast_control_key, sep = "||")]
  st <- as.data.table(open_dataset(file.path(P, "per_study_de.parquet")) |> dplyr::distinct(cluster_id, study_id) |> dplyr::collect()); st[, s := as.character(study_id)]; st <- merge(st[cluster_id %in% d$cluster_id, .(cluster_id, s)], d[, .(cluster_id, ck)], by = "cluster_id"); list(d = d, st = unique(st)) }
a <- carica(A3); p <- carica(PR); cat("re-pool della prova:", PR, "\n")
i40 <- fread("analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv"); i41 <- fread("analysis/audit/2026-11-03-S5-gate-e-insiemi/50-insieme-41.csv")
ck40 <- a$d[cluster_id %in% i40$cluster_id, ck]; ck41 <- a$d[cluster_id %in% i41$cluster_id, ck]
cat(sprintf("\nmeta-analisi: deliverable %d, prova %d; comuni %d; nuove %d; perse %d\n", nrow(a$d), nrow(p$d), length(intersect(a$d$ck, p$d$ck)), length(setdiff(p$d$ck, a$d$ck)), length(setdiff(a$d$ck, p$d$ck))))
cat("perse:", paste(setdiff(a$d$ck, p$d$ck), collapse = "; "), "\n")
ent <- unique(p$st[s %in% NUOVI, s]); ic <- binom.test(length(ent), N)$conf.int
cat(sprintf("\n== Q8 == studi nuovi davvero poolati: %d su %d = %.2f%% [%.2f; %.2f]; scalati su 21.828: %.0f [%.0f; %.0f]\n", length(ent), N, 100 * length(ent) / N, 100 * ic[1], 100 * ic[2], 21828 * length(ent) / N, 21828 * ic[1], 21828 * ic[2]))
ein <- p$st[s %in% NUOVI & ck %in% a$d$ck]; enu <- p$st[s %in% NUOVI & !(ck %in% a$d$ck)]
cat(sprintf("in meta-analisi esistenti: %d studi, %d meta-analisi; in meta-analisi nuove: %d studi, %d meta-analisi\n", uniqueN(ein$s), uniqueN(ein$ck), uniqueN(enu$s), uniqueN(enu$ck)))
uscite <- setdiff(a$st$s, p$st$s); cat(sprintf("studi poolati in agosto e non nella prova: %d\n", length(uscite)))
cat("\n== Q9 == meta-analisi nuove ==\n"); print(p$d[!(ck %in% a$d$ck), .(ck = substr(ck, 1, 60), k_effective, n_sig, k_kish = round(k_kish, 1), dominato)][order(-k_effective)])
cat("\n== composizione delle comuni ==\n")
ca <- a$st[, .(sa = paste(sort(s), collapse = "|"), ka = .N), by = ck]; cp <- p$st[, .(sp = paste(sort(s), collapse = "|"), kp = .N), by = ck]; m <- merge(ca, cp, by = "ck"); m[, cambia := sa != sp]
cat(sprintf("comuni con membri diversi: %d su %d; fra le 41: %d su %d; fra le 40: %d su %d; somma dei delta k: %d\n", sum(m$cambia), nrow(m), sum(m$cambia & m$ck %in% ck41), sum(m$ck %in% ck41), sum(m$cambia & m$ck %in% ck40), sum(m$ck %in% ck40), sum(m$kp - m$ka)))
dd <- merge(a$d[, .(ck, ka = k_kish, doma = dominato, qa = quota_top1)], p$d[, .(ck, kb = k_kish, domb = dominato, qb = quota_top1)], by = "ck")
cat(sprintf("dominate: deliverable %d, prova sulle comuni %d; passano da dominata a non dominata %d, al contrario %d\n", sum(dd$doma, na.rm = TRUE), sum(dd$domb, na.rm = TRUE), sum(dd$doma & !dd$domb, na.rm = TRUE), sum(!dd$doma & dd$domb, na.rm = TRUE)))
fwrite(m[cambia == TRUE, .(ck, ka, kp)][order(-kp)], file.path(DIR, "81-comuni-cambiate.csv"))
sink()
