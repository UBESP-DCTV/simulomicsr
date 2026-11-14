# PROVA DA BUTTARE
# 26-materiale.R — S12r6: il materiale per la lettura dei disaccordi delle corse 1 (00-previsioni.md par. 8).
# Solo i 47 studi di sviluppo.
#
#   S12R6_OGGETTI=<ogg.rds> Rscript .../24-misura.R > .../24-out.txt 2>&1
#   Rscript .../26-materiale.R <ogg.rds> <cartella di uscita fuori dal repo>          (SENZA --vanilla)
#
# Un file per studio con almeno una scheda in 24-da-leggere.csv. In testa lo studio: il testo intero che il modello
# riceve prima della tabella dei campioni, le colonne della vista con i valori distinti, i fattori, i gruppi e i
# confronti di Atlas. Poi la scheda di Mistral-Small 3.2 nella forma B0, con le cause scritte nella terza prova
# (S12r3, 26-disaccordi-M-righe.csv): punto di partenza, non esito. Poi una scheda per ogni chiave distinta delle 8
# corse di Claude, in ordine di impronta.
# LETTURA CIECA AL MODELLO: una scheda porta l'impronta e la forma (T o V), non il nome del modello ne' la corsa.
# La chiave impronta -> corse sta in 24-da-leggere.csv e si unisce dopo la lettura. Un rifiuto o un errore dell'API
# si riconosce dal motivo: li' la lettura non e' cieca, e non c'e' niente da giudicare.
# GSE147507: l'errore fuori dai 9 (il tempo in due colonne complementari) non ha predicato e si giudica leggendo:
# per questo studio il file porta la scheda di OGNI chiave delle 8 corse, anche senza unita' di disaccordo.
# Nessun taglio silenzioso: ogni elenco tagliato scrive quante righe o quanti caratteri mancano. Le voci di
# `assignment` sono scritte tutte (in S12r5 un errore era passato perche' le schede erano tagliate).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
arg <- commandArgs(trailingOnly = TRUE); stopifnot(length(arg) == 2L, file.exists(arg[1]))
O <- readRDS(arg[1]); OUT <- arg[2]; dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
stopifnot(identical(O$sv$gse, sv$gse), !startsWith(normalizePath(OUT), normalizePath(".")))
S6 <- "analysis/audit/2026-11-14-S12r6-claude-via-api"
RUN <- O$RUN; MIS <- O$MIS
local({                                                        # solo le definizioni di funzione di S12r4
  e <- parse(file.path(S4, "25-materiale.R"), encoding = "UTF-8", keep.source = FALSE)
  vuoi <- c("car", "conta_v", "etichetta", "firma_testo", "corto")
  nomi <- vapply(e, function(x) if (is.call(x) && identical(x[[1]], as.name("<-")) && is.name(x[[2]])) as.character(x[[2]]) else "", "")
  stopifnot(all(vuoi %in% nomi)); for (x in e[nomi %in% vuoi]) eval(x, envir = globalenv())
})
TAGLI <- 0L                                                    # quante volte un testo e' stato tagliato (scritto in fondo)
tr <- function(x, n = 70L) { lungo <- !is.na(x) & nchar(x) > n; TAGLI <<- TAGLI + sum(lungo)
  ifelse(lungo, sprintf("%s…[tagliati %d caratteri]", substr(x, 1L, n), nchar(x) - n), x) }
