#!/usr/bin/env Rscript
# Passo A, punto 5, seconda parte: i farmaci di Tahoe con una firma LINCS misurabile interrogano LINCS.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
x <- readRDS(file.path(PES7, "firme.rds")); land <- x$land; Fo <- x$fondo
Tm <- readRDS(file.path(PES7, "tahoe-firme.rds"))
a <- readRDS(file.path(S6, "10-aggancio.rds")); ci <- as.data.table(a$ci_u)
sf <- fread(file.path(S6, "20-composti-lincs.csv"))[linee_attive >= 3L]
lin <- ci[pert_id %in% sf$pert_id]
lin[, n1 := pulisci(cmap_name)]; lin[, n2 := pulisci(compound_aliases)]
dr <- colnames(Tm); nd <- pulisci(dr)
mappa <- rbindlist(lapply(seq_along(dr), function(i) { p <- unique(lin[n1 == nd[i] | n2 == nd[i], pert_id]); if (length(p)) data.table(drug = dr[i], pert_id = p) }))
cat("farmaci Tahoe con firma LINCS misurabile:", uniqueN(mappa$drug), "(atteso dal disegno: 142)\n")
stopifnot(uniqueN(mappa$drug) == 142L)
sim <- land$gene_symbol; names(sim) <- land$gene_id
gcomuni <- land[gene_symbol %in% rownames(Tm)]; cat("landmark per gene_name in Tahoe:", nrow(gcomuni), "su 978\n")
Fs <- Fo[gcomuni$gene_id, ]; rownames(Fs) <- gcomuni$gene_symbol
M <- readRDS(file.path(PES7, "z-landmark-cp.rds")); da <- readRDS(file.path(PES7, "firme-attive-cp.rds"))
R <- rbindlist(lapply(unique(mappa$drug), function(d) {
  p <- mappa[drug == d, pert_id]; q <- Tm[gcomuni$gene_symbol, d]
  giusto <- drop(firme_per_gruppo(M, da[pert_id %in% p, .(sig_id, gruppo = "x", cell_iname)]))[gcomuni$gene_id]; names(giusto) <- gcomuni$gene_symbol
  ok <- !is.na(q); s <- sim_q(q, Fs[, setdiff(colnames(Fs), p), drop = FALSE]); sg <- cor(q[ok], giusto[ok], method = "spearman")
  data.table(drug = d, pert_id = paste(p, collapse = ";"), geni = sum(ok), sim_giusto = sg, P = rango_p(sg, s))
}))
fwrite(R[order(-P)], file.path(E7, "51-h-fonti-per-farmaco.csv"))
x <- sum(R$P >= .9); n <- nrow(R)
cat(sprintf("H_fonti = %d/%d = %.3f, IC95 esatto [%.3f; %.3f]; mediana di P %.3f\n", x, n, x / n, cp_lim(x, n, "lo"), cp_lim(x, n, "hi"), median(R$P)))
