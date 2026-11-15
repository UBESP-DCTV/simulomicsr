# 31-curatori-contro-curatori.R — i curatori di Gemma contro i curatori di Atlas sui 21 studi di sviluppo che
# hanno un disegno di Gemma, con Mistral-Small 3.2 nella forma B0 (corsa congelata) accanto. Carta: 00-previsioni.md.
#   Rscript analysis/audit/2026-11-15-gemma-riferimento/31-curatori-contro-curatori.R   (SENZA --vanilla)
# Legge SOLO studi con parte == sviluppo (cancello K4). Stesse funzioni e stesso riferimento della terza prova
# (cancello K5): misura_r3(), 95 confronti sui 47 studi.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
source("analysis/audit/2026-11-15-gemma-riferimento/30-adattatore-gemma.R")   # G, GEMMA_DIR, gemma_leggi, gemma_tabella
SEME <- 20261115L; B <- 10000L                                # depositati in 00-previsioni.md
scrivi <- function(d, f) utils::write.csv(d, file.path(G, f), row.names = FALSE, na = "")
controllo_positivo()                                          # K2

# ---- K1: Mistral B0 sui 47 studi ----------------------------------------------------------------------------
m <- misura_forma(leggi_uscite(file.path(USCITE_R5, "B0.jsonl")), "B0")
t3 <- tre_numeri(m$tab)
stopifnot(t3[["chiusi"]] == 45L, t3[["identici"]] == 36L, t3[["ritrovati"]] == 68L, t3[["den"]] == 95L)
cat(sprintf("K1: Mistral B0 sui 47 studi: %d chiusi, %d gruppi identici, %d/%d confronti ritrovati\n", t3[["chiusi"]], t3[["identici"]], t3[["ritrovati"]], t3[["den"]]))

# ---- i 21 studi (K4: solo sviluppo) -------------------------------------------------------------------------
el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
el <- el[el$parte == "sviluppo", ]; el <- el[order(el$gse, method = "radix"), ]
stopifnot(nrow(el) == 21L, all(el$gse %in% sv$gse), !anyDuplicated(el$gse), all(sv$parte[match(el$gse, sv$gse)] == "sviluppo"))
studi <- el$gse
cat(sprintf("K4: %d studi, tutti di sviluppo\n", length(studi)))

insiemi <- function(p, U) { p <- p[names(p) %in% U]; unname(sort(vapply(split(names(p), unname(p)), camp_ins, ""), method = "radix")) }   # senza i nomi dei gruppi: contano i campioni
gem <- stats::setNames(lapply(seq_along(studi), function(i) { x <- gemma_leggi(el$shortName[i]); gemma_tabella(x$campioni, x$analisi, studi[i]) }), studi)
stopifnot(all(vapply(gem, function(r) !is.null(r$esito), NA)))                    # K3 sui 21: 21 esiti

