# Dump delle segnalazioni del rilevatore grezzo (100-difetti-riga.R) con il
# contesto che serve a giudicarle: classe del contrasto, entita', verso.
# Serve a capire da dove vengono i 90 falsi allarmi.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v9-results.rds")); pm <- r$pm
d <- read.csv(file.path(SC, "difetti-riga.csv"), stringsAsFactors = FALSE)
info <- pm[pm$elig, ] |>
  group_by(ckey, study_id, treated_label, control_label) |>
  summarise(cls = dom_cls[1], ce2 = ce2_name[1] %||% NA, nome = canonical_name[1], .groups = "drop")
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
d <- left_join(d, info, by = c("ckey", "study_id", "treated_label", "control_label"))
s <- d[d$difetto, ]
cat("segnalate:", nrow(s), "\n\n")
cat("=== per classe del contrasto ===\n")
print(table(s$cls, useNA = "ifany"))
cat("\n=== per tipo di segnalazione x classe ===\n")
for (v in c("A_linea", "B_combo", "C_tempo", "D_genetico", "E_soggetto")) {
  cat("\n--", v, "-- totale", sum(s[[v]]), "\n")
  print(table(s$cls[s[[v]]], useNA = "ifany"))
}
con <- file(file.path(SC, "segnalate-dump.txt"), "w")
for (v in c("A_linea", "B_combo", "C_tempo", "D_genetico", "E_soggetto")) {
  ss <- s[s[[v]], ]
  writeLines(sprintf("\n\n######## %s — %d segnalazioni ########", v, nrow(ss)), con)
  ss <- ss |> arrange(cls, ckey)
  for (i in seq_len(nrow(ss))) {
    writeLines(sprintf("[%s|%s] %s\n    T: %s\n    C: %s", ss$cls[i], ss$study_id[i],
                       ss$ckey[i], ss$treated_label[i], ss$control_label[i]), con)
  }
}
close(con)
cat("\nscritto segnalate-dump.txt\n")
