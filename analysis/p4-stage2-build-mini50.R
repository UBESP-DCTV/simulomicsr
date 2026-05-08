#!/usr/bin/env Rscript
# p4-stage2-build-mini50.R --- Costruisce mini-input 50 record per smoke test
# stage2 (Task 22 investigation 2026-05-08).
#
# Output: data-raw/p4-stage2-mini50.jsonl (gitignored)
#
# Composizione (mix taglie, deterministico seed=1812):
#   25 small   (<10 KB / record)  -> warmup-friendly
#   20 medium  (10-30 KB)         -> rappresentativi del corpus
#    5 large   (>50 KB)           -> riproducono il caso peggiore
# I record sono interleaved (small/medium/large) cosi' un singolo
# llm.chat() su mini50 con sharding worker copre la distribuzione
# realistica di dimensione/prefill cost.

set.seed(1812)
INPUT  <- "data-raw/p4-alpha-stage2.jsonl"
OUTPUT <- "data-raw/p4-stage2-mini50.jsonl"

stopifnot(file.exists(INPUT))

cat("Reading", INPUT, "...\n")
lines <- readLines(INPUT, warn = FALSE)
sizes <- nchar(lines, type = "bytes")
cat("Total records:", length(lines), "\n")
cat("Size distribution (bytes):  min=", min(sizes),
    " median=", as.integer(median(sizes)),
    " p99=", as.integer(quantile(sizes, 0.99)),
    " max=", max(sizes), "\n", sep = "")

idx_small  <- which(sizes < 10000L)
idx_medium <- which(sizes >= 10000L & sizes <= 30000L)
idx_large  <- which(sizes > 50000L)

cat("Pool sizes: small=", length(idx_small),
    " medium=", length(idx_medium),
    " large=", length(idx_large), "\n", sep = "")

stopifnot(length(idx_small)  >= 25L,
          length(idx_medium) >= 20L,
          length(idx_large)  >= 5L)

pick_small  <- sample(idx_small,  25L)
pick_medium <- sample(idx_medium, 20L)
pick_large  <- sample(idx_large,   5L)

# Interleave: alterna le 3 categorie in modo deterministico
ordered <- integer(50L)
si <- 1L; mi <- 1L; li <- 1L
for (k in seq_len(50L)) {
  bucket <- ((k - 1L) %% 10L)
  if (bucket < 5L) {                  # 5/10 small
    ordered[k] <- pick_small[si];  si <- si + 1L
  } else if (bucket < 9L) {           # 4/10 medium
    ordered[k] <- pick_medium[mi]; mi <- mi + 1L
  } else {                            # 1/10 large
    ordered[k] <- pick_large[li];  li <- li + 1L
  }
}

selected <- lines[ordered]
sel_sizes <- nchar(selected, type = "bytes")
cat("\nSelected mini50 size distribution:\n")
cat("  min=", min(sel_sizes),
    " median=", as.integer(median(sel_sizes)),
    " max=", max(sel_sizes),
    " sum_KB=", as.integer(sum(sel_sizes) / 1024L), "\n", sep = "")

writeLines(selected, OUTPUT)
cat("\nWrote", OUTPUT, "(", length(selected), "records )\n")

# Quick id snapshot
ids <- vapply(selected, function(s) {
  sub('^.*"record_id":"([^"]+)".*$', "\\1", s)
}, character(1))
cat("First 5 record_ids:", paste(head(ids, 5), collapse = ", "), "\n")
cat("Last 5 record_ids: ", paste(tail(ids, 5), collapse = ", "), "\n")
