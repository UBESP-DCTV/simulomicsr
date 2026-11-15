# 10-censimento.R — il censimento dei disaccordi fra Mistral `B0` (corsa M-rp11) e i curatori di Gemma sulla
# parte APERTA (carta: 00-previsioni.md, Parte 1). Non chiama nessun modello.
#
#   Rscript analysis/audit/2026-11-15-disaccordi-con-gemma/10-censimento.R > .../10-out.txt 2>&1     (SENZA --vanilla)
#
# Decisioni tecniche (scritte prima dei numeri):
#   - un fattore costante sull'universo della voce non entra nelle prove «raffina» delle classi dei livelli (ogni
#     fattore raffina un fattore costante);
#   - PD5, voce con piu' fattori persi: «ha una colonna nella vista» = TUTTI i fattori persi ne hanno una;
#   - PD4: tipi del lettore `contesto` e `tempo`;
#   - le partizioni degli altri lettori vengono dalla cache della misura dei Claude (chiave = impronta dell'uscita);
#     la classe contro Gemma degli altri lettori si riforma qui dalle partizioni e si confronta con i file della
#     misura dove esistono (30-per-voce-<corsa>.csv);
#   - la tabella dei fattori di Mistral si riforma con adatta_forma() (la cache della misura non la tiene) e si
#     salva in analysis/p4-output/disaccordi-con-gemma/ per le schede.
# Uscite: 10-censimento-voci.csv (una riga per voce misurata), 10-fattori.csv (una riga per fattore in piu' o perso),
#         10-riassunto.csv (le quote con l'intervallo), 10-out.txt.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")            # legge SOLO i 47 studi di sviluppo
source("analysis/audit/2026-11-15-lettori-su-gemma/30-misura-contro-gemma.R")      # LG, G, gemma_leggi, gemma_tabella
QUI <- "analysis/audit/2026-11-15-disaccordi-con-gemma"; CS <- "analysis/audit/2026-11-15-claude-su-gemma"
SEME <- 20261115L; B <- 10000L
USCITE_G <- "analysis/p4-output/lettori-su-gemma-B0"; USCITE_C <- "analysis/p4-output/claude-su-gemma-V"
CACHE_C <- file.path(USCITE_C, "cache-letture"); FUORI <- "analysis/p4-output/disaccordi-con-gemma"
dir.create(FUORI, showWarnings = FALSE, recursive = TRUE)
F_VISTE <- "analysis/input/gemma-viste-v0.jsonl"; F_INGRESSO <- "analysis/input/gemma-b0-ingresso-aperta.jsonl"
passa <- function(che, ok, dett = "") {
  cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else ""))
  if (!isTRUE(ok)) stop("CANCELLO FALLITO: ", che, call. = FALSE)
}
cat("10-censimento.R ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n")

# ---- le funzioni del censimento -------------------------------------------------------------------------------
SEP <- "\u001f"
chiave_liv <- function(liv, S) if (!length(S)) rep("1", nrow(liv)) else do.call(paste, c(unname(as.list(liv[S])), sep = SEP))
raffina <- function(a, b) all(tapply(b, a, function(x) length(unique(x))) == 1L)      # a raffina b
uguale <- function(a, b) raffina(a, b) && raffina(b, a)
costante <- function(x) length(unique(x)) == 1L
classe_gruppi_di <- function(p, q) if (uguale(p, q)) "identica" else if (raffina(p, q)) "piu_fine" else if (raffina(q, p)) "piu_grossa" else "incrociata"
livelli_su <- function(tab, U) {
  stopifnot(all(U %in% tab$campioni)); l <- tab$livelli[match(U, tab$campioni), , drop = FALSE]; rownames(l) <- U; l
}
# Il censimento di una voce: lR, lG = i livelli del lettore e di Gemma sull'universo (righe nello stesso ordine).
censisci <- function(lR, lG) {
  pR <- chiave_liv(lR, names(lR)); pG <- chiave_liv(lG, names(lG))
  in_piu <- names(lR)[!vapply(names(lR), function(h) raffina(pG, lR[[h]]), NA)]
  persi <- names(lG)[!vapply(names(lG), function(f) raffina(pR, lG[[f]]), NA)]
  pR1 <- chiave_liv(lR, setdiff(names(lR), in_piu)); pG1 <- chiave_liv(lG, setdiff(names(lG), persi))
  cg <- classe_gruppi_di(pR, pG)
  stretto <- function(x, y) !costante(x) && !costante(y) && raffina(x, y) && !raffina(y, x)
  fini <- any(vapply(in_piu, function(h) any(vapply(names(lG), function(f) stretto(lR[[h]], lG[[f]]), NA)), NA))
  grossi <- any(vapply(persi, function(f) any(vapply(names(lR), function(h) stretto(lG[[f]], lR[[h]]), NA)), NA))
  classe <- if (cg == "identica") "identica"
    else if (!length(persi) && length(in_piu) && uguale(pR1, pG)) "fattore_in_piu"
    else if (!length(in_piu) && length(persi) && uguale(pR, pG1)) "fattore_in_meno"
    else if (length(in_piu) && length(persi) && uguale(pR1, pG1)) "fattori_in_piu_e_in_meno"
    else if (fini && !grossi) "livelli_piu_fini" else if (grossi && !fini) "livelli_piu_grossi" else "altro"
  list(classe_gruppi = cg, classe = classe, in_piu = in_piu, persi = persi, pR = pR, pG = pG)
}

