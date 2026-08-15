#!/usr/bin/env Rscript
# EQUIVALENZA: gli stessi cluster calcolati in UN pezzo e in TRE pezzi paralleli.
#
# I risultati devono essere IDENTICI, non "simili": stesse righe, stessi valori,
# su tutte le colonne di `cluster_pooled` e `per_study_de`.
#
# Uso:
#   MODO=seriale  Rscript ... E1-equivalenza-shard.R
#   MODO=pezzo    PEZZO=1 N_PEZZI=3 Rscript ... E1-equivalenza-shard.R
#   MODO=confronto Rscript ... E1-equivalenza-shard.R
suppressPackageStartupMessages({ library(arrow); devtools::load_all(".", quiet = TRUE) })
SC   <- "analysis/audit/2026-08-13-rerun-prep/E1-equivalenza"
dir.create(SC, showWarnings = FALSE, recursive = TRUE)
V16  <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"
H5   <- "analysis/input/human_gene_v2.5.h5"
S2P  <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
DEL  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T121010Z-stage4-v16-3e31e59d"
MODO <- Sys.getenv("MODO", "seriale")

# --- i cluster del test: scelti per taglia, piu' uno che cade sotto il gate ---
scelta <- function() {
  d <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
  d <- d[order(d$k_effective), ]
  c(d$cluster_id[c(3, round(nrow(d) * 0.25), round(nrow(d) * 0.5),
                   round(nrow(d) * 0.75), nrow(d) - 2)],
    # e uno che NON passa il gate: deve restare fuori in tutti e due i modi
    readRDS(file.path(DEL, "non_processable.rds"))$cluster_id[1])
}

if (MODO == "confronto") {
  ser <- readRDS(file.path(SC, "seriale.rds"))
  pezzi <- lapply(1:3, function(i) readRDS(file.path(SC, sprintf("pezzo-%d.rds", i))))
  par <- list(
    cluster_pooled = do.call(rbind, lapply(pezzi, `[[`, "cluster_pooled")),
    per_study_de   = do.call(rbind, lapply(pezzi, `[[`, "per_study_de")))
  # ⚠️ `do.call(order, x[k])` passa le colonne come argomenti NOMINATI: la
  # colonna `method` finisce nel parametro `method` di order() ("'arg' must be
  # of length 1"). Vanno spogliate dei nomi.
  ordina <- function(x, k) x[do.call(order, unname(as.list(x[k]))), , drop = FALSE]
  ok <- TRUE
  for (tab in c("cluster_pooled", "per_study_de")) {
    a <- as.data.frame(ser[[tab]]); b <- as.data.frame(par[[tab]])
    cat("\n===", tab, "===\n")
    cat("  righe: seriale", nrow(a), "| pezzi", nrow(b),
        if (nrow(a) == nrow(b)) "OK" else "<<< DIVERSO", "\n")
    cat("  colonne identiche:", identical(sort(names(a)), sort(names(b))), "\n")
    k <- intersect(c("cluster_id", "gene_id", "study_id"), names(a))
    b <- b[names(a)]
    a <- ordina(a, c(k, setdiff(names(a), k)))
    b <- ordina(b, c(k, setdiff(names(b), k)))
    rownames(a) <- NULL; rownames(b) <- NULL
    id <- identical(a, b)
    cat("  identici (identical, tutte le colonne):", id, "\n")
    if (!id) {
      ok <- FALSE
      for (cc in names(a)) {
        va <- a[[cc]]; vb <- b[[cc]]
        if (is.numeric(va)) {
          dmax <- suppressWarnings(max(abs(va - vb), na.rm = TRUE))
          if (!is.finite(dmax) || dmax > 0) cat("   ", cc, ": scarto max", dmax, "\n")
        } else if (!identical(va, vb)) cat("   ", cc, ": DIVERSO\n")
      }
    }
  }
  cat("\nVERDETTO:", if (ok) "IDENTICI" else "NON IDENTICI", "\n")
  quit(status = if (ok) 0L else 1L)
}

cids <- scelta()
if (MODO == "pezzo") {
  i <- as.integer(Sys.getenv("PEZZO")); n <- as.integer(Sys.getenv("N_PEZZI"))
  mie <- cids[seq_along(cids) %% n == (i %% n)]
} else {
  mie <- cids
}
cat("MODO:", MODO, "| cluster:", length(mie), "\n"); print(mie)

cl  <- readRDS(file.path(V16, "clusters.rds"))
asg <- as.data.frame(read_parquet(file.path(V16, "assignments.parquet")))
s2  <- simulomicsr:::.load_stage2_master(S2P)
gsm <- unique(unlist(lapply(s2, function(st)
  unlist(lapply(st$replicate_groups, function(g) as.character(unlist(g$sample_ids)))))))
gse_of <- character(0)
for (st in s2) { v <- unlist(lapply(st$replicate_groups, function(g) as.character(unlist(g$sample_ids))))
  gse_of[v] <- st$series_id }
h5m <- tibble::tibble(sample_id = gsm, gsm = gsm, gse = unname(gse_of[gsm]), lib_size = 1e7L)
h5m <- h5m[!is.na(h5m$gse) & nzchar(h5m$gse), ]

t0 <- Sys.time()
res <- build_stage4_results(
  stage3_clusters = cl, h5_metadata = h5m, config = stage4_default_config(),
  h5_path = H5, stage3_assignments = asg, stage2_master = s2,
  cluster_subset = mie)
cat("wall:", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min\n")
out <- if (MODO == "pezzo") sprintf("pezzo-%s.rds", Sys.getenv("PEZZO")) else "seriale.rds"
saveRDS(list(cluster_pooled = as.data.frame(res$cluster_pooled),
             per_study_de   = as.data.frame(res$per_study_de)), file.path(SC, out))
cat("scritto:", file.path(SC, out), "| pooled", nrow(res$cluster_pooled),
    "righe | per-studio", nrow(res$per_study_de), "\n")
