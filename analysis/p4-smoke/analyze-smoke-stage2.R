#!/usr/bin/env Rscript
# analyze-smoke-stage2.R --- analizza risultati di un smoke test stage2.
#
# Uso:
#   Rscript analysis/p4-smoke/analyze-smoke-stage2.R --run-id <run_id>
#
# Output:
#   - completed records / total
#   - schema validity rate (post-hoc)
#   - throughput (tok/s e rec/min)
#   - eventuali errori
#   - predictions saved in analysis/p4-output/<run_id>/predictions.jsonl

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(k, def = NULL) {
  i <- which(args == paste0("--", k))
  if (length(i) == 0L) return(def)
  args[i + 1L]
}
run_id <- get_arg("run-id")
slurm  <- get_arg("slurm")

if (is.null(run_id) && is.null(slurm)) {
  cat("Uso: --run-id <id> oppure --slurm <id>\n")
  quit("no", status = 1)
}

cfg <- dgx_config()

# Recupero job da bundle (deve esistere localmente)
bundles <- fs::dir_ls("analysis/p4-bundles", type = "directory")
if (!is.null(run_id)) {
  match <- grep(run_id, bundles, value = TRUE)
} else {
  job_files <- fs::dir_ls("analysis/p4-bundles", glob = "*/job.rds", recurse = TRUE)
  jobs_all <- lapply(job_files, readRDS)
  i <- which(vapply(jobs_all, function(j) j$slurm_job_id == slurm, logical(1)))
  if (length(i) == 0L) stop("Job ", slurm, " not found.")
  match <- dirname(job_files[i])
}
if (length(match) == 0L) stop("Bundle non trovato.")
bundle_dir <- match[1L]
job <- readRDS(fs::path(bundle_dir, "job.rds"))

cat("=== analyze-smoke-stage2 ===\n")
cat("run_id:", job$run_id, "\n")
cat("slurm: ", job$slurm_job_id, "\n")

# Collect (rsync remoto -> locale)
cat("\n[1/3] rsync remote run dir...\n")
collected <- tryCatch(
  dgx_p4_collect(job, dest = "analysis/p4-output"),
  error = function(e) {
    cat("ERROR collect:", conditionMessage(e), "\n")
    NULL
  }
)

if (is.null(collected)) {
  # Manual rsync as fallback
  remote_run <- paste0(cfg$remote_root, "/runs/", job$run_id, "/")
  local_run  <- fs::path("analysis/p4-output", job$run_id)
  fs::dir_create(local_run, recurse = TRUE)
  simulomicsr:::.dgx_rsync(cfg, paste0(local_run, "/"), remote_run, "pull")
  cat("Listing local run dir:\n")
  print(fs::dir_ls(local_run))
  quit("no", status = 0)
}

cat("\n[2/3] Summary:\n")
print(collected$summary)

cat("\n[3/3] Predictions detail:\n")
n_valid <- nrow(collected$predictions)
n_err   <- nrow(collected$errors)
cat("  valid (parsed_json non-null):", n_valid, "\n")
cat("  invalid                     :", n_err, "\n")
cat("  total                       :", n_valid + n_err, "\n")

if (n_valid > 0) {
  out_chars <- nchar(collected$predictions$raw_output)
  cat("  raw_output chars: median=", as.integer(median(out_chars)),
      " min=", min(out_chars), " max=", max(out_chars), "\n", sep="")
}

if (n_err > 0) {
  cat("\n--- ERROR samples (first 3) ---\n")
  for (i in seq_len(min(3, n_err))) {
    cat("record_id:", collected$errors$record_id[i], "\n")
    cat("raw_output (first 200c):\n", substr(collected$errors$raw_output[i], 1, 200), "\n\n")
  }
}

# Throughput from slurm.out (microbatch lines)
slurm_out <- fs::dir_ls(collected$run_dir, glob = "*.out")
if (length(slurm_out)) {
  lines <- readLines(slurm_out[1L])
  mb_lines <- grep("microbatch.*in.*s", lines, value = TRUE)
  if (length(mb_lines)) {
    cat("\n--- microbatch timing (last 5) ---\n")
    cat(tail(mb_lines, 5), sep = "\n")
  }
  err_lines <- grep("(?i)(error|stall|deadlock|recompile_limit|Traceback)", lines, value = TRUE)
  if (length(err_lines)) {
    cat("\n--- WARNING/ERROR lines from slurm.out ---\n")
    cat(head(err_lines, 10), sep = "\n")
  }
}
