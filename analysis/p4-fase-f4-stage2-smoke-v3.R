#!/usr/bin/env Rscript
# p4-fase-f4-stage2-smoke-v3.R --- RED ALERT FASE F4 opzione C: smoke Stadio 2 v3.
#
# Valida lo Stadio 2 v3 (input a CONDIZIONI deduplicate + prompt n_replicates +
# espansione rappresentante->membri) sui 72 studi del gold design-aware (756
# campioni). Differenza chiave vs smoke F3: dopo il run, le predizioni hanno i
# RAPPRESENTANTI in sample_ids -> si ASSEMBLA (espansione) prima di valutare.
#
# Config pipeline INVARIATA (uniformity): stage2 tiered_max_tokens, temp=0,
# rep_pen=1.1, microbatch=50, time 72:00:00. Resume-safe via job RDS.
#
# Uso:
#   run completo (submit DGX + eval):   Rscript analysis/p4-fase-f4-stage2-smoke-v3.R
#   solo eval su predictions esistenti: PREDS=<path> EVAL_ONLY=1 Rscript ...

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite); library(fs)
})

OUTPUT_DIR  <- "analysis/p4-output"
INPUT_V3    <- "analysis/input/archs4-human-stage2-input-v3.jsonl"
GOLD_CSV    <- "analysis/p4-output/f2-eval-gold.csv"
SMOKE_INPUT <- "analysis/input/p4-f4-stage2-smoke-input-v3.jsonl"
SLUG        <- "f4-stage2-smoke-v3"
SUBMIT_TIME <- "72:00:00"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
stopifnot(file.exists(GOLD_CSV))

asm   <- simulomicsr:::.assemble_stage2_study
`%||%` <- function(a, b) if (is.null(a)) b else a

# === Costruzione smoke input: i record degli studi gold dal JSONL v3 ===
build_smoke_input <- function() {
  g    <- read.csv(GOLD_CSV, stringsAsFactors = FALSE)
  gser <- unique(g$series)
  lines <- readLines(INPUT_V3, warn = FALSE)
  ser  <- vapply(lines, function(L) fromJSON(L, simplifyVector = FALSE)$series_id,
                 character(1L))
  sel  <- ser %in% gser
  writeLines(lines[sel], SMOKE_INPUT)
  cat(sprintf("Smoke input: %d record / %d studi gold -> %s\n",
              sum(sel), length(gser), SMOKE_INPUT))
  stopifnot(sum(sel) > 0L)
}

# === Assembla il master v3 (espansione) da smoke input + predizioni ===
assemble_master <- function(smoke_input_path, predictions_path) {
  in_recs <- lapply(readLines(smoke_input_path, warn = FALSE),
                    fromJSON, simplifyVector = FALSE)
  in_by_series <- split(in_recs,
                        vapply(in_recs, function(r) r$series_id, character(1L)))
  preds <- jsonlite::stream_in(file(predictions_path), verbose = FALSE,
                               simplifyVector = FALSE)
  llm_by_rid <- list()
  for (p in preds) if (!is.null(p$parsed_json)) llm_by_rid[[p$record_id]] <- p$parsed_json
  schema <- mean(vapply(preds, function(r) !is.null(r$parsed_json), logical(1L)))

  master <- list()
  for (sid in names(in_by_series)) {
    d <- asm(in_by_series[[sid]], llm_by_rid)
    if (!is.null(d)) master[[sid]] <- d
  }
  list(master = master, schema = schema, n_pred = length(preds))
}

# === EVAL binario vs gold (su master espanso) ===
eval_v3 <- function(asm_res) {
  g <- read.csv(GOLD_CSV, stringsAsFactors = FALSE)
  s2r <- list()
  for (d in asm_res$master) for (rg in (d$replicate_groups %||% list())) {
    role <- as.character(rg$primary_role %||% NA_character_)
    for (sid in as.character(unlist(rg$sample_ids))) s2r[[sid]] <- role
  }
  g$pred_role   <- vapply(g$geo, function(x) { v <- s2r[[x]]; if (is.null(v)) NA_character_ else v }, character(1L))
  g$pred_binary <- design_role_to_binary(g$pred_role)
  bm <- eval_binary_accuracy(g$gold_binary, g$pred_binary)
  gser <- length(unique(g$series))
  cat(sprintf("\n=== F4 STAGE2 SMOKE v3 (n_gold=%d, %d studi) ===\n", nrow(g), gser))
  cat(sprintf("schema = %.2f%% | n_pred = %d\n", 100 * asm_res$schema, asm_res$n_pred))
  cat(sprintf("Binary accuracy: %.2f%% (n_eval=%d) | sens=%.1f%% spec=%.1f%% f1=%.3f\n",
              100 * bm$accuracy, bm$n, 100 * bm$sensitivity, 100 * bm$specificity, bm$f1))
  cat("Confusion (gold x pred):\n"); print(table(gold = g$gold_binary, pred = g$pred_binary, useNA = "ifany"))
  n_cov <- sum(!is.na(g$gold_binary) & is.na(g$pred_binary))
  cat(sprintf("Coverage gap (gold senza predizione): %d (%.1f%%)\n", n_cov, 100 * n_cov / nrow(g)))
  invisible(list(g = g, bm = bm, schema = asm_res$schema))
}

