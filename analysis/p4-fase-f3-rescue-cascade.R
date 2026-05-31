#!/usr/bin/env Rscript
# p4-fase-f3-rescue-cascade.R --- F3 cascade sui residui Stadio 2 che il cs25
# non recupera (studi piccoli, gia' single-chunk). Alza repetition_penalty per
# rompere lo schema che corrompe il JSON. Stessa tecnica di
# analysis/p4-fase-f2-rescue-h1-stage1.R (patch generation.json tra build e submit).
#
# CONFIG via env:
#   REP_PEN    repetition_penalty (default 1.2)
#   REMAINING  record_id residui comma-separati; se vuoto -> residual_keys
#              dall'ultimo *-f3-merge.rds
#   SLUG       slug job (default f3-cascade-rp<REP_PEN>)
# Submit-only, resume-safe. Input estratto dai record ORIGINALI di input v2
# (no re-split: questi studi sono gia' un chunk solo).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs); library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT_V2   <- "analysis/input/archs4-human-stage2-input-v2.jsonl"
REP_PEN    <- as.numeric(Sys.getenv("REP_PEN", "1.2"))
SLUG       <- Sys.getenv("SLUG", paste0("f3-cascade-rp", gsub("\\.", "", sprintf("%.1f", REP_PEN))))

remaining <- Sys.getenv("REMAINING", "")
if (nzchar(remaining)) {
  resid <- trimws(strsplit(remaining, ",")[[1]])
} else {
  mr <- list.files(OUTPUT_DIR, pattern = ".*-f3-merge\\.rds$", full.names = TRUE)
  stopifnot(length(mr) >= 1L)
  resid <- readRDS(mr[which.max(file.info(mr)$mtime)])$residual_keys
}
cat(sprintf("Cascade rep_pen=%.1f su %d residui: %s\n",
            REP_PEN, length(resid), paste(resid, collapse = ", ")))
stopifnot(length(resid) > 0L)

# Resume-safe
existing <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"), full.names = TRUE)
if (length(existing) > 0L) {
  job <- readRDS(existing[which.max(file.info(existing)$mtime)])
  st <- tryCatch(dgx_p4_status(job), error = function(e) list(slurm_state = paste0("ERR: ", e$message)))
  cat(sprintf("Resume: slurm=%s state=%s\n", job$slurm_job_id, st$slurm_state)); quit(status = 0L)
}

# Estrai i record residui (originali, no re-split) da input v2
resid_set <- new.env(hash = TRUE); for (g in resid) resid_set[[g]] <- TRUE
con <- file(INPUT_V2, "r"); hits <- list()
while (TRUE) { L <- readLines(con, 1L, warn = FALSE); if (!length(L)) break
  r <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(resid_set[[r$record_id]])) hits[[length(hits) + 1L]] <- r }
close(con)
cat(sprintf("Match input v2: %d / %d\n", length(hits), length(resid)))
stopifnot(length(hits) == length(resid))

INPUT <- file.path("analysis/input", paste0("archs4-human-stage2-", SLUG, "-input.jsonl"))
con <- file(INPUT, "w")
for (r in hits) writeLines(jsonlite::toJSON(r, auto_unbox = TRUE, null = "null", na = "null"), con)
close(con)

cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(input_jsonl = INPUT, stage = "stage2", config = cfg,
                              metadata = list(slug = SLUG), tiered_max_tokens = TRUE)
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$repetition_penalty <- REP_PEN
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("Patched generation.json: repetition_penalty=%.1f\n", REP_PEN))

job <- dgx_p4_submit(bundle, time = "72:00:00")
saveRDS(job, file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds")))
cat(sprintf("\n=== CASCADE rep_pen=%.1f SUBMITTED ===\nslug=%s slurm=%s run_id=%s\n",
            REP_PEN, SLUG, job$slurm_job_id, job$run_id))
cat("ETA: ~3-5 min wall.\n")
