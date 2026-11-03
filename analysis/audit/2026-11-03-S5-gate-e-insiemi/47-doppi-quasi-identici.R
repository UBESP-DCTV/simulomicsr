#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/47-doppi-quasi-identici.R
# L'impronta esatta (46) vede 2 campioni su 5 dove le stime hanno correlazione 1: lo stesso dato
# riallineato non da' conte identiche al bit. Qui la misura e' la distanza L1 relativa fra due
# campioni di studi diversi dello stesso gruppo: somma|a-b| / somma(a+b). Si confrontano le coppie
# con somma delle conte entro lo 0,5%. Il confine si legge dalla distribuzione, sulle tre coppie note.
# Uso: WORKERS=16 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/47-doppi-quasi-identici.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
D <- readRDS(file.path(PES5, "dispatch-A3.rds"))
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
gr <- c(d$cluster_id, D$candidati[k_eff == 2L, cluster_id])
ten <- D$tenuti[cluster_id %in% gr]
lung <- ten[, .(gsm = unique(unlist(strsplit(c(gsm_t, gsm_c), ",", fixed = TRUE)))), by = .(cluster_id, study_id)]
imp <- fread(file.path(PES5, "impronte-campioni.csv"))
lung <- merge(lung, imp[, .(study_id, gsm, somma)], by = c("study_id", "gsm"))
lung <- lung[somma > 0]
TOL <- 0.005
cand <- rbindlist(lapply(split(lung, lung$cluster_id), function(x) {
  x <- x[order(somma)]; n <- nrow(x); s <- x$somma; st <- x$study_id; g <- x$gsm
  j <- findInterval(s * (1 + TOL), s)   # ultimo indice entro la tolleranza
  ii <- rep(seq_len(n), pmax(j - seq_len(n), 0L))
  if (!length(ii)) return(NULL)
  jj <- unlist(lapply(seq_len(n), function(i) if (j[i] > i) (i + 1L):j[i] else integer()))
  tieni <- st[ii] != st[jj]
  data.table(cluster_id = x$cluster_id[1], sa = st[ii][tieni], ga = g[ii][tieni], sb = st[jj][tieni], gb = g[jj][tieni])
}))
un <- unique(cand[, .(ga, gb)])
cat(sprintf("coppie di campioni candidate: %d (distinte %d)\n", nrow(cand), nrow(un)))
serve <- unique(rbind(cand[, .(study_id = sa, gsm = ga)], cand[, .(study_id = sb, gsm = gb)]))
serve <- serve[!duplicated(gsm)]
invisible(.fetch_counts_from_h5(serve$study_id[1], serve$gsm[1:2], H5, gene_biotype_filter = "protein_coding")); rhdf5::h5closeAll()
ls <- split(serve$gsm, serve$study_id)
t0 <- Sys.time()
mm <- mclapply(names(ls), function(s) {
  m <- .fetch_counts_from_h5(s, ls[[s]], H5, gene_biotype_filter = "protein_coding")
  storage.mode(m) <- "double"; attr(m, "gene_symbol") <- NULL; m
}, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(mm, inherits, TRUE, "try-error"); stopifnot(!any(err))
ge <- rownames(mm[[1]]); stopifnot(all(vapply(mm, function(m) identical(rownames(m), ge), TRUE)))
C <- do.call(cbind, mm); rm(mm); gc()
cat(sprintf("matrice %d x %d in %.1f min\n", nrow(C), ncol(C), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
blocchi <- split(seq_len(nrow(un)), cut(seq_len(nrow(un)), WORKERS * 4L, labels = FALSE))
ia <- match(un$ga, colnames(C)); ib <- match(un$gb, colnames(C)); stopifnot(!anyNA(ia), !anyNA(ib))
l1 <- unlist(mclapply(blocchi, function(q) colSums(abs(C[, ia[q], drop = FALSE] - C[, ib[q], drop = FALSE])) / colSums(C[, ia[q], drop = FALSE] + C[, ib[q], drop = FALSE]), mc.cores = WORKERS), use.names = FALSE)
un[, l1 := l1]
cat("distribuzione della distanza L1 relativa sulle coppie candidate:\n")
print(un[, .N, keyby = .(fascia = cut(l1, c(-1, 1e-9, 1e-3, 3e-3, 0.01, 0.02, 0.03, 0.05, 0.1, 0.2, 2)))])
cand <- merge(cand, un, by = c("ga", "gb"))
fwrite(cand[l1 < 0.2], file.path(PES5, "coppie-campioni-vicine.csv"))
for (p in list(c("GSE154613", "GSE159522"), c("GSE108743", "GSE89725"), c("GSE156038", "GSE222279"), c("GSE156038", "GSE156184"), c("GSE156184", "GSE222279"), c("GSE225522", "GSE225523"), c("GSE244485", "GSE244486"), c("GSE73628", "GSE83083"), c("GSE147449", "GSE149004"))) {
  x <- cand[(sa == p[1] & sb == p[2]) | (sa == p[2] & sb == p[1])]
  x <- unique(x[, .(ga, gb, l1)])[order(l1)]
  cat(p, ": coppie", nrow(x), "| L1 piu' basse:", paste(sprintf("%.2g", head(x$l1, 8)), collapse = " "), "\n")
}
