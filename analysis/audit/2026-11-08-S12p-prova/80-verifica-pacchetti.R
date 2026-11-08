#!/usr/bin/env Rscript
# S12p, verifica dei 318 difetti trovati dalla prima lettura (sostituisce la lettura del PI, che il PI non fa).
# Seconda lettura cieca SENZA le affermazioni dei modelli: il pacchetto contiene solo il testo del confronto. Insieme:
# i 318 confronti puliti nel riferimento che la prima lettura giudica non confrontabili; 60 difetti noti (controllo
# positivo); 60 falsi allarmi che la prima lettura giudica confrontabili (controllo dell'altro verso). Nuovi
# identificativi, nuovo ordine. Attese: 00-previsioni-verifica.md.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/80-verifica-pacchetti.R <cartella-lettori> <file-chiave>
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
a <- commandArgs(TRUE); OUT <- a[1]; CHIAVE <- a[2]; N_LOTTO <- 30L
if (dir.exists(OUT)) ferma("la cartella dei lettori esiste gia': %s", OUT)
dir.create(file.path(OUT, "pacchetti"), recursive = TRUE); dir.create(file.path(OUT, "risposte"))
df <- ingressi(); P <- read.csv(file.path(DIR, "70-letture.csv"), stringsAsFactors = FALSE)
nuovi <- P$record_id[P$gruppo == "falso_allarme" & P$confrontabile == "no"]
set.seed(SEME + 2L)
noti <- sample(P$record_id[P$gruppo == "preso" & !P$non_provato], 60L)
si <- sample(P$record_id[P$gruppo == "falso_allarme" & P$confrontabile == "si"], 60L)
sel <- c(nuovi, noti, si); gruppo <- rep(c("nuovo_difetto", "difetto_noto", "confrontabile_prima"), c(length(nuovi), 60L, 60L))
if (anyDuplicated(sel) || length(nuovi) != 318L) ferma("insieme della verifica: attesi 318 + 60 + 60 confronti distinti")
o <- sample(seq_along(sel)); ids <- sprintf("V%04d", seq_along(o)); dimensioni <- integer(); chiave <- list()
for (j in seq_along(o)) {
  r <- sel[o[j]]
  corpo <- c(sprintf("# Packet %s", ids[j]), "", df$testo[match(r, df$record_id)], "", "# Question", "Is this comparison comparable? (see the reading form)")
  con <- file(file.path(OUT, "pacchetti", paste0(ids[j], ".txt")), open = "w", encoding = "UTF-8"); writeLines(corpo, con, useBytes = TRUE); close(con)
  dimensioni[ids[j]] <- sum(nchar(corpo)); chiave[[j]] <- list(id = ids[j], record_id = r, gruppo = gruppo[o[j]])
}
nl <- ceiling(length(ids) / N_LOTTO); ord <- names(sort(dimensioni, decreasing = TRUE)); lotto <- setNames(((seq_along(ord) - 1L) %% nl) + 1L, ord)
for (b in seq_len(nl)) writeLines(sort(names(lotto)[lotto == b]), file.path(OUT, sprintf("lotto-%02d.txt", b)))
write_json(chiave, CHIAVE, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("pacchetti: %d (nuovi difetti %d, difetti noti 60, confrontabili per la prima lettura 60); lotti %d\n", length(ids), length(nuovi), nl))
cat(sprintf("caratteri per lotto: da %d a %d; pacchetto piu' lungo %d\n", min(tapply(dimensioni[names(lotto)], lotto, sum)), max(tapply(dimensioni[names(lotto)], lotto, sum)), max(dimensioni)))
