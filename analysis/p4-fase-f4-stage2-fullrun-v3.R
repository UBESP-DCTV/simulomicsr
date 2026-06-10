#!/usr/bin/env Rscript
# p4-fase-f4-stage2-fullrun-v3.R --- RED ALERT FASE F4 opzione C: fullrun Stadio 2 v3.
#
# Submit del fullrun Stadio 2 sull'input v3 a condizioni deduplicate (24.972
# record). Config INVARIATA vs smoke/F3 (uniformity): stage2 tiered_max_tokens,
# temp=0, rep_pen=1.1, microbatch=50, 4-worker (template SLURM), time 72h.
#
# Questo script SOLO SUBMIT (non polla fino a fine job: il job gira ore). Salva
# il job RDS; il collect + assembly (espansione -> master v3) lo fa la sessione
# successiva via p4-fase-f4-stage2-collect-v3.R (da scrivere) o EVAL_ONLY dello
# smoke script su predictions.jsonl.
#
# Resume-safe: se esiste gia' un job RDS f4-stage2-fullrun-v3, riporta lo stato
# senza ri-submittare.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite); library(fs)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT_V3   <- "analysis/input/archs4-human-stage2-input-v3.jsonl"
SLUG       <- "f4-stage2-fullrun-v3"
SUBMIT_TIME <- "72:00:00"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
stopifnot(file.exists(INPUT_V3))

`%||%` <- function(a, b) if (is.null(a)) b else a

# GATE: prompt Stadio 2 v3 attivo (Input format) — come lo smoke.
s2_prompt <- simulomicsr:::.stage2_system_prompt("mistralai/Mistral-Small-3.2-24B-Instruct-2506")
if (!grepl("Input format: pre-deduplicated design conditions", s2_prompt, fixed = TRUE))
  stop("Prompt Stadio 2 del branch non contiene la sezione v3 (Input format).")
cat("GATE OK: prompt Stadio 2 v3 attivo.\n")

find_job <- function(slug) {
  f <- list.files(OUTPUT_DIR, pattern = paste0(".*-", slug, "-.*-job\\.rds$"),
                  full.names = TRUE)
  if (length(f) == 0L) NULL else f[which.max(file.info(f)$mtime)]
}

ex <- find_job(SLUG)
if (!is.null(ex)) {
  job <- readRDS(ex)
  cat(sprintf("Job gia' submittato: slurm=%s run_id=%s\n", job$slurm_job_id, job$run_id))
  st <- tryCatch(dgx_p4_status(job), error = function(e) NULL)
  if (!is.null(st)) cat(sprintf("Stato corrente: %s\n", st$slurm_state %||% "?"))
  quit(save = "no")
}

cfg <- dgx_config()
b <- dgx_p4_build_bundle(input_jsonl = INPUT_V3, stage = "stage2", config = cfg,
                         metadata = list(slug = SLUG), tiered_max_tokens = TRUE)
cat(sprintf("Bundle: %s | record=%d\n", b$bundle_dir, b$record_count %||% NA))
job <- dgx_p4_submit(b, time = SUBMIT_TIME)
saveRDS(job, file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds")))
cat(sprintf("Submitted %s: slurm=%s run_id=%s\n", SLUG, job$slurm_job_id, job$run_id))
cat("Il job gira sul DGX (4-worker). Collect + assembly nella sessione successiva.\n")
