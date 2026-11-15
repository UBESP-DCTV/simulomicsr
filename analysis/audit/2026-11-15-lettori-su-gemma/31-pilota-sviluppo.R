# 31-pilota-sviluppo.R — la misura contro il riferimento di Gemma, provata sui 21 studi di SVILUPPO che hanno un
# disegno di Gemma. Serve a due cose, prima della carta (00-previsioni.md) e prima di ogni corsa di un modello sugli
# studi di Gemma: (1) il controllo positivo della misura (Gemma contro Gemma) su TUTTE le voci di Gemma con una
# tabella; (2) i numeri di taratura per le previsioni: Mistral-Small 3.2 nella forma B0 (corsa congelata) e i
# curatori di Atlas, letti contro Gemma, sui 21 studi. Nessuna uscita di un modello sugli studi di Gemma esiste.
#   Rscript analysis/audit/2026-11-15-lettori-su-gemma/31-pilota-sviluppo.R > .../31-out.txt 2>&1   (SENZA --vanilla)
#   SALTA_CP=1: salta il controllo positivo (4 minuti) e fa solo la taratura.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
source("analysis/audit/2026-11-15-lettori-su-gemma/30-misura-contro-gemma.R")
SEME <- 20261115L; B <- 10000L
scrivi <- function(d, f) utils::write.csv(d, file.path(LG, f), row.names = FALSE, na = "")

el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
es <- utils::read.csv(file.path(G, "30-esiti.csv"), stringsAsFactors = FALSE)
stopifnot(!any(el$parte[match(es$shortName, el$shortName)] %in% c("giudizio_A", "giudizio_B")))   # nessuno studio di giudizio

# ---- (1) controllo positivo: Gemma contro Gemma, tutte le voci con una tabella -------------------------------
voci <- es[es$esito == "tabella", ]; voci$gse <- el$gse[match(voci$shortName, el$shortName)]
voci <- voci[order(voci$shortName, method = "radix"), ]
tab_gemma <- function(nome, gse) { x <- gemma_leggi(nome); gemma_tabella(x$campioni, x$analisi, gse) }
if (Sys.getenv("SALTA_CP") == "1") cat("(controllo positivo saltato: SALTA_CP=1; il suo esito sta in 31-out-controllo-positivo.txt)\n\n") else {
cp <- do.call(rbind, lapply(seq_len(nrow(voci)), function(i) {
  r <- tab_gemma(voci$shortName[i], voci$gse[i]); stopifnot(r$chiuso)
  d <- gemma_contro_gemma(voci$shortName[i], voci$gse[i], r); d$parte <- voci$parte[i]; d$n_confronti_gemma <- nrow(r$confronti); d
}))
scrivi(cp[c("studio", "gse", "parte", "classe_gruppi", "n_universo", "n_gruppi_gemma", "n_confronti_gemma", "n_atlas", "n_rispetta", "n_b_den",
            "n_b_uguale", "n_non_applicabile_atlas", "n_piu_fattori", "n_non_formabile", "n_nessuna_differenza_atlas", "n_non_elencati")], "31-gemma-contro-gemma.csv")
cat(sprintf("Controllo positivo, Gemma contro Gemma: %d voci (%d studi GEO)\n", nrow(cp), length(unique(cp$gse))))
cat(sprintf("  gruppi identici: %d/%d; confronti del costruttore %d; nel riferimento (classe «rispetta») %d; ritrovati %d; non elencati %d\n",
            sum(cp$classe_gruppi %in% "identica"), nrow(cp), sum(cp$n_confronti_gemma), sum(cp$n_b_den), sum(cp$n_b_uguale), sum(cp$n_non_elencati)))
cat("  classi dei confronti del costruttore secondo la misura: ",
    sprintf("rispetta %d, piu_fattori %d, non_applicabile %d, non_formabile %d, nessuna_differenza %d\n", sum(cp$n_rispetta), sum(cp$n_piu_fattori),
            sum(cp$n_non_applicabile_atlas), sum(cp$n_non_formabile), sum(cp$n_nessuna_differenza_atlas)))
fuori <- cp[cp$n_b_den != cp$n_confronti_gemma, ]
cat(sprintf("  voci dove il riferimento della misura ha meno confronti del costruttore: %d (confronti fuori: %d)\n", nrow(fuori), sum(fuori$n_confronti_gemma - fuori$n_b_den)))
if (nrow(fuori)) print(utils::head(fuori[c("studio", "n_confronti_gemma", "n_rispetta", "n_piu_fattori", "n_non_applicabile_atlas", "n_nessuna_differenza_atlas")], 20), row.names = FALSE)
stopifnot(all(cp$classe_gruppi %in% "identica"), all(cp$n_b_uguale == cp$n_b_den), all(cp$n_non_elencati == 0L))
cat("  CONTROLLO POSITIVO PASSATO: gruppi identici, ogni confronto del riferimento ritrovato, nessun non elencato\n\n")
}

