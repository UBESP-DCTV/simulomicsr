#!/usr/bin/env Rscript
# p4-beta-stage2-poll-state.R --- one-shot stato slurm job 20710 (β-12).
# Stdout: la singola parola slurm_state (es. "RUNNING", "COMPLETED").
# Risolve "TERMINATED" via sacct per stato finale reale (pattern gate2).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

job_rds <- "analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0-job.rds"
job <- readRDS(job_rds)
st <- dgx_p4_status(job)
state <- st$slurm_state

# Resolve TERMINATED to real final state via sacct
if (identical(state, "TERMINATED")) {
  cmd <- paste0("sacct -j ", job$slurm_job_id,
                " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(job$config, cmd),
                  error = function(e) list(stdout = ""))
  final <- trimws(if (is.null(res$stdout)) "" else res$stdout)
  if (nzchar(final)) state <- final
}

cat(state)
