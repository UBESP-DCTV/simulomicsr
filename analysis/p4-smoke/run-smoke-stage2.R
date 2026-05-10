#!/usr/bin/env Rscript
# run-smoke-stage2.R --- smoke test parametrizzato Task 22 stage2 (2026-05-08).
#
# Uso:
#   Rscript analysis/p4-smoke/run-smoke-stage2.R \
#       --slug T2-vanilla-1gpu \
#       --workers 1 --gpus 1 --time 01:00:00 \
#       --input data-raw/p4-stage2-mini50.jsonl \
#       --gen-overrides '{"enable_prefix_caching": false}'
#
# Output: oggetto job stampato; logs accodati a analysis/p4-bundles/smoke-stage2-runs.log
#
# Strategia:
#   1. devtools::load_all() del pacchetto (renv-aware)
#   2. dgx_p4_build_bundle(stage="stage2") con input ridotto
#   3. patch generation.json del bundle con --gen-overrides JSON
#   4. render template SLURM smoke parametrizzato
#   5. rsync bundle, runtime python e SLURM script
#   6. sbatch via SSH

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

# Parser commandArgs minimale (--key value pairs)
parse_cli <- function(defaults) {
  args <- commandArgs(trailingOnly = TRUE)
  out <- defaults
  i <- 1L
  while (i <= length(args)) {
    k <- sub("^--", "", args[i])
    if (i + 1L > length(args)) stop("Missing value for --", k)
    v <- args[i + 1L]
    if (!k %in% names(defaults)) stop("Unknown flag --", k)
    if (is.integer(defaults[[k]])) v <- as.integer(v)
    out[[k]] <- v
    i <- i + 2L
  }
  out
}

opts <- parse_cli(list(
  slug      = "smoke-stage2",
  workers   = 1L,
  gpus      = 1L,
  cpus      = 16L,
  mem       = "100G",
  time      = "01:00:00",
  input     = "data-raw/p4-stage2-mini50.jsonl",
  `gen-overrides` = "{}",
  nodelist  = "poddgx02",
  tiered    = "FALSE"
))
# Compat: rinomina 'gen-overrides' -> gen_overrides
opts$gen_overrides <- opts[["gen-overrides"]]; opts[["gen-overrides"]] <- NULL
opts$tiered <- as.logical(opts$tiered)

if (opts$gpus < opts$workers) {
  stop("--gpus deve essere >= --workers (uno per worker)")
}

cat("=== smoke-stage2 ===\n")
cat("slug:    ", opts$slug, "\n")
cat("input:   ", opts$input, "\n")
cat("workers: ", opts$workers, "  gpus: ", opts$gpus, "\n", sep = "")
cat("time:    ", opts$time, "\n")
cat("overrides: ", opts$gen_overrides, "\n")

stopifnot(file.exists(opts$input))

# --- 1. config (con nodelist override opzionale)
cfg <- if (identical(opts$nodelist, "NULL")) {
  dgx_config(nodelist = NULL)
} else {
  dgx_config(nodelist = opts$nodelist)
}

# --- 2. build bundle stage2
cat("\n[1/6] Building bundle...\n")
bundle <- dgx_p4_build_bundle(
  input_jsonl = opts$input,
  stage       = "stage2",
  config      = cfg,
  metadata    = list(slug = opts$slug),
  bundle_dir_root = "analysis/p4-bundles",
  tiered_max_tokens = opts$tiered
)
cat("  run_id: ", bundle$run_id, "\n")
cat("  records:", bundle$record_count, "\n")

# --- 3. patch generation.json con overrides
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
overrides <- jsonlite::fromJSON(opts$gen_overrides, simplifyVector = FALSE)
if (length(overrides) > 0L) {
  cat("\n[2/6] Patching generation.json with overrides:\n")
  for (k in names(overrides)) {
    cat("    ", k, " = ", deparse(overrides[[k]]), "\n", sep = "")
    gen[[k]] <- overrides[[k]]
  }
  json_txt <- jsonlite::toJSON(gen, auto_unbox = TRUE, pretty = TRUE)
  json_txt <- gsub('("temperature"\\s*:\\s*)(\\d+)(\\s*[,\\n}])',
                   "\\1\\2.0\\3", json_txt)
  writeLines(json_txt, gen_path)
} else {
  cat("\n[2/6] No overrides.\n")
}

