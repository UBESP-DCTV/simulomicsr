#!/usr/bin/env Rscript
# (a) asse dei geni: quanti geni misura L1000 e quanti dei nostri li intersecano
# (b) CONTEGGIO 2 - circolarita': GSE in comune fra il nostro corpus e LINCS

suppressMessages({library(data.table); library(arrow)})
DIR <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
LIN <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
OUT <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"
log <- function(...) cat(sprintf(...), "\n", sep = "")

# ============================================================ (a) asse dei geni
gi <- fread(file.path(LIN, "geneinfo_beta.txt"), sep = "\t", quote = "",
            colClasses = "character")
gi[ensembl_id %in% c("", "\"\""), ensembl_id := NA_character_]
log("=== ASSE DEI GENI ===")
log("LINCS geneinfo: %d righe", nrow(gi))
print(table(gi$feature_space))
log("con ensembl_id: %d/%d", sum(!is.na(gi$ensembl_id)), nrow(gi))
land <- gi[feature_space == "landmark"]
log("landmark: %d (con ensembl: %d)", nrow(land), sum(!is.na(land$ensembl_id)))

# nostro asse: gene_id Ensembl da cluster_pooled
ds <- open_dataset(file.path(DIR, "cluster_pooled.parquet"))
log("cluster_pooled: %d righe", nrow(ds))
gn <- ds |> dplyr::select(gene_id, gene_symbol) |> dplyr::distinct() |>
  dplyr::collect() |> as.data.table()
gn <- unique(gn)
log("nostri geni distinti (gene_id Ensembl): %d", uniqueN(gn$gene_id))

our  <- unique(sub("\\..*", "", gn$gene_id))         # via versione, se presente
land_e <- unique(na.omit(land$ensembl_id))
all_e  <- unique(na.omit(gi$ensembl_id))
log("")
log("intersezione LANDMARK (978) x nostro asse : %d / %d landmark-con-ensembl",
    length(intersect(our, land_e)), length(land_e))
log("intersezione TUTTO L1000 x nostro asse    : %d / %d",
    length(intersect(our, all_e)), length(all_e))
# controprova per simbolo
oursym <- unique(toupper(na.omit(gn$gene_symbol)))
log("controprova per SIMBOLO, landmark         : %d / %d",
    length(intersect(oursym, toupper(land$gene_symbol))), nrow(land))

# ==================================================== (b) circolarita': i GSE
d <- readRDS(file.path(DIR, "deliverable-annotato.rds"))
gse <- sort(unique(unlist(d$studies_in_cluster)))
log("")
log("=== CIRCOLARITA' ===")
log("GSE distinti nelle 214 meta-analisi: %d", length(gse))
log("formato (primi 5): %s", paste(utils::head(gse, 5), collapse = ", "))
log("tutti conformi a ^GSE[0-9]+$: %s", all(grepl("^GSE[0-9]+$", gse)))

lincs_gse <- c("GSE92742", "GSE70138", "GSE106127", "GSE5258", "GSE92743",
               "GSE101406", "GSE114949", "GSE68427")
log("")
log("serie GEO di deposito LINCS/CMap controllate: %s", paste(lincs_gse, collapse = ", "))
inter <- intersect(gse, lincs_gse)
log("INTERSEZIONE ESATTA: %d  -> %s", length(inter),
    if (length(inter)) paste(inter, collapse = ", ") else "(nessuna)")

# ---- piattaforme davvero presenti nel nostro corpus
gpl <- sort(table(unlist(d$gpl_platforms)), decreasing = TRUE)
log("")
log("piattaforme (GPL) distinte nel deliverable: %d", length(gpl))
log("prime 15 per numero di meta-analisi in cui compaiono:")
print(utils::head(gpl, 15))

# GPL del L1000 (Luminex) secondo GEO: GPL20573 / GPL22664 (LINCS L1000)
l1000_gpl <- c("GPL20573", "GPL22664", "GPL15540")
log("")
log("GPL L1000/Luminex controllati: %s", paste(l1000_gpl, collapse = ", "))
log("presenti nel nostro corpus: %s",
    if (length(intersect(names(gpl), l1000_gpl))) paste(intersect(names(gpl), l1000_gpl), collapse = ", ") else "(nessuno)")

fwrite(data.table(gse = gse), file.path(OUT, "gse-del-deliverable.csv"))
fwrite(data.table(gpl = names(gpl), n_meta = as.integer(gpl)),
       file.path(OUT, "gpl-del-deliverable.csv"))
log("")
log("scritti: gse-del-deliverable.csv (%d), gpl-del-deliverable.csv (%d)",
    length(gse), length(gpl))
