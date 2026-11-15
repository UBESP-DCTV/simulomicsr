#!/usr/bin/env Rscript
# Sensibilita' DICHIARATA DOPO I NUMERI (non sta nella carta 00-previsioni.md): la misura 31 rifatta con la base che
# Gemma dichiara anche per i fattori di contesto (cell type, cell line, organism part) e di tempo (regola 5 senza
# le due esclusioni). Dice quanti confronti di Atlas costa la regola 5 e quanti restano persi per scelte dei curatori.
# Uso: Rscript analysis/audit/2026-11-15-gemma-riferimento/32-sensibilita-base-di-gemma.R   (senza --vanilla)
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
source("analysis/audit/2026-11-15-gemma-riferimento/30-adattatore-gemma.R")
SEME <- 20261115L; B <- 10000L
el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
el <- el[el$parte == "sviluppo", ]; stopifnot(nrow(el) == 21L)
studi <- el$gse
m <- misura_forma(leggi_uscite(file.path(USCITE_R5, "B0.jsonl")), "B0")
una_misura <- function(g, r, x) if (r$chiuso) misura_r3(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
  misura_r3(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
righe <- list(); PG <- PM <- list()
for (i in seq_along(studi)) {
  g <- studi[i]; x <- rif[[g]]; d <- gemma_leggi(el$shortName[i])
  r0 <- gemma_tabella(d$campioni, d$analisi, g); r1 <- gemma_tabella(d$campioni, d$analisi, g, base_di_gemma = TRUE)
  x$universo <- sort(intersect(x$universo, r0$gsm), method = "radix")
  a0 <- una_misura(g, r0, x)$principale$riga; a1 <- una_misura(g, r1, x)$principale$riga
  PG[[g]] <- a1; PM[[g]] <- una_misura(g, m$lett[[g]], x)$principale$riga
  righe[[g]] <- data.frame(studio = g, den = a0$n_b_den, ritrovati_carta = a0$n_b_uguale, ritrovati_base_di_gemma = a1$n_b_uguale,
    verso_opposto_base_di_gemma = a1$n_b_verso_opposto, confronti_carta = a0$n_nostri, confronti_base_di_gemma = a1$n_nostri,
    errori_base_di_gemma = a1$n_errori, giudicabili_base_di_gemma = a1$n_giudicabili,
    fattori = unisci(sprintf("%s=%s%s", r1$fattori$nome, r1$fattori$tipo, ifelse(is.na(r1$fattori$base), "", paste0(" (base: ", r1$fattori$base, ")")))))
}
per <- do.call(rbind, righe); rownames(per) <- NULL
utils::write.csv(per, file.path(G, "32-per-studio.csv"), row.names = FALSE, na = "")
cat("SENSIBILITA' DOPO I NUMERI: la base di Gemma anche per i fattori di contesto e di tempo\n")
cat(sprintf("ritrovati: carta %d/%d, con la base di Gemma %d/%d (verso opposto %d)\n", sum(per$ritrovati_carta), sum(per$den),
            sum(per$ritrovati_base_di_gemma), sum(per$den), sum(per$verso_opposto_base_di_gemma)))
cat(sprintf("errori fra i non elencati con la base di Gemma: %d/%d\n", sum(per$errori_base_di_gemma), sum(per$giudicabili_base_di_gemma)))
print(per[per$ritrovati_carta != per$ritrovati_base_di_gemma | per$confronti_carta != per$confronti_base_di_gemma,
          c("studio", "den", "ritrovati_carta", "ritrovati_base_di_gemma", "verso_opposto_base_di_gemma", "confronti_carta", "confronti_base_di_gemma", "errori_base_di_gemma")], row.names = FALSE)
a <- appaiato(do.call(rbind, PG), do.call(rbind, PM), c("gemma_base", "mistral_B0"))
print(a[a$misura == "b_confronti_ritrovati", ], row.names = FALSE)
