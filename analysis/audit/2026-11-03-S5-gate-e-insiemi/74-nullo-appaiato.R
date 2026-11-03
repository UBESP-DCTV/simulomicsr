#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/74-nullo-appaiato.R
# Controllo negativo appaiato per precisione. Vedi la terza aggiunta in 00-previsioni.md.
# Uso: WORKERS=32 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/74-nullo-appaiato.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
M <- readRDS(file.path(PES5, "quadro-194.rds"))
gr <- M[(in173 == TRUE & dominata_T1 == TRUE & sig1 > 0) | in41 == TRUE]
gr[, insieme := fifelse(in41 == TRUE, "41", "dominati")]
print(gr[, .N, by = insieme]); stopifnot(nrow(gr) == 137L)
DIRS <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))[, .(cluster_id, contrast_entity)]
pre <- rbindlist(mclapply(d$cluster_id, function(g) readRDS(file.path(DIRS, paste0(g, ".rds")))[, .(se_med = median(se1, na.rm = TRUE)), by = study_id][, cluster_id := g], mc.cores = WORKERS, mc.preschedule = FALSE))
pre <- merge(pre, d, by = "cluster_id")
dop <- fread(file.path(OUT5, "48-coppie-di-studi-doppie.csv"))[, .(s1, s2)]
doppi_di <- function(s) unique(c(dop[s1 %in% s, s2], dop[s2 %in% s, s1]))
set.seed(SEME)
piano <- rbindlist(lapply(seq_len(nrow(gr)), function(i) {
  g <- gr$cluster_id[i]; dom <- gr$dom1[i]; en <- d[cluster_id == g, contrast_entity]
  dentro <- pre[cluster_id == g]
  altri <- dentro[study_id != dom]
  pool <- pre[contrast_entity != en & !(study_id %in% c(dentro$study_id, doppi_di(dentro$study_id)))][!duplicated(study_id)]
  usati <- character(); righe <- list()
  for (j in sample(nrow(altri))) {
    p <- pool[!(study_id %in% c(usati, doppi_di(usati)))]
    r <- p$se_med / altri$se_med[j]
    ok <- which(r >= 0.75 & r <= 1.25)
    vicino <- length(ok) == 0L
    q <- if (vicino) which.min(abs(log(r))) else ok[sample.int(length(ok), 1L)]
    usati <- c(usati, p$study_id[q])
    righe[[length(righe) + 1L]] <- data.table(cluster_id = g, dom = dom, s_vero = altri$study_id[j], se_vero = altri$se_med[j], g_altro = p$cluster_id[q], s_altro = p$study_id[q], se_altro = p$se_med[q], fuori_margine = vicino)
  }
  rbindlist(righe)
}))
fwrite(piano, file.path(OUT5, "74-piano-estrazione.csv"))
cat(sprintf("studi sostituiti: %d; fuori dal margine del 25%%: %d; rapporto degli errori standard, mediana %.3f\n", nrow(piano), sum(piano$fuori_margine), median(piano$se_altro / piano$se_vero)))
lavoro <- function(g) {
  p <- piano[cluster_id == g]; dom <- p$dom[1]
  st <- readRDS(file.path(DIRS, paste0(g, ".rds")))[study_id == dom, .(gene_id, study_id, d0, se1)]
  al <- rbindlist(lapply(seq_len(nrow(p)), function(j) readRDS(file.path(DIRS, paste0(p$g_altro[j], ".rds")))[study_id == p$s_altro[j], .(gene_id, study_id, d0, se1)]))
  x <- rbind(st, al)
  pieno <- rem_gruppo(x[, .(gene_id, y = d0, se = se1)], g)
  sig <- pieno[!is.na(FDR) & FDR < 0.05]
  out <- data.table(cluster_id = g, sig_n = nrow(sig), I2_n = median(pieno$I2, na.rm = TRUE), tau0_sig_n = if (nrow(sig)) mean(sig$tau2 <= 1e-10) else NA_real_)
  if (!nrow(sig)) return(out)
  r <- rem_gruppo(x[study_id != dom, .(gene_id, y = d0, se = se1)], g)
  m <- merge(sig[, .(gene_id, lfc = logFC_pool)], r[, .(gene_id, lfc2 = logFC_pool, p2 = p_value_pool, FDR2 = FDR)], by = "gene_id", all.x = TRUE)
  ok <- !is.na(m$lfc2); ss <- sign(m$lfc) == sign(m$lfc2)
  out[, `:=`(segno_n = mean(ss[ok]), p05_n = mean((ss & m$p2 < 0.05)[ok]), ancora_n = sum(m$FDR2 < 0.05, na.rm = TRUE) / nrow(sig))]
  out
}
t0 <- Sys.time()
ris <- mclapply(gr$cluster_id, lavoro, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(ris, inherits, TRUE, "try-error"); cat("gruppi con errore:", sum(err), "\n"); if (any(err)) print(ris[err][[1]])
nu <- rbindlist(ris[!err], fill = TRUE)
cat(sprintf("%d gruppi: %.1f min\n", nrow(nu), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
ver <- fread(file.path(OUT5, "70-senza-dominante.csv"))[, .(cluster_id, segno_v = segno, p05_v = p05, ancora_v = sig_comuni / sig)]
m <- merge(merge(gr[, .(cluster_id, nome, k, insieme, sig_v = sig1, I2_v = I2_med, q1)], nu, by = "cluster_id"), ver, by = "cluster_id", all.x = TRUE)
m[, rapporto := sig_v / pmax(sig_n, 1)]
fwrite(m, file.path(OUT5, "74-nullo-appaiato.csv"))
set.seed(SEME)
for (ins in c("41", "dominati")) {
  x <- m[insieme == ins]
  s <- ic_mediana(x$rapporto)
  cat(sprintf("=== %s, gruppi %d: geni veri mediana %g, nulli %g; rapporto veri/nulli %.2f [%.2f; %.2f]; passa la regola (IC tutto sopra 1,5): %s; gruppi con veri > nulli: %d\n", ins, nrow(x), median(x$sig_v), median(x$sig_n), s["stima"], s["lo"], s["hi"], s["lo"] > 1.5, x[sig_v > sig_n, .N]))
  cat(sprintf("    I2 vero %.1f, nullo %.1f | segno vero %.3f, nullo %.3f | p<0,05 vero %.3f, nullo %.3f | ancora FDR vero %.3f, nullo %.3f | tau2=0 sui significativi, nullo %.3f\n", median(x$I2_v), median(x$I2_n), median(x$segno_v, na.rm = TRUE), median(x$segno_n, na.rm = TRUE), median(x$p05_v, na.rm = TRUE), median(x$p05_n, na.rm = TRUE), median(x$ancora_v, na.rm = TRUE), median(x$ancora_n, na.rm = TRUE), median(x$tau0_sig_n, na.rm = TRUE)))
}
cat("\nle 41 per fascia di k:\n")
print(as.data.frame(m[insieme == "41", .(gruppi = .N, veri = as.numeric(median(sig_v)), nulli = as.numeric(median(sig_n)), rapporto = round(median(rapporto), 2), veri_maggiori = sum(sig_v > sig_n)), keyby = .(k = fcase(k == 3L, "3", k == 4L, "4", k %in% 5:9, "5-9", default = ">=10"))]))
cat("\nle 41 con rapporto piu' basso:\n")
print(as.data.frame(m[insieme == "41"][order(rapporto)][1:10, .(nome, k, sig_v, sig_n, rapporto = round(rapporto, 2))]))
