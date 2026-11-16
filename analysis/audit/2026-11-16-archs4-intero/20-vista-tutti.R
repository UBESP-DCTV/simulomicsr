# 20-vista-tutti.R — la vista dello studio (formato v0) per gli studi del bacino di ARCHS4.
#
# E' il programma della vista di ieri (analysis/audit/2026-11-15-lettori-su-gemma/20-vista-v0.R). Il codice che forma
# la vista (da «i testi GEO» alla fine di una_vista) e' copiato alla lettera da quel file. Cambiano solo: l'elenco degli studi (10-elenco.csv), il percorso dei testi GEO (una cartella per classe),
# la tabella dei campioni dell'H5 (una per studio, per non cercare un campione fra 500.000 righe), e la scrittura
# (una vista per volta, senza tenerle tutte in memoria). Lo prova il controllo positivo.
#
# INSIEME=controllo  i 47 studi di sviluppo e i 3.015 studi di Gemma, dai testi gia' congelati. Controllo positivo
#                    (cancello K1): ogni vista e' uguale byte per byte alla riga di 60-viste-v0.jsonl o di
#                    gemma-viste-v0.jsonl, e gli esclusi sono quelli di ieri. Scrive in una cartella temporanea.
# INSIEME=prova      i 540 studi nuovi del campione della prova (casuale e grandi).
# INSIEME=nuovo      tutti gli studi nuovi (21.249), a scarico finito.
# Gli studi di giudizio non entrano mai: lo script si ferma se uno studio della lista sta fra gli 82.
# Uno studio senza i due file dei testi nel manifesto esce con il motivo `senza_testi`. Uno studio senza campioni
# nella vista, o che non passa un controllo di forma, esce con il motivo. La vista non si taglia mai.
#
# Uso: INSIEME=prova Rscript analysis/audit/2026-11-16-archs4-intero/20-vista-tutti.R        (senza --vanilla)
# Uscite: analysis/input/archs4-viste-v0-<insieme>.jsonl, 20-per-studio-<insieme>.csv, 20-esclusi-<insieme>.csv,
#         20-out-<insieme>.txt.
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(jsonlite) })
DIR <- "analysis/audit/2026-11-16-archs4-intero"; S12R <- "analysis/audit/2026-11-09-lettore-studio"
LG <- "analysis/audit/2026-11-15-lettori-su-gemma"
INSIEME <- Sys.getenv("INSIEME"); stopifnot(INSIEME %in% c("controllo", "prova", "nuovo"))
el <- utils::read.csv(file.path(DIR, "10-elenco.csv"), stringsAsFactors = FALSE)
stopifnot(nrow(el) == 24393L, !anyDuplicated(el$gse))
DIVISIONE <- utils::read.delim(file.path(S12R, "30-divisione.tsv"), stringsAsFactors = FALSE)
GIUDIZIO <- DIVISIONE$gse[DIVISIONE$parte != "sviluppo"]; stopifnot(length(GIUDIZIO) == 82L, setequal(GIUDIZIO, el$gse[el$classe == "giudizio"]))
studi <- switch(INSIEME,
  controllo = el$gse[el$classe %in% c("sviluppo", "gemma_aperta", "gemma_chiusa")],
  prova = el$gse[el$classe == "nuovo" & el$prova %in% c("casuale", "grandi")],
  nuovo = el$gse[el$classe == "nuovo"])
studi <- studi[order(as.numeric(sub("GSE", "", studi)))]
stopifnot(!any(studi %in% GIUDIZIO), all(grepl("^GSE[0-9]+$", studi)))
F_VISTE <- if (INSIEME == "controllo") file.path(tempdir(), "viste-v0-controllo.jsonl") else sprintf("analysis/input/archs4-viste-v0-%s.jsonl", INSIEME)
F_OUT <- file.path(DIR, sprintf("20-out-%s.txt", INSIEME))
H5 <- "analysis/input/human_gene_v2.5.h5"
BACINO <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
CAR_PER_TOKEN <- 2.29; LIMITE_TOKEN <- 49152L
TECNICI <- c("library_strategy", "library_selection", "library_source", "molecule_ch1", "instrument_model", "platform_id")
DA_GEO <- c("description", "treatment_protocol_ch1", "growth_protocol_ch1")
FISSE <- c("gsm", "title", "source_name_ch1", TECNICI, DA_GEO)
SENZA_CHIAVE <- "characteristics (no key)"
norm <- .s2b_norm_testo

