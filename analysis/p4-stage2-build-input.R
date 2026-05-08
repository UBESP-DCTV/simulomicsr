#!/usr/bin/env Rscript
# p4-stage2-build-input.R --- Costruisce l'input JSONL per alpha stage2 (Task 22).
#
# Input  : analysis/p4-output/alpha-stage1-final.rds  (130,784 sample_facts)
# Output : data-raw/p4-alpha-stage2.jsonl
#
# Stato 2026-05-08: questo script ha generato l'input usato nei job 19778-
# 19811 (vedi docs/superpowers/specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md).
# Per la next session, Path C suggerisce di abbassare CHUNK_SIZE da 50 a 25
# per ottenere prompt piu' piccoli (~10500 record, max ~50KB/record).
#
# Decisioni P4 alpha stage2 (2026-05-07):
#   1B  -- study_summary = "" (baseline; nessuna chiamata rentrez)
#   2B  -- SuperSeries (record_id "GSEX,GSEY") tenute come record;
#          il prompt's series_id usa il PRIMO membro della comma-string
#          (per pattern `^GSE[0-9]+$` schema-valid output).
#   3   -- studi con > CHUNK_SIZE sample sono splittati in piu' record
#          con record_id "GSEX#kofN" (shuffle deterministico seed=1812);
#          chunk_metadata accompagna il prompt.
#
# Schema input record (linea JSONL):
#   {
#     "record_id": "<GSE>" | "<GSE>#kofN" | "<comma_string>" | "<comma_string>#kofN",
#     "series_id": "<GSE canonico>",   # primo membro per SuperSeries
#     "study_summary": "",
#     "samples": [{ "geo_accession": "GSMxxx", "sample_facts": {...} }, ...],
#     "chunk_metadata": {              # presente solo per chunk
#         "part": k, "total_parts": N, "study_total_samples": M,
#         "original_record_key": "<GSE> | <comma_string>"
#     }
#   }

suppressPackageStartupMessages({
  library(jsonlite)
})

# CHUNK_SIZE: numero di sample per record stage2.
# - 50 (alpha originale 2026-05-07): produce record fino a ~101KB (~28K token)
#   che triggerano deadlock vLLM 0.10 sul processing di prompt vicini al cap
#   max_model_len=32768. Investigation 2026-05-08 jobs 19839-19840 ha
#   confermato: SINGOLO record da 101KB su 1 GPU + max_num_seqs=1 stalla
#   immediatamente dopo "generazione su 1 record", nessuna progress in 12 min.
# - 25 (post-investigation 2026-05-08): tutti i record sotto ~50KB (~14K token),
#   ampia soglia di sicurezza vs cap.
CHUNK_SIZE <- 25L
SEED       <- 1812L
INPUT_RDS  <- "analysis/p4-output/alpha-stage1-final.rds"
OUT_JSONL  <- "data-raw/p4-alpha-stage2-cs25.jsonl"

stopifnot(file.exists(INPUT_RDS))

cat("Loading", INPUT_RDS, "...\n")
final <- readRDS(INPUT_RDS)
sf <- final$predictions
stopifnot(nrow(sf) == 130784L)

# Estrai series_id (puo' essere "GSE12345" o "GSE43788,GSE43789" SuperSeries)
sids <- vapply(sf$parsed_json, function(p) {
  s <- p$series_id
  if (is.null(s) || length(s) == 0L) NA_character_ else as.character(s)
}, character(1))
stopifnot(!any(is.na(sids)))

# Helper: primo GSE di una comma-string
canonical_gse <- function(sid) {
  if (!grepl(",", sid, fixed = TRUE)) return(sid)
  strsplit(sid, ",", fixed = TRUE)[[1L]][1L]
}

# Validazione: tutti i canonical matchano ^GSE[0-9]+$
canonical_all <- vapply(unique(sids), canonical_gse, character(1))
bad <- canonical_all[!grepl("^GSE[0-9]+$", canonical_all)]
if (length(bad)) {
  stop("series_id canonical non valido: ", paste(head(bad, 5), collapse = ", "))
}

# Aggregazione: una entry per series_id-string
unique_sids <- unique(sids)
cat("Unique series_id strings:", length(unique_sids), "\n")
cat("  Single GSE:    ", sum(!grepl(",", unique_sids, fixed = TRUE)), "\n")
cat("  SuperSeries:   ", sum( grepl(",", unique_sids, fixed = TRUE)), "\n")

