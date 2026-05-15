#!/usr/bin/env Rscript
# p4-beta-stage2-fullrun.R --- β Task β-12: stage2 full run su ~17k chunk records
#
# Input  : analysis/input/archs4-human-stage2-input.jsonl (prodotto da β-11
#          via p4-beta-stage2-build-input.R, chunk_size=50 ADR-0013).
# Output : DGX run dir analysis/p4-output/<run-id>/predictions.jsonl (post-collect).
#
# Submit-only -- NON polla il job. Salva job RDS in analysis/p4-output/ per
# resume/status nella sessione successiva. ETA stage2 ~6-8h wall DGX
# (estrapolazione α stage2 cs50 ~6.6k record / β-11 effettivi 39.205 record
# stage2 dopo chunking cs50 da 887.250 sample / 28.479 studi unique).
# Time SLURM 72:00:00 (memoria DGX time limit default minimo).
#
# Config invariante vs gate2 / α stage2 cs50 (ADR-0008/0009/0010/0011/0013):
#   - max_num_seqs = 6, microbatch = 50 (post PR #40946 fix Issue #39734)
#   - tiered_max_tokens = TRUE (S=4096, M=8192, L=16384, XL=32768)
#   - temperature = 0.0, repetition_penalty = 1.1
#   - guided decoding via StructuredOutputsParams (vLLM v0.20.2)
#
# Resume safety: se esiste gia' un job RDS con slug beta-stage2-fullrun nello
# stesso OUTPUT_DIR, lo riusa al posto di submittare un secondo job duplicato.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT_FULL <- Sys.getenv("FULLRUN_INPUT",
                         "analysis/input/archs4-human-stage2-input.jsonl")
SLUG       <- Sys.getenv("FULLRUN_SLUG", "beta-stage2-fullrun")
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
  input_jsonl       = INPUT_FULL,
  stage             = "stage2",
  config            = cfg,
  metadata          = list(slug = SLUG),
  tiered_max_tokens = TRUE
)

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)

cat("\n=== Stage2 full run SUBMITTED ===\n")
cat(sprintf("slurm_job_id  = %s\n", job$slurm_job_id))
cat(sprintf("run_id        = %s\n", job$run_id))
cat(sprintf("job_rds       = %s\n", job_rds))
cat(sprintf("input_records = %d\n", n_records))
cat(sprintf("ETA stage2    = ~6-8h wall (39.205 stage2 records, scale-up alpha cs50)\n"))
cat("NON polling -- re-source questo script per status, oppure:\n")
cat(sprintf("  dgx_p4_status(readRDS('%s'))\n", job_rds))
