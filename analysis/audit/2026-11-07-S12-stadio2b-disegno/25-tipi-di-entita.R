#!/usr/bin/env Rscript
# 25-tipi-di-entita.R — S12: quante meta-analisi e quanti confronti del
# deliverable sono per tipo di entita' (kind_effective_resolved). Serve alla
# decisione del PI sui donatori diversi nei confronti malattia contro sani.
# Nota: kind_effective_resolved sbaglia il tipo in parte dei casi (finding S6).
A3_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
d <- readRDS(file.path(A3_POOL, "deliverable-annotato.rds"))
A <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
k <- d$kind_effective_resolved[match(A$cluster_id, d$cluster_id)]
tab <- merge(as.data.frame(table(tipo = d$kind_effective_resolved), responseName = "meta_analisi"),
             as.data.frame(table(tipo = k), responseName = "confronti"))
print(tab[order(-tab$meta_analisi), ], row.names = FALSE)
cat("totale:", sum(tab$meta_analisi), "meta-analisi,", sum(tab$confronti), "confronti\n")
