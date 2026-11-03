#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/70-senza-dominante.R
# P14-P15: togliendo lo studio che pesa di piu', i geni significativi restano? Tutte le 173, con T1.
# Non vede un bias concorde: vede solo gli studi discordanti.
# Uso: WORKERS=48 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/70-senza-dominante.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
M <- readRDS(file.path(PES5, "quadro-194.rds"))[in173 == TRUE]
DIRS <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"
r1 <- as.data.table(read_parquet(file.path(PES5, "rem-194-T1.parquet")))[cluster_id %in% M$cluster_id]
setkey(r1, cluster_id)
lavoro <- function(i) {
  g <- M$cluster_id[i]; dom <- M$dom1[i]
  # Un gruppo senza geni significativi non ha uno studio dominante (schizophrenia): si registra.
  if (is.na(dom) || !nzchar(dom)) return(data.table(cluster_id = g, sig = 0L))
  st <- readRDS(file.path(DIRS, paste0(g, ".rds")))
  stopifnot(dom %in% st$study_id)
  r <- rem_gruppo(st[study_id != dom, .(gene_id, y = d0, se = se1)], g)
  pieno <- r1[.(g)][!is.na(FDR) & FDR < 0.05]
  if (!nrow(pieno)) return(data.table(cluster_id = g, sig = 0L))
  m <- merge(pieno[, .(gene_id, lfc = logFC_pool)], r[, .(gene_id, lfc2 = logFC_pool, p2 = p_value_pool)], by = "gene_id", all.x = TRUE)
  stimati <- !is.na(m$lfc2)
  stesso <- sign(m$lfc) == sign(m$lfc2)
  data.table(cluster_id = g, sig = nrow(pieno), stimati = sum(stimati), segno = mean(stesso[stimati]), p05 = mean((stesso & m$p2 < 0.05)[stimati]),
             sig_senza = r[, sum(FDR < 0.05, na.rm = TRUE)], sig_comuni = sum(m$gene_id %in% r[!is.na(FDR) & FDR < 0.05, gene_id]))
}
t0 <- Sys.time()
# Ogni gruppo si salva appena finito: un errore su un gruppo non perde gli altri.
DIR70 <- file.path(PES5, "senza-dominante"); dir.create(DIR70, showWarnings = FALSE)
ris <- mclapply(seq_len(nrow(M)), function(i) {
  f <- file.path(DIR70, paste0(M$cluster_id[i], ".rds"))
  if (file.exists(f)) return(readRDS(f))
  r <- lavoro(i); saveRDS(r, f); r
}, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(ris, inherits, TRUE, "try-error")
cat(sprintf("gruppi con errore: %d\n", sum(err)))
if (any(err)) { print(M$nome[err]); print(ris[err][[1]]) }
ris <- rbindlist(ris[!err], fill = TRUE)
cat(sprintf("%d gruppi: %.1f min\n", nrow(ris), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
ris <- merge(M[, .(cluster_id, nome, k, q1, kish1, dominata_T1, in41, n_accusati, dom1)], ris, by = "cluster_id")
fwrite(ris, file.path(OUT5, "70-senza-dominante.csv"))
stampa <- function(x, et) {
  x <- x[sig > 0]
  cat(sprintf("%s (%d gruppi): segno %s | p<0,05 %s | geni ancora FDR<0,05, fra i significativi %s\n", et, nrow(x),
    paste(sprintf("%.3f", ic_mediana(x$segno)[1:3]), collapse = " "), paste(sprintf("%.3f", ic_mediana(x$p05)[1:3]), collapse = " "),
    paste(sprintf("%.3f", ic_mediana(x$sig_comuni / x$sig)[1:3]), collapse = " ")))
}
cat("=== P14 e P15 (stima, IC95, bootstrap per gruppo)\n")
stampa(ris[dominata_T1 == TRUE], "dominate")
stampa(ris[dominata_T1 == TRUE & k == 3L], "dominate a k=3")
stampa(ris[dominata_T1 == TRUE & k > 3L], "dominate a k>3")
stampa(ris[in41 == TRUE], "le 41")
stampa(ris[dominata_T1 == FALSE & in41 == FALSE], "non dominate fuori dalle 41")
d <- ris[dominata_T1 == TRUE & sig > 0]
cat(sprintf("dominate con segno concorde sotto il 70%%: %d su %d (%s)\n", d[segno < 0.7, .N], nrow(d), paste(d[segno < 0.7][order(segno), sprintf("%s %.0f%%", nome, 100 * segno)], collapse = "; ")))
cat(sprintf("dominate senza nessun gene FDR<0,05 dopo la rimozione: %d su %d\n", d[sig_comuni == 0, .N], nrow(d)))
