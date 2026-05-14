#!/usr/bin/env Rscript
# p4-beta-stage1-smoke10k.R --- smoke validation post-fix microbatch stage1
#
# Contesto: il full run beta-stage1-fullrun (job 20416, 2026-05-14) si e'
# hung con 4 GPU a 0% util per 3h+ dovuto a vLLM scheduler stall su single
# llm.chat() con 222k record per worker. Fix applicato in p4-defaults.yml
# stage1.microbatch=500. Questo smoke valida che microbatch sblocchi.
#
# Setup: stratified sample 10k record da archs4-human-stage1-input.jsonl
# (~2.5k per worker, 5 microbatch da 500 ognuno). Soglia molto piu' bassa
# del full run ma sopra la soglia gate2 (250/worker) che era sotto-stall.
#
# Submit-only -- NON polla. Re-source per status.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT_FULL <- "analysis/input/archs4-human-stage1-input.jsonl"
INPUT_SMK  <- "analysis/input/p4-beta-stage1-smoke10k-input.jsonl"
SLUG       <- "beta-stage1-smoke10k"
N_SMOKE    <- 10000L
SEED_STRAT <- 42L
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
stopifnot(file.exists(INPUT_FULL))

# === Resume short-circuit ===
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

# === Build smoke input se non esiste ===
if (!file.exists(INPUT_SMK)) {
  cat("Loading full beta JSONL...\n")
  recs <- jsonlite::stream_in(file(INPUT_FULL), verbose = FALSE,
                              simplifyVector = TRUE)
  cat(sprintf("Loaded %d records, stratifying by nchar...\n", nrow(recs)))
  nch <- nchar(recs$string)
  q   <- quantile(nch, c(0, 0.25, 0.5, 0.75, 1))
  stratum <- cut(nch, breaks = q, include.lowest = TRUE,
                  labels = paste0("Q", 1:4))
  set.seed(SEED_STRAT)
  per_stratum <- as.integer(N_SMOKE / 4L)
  sample_idx <- unlist(lapply(levels(stratum), function(s) {
    pool <- which(stratum == s)
    sample(pool, min(per_stratum, length(pool)))
  }))
  smoke <- recs[sample_idx, c("record_id", "geo_accession", "series_id",
                              "string", "library_strategy", "organism")]
  con <- file(INPUT_SMK, "w")
  jsonlite::stream_out(smoke, con, verbose = FALSE)
  close(con)
  cat(sprintf("Smoke input: %s (%d records)\n", INPUT_SMK, nrow(smoke)))
} else {
  cat(sprintf("Smoke input gia' esistente: %s\n", INPUT_SMK))
}

# === Submit ===
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = INPUT_SMK,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)

# Sanity check: microbatch deve essere stato propagato a generation.json
gen <- jsonlite::read_json(file.path(bundle$bundle_dir, "generation.json"))
cat(sprintf("generation.json microbatch = %s\n",
            if (is.null(gen$microbatch)) "<unset>" else as.character(gen$microbatch)))
stopifnot(!is.null(gen$microbatch) && gen$microbatch == 500L)

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)

cat("\n=== Stage1 smoke 10k SUBMITTED ===\n")
cat(sprintf("slurm_job_id  = %s\n", job$slurm_job_id))
cat(sprintf("run_id        = %s\n", job$run_id))
cat(sprintf("job_rds       = %s\n", job_rds))
cat(sprintf("input_records = %d (4 workers x ~2500 record x 5 microbatch da 500)\n", N_SMOKE))
cat("ETA: pochi minuti--decine di minuti.\n")
cat("Monitor cron gia' attivo (slug match beta-stage1-* prendera' il piu' recente).\n")
