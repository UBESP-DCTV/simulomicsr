# PROVA DA BUTTARE
# 24-misura.R — S12r4: i cancelli 1, 3, 4, 5; la misura di ogni forma con le misure di S12r3 (95 confronti, 97
# accanto); l'esito delle previsioni che non chiedono una lettura (1, 2, 3, 4, 5, 9, 10, 12); lo stato dei 4 errori
# di lettura in ogni forma; i peggioramenti (00-previsioni.md par. 4, criteri 1-6); l'elenco di quello che si legge
# (par. 5). Le previsioni 6, 7, 8, 11, la regola di diagnosi e la forma finale stanno in 27-diagnosi.R, dopo la
# lettura. Legge SOLO le uscite congelate delle corse (analysis/p4-output/S12r4-forme/<corsa>.jsonl) e solo i 47
# studi di sviluppo: gli 82 studi di giudizio restano chiusi.
#
#   [PARZIALE=1] [S12R4_OGGETTI=<file.rds fuori dal repo>] Rscript .../24-misura.R > .../24-out.txt 2>&1   (SENZA --vanilla)
# Senza PARZIALE=1 lo script si ferma se manca una delle 32 corse (31 forme + B0-corsa2; + 2 di FIN se la forma
# finale e' scritta in 30-forma-finale.txt e diversa da B0).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/aiuti-misura-r4.R")
ESITO <- TRUE
passa <- function(che, ok, dett = "") { cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else "")); if (!isTRUE(ok)) ESITO <<- FALSE }
PARZIALE <- nzchar(Sys.getenv("PARZIALE"))
forma_di <- function(corsa) sub("-corsa2$", "", corsa)
base_di <- function(nome) if (FORME[[nome]]$lato == "B") "B0" else "A0"
f_corsa <- function(corsa) file.path(USCITE_R4, paste0(corsa, ".jsonl"))
ATTESE <- c(names(FORME), "B0-corsa2", if ("FIN" %in% names(FORME)) "FIN-corsa2")
CI <- ATTESE[file.exists(f_corsa(ATTESE))]; MANCANO <- setdiff(ATTESE, CI)
cat(sprintf("24-misura.R  PROVA DA BUTTARE\nHEAD %s; corse attese %d, congelate %d%s\n", system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE),
            length(ATTESE), length(CI), if (length(MANCANO)) paste0("; MANCANO: ", paste(MANCANO, collapse = ", ")) else ""))
if (length(MANCANO) && !PARZIALE) stop("mancano corse: ", paste(MANCANO, collapse = ", "), call. = FALSE)
stopifnot(all(c("B0", "A0") %in% CI))

