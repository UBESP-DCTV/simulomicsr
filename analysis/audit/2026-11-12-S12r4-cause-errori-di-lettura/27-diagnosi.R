# S12r4 — 27: gli errori nuovi per forma, la regola di diagnosi, la forma finale.
#
# Uso (dalla radice del repo, SENZA --vanilla):
#   Rscript analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/27-diagnosi.R <oggetti.rds di 24-misura.R> \
#     > analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/27-out.txt 2>&1
#
# Ingressi: gli oggetti di 24-misura.R (misure per corsa, confronto con la base, righe da leggere) e la lettura
# `26-letture.csv` (una riga per scheda e per base: causa, etichette degli errori di lettura presenti, descrizione)
# con `26-errori-nelle-basi.csv` (lo stato di ogni errore etichettato nelle due basi B0 e A0).
#
# Che cosa applica, senza cambiarlo: `00-previsioni.md` par. 3 (regola di diagnosi), par. 4 (errore nuovo),
# par. 6 (forma finale). Le previsioni 6, 7, 8 e 11 prendono qui il loro esito.
#
# Lo stato di un errore in una corsa:
#   - i 4 errori di lettura di S12r3: il predicato depositato (colonna `errore_di_lettura` della misura);
#   - ogni altro errore (le unita' di lettura di S12r2, gli errori nuovi): l'etichetta scritta nella lettura della
#     scheda di quello studio in quella corsa. Uno studio che in una corsa non e' fra le righe da leggere:
#       (a) ha la tabella dei fattori (firma) di una delle due basi: eredita lo stato di quella base;
#       (b) ha una firma gia' letta in un'altra corsa: porta le etichette di quella lettura;
#       (c) ha una firma mai letta e nessuna unita' di disaccordo: un errore che non costa confronti puo' esserci
#           lo stesso (per esempio una colonna con un ruolo sbagliato). Lo script NON scrive «assente» da solo:
#           elenca la cella in `27-celle-senza-unita.csv` e si ferma finche' `26-letture-senza-unita.csv`
#           (studio, firma, errore, descrizione) non la copre. Scelta dichiarata dopo i numeri, piu' severa della
#           regola depositata (che legge solo le coppie con almeno una unita').
#     Uscita non valida o oltre il contesto: non valutabile.

suppressPackageStartupMessages({ library(digest) })
arg <- commandArgs(trailingOnly = TRUE); stopifnot(length(arg) >= 1L, file.exists(arg[1]))
S4 <- "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura"
O <- readRDS(arg[1]); M <- O$M; CONF <- O$CONF; L <- O$L; sv <- O$sv
scrivi <- function(d, f) utils::write.csv(d, file.path(S4, f), row.names = FALSE, fileEncoding = "UTF-8")
leggi <- function(f) utils::read.csv(file.path(S4, f), stringsAsFactors = FALSE, encoding = "UTF-8", na.strings = character(0))
QUATTRO <- c("GSE57945", "GSE60340", "GSE49155", "GSE46665")
Q4 <- paste0(QUATTRO, ":", c("sesso come fattore", "colonna del trattamento non vista", "fattore doppio", "sigle dei pazienti come malattie"))
CORSE <- setdiff(names(M), c("B0-corsa2", "FIN-corsa2"))
CORSE_D <- setdiff(CORSE, "FIN")                                  # la forma finale nasce dalla diagnosi: non entra nella diagnosi
forma_di <- function(k) sub("-corsa2$", "", k)
LATO_A <- c("A0", "A0C", "A0A1", "A0A3", "A0A2", "A0A2A3", "A0A2A3A4", "A0A2A3A4R", "A0pl1", "A0pl2")
base_di <- function(k) if (forma_di(k) %in% LATO_A) "A0" else "B0"
CAUSE <- c("lettura del modello", "forma", "non errore")

