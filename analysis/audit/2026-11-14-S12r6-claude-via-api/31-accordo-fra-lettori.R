# S12r6, conto accanto dichiarato DOPO i numeri (non depositato, non e' un cancello ne' una previsione).
# Domanda: se si tiene uno studio solo quando lettori diversi danno gli stessi gruppi e gli stessi confronti,
# quanti studi restano e quanti di quelli hanno un errore di lettura che costa (conto largo)?
# Uso: Rscript 31-accordo-fra-lettori.R oggetti-16.rds   (senza --vanilla)
# Limiti: 47 studi di sviluppo; le regole di accordo sono scelte dopo aver visto gli errori; errori di Mistral B0
# dal finding S12r5 (i 4 che costano piu' GSE147507); errori dei modelli Claude da 29-classi-per-corsa.csv.
a <- commandArgs(TRUE); o <- readRDS(a[1]); qui <- "analysis/audit/2026-11-14-S12r6-claude-via-api"
cl <- read.csv(file.path(qui, "29-classi-per-corsa.csv"), stringsAsFactors = FALSE)
ps <- read.csv(file.path(qui, "24-per-studio.csv"), stringsAsFactors = FALSE)
st <- o$sv$gse; MISERR <- c("GSE46665", "GSE57945", "GSE60340", "GSE49155", "GSE147507")
gc <- function(k) { stopifnot(identical(k$studio, st)); paste(k$gruppi, k$confronti) }
L <- c(list(mistral_B0 = gc(o$KM$T), mistral_v1 = gc(o$KM$V)), lapply(o$RUN, function(r) gc(r$kk)))
chiuso <- c(list(mistral_B0 = o$MIS$T$tab$chiuso, mistral_v1 = o$MIS$V$tab$chiuso),
            lapply(names(o$RUN), function(n) ps$chiuso[match(paste(n, st), paste(ps$corsa, ps$studio))])); names(chiuso) <- names(L)
err <- function(n, s) if (n == "mistral_B0") s %in% MISERR else if (n == "mistral_v1") NA else {
  r <- cl[cl$corsa == n & cl$studio == s, ]; nrow(r) > 0 && any(r$classe %in% c("lettura del modello", "forma") & r$costa == "si") }
riga <- function(nome, lettori) {
  ok <- sapply(seq_along(st), function(i) all(sapply(lettori, function(n) isTRUE(as.logical(chiuso[[n]][i])))) &&
                 length(unique(sapply(lettori, function(n) L[[n]][i]))) == 1)
  e <- sapply(seq_along(st), function(i) any(sapply(lettori, function(n) isTRUE(err(n, st[i])))))
  rc <- setdiff(lettori, c("mistral_B0", "mistral_v1"))[1]; p <- ps[ps$corsa == rc, ]; p <- p[match(st, p$studio), ]
  data.frame(regola = nome, studi_tenuti = sum(ok), tenuti_con_errore = sum(ok & e), studi_con_errore = paste(st[ok & e], collapse = " "),
             tenuti_identici_ad_atlas = sum(p$classe_gruppi[ok] == "identica"), ritrovati = sum(p$n_b_uguale[ok]), su = sum(p$n_b_den[ok]),
             confronti_atlas_fuori = sum(p$n_b_den[!ok]), esclusi = sum(!ok), esclusi_con_errore = sum(!ok & e), stringsAsFactors = FALSE) }
R <- rbind(
  riga("Mistral B0 = Opus V corsa 1", c("mistral_B0", "V-opus-corsa1")),
  riga("Mistral B0 = Opus V corsa 2", c("mistral_B0", "V-opus-corsa2")),
  riga("Mistral B0 = Sonnet V corsa 1", c("mistral_B0", "V-sonnet-corsa1")),
  riga("Mistral B0 = Sonnet V corsa 2", c("mistral_B0", "V-sonnet-corsa2")),
  riga("Mistral B0 = Haiku V corsa 1", c("mistral_B0", "V-haiku-corsa1")),
  riga("Mistral B0 = Opus V corsa 1 = Sonnet V corsa 1", c("mistral_B0", "V-opus-corsa1", "V-sonnet-corsa1")),
  riga("Opus V corsa 1 = Opus V corsa 2", c("V-opus-corsa1", "V-opus-corsa2")),
  riga("Opus V corsa 1 = Sonnet V corsa 1", c("V-opus-corsa1", "V-sonnet-corsa1")),
  riga("Opus V corsa 2 = Sonnet V corsa 2", c("V-opus-corsa2", "V-sonnet-corsa2")),
  riga("Opus V corsa 1 = Sonnet V corsa 1 = Haiku V corsa 1", c("V-opus-corsa1", "V-sonnet-corsa1", "V-haiku-corsa1")),
  riga("Opus V corse 1 e 2 = Sonnet V corse 1 e 2", c("V-opus-corsa1", "V-opus-corsa2", "V-sonnet-corsa1", "V-sonnet-corsa2")),
  riga("Mistral B0 = Mistral v1", c("mistral_B0", "mistral_v1")),
  riga("le 16 corse Claude", names(o$RUN)),
  riga("Mistral B0 e le 16 corse Claude", c("mistral_B0", names(o$RUN))))
write.csv(R, file.path(qui, "31-accordo-fra-lettori.csv"), row.names = FALSE); options(width = 250); print(R, row.names = FALSE)
