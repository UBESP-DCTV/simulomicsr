#!/usr/bin/env Rscript
# La ricerca di un errore, dopo H sopra 70%: controlli E1-E8 di 72-ricerca-errore-previsioni.md. Non cambia il verdetto.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
v <- readRDS(file.path(PES7, "verdetto.rds")); pm <- as.data.table(v$pm); Qs <- v$Qs; pert <- v$pert
x <- readRDS(file.path(PES7, "firme.rds")); Fo <- x$fondo; Fe <- x$entita; ent <- x$ent
M <- readRDS(file.path(PES7, "z-landmark-cp.rds")); da <- readRDS(file.path(PES7, "firme-attive-cp.rds"))
cop <- fread(file.path(S6, "50-copertura-con-tahoe.csv"))
cs <- fread(file.path(E7, "70-coppie-scambio.csv"))
q72 <- pm[insieme %in% c("40","132")]
# ---- E1: la definizione del disegno, alla lettera
rango <- function(q, firme, giusto) {
  s <- cor(q, firme, method = "spearman", use = "pairwise.complete.obs")[1, ]
  mean(s[setdiff(colnames(firme), giusto)] < mean(s[giusto]))
}
e1 <- vapply(seq_len(nrow(q72)), function(i) { e <- q72$contrast_entity[i]; q <- Qs[[q72$cluster_id[i]]][rownames(Fo)]
  rango(q, cbind(Fo[, setdiff(colnames(Fo), pert[[e]]), drop = FALSE], GIUSTO = Fe[, e]), "GIUSTO") }, 0)
