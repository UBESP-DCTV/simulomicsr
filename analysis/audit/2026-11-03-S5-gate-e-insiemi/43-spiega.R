#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/43-spiega.R
# Cancello 5-bis e spiegazione delle previsioni smentite. Vedi l'aggiunta in 00-previsioni.md.
# Uso: WORKERS=24 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/43-spiega.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/41-q-profile.R")
library(parallel)
tab <- fread(file.path(OUT5, "40-per-gruppo.csv"))
tab[, fascia := fcase(fonte == "k2", "k=2", k == 3L, "k=3", k == 4L, "k=4", k %in% 5:9, "k=5-9", default = "k>=10")]
DIRS <- c("194" = "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio", "k2" = file.path(PES5, "studio-k2"))
prendi <- function(k_voluto, n = 2000L) {
  gg <- if (k_voluto == 2L) tab[fonte == "k2"] else tab[fonte == "194" & k == k_voluto]
  righe <- list()
  for (i in sample(nrow(gg))) {
    st <- readRDS(file.path(DIRS[[gg$fonte[i]]], paste0(gg$cluster_id[i], ".rds")))[is.finite(d0) & is.finite(se1)]
    pie <- st[, .N, by = gene_id][N == k_voluto]
    righe[[length(righe) + 1L]] <- st[gene_id %in% sample(pie$gene_id, min(50L, nrow(pie))), .(cluster_id, gene_id, study_id, d0, se1)]
    if (sum(lengths(lapply(righe, function(z) unique(paste(z$cluster_id, z$gene_id))))) >= n) break
  }
  rbindlist(righe)
}
set.seed(SEME)
cat("=== CANCELLO 5-BIS e controllo su Knapp-Hartung\n")
for (kk in 2:4) {
  x <- prendi(kk)
  chiavi <- unique(x[, .(cluster_id, gene_id)]); chiavi <- chiavi[seq_len(min(.N, 2000L))]
  x <- x[chiavi, on = .(cluster_id, gene_id)]
  ris <- rbindlist(mclapply(seq_len(nrow(chiavi)), function(i) {
    z <- x[cluster_id == chiavi$cluster_id[i] & gene_id == chiavi$gene_id[i]]
    Y <- matrix(z$d0, 1L); V <- matrix(z$se1^2, 1L)
    q <- q_profile(Y, V)
    f <- tryCatch(metafor::rma(yi = z$d0, sei = z$se1, method = "REML"), error = function(e) NULL, warning = function(w) NULL)
    if (is.null(f)) return(NULL)
    ci <- tryCatch(suppressWarnings(metafor::confint.rma.uni(f, control = list(tau2.max = 1e7, tol = 1e-10)))$random, error = function(e) NULL)
    if (is.null(ci)) return(NULL)
    ci0 <- tryCatch(suppressWarnings(metafor::confint.rma.uni(f, control = list(tau2.max = 1e7)))$random, error = function(e) NULL)
    fk <- tryCatch(metafor::rma(yi = z$d0, sei = z$se1, method = "REML", test = "knha"), error = function(e) NULL, warning = function(w) NULL)
    h <- knapp_hartung(Y, V, f$tau2)
    bq <- stats::qchisq(c(0.975, 0.025), kk - 1L)
    Y0 <- Y; o <- is.finite(Y)
    data.table(t_lo = q$tau2_lo, t_hi = q$tau2_hi, m_lo = ci["tau^2", "ci.lb"], m_hi = ci["tau^2", "ci.ub"], m0_lo = if (is.null(ci0)) NA_real_ else ci0["tau^2", "ci.lb"], m0_hi = if (is.null(ci0)) NA_real_ else ci0["tau^2", "ci.ub"],
               q_lo = if (q$tau2_lo > 0) abs(q_stat(Y0, V, o, q$tau2_lo) - bq[1]) else 0, q_hi = if (q$tau2_hi > 0) abs(q_stat(Y0, V, o, q$tau2_hi) - bq[2]) else 0,
               p_mio = h$p, p_mf = if (is.null(fk)) NA_real_ else fk$pval)
  }, mc.cores = WORKERS))
  rel <- function(a, b) { ok <- is.finite(b) & b > 1e-6; if (any(ok)) max(abs(a[ok] - b[ok]) / b[ok]) else 0 }
  cat(sprintf("k=%d: geni %d | tol 1e-10: scarto relativo massimo tau2 lo %.2g, hi %.2g | tol predefinita: lo %.2g, hi %.2g, scarto assoluto massimo %.2g | |Q - bersaglio| massimo %.2g | |p - p metafor| massimo %.2g\n",
              kk, nrow(ris), rel(ris$t_lo, ris$m_lo), rel(ris$t_hi, ris$m_hi), rel(ris$t_lo, ris$m0_lo), rel(ris$t_hi, ris$m0_hi), max(abs(c(ris$t_lo - ris$m0_lo, ris$t_hi - ris$m0_hi)), na.rm = TRUE), max(c(ris$q_lo, ris$q_hi)), max(abs(ris$p_mio - ris$p_mf), na.rm = TRUE)))
}
cat("\n=== Spiegazioni, per fascia di k (mediane per gruppo)\n")
r194 <- as.data.table(read_parquet(file.path(PES5, "rem-194-T1.parquet"))); r194[, fonte := "194"]
rk2 <- as.data.table(read_parquet(file.path(PES5, "rem-k2-T1.parquet")))[cluster_id %in% tab[fonte == "k2", cluster_id]]; rk2[, fonte := "k2"]
rem <- rbind(r194, rk2); setkey(rem, cluster_id)
print(as.data.frame(tab[, .(gruppi = .N, tau0_tutti = round(median(tau0_tutti), 3), tau0_sig = round(median(tau0_sig, na.rm = TRUE), 3), con_gene_KH = sum(kh_nsig > 0), quota_con_gene_KH = round(mean(kh_nsig > 0), 3), KH_geni_mediana = as.numeric(median(kh_nsig)), geni_z_mediana = as.numeric(median(n_sig))), keyby = fascia]))
cat(sprintf("riferimento teorico: con due studi omogenei tau2 REML e' 0 se Q <= 1, P(chi2_1 <= 1) = %.3f\n", pchisq(1, 1)))
# Intervallo di predizione separato per tau2 = 0 e tau2 > 0, tutti i gruppi delle fasce
gruppi <- tab[, .(cluster_id, fonte, fascia)]
sep <- rbindlist(mclapply(seq_len(nrow(gruppi)), function(i) {
  g <- gruppi$cluster_id[i]
  st <- readRDS(file.path(DIRS[[gruppi$fonte[i]]], paste0(g, ".rds")))
  r <- rem[.(g)][!is.na(FDR) & FDR < 0.05]
  if (!nrow(r)) return(NULL)
  st <- st[gene_id %in% r$gene_id & is.finite(d0) & is.finite(se1)]
  ii <- split(seq_len(nrow(st)), st$gene_id); y <- st$d0; s <- st$se1
  ex <- vapply(r$gene_id, function(ge) { j <- ii[[ge]]; isTRUE(.rem_prediction_interval(y[j], s[j])$excl0) }, TRUE)
  z <- r$tau2 <= 1e-10
  data.table(cluster_id = g, fascia = gruppi$fascia[i], ex_tau0 = if (any(z)) mean(ex[z]) else NA_real_, ex_tau_pos = if (any(!z)) mean(ex[!z]) else NA_real_)
}, mc.cores = WORKERS, mc.preschedule = FALSE))
fwrite(sep, file.path(OUT5, "43-predizione-per-tau.csv"))
print(as.data.frame(sep[, .(gruppi = .N, PI_esclude0_se_tau0 = round(median(ex_tau0, na.rm = TRUE), 3), PI_esclude0_se_tau_pos = round(median(ex_tau_pos, na.rm = TRUE), 3)), keyby = fascia]))
