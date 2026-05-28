#!/usr/bin/env Rscript
# p4-fase-f2-smoke-isolate-stage1prompt.R --- ISOLAMENTO trigger deriva Stadio 1
#
# Esperimento a variabile singola: il calo accuracy mini-gold 98% (beta) ->
# 92.93% (F2-smoke) NON e' causato dal prompt Stadio 2 (controprova IT
# smentita). La causa e' a monte: Stadio 1 oggi produce fatti diversi
# (is_zero_timepoint 6->12, kind reclassificato). Gli unici cambi prompt
# Stadio 1 dal beta sono D1b (ground rule molecule) + D4 (organism_hint).
#
# Questo run usa il prompt Stadio 1 BETA-ERA (working tree reverted a
# de440ce^: R/llm-stage1.R + inst/dgx/python/prompts.py), e tiene il
# prompt Stadio 2 EN (HEAD). Unica differenza vs F2-smoke = prompt Stadio 1.
#
# Verdetto:
#   - accuracy -> ~98%, is_zero_timepoint -> ~6, GSE183194 4/4 'treated'
#     => causa = prompt Stadio 1 D1b/D4 (prompt fragile: edit non correlati
#        a is_zero_timepoint perturbano comunque quel campo).
#   - accuracy resta ~93%, is_zero_timepoint resta ~12
#     => NON e' il prompt -> drift modello/infra o non-determinismo vLLM.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)   # working tree: stage1 prompt BETA-ERA
  library(jsonlite); library(fs)
})

cfg        <- dgx_config()
OUTPUT_DIR <- "analysis/p4-output"
MINIGOLD   <- "inst/extdata/p35c-minigold-reviewed-v5-formatB.csv"
GSE183194  <- c("GSM5553041","GSM5553062","GSM5553064","GSM5553066")
REGRESSED  <- c(GSE183194, "GSM6050371")
SUBMIT_TIME<- "72:00:00"

# GATE: confermo prompt Stadio 1 beta-era (no molecule rule)
p1 <- simulomicsr:::.stage1_system_prompt()
if (grepl("molecule_hint|RNA fraction", p1, ignore.case = TRUE))
  stop("Prompt Stadio 1 contiene ancora la regola molecule (D1b): revert beta-era non applicato.")
cat("GATE OK: prompt Stadio 1 e' beta-era (no molecule rule).\n")

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

# === STAGE 1 (beta-era prompt) ===
mg <- read.csv(MINIGOLD, stringsAsFactors = FALSE)
input_s1 <- "analysis/input/p4-f2-isolate-minigold-stage1-input.jsonl"
df1 <- data.frame(record_id = mg$geo_accession, geo_accession = mg$geo_accession,
                  series_id = mg$series_id, string = mg$string_formatB,
                  library_strategy = "RNA-Seq", organism = "Homo sapiens",
                  stringsAsFactors = FALSE)
con <- file(input_s1, "w"); jsonlite::stream_out(df1, con, verbose = FALSE); close(con)

slug1 <- "f2-isolate-betaprompt-s1"
ex1 <- .find_existing_job(slug1)
if (!is.null(ex1)) { job1 <- readRDS(ex1); cat(sprintf("Resume s1: %s\n", ex1)) } else {
  b1 <- dgx_p4_build_bundle(input_jsonl = input_s1, stage = "stage1", config = cfg,
                            metadata = list(slug = slug1))
  bp <- readLines(file.path(b1$bundle_dir, "prompt.txt"), warn = FALSE)
  if (any(grepl("molecule_hint|RNA fraction", bp, ignore.case = TRUE)))
    stop("Bundle stage1 prompt.txt contiene regola molecule: NON beta-era. STOP.")
  cat("Bundle stage1 prompt.txt confermato beta-era.\n")
  job1 <- dgx_p4_submit(b1, time = SUBMIT_TIME)
  saveRDS(job1, file.path(OUTPUT_DIR, paste0(job1$run_id, "-job.rds")))
  cat(sprintf("Submitted s1: slurm=%s run_id=%s\n", job1$slurm_job_id, job1$run_id))
}
st1 <- poll_until_done(job1, "betaprompt-s1")
if (st1$slurm_state != "COMPLETED") cli::cli_abort("s1 fallita: {st1$slurm_state}")
dgx_p4_collect(job1, dest = OUTPUT_DIR)
preds1 <- file.path(OUTPUT_DIR, job1$run_id, "predictions.jsonl")
stopifnot(file.exists(preds1))