# === EVAL_ONLY: valuta su predictions esistenti, niente DGX ===
if (nzchar(Sys.getenv("EVAL_ONLY"))) {
  PREDS <- Sys.getenv("PREDS"); stopifnot(file.exists(SMOKE_INPUT), file.exists(PREDS))
  res <- eval_v3(assemble_master(SMOKE_INPUT, PREDS))
  saveRDS(res, file.path(OUTPUT_DIR, "p4-f4-stage2-smoke-v3-eval.rds"))
  quit(save = "no")
}

# === GATE pre-submit: prompt Stadio 2 v3 (Input format) attivo? ===
s2_prompt <- simulomicsr:::.stage2_system_prompt("mistralai/Mistral-Small-3.2-24B-Instruct-2506")
if (!grepl("Input format: pre-deduplicated design conditions", s2_prompt, fixed = TRUE)) {
  stop("Prompt Stadio 2 del branch non contiene la sezione v3 (Input format). ",
       "Verifica devtools::load_all e branch attivo.")
}
cat("GATE pre-submit OK: prompt Stadio 2 v3 (Input format) attivo.\n")

build_smoke_input()

# === Helper DGX (resume-safe, da p4-fase-f3-stage2-smoke.R) ===
.sacct_final_state <- function(job) {
  cmd <- paste0("sacct -j ", job$slurm_job_id, " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(job$config, cmd), error = function(e) list(stdout = ""))
  s <- trimws(res$stdout %||% ""); if (!nzchar(s)) "TERMINATED" else s
}
poll <- function(job, lbl, poll_sec = 60L, max_polls = 720L) {
  for (i in seq_len(max_polls)) {
    st <- dgx_p4_status(job); state <- st$slurm_state
    if (identical(state, "TERMINATED")) { state <- .sacct_final_state(job); st$slurm_state <- state }
    cat(sprintf("  [%s] %s %s\n", format(Sys.time(), "%H:%M:%S"), lbl, state))
    if (state %in% c("COMPLETED","FAILED","TIMEOUT","CANCELLED","NODE_FAIL","OUT_OF_MEMORY")) return(st)
    Sys.sleep(poll_sec)
  }
  cli::cli_abort("timeout {lbl}")
}
find_job <- function(slug) {
  f <- list.files(OUTPUT_DIR, pattern = paste0(".*-", slug, "-.*-job\\.rds$"), full.names = TRUE)
  if (length(f) == 0L) NULL else f[which.max(file.info(f)$mtime)]
}

# === Submit / resume ===
cfg <- dgx_config()
ex  <- find_job(SLUG)
if (!is.null(ex)) {
  job <- readRDS(ex); cat(sprintf("Resume %s: slurm=%s run_id=%s\n", SLUG, job$slurm_job_id, job$run_id))
} else {
  b <- dgx_p4_build_bundle(input_jsonl = SMOKE_INPUT, stage = "stage2", config = cfg,
                           metadata = list(slug = SLUG), tiered_max_tokens = TRUE)
  job <- dgx_p4_submit(b, time = SUBMIT_TIME)
  saveRDS(job, file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds")))
  cat(sprintf("Submitted %s: slurm=%s run_id=%s\n", SLUG, job$slurm_job_id, job$run_id))
}
st <- poll(job, SLUG)
if (st$slurm_state != "COMPLETED") cli::cli_abort("{SLUG} fallita: {st$slurm_state}")
dgx_p4_collect(job, dest = OUTPUT_DIR)
PREDS <- file.path(OUTPUT_DIR, job$run_id, "predictions.jsonl")
stopifnot(file.exists(PREDS))

res <- eval_v3(assemble_master(SMOKE_INPUT, PREDS))
saveRDS(c(res, list(run_id = job$run_id)),
        file.path(OUTPUT_DIR, paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ"), "-f4-stage2-smoke-v3-eval.rds")))
cat("\n=== F4 STAGE2 SMOKE v3 COMPLETE ===\n")
