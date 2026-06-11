#!/usr/bin/env Rscript
# p4-fase-f4-stage2-collect-v3.R --- RED ALERT FASE F4 opzione C: assembla il
# MASTER Stadio 2 v3 (1 record/studio) da fullrun (24022) + rescue (24222).
#
# Per ogni studio:
#   - studi colpiti dai 19 fail (re-chunkati nel rescue, partizionamento diverso):
#     usa interamente input + predizioni del RESCUE (scarta tutti i loro record del
#     fullrun, anche i chunk riusciti, perche' appartengono a un partizionamento
#     incoerente con quello nuovo).
#   - tutti gli altri studi: input v3 originale + predizioni del fullrun.
# Poi .assemble_stage2_study per series: fonde i chunk (.merge_chunked_designs) +
# espande rappresentante->membri (.expand_study_design) -> UN record per studio.
#
# Output: master JSONL (1 riga = study_design assemblato, schema stage2.v2),
# gitignored. Sanity: 1 record/series (guard fail-loud), copertura campioni.
#
# CONFIG via env var (default = deliverable di questa sessione):
#   INPUT_V3       input v3 originale
#   RESCUE_INPUT   input rescue (re-chunkato)
#   FULLRUN_COLLECT  RDS collect fullrun
#   RESCUE_COLLECT   RDS collect rescue
#   OUT_MASTER     master JSONL

suppressPackageStartupMessages({ library(jsonlite) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))

INPUT_V3        <- Sys.getenv("INPUT_V3",      unset = "analysis/input/archs4-human-stage2-input-v3.jsonl")
RESCUE_INPUT    <- Sys.getenv("RESCUE_INPUT",  unset = "analysis/input/archs4-human-stage2-rescue-v3.jsonl")
FULLRUN_COLLECT <- Sys.getenv("FULLRUN_COLLECT", unset = "analysis/p4-output/p4-f4-stage2-fullrun-v3-collect.rds")
RESCUE_COLLECT  <- Sys.getenv("RESCUE_COLLECT",  unset = "analysis/p4-output/p4-f4-stage2-rescue-v3-collect.rds")
OUT_MASTER      <- Sys.getenv("OUT_MASTER",   unset = "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
for (p in c(INPUT_V3, RESCUE_INPUT, FULLRUN_COLLECT, RESCUE_COLLECT)) stopifnot(file.exists(p))

asm <- simulomicsr:::.assemble_stage2_study
`%||%` <- function(a, b) if (is.null(a)) b else a

# --- predizioni: record_id -> parsed_json (solo validi) ---
build_llm_lookup <- function(collect_rds) {
  res <- readRDS(collect_rds)
  pr  <- res$predictions
  lk <- list()
  for (i in seq_len(nrow(pr))) {
    pj <- pr$parsed_json[[i]]
    if (!is.null(pj)) lk[[as.character(pr$record_id[[i]])]] <- pj
  }
  lk
}
cat("Carico predizioni fullrun...\n");  llm_full   <- build_llm_lookup(FULLRUN_COLLECT)
cat("Carico predizioni rescue...\n");   llm_rescue <- build_llm_lookup(RESCUE_COLLECT)
cat(sprintf("Predizioni valide: fullrun=%d  rescue=%d\n", length(llm_full), length(llm_rescue)))

# --- studi colpiti (data-driven dall'input rescue) ---
rescue_in <- lapply(readLines(RESCUE_INPUT, warn = FALSE), fromJSON, simplifyVector = FALSE)
AFFECTED <- unique(vapply(rescue_in, function(r) as.character(r$series_id)[[1]], character(1)))
cat(sprintf("Studi colpiti (rescue): %d -> %s\n", length(AFFECTED), paste(AFFECTED, collapse = ", ")))

# --- input records per series: originale (studi non colpiti) + rescue (colpiti) ---
in_by_series <- new.env(parent = emptyenv())
push <- function(sid, rec) {
  cur <- if (exists(sid, envir = in_by_series, inherits = FALSE)) get(sid, envir = in_by_series) else list()
  cur[[length(cur) + 1L]] <- rec
  assign(sid, cur, envir = in_by_series)
}
con <- file(INPUT_V3, "r"); n_skip <- 0L; n_keep <- 0L
repeat {
  ln <- readLines(con, n = 20000L)
  if (length(ln) == 0L) break
  for (line in ln) {
    rec <- fromJSON(line, simplifyVector = FALSE)
    sid <- as.character(rec$series_id)[[1]]
    if (sid %in% AFFECTED) { n_skip <- n_skip + 1L; next }  # rimpiazzato dal rescue
    push(sid, rec); n_keep <- n_keep + 1L
  }
}
close(con)
for (rec in rescue_in) push(as.character(rec$series_id)[[1]], rec)
cat(sprintf("Input v3: %d record tenuti, %d scartati (studi colpiti) + %d record rescue\n",
            n_keep, n_skip, length(rescue_in)))

# --- predizioni unite: rescue ha priorita' (chiavi disgiunte comunque) ---
llm_all <- modifyList(llm_full, llm_rescue)

# --- assembly per series ---
sids <- ls(in_by_series)
cat(sprintf("Assemblo %d studi...\n", length(sids)))
master <- list(); n_null <- 0L
for (sid in sids) {
  d <- asm(get(sid, envir = in_by_series), llm_all)
  if (is.null(d)) { n_null <- n_null + 1L; next }
  master[[length(master) + 1L]] <- d
}
cat(sprintf("Studi assemblati: %d  (null/senza-predizione: %d)\n", length(master), n_null))

# --- sanity: 1 record per series (guard fail-loud) ---
master <- simulomicsr:::.assert_stage2_one_record_per_series(master)
master_sids <- vapply(master, function(s) as.character(s$series_id)[[1]], character(1))
cat(sprintf("Guard one-record-per-series: OK (%d series distinte)\n", length(unique(master_sids))))

# --- sanity: copertura campioni (union sample_ids nei replicate_groups) ---
cov <- unique(unlist(lapply(master, function(d)
  unlist(lapply(d$replicate_groups %||% list(), function(rg) as.character(unlist(rg$sample_ids)))))))
cat(sprintf("Campioni coperti dai replicate_groups (union): %d\n", length(cov)))

# --- scrittura master JSONL (1 riga = study_design) ---
con <- file(OUT_MASTER, "w")
for (d in master) writeLines(toJSON(d, auto_unbox = TRUE, null = "null", na = "null"), con)
close(con)
cat(sprintf("\n=== Done ===\nMaster: %s\nStudi: %d\n", OUT_MASTER, length(master)))