# ---- (2) taratura sui 21 studi di sviluppo -------------------------------------------------------------------
s21 <- voci[voci$parte == "sviluppo", ]; s21 <- s21[order(s21$gse, method = "radix"), ]   # una voce e' una parte di studio (GSE52778.2)
stopifnot(nrow(s21) == 21L, all(s21$gse %in% sv$gse), !anyDuplicated(s21$gse))
m <- misura_forma(leggi_uscite(file.path(USCITE_R5, "B0.jsonl")), "B0")
t3 <- tre_numeri(m$tab); stopifnot(t3[["chiusi"]] == 45L, t3[["identici"]] == 36L, t3[["ritrovati"]] == 68L, t3[["den"]] == 95L)   # riproduzione
PM <- PA <- list()
for (g in s21$gse) {
  vg <- s21$shortName[s21$gse == g]
  r <- tab_gemma(vg, g); x <- rif[[g]]; cv <- as.character(unlist(viste[[g]]$campioni))
  PM[[g]] <- misura_contro_gemma(vg, g, r, m$lett[[g]], cv)$riga
  atl <- list(chiuso = TRUE, partizione = x$atlas$partizione, confronti = x$atlas$confronti)   # i curatori di Atlas letti contro Gemma
  PA[[g]] <- misura_contro_gemma(vg, g, r, atl, cv)$riga
}
PM <- do.call(rbind, PM); PA <- do.call(rbind, PA); rownames(PM) <- rownames(PA) <- NULL
col <- c("studio", "chiuso", "classe_gruppi", "n_universo", "n_gemma", "gemma_fuori_vista", "vista_fuori_gemma", "n_gruppi_gemma", "n_gruppi_lettore",
         "n_b_den", "n_b_uguale", "n_b_verso_opposto", "n_nostri", "n_non_elencati", "n_giudicabili", "n_errori")
scrivi(rbind(cbind(chi = "mistral_B0", PM[col]), cbind(chi = "atlas", PA[col])), "31-pilota-per-studio.csv")
rm_ <- riassumi_gemma(PM, B, SEME); ra <- riassumi_gemma(PA, B, SEME)
scrivi(rbind(cbind(chi = "mistral_B0", rm_), cbind(chi = "atlas", ra)), "31-pilota-riassunto.csv")
cat("Taratura sui 21 studi di sviluppo, riferimento = Gemma (B = 10.000, seme 20261115, unita' lo studio):\n")
for (n in names(QUOTE_GEMMA)) cat(sprintf("  Mistral B0   %s\n", riga_gemma(rm_, n)))
for (n in names(QUOTE_GEMMA)) cat(sprintf("  Atlas        %s\n", riga_gemma(ra, n)))
cat("\nPer studio (Mistral B0 contro Gemma | Atlas contro Gemma):\n")
print(cbind(PM[c("studio", "n_universo", "n_gruppi_gemma", "n_gruppi_lettore", "classe_gruppi", "n_b_den", "n_b_uguale", "n_b_verso_opposto", "n_giudicabili", "n_errori")],
            atlas_classe = PA$classe_gruppi, atlas_uguale = PA$n_b_uguale, atlas_opposto = PA$n_b_verso_opposto), row.names = FALSE)
cat(sprintf("\ncampioni di Gemma fuori dalla vista: %d in %d studi; campioni della vista fuori da Gemma: %d in %d studi\n",
            sum(PM$gemma_fuori_vista), sum(PM$gemma_fuori_vista > 0), sum(PM$vista_fuori_gemma), sum(PM$vista_fuori_gemma > 0)))
