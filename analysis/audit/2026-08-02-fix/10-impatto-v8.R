#!/usr/bin/env Rscript
# 10-impatto-v8.R --- effetto della REGOLA A DUE ENTITA' (tgfb, il17) su TUTTI i
# membri del corpus, misurato PRIMA del re-cluster v15. Task 13 del piano
# "2026-08-02-pipeline-impeccabile-pre-v15".
#
# RIPARAZIONE della v8 rispetto alla v7 (che era gia' la riparazione della v6):
# la v7 verificava ancora TRE fusioni autorizzate (tgfb, glioblastoma, il17).
# Il 2026-08-02 `glioblastoma' e' uscita da `.CA_DEFRAG_ACCEPT`
# (R/stage3-defrag-alias.R:339-350): la misura fatta dopo la v7 ha mostrato che
# non comprava nulla (39 membri su 40 avevano gia' l'entita' dal ramo `anchor`,
# che precede questo ripiego) e che non chiudeva lo split che doveva chiudere
# (`STR:glioblastoma` k=6 conviveva con `MeSH:D005909` k=3 in v13). Restano
# SOLO `tgfb`->HGNC:11766 e `il17`->HGNC:5981.
#
# Questa versione aggiorna le asserzioni di conseguenza: `glioblastoma` deve
# dare NA ANCHE A REGOLA ACCESA (non e' piu' nella lista, quindi il lookup
# statico non la trova mai — non serve nemmeno interrogare l'ontologia).
#
# IL MECCANISMO (invariato dalla v7): due passate separate sugli STESSI input,
# la prima con `.ca_defrag_entity` SOSTITUITA da una funzione che restituisce
# sempre NA (= la regola non esiste = il comportamento di v13), la seconda con
# il codice vero. Separate invece che alternate dentro il loop perche' costa
# meno e perche' un mock che vive per un'intera passata e' piu' difficile da
# sbagliare di uno acceso e spento 87.092 volte.
#
# Uso:  Rscript <questo file>                  # misura piena (~52 min)
#       N_MAX=200 Rscript <questo file>        # prova rapida del meccanismo
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT    <- Sys.getenv("OUT_DIR", "analysis/audit/2026-08-02-fix")
N_MAX  <- as.integer(Sys.getenv("N_MAX", "0"))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

`%||%` <- function(a, b) if (is.null(a)) b else a

oe <- simulomicsr:::.load_ontology_dicts()
stopifnot(!isTRUE(oe$is_fixture))

# --------------------------------------------------- i due regimi, provati ---
# La sostituzione della funzione e' l'unico modo onesto di spegnere una regola
# che ora e' una LISTA e non piu' un indice.
spenta <- function(token, contrast_class, ontology_env) NA_character_

with_off <- function(code) {
  testthat::with_mocked_bindings(
    .ca_defrag_entity = spenta, .package = "simulomicsr", code)
}

# ON: le DUE autorizzate si fondono, e nient'altro.
stopifnot(identical(simulomicsr:::.ca_defrag_entity("tgfb", "drug", oe), "HGNC:11766"))
stopifnot(identical(simulomicsr:::.ca_defrag_entity("il17", "drug", oe), "HGNC:5981"))
# glioblastoma NON si fonde piu': tolta da .CA_DEFRAG_ACCEPT il 2026-08-02
# (comprava un membro su quaranta, non chiudeva lo split che doveva chiudere).
# Deve dare NA ANCHE A REGOLA ACCESA -- e' l'invariante che questa v8 corregge
# rispetto alla v7, che si aspettava ancora "MeSH:D005909".
stopifnot(is.na(simulomicsr:::.ca_defrag_entity("glioblastoma", "disease", oe)))
# ifna NON si fonde: e' alias sia di IFNA1 sia di IFNA2 (regola di sempre).
stopifnot(is.na(simulomicsr:::.ca_defrag_entity("ifna", "drug", oe)))
# hypoxia NON si fonde piu': era della regola GENERALE, abbandonata. Se questa
# asserzione cade, la restrizione non e' attiva e la misura sarebbe di nuovo
# quella vecchia (923 fusioni).
stopifnot(is.na(simulomicsr:::.ca_defrag_entity("hypoxia", "disease", oe)))
# OFF: nemmeno le due autorizzate (ne' glioblastoma, che comunque non lo era).
with_off({
  stopifnot(is.na(simulomicsr:::.ca_defrag_entity("tgfb", "drug", oe)))
  stopifnot(is.na(simulomicsr:::.ca_defrag_entity("il17", "drug", oe)))
  stopifnot(is.na(simulomicsr:::.ca_defrag_entity("glioblastoma", "disease", oe)))
})
message("regimi verificati: ON fonde le DUE autorizzate (tgfb, il17) e non ",
        "glioblastoma/hypoxia/ifna; OFF nessuna.")

# ------------------------------------------------------- TUTTI i confronti ---
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
ncs <- c(vapply(rows, function(r) nchar(r$tl), integer(1L)),
         vapply(rows, function(r) nchar(r$cl), integer(1L)))
cat("[strumento] etichette: max", max(ncs), "char · mediana", stats::median(ncs), "\n")
for (lim in c(40, 58, 64, 100, 128, 255)) cat("            == ", lim, ": ", sum(ncs == lim), "\n", sep = "")

if (N_MAX > 0L && N_MAX < n) {
  # Prova del MECCANISMO, non misura: si tengono le prime N_MAX righe PIU'
  # tutte quelle che nominano una delle due entita', altrimenti un campione di
  # testa non tocca mai la regola e la prova non prova niente.
  tocca <- grepl("tgf|il-?17", vapply(rows, function(r) paste(r$tl, r$cl), character(1L)),
                 ignore.case = TRUE)
  sel <- sort(unique(c(seq_len(N_MAX), which(tocca)[seq_len(min(sum(tocca), N_MAX))])))
  rows <- rows[sel]; n <- length(rows)
  message("[N_MAX] prova su ", n, " confronti (di cui ", sum(tocca[sel]), " che nominano le due entita')")
}

