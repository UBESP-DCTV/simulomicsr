#!/usr/bin/env Rscript
# p4-beta-gate1-minigold.R --- GATE #1: mini-gold format B end-to-end stage1+stage2
#
# Pipeline:
#   1. Build stage1 input JSONL da inst/extdata/p35c-minigold-reviewed-v5-formatB.csv
#   2. Submit stage1 DGX -> wait COMPLETED -> collect
#   3. Build stage2 input via analysis/p4-beta-stage2-build-input.R su predictions stage1
#   4. Submit stage2 DGX -> wait COMPLETED -> collect
#   5. Eval: primary_role da replicate_groups vs design_role_gold_v3_original
#
# Output finale: stampa metriche gate + RDS con dettagli per audit.

suppressPackageStartupMessages({
  library(simulomicsr)
  library(jsonlite)
  library(fs)
})

# === Setup ===
cfg        <- dgx_config()
RUN_BASE   <- format(Sys.time(), "%Y%m%dT%H%M%SZ")
OUTPUT_DIR <- "analysis/p4-output"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
fs::dir_create("analysis/input", recurse = TRUE)

.sacct_final_state <- function(job) {
  # dgx_p4_status restituisce TERMINATED quando squeue non vede piu' il job:
  # questo accade SIA a completion (job rimosso dalla queue) SIA a failure.
  # Per disambiguare uso sacct sul JobID (mostra anche job storici).
  cmd <- paste0("sacct -j ", job$slurm_job_id,
                " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(job$config, cmd),
                  error = function(e) list(stdout = ""))
  state <- trimws(res$stdout %||% "")
  if (!nzchar(state)) "TERMINATED" else state
}

poll_until_done <- function(job, stage_label, poll_sec = 60L, max_polls = 720L) {
  cat(sprintf("Polling %s ogni %ds (max %d polls)...\n",
              stage_label, poll_sec, max_polls))
  for (i in seq_len(max_polls)) {
    st <- dgx_p4_status(job)
    state <- st$slurm_state
    # Se TERMINATED, disambigua via sacct (COMPLETED/FAILED/CANCELLED/...)
    if (identical(state, "TERMINATED")) {
      state <- .sacct_final_state(job)
      st$slurm_state <- state
    }
    progress <- ""
    if (!is.null(st$snapshot) && !is.null(st$snapshot$progress_pct)) {
      progress <- sprintf(" progress=%s%%", st$snapshot$progress_pct)
    }
    cat(sprintf("  [%s] poll %d/%d slurm_state=%s%s\n",
                format(Sys.time(), "%H:%M:%S"), i, max_polls,
                state, progress))
    if (state %in% c("COMPLETED", "FAILED", "TIMEOUT",
                     "CANCELLED", "NODE_FAIL", "OUT_OF_MEMORY")) {
      return(st)
    }
    if (state %in% c("RUNNING", "PENDING", "CONFIGURING", "COMPLETING")) {
      Sys.sleep(poll_sec)
      next
    }
    # State sconosciuto: log + continua polling per cautela
    Sys.sleep(poll_sec)
  }
  cli::cli_abort("Max polls superati ({max_polls}) per {stage_label}")
}

# Resume: se job RDS esiste, ricarica invece di re-submit
.find_existing_job <- function(slug_pattern) {
  rds_files <- list.files(OUTPUT_DIR,
                          pattern = paste0(".*-", slug_pattern, "-.*-job\\.rds$"),
                          full.names = TRUE)
  if (length(rds_files) == 0L) return(NULL)
  # Prendi il piu' recente
  info <- file.info(rds_files)
  rds_files[which.max(info$mtime)]
}

# === STAGE 1: build input + submit + wait ===
cat("\n=== STAGE 1: mini-gold format B (n=100) ===\n")
mg <- read.csv("inst/extdata/p35c-minigold-reviewed-v5-formatB.csv",
               stringsAsFactors = FALSE)
