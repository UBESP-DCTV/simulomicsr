#!/usr/bin/env Rscript
# Passo A, punto 2. Solo fonti: nessuna stima del deliverable.
# Legge le z dei 978 landmark per tutte le firme exemplar attive e costruisce le firme del fondo e delle entita'.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
suppressPackageStartupMessages(library(rhdf5))
t0 <- Sys.time()
si <- leggi_si(); land <- landmark()
sa <- attive(si[pert_type == "trt_cp"])
ln <- sa[, .(linee = uniqueN(cell_iname)), by = pert_id]; fondo <- ln[linee >= 3L, pert_id]
n_firme <- sa[pert_id %in% fondo, .N]
cat("composti del fondo:", length(fondo), "; firme:", n_firme, "\n")
cop <- fread(file.path(S6, "50-copertura-con-tahoe.csv")); ag <- fread(file.path(S6, "40-aggancio-con-elenco.csv"))
pm <- merge(cop[misurabile == TRUE & classe == "piccola molecola", .(cluster_id, contrast_entity, nome, insieme, k, metodo_match)], ag[, .(contrast_entity, pert_id)], by = "contrast_entity")
print(pm[, .N, keyby = insieme])
stopifnot(length(fondo) == 5466L, n_firme == 36204L, pm[insieme == "40", .N] == 19L, pm[insieme == "132", .N] == 53L, pm[insieme == "fuori", .N] == 8L)
ent <- pm[, .(pert_id = strsplit(pert_id, ";", fixed = TRUE)[[1]]), by = contrast_entity]

# Le firme da leggere: tutte quelle attive dei composti del fondo o di un'entita'.
da <- sa[pert_id %in% fondo | pert_id %in% ent$pert_id]
leggi_gctx <- function(file, sig) {
  stopifnot(file.exists(file))
  righe <- as.character(h5read(file, "0/META/ROW/id")); col <- as.character(h5read(file, "0/META/COL/id"))
  ir <- match(land$gene_id, righe); ic <- match(sig, col)
  stopifnot(!anyNA(ir), !anyNA(ic))
  o <- order(ic); ic <- ic[o]
  # Righe intere e poi solo i landmark: una selezione HDF5 su 978 righe non contigue per molte colonne si blocca.
  # Il file e' contiguo, quindi leggere una colonna intera costa poco. Blocchi di 2.000 colonne del file.
  sp <- split(ic, (ic - 1L) %/% 2000L)
  M <- matrix(NA_real_, length(ir), length(ic), dimnames = list(land$gene_id, sig[o]))
  k <- 0L; t1 <- Sys.time()
  for (i in seq_along(sp)) {
    x <- h5read(file, "0/DATA/0/matrix", index = list(NULL, sp[[i]]))
    M[, k + seq_along(sp[[i]])] <- x[ir, , drop = FALSE]; k <- k + length(sp[[i]])
    if (i %% 50L == 0L) cat(sprintf("blocco %d/%d, %.1f min\n", i, length(sp), as.numeric(difftime(Sys.time(), t1, units = "mins"))))
  }
  M
}
cat("firme da leggere:", nrow(da), "\n")
system.time(M <- leggi_gctx(GCTX_CP, da$sig_id))
cat("valori mancanti:", sum(is.na(M)), "\n"); stopifnot(!anyNA(M))
saveRDS(M, file.path(PES7, "z-landmark-cp.rds"), compress = FALSE)
saveRDS(da, file.path(PES7, "firme-attive-cp.rds"))
# firme del fondo e delle entita'
Fo <- firme_per_gruppo(M, da[pert_id %in% fondo, .(sig_id, gruppo = pert_id, cell_iname)])
stopifnot(ncol(Fo) == 5466L, nrow(Fo) == 978L)
se <- merge(ent, da[, .(sig_id, pert_id, cell_iname)], by = "pert_id", allow.cartesian = TRUE)
Fe <- firme_per_gruppo(M, se[, .(sig_id, gruppo = contrast_entity, cell_iname)])
stopifnot(ncol(Fe) == 80L)
saveRDS(list(fondo = Fo, entita = Fe, pm = pm, ent = ent, land = land), file.path(PES7, "firme.rds"), compress = FALSE)
cat("linee per entita' (min, mediana, max):", range(se[, uniqueN(cell_iname), by = contrast_entity]$V1), median(se[, uniqueN(cell_iname), by = contrast_entity]$V1), "\n")
cat("tempo totale:", format(Sys.time() - t0), "\n")
