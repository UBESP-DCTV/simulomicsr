# Quante meta-analisi del DELIVERABLE v10 portano un nome nato da una collisione?
suppressPackageStartupMessages({library(dplyr)})
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
cl <- readRDS("analysis/p4-output/20260720T180625Z-stage3-v10-364547a7/clusters.rds")
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")   # i 184 rem_group

## ID che le guardie considerano bersaglio di collisione
bad_ids <- unique(sub("^[^|]*\\|", "", .ALIAS_COLLISIONS))
alias_paths <- c("CHEBI_ALIAS", "CYTOKINE_IMMPORT", "MESH_NAME", "CHEMBL_ALIAS",
                 "PATHOGEN_VERNACULAR", "CYTOKINE_HGNC", "CYTOKINE_UNIPROT", "STR_FALLBACK",
                 "LLM_NAME_CLEANUP", "COMPOUND_COMBO", "PATHOGEN_TAXID", "PAMP_WHITELIST")
cl$sospetto <- cl$agent_id_resolved %in% bad_ids
cat("=== TUTTI i cluster Stadio 3 v10 ===\n")
cat(sprintf("cluster totali            : %d\n", nrow(cl)))
cat(sprintf("con ID ontologico         : %d\n", sum(grepl("^(CHEBI|MeSH|HGNC|CHEMBL|NCBITaxon):", cl$agent_id_resolved))))
cat(sprintf("con ID bersaglio di collisione: %d (%.2f%% dei nominati)\n", sum(cl$sospetto),
            100 * sum(cl$sospetto) / max(1, sum(grepl("^(CHEBI|MeSH|HGNC|CHEMBL|NCBITaxon):", cl$agent_id_resolved)))))
cat("\n-- i piu' frequenti --\n")
print(head(as.data.frame(cl |> filter(sospetto) |> count(agent_id_resolved, canonical_name, sort = TRUE)), 15),
      row.names = FALSE)

d184 <- cv[!is.na(cv$dd_verdict), ]
if (nrow(d184)) {
  m <- cl[match(d184$cluster_id, cl$cluster_id), ]
  cat(sprintf("\n=== DELIVERABLE (i %d rem_group verificati il 2026-07-23) ===\n", nrow(d184)))
  cat(sprintf("con ID bersaglio di collisione: %d\n", sum(m$agent_id_resolved %in% bad_ids, na.rm = TRUE)))
  s <- m[m$agent_id_resolved %in% bad_ids, c("cluster_id", "agent_id_resolved", "canonical_name")]
  if (nrow(s)) print(as.data.frame(s), row.names = FALSE)
}