# ---- KD5 (i): lo studio finto ---------------------------------------------------------------------------------
dfr <- function(...) data.frame(..., stringsAsFactors = FALSE, check.names = FALSE)
tr <- rep(c("a", "b"), each = 4); ce <- rep(c("x", "y"), 4); te <- rep(c("t1", "t1", "t2", "t2"), 2)
finti <- list(
  identica = list(dfr(t = tr), dfr(f = tr)),
  fattore_in_piu = list(dfr(t = tr, c = ce), dfr(f = tr)),
  fattore_in_meno = list(dfr(t = tr), dfr(f = tr, c = ce)),
  fattori_in_piu_e_in_meno = list(dfr(t = tr, c = ce), dfr(f = tr, g = te)),
  livelli_piu_fini = list(dfr(t = c("a1", "a1", "a2", "a2", "b", "b", "b", "b")), dfr(f = tr)),
  livelli_piu_grossi = list(dfr(t = tr), dfr(f = c("a1", "a1", "a2", "a2", "b", "b", "b", "b"))),
  altro = list(dfr(h1 = rep(c("x", "y"), each = 4), h2 = c("1", "2", "3", "3", "1", "1", "2", "2")), dfr(f = rep(c("a", "b", "c", "d"), each = 2))))
visti <- vapply(finti, function(z) censisci(z[[1]], z[[2]])$classe, "")
passa("KD5 (i) lo studio finto: le sei classi attese e la voce identica", identical(unname(visti), names(finti)), paste(visti, collapse = ", "))

# ---- l'oggetto ------------------------------------------------------------------------------------------------
el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
es <- utils::read.csv(file.path(G, "30-esiti.csv"), stringsAsFactors = FALSE)
voci <- es[es$esito == "tabella", ]; voci$gse <- el$gse[match(voci$shortName, el$shortName)]
voci <- voci[order(voci$gse, voci$shortName, method = "radix"), ]
leggi_corsa <- function(f) { x <- leggi_jsonl(f); names(x) <- vapply(x, `[[`, "", "record_id"); stopifnot(!anyDuplicated(names(x))); x }
lettura_studio <- function(v, x) adatta_forma(v, as.character(nullo(x$raw)), e_saltato(x), as.character(nullo(x$fine)), "B0")
campioni_di <- function(v) as.character(unlist(v$campioni))
div <- utils::read.csv(file.path(LG, "21-divisione.csv"), stringsAsFactors = FALSE)
aperti <- div$gse[div$parte == "aperta"]; chiusi_g <- div$gse[div$parte == "chiusa"]
atlas_div <- utils::read.delim("analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv", stringsAsFactors = FALSE)
VG <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
names(VG) <- vapply(VG, `[[`, "", "record_id")

