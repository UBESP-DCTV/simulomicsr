#!/usr/bin/env Rscript
# p4-beta-stage1-outliers.R --- β Task 10b: stage1 sui 26 outliers nchar>3500
#
# I 26 record con nchar>3500 sono stati filtrati dal mainstream stage1 chunked
# perche' triggerano vLLM Issue #39734 (scheduler HoL stall, GPU 0% silenzioso)
# con la config standard max_model_len=4096. Strategy A: bump max_model_len a
# 8192 per coprire prompt+gen di tutti i record outlier (max ~5633 token).
#
# La pipeline normale fa cosi':
#   1. dgx_p4_build_bundle -> legge p4-defaults.yml stage1 (max_model_len=4096)
#   2. dgx_p4_submit -> rsync bundle -> sbatch
#
# Qui INTERPONIAMO uno step tra build e submit: patchiamo bundle/generation.json
# settando max_model_len=8192 prima dell'rsync. Non modifichiamo p4-defaults.yml
# per non confondere i runs futuri.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT      <- "analysis/input/archs4-human-stage1-outliers.jsonl"
SLUG       <- "beta-stage1-outliers"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(INPUT))

# Resume: re-source vede il job_rds e printa stato senza re-submit
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

# === Patch generation.json: max_model_len 4096 -> 32768 ===
# Strategy A1 (max_model_len=8192) testata 2026-05-15 15:00 UTC su job 20705:
# stall ricorrente Issue #39734. Worst case token per outlier nchar=9831:
# ~12.7k token (prompt 775 + record 9831 + output 2048). Bump a 32768 = 3-4x
# headroom. Mistral-Small-3.2-24B supporta 128k context (stage2 in defaults
# usa gia' 65536 per tier XL).
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_model_len <- 32768L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("Patched generation.json: max_model_len=32768 (abbondante per outliers max nchar=9831)\n"))

job <- dgx_p4_submit(bundle, time = "2:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)

cat("\n=== Stage1 outliers SUBMITTED ===\n")
cat(sprintf("slurm_job_id  = %s\n", job$slurm_job_id))
cat(sprintf("run_id        = %s\n", job$run_id))
cat(sprintf("job_rds       = %s\n", job_rds))
cat(sprintf("input_records = %d\n", n_records))
cat(sprintf("max_model_len = 8192 (override per outliers)\n"))
cat(sprintf("ETA           = ~10-15 min wall (boot ~2min + 1 microbatch ~30-60s)\n"))
