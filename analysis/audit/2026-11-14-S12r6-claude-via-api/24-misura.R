# PROVA DA BUTTARE
# 24-misura.R — S12r6 (il lettore dello studio con i modelli Claude via API, sola misura): i cancelli K1, K3, K4 di
# 00-previsioni.md; la misura di ogni corsa congelata (misura_forma() di S12r4, riferimento a 95 confronti) con
# l'adattatore B0 per la forma T (schema B0 come testo) e A0 per la forma V (schema v1 vincolato); token e spesa;
# i confronti appaiati con Mistral-Small 3.2 nella stessa forma e con la pipeline di oggi; la ripetibilita' fra le
# due corse; lo stato dei 9 errori di lettura di B0; l'esito delle previsioni che non chiedono una lettura;
# l'elenco delle schede da leggere. Legge SOLO le corse scritte in 23-uscite-sha256.txt e solo i 47 studi di
# sviluppo: gli 82 studi di giudizio restano chiusi.
#
#   [S12R6_OGGETTI=<file.rds fuori dal repo>] Rscript .../24-misura.R > .../24-out.txt 2>&1        (SENZA --vanilla)
#
# PROVA A SECCO e cancello K2 (prima delle corse): PROVA=<cartella fuori dal repo scritta da 22-controllo-positivo.py>
# misura le uscite congelate di Mistral nel formato del programma di lancio e scrive solo in quella cartella.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
SEME <- 20261114L                                             # depositato in 00-previsioni.md (la data della sessione)
S6 <- "analysis/audit/2026-11-14-S12r6-claude-via-api"
ESITO <- TRUE
passa <- function(che, ok, dett = "") { cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else "")); if (!isTRUE(ok)) ESITO <<- FALSE }
PROVA <- Sys.getenv("PROVA"); SECCO <- nzchar(PROVA)
if (SECCO) { stopifnot(dir.exists(PROVA), !startsWith(normalizePath(PROVA), normalizePath("."))); cat("PROVA A SECCO sulle uscite congelate di Mistral: NON e' un risultato di S12r6\n") }
DIR_OUT <- if (SECCO) PROVA else S6
scrivi <- function(d, f) utils::write.csv(d, file.path(DIR_OUT, f), row.names = FALSE, na = "")
ADAT <- c(T = "B0", V = "A0"); ORD <- c("haiku", "sonnet", "opus", "fable")
ID_API <- c(haiku = "claude-haiku-5-5", sonnet = "claude-sonnet-5-5", opus = "claude-opus-5-5", fable = "claude-fable-5-1", mistral = "mistral", mistralrotto = "mistral")
PREZZI <- list(haiku = c(0.10, 0.50), sonnet = c(2, 10), opus = c(4, 20), fable = c(10, 50)); HAIKU_SOPRA_100K <- c(0.50, 2.50)   # dollari per milione di token, ingresso e uscita
ch <- function(x) if (is.null(x) || length(x) == 0L || is.na(x[[1]])) NA_character_ else as.character(x[[1]])
nm <- function(x) if (is.null(x) || length(x) == 0L) NA_real_ else as.numeric(x[[1]])
impv <- function(x) vapply(x, imp, "", USE.NAMES = FALSE)             # imp() di S12r5 non e' vettoriale: un'impronta per elemento
cat(sprintf("24-misura.R  PROVA DA BUTTARE\nHEAD %s; seme %d, B %d\n", system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), SEME, B))

