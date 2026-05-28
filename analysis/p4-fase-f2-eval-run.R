#!/usr/bin/env Rscript
# Benchmark scalato FASE F2: pipeline corrente (stage1 D1b/D4 + guard
# is_zero_timepoint + stage2 EN) sul gold design-aware da 756 sample.
# Misura binary accuracy vs gold + error analysis per studio/design.

suppressPackageStartupMessages({ devtools::load_all(quiet = TRUE); library(jsonlite); library(fs) })

cfg <- dgx_config(); OUTPUT_DIR <- "analysis/p4-output"
INPUT_S1 <- "analysis/input/p4-f2-eval-stage1-input.jsonl"
SUBMIT_TIME <- "72:00:00"
stopifnot(file.exists(INPUT_S1))

.sacct_final_state <- function(job) {
  cmd <- paste0("sacct -j ", job$slurm_job_id, " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(job$config, cmd), error=function(e) list(stdout=""))
  s <- trimws(res$stdout %||% ""); if (!nzchar(s)) "TERMINATED" else s
}
poll <- function(job, lbl, poll_sec=60L, max_polls=720L) {
  for (i in seq_len(max_polls)) {
    st <- dgx_p4_status(job); state <- st$slurm_state
    if (identical(state,"TERMINATED")) { state <- .sacct_final_state(job); st$slurm_state <- state }
    cat(sprintf("  [%s] %s %s\n", format(Sys.time(),"%H:%M:%S"), lbl, state))
    if (state %in% c("COMPLETED","FAILED","TIMEOUT","CANCELLED","NODE_FAIL","OUT_OF_MEMORY")) return(st)
    Sys.sleep(poll_sec)
  }
  cli::cli_abort("timeout {lbl}")
}
find_job <- function(slug) { f <- list.files(OUTPUT_DIR, pattern=paste0(".*-",slug,"-.*-job\\.rds$"), full.names=TRUE)
  if (length(f)==0L) NULL else f[which.max(file.info(f)$mtime)] }

run_stage <- function(stage, input, slug, tiered=FALSE) {
  ex <- find_job(slug)
  if (!is.null(ex)) { job <- readRDS(ex); cat(sprintf("Resume %s: %s\n", slug, job$slurm_job_id)) } else {
    b <- dgx_p4_build_bundle(input_jsonl=input, stage=stage, config=cfg,
                             metadata=list(slug=slug), tiered_max_tokens=tiered)
    job <- dgx_p4_submit(b, time=SUBMIT_TIME)
    saveRDS(job, file.path(OUTPUT_DIR, paste0(job$run_id,"-job.rds")))
    cat(sprintf("Submitted %s: slurm=%s run_id=%s\n", slug, job$slurm_job_id, job$run_id))
  }
  st <- poll(job, slug)
  if (st$slurm_state != "COMPLETED") cli::cli_abort("{slug} fallita: {st$slurm_state}")
  dgx_p4_collect(job, dest=OUTPUT_DIR)
  p <- file.path(OUTPUT_DIR, job$run_id, "predictions.jsonl"); stopifnot(file.exists(p)); p
}

# STAGE 1
preds1 <- run_stage("stage1", INPUT_S1, "f2-eval-s1")
# STAGE 2 input (con guard is_zero_timepoint) + STAGE 2
input_s2 <- "analysis/input/p4-f2-eval-stage2-input.jsonl"
Sys.setenv(STAGE1_PREDS_PATH=preds1, OUT_JSONL=input_s2, CHUNK_SIZE="50")
source("analysis/p4-beta-stage2-build-input.R", local=new.env())
preds2 <- run_stage("stage2", input_s2, "f2-eval-s2", tiered=TRUE)

# EVAL
g <- readRDS("analysis/p4-output/f2-eval-gold.rds")
p1 <- jsonlite::stream_in(file(preds1), verbose=FALSE, simplifyVector=FALSE)
p2 <- jsonlite::stream_in(file(preds2), verbose=FALSE, simplifyVector=FALSE)
schema1 <- mean(vapply(p1, function(r) !is.null(r$parsed_json), logical(1)))
schema2 <- mean(vapply(p2, function(r) !is.null(r$parsed_json), logical(1)))
s2r <- list()
for (rec in p2) { pj <- rec$parsed_json; if (is.null(pj)||is.null(pj$replicate_groups)) next
  for (rg in pj$replicate_groups) { role <- as.character(rg$primary_role %||% NA_character_)
    for (sid in as.character(rg$sample_ids %||% character(0))) s2r[[sid]] <- role } }
g$pred_role <- vapply(g$geo, function(x){ v<-s2r[[x]]; if(is.null(v)) NA_character_ else v}, character(1))
g$pred_binary <- design_role_to_binary(g$pred_role)
bm <- eval_binary_accuracy(g$gold_binary, g$pred_binary)
cat(sprintf("\n=== BENCHMARK SCALATO (n_gold=%d) ===\n", nrow(g)))
cat(sprintf("schema s1=%.1f%% s2=%.1f%%\n", 100*schema1, 100*schema2))
cat(sprintf("Binary accuracy: %.2f%% (n_eval=%d) | sens=%.1f%% spec=%.1f%% f1=%.3f\n",
            100*bm$accuracy, bm$n, 100*bm$sensitivity, 100*bm$specificity, bm$f1))
cat("Confusion (gold x pred):\n"); print(table(gold=g$gold_binary, pred=g$pred_binary, useNA="ifany"))

# error analysis: errori per studio
g$correct <- !is.na(g$gold_binary) & !is.na(g$pred_binary) & g$gold_binary==g$pred_binary
err <- g[!is.na(g$gold_binary) & (is.na(g$pred_binary) | !g$correct), ]
cat(sprintf("\nErrori/non-predetti: %d / %d evaluable\n", nrow(err), sum(!is.na(g$gold_binary))))
cat("Errori per studio (top):\n")
print(head(sort(table(err$series), decreasing=TRUE), 15))
cat("\nErrori per gold design_role_v3:\n"); print(sort(table(err$design_role_v3), decreasing=TRUE))

saveRDS(list(g=g, bm=bm, schema1=schema1, schema2=schema2, err=err,
             s1_preds=preds1, s2_preds=preds2),
        file.path(OUTPUT_DIR, paste0(format(Sys.time(),"%Y%m%dT%H%M%SZ"),"-f2-eval-run.rds")))
write.csv(err[,c("geo","series","design_role_v3","gold_binary","pred_role","pred_binary","string")],
          "analysis/p4-output/f2-eval-errors.csv", row.names=FALSE)
cat("\nSalvato eval RDS + f2-eval-errors.csv\n=== EVAL RUN COMPLETE ===\n")
