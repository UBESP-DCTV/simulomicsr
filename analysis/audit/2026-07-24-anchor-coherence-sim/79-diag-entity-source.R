# Diagnosi: (a) da dove vengono le entita' mis-risolte; (b) inventario chiavi factor_levels.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
source(file.path(SC, "contrast-sig-engine.R"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
r <- readRDS(file.path(SC, "fase1-v6-results.rds")); pm <- r$pm
elig <- pm[pm$elig, ]

cat("=== (a) entita' sospette: sorgente per-membro ===\n")
for (E in c("HGNC:11795", "HGNC:1706")) {
  m <- elig[grepl(E, elig$entity, fixed = TRUE), ]
  cat(sprintf("\n-- %s | membri=%d | onc(TRUE=eredita nome cluster)=%d\n", E, nrow(m), sum(m$onc)))
  cat("   canonical_name cluster:", paste(unique(substr(m$canonical_name, 1, 40)), collapse=" | "), "\n")
  cat("   ce_name (nome risolto):", paste(unique(m$ce_name), collapse=" | "), "\n")
  cat("   ce_cls:", paste(unique(m$ce_cls), collapse=" | "), "\n")
  print(head(unique(data.frame(onc = m$onc, ce_id = m$ce_id,
                               tval = substr(m$clean_tval, 1, 55))), 12))
}
cat("\n=== nomi ontologici di questi ID ===\n")
oe <- .load_ontology_dicts()
for (h in c(11795, 1706)) {
  g <- .hgnc_lookup_hgnc(h, env = oe)
  cat(sprintf("HGNC:%d -> %s\n", h, if (is.null(g)) "NULL" else g$primary_symbol))
}

cat("\n=== (b) inventario chiavi factor_levels (top 40) ===\n")
allk <- unlist(lapply(pm$treated_fl, function(s) names(.parse_fl_kv(s))))
print(head(sort(table(allk), decreasing = TRUE), 40))

cat("\n=== (c) valori di chiavi di CONTESTO/materiale (per asse tessuto vs liquido vs in-vitro) ===\n")
for (K in c("context_kind", "material", "sample_type", "tissue", "tissue_segment",
            "cell_type_or_line_raw", "cell_context.context_kind")) {
  vals <- unlist(lapply(pm$treated_fl, function(s) { v <- .parse_fl_kv(s); if (K %in% names(v)) v[[K]] else NULL }))
  if (length(vals)) {
    cat(sprintf("\n-- %s (n=%d) top15:\n", K, length(vals)))
    print(head(sort(table(tolower(vals)), decreasing = TRUE), 15))
  }
}
