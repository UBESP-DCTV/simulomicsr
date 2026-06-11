#!/usr/bin/env Rscript
# p4-fase-f4-stage2-rescue-build-v3.R --- RED ALERT FASE F4 opzione C: build input
# di RESCUE per i fail-schema da troncamento output del fullrun Stadio 2 v3 (24022).
#
# I 19 fail erano: 17 troncamenti (output LLM oltre i 32768 token del tier XL su
# chunk a 42-64 condizioni) + 2 whitespace-flood. Questo script ricostruisce SOLO
# gli studi colpiti dal master Stadio 1, con lo stesso percorso canonico
# (.build_study_conditions + .chunk_conditions) ma applicando il tetto
# max_treated_per_chunk (commit e1dec27) cosi' ogni chunk produce meno confronti e
# l'output sta sotto il tetto token. GSE134595 (multi_arm, 9 condizioni) e i 2
# flood restano 1 record (sotto il tetto): il loro fix e' al submit (token-bump /
# rep_pen), non il re-split.
#
# Output: JSONL con lo STESSO schema dell'input v3 (1+ record/studio), gitignored.
#
# CONFIG via env var:
#   STAGE1_PREDS_PATH  default = master F2 rescued
#   OUT_JSONL          default = analysis/input/archs4-human-stage2-rescue-v3.jsonl
#   BUDGET_CHARS       default 80000 (invariato vs build principale)
#   MAX_TREATED        tetto condizioni trattate/chunk (default 20)

suppressPackageStartupMessages({ library(jsonlite) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))

STAGE1_PREDS_PATH <- Sys.getenv(
  "STAGE1_PREDS_PATH",
  unset = "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl")
stopifnot(file.exists(STAGE1_PREDS_PATH))
OUT_JSONL    <- Sys.getenv("OUT_JSONL",
                           unset = "analysis/input/archs4-human-stage2-rescue-v3.jsonl")
BUDGET_CHARS <- as.integer(Sys.getenv("BUDGET_CHARS", unset = "80000"))
MAX_TREATED  <- as.integer(Sys.getenv("MAX_TREATED",  unset = "20"))
BROADCAST_MAX_FRAC <- as.numeric(Sys.getenv("BROADCAST_MAX_FRAC", unset = "0.3"))

# Studi colpiti dai 19 fail-schema (series_id distinte). Re-split per i grandi,
# 1 record per GSE134595 (multi_arm) e per i 2 flood — il tetto li lascia interi.
AFFECTED <- c("GSE249377", "GSE162694", "GSE186121", "GSE193677", "GSE93511",
              "GSE179609", "GSE263557", "GSE134595", "GSE235391", "GSE246587")

cat(sprintf("Config: BUDGET_CHARS=%d  MAX_TREATED=%d  studi=%d\n",
            BUDGET_CHARS, MAX_TREATED, length(AFFECTED)))
dir.create(dirname(OUT_JSONL), recursive = TRUE, showWarnings = FALSE)

# --- raccogli i campioni Stadio 1 dei soli studi colpiti (stream + filtro) ---
affected_set <- new.env(parent = emptyenv())
for (s in AFFECTED) assign(s, TRUE, envir = affected_set)
by_series <- new.env(parent = emptyenv())
zt_total <- 0L; n_scan <- 0L

con <- file(STAGE1_PREDS_PATH, "r")
repeat {
  ln <- readLines(con, n = 20000L)
  if (length(ln) == 0L) break
  n_scan <- n_scan + length(ln)
  for (line in ln) {
    rec <- jsonlite::fromJSON(line, simplifyVector = FALSE)
    pj <- rec$parsed_json
    if (is.null(pj)) next
    sid <- if (is.null(pj$series_id)) NA_character_ else as.character(pj$series_id)[[1]]
    if (is.na(sid) || !exists(sid, envir = affected_set, inherits = FALSE)) next
    res <- normalize_stage1_facts_zt(pj)
    zt_total <- zt_total + res$n_corrected
    entry <- list(geo_accession = as.character(rec$record_id)[[1]],
                  sample_facts = res$facts)
    cur <- if (exists(sid, envir = by_series, inherits = FALSE))
      get(sid, envir = by_series) else list()
    cur[[length(cur) + 1L]] <- entry
    assign(sid, cur, envir = by_series)
  }
}
close(con)
cat(sprintf("Scansionati %d record Stadio 1; guard is_zero_timepoint: %d flag corretti\n",
            n_scan, zt_total))

found <- ls(by_series)
missing <- setdiff(AFFECTED, found)
if (length(missing)) stop("Studi attesi non trovati nel master: ",
                          paste(missing, collapse = ", "))

ub <- jsonlite::unbox
output_buf <- character(0)
n_records <- 0L
log_rows <- list()

for (sid in AFFECTED) {
  samples <- get(sid, envir = by_series)
  conds <- .build_study_conditions(samples)
  chunks <- .chunk_conditions(conds, budget_chars = BUDGET_CHARS,
                              broadcast_max_frac = BROADCAST_MAX_FRAC,
                              max_treated_per_chunk = MAX_TREATED)
  nchunks <- length(chunks)
  all_ids <- unlist(lapply(chunks, function(ch)
    vapply(ch, function(cnd) cnd$condition_id, character(1))))
  bcast <- names(which(table(all_ids) > 1L))

  # copertura per-studio: union member == campioni input
  memb_union <- length(unique(unlist(lapply(conds, function(c)
    unlist(c$member_sample_ids)))))
  if (memb_union != length(samples))
    stop(sprintf("%s: copertura rotta (%d membri vs %d campioni)",
                 sid, memb_union, length(samples)))

  for (k in seq_len(nchunks)) {
    ch <- chunks[[k]]
    samp <- lapply(ch, function(cnd) list(
      geo_accession     = ub(cnd$geo_accession),
      sample_facts      = cnd$sample_facts,
      n_replicates      = ub(as.integer(cnd$n_replicates)),
      member_sample_ids = unlist(cnd$member_sample_ids),
      condition_id      = ub(cnd$condition_id)
    ))
    if (nchunks == 1L) { rid <- sid; cmeta <- NULL } else {
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
  }
  log_rows[[length(log_rows) + 1L]] <- data.frame(
    series = sid, n_sample = length(samples), n_cond = length(conds),
    chunks = nchunks)
}

writeLines(output_buf, OUT_JSONL)

cat("\n=== Done ===\n")
cat("Output:        ", OUT_JSONL, "\n")
cat("Record totali: ", n_records, "\n\n")
print(do.call(rbind, log_rows), row.names = FALSE)
