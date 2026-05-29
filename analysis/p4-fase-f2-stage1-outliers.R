#!/usr/bin/env Rscript
# p4-fase-f2-stage1-outliers.R --- RED ALERT FASE F2: stage1 sui 25 outlier
# nchar(string) > 3500 del bacino v2.
#
# Identico nella sostanza a p4-beta-stage1-outliers.R (Task 10b): i record
# lunghi triggerano vLLM Issue #39734 (scheduler HoL stall) con la config
# standard max_model_len=4096. Si patcha generation.json a max_model_len=32768
# (max nchar outlier ~9831 -> ~12.7k token worst case, 3-4x headroom) PRIMA
# dell'rsync, senza toccare p4-defaults.yml. Submit-only, resume-safe.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT      <- "analysis/input/archs4-human-stage1-v2-outliers.jsonl"
SLUG       <- "f2-stage1-outliers"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(INPUT))

existing <- list.files(
  OUTPUT_DIR,
  pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
  full.names = TRUE
)
if (length(existing) > 0L) {
  job_rds <- existing[which.max(file.info(existing)$mtime)]
  job <- readRDS(job_rds)
  cat(sprintf("Resume: job esistente\n"))
  cat(sprintf("  job_rds      = %s\n", job_rds))
  cat(sprintf("  slurm_job_id = %s\n", job$slurm_job_id))
  st <- tryCatch(dgx_p4_status(job),
                 error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("  slurm_state  = %s\n", st$slurm_state))
  quit(status = 0L)
}

cfg <- dgx_config()
n_records <- length(readLines(INPUT, warn = FALSE))
cat(sprintf("Records outliers: %d\n", n_records))

bundle <- dgx_p4_build_bundle(
  input_jsonl = INPUT,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)

# === Patch generation.json: max_model_len 4096 -> 32768 (Task 10b) ===
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_model_len <- 32768L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("Patched generation.json: max_model_len=32768\n"))

job <- dgx_p4_submit(bundle, time = "2:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)

cat("\n=== Stage1 outliers v2 SUBMITTED ===\n")
cat(sprintf("slurm_job_id  = %s\n", job$slurm_job_id))
cat(sprintf("run_id        = %s\n", job$run_id))
cat(sprintf("job_rds       = %s\n", job_rds))
cat(sprintf("input_records = %d\n", n_records))
cat(sprintf("max_model_len = 32768 (override per outliers)\n"))