# ---- 0. la lettura: completa e coerente --------------------------------------------------------------------------
LET <- leggi("26-letture.csv"); BAS <- leggi("26-errori-nelle-basi.csv")
stopifnot(all(c("scheda", "base", "studio", "firma", "causa", "errore", "descrizione") %in% names(LET)), all(LET$causa %in% CAUSE),
          !anyDuplicated(LET[c("scheda", "base")]), all(c("errore", "studio", "B0", "A0") %in% names(BAS)), !anyDuplicated(BAS$errore),
          all(unlist(BAS[c("B0", "A0")]) %in% c("presente", "assente", "non valutabile")))
chi <- paste(L$scheda, L$base); manca <- setdiff(chi, paste(LET$scheda, LET$base)); troppo <- setdiff(paste(LET$scheda, LET$base), chi)
cat(sprintf("righe da leggere %d, schede per base %d, lette %d; non lette %d; lette e non richieste %d\n", nrow(L), length(unique(chi)), nrow(LET), length(manca), length(troppo)))
if (length(manca)) { cat("NON LETTE:\n"); print(manca); stop("la lettura non copre tutte le schede") }
stopifnot(!length(troppo))
etichette <- function(x) { v <- trimws(strsplit(x, ";", fixed = TRUE)[[1]]); v[nzchar(v)] }
tutte <- sort(unique(unlist(lapply(LET$errore, etichette))))
# le etichette dei 4 errori di S12r3 si usano nella lettura (controllo del predicato), ma il loro stato viene dal predicato
stopifnot(all(tutte %in% c(BAS$errore, Q4)), !any(BAS$errore %in% Q4), all(sub(":.*$", "", BAS$errore) == BAS$studio))
# una etichetta vive in uno studio solo, e ogni scheda porta solo etichette del suo studio
stopifnot(all(vapply(seq_len(nrow(LET)), function(i) all(sub(":.*$", "", etichette(LET$errore[i])) == LET$studio[i]), NA)))
# coerenza: la stessa scheda (studio, firma, unita') porta le stesse etichette contro le due basi. La firma non vede il
# livello di base: due uscite con la stessa firma e basi diverse (base vuota, base che non e' un livello) hanno unita'
# diverse e possono portare etichette diverse. Per questo l'eredita' (b) passa per la scheda, non per la sola firma.
norm_et <- function(y) paste(sort(etichette(y)), collapse = ";")
cf <- tapply(LET$errore, LET$scheda, function(x) length(unique(vapply(x, norm_et, ""))))
if (any(cf > 1L)) { print(cf[cf > 1L]); stop("la stessa scheda ha etichette diverse contro le due basi") }
cf2 <- tapply(LET$errore, paste(LET$studio, LET$firma), function(x) length(unique(vapply(x, norm_et, ""))))
if (any(cf2 > 1L)) { cat("firme con etichette diverse in schede diverse (unita' diverse):\n"); print(cf2[cf2 > 1L]) }
# causa «lettura del modello» chiede almeno una etichetta; le altre cause non ne chiedono
stopifnot(all(nzchar(LET$errore[LET$causa == "lettura del modello"])))
F_SU <- file.path(S4, "26-letture-senza-unita.csv")
SU <- if (file.exists(F_SU)) leggi("26-letture-senza-unita.csv") else data.frame(studio = character(0), firma = character(0), errore = character(0), descrizione = character(0), stringsAsFactors = FALSE)
stopifnot(all(c("studio", "firma", "errore", "descrizione") %in% names(SU)), !anyDuplicated(SU[c("studio", "firma")]),
          !any(paste(SU$studio, SU$firma) %in% paste(LET$studio, LET$firma)),
          all(unlist(lapply(SU$errore, etichette)) %in% c(BAS$errore, Q4)),
          all(vapply(seq_len(nrow(SU)), function(i) all(sub(":.*$", "", etichette(SU$errore[i])) == SU$studio[i]), NA)))
