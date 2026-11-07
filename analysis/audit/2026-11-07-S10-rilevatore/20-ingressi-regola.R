#!/usr/bin/env Rscript
# 20-ingressi-regola.R — S10: gli ingressi VERI della regola di riga sui 1.903
# confronti poolati, e le quattro varianti della regola su ciascuno.
#
# PERCHE'. Lo script di agosto (95-regole-esistenti.R) chiamava `.rp_row_defect()`
# con ingressi ricostruiti: classe da `kind_effective_resolved` (che sbaglia il
# tipo, finding S6), nessun token dell'entita'. Qui la regola si chiama con gli
# ingressi che la produzione le passa davvero: si esegue `.ca_member_contrast()`
# sugli ingressi raccolti dalla S9 (20-ingressi.rds) e si catturano gli argomenti
# di `.rp_row_defect()` e di `.ca_entity_tokens()` con trace().
#
# CANCELLI (00-previsioni.md):
#   C2(a) i 1.903 confronti arrivano tutti alla regola di riga e la superano
#         (sono i sopravvissuti dello Stadio 3): 1.903 su 1.903 con esito "";
#   C2(b) con gli ingressi di agosto la regola di produzione ne segnala 2;
#   C4    controllo positivo e negativo della regola V3, PRIMA dei dati.
# Lo script NON stampa quanti confronti segnala ciascuna variante: lo fa
# 40-misura.R, dopo il conto del riferimento.
#
# Non scrive nulla fuori da questa cartella.
# Uso (Rscript SENZA --vanilla):
#   setsid nohup Rscript analysis/audit/2026-11-07-S10-rilevatore/20-ingressi-regola.R \
#     > analysis/audit/2026-11-07-S10-rilevatore/log/20.log 2>&1 < /dev/null &
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-11-07-S10-rilevatore"
source(file.path(OUT, "10-regola-v2.R"))
A3_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
ns <- asNamespace("simulomicsr")
t0 <- Sys.time(); tempo <- function() round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)

onto <- ns$.load_ontology_dicts()
stopifnot(isTRUE(onto$has_chembl), !isTRUE(onto$is_fixture))
for (o in c("chebi", "chembl", "hgnc", "mesh", "taxon")) invisible(ns$.ca_defrag_index(onto, o))
cli_alert_info("dizionari caricati ({tempo()} min)")

A <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
ing <- readRDS("analysis/audit/2026-11-07-S9-greche-e-corsie/20-ingressi.rds")
m <- match(A$record_id, ing$record_id)
stopifnot(!anyNA(m), identical(ing$tl[m], A$etichetta_trattato), identical(ing$cl[m], A$etichetta_controllo))
ing <- ing[m, ]
d <- readRDS(file.path(A3_POOL, "deliverable-annotato.rds"))
ing$cluster_id <- A$cluster_id
ing$entity_deliverable <- d$contrast_entity[match(A$cluster_id, d$cluster_id)]
cli_alert_info("confronti: {nrow(ing)}; gruppi: {length(unique(ing$cluster_id))}")

# ------------------------------------------------------------- la cattura -----
.E10 <- new.env()
trace(".ca_entity_tokens", where = ns, print = FALSE,
      tracer = quote(assign("tok_args", list(...), envir = .GlobalEnv$.E10)))
trace(".rp_row_defect", where = ns, print = FALSE,
      tracer = quote({
        .es <- extra_stop   # forza la promessa: chiama .ca_entity_tokens()
        .GlobalEnv$.E10$n <- .GlobalEnv$.E10$n + 1L
        .GlobalEnv$.E10$cap <- list(tl = treated_label, cl = control_label, cls = contrast_class,
                                    entity = entity, extra_stop = .es,
                                    tok_raw = .GlobalEnv$.E10$tok_args)
      }))
caches <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))
cap <- vector("list", nrow(ing)); esito <- vector("list", nrow(ing))
for (i in seq_len(nrow(ing))) {
  .E10$n <- 0L; .E10$cap <- NULL; .E10$tok_args <- NULL
  v <- ns$.ca_member_contrast(ing$tl[i], ing$cl[i], ing$tfl[i], ing$cfl[i],
                              anchor_name = ing$anchor_name[i], anchor_id = ing$anchor_id[i],
                              ontology_env = onto, caches = caches)
  esito[[i]] <- list(entity = v$entity %||% NA_character_, classe = v$contrast_class %||% NA_character_,
                     scarto = v$drop_reason %||% NA_character_, n_chiamate = .E10$n)
  cap[[i]] <- .E10$cap
}
untrace(".ca_entity_tokens", where = ns); untrace(".rp_row_defect", where = ns)
ing$entity_membro <- vapply(esito, `[[`, "", "entity")
ing$classe        <- vapply(esito, `[[`, "", "classe")
ing$scarto        <- vapply(esito, `[[`, "", "scarto")
ing$n_chiamate    <- vapply(esito, `[[`, 0L, "n_chiamate")
cli_alert_info("cattura fatta ({tempo()} min)")

