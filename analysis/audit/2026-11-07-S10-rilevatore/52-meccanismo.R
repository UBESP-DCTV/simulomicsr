#!/usr/bin/env Rscript
# 52-meccanismo.R — S10: perche' i record agganciati cambiano campioni nel master A3?
#
# Ipotesi: i record_id portano un numero d'ordine del gruppo (`grp_0004`,
# `mg29`), e lo Stadio 2 rigenerato numera i gruppi in un altro modo.
# Si conta, sui record DISTINTI con stato «diverso» in 50-tabelle-nomi.rds:
#   - quanti hanno un identificativo numerico del gruppo;
#   - quanti campioni hanno in comune con il record del run vecchio.
#
# Uso: Rscript analysis/audit/2026-11-07-S10-rilevatore/52-meccanismo.R
suppressPackageStartupMessages(library(data.table))
OUT <- "analysis/audit/2026-11-07-S10-rilevatore"
source("analysis/audit/_gsm-lookup-helper.R")
R <- as.data.table(readRDS(file.path(OUT, "50-tabelle-nomi.rds")))
o <- build_record_gsm_lookup("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
a <- build_record_gsm_lookup("analysis/p4-output/A3-stage2-master-innestato.jsonl")
NUM <- "__(grp_[0-9]+|mg[0-9]+)(_vs_(grp_[0-9]+|mg[0-9]+))?$"
d <- unique(R[stato_A3 == "diverso", .(record_id)])
d[, numerico := grepl(NUM, record_id, perl = TRUE)]
d[, n_vecchio := vapply(record_id, function(r) length(get(r, o)), 0L)]
d[, comune := vapply(record_id, function(r) length(intersect(get(r, o), get(r, a))), 0L)]
d[, classe := fifelse(comune == 0L, "nessun campione in comune",
              fifelse(comune >= n_vecchio / 2, "meta' o piu' in comune", "meno di meta' in comune"))]
sink(file.path(OUT, "52-out.txt"), split = TRUE)
cat(sprintf("record distinti con campioni diversi (A3): %d\n", nrow(d)))
cat(sprintf("  con un identificativo numerico del gruppo: %d\n", sum(d$numerico)))
print(d[, .N, by = .(numerico, classe)][order(numerico, classe)])
u <- unique(R[, .(record_id, stato_A3)])
u[, numerico := grepl(NUM, record_id, perl = TRUE)]
cat("\nrecord distinti agganciati, per stato e forma dell'identificativo:\n")
print(dcast(u[, .N, by = .(stato_A3, numerico)], stato_A3 ~ numerico, value.var = "N", fill = 0))
sink()
