# 30-misura-contro-gemma.R — la misura di una lettura contro il riferimento di Gemma (UBC).
# `source()` dopo devtools::load_all(".") e dopo aiuti-misura-r5.R (che legge SOLO i 47 studi di sviluppo).
#
# Il riferimento di una voce di Gemma e' la tabella dei fattori dell'adattatore depositato
# (analysis/audit/2026-11-15-gemma-riferimento/30-adattatore-gemma.R, regole 1-7 della sua carta, senza cambi):
#   gruppi     = la partizione dei campioni secondo i fattori di Gemma tenuti;
#   confronti  = quelli che il costruttore del pacchetto (tf_confronti, n_min = 2) forma dalla tabella di Gemma.
# La misura usa la stessa funzione delle prove sui 47 studi (tf_misura_studio), con la tabella di Gemma al posto
# di quella di Atlas:
#   lettura "principale": regola del fattore annidato, un fattore non scritto non conta come differenza;
#   campi_tempo = list(): la marca «tempo zero come controllo» non si calcola, perche' l'adattatore di Gemma non
#     da' una base ai fattori di tempo (regola 5): il riferimento non contiene per costruzione confronti con una
#     base di tempo. Un confronto del lettore con una base di tempo e' un «non elencato» e si giudica;
#   contesto_fuori = FALSE: l'adattatore non da' una base ai fattori di contesto (regola 5), quindi il riferimento
#     non contiene per costruzione confronti di solo contesto.
# Universo di una voce: i campioni di Gemma che stanno nella vista dello studio (regola 7: una voce che e' una
# parte di uno studio GEO si misura sui suoi campioni). I campioni di Gemma fuori dalla vista si contano.
source("analysis/audit/2026-11-15-gemma-riferimento/30-adattatore-gemma.R")   # G, GEMMA_DIR, gemma_leggi, gemma_tabella
LG <- "analysis/audit/2026-11-15-lettori-su-gemma"

rif_di_gemma <- function(studio, r) {
  stopifnot(isTRUE(r$chiuso))
  list(partizione = r$partizione, confronti = confronti_comuni(studio, r$confronti), tabella = r$tabella)
}

# Una voce di Gemma contro una lettura. `lett`: lista con chiuso, partizione, confronti (l'uscita di adatta_forma(),
# di gemma_tabella() o una lista fatta a mano). `campioni_vista`: i GSM della vista dello studio.
# Ritorna l'uscita di tf_misura_studio() con, nella riga: voce, chiuso, i gruppi dei due, i campioni fuori.
misura_contro_gemma <- function(voce, studio, r, lett, campioni_vista) {
  rg <- rif_di_gemma(studio, r)
  U <- sort(intersect(r$gsm, as.character(campioni_vista)), method = "radix")
  if (length(U) == 0L) stop("voce di Gemma senza campioni nella vista: ", voce)
  chiuso <- isTRUE(lett$chiuso)
  p <- if (chiuso) lett$partizione else character(0)
  k <- if (chiuso) confronti_comuni(studio, lett$confronti) else CONFRONTI_VUOTI(studio)
  t <- tf_misura_studio(voce, p, k, rg, U, lettura = "principale", campi_tempo = list(), contesto_fuori = FALSE)
  if (!chiuso) t$riga$classe_gruppi <- "non_chiuso"
  t$riga$gse <- studio; t$riga$chiuso <- chiuso
  t$riga$n_gemma <- length(r$gsm); t$riga$gemma_fuori_vista <- length(setdiff(r$gsm, campioni_vista))
  t$riga$vista_fuori_gemma <- length(setdiff(as.character(campioni_vista), r$gsm))
  t$riga$n_gruppi_gemma <- length(unique(r$partizione[names(r$partizione) %in% U]))
  t$riga$n_gruppi_lettore <- if (chiuso) length(unique(p[names(p) %in% U])) else 0L
  t
}

