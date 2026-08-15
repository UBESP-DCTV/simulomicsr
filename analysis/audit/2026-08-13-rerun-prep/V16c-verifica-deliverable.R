# La verifica finale sul DELIVERABLE v16, contro le previsioni depositate.
# Anti-stale: si legge dai FILE, non dal log.
suppressMessages(devtools::load_all(".", quiet = TRUE))
P <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T121010Z-stage4-v16-3e31e59d"
D15 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
d <- readRDS(file.path(P, "deliverable-annotato.rds"))
d15 <- readRDS(file.path(D15, "deliverable-annotato.rds"))
cat("=== ANTI-STALE (dai file) ===\n")
rm <- jsonlite::fromJSON(file.path(P, "run_metadata.json"))
cat("  Methods:", paste(unlist(rm$deliverable_methods %||% rm$config$deliverable_methods), collapse=","), "\n")
cp <- arrow::read_parquet(file.path(P, "cluster_pooled.parquet"), col_select=c("cluster_id","method"))
cat("  method distinti in cluster_pooled:", paste(unique(cp$method), collapse=","), "\n")
cat("  cluster_id col prefisso cgroup_L5_:",
    sum(startsWith(unique(cp$cluster_id), "cgroup_L5_")), "/", length(unique(cp$cluster_id)), "\n")
cat("  righe pooled:", nrow(cp), "| deliverable:", nrow(d), "(v15:", nrow(d15), ")\n")
cat("  incoerenti dichiarate:", sum(d$coerenza_verdetto != "coherent", na.rm=TRUE),
    "| NA:", sum(is.na(d$coerenza_verdetto)), "\n")

cat("\n=== I k_eff PREVISTI, sul deliverable vero ===\n")
prev <- c("HGNC:11892"=38,"STR:hypoxia"=33,"NCBITaxon:2697049"=36,"HGNC:6018"=11,
          "HGNC:5977"=5,"HGNC:5438"=19,"HGNC:6014"=9,"HGNC:5973"=11,
          "HGNC:14900"=5,"NCBITaxon:1280"=3,"NCBITaxon:1282"=NA,"HGNC:5434"=6,
          "HGNC:11766"=59)
for (e in names(prev)) {
  r <- d[which(d$contrast_entity == e), ]
  r15 <- d15[which(d15$contrast_entity == e), ]
  cat(sprintf("  %-20s v15 k_eff=%-4s | v16 k_eff=%-4s | previsto=%-4s %s\n", e,
              if (nrow(r15)) r15$k_effective[1] else "-",
              if (nrow(r)) r$k_effective[1] else "ASSENTE",
              ifelse(is.na(prev[e]), "esce", prev[e]),
              if (nrow(r) && !is.na(prev[e]) && r$k_effective[1] == prev[e]) "OK" else "<<< DIVERSO"))
}
cat("\n=== LE CORSIE HANNO AGITO? ===\n")
q <- readRDS(file.path(P, "qc_report.rds"))
cat("  lane_collapses:", nrow(q$lane_collapses), "righe (atteso: >0 se il collasso ha agito)\n")
cat("  dispatch_drops:", nrow(q$dispatch_drops), "righe |",
    paste(names(table(q$dispatch_drops$motivo)), table(q$dispatch_drops$motivo), collapse=" | "), "\n")
cat("  GSE173902 nel poolato:",
    sum(q$dispatch_drops$study_id == "GSE173902"), "scarti registrati\n")
psd <- arrow::read_parquet(file.path(P, "per_study_de.parquet"), col_select=c("cluster_id","study_id"))
cat("  confronti di GSE173902 ANCORA nel per_study_de:",
    length(unique(paste(psd$cluster_id, psd$study_id)[psd$study_id == "GSE173902"])), "\n")
cat("\n=== righe entrate/uscite rispetto a v15 ===\n")
cat("  uscite:", paste(setdiff(d15$cluster_id, d$cluster_id), collapse=" "), "\n")
cat("    nomi:", paste(d15$canonical_name[match(setdiff(d15$cluster_id, d$cluster_id), d15$cluster_id)], collapse=" | "), "\n")
cat("  entrate:", paste(setdiff(d$cluster_id, d15$cluster_id), collapse=" "), "\n")
