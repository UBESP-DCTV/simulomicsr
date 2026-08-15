#!/usr/bin/env Rscript
# analysis/p4-fase-f5b-stage4-ricomponi-pezzi.R --- ricompone un re-pool spezzato.
#
# I pezzi (`p4-fase-f5-stage4-layer-a-rebuild-v16.R` con PEZZO/N_PEZZI) hanno
# calcolato ognuno i propri cluster e salvato il proprio `stage4_result`. Qui si
# uniscono righe E registri (`merge_stage4_shards`), si scrivono i parquet e si
# annota il deliverable — una volta sola.
#
# EQUIVALENZA MISURATA prima di usarlo, sui dati veri
# (analysis/audit/2026-08-13-rerun-prep/E2-equivalenza-completa.R): gli stessi
# cluster calcolati in un pezzo solo e in due pezzi danno dati identici (15/15 e
# 11/11 colonne) e registri identici (dispatch_drops 24 = 24, covariate_drops
# 40 = 40).
#
# Uso:
#   PEZZI_DIR=<dir dei pezzi> STAGE3_DIR=<dir stadio 3> \
#   VERDETTI_PATH=<csv dei verdetti applicabili> \
#     Rscript analysis/p4-fase-f5b-stage4-ricomponi-pezzi.R

suppressPackageStartupMessages({ library(cli); library(arrow)
  devtools::load_all(".", quiet = TRUE) })

pezzi_dir  <- Sys.getenv("PEZZI_DIR", "")
stage3_dir <- Sys.getenv("STAGE3_DIR", "")
verdetti   <- Sys.getenv("VERDETTI_PATH", "")
if (!dir.exists(pezzi_dir))  cli_abort("PEZZI_DIR mancante o inesistente.")
if (!dir.exists(stage3_dir)) cli_abort("STAGE3_DIR mancante o inesistente.")
if (!file.exists(verdetti))  cli_abort("VERDETTI_PATH mancante: e' obbligatoria come nel re-pool.")

f <- sort(list.files(pezzi_dir, pattern = "^pezzo-[0-9]+-di-[0-9]+\\.rds$", full.names = TRUE))
if (!length(f)) cli_abort("nessun pezzo in {.path {pezzi_dir}}")
attesi <- as.integer(sub("^.*-di-([0-9]+)\\.rds$", "\\1", basename(f)))
if (length(unique(attesi)) != 1L) cli_abort("i pezzi dichiarano N_PEZZI diversi: {unique(attesi)}")
# Un pezzo mancante produrrebbe un deliverable incompleto senza dirlo.
if (length(f) != attesi[1L])
  cli_abort("trovati {length(f)} pezzi su {attesi[1L]}: mancano {setdiff(seq_len(attesi[1L]), as.integer(sub('^pezzo-([0-9]+)-.*$', '\\\\1', basename(f))))}")
cli_h1("Ricomposizione di {length(f)} pezzi")

shards <- lapply(f, function(x) { cli_alert_info("leggo {.path {basename(x)}}"); readRDS(x) })
result <- merge_stage4_shards(shards)
cli_alert_success(paste0(
  "unito: ", nrow(result$cluster_pooled), " righe poolate | ",
  nrow(result$per_study_de), " per-studio | ",
  length(unique(result$cluster_pooled$cluster_id)), " cluster"))
cli_alert_info(paste0(
  "registri: dispatch_drops ", nrow(result$qc_report$dispatch_drops),
  " | covariate_drops ", nrow(result$qc_report$covariate_drops %||% data.frame()),
  " | conflitti di ruolo ", nrow(result$qc_report$role_conflicts),
  " | collassi di corsia ", nrow(result$qc_report$lane_collapses)))

ts      <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
v_token <- sub("^.*-stage3-(v[0-9]+)-.*$", "\\1", basename(stage3_dir))
run_id  <- result$run_metadata$run_id
out_dir <- file.path("/mnt/wwn-0x5000039d58caca35", paste0("simulomicsr-stage4-", v_token),
                     sprintf("%s-stage4-%s-%s", ts, v_token, run_id))
cli_alert_info("scrivo in {.path {out_dir}}")
write_stage4_to_dir(result, out_dir)

# --- annotazione, con la guardia FATALE sui verdetti orfani -------------------
cli_h2("annotazione del deliverable")
Sys.setenv(POOL_DIR = out_dir, STAGE3_DIR = stage3_dir, VERDETTI_PATH = verdetti)
source("analysis/audit/2026-08-02-fix/80-annotazione-a-freddo-v15.R", echo = FALSE)
cli_alert_success("FATTO: {.path {out_dir}}")
