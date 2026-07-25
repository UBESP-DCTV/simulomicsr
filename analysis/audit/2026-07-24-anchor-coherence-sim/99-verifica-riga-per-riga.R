# Verifica RIGA PER RIGA di tutti i gruppi dichiarati coerenti.
# Ogni riga = (studio, braccio trattato, braccio di controllo). Le righe identiche
# dentro lo stesso studio sono replicati: si mostrano una volta col conteggio.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v9-results.rds")); pm <- r$pm; agg <- r$agg
ver <- read.csv(file.path(SC, "v10-census-verdicts-FINAL.csv"), stringsAsFactors = FALSE)
coh <- ver$ckey[ver$verdetto == "COERENTE"]
elig <- pm[pm$elig, ]
con <- file(file.path(SC, "verifica-riga-per-riga.txt"), "w")
writeLines(sprintf("# VERIFICA RIGA PER RIGA — %d gruppi coerenti", length(coh)), con)
agg2 <- agg[agg$ckey %in% coh, ] |> arrange(desc(k))
for (i in seq_len(nrow(agg2))) {
  kk <- agg2$ckey[i]
  m <- elig[elig$ckey == kk, ]
  nm <- unique(m$ce2_name[!is.na(m$ce2_name)])
  writeLines(sprintf("\n[%03d] %s | studi=%d | %s", i, kk, agg2$k[i], paste(head(nm, 1), collapse = "")), con)
  t <- m |> group_by(study_id, treated_label, control_label) |>
    summarise(n = n(), .groups = "drop") |> arrange(study_id)
  for (j in seq_len(nrow(t))) {
    writeLines(sprintf("  %s %-52s => %-40s x%d", t$study_id[j],
                       substr(t$treated_label[j], 1, 52), substr(t$control_label[j], 1, 40), t$n[j]), con)
  }
}
close(con)
cat("righe:", length(readLines(file.path(SC, "verifica-riga-per-riga.txt"))), "\n")