# ---- 0. le uscite congelate, le impronte, il registro del lancio (cancelli 4 e 5) -------------------------------
X <- stats::setNames(lapply(CI, function(k) leggi_uscite(f_corsa(k))), CI)      # leggi_uscite ferma se non sono i 47 di sviluppo
passa(sprintf("cancello 4: ogni corsa copre 47 studi di sviluppo su 47 e nessun altro (%d corse)", length(CI)), all(vapply(X, length, 0L) == 47L))
imp_ok <- vapply(CI, function(k) {
  f <- file.path(S4, "23-uscite-sha256", paste0(k, ".txt")); if (!file.exists(f)) return(FALSE)
  l <- readLines(f, warn = FALSE); r <- l[endsWith(l, f_corsa(k))]
  length(r) == 1L && identical(sub("  .*$", "", r), sha(f_corsa(k)))
}, NA)
passa("le uscite congelate hanno lo SHA-256 scritto al congelamento (23-uscite-sha256/)", all(imp_ok), paste(CI[!imp_ok], collapse = " "))
reg <- readLines(file.path(S4, "23-out.txt"), warn = FALSE)
amb <- do.call(rbind, lapply(CI, function(k) {
  mandati <- sum(!vapply(X[[k]], e_saltato, NA))
  a <- grep(sprintf("^%s: slurm [0-9]+ COMPLETED, durata [0-9:]+, nodo poddgx02; container-env.txt: VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1$", k), reg, value = TRUE)
  s <- regmatches(reg, regexec(sprintf("^%s: schema per record ([0-9]+)/([0-9]+) ", k), reg)); s <- s[lengths(s) == 3L]
  g <- grep(sprintf("^%s: forma %s .*generation.json: ", k, forma_di(k)), reg, value = TRUE)
  gen <- if (length(g) == 1L) tryCatch(jsonlite::fromJSON(sub("^.*generation.json: ", "", g), simplifyVector = FALSE), error = function(e) NULL) else NULL
  data.frame(corsa = k, nodo_e_ambiente = length(a) == 1L, mandati = mandati,
             schema_per_record = length(s) == 1L && identical(as.integer(s[[1]][2:3]), c(mandati, mandati)),
             configurazione = !is.null(gen) && identical(gen$model_id, "mistralai/Mistral-Small-3.2-24B-Instruct-2506") &&
               identical(gen$llm_extra$revision, "95a6d26c4bfb886c58daf9d3f7332c857cb27b43") && identical(as.numeric(gen$temperature), 0) &&
               identical(as.numeric(gen$repetition_penalty), 1.1) && identical(as.integer(gen$max_model_len), 65536L) && identical(as.integer(gen$max_tokens), 24576L),
             slurm = if (length(a) == 1L) sub("^.*slurm ([0-9]+) .*$", "\\1", a) else NA_character_, stringsAsFactors = FALSE)
}))
scrivi_r4(amb, "24-ambiente.csv")
passa("cancello 5: ogni job COMPLETED su poddgx02 con VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1 (23-out.txt)", all(amb$nodo_e_ambiente), paste(amb$corsa[!amb$nodo_e_ambiente], collapse = " "))
passa("cancello 5: modello, revisione, temperature 0, repetition_penalty 1,1, max_model_len 65536, max_tokens 24576", all(amb$configurazione), paste(amb$corsa[!amb$configurazione], collapse = " "))
passa("cancello 5: il lavoratore usa lo schema del record in ogni record mandato al modello", all(amb$schema_per_record), paste(amb$corsa[!amb$schema_per_record], collapse = " "))
cat(sprintf("studi mandati al modello: 47 in %d corse; meno di 47 in: %s\n", sum(amb$mandati == 47L),
            paste(sprintf("%s (%d)", amb$corsa[amb$mandati < 47L], amb$mandati[amb$mandati < 47L]), collapse = ", ")))

