#!/usr/bin/env Rscript
# (a) conteggio SUPPLEMENTARE: le entita' citochina/ligando del deliverable
#     esistono in LINCS come perturbagene `trt_lig` (non `trt_cp`)?
# (b) casi BORDERLINE fra i 21 non agganciati: LINCS ha un composto imparentato
#     ma non identico. Li elenco, non li conto.

suppressMessages({library(data.table)})
LIN <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
OUT <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/deliverable-annotato.rds"
log <- function(...) cat(sprintf(...), "\n", sep = "")

si <- fread(file.path(LIN, "siginfo_beta.txt"), sep = "\t", quote = "",
            select = c("pert_id", "pert_type", "cmap_name", "cell_iname",
                       "pert_dose", "pert_idose"), colClasses = "character")

lig <- si[pert_type == "trt_lig"]
agg <- lig[, .(n_firme = .N, n_linee = uniqueN(cell_iname), n_dosi = uniqueN(pert_idose)),
           by = cmap_name][order(-n_firme)]
log("=== LINCS trt_lig: %d firme, %d perturbageni distinti ===", nrow(lig), nrow(agg))
print(agg)

d  <- readRDS(DEL)
i  <- grep("^HGNC:", d$contrast_entity)
hg <- data.table(id = d$contrast_entity[i], simbolo = d$contrast_entity_label[i],
                 kind = d$kind_effective_resolved[i], k = d$k_effective[i])
# il simbolo va risolto dall'ID, non letto dall'etichetta
hl  <- readRDS("~/.cache/R/simulomicsr/hgnc-lookup.rds")
hid <- as.data.table(hl$by_hgnc_int)
hg[, simbolo_risolto := hid$symbol[match(as.integer(sub("^HGNC:", "", id)), hid$hgnc_int)]]
# sinonimi HGNC, per non perdere i ligandi che LINCS scrive con un alias
al <- as.data.table(hl$aliases_long)

lign <- toupper(agg$cmap_name)
hg[, lincs_trt_lig := toupper(simbolo_risolto) %in% lign]
hg[, n_firme_lig := agg$n_firme[match(toupper(simbolo_risolto), lign)]]

log("")
log("=== entita' HGNC del deliverable (%d) contro trt_lig ===", nrow(hg))
print(hg[order(-k), .(id, simbolo_risolto, simbolo_etichetta = simbolo, kind, k,
                      lincs_trt_lig, n_firme_lig)])
log("")
log("HGNC agganciate a un trt_lig per simbolo ESATTO: %d/%d",
    sum(hg$lincs_trt_lig), nrow(hg))
log("nomi trt_lig NON risolvibili a un nostro simbolo esatto (famiglie/alias): %s",
    paste(setdiff(agg$cmap_name, hg$simbolo_risolto), collapse = ", "))

fwrite(hg, file.path(OUT, "copertura-trtlig-entita-hgnc.csv"))

# ------------------------------------------------------------------ borderline
log("")
log("=== BORDERLINE: composto LINCS imparentato ma NON identico (NON contato) ===")
ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "",
            colClasses = "character")
for (p in c("bleomycin", "nutlin", "RG-7388", "perfluor")) {
  h <- unique(ci[grepl(p, cmap_name, ignore.case = TRUE), .(pert_id, cmap_name, inchi_key)])
  log("  cercato '%s' in cmap_name -> %d pert_id", p, nrow(h))
  if (nrow(h)) print(h)
}
