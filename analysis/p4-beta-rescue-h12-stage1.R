#!/usr/bin/env Rscript
# p4-beta-rescue-h12-stage1.R --- H1.2 strong retry sui 20 H1 residual fails
# (18 Mode A + 2 Mode B). Triplo-override piu' aggressivo rispetto a H1:
# rep_pen=1.3, max_tokens=8192, max_model_len=16384.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT      <- "analysis/input/archs4-human-stage1-rescue-h12.jsonl"
SLUG       <- "beta-rescue-stage1-h12"
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
cat(sprintf("H1.2 strong retry records: %d\n", n_records))

bundle <- dgx_p4_build_bundle(
  input_jsonl = INPUT,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_tokens          <- 8192L
gen$repetition_penalty  <- 1.3
gen$max_model_len       <- 16384L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat("Patched generation.json (rep_pen=1.3, max_tokens=8192, max_model_len=16384)\n")

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)
cat(sprintf("\n=== H1.2 SUBMITTED ===\nslurm=%s run_id=%s\n",
            job$slurm_job_id, job$run_id))
cat("ETA: ~2-3 min wall (20 record post-boot)\n")
