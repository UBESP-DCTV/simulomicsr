#!/usr/bin/env Rscript
# S12p: i 45 confronti confermati solo per i soggetti (aggiunta a 00-previsioni-verifica.md). Copia i loro pacchetti della
# verifica (senza affermazioni) in una cartella nuova e li divide in due lotti. Eseguito il 2026-11-08 (stesso codice).
v <- read.csv("analysis/audit/2026-11-08-S12p-prova/90-difetti-confermati.csv", stringsAsFactors = FALSE)
solo <- function(t) vapply(strsplit(t, " "), function(x) length(x) > 0 && all(x == "soggetti"), TRUE)
y <- v$record_id[solo(v$tipi1) & solo(v$tipi2)]
k <- jsonlite::fromJSON("analysis/audit/2026-11-08-S12p-prova/82-chiave-verifica.json"); ids <- k$id[match(y, k$record_id)]
O <- "/home/user/S12p-soggetti-20261108"; dir.create(file.path(O, "pacchetti"), recursive = TRUE); dir.create(file.path(O, "risposte"))
file.copy(file.path("/home/user/S12p-verifica-20261108/pacchetti", paste0(ids, ".txt")), file.path(O, "pacchetti"))
set.seed(20261108); ids <- sample(ids); writeLines(sort(ids[1:23]), file.path(O, "lotto-01.txt")); writeLines(sort(ids[24:45]), file.path(O, "lotto-02.txt"))
