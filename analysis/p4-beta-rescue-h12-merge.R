#!/usr/bin/env Rscript
# p4-beta-rescue-h12-merge.R --- merge H1.2 rescued nel master stage1
# rescued post-H1, aggiornando rescue_source per i record recuperati.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
SLUG       <- "beta-rescue-stage1-h12"
MASTER_IN  <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
MASTER_OUT <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued-v2.jsonl"

job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])
res <- dgx_p4_collect(job)
preds <- res$predictions
cat(sprintf("H1.2 collect: %d valid, %d residual\n",
            nrow(preds), nrow(res$errors)))

rescue_map <- new.env(hash = TRUE, size = nrow(preds))
for (i in seq_len(nrow(preds)))
  rescue_map[[preds$record_id[i]]] <- preds$raw_output[i]

con_in  <- file(MASTER_IN, "r")
con_out <- file(MASTER_OUT, "w")
n_total <- 0L; n_rescued <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  new_raw <- rescue_map[[rec$record_id]]
  if (!is.null(new_raw)) {
    rec$raw_output    <- new_raw
    rec$parsed_json   <- tryCatch(jsonlite::fromJSON(new_raw, simplifyVector = FALSE),
                                  error = function(e) NULL)
    rec$rescue_source <- "h12_rep13_maxtok8192"
    n_rescued <- n_rescued + 1L
  }
  writeLines(as.character(jsonlite::toJSON(rec, auto_unbox = TRUE,
                                            null = "null", na = "null")),
             con_out)
}
close(con_in); close(con_out)
cat(sprintf("Master v2 rescued: %d total, %d H1.2 rescued\n",
            n_total, n_rescued))

con <- file(MASTER_OUT, "r")
n_total <- 0L; n_valid <- 0L
while (TRUE) {
  L <- readLines(con, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(rec$parsed_json) && !is.null(rec$parsed_json$series_id))
    n_valid <- n_valid + 1L
}
close(con)
cat(sprintf("Schema validity post-H1.2: %d/%d = %.4f%%\n",
            n_valid, n_total, 100*n_valid/n_total))
# Atomic swap: rename v2 -> master rescued (overwrite)
file.rename(MASTER_OUT, MASTER_IN)
cat(sprintf("Master file replaced: %s\n", MASTER_IN))
