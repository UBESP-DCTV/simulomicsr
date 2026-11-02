#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/32-nullo-fuori-campione.R
# Cancello 4-bis (00-previsioni.md): stessa prova di 30-controllo-positivo.R sui 48 insiemi di
# controllo che l'estrazione dei 40 ha lasciato fuori. Stesso seme: l'estrazione si ripete uguale.
# Uso: WORKERS=32 Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/32-nullo-fuori-campione.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
library(parallel)
RNGkind("L'Ecuyer-CMRG")
A <- readRDS(file.path(PESANTI, "bracci.rds"))$A
K <- A[n_c >= 9L & n_gsm_c == n_c & n_gsm_t == n_t][order(study_id, -n_c, gsm_c)][, .SD[1L], by = study_id]
stopifnot(nrow(K) == 88L)
set.seed(SEME)
usati <- sort(sample.int(nrow(K), 40L))
K <- K[-usati]
stopifnot(nrow(K) == 48L, !any(K$study_id %in% fread(file.path(OUT, "30-controllo-positivo.csv"))$study_id))
semi <- sample.int(1e8, nrow(K))

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
  f1 <- fit(m, st, T1, C0, a$study_id); f2 <- fit(m, st, T2, C0, a$study_id); f3 <- fit(m, st, c(T1, T2), C0, a$study_id)
  g <- Reduce(intersect, list(f1$gene_id, f2$gene_id, f3$gene_id))
  f1 <- f1[match(g, gene_id)]; f2 <- f2[match(g, gene_id)]; f3 <- f3[match(g, gene_id)]
  R <- struttura_coppia(list(T1, T2), list(C0, C0))$R
  z1 <- f1$logFC / f1$SE; z2 <- f2$logFC / f2$SE
  U <- cbind(1 / f1$SE, 1 / f2$SE)
  d0 <- rowSums(cbind(f1$logFC, f2$logFC) * U^2) / rowSums(U^2)
  se0 <- sqrt(1 / rowSums(U^2)); se1 <- sqrt(var_t1(U, R))
  data.table(study_id = a$study_id, prop = prop, n = n, rho_formula = R[1, 2], rho_emp = cor(z1, z2),
             mad2_T0 = mad2(d0 / se0), mad2_T1 = mad2(d0 / se1), mad2_T3 = mad2(f3$logFC / f3$SE))
}
griglia <- CJ(k = seq_len(nrow(K)), prop = 1:2)
ris <- rbindlist(mclapply(seq_len(nrow(griglia)), function(i) una_prova(griglia$k[i], griglia$prop[i]),
                          mc.cores = WORKERS, mc.preschedule = FALSE), fill = TRUE)
fwrite(ris, file.path(OUT, "32-nullo-fuori-campione.csv"))
s <- ris[, .(insiemi = .N, scarto_medio = mean(rho_emp - rho_formula), scarto_mediano = median(rho_emp - rho_formula),
             T0 = median(mad2_T0), T1 = median(mad2_T1), T3 = median(mad2_T3),
             T1_su_T3 = median(mad2_T1 / mad2_T3), T0_su_T1 = median(mad2_T0 / mad2_T1)), by = prop]
print(s, digits = 3)
cat(sprintf("CANCELLO 4-bis: (a) %s | (b) %s | (c) %s\n", all(abs(s$scarto_medio) <= .05),
            all(s$T1_su_T3 >= .95 & s$T1_su_T3 <= 1.05), all(s$T0_su_T1 >= 1.15)))
