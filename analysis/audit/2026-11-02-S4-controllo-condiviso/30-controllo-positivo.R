#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/30-controllo-positivo.R
# Cancello 4. Dentro un gruppo di controllo vero non c'e' nessun effetto. Divido a caso i
# campioni in due pseudo-trattati e uno pseudo-controllo e faccio i fit veri. La formula di
# rho deve prevedere la correlazione fra i due bracci. Lo z di produzione (T0) deve risultare
# gonfiato, lo z di T1 no.
# Uso: WORKERS=32 Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/30-controllo-positivo.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
library(parallel)
RNGkind("L'Ecuyer-CMRG")
A <- readRDS(file.path(PESANTI, "bracci.rds"))$A

# per ogni studio l'insieme di controllo piu' grande, senza corsie, con almeno 9 librerie
K <- A[n_c >= 9L & n_gsm_c == n_c & n_gsm_t == n_t][order(study_id, -n_c, gsm_c)][, .SD[1L], by = study_id]
cat(sprintf("insiemi di controllo disponibili: %d studi\n", nrow(K)))
set.seed(SEME)
if (nrow(K) > 40L) K <- K[sort(sample.int(nrow(K), 40L))]
semi <- sample.int(1e8, nrow(K))
stopifnot(nrow(K) >= 20L)

fit <- function(m, st, tr, co, sid) {
  mm <- m[, c(tr, co), drop = FALSE]; attr(mm, "gene_symbol") <- st
  f <- factor(c(rep("treated", length(tr)), rep("control", length(co))), levels = c("control", "treated"))
  as.data.table(.run_limma_voom_de(mm, f, sid, "nullo"))[, .(gene_id, logFC, SE)]
}
mad2 <- function(z) stats::mad(z[is.finite(z)])^2

una_prova <- function(k, prop) {
  a <- K[k]; set.seed(semi[k] + prop)
  co <- strsplit(a$gsm_c, ",", fixed = TRUE)[[1]]; tr <- strsplit(a$gsm_t, ",", fixed = TRUE)[[1]]
  m <- .fetch_counts_cached(a$study_id, c(tr, co), h5_path = NULL, gene_biotype_filter = "protein_coding")
  st <- attr(m, "gene_symbol")
  s <- sample(co); n <- length(s)
  q <- if (prop == 1L) floor(n / 3) else floor(n / 4)
  T1 <- s[1:q]; T2 <- s[(q + 1):(2 * q)]; C0 <- s[(2 * q + 1):n]
  f1 <- fit(m, st, T1, C0, a$study_id); f2 <- fit(m, st, T2, C0, a$study_id)
  f3 <- fit(m, st, c(T1, T2), C0, a$study_id)
  g <- Reduce(intersect, list(f1$gene_id, f2$gene_id, f3$gene_id))
  f1 <- f1[match(g, gene_id)]; f2 <- f2[match(g, gene_id)]; f3 <- f3[match(g, gene_id)]
  R <- struttura_coppia(list(T1, T2), list(C0, C0))$R
  z1 <- f1$logFC / f1$SE; z2 <- f2$logFC / f2$SE
  U <- cbind(1 / f1$SE, 1 / f2$SE)
  d0 <- rowSums(cbind(f1$logFC, f2$logFC) * U^2) / rowSums(U^2)
  se0 <- sqrt(1 / rowSums(U^2)); se1 <- sqrt(var_t1(U, R))
  dsom <- mad2(z1 + z2); ddif <- mad2(z1 - z2)
  data.table(study_id = a$study_id, prop = prop, n = n, n_t1 = q, n_t2 = q, n_c = length(C0), geni = length(g),
             rho_formula = R[1, 2], rho_emp = cor(z1, z2), rho_rob = (dsom - ddif) / (dsom + ddif),
             mad2_z1 = mad2(z1), mad2_z2 = mad2(z2), mad2_T0 = mad2(d0 / se0), mad2_T1 = mad2(d0 / se1),
             mad2_T3 = mad2(f3$logFC / f3$SE), se3_su_se1 = median(f3$SE / se1), se1_su_se0 = median(se1 / se0))
}
griglia <- CJ(k = seq_len(nrow(K)), prop = 1:2)
ris <- mclapply(seq_len(nrow(griglia)), function(i)
  tryCatch(una_prova(griglia$k[i], griglia$prop[i]),
           error = function(e) data.table(k = griglia$k[i], errore = conditionMessage(e))),
  mc.cores = WORKERS, mc.preschedule = FALSE)
ris <- rbindlist(ris, fill = TRUE)
if ("errore" %in% names(ris) && any(!is.na(ris$errore))) { print(ris[!is.na(errore)][1:3]); stop("prove in errore") }
fwrite(ris, file.path(OUT, "30-controllo-positivo.csv"))

s <- ris[, .(insiemi = .N, rho_formula = median(rho_formula), rho_emp = median(rho_emp),
             scarto = median(rho_emp - rho_formula), rho_rob = median(rho_rob),
             mad2_z = median(c(mad2_z1, mad2_z2)), T0 = median(mad2_T0), T1 = median(mad2_T1), T3 = median(mad2_T3),
             se3_su_se1 = median(se3_su_se1), se1_su_se0 = median(se1_su_se0)), by = prop]
print(s)
a_ok <- all(abs(s$scarto) <= 0.05); b_ok <- all(s$T1 >= 0.85 & s$T1 <= 1.15); c_ok <- all(s$T0 >= 1.15 * s$T1)
cat(sprintf("CANCELLO 4: (a) rho %s | (b) MAD2 T1 in [0,85; 1,15] %s | (c) T0 oltre T1 del 15%% %s\n",
            a_ok, b_ok, c_ok))
