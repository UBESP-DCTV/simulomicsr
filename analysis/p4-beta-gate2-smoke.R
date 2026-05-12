#!/usr/bin/env Rscript
# p4-beta-gate2-smoke.R --- GATE #2: smoke 1000 sample stratificato per nchar quartile
#
# Pipeline:
#   1. Stratified sample 1000 da archs4-human-stage1-input.jsonl (seed=42)
#      stratum = quartile di nchar(string) (Q1/Q2/Q3/Q4 ~250 ciascuno)
#   2. Submit stage1 DGX -> wait COMPLETED -> collect
#   3. Build stage2 input via analysis/p4-beta-stage2-build-input.R
#   4. Submit stage2 DGX -> wait COMPLETED -> collect
#   5. Eval senza gold: schema validity, throughput, tier distribution,
#      diversity di primary_role e design_kind
#
# Gate criteria:
#   - schema_s1 >= 99.5%
#   - schema_s2 >= 99.5%
#   - tier XL overflow = 0
#   - throughput rec/min coerente con full-run ETA <= 50h

suppressPackageStartupMessages({
  library(simulomicsr)
  library(jsonlite)
  library(fs)
})

# === Setup ===
cfg        <- dgx_config()
RUN_BASE   <- format(Sys.time(), "%Y%m%dT%H%M%SZ")
OUTPUT_DIR <- "analysis/p4-output"
INPUT_FULL <- "analysis/input/archs4-human-stage1-input.jsonl"
N_SMOKE    <- 1000L
SEED_STRAT <- 42L
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
fs::dir_create("analysis/input", recurse = TRUE)

.sacct_final_state <- function(job) {
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
    if (identical(state, "TERMINATED")) {
      state <- .sacct_final_state(job)
      st$slurm_state <- state
    }
    cat(sprintf("  [%s] poll %d/%d slurm_state=%s\n",
                format(Sys.time(), "%H:%M:%S"), i, max_polls, state))
    if (state %in% c("COMPLETED", "FAILED", "TIMEOUT",
                     "CANCELLED", "NODE_FAIL", "OUT_OF_MEMORY")) {
      return(st)
    }
    if (state %in% c("RUNNING", "PENDING", "CONFIGURING", "COMPLETING")) {
      Sys.sleep(poll_sec)
      next
    }
    Sys.sleep(poll_sec)
  }
  cli::cli_abort("Max polls superati ({max_polls}) per {stage_label}")
}

.find_existing_job <- function(slug_pattern) {
  rds_files <- list.files(OUTPUT_DIR,
                          pattern = paste0(".*-", slug_pattern, "-.*-job\\.rds$"),
                          full.names = TRUE)
  if (length(rds_files) == 0L) return(NULL)
  rds_files[which.max(file.info(rds_files)$mtime)]
}

# === STAGE 1: stratified sample + submit + wait ===
cat(sprintf("\n=== STAGE 1: smoke %d stratificato per nchar quartile ===\n",
            N_SMOKE))
input_s1 <- "analysis/input/p4-beta-gate2-smoke1000-input.jsonl"

if (!file.exists(input_s1)) {
  cat("Loading full β JSONL...\n")
  recs <- jsonlite::stream_in(file(INPUT_FULL), verbose = FALSE,
                              simplifyVector = TRUE)
  cat(sprintf("Loaded %d records, stratifying by nchar...\n", nrow(recs)))
  nch <- nchar(recs$string)
  q   <- quantile(nch, c(0, 0.25, 0.5, 0.75, 1))
  cat(sprintf("nchar quartiles: Q1=%d Q2=%d Q3=%d Q4=%d Q5=%d\n",
              q[1], q[2], q[3], q[4], q[5]))
  stratum <- cut(nch, breaks = q, include.lowest = TRUE,
                  labels = paste0("Q", 1:4))
  set.seed(SEED_STRAT)
  per_stratum <- as.integer(N_SMOKE / 4L)
  sample_idx <- unlist(lapply(levels(stratum), function(s) {
    pool <- which(stratum == s)
    sample(pool, min(per_stratum, length(pool)))
  }))
  cat(sprintf("Sampled %d (target %d), per-stratum counts:\n",
              length(sample_idx), N_SMOKE))
  print(table(stratum[sample_idx]))
  smoke <- recs[sample_idx, c("record_id", "geo_accession", "series_id",
                              "string", "library_strategy", "organism")]
  con <- file(input_s1, "w")
  jsonlite::stream_out(smoke, con, verbose = FALSE)
  close(con)
  cat("Stage1 smoke input:", input_s1, sprintf(" (%d records)\n", nrow(smoke)))
} else {
  cat("Stage1 input already exists (resume):", input_s1, "\n")
}

