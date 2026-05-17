#!/usr/bin/env Rscript
# p4-beta-rescue-h1-stage1-smoke-validate.R --- collect smoke + count recovery

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

OUTPUT_DIR <- "analysis/p4-output"
SLUG       <- "beta-rescue-stage1-smoke20"

job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])

st <- dgx_p4_status(job)
cat(sprintf("slurm_state: %s\n", st$slurm_state))
stopifnot(st$slurm_state %in% c("COMPLETED", "completed"))

res <- dgx_p4_collect(job)
preds <- res$predictions
errs  <- res$errors
total <- nrow(preds) + nrow(errs)
recovered <- nrow(preds)
cat(sprintf("\n=== Smoke H1 results ===\n"))
cat(sprintf("Total: %d\n", total))
cat(sprintf("Recovered (valid_schema=TRUE): %d (%.1f%%)\n", recovered, 100*recovered/total))
cat(sprintf("Still failing: %d\n", nrow(errs)))

if (recovered / total < 0.80) {
  cat("\n*** NO-GO: recovery < 80% -- investigate residual fails before full retry ***\n")
} else {
  cat(sprintf("\n*** GO: recovery %.1f%% >= 80%% -- proceed to full retry ~822 records ***\n",
              100*recovered/total))
}
