#!/usr/bin/env Rscript
# p4-fase-f3-stage2-collect-eval.R --- F3: raccolta + validazione schema fullrun.
# Collect dal DGX + run_summary + % parsed_json non-null (vs smoke 100%).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite)
})

job <- readRDS("analysis/p4-output/20260530T113933Z-f3-stage2-fullrun-33778a-job.rds")
cat("Collect dal DGX...\n")
col <- dgx_p4_collect(job, dest = "analysis/p4-output")
run_dir <- file.path("analysis/p4-output", job$run_id)
preds_path <- file.path(run_dir, "predictions.jsonl")
cat("run_dir:", run_dir, "\n")
cat("predictions.jsonl esiste:", file.exists(preds_path), "\n")

# run_summary.json
rs_path <- file.path(run_dir, "run_summary.json")
if (file.exists(rs_path)) {
  rs <- jsonlite::fromJSON(rs_path)
  cat("\n=== run_summary.json ===\n")
  cat("records_completed_total:", rs$summary$records_completed_total %||% rs$records_completed_total %||% NA, "\n")
  cat("records_failed_schema:  ", rs$summary$records_failed_schema   %||% rs$records_failed_schema   %||% NA, "\n")
  cat("workers_failed_count:   ", rs$summary$workers_failed_count    %||% rs$workers_failed_count    %||% NA, "\n")
}

# Validità schema da predictions.jsonl (% parsed_json non-null)
cat("\n=== validazione predictions.jsonl ===\n")
p <- jsonlite::stream_in(file(preds_path), verbose = FALSE, simplifyVector = FALSE)
n_tot   <- length(p)
ok      <- vapply(p, function(r) !is.null(r$parsed_json), logical(1L))
n_ok    <- sum(ok)
n_fail  <- n_tot - n_ok
cat(sprintf("record stage2 totali: %d\n", n_tot))
cat(sprintf("schema validi (parsed_json non-null): %d (%.3f%%)\n", n_ok, 100*n_ok/n_tot))
cat(sprintf("fail: %d\n", n_fail))

# studi unici (series_id) coperti
sids <- vapply(p, function(r) {
  s <- r$parsed_json$series_id %||% r$series_id
  if (is.null(s) || length(s) == 0L) NA_character_ else as.character(s)[1]
}, character(1L))
cat(sprintf("studi unici (series_id) nei record: %d\n", length(unique(na.omit(sids)))))

# fail per studio (se presenti)
if (n_fail > 0L) {
  fail_rid <- vapply(p[!ok], function(r) as.character(r$record_id %||% NA), character(1L))
  fail_sid <- sub("#.*$", "", fail_rid)
  cat("\nFail per record_id (primi 20):\n"); print(head(fail_rid, 20))
  cat("\nFail per studio (top):\n"); print(head(sort(table(fail_sid), decreasing = TRUE), 15))
}

saveRDS(list(n_tot = n_tot, n_ok = n_ok, n_fail = n_fail,
             fail_record_ids = if (n_fail > 0L) vapply(p[!ok], function(r) as.character(r$record_id %||% NA), character(1L)) else character(0),
             run_dir = run_dir, preds_path = preds_path),
        file.path("analysis/p4-output", paste0(job$run_id, "-f3-collect-eval.rds")))
cat("\n=== COLLECT+EVAL COMPLETE ===\n")