L$causa <- LET$causa[match(chi, paste(LET$scheda, LET$base))]; L$errore <- LET$errore[match(chi, paste(LET$scheda, LET$base))]
# La lettura per corsa. La scheda (studio, firma, unita') non vede il livello di base ne' il motivo per cui lo studio non
# chiude: due corse con la stessa scheda possono avere cause diverse, e una corsa che eredita per firma puo' prendere una
# etichetta che per lei non vale. `26-letture-per-corsa.csv` porta la lettura di una coppia (corsa, studio) e prevale sulla
# scheda e su ogni eredita'. Le coppie vengono dai tre controlli meccanici 28-schede-condivise.py, 28-eredita.py e
# 28-fattori-celle.py (tutte le celle, non un campione).
F_PC <- file.path(S4, "26-letture-per-corsa.csv")
PC <- if (file.exists(F_PC)) leggi("26-letture-per-corsa.csv") else data.frame(corsa = character(0), studio = character(0), causa = character(0), errore = character(0), descrizione = character(0), stringsAsFactors = FALSE)
PC$errore <- as.character(PC$errore); PC$errore[is.na(PC$errore)] <- ""            # una colonna tutta vuota si legge come logica
stopifnot(all(c("corsa", "studio", "causa", "errore", "descrizione") %in% names(PC)), all(PC$causa %in% CAUSE), !anyDuplicated(PC[c("corsa", "studio")]),
          all(PC$corsa %in% CORSE), !any(PC$corsa %in% c("B0", "A0")), all(unlist(lapply(PC$errore, etichette)) %in% c(BAS$errore, Q4)),
          all(vapply(seq_len(nrow(PC)), function(i) all(sub(":.*$", "", etichette(PC$errore[i])) == PC$studio[i]), NA)),
          all(nzchar(PC$errore[PC$causa == "lettura del modello"])))
pc_l <- match(paste(L$corsa, L$studio), paste(PC$corsa, PC$studio))
cat(sprintf("letture per corsa %d; righe da leggere che prendono la lettura per corsa %d\n", nrow(PC), sum(!is.na(pc_l))))
L$causa[!is.na(pc_l)] <- PC$causa[pc_l[!is.na(pc_l)]]; L$errore[!is.na(pc_l)] <- PC$errore[pc_l[!is.na(pc_l)]]

# ---- 1. lo stato di ogni errore in ogni corsa --------------------------------------------------------------------
ERR <- rbind(data.frame(errore = Q4,
                        studio = QUATTRO, tipo = "predicato", stringsAsFactors = FALSE),
             data.frame(errore = BAS$errore, studio = BAS$studio, tipo = "etichetta", stringsAsFactors = FALSE))
stato_di <- function(e, k) {
  g <- ERR$studio[ERR$errore == e]; t <- M[[k]]$tab; i <- match(g, t$studio)
  if (ERR$tipo[ERR$errore == e] == "predicato") { p <- t$errore_di_lettura[i]; return(if (is.na(p)) "non valutabile" else if (p) "presente" else "assente") }
  if (!isTRUE(t$valida[i])) return("non valutabile")
  if (k %in% c("B0", "A0")) return(BAS[[k]][BAS$errore == e])
  p <- which(PC$corsa == k & PC$studio == g)                                         # la lettura per corsa prevale
  if (length(p)) return(if (e %in% etichette(PC$errore[p])) "presente" else "assente")
  r <- which(L$corsa == k & L$studio == g)
  if (length(r)) return(if (e %in% etichette(L$errore[r])) "presente" else "assente")
  for (b in unique(c(base_di(k), "B0", "A0"))) { o <- M[[b]]$tab                      # (a) la firma di una base
    if (isTRUE(o$valida[match(g, o$studio)]) && identical(t$firma[i], o$firma[match(g, o$studio)])) return(BAS[[b]][BAS$errore == e]) }
  f12 <- substr(t$firma[i], 1L, 12L)
  sc <- sprintf("%s|%s|%s", g, f12, substr(digest::digest(t$unita[i], algo = "sha256", serialize = FALSE), 1L, 8L))
  j <- which(LET$scheda == sc)                                                      # (b) una scheda gia' letta (firma e unita')
  if (!length(j)) { j <- which(LET$studio == g & LET$firma == f12)                  #     oppure una firma gia' letta, se non ambigua
    if (length(j) && length(unique(vapply(LET$errore[j], norm_et, ""))) > 1L) stop(sprintf("firma ambigua senza scheda: %s %s in %s", g, f12, k)) }
  if (length(j)) return(if (e %in% etichette(LET$errore[j[1]])) "presente" else "assente")
  stopifnot(!nzchar(t$unita[i]))                                                    # (c) firma mai letta: solo senza unita'
  j <- which(SU$studio == g & SU$firma == f12)
  MANCA_SU[[length(MANCA_SU) + 1L]] <<- data.frame(corsa = k, studio = g, firma = f12, letta = if (length(j)) "si" else "no", stringsAsFactors = FALSE)
  if (length(j)) return(if (e %in% etichette(SU$errore[j])) "presente" else "assente")
  "da leggere"
}
MANCA_SU <- list()
ST <- do.call(rbind, lapply(ERR$errore, function(e) data.frame(errore = e, studio = ERR$studio[ERR$errore == e], tipo = ERR$tipo[ERR$errore == e], corsa = CORSE,
  stato = vapply(CORSE, function(k) stato_di(e, k), ""), stato_dello_studio = vapply(CORSE, function(k) M[[k]]$tab$stato[match(ERR$studio[ERR$errore == e], M[[k]]$tab$studio)], ""),
  stringsAsFactors = FALSE, row.names = NULL)))
