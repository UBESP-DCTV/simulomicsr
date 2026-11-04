#!/usr/bin/env Rscript
# Cancello 5: il controllo vede l'inversione nota? Stime per studio dopo il collasso dei bracci (T0) contro TCGA-LIHC.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
land <- landmark(); tt <- readRDS(file.path(PES7, "tcga-t.rds"))
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
cc <- d[contrast_entity == "MeSH:D006528", cluster_id]; stopifnot(length(cc) == 1L)
st <- as.data.table(readRDS(file.path("/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio", paste0(cc, ".rds"))))
st[, id := sub("[.].*", "", gene_id)]; st[, q := d0 / se0]; st[!is.finite(q), q := NA_real_]
stopifnot(!anyDuplicated(st, by = c("study_id", "id")), "GSE144269" %in% st$study_id)
tl <- setNames(tt[, "TCGA-LIHC"], rownames(tt))
ris <- st[, { a <- intersect(id[!is.na(q)], names(tl)[!is.na(tl)]); qq <- setNames(q, id)[a]; la <- intersect(a, land$ensembl_id)
  .(geni = length(a), r_tutti = cor(qq, tl[a], method = "spearman"), geni_land = length(la), r_land = cor(qq[la], tl[la], method = "spearman")) }, by = study_id]
print(as.data.frame(ris[order(r_tutti)]), digits = 3); fwrite(ris, file.path(E7, "69-cancello-5.csv"))
a <- ris[study_id == "GSE144269", r_tutti]; b <- ris[study_id != "GSE144269", median(r_tutti)]; al <- ris[study_id == "GSE144269", r_land]; bl <- ris[study_id != "GSE144269", median(r_land)]
cat(sprintf("\nCANCELLO 5: GSE144269 r = %.3f (landmark %.3f); mediana degli altri %.3f (landmark %.3f). %s\n", a, al, b, bl, if (a < 0 && b > 0) "PASSA" else "FALLISCE"))