# ---- KD1: le impronte ------------------------------------------------------------------------------------------
imp_l <- readLines(file.path(LG, "40-uscite-sha256.txt")); imp_c <- readLines(file.path(CS, "20-uscite-sha256.txt"))
imp_i <- readLines(file.path(LG, "22-ingresso-sha256.txt"))
impronta_ok <- function(f, righe) any(righe == sprintf("%s  %s", sha(f), f))
CORSE_C <- c("haiku-corsa1", "haiku-corsa2", "sonnet-corsa1", "opus-corsa1")
f_corse <- c(file.path(USCITE_G, c("M-rp11.jsonl", "GE-rp0.jsonl")), file.path(USCITE_C, paste0(CORSE_C, ".jsonl")))
ok1 <- c(vapply(f_corse[1:2], impronta_ok, NA, righe = imp_l), vapply(f_corse[-(1:2)], impronta_ok, NA, righe = imp_c),
         impronta_ok(F_INGRESSO, imp_i))
passa("KD1 le uscite M-rp11 e GE-rp0, le uscite dei Claude e l'ingresso hanno le impronte congelate", all(ok1), sprintf("%d file su %d", sum(ok1), length(ok1)))
cache_di <- function(corsa, f) {
  p <- file.path(CACHE_C, sprintf("letture-%s-%s.rds", corsa, substr(sha(f), 1L, 16L)))
  if (!file.exists(p)) stop("cache delle letture non trovata: ", p); readRDS(p)
}
ALTRI <- list(`GE-rp0` = cache_di("GE-rp0", f_corse[2]))
for (i in seq_along(CORSE_C)) ALTRI[[CORSE_C[i]]] <- cache_di(CORSE_C[i], f_corse[2L + i])
cat("letture degli altri lettori nella cache:", paste(sprintf("%s %d", names(ALTRI), lengths(ALTRI)), collapse = "; "), "\n")

# ---- KD5 (ii): i due studi di sviluppo noti -------------------------------------------------------------------
tab_gemma <- function(nome, gse) { x <- gemma_leggi(nome); list(x = x, r = gemma_tabella(x$campioni, x$analisi, gse)) }
colonne_che_raffinano <- function(v, U, x) {
  nomi <- setdiff(names(v$tabella), c("title", "description"))
  ok <- vapply(nomi, function(cn) { val <- vapply(U, function(s) { z <- v$tabella[[cn]][[s]]; if (is.null(z) || !length(z) || is.na(z)) "" else as.character(z) }, "")
    !costante(val) && length(unique(val)) < length(U) && raffina(val, x) }, NA)
  nomi[ok]
}
cx <- leggi_uscite(file.path(USCITE_R5, "B0.jsonl"))
noto <- function(g) {
  nome <- voci$shortName[voci$gse == g & voci$parte == "sviluppo"]; stopifnot(length(nome) == 1L)
  tg <- tab_gemma(nome, g)$r; Ls <- lettura_studio(viste[[g]], cx[[g]]); stopifnot(isTRUE(Ls$chiuso))
  U <- sort(intersect(tg$gsm, campioni_di(viste[[g]])), method = "radix")
  lR <- livelli_su(Ls$tabella, U); lG <- livelli_su(tg$tabella, U); k <- censisci(lR, lG)
  list(classe = k$classe, in_piu = k$in_piu, persi = k$persi, fonti = Ls$fattori$fonti[match(k$in_piu, Ls$fattori$nome)],
       colonne = unlist(lapply(k$persi, function(f) colonne_che_raffinano(viste[[g]], U, lG[[f]]))))
}
n1 <- noto("GSE60340"); n2 <- noto("GSE46665")
# KD5 (ii) come scritto nella carta. SCOSTAMENTO (2026-11-15, dopo la prima corsa, prima di ogni numero sulla parte
# aperta): la carta attende GSE46665 = livelli_piu_fini. E' un errore della carta, non dello strumento: in GSE46665 il
# lettore scrive le sigle dei pazienti come un fattore a parte (`disease`, dalla colonna source_name_ch1) accanto al
# trattamento; tolto quel fattore i gruppi sono quelli di Gemma. La classe giusta per definizione e' fattore_in_piu.
# Il cancello alla lettera si riporta come fallito e non ferma la corsa; il controllo corretto qui sotto la ferma.
ok_lettera <- n1$classe == "fattore_in_meno" && length(n1$colonne) >= 1L && n2$classe == "livelli_piu_fini"
cat(sprintf("%s  KD5 (ii) alla lettera della carta (GSE60340 = fattore_in_meno con una colonna; GSE46665 = livelli_piu_fini): GSE60340 %s (colonne: %s); GSE46665 %s\n",
            if (ok_lettera) "PASSA " else "FALLISCE", n1$classe, paste(n1$colonne, collapse = " | "), n2$classe))
