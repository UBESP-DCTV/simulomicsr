suppressPackageStartupMessages({ devtools::load_all(".", quiet=TRUE) })
ont <- simulomicsr:::.load_ontology_dicts()
casi <- list(
  c("Hypoxia + TGF-β1", "PBS (Vehicle Control)"),
  c("Circulating macrophage + IFN-γ and LPS", "Circulating macrophage untreated"),
  c("Non-fibrotic tissue, TGFB+AR", "Non-fibrotic tissue, Vehicle"),
  c("PCOS EPS TGFB iHP10", "PCOS no treatment iHP10"),
  c("MSC iPSC-derived TGF-β 21 days", "MSC Primary Culture Vehicle Only"))
for (x in casi) {
  at <- simulomicsr:::.rp_agents(x[1], ont)
  ac <- simulomicsr:::.rp_agents(x[2], ont)
  cat("TRATTATO :", x[1], "\n  agenti riconosciuti:", if(length(at)) paste(at,collapse=", ") else "NESSUNO", "\n")
  cat("CONTROLLO:", x[2], "\n  agenti riconosciuti:", if(length(ac)) paste(ac,collapse=", ") else "NESSUNO", "\n")
  cat("  solo nel trattato:", length(setdiff(at,ac)), " (serve >=2 perche' la regola scatti)\n\n")
}
