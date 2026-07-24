# Cosa e' cambiato fra v6 (196 poolabili, 81% coerente) e v7: chi si perde e perche'.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
v6 <- readRDS(file.path(SC, "fase1-v6-results.rds"))
v7 <- readRDS(file.path(SC, "fase1-v7-results.rds"))
e6 <- sub("\\|\\|.*$", "", v6$agg$ckey); e7 <- sub("\\|\\|.*$", "", v7$agg$ckey)
cat(sprintf("entita' poolabili: v6 %d distinte | v7 %d distinte\n", n_distinct(e6), n_distinct(e7)))
cat("\n=== entita' presenti in v6 e SPARITE in v7 (le prime 40) ===\n")
lost <- setdiff(unique(e6), unique(e7)); print(head(sort(lost), 40))
cat(sprintf("(totale sparite: %d)\n", length(lost)))
cat("\n=== entita' NUOVE in v7 (le prime 25) ===\n")
print(head(sort(setdiff(unique(e7), unique(e6))), 25))

cat("\n=== perche' spariscono: drop reason dei loro membri in v7 ===\n")
pm7 <- v7$pm; pm6 <- v6$pm
m6 <- pm6[!is.na(pm6$entity) & pm6$entity %in% lost, c("cluster_id", "study_id", "treated_label", "entity")]
key <- paste(pm7$cluster_id, pm7$study_id, pm7$treated_label)
m6$key <- paste(m6$cluster_id, m6$study_id, m6$treated_label)
j <- pm7[match(m6$key, key), ]
print(sort(table(j$dr, useNA = "ifany"), decreasing = TRUE))

cat("\n=== classe genetic: cosa succede (v6 4 cluster -> v7 1) ===\n")
g6 <- v6$agg$ckey[grepl("HGNC", v6$agg$ckey)]
cat("v6 cluster con entita' HGNC:\n"); print(g6)
g7 <- v7$agg$ckey[grepl("HGNC", v7$agg$ckey)]
cat("v7 cluster con entita' HGNC:\n"); print(g7)
for (kk in g6) {
  e <- sub("\\|\\|.*$", "", kk)
  mm <- pm7[!is.na(pm7$entity) & pm7$entity == e, ]
  if (!nrow(mm)) { mm <- pm7[!is.na(pm7$ce2_id) & pm7$ce2_id == e, ] }
  cat(sprintf("\n-- %s : membri v7=%d | drop=%s\n", kk, nrow(mm),
              paste(names(sort(table(mm$dr), decreasing = TRUE))[1:2], collapse = ",")))
  if (nrow(mm)) print(head(unique(substr(mm$treated_label, 1, 62)), 5))
}
