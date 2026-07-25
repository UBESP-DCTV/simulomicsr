# Dump COMPLETO dei membri (nessuna deduplicazione) per i gruppi richiesti.
# Serve a spiegare campione per campione perche' un gruppo e' coerente.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v9-results.rds")); pm <- r$pm; agg <- r$agg
elig <- pm[pm$elig, ]

## i due scartati + candidati piccoli fra i coerenti
DUE <- c("HGNC:2434||gain||vehicle_untreated", "STR:ptsd||gain||vehicle_untreated")
cat("=== dimensioni dei gruppi coerenti piu' piccoli (per sceglierne 5) ===\n")
print(as.data.frame(agg |> filter(!ckey %in% DUE, n <= 16) |> arrange(n) |>
                      select(ckey, k, n) |> head(14)), row.names = FALSE)

dump <- function(kk, titolo) {
  m <- elig[elig$ckey == kk, ]
  cat(sprintf("\n\n############ %s\n#### %s | studi=%d campioni-riga=%d\n",
              titolo, kk, length(unique(m$study_id)), nrow(m)))
  m <- m |> arrange(study_id)
  for (i in seq_len(nrow(m))) {
    cat(sprintf("  [%s] %-58s  VS  %-42s  (%s)\n", m$study_id[i],
                substr(m$treated_label[i], 1, 58), substr(m$control_label[i], 1, 42),
                m$design_kind[i]))
  }
}
for (kk in DUE) dump(kk, "SCARTATO")
sel <- commandArgs(trailingOnly = TRUE)
for (kk in sel) dump(kk, "COERENTE — da verificare")
