# 10-taratura-sviluppo.R — taratura PRIMA della carta: le uscite congelate dei modelli Claude sui 47 studi di sviluppo
# (prova S12r6, forma V: prompt v1 e schema v1 vincolato, adattatore A0), lette contro il riferimento di Gemma sui 21
# studi di sviluppo che hanno un disegno di Gemma. Nessuna chiamata all'API, nessuno studio di Gemma aperto o chiuso.
# Serve a due cose: (1) il codice della misura per la forma V rida' i numeri di S12r6 contro Atlas (cancello KC1 della
# carta); (2) i numeri di taratura per le previsioni della carta.
#   Rscript analysis/audit/2026-11-15-claude-su-gemma/10-taratura-sviluppo.R > .../10-out.txt 2>&1   (SENZA --vanilla)
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
source("analysis/audit/2026-11-15-lettori-su-gemma/30-misura-contro-gemma.R")
SEME <- 20261115L; B <- 10000L; CG <- "analysis/audit/2026-11-15-claude-su-gemma"; U6 <- "analysis/p4-output/S12r6-claude"
el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
es <- utils::read.csv(file.path(G, "30-esiti.csv"), stringsAsFactors = FALSE)
voci <- es[es$esito == "tabella", ]; voci$gse <- el$gse[match(voci$shortName, el$shortName)]
s21 <- voci[voci$parte == "sviluppo", ]; s21 <- s21[order(s21$gse, method = "radix"), ]
stopifnot(nrow(s21) == 21L, all(s21$gse %in% sv$gse), !anyDuplicated(s21$gse))
tab_gemma <- function(nome, gse) { x <- gemma_leggi(nome); gemma_tabella(x$campioni, x$analisi, gse) }
RG <- lapply(setNames(s21$gse, s21$gse), function(g) tab_gemma(s21$shortName[s21$gse == g], g))
CORSE <- c("V-haiku-corsa1", "V-haiku-corsa2", "V-sonnet-corsa1", "V-sonnet-corsa2", "V-opus-corsa1", "V-opus-corsa2")
ATTESO <- utils::read.csv("analysis/audit/2026-11-14-S12r6-claude-via-api/24-corse.csv", stringsAsFactors = FALSE)
cat("colonne di 24-corse.csv:", paste(names(ATTESO), collapse = " "), "\n")
NON_CHIUSO <- "non chiuso non chiuso"
chiave_gc <- function(r) {                                   # uguale a chiave_gc() di analysis/audit/2026-11-15-lettori-su-gemma/41-misura.R
  if (!isTRUE(r$chiuso)) return(NON_CHIUSO)
  g <- imp(paste(sort(vapply(split(names(r$partizione), unname(r$partizione)), camp_ins, "")), collapse = ";"))
  k <- r$confronti
  kk <- if (!nrow(k)) "nessun confronto" else
    imp(paste(sort(sprintf("%s>%s", vapply(k$trattato, camp_ins, ""), vapply(k$controllo, camp_ins, ""))), collapse = ";"))
  paste(g, kk)
}
ris <- list(); chiavi <- list()
for (cn in CORSE) {
  m <- misura_forma(leggi_uscite(file.path(U6, paste0(cn, ".jsonl"))), "A0")
  t3 <- tre_numeri(m$tab)
  cat(sprintf("%s contro Atlas (47 studi): chiusi %d, gruppi identici %d/47, confronti ritrovati %d/%d\n", cn, t3[["chiusi"]], t3[["identici"]], t3[["ritrovati"]], t3[["den"]]))
  P <- do.call(rbind, lapply(s21$gse, function(g) misura_contro_gemma(s21$shortName[s21$gse == g], g, RG[[g]], m$lett[[g]], as.character(unlist(viste[[g]]$campioni)))$riga))
  r <- riassumi_gemma(P, B, SEME); ris[[cn]] <- cbind(corsa = cn, r)
  for (n in names(QUOTE_GEMMA)) cat(sprintf("   contro Gemma (21 studi)  %s\n", riga_gemma(r, n)))
  chiavi[[cn]] <- vapply(sv$gse, function(g) chiave_gc(m$lett[[g]]), "")
}
utils::write.csv(do.call(rbind, ris), file.path(CG, "10-taratura-riassunto.csv"), row.names = FALSE, na = "")
cat("\nStudi di sviluppo (47) con la stessa uscita adattata (stessi gruppi e stessi confronti come insiemi di campioni, chiave di 41-misura.R) fra due corse:\n")
for (p in list(c("V-haiku-corsa1", "V-haiku-corsa2"), c("V-opus-corsa1", "V-opus-corsa2"), c("V-sonnet-corsa1", "V-sonnet-corsa2"), c("V-opus-corsa1", "V-haiku-corsa1"), c("V-opus-corsa1", "V-sonnet-corsa1")))
  cat(sprintf("  %s = %s: %d/47 (tutte e due chiuse e uguali)\n", p[1], p[2], sum(chiavi[[p[1]]] == chiavi[[p[2]]] & chiavi[[p[1]]] != NON_CHIUSO)))
mb <- misura_forma(leggi_uscite(file.path(USCITE_R5, "B0.jsonl")), "B0")
kb <- vapply(sv$gse, function(g) chiave_gc(mb$lett[[g]]), "")
for (cn in CORSE) cat(sprintf("  Mistral B0 = %s: %d/47\n", cn, sum(kb == chiavi[[cn]] & kb != NON_CHIUSO)))