# Costruisci record-list shufflato deterministico
set.seed(SEED)
con <- file(OUT_JSONL, open = "w")
on.exit(close(con), add = TRUE)

n_records   <- 0L
n_chunks    <- 0L
n_chunked_studies <- 0L
chunk_log   <- list()  # per debug: studies that got split

.derive_seed <- function(key, base_seed) {
  # MD5 -> int positivo in [1, 2^31-1] per riproducibilita' senza dep extra.
  # 7 hex digit bastano (0..0xfffffff = 268M < 2^31).
  hex <- substr(digest::digest(paste0(key, ":", base_seed), algo = "md5"), 1L, 7L)
  v <- strtoi(hex, base = 16L)
  if (is.na(v) || v == 0L) v <- 1L
  as.integer(v)
}

for (key in unique_sids) {
  idx <- which(sids == key)
  n_total <- length(idx)
  # Shuffle deterministic per-key (riseed locale, no dipendenza dall'ordine globale)
  set.seed(.derive_seed(key, SEED))
  idx_shuffled <- sample(idx)

  canon <- canonical_gse(key)
  total_parts <- as.integer(ceiling(n_total / CHUNK_SIZE))

  for (k in seq_len(total_parts)) {
    start_i <- (k - 1L) * CHUNK_SIZE + 1L
    end_i   <- min(k * CHUNK_SIZE, n_total)
    chunk_idx <- idx_shuffled[start_i:end_i]

    samples <- lapply(chunk_idx, function(i) {
      list(
        geo_accession = unbox(sf$record_id[i]),
        sample_facts  = sf$parsed_json[[i]]
      )
    })

    if (total_parts == 1L) {
      record_id <- key
      chunk_meta <- NULL
    } else {
      record_id <- paste0(key, "#", k, "of", total_parts)
      chunk_meta <- list(
        part                  = unbox(k),
        total_parts           = unbox(total_parts),
        study_total_samples   = unbox(n_total),
        original_record_key   = unbox(key)
      )
    }

    rec <- list(
      record_id     = unbox(record_id),
      series_id     = unbox(canon),
      study_summary = unbox(""),
      samples       = samples
    )
    if (!is.null(chunk_meta)) rec$chunk_metadata <- chunk_meta

    line <- jsonlite::toJSON(rec, auto_unbox = FALSE, null = "null", na = "null")
    cat(line, "\n", sep = "", file = con)
    n_records <- n_records + 1L
    n_chunks  <- n_chunks + (total_parts > 1L)
  }
  if (total_parts > 1L) {
    n_chunked_studies <- n_chunked_studies + 1L
    chunk_log[[length(chunk_log) + 1L]] <- list(
      key = key, n_total = n_total, total_parts = total_parts
    )
  }
}

cat("\n=== Done ===\n")
cat("Output:           ", OUT_JSONL, "\n")
cat("Total records:    ", n_records, "\n")
cat("Chunked records:  ", n_chunks, " (in", n_chunked_studies, "studies)\n")
cat("Unsplit studies:  ", length(unique_sids) - n_chunked_studies, "\n")

if (length(chunk_log)) {
  cat("\nTop 10 most-split studies:\n")
  log_df <- do.call(rbind, lapply(chunk_log, function(x) {
    data.frame(key = x$key, n_total = x$n_total, parts = x$total_parts,
               stringsAsFactors = FALSE)
  }))
  log_df <- log_df[order(-log_df$parts), ]
  print(head(log_df, 10))
}

# Sanity: ogni linea e' JSON valido + ha i campi attesi
cat("\nSanity check (first record + last record):\n")
lines <- readLines(OUT_JSONL, warn = FALSE)
first <- jsonlite::fromJSON(lines[1], simplifyVector = FALSE)
last  <- jsonlite::fromJSON(lines[length(lines)], simplifyVector = FALSE)
cat("  first record_id:", first$record_id,
    " series_id:", first$series_id,
    " n_samples:", length(first$samples), "\n")
cat("  last record_id: ", last$record_id,
    " series_id: ", last$series_id,
    " n_samples: ", length(last$samples), "\n")

# Verifica: count samples in JSONL == 130784 (no sample lost)
total_samples_in_jsonl <- sum(vapply(lines, function(L) {
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  length(rec$samples)
}, integer(1)))
cat("Total samples emitted:", total_samples_in_jsonl, "(expected 130784)\n")
stopifnot(total_samples_in_jsonl == 130784L)
cat("OK -- nessun sample perso\n")
