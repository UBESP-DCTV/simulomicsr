# PROVA DA BUTTARE
# 26b-materiale-nuove.R — S12r6: il materiale per la lettura delle schede NUOVE delle 8 corse 2 e del file completato
# V-fable-corsa1b (25-deviazioni.md §4). Esegue il testo di 26-materiale.R con tre righe sostituite: (1) l'elenco delle
# schede da leggere (le coppie studio-corsa con disaccordo la cui scheda non sta in 27-classi.csv); (2) la scelta delle
# schede (quelle dell'elenco, piu' le chiavi nuove di GSE147507); (3) il taglio dei testi lunghi, da 70 a 400 caratteri.
#   Rscript .../26b-materiale-nuove.R <oggetti-16.rds> <oggetti-1b.rds> <cartella di uscita fuori dal repo>   (SENZA --vanilla)
a <- commandArgs(trailingOnly = TRUE); stopifnot(length(a) == 3L, file.exists(a[1:2]))
S6 <- "analysis/audit/2026-11-14-S12r6-claude-via-api"
O <- readRDS(a[1]); B <- readRDS(a[2]); CL <- utils::read.csv(file.path(S6, "27-classi.csv"), stringsAsFactors = FALSE)
R2 <- O$RUN[grepl("corsa2$", names(O$RUN))]; R2[["V-fable-corsa1b"]] <- B$RUN[["V-fable-corsa1"]]; stopifnot(length(R2) == 9L)
LEGN <- do.call(rbind, lapply(names(R2), function(k) { r <- R2[[k]]; t <- r$M$tab; q <- t$n_unita > 0 & !(r$kk$scheda %in% CL$scheda)
  if (!any(q)) return(NULL); data.frame(scheda = r$kk$scheda[q], studio = t$studio[q], corsa = k, forma = substr(k, 1L, 1L), chiuso = t$chiuso[q], stato = t$stato[q], n_unita = t$n_unita[q], unita = t$unita[q], stringsAsFactors = FALSE) }))
G <- do.call(rbind, lapply(names(R2), function(k) { r <- R2[[k]]; q <- r$M$tab$studio == "GSE147507" & !(r$kk$scheda %in% CL$scheda) & r$M$tab$n_unita == 0
  if (!any(q)) return(NULL); data.frame(scheda = r$kk$scheda[q], studio = "GSE147507", corsa = k, forma = substr(k, 1L, 1L), chiuso = r$M$tab$chiuso[q], stato = r$M$tab$stato[q], n_unita = 0L, unita = "", stringsAsFactors = FALSE) }))
utils::write.csv(rbind(LEGN, G), file.path(S6, "29-da-leggere-nuove.csv"), row.names = FALSE)
O$RUN <- R2; tmp <- tempfile(fileext = ".rds"); saveRDS(O, tmp)
tx <- readLines(file.path(S6, "26-materiale.R"))
sost <- function(vecchia, nuova) { j <- which(tx == vecchia); stopifnot(length(j) == 1L); tx[j] <<- nuova }
sost('LEG <- utils::read.csv(file.path(S6, "24-da-leggere.csv"), stringsAsFactors = FALSE)', "LEG <- LEGN")
sost("SCH <- TUTTE[paste(TUTTE$scheda, TUTTE$corsa) %in% paste(LEG$scheda, LEG$corsa) | TUTTE$studio == \"GSE147507\", ]",
     "SCH <- TUTTE[paste(TUTTE$scheda, TUTTE$corsa) %in% paste(c(LEG$scheda, G$scheda), c(LEG$corsa, G$corsa)), ]")
sost("tr <- function(x, n = 70L) { lungo <- !is.na(x) & nchar(x) > n; TAGLI <<- TAGLI + sum(lungo)", "tr <- function(x, n = 400L) { lungo <- !is.na(x) & nchar(x) > n; TAGLI <<- TAGLI + sum(lungo)")
commandArgs <- function(...) c(tmp, a[3])
eval(parse(text = tx, keep.source = FALSE), envir = globalenv())
