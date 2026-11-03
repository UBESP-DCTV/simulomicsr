#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/72-nullo-senza-dominante.R
# Controllo negativo di 70-senza-dominante.R. Vedi la seconda aggiunta in 00-previsioni.md.
# Uso: WORKERS=32 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/72-nullo-senza-dominante.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
Q <- readRDS(file.path(PES5, "quadro-194.rds"))
ver <- fread(file.path(OUT5, "70-senza-dominante.csv"))[dominata_T1 == TRUE & sig > 0]
stopifnot(nrow(ver) == 96L)
DIRS <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))[, .(cluster_id, contrast_entity)]
ten <- readRDS(file.path(PES5, "dispatch-A3.rds"))$tenuti[cluster_id %in% d$cluster_id]
coppie <- merge(unique(ten[, .(cluster_id, study_id)]), d, by = "cluster_id")
set.seed(SEME)
piano <- rbindlist(lapply(seq_len(nrow(ver)), function(i) {
  g <- ver$cluster_id[i]; en <- d[cluster_id == g, contrast_entity]
  dentro <- coppie[cluster_id == g, study_id]
  pool <- coppie[contrast_entity != en & !(study_id %in% dentro)]
  scelti <- pool[!duplicated(study_id)][sample(.N, ver$k[i] - 1L)]
  data.table(cluster_id = g, dom = ver$dom1[i], g_altro = scelti$cluster_id, s_altro = scelti$study_id)
}))
fwrite(piano, file.path(OUT5, "72-piano-estrazione.csv"))
lavoro <- function(g) {
  p <- piano[cluster_id == g]; dom <- p$dom[1]
  st <- readRDS(file.path(DIRS, paste0(g, ".rds")))[study_id == dom, .(gene_id, study_id, d0, se1)]
  al <- rbindlist(lapply(seq_len(nrow(p)), function(j) readRDS(file.path(DIRS, paste0(p$g_altro[j], ".rds")))[study_id == p$s_altro[j], .(gene_id, study_id, d0, se1)]))
  x <- rbind(st, al)
  pieno <- rem_gruppo(x[, .(gene_id, y = d0, se = se1)], g)
  sig <- pieno[!is.na(FDR) & FDR < 0.05]
  if (!nrow(sig)) return(data.table(cluster_id = g, sig = 0L))
  r <- rem_gruppo(x[study_id != dom, .(gene_id, y = d0, se = se1)], g)
  m <- merge(sig[, .(gene_id, lfc = logFC_pool)], r[, .(gene_id, lfc2 = logFC_pool, p2 = p_value_pool, FDR2 = FDR)], by = "gene_id", all.x = TRUE)
  st_ok <- !is.na(m$lfc2); stesso <- sign(m$lfc) == sign(m$lfc2)
  data.table(cluster_id = g, sig = nrow(sig), stimati = sum(st_ok), segno = mean(stesso[st_ok]), p05 = mean((stesso & m$p2 < 0.05)[st_ok]), ancora = sum(m$FDR2 < 0.05, na.rm = TRUE) / nrow(sig))
}
t0 <- Sys.time()
ris <- mclapply(ver$cluster_id, lavoro, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(ris, inherits, TRUE, "try-error"); cat("gruppi con errore:", sum(err), "\n"); if (any(err)) print(ris[err][[1]])
nu <- rbindlist(ris[!err], fill = TRUE)
cat(sprintf("%d gruppi: %.1f min\n", nrow(nu), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
fwrite(nu, file.path(OUT5, "72-nullo.csv"))
v <- ver[, .(cluster_id, nome, k, sig_v = sig, segno_v = segno, p05_v = p05, ancora_v = sig_comuni / sig)]
m <- merge(v, nu[, .(cluster_id, sig_n = sig, segno_n = segno, p05_n = p05, ancora_n = ancora)], by = "cluster_id")
cat(sprintf("gruppi nulli senza geni significativi: %d su %d; geni significativi, mediana: veri %g, nulli %g\n", m[sig_n == 0, .N], nrow(m), median(m$sig_v), median(m$sig_n, na.rm = TRUE)))
m <- m[sig_n > 0]
set.seed(SEME)
for (q in c("segno", "p05", "ancora")) {
  a <- m[[paste0(q, "_v")]]; b <- m[[paste0(q, "_n")]]; dd <- a - b; dd <- dd[is.finite(dd)]
  ib <- replicate(B_BOOT, median(sample(dd, replace = TRUE)))
  cat(sprintf("=== %s: vero %.3f, nullo %.3f, differenza mediana appaiata %.1f punti [%.1f; %.1f], gruppi %d, passa la regola: %s\n", q, median(a, na.rm = TRUE), median(b, na.rm = TRUE), 100 * median(dd), 100 * quantile(ib, .025), 100 * quantile(ib, .975), length(dd), quantile(ib, .025) * 100 > 10))
}
