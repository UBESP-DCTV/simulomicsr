#!/usr/bin/env Rscript
# Quanti worker convengono davvero? (2026-08-15)
#
# NEL RUN VERO HO SCELTO 8 SENZA MISURARE: era prudenza sulla memoria, non una
# misura. Qui si misura lo scaling della fase `summarize_clusters`.
#
# LIMITE DICHIARATO, importante: il carico e' una FIXTURE della forma giusta ma
# piu' LEGGERA del vero (i record veri portano anchor segments, hard filters e
# stage1_facts). Con lavoro piu' leggero l'overhead di `fork` e della
# serializzazione dei risultati pesa DI PIU', quindi questa misura e'
# CONSERVATIVA: lo scaling vero non puo' essere peggiore di questo.
suppressMessages(devtools::load_all(".", quiet = TRUE))
N_CLUSTER <- as.integer(Sys.getenv("N_CLUSTER", "40000"))
WS <- as.integer(strsplit(Sys.getenv("WORKERS", "1,4,8,16,32,64"), ",")[[1]])
cat("core disponibili:", parallel::detectCores(), "| cluster nella prova:", N_CLUSTER, "\n\n")

cids <- sprintf("cgroup_L5_%06d", seq_len(N_CLUSTER))
assignments <- data.frame(
  cluster_id = rep(cids, each = 3L), mode = "cgroup", level = 5L,
  anchor_key = rep(paste0("k", seq_len(N_CLUSTER)), each = 3L),
  record_id = sprintf("GSE%d__cmp%d", rep(seq_len(N_CLUSTER), each = 3L), 1:3),
  stringsAsFactors = FALSE)
recs <- new.env(hash = TRUE, parent = emptyenv())
for (i in seq_len(N_CLUSTER)) for (j in 1:3) {
  rid <- sprintf("GSE%d__cmp%d", i, j)
  segs <- c(kind = "cytokine_stim", agent = paste0("HGNC:", i %% 5000L))
  attr(segs, "tracking_meta") <- list(canonical_name = paste0("ent", i),
                                      agent_id_llm_original = "x", resolution_source = "y")
  assign(rid, list(record_id = rid, mode = "cgroup", series_id = sprintf("GSE%d", i),
                   treated_anchor_segments = segs, n_treated_group = 3L,
                   n_control_group = 3L,
                   treated_sample_ids = sprintf("S%d_%d_t", i, 1:3),
                   control_sample_ids = sprintf("S%d_%d_c", i, 1:3),
                   hard_filters = list(), stage1_facts = list()), envir = recs)
}
elig <- as.list(recs)
cfg <- stage3_default_config()
rss <- function() as.numeric(system("ps -eo rss --no-headers | awk '{s+=$1} END {print s}'",
                                    intern = TRUE)) / 1024^2

rif <- NULL; out <- list()
for (w in WS) {
  gc(); r0 <- rss(); t0 <- Sys.time()
  res <- .summarize_clusters(assignments, list(), list(), cfg, NULL,
                             eligible_cgroup = elig, workers = w)
  sec <- as.numeric(difftime(Sys.time(), t0, units = "secs")); r1 <- rss()
  if (is.null(rif)) rif <- res
  out[[length(out) + 1L]] <- data.frame(
    workers = w, secondi = round(sec, 1), accelerazione = NA_real_,
    efficienza = NA_real_, identico = identical(res, rif),
    RSS_totale_GB = round(r1, 1), stringsAsFactors = FALSE)
  cat(sprintf("  %3d worker: %7.1f s | identico al seriale: %s | RSS di sistema %.1f GB\n",
              w, sec, identical(res, rif), r1))
}
T <- do.call(rbind, out)
T$accelerazione <- round(T$secondi[1] / T$secondi, 2)
T$efficienza <- round(T$accelerazione / T$workers, 2)
cat("\n"); print(T, row.names = FALSE)
write.csv(T, "analysis/audit/2026-08-13-rerun-prep/E4-scaling-worker.csv", row.names = FALSE)
