#!/usr/bin/env Rscript
# p4-fase-f4-stage2-conditions-measure.R --- RED ALERT FASE F4 opzione C.
#
# Misura, sul master Stadio 1 F2 (508.037 record), la distribuzione del numero
# di CONDIZIONI di disegno distinte per studio (deduplica via design_signature)
# e la dimensione stimata dell'input LLM per studio, per fissare empiricamente
# la soglia della coda D2 (ADR-0020) rispetto al budget contesto 32k token (XL).
#
# NON scrive l'input v3: solo conta + report. Lettura streaming a basso uso di
# memoria (tiene per condizione solo contatori, non i facts).
#
# CONFIG via env var:
#   STAGE1_PREDS_PATH  default = master F2 rescued
#   BATCH              righe per batch (default 5000)

suppressPackageStartupMessages({
  library(jsonlite)
})
suppressMessages(pkgload::load_all(".", quiet = TRUE))

STAGE1_PREDS_PATH <- Sys.getenv(
  "STAGE1_PREDS_PATH",
  unset = "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl")
stopifnot(file.exists(STAGE1_PREDS_PATH))
BATCH <- as.integer(Sys.getenv("BATCH", unset = "5000"))

# token ~ chars / 3.5 (JSON denso); budget XL = 32768, riserva ~6k per system
# prompt + schema structured output + budget di generazione.
CHARS_PER_TOKEN <- 3.5

# Accumulatori O(1) via environment.
seen_cond     <- new.env(parent = emptyenv())  # key sid\1sig -> TRUE (dedup)
cond_count    <- new.env(parent = emptyenv())  # sid -> n condizioni distinte
sample_count  <- new.env(parent = emptyenv())  # sid -> n campioni
char_sum      <- new.env(parent = emptyenv())  # sid -> somma nchar facts PIENI condizioni
char_sum_cpt  <- new.env(parent = emptyenv())  # sid -> somma nchar facts COMPATTI (firma)

.bump <- function(env, key, by) {
  cur <- if (exists(key, envir = env, inherits = FALSE)) get(key, envir = env) else 0
  assign(key, cur + by, envir = env)
}

con <- file(STAGE1_PREDS_PATH, "r")
n_seen <- 0L; n_valid <- 0L; n_skip <- 0L; t0 <- Sys.time()
repeat {
  lines <- readLines(con, n = BATCH, warn = FALSE)
  if (length(lines) == 0L) break
  for (l in lines) {
    n_seen <- n_seen + 1L
    rec <- tryCatch(jsonlite::fromJSON(l, simplifyVector = FALSE),
                    error = function(e) NULL)
    if (is.null(rec) || !isTRUE(rec$valid_schema)) { n_skip <- n_skip + 1L; next }
    pj <- rec$parsed_json
    sid <- if (is.null(pj$series_id)) NA_character_ else as.character(pj$series_id)[[1]]
    if (is.na(sid) || !grepl("^GSE[0-9]+$", sid)) { n_skip <- n_skip + 1L; next }
    # guard is_zero_timepoint PRIMA della firma
    pj <- normalize_stage1_facts_zt(pj)$facts
    sig <- design_signature(pj)
    n_valid <- n_valid + 1L
    .bump(sample_count, sid, 1L)
    ck <- paste0(sid, "\1", sig)
    if (!exists(ck, envir = seen_cond, inherits = FALSE)) {
      assign(ck, TRUE, envir = seen_cond)
      .bump(cond_count, sid, 1L)
      .bump(char_sum, sid, nchar(jsonlite::toJSON(pj, auto_unbox = TRUE, null = "null")))
      .bump(char_sum_cpt, sid, nchar(sig))
    }
  }
  if (n_seen %% 50000L < BATCH) {
    cat(sprintf("  ...%d letti, %d validi, %.1f min\n", n_seen, n_valid,
                as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  }
}
close(con)

sids <- ls(cond_count)
nc <- vapply(sids, function(s) get(s, envir = cond_count), numeric(1))
ns <- vapply(sids, function(s) get(s, envir = sample_count), numeric(1))
cs <- vapply(sids, function(s) get(s, envir = char_sum), numeric(1))
cc <- vapply(sids, function(s) get(s, envir = char_sum_cpt), numeric(1))
est_tok <- cs / CHARS_PER_TOKEN
est_tok_cpt <- cc / CHARS_PER_TOKEN

cat("\n========== RISULTATI ==========\n")
cat(sprintf("Record letti: %d | validi: %d | scartati: %d\n", n_seen, n_valid, n_skip))
cat(sprintf("Studi: %d | condizioni totali: %d | campioni totali: %d\n",
            length(sids), sum(nc), sum(ns)))
cat(sprintf("Compressione media: %.1f campioni/condizione\n", sum(ns) / sum(nc)))

cat("\n-- condizioni per studio --\n")
print(round(quantile(nc, c(.5, .75, .9, .95, .99, .999, 1)), 1))
for (thr in c(50, 100, 200, 400)) {
  cat(sprintf("  studi con > %d condizioni: %d (%.3f%%)\n",
              thr, sum(nc > thr), 100 * mean(nc > thr)))
}

cat("\n-- token stimati input/studio, FACTS PIENI (chars/3.5) --\n")
print(round(quantile(est_tok, c(.5, .9, .99, .999, 1))))
for (thr in c(20000, 24000, 26000, 28000)) {
  cat(sprintf("  studi con > %d token (facts pieni): %d (%.3f%%)\n",
              thr, sum(est_tok > thr), 100 * mean(est_tok > thr)))
}

cat("\n-- token stimati input/studio, FACTS COMPATTI ~ firma (chars/3.5) --\n")
print(round(quantile(est_tok_cpt, c(.5, .9, .99, .999, 1))))
for (thr in c(20000, 24000, 26000, 28000)) {
  cat(sprintf("  studi con > %d token (facts compatti): %d (%.3f%%)\n",
              thr, sum(est_tok_cpt > thr), 100 * mean(est_tok_cpt > thr)))
}

cat("\n-- studi-coda (top 15 per condizioni) --\n")
ord <- order(nc, decreasing = TRUE)[seq_len(min(15, length(sids)))]
for (i in ord) {
  cat(sprintf("  %s: %d condizioni, %d campioni, ~%d token\n",
              sids[i], nc[i], ns[i], round(est_tok[i])))
}

saveRDS(list(sid = sids, n_cond = nc, n_sample = ns,
             char_sum = cs, char_sum_compact = cc),
        "analysis/p4-output/p4-fase-f4-conditions-measure.rds")
cat("\nCache misura -> analysis/p4-output/p4-fase-f4-conditions-measure.rds\n")
