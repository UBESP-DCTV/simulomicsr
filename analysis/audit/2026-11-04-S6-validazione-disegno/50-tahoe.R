#!/usr/bin/env Rscript
# Tahoe-100M: quali composti delle 194 compaiono nell'indice dei farmaci. Solo nomi, nessun dato.
source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
library(arrow)
t <- as.data.table(read_parquet(file.path(OUT6, "indici/tahoe100m-drug_metadata.parquet")))
cat(nrow(t), "righe; colonne:", names(t), "\n"); print(head(t, 3))
cop <- fread(file.path(OUT6, "40-copertura-194.csv"))
a <- readRDS(file.path(OUT6, "10-aggancio.rds")); ci <- a$ci_u
nomi <- tolower(trimws(t$drug))
pulisci <- function(x) gsub("[^a-z0-9]", "", tolower(x))
# confronto per nome normalizzato, con i nomi dalle tre fonti: etichetta, ChEBI (sinonimi), LINCS
chebi <- readRDS("~/.cache/R/simulomicsr/chebi/chebi-lookup.rds"); al <- as.data.table(chebi$aliases); by <- as.data.table(chebi$by_id)
chembl <- readRDS("~/.cache/R/simulomicsr/chembl/chembl-lookup.rds"); alc <- as.data.table(chembl$aliases); byc <- as.data.table(chembl$by_id)
sin <- function(e, lab) {
  v <- lab
  if (grepl("^CHEBI:", e)) { n <- as.integer(sub("^CHEBI:", "", e)); v <- c(v, al[chebi_id == n]$alias_lower, by[chebi_id == n]$primary_name, by[chebi_id == n]$ascii_name) }
  if (grepl("^CHEMBL:", e)) { n <- sub("^CHEMBL:", "", e); v <- c(v, alc[chembl_id == n]$alias_lower, byc[chembl_id == n]$pref_name) }
  unique(pulisci(v[!is.na(v)]))
}
pm <- cop[classe == "piccola molecola"]
pm[, in_tahoe := vapply(seq_len(.N), function(i) any(sin(contrast_entity[i], nome[i]) %in% pulisci(t$drug)), TRUE)]
# elenco a mano per gli STR, lo stesso dell'aggancio a LINCS
pm[contrast_entity == "STR:atra", in_tahoe := "tretinoin" %in% nomi]; pm[contrast_entity == "STR:1_25_oh_2d3", in_tahoe := "calcitriol" %in% nomi]
print(pm[, .(meta = .N, in_tahoe = sum(in_tahoe), in_tahoe_e_lincs = sum(in_tahoe & misurabile), lincs_misurabile = sum(misurabile)), keyby = insieme])
print(as.data.frame(pm[in_tahoe == TRUE][order(insieme, -k), .(nome, insieme, k, misurabile)]), right = FALSE)
cop[, in_tahoe := contrast_entity %in% pm[in_tahoe == TRUE, contrast_entity]]
fwrite(cop, file.path(OUT6, "50-copertura-con-tahoe.csv"))
# Quanti farmaci di Tahoe hanno una firma misurabile in LINCS, per nome normalizzato.
# E' la taglia della misura fra le due fonti, che non usa il deliverable.
sf <- fread(file.path(OUT6, "20-composti-lincs.csv"))[linee_attive >= 3L]
lin <- a$ci_u[pert_id %in% sf$pert_id]
nomi_l <- unique(c(pulisci(lin$cmap_name), pulisci(lin$compound_aliases)))
cat("farmaci Tahoe:", nrow(t), "; con una firma LINCS misurabile, per nome:", sum(pulisci(t$drug) %in% nomi_l), "\n")
