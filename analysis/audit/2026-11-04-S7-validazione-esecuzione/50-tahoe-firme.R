#!/usr/bin/env Rscript
# Passo A, punto 5. Accordo fra le fonti H_fonti: Tahoe interroga LINCS. Nessuna stima del deliverable.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
suppressPackageStartupMessages({library(arrow); library(parallel)})
fl <- sort(list.files(file.path(LV5, "tahoe100m"), pattern = "[.]parquet$", full.names = TRUE)); cat("file:", length(fl), "\n"); stopifnot(length(fl) == 1026L)
# Prima passata: concentrazione massima di ogni farmaco, dai metadati delle righe, un file alla volta.
col <- c("gene_name","stat","plate","drug","concentration","Cell_Name_Vevo")
leggi <- function(f) as.data.table(read_parquet(f, col_select = dplyr::all_of(col)))
set_cpu_count(1L); setDTthreads(1L)
t0 <- Sys.time()
conc <- rbindlist(mclapply(fl, function(f) { d <- leggi(f); unique(d[, .(drug, concentration)]) }, mc.cores = 32L, mc.preschedule = FALSE))
stopifnot(!anyNA(conc$drug)); cmax <- conc[, .(cmax = max(concentration)), by = drug]
cat("farmaci:", nrow(cmax), "; concentrazioni distinte per farmaco:", paste(names(table(conc[, uniqueN(concentration), by = drug]$V1)), collapse = ","), "\n")
cat("unita' di concentrazione: controllate nella seconda passata\n"); cat("prima passata:", format(Sys.time() - t0), "\n")
# Seconda passata: per ogni file, la somma di stat per farmaco, linea e gene, alla concentrazione massima.
parti <- mclapply(fl, function(f) {
  d <- leggi(f)
  d <- merge(d, cmax, by = "drug")[concentration == cmax & !is.na(stat)]
  d[, .(somma = sum(stat), n = .N), by = .(drug, Cell_Name_Vevo, gene_name)]
}, mc.cores = 32L, mc.preschedule = FALSE)
err <- vapply(parti, inherits, TRUE, what = "try-error"); stopifnot(!any(err))
p <- rbindlist(parti); rm(parti); setDTthreads(32L)
p <- p[, .(z = sum(somma) / sum(n)), by = .(drug, Cell_Name_Vevo, gene_name)]          # media dentro la linea
g <- p[, .(val = mean(z), linee = .N), by = .(drug, gene_name)]                         # poi fra le linee
cat("righe farmaco x gene:", nrow(g), "; geni:", uniqueN(g$gene_name), "; farmaci:", uniqueN(g$drug), "; mediana linee:", median(g$linee), "\n")
Tm <- dcast(g, gene_name ~ drug, value.var = "val"); gn <- Tm$gene_name; Tm <- as.matrix(Tm[, -1L]); rownames(Tm) <- gn
saveRDS(Tm, file.path(PES7, "tahoe-firme.rds"), compress = FALSE)
cat("tempo:", format(Sys.time() - t0), "\n")
