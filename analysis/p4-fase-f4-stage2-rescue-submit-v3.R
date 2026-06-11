#!/usr/bin/env Rscript
# p4-fase-f4-stage2-rescue-submit-v3.R --- RED ALERT FASE F4 opzione C: submit del
# rescue dei 19 fail-schema del fullrun Stadio 2 v3 (24022).
#
# Input rescue (506 record, 10 studi) gia' costruito con tetto condizioni/chunk=12
# (p4-fase-f4-stage2-rescue-build-v3.R). Config di rescue UNICA (deviazione di
# config rispetto al fullrun, tracciata come nel rescue beta, NON cambio di prompt):
#   - max_tokens piatto 32768 (tiered_max_tokens=FALSE): headroom per GSE162694
#     (esplosione confronti) e per GSE134595 (multi_arm a tier S 4096); col tetto
#     12 ogni chunk sta largamente sotto.
#   - repetition_penalty 1.2 (era 1.1): cura la degenerazione "1"-loop di GSE186121
#     e i 2 whitespace-flood (GSE235391/GSE246587). Valore del rescue beta H1.
# Resto invariato (temp 0, microbatch 50, max_num_seqs 6, 4-worker, max_model_len
# 65536). Editiamo generation.json del bundle (no edit dello yaml tracciato).
#
# Resume-safe: se esiste gia' un job RDS rescue-v3, riporta stato senza ri-submit.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite); library(fs)
})

OUTPUT_DIR  <- "analysis/p4-output"
INPUT       <- "analysis/input/archs4-human-stage2-rescue-v3.jsonl"
SLUG        <- "f4-stage2-rescue-v3"
SUBMIT_TIME <- "72:00:00"
RESCUE_MAX_TOKENS <- 32768L
RESCUE_REP_PEN    <- 1.2
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
stopifnot(file.exists(INPUT))

`%||%` <- function(a, b) if (is.null(a)) b else a

# GATE: prompt Stadio 2 v3 attivo (Input format) — come fullrun/smoke.
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
b <- dgx_p4_build_bundle(input_jsonl = INPUT, stage = "stage2", config = cfg,
                         metadata = list(slug = SLUG), tiered_max_tokens = FALSE)
cat(sprintf("Bundle: %s | record=%d\n", b$bundle_dir, b$record_count %||% NA))

# --- override config di rescue in generation.json (no edit dello yaml) ---
gen_path <- file.path(b$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_tokens         <- RESCUE_MAX_TOKENS
gen$repetition_penalty <- RESCUE_REP_PEN
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
cat(sprintf("generation.json: max_tokens=%d  repetition_penalty=%.1f  (override rescue)\n",
            RESCUE_MAX_TOKENS, RESCUE_REP_PEN))

job <- dgx_p4_submit(b, time = SUBMIT_TIME)
saveRDS(job, file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds")))
cat(sprintf("Submitted %s: slurm=%s run_id=%s\n", SLUG, job$slurm_job_id, job$run_id))
cat("Job sul DGX (4-worker). Collect + merge nel master v3 dopo COMPLETED.\n")
