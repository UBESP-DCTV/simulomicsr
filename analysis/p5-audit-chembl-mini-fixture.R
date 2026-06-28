# Mini-fixture ChEMBL per i test (raw, stessa forma di chebi-mini: by_id+aliases+meta).
# ID chembl illustrativi (fixture sintetica, fixture_subset=TRUE); la dict reale
# (analysis/p5-audit-chembl-build-dict.R) usa gli ID veri dal dump.
suppressPackageStartupMessages(library(tibble))
by_id <- tibble::tribble(
  ~chembl_id,        ~pref_name,
  "CHEMBL_ICOTINIB", "Icotinib",
  "CHEMBL_COBI",     "Cobimetinib",
  "CHEMBL_ENZA",     "Enzalutamide",
  "CHEMBL_ONVA",     "Onvansertib",
  "CHEMBL_DOX",      "Doxorubicin"
)
aliases <- tibble::tribble(
  ~alias_lower,    ~chembl_id,        ~type,
  "icotinib",      "CHEMBL_ICOTINIB", "SYNONYM",
  "bpi-2009h",     "CHEMBL_ICOTINIB", "RESEARCH_CODE",
  "cobimetinib",   "CHEMBL_COBI",     "SYNONYM",
  "gdc-0973",      "CHEMBL_COBI",     "RESEARCH_CODE",
  "gdc0973",       "CHEMBL_COBI",     "RESEARCH_CODE",
  "enzalutamide",  "CHEMBL_ENZA",     "SYNONYM",
  "mdv3100",       "CHEMBL_ENZA",     "RESEARCH_CODE",
  "onvansertib",   "CHEMBL_ONVA",     "SYNONYM",
  "nms-1286937",   "CHEMBL_ONVA",     "RESEARCH_CODE",
  "doxorubicin",   "CHEMBL_DOX",      "SYNONYM",
  "nsc-123127",    "CHEMBL_DOX",      "RESEARCH_CODE",
  "inhibitor",     "CHEMBL_DOX",      "GENERIC_TEST"
)
meta <- list(chembl_release = "ChEMBL_37 (fixture subset)",
             n_molecules = nrow(by_id), n_synonyms = nrow(aliases),
             fixture_subset = TRUE)
out <- file.path("inst", "extdata", "ontology-fixtures-mini", "chembl-mini.rds")
saveRDS(list(by_id = by_id, aliases = aliases, meta = meta), out)
cat("scritto:", out, "\n")
