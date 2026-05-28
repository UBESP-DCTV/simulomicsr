#!/usr/bin/env Rscript
# p4-fase-f2-validate-guard.R --- VALIDAZIONE fix guard is_zero_timepoint
#
# Config = produzione F2 (stage1 prompt D1b/D4 HEAD, stage2 EN HEAD). UNICA
# differenza vs F2-smoke: il build input Stadio 2 ora applica il guard
# deterministico normalize_stage1_facts_zt (R/stage1-normalize.R).
#
# Riusa le predizioni Stadio 1 di OGGI (D1b/D4):
#   20260528T202554Z-f2-smoke-minigold-s1-80bedb
# Il guard corregge is_zero_timepoint=TRUE->FALSE dove non c'e' evidenza t=0
# (atteso: i 4 GSM di GSE183194). Poi ri-gira Stadio 2 (EN).
#
# Verdetto atteso: accuracy -> ~98%, GSE183194 4/4 'treated', confermando che
# il guard neutralizza il difetto alla sorgente SENZA toccare il prompt.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)   # HEAD: stage1 D1b/D4, stage2 EN
  library(jsonlite); library(fs)
})

cfg        <- dgx_config()
OUTPUT_DIR <- "analysis/p4-output"
MINIGOLD   <- "inst/extdata/p35c-minigold-reviewed-v5-formatB.csv"
S1_PREDS   <- "analysis/p4-output/20260528T202554Z-f2-smoke-minigold-s1-80bedb/predictions.jsonl"
INPUT_S2   <- "analysis/input/p4-f2-validate-guard-stage2-input.jsonl"
GSE183194  <- c("GSM5553041","GSM5553062","GSM5553064","GSM5553066")
REGRESSED  <- c(GSE183194, "GSM6050371")
SUBMIT_TIME<- "72:00:00"
stopifnot(file.exists(S1_PREDS))

# GATE: working tree e' config produzione (stage1 con molecule rule, stage2 EN)
p1 <- simulomicsr:::.stage1_system_prompt()
p2 <- simulomicsr:::.stage2_system_prompt("mistralai/Mistral-Small-3.2-24B-Instruct-2506")
stopifnot(grepl("molecule", p1, ignore.case = TRUE), grepl("You are an expert", p2))
cat("GATE OK: config produzione F2 (stage1 D1b attivo, stage2 EN).\n")

