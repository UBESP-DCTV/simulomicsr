#!/usr/bin/env Rscript
# 10-impatto-su-tutti.R --- effetto della REGOLA DI DE-FRAMMENTAZIONE su TUTTI i
# membri del corpus, misurato PRIMA del re-cluster.
#
# Condizione 2 della decisione (specs/2026-07-31-decisione-rerun.md §6): «una
# regola che agisce su tutto il corpus ha effetti che vanno contati, non
# supposti». Qui si contano.
#
# COME SI OTTENGONO I DUE REGIMI, senza toccare il codice di produzione e senza
# git stash: `.ca_defrag_index()` memoizza dentro l'ambiente dei dizionari. Una
# COPIA di quell'ambiente con la memoizzazione pre-seminata a indici VUOTI fa
# trovare al ramo nuovo esattamente nulla — cioe' il comportamento di prima —
# sugli STESSI input e nella STESSA passata. I due regimi sono verificati con
# un'asserzione, cosi' il file non puo' essere etichettato male.
#
# Si misura su TUTTI i confronti dello Stadio 2, non sui soli membri che oggi
# sopravvivono al gate: la regola puo' anche RIPESCARE un membro scartato come
# `str_generico`, e contare solo i sopravvissuti lo nasconderebbe.
#
# Uso: Rscript analysis/audit/2026-07-31-defrag/10-impatto-su-tutti.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT    <- "analysis/audit/2026-07-31-defrag"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

`%||%` <- function(a, b) if (is.null(a)) b else a

# ------------------------------------------------------ i due regimi, provati --
oe_on <- simulomicsr:::.load_ontology_dicts()
stopifnot(!isTRUE(oe_on$is_fixture))
message("costruisco l'indice degli alias..."); t0 <- Sys.time()
for (o in c("chebi", "chembl", "hgnc", "mesh", "taxon")) {
  i <- simulomicsr:::.ca_defrag_index(oe_on, o)
  message(sprintf("  %-7s %8d chiavi univoche", o, length(ls(i, sorted = FALSE))))
}
message("  costruzione: ", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), " s")

oe_off <- list2env(as.list(oe_on, all.names = TRUE), envir = new.env(parent = emptyenv()))
memo_off <- new.env(parent = emptyenv())
for (o in c("chebi", "chembl", "hgnc", "mesh", "taxon")) {
  assign(o, new.env(hash = TRUE, parent = emptyenv()), envir = memo_off)
}
assign(".defrag_index", memo_off, envir = oe_off)

# ASSERZIONE: i due regimi sono davvero diversi e nel verso giusto.
stopifnot(identical(simulomicsr:::.ca_defrag_entity("tgfb", "drug", oe_on), "HGNC:11766"))
stopifnot(is.na(simulomicsr:::.ca_defrag_entity("tgfb", "drug", oe_off)))
stopifnot(is.na(simulomicsr:::.ca_defrag_entity("ifna", "drug", oe_on)))
message("regimi verificati: ON fonde tgfb, OFF no.")

# --------------------------------------------------------- TUTTI i confronti --
message("carico lo Stadio 2...")
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))),
        collapse = ";")
}
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid

rows <- list(); n <- 0L
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- stats::setNames(study$replicate_groups,
    vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    n <- n + 1L
    rows[[n]] <- list(record_id = sprintf("%s__%s", study$series_id, cmp$comparison_id),
                      study = study$series_id,
                      tl = lab_of(tg, cmp$treated_group), cl = lab_of(cg, cmp$control_group),
                      tfl = fl_of(tg), cfl = fl_of(cg))
  }
}
rm(s2); gc(verbose = FALSE)
message("confronti totali nel corpus: ", n)

# --- LO STRUMENTO VEDE IL DATO PER INTERO? ----------------------------------
# Se le etichette arrivassero troncate, il giudizio sarebbe dato su mezza frase
# (errore gia' pagato il 2026-07-30: bundle troncato a 58/40 caratteri).
ncs <- c(vapply(rows, function(r) nchar(r$tl), integer(1L)),
         vapply(rows, function(r) nchar(r$cl), integer(1L)))
cat("[strumento] etichette: max", max(ncs), "char · mediana", stats::median(ncs), "\n")
for (lim in c(40, 58, 64, 100, 128, 255)) cat("            == ", lim, ": ", sum(ncs == lim), "\n", sep = "")
ncf <- vapply(rows, function(r) nchar(r$tfl), integer(1L))
cat("[strumento] factor_levels: max", max(ncf), "char\n\n")

# ------------------------------------------------------------- la ri-corsa ---
caches_on  <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))
caches_off <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))
res <- vector("list", n); t0 <- Sys.time()
for (i in seq_len(n)) {
  if (i %% 2000 == 0) message("  ", i, "/", n, " (", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min)")
  r <- rows[[i]]
  a <- simulomicsr:::.ca_member_contrast(r$tl, r$cl, r$tfl, r$cfl,
         ontology_env = oe_off, caches = caches_off)
  b <- simulomicsr:::.ca_member_contrast(r$tl, r$cl, r$tfl, r$cfl,
         ontology_env = oe_on, caches = caches_on)
  res[[i]] <- data.frame(
    record_id = r$record_id, study = r$study,
    ent_off = a$entity %||% NA_character_, ent_on = b$entity %||% NA_character_,
    src_off = a$entity_source %||% NA_character_, src_on = b$entity_source %||% NA_character_,
    drop_off = if (nzchar(a$drop_reason)) a$drop_reason else "",
    drop_on  = if (nzchar(b$drop_reason)) b$drop_reason else "",
    dir_off = a$direction %||% NA_character_, dir_on = b$direction %||% NA_character_,
    ck_off = a$control_key %||% NA_character_, ck_on = b$control_key %||% NA_character_,
    tl = r$tl, cl = r$cl, stringsAsFactors = FALSE)
}
d <- do.call(rbind, res)
saveRDS(d, file.path(OUT, Sys.getenv("IMPATTO_OUT", "impatto-membri.rds")))
cat("\nfatto in", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n")
cat("righe:", nrow(d), "\n")
