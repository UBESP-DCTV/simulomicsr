#!/usr/bin/env Rscript
# 30-due-regimi.R — S9: la chiave d'entita' di ogni confronto, in due regimi.
#
#   OFF = il codice di oggi, sugli ingressi raccolti da 20-ingressi.R;
#   ON  = gli stessi ingressi con i caratteri di G tradotti (01-traduzione.R)
#         in etichette, factor_levels e nome dell'anchor. L'ID dell'anchor resta.
#
# ON si calcola su TUTTI i confronti, anche su quelli senza caratteri di G: e' il
# controllo negativo del cancello 3 (deve dare lo stesso esito di OFF).
# Il controllo positivo del cancello 4(b) gira PRIMA dei dati: se fallisce lo
# script si ferma.
#
# Uso: Rscript analysis/audit/2026-11-07-S9-greche-e-corsie/30-due-regimi.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
`%||%` <- function(a, b) if (is.null(a)) b else a
OUT <- "analysis/audit/2026-11-07-S9-greche-e-corsie"
source(file.path(OUT, "01-traduzione.R"))
WORKER <- as.integer(Sys.getenv("WORKER", "16"))

onto <- simulomicsr:::.load_ontology_dicts()
stopifnot(isTRUE(onto$has_chembl), !isTRUE(onto$is_fixture))
# L'indice della de-frammentazione si memoizza dentro l'ambiente dei dizionari:
# costruito qui, prima del fork, ogni worker lo eredita invece di rifarlo.
for (o in c("chebi", "chembl", "hgnc", "mesh", "taxon")) invisible(simulomicsr:::.ca_defrag_index(onto, o))

mc <- function(tl, cl, tfl, cfl, an, aid, caches) {
  v <- simulomicsr:::.ca_member_contrast(tl, cl, tfl, cfl, anchor_name = an, anchor_id = aid,
                                         ontology_env = onto, caches = caches)
  c(entity = v$entity %||% NA_character_, direction = v$direction %||% NA_character_,
    control_key = v$control_key %||% NA_character_, classe = v$contrast_class %||% NA_character_,
    fonte = v$entity_source %||% NA_character_, scarto = v$drop_reason %||% NA_character_)
}

# ------------------------------------------- cancello 4(b): controllo positivo --
nuove <- function() list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))
pos_off <- mc("IFN-γ", "IFN-β", "treatment=IFN-γ", "treatment=IFN-β",
              NA_character_, NA_character_, nuove())
pos_on  <- mc(traduci_G("IFN-γ"), traduci_G("IFN-β"), traduci_G("treatment=IFN-γ"),
              traduci_G("treatment=IFN-β"), NA_character_, NA_character_, nuove())
cli_h2("Cancello 4(b): IFN-γ contro IFN-β")
cli_alert_info("OFF: scarto = '{pos_off[['scarto']]}'  |  ON: scarto = '{pos_on[['scarto']]}', entita' = {pos_on[['entity']]}")
c4b <- identical(unname(pos_off[["scarto"]]), "no_delta") && !identical(unname(pos_on[["scarto"]]), "no_delta")
writeLines(c(sprintf("OFF: %s", paste(names(pos_off), pos_off, sep = "=", collapse = " | ")),
             sprintf("ON:  %s", paste(names(pos_on), pos_on, sep = "=", collapse = " | ")),
             sprintf("cancello 4(b): %s", if (c4b) "PASSATO" else "FALLITO")),
           file.path(OUT, "30-controllo-positivo.txt"))
if (!c4b) stop("Cancello 4(b) fallito: lo strumento non vede il caso noto. Fermarsi.")
cli_alert_success("cancello 4(b) passato")

# ------------------------------------------------------------ tutti i confronti --
ing <- readRDS(file.path(OUT, "20-ingressi.rds"))
cli_alert_info("confronti: {nrow(ing)}; worker: {WORKER}")
ing$G_in <- ha_G(ing$tl) | ha_G(ing$cl) | ha_G(ing$tfl) | ha_G(ing$cfl) |
            (!is.na(ing$anchor_name) & ha_G(ing$anchor_name))
on_tl <- traduci_G(ing$tl); on_cl <- traduci_G(ing$cl)
on_tfl <- traduci_G(ing$tfl); on_cfl <- traduci_G(ing$cfl)
on_an <- traduci_G(ing$anchor_name); on_an[is.na(ing$anchor_name)] <- NA_character_
non_tradotti <- unique(c(attr(on_tl, "non_tradotti"), attr(on_cl, "non_tradotti"),
                         attr(on_tfl, "non_tradotti"), attr(on_cfl, "non_tradotti"),
                         attr(on_an, "non_tradotti")))
cli_alert_info("caratteri di G senza traduzione: {length(non_tradotti)} {paste(non_tradotti, collapse=' ')}")

pezzi <- split(seq_len(nrow(ing)), cut(seq_len(nrow(ing)), WORKER * 4L, labels = FALSE))
t0 <- Sys.time()
ris <- parallel::mclapply(pezzi, function(idx) {
  c_off <- nuove(); c_on <- nuove()
  m <- matrix(NA_character_, nrow = length(idx), ncol = 12L)
  for (j in seq_along(idx)) {
    i <- idx[j]
    m[j, 1:6]  <- mc(ing$tl[i], ing$cl[i], ing$tfl[i], ing$cfl[i],
                     ing$anchor_name[i], ing$anchor_id[i], c_off)
    m[j, 7:12] <- mc(on_tl[i], on_cl[i], on_tfl[i], on_cfl[i],
                     on_an[i], ing$anchor_id[i], c_on)
  }
  m
}, mc.cores = WORKER, mc.preschedule = FALSE)
err <- vapply(ris, function(r) inherits(r, "try-error") || is.null(r), logical(1L))
if (any(err)) stop("pezzi falliti: ", sum(err), " — ", paste(head(unlist(ris[err])), collapse = " | "))
m <- do.call(rbind, ris)
stopifnot(nrow(m) == nrow(ing))
cli_alert_success("fatto in {round(as.numeric(difftime(Sys.time(), t0, units = 'mins')), 1)} min")

campi <- c("entity", "direction", "control_key", "classe", "fonte", "scarto")
colnames(m) <- c(paste0(campi, "_off"), paste0(campi, "_on"))
out <- cbind(ing[, c("record_id", "study", "eleggibile", "fatti_G", "G_in")],
             as.data.frame(m, stringsAsFactors = FALSE))
out$cat_G <- categoria_G(paste(ing$tl, ing$cl, ing$tfl, ing$cfl,
                               ifelse(is.na(ing$anchor_name), "", ing$anchor_name)))
saveRDS(out, file.path(OUT, "30-due-regimi.rds"))
writeLines(c(sprintf("confronti: %d", nrow(out)),
             sprintf("caratteri di G senza traduzione: %s",
                     if (length(non_tradotti)) paste(sprintf("%s (U+%04X)", non_tradotti,
                       vapply(non_tradotti, utf8ToInt, 0L)), collapse = ", ") else "nessuno")),
           file.path(OUT, "30-due-regimi.txt"))
cli_alert_success("Scritto 30-due-regimi.rds")
