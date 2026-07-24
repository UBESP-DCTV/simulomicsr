# Ispezione dei falliti v6 sui DATI VERI (non sul catalogo riassuntivo).
# Stampa, per ogni ckey fallito, i contrasti dedup dei membri.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v6-results.rds")); pm <- r$pm; agg <- r$agg
elig <- pm[pm$elig, ]

# pattern dei falliti catalogati in v6-census-failures.txt
PAT <- c("CHEBI:4167", "CHEBI:50113", "CHEBI:50114", "CHEMBL:265582",
         "hepatocellular carcinoma", "lung adenocarcinoma", "NCBITaxon:10407",
         "heart_failure", "liver_cancer", "HGNC:11795", "HGNC:1706",
         "heat shock", "covid", "environmental_or_behavioral",
         "rheumatoid arthritis", "early_on_biopsy", "late_on_biopsy",
         "NAME:bleomycin", "temozolomide", "vemurafenib")

hit <- agg$ckey[vapply(agg$ckey, function(k)
  any(vapply(PAT, function(p) grepl(p, k, fixed = TRUE), logical(1))), logical(1))]

cat("=== ckey falliti/da-ispezionare trovati:", length(hit), "===\n\n")
for (kk in sort(hit)) {
  m <- elig[elig$ckey == kk, ]
  cat(sprintf("### %s | k=%d n=%d\n", kk, length(unique(m$study_id)), nrow(m)))
  m$tuple <- sprintf("%s => %s", substr(m$treated_label, 1, 80), substr(m$control_label, 1, 60))
  tb <- sort(table(m$tuple), decreasing = TRUE)
  for (i in seq_len(min(14, length(tb)))) cat(sprintf("   %2dx %s\n", tb[i], names(tb)[i]))
  if (length(tb) > 14) cat(sprintf("   ... +%d altri contrasti distinti\n", length(tb) - 14))
  cat("\n")
}
