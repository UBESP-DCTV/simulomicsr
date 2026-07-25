# Smoke sui gruppi bandiera.
#
# I pavimenti sono MISURATI dal gate v11 (109.log), non stimati. Se un gruppo
# bandiera scende sotto il suo pavimento ci si FERMA e si misura: non si aggiusta
# la regola per far tornare il numero.
suppressPackageStartupMessages(library(dplyr))
OUT <- "analysis/audit/2026-07-27-contrast-builder"
agg <- readRDS(file.path(OUT, "equivalenza-builder.rds"))$agg

PAVIMENTI <- c(
  "NCBITaxon:2697049" = 28,   # SARS-CoV-2
  "CHEBI:16412"       = 26,   # LPS
  "HGNC:11766"        = 27,   # TGFB1
  "CHEBI:68534"       = 21,   # enzalutamide
  "CHEBI:63637"       = 13    # vemurafenib
)
NOMI <- c("SARS-CoV-2", "LPS", "TGFB1", "enzalutamide", "vemurafenib")

esito <- lapply(seq_along(PAVIMENTI), function(i) {
  e <- names(PAVIMENTI)[i]
  k <- suppressWarnings(max(agg$k[agg$entita == e], -Inf))
  k <- if (is.finite(k)) k else 0
  data.frame(entita = e, nome = NOMI[i], k_pavimento = PAVIMENTI[[i]], k_ottenuto = k,
             esito = ifelse(k >= PAVIMENTI[[i]], "OK", "SOTTO IL PAVIMENTO"),
             stringsAsFactors = FALSE)
}) |> bind_rows()

cat("=== SMOKE SUI GRUPPI BANDIERA ===\n")
print(esito, row.names = FALSE)
write.csv(esito, file.path(OUT, "smoke-bandiera.csv"), row.names = FALSE)

if (any(esito$esito != "OK")) {
  cat("\n>>> FERMARSI: almeno un gruppo bandiera e' sotto il pavimento misurato.\n")
} else {
  cat("\nTutti i gruppi bandiera sono al pavimento o sopra.\n")
}

cat("\n=== i 20 gruppi piu' forti ===\n")
print(as.data.frame(agg |> arrange(desc(k)) |> head(20) |> select(ckey, k, n)), row.names = FALSE)
cat("\n=== distribuzione di k ===\n")
print(table(cut(agg$k, breaks = c(2, 4, 9, 19, Inf),
                labels = c("k=3-4", "k=5-9", "k=10-19", "k>=20"))))
