#!/usr/bin/env Rscript
# Passo A, punto 6. TCGA: tumore contro normale appaiati, ~ paziente + tipo. Nessuna stima del deliverable.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
suppressPackageStartupMessages({library(limma); library(edgeR)})
cp <- fread(file.path(E7, "10-tcga-coppie.tsv")); D <- file.path(LV5, "tcga")
cat("coppie per progetto:\n"); print(cp[, .(coppie = uniqueN(caso), file = .N), keyby = progetto])
stopifnot(all(cp[, .N, by = .(progetto, caso)]$N == 2L))
leggi <- function(id) { x <- fread(file.path(D, paste0(id, ".tsv")), skip = 1L, select = c("gene_id","gene_name","unstranded")); x[grepl("^ENSG", gene_id) & !grepl("_PAR_Y", gene_id)] }
primo <- leggi(cp$file_id[1]); ids <- sub("[.].*", "", primo$gene_id); stopifnot(!anyDuplicated(ids))
tt <- matrix(NA_real_, nrow(primo), uniqueN(cp$progetto), dimnames = list(ids, sort(unique(cp$progetto))))
sez <- list()
for (pr in colnames(tt)) {
  s <- cp[progetto == pr]
  C <- vapply(s$file_id, function(id) { x <- leggi(id); stopifnot(identical(x$gene_id, primo$gene_id)); as.numeric(x$unstranded) }, numeric(nrow(primo)))
  rownames(C) <- ids
  s[, tipo2 := factor(ifelse(tipo == "Solid Tissue Normal", "normale", "tumore"), c("normale","tumore"))]
  des <- model.matrix(~ factor(caso) + tipo2, data = s)
  dge <- DGEList(C); keep <- filterByExpr(dge, des); dge <- calcNormFactors(dge[keep, , keep.lib.sizes = FALSE])
  v <- voom(dge, des); fit <- eBayes(lmFit(v, des))
  tv <- fit$t[, "tipo2tumore"]; tt[names(tv), pr] <- tv
  sez[[pr]] <- data.table(progetto = pr, coppie = uniqueN(s$caso), geni = sum(keep), sig = sum(p.adjust(fit$p.value[, "tipo2tumore"], "BH") < .05))
  cat(pr, "fatto\n")
}
print(rbindlist(sez)); fwrite(rbindlist(sez), file.path(E7, "60-tcga-progetti.csv"))
saveRDS(tt, file.path(PES7, "tcga-t.rds"))
gl <- landmark(); cc <- cor(tt[rownames(tt) %in% gl$ensembl_id, ], use = "pairwise.complete.obs", method = "spearman")
cat("\ncorrelazione fra progetti sui landmark, mediana fuori diagonale:", round(median(cc[upper.tri(cc)]), 3), "\n")
# controllo positivo interno: COAD e READ, KIRC e KIRP devono somigliarsi
cat("COAD-READ:", round(cc["TCGA-COAD","TCGA-READ"], 3), " KIRC-KIRP:", round(cc["TCGA-KIRC","TCGA-KIRP"], 3), " LUAD-LUSC:", round(cc["TCGA-LUAD","TCGA-LUSC"], 3), "\n")
