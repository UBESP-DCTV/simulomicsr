#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/A1-campioni-persi.R
#
# CHE FINE FANNO I CAMPIONI DI UNO STUDIO, misurato a ogni porta.
#
# ⚠️ LA PRIMA VERSIONE DI QUESTO SCRIPT ERA SBAGLIATA, e l'utente l'ha presa:
# confrontava i gruppi dello Stadio 2 con i campioni dell'H5, e chiamava «persi
# dallo Stadio 2» tutto quello che mancava — 3.564 campioni, il 9,1%. Ma la
# pipeline non parte dall'H5: parte da un bacino gia' filtrato dallo Stadio 0.
# Il caso peggiore che avevo riportato, «GSE200186: 1.179 campioni nell'H5, 27
# collocati», e' in realta' 1.152 campioni esclusi da `single_cell_protocol_match`,
# cioe' un controllo di qualita' che funziona: i 27 tenuti sono i bulk, e i titoli
# lo dicono («Drug_response_fibroblasts_bulk...»). Nessuno li aveva persi.
#
# Il denominatore giusto e' quello che lo Stadio 2 HA RICEVUTO, non quello che
# esiste in GEO. Qui si misurano le porte una per una:
#
#   H5  --[Stadio 0: 7 filtri]-->  bacino  --[input Stadio 2]-->  gruppi Stadio 2
#
# e si separa cio' che e' stato ESCLUSO con un motivo da cio' che e' stato PERSO
# senza motivo. Solo il secondo e' un difetto.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/A1-campioni-persi.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
OUT   <- "analysis/audit/2026-08-20-rilettura-194"
S2IN  <- "analysis/input/A3-stage2-input.jsonl"
S2OUT <- "analysis/p4-output/A3-stage2-master-innestato.jsonl"
stopifnot(file.exists(S2IN), file.exists(S2OUT))

A <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
studi <- sort(unique(A$study_id))
cli_alert_info("studi nel deliverable: {length(studi)}")

# --- 1. che cosa lo Stadio 2 ha RICEVUTO -------------------------------------
# l'input e' un record per studio; i campioni si leggono dai GSM citati.
cli_alert_info("leggo l'input dello Stadio 2 ({round(file.size(S2IN)/1e6)} MB)...")
ricevuti <- new.env(hash = TRUE, parent = emptyenv())
con <- file(S2IN, "r")
repeat {
  ln <- readLines(con, n = 2000L, warn = FALSE)
  if (!length(ln)) break
  sid <- sub('^.*"series_id"\\s*:\\s*"([^"]*)".*$', "\\1", ln)
  k <- which(sid %in% studi)
  for (j in k) {
    g <- unique(regmatches(ln[j], gregexpr("GSM[0-9]+", ln[j]))[[1L]])
    assign(sid[j], unique(c(if (exists(sid[j], envir = ricevuti, inherits = FALSE))
      get(sid[j], envir = ricevuti, inherits = FALSE), g)), envir = ricevuti)
  }
}
close(con)
cli_alert_info("studi trovati nell'input: {length(ls(ricevuti))}")

# --- 2. che cosa lo Stadio 2 ha COLLOCATO in un gruppo -----------------------
s2  <- simulomicsr:::.load_stage2_master(S2OUT)
s2i <- simulomicsr:::.index_stage2_master(s2)

righe <- lapply(studi, function(g) {
  rec <- if (exists(g, envir = ricevuti, inherits = FALSE))
    get(g, envir = ricevuti, inherits = FALSE) else character(0)
  col <- if (exists(g, envir = s2i, inherits = FALSE))
    unique(unlist(lapply(get(g, envir = s2i, inherits = FALSE)$replicate_groups,
                         function(r) as.character(unlist(r$sample_ids))))) else character(0)
  persi <- setdiff(rec, col)
  data.frame(studio = g, n_ricevuti = length(rec), n_collocati = length(intersect(col, rec)),
             n_persi = length(persi), persi = paste(sort(persi), collapse = ","),
             stringsAsFactors = FALSE)
})
P <- do.call(rbind, righe)

cli_h1("La porta che conta: che cosa lo Stadio 2 ha ricevuto e che cosa ne ha fatto")
cli_alert_info("campioni RICEVUTI dallo Stadio 2 (gia' passati dallo Stadio 0): {sum(P$n_ricevuti)}")
cli_alert_info("collocati in un gruppo: {sum(P$n_collocati)}")
cli_alert_info("PERSI senza motivo: {sum(P$n_persi)}  ({sprintf('%.1f%%', 100*sum(P$n_persi)/max(1,sum(P$n_ricevuti)))})")
cli_alert_info("studi con almeno un campione perso: {sum(P$n_persi > 0)} su {nrow(P)}")

cli_h2("I dieci studi che ne perdono di piu'")
q <- P[order(-P$n_persi), ][1:min(10, nrow(P)), ]
for (i in seq_len(nrow(q))) if (q$n_persi[i] > 0) cli_alert(sprintf(
  "%s  %d persi su %d ricevuti", q$studio[i], q$n_persi[i], q$n_ricevuti[i]))

cli_h2("La distribuzione: quanti ne perde uno studio, quando ne perde")
print(table(P$n_persi[P$n_persi > 0]))

utils::write.csv(P, file.path(OUT, "campioni-persi-per-studio.csv"), row.names = FALSE)
cli_alert_success("Scritto campioni-persi-per-studio.csv")
