#!/usr/bin/env Rscript
# 45-perche-non-visti.R — S10: perche' la regola V3 vede 10 difetti su 129?
#
# Per ogni confronto difettoso si misura se la sotto-regola della sua famiglia
# ha gli ingressi che le servono, sulle etichette con le greche tradotte:
#   tempo     .rp_time_hours() trova un tempo in ENTRAMBI i bracci;
#   soggetto  .rp_identifiers() trova soggetti o codici in ENTRAMBI i bracci;
#   materiale rp_sistemi() trova un sistema biologico in ENTRAMBI i bracci;
#   agente    il trattato ha parole che il controllo non ha (fuori dai token
#             dell'entita'), e quante di queste i resolver riconoscono.
# E' una diagnosi sui positivi: non cambia la regola e non guarda i falsi allarmi.
#
# Uso: Rscript analysis/audit/2026-11-07-S10-rilevatore/45-perche-non-visti.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(data.table); devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-11-07-S10-rilevatore"
source(file.path(OUT, "10-regola-v2.R"))
ns <- asNamespace("simulomicsr")
onto <- ns$.load_ontology_dicts()
z <- readRDS(file.path(OUT, "20-ingressi-regola.rds"))
e <- fread(file.path(OUT, "40-esiti.csv"), encoding = "UTF-8")
stopifnot(identical(e$record_id, z$righe$record_id))
cache <- new.env(parent = emptyenv())

parole <- function(x) {
  tok <- strsplit(ns$.rp_strip_dose_time(gsub("[^A-Za-z0-9 -]", " ", x)), " +")[[1L]]
  unique(tok[nchar(gsub("[^a-z0-9]", "", tok)) >= 3L & !(tok %in% ns$.RP_NOT_AGENT)])
}
idx <- which(e$insieme == "difettoso")
r <- rbindlist(lapply(idx, function(i) {
  cp <- z$cap[[i]]
  tl <- .tr(cp$tl); cl <- .tr(cp$cl)
  raw <- unlist(cp$tok_raw, use.names = FALSE); raw <- raw[!is.na(raw)]
  stop2 <- unique(c(cp$extra_stop, if (length(raw)) ns$.ca_entity_tokens(.tr(raw)) else character(0)))
  it <- ns$.rp_identifiers(tl, stop2); ic <- ns$.rp_identifiers(cl, stop2)
  extra <- setdiff(parole(tl), c(parole(cl), stop2))
  ris <- vapply(extra, function(t) rp_resolve_token(t, onto, cache), "")
  data.table(record_id = e$record_id[i], famiglia = e$famiglia[i], preso = nzchar(e$V3[i]),
             tempo_entrambi = length(ns$.rp_time_hours(tl)) > 0L && length(ns$.rp_time_hours(cl)) > 0L,
             tempo_solo_uno = xor(length(ns$.rp_time_hours(tl)) > 0L, length(ns$.rp_time_hours(cl)) > 0L),
             soggetto_entrambi = (length(it$subjects) + length(it$codes)) > 0L &&
                                 (length(ic$subjects) + length(ic$codes)) > 0L,
             sistema_entrambi = length(rp_sistemi(tl)) > 0L && length(rp_sistemi(cl)) > 0L,
             parole_in_piu = length(extra), riconosciute = sum(nzchar(ris)),
             parole = paste(extra, collapse = " "))
}))
fwrite(r, file.path(OUT, "45-perche-non-visti.csv"))
sink(file.path(OUT, "45-out.txt"), split = TRUE)
cat("== per famiglia: confronti, presi, e quante volte la sotto-regola ha i suoi ingressi ==\n")
print(r[, .(confronti = .N, presi = sum(preso),
            tempo_in_entrambi = sum(tempo_entrambi), tempo_in_uno_solo = sum(tempo_solo_uno),
            soggetto_in_entrambi = sum(soggetto_entrambi), sistema_in_entrambi = sum(sistema_entrambi),
            con_parole_in_piu = sum(parole_in_piu > 0), con_parola_riconosciuta = sum(riconosciute > 0)),
        by = famiglia][order(-confronti)])
cat("\n== secondo agente: le parole in piu' nel trattato, per confronto ==\n")
print(r[grepl("secondo agente", famiglia), .(preso, riconosciute, parole)])
sink()
