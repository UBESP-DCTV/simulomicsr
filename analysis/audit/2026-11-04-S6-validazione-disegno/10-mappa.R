#!/usr/bin/env Rscript
# Aggancio delle entita' a LINCS con il metodo del 2026-08-07 (10-mappa-entita-lincs.R), senza il
# vincolo sulle 214. I nomi si risolvono dall'identificativo. Nessun match approssimato.
# Prima riproduce l'esito sul deliverable v15 (cancello 2), poi lo applica alle 194.
# Uso: Rscript analysis/audit/2026-11-04-S6-validazione-disegno/10-mappa.R
source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
chebi  <- readRDS("~/.cache/R/simulomicsr/chebi/chebi-lookup.rds")
chembl <- readRDS("~/.cache/R/simulomicsr/chembl/chembl-lookup.rds")
cb_by_id <- as.data.table(chebi$by_id); cb_alias <- as.data.table(chebi$aliases); cb_sec <- as.data.table(chebi$secondary)
cm_by_id <- as.data.table(chembl$by_id); cm_alias <- as.data.table(chembl$aliases)
chebi_primary <- function(num) {
  num <- as.integer(num); hit <- cb_sec$primary_id[match(num, cb_sec$secondary_id)]
  ifelse(is.na(hit), num, as.integer(hit))
}
resolve_names <- function(ent) {
  if (grepl("^CHEBI:", ent)) {
    n <- chebi_primary(sub("^CHEBI:", "", ent)); r <- cb_by_id[chebi_id == n]
    prim <- if (nrow(r)) r$primary_name[1] else NA_character_
    syn <- unique(tolower(c(prim, if (nrow(r)) r$ascii_name[1] else NULL, cb_alias[chebi_id == n]$alias_lower)))
  } else {
    cid <- sub("^CHEMBL:", "", ent); r <- cm_by_id[chembl_id == cid]
    prim <- if (nrow(r)) r$pref_name[1] else NA_character_
    syn <- unique(tolower(c(prim, cm_alias[chembl_id == cid]$alias_lower)))
  }
  list(primary = prim, syn = syn[!is.na(syn) & nzchar(syn)])
}
uni <- fread(cmd = paste("zcat", shQuote(file.path(LIN, "src1src7.txt.gz"))), header = TRUE, col.names = c("chembl_id", "chebi_id"))
uni[, chebi_num := as.integer(sub("^CHEBI:", "", chebi_id))]
ck <- as.data.table(readRDS(file.path(LIN, "chembl37-inchikey.rds"))); setnames(ck, c("chembl_id", "inchikey"))
entity_inchikeys <- function(ent) {
  cids <- if (grepl("^CHEBI:", ent)) uni[chebi_num == chebi_primary(sub("^CHEBI:", "", ent))]$chembl_id else sub("^CHEMBL:", "", ent)
  if (!length(cids)) return(character(0))
  unique(ck[chembl_id %in% cids]$inchikey)
}
ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character")
ci_u <- unique(ci[, .(pert_id, cmap_name, inchi_key, compound_aliases, canonical_smiles)])[, .SD[1], by = pert_id]
ci_u[, ik_full := toupper(trimws(inchi_key))]; ci_u[, ik_block := substr(ik_full, 1, 14)]
ci_u[ik_full %in% c("", "\"\"", "NA"), ik_full := NA_character_]; ci_u[is.na(ik_full), ik_block := NA_character_]
nm_lin <- unique(rbind(ci_u[, .(nome = tolower(trimws(cmap_name)), pert_id)], ci_u[, .(nome = tolower(trimws(compound_aliases)), pert_id)]))
nm_lin <- nm_lin[!is.na(nome) & nzchar(nome) & nome != "\"\""]
mappa <- function(ent) {
  keys <- entity_inchikeys(ent); syn <- resolve_names(ent)$syn; pid <- character(0); metodo <- "nessuno"
  if (length(keys)) {
    hit <- ci_u[ik_full %in% toupper(keys)]
    if (nrow(hit)) { pid <- unique(hit$pert_id); metodo <- "struttura_inchikey_completo" }
    else { hit <- ci_u[ik_block %in% substr(toupper(keys), 1, 14)]; if (nrow(hit)) { pid <- unique(hit$pert_id); metodo <- "struttura_blocco_connettivita" } }
  }
  if (!length(pid) && length(syn)) { hit <- nm_lin[nome %in% syn]; if (nrow(hit)) { pid <- unique(hit$pert_id); metodo <- "nome_sinonimo_esatto" } }
  data.table(contrast_entity = ent, metodo_match = metodo, n_inchikey = length(keys), pert_id = paste(pid, collapse = ";"), nome_risolto = resolve_names(ent)$primary)
}
# ---- cancello 2: riproduzione sul v15
v15 <- as.data.table(readRDS(file.path(V15, "deliverable-annotato.rds"))); stopifnot(nrow(v15) == 214L)
ent15 <- v15[grepl("^(CHEBI|CHEMBL):", contrast_entity), contrast_entity]
r15 <- rbindlist(lapply(ent15, mappa))
vec <- as.data.table(readRDS(file.path(OLD, "20-entita-con-firme.rds")))
cf <- merge(r15, vec[, .(contrast_entity, m0 = metodo_match, p0 = pert_id, agganciata)], by = "contrast_entity")
cat(sprintf("v15: candidati %d, nel file vecchio %d, unione %d; metodo uguale %d, pert_id uguale %d\n", nrow(r15), nrow(vec), nrow(cf), sum(cf$metodo_match == cf$m0), sum(cf$pert_id == cf$p0)))
cat(sprintf("v15: AGGANCIATE nel file vecchio %d su %d; con almeno una firma trt_cp %d\n", sum(vec$agganciata), nrow(vec), sum(vec$n_firme_lincs > 0)))
stopifnot(nrow(cf) == 111L, nrow(r15) == 111L, all(cf$metodo_match == cf$m0), all(cf$pert_id == cf$p0))
cat("CANCELLO 2 passa\n")
# ---- le 194
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds"))); stopifnot(nrow(d) == 194L)
i40 <- fread(file.path(S5, "80-insieme-40.csv")); i172 <- fread(file.path(S5, "80-insieme-172.csv"))
d[, insieme := fcase(cluster_id %in% i40$cluster_id, "40", cluster_id %in% i172$cluster_id, "132", default = "fuori")]
ent <- d[grepl("^(CHEBI|CHEMBL):", contrast_entity), contrast_entity]
r <- rbindlist(lapply(ent, mappa))
r[, nuova_rispetto_al_v15 := !contrast_entity %in% ent15]
cat(sprintf("194: candidati CHEBI+CHEMBL %d; gia' fra i 111 %d; nuovi %d\n", nrow(r), sum(!r$nuova_rispetto_al_v15), sum(r$nuova_rispetto_al_v15)))
print(table(r$metodo_match))
saveRDS(list(r = r, ci_u = ci_u, nm_lin = nm_lin), file.path(OUT6, "10-aggancio.rds"))
fwrite(r, file.path(OUT6, "10-aggancio.csv"))
print(as.data.frame(r[r$metodo_match == "nessuno" | nuova_rispetto_al_v15, .(contrast_entity, nome_risolto, metodo_match, nuova_rispetto_al_v15)]))
# controllo positivo 4(a)
pos <- r[contrast_entity %in% c("CHEBI:52717", "CHEBI:114785"), metodo_match]
cat("positivi:", pos, "\n")