# Il file elenca TUTTE le celle del caso (c), lette e non lette: e' l'elenco della lettura supplementare.
ms <- if (length(MANCA_SU)) unique(do.call(rbind, MANCA_SU)) else data.frame(corsa = character(), studio = character(), firma = character(), letta = character())
ms <- ms[order(ms$studio, ms$firma, ms$corsa), ]; scrivi(ms, "27-celle-senza-unita.csv")
cat(sprintf("celle senza unita' e con una firma che la lettura dei disaccordi non copre, negli studi con un errore etichettato: %d celle, %d coppie (studio, firma), %d studi; non lette %d\n",
            nrow(ms), nrow(unique(ms[c("studio", "firma")])), length(unique(ms$studio)), sum(ms$letta == "no")))
if (any(ms$letta == "no")) { print(ms[ms$letta == "no", ], row.names = FALSE); stop("26-letture-senza-unita.csv non copre queste celle") }
stopifnot(nrow(merge(unique(ms[c("studio", "firma")]), SU[c("studio", "firma")])) == nrow(SU))   # nessuna lettura supplementare senza cella
cat(sprintf("letture senza unita' usate: %d coppie (studio, firma)\n", nrow(SU)))
scrivi(ST, "27-stati.csv")
S <- function(e, k) if (k %in% CORSE) ST$stato[ST$errore == e & ST$corsa == k] else NA_character_
# controllo dello strumento: nelle schede lette il predicato depositato e la lettura dicono la stessa cosa?
PL <- do.call(rbind, lapply(which(L$studio %in% QUATTRO), function(i) { e <- Q4[match(L$studio[i], QUATTRO)]
  data.frame(corsa = L$corsa[i], studio = L$studio[i], scheda = L$scheda[i], predicato = S(e, L$corsa[i]), lettura = if (e %in% etichette(L$errore[i])) "presente" else "assente", stringsAsFactors = FALSE) }))
if (!is.null(PL)) { PL$concordi <- PL$predicato == PL$lettura; scrivi(PL, "27-predicato-contro-lettura.csv")
  cat(sprintf("predicato contro lettura nei 4 studi: righe lette %d, concordi %d, discordi %d\n", nrow(PL), sum(PL$concordi), sum(!PL$concordi)))
  if (any(!PL$concordi)) print(PL[!PL$concordi, ], row.names = FALSE) }

