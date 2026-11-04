#!/usr/bin/env Rscript
# Passo B, punto 8 (landmark contro tutti i geni su Tahoe), punto 9 (ligandi, tumori) e cancello 5.
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
suppressPackageStartupMessages(library(arrow))
x <- readRDS(file.path(PES7, "firme.rds")); land <- x$land; pm <- x$pm
Tm <- readRDS(file.path(PES7, "tahoe-firme.rds")); tt <- readRDS(file.path(PES7, "tcga-t.rds"))
cop <- fread(file.path(S6, "50-copertura-con-tahoe.csv"))
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
g <- as.data.table(read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id","gene_id","gene_symbol","logFC_pool","SE_pool")))
g[, q := logFC_pool / SE_pool]; g[!is.finite(q), q := NA_real_]; g[, id := sub("[.].*", "", gene_id)]
rango_gen <- function(q, F, giusti) {
  s <- sim_q(q, F); mean(s[setdiff(colnames(F), giusti)] < mean(s[giusti]))
}
# ---- Tahoe. L'aggancio per nome e' quello di 50-tahoe.R del disegno.
chebi <- readRDS("~/.cache/R/simulomicsr/chebi/chebi-lookup.rds"); al <- as.data.table(chebi$aliases); by <- as.data.table(chebi$by_id)
chembl <- readRDS("~/.cache/R/simulomicsr/chembl/chembl-lookup.rds"); alc <- as.data.table(chembl$aliases); byc <- as.data.table(chembl$by_id)
sin <- function(e, lab) { v <- lab
  if (grepl("^CHEBI:", e)) { n <- as.integer(sub("^CHEBI:", "", e)); v <- c(v, al[chebi_id == n]$alias_lower, by[chebi_id == n]$primary_name, by[chebi_id == n]$ascii_name) }
  if (grepl("^CHEMBL:", e)) { n <- sub("^CHEMBL:", "", e); v <- c(v, alc[chembl_id == n]$alias_lower, byc[chembl_id == n]$pref_name) }
  unique(pulisci(v[!is.na(v)])) }
tn <- pulisci(colnames(Tm))
pt <- merge(pm, cop[, .(contrast_entity, in_tahoe)], by = "contrast_entity")[in_tahoe == TRUE]
pt[, drug := vapply(seq_len(.N), function(i) { z <- colnames(Tm)[tn %in% sin(contrast_entity[i], nome[i])]; paste(z, collapse = ";") }, "")]
pt[contrast_entity == "STR:atra", drug := colnames(Tm)[tolower(colnames(Tm)) == "tretinoin"]]
pt[contrast_entity == "STR:1_25_oh_2d3", drug := colnames(Tm)[tolower(colnames(Tm)) == "calcitriol"]]
print(pt[, .N, keyby = insieme]); stopifnot(pt[insieme == "40", .N] == 8L, pt[insieme == "132", .N] == 24L, all(nzchar(pt$drug)))
genisym <- function(cc, soli) { z <- g[cluster_id == cc & !is.na(gene_symbol) & nzchar(gene_symbol)]; if (!is.null(soli)) z <- z[gene_symbol %in% soli]; z <- z[!duplicated(gene_symbol)]; setNames(z$q, z$gene_symbol) }
pt[, P_land := vapply(seq_len(.N), function(i) { F <- Tm[rownames(Tm) %in% land$gene_symbol, ]; rango_gen(genisym(cluster_id[i], land$gene_symbol), F, strsplit(drug[i], ";")[[1]]) }, 0)]
pt[, P_tutti := vapply(seq_len(.N), function(i) { F <- Tm[complete.cases(Tm), ]; rango_gen(genisym(cluster_id[i], NULL), F, strsplit(drug[i], ";")[[1]]) }, 0)]
cat("geni Tahoe completi su tutti i farmaci:", sum(complete.cases(Tm)), "; farmaci:", ncol(Tm), "\n")
Ta <- pt[insieme %in% c("40","132"), .(n = .N, H_land = mean(P_land >= .9), succ_land = sum(P_land >= .9), H_tutti = mean(P_tutti >= .9), succ_tutti = sum(P_tutti >= .9), med_land = median(P_land), med_tutti = median(P_tutti)), keyby = insieme]
Ta[, lo_land := mapply(cp_lim, succ_land, n, "lo")]; Ta[, lo_tutti := mapply(cp_lim, succ_tutti, n, "lo")]
cat("\nTAHOE contro le stime\n"); print(as.data.frame(Ta), digits = 3); fwrite(Ta, file.path(E7, "71-tahoe-stime.csv"))
print(as.data.frame(pt[order(insieme, -P_land), .(nome, insieme, drug, P_land = round(P_land, 3), P_tutti = round(P_tutti, 3))]), right = FALSE); fwrite(pt[, .(contrast_entity, nome, insieme, drug, P_land, P_tutti)], file.path(E7, "71-tahoe-per-composto.csv"))
# ---- ligandi: descrizione
Fl <- readRDS(file.path(PES7, "firme-ligandi.rds"))
hl <- readRDS("~/.cache/R/simulomicsr/hgnc-lookup.rds"); hid <- as.data.table(hl$by_hgnc_int)
li <- cop[classe == "ligando" & misurabile == TRUE]
li[, chi := toupper(hid$symbol[match(suppressWarnings(as.integer(sub("^HGNC:", "", contrast_entity))), hid$hgnc_int)])]; li[contrast_entity == "STR:ifna", chi := "IFNA"]
stopifnot(all(li$chi %in% toupper(colnames(Fl))))
mp <- setNames(land$gene_id, land$ensembl_id)
li[, P := vapply(seq_len(.N), function(i) { z <- g[cluster_id == cluster_id[i] & id %in% land$ensembl_id]; rango_gen(setNames(z$q, mp[z$id]), Fl, colnames(Fl)[toupper(colnames(Fl)) == chi[i]]) }, 0)]
cat("\nLIGANDI, descrizione (fondo 164)\n"); print(as.data.frame(li[order(-P), .(nome, insieme, chi, k, P = round(P, 3))]), right = FALSE)
cat("nel primo 10%:", sum(li$P >= .9), "su", nrow(li), "; mediana P:", round(median(li$P), 3), "\n"); fwrite(li[, .(contrast_entity, nome, insieme, chi, k, P)], file.path(E7, "71-ligandi.csv"))
# ---- tumori: descrizione, tutti i geni in comune
tum <- list("MeSH:D006528" = "TCGA-LIHC", "MeSH:D013274" = "TCGA-STAD", "MeSH:D015179" = c("TCGA-COAD","TCGA-READ"), "MeSH:D001943" = "TCGA-BRCA", "MeSH:D002292" = c("TCGA-KIRC","TCGA-KIRP","TCGA-KICH"), "STR:oscc" = "TCGA-HNSC")
qg <- function(cc, soli = NULL) { z <- g[cluster_id == cc]; if (!is.null(soli)) z <- z[id %in% soli]; setNames(z$q, z$id) }
ttc <- tt[complete.cases(tt), ]; cat("\nTCGA: geni con t in tutti i 16 progetti:", nrow(ttc), "\n")
tu <- rbindlist(lapply(names(tum), function(e) { r <- d[contrast_entity == e]; q <- qg(r$cluster_id); s <- sim_q(q, ttc); ql <- qg(r$cluster_id, land$ensembl_id); sl <- sim_q(ql, ttc[rownames(ttc) %in% land$ensembl_id, ])
  data.table(entita = e, nome = r$contrast_entity_label, progetto = paste(tum[[e]], collapse = "+"), k = r$k_effective, r_giusto = mean(s[tum[[e]]]), P_16 = mean(s[setdiff(colnames(ttc), tum[[e]])] < mean(s[tum[[e]]])), r_land = mean(sl[tum[[e]]]), P_16_land = mean(sl[setdiff(colnames(ttc), tum[[e]])] < mean(sl[tum[[e]]])), max_altro = names(which.max(s[setdiff(colnames(ttc), tum[[e]])]))) }))
cat("TUMORI, descrizione\n"); print(as.data.frame(tu), digits = 3); fwrite(tu, file.path(E7, "71-tumori.csv"))
# ---- cancello 5: GSE144269 nel carcinoma epatocellulare
cc <- d[contrast_entity == "MeSH:D006528", cluster_id]
st <- readRDS(file.path("/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio", paste0(cc, ".rds"))); st <- as.data.table(st); st[, id := sub("[.].*", "", gene_id)]; st[, q := d0 / se0]; st[!is.finite(q), q := NA_real_]
tl <- setNames(tt[, "TCGA-LIHC"], rownames(tt))
ris <- st[, { a <- intersect(id[!is.na(q)], names(tl)[!is.na(tl)]); qq <- setNames(q, id)[a]; la <- intersect(a, land$ensembl_id)
  .(geni = length(a), r_tutti = cor(qq, tl[a], method = "spearman"), geni_land = length(la), r_land = cor(qq[la], tl[la], method = "spearman")) }, by = study_id]
print(as.data.frame(ris[order(r_tutti)]), digits = 3); fwrite(ris, file.path(E7, "71-cancello-5.csv"))
a <- ris[study_id == "GSE144269", r_tutti]; b <- ris[study_id != "GSE144269", median(r_tutti)]; al <- ris[study_id == "GSE144269", r_land]; bl <- ris[study_id != "GSE144269", median(r_land)]
cat(sprintf("\nCANCELLO 5: GSE144269 r = %.3f (landmark %.3f); mediana degli altri %.3f (landmark %.3f). %s\n", a, al, b, bl, if (a < 0 && b > 0) "PASSA" else "FALLISCE"))