# ------------------------------------------------------------ le due passate --
passata <- function(rows, etichetta) {
  caches <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))
  out <- vector("list", length(rows)); t0 <- Sys.time()
  for (i in seq_along(rows)) {
    if (i %% 5000 == 0) message("  [", etichetta, "] ", i, "/", length(rows),
      " (", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min)")
    r <- rows[[i]]
    out[[i]] <- simulomicsr:::.ca_member_contrast(r$tl, r$cl, r$tfl, r$cfl,
                  ontology_env = oe, caches = caches)
  }
  message("  [", etichetta, "] fatto in ",
          round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min")
  out
}

message("passata OFF (regola sostituita: e' il comportamento di v13)...")
A <- with_off(passata(rows, "off"))
message("passata ON (codice vero, due fusioni)...")
B <- passata(rows, "on")

d <- data.frame(
  record_id = vapply(rows, function(r) r$record_id, character(1L)),
  study     = vapply(rows, function(r) r$study, character(1L)),
  ent_off = vapply(A, function(x) x$entity %||% NA_character_, character(1L)),
  ent_on  = vapply(B, function(x) x$entity %||% NA_character_, character(1L)),
  src_off = vapply(A, function(x) x$entity_source %||% NA_character_, character(1L)),
  src_on  = vapply(B, function(x) x$entity_source %||% NA_character_, character(1L)),
  drop_off = vapply(A, function(x) if (nzchar(x$drop_reason)) x$drop_reason else "", character(1L)),
  drop_on  = vapply(B, function(x) if (nzchar(x$drop_reason)) x$drop_reason else "", character(1L)),
  dir_off = vapply(A, function(x) x$direction %||% NA_character_, character(1L)),
  dir_on  = vapply(B, function(x) x$direction %||% NA_character_, character(1L)),
  ck_off = vapply(A, function(x) x$control_key %||% NA_character_, character(1L)),
  ck_on  = vapply(B, function(x) x$control_key %||% NA_character_, character(1L)),
  tl = vapply(rows, function(r) r$tl, character(1L)),
  cl = vapply(rows, function(r) r$cl, character(1L)),
  stringsAsFactors = FALSE)

saveRDS(d, file.path(OUT, Sys.getenv("IMPATTO_OUT", "impatto-membri-v8.rds")))

# ------------------------------------------------------------- il verdetto ----
cat("\n================= COSA HA FATTO LA REGOLA A DUE ENTITA' =================\n")
cat("righe totali:", nrow(d), "\n")
cambia <- d$ent_off != d$ent_on | (is.na(d$ent_off) != is.na(d$ent_on))
cambia[is.na(cambia)] <- FALSE
cat("membri che CAMBIANO entita':", sum(cambia), "\n")
if (any(cambia)) {
  cat("\n-- da/a, con quanti membri --\n")
  tb <- table(paste(d$ent_off[cambia], "->", d$ent_on[cambia]))
  print(sort(tb, decreasing = TRUE))
}
# INVARIANTE 1: nessun membro parte da un'entita' GIA' RISOLTA.
gia_risolta <- cambia & !is.na(d$src_off) & d$src_off != "STR"
cat("\n[invariante] membri che cambiano partendo da un'entita' gia' risolta:",
    sum(gia_risolta), " (atteso 0)\n")
if (any(gia_risolta)) print(utils::head(d[gia_risolta, c("record_id","ent_off","ent_on","src_off","tl")], 20))
# INVARIANTE 2: nessun membro perso.
perso <- !nzchar(d$drop_off) & nzchar(d$drop_on)
ripescato <- nzchar(d$drop_off) & !nzchar(d$drop_on)
cat("[invariante] membri PERSI (tenuti prima, scartati dopo):", sum(perso), " (atteso 0)\n")
if (any(perso)) print(table(d$drop_on[perso]))
cat("[invariante] membri RIPESCATI (scartati prima, tenuti dopo):", sum(ripescato), "\n")
if (any(ripescato)) print(table(d$drop_off[ripescato]))
# INVARIANTE 3: il control_key non si muove.
ck_div <- d$ck_off != d$ck_on
ck_div[is.na(ck_div)] <- !is.na(d$ck_off[is.na(ck_div)]) | !is.na(d$ck_on[is.na(ck_div)])
cat("[invariante] control_key divergenti:", sum(ck_div), " (atteso 0)\n")
dir_div <- d$dir_off != d$dir_on
dir_div[is.na(dir_div)] <- FALSE
cat("[invariante] direzione divergente:", sum(dir_div), " (atteso 0)\n")
# INVARIANTE 4: solo le DUE entita' autorizzate compaiono come destinazione.
dest <- unique(d$ent_on[cambia])
atteso <- c("HGNC:11766", "HGNC:5981")
cat("[invariante] destinazioni inattese:", paste(setdiff(dest, atteso), collapse = ", "),
    if (length(setdiff(dest, atteso)) == 0L) "(nessuna)" else "<-- FERMARSI", "\n")
cat("\n-- le etichette dei membri che cambiano (TUTTE, da leggere) --\n")
if (any(cambia)) {
  w <- d[cambia, c("study", "ent_off", "ent_on", "tl", "cl")]
  utils::write.csv(w, file.path(OUT, "impatto-v8-membri-cambiati.csv"), row.names = FALSE)
  print(w, right = FALSE)
}
cat("\nEXIT_MISURA=0\n")