# ---- 2. errori nuovi (par. 4) e previsione 11 --------------------------------------------------------------------
# Un errore nuovo: un peggioramento con causa «lettura del modello». L'etichetta nuova e' quella che la base della
# forma non ha.
P <- L[L$peggiorato, ]
P$etichette_nuove <- vapply(seq_len(nrow(P)), function(i) paste(Filter(function(e) S(e, P$base[i]) != "presente", etichette(P$errore[i])), collapse = ";"), "")
P$errore_nuovo <- P$causa == "lettura del modello"                    # alla lettera (par. 4): vale per la previsione 11 e per la forma finale
P$errore_nuovo_stretto <- P$errore_nuovo & nzchar(P$etichette_nuove)  # accanto, dichiarato dopo i numeri: con una etichetta che la base non ha
if (any(P$errore_nuovo & !P$errore_nuovo_stretto)) { cat("\npeggioramenti di lettura per un errore che la base ha gia' (effetto nuovo, errore non nuovo):\n")
  print(P[P$errore_nuovo & !P$errore_nuovo_stretto, c("corsa", "studio", "scheda", "errore")], row.names = FALSE) }
scrivi(P[c("corsa", "forma", "base", "studio", "scheda", "stato_base", "stato", "ritrovati_base", "ritrovati", "errori_base", "errori", "p1_stato", "p2_ritrovati", "p3_errori", "p4_predicato",
           "p5_generico", "p6_firma_e_unita", "causa", "errore", "etichette_nuove", "errore_nuovo", "errore_nuovo_stretto")], "27-peggioramenti.csv")
per_forma <- do.call(rbind, lapply(setdiff(CORSE, c("B0", "A0")), function(k) { d <- CONF[CONF$corsa == k, ]; p <- P[P$corsa == k, ]; b <- base_di(k)
  noti <- ERR$errore[vapply(ERR$errore, function(e) S(e, b) == "presente", NA)]
  data.frame(corsa = k, base = b, migliorati = sum(d$migliorato), peggiorati = sum(d$peggiorato), migliorati_e_peggiorati = sum(d$migliorato & d$peggiorato),
    peggiorati_lettura = sum(p$causa == "lettura del modello"), peggiorati_forma = sum(p$causa == "forma"), peggiorati_non_errore = sum(p$causa == "non errore"),
    studi_con_errore_nuovo = sum(p$errore_nuovo), studi_con_errore_nuovo_stretto = sum(p$errore_nuovo_stretto), errori_nuovi = paste(sort(unique(unlist(lapply(p$etichette_nuove[p$errore_nuovo_stretto], etichette)))), collapse = "; "),
    errori_di_lettura_nella_base = length(noti), errori_di_lettura_tolti = sum(vapply(noti, function(e) S(e, k) == "assente", NA)),
    tolti = paste(noti[vapply(noti, function(e) S(e, k) == "assente", NA)], collapse = "; "), stringsAsFactors = FALSE) }))
scrivi(per_forma, "27-per-forma.csv")
cat("\n== per forma: migliorati, peggiorati, errori nuovi di lettura, errori di lettura tolti ==\n")
print(per_forma[c("corsa", "base", "migliorati", "peggiorati", "peggiorati_lettura", "peggiorati_forma", "peggiorati_non_errore", "studi_con_errore_nuovo", "studi_con_errore_nuovo_stretto", "errori_di_lettura_nella_base", "errori_di_lettura_tolti")], row.names = FALSE)
UNDICI <- c("RP", "RPa", "RPb", "RPc", "RPd", "RP5", "RC", "RC3", "RA1", "RA4", "RR", "F1", "F2")
PREV <- list(); prev <- function(n, che, atteso, intervallo, osservato, esito, accanto = "") {
  PREV[[length(PREV) + 1L]] <<- data.frame(n = n, quantita = che, atteso = atteso, intervallo = intervallo, osservato = osservato, esito = esito, accanto = accanto, stringsAsFactors = FALSE)
  cat(sprintf("previsione %s  %s: osservato %s; atteso %s, intervallo %s  ->  %s%s\n", n, che, osservato, atteso, intervallo, esito, if (nzchar(accanto)) paste0("  [", accanto, "]") else "")) }
if (all(UNDICI %in% per_forma$corsa)) { v <- per_forma$studi_con_errore_nuovo[match(UNDICI, per_forma$corsa)]; me <- stats::median(v)
  cat("\n"); prev("11", "studi con un errore nuovo per forma a un cambio da B0: mediana fra 13 forme", "2", "0-5", format(me), if (me >= 0 && me <= 5) "confermata" else "smentita",
       paste0(paste(sprintf("%s %d", UNDICI, v), collapse = ", "), "; col conto stretto mediana ", format(stats::median(per_forma$studi_con_errore_nuovo_stretto[match(UNDICI, per_forma$corsa)])))) }

