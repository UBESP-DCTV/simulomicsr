#!/usr/bin/env Rscript
# CONTEGGIO 1 (seguito): quante FIRME LINCS esistono per ogni composto agganciato,
# in quante linee cellulari e a quante dosi. Tabella finale per entita' -> CSV.

suppressMessages({library(data.table)})
LIN <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
OUT <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"
log <- function(...) cat(sprintf(...), "\n", sep = "")

x  <- readRDS(file.path(OUT, "10-match-intermedio.rds"))
c1 <- as.data.table(x$cand)
ci <- x$ci_u

# ------------------------------------------------------------------- siginfo
si <- fread(file.path(LIN, "siginfo_beta.txt"), sep = "\t", quote = "",
            select = c("sig_id", "pert_id", "pert_type", "cmap_name",
                       "cell_iname", "pert_dose", "pert_idose", "pert_time",
                       "is_exemplar_sig", "qc_pass"),
            colClasses = "character")
log("siginfo: %d righe", nrow(si))
print(table(si$pert_type)[order(-table(si$pert_type))][1:6])

cp <- si[pert_type == "trt_cp"]
log("firme trt_cp: %d, su %d pert_id distinti", nrow(cp), uniqueN(cp$pert_id))

agg <- cp[, .(n_firme_trt_cp = .N,
              n_linee_cellulari = uniqueN(cell_iname),
              n_dosi = uniqueN(pert_idose),
              n_tempi = uniqueN(pert_time),
              n_firme_exemplar = sum(is_exemplar_sig == "1", na.rm = TRUE)),
          by = pert_id]
setkey(agg, pert_id)
log("aggregato per pert_id: %d righe", nrow(agg))

# ----------------------------------------------- somma per entita' (piu' pert_id)
somma <- function(pstr, col) {
  if (!nzchar(pstr)) return(0L)
  ps <- strsplit(pstr, ";")[[1]]
  sum(agg[ps, on = "pert_id"][[col]], na.rm = TRUE)
}
distinti <- function(pstr, col) {
  if (!nzchar(pstr)) return(0L)
  ps <- strsplit(pstr, ";")[[1]]
  uniqueN(cp[pert_id %in% ps][[col]])
}
c1[, n_firme_lincs   := vapply(pert_id, somma, numeric(1), col = "n_firme_trt_cp")]
c1[, n_firme_exemplar:= vapply(pert_id, somma, numeric(1), col = "n_firme_exemplar")]
c1[, n_linee_lincs   := vapply(pert_id, distinti, numeric(1), col = "cell_iname")]
c1[, n_dosi_lincs    := vapply(pert_id, distinti, numeric(1), col = "pert_idose")]
c1[, nome_lincs := vapply(pert_id, function(p) {
      if (!nzchar(p)) return(NA_character_)
      paste(unique(ci$cmap_name[match(strsplit(p, ";")[[1]], ci$pert_id)]), collapse = ";")
    }, character(1))]
c1[, agganciata := metodo_match != "nessuno"]

# un composto agganciato ma con ZERO firme trt_cp esiste in anagrafica, non in dati
log("")
log("=== ESITO ===")
log("candidati (CHEBI+CHEMBL)                 : %d", nrow(c1))
log("agganciati a un pert_id LINCS            : %d", sum(c1$agganciata))
log("  di cui con >=1 firma trt_cp            : %d", sum(c1$n_firme_lincs > 0))
log("  agganciati ma con 0 firme trt_cp       : %d", sum(c1$agganciata & c1$n_firme_lincs == 0))
log("non agganciati                           : %d", sum(!c1$agganciata))
log("")
log("metodo di match:"); print(table(c1$metodo_match))
log("")
log("distribuzione n_firme_lincs (solo agganciati con firme):")
print(summary(c1$n_firme_lincs[c1$n_firme_lincs > 0]))
log("")
log("=== k_effective delle agganciate CON firme ===")
h <- c1[n_firme_lincs > 0]
log("k_effective >= 10 : %d", sum(h$k_effective >= 10))
log("k_effective 5-9   : %d", sum(h$k_effective >= 5 & h$k_effective < 10))
log("k_effective 3-4   : %d", sum(h$k_effective < 5))
log("")
log("=== per confronto, k_effective dei NON agganciati ===")
n <- c1[n_firme_lincs == 0]
log("k>=10: %d | k 5-9: %d | k 3-4: %d", sum(n$k_effective >= 10),
    sum(n$k_effective >= 5 & n$k_effective < 10), sum(n$k_effective < 5))

cols <- c("contrast_entity", "nome_risolto", "contrast_entity_label", "canonical_name",
          "kind_effective_resolved", "metodo_match", "n_inchikey", "pert_id",
          "nome_lincs", "n_pert_id", "n_firme_lincs", "n_firme_exemplar",
          "n_linee_lincs", "n_dosi_lincs",
          "k_effective", "k_kish", "n_sig", "n_studi_poolati", "coherence_verdict")
out <- c1[order(-n_firme_lincs, -k_effective), ..cols]
fwrite(out, file.path(OUT, "copertura-lincs-per-entita.csv"))
log("")
log("CSV: %s (%d righe)", file.path(OUT, "copertura-lincs-per-entita.csv"), nrow(out))

saveRDS(c1, file.path(OUT, "20-entita-con-firme.rds"))
