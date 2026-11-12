# PROVA DA BUTTARE
# 25-materiale.R — S12r4: il materiale per la lettura (00-previsioni.md par. 5). Solo i 47 studi di sviluppo.
#
#   S12R4_OGGETTI=<ogg.rds> Rscript .../24-misura.R > .../24-out.txt 2>&1
#   Rscript .../25-materiale.R <ogg.rds> <cartella di uscita fuori dal repo>          (SENZA --vanilla)
#
# Un file per studio. In testa lo studio (titolo, colonne della vista con i valori distinti, fattori e confronti di
# Atlas), poi la scheda delle due basi (B0 e A0), poi una scheda per ogni (studio, firma, unita') da leggere, con
# l'elenco delle corse in cui compare e i criteri di peggioramento di ogni corsa. Ogni scheda scrive il canonico
# (fattori, colonne di fonte, livelli con i campioni, base; ruoli delle altre colonne), i componenti della firma,
# i motivi, l'incrocio dei gruppi Atlas x lettore, i confronti del lettore, i confronti di Atlas con l'esito.
# Nessun taglio silenzioso: gli elenchi lunghi sono troncati col numero di righe tolte scritto.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/aiuti-misura-r4.R")
arg <- commandArgs(trailingOnly = TRUE); stopifnot(length(arg) %in% 2:3, file.exists(arg[1]))
O <- readRDS(arg[1]); OUT <- arg[2]; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
stopifnot(identical(O$sv$gse, sv$gse), !startsWith(normalizePath(OUT), normalizePath(".")))
X <- O$X; M <- O$M; CONF <- O$CONF; SCH <- O$SCH; L <- O$L
car <- function(x) if (is.null(x)) character(0) else as.character(unlist(x))
tr <- function(x, n = 70L) ifelse(nchar(x) > n, paste0(substr(x, 1L, n), "…"), x)
conta_v <- function(x, max = 8L) {
  t <- sort(table(x, useNA = "ifany"), decreasing = TRUE); s <- sprintf("«%s» %d", tr(names(t), 50L), as.integer(t))
  paste0(paste(utils::head(s, max), collapse = "; "), if (length(s) > max) sprintf("; … altri %d valori", length(s) - max) else "")
}
etichetta <- function(tab, gsm) {
  if (!ncol(tab$livelli)) return(stats::setNames(rep("(nessun fattore)", length(gsm)), gsm))
  stats::setNames(do.call(paste, c(lapply(names(tab$livelli), function(n) paste0(n, "=", tab$livelli[gsm, n])), sep = " & ")), gsm)
}
righe <- function(x, max = 40L) { cat(utils::head(x, max), sep = "\n"); if (length(x) > max) cat(sprintf("  … altre %d righe\n", length(x) - max)) }
# I componenti della firma, in chiaro (controllo: il digest e' quello di firma_fattori()).
firma_testo <- function(v, k) {
  if (is.null(k)) return(NULL)
  f1 <- vapply(k$factors, function(f) {
    lv <- livelli_canonico(v, f); lv[lv %in% RISERVATI[1]] <- "\001ns"; lv[lv %in% RISERVATI[2]] <- "\001na"
    ris <- lv %in% c("\001ns", "\001na"); idx <- match(lv, unique(lv[!ris & !is.na(lv)]))
    cod <- ifelse(is.na(lv), "?", ifelse(ris, sub("\001", "", lv), as.character(idx)))
    base <- if (nzchar(f$baseline_level) && f$baseline_level %in% lv) match(f$baseline_level, unique(lv[!ris & !is.na(lv)])) else 0L
    paste(f$type, paste(sort(fonti_f(f)), collapse = "+"), paste(cod, collapse = ","), base, sep = "|")
  }, "")
  sg <- vapply(Filter(function(x) identical(x$role, "subject"), k$other_columns), function(x)
    paste(x$column, x$subject_kind, paste(sort(as.character(unlist(x$missing_values))), collapse = ","), sep = "|"), "")
  stopifnot(identical(digest::digest(paste(c(sort(f1), "--", sort(sg)), collapse = "\n"), algo = "sha256", serialize = FALSE), firma_fattori(v, k)))
  list(fattori = sort(f1), soggetti = sort(sg))
}
corto <- function(x) {                                        # la partizione in corto: i codici con le conte
  p <- strsplit(x, "|", fixed = TRUE)[[1]]; cod <- strsplit(p[3], ",", fixed = TRUE)[[1]]; t <- table(cod)
  sprintf("%s | %s | livelli %s | base %s | impronta %s", p[1], p[2], paste(sprintf("%s:%d", names(t), as.integer(t)), collapse = " "), p[4],
          substr(digest::digest(p[3], algo = "sha256", serialize = FALSE), 1L, 6L))
}
testa_studio <- function(g) {
  v <- viste[[g]]; x <- rif[[g]]; ta <- x$atlas$tabella
  cat(sprintf("################ %s (%s) campioni della vista %d, universo di Atlas %d\n", g, x$accession, length(car(v$campioni)), length(x$universo)))
  cat("TITOLO:", tr(sub("\n.*$", "", sub("^[^\n]*\n?", "", v$testo)), 300L), "\n")
  cat("VISTA colonne:\n")
  for (k in car(v$colonne)) cat(sprintf("  %s [%d distinti]: %s\n", k, length(unique(unlist(v$tabella[[k]]))), conta_v(unlist(v$tabella[[k]]), 8L)))
  if (length(v$costanti)) cat("VISTA costanti:", tr(paste(sprintf("%s=«%s»", names(v$costanti), tr(car(v$costanti), 40L)), collapse = "; "), 700L), "\n")
  cat("ATLAS fattori:", paste(sprintf("%s (%s; base «%s»)", ta$fattori$nome, ta$fattori$tipo, ta$fattori$base), collapse = "; "), "\n")
  ea <- etichetta(ta, x$universo); righe(sprintf("  A[%s] n=%d", tr(names(table(ea)), 130L), as.integer(table(ea))), 30L)
  ki <- M$B0$mm[[g]]$intera$atlas; ka <- M$B0$mm[[g]]$principale$atlas
  if (nrow(ki)) { ip <- match(ki$id, ka$id)
    righe(sprintf("  ATLAS confronto %s «%s» (%d/%d) classe=%s diversi=%s tempo_zero=%s solo_contesto=%s nel_denominatore=%s", ki$id, tr(ki$nome, 110L),
                  lengths(ki$trattato), lengths(ki$controllo), ka$classe[ip], ka$fattori_diversi[ip], ka$tempo_zero[ip], ka$solo_contesto[ip], ka$in_b[ip]), 60L) }
}
scheda <- function(k, g, titolo) {
  v <- viste[[g]]; x <- rif[[g]]; r <- M[[k]]$lett[[g]]; mp <- M[[k]]$mm[[g]]$principale; t <- M[[k]]$tab[M[[k]]$tab$studio == g, ]
  cat(sprintf("\n=========== %s\ncorsa %s (forma %s, cambi: %s) | stato %s | ritrovati %d/%d | errori %d/%d | predicato %s | fattori doppi %s | soggetto costante: %s | fine %s, %s token\n",
              titolo, k, sub("-corsa2$", "", k), paste(FORME[[sub("-corsa2$", "", k)]]$cambi, collapse = "+"), t$stato, t$n_b_uguale, t$n_b_den, t$n_errori, t$n_giudicabili,
              t$errore_di_lettura, t$fattori_doppi, t$soggetto_costante_nei_gruppi, t$fine, t$n_out))
  if (length(r$motivi)) cat("motivi:", tr(paste(r$motivi, collapse = " || "), 1200L), "\n")
  if (length(r$note)) cat("note:", tr(paste(r$note, collapse = " || "), 600L), "\n")
  kk <- r$canonico
  if (is.null(kk)) { cat("USCITA non valida o assente; inizio dell'uscita:", tr(as.character(nullo(X[[k]][[g]]$raw)), 600L), "\n"); return(invisible()) }
  for (f in kk$factors) {
    lv <- livelli_canonico(v, f)
    cat(sprintf("FATTORE «%s» (%s; colonne: %s; base «%s»; prova «%s»)\n    livelli scritti: %s\n    campioni per livello: %s\n    voci (%d): %s\n",
                f$name, f$type, paste(fonti_f(f), collapse = " + "), f$baseline_level, tr(nullo(f$baseline_evidence), 110L),
                tr(paste(vapply(f$levels, function(l) sprintf("%s{%s%s%s}", l$level, nullo(l$entity), if (nzchar(nullo(l$dose))) paste0("; dose ", l$dose) else "",
                                                                if (nzchar(nullo(l$duration))) paste0("; durata ", l$duration) else ""), ""), collapse = " | "), 700L),
                conta_v(lv, 12L), length(f$assignment),
                tr(paste(utils::head(vapply(f$assignment, function(a) sprintf("[%s]→%s", paste(vapply(a$when, function(w) sprintf("%s=%s", w$column, tr(w$value, 40L)), ""), collapse = " & "), a$level), ""), 14L), collapse = "  "), 1100L)))
  }
  cat("ALTRE COLONNE:", tr(paste(vapply(kk$other_columns, function(z) sprintf("%s=%s%s%s", z$column, z$role, if (nzchar(nullo(z$subject_kind))) paste0("/", z$subject_kind) else "",
      if (length(z$missing_values)) sprintf(" [mancanti: %s]", paste(car(z$missing_values), collapse = "¦")) else ""), ""), collapse = "; "), 1200L), "\n")
  if (length(kk$not_understood)) cat("NON CAPITO:", tr(as.character(jsonlite::toJSON(kk$not_understood, auto_unbox = TRUE)), 600L), "\n")
  ft <- firma_testo(v, kk); cat("FIRMA", substr(t$firma, 1L, 12L), "\n"); for (z in ft$fattori) cat("    ", corto(z), "\n"); if (length(ft$soggetti)) cat("     soggetti:", paste(ft$soggetti, collapse = "; "), "\n")
  if (r$chiuso) {
    uni <- x$universo; ea <- etichetta(x$atlas$tabella, uni); el <- etichetta(r$tabella, uni)
    cat(sprintf("GRUPPI Atlas × lettore (universo): gruppi del lettore %d, di Atlas %d, classe %s\n", t$n_gruppi_lettore, t$n_gruppi_atlas, t$classe_gruppi))
    tt <- as.data.frame(table(atlas = ea, lettore = el), stringsAsFactors = FALSE); tt <- tt[tt$Freq > 0L, ]; tt <- tt[order(tt$atlas, tt$lettore), ]
    righe(sprintf("  A[%s]  ×  L[%s]  n=%d", tr(tt$atlas, 90L), tr(tt$lettore, 120L), tt$Freq), 45L)
    kc <- r$confronti
    if (nrow(kc)) righe(sprintf("  LETTORE confronto %s %s: «%s» contro «%s» (%d/%d) %s", kc$id, kc$fattore, kc$livello_trattato, kc$livello_base, lengths(kc$trattato), lengths(kc$controllo), kc$esito), 40L)
    if (!is.null(r$registro) && nrow(r$registro)) cat("  REGISTRO coppie:", paste(sprintf("%s %d", names(table(r$registro$motivo)), as.integer(table(r$registro$motivo))), collapse = "; "), "\n")
    ne <- mp$non_elencati; if (!is.null(ne) && nrow(ne)) cat("  NON ELENCATI da Atlas:", paste(sprintf("%s=%s", ne$id, ne$giudizio), collapse = "; "), "\n")
  }
  ka <- mp$atlas; if (nrow(ka)) cat("  ATLAS esito:", paste(sprintf("%s=%s", ka$id[ka$in_b], ka$ritrovato[ka$in_b]), collapse = "; "), "\n")
  cat("UNITA':", if (nzchar(t$unita)) t$unita else "(nessuna)", "\n")
}
CRIT <- c(p1_stato = "stato", p2_ritrovati = "ritrovati", p3_errori = "errori(c)", p4_predicato = "predicato", p5_generico = "generico", p6_firma_e_unita = "firma+unita'")
MIGL <- c(m1_stato = "stato", m2_ritrovati = "ritrovati", m3_errori = "errori(c)", m4_predicato = "predicato", m5_generico = "generico")
for (g in sort(unique(SCH$studio))) {
  sink(file.path(OUT, paste0(g, ".txt")))
  testa_studio(g)
  scheda("B0", g, "BASE B0 (causa delle unita' in S12r3: 26-disaccordi-M-righe.csv)")
  scheda("A0", g, "BASE A0 (causa delle unita' in S12r2: 26-disaccordi-M-righe.csv)")
  s <- SCH[SCH$studio == g, ]
  for (i in seq_len(nrow(s))) {
    d <- L[L$scheda == s$scheda[i], ]
    scheda(s$prima_corsa[i], g, sprintf("SCHEDA %s | %d corse", s$scheda[i], nrow(d)))
    for (j in seq_len(nrow(d))) cat(sprintf("  in %s (base %s: %s, %d/%d, errori %d): %s%s; unita' nuove %d, tolte %d; firma diversa %s\n", d$corsa[j], d$base[j], d$stato_base[j], d$ritrovati_base[j],
      M$B0$tab$n_b_den[M$B0$tab$studio == g], d$errori_base[j],
      if (d$peggiorato[j]) paste0("PEGGIORA per ", paste(CRIT[names(CRIT)[unlist(d[j, names(CRIT)])]], collapse = ", ")) else "non peggiora",
      if (d$migliorato[j]) paste0("; MIGLIORA per ", paste(MIGL[names(MIGL)[unlist(CONF[CONF$corsa == d$corsa[j] & CONF$studio == g, names(MIGL)])]], collapse = ", ")) else "",
      d$unita_nuove[j], d$unita_tolte[j], d$firma_diversa[j]))
  }
  sink()
}
cat(sprintf("schede scritte: %d in %d file, cartella %s\n", nrow(SCH), length(unique(SCH$studio)), OUT))

