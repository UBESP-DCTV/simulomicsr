#!/usr/bin/env Rscript
# Seconda parte della ricerca di un errore. Rifa' E4, E5, E6 con l'intervallo bootstrap, perche' in 72-ricerca-errore.R
# il parametro k dell'aiutante coincideva con la colonna k: E5 ed E6 avevano n = 0. Rifa' lo scambio contro Tahoe:
# un farmaco con due nomi rendeva NA la media. In piu', NON depositato e dichiarato come tale: LINCS con il fondo dei farmaci di Tahoe.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
v <- readRDS(file.path(PES7, "verdetto.rds")); pm <- as.data.table(v$pm); Qs <- v$Qs; pert <- v$pert
x <- readRDS(file.path(PES7, "firme.rds")); Fo <- x$fondo; Fe <- x$entita; ent <- x$ent; land <- x$land
M <- readRDS(file.path(PES7, "z-landmark-cp.rds")); da <- readRDS(file.path(PES7, "firme-attive-cp.rds"))
cs <- fread(file.path(E7, "70-coppie-scambio.csv"))
q72 <- pm[insieme %in% c("40","132")]; w0 <- cs[e %in% q72$contrast_entity]
s_f <- lapply(seq_len(nrow(q72)), function(i) sim_q(Qs[[q72$cluster_id[i]]], Fo)); names(s_f) <- q72$contrast_entity
s_e <- lapply(seq_len(nrow(q72)), function(i) sim_q(Qs[[q72$cluster_id[i]]], Fe)); names(s_e) <- q72$contrast_entity
# Intervalli: bootstrap sulle meta-analisi; d e' una tabella (e, P) dei giusti, w dei sbagliati.
sintesi <- function(giusti, sbagliati, nome) rbindlist(lapply(c("40","132"), function(insi) {
  es <- q72[insieme == insi, contrast_entity]; g <- giusti[e %in% es]; w <- sbagliati[e %in% es]
  pg <- g[, .(s = mean(P >= .9)), by = e]; pw <- w[, .(s = sum(P >= .9), n = .N), by = e]; ab <- merge(pg, pw, by = "e", suffixes = c("", "w"))
  set.seed(SEME); b <- replicate(BOOT, { i <- sample(nrow(ab), replace = TRUE); c(mean(ab$s[i]), sum(ab$sw[i]) / sum(ab$n[i]), mean(ab$s[i]) - sum(ab$sw[i]) / sum(ab$n[i])) })
  qq <- apply(b, 1L, quantile, c(.025, .975))
  data.table(controllo = nome, insieme = insi, n = nrow(ab), H = mean(ab$s), H_lo = qq[1, 1], H_hi = qq[2, 1], H_scambio = sum(ab$sw) / sum(ab$n), Hs_lo = qq[1, 2], Hs_hi = qq[2, 2], diff = mean(ab$s) - sum(ab$sw) / sum(ab$n), d_lo = qq[1, 3], d_hi = qq[2, 3])
}))
tutto <- list()
# ---- primaria, come termine di confronto
tutto[[1]] <- sintesi(q72[, .(e = contrast_entity, P)], w0[, .(e, c, P)], "primaria")
# ---- E4
se <- merge(ent, da[, .(sig_id, pert_id, cell_iname)], by = "pert_id", allow.cartesian = TRUE); se[, chiave := paste(contrast_entity, cell_iname, sep = "\r")]
Le <- { s <- rowsum(t(M[, se$sig_id, drop = FALSE]), se$chiave, reorder = FALSE); s / as.numeric(table(se$chiave)[rownames(s)]) }
ge <- sub("\r.*", "", rownames(Le)); idx <- split(seq_along(ge), ge); set.seed(SEME)
g4 <- list(); w4 <- list()
Pf <- function(e, val, via, tieni = NULL) { s <- s_f[[e]]; if (!is.null(tieni)) s <- s[names(s) %in% tieni]; s <- s[setdiff(names(s), via)]; mean(s < val) }
for (b in 1:20) {
  scelte <- lapply(idx, function(v) if (length(v) <= 5L) v else sample(v, 5L))
  D <- vapply(scelte, function(v) colMeans(Le[v, , drop = FALSE]), numeric(ncol(Le))); rownames(D) <- colnames(Le)
  sims <- lapply(seq_len(nrow(q72)), function(i) sim_q(Qs[[q72$cluster_id[i]]], D)); names(sims) <- q72$contrast_entity
  g4[[b]] <- data.table(e = q72$contrast_entity, P = vapply(q72$contrast_entity, function(e) Pf(e, sims[[e]][e], pert[[e]]), 0))
  w4[[b]] <- w0[, .(e, c, P = mapply(function(a, b2) Pf(a, sims[[a]][b2], union(pert[[a]], pert[[b2]])), e, c))]
}
tutto[[2]] <- sintesi(rbindlist(g4), rbindlist(w4), "E4 firme su 5 linee")
# ---- E5
lin <- da[pert_id %in% colnames(Fo), .(l = uniqueN(cell_iname)), by = pert_id]; ten <- lin[l >= 10L, pert_id]; cat("E5, composti con almeno 10 linee:", length(ten), "\n")
g5 <- data.table(e = q72$contrast_entity); g5[, P := vapply(e, function(a) Pf(a, s_e[[a]][a], pert[[a]], ten), 0)]
w5 <- w0[, .(e, c, P = mapply(function(a, b2) Pf(a, s_e[[a]][b2], union(pert[[a]], pert[[b2]]), ten), e, c))]
tutto[[3]] <- sintesi(g5, w5, "E5 fondo con almeno 10 linee")
fwrite(merge(g5, q72[, .(e = contrast_entity, nome, insieme)], by = "e"), file.path(E7, "73-e5-per-composto.csv"))
# ---- E6: tolta la prima componente del fondo, senza centrare
sv1 <- svd(Fo, nu = 1L, nv = 0L); u <- sv1$u[, 1L]; names(u) <- rownames(Fo); cat("E6, varianza spiegata dalla prima componente:", round(sv1$d[1]^2 / sum(sv1$d^2), 3), "\n")
res <- function(A) { R <- A - u %*% crossprod(u, A); dimnames(R) <- dimnames(A); R }; Fo6 <- res(Fo); Fe6 <- res(Fe)
qres <- function(q) { g <- names(q)[!is.na(q)]; ug <- u[g] / sqrt(sum(u[g]^2)); q[g] - ug * sum(ug * q[g]) }
sf6 <- list(); se6 <- list(); for (i in seq_len(nrow(q72))) { q <- qres(Qs[[q72$cluster_id[i]]]); a <- q72$contrast_entity[i]; sf6[[a]] <- sim_q(q, Fo6); se6[[a]] <- sim_q(q, Fe6) }
g6 <- data.table(e = q72$contrast_entity); g6[, P := vapply(e, function(a) mean(sf6[[a]][setdiff(colnames(Fo), pert[[a]])] < se6[[a]][a]), 0)]
w6 <- w0[, .(e, c, P = mapply(function(a, b2) mean(sf6[[a]][setdiff(colnames(Fo), union(pert[[a]], pert[[b2]]))] < se6[[a]][b2]), e, c))]
tutto[[4]] <- sintesi(g6, w6, "E6 senza la prima componente")
fwrite(merge(g6, q72[, .(e = contrast_entity, nome, insieme)], by = "e"), file.path(E7, "73-e6-per-composto.csv"))
# ---- NON depositato: LINCS con il fondo dei farmaci che stanno anche in Tahoe
hf <- fread(file.path(E7, "51-h-fonti-per-farmaco.csv")); pt <- unique(unlist(strsplit(hf$pert_id, ";", fixed = TRUE))); pt <- intersect(pt, colnames(Fo)); cat("fondo LINCS ristretto ai farmaci di Tahoe:", length(pt), "pert_id\n")
g7 <- data.table(e = q72$contrast_entity); g7[, P := vapply(e, function(a) Pf(a, s_e[[a]][a], pert[[a]], pt), 0)]
w7 <- w0[, .(e, c, P = mapply(function(a, b2) Pf(a, s_e[[a]][b2], union(pert[[a]], pert[[b2]]), pt), e, c))]
tutto[[5]] <- sintesi(g7, w7, "non depositato: L1000, fondo dei farmaci di Tahoe")
fwrite(merge(g7, q72[, .(e = contrast_entity, nome, insieme)], by = "e"), file.path(E7, "73-fondo-tahoe-per-composto.csv"))
R <- rbindlist(tutto); cat("\nRIASSUNTO\n"); print(as.data.frame(R), digits = 3); fwrite(R, file.path(E7, "73-riassunto.csv"))
# ---- lo scambio contro Tahoe, sui composti agganciati a Tahoe
Tm <- readRDS(file.path(PES7, "tahoe-firme.rds")); tp <- fread(file.path(E7, "71-tahoe-per-composto.csv"))
tp2 <- merge(tp, pm[, .(contrast_entity, P_L1000 = P, cluster_id)], by = "contrast_entity")
g <- as.data.table(arrow::read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id","gene_symbol","logFC_pool","SE_pool")))[cluster_id %in% tp2$cluster_id & gene_symbol %in% land$gene_symbol]
g[, q := logFC_pool / SE_pool]; Ft <- Tm[rownames(Tm) %in% land$gene_symbol, ]; g <- g[!duplicated(g, by = c("cluster_id","gene_symbol"))]
simT <- lapply(split(g, by = "cluster_id"), function(d) { qq <- setNames(d$q, d$gene_symbol); a <- intersect(names(qq), rownames(Ft)); apply(Ft[a, ], 2L, function(v) cor(qq[a], v, method = "spearman", use = "pairwise.complete.obs")) })
ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character"); ci[moa %in% c('""',""), moa := NA]
mo <- lapply(pert, function(p) unique(na.omit(ci[pert_id %in% p, moa])))
farmaci <- function(s) strsplit(s, ";", fixed = TRUE)[[1]]
tp3 <- tp2[insieme %in% c("40","132")]
ws <- rbindlist(lapply(seq_len(nrow(tp3)), function(i) rbindlist(lapply(setdiff(seq_len(nrow(tp2)), which(tp2$contrast_entity == tp3$contrast_entity[i])), function(j) {
  a <- tp3$contrast_entity[i]; b <- tp2$contrast_entity[j]; if (length(intersect(mo[[a]], mo[[b]])) > 0L || length(intersect(pert[[a]], pert[[b]])) > 0L) return(NULL)
  s <- simT[[tp3$cluster_id[i]]]; dd <- farmaci(tp2$drug[j]); data.table(e = a, c = b, insieme = tp3$insieme[i], P = mean(s[setdiff(names(s), c(dd, farmaci(tp3$drug[i])))] < mean(s[dd]))) }))))
cat("\nH_scambio contro Tahoe, sui composti agganciati:\n"); print(ws[, .(coppie = .N, H_scambio = mean(P >= .9), mediana_P = median(P)), keyby = insieme], digits = 3)
tt <- rbind(tp3[, .(fonte = "Tahoe", insieme, succ = P_land >= .9)], tp3[, .(fonte = "L1000", insieme, succ = P_L1000 >= .9)]); print(dcast(tt[, .(x = sum(succ), n = .N), by = .(fonte, insieme)], insieme ~ fonte, value.var = c("x", "n")))
cc <- tp3[, cor(P_land, P_L1000, method = "spearman")]; cat("Spearman fra P contro L1000 e P contro Tahoe, sui 32:", round(cc, 3), "\n")
fwrite(ws, file.path(E7, "73-scambio-tahoe.csv"))
