# PROVA DA BUTTARE
# 25-materiale.R — S12r2: il materiale per la lettura di tutti i disaccordi di un modello (25-disaccordi.md).
# Solo i 47 studi di sviluppo: gli studi di giudizio non entrano in nessun oggetto letto qui.
#
# Uso (SENZA --vanilla), dopo 24-misura.R con gli oggetti salvati fuori dal repo:
#   S12R2_OGGETTI=<ogg.rds> Rscript .../24-misura.R > .../24-out.txt 2>&1
#   Rscript .../25-materiale.R <ogg.rds> <modello: M, M0, G1, G2> > .../25-materiale-<modello>.txt
#
# Un'unita' di disaccordo (00-previsioni.md) e': uno studio non chiuso; una partizione non identica; un confronto
# del riferimento non ritrovato; un confronto del lettore giudicato errore. Si contano nella lettura principale;
# i confronti che entrano nel riferimento solo nella lettura intera (tempo zero) sono stampati con la loro lettura.
# Per ogni studio con almeno un'unita': la vista (colonne e valori distinti), l'uscita del modello (fattori, livelli,
# base, voci, altre colonne), la tabella di Atlas, l'incrocio dei gruppi, i confronti di Atlas con classe ed esito,
# i confronti del lettore, il registro delle coppie, i non elencati. Gli studi senza unita' hanno una riga.
# Nessun taglio: gli elenchi lunghi sono troncati a video con il numero di righe tolte scritto.
suppressMessages(devtools::load_all(".", quiet = TRUE))
arg <- commandArgs(trailingOnly = TRUE)
stopifnot(length(arg) == 2L, file.exists(arg[1]))
O <- readRDS(arg[1]); cod <- arg[2]
stopifnot(cod %in% names(O$ris))
R <- O$ris[[cod]]; studi <- O$sv$gse
stopifnot(length(studi) == 47L, identical(names(R$lett), studi))
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
oggi_p <- O$oggi[O$oggi$lettura == "principale", ]

