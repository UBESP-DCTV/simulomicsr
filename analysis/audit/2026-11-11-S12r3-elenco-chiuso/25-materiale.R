# PROVA DA BUTTARE
# 25-materiale.R — S12r3: il materiale per la lettura di tutti i disaccordi (schema delle uscite a elenco chiuso).
# Solo i 47 studi di sviluppo: gli studi di giudizio non entrano in nessun oggetto letto qui (cancello K5).
#
# Uso (SENZA --vanilla), dopo 24-misura.R con gli oggetti salvati fuori dal repo:
#   S12R3_OGGETTI=<ogg.rds> Rscript .../24-misura.R > .../24-out.txt 2>&1
#   Rscript .../25-materiale.R <ogg.rds> > .../25-materiale-M.txt
#
# Un'unita' di disaccordo (00-previsioni.md, come in S12r2) e': uno studio non chiuso; una partizione non identica;
# un confronto del riferimento non ritrovato; un confronto del lettore giudicato errore. Si contano nella misura
# principale (contesto fuori, 95 confronti). Accanto a ogni confronto di Atlas stanno la marca `solo_contesto` e
# l'esito nella lettura intera.
# Per ogni studio con almeno un'unita', e per ogni studio che in S12r2 aveva un'unita' (13 non chiusi, 3 partizioni
# non identiche, 4 con soli confronti non ritrovati): lo stato in S12r2 con la causa letta allora, la vista (colonne
# e valori distinti), l'uscita del modello (fattori, colonna, livelli, base, voci; ruoli delle colonne), la tabella
# di Atlas, l'incrocio dei gruppi, i confronti del lettore, il registro, i non elencati, i confronti di Atlas.
# Nessun taglio: gli elenchi lunghi sono troncati a video con il numero di righe tolte scritto.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-11-S12r3-elenco-chiuso/aiuti-misura-r3.R")
arg <- commandArgs(trailingOnly = TRUE)
stopifnot(length(arg) == 1L, file.exists(arg[1]))
O <- readRDS(arg[1]); cod <- "M"
R <- O$ris[[cod]]; studi <- O$sv$gse
stopifnot(length(studi) == 47L, identical(names(R$lett), studi), identical(names(R$mm), studi))
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
oggi_p <- O$oggi$principale; v1_p <- O$v1$principale
stopifnot(identical(oggi_p$studio, studi), identical(v1_p$studio, studi))
# S12r2 (schema v1, Mistral-Small 3.2, corsa 1): le unita' con la causa letta allora
d2 <- utils::read.csv(file.path(R2, "26-disaccordi-M-righe.csv"), stringsAsFactors = FALSE)
stato3 <- function(chiuso, classe) ifelse(!chiuso, "non chiuso", ifelse(classe %in% "identica", "identica", "diversa"))

