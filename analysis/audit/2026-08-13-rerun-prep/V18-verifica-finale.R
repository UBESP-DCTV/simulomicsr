# La verifica finale del deliverable v16b, contro le previsioni depositate.
suppressMessages(devtools::load_all(".", quiet = TRUE))
P <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d"
D15 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
d <- readRDS(file.path(P, "deliverable-annotato.rds"))
d15 <- readRDS(file.path(D15, "deliverable-annotato.rds"))
cat("=== ANTI-STALE (dai file) ===\n")
cp <- arrow::read_parquet(file.path(P, "cluster_pooled.parquet"), col_select = c("cluster_id","method"))
cat("  method distinti:", paste(unique(cp$method), collapse=","), "\n")
cat("  cluster_id cgroup_L5_:", sum(startsWith(unique(cp$cluster_id), "cgroup_L5_")), "/",
    length(unique(cp$cluster_id)), "\n")
cat("  deliverable:", nrow(d), "(previsto 211 | v15: 214)\n")
cat("  incoerenti:", sum(d$coerenza_verdetto != "coherent"), "| NA:", sum(is.na(d$coerenza_verdetto)), "\n")

cat("\n=== I k_eff PREVISTI ===\n")
prev <- c("HGNC:11892"=38,"STR:hypoxia"=33,"NCBITaxon:2697049"=36,"HGNC:6018"=11,
          "HGNC:5977"=5,"HGNC:5438"=19,"HGNC:6014"=9,"HGNC:5973"=11,"HGNC:14900"=5,
          "NCBITaxon:1280"=3,"HGNC:5434"=6,"HGNC:11766"=59)
ok <- 0L
for (e in names(prev)) {
  r <- d[which(d$contrast_entity == e), ]; r15 <- d15[which(d15$contrast_entity == e), ]
  v <- if (nrow(r)) r$k_effective[1] else NA
  good <- !is.na(v) && v == prev[e]; ok <- ok + good
  cat(sprintf("  %-20s v15 %-4s -> v16b %-4s | previsto %-3s %s\n", e,
              if (nrow(r15)) r15$k_effective[1] else "-", ifelse(is.na(v), "ASSENTE", v),
              prev[e], if (good) "OK" else "<<< DIVERSO"))
}
cat("  ", ok, "/", length(prev), "\n")
for (e in c("NCBITaxon:1282", "CHEBI:63451")) {
  pres <- any(d$contrast_entity == e, na.rm = TRUE)
  cat(sprintf("  %-20s nel deliverable: %s (atteso: NO) %s\n", e, pres, if (!pres) "OK" else "<<<"))
}

cat("\n=== LE CORSIE HANNO AGITO? ===\n")
q <- readRDS(file.path(P, "qc_report.rds"))
cat("  lane_collapses:", nrow(q$lane_collapses), "righe (atteso: > 0)",
    if (nrow(q$lane_collapses) > 0L) "OK" else "<<< VUOTO", "\n")
if (nrow(q$lane_collapses)) print(head(q$lane_collapses[, c("libreria","n_campioni","cluster_id","study_id")], 3))
cat("  dispatch_drops:", nrow(q$dispatch_drops), "| motivi:",
    paste(names(table(q$dispatch_drops$motivo)), table(q$dispatch_drops$motivo), collapse=" | "), "\n")
psd <- arrow::read_parquet(file.path(P, "per_study_de.parquet"), col_select = c("cluster_id","study_id"))
n173 <- length(unique(paste(psd$cluster_id, psd$study_id)[psd$study_id == "GSE173902"]))
cat("  confronti di GSE173902 nel per_study_de:", n173, "(v16 seriale ne aveva 7)",
    if (n173 == 0L) "OK" else "<<< ancora presenti", "\n")
cat("  covariate_drops:", nrow(q$covariate_drops %||% data.frame()), "righe\n")

cat("\n=== righe entrate/uscite rispetto a v15 ===\n")
u <- setdiff(d15$cluster_id, d$cluster_id); e2 <- setdiff(d$cluster_id, d15$cluster_id)
cat("  uscite:", length(u), "->", paste(d15$canonical_name[match(u, d15$cluster_id)], collapse=" | "), "\n")
cat("  entrate:", length(e2), if (length(e2)) paste(e2, collapse=" ") else "", "\n")
