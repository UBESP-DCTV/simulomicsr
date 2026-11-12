#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 27-dopo-la-lettura.R — S12r5: i conti che chiedono la lettura dei disaccordi (00-previsioni.md par. 6):
# previsione 11 (studi con un errore di lettura nuovo, per lettura nuova, conto per etichetta), previsione 12
# (quota di studi segnalati in cui la discordanza tocca un errore di lettura) e la classe di ogni studio segnalato.
# Scritto dopo il deposito e prima della lettura: applica le definizioni depositate, non ne aggiunge.
#
# Legge: 24-da-leggere-righe.csv, 24-da-leggere-schede.csv, 24-segnalati.csv, 24-stati-errori.csv (24-misura.R) e
# 26-letture.csv (la lettura dell'agente: una riga per scheda; colonne scheda, studio, causa, dove, etichette,
# descrizione; `etichette` = gli errori di lettura presenti nella lettura nuova, separati da « ; »).
# Uso: Rscript analysis/audit/2026-11-12-S12r5-piu-letture/27-dopo-la-lettura.R [26-letture.csv] > .../27-out.txt 2>&1
DIR <- "analysis/audit/2026-11-12-S12r5-piu-letture"
a <- commandArgs(trailingOnly = TRUE)
F_LETT <- if (length(a)) a[[1]] else file.path(DIR, "26-letture.csv")
SUFF <- if (length(a) >= 2L) a[[2]] else ""                    # suffisso delle uscite (per la lettura del revisore)
leggi <- function(f) utils::read.csv(file.path(DIR, f), stringsAsFactors = FALSE, check.names = FALSE)
scrivi <- function(...) cat(sprintf(...), "\n", sep = "")
ferma <- function(...) stop(sprintf(...), call. = FALSE)
RIGHE <- leggi("24-da-leggere-righe.csv"); SCH <- leggi("24-da-leggere-schede.csv")
SEG <- leggi("24-segnalati.csv"); ST <- leggi("24-stati-errori.csv")
LETT <- utils::read.csv(F_LETT, stringsAsFactors = FALSE, check.names = FALSE)
NUOVE <- paste0("L", 1:8)
CAUSE <- c("lettura del modello", "forma", "non errore")
DOVE <- c("in B0", "nella lettura nuova", "in tutte e due", "in nessuna")

# ---- controlli sulla lettura: tutto letto, vocabolario chiuso ------------------------------------------------------
stopifnot(all(c("scheda", "studio", "causa", "dove", "etichette", "descrizione") %in% names(LETT)))
if (anyDuplicated(LETT$scheda)) ferma("26-letture.csv: schede doppie")
if (!setequal(LETT$scheda, SCH$scheda)) ferma("26-letture.csv: le schede lette non sono le schede da leggere (mancano %d, di troppo %d)",
                                               length(setdiff(SCH$scheda, LETT$scheda)), length(setdiff(LETT$scheda, SCH$scheda)))
if (!all(LETT$causa %in% CAUSE)) ferma("causa fuori dal vocabolario: %s", paste(setdiff(LETT$causa, CAUSE), collapse = ", "))
if (!all(LETT$dove %in% DOVE)) ferma("dove fuori dal vocabolario: %s", paste(setdiff(LETT$dove, DOVE), collapse = ", "))
if (any(LETT$causa == "lettura del modello" & LETT$dove == "in nessuna")) ferma("causa «lettura del modello» senza una lettura con l'errore")
if (any(LETT$causa != "lettura del modello" & LETT$dove != "in nessuna")) ferma("causa diversa da «lettura del modello» con un errore di lettura indicato")
if (any(!nzchar(trimws(LETT$descrizione)))) ferma("una scheda non ha la descrizione")
LETT$etichette[is.na(LETT$etichette)] <- ""
etich <- function(x) { p <- trimws(strsplit(x, ";", fixed = TRUE)[[1]]); p[nzchar(p)] }
E <- lapply(LETT$etichette, etich); names(E) <- LETT$scheda
for (i in seq_along(E)) if (length(E[[i]]) && !all(startsWith(E[[i]], paste0(LETT$studio[i], ":"))))
  ferma("%s: un'etichetta non comincia col numero dello studio", LETT$scheda[i])
if (any(LETT$dove %in% c("nella lettura nuova", "in tutte e due") & lengths(E) == 0L)) ferma("errore nella lettura nuova senza etichetta")
scrivi("Schede lette: %d su %d; coppie (studio, lettura nuova) coperte: %d su %d; studi: %d.",
       nrow(LETT), nrow(SCH), sum(RIGHE$scheda %in% LETT$scheda), nrow(RIGHE), length(unique(RIGHE$studio)))
scrivi("Cause delle schede: %s.", paste(sprintf("%s %d", CAUSE, vapply(CAUSE, function(k) sum(LETT$causa == k), 1L)), collapse = "; "))
scrivi("Dove sta l'errore (schede con causa «lettura del modello»): %s.",
       paste(sprintf("%s %d", DOVE[1:3], vapply(DOVE[1:3], function(k) sum(LETT$dove == k), 1L)), collapse = "; "))

