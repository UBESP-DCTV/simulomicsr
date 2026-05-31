#!/usr/bin/env Rscript
# p4-fase-f3-rescue-merge.R --- Merge cs25 rescued chunks nel master Stadio 2 v2.
# Logica (da p4-beta-rescue-h3-merge.R): una original_record_key (cs50 fallito)
# e' rescued solo se TUTTE le sue parti cs25 sono valid_schema=TRUE. Il master
# finale = record validi del fullrun + chunk cs25 rescued (per le key recuperate),
# i 36 fail originali rimossi. Output JSONL.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
FULLRUN    <- file.path(OUTPUT_DIR, "20260530T113933Z-f3-stage2-fullrun-33778a/predictions.jsonl")
SLUG_RESC  <- "f3-rescue-stage2"
OUT_MASTER <- file.path(OUTPUT_DIR, "p4-fase-f3-stage2-master-rescued.jsonl")

is_valid <- function(r) isTRUE(r$valid_schema) || !is.null(r$parsed_json)

# --- 1. Collect del job rescue ---
rj_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG_RESC, "-.*-job\\.rds$"), full.names = TRUE)
stopifnot(length(rj_rds) >= 1L)
rjob <- readRDS(rj_rds[which.max(file.info(rj_rds)$mtime)])
dgx_p4_collect(rjob, dest = OUTPUT_DIR)
resc_path <- file.path(OUTPUT_DIR, rjob$run_id, "predictions.jsonl")
stopifnot(file.exists(resc_path))

# --- 2. Fullrun: valid vs fail ---
full <- jsonlite::stream_in(file(FULLRUN), verbose = FALSE, simplifyVector = FALSE)
full_ok   <- Filter(is_valid, full)
full_fail <- Filter(function(r) !is_valid(r), full)
fail_keys <- vapply(full_fail, function(r) as.character(r$record_id), character(1L))
cat(sprintf("Fullrun: %d totali, %d validi, %d fail\n", length(full), length(full_ok), length(full_fail)))

# --- 3. Rescue cs25: raggruppa per original_record_key ---
resc <- jsonlite::stream_in(file(resc_path), verbose = FALSE, simplifyVector = FALSE)
orig_key <- function(rid) sub("--rsc.*", "", rid)
resc_rid   <- vapply(resc, function(r) as.character(r$record_id), character(1L))
resc_okflg <- vapply(resc, is_valid, logical(1L))
resc_key   <- orig_key(resc_rid)
cat(sprintf("Rescue: %d chunk cs25, %d validi, %d invalidi\n",
            length(resc), sum(resc_okflg), sum(!resc_okflg)))

# una key e' fully rescued sse tutte le sue parti sono valide
keys_all     <- unique(resc_key)
keys_invalid <- unique(resc_key[!resc_okflg])
keys_rescued <- setdiff(keys_all, keys_invalid)
cat(sprintf("Original key fully rescued: %d / %d\n", length(keys_rescued), length(fail_keys)))
residual_keys <- setdiff(fail_keys, keys_rescued)
if (length(residual_keys)) {
  cat("RESIDUAL keys (non recuperate):\n"); print(residual_keys)
}

# --- 4. Master = fullrun validi + chunk cs25 delle key rescued ---
resc_keep <- resc[resc_okflg & (resc_key %in% keys_rescued)]
for (i in seq_along(resc_keep)) resc_keep[[i]]$rescue_source <- "h3_cs25_resplit_v2"

# i fullrun validi: rescue_source = NA (non toccati)
master <- c(full_ok, resc_keep)
cat(sprintf("\nMaster Stadio 2 v2: %d record (%d fullrun validi + %d cs25 rescued)\n",
            length(master), length(full_ok), length(resc_keep)))

# --- 5. Scrivi JSONL ---
con <- file(OUT_MASTER, "w")
for (r in master) writeLines(jsonlite::toJSON(r, auto_unbox = TRUE, null = "null", na = "null"), con)
close(con)
cat("Master scritto:", OUT_MASTER, "\n")

# --- 6. Report copertura studi + validita' ---
master_sid <- unique(vapply(master, function(r) {
  s <- r$parsed_json$series_id %||% NA_character_
  if (is.null(s) || length(s)==0L) NA_character_ else as.character(s)[1]
}, character(1L)))
n_resc_ok    <- length(keys_rescued)
n_residual   <- length(residual_keys)
schema_pct   <- 100 * (length(fail_keys) - n_residual + length(full_ok)) /
                (length(full_ok) + length(fail_keys))
cat(sprintf("\n=== ESITO ===\n"))
cat(sprintf("Studi (series_id) nel master: %d\n", length(na.omit(master_sid))))
cat(sprintf("Fail originali: %d | rescued: %d | residual: %d\n",
            length(fail_keys), n_resc_ok, n_residual))
cat(sprintf("Validita' schema Stadio 2 (per-record originale): %.4f%%\n",
            100 * (length(full_ok) + n_resc_ok) / (length(full_ok) + length(fail_keys))))
saveRDS(list(n_master = length(master), n_full_ok = length(full_ok),
             n_rescued_keys = n_resc_ok, residual_keys = residual_keys,
             out_master = OUT_MASTER),
        file.path(OUTPUT_DIR, paste0(rjob$run_id, "-f3-merge.rds")))
cat("\n=== MERGE COMPLETE ===\n")
