#!/usr/bin/env Rscript
# phase3-h1-eval.R --- Eval H1 mini-gold v5 per ADR-0010 Phase 3.
#
# Usa la logica di analysis/p4-stage2-eval-final.R (sezione 2: mini-gold)
# applicata ai predictions di un singolo smoke run (e.g. job 20085 con
# input data-raw/p4-stage2-rerun-minigold.jsonl). Output: binary accuracy
# vs gold per applicare HARD gate H1 (>= 93%).
#
# Uso:
#   Rscript analysis/p4-smoke/phase3-h1-eval.R --slurm 20085
#   Rscript analysis/p4-smoke/phase3-h1-eval.R --run-id 20260510T...-p3-minigold-h1-009503

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(jsonlite)
})

`%||%` <- function(a, b) if (is.null(a)) b else a

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(k) {
  i <- which(args == paste0("--", k))
  if (length(i) == 0L) return(NULL)
  args[i + 1L]
}
slurm  <- get_arg("slurm")
run_id <- get_arg("run-id")
stopifnot(!is.null(slurm) || !is.null(run_id))

# Localizza bundle/job
job_files <- fs::dir_ls("analysis/p4-bundles", glob = "*/job.rds", recurse = TRUE)
jobs_all <- lapply(job_files, readRDS)
i <- if (!is.null(slurm)) {
  which(vapply(jobs_all, function(j) j$slurm_job_id == slurm, logical(1)))
} else {
  which(vapply(jobs_all, function(j) j$run_id == run_id, logical(1)))
}
if (length(i) == 0L) stop("Job non trovato.")
job <- jobs_all[[i]]
cat("=== Phase 3 H1 eval (ADR-0010) ===\n")
cat("run_id:", job$run_id, "\n")
cat("slurm: ", job$slurm_job_id, "\n\n")

# Collect
cat("[1/4] dgx_p4_collect...\n")
collected <- dgx_p4_collect(job, dest = "analysis/p4-output")
preds <- collected$predictions
errs  <- collected$errors

cat(sprintf("  predictions: %d\n", nrow(preds)))
cat(sprintf("  errors:      %d\n", nrow(errs %||% data.frame())))

# Strip suffix #NofM dal series_id (vedi commento in p4-stage2-eval-final.R)
preds$series_canonical <- vapply(preds$parsed_json, function(p) {
  sid <- p$series_id %||% NA_character_
  sub("#.*$", "", sid)
}, character(1))

# Mini-gold
cat("\n[2/4] Load mini-gold v5...\n")
mg <- read.csv("inst/extdata/p35c-minigold-reviewed-v5.csv", stringsAsFactors = FALSE)
cat(sprintf("  samples: %d in %d GSE\n", nrow(mg), length(unique(mg$series_id))))

predict_role_for_gsm <- function(gsm, gse_canonical) {
  rows <- which(preds$series_canonical == gse_canonical)
  if (length(rows) == 0L)
    return(c(role = NA_character_, design_kind = NA_character_))
  for (r in rows) {
    pj  <- preds$parsed_json[[r]]
    rgs <- pj$replicate_groups
    if (is.null(rgs) || length(rgs) == 0L) next
    for (g in rgs) {
      sids <- g$sample_ids
      if (!is.null(sids) && gsm %in% unlist(sids)) {
        return(c(
          role        = g$primary_role %||% NA_character_,
          design_kind = pj$design_kind %||% NA_character_
        ))
      }
    }
  }
  c(role = NA_character_, design_kind = NA_character_)
}

cat("\n[3/4] Predict roles per sample...\n")
mg$primary_role_pred <- NA_character_
mg$design_kind_pred  <- NA_character_
for (i in seq_len(nrow(mg))) {
  out <- predict_role_for_gsm(mg$geo_accession[i], mg$series_id[i])
  mg$primary_role_pred[i] <- out[["role"]]
  mg$design_kind_pred[i]  <- out[["design_kind"]]
}

mg$pred_binary <- design_role_to_binary(mg$primary_role_pred)
mg$gold_binary <- mg$design_role_gold

cov_pct <- 100 * mean(!is.na(mg$pred_binary))
cat(sprintf("  Coverage (role non-NA): %d / %d (%.0f%%)\n",
            sum(!is.na(mg$pred_binary)), nrow(mg), cov_pct))

cat("\n[4/4] Binary accuracy (control/treated) vs gold\n")
all_acc <- eval_binary_accuracy(mg$gold_binary, mg$pred_binary)
cat(sprintf("=== H1 GATE ===\n"))
cat(sprintf("Overall: n=%d, accuracy=%.3f, sensitivity=%.3f, specificity=%.3f, f1=%.3f\n",
            all_acc$n,
            all_acc$accuracy    %||% NA,
            all_acc$sensitivity %||% NA,
            all_acc$specificity %||% NA,
            all_acc$f1          %||% NA))

threshold <- 0.93
verdict <- if (!is.null(all_acc$accuracy) && all_acc$accuracy >= threshold) {
  "PASS"
} else if (!is.null(all_acc$accuracy) && all_acc$accuracy >= 0.80) {
  "INVESTIGATIVO (PASS investigativo plan, sotto target)"
} else {
  "FAIL"
}
cat(sprintf("\nH1 threshold = %.2f -> %s\n", threshold, verdict))
cat(sprintf("Baseline alpha (v0.10.0 + 3-pass): 0.933\n"))

# Per tier
cat("\nPer tier:\n")
for (t in unique(mg$tier)) {
  ix <- mg$tier == t
  acc_t <- eval_binary_accuracy(mg$gold_binary[ix], mg$pred_binary[ix])
  cat(sprintf("  %-4s : n=%d, accuracy=%.3f\n",
              t, acc_t$n, acc_t$accuracy %||% NA))
}

# Save eval result
out_path <- fs::path("analysis/p4-output", paste0("phase3-h1-eval-", job$slurm_job_id, ".rds"))
saveRDS(list(
  job        = job,
  predictions = preds,
  minigold   = mg,
  accuracy   = all_acc,
  verdict    = verdict,
  threshold  = threshold,
  evaluated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
), out_path)
cat(sprintf("\n[saved] %s\n", out_path))