sink(F_OUT, split = TRUE)
cat("20-vista-tutti.R  INSIEME=", INSIEME, " ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n", sep = "")
prompt <- paste(readLines(file.path(S12R, "62-prompt-v0.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
cat("studi:", length(studi), "  caratteri del prompt di sistema:", nchar(prompt), "\n")

# ---- i manifesti dei testi GEO (uno per data di congelamento): i byte su disco tornano con lo SHA-256 scritto ----
leggi_man <- function(f, cartella) { m <- utils::read.delim(f, stringsAsFactors = FALSE, quote = ""); m$cartella <- rep(cartella, nrow(m)); m[c("file", "sha256", "cartella")] }
man <- rbind(leggi_man(file.path(S12R, "50-manifesto-geo.tsv"), "analysis/input/geo-testi-lettore-2026-11-09"),
             leggi_man(file.path(LG, "10-manifesto-geo.tsv"), "analysis/input/geo-testi-gemma-2026-11-15"),
             do.call(rbind, lapply(list.files(DIR, pattern = "^11-manifesto-geo(-[0-9]+)?[.]tsv$", full.names = TRUE), leggi_man,
                                   cartella = "analysis/input/geo-testi-archs4-2026-11-16")))
stopifnot(!anyDuplicated(man$file))
man$gse <- sub("[.].*$", "", man$file); stopifnot(!any(man$gse %in% GIUDIZIO))        # K5: nessun testo di uno studio di giudizio
man <- man[man$gse %in% studi, ]
con_testi <- intersect(studi, names(which(table(man$gse) == 2L)))
# la classe dello studio decide la cartella: un file di uno studio non puo' venire dalla cartella di un'altra classe
stopifnot(identical(man$cartella, el$testi[match(man$gse, el$gse)]))
man <- man[man$gse %in% con_testi, ]
PERCORSO <- stats::setNames(as.list(file.path(man$cartella, man$file)), man$file)
sha <- vapply(unlist(PERCORSO), function(p) digest::digest(p, algo = "sha256", file = TRUE), "")
stopifnot(all(sha == man$sha256))
cat("studi con i due file dei testi nel manifesto:", length(con_testi), "su", length(studi),
    "; file:", nrow(man), ", SHA-256 uguali al manifesto:", sum(sha == man$sha256), "\n")
senza_testi <- setdiff(studi, con_testi); studi_tutti <- studi; studi <- con_testi

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
M_TUTTI <- lapply(M, `[`, pos); rm(M)
RIGHE_DI <- split(seq_along(pos), rep(names(bacino), lengths(bacino)))
cat("campioni letti dall'H5:", length(pos), "\n")
# la tabella dei campioni di UNO studio, con la forma che il codice della vista si aspetta (righe col nome del campione)
m_dello_studio <- function(g) { d <- as.data.frame(lapply(M_TUTTI, `[`, RIGHE_DI[[g]]), stringsAsFactors = FALSE); rownames(d) <- d$geo_accession; d }

# ---- i testi GEO ----
non_utf8 <- character()
leggi_soft <- function(nome) {
  p <- PERCORSO[[nome]]; t <- rawToChar(readBin(p, "raw", file.size(p))); Encoding(t) <- "UTF-8"
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
vista_ora <- NULL; tab_out <- vector("list", length(studi))
tutti_cancellati <- character(); geo_fuori_bacino <- 0L
esclusi <- list()
una_vista <- function(g) {
  s <- leggi_soft(paste0(g, ".serie.soft.txt"))
  stopifnot(any(s == paste0("^SERIES = ", g)))
  b <- blocchi_campioni(leggi_soft(paste0(g, ".campioni.soft.txt")))
  cancellati <- setdiff(bacino[[g]], names(b)); tutti_cancellati <<- c(tutti_cancellati, cancellati)
  geo_fuori_bacino <<- geo_fuori_bacino + length(setdiff(names(b), bacino[[g]]))
  gsm <- setdiff(bacino[[g]], cancellati); gsm <- gsm[order(as.numeric(sub("GSM", "", gsm)))]
  if (length(gsm) == 0L) stop("studio senza campioni nella vista: ", g)
  car <- lapply(gsm, function(x) caratteristiche(M[x, "characteristics_ch1"], campo(b[[x]], "Sample_characteristics_ch1")))
  chiavi <- unique(unlist(lapply(car, names)))
  tab <- data.frame(gsm = gsm, title = norm(M[gsm, "title"]), source_name_ch1 = norm(M[gsm, "source_name_ch1"]),
                    stringsAsFactors = FALSE, check.names = FALSE)
  conta[["title_diverso_da_geo"]] <<- conta[["title_diverso_da_geo"]] +
    sum(tab$title != vapply(gsm, function(x) norm(una_riga(campo(b[[x]], "Sample_title"))), ""))
  conta[["source_diverso_da_geo"]] <<- conta[["source_diverso_da_geo"]] +
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
  vista_ora <<- list(
    record_id = g, testo = testo, campioni = I(gsm), colonne = I(variabili),
    costanti = if (length(costanti)) lapply(tab[costanti], `[`, 1L) else stats::setNames(list(), character()),
    tabella = if (length(variabili)) lapply(tab[variabili], function(v) as.list(stats::setNames(v, gsm))) else stats::setNames(list(), character()))
  tok <- ceiling((nchar(testo) + nchar(prompt)) / CAR_PER_TOKEN)
  tab_out[[match(g, studi)]] <<- data.frame(
    gse = g, campioni = length(gsm), cancellati = length(cancellati), colonne_non_costanti = length(variabili),
    colonne_costanti = length(costanti), colonne_vuote = length(vuote), caratteri = nchar(testo), token_stimati = tok,
    oltre_49152 = as.integer(tok > LIMITE_TOKEN), senza_riassunto = as.integer(!length(campo(s, "Series_summary"))),
    senza_disegno = as.integer(!length(campo(s, "Series_overall_design"))), stringsAsFactors = FALSE)
}

# ---- una vista per studio, scritta subito ----
con <- file(F_VISTE, "wb")
for (g in studi) {
  M <- m_dello_studio(g); vista_ora <- NULL
  e <- tryCatch({ una_vista(g); NULL }, error = function(e) conditionMessage(e))
  if (!is.null(e)) { esclusi[[g]] <- data.frame(gse = g, motivo = e, stringsAsFactors = FALSE); next }
  riga <- enc2utf8(as.character(jsonlite::toJSON(vista_ora, auto_unbox = TRUE)))
  # rilettura: la riga scritta rida' lo stesso testo e la stessa tabella
  rl <- jsonlite::fromJSON(riga, simplifyVector = FALSE)
  stopifnot(identical(rl$record_id, g), identical(rl$testo, vista_ora$testo), identical(unlist(rl$tabella), unlist(vista_ora$tabella)),
            identical(as.character(unlist(rl$campioni)), as.character(vista_ora$campioni)))
  writeLines(riga, con, useBytes = TRUE)
}
close(con)
tab_out <- do.call(rbind, tab_out)
tab_out <- tab_out[!tab_out$gse %in% names(esclusi), ]      # uno studio che fallisce dopo la riga dei conti non ha una vista
esclusi <- rbind(if (length(esclusi)) do.call(rbind, esclusi) else data.frame(gse = character(), motivo = character()),
                 data.frame(gse = senza_testi, motivo = rep("senza_testi", length(senza_testi)), stringsAsFactors = FALSE))
rownames(esclusi) <- NULL
id_scritti <- sub('^\\{"record_id":"(GSE[0-9]+)".*$', "\\1", readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"))
stopifnot(identical(id_scritti, tab_out$gse), nrow(tab_out) + nrow(esclusi) == length(studi_tutti), !any(id_scritti %in% GIUDIZIO))
cat("studi con la vista:", nrow(tab_out), "su", length(studi_tutti), "; esclusi:", nrow(esclusi), "\n")
if (nrow(esclusi)) print(table(sub("GSE[0-9]+", "<GSE>", esclusi$motivo)))

cat("\nTotali: campioni nella vista", sum(tab_out$campioni), " campioni del bacino cancellati da GEO", length(tutti_cancellati),
    " in", sum(tab_out$cancellati > 0L), "studi\n")
cat("campioni nel testo GEO e fuori dal bacino (non entrano nella vista):", geo_fuori_bacino, "\n")
cat("token stimati: mediana", stats::median(tab_out$token_stimati), " massimo", max(tab_out$token_stimati),
    " studi oltre", LIMITE_TOKEN, ":", sum(tab_out$oltre_49152), "\n")
cat("studi senza riassunto:", sum(tab_out$senza_riassunto), " senza disegno complessivo:", sum(tab_out$senza_disegno), "\n")
cat("file GEO non UTF-8 (byte sostituiti con U+FFFD):", length(non_utf8), paste(utils::head(non_utf8, 20), collapse = " "), "\n")
cat("\nContatori (per campione, o per riga di caratteristiche):\n"); print(as.data.frame(conta))
SHA <- unname(tools::sha256sum(F_VISTE)); cat("\nSHA-256 del file delle viste:", SHA, "\n")

# ---- chiusura ----
if (INSIEME == "controllo") {
  # cancello K1: ogni vista e' uguale byte per byte alla riga congelata; gli esclusi sono quelli di ieri
  nuove <- readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"); names(nuove) <- id_scritti
  per_id <- function(f) { r <- readLines(f, warn = FALSE, encoding = "UTF-8"); stats::setNames(r, sub('^\\{"record_id":"(GSE[0-9]+)".*$', "\\1", r)) }
  v_sv <- per_id(file.path(S12R, "60-viste-v0.jsonl")); v_ge <- per_id("analysis/input/gemma-viste-v0.jsonl")
  stopifnot(identical(unname(tools::sha256sum(file.path(S12R, "60-viste-v0.jsonl"))), "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"),
            length(v_sv) == 47L, length(v_ge) == 3014L, !any(names(v_sv) %in% names(v_ge)))
  congelate <- c(v_sv, v_ge)
  esclusi_ieri <- utils::read.csv(file.path(LG, "20-esclusi.csv"), stringsAsFactors = FALSE)
  uguali <- sum(nuove[names(congelate)] == congelate, na.rm = TRUE)
  cat(sprintf("CONTROLLO POSITIVO (K1): viste uguali byte per byte alle righe congelate %d su %d (sviluppo %d su 47, Gemma %d su 3.014); esclusi adesso %d (%s), ieri %d (%s)\n",
              uguali, length(congelate), sum(nuove[names(v_sv)] == v_sv, na.rm = TRUE), sum(nuove[names(v_ge)] == v_ge, na.rm = TRUE),
              nrow(esclusi), paste(esclusi$gse, collapse = " "), nrow(esclusi_ieri), paste(esclusi_ieri$gse, collapse = " ")))
  stopifnot(setequal(names(nuove), names(congelate)), uguali == length(congelate), identical(sort(esclusi$gse), sort(esclusi_ieri$gse)),
            identical(esclusi$motivo[match(esclusi_ieri$gse, esclusi$gse)], esclusi_ieri$motivo))
  cat("K1 PASSA\n")
} else {
  utils::write.csv(tab_out, file.path(DIR, sprintf("20-per-studio-%s.csv", INSIEME)), row.names = FALSE)
  utils::write.csv(esclusi, file.path(DIR, sprintf("20-esclusi-%s.csv", INSIEME)), row.names = FALSE)
  cat("FINE:", nrow(tab_out), "studi con la vista,", nrow(esclusi), "esclusi con il motivo, su", length(studi_tutti), "\n")
}
sink()
