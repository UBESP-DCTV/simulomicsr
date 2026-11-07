#!/usr/bin/env Rscript
# 20-confronti.R — S10b: i 1.903 confronti con i campioni dei due bracci.
#
# Ingressi: dispatch-A3.rds (elemento `tenuti`: gsm_t, gsm_c dei 1.903 confronti poolati del
# deliverable) e gli ingressi veri della regola di S10 (classe passata alla regola, entita' del
# membro, token dell'entita' `extra_stop`). Non legge il riferimento (30-riferimento.csv).
# Uscita: 20-confronti.csv, 20-gsm.txt.
#
# Uso: Rscript analysis/audit/2026-11-07-S10b-metadati-campioni/20-confronti.R   (senza --vanilla)
suppressPackageStartupMessages(library(data.table))
OUT <- "analysis/audit/2026-11-07-S10b-metadati-campioni"
d <- as.data.table(readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti)
x <- as.data.table(readRDS("analysis/audit/2026-11-07-S10-rilevatore/20-ingressi-regola.rds")$righe)
stopifnot(nrow(d) == 1903L, !anyDuplicated(d$record_id), setequal(d$record_id, x$record_id))
d[x, on = "record_id", `:=`(classe = i.cls_regola, entita = i.entity_regola, extra_stop = i.extra_stop)]
stopifnot(!anyNA(d$classe))
out <- d[, .(cluster_id, study = study_id, record_id, tl = etichetta_trattato, cl = etichetta_controllo,
             classe, entita, extra_stop, gsm_t, gsm_c)]
fwrite(out, file.path(OUT, "20-confronti.csv"))
writeLines(sort(unique(unlist(strsplit(c(d$gsm_t, d$gsm_c), ",")))), file.path(OUT, "20-gsm.txt"))
cat(sprintf("confronti %d, classi: %s\n", nrow(out),
            paste(names(table(out$classe)), table(out$classe), collapse = ", ")))
