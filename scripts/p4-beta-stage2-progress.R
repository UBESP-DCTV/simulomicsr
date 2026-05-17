#!/usr/bin/env Rscript
# p4-beta-stage2-progress.R --- progress snapshot β-12 stage2 fullrun (slurm 20710).
#
# Stampa:
#  - slurm_state (squeue / sacct fallback)
#  - elapsed wall time (sacct)
#  - record gia' emessi (wc -l su predictions.jsonl remoto)
#  - throughput rec/min e ETA aggiornato (record rimanenti / throughput)

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

job_rds <- "analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0-job.rds"
job <- readRDS(job_rds)
cfg <- job$config
N_TOTAL <- 39205L

st <- dgx_p4_status(job)
state <- st$slurm_state

# Resolve TERMINATED via sacct
if (identical(state, "TERMINATED")) {
  cmd <- paste0("sacct -j ", job$slurm_job_id,
                " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(cfg, cmd),
                  error = function(e) list(stdout = ""))
  final <- trimws(if (is.null(res$stdout)) "" else res$stdout)
  if (nzchar(final)) state <- final
}

# sacct Elapsed
cmd_elapsed <- paste0("sacct -j ", job$slurm_job_id,
                       " --format=Elapsed -n -P 2>/dev/null | head -1")
res_e <- tryCatch(simulomicsr:::.dgx_ssh(cfg, cmd_elapsed),
                  error = function(e) list(stdout = ""))
elapsed_str <- trimws(if (is.null(res_e$stdout)) "" else res_e$stdout)

# Parse Elapsed HH:MM:SS or D-HH:MM:SS to minutes
parse_elapsed_min <- function(s) {
  if (!nzchar(s)) return(NA_real_)
  has_day <- grepl("-", s, fixed = TRUE)
  if (has_day) {
    parts <- strsplit(s, "-", fixed = TRUE)[[1]]
    d <- as.integer(parts[1])
    hms <- parts[2]
  } else {
    d <- 0L
    hms <- s
  }
  hms_parts <- as.integer(strsplit(hms, ":", fixed = TRUE)[[1]])
  if (length(hms_parts) != 3L) return(NA_real_)
  d * 24 * 60 + hms_parts[1] * 60 + hms_parts[2] + hms_parts[3] / 60
}
elapsed_min <- parse_elapsed_min(elapsed_str)

# Remote predictions count: stage2 emette predictions.worker_<N>.jsonl
# (uno per GPU worker). Final predictions.jsonl viene mergiata a fine job.
remote_dir <- paste0(cfg$remote_root, "/runs/", job$run_id)
cmd_wc <- paste0(
  "cat ", remote_dir, "/predictions.worker_*.jsonl 2>/dev/null | wc -l; ",
  "wc -l < ", remote_dir, "/predictions.jsonl 2>/dev/null || echo 0"
)
res_wc <- tryCatch(simulomicsr:::.dgx_ssh(cfg, cmd_wc),
                   error = function(e) list(stdout = "0\n0"))
wc_lines <- strsplit(trimws(if (is.null(res_wc$stdout)) "0" else res_wc$stdout),
                      "\n", fixed = TRUE)[[1]]
n_workers <- as.integer(wc_lines[1L])
n_merged  <- if (length(wc_lines) > 1L) as.integer(wc_lines[2L]) else 0L
if (is.na(n_workers)) n_workers <- 0L
if (is.na(n_merged))  n_merged  <- 0L
n_done <- max(n_workers, n_merged)

# Throughput + ETA
if (!is.na(elapsed_min) && elapsed_min > 0 && n_done > 0) {
  throughput <- n_done / elapsed_min
  remaining <- N_TOTAL - n_done
  eta_min <- remaining / throughput
  eta_h   <- eta_min / 60
  pct <- 100 * n_done / N_TOTAL
} else {
  throughput <- NA_real_; eta_min <- NA_real_; eta_h <- NA_real_; pct <- NA_real_
}

cat(sprintf("==== β-12 stage2 fullrun progress (slurm %s) ====\n",
            job$slurm_job_id))
cat(sprintf("slurm_state    : %s\n", state))
cat(sprintf("elapsed wall   : %s (%.1f min)\n",
            if (nzchar(elapsed_str)) elapsed_str else "n/a",
            elapsed_min %||% NA_real_))
cat(sprintf("records done   : %d / %d (%.2f%%)\n",
            n_done, N_TOTAL,
            pct %||% NA_real_))
cat(sprintf("throughput     : %.1f rec/min\n",
            throughput %||% NA_real_))
cat(sprintf("ETA remaining  : %.1f h (%.0f min)\n",
            eta_h %||% NA_real_,
            eta_min %||% NA_real_))
