# PROVA DA BUTTARE
# 25-materiale.R — S12r5: il materiale per la lettura (00-previsioni.md par. 6). Solo i 47 studi di sviluppo.
#
#   S12R5_OGGETTI=<ogg.rds> Rscript .../24-misura.R > .../24-out.txt 2>&1
#   Rscript .../25-materiale.R <ogg.rds> <cartella di uscita fuori dal repo>          (SENZA --vanilla)
#
# Un file per studio segnalato. In testa lo studio (titolo, colonne della vista con i valori distinti, fattori e
# confronti di Atlas) e la legenda delle letture (la frase riscritta di ognuna), poi la scheda di B0, poi una scheda
# per ogni (studio, chiave) diversa da B0, con l'elenco delle letture che hanno quella chiave, che cosa cambia
# rispetto a B0 (tabella dei fattori, gruppi, confronti), lo stato dei 9 errori di B0 in quella lettura e, quando la
# stessa tabella dei fattori e' gia' stata letta in S12r4, l'etichetta di allora (punto di partenza, non esito).
# Le funzioni delle schede sono quelle di S12r4 (25-materiale.R), prese dal file senza eseguirne il resto.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
arg <- commandArgs(trailingOnly = TRUE); stopifnot(length(arg) == 2L, file.exists(arg[1]))
O <- readRDS(arg[1]); OUT <- arg[2]; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
stopifnot(identical(O$sv$gse, sv$gse), !startsWith(normalizePath(OUT), normalizePath(".")))
X <- O$X; M <- O$M; SCH <- O$SCH; L <- O$L; SE <- O$SE; CORSE <- O$CORSE
local({                                                        # solo le definizioni di funzione di S12r4
  e <- parse(file.path(S4, "25-materiale.R"), encoding = "UTF-8", keep.source = FALSE)
  vuoi <- c("car", "tr", "conta_v", "etichetta", "righe", "firma_testo", "corto", "testa_studio", "scheda")
  nomi <- vapply(e, function(x) if (is.call(x) && identical(x[[1]], as.name("<-")) && is.name(x[[2]])) as.character(x[[2]]) else "", "")
  stopifnot(all(vuoi %in% nomi)); for (x in e[nomi %in% vuoi]) eval(x, envir = globalenv())
})
ris <- utils::read.csv(file.path(S5, "11-riscritture.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
legenda <- function() { cat("LETTURE: B0 = prompt v2 senza cambi; ogni altra lettura = B0 con UNA frase del prompt riscritta senza cambiare il senso:\n")
  for (i in seq_len(nrow(ris))) if (ris$lettura[i] %in% CORSE) cat(sprintf("  %s [%s]: «%s»  ->  «%s»\n", ris$lettura[i], ris$sezione[i], ris$originale[i], ris$riscritta[i])) }
errori_studio <- function(g, k) { i <- which(SE$studio == g); if (!length(i)) return("(nessun errore di B0 in questo studio)")
  paste(sprintf("%s = %s", sub("^[^:]*:", "", SE$errore[i]), SE[i, k]), collapse = "; ") }
for (g in sort(unique(SCH$studio))) {
  sink(file.path(OUT, paste0(g, ".txt")))
  testa_studio(g); legenda()
  cat("ERRORI DI B0 (S12r4) in questo studio, stato in B0:", errori_studio(g, "B0"), "\n")
  scheda("B0", g, "BASE B0")
  s <- SCH[SCH$studio == g, ]
  for (i in seq_len(nrow(s))) {
    d <- L[L$scheda == s$scheda[i], ]
    scheda(s$prima_lettura[i], g, sprintf("SCHEDA %s | %d letture: %s", s$scheda[i], nrow(d), paste(d$lettura, collapse = " ")))
    cat(sprintf("  rispetto a B0: tabella dei fattori %s, gruppi %s, confronti %s; stato %s (B0 %s); ritrovati %d (B0 %d) su %d\n",
                if (s$firma_diversa[i]) "DIVERSA" else "uguale", if (s$gruppi_diversi[i]) "DIVERSI" else "uguali", if (s$confronti_diversi[i]) "DIVERSI" else "uguali",
                s$stato[i], s$stato_B0[i], s$ritrovati[i], s$ritrovati_B0[i], s$den[i]))
    cat("  errori di B0, stato in questa lettura:", errori_studio(g, s$prima_lettura[i]), "\n")
    if (nzchar(s$firma_vista_in_S12r4[i])) cat(sprintf("  GIA' LETTA IN S12r4 (corse %s): causa «%s»; errore «%s»; %s\n", tr(s$firma_vista_in_S12r4[i], 200L), s$causa_S12r4[i], s$errore_S12r4[i], s$descrizione_S12r4[i]))
    else cat("  tabella dei fattori MAI vista in S12r4\n")
  }
  sink()
}
cat(sprintf("schede scritte: %d in %d file, cartella %s\n", nrow(SCH), length(unique(SCH$studio)), OUT))
