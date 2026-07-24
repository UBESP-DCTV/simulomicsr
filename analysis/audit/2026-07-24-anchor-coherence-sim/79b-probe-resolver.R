# Probe: quale meccanismo trasforma spazzatura in entita'?
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
oe <- .load_ontology_dicts()
tests <- c("GO 1 ug/ml 28 days", "go ug ml", "L-40 40 ug/ml 1 day", "US 8 ug/ml",
           "CD8 T cells from Melanoma patient number 14, Month 1 after anti-PD-1 therapy",
           "month anti pd therapy", "wtd", "WTD 0.1 nM", "acute tcr",
           "Doxorubicin 0.5 ug/ml 24h", "LPS", "DHT", "TNF", "vemurafenib")
for (t in tests) {
  a <- try(.normalize_compound_to_chebi(t, oe), silent = TRUE)
  b <- try(.normalize_cytokine_to_hgnc(t, oe), silent = TRUE)
  cat(sprintf("%-70s chebi=%-14s cyto=%-12s\n", substr(t, 1, 68),
              if (inherits(a, "try-error")) "ERR" else paste0(a$id, ""),
              if (inherits(b, "try-error")) "ERR" else paste0(b$id, "")))
}
cat("\n--- candidati estratti (extract_compound_candidates) ---\n")
for (t in c("GO 1 ug/ml 28 days", "month anti pd therapy", "WTD 0.1 nM", "acute tcr")) {
  cc <- try(.extract_compound_candidates(t), silent = TRUE)
  cat(sprintf("%-40s -> %s\n", t, paste(utils::head(cc, 10), collapse = " | ")))
}
cat("\n--- alias esatti sospetti ---\n")
for (a in c("go", "us", "l", "wtd", "wtm", "pd", "tcr", "anti", "month")) {
  h <- .hgnc_lookup_symbol(a, env = oe)
  u <- try(.uniprot_lookup_name(a, env = oe), silent = TRUE)
  i <- try(.immport_lookup_synonym(a, env = oe), silent = TRUE)
  cat(sprintf("%-6s hgnc=%-8s uniprot=%-8s immport=%-8s\n", a,
      if (is.null(h)) "-" else h$primary_symbol,
      if (inherits(u,"try-error")||is.null(u)) "-" else paste(unlist(u)[1]),
      if (inherits(i,"try-error")||is.null(i)) "-" else paste(unlist(i)[1])))
}