# ---- 1. la misura di ogni corsa -----------------------------------------------------------------------------------
t0 <- Sys.time()
M <- stats::setNames(lapply(CI, function(k) misura_forma(X[[k]], forma_di(k))), CI)
cat(sprintf("misura di %d corse: %.0f s\n", length(CI), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
TAB <- do.call(rbind, lapply(CI, function(k) cbind(corsa = k, M[[k]]$tab, stringsAsFactors = FALSE)))
UNI <- do.call(rbind, lapply(CI, function(k) if (nrow(M[[k]]$unita)) cbind(corsa = k, M[[k]]$unita, stringsAsFactors = FALSE) else NULL))
scrivi_r4(TAB, "24-per-studio.csv"); scrivi_r4(UNI, "24-unita.csv")

# ---- 2. cancello 1: la condizione di partenza si riproduce; cancello 3: il controllo positivo ---------------------
r3 <- leggi_uscite("analysis/p4-output/S12r3-lettore-v2/M-corsa1.jsonl")
u1 <- uguali_al_carattere(X$B0, r3)
passa("cancello 1: la prima corsa di B0 e' identica al carattere alle uscite congelate di S12r3, 47 studi su 47", all(u1), sprintf("%d/47; diversi: %s", sum(u1), paste(sv$gse[!u1], collapse = " ")))
nB <- tre_numeri(M$B0$tab); print(nB)
passa("cancello 1: B0 rida' 45 chiusi, 36 gruppi identici, 68 confronti su 95", identical(unname(nB[1:4]), c(45L, 36L, 68L, 95L)))
d3 <- utils::read.csv(file.path(R3, "26-disaccordi-M-righe.csv"), stringsAsFactors = FALSE, encoding = "UTF-8"); d3$id[is.na(d3$id)] <- ""
ch <- function(d) sort(paste(d$tipo, d$studio, d$id))
m13 <- d3[d3$causa == "modello", ]
passa("cancello 1: B0 rida' le 40 unita' di disaccordo di S12r3 e, fra quelle, le 13 di lettura del modello",
      nrow(M$B0$unita) == 40L && identical(ch(M$B0$unita), ch(d3)) && nrow(m13) == 13L && all(ch(m13) %in% ch(M$B0$unita)))
if ("B0-corsa2" %in% CI) { u2 <- uguali_al_carattere(X$B0, X[["B0-corsa2"]])
  passa("cancello 1: la seconda corsa di B0 e' identica alla prima, 47 studi su 47", all(u2), sprintf("%d/47; diversi: %s", sum(u2), paste(sv$gse[!u2], collapse = " "))) }
if (all(c("FIN", "FIN-corsa2") %in% CI)) { uf <- uguali_al_carattere(X$FIN, X[["FIN-corsa2"]])
  passa("cancello 1: le due corse della forma finale sono identiche, 47 studi su 47", all(uf), sprintf("%d/47; diversi: %s", sum(uf), paste(sv$gse[!uf], collapse = " "))) }
prB <- M$B0$tab$errore_di_lettura[match(QUATTRO, sv$gse)]
passa("cancello 3: i predicati vedono i 4 errori di lettura nella corsa nuova di B0", all(prB %in% TRUE), paste(QUATTRO[!(prB %in% TRUE)], collapse = " "))
scB <- M$B0$tab[M$B0$tab$studio %in% c("GSE50760", "GSE71595"), "soggetto_costante_nei_gruppi"]
passa("cancello 3: il conto dei soggetti costanti vede `source_name_ch1` in GSE50760 e GSE71595 nella corsa nuova di B0", identical(scB, rep("source_name_ch1", 2L)))

# ---- 3. ogni forma contro la sua base: numeri, differenze appaiate, firme, peggioramenti -------------------------
set.seed(SEME); ESTR <- matrix(sample.int(47L, 47L * B, replace = TRUE), nrow = B)
ic_somma <- function(x) { v <- rowSums(matrix(x[ESTR], nrow = B)); unname(stats::quantile(v, c(0.025, 0.975), names = FALSE)) }
GRADO <- c("non chiuso" = 0L, "diversa" = 1L, "identica" = 2L)
n_col <- function(x) ifelse(is.na(x), NA_integer_, ifelse(nzchar(x), lengths(strsplit(x, " | ", fixed = TRUE)), 0L))
chiavi <- function(k, g) { u <- M[[k]]$unita; sort(paste(u$tipo[u$studio == g], u$chiave[u$studio == g], sep = ":")) }
confronta <- function(k) {                                     # una riga per studio: la corsa k contro la sua base
  nome <- forma_di(k); b <- base_di(nome); t <- M[[k]]$tab; o <- M[[b]]$tab; stopifnot(identical(t$studio, o$studio))
  nv <- is.na(t$firma) & is.na(o$firma); firma_diversa <- !nv & (is.na(t$firma) | is.na(o$firma) | t$firma != o$firma)
  nuove <- vapply(sv$gse, function(g) length(setdiff(chiavi(k, g), chiavi(b, g))), 0L)
  tolte <- vapply(sv$gse, function(g) length(setdiff(chiavi(b, g), chiavi(k, g))), 0L)
  su <- function(a, z) !is.na(a) & !is.na(z) & a > z
  d <- data.frame(corsa = k, forma = nome, base = b, studio = t$studio, stato_base = o$stato, stato = t$stato,
    ritrovati_base = o$n_b_uguale, ritrovati = t$n_b_uguale, den = t$n_b_den, errori_base = o$n_errori, errori = t$n_errori,
    predicato_base = o$errore_di_lettura, predicato = t$errore_di_lettura, doppi_base = o$fattori_doppi, doppi = t$fattori_doppi,
    costanti_base = o$soggetto_costante_nei_gruppi, costanti = t$soggetto_costante_nei_gruppi,
    uscita_uguale = uguali_al_carattere(X[[k]], X[[b]]), firma_non_valutabile = nv, firma_diversa = firma_diversa, firma_base = o$firma, firma = t$firma,
    unita_base = o$unita, unita = t$unita, unita_nuove = nuove, unita_tolte = tolte,
    p1_stato = GRADO[t$stato] < GRADO[o$stato], p2_ritrovati = t$n_b_uguale < o$n_b_uguale, p3_errori = t$n_errori > o$n_errori,
    p4_predicato = (o$errore_di_lettura %in% FALSE) & (t$errore_di_lettura %in% TRUE),
    p5_generico = su(t$fattori_doppi, o$fattori_doppi) | su(n_col(t$soggetto_costante_nei_gruppi), n_col(o$soggetto_costante_nei_gruppi)),
    p6_firma_e_unita = firma_diversa & nuove > 0L,
    m1_stato = GRADO[t$stato] > GRADO[o$stato], m2_ritrovati = t$n_b_uguale > o$n_b_uguale, m3_errori = t$n_errori < o$n_errori,
    m4_predicato = (o$errore_di_lettura %in% TRUE) & (t$errore_di_lettura %in% FALSE),
    m5_generico = su(o$fattori_doppi, t$fattori_doppi) | su(n_col(o$soggetto_costante_nei_gruppi), n_col(t$soggetto_costante_nei_gruppi)),
    motivi = t$motivi, fine = t$fine, stringsAsFactors = FALSE, row.names = NULL)
  d$peggiorato <- d$p1_stato | d$p2_ritrovati | d$p3_errori | d$p4_predicato | d$p5_generico | d$p6_firma_e_unita
  d$migliorato <- d$m1_stato | d$m2_ritrovati | d$m3_errori | d$m4_predicato | d$m5_generico
  d
}
CONF <- do.call(rbind, lapply(setdiff(CI, c("B0", "A0")), confronta))
if (is.null(CONF)) { cat("solo le basi: niente da confrontare\n"); quit(status = if (ESITO) 0L else 1L) }
scrivi_r4(CONF, "24-contro-la-base.csv")
riga_forma <- function(k) {
  nome <- forma_di(k); t <- M[[k]]$tab; n <- tre_numeri(t); b <- base_di(nome); o <- M[[b]]$tab
  d <- if (k %in% CONF$corsa) CONF[CONF$corsa == k, ] else NULL
  dr <- t$n_b_uguale - o$n_b_uguale; dc <- as.integer(t$chiuso) - as.integer(o$chiuso); di <- as.integer(t$stato == "identica") - as.integer(o$stato == "identica")
  pr <- t$errore_di_lettura[match(QUATTRO, t$studio)]
  data.frame(corsa = k, lato = FORME[[nome]]$lato, cambi = paste(FORME[[nome]]$cambi, collapse = "+"), base = b,
    oltre_contesto = sum(vapply(X[[k]], e_saltato, NA)), fine_length = sum(t$fine %in% "length"), valide = sum(t$valida),
    chiusi = n[["chiusi"]], identici = n[["identici"]], ritrovati = n[["ritrovati"]], den = n[["den"]], ritrovati97 = n[["ritrovati97"]], den97 = n[["den97"]],
    errori_c = n[["errori_c"]], giudicabili_c = n[["giudicabili_c"]], unita = sum(t$n_unita),
    d_chiusi = sum(dc), d_chiusi_ic = paste(ic_somma(dc), collapse = " "), d_identici = sum(di), d_identici_ic = paste(ic_somma(di), collapse = " "),
    d_ritrovati = sum(dr), d_ritrovati_ic = paste(ic_somma(dr), collapse = " "),
    uscite_uguali_alla_base = if (is.null(d)) NA_integer_ else sum(d$uscita_uguale),
    firme_diverse = if (is.null(d)) NA_integer_ else sum(d$firma_diversa), firme_non_valutabili = if (is.null(d)) NA_integer_ else sum(d$firma_non_valutabile),
    migliorati = if (is.null(d)) NA_integer_ else sum(d$migliorato & !d$peggiorato), peggiorati = if (is.null(d)) NA_integer_ else sum(d$peggiorato & !d$migliorato),
    migliorati_e_peggiorati = if (is.null(d)) NA_integer_ else sum(d$peggiorato & d$migliorato),
    GSE57945 = pr[1], GSE60340 = pr[2], GSE49155 = pr[3], GSE46665 = pr[4],
    fattori_doppi = sum(t$fattori_doppi, na.rm = TRUE), studi_con_soggetto_costante = sum(n_col(t$soggetto_costante_nei_gruppi) > 0L, na.rm = TRUE),
    stringsAsFactors = FALSE)
}
RIA <- do.call(rbind, lapply(CI, riga_forma)); scrivi_r4(RIA, "24-forme.csv")
cat("\n== ogni corsa: numeri e differenze dalla base (riferimento a 95 confronti; 97 accanto) ==\n")
print(RIA[c("corsa", "base", "oltre_contesto", "fine_length", "valide", "chiusi", "identici", "ritrovati", "ritrovati97", "errori_c", "giudicabili_c", "unita", "d_ritrovati", "d_ritrovati_ic",
            "uscite_uguali_alla_base", "firme_diverse", "migliorati", "peggiorati", "migliorati_e_peggiorati")], row.names = FALSE)
cat("\n== i 4 errori di lettura (predicati) e i conti generici, per corsa ==\n")
print(RIA[c("corsa", "cambi", QUATTRO, "fattori_doppi", "studi_con_soggetto_costante")], row.names = FALSE)
stato_err <- function(x) ifelse(is.na(x), "non valutabile", ifelse(x, "presente", "assente"))
STATI <- do.call(rbind, lapply(CI, function(k) data.frame(corsa = k, forma = forma_di(k), errore = QUATTRO,
  stato = stato_err(M[[k]]$tab$errore_di_lettura[match(QUATTRO, sv$gse)]), stato_dello_studio = M[[k]]$tab$stato[match(QUATTRO, sv$gse)], stringsAsFactors = FALSE)))
scrivi_r4(STATI, "24-stati-dei-4-errori.csv")
# esplorativo, non previsto: i due studi delle 5 unita' di lettura di S12r2
cat("\n== esplorativo: GSE57116 e GSE75852 (le 5 unita' di lettura di S12r2), per corsa ==\n")
print(TAB[TAB$studio %in% c("GSE57116", "GSE75852"), c("corsa", "studio", "stato", "n_b_uguale", "n_b_den", "n_fattori", "fattori_doppi", "fonti", "motivi")], row.names = FALSE)

# ---- 4. le previsioni che non chiedono una lettura ---------------------------------------------------------------
PREV <- list()
prev <- function(n, che, atteso, intervallo, osservato, esito, accanto = "") {
  PREV[[length(PREV) + 1L]] <<- data.frame(n = n, quantita = che, atteso = atteso, intervallo = intervallo, osservato = osservato, esito = esito, accanto = accanto, stringsAsFactors = FALSE)
  cat(sprintf("previsione %s  %s: osservato %s; atteso %s, intervallo %s  ->  %s%s\n", n, che, osservato, atteso, intervallo, esito, if (nzchar(accanto)) paste0("  [", accanto, "]") else ""))
}
dentro <- function(x, a, z) if (x >= a && x <= z) "confermata" else "smentita"
cat("\n== previsioni ==\n")
r2 <- leggi_uscite("analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl")
ua <- uguali_al_carattere(X$A0, r2)
prev("1", "A0 identica al carattere a M-corsa1.jsonl di S12r2", "47/47", "47", sprintf("%d/47", sum(ua)), dentro(sum(ua), 47, 47), paste("diversi:", paste(sv$gse[!ua], collapse = " ")))
nA <- tre_numeri(M$A0$tab)
cat(sprintf("  A0 di S12r4: %d chiusi, %d identici, %d/%d, %d/%d (S12r2: 34, 31, 50/95, 50/97)\n", nA[["chiusi"]], nA[["identici"]], nA[["ritrovati"]], nA[["den"]], nA[["ritrovati97"]], nA[["den97"]]))
# previsione 2: il blocco `factors` di RC3 contro B0. Due letture: i caratteri dell'uscita fino al campo che segue
# `factors` (decide), e il blocco letto come JSON (accanto).
blocco <- function(raw) {
  if (is.na(raw) || !nzchar(raw)) return(list(testo = NA_character_, json = NULL))
  u <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  dopo <- if (!is.null(u) && length(names(u)) >= 3L && identical(names(u)[2], "factors")) names(u)[3] else NA_character_
  p <- if (is.na(dopo)) -1L else regexpr(sprintf("\"%s\"[ \t\r\n]*:", dopo), raw)
  list(testo = if (p > 0L) substr(raw, 1L, p - 1L) else NA_character_, json = if (is.null(u)) NULL else u$factors)
}
if ("RC3" %in% CI) {
  bl <- lapply(c(B0 = "B0", RC3 = "RC3"), function(k) lapply(sv$gse, function(g) blocco(as.character(nullo(X[[k]][[g]]$raw)))))
  car <- vapply(seq_along(sv$gse), function(i) !is.na(bl$B0[[i]]$testo) && identical(bl$B0[[i]]$testo, bl$RC3[[i]]$testo), NA)
  js <- vapply(seq_along(sv$gse), function(i) !is.null(bl$B0[[i]]$json) && identical(bl$B0[[i]]$json, bl$RC3[[i]]$json), NA)
  prev("2", "RC3: blocco `factors` identico a quello di B0 (al carattere)", "47/47", "47", sprintf("%d/47", sum(car)), dentro(sum(car), 47, 47),
       sprintf("letto come JSON: %d/47; diversi: %s", sum(js), paste(sv$gse[!car], collapse = " ")))
}
if (all(c("A0A2A3A4R", "RA1PP5C") %in% CI)) { up <- uguali_al_carattere(X$A0A2A3A4R, X$RA1PP5C)
  prev("3", "il ponte: A0A2A3A4R identica al carattere a RA1PP5C", "47/47", "47", sprintf("%d/47", sum(up)), dentro(sum(up), 47, 47), paste("diversi:", paste(sv$gse[!up], collapse = " "))) }
for (k in intersect(c("B0pl1", "B0pl2", "A0pl1", "A0pl2"), CI)) { d <- CONF[CONF$corsa == k, ]
  prev("4", sprintf("%s: studi con la firma diversa dalla base", k), "5/47", "0-12", sprintf("%d/47", sum(d$firma_diversa)), dentro(sum(d$firma_diversa), 0, 12),
       sprintf("ricampionamento sugli studi, IC 95%%: %s; uscite uguali al carattere %d/47; firme non valutabili %d; migliorati %d, peggiorati %d", paste(ic_somma(as.integer(d$firma_diversa)), collapse = "-"),
               sum(d$uscita_uguale), sum(d$firma_non_valutabile), sum(d$migliorato), sum(d$peggiorato))) }
if (all(c("B0pl1", "B0pl2") %in% CI)) { s8 <- STATI[STATI$corsa %in% c("B0pl1", "B0pl2"), ]
  prev("5", "i 4 errori di lettura sotto i due placebo di B0 (8 stati)", "8 presenti", "7-8", sprintf("%d presenti, %d assenti, %d non valutabili", sum(s8$stato == "presente"), sum(s8$stato == "assente"), sum(s8$stato == "non valutabile")),
       dentro(sum(s8$stato == "presente"), 7, 8), paste(sprintf("%s in %s: %s", s8$errore, s8$corsa, s8$stato)[s8$stato != "presente"], collapse = "; ")) }
tre_esiti <- function(ic, a, z) if (ic[1] >= a && ic[2] <= z) "confermata" else if (ic[2] < a || ic[1] > z) "smentita" else "indeterminata"
if ("F12" %in% CI) { t <- M$F12$tab; o <- M$B0$tab; dr <- t$n_b_uguale - o$n_b_uguale; icc <- ic_somma(as.integer(t$chiuso)); icr <- ic_somma(dr)
  prev("9a", "F12: studi chiusi", "47", "46-47", sprintf("%d (IC 95%% %s)", sum(t$chiuso), paste(icc, collapse = "-")), tre_esiti(icc, 46, 47), paste("non chiusi:", paste(t$studio[!t$chiuso], collapse = " ")))
  prev("9b", "F12: confronti ritrovati meno quelli di B0", "+3 (71/95)", "0 - +6", sprintf("%+d (%d/95; IC 95%% %s)", sum(dr), sum(t$n_b_uguale), paste(icr, collapse = " ")), tre_esiti(icr, 0, 6)) }
if ("F1" %in% CI) { s <- M$F1$tab[M$F1$tab$studio == "GSE50499", ]; prev("10a", "F1 chiude GSE50499", "si'", "-", sprintf("%s (%s)", if (s$chiuso) "si'" else "no", s$stato), if (s$chiuso) "confermata" else "smentita", s$motivi) }
if ("F2" %in% CI) { s <- M$F2$tab[M$F2$tab$studio == "GSE63816", ]; prev("10b", "F2 chiude GSE63816", "si'", "-", sprintf("%s (%s)", if (s$chiuso) "si'" else "no", s$stato), if (s$chiuso) "confermata" else "smentita", s$motivi) }
if ("RA4" %in% CI) { t <- M$RA4$tab
  prev("12", "RA4 (senza la tupla dei valori): studi chiusi", "39", "35-43", sprintf("%d", sum(t$chiuso)), dentro(sum(t$chiuso), 35, 43),
       sprintf("ricampionamento sugli studi, IC 95%%: %s; motivi dei non chiusi: %s", paste(ic_somma(as.integer(t$chiuso)), collapse = "-"),
               paste(sprintf("%s %d", names(table(unlist(strsplit(t$motivi[!t$chiuso], " | ", fixed = TRUE)))), as.integer(table(unlist(strsplit(t$motivi[!t$chiuso], " | ", fixed = TRUE))))), collapse = ", "))) }
scrivi_r4(do.call(rbind, PREV), "24-previsioni.csv")

# ---- 5. che cosa si legge (00-previsioni.md par. 5) --------------------------------------------------------------
# Ogni coppia (studio, firma) in ogni corsa che ha almeno una unita' di disaccordo e in cui le unita' o la firma sono
# diverse dalla base. Una scheda = (studio, firma, unita'): la stessa scheda in piu' corse si legge una volta.
# In piu', anche senza unita': ogni peggioramento (par. 4) si legge.
L <- CONF[!(CONF$corsa %in% c("B0-corsa2", "FIN-corsa2")), ]
L$con_unita_che_cambiano <- nzchar(L$unita) & (L$unita != L$unita_base | L$firma_diversa)
L <- L[L$con_unita_che_cambiano | L$peggiorato, ]
if (!nrow(L)) { cat("niente da leggere\n"); quit(status = if (ESITO) 0L else 1L) }
L$scheda <- sprintf("%s|%s|%s", L$studio, ifelse(is.na(L$firma), "NA", substr(L$firma, 1L, 12L)), substr(vapply(L$unita, digest::digest, "", algo = "sha256", serialize = FALSE), 1L, 8L))
SCH <- do.call(rbind, lapply(split(L, L$scheda), function(d) data.frame(scheda = d$scheda[1], studio = d$studio[1], firma = substr(d$firma[1], 1L, 12L),
  lati = paste(sort(unique(d$base)), collapse = "+"), n_corse = nrow(d), corse = paste(d$corsa, collapse = " "), prima_corsa = d$corsa[1],
  stato = paste(unique(d$stato), collapse = "/"), peggiorato_in = sum(d$peggiorato), unita = d$unita[1], stringsAsFactors = FALSE)))
SCH <- SCH[order(SCH$studio, SCH$scheda), ]; rownames(SCH) <- NULL
scrivi_r4(L[c("corsa", "forma", "base", "studio", "scheda", "stato_base", "stato", "ritrovati_base", "ritrovati", "errori_base", "errori", "predicato_base", "predicato", "firma_diversa",
              "unita_nuove", "unita_tolte", "con_unita_che_cambiano", "peggiorato", "migliorato", "p1_stato", "p2_ritrovati", "p3_errori", "p4_predicato", "p5_generico", "p6_firma_e_unita", "motivi", "unita")],
          "24-da-leggere-righe.csv")
scrivi_r4(SCH, "24-da-leggere-schede.csv")
cat(sprintf("\n== da leggere: %d righe (corsa, studio) in %d schede distinte (studio, firma, unita'), in %d studi; righe con un peggioramento: %d ==\n",
            nrow(L), nrow(SCH), length(unique(SCH$studio)), sum(L$peggiorato)))
print(as.data.frame(table(studio = SCH$studio), responseName = "schede"), row.names = FALSE)

f_ogg <- Sys.getenv("S12R4_OGGETTI", "")
if (nzchar(f_ogg)) { saveRDS(list(sv = sv, rif = rif, viste = viste, X = X, M = M, CONF = CONF, SCH = SCH, L = L), f_ogg); cat("oggetti salvati in", f_ogg, "\n") }
cat(if (ESITO) "\nCANCELLI: PASSANO\n" else "\nCANCELLI: UNO O PIU' FALLISCONO\n")
if (!ESITO) quit(status = 1L)
