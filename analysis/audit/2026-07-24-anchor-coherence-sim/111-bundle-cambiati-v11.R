# Estrae i bundle dei soli gruppi la cui COMPOSIZIONE e' cambiata fra v9 e v10
# (piu' i nuovi): sono gli unici il cui verdetto non si puo' conservare.
# Mostra i contrasti rimasti e, accanto, quelli scartati dalle regole di riga.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
v9 <- readRDS(file.path(SC, "fase1-v10-results.rds"))
v10 <- readRDS(file.path(SC, "fase1-v11-results.rds"))
d <- readRDS(file.path(SC, "delta-v10-v11.rds"))
m9 <- v9$pm[v9$pm$elig, ] |> group_by(ckey) |> summarise(n9 = n(), .groups = "drop")
m10 <- v10$pm[v10$pm$elig, ] |> group_by(ckey) |> summarise(n10 = n(), .groups = "drop")
cambiati <- inner_join(m9, m10, by = "ckey") |> filter(n9 != n10) |> pull(ckey)
target <- unique(c(cambiati, d$nuovi))
target <- intersect(target, v10$agg$ckey)
agg <- v10$agg |> filter(ckey %in% target) |> arrange(desc(k))
elig <- v10$pm[v10$pm$elig, ]
## le righe che questo gruppo aveva in v9 e che v10 ha scartato
sc9 <- v9$pm[v9$pm$elig, ]
con <- file(file.path(SC, "v12-cambiati.txt"), "w")
writeLines(sprintf("# GRUPPI CON COMPOSIZIONE CAMBIATA — %d (da ri-giudicare)", nrow(agg)), con)
for (i in seq_len(nrow(agg))) {
  kk <- agg$ckey[i]
  m <- elig[elig$ckey == kk, ]
  nm <- unique(m$ce2_name[!is.na(m$ce2_name)])
  writeLines(sprintf("\n[%03d] %s | k=%d n=%d cls=%s | nome=%s", i, kk, agg$k[i], agg$n[i],
                     agg$cls[i], paste(head(nm, 2), collapse = "/")), con)
  t <- m |> group_by(study_id, treated_label, control_label) |> summarise(n = n(), .groups = "drop")
  for (j in seq_len(nrow(t))) {
    writeLines(sprintf("  TENUTA %s %-50s => %-38s x%d", t$study_id[j],
                       substr(t$treated_label[j], 1, 50), substr(t$control_label[j], 1, 38), t$n[j]), con)
  }
  old <- sc9[sc9$ckey == kk, ]
  key_new <- paste(m$study_id, m$treated_label, m$control_label)
  drop <- old[!(paste(old$study_id, old$treated_label, old$control_label) %in% key_new), ]
  if (nrow(drop)) {
    dd <- drop |> group_by(study_id, treated_label, control_label) |> summarise(n = n(), .groups = "drop")
    for (j in seq_len(nrow(dd))) {
      writeLines(sprintf("  scartata %s %-50s => %-38s x%d", dd$study_id[j],
                         substr(dd$treated_label[j], 1, 50), substr(dd$control_label[j], 1, 38), dd$n[j]), con)
    }
  }
}
close(con)
cat("scritto v11-cambiati.txt per", nrow(agg), "gruppi\n")
