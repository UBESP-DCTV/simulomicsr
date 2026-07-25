# CENSIMENTO v11 — gate v10 (v9 + scarto delle righe mal appaiate), TUTTI i gruppi.
#
# Metodo, dichiarato: i gruppi la cui COMPOSIZIONE e' identica a v9 conservano il
# verdetto del censimento precedente (stessi contrasti, stesso giudizio); i 36
# gruppi con composizione cambiata o nuovi sono stati riletti uno per uno in
# questa sessione (v11-cambiati.txt).
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
v9 <- readRDS(file.path(SC, "fase1-v9-results.rds"))
v10 <- readRDS(file.path(SC, "fase1-v10-results.rds"))
prev <- read.csv(file.path(SC, "v10-census-verdicts-FINAL.csv"), stringsAsFactors = FALSE)
agg <- v10$agg

## verdetti riletti in questa sessione (i gruppi con composizione cambiata)
RILETTI <- c(
  # unico gruppo NUOVO: la dedup per entita' ha promosso la variante peggiore di
  # RSV. Mescola infezione CLINICA (bambini "virus positive at AV" vs "Control CV",
  # una con co-infezione RSV+rhinovirus) e SPERIMENTALE (H292 vs mock).
  "NCBITaxon:12814||gain||vehicle_untreated" =
    "INCOERENTE|infezione clinica e sperimentale mescolate, piu' una co-infezione RSV+rhinovirus"
)
agg$verdetto <- prev$verdetto[match(agg$ckey, prev$ckey)]
agg$nota <- prev$nota[match(agg$ckey, prev$ckey)]
hit <- agg$ckey %in% names(RILETTI)
agg$verdetto[hit] <- sub("\\|.*$", "", RILETTI[agg$ckey[hit]])
agg$nota[hit] <- sub("^[^|]*\\|", "", RILETTI[agg$ckey[hit]])
stopifnot(!any(is.na(agg$verdetto)))   # nessun gruppo senza verdetto

agg <- agg |> arrange(verdetto, desc(k))
write.csv(agg |> select(ckey, k, n, src, verso, cls, verdetto, nota),
          file.path(SC, "v11-census-verdicts-FINAL.csv"), row.names = FALSE)

n <- nrow(agg); nc <- sum(agg$verdetto == "COERENTE")
cat("=== CENSIMENTO v11 (TUTTI i gruppi, nessun campione) ===\n")
cat(sprintf("poolabili k>=3 : %d   (v9: %d)\n", n, nrow(v9$agg)))
cat(sprintf("COERENTI       : %d (%.1f%%)   (v9: 143 su 145 = 98,6%%)\n", nc, 100 * nc / n))
cat(sprintf("INCOERENTI     : %d\n", n - nc))
cat(sprintf("studi-slot nei coerenti: %d / %d\n", sum(agg$k[agg$verdetto == "COERENTE"]), sum(agg$k)))
cat("\n-- forza dei coerenti --\n")
print(table(cut(agg$k[agg$verdetto == "COERENTE"], c(2, 4, 9, 19, Inf),
                labels = c("k=3-4", "k=5-9", "k=10-19", "k>=20"))))
cat("\n-- classe --\n"); print(table(agg$cls[agg$verdetto == "COERENTE"]))
cat("\n-- i 12 gruppi piu' forti --\n")
print(as.data.frame(head(agg |> filter(verdetto == "COERENTE") |> select(ckey, k, n), 12)), row.names = FALSE)
cat("\n-- gli incoerenti --\n")
print(as.data.frame(agg |> filter(verdetto == "INCOERENTE") |> select(ckey, k, nota)), row.names = FALSE)

## righe scartate: il conto onesto
sc <- v10$pm[startsWith(v10$pm$dr, "riga_"), ]
cat(sprintf("\n=== righe mal appaiate scartate ===\nmembri: %d | coppie distinte (studio, trattato, controllo): %d\n",
            nrow(sc), nrow(unique(sc[, c("study_id", "treated_label", "control_label")]))))
print(sort(table(sub("^riga_", "", sc$dr)), decreasing = TRUE))
