#!/usr/bin/env Rscript
# p4-beta-rescue-h1-build-input.R --- H1: estrai gli input stage1 originali
# (string metadati) per i fails Mode A/B/OTHER_DEGEN da re-submittare con
# rep_pen=1.2 + max_tokens=4096 (mirror ADR-0008 addendum rep12_maxtok2048
# escalation alpha).

suppressPackageStartupMessages({
  library(jsonlite)
})

CLASSIFIED <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"
INPUT_FULL <- "analysis/input/archs4-human-stage1-input.jsonl"
OUT        <- "analysis/input/archs4-human-stage1-rescue.jsonl"

df <- read.csv(CLASSIFIED, stringsAsFactors = FALSE)
target_gsm <- df$record_id[df$fail_mode %in% c("MODE_A_WHITESPACE",
                                                "MODE_B_LEGIT_TRUNC",
                                                "OTHER_DEGEN")]
cat(sprintf("Target rescue records: %d\n", length(target_gsm)))
target_set <- new.env(hash = TRUE, size = length(target_gsm))
for (g in target_gsm) target_set[[g]] <- TRUE

cat("Streaming input full...\n")
con_in  <- file(INPUT_FULL, "r")
con_out <- file(OUT, "w")
n_total <- 0L; n_kept <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(target_set[[rec$record_id]])) {
    writeLines(L, con_out)
    n_kept <- n_kept + 1L
  }
  if (n_total %% 100000L == 0L)
    cat(sprintf("...%d processed, %d/%d matched\n",
                n_total, n_kept, length(target_gsm)))
}
close(con_in); close(con_out)
cat(sprintf("Rescue input emitted: %d records (expected %d)\n",
            n_kept, length(target_gsm)))
stopifnot(n_kept == length(target_gsm))
cat("Output:", OUT, "\n")