misura_di <- function(g, r, x) {                               # r: lista con chiuso, partizione, confronti
  t <- if (r$chiuso) misura_r3(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
    misura_r3(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
  for (k in NOMI_R3) { if (!r$chiuso) t[[k]]$riga$classe_gruppi <- "non_chiuso"; t[[k]]$riga$chiuso <- r$chiuso }
  t
}
MG <- MM <- list(); righe <- list()
for (g in studi) {
  x <- rif[[g]]; r <- gem[[g]]; ml <- m$lett[[g]]
  U <- if (r$chiuso) sort(intersect(x$universo, r$gsm), method = "radix") else x$universo   # regola 7
  xg <- x; xg$universo <- U
  MG[[g]] <- misura_di(g, r, xg); MM[[g]] <- misura_di(g, ml, xg)
  pg <- MG[[g]]$principale$riga; pm <- MM[[g]]$principale$riga; pi <- m$per_studio$principale[match(g, sv$gse), ]
  stessi <- r$chiuso && ml$chiuso && identical(insiemi(r$partizione, U), insiemi(ml$partizione, U))
  righe[[g]] <- data.frame(
    studio = g, voce_gemma = el$shortName[match(g, el$gse)], esito_gemma = r$esito, chiuso_gemma = r$chiuso,
    n_gemma = length(r$gsm), n_universo_atlas = length(x$universo), n_universo = length(U),
    atlas_fuori_da_gemma = length(setdiff(x$universo, r$gsm)), gemma_fuori_da_atlas = length(setdiff(r$gsm, x$universo)),
    fattori_gemma = unisci(sprintf("%s=%s%s", r$fattori$nome, r$fattori$tipo, ifelse(is.na(r$fattori$base), "", paste0(" (base: ", r$fattori$base, ")")))),
    note_gemma = unisci(unique(sub(":.*$", "", r$note))),
    gruppi_gemma = length(insiemi(r$partizione, U)), gruppi_atlas = length(insiemi(x$atlas$partizione, U)),
    gruppi_mistral = if (ml$chiuso) length(insiemi(ml$partizione, U)) else NA_integer_,
    classe_gemma = pg$classe_gruppi, classe_mistral = pm$classe_gruppi, classe_mistral_universo_intero = pi$classe_gruppi,
    den = pg$n_b_den, ritrovati_gemma = pg$n_b_uguale, verso_opposto_gemma = pg$n_b_verso_opposto, ritrovati_mistral = pm$n_b_uguale,
    den_universo_intero = pi$n_b_den, ritrovati_mistral_universo_intero = pi$n_b_uguale,
    confronti_gemma = pg$n_nostri, non_elencati_gemma = pg$n_non_elencati, giudicabili_gemma = pg$n_giudicabili, errori_gemma = pg$n_errori,
    giudicabili_mistral = pm$n_giudicabili, errori_mistral = pm$n_errori,
    gemma_uguale_a_mistral = stessi, chiuso_mistral = ml$chiuso, stringsAsFactors = FALSE)
  stopifnot(pg$n_b_den == pm$n_b_den)                          # stesso riferimento per i due
}
per <- do.call(rbind, righe); rownames(per) <- NULL
scrivi(per, "31-per-studio.csv")
PG <- stats::setNames(lapply(NOMI_R3, function(k) do.call(rbind, lapply(MG, function(z) z[[k]]$riga))), NOMI_R3)
PM <- stats::setNames(lapply(NOMI_R3, function(k) do.call(rbind, lapply(MM, function(z) z[[k]]$riga))), NOMI_R3)
stopifnot(all(vapply(PG, nrow, 0L) == 21L), all(vapply(PM, nrow, 0L) == 21L))
cat(sprintf("K3: 21 studi, 21 esiti dell'adattatore (%s)\n", unisci(sprintf("%s %d", names(table(per$esito_gemma)), as.integer(table(per$esito_gemma))))))
cat(sprintf("Regola 7: campioni dell'universo di Atlas fuori dalla voce di Gemma: %d in %d studi (%s); campioni di Gemma fuori dall'universo di Atlas: %d in %d studi\n",
            sum(per$atlas_fuori_da_gemma), sum(per$atlas_fuori_da_gemma > 0),
            unisci(sprintf("%s %d/%d", per$studio, per$atlas_fuori_da_gemma, per$n_universo_atlas)[per$atlas_fuori_da_gemma > 0]),
            sum(per$gemma_fuori_da_atlas), sum(per$gemma_fuori_da_atlas > 0)))

# ---- le misure e le previsioni -------------------------------------------------------------------------------
rg <- lapply(PG, tf_riassumi_misure, B = B, seme = SEME); rm_ <- lapply(PM, tf_riassumi_misure, B = B, seme = SEME)
riass <- do.call(rbind, lapply(NOMI_R3, function(k) rbind(cbind(chi = "gemma", misura_r3 = k, rg[[k]]), cbind(chi = "mistral_B0", misura_r3 = k, rm_[[k]]))))
scrivi(riass, "31-riassunto.csv")
app <- do.call(rbind, lapply(NOMI_R3, function(k) cbind(misura_r3 = k, appaiato(PG[[k]], PM[[k]], c("gemma", "mistral_B0")))))
scrivi(app, "31-appaiato.csv")
una <- function(r, nome) r[r$misura == nome, ]
stampa <- function(chi, r) for (n in c("a_gruppi_identici", "b_confronti_ritrovati", "c_errori_non_elencati", "verso_opposto")) cat(sprintf("  %-11s %s\n", chi, riga_misura(r, n)))
cat("\nMisura principale (riferimento a 95 confronti sui 47 studi), 21 studi, stesso universo per i due:\n"); stampa("Gemma", rg$principale); stampa("Mistral B0", rm_$principale)
for (k in setdiff(NOMI_R3, "principale")) { cat(sprintf("accanto, misura %s:\n", k)); stampa("Gemma", rg[[k]]); stampa("Mistral B0", rm_[[k]]) }
cat("\nDifferenza appaiata Gemma meno Mistral B0 (B = 10.000, seme 20261115):\n"); print(app, row.names = FALSE, digits = 3)

prev <- function(cod, che, valore, ic, atteso, basso, alto) {
  cat(sprintf("%s  %s: %s (IC95 %.3g, %.3g); atteso %s, rilevanza %s-%s  ->  %s\n", cod, che, format(valore, digits = 3), ic[1], ic[2], atteso, basso, alto, giudica(ic[1], ic[2], basso, alto)))
}
cat("\nPrevisioni:\n")
# P1: chiusi su 21 (IC per ricampionamento degli studi)
set.seed(SEME); bb <- matrix(sample.int(21L, 21L * B, replace = TRUE), nrow = B)
icn <- function(v) unname(stats::quantile(apply(bb, 1L, function(i) sum(v[i])), c(0.025, 0.975)))
prev("P1", "m1, studi con una tabella di Gemma che forma gruppi, su 21", sum(per$chiuso_gemma), icn(per$chiuso_gemma), 20, 18, 21)
idg <- per$classe_gemma %in% "identica"; idm <- per$classe_mistral %in% "identica"
prev("P2", "m2, Gemma: gruppi identici ad Atlas, su 21", sum(idg), icn(idg), 11, 7, 15)
prev("P3", "m2, Mistral B0: gruppi identici ad Atlas, su 21", sum(idm), icn(idm), 16, 13, 19)
cat(sprintf("     accanto, Mistral B0 sull'universo intero di Atlas: %d su 21\n", sum(per$classe_mistral_universo_intero %in% "identica")))
b <- una(rg$principale, "b_confronti_ritrovati")
prev("P4", sprintf("m3, Gemma: confronti di Atlas ritrovati (%d/%d), in %%", as.integer(b$numeratore), as.integer(b$denominatore)), 100 * b$quota, 100 * c(b$ic_basso, b$ic_alto), "45", 25, 65)
bm <- una(rm_$principale, "b_confronti_ritrovati")
cat(sprintf("     accanto, Mistral B0 sugli stessi 21 studi e sullo stesso universo: %d/%d = %.1f%%; sull'universo intero %d/%d\n", as.integer(bm$numeratore), as.integer(bm$denominatore), 100 * bm$quota,
            sum(per$ritrovati_mistral_universo_intero), sum(per$den_universo_intero)))
d <- app[app$misura_r3 == "principale" & app$misura == "b_confronti_ritrovati", ]
cat(sprintf("P5  m3, differenza Gemma meno Mistral B0: %+.1f punti (IC95 %+.1f, %+.1f); atteso -15, IC tutto sotto 0  ->  %s\n", 100 * d$differenza, 100 * d$ic_basso, 100 * d$ic_alto,
            if (d$ic_alto < 0) "confermata" else if (d$ic_basso > 0) "smentita (Gemma sopra Mistral)" else "smentita (IC a cavallo di 0)"))
q4 <- per[per$studio %in% QUATTRO, ]; stopifnot(nrow(q4) == 4L)
prev("P6", "m5, Gemma con i gruppi di Atlas nei 4 studi con un errore di Mistral che costa", sum(q4$classe_gemma %in% "identica"), c(NA, NA), 2, 1, 3)
cat(sprintf("     (4 studi: nessun intervallo; il conto e' %d, %s l'intervallo 1-3)\n", sum(q4$classe_gemma %in% "identica"), if (sum(q4$classe_gemma %in% "identica") %in% 1:3) "dentro" else "fuori"))
cat("\nm4: Gemma e Mistral B0 danno gli stessi gruppi in", sum(per$gemma_uguale_a_mistral), "studi su 21; di questi, identici ad Atlas:", sum(per$gemma_uguale_a_mistral & idg), "\n")
cat("    tabella a doppia entrata (Gemma identica ad Atlas x Mistral identico ad Atlas):\n"); print(table(gemma = idg, mistral = idm))
cat("\nm5: i 4 studi con un errore di lettura di Mistral che costa:\n")
print(q4[c("studio", "gruppi_atlas", "gruppi_gemma", "gruppi_mistral", "classe_gemma", "classe_mistral", "gemma_uguale_a_mistral", "den", "ritrovati_gemma", "ritrovati_mistral")], row.names = FALSE)
cat("\nPer studio:\n")
print(per[c("studio", "n_universo", "gruppi_atlas", "gruppi_gemma", "gruppi_mistral", "classe_gemma", "classe_mistral", "den", "ritrovati_gemma", "ritrovati_mistral", "errori_gemma", "gemma_uguale_a_mistral")], row.names = FALSE)

# ---- le schede di lettura: una per studio, tutti e 21 --------------------------------------------------------
dir.create(file.path(G, "31-schede"), showWarnings = FALSE)
conta_livelli <- function(liv, U) {
  liv <- liv[rownames(liv) %in% U, , drop = FALSE]
  unlist(lapply(names(liv), function(f) { t <- table(liv[[f]]); sprintf("    %s: %s", f, unisci(sprintf("%s (%d)", names(t), as.integer(t)), "; ")) }))
}
for (g in studi) {
  x <- rif[[g]]; r <- gem[[g]]; ml <- m$lett[[g]]; p <- per[per$studio == g, ]
  U <- if (r$chiuso) intersect(x$universo, r$gsm) else x$universo
  k <- MG[[g]]$principale$atlas; km <- MM[[g]]$principale$atlas; ne <- MG[[g]]$principale$non_elencati
  f <- file(file.path(G, "31-schede", paste0(g, ".txt")), "w", encoding = "UTF-8")
  w <- function(...) writeLines(sprintf(...), f)
  w("%s (voce di Gemma %s): universo %d campioni (Atlas %d, Gemma %d; di Atlas fuori da Gemma %d)", g, p$voce_gemma, p$n_universo, p$n_universo_atlas, p$n_gemma, p$atlas_fuori_da_gemma)
  w("gruppi: Atlas %d, Gemma %d (%s), Mistral B0 %s (%s); Gemma uguale a Mistral: %s", p$gruppi_atlas, p$gruppi_gemma, p$classe_gemma, p$gruppi_mistral, p$classe_mistral, p$gemma_uguale_a_mistral)
  w("confronti di Atlas nel riferimento: %d; ritrovati Gemma %d (verso opposto %d), Mistral B0 %d", p$den, p$ritrovati_gemma, p$verso_opposto_gemma, p$ritrovati_mistral)
  w("\nFATTORI DI ATLAS (livelli e campioni nell'universo):"); writeLines(conta_livelli(x$atlas$tabella$livelli, U), f)
  w("  tipi e basi: %s", unisci(sprintf("%s=%s%s", x$atlas$tabella$fattori$nome, x$atlas$tabella$fattori$tipo, ifelse(is.na(x$atlas$tabella$fattori$base), "", paste0(" (base: ", x$atlas$tabella$fattori$base, ")")))))
  w("\nFATTORI DI GEMMA TENUTI:"); if (r$chiuso) writeLines(conta_livelli(r$tabella$livelli, U), f)
  w("  tipi e basi: %s", p$fattori_gemma)
  w("  base dichiarata da Gemma e non usata (contesto o tempo): %s", unisci(sprintf("%s=%s", r$fattori$nome, r$fattori$base_gemma)[!is.na(r$fattori$base_gemma) & is.na(r$fattori$base)]))
  w("  fattori di Gemma tolti: %s", unisci(sprintf("%s [%s] %s", r$fattori_gemma$categoria, r$fattori_gemma$fattore, r$fattori_gemma$motivo_uscita)[!is.na(r$fattori_gemma$motivo_uscita)]))
  w("  note: %s", unisci(r$note))
  if (r$chiuso) {
    w("\nGRUPPI DI ATLAS (righe) x GRUPPI DI GEMMA (colonne), campioni:")
    pa <- x$atlas$partizione[U]; pgm <- r$partizione[U]
    writeLines(utils::capture.output(print(table(atlas = pa, gemma = pgm), zero.print = ".")), f)
    if (ml$chiuso) { w("\nGRUPPI DI ATLAS (righe) x GRUPPI DI MISTRAL B0 (colonne), campioni:")
      writeLines(utils::capture.output(print(table(atlas = pa, mistral = ml$partizione[U]), zero.print = ".")), f) }
  }
  w("\nCONFRONTI DI ATLAS (classe; nel riferimento; ritrovato da Gemma; ritrovato da Mistral B0):")
  if (nrow(k)) for (i in seq_len(nrow(k))) w("  %s | %s | classe %s | nel riferimento %s | Gemma %s | Mistral %s | %d contro %d", k$id[i], k$nome[i], k$classe[i], k$in_b[i], k$ritrovato[i], km$ritrovato[i], length(intersect(unlist(k$trattato[i]), U)), length(intersect(unlist(k$controllo[i]), U)))
  w("\nCONFRONTI DI GEMMA (costruttore) NON ELENCATI DA ATLAS:")
  if (!is.null(ne) && nrow(ne)) for (i in seq_len(nrow(ne))) {
    j <- match(ne$id[i], r$confronti$id)
    w("  %s | %s | giudizio %s | %d contro %d", ne$id[i], if (is.na(j)) "" else unisci(unlist(r$confronti[j, intersect(c("fattore", "livello_trattato", "livello_controllo", "nome"), names(r$confronti))]), " / "), ne$giudizio[i], length(unlist(ne$trattato[i])), length(unlist(ne$controllo[i])))
  }
  if (r$chiuso && nrow(r$registro)) { w("\nREGISTRO DEL COSTRUTTORE (Gemma):"); writeLines(utils::capture.output(print(utils::head(r$registro, 40), row.names = FALSE)), f) }
  close(f)
}
cat(sprintf("\nschede di lettura: %d in %s/31-schede\n", length(list.files(file.path(G, "31-schede"))), G))
