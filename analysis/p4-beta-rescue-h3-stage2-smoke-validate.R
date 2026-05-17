#!/usr/bin/env Rscript
# p4-beta-rescue-h3-stage2-smoke-validate.R --- collect + count recovery

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

OUTPUT_DIR <- "analysis/p4-output"
SLUG       <- "beta-rescue-stage2-smoke5"

job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])
st  <- dgx_p4_status(job)
stopifnot(st$slurm_state %in% c("COMPLETED", "completed"))

res <- dgx_p4_collect(job)
total <- nrow(res$predictions) + nrow(res$errors)
recovered <- nrow(res$predictions)
cat(sprintf("\n=== H3 smoke5 results ===\n"))
cat(sprintf("Total chunks: %d  Recovered: %d (%.1f%%)\n",
            total, recovered, 100*recovered/total))
cat(sprintf("Still failing: %d\n", nrow(res$errors)))
if (recovered / total < 0.60) {
  cat("\n*** NO-GO: recovery < 60% -- investigate o accept residuals ***\n")
} else {
  cat(sprintf("\n*** GO: recovery %.1f%% -- proceed to full ~86-100 chunk retry ***\n",
              100*recovered/total))
}
