# Bundle di censimento per TUTTI i poolabili v7 (mai un campione).
# Formato compatto: un blocco per cluster, contrasti dedup con conteggio.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v7-results.rds")); pm <- r$pm; agg <- r$agg
elig <- pm[pm$elig, ]
agg <- agg |> arrange(desc(k))
con <- file(file.path(SC, "v7-census-bundles.txt"), "w")
writeLines(sprintf("# CENSIMENTO COERENZA v7 — %d cluster poolabili k>=3 (TUTTI)", nrow(agg)), con)
for (i in seq_len(nrow(agg))) {
  kk <- agg$ckey[i]
  m <- elig[elig$ckey == kk, ]
  nm <- unique(m$ce2_name[!is.na(m$ce2_name)])
  m$tuple <- sprintf("%s => %s", substr(m$treated_label, 1, 62), substr(m$control_label, 1, 46))
  tb <- sort(table(m$tuple), decreasing = TRUE)
  writeLines(sprintf("\n[%03d] %s | k=%d n=%d cls=%s src=%s | nome=%s", i, kk, agg$k[i], agg$n[i],
                     agg$cls[i], agg$src[i], paste(head(nm, 2), collapse = "/")), con)
  for (j in seq_len(min(10, length(tb)))) writeLines(sprintf("  %2dx %s", tb[j], names(tb)[j]), con)
  if (length(tb) > 10) writeLines(sprintf("  ... +%d contrasti distinti", length(tb) - 10), con)
}
close(con)
cat("scritto v7-census-bundles.txt per", nrow(agg), "cluster\n")
cat("righe:", length(readLines(file.path(SC, "v7-census-bundles.txt"))), "\n")
