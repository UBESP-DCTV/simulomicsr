#!/usr/bin/env Rscript
# p4-beta-rescue-classify-stage1-fails.R --- Phase 1 rescue: classifica i 1571
# stage1 fails come {ETL_LEAK_NONHUMAN, MODE_A_WHITESPACE, MODE_B_LEGIT_TRUNC,
# OTHER_DEGEN} per drive di H2 (cleanup) + H1 (retry input).

suppressPackageStartupMessages({
  library(jsonlite)
})

`%||%` <- function(a, b) if (is.null(a)) b else a

PREDS  <- "analysis/p4-output/p4-beta-stage1-master-predictions.jsonl"
OUT    <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"

stopifnot(file.exists(PREDS))

extract_field <- function(raw, field) {
  pat <- sprintf("\"%s\"\\s*:\\s*\"[^\"]+\"", field)
  m   <- regmatches(raw, regexpr(pat, raw))
  if (length(m) == 0L) NA_character_
  else sub(sprintf("\"%s\"\\s*:\\s*\"([^\"]+)\"", field), "\\1", m)
}

classify_fail <- function(raw) {
  nc   <- nchar(raw)
  tail <- substr(raw, max(1L, nc - 50L), nc)
  if (grepl("\\t{20,}", tail)) return("MODE_A_WHITESPACE")
  if (nc >= 2400L && !grepl("[\\t\\s]{30,}|(?:\\.{30,})", tail, perl = TRUE)) {
    return("MODE_B_LEGIT_TRUNC")
  }
  "OTHER_DEGEN"
}

cat("Scanning", PREDS, "...\n")
con <- file(PREDS, "r")
rows <- list()
i <- 0L
while (TRUE) {
  L <- readLines(con, n = 1L, warn = FALSE)
  if (!length(L)) break
  i <- i + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(rec$parsed_json)) next
  org <- extract_field(rec$raw_output %||% "", "organism")
  sid <- extract_field(rec$raw_output %||% "", "series_id")
  is_human <- isTRUE(org %in% c("human", "Homo sapiens"))
  mode <- if (!is_human && !is.na(org)) "ETL_LEAK_NONHUMAN" else classify_fail(rec$raw_output %||% "")
  rows[[length(rows) + 1L]] <- data.frame(
    record_id   = rec$record_id,
    series_id   = sid,
    organism    = org,
    nchar_raw   = nchar(rec$raw_output %||% ""),
    fail_mode   = mode,
    stringsAsFactors = FALSE
  )
  if (length(rows) %% 200L == 0L) {
    cat(sprintf("...processed %d lines, %d fails captured\n", i, length(rows)))
  }
}
close(con)

df <- do.call(rbind, rows)
write.csv(df, OUT, row.names = FALSE)
cat(sprintf("\nTotal fails: %d\n", nrow(df)))
cat("\n=== fail_mode distribution ===\n")
print(table(df$fail_mode))
cat("\n=== organism per fail_mode ===\n")
print(table(df$fail_mode, df$organism, useNA = "always"))
cat("\nOutput:", OUT, "\n")
