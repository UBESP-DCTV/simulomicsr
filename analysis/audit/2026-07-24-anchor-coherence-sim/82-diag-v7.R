suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v7-results.rds")); pm <- r$pm; agg <- r$agg
cat("=== (a) dove sono finiti i membri SARS (ce2_id = NCBITaxon:2697049) ===\n")
s <- pm[!is.na(pm$ce2_id) & pm$ce2_id == "NCBITaxon:2697049", ]
cat("membri:", nrow(s), " | drop reason:\n"); print(sort(table(s$dr), decreasing = TRUE))
cat("\nentity assegnata (top):\n"); print(head(sort(table(s$entity, useNA = "ifany"), decreasing = TRUE), 8))
cat("\nckey (top, con k):\n")
sk <- s[!is.na(s$ckey), ] |> group_by(ckey) |> summarise(k = n_distinct(study_id), n = n(), .groups = "drop") |> arrange(desc(k))
print(head(as.data.frame(sk), 10), row.names = FALSE)
cat("\nesempi marcati combo:\n")
print(head(unique(substr(s$dtval[s$dr == "ok_combo"], 1, 70)), 8))

cat("\n=== (b) combo: sono davvero combinazioni? campione casuale ===\n")
cb <- pm[pm$dr == "ok_combo", ]
set.seed(1); idx <- sample(seq_len(nrow(cb)), min(25, nrow(cb)))
print(data.frame(dtval = substr(cb$dtval[idx], 1, 58), entity = substr(cb$entity[idx], 1, 46)), row.names = FALSE)

cat("\n=== (c) verso: distribuzione sui membri eleggibili ===\n")
print(table(pm$verso[pm$elig], useNA = "ifany"))
cat("\n=== (d) contrasto_rotto: campione ===\n")
br <- pm[pm$dr == "contrasto_rotto", ]
print(head(unique(data.frame(t = substr(br$treated_label, 1, 46), c = substr(br$control_label, 1, 40))), 10), row.names = FALSE)
cat("\n=== (e) entita_ombrello scartate ===\n")
om <- pm[pm$dr == "entita_ombrello", ]
print(head(sort(table(om$ce2_id, useNA = "ifany"), decreasing = TRUE), 10))
