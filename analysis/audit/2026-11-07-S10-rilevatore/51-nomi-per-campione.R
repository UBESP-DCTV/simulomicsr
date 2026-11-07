#!/usr/bin/env Rscript
# 51-nomi-per-campione.R — S10: il nome che ogni campione riceve dalle tabelle,
# agganciato come in produzione e agganciato ai campioni del run vecchio.
#
# 50-tabelle-nomi.R conta i record_id con un contenuto diverso. Un contenuto
# diverso non vuol dire un nome sbagliato: un gruppo puo' avere un campione in
# piu' e la stessa condizione. Qui si confronta il NOME FINALE di ogni campione:
#   prod   = overlay costruito come in produzione (20-ingressi.R della S9,
#            passo 6b): record_id del run v9 -> campioni nel master CORRENTE;
#   giusto = lo stesso overlay, ma record_id -> campioni nel master del run v9,
#            cioe' i campioni che la correzione ha davvero visto.
# Ordine e precedenza come in produzione: dentro una tabella vince l'ultima
# scrittura (righe, poi record, poi campioni nell'ordine); la tabella fallback
# si applica dopo la v1 e la sovrascrive.
#
# Si conta: quanti campioni hanno un nome diverso fra prod e giusto (nome
# cambiato, nome che c'e' solo in prod, nome che c'e' solo in giusto), per il
# master del deliverable (A3) e per il master rifatto da zero (S14); e quanti dei
# 1.903 confronti hanno il primo campione trattato con un nome diverso.
#
# Uso: Rscript analysis/audit/2026-11-07-S10-rilevatore/51-nomi-per-campione.R
suppressPackageStartupMessages({ library(data.table); devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-11-07-S10-rilevatore"
source("analysis/audit/_gsm-lookup-helper.R")
MASTER <- c(vecchio = "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl",
            A3      = "analysis/p4-output/A3-stage2-master-innestato.jsonl",
            S14     = "analysis/p4-output/S14-stage2-master.jsonl")
r2g <- lapply(MASTER, build_record_gsm_lookup)

tab <- list(
  v1       = list(s = readRDS("analysis/p4-output/name-cleanup-side-table-v1.rds"),
                  run = "analysis/p4-output/20260710T045849Z-stage3-v9pre-364547a7"),
  fallback = list(s = readRDS("analysis/p4-output/name-cleanup-fallback-side-table.rds"),
                  run = "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7"))

# overlay di una tabella con una mappa record -> campioni: GSM -> new_id (ultima scrittura)
overlay <- function(s, a, env) {
  keep <- s[s$action == "override" & !is.na(s$new_id), , drop = FALSE]
  asg_by <- split(a$record_id, a$cluster_id)
  out <- vector("list", nrow(keep))
  for (i in seq_len(nrow(keep))) {
    rids <- asg_by[[keep$cluster_id[i]]]; if (is.null(rids)) next
    g <- lapply(rids, function(r) get0(r, envir = env, inherits = FALSE))
    n <- lengths(g); if (!sum(n)) next
    out[[i]] <- data.table(ordine = i, gsm = unlist(g, use.names = FALSE), new_id = keep$new_id[i],
                           record_id = rep(rids, n))
  }
  d <- rbindlist(out)
  d[, k := seq_len(.N)]
  d[d[, .I[which.max(k)], by = gsm]$V1, .(gsm, new_id, record_id)]
}
finale <- function(env) {
  ov <- lapply(tab, function(t) overlay(t$s, as.data.frame(arrow::read_parquet(
    file.path(t$run, "assignments.parquet"))), env))
  f <- rbind(ov$v1[, tabella := "v1"], ov$fallback[, tabella := "fallback"])
  f[, p := fifelse(tabella == "fallback", 2L, 1L)]
  f[f[, .I[which.max(p)], by = gsm]$V1, .(gsm, new_id, tabella, record_id)]
}
giusto <- finale(r2g$vecchio)
confronto <- function(prod, nome) {
  m <- merge(giusto[, .(gsm, id_giusto = new_id)], prod[, .(gsm, id_prod = new_id)], by = "gsm", all = TRUE)
  m[, esito := fifelse(is.na(id_prod), "solo_giusto", fifelse(is.na(id_giusto), "solo_prod",
               fifelse(id_prod == id_giusto, "uguale", "diverso")))]
  m[, master := nome]
  m
}
cmp <- rbind(confronto(finale(r2g$A3), "A3"), confronto(finale(r2g$S14), "S14"))
saveRDS(cmp, file.path(OUT, "51-nomi-per-campione.rds"))

sink(file.path(OUT, "51-out.txt"), split = TRUE)
cat("== campioni con un nome dalle tabelle: nome in produzione contro nome agganciato al run vecchio ==\n")
print(dcast(cmp[, .N, by = .(master, esito)], master ~ esito, value.var = "N", fill = 0))

# i 1.903 confronti del deliverable: primo campione trattato nel master A3
A <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
chiave <- sub("__[0-9]+$", "", A$record_id)
A$primo <- vapply(chiave, function(k) { v <- get0(k, envir = r2g$A3, inherits = FALSE); if (is.null(v)) NA_character_ else v[1L] }, "")
stopifnot(!anyNA(A$primo))
a3 <- cmp[master == "A3"]
A$esito_primo <- a3$esito[match(A$primo, a3$gsm)]
A$esito_primo[is.na(A$esito_primo)] <- "nessun_nome"
cat("\n== i 1.903 confronti del deliverable, per esito del nome sul primo campione trattato ==\n")
print(table(A$esito_primo))
tocc <- A$esito_primo %in% c("diverso", "solo_prod", "solo_giusto")
cat(sprintf("confronti con un nome diverso sul primo campione trattato: %d, in %d meta-analisi\n",
            sum(tocc), length(unique(A$cluster_id[tocc]))))
sink()
A$id_prod <- a3$id_prod[match(A$primo, a3$gsm)]
A$id_giusto <- a3$id_giusto[match(A$primo, a3$gsm)]
fwrite(as.data.table(A)[tocc, .(cluster_id, study_id, record_id, primo, esito_primo, id_prod, id_giusto,
                                 etichetta_trattato, etichetta_controllo)],
       file.path(OUT, "51-deliverable-nome-diverso.csv"))
cat("Scritti 51-out.txt, 51-nomi-per-campione.rds, 51-deliverable-nome-diverso.csv\n")
