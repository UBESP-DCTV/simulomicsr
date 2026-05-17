#!/usr/bin/env Rscript
# p4-beta-rescue-h3-merge.R --- Merge cs25 rescued chunks nel master stage2.
# Logica: ogni original_record_key e' rescued solo se TUTTE le sue cs25 parts
# sono valid_schema=TRUE. Altrimenti resta nei residual.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite)
})

OUTPUT_DIR  <- "analysis/p4-output"
ORIG_COLL   <- "analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/collect.rds"
SLUG_H3     <- "beta-rescue-stage2-full"
OUT_COLL    <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

orig <- readRDS(ORIG_COLL)
cat(sprintf("Orig collect: %d valid, %d errors\n", nrow(orig$predictions), nrow(orig$errors)))

job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG_H3, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])
h3 <- dgx_p4_collect(job)
cat(sprintf("H3 collect: %d valid cs25 chunks, %d errors\n",
            nrow(h3$predictions), nrow(h3$errors)))

extract_orig_key <- function(rec_id) sub("--rsc.*", "", rec_id)
h3_valid_keys   <- extract_orig_key(h3$predictions$record_id)
h3_invalid_keys <- extract_orig_key(h3$errors$record_id)

counts_invalid_per_key <- table(h3_invalid_keys)
rescued_keys <- setdiff(unique(h3_valid_keys), names(counts_invalid_per_key))
cat(sprintf("Original keys fully rescued: %d / %d\n",
            length(rescued_keys), length(orig$errors$record_id)))

add_rescue <- function(df, rescue_tag) {
  if (!"rescue_source" %in% names(df)) df$rescue_source <- NA_character_
  df$rescue_source[is.na(df$rescue_source)] <- rescue_tag
  df
}
preds_orig <- add_rescue(orig$predictions, NA_character_)
preds_rescued <- h3$predictions[extract_orig_key(h3$predictions$record_id) %in% rescued_keys, ]
preds_rescued$rescue_source <- "h3_cs25_resplit"

preds_new <- rbind(preds_orig, preds_rescued)
errors_new <- orig$errors[!orig$errors$record_id %in% rescued_keys, ]

saveRDS(list(
  predictions = preds_new,
  errors      = errors_new,
  summary     = list(orig = orig$summary, h3_added = nrow(preds_rescued))
), OUT_COLL)
cat(sprintf("\nWritten: %s\n", OUT_COLL))
cat(sprintf("Total predictions post-H3: %d  Residual errors: %d\n",
            nrow(preds_new), nrow(errors_new)))
cat(sprintf("Schema validity: %.3f%%\n",
            100*nrow(preds_new)/(nrow(preds_new)+nrow(errors_new))))