# --------------------------------------------------------- cancello C2(a) -----
v0 <- vapply(seq_len(nrow(ing)), function(i) if (is.null(cap[[i]])) NA_character_ else
  rp_row_defect_var(cap[[i]]$tl, cap[[i]]$cl, cap[[i]]$cls, cap[[i]]$entity, cap[[i]]$extra_stop,
                    cap[[i]]$tok_raw, onto, caches$token, "V0"), "")
c2a <- c(scarto_vuoto = sum(ing$scarto == "", na.rm = TRUE),
         una_chiamata = sum(ing$n_chiamate == 1L),
         v0_vuoto     = sum(v0 == "", na.rm = TRUE),
         entita_uguale_deliverable = sum(ing$entity_membro == ing$entity_deliverable, na.rm = TRUE))
cli_h2("C2(a)"); print(c2a)

# --------------------------------------------------------- cancello C2(b) -----
mappa <- c(small_molecule = "drug", pathogen_or_aggregate_exposure = "infection",
           cytokine_stim = "cytokine", disease_vs_normal = "disease",
           genetic_overexpression = "genetic", genetic_knockout = "genetic")
classe_ago <- d$kind_effective_resolved[match(A$cluster_id, d$cluster_id)]
cls_ago <- unname(ifelse(is.na(mappa[classe_ago]), "drug", mappa[classe_ago]))
ago <- vapply(seq_len(nrow(ing)), function(k) tryCatch(ns$.rp_row_defect(
  ing$tl[k], ing$cl[k], cls_ago[k], ing$entity_deliverable[k], character(0), onto, caches$token),
  error = function(e) NA_character_), character(1))
c2b <- sum(nzchar(ago) & !is.na(ago))
cli_h2("C2(b): con gli ingressi di agosto la produzione segnala {c2b} confronti (attesi 2)")

writeLines(c(sprintf("C2(a) %s = %d su %d", names(c2a), c2a, nrow(ing)),
             sprintf("C2(b) segnalati con gli ingressi di agosto = %d (attesi 2)", c2b)),
           file.path(OUT, "20-cancello-C2.txt"))

# --------------------------------------------------------- cancello C4 --------
# I casi sono fissati in 00-previsioni.md: studio + etichetta del trattato + esito atteso.
casi <- read.csv(file.path(OUT, "20-controlli.csv"), stringsAsFactors = FALSE)
casi$riga <- vapply(seq_len(nrow(casi)), function(j) {
  w <- which(ing$study == casi$study[j] & ing$tl == casi$trattato[j] & ing$cl == casi$controllo[j])
  if (length(w) == 1L) w else NA_integer_
}, 0L)
stopifnot(!anyNA(casi$riga))
casi$esito_V3 <- vapply(casi$riga, function(i) rp_row_defect_var(
  cap[[i]]$tl, cap[[i]]$cl, cap[[i]]$cls, cap[[i]]$entity, cap[[i]]$extra_stop,
  cap[[i]]$tok_raw, onto, caches$token, "V3"), "")
casi$visto <- ifelse(casi$atteso == "segnala", nzchar(casi$esito_V3), !nzchar(casi$esito_V3))
cli_h2("C4: controlli"); print(casi[, c("study", "trattato", "atteso", "esito_V3", "visto")])
write.csv(casi, file.path(OUT, "20-cancello-C4.csv"), row.names = FALSE)

# ------------------------------------------------- le quattro varianti ---------
var <- sapply(c("V0", "V1", "V2", "V3"), function(vv) vapply(seq_len(nrow(ing)), function(i)
  if (is.null(cap[[i]])) NA_character_ else rp_row_defect_var(
    cap[[i]]$tl, cap[[i]]$cl, cap[[i]]$cls, cap[[i]]$entity, cap[[i]]$extra_stop,
    cap[[i]]$tok_raw, onto, caches$token, vv), ""))
out <- cbind(ing[, c("cluster_id", "study", "record_id", "tl", "cl", "entity_deliverable",
                     "entity_membro", "classe", "scarto", "n_chiamate")],
             as.data.frame(var, stringsAsFactors = FALSE))
out$extra_stop <- vapply(cap, function(z) if (is.null(z)) NA_character_ else paste(z$extra_stop, collapse = " "), "")
out$cls_regola <- vapply(cap, function(z) if (is.null(z)) NA_character_ else as.character(z$cls)[1L], "")
out$entity_regola <- vapply(cap, function(z) if (is.null(z)) NA_character_ else as.character(z$entity)[1L], "")
out$V0_agosto <- ago
saveRDS(list(righe = out, cap = cap), file.path(OUT, "20-ingressi-regola.rds"))
cli_alert_success("Scritto 20-ingressi-regola.rds ({tempo()} min)")
if (any(!casi$visto)) cli_alert_danger("C4: un controllo non e' visto. Fermarsi prima della misura.")
