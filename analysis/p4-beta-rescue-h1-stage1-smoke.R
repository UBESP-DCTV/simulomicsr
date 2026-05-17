#!/usr/bin/env Rscript
# p4-beta-rescue-h1-stage1-smoke.R --- H1 smoke: 20 sample stratified retry
# con rep_pen=1.2 + max_tokens=4096 (mirror ADR-0008 escalation).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
RESCUE_IN  <- "analysis/input/archs4-human-stage1-rescue.jsonl"
SMOKE_IN   <- "analysis/input/archs4-human-stage1-rescue-smoke.jsonl"
CLASSIFIED <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"
SLUG       <- "beta-rescue-stage1-smoke20"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(RESCUE_IN), file.exists(CLASSIFIED))

existing <- list.files(OUTPUT_DIR,
                       pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job_rds <- existing[which.max(file.info(existing)$mtime)]
  job <- readRDS(job_rds)
  cat(sprintf("Resume: %s slurm=%s\n", job_rds, job$slurm_job_id))
  st <- tryCatch(dgx_p4_status(job),
                 error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("slurm_state: %s\n", st$slurm_state))
  quit(status = 0L)
}

# === Build smoke subset: 15 Mode A + 5 Mode B/OTHER ===
df <- read.csv(CLASSIFIED, stringsAsFactors = FALSE)
set.seed(1812L)
gsm_A <- sample(df$record_id[df$fail_mode == "MODE_A_WHITESPACE"], 15L)
gsm_B <- sample(df$record_id[df$fail_mode %in% c("MODE_B_LEGIT_TRUNC", "OTHER_DEGEN")],
                min(5L, sum(df$fail_mode %in% c("MODE_B_LEGIT_TRUNC", "OTHER_DEGEN"))))
target_set <- new.env(hash = TRUE)
for (g in c(gsm_A, gsm_B)) target_set[[g]] <- TRUE

con_in  <- file(RESCUE_IN, "r")
con_out <- file(SMOKE_IN, "w")
n_emit <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(target_set[[rec$record_id]])) {
    writeLines(L, con_out)
    n_emit <- n_emit + 1L
  }
}
close(con_in); close(con_out)
cat(sprintf("Smoke subset: %d records (target %d)\n", n_emit, length(gsm_A) + length(gsm_B)))

cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = SMOKE_IN,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)

gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_tokens          <- 4096L
gen$repetition_penalty  <- 1.2
gen$max_model_len       <- 8192L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("Patched: max_tokens=4096, repetition_penalty=1.2, max_model_len=8192\n"))

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)

cat("\n=== H1 smoke20 SUBMITTED ===\n")
cat(sprintf("slurm_job_id  = %s\n", job$slurm_job_id))
cat(sprintf("run_id        = %s\n", job$run_id))
cat(sprintf("job_rds       = %s\n", job_rds))
cat(sprintf("ETA           = ~5 min wall (boot ~2min + 20 record ~1-2min)\n"))
