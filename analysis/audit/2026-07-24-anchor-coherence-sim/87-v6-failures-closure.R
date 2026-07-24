# Verifica UNO-PER-UNO: i falliti catalogati in v6-census-failures.txt sono chiusi in v7?
# (confronto valido fra v6 e v7 — le PERCENTUALI non lo sono, perche' il giudice
#  e la rubrica sono diversi.)
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
v7 <- readRDS(file.path(SC, "fase1-v7-results.rds"))$agg
ver <- read.csv(file.path(SC, "v7-census-verdicts.csv"), stringsAsFactors = FALSE)
fail7 <- ver$ckey[ver$verdetto == "INCOERENTE"]

# entita' (o pattern) dei falliti v6 -> come si chiama in v7
CASI <- list(
  "COMBO_BUCKET (16 bucket +COMBO)"      = "\\+COMBO",
  "COMBO_UNCAUGHT bleomicina"            = "^CHEBI:3139\\|\\|",
  "COMBO_UNCAUGHT temozolomide"          = "^CHEBI:72564\\|\\|",
  "COMBO_UNCAUGHT vemurafenib"           = "^CHEBI:63637\\|\\|",
  "DIREZIONE glucosio"                   = "^CHEBI:4167\\|\\|",
  "DIREZIONE androgeno (CHEBI:50113)"    = "^CHEBI:50113\\|\\|",
  "DIREZIONE estrogeno (CHEBI:50114)"    = "^CHEBI:50114\\|\\|",
  "DIREZIONE TNF (CHEMBL:265582)"        = "CHEMBL265582",
  "BASELINE HCC tessuto/plasma"          = "^MeSH:D006528\\|\\|",
  "BASELINE liver_cancer plasma"         = "STR:liver_cancer",
  "BASELINE lung adeno +SSc/plasma"      = "^MeSH:D000077192\\|\\|",
  "BASELINE heart_failure vs Kidney"     = "STR:heart_failure",
  "BASELINE HBV+HDV"                     = "^NCBITaxon:10407\\|\\|",
  "MIXED HGNC:11795 (THPO da ug/ml)"     = "^HGNC:11795\\|\\|",
  "MIXED HGNC:1706 (CD8A da label)"      = "^HGNC:1706\\|\\|",
  "UMBRELLA heat shock +tabacco"         = "heat shock",
  "UMBRELLA covid +vaccino"              = "^STR:covid\\|\\|",
  "UMBRELLA environmental_or_behavioral" = "environmental",
  "LONGITUDINALE artrite reumatoide"     = "^MeSH:D001172\\|\\|",
  "UNCLEAR early/late_on_biopsy"         = "_on_biopsy"
)
cat(sprintf("%-40s %-9s %s\n", "caso fallito in v6", "in v7?", "esito"))
cat(strrep("-", 96), "\n")
n_chiusi <- 0; n_aperti <- 0
for (nm in names(CASI)) {
  hit <- v7$ckey[grepl(CASI[[nm]], v7$ckey)]
  if (!length(hit)) {
    esito <- "CHIUSO — non raggiunge piu' k>=3 (scartato/spezzato dalle regole)"
    stato <- "assente"; n_chiusi <- n_chiusi + 1
  } else if (all(hit %in% fail7)) {
    esito <- paste0("APERTO — ancora incoerente: ", paste(hit, collapse = ", "))
    stato <- "presente"; n_aperti <- n_aperti + 1
  } else if (any(hit %in% fail7)) {
    esito <- paste0("PARZIALE — ", sum(hit %in% fail7), "/", length(hit), " ancora incoerenti")
    stato <- "presente"; n_aperti <- n_aperti + 1
  } else {
    esito <- paste0("CHIUSO — ora COERENTE (k=", paste(v7$k[v7$ckey %in% hit], collapse = "+"), ")")
    stato <- "presente"; n_chiusi <- n_chiusi + 1
  }
  cat(sprintf("%-40s %-9s %s\n", substr(nm, 1, 39), stato, esito))
}
cat(strrep("-", 96), "\n")
cat(sprintf("chiusi %d / aperti %d su %d casi catalogati in v6\n", n_chiusi, n_aperti, length(CASI)))
cat("\nNUOVI falliti visti solo alla risoluzione piu' fine di v7:\n")
for (f in fail7) cat("  -", f, "|", ver$nota[ver$ckey == f], "\n")