# ---- 3. la regola di diagnosi (par. 3) ---------------------------------------------------------------------------
# Coppie (forma senza D, forma con D). T: la forma che toglie solo D da B0, contro B0 (per A3: RA4A3 contro RA4).
# Mc: le coppie del lato A a un cambio da A0 e le coppie vicine della catena da A0 a B0 (01-carta.md par. 4).
cop <- function(senza, con, D, insieme) data.frame(senza = senza, con = con, D = D, insieme = insieme, stringsAsFactors = FALSE)
COPPIE <- rbind(
  cop(c("RP", "RPa", "RPb", "RPc", "RPd", "RP5", "RC", "RC3", "RA1", "RA4", "RR"), "B0", c("P", "Pa", "Pb", "Pc", "Pd", "P5", "C", "C3", "A1", "A4", "R"), "toglie"),
  cop("RA4A3", "RA4", "A3", "toglie"),
  cop(c("A0", "A0", "A0", "A0"), c("A0A2", "A0A3", "A0C", "A0A1"), c("A2", "A3", "C", "A1"), "mette"),
  cop(c("A0A2", "A0A2A3", "A0A2A3A4", "RA1PP5C", "RA1PP5", "RA1P", "RA1"), c("A0A2A3", "A0A2A3A4", "A0A2A3A4R", "RA1PP5", "RA1P", "RA1", "B0"),
      c("A3", "A4", "R", "C", "P5", "P", "A1"), "mette"))
