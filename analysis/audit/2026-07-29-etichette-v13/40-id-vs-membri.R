#!/usr/bin/env Rscript
# 40-id-vs-membri.R --- controllo SISTEMATICO su tutti e 305 i gruppi:
# il nome che l'ID promette compare davvero nelle etichette dei membri?
#
# Nasce da un caso trovato a mano: CHEBI:73572 dice "Leu-Thr-Ala" ma i suoi tre
# studi trattano con acido lipoteicoico (LTA). Se l'ID e' sbagliato, il gruppo
# resta magari coerente ma l'identita' che gli attribuiamo e' falsa.
#
# Il controllo NON e' un verdetto: e' un filtro. Per ogni gruppo si prendono
# TUTTI i nomi con cui l'ontologia conosce quell'ID (nome primario + sinonimi)
# e si cerca se almeno uno compare in un'etichetta dei bracci. Chi non matcha
# finisce nella lista da leggere a mano — sono attesi falsi allarmi (i nomi
# sistematici ChEBI non compaiono mai nei metadati: "17β-hydroxy-5α-androstan-
# 3-one" negli studi si chiama DHT).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-07-29-etichette-v13"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
CACHE <- "/home/user/.cache/R/simulomicsr"

norm <- function(x) gsub("[^a-z0-9]", "", tolower(as.character(x)))

cl  <- readRDS(file.path(V13, "clusters.rds"))
sel <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
stopifnot(nrow(sel) == 305L)

# --- etichette dei membri ----------------------------------------------------
asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% sel$cluster_id, ]
s2  <- simulomicsr:::.load_stage2_master(STAGE2)
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
    assign(rid, paste(lab_of(tg, cmp$treated_group), lab_of(cg, cmp$control_group)),
           envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

# --- tutti i nomi con cui l'ontologia conosce ogni ID ------------------------
ent <- unique(sel$contrast_entity)
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
for (i in which(pref %in% c("STR", "COMBO"))) {
  alias_of[[ent[i]]] <- unique(trimws(strsplit(rest[i], "+", fixed = TRUE)[[1L]]))
}
rm(ch, hg, me, cb, tx); gc(verbose = FALSE)

# --- il match ---------------------------------------------------------------
env <- simulomicsr:::.load_ontology_dicts()
res <- data.frame(cluster_id = sel$cluster_id, contrast_entity = sel$contrast_entity,
                  canonical_name = sel$canonical_name, k = sel$k,
                  stringsAsFactors = FALSE)
res$label_id <- vapply(sel$contrast_entity,
  function(e) simulomicsr:::.resolve_contrast_entity_label(e, env = env)$label %||% NA_character_,
  character(1L))
res$n_alias <- vapply(sel$contrast_entity, function(e) length(alias_of[[e]]), integer(1L))

# ATTENZIONE AL METRO. La prima versione di questo controllo dava per buono
# CHEBI:73572 — il caso da cui e' nato — perche' fra i sinonimi del tripeptide
# Leu-Thr-Ala c'e' la sigla "LTA", che nei membri compare... ma significa acido
# lipoteicoico. Un match su una SIGLA non prova l'identita': e' esattamente la
# forma delle collisioni di alias gia' misurate il 2026-07-25 (ml->THPO,
# cancer->granchio). Quindi si separa: match su un nome per esteso (>=5
# caratteri) = identita' vista nel testo; match SOLO su sigle = da leggere.
SIGLA_MAX <- 4L
esito <- character(nrow(sel)); quale <- character(nrow(sel)); n_mem <- integer(nrow(sel))
for (i in seq_len(nrow(sel))) {
  rid <- asg$record_id[asg$cluster_id == sel$cluster_id[i]]
  txt <- unlist(lapply(rid, function(r) get0(r, envir = lab, inherits = FALSE)))
  n_mem[i] <- length(txt)
  if (!length(txt)) { esito[i] <- "senza membri risolti"; next }
  hay <- norm(paste(txt, collapse = " "))
  al  <- alias_of[[sel$contrast_entity[i]]]
  al  <- al[!is.na(al)]
  aln <- norm(al)
  keep <- nchar(aln) >= 3L          # sotto i 3 caratteri il match e' rumore
  al <- al[keep]; aln <- aln[keep]
  hitv <- which(vapply(aln, function(a) grepl(a, hay, fixed = TRUE), logical(1L)))
  if (!length(hitv)) {
    esito[i] <- "nessun nome trovato"; quale[i] <- ""
  } else {
    lunghi <- hitv[nchar(aln[hitv]) > SIGLA_MAX]
    if (length(lunghi)) {
      esito[i] <- "nome per esteso"
      quale[i] <- al[lunghi[which.max(nchar(aln[lunghi]))]]
    } else {
      esito[i] <- "SOLO SIGLA"
      quale[i] <- paste(unique(al[hitv]), collapse = "/")
    }
  }
}
res$esito            <- esito
res$alias_che_matcha <- quale
res$n_membri         <- n_mem
res <- res[order(match(res$esito, c("nessun nome trovato", "SOLO SIGLA",
                                    "senza membri risolti", "nome per esteso")), -res$k), ]
utils::write.csv(res, file.path(OUT, "id-vs-membri.csv"), row.names = FALSE)

cat("=== IL NOME CHE L'ID PROMETTE COMPARE NEI MEMBRI? (305 gruppi) ===\n")
print(table(res$esito))
da_leggere <- res$esito %in% c("nessun nome trovato", "SOLO SIGLA", "senza membri risolti")
cat("\ngruppi da leggere a mano:", sum(da_leggere), " (studi-slot:", sum(res$k[da_leggere]), ")\n\n")
print(res[da_leggere, c("contrast_entity", "label_id", "canonical_name", "k",
                        "esito", "alias_che_matcha")], row.names = FALSE)
cat("\ntabella:", file.path(OUT, "id-vs-membri.csv"), "\n")
