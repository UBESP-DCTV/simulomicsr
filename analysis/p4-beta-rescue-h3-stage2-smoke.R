#!/usr/bin/env Rscript
# p4-beta-rescue-h3-stage2-smoke.R --- H3 smoke: 5 cs25 chunk retry stage2.
# Stessa config stage2 (tiered_max_tokens=TRUE), unico fix = chunk_size 50->25.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
})

OUTPUT_DIR <- "analysis/p4-output"
RESCUE_IN  <- "analysis/input/archs4-human-stage2-rescue-cs25.jsonl"
SMOKE_IN   <- "analysis/input/archs4-human-stage2-rescue-cs25-smoke5.jsonl"
SLUG       <- "beta-rescue-stage2-smoke5"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(RESCUE_IN))

existing <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job <- readRDS(existing[which.max(file.info(existing)$mtime)])
  st  <- tryCatch(dgx_p4_status(job),
                  error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("Resume: slurm=%s state=%s\n", job$slurm_job_id, st$slurm_state))
  quit(status = 0L)
}

lines <- readLines(RESCUE_IN, warn = FALSE)
writeLines(head(lines, 5L), SMOKE_IN)
cat(sprintf("Smoke subset: 5 chunks (out of %d)\n", length(lines)))

cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl       = SMOKE_IN,
  stage             = "stage2",
  config            = cfg,
  metadata          = list(slug = SLUG),
  tiered_max_tokens = TRUE
)

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)
cat(sprintf("\n=== H3 smoke5 SUBMITTED ===\nslurm=%s run_id=%s\n",
            job$slurm_job_id, job$run_id))
cat("ETA: ~5-10 min wall (boot ~2min + 5 cs25 chunk ~3-8min)\n")
