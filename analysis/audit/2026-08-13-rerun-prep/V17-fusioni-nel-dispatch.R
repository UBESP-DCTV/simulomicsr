# La verifica che mancava: dopo il fix, il `k` dichiarato dalla fusione e' quello
# che il dispatch realizza davvero. Sui dati veri, non su fixture.
suppressMessages(devtools::load_all(".", quiet = TRUE))
V16 <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"
cl  <- readRDS(file.path(V16, "clusters.rds"))
asg <- as.data.frame(arrow::read_parquet(file.path(V16, "assignments.parquet")))
s2  <- readRDS("analysis/audit/2026-08-12-corsie/s2.rds")
lk  <- readRDS("analysis/audit/2026-08-13-rerun-prep/D1-lookup.rds")
cfg <- stage4_default_config()
A <- .identify_layer_a_clusters(cl, cfg); fus <- attr(A, "fusioni")
A <- A[A$method == "rem_group", ]
cat("fusioni:", nrow(fus), "\n\n")
asg2 <- .reassign_absorbed_records(asg, fus)
cat("record spostati:", sum(asg$cluster_id != asg2$cluster_id), "\n\n")
d0 <- .build_group_rem_dispatch_from_stage3(A, asg,  s2, n_min = 2L, lane_lookup = lk)
d1 <- .build_group_rem_dispatch_from_stage3(A, asg2, s2, n_min = 2L, lane_lookup = lk)
ns <- function(d, cid) if (is.null(d[[cid]])) 0L else
  length(unique(vapply(d[[cid]], function(x) x$study_id, character(1))))
cat(sprintf("%-22s %-28s  prima  dopo  atteso\n", "cluster", "entita"))
att <- c("HGNC:11892"=38, "STR:hypoxia"=33, "NCBITaxon:2697049"=36,
         "HGNC:6018"=11, "HGNC:5977"=5, "CHEBI:63451"=2, "CHEBI:80240"=2)
for (w in unique(fus$cluster_id_vincente)) {
  e <- A$contrast_entity[match(w, A$cluster_id)]
  cat(sprintf("%-22s %-28s  %4d  %4d  %s %s\n", w, e, ns(d0, w), ns(d1, w),
              ifelse(is.na(att[e]), "-", att[e]),
              ifelse(!is.na(att[e]) && ns(d1, w) == att[e], "OK", "")))
}
k_eff <- vapply(A$cluster_id, function(c0) ns(d1, c0), integer(1))
cat("\ncandidati:", nrow(A), "| passano k_eff>=3:", sum(k_eff >= 3L), "\n")
saveRDS(k_eff, "analysis/audit/2026-08-13-rerun-prep/V17-keff.rds")