passa("KD5 (ii) corretto, dichiarato dopo il fallimento: GSE60340 = fattore_in_meno con una colonna nella vista; GSE46665 = fattore_in_piu, il fattore in piu' e' `disease` da source_name_ch1",
      n1$classe == "fattore_in_meno" && length(n1$colonne) >= 1L && n2$classe == "fattore_in_piu" && identical(n2$in_piu, "disease") && identical(n2$fonti, "source_name_ch1"),
      sprintf("GSE60340 %s, perso: %s; GSE46665 %s, in piu': %s (%s)", n1$classe, paste(n1$persi, collapse = " | "), n2$classe, paste(n2$in_piu, collapse = " | "), paste(n2$fonti, collapse = " | ")))
# Accanto (dichiarato dopo il fallimento, senza attesa scritta prima): gli altri studi di sviluppo con una causa gia' letta.
for (g in c("GSE51261", "GSE71289", "GSE56787", "GSE57945")) { z <- noto(g)
  cat(sprintf("  noto %s: %s; in piu': %s; persi: %s\n", g, z$classe, paste(z$in_piu, collapse = " | "), paste(z$persi, collapse = " | "))) }

# ---- le letture di Mistral con la tabella dei fattori ---------------------------------------------------------
X <- leggi_corsa(f_corse[1]); stopifnot(all(names(X) %in% aperti), !any(names(X) %in% chiusi_g), !any(names(X) %in% atlas_div$gse))
f_tab <- file.path(FUORI, sprintf("letture-M-rp11-tabelle-%s.rds", substr(sha(f_corse[1]), 1L, 16L)))
if (file.exists(f_tab)) L <- readRDS(f_tab) else {
  L <- stats::setNames(lapply(seq_along(X), function(i) { g <- names(X)[i]
    r <- lettura_studio(VG[[g]], X[[g]])
    rm(list = ls(.validatori_forma), envir = .validatori_forma); if (i %% 25L == 0L) invisible(gc())
    if (i %% 200L == 0L) cat(sprintf("  letture di Mistral: %d su %d (%s)\n", i, length(X), format(Sys.time(), "%H:%M")))
    r[c("chiuso", "motivi", "tabella", "fattori", "partizione")] }), names(X))
  saveRDS(L, f_tab)
}
M0 <- ALTRI[["GE-rp0"]]; rm(M0)
cm <- cache_di("M-rp11", f_corse[1])
stopifnot(setequal(names(cm), names(L)), all(vapply(names(L), function(g) identical(isTRUE(L[[g]]$chiuso), isTRUE(cm[[g]]$chiuso)) &&
  (!isTRUE(L[[g]]$chiuso) || identical(L[[g]]$partizione[order(names(L[[g]]$partizione))], cm[[g]]$partizione[order(names(cm[[g]]$partizione))])), NA)))
cat(sprintf("letture di Mistral riformate: %d studi, %d chiusi; uguali alla cache della misura\n", length(L), sum(vapply(L, function(r) isTRUE(r$chiuso), NA))))

