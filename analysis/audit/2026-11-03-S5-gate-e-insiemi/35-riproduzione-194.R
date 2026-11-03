#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/35-riproduzione-194.R
# Cancello 3: lo stesso rem_gruppo e la stessa efficacia del calcolo a k=2 riproducono il deliverable
# (T0) e la misura sul controllo condiviso (T1), su tutte le 194.
# Le stime per studio vengono da studio/<gruppo>.rds della sessione sul controllo condiviso.
# Uso: WORKERS=48 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/35-riproduzione-194.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
g194 <- sort(d$cluster_id)
DIRS <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"
s4 <- fread("analysis/audit/2026-11-02-S4-controllo-condiviso/50-per-gruppo.csv")
t0 <- Sys.time()
ris <- mclapply(g194, function(g) {
  st <- readRDS(file.path(DIRS, paste0(g, ".rds")))
  toccato <- st[, any(abs(se1 - se0) > 0)]
  r0 <- rem_gruppo(st[, .(gene_id, y = d0, se = se0)], g)
  r1 <- if (toccato) rem_gruppo(st[, .(gene_id, y = d0, se = se1)], g) else copy(r0)
  eff <- function(r, colse) {
    t2 <- r[!is.na(FDR) & FDR < 0.05, .(cluster_id, gene_id, tau2)]
    if (nrow(t2) == 0L) return(NULL)
    pa <- st[is.finite(get(colse)) & get(colse) > 0, .(cluster_id, gene_id, study_id, SE = get(colse))]
    as.data.table(compute_pooling_effectiveness(as.data.frame(pa), as.data.frame(t2)))
  }
  list(r0 = r0, r1 = r1, e0 = eff(r0, "se0"), e1 = eff(r1, "se1"), toccato = toccato)
}, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(ris, inherits, TRUE, "try-error"); if (any(err)) stop(ris[[which(err)[1]]])
cat(sprintf("REM di 194 gruppi: %.1f min; gruppi toccati da T1: %d\n", as.numeric(difftime(Sys.time(), t0, units = "mins")), sum(vapply(ris, `[[`, TRUE, "toccato"))))
r0 <- rbindlist(lapply(ris, `[[`, "r0")); r1 <- rbindlist(lapply(ris, `[[`, "r1"))
e0 <- rbindlist(lapply(ris, `[[`, "e0")); e1 <- rbindlist(lapply(ris, `[[`, "e1"))
write_parquet(r1, file.path(PES5, "rem-194-T1.parquet"))
vero <- as.data.table(read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id", "gene_id", "logFC_pool", "SE_pool", "tau2", "FDR_BH_within_cluster")))
vero <- vero[cluster_id %in% g194]
m <- merge(vero, r0, by = c("cluster_id", "gene_id"), all = TRUE, suffixes = c(".v", ".m"))
cat("=== CANCELLO 3, T0 contro il deliverable\n")
cat(sprintf("righe %d e %d, senza abbinamento %d; scarto massimo logFC %.3g, SE %.3g, tau2 %.3g, FDR %.3g\n", nrow(vero), nrow(r0),
            sum(is.na(m$logFC_pool.v) | is.na(m$logFC_pool.m)), max(abs(m$logFC_pool.v - m$logFC_pool.m)), max(abs(m$SE_pool.v - m$SE_pool.m)), max(abs(m$tau2.v - m$tau2.m)), max(abs(m$FDR_BH_within_cluster - m$FDR))))
g <- r0[, .(n_sig = sum(FDR < 0.05, na.rm = TRUE), I2 = median(I2, na.rm = TRUE)), by = cluster_id]
c0 <- merge(merge(d[, .(cluster_id, n_sig, I2_med, quota_top1, k_kish)], g, by = "cluster_id"), e0[, .(cluster_id, q = quota_top1, k = k_kish)], by = "cluster_id", all.x = TRUE)
cat(sprintf("gruppi %d; n_sig uguale in %d; scarto massimo I2_med %.3g, quota_top1 %.3g, k_kish %.3g\n", nrow(c0), c0[n_sig.x == n_sig.y, .N], c0[, max(abs(I2_med - I2))], c0[, max(abs(quota_top1 - q), na.rm = TRUE)], c0[, max(abs(k_kish - k), na.rm = TRUE)]))
cat("=== CANCELLO 3, T1 contro la misura sul controllo condiviso\n")
g1 <- r1[, .(sig = sum(FDR < 0.05, na.rm = TRUE)), by = cluster_id]
c1 <- merge(merge(s4[, .(cluster_id, q1, kish1, sig1)], g1, by = "cluster_id"), e1[, .(cluster_id, q = quota_top1, k = k_kish)], by = "cluster_id", all.x = TRUE)
cat(sprintf("gruppi %d; sig1 uguale in %d; scarto massimo q1 %.3g, kish1 %.3g\n", nrow(c1), c1[sig1 == sig, .N], c1[, max(abs(q1 - q), na.rm = TRUE)], c1[, max(abs(kish1 - k), na.rm = TRUE)]))
