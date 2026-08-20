#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/95-regole-esistenti.R
#
# LE REGOLE CI SONO GIA': PERCHE' NON HANNO PRESO QUESTI DIFETTI?
#
# `.rp_row_defect()` e' codice di pacchetto, e' chiamata in produzione
# (R/stage3-contrast-anchor.R:684 e 787) e contiene gia' quattro regole, fra cui
# `.rp_uncaptured_combination`, che e' esattamente «il secondo agente e' presente
# solo nel braccio trattato» — il difetto piu' frequente della rilettura (32,9%).
#
# Prima di proporre una regola NUOVA bisogna sapere se quella che c'e' fallisce
# perche' e' troppo stretta, o se non e' mai stata interrogata su questi casi.
# Sono due diagnosi diverse e portano a due interventi diversi.
#
# Qui si fa l'esperimento diretto: si passa alla funzione DI PRODUZIONE ognuno
# dei 1.903 confronti effettivamente poolati, e si guarda:
#   - quanti ne segnala in tutto;
#   - quanti dei 97 accusati dalla rilettura vengono segnalati (sensibilita');
#   - quanti dei confronti giudicati puliti vengono segnalati (falsi allarmi).
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/95-regole-esistenti.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
OUT     <- "analysis/audit/2026-08-20-rilettura-194"
A3_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"

A  <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
d  <- readRDS(file.path(A3_POOL, "deliverable-annotato.rds"))
i  <- match(A$cluster_id, d$cluster_id)
A$entity <- d$contrast_entity[i]
A$classe <- d$kind_effective_resolved[i]
cli_alert_info("confronti poolati da passare alla regola: {nrow(A)}")

ont <- simulomicsr:::.load_ontology_dicts()
cache <- new.env(hash = TRUE, parent = emptyenv())

# la classe del contrasto che la regola si aspetta e' quella dell'anchor
mappa <- c(small_molecule = "drug", pathogen_or_aggregate_exposure = "infection",
           cytokine_stim = "cytokine", disease_vs_normal = "disease",
           genetic_overexpression = "genetic", genetic_knockout = "genetic")
A$cls <- unname(ifelse(is.na(mappa[A$classe]), "drug", mappa[A$classe]))

A$verdetto_regola <- vapply(seq_len(nrow(A)), function(k) {
  tryCatch(simulomicsr:::.rp_row_defect(
    A$etichetta_trattato[k], A$etichetta_controllo[k], A$cls[k], A$entity[k],
    character(0), ont, cache), error = function(e) NA_character_)
}, character(1))

cli_h2("Che cosa segnala la regola di produzione, sui confronti poolati")
print(table(ifelse(nzchar(A$verdetto_regola) & !is.na(A$verdetto_regola),
                   A$verdetto_regola, "(nessun difetto)")))

# --- incrocio con i verdetti della rilettura ----------------------------------
dif <- read.csv(file.path(OUT, "difetti.csv"), stringsAsFactors = FALSE)
acc <- unique(paste(dif$cluster_id, dif$study_id))
A$accusato <- paste(A$cluster_id, A$study_id) %in% acc

segnala <- nzchar(A$verdetto_regola) & !is.na(A$verdetto_regola)
cli_h2("La regola prende i difetti che la rilettura ha trovato?")
t <- table(regola = ifelse(segnala, "segnala", "tace"),
           rilettura = ifelse(A$accusato, "accusato", "pulito"))
print(t)
if (all(c("segnala","tace") %in% rownames(t))) {
  sens <- t["segnala","accusato"] / sum(t[,"accusato"])
  fp   <- t["segnala","pulito"]  / sum(t[,"pulito"])
  cli_alert_info("dei confronti di studi ACCUSATI, la regola ne segnala il {sprintf('%.1f%%', 100*sens)}")
  cli_alert_info("dei confronti giudicati PULITI, ne segnala il {sprintf('%.1f%%', 100*fp)}")
}

cli_h2("I casi di scuola: la regola li vede?")
casi <- c("GSE139963", "GSE199225", "GSE240476", "GSE210984", "GSE97744")
for (g in casi) {
  s <- A[A$study_id == g & A$accusato, ]
  if (!nrow(s)) next
  for (k in seq_len(min(2, nrow(s)))) cli_alert(sprintf(
    "%s  [%s]\n      TRATTATO : %s\n      CONTROLLO: %s\n      regola -> %s", g, s$entity[k],
    s$etichetta_trattato[k], s$etichetta_controllo[k],
    if (nzchar(s$verdetto_regola[k])) s$verdetto_regola[k] else "TACE"))
}

utils::write.csv(A[, c("cluster_id","study_id","entity","cls","etichetta_trattato",
                       "etichetta_controllo","verdetto_regola","accusato")],
                 file.path(OUT, "regole-esistenti-esito.csv"), row.names = FALSE)
cli_alert_success("Scritto regole-esistenti-esito.csv")
