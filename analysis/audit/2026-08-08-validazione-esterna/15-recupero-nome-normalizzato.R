#!/usr/bin/env Rscript
# Terzo livello di match, SOLO per i 21 rimasti fuori: nome normalizzato
# (minuscolo, tolta ogni punteggiatura/spazio). Serve perche' LINCS scrive
# `ascorbic-acid` dove ChEBI scrive `L-ascorbic acid`, e perche' solo 21.941
# pert_id su 34.419 hanno un InChIKey in compoundinfo (la via strutturale
# semplicemente non esiste per il 36% dell'anagrafica LINCS).
# OGNI candidato prodotto qui viene stampato per ISPEZIONE MANUALE: nessuno
# entra nel conteggio senza essere stato letto.

suppressMessages({library(data.table)})
LIN <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
OUT <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"
log <- function(...) cat(sprintf(...), "\n", sep = "")

x  <- readRDS(file.path(OUT, "10-match-intermedio.rds"))
c1 <- x$cand; nm <- x$nm; ci <- as.data.table(x$ci_u)

norm <- function(s) gsub("[^a-z0-9]", "", tolower(s))

nm_lin <- rbind(
  ci[, .(nome = cmap_name, pert_id)],
  ci[, .(nome = compound_aliases, pert_id)]
)
nm_lin <- nm_lin[!is.na(nome) & nzchar(nome) & nome != "\"\""]
nm_lin[, nn := norm(nome)]
nm_lin <- unique(nm_lin[nzchar(nn)])

idx <- which(c1$metodo_match == "nessuno")
log("=== CANDIDATI PROPOSTI DAL MATCH NORMALIZZATO (da ispezionare a mano) ===")
log("")
prop <- list()
for (i in idx) {
  syn  <- nm[[i]]$syn
  nsyn <- unique(norm(syn)); nsyn <- nsyn[nzchar(nsyn)]
  hit  <- nm_lin[nn %in% nsyn]
  if (!nrow(hit)) next
  hit  <- unique(hit[, .(pert_id, nome)])
  log("ENTITA': %s  |  nome risolto: %s", c1$contrast_entity[i], c1$nome_risolto[i])
  log("  sinonimo(i) nostro/i che hanno agganciato: %s",
      paste(utils::head(syn[norm(syn) %in% hit$nn], 6), collapse = " / "))
  for (r in seq_len(nrow(hit)))
    log("  -> pert_id %s  nome LINCS: '%s'", hit$pert_id[r], hit$nome[r])
  log("")
  prop[[as.character(i)]] <- unique(hit$pert_id)
}
if (!length(prop)) log("(nessun candidato aggiuntivo)")
saveRDS(prop, file.path(OUT, "15-proposte-nome-normalizzato.rds"))
log("proposte salvate: %d entita'", length(prop))
