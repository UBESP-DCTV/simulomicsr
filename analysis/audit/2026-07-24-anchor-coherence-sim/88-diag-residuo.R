# Diagnosi PER-MEMBRO degli 11 cluster incoerenti residui: da dove viene la chiave?
# Serve a scrivere regole deterministiche, non una blacklist di ckey.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v7-results.rds")); pm <- r$pm
ver <- read.csv(file.path(SC, "v7-census-verdicts.csv"), stringsAsFactors = FALSE)
fail <- ver$ckey[ver$verdetto == "INCOERENTE"]
elig <- pm[pm$elig, ]
for (kk in fail) {
  m <- elig[elig$ckey == kk, ]
  cat(sprintf("\n########## %s | k=%d n=%d\n", kk, length(unique(m$study_id)), nrow(m)))
  d <- unique(data.frame(
    onc = m$onc, ce2 = substr(m$ce2_id, 1, 18), cand = substr(m$ce2_cand, 1, 22),
    cls = m$dclasses, verso = m$verso,
    dtval = substr(m$dtval, 1, 42), tlab = substr(m$treated_label, 1, 40),
    clab = substr(m$control_label, 1, 32), stringsAsFactors = FALSE))
  print(head(d, 16), row.names = FALSE)
}
