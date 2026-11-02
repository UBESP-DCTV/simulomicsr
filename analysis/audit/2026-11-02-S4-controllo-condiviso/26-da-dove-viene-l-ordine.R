#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/26-da-dove-viene-l-ordine.R
# Da dove puo' venire l'ordine sbagliato in cache: dentro le 194 un insieme di campioni ha due
# divisioni in ruoli? Il dispatch del riferimento ha gli stessi insiemi con altri ruoli?
suppressPackageStartupMessages(library(data.table))
RIL <- "analysis/audit/2026-08-20-rilettura-194"
A <- as.data.table(readRDS(file.path(RIL, "dispatch-A3.rds"))$tenuti); R <- as.data.table(readRDS(file.path(RIL, "dispatch-RIF.rds"))$tenuti)
un <- function(a, b) vapply(strsplit(paste(a, b, sep = ","), ",", fixed = TRUE), function(z) paste(sort(z), collapse = ","), "")
A[, ins := un(gsm_t, gsm_c)]; R[, ins := un(gsm_t, gsm_c)]
s <- A[, .(n = .N, ruoli = uniqueN(gsm_t)), by = .(study_id, ins)]
cat("insiemi con piu' di una divisione in ruoli, dentro le 194:", sum(s$ruoli > 1), "\n")
for (q in list(c("GSE222992", "grp_0007"), c("GSE208347", "grp_0002"), c("GSE135485", "group_0001"))) {
  a <- A[study_id == q[1] & treated_group == q[2]]
  r <- R[study_id == q[1] & ins %in% a$ins]
  cat(q[1], ": confronti con lo stesso insieme nel riferimento:", nrow(r), "\n")
  if (nrow(r)) print(r[, .(cluster_id, treated_group, control_group, n_t, n_c, trattati_uguali = gsm_t == a$gsm_t[1], ruoli_invertiti = gsm_t == a$gsm_c[1])])
}