righe <- function(x, max = 40L) { cat(utils::head(x, max), sep = "\n"); if (length(x) > max) { TAGLI <<- TAGLI + 1L; cat(sprintf("  … altre %d righe NON scritte\n", length(x) - max)) } }
r3 <- utils::read.csv("analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-disaccordi-M-righe.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
LEG <- utils::read.csv(file.path(S6, "24-da-leggere.csv"), stringsAsFactors = FALSE)

testa_studio <- function(g) {
  v <- viste[[g]]; x <- rif[[g]]; ta <- x$atlas$tabella
  cat(sprintf("################ %s (%s) campioni della vista %d, universo di Atlas %d\n", g, x$accession, length(car(v$campioni)), length(x$universo)))
  cat("TESTO DELLO STUDIO (quello che il modello riceve, fino alla tabella dei campioni):\n")
  cat(tr(sub("\nSAMPLE TABLE\n.*$", "", v$testo), 6000L), "\n")
  cat("VISTA colonne:\n")
  for (k in car(v$colonne)) cat(sprintf("  %s [%d distinti]: %s\n", k, length(unique(unlist(v$tabella[[k]]))), conta_v(unlist(v$tabella[[k]]), 14L)))
  cat("ATLAS fattori:", paste(sprintf("%s (%s; base «%s»)", ta$fattori$nome, ta$fattori$tipo, ta$fattori$base), collapse = "; "), "\n")
  ea <- etichetta(ta, x$universo); righe(sprintf("  A[%s] n=%d", tr(names(table(ea)), 260L), as.integer(table(ea))), 40L)
  ki <- MIS$T$mm[[g]]$intera$atlas; ka <- MIS$T$mm[[g]]$principale$atlas
  if (nrow(ki)) { ip <- match(ki$id, ka$id)
    righe(sprintf("  ATLAS confronto %s «%s» (%d/%d) classe=%s diversi=%s tempo_zero=%s solo_contesto=%s nel_denominatore=%s", ki$id, tr(ki$nome, 140L),
                  lengths(ki$trattato), lengths(ki$controllo), ka$classe[ip], ka$fattori_diversi[ip], ka$tempo_zero[ip], ka$solo_contesto[ip], ka$in_b[ip]), 60L) }
}
# La scheda di una lettura: M = misura_forma() della corsa, rec = la riga dell'uscita (NULL per Mistral).
scheda <- function(M, rec, inf, g, titolo) {
  v <- viste[[g]]; x <- rif[[g]]; r <- M$lett[[g]]; mp <- M$mm[[g]]$principale; t <- M$tab[M$tab$studio == g, ]
  cat(sprintf("\n=========== %s\nstato %s | ritrovati %d/%d | errori (c) %d/%d | predicato %s | fattori doppi %s | soggetto costante nei gruppi: %s\n",
              titolo, t$stato, t$n_b_uguale, t$n_b_den, t$n_errori, t$n_giudicabili, t$errore_di_lettura, t$fattori_doppi, t$soggetto_costante_nei_gruppi))
  if (!is.null(inf)) { i <- inf[inf$studio == g, ]
    if (nrow(i) && (nzchar(i$errore_api) || !i$stop_reason %in% "end_turn")) cat(sprintf("API: stop_reason «%s»; errore «%s»\n", i$stop_reason, tr(i$errore_api, 400L))) }
  if (length(r$motivi)) cat("motivi:", tr(paste(r$motivi, collapse = " || "), 2500L), "\n")
  if (length(r$note)) cat("note:", tr(paste(r$note, collapse = " || "), 1200L), "\n")
  kk <- r$canonico
  if (is.null(kk)) { cat("USCITA non valida o assente; inizio dell'uscita:", tr(as.character(nullo(rec$raw)), 8000L), "\n"); return(invisible()) }
  for (f in kk$factors) {
    lv <- livelli_canonico(v, f)
    cat(sprintf("FATTORE «%s» (%s; colonne: %s; base «%s»; prova «%s»)\n    livelli scritti: %s\n    campioni per livello: %s\n    voci (%d): %s\n",
                f$name, f$type, paste(fonti_f(f), collapse = " + "), f$baseline_level, tr(nullo(f$baseline_evidence), 500L),
                tr(paste(vapply(f$levels, function(l) sprintf("%s{%s%s%s}", l$level, nullo(l$entity), if (nzchar(nullo(l$dose))) paste0("; dose ", l$dose) else "",
                                                                if (nzchar(nullo(l$duration))) paste0("; durata ", l$duration) else ""), ""), collapse = " | "), 2500L),
                conta_v(lv, 30L), length(f$assignment),
                tr(paste(vapply(f$assignment, function(a) sprintf("[%s]→%s", paste(vapply(a$when, function(w) sprintf("%s=%s", w$column, tr(w$value, 60L)), ""), collapse = " & "), a$level), ""), collapse = "  "), 9000L)))
  }
  cat("ALTRE COLONNE:", tr(paste(vapply(kk$other_columns, function(z) sprintf("%s=%s%s%s", z$column, z$role, if (nzchar(nullo(z$subject_kind))) paste0("/", z$subject_kind) else "",
      if (length(z$missing_values)) sprintf(" [mancanti: %s]", paste(car(z$missing_values), collapse = "¦")) else ""), ""), collapse = "; "), 2500L), "\n")
  if (length(kk$not_understood)) cat("NON CAPITO:", tr(as.character(jsonlite::toJSON(kk$not_understood, auto_unbox = TRUE)), 1500L), "\n")
  ft <- firma_testo(v, kk); cat("FIRMA", substr(t$firma, 1L, 12L), "\n"); for (z in ft$fattori) cat("    ", corto(z), "\n"); if (length(ft$soggetti)) cat("     soggetti:", paste(ft$soggetti, collapse = "; "), "\n")
  if (r$chiuso) {
    uni <- x$universo; ea <- etichetta(x$atlas$tabella, uni); el <- etichetta(r$tabella, uni)
    cat(sprintf("GRUPPI Atlas × lettore (universo): gruppi del lettore %d, di Atlas %d, classe %s\n", t$n_gruppi_lettore, t$n_gruppi_atlas, t$classe_gruppi))
    tt <- as.data.frame(table(atlas = ea, lettore = el), stringsAsFactors = FALSE); tt <- tt[tt$Freq > 0L, ]; tt <- tt[order(tt$atlas, tt$lettore), ]
    righe(sprintf("  A[%s]  ×  L[%s]  n=%d", tr(tt$atlas, 260L), tr(tt$lettore, 320L), tt$Freq), 70L)
    kc <- r$confronti
    if (nrow(kc)) righe(sprintf("  LETTORE confronto %s %s: «%s» contro «%s» (%d/%d) %s", kc$id, kc$fattore, kc$livello_trattato, kc$livello_base, lengths(kc$trattato), lengths(kc$controllo), kc$esito), 60L)
    if (!is.null(r$registro) && nrow(r$registro)) cat("  REGISTRO coppie:", paste(sprintf("%s %d", names(table(r$registro$motivo)), as.integer(table(r$registro$motivo))), collapse = "; "), "\n")
    ne <- mp$non_elencati; if (!is.null(ne) && nrow(ne)) cat("  NON ELENCATI da Atlas:", paste(sprintf("%s=%s", ne$id, ne$giudizio), collapse = "; "), "\n")
  }
  ka <- mp$atlas; if (nrow(ka)) cat("  ATLAS esito:", paste(sprintf("%s=%s", ka$id[ka$in_b], ka$ritrovato[ka$in_b]), collapse = "; "), "\n")
  cat("UNITA':", if (nzchar(t$unita)) t$unita else "(nessuna)", "\n")
}

# Le schede: quelle di 24-da-leggere.csv, piu' ogni chiave delle 8 corse per GSE147507.
TUTTE <- do.call(rbind, lapply(names(RUN), function(k) data.frame(scheda = RUN[[k]]$kk$scheda, studio = sv$gse, corsa = k, forma = substr(k, 1L, 1L), stringsAsFactors = FALSE)))
SCH <- TUTTE[paste(TUTTE$scheda, TUTTE$corsa) %in% paste(LEG$scheda, LEG$corsa) | TUTTE$studio == "GSE147507", ]
stopifnot(all(paste(LEG$scheda, LEG$corsa) %in% paste(SCH$scheda, SCH$corsa)))
n_schede <- 0L
for (g in sort(unique(SCH$studio))) {
  sink(file.path(OUT, paste0(g, ".txt")))
  testa_studio(g)
  scheda(MIS$T, NULL, NULL, g, "BASE: Mistral-Small 3.2 nella forma B0 (terza prova, S12r3)")
  c3 <- r3[r3$studio == g, ]
  if (nrow(c3)) { cat("CAUSE SCRITTE IN S12r3 per Mistral B0 (punto di partenza, non esito):\n")
    for (i in seq_len(nrow(c3))) cat(sprintf("  %s %s: %s/%s. %s\n", c3$tipo[i], c3$id[i], c3$causa[i], c3$sotto[i], c3$differenza[i])) } else cat("CAUSE S12r3: nessuna unita' di disaccordo per Mistral B0 in questo studio.\n")
  s <- SCH[SCH$studio == g, ]
  for (h in sort(unique(s$scheda))) { d <- s[s$scheda == h, ]; k <- d$corsa[1]
    stopifnot(length(unique(d$forma)) >= 1L)
    scheda(RUN[[k]]$M, RUN[[k]]$X[[g]], RUN[[k]]$inf, g, sprintf("SCHEDA %s | forme: %s | %d corse su 8%s", h, paste(sort(unique(d$forma)), collapse = " e "), nrow(d),
                                                                  if (!any(paste(h, d$corsa) %in% paste(LEG$scheda, LEG$corsa))) " | SENZA unita' di disaccordo (solo per GSE147507)" else ""))
    n_schede <- n_schede + 1L }
  sink()
}
cat(sprintf("schede scritte: %d in %d file, cartella %s; testi tagliati: %d (ognuno scritto nel punto del taglio)\n", n_schede, length(unique(SCH$studio)), OUT, TAGLI))