# ---- 1. K1: riproduzione prima del cambio (uscite congelate di Mistral-Small 3.2, pipeline di oggi) ---------------
F_MIS <- c(T = "analysis/p4-output/S12r5-letture/B0.jsonl", V = "analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl")
MIS <- lapply(c(T = "T", V = "V"), function(f) misura_forma(leggi_uscite(F_MIS[[f]]), ADAT[[f]]))
sei <- function(tab) unname(as.integer(tre_numeri(tab)[c("chiusi", "identici", "ritrovati", "den", "errori_c", "giudicabili_c")]))
passa("K1: Mistral-Small 3.2 nella forma B0 rida' 45 chiusi, 36/47, 68/95, 2/33", identical(sei(MIS$T$tab), c(45L, 36L, 68L, 95L, 2L, 33L)), paste(sei(MIS$T$tab), collapse = " "))
passa("K1: Mistral-Small 3.2 con lo schema v1 rida' 34 chiusi, 31/47, 50/95, 0/4", identical(sei(MIS$V$tab), c(34L, 31L, 50L, 95L, 0L, 4L)), paste(sei(MIS$V$tab), collapse = " "))
og <- utils::read.csv(file.path(R3, "15-per-studio-oggi.csv"), stringsAsFactors = FALSE); og <- og[og$misura_r3 == "principale", ]; og <- og[match(sv$gse, og$studio), ]
stopifnot(!anyNA(og$studio)); og$contesto_fuori <- as.logical(og$contesto_fuori)
n_og <- c(sum(og$classe_gruppi %in% "identica"), sum(og$n_b_uguale), sum(og$n_b_den), sum(og$n_errori), sum(og$n_giudicabili))
passa("K1: la pipeline di oggi rida' 14/47, 13/95, 18/79", identical(as.integer(n_og), c(14L, 13L, 95L, 18L, 79L)), paste(n_og, collapse = " "))
st_mis <- stato_errori(MIS$T$tab)
passa("controllo positivo dei predicati: vedono i 9 errori di lettura di B0 nelle uscite di Mistral", all(st_mis %in% TRUE), sprintf("%d su 9", sum(st_mis %in% TRUE)))

# ---- 2. K4: gli ingressi ------------------------------------------------------------------------------------------
ingT <- leggi_jsonl("analysis/input/S12r3-lettore-v2-ingresso.jsonl"); names(ingT) <- vapply(ingT, `[[`, "", "record_id")
ingV <- leggi_jsonl("analysis/input/S12r2-lettore-v1-ingresso.jsonl"); names(ingV) <- vapply(ingV, `[[`, "", "record_id")
sch_ok <- vapply(sv$gse, function(g) identical(jsonlite::fromJSON(schema_json_forma(viste[[g]], "B0"), simplifyVector = FALSE), ingT[[g]]$schema), NA)
passa("K4: i 47 schemi dati come testo (forma T) sono quelli contro cui l'adattatore B0 valida", all(sch_ok), sprintf("%d/47", sum(sch_ok)))
tx_ok <- vapply(sv$gse, function(g) identical(ingT[[g]]$testo, ingV[[g]]$testo), NA)
passa("il testo dello studio e' lo stesso nelle due forme, 47 studi su 47", all(tx_ok), sprintf("%d/47", sum(tx_ok)))

