#!/usr/bin/env Rscript
# Passo A, punto 4. Soffitto della fonte H_meta': solo LINCS.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
x <- readRDS(file.path(PES7, "firme.rds")); ent <- x$ent; pm <- x$pm
M <- readRDS(file.path(PES7, "z-landmark-cp.rds")); da <- readRDS(file.path(PES7, "firme-attive-cp.rds"))
fondo <- colnames(x$fondo)
# Una sola tabella (gruppo, linea) x geni: fondo per pert_id, entita' per contrast_entity.
Lm <- function(sg) { sg[, chiave := paste(gruppo, cell_iname, sep = "\r")]; s <- rowsum(t(M[, sg$sig_id, drop = FALSE]), sg$chiave, reorder = FALSE); s / as.numeric(table(sg$chiave)[rownames(s)]) }
Lf <- Lm(da[pert_id %in% fondo, .(sig_id, gruppo = pert_id, cell_iname)])
se <- merge(ent, da[, .(sig_id, pert_id, cell_iname)], by = "pert_id", allow.cartesian = TRUE)
Le <- Lm(se[, .(sig_id, gruppo = contrast_entity, cell_iname)])
gf <- sub("\r.*", "", rownames(Lf)); ge <- sub("\r.*", "", rownames(Le))
media_gruppo <- function(L, g, tieni) { s <- rowsum(L[tieni, , drop = FALSE], g[tieni], reorder = FALSE); t(s / as.numeric(table(g[tieni])[rownames(s)])) }
meta2 <- function(g) { i <- split(seq_along(g), g); m2 <- integer(0L); m1 <- integer(0L)
  for (v in i) { n <- length(v); p <- if (n == 1L) v else sample(v); k <- n %/% 2L; if (k > 0L) m1 <- c(m1, p[seq_len(k)]); m2 <- c(m2, p[seq(k + 1L, n)]) }
  list(m1 = m1, m2 = m2) }
set.seed(SEME)
ents <- unique(ge); res <- matrix(NA_real_, length(ents), 20L, dimnames = list(ents, NULL))
for (d in 1:20) {
  sf <- meta2(gf); se2 <- meta2(ge)
  F2 <- media_gruppo(Lf, gf, sf$m2); R2 <- ranghi(F2)
  Q1 <- media_gruppo(Le, ge, se2$m1)[, ents, drop = FALSE]; T2 <- media_gruppo(Le, ge, se2$m2)[, ents, drop = FALSE]
  RQ <- ranghi(Q1); RT <- ranghi(T2)
  S <- cor(RQ, R2); st <- diag(cor(RQ, RT))
  for (e in ents) { via <- ent[contrast_entity == e, pert_id]; tieni <- setdiff(colnames(R2), via); res[e, d] <- mean(S[e, tieni] < st[e]) }
  cat(sprintf("divisione %d: H = %.3f\n", d, mean(res[, d] >= .9)))
}
fwrite(data.table(contrast_entity = ents, res), file.path(E7, "40-h-meta-per-composto.csv"))
per <- rowMeans(res >= .9); H <- mean(per)
set.seed(SEME); b <- replicate(BOOT, mean(sample(per, replace = TRUE))); ic <- quantile(b, c(.025, .975))
cat(sprintf("\nH_meta' = %.3f, IC95 bootstrap [%.3f; %.3f], su %d composti e 20 divisioni\n", H, ic[1], ic[2], length(per)))