input_s1 <- paste0("analysis/input/p4-beta-gate1-minigold-stage1-input.jsonl")
df1 <- data.frame(
  record_id        = mg$geo_accession,
  geo_accession    = mg$geo_accession,
  series_id        = mg$series_id,
  string           = mg$string_formatB,
  library_strategy = "RNA-Seq",
  organism         = "Homo sapiens",
  stringsAsFactors = FALSE
)
con <- file(input_s1, "w")
jsonlite::stream_out(df1, con, verbose = FALSE)
close(con)
cat("Stage1 input JSONL:", input_s1, sprintf(" (%d records)\n", nrow(df1)))

existing_job1 <- .find_existing_job("gate1-minigold-stage1")
if (!is.null(existing_job1)) {
  job1 <- readRDS(existing_job1)
  cat(sprintf("Resume: stage1 job esistente caricato da %s (slurm=%s)\n",
              existing_job1, job1$slurm_job_id))
} else {
  bundle1 <- dgx_p4_build_bundle(
    input_jsonl = input_s1,
    stage       = "stage1",
    config      = cfg,
    metadata    = list(slug = "gate1-minigold-stage1")
  )
  job1 <- dgx_p4_submit(bundle1, time = "72:00:00")
  saveRDS(job1, file.path(OUTPUT_DIR, paste0(job1$run_id, "-job.rds")))
  cat(sprintf("Stage1 submitted: slurm=%s run_id=%s\n",
              job1$slurm_job_id, job1$run_id))
}

st1 <- poll_until_done(job1, "stage1")
if (st1$slurm_state != "COMPLETED") {
  cli::cli_abort("Stage1 fallita: slurm_state={st1$slurm_state}. STOP gate.")
}
dgx_p4_collect(job1, dest = OUTPUT_DIR)
preds1_path <- file.path(OUTPUT_DIR, job1$run_id, "predictions.jsonl")
stopifnot(file.exists(preds1_path))
cat("Stage1 predictions:", preds1_path, "\n")

# === STAGE 2 INPUT BUILD ===
cat("\n=== STAGE 2 INPUT BUILD ===\n")
input_s2 <- "analysis/input/p4-beta-gate1-minigold-stage2-input.jsonl"
Sys.setenv(STAGE1_PREDS_PATH = preds1_path,
           OUT_JSONL         = input_s2,
           CHUNK_SIZE        = "50")
source("analysis/p4-beta-stage2-build-input.R")
stopifnot(file.exists(input_s2))

# === STAGE 2: submit + wait + collect ===
cat("\n=== STAGE 2: study-level interpretation ===\n")
existing_job2 <- .find_existing_job("gate1-minigold-stage2")
if (!is.null(existing_job2)) {
  job2 <- readRDS(existing_job2)
  cat(sprintf("Resume: stage2 job esistente caricato da %s (slurm=%s)\n",
              existing_job2, job2$slurm_job_id))
} else {
  bundle2 <- dgx_p4_build_bundle(
    input_jsonl       = input_s2,
    stage             = "stage2",
    config            = cfg,
    metadata          = list(slug = "gate1-minigold-stage2"),
    tiered_max_tokens = TRUE
  )
  job2 <- dgx_p4_submit(bundle2, time = "72:00:00")
  saveRDS(job2, file.path(OUTPUT_DIR, paste0(job2$run_id, "-job.rds")))
  cat(sprintf("Stage2 submitted: slurm=%s run_id=%s\n",
              job2$slurm_job_id, job2$run_id))
}

st2 <- poll_until_done(job2, "stage2")
if (st2$slurm_state != "COMPLETED") {
  cli::cli_abort("Stage2 fallita: slurm_state={st2$slurm_state}. STOP gate.")
}
dgx_p4_collect(job2, dest = OUTPUT_DIR)
preds2_path <- file.path(OUTPUT_DIR, job2$run_id, "predictions.jsonl")
stopifnot(file.exists(preds2_path))
cat("Stage2 predictions:", preds2_path, "\n")

# === EVAL ===
cat("\n=== EVAL: primary_role vs design_role_gold_v3_original ===\n")
preds2 <- jsonlite::stream_in(file(preds2_path), verbose = FALSE)