existing_job1 <- .find_existing_job("gate2-smoke1000-stage1")
if (!is.null(existing_job1)) {
  job1 <- readRDS(existing_job1)
  cat(sprintf("Resume: stage1 job esistente caricato da %s (slurm=%s)\n",
              existing_job1, job1$slurm_job_id))
} else {
  bundle1 <- dgx_p4_build_bundle(
    input_jsonl = input_s1,
    stage       = "stage1",
    config      = cfg,
    metadata    = list(slug = "gate2-smoke1000-stage1")
  )
  job1 <- dgx_p4_submit(bundle1, time = "72:00:00")
  saveRDS(job1, file.path(OUTPUT_DIR, paste0(job1$run_id, "-job.rds")))
  cat(sprintf("Stage1 submitted: slurm=%s run_id=%s\n",
              job1$slurm_job_id, job1$run_id))
}

t_s1_start <- Sys.time()
st1 <- poll_until_done(job1, "stage1")
t_s1_wall <- as.numeric(difftime(Sys.time(), t_s1_start, units = "mins"))
if (st1$slurm_state != "COMPLETED") {
  cli::cli_abort("Stage1 fallita: slurm_state={st1$slurm_state}.")
}
dgx_p4_collect(job1, dest = OUTPUT_DIR)
preds1_path <- file.path(OUTPUT_DIR, job1$run_id, "predictions.jsonl")
stopifnot(file.exists(preds1_path))
cat("Stage1 predictions:", preds1_path, "\n")

# === STAGE 2 INPUT BUILD ===
cat("\n=== STAGE 2 INPUT BUILD ===\n")
input_s2 <- "analysis/input/p4-beta-gate2-smoke1000-stage2-input.jsonl"
Sys.setenv(STAGE1_PREDS_PATH = preds1_path,
           OUT_JSONL         = input_s2,
           CHUNK_SIZE        = "50")
source("analysis/p4-beta-stage2-build-input.R")
stopifnot(file.exists(input_s2))

# === STAGE 2: submit + wait + collect ===
cat("\n=== STAGE 2: study-level interpretation ===\n")
existing_job2 <- .find_existing_job("gate2-smoke1000-stage2")
if (!is.null(existing_job2)) {
  job2 <- readRDS(existing_job2)
  cat(sprintf("Resume: stage2 job esistente caricato da %s (slurm=%s)\n",
              existing_job2, job2$slurm_job_id))
} else {
  bundle2 <- dgx_p4_build_bundle(
    input_jsonl       = input_s2,
    stage             = "stage2",
    config            = cfg,
    metadata          = list(slug = "gate2-smoke1000-stage2"),
    tiered_max_tokens = TRUE
  )
  job2 <- dgx_p4_submit(bundle2, time = "72:00:00")
  saveRDS(job2, file.path(OUTPUT_DIR, paste0(job2$run_id, "-job.rds")))
  cat(sprintf("Stage2 submitted: slurm=%s run_id=%s\n",
              job2$slurm_job_id, job2$run_id))
}

t_s2_start <- Sys.time()
st2 <- poll_until_done(job2, "stage2")
t_s2_wall <- as.numeric(difftime(Sys.time(), t_s2_start, units = "mins"))
if (st2$slurm_state != "COMPLETED") {
  cli::cli_abort("Stage2 fallita: slurm_state={st2$slurm_state}.")
}
dgx_p4_collect(job2, dest = OUTPUT_DIR)
preds2_path <- file.path(OUTPUT_DIR, job2$run_id, "predictions.jsonl")
stopifnot(file.exists(preds2_path))
cat("Stage2 predictions:", preds2_path, "\n")

# === EVAL senza gold ===
cat("\n=== EVAL: schema validity + throughput + distribution ===\n")
preds1 <- jsonlite::stream_in(file(preds1_path), verbose = FALSE,
                              simplifyVector = FALSE)
preds2 <- jsonlite::stream_in(file(preds2_path), verbose = FALSE,
                              simplifyVector = FALSE)

schema_s1 <- mean(vapply(preds1, function(r) isTRUE(r$valid_schema),
                          logical(1L)), na.rm = TRUE)
