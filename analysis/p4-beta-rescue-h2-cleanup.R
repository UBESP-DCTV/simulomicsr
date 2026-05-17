#!/usr/bin/env Rscript
# p4-beta-rescue-h2-cleanup.R --- H2: rimuovi ETL leak non-human dal master stage1
# e propaga la pulizia al stage2-input.
#
# I record marcati ETL_LEAK_NONHUMAN da p4-beta-rescue-stage1-fails-classified.csv
# sono sample dove ARCHS4 dichiara organism_ch1="Homo sapiens" ma il metadato
# stringa indica chiaramente non-human (es. GSE86977 mouse Cre-line). Il filtro
# ETL e' corretto data l'input, ma il dato GEO upstream e' wrong. Drop dal
# master stage1 e da stage2-input per evitare contaminazione downstream.

suppressPackageStartupMessages({
  library(jsonlite)
})

CLASSIFIED <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"
MASTER_IN  <- "analysis/p4-output/p4-beta-stage1-master-predictions.jsonl"
MASTER_OUT <- "analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl"
STAGE2_IN  <- "analysis/input/archs4-human-stage2-input.jsonl"
STAGE2_OUT <- "analysis/input/archs4-human-stage2-input-cleaned.jsonl"

stopifnot(file.exists(CLASSIFIED), file.exists(MASTER_IN), file.exists(STAGE2_IN))

df <- read.csv(CLASSIFIED, stringsAsFactors = FALSE)
to_drop_gsm <- df$record_id[df$fail_mode == "ETL_LEAK_NONHUMAN"]
to_drop_gse <- unique(df$series_id[df$fail_mode == "ETL_LEAK_NONHUMAN"])
cat(sprintf("Drop %d GSM (across %d GSE)\n", length(to_drop_gsm), length(to_drop_gse)))

drop_set <- new.env(hash = TRUE, size = length(to_drop_gsm))
for (g in to_drop_gsm) drop_set[[g]] <- TRUE

# === stage1 master cleanup ===
cat("Streaming master stage1...\n")
con_in  <- file(MASTER_IN, "r")
con_out <- file(MASTER_OUT, "w")
n_total <- 0L; n_kept <- 0L; n_dropped <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(drop_set[[rec$record_id]])) {
    n_dropped <- n_dropped + 1L
    next
  }
  writeLines(L, con_out)
  n_kept <- n_kept + 1L
  if (n_total %% 100000L == 0L)
    cat(sprintf("...stage1 %d/%d processed (kept %d)\n", n_total, 888821L, n_kept))
}
close(con_in); close(con_out)
cat(sprintf("Stage1 cleaned: %d -> %d (dropped %d)\n", n_total, n_kept, n_dropped))
stopifnot(n_dropped == length(to_drop_gsm))

# === stage2-input cleanup: fast path -- la stragrande maggioranza dei 39k
# records NON contiene nessun GSM da droppare (i 749 sono concentrati in
# GSE86977 = ~15 record stage2 cs50 + 3 isolated). Per ogni linea: prima
# check via grepl con pattern unico OR-ato. Solo se hit, parse+filter+
# re-serialize. Speedup ~100-1000x vs full JSON roundtrip per record. ===
cat("Streaming stage2-input (fast-path)...\n")
# Pattern OR-ato unico: "(\"GSM1234\"|\"GSM5678\"|...)"
drop_pattern <- paste0("(", paste0("\"", to_drop_gsm, "\"",
                                    collapse = "|"), ")")
con_in  <- file(STAGE2_IN, "r")
con_out <- file(STAGE2_OUT, "w")
n_total <- 0L; n_kept <- 0L; n_dropped_empty <- 0L; n_samples_dropped <- 0L
n_touched <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  if (!grepl(drop_pattern, L, perl = TRUE)) {
    writeLines(L, con_out)
    n_kept <- n_kept + 1L
    if (n_total %% 5000L == 0L)
      cat(sprintf("...stage2 %d/%d processed (touched %d, dropped_empty %d)\n",
                  n_total, 39205L, n_touched, n_dropped_empty))
    next
  }
  # Slow path: parse + filter + re-serialize
  n_touched <- n_touched + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  before <- length(rec$samples)
  rec$samples <- Filter(function(s) is.null(drop_set[[s$geo_accession]]),
                        rec$samples)
  after <- length(rec$samples)
  if (after < before) n_samples_dropped <- n_samples_dropped + (before - after)
  if (after == 0L) {
    n_dropped_empty <- n_dropped_empty + 1L
    next
  }
  out_line <- jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null", na = "null")
  writeLines(as.character(out_line), con_out)
  n_kept <- n_kept + 1L
}
close(con_in); close(con_out)
cat(sprintf("Stage2 fast-path: touched %d / %d records (slow-path)\n",
            n_touched, n_total))
cat(sprintf("Stage2-input cleaned: %d records -> %d (dropped %d empty), %d samples removed\n",
            n_total, n_kept, n_dropped_empty, n_samples_dropped))

cat("\n=== Done ===\n")
cat("Outputs:\n")
cat("  ", MASTER_OUT, "\n")
cat("  ", STAGE2_OUT, "\n")