# Schema validity stage1 + stage2
preds1 <- jsonlite::stream_in(file(preds1_path), verbose = FALSE)
schema_s1 <- mean(vapply(preds1$parsed_json, function(p) !is.null(p),
                          logical(1L)), na.rm = TRUE)
schema_s2 <- mean(vapply(preds2$parsed_json, function(p) !is.null(p),
                          logical(1L)), na.rm = TRUE)

# Map sample -> primary_role via replicate_groups
sample_to_role <- list()
for (i in seq_len(nrow(preds2))) {
  pj <- preds2$parsed_json[[i]]
  if (is.null(pj) || is.null(pj$replicate_groups)) next
  for (rg in pj$replicate_groups) {
    role <- as.character(rg$primary_role %||% NA_character_)
    sids <- as.character(rg$sample_ids %||% character(0))
    for (sid in sids) sample_to_role[[sid]] <- role
  }
}

# Merge con gold
mg$primary_role_pred <- vapply(mg$geo_accession, function(g) {
  v <- sample_to_role[[as.character(g)]]
  if (is.null(v)) NA_character_ else v
}, character(1L))

n_total       <- nrow(mg)
n_predicted   <- sum(!is.na(mg$primary_role_pred))
n_gold_match  <- sum(mg$primary_role_pred == mg$design_role_gold_v3_original,
                     na.rm = TRUE)
acc           <- n_gold_match / n_total
acc_predicted <- if (n_predicted > 0) n_gold_match / n_predicted else NA_real_

cat(sprintf("Schema validity stage1: %.2f%% (%d / %d)\n",
            100 * schema_s1, round(schema_s1 * nrow(preds1)), nrow(preds1)))
cat(sprintf("Schema validity stage2: %.2f%% (%d / %d)\n",
            100 * schema_s2, round(schema_s2 * nrow(preds2)), nrow(preds2)))
cat(sprintf("Sample predetti su gold: %d / %d (%.1f%%)\n",
            n_predicted, n_total, 100 * n_predicted / n_total))
cat(sprintf("Accuracy primary_role vs gold (su totale): %.2f%% (%d / %d)\n",
            100 * acc, n_gold_match, n_total))
cat(sprintf("Accuracy condizionata sui predetti: %.2f%% (%d / %d)\n",
            100 * acc_predicted, n_gold_match, n_predicted))

# Confusion matrix per categoria
cat("\nConfusion table (gold vs pred):\n")
print(table(gold = mg$design_role_gold_v3_original,
            pred = mg$primary_role_pred,
            useNA = "ifany"))

# Save eval RDS per audit
eval_rds <- file.path(OUTPUT_DIR,
                     paste0(RUN_BASE, "-p4-beta-gate1-minigold-eval.rds"))
saveRDS(list(
  run_base       = RUN_BASE,
  stage1_run_id  = job1$run_id,
  stage2_run_id  = job2$run_id,
  schema_s1      = schema_s1,
  schema_s2      = schema_s2,
  acc_total      = acc,
  acc_predicted  = acc_predicted,
  n_total        = n_total,
  n_predicted    = n_predicted,
  n_gold_match   = n_gold_match,
  mg_with_pred   = mg,
  sample_to_role = sample_to_role
), eval_rds)
cat("\nEval RDS:", eval_rds, "\n")

# === GATE DECISION ===
cat("\n=== GATE #1 DECISION ===\n")
gate_pass <- schema_s1 >= 0.995 && schema_s2 >= 0.995 && acc >= 0.95
if (gate_pass) {
  cat("✓ PASS - procedi a smoke 1000 (Task 9)\n")
} else if (acc >= 0.85) {
  cat("BORDERLINE - acc=%.2f%%, schema_s1=%.2f%%, schema_s2=%.2f%%. ",
      "Nuova sessione per decidere se procedere o iter prompt.\n")
} else {
  cat(sprintf("✗ FAIL - acc=%.2f%% < 85%% soglia. Investigare.\n", 100 * acc))
}
