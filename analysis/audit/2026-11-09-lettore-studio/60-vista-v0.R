# PROVA DA BUTTARE
# 60-vista-v0.R — S12r, Task 9, passo 3: la vista dello studio (formato v0) per i 47 studi di sviluppo.
#
# Che cosa vede il modello (spec §5.1):
#   1. SERIES <GSE>, Title, Summary, Overall design      dal testo dello studio congelato da GEO;
#   2. CONSTANT COLUMNS                                   le colonne con un solo valore, una riga «nome: valore»;
#   3. SAMPLE TABLE                                       TSV, una riga per campione, solo le colonne non costanti.
# Colonne: gsm, title, source_name_ch1, una colonna per chiave di characteristics_ch1, i sei campi tecnici
# (dall'H5 di ARCHS4), description, treatment_protocol_ch1, growth_protocol_ch1 (da GEO congelato).
# I campioni dello studio sono quelli del bacino (ingresso dello Stadio 1 v2) con series_id = GSE.
# Un campione del bacino assente dal testo GEO di oggi (cancellato) esce dallo studio e si conta.
# La vista non si taglia mai: un prompt oltre 49.152 token stimati si segnala soltanto.
#
# Le caratteristiche: l'H5 unisce le righe «chiave: valore» con una virgola, e una virgola puo' stare anche in
# un valore. Se la stringa dell'H5 e' uguale alle righe di GEO unite con la virgola (dopo .s2b_norm_testo), i
# confini sono quelli delle righe di GEO. Se e' diversa, vale l'H5, diviso con la regola di
# 10-token-per-studio.py (virgola seguita da «chiave: »), e il campione si conta.
#
# K5: lo script legge solo gli studi con parte == sviluppo (solo_sviluppo() ferma tutto il resto).
# Uso: Rscript analysis/audit/2026-11-09-lettore-studio/60-vista-v0.R        (senza --vanilla)
# Uscite: 60-viste-v0.jsonl (record_id, testo, campioni, colonne, costanti, tabella), 60-out.txt.
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(jsonlite) })
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")
H5 <- "analysis/input/human_gene_v2.5.h5"
BACINO <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
TESTI <- "analysis/input/geo-testi-lettore-2026-11-09"
CAR_PER_TOKEN <- 2.29; LIMITE_TOKEN <- 49152L
TECNICI <- c("library_strategy", "library_selection", "library_source", "molecule_ch1", "instrument_model", "platform_id")
DA_GEO <- c("description", "treatment_protocol_ch1", "growth_protocol_ch1")
FISSE <- c("gsm", "title", "source_name_ch1", TECNICI, DA_GEO)
SENZA_CHIAVE <- "characteristics (no key)"
norm <- .s2b_norm_testo

