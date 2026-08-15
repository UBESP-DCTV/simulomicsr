#!/usr/bin/env Rscript
# EQUIVALENZA COMPLETA: dati E registri, seriale contro pezzi ricomposti.
# Il primo test (E1) confrontava solo le due tabelle; questo salva l'oggetto
# intero e confronta anche i registri, che sono cio' che rende auditabile uno
# scarto. Cluster piccoli, per poter rifare tutto in pochi minuti.
suppressPackageStartupMessages({ library(arrow); devtools::load_all(".", quiet = TRUE) })
SC   <- "analysis/audit/2026-08-13-rerun-prep/E2-equivalenza"
dir.create(SC, showWarnings = FALSE, recursive = TRUE)
V16  <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"
H5   <- "analysis/input/human_gene_v2.5.h5"
S2P  <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
DEL  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T121010Z-stage4-v16-3e31e59d"
MODO <- Sys.getenv("MODO", "seriale")

scelta <- function() {
  d <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
  d <- d[order(d$n_sig), ]                      # i piu' piccoli: veloci
  c(head(d$cluster_id, 4), readRDS(file.path(DEL, "non_processable.rds"))$cluster_id[2])
}

if (MODO == "confronto") {
  ser <- readRDS(file.path(SC, "seriale.rds"))
  pezzi <- lapply(1:2, function(i) readRDS(file.path(SC, sprintf("pezzo-%d.rds", i))))
  uni <- merge_stage4_shards(pezzi)
  norm <- function(x, k) { x <- as.data.frame(x)
    x <- x[do.call(order, unname(as.list(x[intersect(k, names(x))]))), , drop = FALSE]
    rownames(x) <- NULL; x }
  ok <- TRUE
  cat("=== DATI ===\n")
  for (tab in c("cluster_pooled", "per_study_de")) {
    k <- c("cluster_id", "gene_id", "study_id")
    a <- norm(ser[[tab]], k); b <- norm(uni[[tab]], k)[names(as.data.frame(ser[[tab]]))]
    b <- norm(b, k)
    col_ok <- vapply(names(a), function(cc) identical(a[[cc]], b[[cc]]), logical(1))
    cat(sprintf("  %-16s righe %d vs %d | colonne identiche %d/%d %s\n", tab,
                nrow(a), nrow(b), sum(col_ok), length(col_ok),
                if (nrow(a) == nrow(b) && all(col_ok)) "OK" else "<<< DIVERSO"))
    if (!(nrow(a) == nrow(b) && all(col_ok))) { ok <- FALSE; print(names(col_ok)[!col_ok]) }
  }
  cat("\n=== REGISTRI ===\n")
  for (nm in c("role_conflicts", "lane_collapses", "covariate_drop_log")) {
    a <- attr(ser$per_study_de, nm); b <- attr(uni$per_study_de, nm)
    na <- if (is.data.frame(a)) nrow(a) else length(a); nb <- if (is.data.frame(b)) nrow(b) else length(b)
    cat(sprintf("  %-20s seriale %-5s pezzi %-5s %s\n", nm, na, nb,
                if (identical(na, nb)) "OK" else "<<< DIVERSO"))
    if (!identical(na, nb)) ok <- FALSE
  }
  for (nm in names(ser$qc_report)) {
    a <- ser$qc_report[[nm]]; b <- uni$qc_report[[nm]]
    if (!is.data.frame(a)) next
    cat(sprintf("  qc_report$%-16s seriale %-5d pezzi %-5d %s\n", nm, nrow(a),
                if (is.data.frame(b)) nrow(b) else -1L,
                if (is.data.frame(b) && nrow(a) == nrow(b)) "OK" else "<<< DIVERSO"))
    if (!(is.data.frame(b) && nrow(a) == nrow(b))) ok <- FALSE
  }
  cat("\nVERDETTO:", if (ok) "EQUIVALENTI (dati e registri)" else "NON EQUIVALENTI", "\n")
  quit(status = if (ok) 0L else 1L)
}

cids <- scelta()
mie <- if (MODO == "pezzo") {
  i <- as.integer(Sys.getenv("PEZZO")); n <- as.integer(Sys.getenv("N_PEZZI"))
  cids[seq_along(cids) %% n == (i %% n)]
} else cids
cat("MODO:", MODO, "| cluster:", length(mie), "\n")
cl  <- readRDS(file.path(V16, "clusters.rds"))
asg <- as.data.frame(read_parquet(file.path(V16, "assignments.parquet")))
s2  <- simulomicsr:::.load_stage2_master(S2P)
gse_of <- character(0)
for (st in s2) { v <- unlist(lapply(st$replicate_groups, function(g) as.character(unlist(g$sample_ids))))
  gse_of[v] <- st$series_id }
gsm <- names(gse_of)
h5m <- tibble::tibble(sample_id = gsm, gsm = gsm, gse = unname(gse_of), lib_size = 1e7L)
t0 <- Sys.time()
res <- build_stage4_results(stage3_clusters = cl, h5_metadata = h5m,
  config = stage4_default_config(), h5_path = H5, stage3_assignments = asg,
  stage2_master = s2, cluster_subset = mie)
cat("wall:", round(as.numeric(difftime(Sys.time(), t0, units="mins")), 1), "min\n")
saveRDS(res, file.path(SC, if (MODO == "pezzo") sprintf("pezzo-%s.rds", Sys.getenv("PEZZO")) else "seriale.rds"))
cat("scritto | pooled", nrow(res$cluster_pooled), "| per-studio", nrow(res$per_study_de), "\n")
