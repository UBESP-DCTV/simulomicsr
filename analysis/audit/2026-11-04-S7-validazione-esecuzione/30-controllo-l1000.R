#!/usr/bin/env Rscript
# Passo A, punto 3. Cancello 4: il primo composto interroga il secondo, sul fondo.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
x <- readRDS(file.path(PES7, "firme.rds")); Fo <- x$fondo
M <- readRDS(file.path(PES7, "z-landmark-cp.rds")); da <- readRDS(file.path(PES7, "firme-attive-cp.rds"))
ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character")
norm <- function(s) gsub("[- ]+", "-", tolower(s))
pert_di <- function(n) { p <- unique(ci[norm(cmap_name) == norm(n) | norm(compound_aliases) == norm(n), pert_id]); intersect(p, da$pert_id) }
coppie <- list(c("romidepsin","trichostatin A"), c("romidepsin","vorinostat"), c("trichostatin A","vorinostat"), c("bortezomib","carfilzomib"), c("thapsigargin","tunicamycin"))
firma <- function(p) drop(firme_per_gruppo(M, da[pert_id %in% p, .(sig_id, gruppo = "x", cell_iname)]))
ris <- rbindlist(lapply(coppie, function(cc) {
  a <- pert_di(cc[1]); b <- pert_di(cc[2]); stopifnot(length(a) > 0L, length(b) > 0L)
  q <- firma(a); giusto <- firma(b); bg <- Fo[, setdiff(colnames(Fo), c(a, b)), drop = FALSE]
  sp <- function(q) { s <- sim_q(q, bg); sg <- cor(q, giusto, method = "spearman"); rango_p(sg, s) }
  data.table(query = cc[1], bersaglio = cc[2], pert_query = paste(a, collapse = ";"), pert_bersaglio = paste(b, collapse = ";"), P = sp(q), P_invertita = sp(-q))
}))
ris[, primo_10 := P >= 0.90]; ris[, abbassa := P_invertita < P]
print(as.data.frame(ris), right = FALSE); fwrite(ris, file.path(E7, "30-controllo-l1000.csv"))
# la forma veloce coincide con la definizione di riferimento del disegno
set.seed(SEME); q <- Fo[, sample(ncol(Fo), 1L)]; names(q) <- rownames(Fo); sub <- Fo[, sample(ncol(Fo), 200L)]; q[sample(978L, 40L)] <- NA
r1 <- cor(q, sub, method = "spearman", use = "pairwise.complete.obs")[1L, ]; r2 <- sim_q(q, sub); cat("differenza massima con cor() di riferimento:", max(abs(r1 - r2)), "\n"); stopifnot(max(abs(r1 - r2)) < 1e-12)
cat("\nCANCELLO 4:", sum(ris$primo_10), "coppie su 5 nel primo 10% (servono 4); invertita piu' bassa in", sum(ris$abbassa), "su 5\n")
cat(if (sum(ris$primo_10) >= 4L && all(ris$abbassa)) "PASSA\n" else "FALLISCE\n")