# ---- il censimento di ogni voce misurata ----------------------------------------------------------------------
per <- utils::read.csv(file.path(LG, "41-per-voce-M-rp11.csv"), stringsAsFactors = FALSE)
stopifnot(nrow(per) == 2052L, !anyDuplicated(per$studio), all(per$studio %in% voci$shortName))
fattori_tolti <- function(x, r) {                     # i livelli dei fattori di Gemma che l'adattatore toglie (blocco, continuo)
  tolti <- r$fattori_gemma$fattore[!is.na(r$fattori_gemma$motivo_uscita)]; if (!length(tolti)) return(list())
  gsm <- vapply(x$campioni, function(z) as.character(z$accession$accession), "")
  stats::setNames(lapply(tolti, function(f) stats::setNames(vapply(x$campioni, function(z) {
    v <- Filter(function(w) identical(as.character(w$experimentalFactorId), f), z$sample$fvbasicVOs %||% list())
    if (length(v)) as.character(v[[1]]$id) else "" }, ""), gsm)), tolti)
}
classe_altro <- function(a, U, pG, pR) {              # un altro lettore sulla stessa voce
  if (is.null(a)) return(c(classe = NA, come_mistral = NA))
  if (!isTRUE(a$chiuso)) return(c(classe = "non_chiuso", come_mistral = FALSE))
  if (!all(U %in% names(a$partizione))) return(c(classe = "campioni_mancanti", come_mistral = FALSE))
  p <- unname(a$partizione[U]); c(classe = classe_gruppi_di(p, pG), come_mistral = if (is.null(pR)) FALSE else uguale(p, pR))
}
righe <- list(); fatt <- list()
for (i in seq_len(nrow(per))) {
  nome <- per$studio[i]; g <- per$gse[i]; tg <- tab_gemma(nome, g); r <- tg$r; stopifnot(isTRUE(r$chiuso))
  v <- VG[[g]]; U <- sort(intersect(r$gsm, campioni_di(v)), method = "radix"); stopifnot(length(U) == per$n_universo[i])
  lG <- livelli_su(r$tabella, U); pG <- chiave_liv(lG, names(lG))
  stopifnot(uguale(pG, unname(r$partizione[U])))                                    # KD2: partizione riformata = scritta (Gemma)
  Lr <- L[[g]]; chiuso <- isTRUE(Lr$chiuso); k <- NULL; pR <- NULL
  if (chiuso) {
    lR <- livelli_su(Lr$tabella, U); k <- censisci(lR, lG); pR <- k$pR
    stopifnot(uguale(pR, unname(Lr$partizione[U])))                                 # KD2: partizione riformata = scritta (lettore)
    tol <- fattori_tolti(tg$x, r)
    for (h in k$in_piu) { j <- match(h, Lr$fattori$nome)
      fatt[[length(fatt) + 1L]] <- data.frame(studio = nome, gse = g, lato = "in_piu_del_lettore", fattore = h, tipo = Lr$fattori$tipo[j],
        colonna = Lr$fattori$fonti[j], per_campione = isTRUE(Lr$fattori$per_campione[j]), n_livelli = length(unique(lR[[h]])),
        uguale_a_un_fattore_tolto = any(vapply(tol, function(z) !costante(z[U]) && uguale(unname(z[U]), lR[[h]]), NA)),
        categoria_gemma = NA_character_, colonne_nella_vista = NA_character_, stringsAsFactors = FALSE) }
    for (f in k$persi) { j <- match(f, r$fattori$nome); cn <- colonne_che_raffinano(v, U, lG[[f]])
      fatt[[length(fatt) + 1L]] <- data.frame(studio = nome, gse = g, lato = "perso_di_gemma", fattore = f, tipo = r$fattori$tipo[j],
        colonna = NA_character_, per_campione = NA, n_livelli = length(unique(lG[[f]])), uguale_a_un_fattore_tolto = NA,
        categoria_gemma = r$fattori$categoria[j], colonne_nella_vista = paste(cn, collapse = " | "), stringsAsFactors = FALSE) }
  }
  al <- lapply(ALTRI, function(A) classe_altro(A[[g]], U, pG, pR))
  riga <- data.frame(studio = nome, gse = g, chiuso = chiuso, classe_gruppi = if (chiuso) k$classe_gruppi else "non_chiuso",
    classe = if (chiuso) k$classe else "non_chiuso", motivi = if (chiuso) "" else paste(Lr$motivi, collapse = " | "),
    n_universo = length(U), n_fattori_gemma = ncol(lG), n_fattori_lettore = if (chiuso) ncol(lR) else NA_integer_,
    n_in_piu = if (chiuso) length(k$in_piu) else NA_integer_, n_persi = if (chiuso) length(k$persi) else NA_integer_,
    in_piu = if (chiuso) paste(k$in_piu, collapse = " | ") else "", persi = if (chiuso) paste(k$persi, collapse = " | ") else "",
    note_gemma = paste(r$note, collapse = " | "), stringsAsFactors = FALSE)
  for (n in names(al)) { riga[[paste0("classe_", n)]] <- al[[n]][["classe"]]; riga[[paste0("come_mistral_", n)]] <- as.logical(al[[n]][["come_mistral"]]) }
  righe[[i]] <- riga
  if (i %% 400L == 0L) cat(sprintf("  censimento: %d voci su %d\n", i, nrow(per)))
}
cen <- do.call(rbind, righe); fat <- do.call(rbind, fatt)
passa("KD2 la classe dei gruppi riformata dalle due tabelle e' quella di 41-per-voce-M-rp11.csv riga per riga",
      identical(cen$classe_gruppi, per$classe_gruppi) && identical(as.integer(table(factor(cen$classe_gruppi, c("identica", "piu_fine", "piu_grossa", "incrociata", "non_chiuso")))), c(1377L, 307L, 156L, 82L, 130L)),
      paste(sprintf("%s %d", names(table(cen$classe_gruppi)), as.integer(table(cen$classe_gruppi))), collapse = ", "))
