suppressPackageStartupMessages({ devtools::load_all(".", quiet=TRUE) })
ont <- simulomicsr:::.load_ontology_dicts()
for (s in c("TGF-β1","TGF-beta1","TGFB1","TGFb1",
            "IFN-γ","IFN-gamma","IFNG",
            "IL-1β","IL-1beta","IL1B")) {
  a <- simulomicsr:::.rp_agents(s, ont)
  cat(sprintf("  %-12s -> %s\n", s, if (length(a)) paste(a, collapse=", ") else "NESSUNO"))
}