# Terzo argomento (facoltativo): `27-celle-senza-unita.csv` (corsa, studio, firma). Per ogni coppia (studio, firma)
# una scheda nella sottocartella `su/`: sono le celle senza unita' di disaccordo e con una tabella dei fattori mai
# letta, negli studi che hanno un errore etichettato (27-diagnosi.R le chiede prima di scrivere «assente»).
if (length(arg) == 3L) {
  CE <- utils::read.csv(arg[3], stringsAsFactors = FALSE); OUT2 <- file.path(OUT, "su"); unlink(OUT2, recursive = TRUE); dir.create(OUT2)
  for (g in sort(unique(CE$studio))) {
    sink(file.path(OUT2, paste0(g, ".txt")))
    testa_studio(g)
    scheda("B0", g, "BASE B0"); scheda("A0", g, "BASE A0")
    d <- CE[CE$studio == g, ]
    for (f in unique(d$firma)) { kk <- d$corsa[d$firma == f]
      stopifnot(all(vapply(kk, function(k) substr(M[[k]]$tab$firma[M[[k]]$tab$studio == g], 1L, 12L), "") == f))
      scheda(kk[1], g, sprintf("SCHEDA %s|%s|su | %d corse", g, f, length(kk))); cat("  corse con questa firma e nessuna unita':", paste(kk, collapse = " "), "\n") }
    sink()
  }
  cat(sprintf("schede senza unita': %d in %d file, cartella %s\n", nrow(unique(CE[c("studio", "firma")])), length(unique(CE$studio)), OUT2))
}