# Il riassunto di piu' voci. L'unita' del ricampionamento e' lo STUDIO GEO (`gse`): le voci di Gemma che sono
# parti dello stesso studio GEO si estraggono insieme. Quote = rapporti fra le somme.
#   a: voci con gruppi identici a Gemma su voci misurate; b: confronti di Gemma ritrovati (stessi due insiemi,
#   stesso verso) su confronti di Gemma nel riferimento; b_ogni_verso: ritrovati nel verso di Gemma o in quello
#   opposto; c: confronti del lettore non elencati da Gemma e giudicati errore (piu' fattori di Gemma cambiano, o un
#   braccio misto) su quelli giudicabili; chiusi: voci con una lettura chiusa.
QUOTE_GEMMA <- list(
  chiusi = function(d) c(sum(d$chiuso), nrow(d)),
  a_gruppi_identici = function(d) c(sum(d$classe_gruppi %in% "identica"), nrow(d)),
  a_piu_fine = function(d) c(sum(d$classe_gruppi %in% "piu_fine"), nrow(d)),
  a_piu_grossa = function(d) c(sum(d$classe_gruppi %in% "piu_grossa"), nrow(d)),
  a_incrociata = function(d) c(sum(d$classe_gruppi %in% "incrociata"), nrow(d)),
  b_confronti_ritrovati = function(d) c(sum(d$n_b_uguale), sum(d$n_b_den)),
  b_ogni_verso = function(d) c(sum(d$n_b_uguale + d$n_b_verso_opposto), sum(d$n_b_den)),
  c_errori_non_elencati = function(d) c(sum(d$n_errori), sum(d$n_giudicabili)))
estrazioni_per_studio <- function(gse, B, seme) {
  u <- unique(gse); righe <- split(seq_along(gse), factor(gse, levels = u))
  set.seed(seme)
  lapply(seq_len(B), function(b) unlist(righe[sample.int(length(u), length(u), replace = TRUE)], use.names = FALSE))
}
riassumi_gemma <- function(per, B, seme, estr = estrazioni_per_studio(per$gse, B, seme)) {
  q <- function(f, d) { x <- f(d); if (x[2] > 0) x[1] / x[2] else NA_real_ }
  do.call(rbind, lapply(names(QUOTE_GEMMA), function(n) {
    f <- QUOTE_GEMMA[[n]]; x <- f(per)
    v <- vapply(estr, function(i) q(f, per[i, , drop = FALSE]), 0)
    ic <- unname(stats::quantile(v, c(0.025, 0.975), na.rm = TRUE, names = FALSE))
    data.frame(misura = n, numeratore = x[1], denominatore = x[2], quota = q(f, per), ic_basso = ic[1], ic_alto = ic[2],
               ricampioni_senza_valore = sum(is.na(v)), stringsAsFactors = FALSE)
  }))
}
# Differenza appaiata fra due letture sulle stesse voci (X meno Y), stesse estrazioni per i due.
appaiato_gemma <- function(X, Y, B, seme, nomi = c("x", "y")) {
  stopifnot(identical(X$studio, Y$studio), identical(X$gse, Y$gse), identical(X$n_b_den, Y$n_b_den))
  estr <- estrazioni_per_studio(X$gse, B, seme)
  q <- function(f, d) { x <- f(d); if (x[2] > 0) x[1] / x[2] else NA_real_ }
  do.call(rbind, lapply(c("chiusi", "a_gruppi_identici", "b_confronti_ritrovati", "b_ogni_verso", "c_errori_non_elencati"), function(n) {
    f <- QUOTE_GEMMA[[n]]
    v <- vapply(estr, function(i) q(f, X[i, , drop = FALSE]) - q(f, Y[i, , drop = FALSE]), 0)
    ic <- unname(stats::quantile(v, c(0.025, 0.975), na.rm = TRUE, names = FALSE))
    d <- data.frame(misura = n, x = q(f, X), y = q(f, Y), differenza = q(f, X) - q(f, Y), ic_basso = ic[1], ic_alto = ic[2],
                    ricampioni_senza_valore = sum(is.na(v)), stringsAsFactors = FALSE)
    names(d)[2:3] <- nomi; d
  }))
}
riga_gemma <- function(m, nome) { r <- m[m$misura == nome, ]
  sprintf("%s: %d/%d = %.1f%% (IC95 %.1f-%.1f%%)", nome, as.integer(r$numeratore), as.integer(r$denominatore), 100 * r$quota, 100 * r$ic_basso, 100 * r$ic_alto) }

# Controllo positivo della misura: Gemma contro Gemma. Per ogni voce il riferimento letto come lettura deve dare
# gruppi identici, tutti i confronti del riferimento ritrovati nello stesso verso e nessun confronto non elencato.
# Ritorna le righe; chi chiama ferma la corsa se una voce non passa.
gemma_contro_gemma <- function(voce, studio, r) misura_contro_gemma(voce, studio, r, r, r$gsm)$riga
