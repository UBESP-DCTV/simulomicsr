# 67-controlli-revisione.R — conti chiesti dalla revisione finale del branch (S12r, 2026-11-10).
# LETTURE DESCRITTIVE FATTE DOPO I NUMERI: non sono misure depositate e non cambiano l'esito di nessuna previsione.
# Solo i 47 studi di sviluppo (i CSV letti qui non contengono studi di giudizio).
# Uso (SENZA --vanilla): Rscript analysis/audit/2026-11-09-lettore-studio/67-controlli-revisione.R > .../67-out.txt
A <- "analysis/audit/2026-11-09-lettore-studio"
leggi <- function(f) utils::read.csv(file.path(A, f), stringsAsFactors = FALSE, na.strings = character(0), encoding = "UTF-8")
ferma <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call. = FALSE)

cat("== 1. Fattore che i curatori non scrivono per un braccio: lettura larga (usata) e lettura stretta ==\n")
og <- leggi("40-confronti-atlas-oggi.csv"); og <- og[og$variante == "principale", ]
le <- leggi("64-confronti-atlas-lettore.csv")
ferma(nrow(og) == 123L && nrow(le) == 123L, "attesi 123 confronti di Atlas per parte")
ferma(identical(paste(og$studio, og$id), paste(le$studio, le$id)), "le due tabelle non hanno gli stessi confronti nello stesso ordine")
ferma(identical(og$classe, le$classe) && identical(og$fattori_non_scritti, le$fattori_non_scritti), "classi diverse fra le due tabelle")
risp <- og$classe == "rispetta"; ns <- nzchar(og$fattori_non_scritti)
cat(sprintf("confronti `rispetta`: %d; di questi con un fattore non scritto in un braccio: %d, in %d studi\n", sum(risp), sum(risp & ns), length(unique(og$studio[risp & ns]))))
conta <- function(x, nome) {
  largo <- sum(x$ritrovato[risp] == "uguale"); fra <- sum(x$ritrovato[risp & ns] == "uguale"); stretto <- sum(x$ritrovato[risp & !ns] == "uguale")
  cat(sprintf("%s: lettura larga %d/%d = %.1f%%; ritrovati fra i %d con un fattore non scritto: %d; lettura stretta %d/%d = %.1f%%\n", nome,
              largo, sum(risp), 100 * largo / sum(risp), sum(risp & ns), fra, stretto, sum(risp & !ns), 100 * stretto / sum(risp & !ns)))
  c(largo / sum(risp), stretto / sum(risp & !ns))
}
qo <- conta(og, "oggi"); ql <- conta(le, "lettore")
cat(sprintf("differenza lettore - oggi in (b): lettura larga %.1f punti; lettura stretta %.1f punti (senza intervallo: non e' una misura depositata)\n",
            100 * (ql[1] - qo[1]), 100 * (ql[2] - qo[2])))

cat("\n== 2. Unita' di disaccordo per esito (65-disaccordi-righe.csv) ==\n")
u <- leggi("65-disaccordi-righe.csv"); ferma(nrow(u) == 145L, "attese 145 unita'")
print(table(u$tipo, u$esito)); cat("totale per esito:\n"); print(table(u$esito))

cat("\n== 3. Studi in cui una sottoclasse compare: prima causa o resto, e con le note «in piu'» ==\n")
per <- function(chiave) {
  prima <- u$studio[paste(u$causa, u$sotto, sep = "/") == chiave]
  resto <- u$studio[paste(u$resto_causa, u$resto_sotto, sep = "/") == chiave]
  anche <- u$studio[vapply(strsplit(u$anche, "; *"), function(v) chiave %in% trimws(v), NA)]
  pr <- unique(c(prima, resto)); tutti <- unique(c(pr, anche))
  cat(sprintf("%s: prima causa %d studi; prima o resto %d studi; anche con le note «in piu'» %d studi; solo nota in: %s\n", chiave,
              length(unique(prima)), length(pr), length(tutti), paste(setdiff(tutti, pr), collapse = ", ")))
}
for (k in c("modello/fattore_dal_titolo", "schema/fattore_annidato")) per(k)
cat("valori distinti della colonna `anche`:\n"); print(table(u$anche[nzchar(u$anche)]))
