#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/A1-campioni-persi.R
#
# I CAMPIONI CHE ESISTONO MA NON SONO IN NESSUN GRUPPO.
#
# Controllando a mano la scheda 194 (YKL-5-124) si vede che GSE172442 ha i
# campioni GSM5256097..GSM5256114 (diciotto, numerati di seguito) ma i gruppi
# dello Stadio 2 ne contengono quindici: GSM5256102, GSM5256108 e GSM5256110 non
# stanno in NESSUN gruppo. Esistono nell'H5, sono di quello studio, e sono spariti.
#
# E' il «coverage gap» gia' noto al progetto, ma nelle schede non si vedeva: chi
# controlla a mano trova un braccio con n=2 dove il numero dei GSM dice 3 e non
# ha modo di sapere se e' un taglio del gate o una perdita a monte. Sono due cose
# diverse e vanno distinte:
#
#   (a) il campione sta in un ALTRO gruppo dello studio -> normale, quel gruppo
#       serve un altro confronto e non c'entra con questo contrasto;
#   (b) il campione non sta in NESSUN gruppo -> lo Stadio 2 l'ha perso.
#
# Questo script misura (b) su tutti gli studi del deliverable e scrive il
# risultato, che poi A0 aggiunge in fondo a ogni scheda.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/A1-campioni-persi.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-08-20-rilettura-194"
H5  <- "analysis/input/human_gene_v2.5.h5"
S2  <- "analysis/p4-output/A3-stage2-master-innestato.jsonl"

A <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
studi <- sort(unique(A$study_id))
cli_alert_info("studi nel deliverable: {length(studi)}")

s2  <- simulomicsr:::.load_stage2_master(S2)
s2i <- simulomicsr:::.index_stage2_master(s2)

ga  <- as.character(rhdf5::h5read(H5, "meta/samples/geo_accession"))
ser <- as.character(rhdf5::h5read(H5, "meta/samples/series_id"))
rhdf5::h5closeAll()

# UN CAMPIONE PUO' APPARTENERE A PIU' SERIE (super-series): il campo e' una lista
# separata da virgole e va SPEZZATA.
# ⚠️ La prima versione faceva grepl(gse, ser, fixed = TRUE), e «GSE1234» matcha
# dentro «GSE12345»: attribuiva a uno studio i campioni di un altro con lo stesso
# prefisso, e faceva risultare «GSE200186: 1152 persi su 1179». Indice esatto.
idx_serie <- new.env(hash = TRUE, parent = emptyenv())
for (k in seq_along(ser)) {
  for (s in strsplit(ser[k], "[,;\\s]+", perl = TRUE)[[1L]]) {
    if (!nzchar(s)) next
    assign(s, c(if (exists(s, envir = idx_serie, inherits = FALSE))
                  get(s, envir = idx_serie, inherits = FALSE), ga[k]), envir = idx_serie)
  }
}
appartiene <- function(gse) {
  if (exists(gse, envir = idx_serie, inherits = FALSE))
    unique(get(gse, envir = idx_serie, inherits = FALSE)) else character(0)
}

righe <- list()
for (g in studi) {
  if (!exists(g, envir = s2i, inherits = FALSE)) next
  st <- get(g, envir = s2i, inherits = FALSE)
  in_gruppi <- unique(unlist(lapply(st$replicate_groups, function(r) as.character(unlist(r$sample_ids)))))
  in_h5 <- appartiene(g)
  persi <- setdiff(in_h5, in_gruppi)
  righe[[length(righe) + 1L]] <- data.frame(
    studio = g, n_h5 = length(in_h5), n_in_gruppi = length(intersect(in_gruppi, in_h5)),
    n_persi = length(persi), persi = paste(sort(persi), collapse = ","),
    stringsAsFactors = FALSE)
}
P <- do.call(rbind, righe)

cli_h2("Campioni che esistono nell'H5 ma non stanno in nessun gruppo dello Stadio 2")
cli_alert_info("studi esaminati: {nrow(P)}")
cli_alert_info("campioni dei loro studi nell'H5: {sum(P$n_h5)}")
cli_alert_info("collocati in un gruppo: {sum(P$n_in_gruppi)}")
cli_alert_info("PERSI (in nessun gruppo): {sum(P$n_persi)}  ({sprintf('%.1f%%', 100*sum(P$n_persi)/max(1,sum(P$n_h5)))})")
cli_alert_info("studi con almeno un campione perso: {sum(P$n_persi > 0)} su {nrow(P)}")

cli_h2("I dieci studi che ne perdono di piu'")
q <- P[order(-P$n_persi), ][1:min(10, nrow(P)), ]
for (i in seq_len(nrow(q))) cli_alert(sprintf(
  "%s  %d su %d persi", q$studio[i], q$n_persi[i], q$n_h5[i]))

utils::write.csv(P, file.path(OUT, "campioni-persi-per-studio.csv"), row.names = FALSE)
cli_alert_success("Scritto campioni-persi-per-studio.csv")