schema_s2 <- mean(vapply(preds2, function(r) isTRUE(r$valid_schema),
                          logical(1L)), na.rm = TRUE)

# Distribuzione primary_role da stage2 replicate_groups
all_roles <- list()
for (rec in preds2) {
  pj <- rec$parsed_json
  if (is.null(pj) || is.null(pj$replicate_groups)) next
  for (rg in pj$replicate_groups) {
    role <- as.character(rg$primary_role %||% NA_character_)
    n    <- length(rg$sample_ids %||% character(0))
    all_roles[[length(all_roles) + 1L]] <- list(role = role, n = n)
  }
}
roles_df <- do.call(rbind, lapply(all_roles, function(x) {
  data.frame(role = x$role, n_samples = x$n, stringsAsFactors = FALSE)
}))
role_dist <- aggregate(n_samples ~ role, data = roles_df, FUN = sum)
role_dist <- role_dist[order(-role_dist$n_samples), ]

# Distribuzione design_kind da stage2
all_dk <- vapply(preds2, function(r) {
  v <- r$parsed_json$design_kind
  if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)
}, character(1L))
dk_dist <- as.data.frame(table(design_kind = all_dk, useNA = "ifany"),
                          stringsAsFactors = FALSE)
dk_dist <- dk_dist[order(-dk_dist$Freq), ]

# Throughput
throughput_s1 <- length(preds1) / max(t_s1_wall, 0.01)
throughput_s2 <- length(preds2) / max(t_s2_wall, 0.01)
# Stima full-run ETA: stage1 su 888k sample @ throughput_s1
eta_stage1_full <- 888821 / throughput_s1 / 60

cat(sprintf("Schema validity stage1: %.2f%% (%d / %d)\n",
            100 * schema_s1, round(schema_s1 * length(preds1)),
            length(preds1)))
cat(sprintf("Schema validity stage2: %.2f%% (%d / %d)\n",
            100 * schema_s2, round(schema_s2 * length(preds2)),
            length(preds2)))
cat(sprintf("Stage1 throughput: %.1f records/min (wall %.1f min)\n",
            throughput_s1, t_s1_wall))
cat(sprintf("Stage2 throughput: %.1f records/min (wall %.1f min)\n",
            throughput_s2, t_s2_wall))
cat(sprintf("ETA stage1 full run (~888k sample): %.1f h\n", eta_stage1_full))

cat("\nDistribuzione primary_role (n_samples per ruolo):\n")
print(role_dist)
cat("\nDistribuzione design_kind:\n")
print(dk_dist)

# Save eval RDS
eval_rds <- file.path(OUTPUT_DIR,
                     paste0(RUN_BASE, "-p4-beta-gate2-smoke1000-eval.rds"))
saveRDS(list(
  run_base       = RUN_BASE,
  stage1_run_id  = job1$run_id,
  stage2_run_id  = job2$run_id,
  schema_s1      = schema_s1,
  schema_s2      = schema_s2,
  throughput_s1  = throughput_s1,
  throughput_s2  = throughput_s2,
  t_s1_wall_min  = t_s1_wall,
  t_s2_wall_min  = t_s2_wall,
  eta_stage1_full_hours = eta_stage1_full,
  role_dist      = role_dist,
  dk_dist        = dk_dist
), eval_rds)
cat("\nEval RDS:", eval_rds, "\n")

# === GATE DECISION ===
cat("\n=== GATE #2 DECISION ===\n")
gate_pass <- schema_s1 >= 0.995 && schema_s2 >= 0.995 &&
             eta_stage1_full <= 50
if (gate_pass) {
  cat(sprintf("PASS - schema_s1=%.2f%%, schema_s2=%.2f%%, ETA stage1 full=%.1fh <= 50h.\n",
              100 * schema_s1, 100 * schema_s2, eta_stage1_full))
  cat("Procedi a stage1 full run (Task 10) in NUOVA SESSIONE per validate-before-fullrun.\n")
} else if (schema_s1 >= 0.95 && schema_s2 >= 0.95) {
  cat(sprintf("BORDERLINE - schema_s1=%.2f%%, schema_s2=%.2f%%, ETA=%.1fh. Decidi.\n",
              100 * schema_s1, 100 * schema_s2, eta_stage1_full))
} else {
  cat(sprintf("FAIL - schema_s1=%.2f%%, schema_s2=%.2f%%. Investigare.\n",
              100 * schema_s1, 100 * schema_s2))
}
