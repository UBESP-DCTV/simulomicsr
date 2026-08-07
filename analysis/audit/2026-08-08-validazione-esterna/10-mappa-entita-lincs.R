#!/usr/bin/env Rscript
# CONTEGGIO 1 - copertura: quante entita' del deliverable esistono in LINCS L1000.
#
# Regola: i NOMI si risolvono DAGLI ID via dizionario. `canonical_name` del
# deliverable NON e' affidabile (etichette sbagliate su ID corretti) e viene
# letto solo per riportare il disaccordo, mai per fare match.
#
# Mappatura, in ordine di preferenza:
#   1. per STRUTTURA: InChIKey  (ChEBI --UniChem--> ChEMBL --ChEMBL37--> InChIKey
#      contro `inchi_key` di LINCS compoundinfo)
#   2. per NOME/SINONIMO ESATTO risolto dall'ID (case-insensitive)
# Nessun match approssimato.

suppressMessages({library(data.table)})

DELIV <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/deliverable-annotato.rds"
LIN   <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
OUT   <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"

log <- function(...) cat(sprintf(...), "\n", sep = "")

# ---------------------------------------------------------------- 1. deliverable
d <- readRDS(DELIV)
stopifnot(nrow(d) == 214)
d$prefix <- sub(":.*", "", d$contrast_entity)
log("=== DELIVERABLE: %d righe ===", nrow(d))
print(table(d$prefix))
log("")
log("kind_effective_resolved:")
print(table(d$kind_effective_resolved))

# Insieme candidato per LINCS: entita' con ID di composto (ChEBI o ChEMBL).
cand <- d[d$prefix %in% c("CHEBI", "CHEMBL"), ]
log("")
log("CANDIDATI (prefisso CHEBI o CHEMBL): %d  (CHEBI %d + CHEMBL %d)",
    nrow(cand), sum(cand$prefix == "CHEBI"), sum(cand$prefix == "CHEMBL"))
log("ESCLUSI dal conteggio 1 (nessun ID di composto risolvibile a struttura): %d",
    nrow(d) - nrow(cand))
print(table(d$prefix[!d$prefix %in% c("CHEBI", "CHEMBL")]))

# ---------------------------------------------------------- 2. dizionari: nomi
chebi  <- readRDS("~/.cache/R/simulomicsr/chebi/chebi-lookup.rds")
chembl <- readRDS("~/.cache/R/simulomicsr/chembl/chembl-lookup.rds")

cb_by_id  <- as.data.table(chebi$by_id)
cb_alias  <- as.data.table(chebi$aliases)
cb_sec    <- as.data.table(chebi$secondary)
cm_by_id  <- as.data.table(chembl$by_id)
cm_alias  <- as.data.table(chembl$aliases)

# ChEBI: secondario -> primario
chebi_primary <- function(num) {
  num <- as.integer(num)
  hit <- cb_sec$primary_id[match(num, cb_sec$secondary_id)]
  ifelse(is.na(hit), num, as.integer(hit))
}

# nome canonico + tutti i sinonimi risolti DALL'ID
resolve_names <- function(ent) {
  if (grepl("^CHEBI:", ent)) {
    n <- chebi_primary(sub("^CHEBI:", "", ent))
    r <- cb_by_id[chebi_id == n]
    prim <- if (nrow(r)) r$primary_name[1] else NA_character_
    al   <- cb_alias[chebi_id == n]$alias_lower
    syn  <- unique(tolower(c(prim, if (nrow(r)) r$ascii_name[1] else NULL, al)))
  } else if (grepl("^CHEMBL:", ent)) {
    cid  <- sub("^CHEMBL:", "", ent)
    r    <- cm_by_id[chembl_id == cid]
    prim <- if (nrow(r)) r$pref_name[1] else NA_character_
    al   <- cm_alias[chembl_id == cid]$alias_lower
    syn  <- unique(tolower(c(prim, al)))
  } else {
    prim <- NA_character_; syn <- character(0)
  }
  syn <- syn[!is.na(syn) & nzchar(syn)]
  list(primary = prim, syn = syn)
}

nm <- lapply(cand$contrast_entity, resolve_names)
cand$nome_risolto <- vapply(nm, function(x) x$primary %||% NA_character_, character(1))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
cand$nome_risolto <- vapply(nm, function(x) if (is.null(x$primary)) NA_character_ else x$primary, character(1))
cand$n_sinonimi   <- vapply(nm, function(x) length(x$syn), integer(1))

log("")
log("Nomi risolti dall'ID: %d/%d (NA: %d)",
    sum(!is.na(cand$nome_risolto)), nrow(cand), sum(is.na(cand$nome_risolto)))
log("Disaccordo nome_risolto vs canonical_name del deliverable: %d/%d",
    sum(tolower(cand$nome_risolto) != tolower(cand$canonical_name), na.rm = TRUE), nrow(cand))

