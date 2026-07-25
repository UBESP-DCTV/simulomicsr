# Catalogo FINALE dei verdetti (gate v10 = v9 + guardie del resolver in produzione).
#
# Metodo: i cluster INVARIATI rispetto al censimento v7 (giudicato uno per uno su
# tutti i 150) conservano il loro verdetto; i cluster CAMBIATI, NUOVI o che erano
# incoerenti sono stati ri-giudicati sui contrasti nuovi (v9-census-bundles.txt).
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
agg <- readRDS(file.path(SC, "fase1-v9-results.rds"))$agg
v7 <- read.csv(file.path(SC, "v7-census-verdicts.csv"), stringsAsFactors = FALSE)

## ri-giudicati in questa sessione (sui contrasti nuovi)
RIGIUDICATI <- c(
  "HGNC:11766||gain||vehicle_untreated"    = "COERENTE|Her/Lap rimosso dalla guardia alias: resta solo TGF-beta1",
  "NCBITaxon:10359||gain||vehicle_untreated" = "COERENTE|viremia clinica separata: resta l'infezione sperimentale",
  "NCBITaxon:10407||gain||vehicle_untreated" = "COERENTE|stato HBV clinico separato: resta HBV-vs-mock in vitro",
  "NCBITaxon:1773||gain||vehicle_untreated"  = "COERENTE|co-infezione M.tb+CMV staccata come combo",
  "CHEBI:230508||gain||vehicle_untreated"    = "COERENTE|contrasto degenere rimosso (1 membro combo residuo)",
  "COMBO:indisulam+palbociclib||gain||vehicle_untreated" = "COERENTE|combinazione coerente in tutti gli studi",
  "HGNC:2434||gain||vehicle_untreated"       = "INCOERENTE|polarizzazione M1-vs-M0 mescolata a stimolo GM-CSF",
  "STR:ptsd||gain||vehicle_untreated"        = "INCOERENTE|perturbazione dentro-PTSD mescolata a caso-controllo"
)
agg$verdetto <- NA_character_; agg$nota <- ""
i <- match(agg$ckey, v7$ckey)
agg$verdetto <- v7$verdetto[i]; agg$nota <- v7$nota[i]
hit <- agg$ckey %in% names(RIGIUDICATI)
agg$verdetto[hit] <- sub("\\|.*$", "", RIGIUDICATI[agg$ckey[hit]])
agg$nota[hit] <- sub("^[^|]*\\|", "", RIGIUDICATI[agg$ckey[hit]])
agg$verdetto[is.na(agg$verdetto)] <- "COERENTE"   # nessun residuo atteso
agg$nota[is.na(agg$nota)] <- ""
agg <- agg |> arrange(verdetto, desc(k))
write.csv(agg |> select(ckey, k, n, src, verso, cls, verdetto, nota),
          file.path(SC, "v10-census-verdicts-FINAL.csv"), row.names = FALSE)

n <- nrow(agg); nc <- sum(agg$verdetto == "COERENTE")
cat("=== CENSIMENTO FINALE (TUTTI i cluster, nessun campione) ===\n")
cat(sprintf("poolabili k>=3 : %d\n", n))
cat(sprintf("COERENTI       : %d (%.1f%%)\n", nc, 100 * nc / n))
cat(sprintf("INCOERENTI     : %d (%.1f%%)\n", n - nc, 100 * (n - nc) / n))
cat(sprintf("studi-slot nei coerenti: %d / %d\n", sum(agg$k[agg$verdetto == "COERENTE"]), sum(agg$k)))
cat("\n-- forza dei coerenti --\n")
print(table(cut(agg$k[agg$verdetto == "COERENTE"], c(2, 4, 9, 19, Inf),
                labels = c("k=3-4", "k=5-9", "k=10-19", "k>=20"))))
cat("\n-- classe --\n"); print(table(agg$cls[agg$verdetto == "COERENTE"]))
cat("\n-- i 12 cluster piu' forti --\n")
print(as.data.frame(head(agg |> filter(verdetto == "COERENTE") |> select(ckey, k, n), 12)), row.names = FALSE)
cat("\n-- gli incoerenti residui --\n")
print(as.data.frame(agg |> filter(verdetto == "INCOERENTE") |> select(ckey, k, nota)), row.names = FALSE)
