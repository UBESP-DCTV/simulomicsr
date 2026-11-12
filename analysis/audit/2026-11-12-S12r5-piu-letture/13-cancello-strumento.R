#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 13-cancello-strumento.R — S12r5: lo strumento di misura provato sulle uscite CONGELATE di S12r4, prima di ogni
# corsa nuova. Uscita: 13-out.txt. Nessuna uscita di questa sessione si legge qui.
#   (1) le uscite di B0, B0pl1 e B0pl2 hanno lo SHA-256 depositato in S12r4 e la misura di oggi rida' le righe di
#       24-per-studio.csv (stato, firma, fonti, soggetti, confronti ritrovati, predicati);
#   (2) i 9 predicati degli errori di B0 ridanno gli stati letti in S12r4 (27-stati.csv) nelle 31 corse: 279 su 279;
#       in B0 i 9 errori sono presenti;
#   (3) la regola sulla discordanza, applicata a B0 e ai due placebo di S12r4, rida' i 12 studi dell'handout
#       (31-out.txt di S12r4): 7 con gruppi identici ai curatori, 4 studi con errore su 8, 3 dei 4 che costano;
#   (4) firma uguale -> gruppi uguali e confronti uguali (conto sulle 3 corse).
# In coda, DICHIARATO come calcolo su dati gia' visti: la regola di esito applicata a quel caso (serve a scrivere
# la previsione, non e' un risultato di questa sessione).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
OUT <- file.path(S5, "13-out.txt"); cat("13-cancello-strumento.R  PROVA DA BUTTARE\n", file = OUT)
nota <- function(...) { x <- sprintf(...); cat(x, "\n", sep = ""); cat(x, "\n", sep = "", file = OUT, append = TRUE) }
ps <- utils::read.csv(file.path(S4, "24-per-studio.csv"), stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8", na.strings = "")
st <- utils::read.csv(file.path(S4, "27-stati.csv"), stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8")
ok <- TRUE; cancello <- function(v, ...) { nota("%s: %s", if (isTRUE(v)) "PASSA" else "FALLISCE", sprintf(...)); if (!isTRUE(v)) ok <<- FALSE }

# (1) impronte e misura
TRE <- c("B0", "B0pl1", "B0pl2"); M <- list()
for (k in TRE) {
  f <- file.path(USCITE_R4, paste0(k, ".jsonl")); im <- readLines(file.path(S4, "23-uscite-sha256", paste0(k, ".txt")), warn = FALSE)
  atteso <- sub("  .*$", "", im[endsWith(im, paste0("  ", f))])
  cancello(length(atteso) == 1L && identical(sha(f), atteso), "%s: SHA-256 dell'uscita congelata = impronta di S12r4 (%s)", k, substr(sha(f), 1L, 12L))
  M[[k]] <- misura_forma(leggi_uscite(f), k)
  a <- M[[k]]$tab; b <- ps[ps$corsa == k, ]; b <- b[match(a$studio, b$studio), ]
  uguale <- function(n) identical(as.character(a[[n]]), as.character(b[[n]])) || all((is.na(a[[n]]) & is.na(b[[n]])) | (!is.na(a[[n]]) & !is.na(b[[n]]) & as.character(a[[n]]) == as.character(b[[n]])))
  nn <- c("stato", "firma", "fonti", "soggetti", "n_b_uguale", "n_b_den", "errore_di_lettura", "fattori_doppi")
  # nel CSV una stringa vuota e' NA: si confronta dopo la stessa lettura
  a2 <- a; for (n in c("fonti", "soggetti")) a2[[n]][!is.na(a2[[n]]) & !nzchar(a2[[n]])] <- NA; a <- a2
  cancello(all(vapply(nn, uguale, NA)), "%s: la misura di oggi rida' 24-per-studio.csv su 47 studi (%s); chiusi %d, gruppi identici %d, confronti ritrovati %d/%d",
           k, paste(nn, collapse = ", "), sum(a$chiuso), sum(a$stato == "identica"), sum(a$n_b_uguale), sum(a$n_b_den))
}

# (2) i 9 predicati sulle 31 corse di S12r4
corse <- unique(st$corsa); stopifnot(length(corse) == 31L, all(corse %in% ps$corsa))   # le 31 forme; 24-per-studio.csv ha anche le seconde corse
P <- do.call(rbind, lapply(corse, function(k) { t <- ps[ps$corsa == k, ]; t$soggetti[is.na(t$soggetti) & !is.na(t$fonti)] <- ""
  data.frame(errore = ERRORI_B0$errore, corsa = k, predicato = stato_errori(t), stringsAsFactors = FALSE) }))
P$letto <- st$stato[match(paste(P$errore, P$corsa), paste(st$errore, st$corsa))]
P$predetto <- ifelse(is.na(P$predicato), "non valutabile", ifelse(P$predicato, "presente", "assente"))
scrivi_r5(P, "13-predicati-su-S12r4.csv")
cancello(nrow(P) == 279L && !anyNA(P$letto) && all(P$predetto == P$letto), "i 9 predicati ridanno gli stati letti in S12r4: %d su %d (errore x corsa); discordi: %s",
         sum(P$predetto == P$letto, na.rm = TRUE), nrow(P), unisci(paste(P$errore, P$corsa)[is.na(P$letto) | P$predetto != P$letto]))
cancello(all(P$predicato[P$corsa == "B0"]), "in B0 i 9 errori sono presenti: %d su 9", sum(P$predicato[P$corsa == "B0"]))
for (e in ERRORI_B0$errore) nota("  %s: presente in %d corse su 31, in %d delle 21 del lato B", e, sum(P$predicato[P$errore == e], na.rm = TRUE),
                                 sum(P$predicato[P$errore == e & P$corsa %in% names(FORME)[vapply(FORME, function(f) f$lato == "B", NA)]], na.rm = TRUE))

# (3) la regola sulla discordanza su B0 + i due placebo
CH <- lapply(M, chiavi_lettura); K <- function(n) vapply(CH, function(x) if (n == "tutto") chiave_tutto(x) else x[[n]], character(47))
DODICI <- c("GSE147507", "GSE46665", "GSE49155", "GSE56691", "GSE56787", "GSE60340", "GSE63816", "GSE65335", "GSE66573", "GSE67812", "GSE68919", "GSE83687")
sf <- segnalato(K("firma")); b0 <- M$B0$tab
cancello(setequal(sv$gse[sf], DODICI), "discordanza sulla sola firma, B0 + B0pl1 + B0pl2: %d studi segnalati, gli stessi 12 dell'handout: %s", sum(sf), unisci(sort(sv$gse[sf])))
cancello(sum(b0$stato[sf] == "identica") == 7L && sum(sf & sv$gse %in% STUDI_CON_ERRORE) == 4L && sum(sf & sv$gse %in% STUDI_CHE_COSTANO) == 3L,
         "dei 12: gruppi identici ai curatori in B0 %d (attesi 7); studi con un errore di B0 %d su 8 (attesi 4); studi con un errore che costa %d su 4 (attesi 3: non %s)",
         sum(b0$stato[sf] == "identica"), sum(sf & sv$gse %in% STUDI_CON_ERRORE), sum(sf & sv$gse %in% STUDI_CHE_COSTANO), unisci(setdiff(STUDI_CHE_COSTANO, sv$gse[sf])))
sg <- segnalato(K("tutto"))
nota("  la regola principale (firma + gruppi + confronti): %d studi segnalati; in piu' della sola firma: %s; segnalati sui soli gruppi %d, sui soli confronti %d",
     sum(sg), unisci(sv$gse[sg & !sf]), sum(segnalato(K("gruppi"))), sum(segnalato(K("confronti"))))
cancello(all(sg[sf]), "ogni studio segnalato sulla firma e' segnalato dalla regola principale")

# (4) firma uguale e tutte e due le letture chiuse -> gruppi e confronti uguali; firma uguale e chiusura diversa: si conta
viol <- 0L; coppie <- 0L; chius <- character(0)
for (g in seq_len(47L)) for (i in 1:2) for (j in (i + 1):3) if (K("firma")[g, i] == K("firma")[g, j] && K("firma")[g, i] != "senza tabella") {
  coppie <- coppie + 1L; nc <- c(K("gruppi")[g, i], K("gruppi")[g, j]) == "non chiuso"
  if (xor(nc[1], nc[2])) chius <- c(chius, sv$gse[g])
  else if (K("gruppi")[g, i] != K("gruppi")[g, j] || K("confronti")[g, i] != K("confronti")[g, j]) viol <- viol + 1L }
cancello(viol == 0L, "firma uguale e stessa chiusura -> gruppi e confronti uguali: %d coppie di letture con la stessa firma, %d con gruppi o confronti diversi", coppie, viol)
nota("  firma uguale, una lettura chiusa e una no: %d coppie, negli studi %s (la firma non vede la chiusura: per questo la regola principale usa le tre chiavi)", length(chius), unisci(unique(chius)))

# coda: la regola di esito sul caso gia' visto (per la previsione)
for (n in c("tutto", "firma")) { e <- esito_regola(segnalato(K(n)))
nota("GIA' VISTO (non e' un risultato): regola di esito su B0 + 2 placebo, chiave %s: segnalati %d; fra gli studi con errore %d/%d, fra gli altri %d/%d, differenza %+.3f, IC95 %+.3f, %+.3f (ricampionamenti senza un gruppo: %d); studi che costano segnalati %d/4; esito %s",
     n, sum(segnalato(K(n))), e$q$con, e$q$n_con, e$q$senza, e$q$n_senza, e$q$diff, e$q$ic[1], e$q$ic[2], e$q$vuoti, e$costano, e$esito) }
nota("CANCELLO DELLO STRUMENTO: %s", if (ok) "PASSA" else "FALLISCE")
if (!ok) quit(status = 1L)
