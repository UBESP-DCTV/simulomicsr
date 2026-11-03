#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/40-incertezza.R
# Quanto valgono tau2 e I2, con che intervallo. Gene per gene, per tutti i gruppi a k=2 e per le 194,
# con T1. Intervallo Q-profile al 95%, Knapp-Hartung con t(k-1), intervallo di predizione del pacchetto.
# Uso: WORKERS=48 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/40-incertezza.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/41-q-profile.R")
library(parallel)
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
k2 <- fread(file.path(OUT5, "30-per-gruppo-k2.csv"))[k_reale == 2L]
DIR_194 <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"
DIR_K2 <- file.path(PES5, "studio-k2")
r194 <- as.data.table(read_parquet(file.path(PES5, "rem-194-T1.parquet"))); r194[, fonte := "194"]
rk2 <- as.data.table(read_parquet(file.path(PES5, "rem-k2-T1.parquet")))[cluster_id %in% k2$cluster_id]; rk2[, fonte := "k2"]
rem <- rbind(r194, rk2); setkey(rem, cluster_id)
gruppi <- rbind(data.table(cluster_id = sort(d$cluster_id), fonte = "194", dir = DIR_194), data.table(cluster_id = sort(k2$cluster_id), fonte = "k2", dir = DIR_K2))
lavoro <- function(i) {
  g <- gruppi$cluster_id[i]
  st <- readRDS(file.path(gruppi$dir[i], paste0(g, ".rds")))
  r <- rem[.(g)]
  st <- st[gene_id %in% r$gene_id & is.finite(d0) & is.finite(se1)]
  geni <- r$gene_id; studi <- sort(unique(st$study_id))
  Y <- matrix(NA_real_, length(geni), length(studi)); V <- Y
  ig <- match(st$gene_id, geni); is <- match(st$study_id, studi)
  Y[cbind(ig, is)] <- st$d0; V[cbind(ig, is)] <- st$se1^2
  q <- q_profile(Y, V)
  h <- knapp_hartung(Y, V, r$tau2)
  stopifnot(max(abs(h$mu - r$logFC_pool)) < 1e-6)
  fdr_kh <- p.adjust(h$p, method = "BH")
  sig <- !is.na(r$FDR) & r$FDR < 0.05
  # intervallo di predizione: la funzione del pacchetto, sui soli geni significativi
  excl <- rep(NA, length(geni))
  for (j in which(sig)) {
    ok <- is.finite(Y[j, ])
    excl[j] <- .rem_prediction_interval(Y[j, ok], sqrt(V[j, ok]))$excl0
  }
  m <- function(x) if (any(is.finite(x))) median(x, na.rm = TRUE) else NA_real_
  w_i2 <- q$I2_hi - q$I2_lo
  data.table(cluster_id = g, fonte = gruppi$fonte[i], k = length(studi), n_geni = length(geni), n_sig = sum(sig),
             I2_med = m(r$I2), tau2_med = m(r$tau2),
             I2_lo_med = m(q$I2_lo), I2_hi_med = m(q$I2_hi), ampiezza_I2 = m(w_i2), ampiezza_I2_sig = m(w_i2[sig]),
             tau2_lo_med = m(q$tau2_lo), tau2_hi_med = m(q$tau2_hi), tau2_rapporto_hi = m(q$tau2_hi / pmax(r$tau2, 1e-12)),
             quota_I2_lo0 = mean(q$I2_lo <= 0, na.rm = TRUE),
             tau0_sig = if (any(sig)) mean(r$tau2[sig] <= 1e-10) else NA_real_, tau0_tutti = mean(r$tau2 <= 1e-10),
             kh_resta = if (any(sig)) mean(fdr_kh[sig] < 0.05, na.rm = TRUE) else NA_real_, kh_nsig = sum(fdr_kh < 0.05, na.rm = TRUE),
             pi_esclude0 = if (any(sig)) mean(excl[sig], na.rm = TRUE) else NA_real_, pi_na = if (any(sig)) mean(is.na(excl[sig])) else NA_real_)
}
t0 <- Sys.time()
ris <- mclapply(seq_len(nrow(gruppi)), function(i) tryCatch(lavoro(i), error = function(e) data.table(cluster_id = gruppi$cluster_id[i], errore = conditionMessage(e))), mc.cores = WORKERS, mc.preschedule = FALSE)
cat(sprintf("%d gruppi: %.1f min\n", nrow(gruppi), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
tab <- rbindlist(ris, fill = TRUE)
if ("errore" %in% names(tab) && any(!is.na(tab$errore))) { print(tab[!is.na(errore), .(cluster_id, errore)][1:min(.N, 10)]); stop("errori") }
tab[, errore := NULL]
fwrite(tab, file.path(OUT5, "40-per-gruppo.csv"))
tab[, fascia := fcase(fonte == "k2", "k=2", k == 3L, "k=3", k == 4L, "k=4", k %in% 5:9, "k=5-9", default = "k>=10")]
fasce <- c("k=2", "k=3", "k=4", "k=5-9", "k>=10")
sintesi <- rbindlist(lapply(fasce, function(fa) {
  x <- tab[fascia == fa]
  rbindlist(lapply(c("I2_med", "tau2_med", "ampiezza_I2", "ampiezza_I2_sig", "I2_lo_med", "I2_hi_med", "tau2_hi_med", "tau2_rapporto_hi", "tau0_sig", "n_sig", "kh_resta", "pi_esclude0", "pi_na"), function(v) {
    s <- ic_mediana(x[[v]]); data.table(fascia = fa, misura = v, stima = s["stima"], lo = s["lo"], hi = s["hi"], n = s["n"])
  }))
}))
fwrite(sintesi, file.path(OUT5, "40-per-fascia.csv"))
print(dcast(sintesi[, .(fascia, misura, v = sprintf("%.3g [%.3g; %.3g]", stima, lo, hi))], misura ~ fascia, value.var = "v"))
# P5: differenza delle mediane k=2 meno k=3, bootstrap per gruppo
a <- tab[fascia == "k=2"]$ampiezza_I2; b <- tab[fascia == "k=3"]$ampiezza_I2
set.seed(SEME); bd <- replicate(B_BOOT, median(sample(a, replace = TRUE)) - median(sample(b, replace = TRUE)))
cat(sprintf("=== P5 ampiezza k=2 meno k=3: %.2f [%.2f; %.2f]\n", median(a) - median(b), quantile(bd, .025), quantile(bd, .975)))
