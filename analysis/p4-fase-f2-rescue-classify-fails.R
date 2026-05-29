#!/usr/bin/env Rscript
# p4-fase-f2-rescue-classify-fails.R --- RED ALERT FASE F2 rescue Phase 1:
# classifica i fail LLM Stadio 1 v2 (parsed_json null) come
# {MODE_A_WHITESPACE, MODE_B_LEGIT_TRUNC, OTHER_DEGEN} + check leak organism.
#
# A differenza del beta, l'input v2 e' gia' H2-pulito + filtrato Homo sapiens
# all'ETL (F1), quindi NON sono attesi ETL_LEAK_NONHUMAN. Il check organism dal
# raw_output e' una verifica di sanita': se emergono leak, e' un segnale.

suppressPackageStartupMessages({ library(jsonlite) })
`%||%` <- function(a, b) if (is.null(a)) b else a

FAILS <- "analysis/p4-output/p4-fase-f2-stage1-fails.jsonl"
OUT   <- "analysis/p4-output/p4-fase-f2-rescue-stage1-fails-classified.csv"
stopifnot(file.exists(FAILS))

extract_field <- function(raw, field) {
  pat <- sprintf("\"%s\"\\s*:\\s*\"[^\"]+\"", field)
  m   <- regmatches(raw, regexpr(pat, raw))
  if (length(m) == 0L) NA_character_
  else sub(sprintf("\"%s\"\\s*:\\s*\"([^\"]+)\"", field), "\\1", m)
}

# Stessa euristica del beta (p4-beta-rescue-classify-stage1-fails.R)
classify_fail <- function(raw) {
  nc   <- nchar(raw)
  tail <- substr(raw, max(1L, nc - 50L), nc)
  if (grepl("\\t{20,}", tail)) return("MODE_A_WHITESPACE")
  if (nc >= 2400L && !grepl("[\\t\\s]{30,}|(?:\\.{30,})", tail, perl = TRUE)) {
    return("MODE_B_LEGIT_TRUNC")
  }
  "OTHER_DEGEN"
}

con <- file(FAILS, "r"); rows <- list(); i <- 0L
while (TRUE) {
  L <- readLines(con, n = 1L, warn = FALSE)
  if (!length(L)) break
  i <- i + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  raw <- rec$raw_output %||% ""
  org <- extract_field(raw, "organism")
  is_human <- isTRUE(org %in% c("human", "Homo sapiens"))
  mode <- if (!is.na(org) && !is_human) "ETL_LEAK_NONHUMAN" else classify_fail(raw)
  rows[[length(rows) + 1L]] <- data.frame(
    record_id = rec$record_id %||% NA_character_,
    organism  = org,
    nchar_raw = nchar(raw),
    fail_mode = mode,
    stringsAsFactors = FALSE
  )
}
close(con)

df <- do.call(rbind, rows)
write.csv(df, OUT, row.names = FALSE)
cat(sprintf("Total fail: %d\n", nrow(df)))
cat("\n=== fail_mode ===\n"); print(table(df$fail_mode))
cat("\n=== organism (da raw_output) ===\n"); print(table(df$organism, useNA = "always"))
cat("\n=== nchar_raw summary ===\n"); print(summary(df$nchar_raw))
cat("\nOutput:", OUT, "\n")
