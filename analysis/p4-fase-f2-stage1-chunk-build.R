#!/usr/bin/env Rscript
# p4-fase-f2-stage1-chunk-build.R --- RED ALERT FASE F2: prepara l'input
# chunked per il fullrun Stadio 1 sul bacino v2 (508.037 sample).
#
# Replica fedele del setup beta (Task 10 + 10b), config INVARIATA:
#   1. Shuffle deterministico seed=42 (shell `shuf --random-source=<(yes 42)`,
#      identico a beta). L'ordine e' irrilevante per la correttezza di Stadio 1
#      (ogni sample classificato indipendentemente) ma bilancia la difficolta'
#      tra chunk e da throughput stabile.
#   2. Split outlier: i record con nchar(string) > 3500 (valore DECODIFICATO
#      del campo JSON `string`, non la riga raw) vanno in un file separato,
#      processati a parte con max_model_len=32768 (Task 10b, vLLM Issue #39734).
#   3. Chunk del mainstream (nchar <= 3500) in blocchi da 10.000 record.
#
# NON tocca alcun artefatto beta: dir/slug/state separati (v2-*).

suppressPackageStartupMessages({
  library(jsonlite)
  library(fs)
})

INPUT      <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
SHUFFLED   <- "analysis/input/archs4-human-stage1-input-v2-shuffled.jsonl"
OUTLIERS   <- "analysis/input/archs4-human-stage1-v2-outliers.jsonl"
CHUNKS_DIR <- "analysis/input/v2-chunks"
CHUNK_SIZE <- 10000L
NCHAR_MAX  <- 3500L

stopifnot(file.exists(INPUT))

# === 1. Shuffle deterministico seed=42 (identico a beta) ===
if (!file.exists(SHUFFLED)) {
  cat("Shuffle seed=42 ...\n")
  rc <- system2("bash", c("-c",
    shQuote(sprintf("shuf --random-source=<(yes 42) %s > %s",
                    shQuote(INPUT), shQuote(SHUFFLED)))))
  if (rc != 0L) stop("shuf fallito (rc=", rc, ")")
} else {
  cat("Shuffled gia' presente, riuso.\n")
}

# === 2. Lettura raw (verbatim) + parse per nchar(string) ===
raw <- readLines(SHUFFLED, warn = FALSE)
cat(sprintf("Record shuffled: %d\n", length(raw)))

# stream_in preserva l'ordine del file -> indici allineati a `raw`.
df <- jsonlite::stream_in(file(SHUFFLED), verbose = FALSE)
stopifnot(nrow(df) == length(raw))
stopifnot("string" %in% names(df))

nc <- nchar(df$string)
cat("Summary nchar(string decodificato):\n"); print(summary(nc))

idx_out <- which(nc > NCHAR_MAX)
cat(sprintf("Outlier nchar>%d: %d\n", NCHAR_MAX, length(idx_out)))

# === 3. Scrittura outlier + mainstream chunked ===
fs::dir_create(CHUNKS_DIR, recurse = TRUE)

if (length(idx_out) > 0L) {
  writeLines(raw[idx_out], OUTLIERS)
  cat(sprintf("Outliers -> %s (%d record)\n", OUTLIERS, length(idx_out)))
  main <- raw[-idx_out]
} else {
  cat("Nessun outlier.\n")
  main <- raw
}

n_main   <- length(main)
n_chunks <- ceiling(n_main / CHUNK_SIZE)
cat(sprintf("Mainstream: %d record -> %d chunk da %d\n",
            n_main, n_chunks, CHUNK_SIZE))

for (i in seq_len(n_chunks)) {
  lo <- (i - 1L) * CHUNK_SIZE + 1L
  hi <- min(i * CHUNK_SIZE, n_main)
  path <- fs::path(CHUNKS_DIR, sprintf("chunk-%02d.jsonl", i - 1L))
  writeLines(main[lo:hi], path)
}
cat(sprintf("Scritti %d chunk in %s (chunk-00 .. chunk-%02d)\n",
            n_chunks, CHUNKS_DIR, n_chunks - 1L))

# Riconciliazione: somma chunk + outlier == input
written <- sum(vapply(
  fs::dir_ls(CHUNKS_DIR, glob = "*.jsonl"),
  function(p) length(readLines(p, warn = FALSE)), integer(1)))
total <- written + length(idx_out)
cat(sprintf("Riconciliazione: chunk %d + outlier %d = %d (input %d) -> %s\n",
            written, length(idx_out), total, length(raw),
            if (total == length(raw)) "OK" else "MISMATCH"))
stopifnot(total == length(raw))
cat(sprintf("\nTOTAL_CHUNKS per il tick = %d\n", n_chunks))
