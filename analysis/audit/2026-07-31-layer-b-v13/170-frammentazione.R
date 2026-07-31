#!/usr/bin/env Rscript
# 170-frammentazione.R --- quanta POTENZA si perde perche' la stessa sostanza
# finisce in gruppi diversi?
#
# Serve a decidere se un re-cluster ha contenuto scientifico. Un re-pool da solo
# non ne ha: dal run v13 nessun file del pooling e' cambiato, quindi
# riprodurrebbe gli stessi numeri. Un re-cluster invece cambia i gruppi — e
# allora va misurato che cosa guadagna, non supposto.
#
# La frammentazione nota (finding 2026-07-28 §8): TGF-beta1 sta in tre gruppi
# (`HGNC:11766` k=65, `STR:tgfb` k=11, `STR:tgf_b` k=3) perche' le scritture
# `TGFb`/`TGF-B` non risolvono all'ID del gene. I gruppi sono internamente
# coerenti: e' potenza persa, non un errore di contrasto.
#
# Qui si misura su TUTTI e 305 i gruppi, non sui casi gia' noti.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/170-frammentazione.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(cli) })

V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-07-31-layer-b-v13"

cl <- readRDS(file.path(V13, "clusters.rds"))
gr <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
cli_alert_info("gruppi del deliverable: {nrow(gr)}")

env <- simulomicsr:::.load_ontology_dicts()
lab <- simulomicsr:::.display_entity_labels(gr$contrast_entity, env = env)
gr$etichetta <- lab$contrast_entity_label
gr$fonte     <- lab$contrast_entity_label_source

# normalizzazione per il confronto: minuscole, via tutto cio' che non e'
# alfanumerico. `tgf_b`, `TGF-B` e `TGFb` collassano sulla stessa forma.
norm <- function(x) gsub("[^a-z0-9]", "", tolower(x))
gr$norm_id  <- norm(sub("^[A-Za-z]+:", "", gr$contrast_entity))
gr$norm_lab <- norm(gr$etichetta)

# --- 1. entita' STR che collassano su un'etichetta risolta ------------------
# Il caso TGF-beta1: `STR:tgfb` e `STR:tgf_b` hanno la stessa forma normalizzata
# di un alias di `HGNC:11766`.
# ⚠️ La prima versione filtrava su `fonte == "STR"`, valore che NON esiste: le
# fonti vere sono chebi/chembl/combo_parts/hgnc/mesh/override/str_literal.
# `str_gr` restava vuoto e la sezione non poteva trovare nulla — lo strumento
# non vedeva il dato, di nuovo. Verificato stampando i valori distinti.
risolti <- gr[gr$fonte != "str_literal", ]
str_gr  <- gr[gr$fonte == "str_literal", ]
cli_alert_info("risolti: {nrow(risolti)} | STR letterali: {nrow(str_gr)}")
stopifnot(nrow(str_gr) > 0L, nrow(risolti) > 0L)

# Alias di ogni ID, con lo STESSO costruttore gia' usato il 2026-07-29
# (40-id-vs-membri.R): non se ne scrive un secondo, che divergerebbe.
CACHE <- "/home/user/.cache/R/simulomicsr"
ent <- unique(gr$contrast_entity)
pref <- sub(":.*$", "", ent); rest <- sub("^[^:]*:", "", ent)
alias_of <- setNames(vector("list", length(ent)), ent)
ch <- readRDS(file.path(CACHE, "chebi", "chebi-lookup.rds"))
i_ch <- which(pref == "CHEBI")
if (length(i_ch)) {
  a <- ch$aliases[as.character(ch$aliases$chebi_id) %in% rest[i_ch], ]
  spl <- split(a$alias_lower, as.character(a$chebi_id))
  for (i in i_ch) alias_of[[ent[i]]] <- unique(c(spl[[rest[i]]],
    ch$by_id$primary_name[as.character(ch$by_id$chebi_id) == rest[i]]))
}
hg <- readRDS(file.path(CACHE, "hgnc-lookup.rds"))
i_hg <- which(pref == "HGNC")
if (length(i_hg)) {
  al <- hg$aliases_long[as.character(hg$aliases_long$hgnc_int) %in% rest[i_hg], ]
  spl <- split(al$alias_lower, as.character(al$hgnc_int))
  for (i in i_hg) {
    row <- hg$by_hgnc_int[as.character(hg$by_hgnc_int$hgnc_int) == rest[i], ]
    alias_of[[ent[i]]] <- unique(c(spl[[rest[i]]], row$symbol, row$name))
  }
}
me <- readRDS(file.path(CACHE, "mesh-lookup.rds"))
i_me <- which(pref == "MeSH")
if (length(i_me)) {
  e <- me$by_entry_lower[me$by_entry_lower$ui %in% rest[i_me], ]
  spl <- split(e$entry_lower, e$ui)
  for (i in i_me) alias_of[[ent[i]]] <- unique(c(spl[[rest[i]]],
    me$by_ui$mh[me$by_ui$ui == rest[i]]))
}
cb <- readRDS(file.path(CACHE, "chembl", "chembl-lookup.rds"))
i_cb <- which(pref == "CHEMBL")
if (length(i_cb)) {
  a <- cb$aliases[cb$aliases$chembl_id %in% rest[i_cb], ]
  spl <- split(a$alias_lower, a$chembl_id)
  for (i in i_cb) alias_of[[ent[i]]] <- unique(c(spl[[rest[i]]],
    cb$by_id$pref_name[cb$by_id$chembl_id == rest[i]]))
}
tx <- readRDS(file.path(CACHE, "taxonomy", "taxonomy-lookup.rds"))
i_tx <- which(pref == "NCBITaxon")
if (length(i_tx)) {
  n <- tx$names[as.character(tx$names$taxid) %in% rest[i_tx], ]
  spl <- split(n$name_norm, as.character(n$taxid))
  for (i in i_tx) alias_of[[ent[i]]] <- unique(spl[[rest[i]]])
}
rm(ch, hg, me, cb, tx); gc(verbose = FALSE)