dv <- cen[cen$chiuso & cen$classe_gruppi != "identica", ]
passa("KD3 (censimento) 545 voci su 545 con una classe, 130 su 130 con un motivo",
      nrow(dv) == 545L && all(dv$classe %in% names(finti)[-1]) && sum(!cen$chiuso) == 130L && all(nzchar(cen$motivi[!cen$chiuso])),
      sprintf("%d voci chiuse con gruppi diversi, %d non chiuse", nrow(dv), sum(!cen$chiuso)))
passa("KD4 nessuno studio della parte chiusa, di giudizio o di sviluppo nel censimento",
      all(cen$gse %in% aperti) && !any(cen$gse %in% chiusi_g) && !any(cen$gse %in% atlas_div$gse), sprintf("%d studi GEO, tutti aperti", length(unique(cen$gse))))
# la classe degli altri lettori riformata qui = quella dei file della misura dei Claude
for (n in CORSE_C) { pc <- utils::read.csv(file.path(CS, sprintf("30-per-voce-%s.csv", n)), stringsAsFactors = FALSE)
  m <- match(pc$studio, cen$studio); qui <- cen[[paste0("classe_", n)]][m]
  cat(sprintf("  %s: %d voci nel file della misura, classe uguale in %d\n", n, nrow(pc), sum(qui == pc$classe_gruppi, na.rm = TRUE))) }
utils::write.csv(cen, file.path(QUI, "10-censimento-voci.csv"), row.names = FALSE, na = "")
utils::write.csv(fat, file.path(QUI, "10-fattori.csv"), row.names = FALSE, na = "")

# ---- le quote, con l'intervallo dal ricampionamento degli studi GEO -------------------------------------------
quota_ic <- function(num, den, gse) {
  estr <- estrazioni_per_studio(gse, B, SEME)
  v <- vapply(estr, function(ii) if (sum(den[ii]) > 0) sum(num[ii]) / sum(den[ii]) else NA_real_, 0)
  c(num = sum(num), den = sum(den), quota = sum(num) / sum(den), stats::quantile(v, c(0.025, 0.975), na.rm = TRUE, names = FALSE))
}
ris <- list(); agg <- function(nome, num, den, gse) { q <- quota_ic(as.numeric(num), as.numeric(den), gse)
  ris[[length(ris) + 1L]] <<- data.frame(misura = nome, num = q[[1]], den = q[[2]], quota = q[[3]], ic_basso = q[[4]], ic_alto = q[[5]], stringsAsFactors = FALSE)
  cat(sprintf("%s: %d/%d = %.1f%% (IC95 %.1f-%.1f%%)\n", nome, as.integer(q[[1]]), as.integer(q[[2]]), 100 * q[[3]], 100 * q[[4]], 100 * q[[5]])) }
