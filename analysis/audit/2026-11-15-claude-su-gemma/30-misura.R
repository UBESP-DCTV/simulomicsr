# 30-misura.R — la misura dei modelli Claude sulla parte APERTA degli studi di Gemma (carta: 00-previsioni.md).
# Termine di misura: niente entra nella pipeline. Base: ../2026-11-15-lettori-su-gemma/41-misura.R (stesse funzioni,
# stesso riferimento, stessa misura per voce); la forma delle uscite dei Claude e' V, adattatore `A0` (S12r4).
#
#   FASE=letture CORSA=<corsa> Rscript .../30-misura.R     adatta le uscite di una corsa e le mette nella cache (SENZA --vanilla)
#   CORSE=haiku-corsa1,haiku-corsa2,opus-corsa1,sonnet-corsa1 Rscript .../30-misura.R > .../30-out.txt 2>&1
#
# Corse: M-rp11 (Mistral B0) e GE-rp0 (Gemma-4-31B B0), congelate in analysis/p4-output/lettori-su-gemma-B0/;
# le corse dei Claude congelate da 20-lancia-lotti.py in analysis/p4-output/claude-su-gemma-V/<corsa>.jsonl.
#
# Decisioni tecniche, scritte prima di ogni uscita di un Claude su uno studio di Gemma:
#   - un rifiuto (stop_reason = refusal) e' uno studio non chiuso: il testo scritto prima del rifiuto non si misura
#     (regola 4 della prova del 2026-11-14);
#   - uno studio `saltato` (errore della richiesta) o `senza_risposta` ha una lettura non chiusa: le sue voci contano
#     come non identiche e i loro confronti come non ritrovati (carta, c3);
#   - «studi con una risposta richiesta» (c2) = gli studi dei pezzi lanciati della corsa;
#   - c6 e c8 si calcolano sugli studi che Mistral ha letto (uscita generata) e che la corsa del Claude ha chiesto;
#   - c8 usa le voci misurate di Mistral (il lettore della pipeline), come m8 di 41-misura.R;
#   - «stessi gruppi» (accanto) = la stessa partizione dei campioni dello studio, tutte e due le letture chiuse;
#   - la cache delle letture tiene solo chiuso, partizione, confronti, motivi; la chiave e' l'impronta dell'uscita.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")            # legge SOLO i 47 studi di sviluppo
source("analysis/audit/2026-11-15-lettori-su-gemma/30-misura-contro-gemma.R")      # LG, G, misura_contro_gemma, ...
QUI <- "analysis/audit/2026-11-15-claude-su-gemma"
SEME <- 20261115L; B <- 10000L; TETTO <- 75
USCITE_L <- "analysis/p4-output/lettori-su-gemma-B0"; USCITE_C <- "analysis/p4-output/claude-su-gemma-V"
CACHE <- file.path(USCITE_C, "cache-letture"); dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
F_VISTE <- "analysis/input/gemma-viste-v0.jsonl"; F_INGRESSO <- "analysis/input/gemma-b0-ingresso-aperta.jsonl"
PROMPT_V1 <- "analysis/audit/2026-11-10-S12r2-prova-ripetuta/21-prompt-v1.md"; SCHEMA_V1 <- "analysis/audit/2026-11-10-S12r2-prova-ripetuta/20-schema-v1.json"
PREZZI <- list(haiku = c(0.10, 0.50), sonnet = c(2, 10), opus = c(4, 20)); HAIKU_SOPRA_100K <- c(0.50, 2.50); SCONTO_LOTTI <- 0.5
FASE <- Sys.getenv("FASE", "misura")
passa <- function(che, ok, dett = "") {
  cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else ""))
  if (!isTRUE(ok)) stop("CANCELLO FALLITO: ", che, call. = FALSE)
}
scrivi_csv <- function(d, f) utils::write.csv(d, file.path(QUI, f), row.names = FALSE, na = "")
ch <- function(x) if (is.null(x) || !length(x) || is.na(x[[1]])) "" else as.character(x[[1]])
nm <- function(x) if (is.null(x) || !length(x) || is.na(x[[1]])) 0 else as.numeric(x[[1]])
cat("30-misura.R ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), " fase ", FASE, "\n")

# ---- l'oggetto (come 41-misura.R) -----------------------------------------------------------------------------
el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
es <- utils::read.csv(file.path(G, "30-esiti.csv"), stringsAsFactors = FALSE)
voci <- es[es$esito == "tabella", ]; voci$gse <- el$gse[match(voci$shortName, el$shortName)]
voci <- voci[order(voci$gse, voci$shortName, method = "radix"), ]
stopifnot(!anyNA(voci$gse), !any(voci$parte %in% c("giudizio_A", "giudizio_B")))
e21 <- new.env(); sys.source(file.path(LG, "21-divisione.R"), envir = e21)
div <- utils::read.csv(file.path(LG, "21-divisione.csv"), stringsAsFactors = FALSE)
stopifnot(identical(div$parte, unname(e21$parte_gemma(div$gse))))
aperti <- div$gse[div$parte == "aperta"]; chiusi_g <- div$gse[div$parte == "chiusa"]
atlas_div <- utils::read.delim("analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv", stringsAsFactors = FALSE)
VG <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
names(VG) <- vapply(VG, `[[`, "", "record_id")
s22 <- utils::read.csv(file.path(LG, "22-per-studio.csv"), stringsAsFactors = FALSE)
in_ingresso <- s22$gse[s22$parte == "aperta" & s22$esito == "al_modello"]
stopifnot(length(in_ingresso) == 2016L, all(in_ingresso %in% names(VG)))
campioni_di <- function(v) as.character(unlist(v$campioni))

# ---- corse, letture, chiavi -----------------------------------------------------------------------------------
LOCALI <- c("M-rp11", "GE-rp0")
file_corsa <- function(corsa) file.path(if (corsa %in% LOCALI) USCITE_L else USCITE_C, paste0(corsa, ".jsonl"))
adattatore_di <- function(corsa) if (corsa %in% LOCALI) "B0" else "A0"
modello_di <- function(corsa) sub("-corsa.*$", "", corsa)
leggi_corsa <- function(f) { x <- leggi_jsonl(f); names(x) <- vapply(x, `[[`, "", "record_id"); stopifnot(!anyDuplicated(names(x))); x }
e_rifiuto <- function(r) identical(ch(r$stop_reason), "refusal")
e_fallita <- function(r) nzchar(ch(r$fallita))
# Il validatore di ogni studio resta nella cache `.validatori_forma` di 10-forme.R: si svuota dopo ogni studio.
letture_di <- function(x, ad) stats::setNames(lapply(seq_along(x), function(i) { g <- names(x)[i]; r0 <- x[[g]]
  raw <- if (e_rifiuto(r0)) "" else as.character(nullo(r0$raw))
  r <- adatta_forma(VG[[g]], raw, e_saltato(r0), as.character(nullo(r0$fine)), ad)
  rm(list = ls(.validatori_forma), envir = .validatori_forma); if (i %% 25L == 0L) invisible(gc())
  r[intersect(c("chiuso", "partizione", "confronti", "motivi"), names(r))] }), names(x))
letture_cache <- function(corsa, x) {
  f <- file.path(CACHE, sprintf("letture-%s-%s.rds", corsa, substr(sha(file_corsa(corsa)), 1L, 16L)))
  if (file.exists(f)) return(readRDS(f))
  L <- letture_di(x, adattatore_di(corsa)); tmp <- paste0(f, ".tmp"); saveRDS(L, tmp); file.rename(tmp, f); L
}
NON_CHIUSO <- "non chiuso non chiuso"
chiave_g <- function(r) if (!isTRUE(r$chiuso)) "non chiuso" else
  imp(paste(sort(vapply(split(names(r$partizione), unname(r$partizione)), camp_ins, "")), collapse = ";"))
chiave_gc <- function(r) {                                   # uguale a chiave_gc() di 41-misura.R
  if (!isTRUE(r$chiuso)) return(NON_CHIUSO)
  k <- r$confronti
  kk <- if (!nrow(k)) "nessun confronto" else
    imp(paste(sort(sprintf("%s>%s", vapply(k$trattato, camp_ins, ""), vapply(k$controllo, camp_ins, ""))), collapse = ";"))
  paste(chiave_g(r), kk)
}
if (FASE == "letture") {
  corsa <- Sys.getenv("CORSA"); stopifnot(nzchar(corsa), file.exists(file_corsa(corsa)))
  x <- leggi_corsa(file_corsa(corsa)); L <- letture_cache(corsa, x)
  cat(sprintf("letture di %s: %d studi, %d chiusi; cache scritta\n", corsa, length(L), sum(vapply(L, function(r) isTRUE(r$chiuso), NA))))
  quit(save = "no", status = 0L)
}

.tg <- new.env()
tab_gemma <- function(nome, gse) { if (is.null(.tg[[nome]])) .tg[[nome]] <- { x <- gemma_leggi(nome); gemma_tabella(x$campioni, x$analisi, gse) }; .tg[[nome]] }
misura_voci <- function(vv, vs, lett) {                      # uguale a misura_voci() di 41-misura.R
  righe <- list(); senza <- character(0)
  for (i in seq_len(nrow(vv))) {
    g <- vv$gse[i]; r <- tab_gemma(vv$shortName[i], g); stopifnot(isTRUE(r$chiuso))
    cv <- campioni_di(vs[[g]])
    if (!length(intersect(r$gsm, cv))) { senza <- c(senza, vv$shortName[i]); next }
    righe[[length(righe) + 1L]] <- misura_contro_gemma(vv$shortName[i], g, r, lett[[g]], cv)$riga
  }
  per <- do.call(rbind, righe); rownames(per) <- NULL
  list(per = per, senza = senza)
}
quota_studi <- function(x, B, seme) {
  set.seed(seme); n <- length(x)
  v <- vapply(seq_len(B), function(b) mean(x[sample.int(n, n, replace = TRUE)]), 0)
  c(num = sum(x), den = n, quota = mean(x), ic_basso = unname(stats::quantile(v, 0.025)), ic_alto = unname(stats::quantile(v, 0.975)))
}
riga_q <- function(nome, q) sprintf("%s: %d/%d = %.1f%% (IC95 %.1f-%.1f%%)", nome, as.integer(q[["num"]]), as.integer(q[["den"]]),
                                    100 * q[["quota"]], 100 * q[["ic_basso"]], 100 * q[["ic_alto"]])
costo <- function(modello, uso) {
  if (is.null(uso)) return(0)
  t_in <- nm(uso$input_tokens); t_cw <- nm(uso$cache_creation_input_tokens); t_cr <- nm(uso$cache_read_input_tokens); t_out <- nm(uso$output_tokens)
  p <- PREZZI[[modello]]; if (modello == "haiku" && (t_in + t_cw + t_cr) > 100000) p <- HAIKU_SOPRA_100K
  SCONTO_LOTTI * (t_in * p[1] + t_cw * p[1] * 1.25 + t_cr * p[1] * 0.1 + t_out * p[2]) / 1e6
}
giudica <- function(lo, hi, a, b) if (lo >= a && hi <= b) "confermata" else if (hi < a || lo > b) "smentita" else "indeterminata"
PREV <- list()
prev <- function(id, che, atteso, a, b, stima, lo, hi, nota = "") {
  e <- giudica(lo, hi, a, b)
  PREV[[length(PREV) + 1L]] <<- data.frame(previsione = id, quantita = che, atteso = atteso, rilevanza_da = a, rilevanza_a = b, stima = stima,
                                           ic_basso = lo, ic_alto = hi, esito = e, nota = nota, stringsAsFactors = FALSE)
  cat(sprintf("  %s %s: atteso %s, rilevanza %s..%s; stima %.1f (IC95 %.1f, %.1f): %s%s\n", id, che, atteso, a, b, stima, lo, hi, toupper(e),
              if (nzchar(nota)) paste0(" [", nota, "]") else ""))
}

# ---- KC1: riproduzione ---------------------------------------------------------------------------------------
m_op <- misura_forma(leggi_uscite("analysis/p4-output/S12r6-claude/V-opus-corsa1.jsonl"), "A0"); t3 <- tre_numeri(m_op$tab)
passa("KC1 la misura della forma V rida' il 2026-11-14 contro Atlas (Opus corsa 1 sui 47 studi di sviluppo)",
      t3[["chiusi"]] == 47L && t3[["identici"]] == 38L && t3[["ritrovati"]] == 72L && t3[["den"]] == 95L,
      sprintf("%d chiusi, %d/47, %d/%d", t3[["chiusi"]], t3[["identici"]], t3[["ritrovati"]], t3[["den"]]))

# ---- KC2: impronte -------------------------------------------------------------------------------------------
passa("KC2 l'ingresso ha l'impronta di 22-ingresso-sha256.txt",
      identical(sprintf("%s  %s", sha(F_INGRESSO), F_INGRESSO), readLines(file.path(LG, "22-ingresso-sha256.txt"))))
passa("KC2 prompt v1 e schema v1 hanno le impronte della carta",
      identical(sha(PROMPT_V1), "9be21089fe5b158d1b6c75ba970965fc58fc2aa09c46d7aa916f70ec7f545b1d") &&
        identical(sha(SCHEMA_V1), "6a3fc587c0b6e16128cd2101e8bbdbda2565c3be237007b3fda06a98f4afd2a6"))
imp_l <- readLines(file.path(LG, "40-uscite-sha256.txt")); imp_c <- readLines(file.path(QUI, "20-uscite-sha256.txt"))
impronte <- data.frame(sha = sub("  .*$", "", c(imp_l, imp_c)), file = sub("^[0-9a-f]+  ", "", c(imp_l, imp_c)), stringsAsFactors = FALSE)
lotti <- lapply(readLines(file.path(QUI, "20-lotti.jsonl"), warn = FALSE), jsonlite::fromJSON, simplifyVector = FALSE)
lotti <- data.frame(corsa = vapply(lotti, function(r) ch(r$corsa), ""), pezzo = vapply(lotti, function(r) ch(r$pezzo), ""),
                    n = vapply(lotti, function(r) nm(r$n), 0), costo_prova = vapply(lotti, function(r) nm(r$costo_prova), 0), stringsAsFactors = FALSE)
ord_sha <- in_ingresso[order(vapply(in_ingresso, function(g) digest::digest(g, algo = "sha256", serialize = FALSE), ""), method = "radix")]
stopifnot(identical(ord_sha[1:5], c("GSE144208", "GSE195877", "GSE57871", "GSE141756", "GSE197959")))
pezzo_di <- stats::setNames((seq_along(ord_sha) - 1L) %/% 252L + 1L, ord_sha)

apri_corsa <- function(corsa) {
  f <- file_corsa(corsa)
  passa(sprintf("KC2 l'uscita %s ha l'impronta congelata", corsa), file.exists(f) && identical(sha(f), impronte$sha[match(f, impronte$file)]))
  x <- leggi_corsa(f); id <- names(x)
  passa(sprintf("KC5 %s: nessuno studio della parte chiusa, di giudizio o di sviluppo", corsa),
        !any(id %in% chiusi_g) && !any(id %in% atlas_div$gse) && !any(id %in% sv$gse) && all(id %in% aperti), sprintf("%d record, tutti della parte aperta", length(id)))
  if (corsa %in% LOCALI) attesi <- in_ingresso else {
    pz <- suppressWarnings(as.integer(lotti$pezzo[lotti$corsa == corsa])); pz <- pz[!is.na(pz)]
    attesi <- in_ingresso[pezzo_di[in_ingresso] %in% pz]
  }
  passa(sprintf("KC3 %s: un record per ogni studio richiesto", corsa), setequal(id, attesi), sprintf("%d su %d", length(id), length(attesi)))
  x[attesi]
}
RUN <- list()
carica <- function(corsa) { X <- apri_corsa(corsa); L <- letture_cache(corsa, X)
  # correzione del 2026-11-15, dopo il primo lancio della misura (fermo qui, prima di ogni numero su Gemma): la fase
  # "letture" scrive la cache nell'ordine del file, la misura chiede l'ordine dell'ingresso. Stessi studi, riordino per nome.
  stopifnot(setequal(names(L), names(X)), !anyDuplicated(names(L))); L <- L[names(X)]; stopifnot(identical(names(L), names(X)))
  list(X = X, L = L, kc = vapply(L, chiave_gc, ""), kg = vapply(L, chiave_g, ""), chiuso = vapply(L, function(r) isTRUE(r$chiuso), NA)) }

# ---- Mistral M-rp11 e Gemma-4-31B GE-rp0 (corse congelate) ----------------------------------------------------
RUN[["M-rp11"]] <- carica("M-rp11"); RUN[["GE-rp0"]] <- carica("GE-rp0")
M <- RUN[["M-rp11"]]; mandati_M <- names(M$X)[!vapply(M$X, e_saltato, NA)]
vv_M <- voci[voci$gse %in% mandati_M, ]; per_M <- misura_voci(vv_M, VG, M$L)$per
passa("KC1 la misura di Mistral M-rp11 contro Gemma rida' 1.377/2.052 voci identiche e 3.198/6.850 confronti",
      sum(per_M$classe_gruppi %in% "identica") == 1377L && nrow(per_M) == 2052L && sum(per_M$n_b_uguale) == 3198L && sum(per_M$n_b_den) == 6850L,
      sprintf("%d/%d, %d/%d", sum(per_M$classe_gruppi %in% "identica"), nrow(per_M), sum(per_M$n_b_uguale), sum(per_M$n_b_den)))

# ---- le corse dei Claude: esiti (KC3), misure c2-c5, token e spesa --------------------------------------------
CORSE <- strsplit(Sys.getenv("CORSE", "haiku-corsa1,haiku-corsa2,opus-corsa1,sonnet-corsa1"), ",", fixed = TRUE)[[1]]
PER <- list("M-rp11" = per_M); RIASSUNTO <- list(); CONTI <- list()
campioni_vista <- vapply(in_ingresso, function(g) length(campioni_di(VG[[g]])), 1L)
aggiungi_classi <- function(per) {
  per$campioni_vista <- campioni_vista[per$gse]; per$fattori_gemma <- voci$fattori[match(per$studio, voci$shortName)]
  per$classe_grandezza <- as.character(cut(per$campioni_vista, c(0, 12, 48, Inf), labels = c("fino a 12 campioni", "13-48 campioni", "oltre 48 campioni")))
  per$classe_fattori <- ifelse(per$fattori_gemma >= 3L, "3 o piu' fattori di Gemma", sprintf("%d fattori di Gemma", per$fattori_gemma)); per
}
PER[["M-rp11"]] <- aggiungi_classi(per_M)
for (corsa in CORSE) {
  cat("\n==================== ", corsa, " ====================\n", sep = "")
  R <- carica(corsa); RUN[[corsa]] <- R; X <- R$X; L <- R$L; mod <- modello_di(corsa)
  esiti <- data.frame(gse = names(X), pezzo = unname(pezzo_di[names(X)]), stringsAsFactors = FALSE)
  esiti$esito <- vapply(names(X), function(g) if (e_saltato(X[[g]])) "saltato" else if (e_fallita(X[[g]])) "senza_risposta" else if (R$chiuso[[g]]) "misurato" else "non_chiuso", "")
  esiti$motivi <- vapply(names(X), function(g) if (esiti$esito[match(g, esiti$gse)] != "non_chiuso") "" else if (e_rifiuto(X[[g]])) "rifiuto" else paste(nomi_motivi(L[[g]]), collapse = " | "), "")
  esiti$dettaglio <- vapply(names(X), function(g) substr(paste0(ch(X[[g]]$saltato), ch(X[[g]]$fallita)), 1L, 200L), "")
  esiti$stop_reason <- vapply(X, function(r) ch(r$stop_reason), ""); esiti$t_in <- vapply(X, function(r) nm(r$n_prompt), 0); esiti$t_out <- vapply(X, function(r) nm(r$n_out), 0)
  esiti$dollari <- vapply(X, function(r) costo(mod, r$uso), 0); esiti$campioni_vista <- campioni_vista[esiti$gse]
  scrivi_csv(esiti, sprintf("30-esiti-studi-%s.csv", corsa))
  passa(sprintf("KC3 %s: ogni studio richiesto ha un esito", corsa), !anyNA(esiti$esito) && all(esiti$esito %in% c("misurato", "non_chiuso", "saltato", "senza_risposta")),
        sprintf("somma %d (pezzi %s)", nrow(esiti), paste(sort(unique(esiti$pezzo)), collapse = ",")))
  cat("Esiti:\n"); print(table(esiti$esito))
  cat("motivi degli studi non chiusi (uno studio puo' averne piu' di uno):\n")
  print(sort(table(unlist(strsplit(esiti$motivi[esiti$esito == "non_chiuso"], " | ", fixed = TRUE))), decreasing = TRUE))
  cat("motivi di fine (stop_reason):\n"); print(table(esiti$stop_reason, useNA = "ifany"))
  if (any(esiti$esito %in% c("saltato", "senza_risposta"))) { cat("saltati e senza risposta:\n"); print(esiti[esiti$esito %in% c("saltato", "senza_risposta"), c("gse", "esito", "dettaglio")], row.names = FALSE) }
  cat(sprintf("token: ingresso %.0f, uscita %.0f; studi con l'ingresso oltre 100.000 token: %d; spesa %.2f dollari (listino, meta' per i lotti)\n",
              sum(esiti$t_in), sum(esiti$t_out), sum(esiti$t_in > 100000), sum(esiti$dollari)))
  vv <- voci[voci$gse %in% names(X), ]; mv <- misura_voci(vv, VG, L); per <- aggiungi_classi(mv$per); PER[[corsa]] <- per
  scrivi_csv(per, sprintf("30-per-voce-%s.csv", corsa))
  cat(sprintf("voci degli studi richiesti: %d (in %d studi); misurate %d; senza campioni di Gemma nella vista %d\n", nrow(vv), length(X), nrow(per), length(mv$senza)))
  q2 <- quota_studi(as.integer(R$chiuso), B, SEME); cat("  ", riga_q("c2 studi chiusi su studi con una risposta richiesta", q2), "\n", sep = "")
  ria <- riassumi_gemma(per, B, SEME)
  for (n in names(QUOTE_GEMMA)) cat(sprintf("  %s\n", riga_gemma(ria, n)))
  ria$corsa <- corsa; ria$insieme <- "tutte le voci misurate"; RIASSUNTO[[length(RIASSUNTO) + 1L]] <- ria
  CONTI[[corsa]] <- data.frame(corsa = corsa, studi = nrow(esiti), misurati = sum(esiti$esito == "misurato"), non_chiusi = sum(esiti$esito == "non_chiuso"),
                               saltati = sum(esiti$esito == "saltato"), senza_risposta = sum(esiti$esito == "senza_risposta"), rifiuti = sum(esiti$motivi == "rifiuto"),
                               troncate = sum(esiti$stop_reason == "max_tokens"), c2_chiusi = q2[["quota"]], c2_ic_basso = q2[["ic_basso"]], c2_ic_alto = q2[["ic_alto"]],
                               t_in = sum(esiti$t_in), t_out = sum(esiti$t_out), dollari = sum(esiti$dollari), stringsAsFactors = FALSE)
  cat("  accanto, senza previsione (gruppi identici | confronti ritrovati):\n")
  for (cl in c("classe_grandezza", "classe_fattori")) for (lv in sort(unique(per[[cl]]))) {
    d <- per[per[[cl]] == lv, ]; r <- riassumi_gemma(d, B, SEME)
    cat(sprintf("    %-28s voci %4d | %s | %s\n", lv, nrow(d), riga_gemma(r, "a_gruppi_identici"), riga_gemma(r, "b_confronti_ritrovati")))
    r$corsa <- corsa; r$insieme <- lv; RIASSUNTO[[length(RIASSUNTO) + 1L]] <- r
  }
}
scrivi_csv(do.call(rbind, RIASSUNTO), "30-riassunto.csv"); conti <- do.call(rbind, CONTI); scrivi_csv(conti, "30-corse.csv")

# ---- KC4 e KC5 -----------------------------------------------------------------------------------------------
spesa <- sum(conti$dollari) + sum(lotti$costo_prova)
cat("\n"); passa("KC4 la spesa contata da usage e' al massimo 75 dollari", spesa <= TETTO, sprintf("%.2f dollari (prove del percorso %.3f)", spesa, sum(lotti$costo_prova)))
tracciati <- suppressWarnings(system2("git", c("grep", "-l", "-E", shQuote("sk-ant-[A-Za-z0-9_-]{20,}")), stdout = TRUE, stderr = FALSE))
scritti <- suppressWarnings(system2("grep", c("-rlE", shQuote("sk-ant-[A-Za-z0-9_-]{20,}"), QUI, USCITE_C), stdout = TRUE, stderr = FALSE))
passa("KC5 la chiave non sta in nessun file tracciato o scritto dalla prova", length(tracciati) == 0L && length(scritti) == 0L,
      sprintf("file tracciati con una chiave: %d; file della prova con una chiave: %d", length(tracciati), length(scritti)))

# ---- c6: differenza appaiata con Mistral B0 e fra i Claude -----------------------------------------------------
appaia <- function(a, b) {
  com <- intersect(PER[[a]]$studio, PER[[b]]$studio); X <- PER[[a]][match(com, PER[[a]]$studio), ]; Y <- PER[[b]][match(com, PER[[b]]$studio), ]
  r <- appaiato_gemma(X, Y, B, SEME, c("x", "y")); r$x_corsa <- a; r$y_corsa <- b; r$voci <- length(com); r$studi <- length(unique(X$gse)); r
}
dici_app <- function(r, n) { z <- r[r$misura == n, ]
  sprintf("%s: %.1f%% contro %.1f%%, differenza %+.1f punti (IC95 %+.1f, %+.1f)", n, 100 * z$x, 100 * z$y, 100 * z$differenza, 100 * z$ic_basso, 100 * z$ic_alto) }
APP <- list()
cat("\nc6: differenza appaiata (prima corsa meno seconda), sulle voci degli studi che tutte e due hanno\n")
coppie <- c(lapply(CORSE, function(k) c(k, "M-rp11")), if ("opus-corsa1" %in% CORSE) lapply(setdiff(CORSE, "opus-corsa1"), function(k) c(k, "opus-corsa1")))
for (cp in coppie) { r <- appaia(cp[1], cp[2]); APP[[paste(cp, collapse = " - ")]] <- r
  cat(sprintf("  %s meno %s (%d voci, %d studi): %s; %s; %s\n", cp[1], cp[2], r$voci[1], r$studi[1], dici_app(r, "a_gruppi_identici"), dici_app(r, "b_confronti_ritrovati"), dici_app(r, "c_errori_non_elencati"))) }
scrivi_csv(do.call(rbind, APP), "30-appaiati.csv")

# ---- c7: stessi gruppi e stessi confronti fra due corse dei Claude ---------------------------------------------
cat("\nc7: studi con gli stessi gruppi e gli stessi confronti fra due corse (sugli studi che tutte e due hanno chiesto)\n")
C7 <- list()
if (length(CORSE) > 1L) for (cp in utils::combn(CORSE, 2L, simplify = FALSE)) {
  com <- intersect(names(RUN[[cp[1]]]$kc), names(RUN[[cp[2]]]$kc)); a <- RUN[[cp[1]]]$kc[com]; b <- RUN[[cp[2]]]$kc[com]
  q <- quota_studi(as.integer(a == b), B, SEME); nn <- sum(a == NON_CHIUSO & b == NON_CHIUSO)
  cat(sprintf("  %s = %s: %s; non chiusi in tutte e due %d (contano come «stessi»)\n", cp[1], cp[2], riga_q("stessi", q), nn))
  C7[[paste(cp, collapse = " = ")]] <- data.frame(a = cp[1], b = cp[2], studi = length(com), stessi = q[["num"]], quota = q[["quota"]], ic_basso = q[["ic_basso"]], ic_alto = q[["ic_alto"]], non_chiusi_in_due = nn)
}
if (length(C7)) scrivi_csv(do.call(rbind, C7), "30-c7.csv")

# ---- c8: l'accordo fra Mistral B0 e un altro lettore come filtro -----------------------------------------------
id_M <- PER[["M-rp11"]]$classe_gruppi %in% "identica"
tenuti <- function(altri, studi) { t <- M$kc[studi] != NON_CHIUSO
  for (a in altri) t <- t & RUN[[a]]$kc[studi] == M$kc[studi]; stats::setNames(t, studi) }
c8 <- function(nome, altri) {
  studi <- Reduce(intersect, c(list(mandati_M), lapply(altri, function(a) names(RUN[[a]]$kc)))); t <- tenuti(altri, studi)
  per <- PER[["M-rp11"]]; sel <- per$gse %in% studi; per <- per[sel, ]; idv <- id_M[sel]; tv <- unname(t[per$gse])
  estr <- estrazioni_per_studio(per$gse, B, SEME)
  f <- function(i) mean(idv[i][tv[i]]) - mean(idv[i][!tv[i]]); d <- vapply(estr, f, 0); qt <- quota_studi(as.integer(t), B, SEME)
  fk <- function(i) mean(idv[i][tv[i]]); dk <- vapply(estr, fk, 0)
  rt <- riassumi_gemma(per[tv, ], B, SEME)
  cat(sprintf("  %s\n    %s\n    gruppi identici a Gemma: fra i tenuti %d/%d = %.1f%% (IC95 %.1f-%.1f%%), fra i non tenuti %d/%d = %.1f%%; differenza %+.1f punti (IC95 %+.1f, %+.1f)\n    fra i tenuti: %s; %s\n",
              nome, riga_q("studi tenuti", qt), sum(idv & tv), sum(tv), 100 * mean(idv[tv]), 100 * stats::quantile(dk, 0.025), 100 * stats::quantile(dk, 0.975),
              sum(idv & !tv), sum(!tv), 100 * mean(idv[!tv]), 100 * f(seq_along(tv)), 100 * stats::quantile(d, 0.025, na.rm = TRUE), 100 * stats::quantile(d, 0.975, na.rm = TRUE),
              riga_gemma(rt, "b_confronti_ritrovati"), riga_gemma(rt, "c_errori_non_elencati")))
  list(nome = nome, studi = studi, tenuto = t, qt = qt, id_tenuti = mean(idv[tv]), diff = f(seq_along(tv)), diff_ic = unname(stats::quantile(d, c(0.025, 0.975), na.rm = TRUE)),
       riga = data.frame(accordo = nome, studi = length(studi), tenuti = sum(t), quota_tenuti = qt[["quota"]], tenuti_ic_basso = qt[["ic_basso"]], tenuti_ic_alto = qt[["ic_alto"]],
                         voci_tenute = sum(tv), identiche_tenute = sum(idv & tv), voci_non_tenute = sum(!tv), identiche_non_tenute = sum(idv & !tv),
                         differenza = f(seq_along(tv)), diff_ic_basso = unname(stats::quantile(d, 0.025, na.rm = TRUE)), diff_ic_alto = unname(stats::quantile(d, 0.975, na.rm = TRUE)),
                         ritrovati_tenuti = rt$numeratore[rt$misura == "b_confronti_ritrovati"], confronti_tenuti = rt$denominatore[rt$misura == "b_confronti_ritrovati"],
                         errori_tenuti = rt$numeratore[rt$misura == "c_errori_non_elencati"], giudicabili_tenuti = rt$denominatore[rt$misura == "c_errori_non_elencati"], stringsAsFactors = FALSE))
}
# la quota di voci identiche fra i tenuti da un accordo meno la stessa quota fra i tenuti da un altro, sugli stessi studi
c8_fra <- function(altri_x, altri_y) {
  studi <- Reduce(intersect, c(list(mandati_M), lapply(c(altri_x, altri_y), function(a) names(RUN[[a]]$kc))))
  per <- PER[["M-rp11"]]; sel <- per$gse %in% studi; per <- per[sel, ]; idv <- id_M[sel]
  tx <- unname(tenuti(altri_x, studi)[per$gse]); ty <- unname(tenuti(altri_y, studi)[per$gse]); estr <- estrazioni_per_studio(per$gse, B, SEME)
  f <- function(i) mean(idv[i][tx[i]]) - mean(idv[i][ty[i]]); d <- vapply(estr, f, 0)
  c(x = mean(idv[tx]), y = mean(idv[ty]), diff = f(seq_along(tx)), lo = unname(stats::quantile(d, 0.025, na.rm = TRUE)), hi = unname(stats::quantile(d, 0.975, na.rm = TRUE)), studi = length(studi))
}
cat("\nc8: l'accordo con Mistral B0 (stessi gruppi e stessi confronti) come filtro; voci misurate di Mistral\n")
C8 <- list(); C8[["GE-rp0"]] <- c8("Mistral = Gemma-4-31B (GE-rp0)", "GE-rp0")
for (k in CORSE) C8[[k]] <- c8(sprintf("Mistral = %s", k), k)
if ("opus-corsa1" %in% CORSE) C8[["tre"]] <- c8("Mistral = Gemma-4-31B = opus-corsa1 (accordo a tre)", c("GE-rp0", "opus-corsa1"))
scrivi_csv(do.call(rbind, lapply(C8, `[[`, "riga")), "30-c8.csv")

# ---- accanto: le voci dove Mistral e Opus hanno gli stessi gruppi e Gemma no ----------------------------------
if ("opus-corsa1" %in% CORSE) {
  O <- RUN[["opus-corsa1"]]; pm <- PER[["M-rp11"]]; po <- PER[["opus-corsa1"]]
  com <- intersect(pm$studio, po$studio); pm <- pm[match(com, pm$studio), ]; po <- po[match(com, po$studio), ]
  stessi_g <- M$kg[pm$gse] != "non chiuso" & O$kg[pm$gse] == M$kg[pm$gse]
  cat(sprintf("\nAccanto: voci degli studi che Mistral e Opus hanno tutti e due (%d voci)\n", length(com)))
  cat("  gruppi identici a Gemma, Mistral (righe) per Opus (colonne):\n"); print(table(mistral = pm$classe_gruppi %in% "identica", opus = po$classe_gruppi %in% "identica"))
  cat(sprintf("  voci di studi dove Mistral e Opus hanno gli stessi gruppi: %d; di queste con gruppi diversi da Gemma: %d\n", sum(stessi_g), sum(stessi_g & !(pm$classe_gruppi %in% "identica"))))
  cat("  classi di quelle voci (stessi gruppi Mistral = Opus, diversi da Gemma):\n"); print(table(pm$classe_gruppi[stessi_g & !(pm$classe_gruppi %in% "identica")]))
  cat("  classi di Mistral nelle voci non identiche a Gemma (righe) per «Mistral e Opus hanno gli stessi gruppi» (colonne):\n")
  print(table(classe_mistral = pm$classe_gruppi[!(pm$classe_gruppi %in% "identica")], stessi_gruppi_di_opus = stessi_g[!(pm$classe_gruppi %in% "identica")]))
  d <- data.frame(studio = pm$studio, gse = pm$gse, classe_mistral = pm$classe_gruppi, classe_opus = po$classe_gruppi, stessi_gruppi_mistral_opus = unname(stessi_g),
                  stessi_gruppi_e_confronti = unname(M$kc[pm$gse] != NON_CHIUSO & O$kc[pm$gse] == M$kc[pm$gse]),
                  n_gruppi_gemma = pm$n_gruppi_gemma, n_gruppi_mistral = pm$n_gruppi_lettore, n_gruppi_opus = po$n_gruppi_lettore, campioni_vista = pm$campioni_vista, fattori_gemma = pm$fattori_gemma, stringsAsFactors = FALSE)
  scrivi_csv(d, "30-voci-mistral-opus-gemma.csv")
}

# ---- le previsioni --------------------------------------------------------------------------------------------
cat("\nPrevisioni (carta 00-previsioni.md; il giudizio usa l'intervallo al 95%)\n")
ria_tutti <- do.call(rbind, RIASSUNTO); pren <- function(corsa, mis) ria_tutti[ria_tutti$corsa == corsa & ria_tutti$insieme == "tutte le voci misurate" & ria_tutti$misura == mis, ]
if ("opus-corsa1" %in% CORSE) {
  z <- conti[conti$corsa == "opus-corsa1", ]; prev("PC1", "Opus, studi chiusi (%)", "97", 93, 100, 100 * z$c2_chiusi, 100 * z$c2_ic_basso, 100 * z$c2_ic_alto)
  z <- pren("opus-corsa1", "a_gruppi_identici"); prev("PC2", "Opus, voci con gruppi identici a Gemma (%)", "72", 62, 80, 100 * z$quota, 100 * z$ic_basso, 100 * z$ic_alto)
  z <- APP[["opus-corsa1 - M-rp11"]]; z <- z[z$misura == "a_gruppi_identici", ]; prev("PC3", "Opus meno Mistral, gruppi identici (punti)", "+4", -5, 5, 100 * z$differenza, 100 * z$ic_basso, 100 * z$ic_alto)
  z <- pren("opus-corsa1", "b_confronti_ritrovati"); prev("PC4", "Opus, confronti di Gemma ritrovati (%)", "52", 40, 62, 100 * z$quota, 100 * z$ic_basso, 100 * z$ic_alto)
  z <- pren("opus-corsa1", "c_errori_non_elencati"); prev("PC5", "Opus, non elencati giudicati errore (%)", "30", 15, 45, 100 * z$quota, 100 * z$ic_basso, 100 * z$ic_alto)
  if ("haiku-corsa1" %in% CORSE) { z <- APP[["haiku-corsa1 - opus-corsa1"]]; z <- z[z$misura == "a_gruppi_identici", ]
    prev("PC6", "Haiku corsa 1 meno Opus, gruppi identici (punti)", "-2", -5, 5, 100 * z$differenza, 100 * z$ic_basso, 100 * z$ic_alto) }
  if ("sonnet-corsa1" %in% CORSE) { z <- APP[["sonnet-corsa1 - opus-corsa1"]]; n_v <- z$voci[1]; n_s <- z$studi[1]; z <- z[z$misura == "a_gruppi_identici", ]
    prev("PC7", "Sonnet meno Opus, gruppi identici (punti)", "0", -5, 5, 100 * z$differenza, 100 * z$ic_basso, 100 * z$ic_alto, sprintf("%d voci, %d studi", n_v, n_s)) }
}
if (all(c("haiku-corsa1", "haiku-corsa2") %in% CORSE)) { z <- C7[["haiku-corsa1 = haiku-corsa2"]]
  prev("PC8", "Haiku, stessi gruppi e confronti fra le due corse (%)", "80", 70, 90, 100 * z$quota, 100 * z$ic_basso, 100 * z$ic_alto) }
if ("opus-corsa1" %in% CORSE) {
  z <- C8[["opus-corsa1"]]; prev("PC9", "studi tenuti dall'accordo Mistral = Opus (%)", "65", 55, 78, 100 * z$qt[["quota"]], 100 * z$qt[["ic_basso"]], 100 * z$qt[["ic_alto"]])
  z <- c8_fra("opus-corsa1", "GE-rp0")
  prev("PC10", "identici fra i tenuti da Mistral = Opus meno fra i tenuti da Mistral = Gemma-4-31B (punti)", "+2", -5, 5, 100 * z[["diff"]], 100 * z[["lo"]], 100 * z[["hi"]],
       sprintf("%.1f%% contro %.1f%%, %d studi", 100 * z[["x"]], 100 * z[["y"]], as.integer(z[["studi"]])))
  z <- C8[["opus-corsa1"]]; prev("PC11", "tenuti meno non tenuti, accordo Mistral = Opus (punti)", "+40", 0, Inf, 100 * z$diff, 100 * z$diff_ic[1], 100 * z$diff_ic[2], "confermata = intervallo tutto sopra 0")
}
if (length(PREV)) scrivi_csv(do.call(rbind, PREV), "30-previsioni-esito.csv")
cat("\nFINE 30-misura.R\n")
