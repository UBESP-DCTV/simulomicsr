#!/usr/bin/env Rscript
# p4-fase-f3-rescue-build-input.R --- F3 H3: estrai i 36 stage2 fail dal
# stage2-input-v2 + re-splitta a cs25 (half-size chunks). Adattato da
# analysis/p4-beta-rescue-h3-build-input.R.

suppressPackageStartupMessages({
  library(jsonlite)
})

EVAL_RDS <- "analysis/p4-output/20260530T113933Z-f3-stage2-fullrun-33778a-f3-collect-eval.rds"
INPUT_IN <- "analysis/input/archs4-human-stage2-input-v2.jsonl"
OUT      <- "analysis/input/archs4-human-stage2-rescue-cs25-v2.jsonl"

fail_ids <- readRDS(EVAL_RDS)$fail_record_ids
cat(sprintf("Stage2 fail da re-splittare: %d\n", length(fail_ids)))
fail_set <- new.env(hash = TRUE)
for (g in fail_ids) fail_set[[g]] <- TRUE

con_in <- file(INPUT_IN, "r")
hits <- list()
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(fail_set[[rec$record_id]])) hits[[length(hits) + 1L]] <- rec
}
close(con_in)
cat(sprintf("Match nell'input v2: %d records (attesi %d)\n", length(hits), length(fail_ids)))
stopifnot(length(hits) == length(fail_ids))

out_lines <- character(0)
n_out <- 0L
for (rec in hits) {
  samples <- rec$samples
  n <- length(samples)
  new_chunks <- ceiling(n / 25L)
  for (k in seq_len(new_chunks)) {
    s_idx <- ((k-1L)*25L + 1L):min(k*25L, n)
    sub <- list(
      record_id     = paste0(rec$record_id, "--rsc", k, "of", new_chunks),
      series_id     = rec$series_id,
      study_summary = "",
      samples       = samples[s_idx]
    )
    sub$chunk_metadata <- list(
      part                = k,
      total_parts         = new_chunks,
      study_total_samples = n,
      original_record_key = rec$record_id,
      rescue_strategy     = "cs25_resplit_from_cs50"
    )
    line <- jsonlite::toJSON(sub, auto_unbox = TRUE, null = "null", na = "null")
    out_lines <- c(out_lines, as.character(line))
    n_out <- n_out + 1L
  }
}
writeLines(out_lines, OUT)
cat(sprintf("Output: %d chunk cs25 (da %d fail cs50)\n", n_out, length(hits)))
cat("File:", OUT, "\n")
