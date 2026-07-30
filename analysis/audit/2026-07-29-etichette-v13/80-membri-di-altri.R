#!/usr/bin/env Rscript
# 80-membri-di-altri.R --- quanti membri stanno nel gruppo sbagliato?
#
# Il principio che si vuole verificare: UN MEMBRO APPARTIENE ALL'ENTITA' CHE
# MISURA DAVVERO. Se un confronto misura X e X ha un gruppo proprio nel
# deliverable, quel confronto deve stare li', non altrove.
#
# Non si puo' controllare confrontando le entita' calcolate: i membri di un
# gruppo hanno la stessa entita' PER COSTRUZIONE (e' la chiave del
# raggruppamento). Quando l'entita' e' risolta male — GSE126517 misura R5020 ma
# e' finito in IFN-alfa — l'errore e' invisibile da li'.
#
# Si controlla dal TESTO, in modo indipendente: per ogni membro si cerca quali
# entita' DEL DELIVERABLE sono nominate per esteso nelle etichette dei suoi due
# bracci. Se compare un'altra entita' e NON compare quella del proprio gruppo,
# il membro e' quasi certamente nel gruppo sbagliato.
#
# E' un filtro, non un verdetto: quello che trova va letto.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-07-29-etichette-v13"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
CACHE <- "/home/user/.cache/R/simulomicsr"
MIN_NOME <- 5L   # solo nomi per esteso: le sigle collidono (lezione LTA)

# Le lettere greche NON si buttano: normalizzando via i non-ASCII "IL-1beta"
# diventerebbe "il1" e non matcherebbe piu' nulla — ed e' proprio la forma in cui
# i metadati scrivono le citochine. Si traslitterano, come fa gia'
# .normalize_greek_stereo nel pacchetto.
GRECHE <- c("\u03b1"="alpha","\u03b2"="beta","\u03b3"="gamma","\u03b4"="delta",
            "\u03ba"="kappa","\u03bc"="u","\u03c9"="omega","\u0391"="alpha",
            "\u0392"="beta","\u0393"="gamma")
norm <- function(x) {
  x <- tolower(as.character(x))
  for (g in names(GRECHE)) x <- gsub(g, GRECHE[[g]], x, fixed = TRUE)
  gsub("[^a-z0-9]", "", x)
}

d <- readRDS(file.path(OUT, "deliverable-v13-poolato.rds"))   # i 191 poolati
cl  <- readRDS(file.path(V13, "clusters.rds"))
sel <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
sel <- sel[sel$cluster_id %in% d$cluster_id, ]
cat("gruppi:", nrow(sel), "\n")

# --- alias di ogni entita' del deliverable ----------------------------------
ent <- unique(sel$contrast_entity)
pref <- sub(":.*$", "", ent); rest <- sub("^[^:]*:", "", ent)
alias_of <- setNames(vector("list", length(ent)), ent)
ch <- readRDS(file.path(CACHE, "chebi", "chebi-lookup.rds"))
i <- which(pref == "CHEBI")
a <- ch$aliases[as.character(ch$aliases$chebi_id) %in% rest[i], ]
spl <- split(a$alias_lower, as.character(a$chebi_id))
for (j in i) alias_of[[ent[j]]] <- unique(c(spl[[rest[j]]],
  ch$by_id$primary_name[as.character(ch$by_id$chebi_id) == rest[j]]))
hg <- readRDS(file.path(CACHE, "hgnc-lookup.rds"))
i <- which(pref == "HGNC")
al <- hg$aliases_long[as.character(hg$aliases_long$hgnc_int) %in% rest[i], ]
spl <- split(al$alias_lower, as.character(al$hgnc_int))
for (j in i) {
  row <- hg$by_hgnc_int[as.character(hg$by_hgnc_int$hgnc_int) == rest[j], ]
  alias_of[[ent[j]]] <- unique(c(spl[[rest[j]]], row$symbol, row$name))
}
me <- readRDS(file.path(CACHE, "mesh-lookup.rds"))
i <- which(pref == "MeSH")
e <- me$by_entry_lower[me$by_entry_lower$ui %in% rest[i], ]
spl <- split(e$entry_lower, e$ui)
for (j in i) alias_of[[ent[j]]] <- unique(c(spl[[rest[j]]],
  me$by_ui$mh[me$by_ui$ui == rest[j]]))
