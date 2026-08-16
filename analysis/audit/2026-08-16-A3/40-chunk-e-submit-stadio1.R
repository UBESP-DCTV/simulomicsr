#!/usr/bin/env Rscript
# =============================================================================
# A3 — Stadio 1: taglio in blocchi e sottomissione (GATED: tocca il DGX)
#
# Stesso trattamento di F2 (`p4-fase-f2-stage1-chunk-build.R`): shuffle
# deterministico, outlier `nchar > 3500` a parte, blocchi da 10.000. Non e' un
# vezzo: il runtime manda l'intero shard in una chiamata sola, quindi la
# dimensione del blocco decide la composizione del batch. Tenere il taglio di
# produzione e' cio' che rende A3 confrontabile col re-run completo.
#
# Uso:
#   DRY_RUN=1 Rscript .../40-chunk-e-submit-stadio1.R    # prepara e si ferma
#   Rscript .../40-chunk-e-submit-stadio1.R              # prepara e SOTTOMETTE
# =============================================================================

suppressPackageStartupMessages({ library(jsonlite); library(fs) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))

INPUT      <- Sys.getenv("A3_INPUT", "analysis/input/A3-stage1-input.jsonl")
SHUFFLED   <- Sys.getenv("A3_SHUFFLED", "analysis/input/A3-stage1-input-shuffled.jsonl")
OUTLIERS   <- Sys.getenv("A3_OUTLIERS", "analysis/input/A3-stage1-outliers.jsonl")
CHUNKS_DIR <- Sys.getenv("A3_CHUNKS", "analysis/input/A3-chunks")
CHUNK_SIZE <- as.integer(Sys.getenv("CHUNK_SIZE", "10000"))
NCHAR_MAX  <- 3500L
DRY        <- nzchar(Sys.getenv("DRY_RUN"))
stopifnot(file.exists(INPUT))

# === 1. shuffle deterministico, stesso seme di F2 ===========================
if (!file.exists(SHUFFLED)) {
  rc <- system2("bash", c("-c", shQuote(sprintf(
    "shuf --random-source=<(yes 42) %s > %s", shQuote(INPUT), shQuote(SHUFFLED)))))
  if (rc != 0L) stop("shuf fallito (rc=", rc, ")")
}
raw <- readLines(SHUFFLED, warn = FALSE)
cat(sprintf("record: %d\n", length(raw)))

df <- jsonlite::stream_in(file(SHUFFLED), verbose = FALSE)
stopifnot(nrow(df) == length(raw), "string" %in% names(df))
nc <- nchar(df$string)
idx_out <- which(nc > NCHAR_MAX)
cat(sprintf("outlier nchar>%d: %d\n", NCHAR_MAX, length(idx_out)))

# === 2. scrittura =========================================================
fs::dir_create(CHUNKS_DIR, recurse = TRUE)
if (length(idx_out) > 0L) writeLines(raw[idx_out], OUTLIERS)
main <- if (length(idx_out) > 0L) raw[-idx_out] else raw
n_chunks <- ceiling(length(main) / CHUNK_SIZE)
for (i in seq_len(n_chunks)) {
  lo <- (i - 1L) * CHUNK_SIZE + 1L; hi <- min(i * CHUNK_SIZE, length(main))
  writeLines(main[lo:hi], fs::path(CHUNKS_DIR, sprintf("chunk-%02d.jsonl", i - 1L)))
}
cat(sprintf("blocchi: %d da %d (ultimo %d) in %s\n",
            n_chunks, CHUNK_SIZE, length(main) - (n_chunks - 1L) * CHUNK_SIZE, CHUNKS_DIR))

# === 3. casi di accettazione ==============================================
cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(n, e, d) { cat(sprintf("  [%s] %-52s %s\n", if (isTRUE(e)) "OK" else "FALLITO", n, d)); if (!isTRUE(e)) ok <<- FALSE }
riletti <- unlist(lapply(fs::dir_ls(CHUNKS_DIR, glob = "*.jsonl"), readLines, warn = FALSE),
                  use.names = FALSE)
if (length(idx_out) > 0L) riletti <- c(riletti, readLines(OUTLIERS, warn = FALSE))
chk("positivo: nessun record perso nel taglio",
    length(riletti) == length(raw), sprintf("%d == %d", length(riletti), length(raw)))
chk("negativo: nessun record duplicato",
    !anyDuplicated(riletti), sprintf("%d duplicati", sum(duplicated(riletti))))
chk("negativo: i blocchi sono righe dell'input, non righe nuove",
    all(riletti %in% raw), sprintf("%d estranee", sum(!riletti %in% raw)))
if (!ok) stop("CASI DI ACCETTAZIONE FALLITI: non sottometto.")

if (DRY) { cat("\nDRY_RUN: mi fermo prima di sottomettere.\n"); quit(save = "no") }

# === 4. sottomissione =====================================================
cfg <- dgx_config()
paths <- c(as.character(fs::dir_ls(CHUNKS_DIR, glob = "*.jsonl")),
           if (length(idx_out) > 0L) OUTLIERS else NULL)
cat("\n== sottomissione ==\n")
jobs <- list()
for (p in paths) {
  slug <- paste0("a3-s1-", sub("[.]jsonl$", "", basename(p)))
  b <- dgx_p4_build_bundle(p, stage = "stage1", config = cfg,
                           metadata = list(slug = slug))
  j <- dgx_p4_submit(b, time = "12:00:00", env = c(VLLM_BATCH_INVARIANT = "1"))
  cat(sprintf("  %-22s slurm=%s  run_id=%s\n", slug, j$slurm_job_id, j$run_id))
  jobs[[slug]] <- j
}
saveRDS(jobs, "analysis/audit/2026-08-16-A3/jobs-stadio1.rds")
cat("\nslurm:", paste(vapply(jobs, function(j) j$slurm_job_id, character(1)), collapse = ","), "\n")