# ---- 3. le corse congelate (K3, K4) -------------------------------------------------------------------------------
reg <- utils::read.table(file.path(DIR_OUT, "23-uscite-sha256.txt"), col.names = c("sha", "file"), colClasses = "character", stringsAsFactors = FALSE)
reg$nome <- sub("\\.jsonl$", "", basename(reg$file))
pz <- regmatches(reg$nome, regexec("^([TV])-([a-z]+)-corsa([12])$", reg$nome)); stopifnot(all(lengths(pz) == 4L), !anyDuplicated(reg$nome))
reg$forma <- vapply(pz, `[`, "", 2L); reg$modello <- vapply(pz, `[`, "", 3L); reg$corsa <- as.integer(vapply(pz, `[`, "", 4L))
reg <- reg[order(match(reg$forma, c("T", "V")), match(reg$modello, c(ORD, "mistral", "mistralrotto")), reg$corsa), ]; rownames(reg) <- NULL
sha_ok <- vapply(seq_len(nrow(reg)), function(i) file.exists(reg$file[i]) && identical(sha(reg$file[i]), reg$sha[i]), NA)
passa(sprintf("K4: le %d corse hanno lo SHA-256 scritto al congelamento (23-uscite-sha256.txt)", nrow(reg)), all(sha_ok), paste(reg$nome[!sha_ok], collapse = " "))
una_corsa <- function(i) {
  X <- leggi_uscite(reg$file[i]); f <- reg$forma[i]; mod <- reg$modello[i]         # leggi_uscite ferma se non sono i 47 di sviluppo (K3)
  inf <- data.frame(corsa = reg$nome[i], studio = sv$gse,
    stop_reason = vapply(X, function(r) ch(r$stop_reason), ""), errore_api = vapply(X, function(r) if (e_saltato(r)) substr(ch(r$saltato), 1L, 300L) else "", ""),
    recinto = vapply(X, function(r) isTRUE(r$recinto), NA), modello_api = vapply(X, function(r) ch(r$modello_api), ""),
    t_in = vapply(X, function(r) nm(r$uso$input_tokens), 0), t_out = vapply(X, function(r) nm(r$uso$output_tokens), 0),
    t_pens = vapply(X, function(r) nm(r$uso$output_tokens_details$thinking_tokens), 0),
    t_cache = vapply(X, function(r) sum(nm(r$uso$cache_read_input_tokens), nm(r$uso$cache_creation_input_tokens), na.rm = TRUE), 0),
    tentativi = vapply(X, function(r) nm(r$n_tentativi), 0), secondi = vapply(X, function(r) nm(r$secondi), 0),
    caratteri = vapply(X, function(r) nchar(nullo(ch(r$raw))), 0L), avvio = vapply(X, function(r) substr(ch(r$run_id), 1L, 16L), ""),
    impronta_uscita = vapply(X, function(r) imp(as.character(nullo(ch(r$raw_api)))), ""), stringsAsFactors = FALSE, row.names = NULL)
  pr <- PREZZI[[mod]]                                         # output_tokens comprende i token di ragionamento
  inf$dollari <- if (is.null(pr)) NA_real_ else { su <- mod == "haiku" & !is.na(inf$t_in) & inf$t_in > 1e5
    (inf$t_in * ifelse(su, HAIKU_SOPRA_100K[1], pr[1]) + inf$t_out * ifelse(su, HAIKU_SOPRA_100K[2], pr[2])) / 1e6 }
  # regola 4 di 00-previsioni.md: un rifiuto e' uno studio non chiuso; il testo scritto prima del rifiuto non si misura
  Xm <- lapply(X, function(r) { if (identical(ch(r$stop_reason), "refusal")) r$raw <- ""; r })
  M <- misura_forma(Xm, ADAT[[f]])
  inf$categoria <- ifelse(nzchar(inf$errore_api), "errore_400", ifelse(inf$stop_reason %in% "refusal", "rifiuto", ifelse(inf$stop_reason %in% "max_tokens", "troncata",
                     ifelse(!M$tab$valida, "non_valida", ifelse(!M$tab$chiuso, "valida_non_chiusa", "chiusa")))))
  kk <- chiavi_lettura(M); kk$tutto <- chiave_tutto(kk)
  kk$scheda <- impv(ifelse(M$tab$chiuso, paste(sv$gse, kk$tutto), paste(sv$gse, "non chiuso", vapply(Xm, function(r) as.character(nullo(ch(r$raw))), ""))))
  list(X = X, M = M, inf = inf, kk = kk)
}
t0 <- Sys.time(); RUN <- stats::setNames(lapply(seq_len(nrow(reg)), una_corsa), reg$nome)
cat(sprintf("misura di %d corse: %.0f s\n", nrow(reg), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
passa(sprintf("K3: ogni corsa copre 47 studi di sviluppo su 47 con una riga per studio (%d corse)", nrow(reg)), all(vapply(RUN, function(r) length(r$X) == 47L && nrow(r$M$tab) == 47L, NA)))
mod_ok <- vapply(seq_len(nrow(reg)), function(i) all(RUN[[i]]$inf$modello_api[!nzchar(RUN[[i]]$inf$errore_api)] == ID_API[[reg$modello[i]]]), NA)
passa("K4: il modello che risponde e' quello chiesto in ogni risposta", all(mod_ok), paste(reg$nome[!mod_ok], collapse = " "))
if (!SECCO) {
  fz <- file.path(S6, c("00-previsioni.md", "20-frase-schema.md", "23-lancia.py"))
  sporco <- system2("git", c("status", "--porcelain", "--", fz), stdout = TRUE)
  t_commit <- max(as.numeric(vapply(fz, function(f) system2("git", c("log", "-1", "--format=%ct", "--", f), stdout = TRUE), "")))
  avvii <- unlist(lapply(RUN, function(r) r$inf$avvio)); t_prima <- min(as.numeric(as.POSIXct(avvii, format = "%Y%m%dT%H%M%SZ", tz = "UTC")))
  passa("K4: carta, frase fissa e programma di lancio sono committati prima del primo avvio e non sono cambiati dopo", !length(sporco) && t_commit < t_prima,
        sprintf("ultimo commit %s, primo avvio %s", format(as.POSIXct(t_commit, origin = "1970-01-01", tz = "UTC")), format(as.POSIXct(t_prima, origin = "1970-01-01", tz = "UTC"))))
  cat(sprintf("24-misura.R: ultimo commit %s\n", system2("git", c("log", "-1", "--format=%h %cI", "--", file.path(S6, "24-misura.R")), stdout = TRUE)))
}

# ---- 4. i numeri di ogni corsa, token e spesa ---------------------------------------------------------------------
mis <- function(M, nome) { m <- M$misure$principale; m[m$misura == nome, ] }
CORSE <- do.call(rbind, lapply(seq_len(nrow(reg)), function(i) { r <- RUN[[i]]; n <- tre_numeri(r$M$tab); a <- mis(r$M, "a_gruppi_identici"); b <- mis(r$M, "b_confronti_ritrovati"); cc <- mis(r$M, "c_errori_non_elencati")
  cat_n <- table(factor(r$inf$categoria, levels = c("chiusa", "valida_non_chiusa", "non_valida", "troncata", "rifiuto", "errore_400")))
  data.frame(corsa = reg$nome[i], forma = reg$forma[i], modello = reg$modello[i], n_corsa = reg$corsa[i],
    chiusi = n[["chiusi"]], non_chiusi = 47L - n[["chiusi"]], identici = n[["identici"]], a_ic_basso = a$ic_basso, a_ic_alto = a$ic_alto,
    ritrovati = n[["ritrovati"]], den = n[["den"]], b_quota = b$quota, b_ic_basso = b$ic_basso, b_ic_alto = b$ic_alto, ritrovati97 = n[["ritrovati97"]], den97 = n[["den97"]],
    errori_c = n[["errori_c"]], giudicabili_c = n[["giudicabili_c"]], c_quota = cc$quota, c_ic_basso = cc$ic_basso, c_ic_alto = cc$ic_alto,
    valide_non_chiuse = cat_n[["valida_non_chiusa"]], non_valide = cat_n[["non_valida"]], troncate = cat_n[["troncata"]], rifiuti = cat_n[["rifiuto"]], errori_400 = cat_n[["errore_400"]],
    recinti = sum(r$inf$recinto), t_in = sum(r$inf$t_in, na.rm = TRUE), t_out = sum(r$inf$t_out, na.rm = TRUE), t_pens = sum(r$inf$t_pens, na.rm = TRUE), t_cache = sum(r$inf$t_cache),
    studi_con_ragionamento = sum(r$inf$t_pens > 0, na.rm = TRUE), t_out_max = max(r$inf$t_out, na.rm = TRUE), dollari = sum(r$inf$dollari, na.rm = TRUE),
    secondi_mediana = stats::median(r$inf$secondi, na.rm = TRUE), secondi_max = max(r$inf$secondi, na.rm = TRUE), tentativi_max = max(r$inf$tentativi, na.rm = TRUE), stringsAsFactors = FALSE) }))
scrivi(CORSE, "24-corse.csv")
scrivi(do.call(rbind, lapply(RUN, function(r) cbind(r$inf, r$M$tab[, setdiff(names(r$M$tab), "studio")], r$kk[, c("firma", "gruppi", "confronti", "scheda")][, -1], stringsAsFactors = FALSE))), "24-per-studio.csv")
scrivi(do.call(rbind, lapply(names(RUN), function(k) if (nrow(RUN[[k]]$M$unita)) cbind(corsa = k, RUN[[k]]$M$unita, stringsAsFactors = FALSE))), "24-unita.csv")
cat("\n== I numeri di ogni corsa (misura principale, 95 confronti) ==\n")
cat(sprintf("%-22s chiusi %2d  (a) %2d/47  (b) %2d/%d [97: %2d/%d]  (c) %d/%d | non valide %d, valide non chiuse %d, troncate %d, rifiuti %d, errori 400 %d, recinti %d | token in %d out %d (ragionamento %d, in %d studi) | %.2f $\n",
            CORSE$corsa, CORSE$chiusi, CORSE$identici, CORSE$ritrovati, CORSE$den, CORSE$ritrovati97, CORSE$den97, CORSE$errori_c, CORSE$giudicabili_c, CORSE$non_valide, CORSE$valide_non_chiuse,
            CORSE$troncate, CORSE$rifiuti, CORSE$errori_400, CORSE$recinti, CORSE$t_in, CORSE$t_out, CORSE$t_pens, CORSE$studi_con_ragionamento, CORSE$dollari), sep = "")
cat(sprintf("Mistral-Small 3.2: forma B0 %s; schema v1 %s; oggi %s\n", paste(sei(MIS$T$tab), collapse = " "), paste(sei(MIS$V$tab), collapse = " "), paste(n_og, collapse = " ")))
cat(sprintf("spesa delle corse misurate: %.2f dollari (prezzi di listino; i token di cache sono %d)\n", sum(CORSE$dollari), sum(CORSE$t_cache)))
for (k in names(RUN)) { e <- RUN[[k]]$inf[nzchar(RUN[[k]]$inf$errore_api) | RUN[[k]]$inf$stop_reason %in% c("refusal", "max_tokens"), ]
  if (nrow(e)) cat(sprintf("  %s %s: %s %s\n", k, e$studio, e$stop_reason, e$errore_api), sep = "") }
if (!SECCO && any(CORSE$modello == "haiku" & CORSE$n_corsa == 1L)) {
  h <- CORSE[CORSE$modello == "haiku" & CORSE$n_corsa == 1L, ]
  pj <- vapply(ORD, function(m) 2 * sum(h$t_in * PREZZI[[m]][1] + h$t_out * PREZZI[[m]][2]) / 1e6, 0)
  cat(sprintf("proiezione della spesa di tutta la prova con i token di Haiku (corsa 1, %d forme; il ragionamento degli altri modelli puo' essere di piu'): %s; totale %.0f dollari\n",
              nrow(h), paste(sprintf("%s %.1f", ORD, pj), collapse = ", "), sum(pj)))
}

# ---- 5. appaiati: Claude meno Mistral nella stessa forma, Claude meno oggi ------------------------------------------
APP <- do.call(rbind, lapply(seq_len(nrow(reg)), function(i) { L <- RUN[[i]]$M$per_studio$principale
  rbind(cbind(corsa = reg$nome[i], contro = "mistral_stessa_forma", appaiato(L, MIS[[reg$forma[i]]]$per_studio$principale, c("claude", "altro")), stringsAsFactors = FALSE),
        cbind(corsa = reg$nome[i], contro = "oggi", appaiato(L, og, c("claude", "altro")), stringsAsFactors = FALSE)) }))
scrivi(APP, "24-appaiati.csv")
cat("\n== Appaiati, (b) confronti ritrovati ==\n")
ab <- APP[APP$misura == "b_confronti_ritrovati", ]
cat(sprintf("%-22s meno %-20s %+6.1f punti (IC95 %+6.1f, %+6.1f)\n", ab$corsa, ab$contro, 100 * ab$differenza, 100 * ab$ic_basso, 100 * ab$ic_alto), sep = "")

# ---- 6. la ripetibilita' fra le due corse -------------------------------------------------------------------------
cop <- unique(reg[, c("forma", "modello")]); cop <- cop[vapply(seq_len(nrow(cop)), function(j) sum(reg$forma == cop$forma[j] & reg$modello == cop$modello[j]) == 2L, NA), ]
RIP <- if (nrow(cop)) do.call(rbind, lapply(seq_len(nrow(cop)), function(j) { a <- RUN[[sprintf("%s-%s-corsa1", cop$forma[j], cop$modello[j])]]; b <- RUN[[sprintf("%s-%s-corsa2", cop$forma[j], cop$modello[j])]]
  data.frame(forma = cop$forma[j], modello = cop$modello[j], identiche_al_carattere = sum(uguali_al_carattere(a$X, b$X)), identiche_com_e_arrivata = sum(a$inf$impronta_uscita == b$inf$impronta_uscita),
             stessa_firma = sum(a$kk$firma == b$kk$firma), stessi_gruppi = sum(a$kk$gruppi == b$kk$gruppi), stessi_confronti = sum(a$kk$confronti == b$kk$confronti),
             stessa_chiave = sum(a$kk$tutto == b$kk$tutto), chiusi_1 = sum(a$M$tab$chiuso), chiusi_2 = sum(b$M$tab$chiuso),
             studi_diversi = unisci(sv$gse[a$kk$tutto != b$kk$tutto], " "), stringsAsFactors = FALSE) })) else NULL
if (!is.null(RIP)) { scrivi(RIP, "24-ripetibilita.csv"); cat("\n== Ripetibilita' fra le due corse (studi su 47) ==\n"); print(RIP[, 1:10], row.names = FALSE) }

# ---- 7. le chiavi di ogni corsa, uguali a Mistral nella stessa forma, uguali fra i modelli ---------------------------
KM <- lapply(MIS, function(m) { k <- chiavi_lettura(m); k$tutto <- chiave_tutto(k); k })
CH <- data.frame(studio = sv$gse, mistral_T = impv(KM$T$tutto), mistral_V = impv(KM$V$tutto), stringsAsFactors = FALSE)
for (k in names(RUN)) CH[[k]] <- impv(RUN[[k]]$kk$tutto)
scrivi(CH, "24-chiavi.csv")
cat("\n== Studi con la stessa chiave (tabella dei fattori, gruppi, confronti) di Mistral nella stessa forma ==\n")
for (i in seq_len(nrow(reg))) cat(sprintf("%-22s %d/47\n", reg$nome[i], sum(RUN[[i]]$kk$tutto == KM[[reg$forma[i]]]$tutto)))

# ---- 8. lo stato dei 9 errori di lettura di B0 (predicati) e le fonti dei fattori di GSE147507 ------------------------
ST <- do.call(rbind, lapply(names(RUN), function(k) data.frame(corsa = k, errore = ERRORI_B0$errore, costa = ERRORI_B0$costa, presente = stato_errori(RUN[[k]]$M$tab), stringsAsFactors = FALSE)))
ST <- merge(ST, reg[, c("nome", "forma", "modello", "corsa")], by.x = "corsa", by.y = "nome", suffixes = c("", "_n"), sort = FALSE)
scrivi(ST, "24-stati-errori.csv")
cat("\n== I 9 errori di lettura di B0, per corsa (TRUE presente, FALSE assente, NA senza tabella dei fattori) ==\n")
w <- vapply(names(RUN), function(k) stato_errori(RUN[[k]]$M$tab), logical(nrow(ERRORI_B0))); rownames(w) <- ERRORI_B0$errore; print(t(w))
f147 <- rbind(data.frame(corsa = c("mistral_T", "mistral_V"), chiuso = c(MIS$T$tab$chiuso[sv$gse == "GSE147507"], MIS$V$tab$chiuso[sv$gse == "GSE147507"]),
                         fonti = c(MIS$T$tab$fonti[sv$gse == "GSE147507"], MIS$V$tab$fonti[sv$gse == "GSE147507"]), stringsAsFactors = FALSE),
              do.call(rbind, lapply(names(RUN), function(k) { t <- RUN[[k]]$M$tab; data.frame(corsa = k, chiuso = t$chiuso[t$studio == "GSE147507"], fonti = t$fonti[t$studio == "GSE147507"], stringsAsFactors = FALSE) })))
scrivi(f147, "24-GSE147507-fonti.csv"); cat("\nGSE147507, le colonne di fonte dei fattori (senza predicato: si giudica leggendo):\n"); print(f147, row.names = FALSE, right = FALSE)

# ---- 9. le previsioni che non chiedono una lettura (corsa 1) ----------------------------------------------------------
AT <- list(P1 = list(T = c(9, 5, 4, 3), V = c(6, 3, 2, 2)), P2 = list(T = c(6, 2, 2, 1), V = c(0, 0, 0, 0)), P3 = list(T = c(0, 0, 0, 1), V = c(0, 0, 0, 1)),
           P6 = list(T = c(31, 36, 38, 39), V = c(33, 37, 39, 39)), P7 = list(T = c(56, 68, 72, 74), V = c(58, 68, 72, 74)), P8 = list(T = c(-13, 0, 4, 6), V = c(8, 19, 23, 25)),
           P11 = c(2, 1, 1, 1), P12 = c(2, 1, 0, 0), P15 = c(38, 41, 42, 42))
ATTESE_PER_STUDIO <- rbind("GSE46665:sigle dei pazienti come malattie" = c(TRUE, FALSE, FALSE, FALSE), "GSE57945:sesso come fattore" = c(TRUE, TRUE, TRUE, TRUE),
                           "GSE60340:colonna del trattamento non vista" = c(FALSE, FALSE, FALSE, FALSE), "GSE49155:fattore doppio" = c(FALSE, FALSE, FALSE, FALSE)); colnames(ATTESE_PER_STUDIO) <- ORD
PREV <- list()
ORD_P <- if (SECCO) c(ORD, "mistral") else ORD                # prova a secco: Mistral con le attese di Haiku, solo per provare il codice
conto_p <- function(cod, forma, mod, che, v, att, lo, hi) PREV[[length(PREV) + 1L]] <<- data.frame(codice = cod, forma = forma, modello = mod, quantita = che, valore = v, ic_basso = NA, ic_alto = NA,
  atteso = as.character(att), rilevanza = sprintf("%s-%s", lo, hi), esito = if (v >= lo && v <= hi) "confermata" else "smentita", stringsAsFactors = FALSE)
stima_p <- function(cod, forma, mod, che, v, icb, ica, att, lo, hi) PREV[[length(PREV) + 1L]] <<- data.frame(codice = cod, forma = forma, modello = mod, quantita = che, valore = v, ic_basso = icb, ic_alto = ica,
  atteso = as.character(att), rilevanza = sprintf("%s-%s", lo, hi), esito = if (is.na(v)) "non giudicabile" else if (icb >= lo && ica <= hi) "confermata" else if (ica < lo || icb > hi) "smentita" else "indeterminata", stringsAsFactors = FALSE)
sopra0_p <- function(cod, forma, mod, che, r, att) PREV[[length(PREV) + 1L]] <<- data.frame(codice = cod, forma = forma, modello = mod, quantita = che, valore = r$differenza, ic_basso = r$ic_basso, ic_alto = r$ic_alto,
  atteso = as.character(att), rilevanza = "IC95 sopra 0", esito = if (r$ic_basso > 0) "sopra 0" else if (r$ic_alto < 0) "sotto 0" else "a cavallo di 0", stringsAsFactors = FALSE)
for (i in which(reg$corsa == 1L & reg$modello %in% ORD_P)) {
  f <- reg$forma[i]; m <- reg$modello[i]; j <- match(m, ORD); if (is.na(j)) j <- 1L; cr <- CORSE[i, ]; stopifnot(cr$corsa == reg$nome[i])
  conto_p("P1", f, m, "studi non chiusi", cr$non_chiusi, AT$P1[[f]][j], 0, 7)
  conto_p("P2", f, m, "uscite non valide contro lo schema", cr$non_valide, AT$P2[[f]][j], 0, if (f == "T") 2 else 0)
  conto_p("P3", f, m, "rifiuti", cr$rifiuti, AT$P3[[f]][j], 0, 0)
  conto_p("P4", f, m, "uscite troncate", cr$troncate, 0, 0, 0)
  if (f == "T") conto_p("P5", f, m, "uscite con un recinto di codice", cr$recinti, 0, 0, 2)
  stima_p("P6", f, m, "(a) quota di studi con partizione identica", cr$identici / 47, cr$a_ic_basso, cr$a_ic_alto, sprintf("%d/47", AT$P6[[f]][j]), 24 / 47, 1)
  PREV[[length(PREV) + 1L]] <- data.frame(codice = "P7", forma = f, modello = m, quantita = "(b) confronti ritrovati su 95", valore = cr$ritrovati, ic_basso = NA, ic_alto = NA, atteso = as.character(AT$P7[[f]][j]), rilevanza = "vedi P8", esito = "", stringsAsFactors = FALSE)
  a <- APP[APP$corsa == reg$nome[i] & APP$misura == "b_confronti_ritrovati", ]
  sopra0_p("P8", f, m, "Claude meno Mistral nella stessa forma, (b)", a[a$contro == "mistral_stessa_forma", ], sprintf("%+d punti", AT$P8[[f]][j]))
  sopra0_p("P9", f, m, "Claude meno oggi, (b)", a[a$contro == "oggi", ], "sopra 0")
  stima_p("P10", f, m, "(c) errori fra i non elencati", cr$c_quota, cr$c_ic_basso, cr$c_ic_alto, "3%", 0, 0.10)
  s <- stato_errori(RUN[[i]]$M$tab)
  if (f == "T") { conto_p("P11", f, m, "dei 4 errori di B0 che costano, presenti", sum(s[ERRORI_B0$costa] %in% TRUE), AT$P11[j], 0, 0)
                  conto_p("P12", f, m, "dei 5 errori di B0 che non costano, presenti", sum(s[!ERRORI_B0$costa] %in% TRUE), AT$P12[j], 0, 0) }
  if (!is.null(RIP) && any(RIP$forma == f & RIP$modello == m)) { r <- RIP[RIP$forma == f & RIP$modello == m, ]
    conto_p("P14", f, m, "studi con l'uscita identica al carattere fra le due corse", r$identiche_al_carattere, 15, 47, 47)
    conto_p("P15", f, m, "studi con la stessa tabella, gli stessi gruppi e gli stessi confronti fra le due corse", r$stessa_chiave, AT$P15[j], 43, 47) }
}
if (length(PREV)) { PREV <- do.call(rbind, PREV); scrivi(PREV, "24-previsioni.csv"); cat("\n== Previsioni (corsa 1) ==\n"); print(PREV[order(as.integer(sub("P", "", PREV$codice)), PREV$forma, match(PREV$modello, ORD_P)), ], row.names = FALSE, digits = 3) }
tt <- which(reg$corsa == 1L & reg$forma == "T" & reg$modello %in% ORD_P)
if (length(tt)) { o <- vapply(tt, function(i) as.logical(stato_errori(RUN[[i]]$M$tab)[match(rownames(ATTESE_PER_STUDIO), ERRORI_B0$errore)]), logical(4)); colnames(o) <- reg$modello[tt]; rownames(o) <- rownames(ATTESE_PER_STUDIO)
  cat("\nPer studio, forma T, i 4 errori che costano: osservato (TRUE presente)\n"); print(o)
  cat(sprintf("attese giuste: %d su %d (senza GSE147507, che si giudica leggendo; NA = senza tabella, contato come attesa sbagliata)\n", sum(o == ATTESE_PER_STUDIO[, ifelse(colnames(o) %in% ORD, colnames(o), "haiku"), drop = FALSE], na.rm = TRUE), length(o))) }

# ---- 10. le schede da leggere: tutti i disaccordi della corsa 1 -------------------------------------------------------
u1 <- which(reg$corsa == 1L)
LEG <- do.call(rbind, lapply(u1, function(i) { r <- RUN[[i]]; t <- r$M$tab; q <- t$n_unita > 0
  if (!any(q)) return(NULL)
  data.frame(scheda = r$kk$scheda[q], studio = t$studio[q], corsa = reg$nome[i], forma = reg$forma[i], modello = reg$modello[i], chiuso = t$chiuso[q], stato = t$stato[q], n_unita = t$n_unita[q], unita = t$unita[q],
             uguale_a_mistral_stessa_forma = r$kk$tutto[q] == KM[[reg$forma[i]]]$tutto[q], uguale_a_mistral_T = r$kk$tutto[q] == KM$T$tutto[q], uguale_a_mistral_V = r$kk$tutto[q] == KM$V$tutto[q], stringsAsFactors = FALSE) }))
if (!is.null(LEG)) { scrivi(LEG, "24-da-leggere.csv")
  cat(sprintf("\n== Da leggere (corsa 1): %d coppie studio-corsa con almeno un disaccordo, %d schede distinte in %d studi; %d schede uguali a una lettura di Mistral ==\n", nrow(LEG), length(unique(LEG$scheda)),
              length(unique(LEG$studio)), length(unique(LEG$scheda[LEG$uguale_a_mistral_T | LEG$uguale_a_mistral_V])))) }

# ---- 11. K2 nella prova a secco: l'estrazione e il formato non cambiano la misura; un'uscita rotta e' non valida -------
if (SECCO) {
  a <- RUN[["T-mistral-corsa1"]]; v <- RUN[["V-mistral-corsa1"]]; rt <- RUN[["T-mistralrotto-corsa1"]]
  passa("K2 (i): le uscite di Mistral nella forma B0, avvolte nel recinto e passate per estrai(), danno gli stessi numeri di K1", identical(sei(a$M$tab), sei(MIS$T$tab)) && all(a$kk$tutto == KM$T$tutto) && sum(a$inf$recinto) == 47L)
  passa("K2 (i): le uscite di Mistral con lo schema v1, nel formato del programma di lancio, danno gli stessi numeri di K1", identical(sei(v$M$tab), sei(MIS$V$tab)) && all(v$kk$tutto == KM$V$tutto))
  rotte <- strsplit(readLines(file.path(PROVA, "rotte.txt")), " ")[[1]]
  passa("K2 (ii): le tre uscite rotte apposta sono non valide e solo quelle cambiano", all(!rt$M$tab$valida[match(rotte, sv$gse)]) && all(rt$inf$categoria[match(rotte, sv$gse)] == "non_valida") &&
          all(rt$kk$tutto[!(sv$gse %in% rotte)] == KM$T$tutto[!(sv$gse %in% rotte)]), paste(rotte, rt$inf$categoria[match(rotte, sv$gse)], collapse = "; "))
}
if (nzchar(Sys.getenv("S12R6_OGGETTI"))) saveRDS(list(RUN = RUN, MIS = MIS, KM = KM, reg = reg, CORSE = CORSE, APP = APP, RIP = RIP, og = og, sv = sv, rif = rif, viste = viste, campi = campi), Sys.getenv("S12R6_OGGETTI"))
cat(if (ESITO) "\nCANCELLI: PASSANO\n" else "\nCANCELLI: ALMENO UNO FALLISCE\n")
