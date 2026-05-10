#!/usr/bin/env Rscript
# poll-smoke-stage2.R --- snapshot stato di tutti gli smoke job stage2 attivi.
#
# Uso:
#   Rscript analysis/p4-smoke/poll-smoke-stage2.R
#   Rscript analysis/p4-smoke/poll-smoke-stage2.R --slurm 19815
#
# Per ogni job: SLURM state, righe finali slurm.out (per microbatch progress
# e errori), conteggio predictions.worker_*.jsonl, presenza status.json.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

args <- commandArgs(trailingOnly = TRUE)
filter_slurm <- if ("--slurm" %in% args) {
  args[which(args == "--slurm") + 1L]
} else NULL

cfg <- dgx_config()

# Collect all run_ids da analysis/p4-bundles/*.rds (smoke jobs)
job_files <- fs::dir_ls("analysis/p4-bundles", recurse = TRUE,
                       glob = "*/job.rds")
if (length(job_files) == 0L) {
  cat("Nessun job.rds trovato in analysis/p4-bundles/\n")
  quit("no", status = 0)
}

jobs <- lapply(job_files, readRDS)
names(jobs) <- vapply(jobs, function(j) j$slurm_job_id %||% "NA", character(1))

# Filter
if (!is.null(filter_slurm)) {
  jobs <- jobs[names(jobs) == filter_slurm]
}

# squeue once
res <- simulomicsr:::.dgx_ssh(cfg,
  "squeue -u u0044 --format='%.10i %.8T %.10M %R'")
squeue_lines <- strsplit(res$stdout, "\n", fixed = TRUE)[[1L]]
parse_squeue <- function(slurm_id) {
  m <- grep(paste0("^\\s*", slurm_id, "\\s"), squeue_lines, value = TRUE)
  if (length(m) == 0L) return(list(state = "TERMINATED", time = "-", node = "-"))
  parts <- strsplit(trimws(m), "\\s+")[[1L]]
  list(state = parts[2], time = parts[3], node = paste(parts[4:length(parts)], collapse=" "))
}

cat(sprintf("=== %s ===\n\n", format(Sys.time(), "%H:%M:%S")))

for (slurm_id in names(jobs)) {
  job <- jobs[[slurm_id]]
  if (is.na(slurm_id) || slurm_id == "NA") next
  st <- parse_squeue(slurm_id)
  cat(sprintf("--- slurm %s | %s | run_id=%s ---\n",
              slurm_id, st$state, job$run_id))
  if (!is.null(st$time)) cat(sprintf("    elapsed=%s node=%s\n", st$time, st$node))

  # Get last 8 lines of slurm-XXX.out via SSH tail
  remote_run <- paste0(cfg$remote_root, "/runs/", job$run_id)
  cmd <- paste0(
    "ls ", shQuote(remote_run), "/slurm-*.out 2>/dev/null | tail -1 | ",
    "xargs -I{} sh -c 'echo \"--- last 12 of {} ---\"; tail -12 {}' 2>/dev/null; ",
    "echo \"--- worker files ---\"; ",
    "for f in ", shQuote(remote_run), "/predictions.worker_*.jsonl; do ",
    "  if [ -f \"$f\" ]; then printf \"  %s: \" \"$(basename $f)\"; wc -l < $f; fi; ",
    "done; ",
    "echo \"--- status.json ---\"; ",
    "if [ -f ", shQuote(remote_run), "/status.json ]; then ",
    "  grep -E '\"state\"|\"records_completed\"|\"records_total\"|\"records_todo\"' ",
       shQuote(remote_run), "/status.json | tr -d ',' ; ",
    "fi"
  )
  ssh_res <- simulomicsr:::.dgx_ssh(cfg, cmd)
  cat(ssh_res$stdout)
  cat("\n")
}
