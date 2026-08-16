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
#   STAGE1_INPUT_PATH  default = input Stadio 1 v2 (AUTORITA' su series_id)
#   OUT_JSONL          default = analysis/input/archs4-human-stage2-input-v3.jsonl
#   BUDGET_CHARS       tetto caratteri input/record (default 80000, ~23k token)
#
# ⚠️ CORRETTO 2026-08-16 — DA DOVE VIENE `series_id`.
# Fino a oggi la chiave di raggruppamento degli studi era `parsed_json$series_id`,
# cioe' la sigla RI-EMESSA DAL MODELLO. La guardia `^GSE[0-9]+$` non se ne
# accorge, perche' una sigla alterata resta sintatticamente valida. Misurato sui
# 508.037 record del master: 3 record alterati (GSE91395 -> GSE9135), uno studio
# fantasma da 3 campioni. Impatto su v16b: ZERO (ne' GSE91395 ne' GSE9135
# toccano i 1.123 studi poolati). Ma in un run nuovo il modello altera sigle
# DIVERSE, e nulla lo intercetta: se colpisce uno studio del deliverable, quello
# studio si spezza in silenzio.
# Ora la sigla viene dall'INPUT, che e' deterministico. Le divergenze non si
# perdono: si contano e si scrivono in <OUT_JSONL>.series-divergenti.csv.

suppressPackageStartupMessages({ library(jsonlite) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))

STAGE1_PREDS_PATH <- Sys.getenv(
  "STAGE1_PREDS_PATH",
  unset = "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl")
stopifnot(file.exists(STAGE1_PREDS_PATH))
STAGE1_INPUT_PATH <- Sys.getenv(
  "STAGE1_INPUT_PATH",
  unset = "analysis/input/archs4-human-stage1-input-v2.jsonl")
stopifnot(file.exists(STAGE1_INPUT_PATH))
OUT_JSONL <- Sys.getenv(
  "OUT_JSONL", unset = "analysis/input/archs4-human-stage2-input-v3.jsonl")
BUDGET_CHARS <- as.integer(Sys.getenv("BUDGET_CHARS", unset = "80000"))
BROADCAST_MAX_FRAC <- as.numeric(Sys.getenv("BROADCAST_MAX_FRAC", unset = "0.3"))
dir.create(dirname(OUT_JSONL), recursive = TRUE, showWarnings = FALSE)
cat(sprintf("Config: BUDGET_CHARS=%d  BROADCAST_MAX_FRAC=%.2f\n",
            BUDGET_CHARS, BROADCAST_MAX_FRAC))

# --- AUTORITA' su series_id: l'input, non l'output del modello ---------------
cat("Loading", STAGE1_INPUT_PATH, "(autorita' su series_id) ...\n")
in_lines <- readLines(STAGE1_INPUT_PATH, warn = FALSE)
in_rid <- sub('^.*"record_id":"([^"]+)".*$', "\\1", in_lines)
in_sid <- sub('^.*"series_id":"([^"]+)".*$', "\\1", in_lines)
# Se una sostituzione non ha morso, il campo manca: non si tira a indovinare.
if (any(in_rid == in_lines) || any(in_sid == in_lines))
  stop("Input Stadio 1: record_id o series_id assenti in almeno una riga.")
series_by_gsm <- new.env(parent = emptyenv(), size = length(in_rid))
for (i in seq_along(in_rid)) assign(in_rid[[i]], in_sid[[i]], envir = series_by_gsm)
rm(in_lines); invisible(gc())
cat(sprintf("Input Stadio 1: %d record, %d studi distinti\n",
            length(in_rid), length(unique(in_sid))))

cat("Loading", STAGE1_PREDS_PATH, "...\n")
preds <- jsonlite::stream_in(file(STAGE1_PREDS_PATH), verbose = FALSE,
                             simplifyVector = FALSE)
cat("Loaded", length(preds), "stage1 predictions\n")

# Guard is_zero_timepoint + raggruppamento per series_id (dall'INPUT).
by_series <- new.env(parent = emptyenv())
n_drop <- 0L; zt_total <- 0L; n_orfani <- 0L
div_gsm <- character(0); div_in <- character(0); div_out <- character(0)
for (rec in preds) {
  pj <- rec$parsed_json
  if (is.null(pj)) { n_drop <- n_drop + 1L; next }
  gsm <- as.character(rec$record_id)[[1]]
  # La sigla vera viene dall'input. Un record del master assente dall'input non
  # e' un dato con un difetto: e' un record che non sappiamo da dove venga.
  if (!exists(gsm, envir = series_by_gsm, inherits = FALSE)) {
    n_orfani <- n_orfani + 1L; n_drop <- n_drop + 1L; next
  }
  sid <- get(gsm, envir = series_by_gsm, inherits = FALSE)
  sid_llm <- if (is.null(pj$series_id)) NA_character_ else as.character(pj$series_id)[[1]]
  if (is.na(sid_llm) || !identical(sid_llm, sid)) {
    div_gsm <- c(div_gsm, gsm); div_in <- c(div_in, sid)
    div_out <- c(div_out, if (is.na(sid_llm)) "<assente>" else sid_llm)
  }
  if (!grepl("^GSE[0-9]+$", sid)) { n_drop <- n_drop + 1L; next }
  res <- normalize_stage1_facts_zt(pj)
  zt_total <- zt_total + res$n_corrected
  entry <- list(geo_accession = gsm, sample_facts = res$facts)
  cur <- if (exists(sid, envir = by_series, inherits = FALSE)) {
    get(sid, envir = by_series)
  } else list()
  cur[[length(cur) + 1L]] <- entry
  assign(sid, cur, envir = by_series)
}
rm(preds); invisible(gc())
cat(sprintf("Guard is_zero_timepoint: %d flag corretti\n", zt_total))
cat(sprintf("Scartati (series_id mancante/non-canonico): %d\n", n_drop))
if (n_orfani > 0L)
  cat(sprintf("  di cui ORFANI (nel master, assenti dall'input): %d\n", n_orfani))

cat(sprintf("series_id alterato dal modello: %d record (%.4f%%) su %d studi\n",
            length(div_gsm), 100 * length(div_gsm) / max(1L, length(in_rid)),
            length(unique(div_in))))
if (length(div_gsm) > 0L) {
  div_path <- paste0(OUT_JSONL, ".series-divergenti.csv")
  utils::write.csv(data.frame(gsm = div_gsm, series_input = div_in,
                              series_modello = div_out),
                   div_path, row.names = FALSE)
  cat("  registro:", div_path, "\n")
}

sids <- ls(by_series)
cat("Studi:", length(sids), "\n")

# CASO DI ACCETTAZIONE (negativo): nessuno studio prodotto qui puo' essere
# assente dall'input. Se accade, il raggruppamento sta di nuovo seguendo il
# modello e non l'input, ed e' un errore fatale, non un avviso.
fantasmi <- setdiff(sids, unique(in_sid))
if (length(fantasmi) > 0L)
  stop(sprintf("Studi FANTASMA assenti dall'input Stadio 1: %d (%s)",
               length(fantasmi), paste(utils::head(fantasmi, 5), collapse = ", ")))
cat(sprintf("[OK] nessuno studio fantasma (tutti e %d presenti nell'input)\n",
            length(sids)))

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
  chunks <- .chunk_conditions(conds, budget_chars = BUDGET_CHARS,
                              broadcast_max_frac = BROADCAST_MAX_FRAC)
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
