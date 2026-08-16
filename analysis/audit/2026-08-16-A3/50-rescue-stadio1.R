#!/usr/bin/env Rscript
# =============================================================================
# A3 — Stadio 1: rescue dei record che hanno fallito lo schema
#
# PERCHE' NON SI PUO' SALTARE. I 197 record non validi tornerebbero nel master
# al posto di record OGGI VALIDI (nel master attuale quegli stessi GSM sono
# stati recuperati dalla cascata di F2). Lo Stadio 2 scarta i record senza
# `parsed_json`: quei campioni sparirebbero. Misurato: i 197 toccano 46 studi,
# **19 dei quali sono fra i 1.123 poolati** nelle 211 meta-analisi. Sarebbe una
# perdita sistematica scambiata per rumore del modello, cioe' proprio la cosa
# che A3 deve misurare.
#
# CONFIGURAZIONE: identica a H1 di F2 (`p4-fase-f2-rescue-h1-stage1.R`),
# rep_pen=1.2 / max_tokens=4096 / max_model_len=8192, piu' la flag. Non si
# cambia una leva mentre se ne misura un'altra.
#
# Uso:
#   Rscript analysis/audit/2026-08-16-A3/50-rescue-stadio1.R
# =============================================================================

suppressPackageStartupMessages({ library(jsonlite); library(fs) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))

PRED  <- Sys.getenv("PRED",  "analysis/p4-output/A3-stage1-predictions.jsonl")
INPUT <- Sys.getenv("A3_INPUT", "analysis/input/A3-stage1-input.jsonl")
RESC  <- Sys.getenv("RESC", "analysis/input/A3-stage1-rescue.jsonl")
DRY   <- nzchar(Sys.getenv("DRY_RUN"))
stopifnot(file.exists(PRED), file.exists(INPUT))

pred <- readLines(PRED, warn = FALSE)
valido <- grepl('"valid_schema": *true', pred)
rid <- sub('^.*"record_id": ?"([^"]+)".*$', "\\1", pred)
da_rifare <- rid[!valido]
cat(sprintf("record: %d, non validi: %d (%.3f%%)\n",
            length(pred), length(da_rifare), 100 * length(da_rifare) / length(pred)))
if (length(da_rifare) == 0L) { cat("nulla da recuperare.\n"); quit(save = "no") }

inp <- readLines(INPUT, warn = FALSE)
inp_rid <- sub('^.*"record_id":"([^"]+)".*$', "\\1", inp)
sel <- inp[inp_rid %in% da_rifare]

cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(n, e, d) { cat(sprintf("  [%s] %-50s %s\n", if (isTRUE(e)) "OK" else "FALLITO", n, d)); if (!isTRUE(e)) ok <<- FALSE }
chk("positivo: ogni record da rifare ha la sua riga di input",
    length(sel) == length(da_rifare), sprintf("%d/%d", length(sel), length(da_rifare)))
chk("negativo: nessun record valido finisce nel rescue",
    !any(sub('^.*"record_id":"([^"]+)".*$', "\\1", sel) %in% rid[valido]), "0 intrusi")
if (!ok) stop("CASI DI ACCETTAZIONE FALLITI.")
writeLines(sel, RESC)
cat("\nscritto:", RESC, sprintf("(%d righe)\n", length(sel)))

if (DRY) { cat("DRY_RUN: mi fermo prima di sottomettere.\n"); quit(save = "no") }

bundle <- dgx_p4_build_bundle(RESC, stage = "stage1", config = dgx_config(),
                              metadata = list(slug = "a3-s1-rescue"))
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_tokens         <- 4096L
gen$repetition_penalty <- 1.2
gen$max_model_len      <- 8192L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat("generation.json: rep_pen=1.2, max_tokens=4096, max_model_len=8192 (identico a H1 di F2)\n")

job <- dgx_p4_submit(bundle, time = "04:00:00",
                     env = c(VLLM_BATCH_INVARIANT = "1"))
saveRDS(job, "analysis/audit/2026-08-16-A3/job-s1-rescue.rds")
cat(sprintf("\nslurm=%s run_id=%s\n", job$slurm_job_id, job$run_id))