cb <- readRDS(file.path(CACHE, "chembl", "chembl-lookup.rds"))
i <- which(pref == "CHEMBL")
a <- cb$aliases[cb$aliases$chembl_id %in% rest[i], ]
spl <- split(a$alias_lower, a$chembl_id)
for (j in i) alias_of[[ent[j]]] <- unique(c(spl[[rest[j]]],
  cb$by_id$pref_name[cb$by_id$chembl_id == rest[j]]))
tx <- readRDS(file.path(CACHE, "taxonomy", "taxonomy-lookup.rds"))
i <- which(pref == "NCBITaxon")
n <- tx$names[as.character(tx$names$taxid) %in% rest[i], ]
spl <- split(n$name_norm, as.character(n$taxid))
for (j in i) alias_of[[ent[j]]] <- unique(spl[[rest[j]]])
for (j in which(pref %in% c("STR", "COMBO")))
  alias_of[[ent[j]]] <- unique(trimws(strsplit(rest[j], "+", fixed = TRUE)[[1L]]))
rm(ch, hg, me, cb, tx); gc(verbose = FALSE)

# tavola alias -> entita', solo nomi per esteso
tab <- do.call(rbind, lapply(names(alias_of), function(e) {
  a <- unique(norm(alias_of[[e]])); a <- a[nchar(a) >= MIN_NOME]
  if (!length(a)) return(NULL)
  data.frame(alias = a, entita = e, stringsAsFactors = FALSE)
}))
# un alias che punta a piu' entita' non distingue nulla: fuori
dup <- tab$alias[duplicated(tab$alias)]
tab <- tab[!(tab$alias %in% dup), ]
cat("nomi per esteso utilizzabili:", nrow(tab), "su", length(ent), "entita'\n")

# --- etichette dei membri ---------------------------------------------------
asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% sel$cluster_id, ]
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  sid <- study$series_id
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", sid, cmp$comparison_id)
    if (!rid %in% need) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, paste(lab_of(tg, cmp$treated_group), lab_of(cg, cmp$control_group)), envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

# --- il controllo -----------------------------------------------------------
ent_di <- setNames(sel$contrast_entity, sel$cluster_id)
out <- list()
for (r in seq_len(nrow(asg))) {
  txt <- get0(asg$record_id[r], envir = lab, inherits = FALSE)
  if (is.null(txt)) next
  hay <- norm(txt)
  hit <- tab$entita[vapply(tab$alias, function(a) grepl(a, hay, fixed = TRUE), logical(1L))]
  if (!length(hit)) next
  mia <- ent_di[[asg$cluster_id[r]]]
  altre <- setdiff(unique(hit), mia)
  if (!length(altre)) next
  out[[length(out) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[r], record_id = asg$record_id[r],
    entita_gruppo = mia, entita_nominate = paste(altre, collapse = " "),
    nomina_la_propria = mia %in% hit, etichette = substr(txt, 1, 110),
    stringsAsFactors = FALSE)
}
res <- if (length(out)) do.call(rbind, out) else
  data.frame(cluster_id = character(0))
utils::write.csv(res, file.path(OUT, "membri-di-altri.csv"), row.names = FALSE)

cat("\n=== MEMBRI CHE NOMINANO UN'ALTRA ENTITA' DEL DELIVERABLE ===\n")
cat("confronti totali esaminati:", nrow(asg), "\n")
cat("nominano un'altra entita':", nrow(res), "\n")
solo <- res[!res$nomina_la_propria, ]
cat("...e NON nominano la propria (nel gruppo sbagliato?):", nrow(solo), "\n")
cat("gruppi coinvolti:", length(unique(solo$cluster_id)), "su", nrow(sel), "\n\n")
if (nrow(solo)) {
  agg <- aggregate(record_id ~ cluster_id + entita_gruppo, solo, length)
  names(agg)[3] <- "n_membri_sospetti"
  agg <- merge(agg, d[, c("cluster_id", "contrast_entity_label", "k_effective",
                          "coherence_verdict")], by = "cluster_id")
  agg <- agg[order(-agg$n_membri_sospetti), ]
  print(head(agg[, c("contrast_entity_label", "k_effective", "n_membri_sospetti",
                     "coherence_verdict")], 40), row.names = FALSE)
}
cat("\ntabella:", file.path(OUT, "membri-di-altri.csv"), "\n")
