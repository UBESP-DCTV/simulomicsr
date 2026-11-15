# 20-schede.R — il campione e le schede della lettura dei disaccordi (carta: 00-previsioni.md, Parte 2).
#
#   Rscript analysis/audit/2026-11-15-disaccordi-con-gemma/20-schede.R <cartella delle schede, fuori dal repo> > .../20-out.txt 2>&1
#
# Campione: 120 voci fra le 545 chiuse con gruppi diversi (50 piu' fini, 40 piu' grosse, 30 incrociate), estratte con
# set.seed(20261115) dalle voci ordinate per nome dentro ogni classe, le classi in quest'ordine, un solo seme.
# Poi, dallo stesso flusso: l'ordine delle 124 schede (120 + 4 esche) e il lato del lettore (A o B) di ogni scheda.
# Decisioni tecniche (scritte prima delle letture):
#   - il nome di un fattore di Gemma si scrive senza il numero fra parentesi quadre (e' la sigla interna di Gemma);
#   - una riga del testo oltre 1.800 caratteri si spezza ai tabulatori, le righe di seguito cominciano con «    ↳ »:
#     cambia solo l'impaginazione; lo strumento di lettura degli agenti taglia le righe oltre 2.000 caratteri;
#   - ogni livello di un fattore sta su una riga sua; nessuna riga della scheda supera 1.900 caratteri (controllato);
#   - la scheda porta i livelli dei soli campioni della voce (l'universo della misura).
# Uscite: le schede S001.md ... nella cartella data; la chiave in analysis/p4-output/disaccordi-con-gemma/20-chiave.csv
# (fuori dalla cartella delle schede; entra nella cartella dell'audit dopo le letture); 20-out.txt.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
source("analysis/audit/2026-11-15-lettori-su-gemma/30-misura-contro-gemma.R")
QUI <- "analysis/audit/2026-11-15-disaccordi-con-gemma"; FUORI <- "analysis/p4-output/disaccordi-con-gemma"
a <- commandArgs(trailingOnly = TRUE); stopifnot(length(a) == 1L); SCHEDE <- a[1]; dir.create(SCHEDE, showWarnings = FALSE, recursive = TRUE)
stopifnot(!startsWith(normalizePath(SCHEDE), normalizePath(".")), length(list.files(SCHEDE)) == 0L)
SEME <- 20261115L; N_CAMP <- c(piu_fine = 50L, piu_grossa = 40L, incrociata = 30L); ESCHE <- c("GSE46665", "GSE60340", "GSE51261", "GSE71289")
cen <- utils::read.csv(file.path(QUI, "10-censimento-voci.csv"), stringsAsFactors = FALSE)
dv <- cen[cen$chiuso & cen$classe_gruppi != "identica", ]; stopifnot(nrow(dv) == 545L)
set.seed(SEME)
camp <- do.call(rbind, lapply(names(N_CAMP), function(cl) { z <- dv[dv$classe_gruppi == cl, ]; z <- z[order(z$studio, method = "radix"), ]
  z[sort(sample.int(nrow(z), N_CAMP[[cl]])), c("studio", "gse", "classe_gruppi")] }))
el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE); es <- utils::read.csv(file.path(G, "30-esiti.csv"), stringsAsFactors = FALSE)
voci <- es[es$esito == "tabella", ]; voci$gse <- el$gse[match(voci$shortName, el$shortName)]
esche <- data.frame(studio = vapply(ESCHE, function(g) voci$shortName[voci$gse == g & voci$parte == "sviluppo"], ""), gse = ESCHE, classe_gruppi = "esca", stringsAsFactors = FALSE)
tutte <- rbind(camp, esche); n <- nrow(tutte); stopifnot(n == 124L, !anyDuplicated(tutte$studio))
tutte$scheda <- sprintf("S%03d", order(sample.int(n))); tutte$lato_lettore <- sample(c("A", "B"), n, replace = TRUE)
tutte <- tutte[order(tutte$scheda), ]
div <- utils::read.csv(file.path(LG, "21-divisione.csv"), stringsAsFactors = FALSE)
stopifnot(all(camp$gse %in% div$gse[div$parte == "aperta"]))                                           # KD4 sul campione