PLACEBO <- list(B0 = c("B0pl1", "B0pl2"), A0 = c("A0pl1", "A0pl2"))
diagnosi <- function(e) {
  st <- vapply(CORSE_D, function(k) S(e, k), ""); conto <- table(factor(st, c("presente", "assente", "non valutabile")))
  c1 <- COPPIE; c1$s_senza <- st[c1$senza]; c1$s_con <- st[c1$con]
  c1$verso <- ifelse(c1$s_senza == "assente" & c1$s_con == "presente", "appare con D", ifelse(c1$s_senza == "presente" & c1$s_con == "assente", "sparisce con D",
              ifelse(c1$s_senza == "non valutabile" | c1$s_con == "non valutabile", "non valutabile", "")))
  mosse <- c1[c1$verso %in% c("appare con D", "sparisce con D"), ]
  chiave <- function(d) unique(paste(d$D, d$verso, sep = "|"))
  kt <- chiave(mosse[mosse$insieme == "toglie", ]); km <- chiave(mosse[mosse$insieme == "mette", ]); doppie <- intersect(kt, km); sole <- setdiff(union(kt, km), doppie)
  # sensibilita' dichiarata dopo i numeri: per A1 la coppia (RA1, B0) sta in tutti e due gli insiemi; la prova doppia
  # «su coppie diverse» chiede che la prova «mette» valga in una coppia che non e' quella della prova «toglie»
  indip <- vapply(doppie, function(x) { m <- mosse[paste(mosse$D, mosse$verso, sep = "|") == x, ]; a <- paste(m$senza, m$con)
    any(!(a[m$insieme == "mette"] %in% a[m$insieme == "toglie"])) }, NA)
  plac <- do.call(rbind, lapply(names(PLACEBO), function(b) data.frame(base = b, stato_base = st[b], pl1 = st[PLACEBO[[b]][1]], pl2 = st[PLACEBO[[b]][2]], stringsAsFactors = FALSE)))
  instabile <- any(plac$pl1 != plac$stato_base | plac$pl2 != plac$stato_base)
  instabile_dove_presente <- any((plac$pl1 != plac$stato_base | plac$pl2 != plac$stato_base) & plac$stato_base == "presente")
  val <- st[st != "non valutabile"]
  esito <- if (all(val == "presente") && st["B0"] == "presente" && st["A0"] == "presente") "del modello"
    else if (length(doppie) && !instabile_dove_presente) sprintf("della forma (%s)", paste(unique(sub("\\|.*$", "", doppie)), collapse = ", "))
    else if (instabile) "non deciso: instabile col placebo"
    else if (length(sole) == 1L) sprintf("non deciso: una direzione sola (%s)", sub("\\|.*$", "", sole))
    else if (length(sole) > 1L) sprintf("non deciso: più cambi, nessuna prova doppia (%s)", paste(unique(sub("\\|.*$", "", sole)), collapse = ", "))
    else if (any(c1$verso == "non valutabile")) "non deciso: non valutabile"
    else "non deciso: nessuna coppia a un cambio lo sposta"
  # Lettura severa, dichiarata dopo i numeri (non e' la regola depositata, si riporta accanto): la prova doppia vale solo
  # su coppie diverse, e lo stato non deve cambiare sotto nessuno dei quattro placebo (non solo quelli della base in cui
  # l'errore e' presente).
  doppie_s <- doppie[indip]; sole_s <- setdiff(union(kt, km), doppie_s)
  esito_severo <- if (all(val == "presente") && st["B0"] == "presente" && st["A0"] == "presente") "del modello"
    else if (length(doppie_s) && !instabile) sprintf("della forma (%s)", paste(unique(sub("\\|.*$", "", doppie_s)), collapse = ", "))
    else if (instabile) "non deciso: instabile col placebo"
    else if (length(sole_s) == 1L) sprintf("non deciso: una direzione sola (%s)", sub("\\|.*$", "", sole_s))
    else if (length(sole_s) > 1L) sprintf("non deciso: più cambi, nessuna prova doppia (%s)", paste(unique(sub("\\|.*$", "", sole_s)), collapse = ", "))
    else if (any(c1$verso == "non valutabile")) "non deciso: non valutabile"
    else "non deciso: nessuna coppia a un cambio lo sposta"
  data.frame(errore = e, studio = ERR$studio[ERR$errore == e], B0 = st["B0"], A0 = st["A0"], presente = conto[["presente"]], assente = conto[["assente"]], non_valutabile = conto[["non valutabile"]],
    presente_in = paste(names(st)[st == "presente"], collapse = " "), assente_in = paste(names(st)[st == "assente"], collapse = " "), non_valutabile_in = paste(names(st)[st == "non valutabile"], collapse = " "),
    prove_toglie = paste(kt, collapse = "; "), prove_mette = paste(km, collapse = "; "), prove_doppie = paste(doppie, collapse = "; "),
    prove_doppie_su_coppie_diverse = paste(doppie[indip], collapse = "; "),
    placebo = paste(sprintf("%s %s: pl1 %s, pl2 %s", plac$base, plac$stato_base, plac$pl1, plac$pl2), collapse = " | "),
    coppie_che_lo_spostano = paste(sprintf("%s>%s (%s, %s: %s)", mosse$senza, mosse$con, mosse$D, mosse$insieme, mosse$verso), collapse = "; "),
    esito = esito, esito_severo = esito_severo, stringsAsFactors = FALSE, row.names = NULL)
}
completo <- all(c(COPPIE$senza, COPPIE$con, unlist(PLACEBO)) %in% CORSE_D)
if (!completo) { cat("\nmancano corse della regola di diagnosi: la diagnosi non si calcola\n"); quit(status = 0L) }
DIA <- do.call(rbind, lapply(ERR$errore, diagnosi)); scrivi(DIA, "27-diagnosi.csv")
cat("\n== la regola di diagnosi, un esito per errore ==\n"); print(DIA[c("errore", "B0", "A0", "presente", "assente", "non_valutabile", "esito")], row.names = FALSE)
cat("\n== le prove ==\n"); for (i in seq_len(nrow(DIA))) cat(sprintf("%s\n  esito: %s\n  placebo: %s\n  toglie: %s\n  mette: %s\n  doppie: %s; su coppie diverse: %s\n  coppie: %s\n  assente in: %s\n  non valutabile in: %s\n",
  DIA$errore[i], DIA$esito[i], DIA$placebo[i], DIA$prove_toglie[i], DIA$prove_mette[i], DIA$prove_doppie[i], DIA$prove_doppie_su_coppie_diverse[i], DIA$coppie_che_lo_spostano[i], DIA$assente_in[i], DIA$non_valutabile_in[i]))