# ---- previsione 11: errori di lettura nuovi, conto per etichetta ---------------------------------------------------
# Un errore e' nuovo se B0 non ha quell'etichetta in quello studio. Le etichette di B0 sono i 9 errori di riferimento.
# Una lettura nuova con la chiave uguale a B0 ha la lettura di B0: nessun errore nuovo per costruzione.
B0E <- split(ST$errore, ST$studio)
RIGHE$nuove <- vapply(seq_len(nrow(RIGHE)), function(i) paste(setdiff(E[[RIGHE$scheda[i]]], B0E[[RIGHE$studio[i]]]), collapse = " ; "), "")
RN <- RIGHE[nzchar(RIGHE$nuove), c("studio", "lettura", "scheda", "nuove")]
utils::write.csv(RN, file.path(DIR, sprintf("27-errori-nuovi%s.csv", SUFF)), row.names = FALSE)
per_lett <- vapply(NUOVE, function(l) length(unique(RN$studio[RN$lettura == l])), 1L)
tutte_nuove <- unique(unlist(lapply(RN$nuove, etich)))
scrivi("\nErrori di lettura nuovi (per etichetta). Studi con un errore nuovo per lettura: %s; mediana %s.",
       paste(sprintf("%s %d", NUOVE, per_lett), collapse = ", "), format(stats::median(per_lett)))
scrivi("Etichette nuove distinte nelle 8 letture: %d, in %d studi: %s.", length(tutte_nuove), length(unique(RN$studio)),
       paste(sort(tutte_nuove), collapse = " | "))

# ---- la classe di ogni studio segnalato e la previsione 12 ---------------------------------------------------------
S <- SEG[SEG$segnalato, ]
cambia <- unique(ST$studio[ST$stato_cambia])
S$schede <- vapply(S$studio, function(s) sum(LETT$studio == s), 1L)
S$schede_lettura <- vapply(S$studio, function(s) sum(LETT$studio == s & LETT$causa == "lettura del modello"), 1L)
S$schede_forma <- vapply(S$studio, function(s) sum(LETT$studio == s & LETT$causa == "forma"), 1L)
S$schede_non_errore <- vapply(S$studio, function(s) sum(LETT$studio == s & LETT$causa == "non errore"), 1L)
S$stato_errore_B0_cambia <- S$studio %in% cambia
if (any(S$schede == 0L)) ferma("uno studio segnalato non ha schede")
S$classe <- ifelse(S$schede_lettura > 0L | S$stato_errore_B0_cambia, "tocca un errore di lettura",
                   ifelse(S$schede_forma > 0L, "forma", "non errore"))
S$errore_dove <- vapply(S$studio, function(s) paste(sort(unique(LETT$dove[LETT$studio == s & LETT$causa == "lettura del modello"])), collapse = " ; "), "")
utils::write.csv(S[, c("studio", "classe", "schede", "schede_lettura", "schede_forma", "schede_non_errore", "stato_errore_B0_cambia",
                       "errore_dove", "stato_B0", "errori_di_B0", "errore_che_costa", "n_letture_diverse_da_B0")],
                 file.path(DIR, sprintf("27-classi%s.csv", SUFF)), row.names = FALSE)
tb <- table(factor(S$classe, levels = c("tocca un errore di lettura", "forma", "non errore")))
q <- unname(tb[1]) / nrow(S)
scrivi("\nStudi segnalati: %d. Classe: %s.", nrow(S), paste(sprintf("%s %d", names(tb), as.integer(tb)), collapse = "; "))
scrivi("Quota di studi segnalati in cui la discordanza tocca un errore di lettura: %d/%d = %.1f%%.", unname(tb[1]), nrow(S), 100 * q)
tocca <- S[S$classe == "tocca un errore di lettura", ]
scrivi("Fra questi %d: con un errore di B0 %d; senza errori di B0 (l'errore sta solo in letture nuove) %d; con gruppi identici ai curatori in B0 %d.",
       nrow(tocca), sum(tocca$errori_di_B0 > 0), sum(tocca$errori_di_B0 == 0), sum(tocca$stato_B0 == "identica"))

giud <- function(v, lo, hi) if (v >= lo && v <= hi) "confermata" else "smentita"
P <- data.frame(n = c(11L, 12L),
                quantita = c("studi con un errore di lettura nuovo per lettura nuova, mediana fra le 8", "quota di studi segnalati in cui la discordanza tocca un errore di lettura"),
                atteso = c("2", "65%"), intervallo = c("0-4", "50%-85%"),
                misurato = c(format(stats::median(per_lett)), sprintf("%d/%d = %.1f%%", unname(tb[1]), nrow(S), 100 * q)),
                esito = c(giud(stats::median(per_lett), 0, 4), giud(q, 0.50, 0.85)), stringsAsFactors = FALSE)
utils::write.csv(P, file.path(DIR, sprintf("27-previsioni%s.csv", SUFF)), row.names = FALSE)
scrivi("\nPrevisione 11: %s (%s). Previsione 12: %s (%s).", P$esito[1], P$misurato[1], P$esito[2], P$misurato[2])
