#!/usr/bin/env Rscript
# p4-stage2-build-mini2000.R --- mini-input 2000 record per scale test
# Task 22 (post mini50 smoke OK 2026-05-08).
#
# Output: data-raw/p4-stage2-mini2000.jsonl
#
# Composizione (mix realistico, deterministico seed=1812):
#   1000 small   (<10 KB)     warm-up zone
#    800 medium  (10-30 KB)   tipico
#    200 large   (>30 KB)     stress zone (scenario v5 cycle 0)
# Round-robin sharding 4 worker -> 500 record/worker, supera 340 limite v5.

set.seed(1812)
# Permetti override input/output via env var (per buildare varianti chunk_size)
INPUT  <- Sys.getenv("MINI_INPUT",  unset = "data-raw/p4-alpha-stage2-cs25.jsonl")
OUTPUT <- Sys.getenv("MINI_OUTPUT", unset = "data-raw/p4-stage2-mini2000-cs25.jsonl")
stopifnot(file.exists(INPUT))

lines <- readLines(INPUT, warn = FALSE)
sizes <- nchar(lines, type = "bytes")

idx_small  <- which(sizes < 10000L)
idx_medium <- which(sizes >= 10000L & sizes <= 30000L)
idx_large  <- which(sizes > 30000L)
cat("Pool sizes: small=", length(idx_small),
    " medium=", length(idx_medium),
    " large=", length(idx_large), "\n", sep = "")

# Cap a quanto disponibile per ogni bucket
n_small  <- min(1000L, length(idx_small))
n_medium <- min(800L,  length(idx_medium))
n_large  <- min(200L,  length(idx_large))
cat("Selecting: small=", n_small,
    " medium=", n_medium, " large=", n_large, "\n", sep = "")

pick_small  <- sample(idx_small,  n_small)
pick_medium <- sample(idx_medium, n_medium)
pick_large  <- sample(idx_large,  n_large)

# Interleave: 5 small / 4 medium / 1 large (= 10 cycle)
ordered <- integer(0L)
si <- 1L; mi <- 1L; li <- 1L
while (si <= n_small || mi <= n_medium || li <= n_large) {
  for (k in 1:5) if (si <= n_small) { ordered <- c(ordered, pick_small[si]);  si <- si + 1L }
  for (k in 1:4) if (mi <= n_medium){ ordered <- c(ordered, pick_medium[mi]); mi <- mi + 1L }
  for (k in 1:1) if (li <= n_large) { ordered <- c(ordered, pick_large[li]);  li <- li + 1L }
}

selected <- lines[ordered]
sel_sizes <- nchar(selected, type = "bytes")
cat("\nSelected mini2000:\n")
cat("  total  records=", length(selected), "\n")
cat("  size median=", as.integer(median(sel_sizes)),
    " p99=", as.integer(quantile(sel_sizes, 0.99)),
    " max=", max(sel_sizes),
    " sum_KB=", as.integer(sum(sel_sizes) / 1024L), "\n", sep = "")

writeLines(selected, OUTPUT)
cat("\nWrote", OUTPUT, "(", length(selected), "records )\n")
