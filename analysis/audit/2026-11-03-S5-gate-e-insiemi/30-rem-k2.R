#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/30-rem-k2.R
# REM di tutti i gruppi a k_eff = 2, con T0 e con T1 (la varianza corretta scelta dal PI), e
# dominanza con la funzione di produzione compute_pooling_effectiveness().
# Uso: WORKERS=48 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/30-rem-k2.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
D <- readRDS(file.path(PES5, "dispatch-A3.rds")); corsie <- D$lane
A <- readRDS(file.path(PES5, "bracci-k2.rds"))
es <- fread(file.path(OUT5, "20-esito-bracci.csv"))
fit <- as.data.table(read_parquet(file.path(PES5, "fit-bracci.parquet")))
k2 <- D$candidati[k_eff == 2L, cluster_id]
A <- A[cluster_id %in% k2]; fit <- fit[cluster_id %in% k2]
cat(sprintf("gruppi a k_eff=2 nel dispatch: %d | bracci: %d | bracci con fit: %d\n", length(k2), nrow(A), uniqueN(fit[, .(cluster_id, study_id, braccio)])))
setkey(fit, cluster_id)
DIR <- file.path(PES5, "studio-k2"); dir.create(DIR, showWarnings = FALSE)

stime_coppia <- function(xs, a) {
  bracci <- sort(unique(xs$braccio)); a <- a[braccio %in% bracci][order(braccio)]; m <- length(bracci)
  if (m == 1L) return(xs[, .(gene_id, gene_symbol, d0 = logFC, se0 = SE, se1 = SE)])
  TT <- lapply(strsplit(a$gsm_t, ",", fixed = TRUE), librerie, corsie)
  CC <- lapply(strsplit(a$gsm_c, ",", fixed = TRUE), librerie, corsie)
  R <- struttura_coppia(TT, CC)$R
  geni <- sort(unique(xs$gene_id))
  D <- matrix(NA_real_, length(geni), m); S <- D
  ig <- match(xs$gene_id, geni); ib <- match(xs$braccio, bracci)
  D[cbind(ig, ib)] <- xs$logFC; S[cbind(ig, ib)] <- xs$SE
  U <- 1 / S; U[is.na(U)] <- 0; Dz <- D; Dz[is.na(Dz)] <- 0
  sw <- rowSums(U^2)
  data.table(gene_id = geni, gene_symbol = xs$gene_symbol[match(geni, xs$gene_id)],
             d0 = rowSums(Dz * U^2) / sw, se0 = sqrt(1 / sw), se1 = sqrt(var_t1(U, R)))
}
lavoro <- function(g) {
  xg <- fit[.(g)]; ag <- A[cluster_id == g]
  if (nrow(xg) == 0L) return(list(g = g, st = NULL))
  st <- rbindlist(lapply(split(xg, xg$study_id), function(xs) {
    s <- stime_coppia(xs, ag[study_id == xs$study_id[1]])
    s[, `:=`(study_id = xs$study_id[1], cluster_id = g)]; s
  }))
  saveRDS(st, file.path(DIR, paste0(g, ".rds")))
  r0 <- rem_gruppo(st[, .(gene_id, y = d0, se = se0)], g)
  r1 <- rem_gruppo(st[, .(gene_id, y = d0, se = se1)], g)
  eff <- function(r, colse) {
    t2 <- r[!is.na(FDR) & FDR < 0.05, .(cluster_id, gene_id, tau2)]
    if (nrow(t2) == 0L) return(NULL)
    pa <- st[is.finite(get(colse)) & get(colse) > 0, .(cluster_id, gene_id, study_id, SE = get(colse))]
    as.data.table(compute_pooling_effectiveness(as.data.frame(pa), as.data.frame(t2)))
  }
  list(g = g, st = TRUE, r0 = r0, r1 = r1, e0 = eff(r0, "se0"), e1 = eff(r1, "se1"),
       k_reale = uniqueN(st$study_id), bracci = uniqueN(xg[, .(study_id, braccio)]),
       multi = xg[, uniqueN(braccio), by = study_id][, sum(V1 > 1L)])
}
t0 <- Sys.time()
ris <- mclapply(k2, function(g) tryCatch(lavoro(g), error = function(e) list(g = g, errore = conditionMessage(e))), mc.cores = WORKERS, mc.preschedule = FALSE)
cat(sprintf("REM di %d gruppi: %.1f min\n", length(k2), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
err <- Filter(function(z) !is.null(z$errore), ris); cat("errori:", length(err), "\n"); if (length(err)) print(err[[1]])
ok <- Filter(function(z) isTRUE(z$st), ris)
cat(sprintf("gruppi senza nessun fit: %d\n", sum(vapply(ris, function(z) is.null(z$st) && is.null(z$errore), TRUE))))
write_parquet(rbindlist(lapply(ok, `[[`, "r0")), file.path(PES5, "rem-k2-T0.parquet"))
write_parquet(rbindlist(lapply(ok, `[[`, "r1")), file.path(PES5, "rem-k2-T1.parquet"))
riga <- function(z) {
  s <- function(r) r[, .(n_geni = .N, n_sig = sum(FDR < 0.05, na.rm = TRUE), I2_med = median(I2, na.rm = TRUE), tau2_med = median(tau2, na.rm = TRUE))]
  a <- s(z$r0); b <- s(z$r1)
  e <- function(x, n) if (is.null(x) || !nrow(x)) NA_real_ else x[[n]]
  data.table(cluster_id = z$g, k_reale = z$k_reale, bracci = z$bracci, studi_multibraccio = z$multi,
             n_geni = b$n_geni, sig0 = a$n_sig, sig1 = b$n_sig, I2_med0 = a$I2_med, I2_med1 = b$I2_med, tau2_med0 = a$tau2_med, tau2_med1 = b$tau2_med,
             kish0 = e(z$e0, "k_kish"), q0 = e(z$e0, "quota_top1"), kish1 = e(z$e1, "k_kish"), q1 = e(z$e1, "quota_top1"),
             dom1 = if (is.null(z$e1) || !nrow(z$e1)) NA_character_ else z$e1$studio_dominante)
}
tab <- rbindlist(lapply(ok, riga))
tab <- merge(D$candidati[k_eff == 2L, .(cluster_id, k_censito, contrast_entity, contrast_direction, contrast_control_key, canonical_name)], tab, by = "cluster_id", all.x = TRUE)
fwrite(tab, file.path(OUT5, "30-per-gruppo-k2.csv"))
cat("=== P1 gruppi a k censito 2 che arrivano a k_eff=2:", tab[k_censito == 2L, .N], "| a k censito >= 3:", tab[k_censito >= 3L, .N], "| totale:", nrow(tab), "\n")
print(tab[, .(gruppi = .N, k_reale2 = sum(k_reale == 2L, na.rm = TRUE), con_geni_sig = sum(sig1 > 0, na.rm = TRUE)), by = .(censito = fifelse(k_censito == 2L, "2", ">=3"))])
cat(sprintf("=== P2 gruppi con quota_top1 <= 0,50 in T1: %d | quota minima %.6f | kish massimo %.4f (gruppi con quota: %d)\n",
            tab[q1 <= 0.5, .N], min(tab$q1, na.rm = TRUE), max(tab$kish1, na.rm = TRUE), tab[!is.na(q1), .N]))
print(tab[, .(I2_T1 = median(I2_med1, na.rm = TRUE), tau2_T1 = median(tau2_med1, na.rm = TRUE), sig_T1 = median(sig1, na.rm = TRUE), sig_T0 = median(sig0, na.rm = TRUE), kish = median(kish1, na.rm = TRUE), quota = median(q1, na.rm = TRUE), sig0_gruppi = sum(sig1 == 0, na.rm = TRUE))])