unita <- data.frame()
for (g in studi) {
  v <- O$viste[[g]]; r <- R$lett[[g]]; x <- O$rif[[g]]; m <- R$mm[[g]]; mp <- m$principale; mi <- m$intera
  o <- oggi_p[oggi_p$studio == g, ]
  ka <- mp$atlas; ne <- mp$non_elencati
  persi <- if (nrow(ka)) ka$id[ka$in_b & !ka$ritrovato %in% "uguale"] else character(0)
  err <- if (nrow(ne)) ne$id[ne$giudizio %in% c("piu_fattori", "braccio_misto")] else character(0)
  n_un <- as.integer(!r$chiuso) + as.integer(r$chiuso && !mp$riga$classe_gruppi %in% "identica") + length(persi) + length(err)
  unita <- rbind(unita, data.frame(studio = g, chiuso = r$chiuso, classe = mp$riga$classe_gruppi, non_ritrovati = length(persi),
                                   errori = length(err), unita = n_un, stringsAsFactors = FALSE))
  testa <- sprintf("%s (%s) campioni vista %d, universo Atlas %d | %s: chiuso=%s classe=%s ritrovati %d/%d nostri %d errori %d/%d | OGGI: classe=%s ritrovati %d/%d nostri %d errori %d/%d",
                   g, x$accession, length(car(v$campioni)), length(x$universo), cod, r$chiuso, mp$riga$classe_gruppi, mp$riga$n_b_uguale,
                   mp$riga$n_b_den, mp$riga$n_nostri, mp$riga$n_errori, mp$riga$n_giudicabili,
                   o$classe_gruppi, o$n_b_uguale, o$n_b_den, o$n_nostri, o$n_errori, o$n_giudicabili)
  if (n_un == 0L) { cat("\n=== SENZA UNITA' ", testa, "\n", sep = ""); next }
  cat(sprintf("\n=================== %s\nUNITA': %d (non chiuso %d, partizione %d, non ritrovati %d, errori %d)\n", testa, n_un,
              as.integer(!r$chiuso), as.integer(r$chiuso && !mp$riga$classe_gruppi %in% "identica"), length(persi), length(err)))
  if (length(r$motivi)) cat("motivi:", tr(paste(r$motivi, collapse = " || "), 700L), "\n")
  if (length(r$note)) cat("note:", tr(paste(r$note, collapse = " || "), 400L), "\n")
  cat("TITOLO:", tr(sub("\n.*$", "", sub("^[^\n]*\n?", "", v$testo)), 200L), "\n")
  cat("VISTA colonne:\n")
  for (k in car(v$colonne)) cat(sprintf("  %s [%d distinti]: %s\n", k, length(unique(unlist(v$tabella[[k]]))), conta(unlist(v$tabella[[k]]), 6L)))
  raw <- R$corsa[[g]]$raw
  u <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(u)) cat("MODELLO: uscita non leggibile (fine =", car(R$corsa[[g]]$fine), ")\n") else {
    for (f in u$factors) {
      nv <- vapply(f$assignment, function(a) length(a$when), 0L)
      cat(sprintf("MODELLO fattore «%s» (%s; fonti: %s; base: «%s»; prova: «%s»); %d voci, condizioni per voce: %s\n    livelli: %s\n    voci: %s\n",
                  f$name, f$type, paste(car(f$source_columns), collapse = ", "), f$baseline_level, tr(f$baseline_evidence, 80L), length(nv),
                  paste(sprintf("%dx%d", as.integer(table(nv)), as.integer(names(table(nv)))), collapse = " "),
                  tr(paste(vapply(f$levels, function(l) l$level, ""), collapse = " | "), 300L),
                  tr(paste(utils::head(vapply(f$assignment, function(a) sprintf("[%s]→%s", paste(vapply(a$when, function(w)
                    sprintf("%s=%s", w$column, tr(w$value, 30L)), ""), collapse = " ∧ "), a$level), ""), 10L), collapse = "  "), 700L)))
    }
    cat("MODELLO altre colonne:", paste(vapply(u$other_columns, function(k) sprintf("%s=%s%s%s", k$column, k$role,
      if (nzchar(k$subject_kind)) paste0("/", k$subject_kind) else "",
      if (length(k$missing_values)) sprintf(" [mancanti: %s]", paste(car(k$missing_values), collapse = "¦")) else ""), ""), collapse = "; "), "\n")
    if (length(u$not_understood)) cat("MODELLO non capito:", tr(as.character(jsonlite::toJSON(u$not_understood, auto_unbox = TRUE)), 400L), "\n")
  }
  ta <- x$atlas$tabella; uni <- x$universo
  cat("ATLAS fattori:", paste(sprintf("%s (%s; base «%s»)", ta$fattori$nome, ta$fattori$tipo, ta$fattori$base), collapse = "; "), "\n")
  ea <- etichetta(ta, uni)
  if (r$chiuso) {
    cat("GRUPPI Atlas × lettore (universo): lettore fattori:",
        paste(sprintf("%s (%s; base «%s»)", r$tabella$fattori$nome, r$tabella$fattori$tipo, r$tabella$fattori$base), collapse = "; "), "\n")
    el <- etichetta(r$tabella, uni)
    t <- as.data.frame(table(atlas = ea, lettore = el), stringsAsFactors = FALSE); t <- t[t$Freq > 0L, ]
    t <- t[order(t$atlas, t$lettore), ]
    righe(sprintf("  A[%s]  ×  L[%s]  n=%d", tr(t$atlas, 90L), tr(t$lettore, 110L), t$Freq), 45L)
    k <- r$confronti
    if (nrow(k)) righe(sprintf("  LETTORE confronto %s %s: «%s» contro «%s» (%d/%d) %s %s", k$id, k$fattore, k$livello_trattato, k$livello_base,
                               lengths(k$trattato), lengths(k$controllo), k$esito,
                               vapply(k$avvisi, function(a) paste(if (is.null(names(a))) unlist(a) else names(a), collapse = ","), "")), 40L)
    if (nrow(r$registro)) cat("  REGISTRO coppie:", paste(sprintf("%s %d", names(table(r$registro$motivo)), as.integer(table(r$registro$motivo))), collapse = "; "), "\n")
    if (nrow(ne)) cat("  NON ELENCATI da Atlas:", paste(sprintf("%s=%s", ne$id, ne$giudizio), collapse = "; "), "\n")
  } else {
    cat("GRUPPI Atlas (lettore non chiuso):\n")
    righe(sprintf("  A[%s] n=%d", tr(names(table(ea)), 120L), as.integer(table(ea))), 30L)
  }
  ki <- mi$atlas
  if (nrow(ki)) {
    ip <- match(ki$id, ka$id)
    righe(sprintf("  ATLAS confronto %s «%s» (%d/%d) classe=%s diversi=%s tempo_zero=%s | principale: in_b=%s ritrovato=%s | intera: in_b=%s ritrovato=%s",
                  ki$id, tr(ki$nome, 110L), lengths(ki$trattato), lengths(ki$controllo), ka$classe[ip], ka$fattori_diversi[ip], ka$tempo_zero[ip],
                  ka$in_b[ip], ka$ritrovato[ip], ki$in_b, ki$ritrovato), 60L)
  }
}
cat(sprintf("\n=================== RIEPILOGO %s, lettura principale\nstudi con almeno un'unita': %d su 47; unita': %d (non chiusi %d, partizioni non identiche %d, confronti non ritrovati %d, errori %d)\n",
            cod, sum(unita$unita > 0L), sum(unita$unita), sum(!unita$chiuso), sum(unita$chiuso & !unita$classe %in% "identica"),
            sum(unita$non_ritrovati), sum(unita$errori)))
utils::write.csv(unita, file.path("analysis/audit/2026-11-10-S12r2-prova-ripetuta", sprintf("25-unita-%s.csv", cod)), row.names = FALSE)
