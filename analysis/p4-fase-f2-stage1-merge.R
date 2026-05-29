#!/usr/bin/env Rscript
# p4-fase-f2-stage1-merge.R --- RED ALERT FASE F2 merge finale Stadio 1 v2
#
# Concatena i predictions.jsonl dei 52 run dir DGX (51 chunk + 1 outlier) in un
# singolo master locale. Total atteso: 508.037 record (= 508.012 mainstream +
# 25 outlier). Cat lato server poi rsync del file singolo (no parse del JSON;
# il parsing/validazione avviene a valle).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

OUTPUT_DIR <- "analysis/p4-output"
MASTER     <- file.path(OUTPUT_DIR, "p4-fase-f2-stage1-master-predictions.jsonl")
EXPECTED   <- 508037L

chunk_rds   <- list.files(OUTPUT_DIR,
                          pattern = "-f2-stage1-chunk[0-9]+-.*-job\\.rds$",
                          full.names = TRUE)
outlier_rds <- list.files(OUTPUT_DIR,
                          pattern = "-f2-stage1-outliers-.*-job\\.rds$",
                          full.names = TRUE)
all_rds <- c(chunk_rds, outlier_rds)
cat(sprintf("Trovati %d job_rds (%d chunk + %d outlier)\n",
            length(all_rds), length(chunk_rds), length(outlier_rds)))
stopifnot(length(chunk_rds) == 51L, length(outlier_rds) == 1L)

jobs <- lapply(all_rds, readRDS)
run_ids <- vapply(jobs, function(j) j$run_id, character(1))
cfg <- jobs[[1]]$config

remote_files  <- paste0(cfg$remote_root, "/runs/", run_ids, "/predictions.jsonl")
remote_master <- paste0(cfg$remote_root, "/runs/p4-fase-f2-stage1-master-predictions.jsonl")

# Verifica presenza + righe totali
check_cmd <- sprintf(
  "for f in %s; do test -f \"$f\" || { echo MISSING:$f; exit 1; }; done; echo OK_ALL_PRESENT; cat %s | wc -l",
  paste(shQuote(remote_files), collapse = " "),
  paste(shQuote(remote_files), collapse = " ")
)
cat("Verifica presenza predictions.jsonl su DGX...\n")
res <- simulomicsr:::.dgx_ssh(cfg, check_cmd)
cat(res$stdout, "\n")

# Cat remoto -> master singolo
cat("Cat remoto -> master singolo su DGX...\n")
cat_cmd <- sprintf(
  "cat %s > %s && wc -l %s",
  paste(shQuote(remote_files), collapse = " "),
  shQuote(remote_master),
  shQuote(remote_master)
)
res <- simulomicsr:::.dgx_ssh(cfg, cat_cmd)
cat(res$stdout, "\n")

# Rsync master -> local
cat("Rsync master -> local...\n")
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
simulomicsr:::.dgx_rsync(cfg,
                         local_path  = MASTER,
                         remote_path = remote_master,
                         direction   = "pull")

n_local <- length(readLines(MASTER, warn = FALSE))
size_mb <- file.info(MASTER)$size / 1e6
cat(sprintf("\nMaster file: %s\n  %d righe (atteso %d)\n  %.1f MB\n",
            MASTER, n_local, EXPECTED, size_mb))
stopifnot(n_local == EXPECTED)
cat("OK merge\n")
