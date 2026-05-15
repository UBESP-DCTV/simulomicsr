#!/usr/bin/env Rscript
# p4-beta-stage1-merge.R --- β Task 10 + 10b merge finale
#
# Concatena tutti i predictions.jsonl di 90 run dirs DGX (89 chunks da 10k +
# 1 outliers da 26 record) in un singolo master file locale. Total atteso:
# 888.821 record (= 888.795 chunks + 26 outliers).
#
# Esegue cat lato server (rapido) poi rsync del file singolo. Non parsa il
# JSON (concat raw); il parsing con parse_stage1_response() avviene in fase
# successiva di analisi (es. tibble + post-processing per Stadio 2).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

OUTPUT_DIR <- "analysis/p4-output"
MASTER     <- file.path(OUTPUT_DIR, "p4-beta-stage1-master-predictions.jsonl")
EXPECTED   <- 888821L

chunk_rds   <- list.files(OUTPUT_DIR,
                          pattern = "-beta-stage1-chunk[0-9]+-.*-job\\.rds$",
                          full.names = TRUE)
outlier_rds <- list.files(OUTPUT_DIR,
                          pattern = "-beta-stage1-outliers-.*-job\\.rds$",
                          full.names = TRUE)
all_rds <- c(chunk_rds, outlier_rds)
cat(sprintf("Trovati %d job_rds (%d chunks + %d outliers)\n",
            length(all_rds), length(chunk_rds), length(outlier_rds)))
stopifnot(length(chunk_rds) == 89L, length(outlier_rds) == 1L)

jobs <- lapply(all_rds, readRDS)
run_ids <- vapply(jobs, function(j) j$run_id, character(1))
cfg <- jobs[[1]]$config

remote_files <- paste0(cfg$remote_root, "/runs/", run_ids, "/predictions.jsonl")
remote_master <- paste0(cfg$remote_root, "/runs/p4-beta-stage1-master-predictions.jsonl")

# Verifica remote files esistano + righe totali atteso
check_cmd <- sprintf(
  "for f in %s; do test -f \"$f\" || { echo MISSING:$f; exit 1; }; done; echo OK_ALL_PRESENT; wc -l %s | tail -1",
  paste(shQuote(remote_files), collapse = " "),
  paste(shQuote(remote_files), collapse = " ")
)
cat("Verifica presenza predictions.jsonl su DGX...\n")
res <- simulomicsr:::.dgx_ssh(cfg, check_cmd)
cat(res$stdout, "\n")

# Cat remoto in master
cat("Cat remoto -> master singolo su DGX...\n")
cat_cmd <- sprintf(
  "cat %s > %s && wc -l %s",
  paste(shQuote(remote_files), collapse = " "),
  shQuote(remote_master),
  shQuote(remote_master)
)
res <- simulomicsr:::.dgx_ssh(cfg, cat_cmd)
cat(res$stdout, "\n")

# Rsync master file local
cat("Rsync master file -> local...\n")
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
simulomicsr:::.dgx_rsync(cfg,
                         local_path  = MASTER,
                         remote_path = remote_master,
                         direction   = "pull")

# Verifica
n_local <- length(readLines(MASTER, warn = FALSE))
size_mb <- file.info(MASTER)$size / 1e6
cat(sprintf("\nMaster file: %s\n  %d righe (atteso %d)\n  %.1f MB\n",
            MASTER, n_local, EXPECTED, size_mb))
stopifnot(n_local == EXPECTED)
cat("OK merge\n")