cat("E1: differenza massima fra il rango di riferimento e quello del verdetto:", max(abs(e1 - q72$P)), "\n")
# ---- E2
sing <- ent[, .(n = .N, p = pert_id[1]), by = contrast_entity][n == 1L & p %in% colnames(Fo)]
e2 <- vapply(seq_len(nrow(sing)), function(i) max(abs(Fe[, sing$contrast_entity[i]] - Fo[, sing$p[i]])), 0)
cat("E2: entita' con un solo pert_id misurabile:", nrow(sing), "; differenza massima con la colonna del fondo:", max(e2), "\n")
# ---- similarita' di ogni interrogazione col fondo: si riusa sotto
s_f <- list(); Rs <- NULL
set.seed(SEME); e3 <- matrix(NA_real_, nrow(q72), 99L)
t0 <- Sys.time()
for (i in seq_len(nrow(pm))) {
  e <- pm$contrast_entity[i]; q <- Qs[[pm$cluster_id[i]]]; g <- intersect(names(q)[!is.na(q)], rownames(Fo)); R <- ranghi(Fo[g, , drop = FALSE])
  s_f[[e]] <- drop(cor(rank(q[g]), R))
  j <- match(e, q72$contrast_entity)
  if (!is.na(j)) { keep <- setdiff(colnames(R), pert[[e]]); Rk <- R[, keep, drop = FALSE]; tg <- rank(Fe[g, e])
    for (b in 1:99) { qp <- sample(rank(q[g])); e3[j, b] <- mean(drop(cor(qp, Rk)) < cor(qp, tg)) } }
}
cat("similarita' e rimescolamenti:", format(Sys.time() - t0), "\n")
h3 <- colMeans(e3 >= .9); cat(sprintf("E3: H con i geni rimescolati, 99 ripetizioni sui 72: media %.3f, min %.3f, max %.3f; mediana di P %.3f\n", mean(h3), min(h3), max(h3), median(e3)))
# P veloce con fondo senza i pert_id tolti
Pf <- function(e, val, via, tieni = NULL) { s <- s_f[[e]]; if (!is.null(tieni)) s <- s[names(s) %in% tieni]; s <- s[setdiff(names(s), via)]; mean(s < val) }
sv <- function(d, nome) { rbindlist(lapply(c("40","132"), function(k) { z <- d[insieme == k]; data.table(controllo = nome, insieme = k, n = nrow(z), H = mean(z$P >= .9), mediana_P = median(z$P)) })) }
sc <- function(d) { a <- merge(d, q72[, .(e = contrast_entity, insieme)], by = "e"); a[, .(H_scambio = mean(P >= .9), coppie = .N), keyby = insieme] }
ris <- list(); ris_s <- list()
# ---- E4: le firme giuste e sbagliate su 5 linee a caso
se <- merge(ent, da[, .(sig_id, pert_id, cell_iname)], by = "pert_id", allow.cartesian = TRUE)
se[, chiave := paste(contrast_entity, cell_iname, sep = "\r")]
Le <- { s <- rowsum(t(M[, se$sig_id, drop = FALSE]), se$chiave, reorder = FALSE); s / as.numeric(table(se$chiave)[rownames(s)]) }
ge <- sub("\r.*", "", rownames(Le))
lin <- da[pert_id %in% colnames(Fo), .(l = uniqueN(cell_iname)), by = pert_id]; cat("linee per composto nel fondo: mediana", median(lin$l), "; entita', mediana", median(table(ge)), "\n")
idx <- split(seq_along(ge), ge); set.seed(SEME)
e4 <- list(); e4s <- list()
for (b in 1:20) {
  scelte <- lapply(idx, function(v) if (length(v) <= 5L) v else sample(v, 5L))
  D <- vapply(scelte, function(v) colMeans(Le[v, , drop = FALSE]), numeric(ncol(Le))); rownames(D) <- colnames(Le)
  sims <- lapply(seq_len(nrow(q72)), function(i) sim_q(Qs[[q72$cluster_id[i]]], D)); names(sims) <- q72$contrast_entity
  e4[[b]] <- data.table(contrast_entity = q72$contrast_entity, P = vapply(q72$contrast_entity, function(e) Pf(e, sims[[e]][e], pert[[e]]), 0))
  w <- cs[e %in% q72$contrast_entity]
  e4s[[b]] <- w[, .(e, c, P = mapply(function(a, b2) Pf(a, sims[[a]][b2], union(pert[[a]], pert[[b2]])), e, c))]
}
a <- merge(rbindlist(e4)[, .(P = mean(P), succ = mean(P >= .9)), by = contrast_entity], q72[, .(contrast_entity, insieme)], by = "contrast_entity")
h4 <- rbindlist(e4)[q72[, .(contrast_entity, insieme)], on = "contrast_entity"][, .(H = mean(P >= .9), mediana_P = median(P)), keyby = insieme]
s4 <- rbindlist(e4s); s4 <- merge(s4, q72[, .(e = contrast_entity, insieme)], by = "e")[, .(H_scambio = mean(P >= .9)), keyby = insieme]
cat("\nE4: firme su 5 linee a caso, 20 estrazioni\n"); print(merge(h4, s4, by = "insieme"), digits = 3)
fwrite(a, file.path(E7, "72-e4-per-composto.csv"))
# ---- E5: fondo con almeno 10 linee
ten <- lin[l >= 10L, pert_id]; cat("\nE5: composti del fondo con almeno 10 linee:", length(ten), "\n")
d5 <- copy(q72); d5[, P := vapply(seq_len(.N), function(i) Pf(contrast_entity[i], sim_q(Qs[[cluster_id[i]]], Fe[, contrast_entity[i], drop = FALSE]), pert[[contrast_entity[i]]], ten), 0)]
w5 <- cs[e %in% q72$contrast_entity]; simE <- lapply(q72$contrast_entity, function(e) sim_q(Qs[[q72[contrast_entity == e, cluster_id]]], Fe)); names(simE) <- q72$contrast_entity
w5[, P := mapply(function(a, b2) Pf(a, simE[[a]][b2], union(pert[[a]], pert[[b2]]), ten), e, c)]
print(merge(sv(d5, "E5")[, .(insieme, n, H, mediana_P)], sc(w5), by = "insieme"), digits = 3)
# ---- E6: tolta la prima componente del fondo, senza centrare
sv1 <- svd(Fo, nu = 1L, nv = 0L); u <- sv1$u[, 1L]; names(u) <- rownames(Fo); cat("\nE6: varianza spiegata dalla prima componente:", round(sv1$d[1]^2 / sum(sv1$d^2), 3), "\n")
res <- function(A) A - u %*% crossprod(u, A)
Fo6 <- res(Fo); Fe6 <- res(Fe); dimnames(Fo6) <- dimnames(Fo); dimnames(Fe6) <- dimnames(Fe)
qres <- function(q) { g <- names(q)[!is.na(q)]; ug <- u[g] / sqrt(sum(u[g]^2)); q[g] - ug * sum(ug * q[g]) }
Q6 <- lapply(Qs, qres)
sf6 <- lapply(seq_len(nrow(q72)), function(i) sim_q(Q6[[q72$cluster_id[i]]], Fo6)); names(sf6) <- q72$contrast_entity
se6 <- lapply(seq_len(nrow(q72)), function(i) sim_q(Q6[[q72$cluster_id[i]]], Fe6)); names(se6) <- q72$contrast_entity
d6 <- copy(q72); d6[, P := vapply(contrast_entity, function(e) mean(sf6[[e]][setdiff(colnames(Fo), pert[[e]])] < se6[[e]][e]), 0)]
w6 <- cs[e %in% q72$contrast_entity]; w6[, P := mapply(function(a, b2) mean(sf6[[a]][setdiff(colnames(Fo), union(pert[[a]], pert[[b2]]))] < se6[[a]][b2]), e, c)]
print(merge(sv(d6, "E6")[, .(insieme, n, H, mediana_P)], sc(w6), by = "insieme"), digits = 3)
fwrite(d6[, .(contrast_entity, nome, insieme, P_senza_pc1 = P)], file.path(E7, "72-e6-per-composto.csv"))
# ---- E7: H_fonti, selezione
hf <- fread(file.path(E7, "51-h-fonti-per-farmaco.csv")); tp <- fread(file.path(E7, "71-tahoe-per-composto.csv"))
hf[, nel_deliverable := pulisci(drug) %in% pulisci(tp$drug)]
e7 <- hf[, .(n = .N, succ = sum(P >= .9), H = mean(P >= .9), mediana_P = median(P)), by = nel_deliverable]; e7[, lo := mapply(cp_lim, succ, n, "lo")]; e7[, hi := mapply(cp_lim, succ, n, "hi")]
cat("\nE7: H_fonti, Tahoe interroga LINCS, composti nel deliverable o no\n"); print(as.data.frame(e7), digits = 3); fwrite(e7, file.path(E7, "72-e7.csv"))
# ---- E8
li <- se[, .(linee = uniqueN(cell_iname)), by = contrast_entity]; tt <- merge(merge(q72, li, by = "contrast_entity"), cop[, .(contrast_entity, tas_mediana)], by = "contrast_entity")
bo <- function(a, b) { set.seed(SEME); r <- replicate(BOOT, { i <- sample(length(a), replace = TRUE); cor(a[i], b[i], method = "spearman") }); c(cor(a, b, method = "spearman"), quantile(r, c(.025, .975))) }
cat("\nE8: Spearman di P_e con le linee:", round(bo(tt$P, tt$linee), 3), "\n    Spearman di P_e con tas mediano:", round(bo(tt$P, tt$tas_mediana), 3), "\n")
w8 <- cs[e %in% q72$contrast_entity]; w8[, P := as.numeric(P)]; m8 <- merge(w8[, .(medio = mean(P), succ = mean(P >= .9)), by = .(contrast_entity = c)], li, by = "contrast_entity")
cat("    composto sbagliato: Spearman fra la quota di volte nel primo 10% e le sue linee:", round(bo(m8$succ, m8$linee), 3), "\n")
print(m8[order(-succ)][1:8], digits = 3)
fwrite(m8, file.path(E7, "72-e8-sbagliati.csv"))
# ---- aggiunto dopo aver visto Tahoe, non depositato: sugli stessi composti, L1000 e Tahoe
Tm <- readRDS(file.path(PES7, "tahoe-firme.rds")); land <- x$land
tp2 <- merge(tp, pm[, .(contrast_entity, P_L1000 = P, cluster_id)], by = "contrast_entity")
cat("\nAGGIUNTO: stessi composti, L1000 contro Tahoe\n"); print(tp2[insieme %in% c("40","132"), .(n = .N, L1000 = sum(P_L1000 >= .9), Tahoe = sum(P_land >= .9)), keyby = insieme])
g <- as.data.table(arrow::read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id","gene_symbol","logFC_pool","SE_pool")))[cluster_id %in% tp2$cluster_id & gene_symbol %in% land$gene_symbol]
g[, q := logFC_pool / SE_pool]; Ft <- Tm[rownames(Tm) %in% land$gene_symbol, ]; g <- g[!duplicated(g, by = c("cluster_id","gene_symbol"))]
simT <- lapply(split(g, by = "cluster_id"), function(d) { qq <- setNames(d$q, d$gene_symbol); a <- intersect(names(qq), rownames(Ft)); apply(Ft[a, ], 2L, function(v) cor(qq[a], v, method = "spearman", use = "pairwise.complete.obs")) })
tp3 <- tp2[insieme %in% c("40","132")]; ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character"); ci[moa %in% c('""',""), moa := NA]
mo <- lapply(pert, function(p) unique(na.omit(ci[pert_id %in% p, moa])))
ws <- rbindlist(lapply(seq_len(nrow(tp3)), function(i) rbindlist(lapply(setdiff(seq_len(nrow(tp2)), which(tp2$contrast_entity == tp3$contrast_entity[i])), function(j) {
  a <- tp3$contrast_entity[i]; b <- tp2$contrast_entity[j]; if (length(intersect(mo[[a]], mo[[b]])) > 0L || length(intersect(pert[[a]], pert[[b]])) > 0L) return(NULL)
  s <- simT[[tp3$cluster_id[i]]]; dd <- tp2$drug[j]; data.table(e = a, c = b, insieme = tp3$insieme[i], P = mean(s[setdiff(names(s), c(dd, tp3$drug[i]))] < s[dd])) }))))
cat("H_scambio contro Tahoe, sui composti agganciati:\n"); print(ws[, .(coppie = .N, H_scambio = mean(P >= .9), mediana_P = median(P)), keyby = insieme], digits = 3)
fwrite(ws, file.path(E7, "72-scambio-tahoe.csv"))