VG <- lapply(readLines("analysis/input/gemma-viste-v0.jsonl", warn = FALSE, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
names(VG) <- vapply(VG, `[[`, "", "record_id")
L <- readRDS(list.files(FUORI, "^letture-M-rp11-tabelle-.*\\.rds$", full.names = TRUE))
cx <- leggi_uscite(file.path(USCITE_R5, "B0.jsonl"))
vuoto <- function(x) ifelse(is.na(x) | !nzchar(x), "(nessuno)", x)
spezza <- function(righe, lim = 1800L) unlist(lapply(righe, function(r) {
  if (nchar(r) <= lim) return(r)
  campi <- unlist(lapply(strsplit(r, "\t", fixed = TRUE)[[1]], function(f) if (nchar(f) <= lim) f else substring(f, seq(1L, nchar(f), lim), pmin(seq(1L, nchar(f), lim) + lim - 1L, nchar(f)))))
  out <- character(0); cur <- ""
  for (f in campi) { if (nzchar(cur) && nchar(cur) + nchar(f) + 1L > lim) { out <- c(out, cur); cur <- f } else cur <- if (nzchar(cur)) paste(cur, f, sep = "\t") else f }
  out <- c(out, cur); c(out[1], paste0("    ↳ ", out[-1]))
}))
disegno <- function(fattori, livelli, gemma) {
  nomi <- fattori$nome; mostra <- if (gemma) make.unique(trimws(sub("\\s*\\[[0-9]+\\]$", "", nomi)), sep = " n.") else nomi
  stopifnot(setequal(nomi, names(livelli)))
  righe <- unlist(lapply(seq_along(nomi), function(j) { t <- table(vuoto(as.character(livelli[[nomi[j]]])))
    c(sprintf("- fattore «%s» | tipo: %s | livello di base: %s | %d livelli:", mostra[j], vuoto(as.character(fattori$tipo[j])), vuoto(as.character(fattori$base[j])), length(t)),
      sprintf("    - «%s» (%d campioni)", names(t), as.integer(t))) }))
  per <- if (length(nomi)) do.call(paste, c(lapply(seq_along(nomi), function(j) sprintf("%s = «%s»", mostra[j], vuoto(as.character(livelli[[nomi[j]]])))), sep = "; ")) else rep("(nessun fattore: un gruppo solo)", nrow(livelli))
  list(righe = if (length(righe)) righe else "- (nessun fattore: tutti i campioni in un gruppo solo)", per = per, n_gruppi = length(unique(per)))
}
conti <- list()
for (i in seq_len(n)) {
  g <- tutte$gse[i]; nome <- tutte$studio[i]; esca <- tutte$classe_gruppi[i] == "esca"
  v <- if (esca) viste[[g]] else VG[[g]]
  Lr <- if (esca) adatta_forma(v, as.character(nullo(cx[[g]]$raw)), e_saltato(cx[[g]]), as.character(nullo(cx[[g]]$fine)), "B0") else L[[g]]
  x <- gemma_leggi(nome); r <- gemma_tabella(x$campioni, x$analisi, g); stopifnot(isTRUE(r$chiuso), isTRUE(Lr$chiuso))
  U <- sort(intersect(r$gsm, as.character(unlist(v$campioni))), method = "radix")
  lG <- r$tabella$livelli[match(U, r$tabella$campioni), , drop = FALSE]; lR <- Lr$tabella$livelli[match(U, Lr$tabella$campioni), , drop = FALSE]
  dG <- disegno(r$fattori[c("nome", "tipo", "base")], lG, TRUE); dR <- disegno(Lr$fattori[c("nome", "tipo", "base")], lR, FALSE)
  dA <- if (tutte$lato_lettore[i] == "A") dR else dG; dB <- if (tutte$lato_lettore[i] == "A") dG else dR
  tit <- vapply(U, function(s) { z <- v$tabella$title[[s]]; if (is.null(z)) "" else as.character(z) }, "")
  testo <- strsplit(as.character(v$testo), "\n", fixed = TRUE)[[1]]; testo_s <- spezza(testo)
  tab <- spezza(sprintf("%s\t%s\tA: %s\tB: %s", U, tit, dA$per, dB$per))
  righe <- c(sprintf("# Scheda %s", tutte$scheda[i]), "",
    sprintf("La scheda riguarda %d campioni su %d della tabella dello studio. I due disegni si giudicano solo su questi campioni.", length(U), length(unlist(v$campioni))), "",
    "## 1. Il testo dello studio", "", "```", testo_s, "```", "",
    sprintf("## 2. Disegno A (%d gruppi)", dA$n_gruppi), "", dA$righe, "",
    sprintf("## 3. Disegno B (%d gruppi)", dB$n_gruppi), "", dB$righe, "",
    "## 4. I campioni della scheda: campione, titolo, livelli nel disegno A, livelli nel disegno B", "", "```", tab, "```", "", sprintf("FINE DELLA SCHEDA %s", tutte$scheda[i]))
  righe <- spezza(righe); stopifnot(max(nchar(righe)) <= 1900L)
  f <- file.path(SCHEDE, paste0(tutte$scheda[i], ".md")); writeLines(enc2utf8(righe), f, useBytes = TRUE)
  conti[[i]] <- data.frame(scheda = tutte$scheda[i], righe = length(righe), caratteri = sum(nchar(righe)) + length(righe), riga_max = max(nchar(righe)),
    righe_spezzate = sum(nchar(testo) > 1800L), n_universo = length(U), gruppi_A = dA$n_gruppi, gruppi_B = dB$n_gruppi, stringsAsFactors = FALSE)
  rm(list = ls(.validatori_forma), envir = .validatori_forma)
}
conti <- do.call(rbind, conti); tutte <- merge(tutte, conti, by = "scheda")
utils::write.csv(tutte, file.path(FUORI, "20-chiave.csv"), row.names = FALSE)
cat(sprintf("schede scritte: %d (campione %d: %s; esche %d)\n", n, nrow(camp), paste(sprintf("%s %d", names(table(camp$classe_gruppi)), as.integer(table(camp$classe_gruppi))), collapse = ", "), nrow(esche)))
cat(sprintf("studi GEO nel campione: %d; lato del lettore: A %d, B %d\n", length(unique(camp$gse)), sum(tutte$lato_lettore == "A"), sum(tutte$lato_lettore == "B")))
cat(sprintf("grandezza delle schede: caratteri mediana %d, massimo %d (%s); righe mediana %d, massimo %d; schede oltre 2.000 righe: %d; riga piu' lunga: %d caratteri; schede con righe del testo spezzate: %d\n",
  as.integer(stats::median(tutte$caratteri)), max(tutte$caratteri), tutte$scheda[which.max(tutte$caratteri)], as.integer(stats::median(tutte$righe)), max(tutte$righe), sum(tutte$righe > 2000L), max(tutte$riga_max), sum(tutte$righe_spezzate > 0L)))
print(tutte[order(-tutte$caratteri), c("scheda", "righe", "caratteri", "riga_max", "n_universo", "gruppi_A", "gruppi_B")][1:12, ], row.names = FALSE)
