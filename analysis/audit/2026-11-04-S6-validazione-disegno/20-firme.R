#!/usr/bin/env Rscript
# Che cosa contiene LINCS, dai soli metadati. Nessun dato Level 5, nessuna stima del deliverable.
source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
si <- fread(file.path(LIN, "siginfo_beta.txt"), sep = "\t", quote = "", colClasses = "character",
  select = c("sig_id","pert_id","pert_type","cmap_name","cell_iname","pert_idose","pert_itime","tas","ss_ngene","cc_q75","pct_self_rank_q25","median_recall_rank_spearman","is_exemplar_sig","is_ncs_sig","is_hiq","qc_pass","is_null_sig","nsample","project_code"))
for (v in c("tas","ss_ngene","cc_q75","pct_self_rank_q25","median_recall_rank_spearman")) set(si, j = v, value = suppressWarnings(as.numeric(si[[v]])))
cat("firme:", nrow(si), "\n"); print(si[, .(firme = .N, pert = uniqueN(pert_id), exemplar = sum(is_exemplar_sig == "1"), hiq = sum(is_hiq == "1")), by = pert_type][order(-firme)])
cat("\nquantili di tas, trt_cp:\n"); print(quantile(si[pert_type == "trt_cp", tas], c(.1,.25,.5,.75,.9), na.rm = TRUE))
cat("exemplar per coppia composto-linea, trt_cp (massimo):", si[pert_type == "trt_cp" & is_exemplar_sig == "1", .N, by = .(pert_id, cell_iname)][, max(N)], "\n")
cp <- si[pert_type == "trt_cp"]
sf <- cp[, .(firme = .N, linee = uniqueN(cell_iname), exemplar = sum(is_exemplar_sig == "1"), linee_ex = uniqueN(cell_iname[is_exemplar_sig == "1"]),
  attive = sum(is_exemplar_sig == "1" & tas >= 0.2, na.rm = TRUE), linee_attive = uniqueN(cell_iname[is_exemplar_sig == "1" & tas >= 0.2 & !is.na(tas)]),
  tas_max = suppressWarnings(max(tas, na.rm = TRUE)), tas_med = median(tas[is_exemplar_sig == "1"], na.rm = TRUE)), by = pert_id]
cat("\ncomposti trt_cp:", nrow(sf), "; con almeno 3 linee attive:", sf[linee_attive >= 3, .N], "; con almeno 3 exemplar in 3 linee:", sf[linee_ex >= 3, .N], "\n")
saveRDS(si, file.path(PES6, "si.rds"))
fwrite(sf, file.path(OUT6, "20-composti-lincs.csv"))
lig <- si[pert_type == "trt_lig"]
print(as.data.frame(lig[, .(firme = .N, linee = uniqueN(cell_iname), ex = sum(is_exemplar_sig == "1"), attive = sum(tas >= 0.2, na.rm = TRUE), tas_med = round(median(tas, na.rm = TRUE), 3)), by = cmap_name][order(-firme)]))
