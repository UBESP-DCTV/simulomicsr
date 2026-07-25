# Perche' v9 ha perso due cluster COERENTI? (mitoxantrone, siRNA IGF2BP1)
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
v7 <- readRDS(file.path(SC, "fase1-v7-results.rds")); v9 <- readRDS(file.path(SC, "fase1-v9-results.rds"))
p7 <- v7$pm; p9 <- v9$pm
key <- function(p) paste(p$cluster_id, p$study_id, p$treated_label)
p7$key <- key(p7); p9$key <- key(p9)
for (kk in c("CHEBI:50729||gain||vehicle_untreated", "STR:sirna_pool_against_igf_bp||block||control sirna")) {
  m7 <- p7[!is.na(p7$ckey) & p7$ckey == kk, ]
  cat(sprintf("\n#### %s | membri in v7: %d\n", kk, nrow(m7)))
  j <- p9[match(m7$key, p9$key), ]
  cat("motivo di scarto in v9:\n"); print(table(j$dr, useNA = "ifany"))
  print(head(data.frame(t = substr(m7$treated_label, 1, 46), c = substr(m7$control_label, 1, 34),
                        cand = substr(j$ce2_cand, 1, 18), dr9 = j$dr), 8), row.names = FALSE)
}
cat("\n\n#### quanti membri COERENTI persi in totale per ciascuna regola nuova? ####\n")
ver <- read.csv(file.path(SC, "v7-census-verdicts.csv"), stringsAsFactors = FALSE)
coh <- ver$ckey[ver$verdetto == "COERENTE"]
m7 <- p7[!is.na(p7$ckey) & p7$ckey %in% coh, ]
j <- p9[match(m7$key, p9$key), ]
print(sort(table(j$dr[j$dr != "ok" & j$dr != "ok_combo"]), decreasing = TRUE))
cat("\nmembri coerenti totali in v7:", nrow(m7), "| persi in v9:",
    sum(!j$dr %in% c("ok", "ok_combo")), sprintf("(%.1f%%)", 100 * mean(!j$dr %in% c("ok", "ok_combo"))), "\n")