alias_di <- function(id) {
  a <- alias_of[[id]]
  if (is.null(a)) return(character(0))
  # Solo alias per ESTESO (>3 caratteri): un match su una sigla non prova
  # l'identita' — e' l'errore del metro che il 2026-07-29 dava per buono
  # CHEBI:73572 perche' fra i sinonimi del tripeptide c'e' `LTA`.
  a <- a[nzchar(a) & nchar(a) > 3L]
  unique(norm(a))
}

cli_h2("Entita' STR che corrispondono a un'entita' gia' risolta")
coppie <- list()
for (i in seq_len(nrow(risolti))) {
  al <- alias_di(risolti$contrast_entity[i])
  if (length(al) == 0L) next
  hit <- which(str_gr$norm_id %in% al &
                 str_gr$contrast_direction == risolti$contrast_direction[i] &
                 str_gr$contrast_control_key == risolti$contrast_control_key[i])
  for (h in hit) {
    coppie[[length(coppie) + 1L]] <- data.frame(
      entita_risolta = risolti$contrast_entity[i],
      etichetta = risolti$etichetta[i],
      k_risolto = risolti$k[i],
      entita_str = str_gr$contrast_entity[h],
      k_str = str_gr$k[h],
      stringsAsFactors = FALSE)
  }
}
fr <- if (length(coppie)) do.call(rbind, coppie) else NULL

if (is.null(fr)) {
  cat("  nessuna trovata con questo metro\n")
} else {
  fr <- fr[order(-fr$k_str), ]
  for (i in seq_len(nrow(fr))) {
    cat(sprintf("  %-28s %-14s k=%2d  <-  %-18s k=%2d\n",
                substr(fr$etichetta[i], 1, 28), fr$entita_risolta[i], fr$k_risolto[i],
                fr$entita_str[i], fr$k_str[i]))
  }
  agg <- aggregate(list(k_recuperabile = fr$k_str),
                   by = list(entita = fr$entita_risolta, etichetta = fr$etichetta,
                             k_attuale = fr$k_risolto), FUN = sum)
  cat(sprintf("\n  entita' coinvolte: %d | studi-slot recuperabili: %d\n",
              nrow(agg), sum(agg$k_recuperabile)))
  cli_h2("Guadagno per entita' (k attuale -> k unito)")
  agg <- agg[order(-agg$k_recuperabile), ]
  for (i in seq_len(nrow(agg))) {
    cat(sprintf("  %-30s %2d -> %2d  (+%d)\n", substr(agg$etichetta[i], 1, 30),
                agg$k_attuale[i], agg$k_attuale[i] + agg$k_recuperabile[i],
                agg$k_recuperabile[i]))
  }
  write.csv(fr, file.path(OUT, "frammentazione-str.csv"), row.names = FALSE)
}

# --- 2. entita' diverse con la STESSA etichetta risolta ---------------------
# Il caso nutlin: due ID ChEBI per la stessa molecola.
cli_h2("ID diversi con la stessa etichetta risolta")
chiave <- paste(gr$norm_lab, gr$contrast_direction, gr$contrast_control_key, sep = "|")
dup <- names(which(table(chiave[nzchar(gr$norm_lab)]) > 1L))
n_dup <- 0L
for (k in dup) {
  sub <- gr[chiave == k, ]
  if (length(unique(sub$contrast_entity)) < 2L) next
  n_dup <- n_dup + 1L
  cat(sprintf("  %-26s : %s\n", substr(sub$etichetta[1], 1, 26),
              paste(sprintf("%s(k=%d)", sub$contrast_entity, sub$k), collapse = " + ")))
}
if (n_dup == 0L) cat("  nessuna\n")

# --- 3. quanto pesa sul deliverable poolato --------------------------------
d <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
cli_h2("Contesto")
cat(sprintf("  gruppi censiti: %d | poolati: %d | studi-slot censiti: %d\n",
            nrow(gr), nrow(d), sum(gr$k)))
cat(sprintf("  gruppi sotto k=5 (dove la dominanza morde): %d (%.0f%%)\n",
            sum(d$k_effective < 5), 100 * mean(d$k_effective < 5)))
