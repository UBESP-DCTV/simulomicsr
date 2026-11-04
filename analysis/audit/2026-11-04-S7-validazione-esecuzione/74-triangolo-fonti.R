#!/usr/bin/env Rscript
# NON depositato, aggiunto dopo aver visto Tahoe: perche' contro Tahoe i successi sono meno che contro L1000?
# Confronto sugli stessi composti: stime contro Tahoe, stime contro L1000, L1000 contro Tahoe, Tahoe contro L1000.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
v <- readRDS(file.path(PES7, "verdetto.rds")); pm <- as.data.table(v$pm); Qs <- v$Qs; pert <- v$pert
x <- readRDS(file.path(PES7, "firme.rds")); Fo <- x$fondo; Fe <- x$entita; land <- x$land
Tm <- readRDS(file.path(PES7, "tahoe-firme.rds")); Ft <- Tm[rownames(Tm) %in% land$gene_symbol, ]
stopifnot(!anyNA(Ft)); nd <- pulisci(colnames(Ft))
tp <- fread(file.path(E7, "71-tahoe-per-composto.csv")); tp2 <- merge(tp, pm[, .(contrast_entity, P_L1000 = P, cluster_id)], by = "contrast_entity")
colonne <- function(s) which(nd %in% pulisci(strsplit(s, ";", fixed = TRUE)[[1]]))
stopifnot(all(vapply(tp2$drug, function(s) length(colonne(s)) > 0L, TRUE)))
sim_p <- function(q, F) { g <- intersect(names(q)[!is.na(q)], rownames(F)); drop(cor(rank(q[g]), ranghi(F[g, , drop = FALSE]))) }
# ---- le stime contro Tahoe, e lo scambio
g <- as.data.table(arrow::read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id","gene_symbol","logFC_pool","SE_pool")))[cluster_id %in% tp2$cluster_id & gene_symbol %in% land$gene_symbol]
g[, q := logFC_pool / SE_pool]; g <- g[!duplicated(g, by = c("cluster_id","gene_symbol"))]
simT <- lapply(split(g, by = "cluster_id"), function(d) sim_p(setNames(d$q, d$gene_symbol), Ft))
pr <- function(s, giuste, via) mean(s[-unique(c(giuste, via))] < mean(s[giuste]))
tp2[, P_T := vapply(seq_len(.N), function(i) { k <- colonne(drug[i]); pr(simT[[cluster_id[i]]], k, integer()) }, 0)]
cat("riproduce P_land di 71: differenza massima", max(abs(tp2$P_T - tp2$P_land)), "\n")
ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character"); ci[moa %in% c('""',""), moa := NA]
mo <- lapply(pert, function(p) unique(na.omit(ci[pert_id %in% p, moa])))
tp3 <- tp2[insieme %in% c("40","132")]
ws <- rbindlist(lapply(seq_len(nrow(tp3)), function(i) rbindlist(lapply(which(tp2$contrast_entity != tp3$contrast_entity[i]), function(j) {
  a <- tp3$contrast_entity[i]; b <- tp2$contrast_entity[j]; if (length(intersect(mo[[a]], mo[[b]])) > 0L || length(intersect(pert[[a]], pert[[b]])) > 0L) return(NULL)
  data.table(e = a, c = b, insieme = tp3$insieme[i], P = pr(simT[[tp3$cluster_id[i]]], colonne(tp2$drug[j]), colonne(tp3$drug[i]))) }))))
cat("\nH_scambio contro Tahoe\n"); print(ws[, .(coppie = .N, H_scambio = mean(P >= .9), mediana_P = median(P)), keyby = insieme], digits = 3); cat("tutti e due gli insiemi:", round(mean(ws$P >= .9), 3), "\n")
fwrite(ws, file.path(E7, "74-scambio-tahoe.csv"))
# ---- L1000 interroga Tahoe, sugli stessi composti; Tahoe interroga L1000 viene da 51
sym <- land$gene_symbol; names(sym) <- land$gene_id
tp3[, P_L_a_T := vapply(seq_len(.N), function(i) { q <- Fe[, contrast_entity[i]]; names(q) <- sym[names(q)]; pr(sim_p(q, Ft), colonne(drug[i]), integer()) }, 0)]
hf <- fread(file.path(E7, "51-h-fonti-per-farmaco.csv")); hf[, n := pulisci(drug)]
# Correzione: dentro hf[...] drug[i] era la colonna di hf. Il valore 32 su 32 della prima esecuzione era questo errore.
tp3[, P_T_a_L := vapply(strsplit(drug, ";", fixed = TRUE), function(dd) { nn <- pulisci(dd); z <- hf$P[hf$n %in% nn]; if (length(z)) mean(z) else NA_real_ }, 0)]
fb <- fread(file.path(E7, "73-fondo-tahoe-per-composto.csv")); tp3 <- merge(tp3, fb[, .(contrast_entity = e, P_fondoT = P)], by = "contrast_entity")
riga <- function(nome, p) { p <- p[!is.na(p)]; xx <- sum(p >= .9); n <- length(p); data.table(confronto = nome, n = n, successi = xx, H = xx / n, lo = cp_lim(xx, n, "lo"), hi = cp_lim(xx, n, "hi"), mediana_P = median(p)) }
R <- rbind(riga("stime contro Tahoe", tp3$P_T), riga("stime contro L1000", tp3$P_L1000), riga("stime contro L1000, fondo dei farmaci di Tahoe", tp3$P_fondoT), riga("L1000 contro Tahoe", tp3$P_L_a_T), riga("Tahoe contro L1000", tp3$P_T_a_L))
cat("\nSUGLI STESSI 32 COMPOSTI\n"); print(as.data.frame(R), digits = 3); fwrite(R, file.path(E7, "74-triangolo.csv"))
fwrite(tp3[order(insieme, -P_L1000), .(nome, insieme, drug, P_L1000, P_T, P_L_a_T, P_T_a_L, P_fondoT)], file.path(E7, "74-triangolo-per-composto.csv"))
cat("Spearman, stime contro L1000 e stime contro Tahoe:", round(tp3[, cor(P_L1000, P_T, method = "spearman")], 3), "\n")
