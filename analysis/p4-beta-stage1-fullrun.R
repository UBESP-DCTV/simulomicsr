#!/usr/bin/env Rscript
# p4-beta-stage1-fullrun.R --- β Task β-10: stage1 full run su 888.821 sample
#
# Submit-only -- NON polla il job. Salva job RDS in analysis/p4-output/ per
# resume/status nella sessione successiva. ETA stage1 = ~59h wall DGX (gate2),
# time = 72:00:00 (memoria DGX time limit default minimo).
#
# Resume safety: se esiste gia' un job RDS con slug beta-stage1-fullrun nello
# stesso OUTPUT_DIR, lo riusa al posto di submittare un secondo job duplicato.

# Nota: usa devtools::load_all() invece di library(simulomicsr) perche' il
# pacchetto non e' installato nell'ambiente corrente (renv out-of-sync). Stessa
# strategia di analysis/p4-beta-build-minigold-formatB.R.
suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT_FULL <- Sys.getenv("FULLRUN_INPUT", "analysis/input/archs4-human-stage1-input.jsonl")
SLUG       <- Sys.getenv("FULLRUN_SLUG", "beta-stage1-fullrun")
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(INPUT_FULL))

# === Resume: se gia' submitted, riusa il job RDS piu' recente ===
existing <- list.files(
  OUTPUT_DIR,
  pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
  full.names = TRUE
)
if (length(existing) > 0L) {
  job_rds <- existing[which.max(file.info(existing)$mtime)]
  job <- readRDS(job_rds)
  cat(sprintf("Resume: job esistente trovato\n"))
  cat(sprintf("  job_rds      = %s\n", job_rds))
  cat(sprintf("  slurm_job_id = %s\n", job$slurm_job_id))
  cat(sprintf("  run_id       = %s\n", job$run_id))
  st <- tryCatch(dgx_p4_status(job),
                 error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("  slurm_state  = %s\n", st$slurm_state))
  quit(status = 0L)
}

# === Submit fresh ===
cfg <- dgx_config()
cat(sprintf("Counting records in %s ...\n", INPUT_FULL))
n_records <- length(readLines(INPUT_FULL, warn = FALSE))
cat(sprintf("Records: %d\n", n_records))

bundle <- dgx_p4_build_bundle(
  input_jsonl = INPUT_FULL,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)

cat("\n=== Stage1 full run SUBMITTED ===\n")
cat(sprintf("slurm_job_id  = %s\n", job$slurm_job_id))
cat(sprintf("run_id        = %s\n", job$run_id))
cat(sprintf("job_rds       = %s\n", job_rds))
cat(sprintf("input_records = %d\n", n_records))
cat(sprintf("ETA stage1    = ~59h wall (da GATE #2)\n"))
cat("NON polling -- re-source questo script per status, oppure:\n")
cat(sprintf("  dgx_p4_status(readRDS('%s'))\n", job_rds))