sink(file.path(DIR, "60-out.txt"), split = TRUE)
cat("60-vista-v0.R  PROVA DA BUTTARE ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n", sep = "")
studi <- studi_sviluppo(); solo_sviluppo(studi)
prompt <- paste(readLines(file.path(DIR, "62-prompt-v0.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
cat("studi di sviluppo:", length(studi), "  caratteri del prompt di sistema:", nchar(prompt), "\n")

# ---- il manifesto dei testi GEO: i byte su disco tornano con lo SHA-256 scritto ----
man <- utils::read.delim(file.path(DIR, "50-manifesto-geo.tsv"), stringsAsFactors = FALSE)
stopifnot(nrow(man) == 2L * length(studi),
          setequal(man$file, c(paste0(studi, ".serie.soft.txt"), paste0(studi, ".campioni.soft.txt"))))
sha <- vapply(file.path(TESTI, man$file), function(p) digest::digest(p, algo = "sha256", file = TRUE), "")
stopifnot(all(sha == man$sha256))
cat("testi GEO congelati:", nrow(man), "file, SHA-256 uguali al manifesto:", sum(sha == man$sha256), "\n")

# ---- il bacino: i campioni di ogni studio ----
righe <- readLines(BACINO, warn = FALSE)
stopifnot(length(righe) == 508037L)
serie <- sub('^.*"series_id":"([^"]*)".*$', "\\1", righe); gsm_b <- sub('^.*"geo_accession":"(GSM[0-9]+)".*$', "\\1", righe)
stopifnot(all(grepl("^GSM[0-9]+$", gsm_b)))
tieni <- serie %in% studi
bacino <- split(gsm_b[tieni], serie[tieni]); rm(righe, serie, gsm_b)
stopifnot(setequal(names(bacino), studi), !anyDuplicated(unlist(bacino)))
cat("campioni del bacino nei", length(studi), "studi:", sum(lengths(bacino)), "\n")

# ---- l'H5: i campi interi (h5read con index= sulle stringhe va in segfault) ----
campi_h5 <- c("geo_accession", "title", "source_name_ch1", "characteristics_ch1", TECNICI)
M <- lapply(stats::setNames(campi_h5, campi_h5), function(k) as.character(rhdf5::h5read(H5, paste0("meta/samples/", k))))
rhdf5::h5closeAll()
pos <- match(unlist(bacino), M$geo_accession)
stopifnot(!anyNA(pos), !anyDuplicated(M$geo_accession[pos]))
M <- as.data.frame(lapply(M, `[`, pos), stringsAsFactors = FALSE); rownames(M) <- M$geo_accession
cat("campioni letti dall'H5:", nrow(M), "\n")

# ---- i testi GEO ----
non_utf8 <- character()
leggi_soft <- function(nome) {
  p <- file.path(TESTI, nome); t <- rawToChar(readBin(p, "raw", file.size(p))); Encoding(t) <- "UTF-8"
  if (!validUTF8(t)) { non_utf8 <<- c(non_utf8, nome); t <- iconv(t, "UTF-8", "UTF-8", sub = "�") }
  strsplit(gsub("\r\n", "\n", t, fixed = TRUE), "\n", fixed = TRUE)[[1]]
}
campo <- function(blocco, nome) { p <- paste0("!", nome, " = "); substring(blocco[startsWith(blocco, p)], nchar(p) + 1L) }
blocchi_campioni <- function(r) {
  inizio <- which(startsWith(r, "^")); fine <- c(inizio[-1] - 1L, length(r))
  e <- startsWith(r[inizio], "^SAMPLE = "); out <- list()
  for (i in which(e)) out[[sub("^\\^SAMPLE = ", "", r[inizio[i]])]] <- r[seq.int(inizio[i] + 1L, length.out = fine[i] - inizio[i])]
  out
}

# ---- le caratteristiche di un campione: vettore con nome «chiave» -> valore ----
conta <- c(car_concordi = 0L, car_diverse = 0L, car_vuote = 0L, righe_senza_chiave = 0L, chiavi_doppie = 0L,
           chiavi_come_campo_fisso = 0L, title_diverso_da_geo = 0L, source_diverso_da_geo = 0L)
dividi_h5 <- function(x) if (!nzchar(x)) character() else strsplit(x, ",(?=[^,:]{1,60}: )", perl = TRUE)[[1]]
caratteristiche <- function(h5, geo_righe) {
  h5 <- norm(h5); geo_righe <- norm(geo_righe); geo_righe <- geo_righe[nzchar(geo_righe)]
  if (!nzchar(h5)) { conta[["car_vuote"]] <<- conta[["car_vuote"]] + 1L; return(character()) }
  if (identical(h5, norm(paste(geo_righe, collapse = ",")))) {
    conta[["car_concordi"]] <<- conta[["car_concordi"]] + 1L; r <- geo_righe
  } else { conta[["car_diverse"]] <<- conta[["car_diverse"]] + 1L; r <- norm(dividi_h5(h5)) }
  due <- regexpr(":", r, fixed = TRUE)
  chiave <- ifelse(due > 1L, trimws(substring(r, 1L, due - 1L)), ""); valore <- ifelse(due > 1L, trimws(substring(r, due + 1L)), r)
  vuota <- !nzchar(chiave) | nchar(chiave) > 60L
  conta[["righe_senza_chiave"]] <<- conta[["righe_senza_chiave"]] + sum(vuota)
  valore[vuota] <- r[vuota]; chiave[vuota] <- SENZA_CHIAVE
  fissa <- chiave %in% FISSE
  conta[["chiavi_come_campo_fisso"]] <<- conta[["chiavi_come_campo_fisso"]] + sum(fissa)
  chiave[fissa] <- paste0(chiave[fissa], " (characteristics)")
  conta[["chiavi_doppie"]] <<- conta[["chiavi_doppie"]] + sum(duplicated(chiave))
  vapply(split(valore, factor(chiave, levels = unique(chiave))), paste, "", collapse = "; ")
}

# ---- una vista per studio ----
una_riga <- function(x) paste(x, collapse = " ")
viste <- vector("list", length(studi)); names(viste) <- studi; tab_out <- vector("list", length(studi))
tutti_cancellati <- character(); geo_fuori_bacino <- 0L
for (g in studi) {
  s <- leggi_soft(paste0(g, ".serie.soft.txt"))
  stopifnot(any(s == paste0("^SERIES = ", g)))
  b <- blocchi_campioni(leggi_soft(paste0(g, ".campioni.soft.txt")))
  cancellati <- setdiff(bacino[[g]], names(b)); tutti_cancellati <- c(tutti_cancellati, cancellati)
  geo_fuori_bacino <- geo_fuori_bacino + length(setdiff(names(b), bacino[[g]]))
  gsm <- setdiff(bacino[[g]], cancellati); gsm <- gsm[order(as.numeric(sub("GSM", "", gsm)))]
  if (length(gsm) == 0L) stop("studio senza campioni nella vista: ", g)
  car <- lapply(gsm, function(x) caratteristiche(M[x, "characteristics_ch1"], campo(b[[x]], "Sample_characteristics_ch1")))
  chiavi <- unique(unlist(lapply(car, names)))
  tab <- data.frame(gsm = gsm, title = norm(M[gsm, "title"]), source_name_ch1 = norm(M[gsm, "source_name_ch1"]),
                    stringsAsFactors = FALSE, check.names = FALSE)
  conta[["title_diverso_da_geo"]] <- conta[["title_diverso_da_geo"]] +
    sum(tab$title != vapply(gsm, function(x) norm(una_riga(campo(b[[x]], "Sample_title"))), ""))
  conta[["source_diverso_da_geo"]] <- conta[["source_diverso_da_geo"]] +
    sum(tab$source_name_ch1 != vapply(gsm, function(x) norm(una_riga(campo(b[[x]], "Sample_source_name_ch1"))), ""))
  for (k in chiavi) tab[[k]] <- vapply(car, function(v) if (k %in% names(v)) v[[k]] else "", "")
  for (k in TECNICI) tab[[k]] <- norm(M[gsm, k])
  for (k in DA_GEO) tab[[k]] <- vapply(gsm, function(x) norm(una_riga(campo(b[[x]], paste0("Sample_", k)))), "")
  stopifnot(!anyDuplicated(names(tab)), !any(grepl("[\t\n\r]", unlist(tab))), !any(grepl("[\t\n\r]", names(tab))))

  dati <- setdiff(names(tab), "gsm"); n_val <- vapply(tab[dati], function(v) length(unique(v)), 1L)
  vuote <- dati[vapply(tab[dati], function(v) all(!nzchar(v)), TRUE)]
  costanti <- setdiff(dati[n_val == 1L], vuote); variabili <- dati[n_val > 1L]
  testa <- c(sprintf("SERIES %s", g),
             sprintf("Title: %s", norm(una_riga(campo(s, "Series_title")))),
             sprintf("Summary: %s", norm(una_riga(campo(s, "Series_summary")))),
             sprintf("Overall design: %s", norm(una_riga(campo(s, "Series_overall_design")))))
  righe_tab <- c(paste(c("gsm", variabili), collapse = "\t"), do.call(paste, c(unname(tab[c("gsm", variabili)]), sep = "\t")))
  testo <- paste(c(testa, "", "CONSTANT COLUMNS", sprintf("%s: %s", costanti, vapply(tab[costanti], `[`, "", 1L)),
                   "", "SAMPLE TABLE", righe_tab), collapse = "\n")
  # controllo: ogni riga della tabella ha tante tabulazioni quante sono le colonne non costanti
  stopifnot(all(lengths(regmatches(righe_tab, gregexpr("\t", righe_tab, fixed = TRUE))) == length(variabili)))
  viste[[g]] <- list(
    record_id = g, testo = testo, campioni = I(gsm), colonne = I(variabili),
    costanti = if (length(costanti)) lapply(tab[costanti], `[`, 1L) else stats::setNames(list(), character()),
    tabella = if (length(variabili)) lapply(tab[variabili], function(v) as.list(stats::setNames(v, gsm))) else stats::setNames(list(), character()))
  tok <- ceiling((nchar(testo) + nchar(prompt)) / CAR_PER_TOKEN)
  tab_out[[match(g, studi)]] <- data.frame(
    gse = g, campioni = length(gsm), cancellati = length(cancellati), colonne_non_costanti = length(variabili),
    colonne_costanti = length(costanti), colonne_vuote = length(vuote), caratteri = nchar(testo), token_stimati = tok,
    oltre_49152 = as.integer(tok > LIMITE_TOKEN), senza_riassunto = as.integer(!length(campo(s, "Series_summary"))),
    senza_disegno = as.integer(!length(campo(s, "Series_overall_design"))), stringsAsFactors = FALSE)
}
tab_out <- do.call(rbind, tab_out)

# ---- uscite ----
con <- file(file.path(DIR, "60-viste-v0.jsonl"), "wb")
for (v in viste) writeLines(enc2utf8(as.character(jsonlite::toJSON(v, auto_unbox = TRUE))), con, useBytes = TRUE)
close(con)
# rilettura: il file scritto ridà gli stessi testi e le stesse tabelle
rl <- lapply(readLines(file.path(DIR, "60-viste-v0.jsonl"), warn = FALSE, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
stopifnot(length(rl) == length(studi), identical(vapply(rl, `[[`, "", "record_id"), studi),
          all(vapply(seq_along(rl), function(i) identical(rl[[i]]$testo, viste[[i]]$testo) &&
                       identical(unlist(rl[[i]]$tabella), unlist(viste[[i]]$tabella)) &&
                       identical(unlist(rl[[i]]$campioni), as.character(viste[[i]]$campioni)), TRUE)))

cat("\nPer studio (token stimati = (caratteri della vista + caratteri del prompt) /", CAR_PER_TOKEN, "):\n")
print(tab_out, row.names = FALSE)
cat("\nTotali: studi con la vista", nrow(tab_out), "su", length(studi), " campioni nella vista", sum(tab_out$campioni),
    " campioni del bacino cancellati da GEO", length(tutti_cancellati),
    if (length(tutti_cancellati)) paste0(" (", paste(tutti_cancellati, collapse = " "), ")") else "", "\n")
cat("campioni nel testo GEO e fuori dal bacino (non entrano nella vista):", geo_fuori_bacino, "\n")
cat("token stimati: mediana", stats::median(tab_out$token_stimati), " massimo", max(tab_out$token_stimati),
    " studi oltre", LIMITE_TOKEN, ":", sum(tab_out$oltre_49152),
    if (any(tab_out$oltre_49152 == 1L)) paste0(" (", paste(tab_out$gse[tab_out$oltre_49152 == 1L], collapse = " "), ")") else "", "\n")
cat("studi senza riassunto:", sum(tab_out$senza_riassunto), " senza disegno complessivo:", sum(tab_out$senza_disegno), "\n")
cat("file GEO non UTF-8 (byte sostituiti con U+FFFD):", length(non_utf8), paste(non_utf8, collapse = " "), "\n")
cat("\nContatori (per campione, o per riga di caratteristiche):\n"); print(as.data.frame(conta))

# ---- controllo: ogni campione dell'universo delle misure (Atlas e bacino) sta nella vista o e' cancellato ----
leg <- utils::read.delim(file.path(DIR, "33-legame.tsv"), stringsAsFactors = FALSE)
leg <- leg[leg$gse %in% studi & leg$nel_bacino == 1L, ]
nella_vista <- unlist(lapply(viste, function(v) as.character(v$campioni)))
fuori <- setdiff(unique(leg$gsm), c(nella_vista, tutti_cancellati))
cat("\nuniverso delle misure (Atlas e bacino):", length(unique(leg$gsm)), "campioni; nella vista",
    sum(unique(leg$gsm) %in% nella_vista), "; cancellati", sum(unique(leg$gsm) %in% tutti_cancellati), "; ne' l'uno ne' l'altro", length(fuori), "\n")
stopifnot(length(fuori) == 0L, nrow(tab_out) == 47L)
cat("FINE: 47 studi su 47, nessuno saltato\n")
sink()
