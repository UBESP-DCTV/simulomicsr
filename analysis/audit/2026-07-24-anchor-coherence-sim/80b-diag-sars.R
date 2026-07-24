suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
source(file.path(SC, "contrast-sig-engine.R"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
pm <- readRDS(file.path(SC, "fase1-pm2.rds"))
lost <- pm[!is.na(pm$ce_id) & pm$ce_id == "NCBITaxon:2697049" &
             (is.na(pm$ce2_id) | pm$ce2_id != "NCBITaxon:2697049"), ]
cat("membri persi:", nrow(lost), "\n")
cat("\n-- classe dominante ora (ce2_cls) --\n"); print(table(lost$ce2_cls, useNA = "ifany"))
cat("\n-- classe prima (ce_cls) --\n"); print(table(lost$ce_cls, useNA = "ifany"))
cat("\n-- cosa risolvono ora --\n"); print(head(sort(table(lost$ce2_id, useNA = "ifany"), decreasing = TRUE), 8))
cat("\n-- esempi (delta trattato | label) --\n")
ex <- unique(data.frame(cls = lost$ce2_cls, dtval = substr(lost$dtval, 1, 60),
                        lab = substr(lost$treated_label, 1, 60), now = lost$ce2_id))
print(head(ex, 15), row.names = FALSE)
oe <- .load_ontology_dicts()
cat("\n-- probe resolver sui delta persi --\n")
for (s in head(unique(lost$dtval), 6)) {
  cat(sprintf("%-45s pathogen=%s\n", substr(s, 1, 43), .normalize_pathogen_to_taxid(s, oe)$id))
}