unita <- data.frame()
for (g in studi) {
  v <- O$viste[[g]]; r <- R$lett[[g]]; x <- O$rif[[g]]; m <- R$mm[[g]]; mp <- m$principale; mi <- m$intera
  o <- oggi_p[oggi_p$studio == g, ]; w <- v1_p[v1_p$studio == g, ]
  ka <- mp$atlas; ne <- mp$non_elencati
  persi <- if (nrow(ka)) ka$id[ka$in_b & !ka$ritrovato %in% "uguale"] else character(0)
  err <- if (nrow(ne)) ne$id[ne$giudizio %in% c("piu_fattori", "braccio_misto")] else character(0)
  n_un <- as.integer(!r$chiuso) + as.integer(r$chiuso && !mp$riga$classe_gruppi %in% "identica") + length(persi) + length(err)
  s_v1 <- stato3(w$chiuso, w$classe_gruppi); s_nuovo <- stato3(r$chiuso, mp$riga$classe_gruppi)
  u2 <- d2[d2$studio == g, ]
  unita <- rbind(unita, data.frame(studio = g, chiuso = r$chiuso, classe = mp$riga$classe_gruppi, non_ritrovati = length(persi),
                                   errori = length(err), unita = n_un, stato_v1 = s_v1, stato_nuovo = s_nuovo,
                                   unita_v1 = nrow(u2), stringsAsFactors = FALSE))
  testa <- sprintf("%s (%s) campioni vista %d, universo Atlas %d | NUOVO: %s ritrovati %d/%d nostri %d errori %d/%d | V1: %s ritrovati %d/%d nostri %d errori %d/%d | OGGI: classe=%s ritrovati %d/%d nostri %d errori %d/%d",
                   g, x$accession, length(car(v$campioni)), length(x$universo), s_nuovo, mp$riga$n_b_uguale,
                   mp$riga$n_b_den, mp$riga$n_nostri, mp$riga$n_errori, mp$riga$n_giudicabili,
                   s_v1, w$n_b_uguale, w$n_b_den, w$n_nostri, w$n_errori, w$n_giudicabili,
                   o$classe_gruppi, o$n_b_uguale, o$n_b_den, o$n_nostri, o$n_errori, o$n_giudicabili)
  if (n_un == 0L && !nrow(u2)) { cat("\n=== SENZA UNITA' ", testa, "\n", sep = ""); next }
  cat(sprintf("\n=================== %s\nUNITA': %d (non chiuso %d, partizione %d, non ritrovati %d, errori %d); in S12r2: %d\n", testa, n_un,
              as.integer(!r$chiuso), as.integer(r$chiuso && !mp$riga$classe_gruppi %in% "identica"), length(persi), length(err), nrow(u2)))
  if (nrow(u2)) righe(sprintf("  S12r2 %s %s: %s/%s%s | rimedio %s | %s", u2$tipo, u2$id, u2$causa, u2$sotto,
                              ifelse(nzchar(u2$resto_causa), sprintf(" (resto %s/%s)", u2$resto_causa, u2$resto_sotto), ""),
                              u2$rimedio, tr(u2$differenza, 420L)), 12L)
  if (length(r$motivi)) cat("motivi:", tr(paste(r$motivi, collapse = " || "), 900L), "\n")
  if (length(r$note)) cat("note:", tr(paste(r$note, collapse = " || "), 500L), "\n")
  cat("conti:", paste(sprintf("%s=%s", names(r$conti), unlist(r$conti)), collapse = "; "), "\n")
  cat("TITOLO:", tr(sub("\n.*$", "", sub("^[^\n]*\n?", "", v$testo)), 200L), "\n")
  cat("VISTA colonne:\n")
  for (k in car(v$colonne)) cat(sprintf("  %s [%d distinti]: %s\n", k, length(unique(unlist(v$tabella[[k]]))), conta(unlist(v$tabella[[k]]), 6L)))
  raw <- as.character(unlist(R$corsa[[g]]$raw)); fine <- car(R$corsa[[g]]$fine)
  u <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  cat(sprintf("MODELLO: fine=%s, token di uscita %s\n", paste(fine, collapse = ","), paste(car(R$corsa[[g]]$n_out), collapse = ",")))
  if (is.null(u)) cat("MODELLO: uscita non leggibile\n") else {
    for (f in u$factors) {
      vv <- f$assignment$values
      lv <- vapply(vv, function(a) a$level, "")
      cat(sprintf("MODELLO fattore «%s» (%s; colonna: %s; base: «%s»; prova: «%s»); %d voci su %d livelli scritti\n    livelli: %s\n    voci: %s\n    campioni per livello: %s\n",
                  f$name, f$type, f$assignment$column, f$baseline_level, tr(f$baseline_evidence, 100L), length(vv), length(f$levels),
                  tr(paste(vapply(f$levels, function(l) sprintf("%s{%s%s%s}", l$level, l$entity,
                                                                  if (nzchar(l$dose)) paste0("; dose ", l$dose) else "",
                                                                  if (nzchar(l$duration)) paste0("; durata ", l$duration) else ""), ""), collapse = " | "), 500L),
                  tr(paste(utils::head(vapply(vv, function(a) sprintf("[%s]→%s", tr(a$value, 45L), a$level), ""), 14L), collapse = "  "), 900L),
                  conta(lv[match(unlist(v$tabella[[f$assignment$column]]), vapply(vv, function(a) a$value, ""))], 10L)))
    }
    cat("MODELLO colonne:", paste(vapply(u$columns, function(k) sprintf("%s=%s%s%s", k$column, k$role,
      if (nzchar(k$subject_kind)) paste0("/", k$subject_kind) else "",
      if (length(k$missing_values)) sprintf(" [mancanti: %s]", paste(car(k$missing_values), collapse = "¦")) else ""), ""), collapse = "; "), "\n")
    if (length(u$not_understood)) cat("MODELLO non capito:", tr(as.character(jsonlite::toJSON(u$not_understood, auto_unbox = TRUE)), 600L), "\n")
  }
  ta <- x$atlas$tabella; uni <- x$universo
  cat("ATLAS fattori:", paste(sprintf("%s (%s; base «%s»)", ta$fattori$nome, ta$fattori$tipo, ta$fattori$base), collapse = "; "), "\n")
  ea <- etichetta(ta, uni)
  if (r$chiuso) {
    cat("GRUPPI Atlas × lettore (universo): lettore fattori:",
        paste(sprintf("%s (%s; base «%s»)", r$tabella$fattori$nome, r$tabella$fattori$tipo, r$tabella$fattori$base), collapse = "; "),
        sprintf("| soggetti: %d colonne | gruppi del lettore nell'universo %d, di Atlas %d", as.integer(r$n_soggetti),
                mp$riga$n_gruppi_lettore, mp$riga$n_gruppi_atlas), "\n")
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
    righe(sprintf("  ATLAS confronto %s «%s» (%d/%d) classe=%s diversi=%s tempo_zero=%s solo_contesto=%s | principale: in_b=%s ritrovato=%s | intera: in_b=%s ritrovato=%s",
                  ki$id, tr(ki$nome, 110L), lengths(ki$trattato), lengths(ki$controllo), ka$classe[ip], ka$fattori_diversi[ip], ka$tempo_zero[ip],
                  ka$solo_contesto[ip], ka$in_b[ip], ka$ritrovato[ip], ki$in_b, ki$ritrovato), 60L)
  }
}
cat(sprintf("\n=================== RIEPILOGO %s, misura principale (contesto fuori)\nstudi con almeno un'unita': %d su 47; unita': %d (non chiusi %d, partizioni non identiche %d, confronti non ritrovati %d, errori %d)\n",
            cod, sum(unita$unita > 0L), sum(unita$unita), sum(!unita$chiuso), sum(unita$chiuso & !unita$classe %in% "identica"),
            sum(unita$non_ritrovati), sum(unita$errori)))
cat("stato in S12r2 (righe) contro stato nuovo (colonne):\n")
print(table(v1 = factor(unita$stato_v1, c("non chiuso", "identica", "diversa")), nuovo = factor(unita$stato_nuovo, c("non chiuso", "identica", "diversa"))))
utils::write.csv(unita, file.path(R3, sprintf("25-unita-%s.csv", cod)), row.names = FALSE)
