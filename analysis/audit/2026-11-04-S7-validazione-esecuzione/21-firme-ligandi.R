#!/usr/bin/env Rscript
# Passo A, per la descrizione dei ligandi (§7, punto 9). Solo fonti. Stessa regola dei composti: fondo di 164 ligandi misurabili.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
suppressPackageStartupMessages(library(rhdf5))
si <- leggi_si(); land <- landmark()
# Il fondo conta i nomi esatti, come il disegno: TGFA e TGFa restano due voci, e nessuna delle due e' un'entita' delle 194.
sa <- attive(si[pert_type == "trt_lig"]); sa[, chi := cmap_name]
ln <- sa[, .(linee = uniqueN(cell_iname)), by = chi]; fondo <- ln[linee >= 3L, chi]
cat("ligandi del fondo:", length(fondo), "; firme:", sa[chi %in% fondo, .N], "\n"); stopifnot(length(fondo) == 164L)
righe <- as.character(h5read(GCTX_LIG, "0/META/ROW/id")); col <- as.character(h5read(GCTX_LIG, "0/META/COL/id"))
ir <- match(land$gene_id, righe); ic <- match(sa$sig_id, col); stopifnot(!anyNA(ir), !anyNA(ic))
o <- order(ic); M <- h5read(GCTX_LIG, "0/DATA/0/matrix", index = list(ir, ic[o])); dimnames(M) <- list(land$gene_id, sa$sig_id[o])
stopifnot(!anyNA(M))
Fl <- firme_per_gruppo(M, sa[chi %in% fondo, .(sig_id, gruppo = chi, cell_iname)])
cat("dimensioni:", dim(Fl), "\n"); saveRDS(Fl, file.path(PES7, "firme-ligandi.rds"), compress = FALSE)
h5closeAll()
