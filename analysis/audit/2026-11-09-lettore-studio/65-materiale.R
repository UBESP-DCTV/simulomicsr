# PROVA DA BUTTARE
# 65-materiale.R — il materiale per la lettura di tutti i disaccordi del lettore v0 (65-disaccordi.md).
# Task 10 del piano del lettore dello studio (S12r). Solo i 47 studi di sviluppo: gli studi di giudizio non
# entrano in nessun oggetto letto qui.
#
# Uso (SENZA --vanilla), dopo le due esecuzioni di 64-adatta-e-misura.R con gli oggetti salvati:
#   S12R_OGGETTI=/tmp/ogg-principale.rds Rscript .../64-adatta-e-misura.R > /dev/null
#   S12R_OGGETTI=/tmp/ogg-forma.rds S12R_SENSIBILITA=forma Rscript .../64-adatta-e-misura.R > /dev/null
#   Rscript .../65-materiale.R /tmp/ogg-principale.rds /tmp/ogg-forma.rds > .../65-materiale.txt
#
# Per ogni studio: la vista (colonne e valori distinti), l'uscita del modello (ruoli, fattori, livelli, base, forma
# delle voci), la tabella di Atlas, l'incrocio dei gruppi di Atlas con i gruppi del lettore, i confronti di Atlas
# con la classe e l'esito nella misura principale e nella sensibilita' `forma`, i confronti del lettore, il
# registro delle coppie. Dove la misura principale non chiude lo studio e la sensibilita' si', l'incrocio e i
# confronti del lettore vengono dalla sensibilita' e la riga lo dice. Nessun taglio: gli elenchi lunghi sono
# troncati a video con il numero di righe tolte scritto.
suppressMessages(devtools::load_all(".", quiet = TRUE))
arg <- commandArgs(trailingOnly = TRUE)
stopifnot(length(arg) == 2L, all(file.exists(arg)))
P <- readRDS(arg[1]); F <- readRDS(arg[2])
A <- "analysis/audit/2026-11-09-lettore-studio"
DIR_USCITE <- "analysis/p4-output/S12r-lettore-v0"
c1 <- lapply(readLines(file.path(DIR_USCITE, "corsa1.jsonl"), encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
names(c1) <- vapply(c1, `[[`, "", "record_id")
studi <- names(P$lett)
stopifnot(length(studi) == 47L, identical(studi, names(F$lett)), setequal(studi, names(c1)))
car <- function(x) if (is.null(x)) character(0) else as.character(unlist(x))
tr <- function(x, n = 70L) ifelse(nchar(x) > n, paste0(substr(x, 1L, n), "…"), x)
conta <- function(x, max = 8L) {
  t <- sort(table(x, useNA = "ifany"), decreasing = TRUE)
  s <- sprintf("«%s» %d", tr(names(t), 50L), as.integer(t))
  paste0(paste(utils::head(s, max), collapse = "; "), if (length(s) > max) sprintf("; … altri %d valori", length(s) - max) else "")
}
etichetta <- function(tab, gsm) {
  if (!ncol(tab$livelli)) return(stats::setNames(rep("(nessun fattore)", length(gsm)), gsm))
  stats::setNames(do.call(paste, c(lapply(names(tab$livelli), function(n) paste0(n, "=", tab$livelli[gsm, n])), sep = " & ")), gsm)
}
righe <- function(x, max = 40L) {
  cat(utils::head(x, max), sep = "\n")
  if (length(x) > max) cat(sprintf("  … altre %d righe\n", length(x) - max))
}

for (g in studi) {
  v <- P$viste[[g]]; u <- jsonlite::fromJSON(c1[[g]]$raw, simplifyVector = FALSE)
  rp <- P$lett[[g]]; rf <- F$lett[[g]]; x <- P$rif[[g]]
  mp <- P$mm[[g]]; mf <- F$mm[[g]]; o <- P$oggi[P$oggi$studio == g, ]
  cat(sprintf("\n=================== %s (%s) campioni vista %d, universo Atlas %d\n", g, x$accession, length(car(v$campioni)), length(x$universo)))
  cat(sprintf("LETTORE principale: chiuso=%s classe=%s ritrovati %d/%d nostri %d | FORMA: chiuso=%s classe=%s ritrovati %d/%d nostri %d | OGGI: classe=%s ritrovati %d/%d nostri %d errori %d/%d\n",
              rp$chiuso, mp$riga$classe_gruppi, mp$riga$n_rispetta_uguale, mp$riga$n_rispetta, mp$riga$n_nostri,
              rf$chiuso, mf$riga$classe_gruppi, mf$riga$n_rispetta_uguale, mf$riga$n_rispetta, mf$riga$n_nostri,
              o$classe_gruppi, o$n_rispetta_uguale, o$n_rispetta, o$n_nostri, o$n_errori, o$n_giudicabili))
  if (length(rp$motivi)) cat("motivi principale:", tr(paste(rp$motivi, collapse = " || "), 500L), "\n")
  if (length(rf$motivi)) cat("motivi forma:", tr(paste(rf$motivi, collapse = " || "), 500L), "\n")
  if (length(rp$note)) cat("note principale:", tr(paste(rp$note, collapse = " || "), 300L), "\n")
  cat("TITOLO:", tr(sub("\n.*$", "", sub("^[^\n]*\n?", "", v$testo)), 200L), "\n")
  cat("VISTA colonne:\n")
  for (k in car(v$colonne)) cat(sprintf("  %s [%d distinti]: %s\n", k, length(unique(unlist(v$tabella[[k]]))), conta(unlist(v$tabella[[k]]), 6L)))
  cat("MODELLO ruoli:", paste(vapply(u$columns, function(k) sprintf("%s=%s%s", k$column, k$role, if (nzchar(k$subject_kind)) paste0("/", k$subject_kind) else ""), ""), collapse = "; "), "\n")
  for (f in u$factors) {
    nv <- vapply(f$assignment, function(a) length(a$values), 0L)
    cat(sprintf("MODELLO fattore «%s» (%s; fonti: %s; base: «%s»); %d voci, valori per voce: %s\n    livelli: %s\n    voci: %s\n", f$name, f$type,
                paste(car(f$source_columns), collapse = ", "), f$baseline_level, length(nv),
                paste(sprintf("%dx%d", as.integer(table(nv)), as.integer(names(table(nv)))), collapse = " "),
                tr(paste(vapply(f$levels, function(l) l$level, ""), collapse = " | "), 300L),
                tr(paste(utils::head(vapply(f$assignment, function(a) sprintf("[%s]→%s", paste(tr(car(a$values), 30L), collapse = " ¦ "), a$level), ""), 6L), collapse = "  "), 420L)))
  }
  if (length(u$not_understood)) cat("MODELLO non capito:", tr(jsonlite::toJSON(u$not_understood, auto_unbox = TRUE), 300L), "\n")
  ta <- x$atlas$tabella; uni <- x$universo
  cat("ATLAS fattori:", paste(sprintf("%s (%s; base «%s»)", ta$fattori$nome, ta$fattori$tipo, ta$fattori$base), collapse = "; "), "\n")
  ea <- etichetta(ta, uni)
  usa <- if (rp$chiuso) rp else if (rf$chiuso) rf else NULL
  if (!is.null(usa)) {
    cat(sprintf("GRUPPI Atlas × lettore%s (universo): lettore fattori: %s\n", if (rp$chiuso) "" else " [DALLA SENSIBILITA' forma]",
                paste(sprintf("%s (%s; base «%s»)", usa$tabella$fattori$nome, usa$tabella$fattori$tipo, usa$tabella$fattori$base), collapse = "; ")))
    el <- etichetta(usa$tabella, uni)
    t <- as.data.frame(table(atlas = ea, lettore = el), stringsAsFactors = FALSE); t <- t[t$Freq > 0L, ]
    t <- t[order(t$atlas, t$lettore), ]
    righe(sprintf("  A[%s]  ×  L[%s]  n=%d", tr(t$atlas, 90L), tr(t$lettore, 110L), t$Freq), 45L)
    k <- usa$confronti
    if (nrow(k)) righe(sprintf("  LETTORE confronto %s: «%s» contro «%s» (%d/%d) %s %s", k$fattore, k$livello_trattato, k$livello_base,
                               lengths(k$trattato), lengths(k$controllo), k$esito,
                               vapply(k$avvisi, function(a) paste(names(a), collapse = ","), "")), 30L)
    if (nrow(usa$registro)) cat("  REGISTRO coppie:", paste(sprintf("%s %d", names(table(usa$registro$motivo)), as.integer(table(usa$registro$motivo))), collapse = "; "), "\n")
    ne <- (if (rp$chiuso) mp else mf)$non_elencati
    if (nrow(ne)) cat("  NON ELENCATI da Atlas:", paste(sprintf("%s=%s", ne$id, ne$giudizio), collapse = "; "), "\n")
  } else {
    cat("GRUPPI Atlas (lettore non chiuso in nessuna delle due letture):\n")
    righe(sprintf("  A[%s] n=%d", tr(names(table(ea)), 120L), as.integer(table(ea))), 30L)
  }
  ka <- mp$atlas; kf <- mf$atlas
  if (nrow(ka)) righe(sprintf("  ATLAS confronto «%s» (%d/%d) classe=%s diversi=%s | principale: %s | forma: %s", tr(ka$nome, 110L), lengths(ka$trattato),
                              lengths(ka$controllo), ka$classe, ka$fattori_diversi, ka$ritrovato, kf$ritrovato[match(ka$id, kf$id)]), 60L)
}
