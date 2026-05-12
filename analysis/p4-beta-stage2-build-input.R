#!/usr/bin/env Rscript
# p4-beta-stage2-build-input.R --- Costruisce l'input JSONL per beta stage2.
#
# Input  : analysis/p4-output/<run-id>/predictions.jsonl (stage1 beta output)
# Output : data-raw/p4-beta-stage2.jsonl
#
# Paralello a analysis/p4-stage2-build-input.R (versione alpha): condivide la
# logica di chunking ma legge JSONL invece di RDS, e usa il series_id gia'
# canonicalizzato dal series-id-resolver dell'ETL (Task beta-4) invece della
# heuristic canonical_gse (primo membro della comma-string) usata in alpha.
#
# Schema input record (stage1 predictions.jsonl):
#   { "record_id": "GSM...", "raw_output": "...", "parsed_json": { ... sample_facts.stage1.v3 ... } }
#
# Schema output record (stage2 input JSONL): identico a alpha.
#   {
#     "record_id": "<GSE>" | "<GSE>#kofN",
#     "series_id": "<GSE canonico>",        # da parsed_json$series_id
#     "study_summary": "",
#     "samples": [{ "geo_accession": "GSM...", "sample_facts": {...} }, ...],
#     "chunk_metadata": { ... }              # presente solo per chunk
#   }
#
# CONFIG via env var:
#   STAGE1_PREDS_PATH  Path al predictions.jsonl di stage1 (no default - obbligatorio)
#   OUT_JSONL          Path output (default data-raw/p4-beta-stage2.jsonl)
#   CHUNK_SIZE         Sample per chunk (default 50 - ADR-0013 cs50)
#   SEED               Seed deterministico shuffle (default 1812 come alpha)

suppressPackageStartupMessages({
  library(jsonlite)
})

STAGE1_PREDS_PATH <- Sys.getenv("STAGE1_PREDS_PATH", unset = NA_character_)
if (is.na(STAGE1_PREDS_PATH) || !nzchar(STAGE1_PREDS_PATH)) {
  stop("STAGE1_PREDS_PATH non settato. ",
       "Esempio: STAGE1_PREDS_PATH=analysis/p4-output/<run-id>/predictions.jsonl Rscript ...",
       call. = FALSE)
}
stopifnot(file.exists(STAGE1_PREDS_PATH))

OUT_JSONL  <- Sys.getenv("OUT_JSONL",  unset = "data-raw/p4-beta-stage2.jsonl")
CHUNK_SIZE <- as.integer(Sys.getenv("CHUNK_SIZE", unset = "50"))
SEED       <- as.integer(Sys.getenv("SEED",       unset = "1812"))

dir.create(dirname(OUT_JSONL), recursive = TRUE, showWarnings = FALSE)

cat("Loading", STAGE1_PREDS_PATH, "...\n")
# simplifyVector=FALSE: jsonlite default semplifica parsed_json a nested
# data.frame, qui invece serve list-of-lists per accesso uniforme a campi
# heterogenei (es. perturbations[] vuoto/popolato per record diversi).
preds <- jsonlite::stream_in(file(STAGE1_PREDS_PATH),
                              verbose = FALSE,
                              simplifyVector = FALSE)
n_preds <- length(preds)
cat("Loaded", n_preds, "stage1 predictions\n")

# Estrai series_id da parsed_json. In beta il resolver pre-stage1 produce un
# singolo GSE canonico (non comma-string), quindi NO canonical_gse heuristic.
sids <- vapply(preds, function(rec) {
  pj <- rec$parsed_json
  if (is.null(pj)) return(NA_character_)
  s <- pj$series_id
  if (is.null(s) || length(s) == 0L) NA_character_ else as.character(s)
}, character(1))
n_na <- sum(is.na(sids))
if (n_na > 0L) {
  warning(sprintf("Stage1 predictions con series_id mancante (LLM fail): %d / %d (%.2f%%). ",
                  n_na, length(sids), 100 * n_na / length(sids)),
          "Sample droppati da stage2 input. Per recovery completo: ",
          "retry/uniqfail rounds upstream + re-run.", call. = FALSE)
  # Drop failed: filtra preds + sids alle posizioni valide
  keep_idx <- !is.na(sids)
  preds <- preds[keep_idx]
  sids  <- sids[keep_idx]
  n_preds <- length(preds)
  cat(sprintf("Dropped %d records; %d valid records rimangono.\n",
              n_na, n_preds))
}

