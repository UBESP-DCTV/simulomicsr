#!/usr/bin/env Rscript
# 40-id-vs-membri-v15.R --- il nome che l'ID promette compare nelle etichette
# dei membri? Su TUTTI e 351 i candidati di v15, e sulle 214 poolate.
#
# Porta su v15 lo strumento di `analysis/audit/2026-07-29-etichette-v13/40-id-vs-membri.R`
# (v13: 303 corretti, 1 sbagliato, 1 parziale). Tre differenze, tutte dichiarate:
#
#  1. RECORD_ID A TRE SEGMENTI. In v13 il record_id era `sid__comparison_id`; da
#     v15 e' `sid__comparison_id__n` (fix F2 del 2026-08-05, che aggancia
#     4.726/4.726 record). La ricostruzione a due segmenti su v15 NON aggancia
#     nulla e darebbe "senza membri risolti" su tutto: sarebbe uno strumento
#     cieco che restituisce un risultato dall'aria plausibile. Per questo il
#     contatore `cmp_seen` e' replicato IDENTICO alla produzione
#     (`.build_contrast_group_records`, R/stage3-build.R:596-625) e c'e' un CASO
#     DI ACCETTAZIONE che ferma lo script se la copertura non e' totale.
#
#  2. STRATIFICAZIONE PER `contrast_entity_source`. Il controllo e' PARZIALMENTE
#     CIRCOLARE sul ramo `onto`: li' l'entita' e' stata risolta proprio da quel
#     testo, quindi ritrovarcela dentro non prova niente. E' invece informativo
#     sui rami `anchor` (identita' importata dall'anchor del campione trattato) e
#     sui gruppi la cui identita' viene dal recupero-nome. La stratificazione
#     rende visibile la circolarita' invece di nasconderla.
#
#  3. Il metro resta quello di v13, cicatrice inclusa: un match su una SIGLA
#     (<=4 caratteri) NON prova l'identita' — e' la forma delle collisioni di
#     alias gia' misurate (ml->THPO, cancer->granchio, e il caso che ha generato
#     il controllo: i sinonimi del tripeptide Leu-Thr-Ala contengono "LTA", che
#     nei membri c'e' ma significa acido lipoteicoico).
#
# NON e' un verdetto: e' un filtro. I falsi allarmi sono ATTESI e noti (i nomi
# sistematici ChEBI non compaiono mai nei metadati: "17beta-hydroxy-5alpha-
# androstan-3-one" negli studi si chiama DHT).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V15    <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DELIV  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT    <- "analysis/audit/2026-08-09-passo1"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
CACHE  <- "/home/user/.cache/R/simulomicsr"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

norm <- function(x) gsub("[^a-z0-9]", "", tolower(as.character(x)))

cl  <- readRDS(file.path(V15, "clusters.rds"))
sel <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
cat("candidati alla porta:", nrow(sel), "(atteso 351)\n")
stopifnot(nrow(sel) == 351L)

deliv <- readRDS(file.path(DELIV, "deliverable-annotato.rds"))
stopifnot(nrow(deliv) == 214L)
sel$nel_deliverable <- sel$cluster_id %in% deliv$cluster_id
cat("di cui nel deliverable:", sum(sel$nel_deliverable), "(atteso 214)\n")
stopifnot(sum(sel$nel_deliverable) == 214L)