.sacct_final_state <- function(job) {
  cmd <- paste0("sacct -j ", job$slurm_job_id, " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(job$config, cmd), error = function(e) list(stdout = ""))
  s <- trimws(res$stdout %||% ""); if (!nzchar(s)) "TERMINATED" else s
}
poll_until_done <- function(job, lbl, poll_sec = 60L, max_polls = 720L) {
  for (i in seq_len(max_polls)) {
    st <- dgx_p4_status(job); state <- st$slurm_state
    if (identical(state, "TERMINATED")) { state <- .sacct_final_state(job); st$slurm_state <- state }
    cat(sprintf("  [%s] poll %d %s state=%s\n", format(Sys.time(), "%H:%M:%S"), i, lbl, state))
    if (state %in% c("COMPLETED","FAILED","TIMEOUT","CANCELLED","NODE_FAIL","OUT_OF_MEMORY")) return(st)
    Sys.sleep(poll_sec)
  }
  cli::cli_abort("Max polls superati per {lbl}")
}
.find_existing_job <- function(slug) {
  f <- list.files(OUTPUT_DIR, pattern = paste0(".*-", slug, "-.*-job\\.rds$"), full.names = TRUE)
  if (length(f) == 0L) return(NULL); f[which.max(file.info(f)$mtime)]
}

# === Build input Stadio 2 CON guard (sourcing build-input modificato) ===
Sys.setenv(STAGE1_PREDS_PATH = S1_PREDS, OUT_JSONL = INPUT_S2, CHUNK_SIZE = "50")
source("analysis/p4-beta-stage2-build-input.R", local = new.env())
stopifnot(file.exists(INPUT_S2))

# === Submit stage2 EN ===
slug2 <- "f2-validate-guard-s2"
ex2 <- .find_existing_job(slug2)
if (!is.null(ex2)) { job2 <- readRDS(ex2); cat(sprintf("Resume: %s\n", ex2)) } else {
  b2 <- dgx_p4_build_bundle(input_jsonl = INPUT_S2, stage = "stage2", config = cfg,
                            metadata = list(slug = slug2), tiered_max_tokens = TRUE)
  job2 <- dgx_p4_submit(b2, time = SUBMIT_TIME)
  saveRDS(job2, file.path(OUTPUT_DIR, paste0(job2$run_id, "-job.rds")))
  cat(sprintf("Submitted: slurm=%s run_id=%s\n", job2$slurm_job_id, job2$run_id))
}
st2 <- poll_until_done(job2, "validate-guard-s2")
if (st2$slurm_state != "COMPLETED") cli::cli_abort("s2 fallita: {st2$slurm_state}")
dgx_p4_collect(job2, dest = OUTPUT_DIR)
preds2 <- file.path(OUTPUT_DIR, job2$run_id, "predictions.jsonl")
stopifnot(file.exists(preds2))

# === Eval ===
mg <- read.csv(MINIGOLD, stringsAsFactors = FALSE)
p2x <- jsonlite::stream_in(file(preds2), verbose = FALSE, simplifyVector = FALSE)
schema_s2 <- mean(vapply(p2x, function(r) !is.null(r$parsed_json), logical(1L)))
s2r <- list()
for (rec in p2x) {
  pj <- rec$parsed_json; if (is.null(pj) || is.null(pj$replicate_groups)) next
  for (rg in pj$replicate_groups) {
    role <- as.character(rg$primary_role %||% NA_character_)
    for (sid in as.character(rg$sample_ids %||% character(0))) s2r[[sid]] <- role
  }
}
mg$pred  <- vapply(mg$geo_accession, function(g){ v<-s2r[[as.character(g)]]; if(is.null(v)) NA_character_ else v}, character(1L))
mg$goldb <- design_role_to_binary(mg$design_role_gold_v3_original)
mg$predb <- design_role_to_binary(mg$pred)
n_eval <- sum(!is.na(mg$goldb)&!is.na(mg$predb)); n_corr <- sum(mg$goldb==mg$predb, na.rm=TRUE)
acc <- if (n_eval>0) n_corr/n_eval else NA_real_

cat(sprintf("\n=== ACCURACY (stage1 D1b/D4 + GUARD + stage2 EN) ===\nschema_s2 %.1f%% | accuracy %.2f%% (%d/%d)\n", 100*schema_s2, 100*acc, n_corr, n_eval))
cat("[riferimenti: F2-smoke senza guard 92.93%, beta 98%, isolamento beta-prompt 97.96%]\n")
cat("GSE183194 (4 sample, atteso treated dopo guard):\n")
for (g in GSE183194) cat(sprintf("  %s: pred=%s (bin=%s)\n", g, mg$pred[mg$geo_accession==g], mg$predb[mg$geo_accession==g]))
cat(sprintf("GSM6050371 (multi-arm, atteso ANCORA control - non e' un bug): pred=%s (bin=%s)\n",
            mg$pred[mg$geo_accession=="GSM6050371"], mg$predb[mg$geo_accession=="GSM6050371"]))
fixed_gse <- sum(vapply(GSE183194, function(g){ i<-which(mg$geo_accession==g); !is.na(mg$predb[i])&&mg$predb[i]=="treated"}, logical(1L)))
cat(sprintf("\nGSE183194 recuperati: %d/4\n", fixed_gse))

cat("\n=== VERDETTO GUARD ===\n")
if (!is.na(acc) && acc >= 0.96 && fixed_gse >= 4) {
  cat(sprintf("CONFERMATO: guard recupera GSE183194 (4/4) e accuracy %.2f%%. Difetto neutralizzato alla sorgente.\n", 100*acc))
} else {
  cat(sprintf("PARZIALE: acc=%.2f%%, GSE183194 %d/4. Interpretare con utente.\n", 100*acc, fixed_gse))
}
saveRDS(list(acc=acc, n_eval=n_eval, n_corr=n_corr, fixed_gse=fixed_gse, s2_run=job2$run_id, mg=mg),
        file.path(OUTPUT_DIR, paste0(format(Sys.time(),"%Y%m%dT%H%M%SZ"),"-f2-validate-guard-eval.rds")))
cat("\n=== VALIDAZIONE GUARD COMPLETE ===\n")
