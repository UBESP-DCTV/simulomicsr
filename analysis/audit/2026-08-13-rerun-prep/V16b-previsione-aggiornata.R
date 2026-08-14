# La previsione RICALCOLATA sull'output v16 vero, prima del re-pool.
# ⚠️ La previsione depositata assumeva che il solo delta di codice rispetto a v15
# fosse D2. NON era vero: il 2026-08-09 era entrato anche il fix IFN-beta
# (`.CA_DEFRAG_ACCEPT` + "ifnb"), con la nota «si materializza solo al prossimo
# re-cluster». Questo E' quel re-cluster.
suppressMessages(devtools::load_all(".", quiet = TRUE))
V16 <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"
V15 <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
SC  <- "analysis/audit/2026-08-13-rerun-prep"
OLD <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

c16 <- readRDS(file.path(V16, "clusters.rds")); c15 <- readRDS(file.path(V15, "clusters.rds"))
a16 <- arrow::read_parquet(file.path(V16, "assignments.parquet"))
s2  <- readRDS(file.path(OLD, "s2.rds")); lk <- readRDS(file.path(SC, "D1-lookup.rds"))
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
cfg <- stage4_default_config()

A16 <- .identify_layer_a_clusters(c16, cfg); f16 <- attr(A16, "fusioni"); A16 <- A16[A16$method=="rem_group",]
A15 <- .identify_layer_a_clusters(c15, cfg); f15 <- attr(A15, "fusioni"); A15 <- A15[A15$method=="rem_group",]
cat("candidati: v15", nrow(A15), "| v16", nrow(A16), "\n")
esce <- setdiff(A15$cluster_id, A16$cluster_id); entra <- setdiff(A16$cluster_id, A15$cluster_id)
cat("\nescono dai candidati:", length(esce), "\n")
for (x in esce) cat(sprintf("   %-22s k15=%s ent=%s %s\n", x, c15$k[match(x,c15$cluster_id)],
   c15$contrast_entity[match(x,c15$cluster_id)], ifelse(x %in% del$cluster_id, "[era nel 214]", "")))
cat("entrano:", length(entra), "\n")
for (x in entra) cat(sprintf("   %-22s k16=%s ent=%s\n", x, c16$k[match(x,c16$cluster_id)],
   c16$contrast_entity[match(x,c16$cluster_id)]))

asg_by <- split(a16$record_id, a16$cluster_id)
comp <- setNames(as.list(A16$cluster_id), A16$cluster_id)
if (!is.null(f16) && nrow(f16)) for (w in unique(f16$cluster_id_vincente))
  if (w %in% names(comp)) comp[[w]] <- c(w, f16$cluster_id_assorbito[f16$cluster_id_vincente == w])
keff <- function(cids) {
  rid <- unlist(asg_by[intersect(cids, names(asg_by))], use.names = FALSE)
  if (!length(rid)) return(0L)
  el <- data.frame(cluster_id="__X__", mode="cgroup", method="rem_group", stringsAsFactors=FALSE)
  d <- .build_group_rem_dispatch_from_stage3(el,
        data.frame(record_id=rid, cluster_id="__X__", stringsAsFactors=FALSE),
        s2, n_min=2L, lane_lookup=lk)
  if (!length(d)) return(0L)
  length(unique(vapply(d[["__X__"]], function(x) x$study_id, character(1))))
}
K <- vapply(names(comp), function(c0) keff(comp[[c0]]), integer(1))
cat("\n=== PREVISIONE AGGIORNATA DEL DELIVERABLE ===\n")
cat("candidati:", length(K), "| passano k_eff>=3:", sum(K >= 3L),
    "| non processabili:", sum(K < 3L), "\n")
cat("(previsione depositata: 212 su 351 candidati)\n\n")
band <- c("HGNC:11892","STR:hypoxia","NCBITaxon:2697049","HGNC:6018","HGNC:5977",
          "CHEBI:63451","HGNC:5438","HGNC:6014","HGNC:5973","HGNC:14900",
          "NCBITaxon:1280","NCBITaxon:1282","HGNC:5434","HGNC:11766")
prev <- c("HGNC:11892"=38,"STR:hypoxia"=33,"NCBITaxon:2697049"=36,"HGNC:6018"=11,
          "HGNC:5977"=5,"CHEBI:63451"=2,"HGNC:5438"=19,"HGNC:6014"=9,"HGNC:5973"=11,
          "HGNC:14900"=5,"NCBITaxon:1280"=3,"NCBITaxon:1282"=2)
for (e in band) {
  ids <- A16$cluster_id[which(A16$contrast_entity == e)]
  for (c0 in ids) cat(sprintf("  %-20s %-22s k=%3d k_eff=%2d  previsto=%s %s\n", e, c0,
    A16$k[A16$cluster_id==c0], K[c0], ifelse(is.na(prev[e]), "-", prev[e]),
    ifelse(K[c0] >= 3L, "", "(sotto il gate)")))
}
saveRDS(list(K=K, A16=A16, fusioni=f16, esce=esce, entra=entra),
        file.path(SC, "V16b-previsione.rds"))