# --- etichette dei membri ----------------------------------------------------
asg <- arrow::read_parquet(file.path(V15, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% sel$cluster_id, ]
need <- unique(asg$record_id)
cat("record_id da agganciare:", length(need), "\n")

# `need` come hash: il `%in%` su un vettore di ~28k dentro il ciclo sui
# confronti e' O(n^2) (stessa classe del fix I1 del 2026-06-26).
need_env <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
for (r in need) assign(r, TRUE, envir = need_env)
is_needed <- function(r) !is.null(get0(r, envir = need_env, inherits = FALSE))

s2  <- simulomicsr:::.load_stage2_master(STAGE2)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  sid <- study$series_id
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  # IDENTICO alla produzione: lo stesso comparison_id puo' comparire piu' volte
  # nello stesso studio su bracci diversi, e l'indice fa parte della chiave.
  cmp_seen <- new.env(hash = TRUE, parent = emptyenv())
  for (cmp in study$comparisons) {
    n_seen <- (get0(cmp$comparison_id, envir = cmp_seen, ifnotfound = 0L)) + 1L
    assign(cmp$comparison_id, n_seen, envir = cmp_seen)
    rid <- sprintf("%s__%s__%d", sid, cmp$comparison_id, n_seen)
    if (!is_needed(rid)) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, paste(lab_of(tg, cmp$treated_group), lab_of(cg, cmp$control_group)),
           envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

# --- CASO DI ACCETTAZIONE: lo strumento vede il dato? ------------------------
# Se la ricostruzione del record_id fosse sbagliata (p.es. quella a DUE segmenti
# di v13) qui la copertura sarebbe ~0 e lo script si ferma invece di produrre un
# numero cieco.
coperti <- sum(vapply(need, function(r) !is.null(get0(r, envir = lab, inherits = FALSE)), logical(1L)))
cat(sprintf("CASO DI ACCETTAZIONE copertura record_id: %d/%d = %.2f%%\n",
            coperti, length(need), 100 * coperti / length(need)))
if (coperti / length(need) < 0.98) {
  stop("STRUMENTO CIECO: copertura record_id sotto il 98%. Non produco numeri.")
}

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
                  entity_source = sel$contrast_entity_source,
                  recovery_source = sel$recovery_source,
                  nel_deliverable = sel$nel_deliverable,
                  stringsAsFactors = FALSE)
res$label_id <- vapply(sel$contrast_entity,
  function(e) simulomicsr:::.resolve_contrast_entity_label(e, env = env)$label %||% NA_character_,
  character(1L))
res$n_alias <- vapply(sel$contrast_entity, function(e) length(alias_of[[e]]), integer(1L))

SIGLA_MAX <- 4L
esito <- character(nrow(sel)); quale <- character(nrow(sel)); n_mem <- integer(nrow(sel))
rid_by <- split(asg$record_id, asg$cluster_id)
for (i in seq_len(nrow(sel))) {
  rid <- rid_by[[sel$cluster_id[i]]]
  txt <- unlist(lapply(rid, function(r) get0(r, envir = lab, inherits = FALSE)))
  n_mem[i] <- length(txt)
  if (!length(txt)) { esito[i] <- "senza membri risolti"; next }
  hay <- norm(paste(txt, collapse = " "))
  al  <- alias_of[[sel$contrast_entity[i]]]
  al  <- al[!is.na(al)]
  aln <- norm(al)
  keep <- nchar(aln) >= 3L
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
utils::write.csv(res, file.path(OUT, "id-vs-membri-v15.csv"), row.names = FALSE)

cat("\n=== IL NOME CHE L'ID PROMETTE COMPARE NEI MEMBRI? ===\n")
cat("\n--- tutti i 351 candidati ---\n"); print(table(res$esito))
d <- res[res$nel_deliverable, ]
cat("\n--- le 214 poolate ---\n"); print(table(d$esito))
cat("\n--- le 214, per ramo di provenienza dell'entita (la circolarita' e' su `onto`) ---\n")
print(table(d$entity_source, d$esito))
cat("\n--- le 214, per prefisso dell'ID ---\n")
print(table(sub(":.*", "", d$contrast_entity), d$esito))

da_leggere <- d$esito %in% c("nessun nome trovato", "SOLO SIGLA", "senza membri risolti")
cat("\ngruppi del deliverable da leggere a mano:", sum(da_leggere),
    " (studi-slot:", sum(d$k[da_leggere]), ")\n\n")
print(d[da_leggere, c("contrast_entity", "label_id", "k", "entity_source",
                      "recovery_source", "esito", "alias_che_matcha")], row.names = FALSE)
cat("\ntabella:", file.path(OUT, "id-vs-membri-v15.csv"), "\n")