# Validazione: tutti i sid validi matchano ^GSE[0-9]+$ (post-resolver = single GSE)
bad <- unique(sids[!grepl("^GSE[0-9]+$", sids)])
if (length(bad)) {
  warning("series_id non-canonico trovato (atteso ^GSE[0-9]+$ post-resolver): ",
          paste(head(bad, 5), collapse = ", "),
          ". Records droppati.", call. = FALSE)
  keep_idx <- grepl("^GSE[0-9]+$", sids)
  preds <- preds[keep_idx]
  sids  <- sids[keep_idx]
  n_preds <- length(preds)
}

unique_sids <- unique(sids)
cat("Unique series_id (studi):", length(unique_sids), "\n")

# Costruzione record stage2: chunking deterministico per-studio.
# NB: accumula linee in memoria + writeLines finale invece di file
# connection persistente (evita "invalid connection" quando il file e'
# sourced da un altro script con env multipli).
set.seed(SEED)
output_buf        <- vector("list", 0L)
n_records         <- 0L
n_chunks          <- 0L
n_chunked_studies <- 0L
chunk_log         <- list()

.derive_seed <- function(key, base_seed) {
  hex <- substr(digest::digest(paste0(key, ":", base_seed), algo = "md5"), 1L, 7L)
  v <- strtoi(hex, base = 16L)
  if (is.na(v) || v == 0L) v <- 1L
  as.integer(v)
}

for (key in unique_sids) {
  idx <- which(sids == key)
  n_total <- length(idx)
  set.seed(.derive_seed(key, SEED))
  idx_shuffled <- sample(idx)

  total_parts <- as.integer(ceiling(n_total / CHUNK_SIZE))

  for (k in seq_len(total_parts)) {
    start_i   <- (k - 1L) * CHUNK_SIZE + 1L
    end_i     <- min(k * CHUNK_SIZE, n_total)
    chunk_idx <- idx_shuffled[start_i:end_i]

    samples <- lapply(chunk_idx, function(i) {
      list(
        geo_accession = unbox(preds[[i]]$record_id),
        sample_facts  = preds[[i]]$parsed_json
      )
    })

    if (total_parts == 1L) {
      record_id  <- key
      chunk_meta <- NULL
    } else {
      record_id  <- paste0(key, "#", k, "of", total_parts)
      chunk_meta <- list(
        part                = unbox(k),
        total_parts         = unbox(total_parts),
        study_total_samples = unbox(n_total),
        original_record_key = unbox(key)
      )
    }

    rec <- list(
      record_id     = unbox(record_id),
      series_id     = unbox(key),
      study_summary = unbox(""),
      samples       = samples
    )
    if (!is.null(chunk_meta)) rec$chunk_metadata <- chunk_meta

    line <- jsonlite::toJSON(rec, auto_unbox = FALSE, null = "null", na = "null")
    n_records <- n_records + 1L
    output_buf[[n_records]] <- as.character(line)
    n_chunks  <- n_chunks  + (total_parts > 1L)
  }
  if (total_parts > 1L) {
    n_chunked_studies <- n_chunked_studies + 1L
    chunk_log[[length(chunk_log) + 1L]] <- list(
      key = key, n_total = n_total, total_parts = total_parts
    )
  }
}

# Scrive tutto in una writeLines (single connection, niente on.exit issue)
writeLines(unlist(output_buf), OUT_JSONL)

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
first <- jsonlite::fromJSON(lines[1L], simplifyVector = FALSE)
last  <- jsonlite::fromJSON(lines[length(lines)], simplifyVector = FALSE)
cat("  first record_id:", first$record_id,
    " series_id:", first$series_id,
    " n_samples:", length(first$samples), "\n")
cat("  last record_id: ", last$record_id,
    " series_id: ", last$series_id,
    " n_samples: ", length(last$samples), "\n")

# Verifica: count samples in JSONL == n_preds (no sample lost)
total_samples_in_jsonl <- sum(vapply(lines, function(L) {
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  length(rec$samples)
}, integer(1L)))
cat("Total samples emitted:", total_samples_in_jsonl,
    "(expected", n_preds, ")\n")
stopifnot(total_samples_in_jsonl == n_preds)
cat("OK -- nessun sample perso\n")