cat("\n== esiti: la regola alla lettera e la lettura severa (dichiarata dopo i numeri) ==\n")
cl <- function(x) sub(" \\(.*$", "", x); print(table(alla_lettera = cl(DIA$esito), severa = cl(DIA$esito_severo)))
cat("errori con esito diverso nelle due letture:\n"); print(DIA[DIA$esito != DIA$esito_severo, c("errore", "esito", "esito_severo")], row.names = FALSE)
e_di <- function(g) DIA$esito[DIA$studio == g & DIA$errore %in% ERR$errore[ERR$tipo == "predicato"]]
cat("\n")
prev("6", "GSE46665: esito della regola", "del modello", "-", e_di("GSE46665"), if (e_di("GSE46665") == "del modello") "confermata" else "smentita")
for (g in c("GSE60340", "GSE49155")) prev("7", sprintf("%s: esito della regola", g), "della forma (A1)", "-", e_di(g), if (e_di(g) == "della forma (A1)") "confermata" else "smentita")
n8 <- sum(grepl("^della forma", vapply(c("GSE57945", "GSE60340", "GSE49155"), e_di, "")))
prev("8", "i 3 errori assenti con la forma A: quanti hanno esito «della forma»", "2", "1-3", format(n8), if (n8 >= 1 && n8 <= 3) "confermata" else "smentita")
scrivi(do.call(rbind, PREV), "27-previsioni.csv")

# ---- 4. la forma finale (par. 6) ---------------------------------------------------------------------------------
TOGLIE_DA_B0 <- c(P = "RP", Pa = "RPa", Pb = "RPb", Pc = "RPc", Pd = "RPd", P5 = "RP5", C = "RC", C3 = "RC3", A1 = "RA1", A4 = "RA4", R = "RR")
cand <- unique(unlist(lapply(DIA$esito[grepl("^della forma", DIA$esito)], function(x) trimws(strsplit(sub("^della forma \\((.*)\\)$", "\\1", x), ",", fixed = TRUE)[[1]]))))
cat("\n== la forma finale ==\n")
cat("differenze con almeno un errore «della forma»:", if (length(cand)) paste(cand, collapse = ", ") else "nessuna", "\n")
entra <- character(0)
for (D in cand) { k <- TOGLIE_DA_B0[[D]]
  if (is.null(k)) { cat(sprintf("  %s: da B0 non si toglie con un cambio solo; non entra\n", D)); next }
  n <- per_forma$studi_con_errore_nuovo[per_forma$corsa == k]
  cat(sprintf("  %s: la forma %s ha %d studi con un errore nuovo di lettura -> %s\n", D, k, n, if (n == 0L) "entra" else "NON entra: conflitto, va al PI"))
  if (n == 0L) entra <- c(entra, D) }
t1 <- M$F1$tab[M$F1$tab$studio == "GSE50499", ]; t2 <- M$F2$tab[M$F2$tab$studio == "GSE63816", ]
for (f in c("F1", "F2")) { ch <- if (f == "F1") t1$chiuso else t2$chiuso; n <- per_forma$studi_con_errore_nuovo[per_forma$corsa == f]
  cat(sprintf("  %s: chiude il suo studio %s; studi con un errore nuovo di lettura %d -> %s\n", f, if (ch) "si'" else "no", n, if (ch && n == 0L) "entra" else "non entra"))
  if (ch && n == 0L) entra <- c(entra, f) }
cat("FORMA FINALE: B0", if (length(entra)) paste("con i cambi", paste(entra, collapse = ",")) else "senza cambi (coincide con B0: non servono altre corse)", "\n")
writeLines(paste(entra, collapse = ","), file.path(S4, "27-forma-finale-calcolata.txt"))