# --- Check immediato is_zero_timepoint (diagnostico primario) ---
p1x <- jsonlite::stream_in(file(preds1), verbose = FALSE, simplifyVector = FALSE)
zt_by_gsm <- list(); zt_global <- 0L; n_pert <- 0L
for (r in p1x) {
  pj <- r$parsed_json; if (is.null(pj)) next
  any_zt <- FALSE
  for (pt in (pj$perturbations %||% list())) {
    n_pert <- n_pert + 1L
    if (isTRUE(pt$duration$is_zero_timepoint)) { zt_global <- zt_global + 1L; any_zt <- TRUE }
  }
  zt_by_gsm[[r$record_id]] <- any_zt
}
cat(sprintf("\n=== is_zero_timepoint (beta-prompt run) ===\nglobale TRUE: %d su %d perturbations (beta storico=6, F2-smoke=12)\n", zt_global, n_pert))
cat("GSE183194 (atteso FALSE se prompt e' la causa):\n")
for (g in GSE183194) cat(sprintf("  %s: is_zero_timepoint=%s\n", g, isTRUE(zt_by_gsm[[g]])))

# === STAGE 2 (EN, HEAD) ===
input_s2 <- "analysis/input/p4-f2-isolate-minigold-stage2-input.jsonl"
Sys.setenv(STAGE1_PREDS_PATH = preds1, OUT_JSONL = input_s2, CHUNK_SIZE = "50")
source("analysis/p4-beta-stage2-build-input.R", local = new.env())
stopifnot(file.exists(input_s2))

slug2 <- "f2-isolate-betaprompt-s2"
ex2 <- .find_existing_job(slug2)
if (!is.null(ex2)) { job2 <- readRDS(ex2); cat(sprintf("Resume s2: %s\n", ex2)) } else {
  b2 <- dgx_p4_build_bundle(input_jsonl = input_s2, stage = "stage2", config = cfg,
                            metadata = list(slug = slug2), tiered_max_tokens = TRUE)
  job2 <- dgx_p4_submit(b2, time = SUBMIT_TIME)
  saveRDS(job2, file.path(OUTPUT_DIR, paste0(job2$run_id, "-job.rds")))
  cat(sprintf("Submitted s2: slurm=%s run_id=%s\n", job2$slurm_job_id, job2$run_id))
}
st2 <- poll_until_done(job2, "betaprompt-s2")
if (st2$slurm_state != "COMPLETED") cli::cli_abort("s2 fallita: {st2$slurm_state}")
dgx_p4_collect(job2, dest = OUTPUT_DIR)
preds2 <- file.path(OUTPUT_DIR, job2$run_id, "predictions.jsonl")
stopifnot(file.exists(preds2))

# === EVAL accuracy ===
p2 <- jsonlite::stream_in(file(preds2), verbose = FALSE, simplifyVector = FALSE)
schema_s2 <- mean(vapply(p2, function(r) !is.null(r$parsed_json), logical(1L)))
s2r <- list()
for (rec in p2) {
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

cat(sprintf("\n=== ACCURACY (stage1 beta-prompt + stage2 EN) ===\nschema_s2 %.1f%% | accuracy %.2f%% (%d/%d)  [F2-smoke EN era 92.93%%, beta era 98%%]\n",
            100*schema_s2, 100*acc, n_corr, n_eval))
cat("I 5 GSM regrediti (gold=treated):\n")
for (g in REGRESSED) cat(sprintf("  %s: pred=%s (bin=%s)\n", g, mg$pred[mg$geo_accession==g], mg$predb[mg$geo_accession==g]))
fixed5 <- sum(vapply(REGRESSED, function(g){ i<-which(mg$geo_accession==g); !is.na(mg$predb[i])&&!is.na(mg$goldb[i])&&mg$predb[i]==mg$goldb[i]}, logical(1L)))
cat(sprintf("Dei 5 GSM regrediti, corretti ora: %d/5\n", fixed5))

cat("\n=== VERDETTO ISOLAMENTO ===\n")
if (!is.na(acc) && acc >= 0.967 && zt_global <= 8 && fixed5 >= 4) {
  cat("CONFERMATO: prompt Stadio 1 (D1b/D4) e' il trigger. Beta-prompt recupera accuracy + is_zero_timepoint.\n")
} else if (!is.na(acc) && acc < 0.94 && zt_global >= 10) {
  cat("PROMPT ESCLUSO: beta-prompt NON recupera. Causa = drift modello/infra o non-determinismo vLLM.\n")
} else {
  cat(sprintf("PARZIALE: acc=%.2f%%, is_zero_timepoint=%d, fixed=%d/5. Interpretare con utente.\n", 100*acc, zt_global, fixed5))
}
saveRDS(list(acc=acc, n_eval=n_eval, n_corr=n_corr, zt_global=zt_global, zt_by_gsm=zt_by_gsm,
             fixed5=fixed5, s1_run=job1$run_id, s2_run=job2$run_id, mg=mg),
        file.path(OUTPUT_DIR, paste0(format(Sys.time(),"%Y%m%dT%H%M%SZ"),"-f2-isolate-stage1prompt-eval.rds")))
cat("\n=== ISOLAMENTO COMPLETE ===\n")
