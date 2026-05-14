#!/usr/bin/env Rscript
# scripts/p4-beta-monitor.R --- check periodico del job β stage1 full run
#
# Risolve il job RDS piu' recente con slug `beta-stage1-fullrun`, interroga
# SLURM (squeue + sacct), conta record in predictions.jsonl remoto, e tail
# delle ultime righe di slurm-<jobid>.out. Stampa tutto su stdout (cron
# redirige al log file).

suppressPackageStartupMessages(devtools::load_all(quiet = TRUE))

# Slug prefix: match sia beta-stage1-fullrun che beta-stage1-smoke10k (e
# qualunque altro beta-stage1-*). Il pattern del find e' .*-{SLUG}-.* quindi
# "beta-stage1" prende il job piu' recente di qualsiasi sotto-variante.
SLUG       <- Sys.getenv("MONITOR_SLUG", unset = "beta-stage1")
OUTPUT_DIR <- "analysis/p4-output"

ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
cat(sprintf("==== [%s] P4 β monitor (slug=%s) ====\n", ts, SLUG))

existing <- list.files(
  OUTPUT_DIR,
  pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
  full.names = TRUE
)
if (length(existing) == 0L) {
  cat(sprintf("[ATTENTION] nessun job RDS trovato per slug=%s in %s\n",
              SLUG, OUTPUT_DIR))
  quit(status = 1L)
}
job_rds <- existing[which.max(file.info(existing)$mtime)]
job <- readRDS(job_rds)
cat(sprintf("job_rds      = %s\n", job_rds))
cat(sprintf("slurm_job_id = %s\n", job$slurm_job_id))
cat(sprintf("run_id       = %s\n", job$run_id))

# --- slurm_state via dgx_p4_status (squeue) ---
st <- tryCatch(dgx_p4_status(job),
               error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
cat(sprintf("slurm_state  = %s\n", st$slurm_state))

cfg <- job$config
remote_run <- paste0(cfg$remote_root, "/runs/", job$run_id)

# --- sacct: Elapsed/State/ExitCode ---
sacct_cmd <- sprintf(
  "sacct -j %s --format=JobID,State,Elapsed,ExitCode,MaxRSS -P 2>/dev/null",
  job$slurm_job_id
)
res <- tryCatch(simulomicsr:::.dgx_ssh(cfg, sacct_cmd),
                error = function(e) list(stdout = paste0("ERR: ", e$message)))
cat("-- sacct --\n")
cat(res$stdout, "\n")

# --- predictions.jsonl line count (live throughput) ---
wc_cmd <- sprintf(
  "wc -l %s/predictions.jsonl 2>/dev/null || echo '[no predictions yet]'",
  shQuote(remote_run)
)
res <- tryCatch(simulomicsr:::.dgx_ssh(cfg, wc_cmd),
                error = function(e) list(stdout = paste0("ERR: ", e$message)))
cat("-- predictions.jsonl line count --\n")
cat(res$stdout, "\n")

# --- tail slurm-<jobid>.out (50 righe) ---
tail_cmd <- sprintf(
  "tail -50 %s/slurm-%s.out 2>/dev/null || echo '[no slurm.out yet]'",
  shQuote(remote_run), job$slurm_job_id
)
res <- tryCatch(simulomicsr:::.dgx_ssh(cfg, tail_cmd),
                error = function(e) list(stdout = paste0("ERR: ", e$message)))
cat("-- slurm.out tail (50 lines) --\n")
cat(res$stdout, "\n")

cat("\n")
