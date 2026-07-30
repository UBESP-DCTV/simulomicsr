#!/usr/bin/env Rscript
# 90-malattie-modello-vs-paziente.R --- tutti i gruppi di malattia, letti col
# metro che sto per applicare a Parkinson.
#
# Il Layer B ha mostrato che il gruppo Parkinson mescola cervello post-mortem di
# paziente e neuroni derivati da iPSC (modello cellulare), col modello che pesa
# il 73%. Se questo squalifica Parkinson, deve squalificare chiunque altro abbia
# la stessa forma: un verdetto applicato a un gruppo solo perche' e' quello che
# mi e' capitato sotto gli occhi non e' una regola, e' una lista.
#
# Qui si stampano i membri POOLATI, a testo intero, di TUTTI i gruppi di
# malattia (entita' MeSH:) del deliverable, per leggerli uno per uno.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/90-malattie-modello-vs-paziente.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
POOL   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT    <- "analysis/audit/2026-07-31-layer-b-v13"

d <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
dom <- read.csv(file.path(OUT, "dominanza-tutti-191.csv"), stringsAsFactors = FALSE)
mal <- d[grepl("^MeSH:", d$contrast_entity), ]
mal$k_kish <- dom$k_kish_med[match(mal$cluster_id, dom$cluster_id)]
mal$top1   <- dom$quota_top1_med[match(mal$cluster_id, dom$cluster_id)]
mal <- mal[order(-mal$k_effective), ]
cat("gruppi di malattia (MeSH) nel deliverable poolato:", nrow(mal), "\n")

asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% mal$cluster_id, ]
asg$study <- sub("__.*$", "", asg$record_id)

sp <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet")) |>
  dplyr::filter(cluster_id %in% mal$cluster_id) |>
  dplyr::distinct(cluster_id, study_id) |> dplyr::collect()
studi_pool <- split(sp$study_id, sp$cluster_id)

# peso per studio, per marcare accanto a ogni membro quanto pesa davvero
cp <- arrow::open_dataset(file.path(POOL, "cluster_pooled.parquet")) |>
  dplyr::filter(cluster_id %in% mal$cluster_id, FDR_BH_within_cluster < 0.05) |>
  dplyr::select(cluster_id, gene_id, tau2) |> dplyr::collect()
ps <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet")) |>
  dplyr::filter(cluster_id %in% mal$cluster_id) |>
  dplyr::select(cluster_id, study_id, gene_id, SE) |> dplyr::collect()
pesi <- ps |>
  dplyr::filter(!is.na(SE), SE > 0) |>
  dplyr::group_by(cluster_id, gene_id, study_id) |>
  dplyr::summarise(SEs = sqrt(1 / sum(1 / SE^2)), .groups = "drop") |>
  dplyr::inner_join(cp, by = c("cluster_id", "gene_id")) |>
  dplyr::filter(!is.na(tau2)) |>
  dplyr::mutate(w = 1 / (SEs^2 + tau2)) |>
  dplyr::group_by(cluster_id, gene_id) |>
  dplyr::mutate(q = w / sum(w)) |> dplyr::ungroup() |>
  dplyr::group_by(cluster_id, study_id) |>
  dplyr::summarise(quota = median(q), .groups = "drop")
rm(ps, cp); gc(verbose = FALSE)

s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", study$series_id, cmp$comparison_id)
    if (!rid %in% need) next
    t <- rgl[[cmp$treated_group]]; c <- rgl[[cmp$control_group]]
    if (is.null(t) || is.null(c)) next
    assign(rid, list(tl = lab_of(t, cmp$treated_group), cl = lab_of(c, cmp$control_group)),
           envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

# controllo di cecita' dello strumento
tutte <- unlist(lapply(ls(lab), function(k) { e <- get(k, envir = lab); c(e$tl, e$cl) }))
cat("etichette:", length(tutte), "| max caratteri:", max(nchar(tutte)),
    "| >=80 char:", sum(nchar(tutte) >= 80), "| nessun troncamento applicato\n")

zz <- file(file.path(OUT, "malattie-membri.txt"), open = "wt")
sink(zz)
cat("TUTTI I GRUPPI DI MALATTIA (MeSH) DEL DELIVERABLE POOLATO — TESTO INTERO\n")
cat("Domanda: il gruppo mescola tessuto/campione di paziente con un MODELLO in vitro\n")
cat("(iPSC, linea cellulare, organoide)? Accanto a ogni studio, il suo peso nel REM.\n")
for (i in seq_len(nrow(mal))) {
  cid <- mal$cluster_id[i]
  dentro <- unique(studi_pool[[cid]])
  righe <- asg[asg$cluster_id == cid, ]
  cat("\n\n=============================================================\n")
  cat(sprintf("[%02d/%02d] %s (%s)\n", i, nrow(mal),
              mal$contrast_entity_label[i], mal$contrast_entity[i]))
  cat(sprintf("  k=%d | studi efficaci=%.1f | studio piu' pesante=%.1f%% | n_sig=%d | I2=%.1f | %s\n",
              mal$k_effective[i], mal$k_kish[i], 100 * mal$top1[i],
              mal$n_sig[i], mal$I2_med[i], mal$coherence_verdict[i]))
  vis <- character(0)
  for (j in seq_len(nrow(righe))) {
    e <- get0(righe$record_id[j], envir = lab, inherits = FALSE)
    if (is.null(e)) next
    if (!(righe$study[j] %in% dentro)) next
    key <- paste(righe$study[j], e$tl, e$cl)
    if (key %in% vis) next
    vis <- c(vis, key)
    q <- pesi$quota[pesi$cluster_id == cid & pesi$study_id == righe$study[j]]
    qs <- if (length(q) == 1L) sprintf("[%4.1f%%]", 100 * q) else "[  ? ]"
    cat(sprintf("   %-10s %s %s\n          => %s\n", righe$study[j], qs, e$tl, e$cl))
  }
}
sink(); close(zz)
cat("scritto", file.path(OUT, "malattie-membri.txt"), "\n")
