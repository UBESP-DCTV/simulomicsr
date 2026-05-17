#!/usr/bin/env Rscript
# p4-beta-rescue-h2-cleanup.R --- H2 v2: drop GSE-level dei 72 studi mouse-
# labeled-as-human in ARCHS4 v2.5 upstream (Opzione 1 user 2026-05-17).
#
# Scope esteso rispetto a v1 (749 GSM fails only): include 8.398 sample
# addizionali da 72 studi dove >=5 sample classificati non-human dall'LLM e
# >=50% del totale per studio. Total drop ~9.147 sample = 1.03% del dataset
# beta. Dettagli del finding (paper-grade): docs/findings/2026-05-17-llm-
# detected-archs4-geo-organism-mislabeling.md.
#
# Discovery generata da scan completo master stage1 per organism breakdown
# per GSE (file `analysis/p4-output/p4-beta-rescue-h2-suspects.rds` salvato
# durante validation fase 2026-05-17). H2 v2 droppa GSE-level (intero studio)
# vs GSM-level di v1.

suppressPackageStartupMessages({
  library(jsonlite)
})

SUSPECTS   <- "/tmp/p4-beta-rescue-h2-suspects.rds"  # 72 GSE da scan organism
SUSPECTS_OUT <- "analysis/p4-output/p4-beta-rescue-h2-suspects.rds"
MASTER_IN  <- "analysis/p4-output/p4-beta-stage1-master-predictions.jsonl"
MASTER_OUT <- "analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl"
STAGE2_IN  <- "analysis/input/archs4-human-stage2-input.jsonl"
STAGE2_OUT <- "analysis/input/archs4-human-stage2-input-cleaned.jsonl"

stopifnot(file.exists(SUSPECTS), file.exists(MASTER_IN), file.exists(STAGE2_IN))

# Snapshot suspects in analysis/p4-output (gitignored) per riproducibilita'
file.copy(SUSPECTS, SUSPECTS_OUT, overwrite = TRUE)

# === Lista 72 GSE da droppare GSE-level (paper-grade finding, Opzione 1) ===
suspects <- readRDS(SUSPECTS)
to_drop_gse <- suspects$series_id
cat(sprintf("Drop GSE-level: %d studi mouse-labeled-as-human (paper-grade finding)\n",
            length(to_drop_gse)))
cat(sprintf("Total samples-in-master attesi (somma su 72 GSE): %d\n",
            sum(suspects$total)))
drop_gse_set <- new.env(hash = TRUE, size = length(to_drop_gse))
for (g in to_drop_gse) drop_gse_set[[g]] <- TRUE

# Per compatibilita' downstream con stage2 fast-path: deriviamo anche la lista
# di GSM-da-droppare via scan del master stage1 (sono i GSM dei 72 GSE).
cat("Pre-scan: building drop-GSM list from 72 suspect GSE...\n")
con_pre <- file(MASTER_IN, "r")
to_drop_gsm <- character(0)
to_drop_gsm_grow <- vector("list", 0L)
while (TRUE) {
  L <- readLines(con_pre, n = 1000L, warn = FALSE)
  if (!length(L)) break
  for (line in L) {
    # Fast-pat per GSE prima di parse pieno
    gse_m <- regmatches(line, regexpr("\"series_id\"\\s*:\\s*\"GSE[0-9]+\"", line))
    if (length(gse_m) == 0L) next
    gse <- sub("\"series_id\"\\s*:\\s*\"(GSE[0-9]+)\"", "\\1", gse_m)
    if (is.null(drop_gse_set[[gse]])) next
    # In suspect: estrai geo_accession
    gsm_m <- regmatches(line, regexpr("\"record_id\"\\s*:\\s*\"GSM[0-9]+\"", line))
    if (length(gsm_m) > 0L) {
      gsm <- sub("\"record_id\"\\s*:\\s*\"(GSM[0-9]+)\"", "\\1", gsm_m)
      to_drop_gsm_grow[[length(to_drop_gsm_grow) + 1L]] <- gsm
    }
  }
}
close(con_pre)
to_drop_gsm <- unlist(to_drop_gsm_grow)
cat(sprintf("Pre-scan done: %d GSM from %d suspect GSE\n",
            length(to_drop_gsm), length(to_drop_gse)))

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
cat(sprintf("Stage1 cleaned: %d -> %d (dropped %d sample da %d GSE)\n",
            n_total, n_kept, n_dropped, length(to_drop_gse)))
# NB: n_dropped puo' essere < length(to_drop_gsm) se il pre-scan ha incluso
# GSM da fail records (parsed_json=NULL) il cui record_id e' presente nel
# master ma series_id viene dal fail-classified.csv (non da parsed_json).
stopifnot(n_dropped >= length(to_drop_gse) * 5L)  # almeno 5 sample per GSE

# === stage2-input cleanup: GSE-level drop (Opzione 1) ===
# Per ogni record stage2: estrai series_id via regex, drop se in suspect GSE.
# Nessun parse JSON necessario (header check su pattern fisso).
cat("Streaming stage2-input (GSE-level drop)...\n")
con_in  <- file(STAGE2_IN, "r")
con_out <- file(STAGE2_OUT, "w")
n_total <- 0L; n_kept <- 0L; n_dropped <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  # Extract series_id from top-level (record_id pattern oppure series_id field)
  gse_m <- regmatches(L, regexpr("\"series_id\"\\s*:\\s*\"GSE[0-9]+\"", L))
  if (length(gse_m) == 0L) {
    # Fallback: pass-through se non parse-able (shouldn't happen)
    writeLines(L, con_out); n_kept <- n_kept + 1L; next
  }
  gse <- sub("\"series_id\"\\s*:\\s*\"(GSE[0-9]+)\"", "\\1", gse_m)
  if (!is.null(drop_gse_set[[gse]])) {
    n_dropped <- n_dropped + 1L
    next
  }
  writeLines(L, con_out)
  n_kept <- n_kept + 1L
  if (n_total %% 5000L == 0L)
    cat(sprintf("...stage2 %d/%d processed (dropped %d)\n",
                n_total, 39205L, n_dropped))
}
close(con_in); close(con_out)
cat(sprintf("Stage2 cleaned: %d records -> %d (dropped %d entire records GSE-level)\n",
            n_total, n_kept, n_dropped))
cat("\n=== Done ===\n")
cat("Outputs:\n")
cat("  ", MASTER_OUT, "\n")
cat("  ", STAGE2_OUT, "\n")