# --- 4. render SLURM smoke template
cat("\n[3/6] Rendering SLURM smoke template...\n")
tmpl_path <- "analysis/p4-smoke/smoke-stage2-template.sh"
stopifnot(file.exists(tmpl_path))
tmpl <- paste(readLines(tmpl_path, warn = FALSE), collapse = "\n")
nodelist_directive <- if (is.null(cfg$nodelist)) "" else
  paste0("#SBATCH --nodelist=", cfg$nodelist)
rendered <- simulomicsr:::.dgx_render_slurm_template(
  tmpl,
  run_id              = bundle$run_id,
  run_id_short        = simulomicsr:::.dgx_run_id_short(bundle$run_id),
  user                = cfg$login_user,
  time                = opts$time,
  mail_user           = cfg$mail_user,
  cpus                = as.character(opts$cpus),
  mem                 = opts$mem,
  gpus                = as.character(opts$gpus),
  workers             = as.character(opts$workers),
  nodelist_directive  = nodelist_directive
)
rendered_path <- fs::path(bundle$bundle_dir, "run_p4.rendered.sh")
writeLines(rendered, rendered_path)

# --- 5. rsync bundle + runtime python
cat("\n[4/6] rsync bundle + runtime python...\n")
remote_bundle  <- paste0(cfg$remote_root, "/bundles/", bundle$run_id, "/")
remote_run     <- paste0(cfg$remote_root, "/runs/",    bundle$run_id, "/")
remote_runtime <- paste0(cfg$remote_root, "/runtime/python/")
res_mkdir <- simulomicsr:::.dgx_ssh(cfg, paste0(
  "mkdir -p ", shQuote(remote_bundle), " ", shQuote(remote_run), " ", shQuote(remote_runtime)
))
stopifnot(res_mkdir$status == 0L)
simulomicsr:::.dgx_rsync(cfg,
  local_path  = paste0(bundle$bundle_dir, "/"),
  remote_path = remote_bundle, direction = "push")
py_local <- system.file("dgx", "python", package = "simulomicsr")
simulomicsr:::.dgx_rsync(cfg,
  local_path  = paste0(py_local, "/"),
  remote_path = remote_runtime, direction = "push",
  flags = c("-az", "--exclude=__pycache__"))

# --- 6. sbatch
cat("\n[5/6] sbatch...\n")
remote_script <- paste0(remote_bundle, "run_p4.rendered.sh")
res_sbatch <- simulomicsr:::.dgx_ssh(cfg,
  paste0("sbatch ", shQuote(remote_script)))
if (res_sbatch$status != 0L) {
  cat("  STDERR:\n", res_sbatch$stderr, "\n", sep = "")
  stop("sbatch failed")
}
m <- regmatches(res_sbatch$stdout,
                regexpr("Submitted batch job (\\d+)", res_sbatch$stdout))
slurm_id <- sub("Submitted batch job ", "", m)
cat("  slurm job id:", slurm_id, "\n")

# --- 7. log
log_path <- "analysis/p4-bundles/smoke-stage2-runs.log"
log_line <- sprintf(
  "%s | slurm=%s | run_id=%s | slug=%s | workers=%d gpus=%d | overrides=%s",
  format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  slurm_id, bundle$run_id, opts$slug,
  opts$workers, opts$gpus, opts$gen_overrides
)
cat(log_line, "\n", file = log_path, append = TRUE)

cat("\n[6/6] Done.\n")
cat("  slurm:  ", slurm_id, "\n")
cat("  run_id: ", bundle$run_id, "\n")
cat("  poll:   Rscript analysis/p4-smoke/poll-smoke-stage2.R --slurm ", slurm_id, " --run-id ", bundle$run_id, "\n", sep="")

# Save R object for later poll/collect
job <- structure(list(
  run_id = bundle$run_id,
  slurm_job_id = slurm_id,
  stage = "stage2",
  bundle_dir = bundle$bundle_dir,
  rendered_slurm = rendered_path,
  submitted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  config = cfg
), class = "simulomicsr_dgx_job")
saveRDS(job, fs::path(bundle$bundle_dir, "job.rds"))
cat("  job.rds saved\n")
