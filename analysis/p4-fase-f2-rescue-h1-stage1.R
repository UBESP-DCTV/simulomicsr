#!/usr/bin/env Rscript
# p4-fase-f2-rescue-h1-stage1.R --- RED ALERT FASE F2 rescue H1: retry dei
# 1.464 fail LLM Stadio 1 v2 con la config H1 beta (ADR-0008 addendum):
#   repetition_penalty=1.2 (rompe il loop whitespace Mode A)
#   max_tokens=4096        (copre Mode B truncation)
#   max_model_len=8192
# Prompt e temperatura INVARIATI (stesso prompt v2 D1b/D4). Submit-only,
# resume-safe. Patch chirurgica di generation.json tra build e submit.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT      <- "analysis/input/archs4-human-stage1-v2-rescue.jsonl"
SLUG       <- "f2-rescue-stage1-h1"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
stopifnot(file.exists(INPUT))

existing <- list.files(OUTPUT_DIR,
                       pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job_rds <- existing[which.max(file.info(existing)$mtime)]
  job <- readRDS(job_rds)
  st <- tryCatch(dgx_p4_status(job),
                 error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("Resume: %s slurm=%s state=%s\n",
              job_rds, job$slurm_job_id, st$slurm_state))
  quit(status = 0L)
}

cfg <- dgx_config()
n_records <- length(readLines(INPUT, warn = FALSE))
cat(sprintf("H1 retry records: %d\n", n_records))

bundle <- dgx_p4_build_bundle(
  input_jsonl = INPUT,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_tokens         <- 4096L
gen$repetition_penalty <- 1.2
gen$max_model_len      <- 8192L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat("Patched generation.json (rep_pen=1.2, max_tokens=4096, max_model_len=8192)\n")

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)
cat(sprintf("\n=== H1 SUBMITTED ===\nslurm_job_id=%s run_id=%s\njob_rds=%s\n",
            job$slurm_job_id, job$run_id, job_rds))
cat("ETA: ~5-10 min wall (1.464 record; beta 822 in 3m21s)\n")
