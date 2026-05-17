#!/usr/bin/env Rscript
# p4-beta-rescue-h3-stage2-full.R --- H3 FULL retry tutti i cs25 chunks
# derivati dai 43 stage2 fails.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT      <- "analysis/input/archs4-human-stage2-rescue-cs25.jsonl"
SLUG       <- "beta-rescue-stage2-full"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(INPUT))

existing <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job <- readRDS(existing[which.max(file.info(existing)$mtime)])
  st  <- tryCatch(dgx_p4_status(job),
                  error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("Resume: slurm=%s state=%s\n", job$slurm_job_id, st$slurm_state))
  quit(status = 0L)
}

cfg <- dgx_config()
n_records <- length(readLines(INPUT, warn = FALSE))
cat(sprintf("Stage2 cs25 full retry records: %d\n", n_records))

bundle <- dgx_p4_build_bundle(
  input_jsonl       = INPUT,
  stage             = "stage2",
  config            = cfg,
  metadata          = list(slug = SLUG),
  tiered_max_tokens = TRUE
)

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)
cat(sprintf("\n=== H3 full SUBMITTED ===\nslurm=%s run_id=%s\n",
            job$slurm_job_id, job$run_id))
cat(sprintf("ETA: ~15-30 min wall (~100 chunks @ 5-10 chunk/min)\n"))
