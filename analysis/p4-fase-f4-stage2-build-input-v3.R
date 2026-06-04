#!/usr/bin/env Rscript
# p4-fase-f4-stage2-build-input-v3.R --- RED ALERT FASE F4 opzione C (ADR-0020).
#
# Costruisce l'input Stadio 2 v3 a CONDIZIONI DEDUPLICATE (niente chunking per
# campione). Per ogni studio raggruppa i campioni per design_signature in
# condizioni di disegno distinte (rappresentante + n_replicates +
# member_sample_ids), emettendo 1 record/studio. Gli studi le cui condizioni
# eccedono il budget caratteri vengono divisi in chunk per-condizione con
# broadcast dei controlli (coda D2). Sostituisce il chunking cs50 per-campione
# (finding 2026-06-01).
#
# Input  : master Stadio 1 F2 (predictions rescued, 1 record/campione)
# Output : JSONL, 1 record/studio (+ chunk per i pochi studi-coda)
#
# Schema output record:
#   { "record_id": "<GSE>" | "<GSE>#kofN",
#     "series_id": "<GSE>",
#     "study_summary": "",
#     "samples": [ { "geo_accession": "<repr GSM>", "sample_facts": {...},
#                    "n_replicates": N, "member_sample_ids": [...],
#                    "condition_id": "cond_0001" }, ... ],
#     "chunk_metadata": {...} }            # solo per studi chunkati
#
# CONFIG via env var:
#   STAGE1_PREDS_PATH  default = master F2 rescued
#   OUT_JSONL          default = analysis/input/archs4-human-stage2-input-v3.jsonl
#   BUDGET_CHARS       tetto caratteri input/record (default 80000, ~23k token)

suppressPackageStartupMessages({ library(jsonlite) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))

STAGE1_PREDS_PATH <- Sys.getenv(
  "STAGE1_PREDS_PATH",
  unset = "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl")
stopifnot(file.exists(STAGE1_PREDS_PATH))
OUT_JSONL <- Sys.getenv(
  "OUT_JSONL", unset = "analysis/input/archs4-human-stage2-input-v3.jsonl")
BUDGET_CHARS <- as.integer(Sys.getenv("BUDGET_CHARS", unset = "80000"))
dir.create(dirname(OUT_JSONL), recursive = TRUE, showWarnings = FALSE)

cat("Loading", STAGE1_PREDS_PATH, "...\n")
preds <- jsonlite::stream_in(file(STAGE1_PREDS_PATH), verbose = FALSE,
                             simplifyVector = FALSE)
cat("Loaded", length(preds), "stage1 predictions\n")

# Guard is_zero_timepoint + raggruppamento per series_id.
by_series <- new.env(parent = emptyenv())
n_drop <- 0L; zt_total <- 0L
for (rec in preds) {
  pj <- rec$parsed_json
  if (is.null(pj)) { n_drop <- n_drop + 1L; next }
  sid <- if (is.null(pj$series_id)) NA_character_ else as.character(pj$series_id)[[1]]
  if (is.na(sid) || !grepl("^GSE[0-9]+$", sid)) { n_drop <- n_drop + 1L; next }
  res <- normalize_stage1_facts_zt(pj)
  zt_total <- zt_total + res$n_corrected
  entry <- list(geo_accession = as.character(rec$record_id)[[1]],
                sample_facts = res$facts)
  cur <- if (exists(sid, envir = by_series, inherits = FALSE)) {
    get(sid, envir = by_series)
  } else list()
  cur[[length(cur) + 1L]] <- entry
  assign(sid, cur, envir = by_series)
}
rm(preds); invisible(gc())
cat(sprintf("Guard is_zero_timepoint: %d flag corretti\n", zt_total))
cat(sprintf("Scartati (series_id mancante/non-canonico): %d\n", n_drop))

sids <- ls(by_series)
cat("Studi:", length(sids), "\n")

# unbox helper per scalari
ub <- jsonlite::unbox

output_buf <- character(0)
n_records <- 0L; n_chunked_studies <- 0L; n_chunk_records <- 0L
total_members <- 0L; total_input <- 0L
chunk_log <- list()

for (sid in sids) {
  samples <- get(sid, envir = by_series)
  total_input <- total_input + length(samples)
  conds <- .build_study_conditions(samples)
  # check copertura: union member == campioni input dello studio
  total_members <- total_members + length(unique(unlist(
    lapply(conds, function(c) unlist(c$member_sample_ids)))))
  chunks <- .chunk_conditions(conds, budget_chars = BUDGET_CHARS)
  nchunks <- length(chunks)
  # broadcast reale = condizioni presenti in >1 chunk (onesto vs euristica)
  all_ids <- unlist(lapply(chunks, function(ch)
    vapply(ch, function(cnd) cnd$condition_id, character(1))))
  tab <- table(all_ids)
  bcast <- names(tab)[tab > 1L]

  for (k in seq_len(nchunks)) {
    ch <- chunks[[k]]
    samp <- lapply(ch, function(cnd) list(
      geo_accession     = ub(cnd$geo_accession),
      sample_facts      = cnd$sample_facts,
      n_replicates      = ub(as.integer(cnd$n_replicates)),
      member_sample_ids = unlist(cnd$member_sample_ids),
      condition_id      = ub(cnd$condition_id)
    ))
    if (nchunks == 1L) {
      rid <- sid; cmeta <- NULL
    } else {
      rid <- paste0(sid, "#", k, "of", nchunks)
      cmeta <- list(part = ub(k), total_parts = ub(nchunks),
                    original_record_key = ub(sid),
                    broadcast_condition_ids = as.character(bcast))
    }
    rec <- list(record_id = ub(rid), series_id = ub(sid),
                study_summary = ub(""), samples = samp)
    if (!is.null(cmeta)) rec$chunk_metadata <- cmeta
    n_records <- n_records + 1L
    output_buf[n_records] <- as.character(
      jsonlite::toJSON(rec, auto_unbox = FALSE, null = "null", na = "null"))
    n_chunk_records <- n_chunk_records + (nchunks > 1L)
  }
  if (nchunks > 1L) {
    n_chunked_studies <- n_chunked_studies + 1L
    chunk_log[[length(chunk_log) + 1L]] <- list(
      key = sid, n_cond = length(conds), n_sample = length(samples),
      parts = nchunks)
  }
}

writeLines(output_buf, OUT_JSONL)

cat("\n=== Done ===\n")
cat("Output:            ", OUT_JSONL, "\n")
cat("Record totali:     ", n_records, "\n")
cat("Studi chunkati:    ", n_chunked_studies,
    sprintf("(%d record chunk)\n", n_chunk_records))
cat("Studi 1-record:    ", length(sids) - n_chunked_studies, "\n")

# Sanity: copertura campioni (no sample perso)
cat(sprintf("\nCopertura: %d campioni input -> %d membri distinti (atteso uguale)\n",
            total_input, total_members))
stopifnot(total_members == total_input)
cat("OK -- nessun campione perso nelle condizioni\n")

if (length(chunk_log)) {
  cat("\nTop 10 studi piu' chunkati:\n")
  df <- do.call(rbind, lapply(chunk_log, function(x) data.frame(
    key = x$key, n_cond = x$n_cond, n_sample = x$n_sample, parts = x$parts)))
  print(head(df[order(-df$parts), ], 10), row.names = FALSE)
}