TRE <- c("GE-rp0", "haiku-corsa1", "sonnet-corsa1")
id3 <- rowSums(sapply(TRE, function(n) dv[[paste0("classe_", n)]] %in% "identica")); cm3 <- rowSums(sapply(TRE, function(n) dv[[paste0("come_mistral_", n)]] %in% TRUE))
cat("\n== Le classi del censimento (545 voci chiuse con gruppi diversi) ==\n"); print(table(dv$classe_gruppi, dv$classe))
cat("\n== Le previsioni del censimento ==\n")
agg("PD1 almeno uno dei tre altri lettori ha i gruppi di Gemma", id3 >= 1, rep(1, nrow(dv)), dv$gse)
agg("PD2 almeno due dei tre altri lettori hanno i gruppi di Mistral", cm3 >= 2, rep(1, nrow(dv)), dv$gse)
agg("PD3 voci nelle tre classi a fattori interi", dv$classe %in% c("fattore_in_piu", "fattore_in_meno", "fattori_in_piu_e_in_meno"), rep(1, nrow(dv)), dv$gse)
fp <- dv[dv$classe == "fattore_in_piu", ]; tipi_ok <- vapply(fp$studio, function(s) all(fat$tipo[fat$studio == s & fat$lato == "in_piu_del_lettore"] %in% c("contesto", "tempo")), NA)
agg("PD4 fattore_in_piu: tutti i fattori in piu' sono di contesto o di tempo", tipi_ok, rep(1, nrow(fp)), fp$gse)
fm <- dv[dv$classe %in% c("fattore_in_meno", "fattori_in_piu_e_in_meno"), ]
col_ok <- vapply(fm$studio, function(s) all(nzchar(fat$colonne_nella_vista[fat$studio == s & fat$lato == "perso_di_gemma"])), NA)
agg("PD5 fattore perso con una colonna nella vista (tutte le voci con un fattore perso intero)", col_ok, rep(1, nrow(fm)), fm$gse)
agg("PD6 errori fra i non elencati che stanno in voci con gruppi diversi", ifelse(per$classe_gruppi != "identica", per$n_errori, 0), per$n_errori, per$gse)
cat("\n== Accanto ==\n")
agg("tutti e tre gli altri lettori hanno i gruppi di Mistral", cm3 == 3, rep(1, nrow(dv)), dv$gse)
agg("nessuno dei tre altri lettori ha i gruppi di Gemma", id3 == 0, rep(1, nrow(dv)), dv$gse)
for (n in names(ALTRI)) { z <- dv[!is.na(dv[[paste0("classe_", n)]]), ]
  agg(sprintf("%s ha i gruppi di Gemma (voci dove ha letto)", n), z[[paste0("classe_", n)]] %in% "identica", rep(1, nrow(z)), z$gse)
  agg(sprintf("%s ha i gruppi di Mistral (voci dove ha letto)", n), z[[paste0("come_mistral_", n)]] %in% TRUE, rep(1, nrow(z)), z$gse) }
for (cl in c("piu_fine", "piu_grossa", "incrociata")) { z <- dv$classe_gruppi == cl
  agg(sprintf("%s: almeno uno dei tre altri lettori ha i gruppi di Gemma", cl), (id3 >= 1)[z], rep(1, sum(z)), dv$gse[z])
  agg(sprintf("%s: tutti e tre hanno i gruppi di Mistral", cl), (cm3 == 3)[z], rep(1, sum(z)), dv$gse[z]) }
cat("\nfattori in piu' del lettore, per tipo (voci fattore_in_piu):\n"); print(table(fat$tipo[fat$lato == "in_piu_del_lettore" & fat$studio %in% fp$studio]))
cat("fattori in piu' del lettore uguali a un fattore tolto dall'adattatore (tutte le voci): ", sum(fat$uguale_a_un_fattore_tolto %in% TRUE), "su", sum(fat$lato == "in_piu_del_lettore"), "\n")
cat("\nfattori persi di Gemma, per categoria (tutte le voci), con e senza una colonna nella vista:\n")
fpz <- fat[fat$lato == "perso_di_gemma", ]; print(table(fpz$categoria_gemma, ifelse(nzchar(fpz$colonne_nella_vista), "con_colonna", "senza_colonna")))
cat("\nvoci non chiuse, per motivo (una voce puo' avere piu' motivi):\n"); print(sort(table(unlist(strsplit(cen$motivi[!cen$chiuso], " | ", fixed = TRUE))), decreasing = TRUE))
cat("\nerrori fra i non elencati, per classe dei gruppi della voce e per motivo:\n")
print(stats::aggregate(cbind(n_errori, n_piu_fattori_nostri, n_braccio_misto, n_giudicabili) ~ classe_gruppi, per, sum))
utils::write.csv(do.call(rbind, ris), file.path(QUI, "10-riassunto.csv"), row.names = FALSE)
cat("\nfine ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n")