# ------------------------------------------------------ 3. struttura: InChIKey
uni <- fread(cmd = paste("zcat", shQuote(file.path(LIN, "src1src7.txt.gz"))),
             header = TRUE, col.names = c("chembl_id", "chebi_id"))
uni[, chebi_num := as.integer(sub("^CHEBI:", "", chebi_id))]
ck <- as.data.table(readRDS(file.path(LIN, "chembl37-inchikey.rds")))
setnames(ck, c("chembl_id", "inchikey"))

log("")
log("UniChem ChEMBL<->ChEBI: %d righe; ChEMBL37 struct: %d righe", nrow(uni), nrow(ck))

entity_inchikeys <- function(ent) {
  if (grepl("^CHEBI:", ent)) {
    n <- chebi_primary(sub("^CHEBI:", "", ent))
    cids <- uni[chebi_num == n]$chembl_id
  } else if (grepl("^CHEMBL:", ent)) {
    cids <- sub("^CHEMBL:", "", ent)
  } else cids <- character(0)
  if (!length(cids)) return(character(0))
  unique(ck[chembl_id %in% cids]$inchikey)
}
ik <- lapply(cand$contrast_entity, entity_inchikeys)
cand$n_inchikey <- lengths(ik)
log("Entita' con almeno un InChIKey ricavato: %d/%d", sum(cand$n_inchikey > 0), nrow(cand))

# ------------------------------------------------------------- 4. LINCS compound
ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "",
            colClasses = "character")
log("")
log("LINCS compoundinfo: %d righe, %d pert_id distinti", nrow(ci), uniqueN(ci$pert_id))
ci_u <- unique(ci[, .(pert_id, cmap_name, inchi_key, compound_aliases, canonical_smiles)])
ci_u <- ci_u[, .SD[1], by = pert_id]           # dedup: le righe extra sono target multipli
log("dopo dedup per pert_id: %d", nrow(ci_u))

ci_u[, ik_full  := toupper(trimws(inchi_key))]
ci_u[, ik_block := substr(ik_full, 1, 14)]
ci_u[ik_full %in% c("", "\"\"", "NA"), ik_full := NA_character_]
ci_u[is.na(ik_full), ik_block := NA_character_]
log("pert_id con inchi_key: %d/%d", sum(!is.na(ci_u$ik_full)), nrow(ci_u))

# indice nomi LINCS -> pert_id
nm_lin <- rbind(
  ci_u[, .(nome = tolower(trimws(cmap_name)), pert_id)],
  ci_u[, .(nome = tolower(trimws(compound_aliases)), pert_id)]
)
nm_lin <- nm_lin[!is.na(nome) & nzchar(nome) & nome != "\"\""]
nm_lin <- unique(nm_lin)
log("indice nomi LINCS: %d coppie (nome, pert_id), %d nomi distinti",
    nrow(nm_lin), uniqueN(nm_lin$nome))

# ----------------------------------------------------------------- 5. matching
res <- vector("list", nrow(cand))
for (i in seq_len(nrow(cand))) {
  keys <- ik[[i]]
  pid <- character(0); metodo <- "nessuno"

  # (1) struttura, InChIKey completo
  if (length(keys)) {
    hit <- ci_u[ik_full %in% toupper(keys)]
    if (nrow(hit)) { pid <- unique(hit$pert_id); metodo <- "struttura_inchikey_completo" }
  }
  # (1b) struttura, solo blocco di connettivita' (sale/stereo/protonazione diversi)
  if (!length(pid) && length(keys)) {
    hit <- ci_u[ik_block %in% substr(toupper(keys), 1, 14)]
    if (nrow(hit)) { pid <- unique(hit$pert_id); metodo <- "struttura_blocco_connettivita" }
  }
  # (2) nome/sinonimo esatto risolto dall'ID
  if (!length(pid)) {
    syn <- nm[[i]]$syn
    if (length(syn)) {
      hit <- nm_lin[nome %in% syn]
      if (nrow(hit)) { pid <- unique(hit$pert_id); metodo <- "nome_sinonimo_esatto" }
    }
  }
  res[[i]] <- list(pert_id = pid, metodo = metodo)
}
cand$metodo_match <- vapply(res, function(x) x$metodo, character(1))
cand$n_pert_id    <- vapply(res, function(x) length(x$pert_id), integer(1))
cand$pert_id      <- vapply(res, function(x) paste(x$pert_id, collapse = ";"), character(1))

log("")
log("=== ESITO MATCH sui %d candidati ===", nrow(cand))
print(table(cand$metodo_match))
log("AGGANCIATE a LINCS: %d/%d", sum(cand$metodo_match != "nessuno"), nrow(cand))

saveRDS(list(cand = cand, res = res, ik = ik, nm = nm, ci_u = ci_u),
        file.path(OUT, "10-match-intermedio.rds"))
log("")
log("salvato: %s", file.path(OUT, "10-match-intermedio.rds"))
