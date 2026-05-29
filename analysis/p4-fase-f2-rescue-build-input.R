#!/usr/bin/env Rscript
# p4-fase-f2-rescue-build-input.R --- RED ALERT FASE F2 rescue: costruisce
# l'input H1 estraendo dal jsonl-v2 i record completi dei 1.464 fail LLM
# (record_id presi dal CSV di classificazione). Output verbatim (stesse chiavi
# del jsonl-v2: record_id, geo_accession, series_id, string, library_strategy,
# organism, molecule_ch1) -> riusabile dal bundle stage1 standard.

suppressPackageStartupMessages({ library(jsonlite) })

FAILS_CSV <- "analysis/p4-output/p4-fase-f2-rescue-stage1-fails-classified.csv"
INPUT_V2  <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
OUT       <- "analysis/input/archs4-human-stage1-v2-rescue.jsonl"
stopifnot(file.exists(FAILS_CSV), file.exists(INPUT_V2))

fail_ids <- read.csv(FAILS_CSV, stringsAsFactors = FALSE)$record_id
fail_set <- new.env(parent = emptyenv())
for (id in fail_ids) assign(id, TRUE, envir = fail_set)
cat(sprintf("Fail record_id da estrarre: %d\n", length(fail_ids)))

con <- file(INPUT_V2, "r"); out <- file(OUT, "w")
kept <- 0L; seen_ids <- character(0)
repeat {
  ls <- readLines(con, n = 50000L, warn = FALSE)
  if (length(ls) == 0L) break
  # estrazione veloce del record_id via regex (chiave sempre presente)
  ids <- sub('.*"record_id"[[:space:]]*:[[:space:]]*"([^"]+)".*', "\\1", ls)
  keep <- vapply(ids, function(x) exists(x, envir = fail_set, inherits = FALSE),
                 logical(1))
  if (any(keep)) {
    writeLines(ls[keep], out)
    kept <- kept + sum(keep)
    seen_ids <- c(seen_ids, ids[keep])
  }
}
close(con); close(out)

cat(sprintf("Estratti %d record -> %s\n", kept, OUT))
missing <- setdiff(fail_ids, seen_ids)
cat(sprintf("Mancanti (fail id non trovati nel jsonl-v2): %d\n", length(missing)))
if (length(missing) > 0L) print(utils::head(missing, 20))
stopifnot(kept == length(fail_ids), length(missing) == 0L)
cat("OK build rescue input\n")
