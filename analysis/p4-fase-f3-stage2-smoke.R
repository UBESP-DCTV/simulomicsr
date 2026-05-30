#!/usr/bin/env Rscript
# p4-fase-f3-stage2-smoke.R --- RED ALERT FASE F3: smoke Stadio 2 pre-fullrun.
#
# Scopo (sessione 11, validate-before-fullrun): validare lo Stadio 2 sul
# MATERIALE REALE del fullrun F3 --- cioe' l'input gia' costruito a partire dal
# master Stadio 1 v2 CONGELATO (508.037 record, recuperati inclusi) --- senza
# rifare lo Stadio 1. Differenza chiave vs benchmark sessione 9: la' lo Stadio 1
# veniva rifatto da zero; qui parte dal master congelato che daremo al fullrun.
#
# Sottoinsieme: i 72 studi del gold design-aware (756 campioni, f2-eval-gold.csv)
# sono tutti dentro il bacino v2 -> 72 record stage2, 0 chunk. Si misura:
#   - schema validity (risposte JSON ben formate): target ~100%
#   - accuracy binaria vs gold 756 (atteso ~94-96%, benchmark sessione 9)
#
# Config pipeline INVARIATA (uniformity): stage2 tiered_max_tokens, temp=0,
# rep_pen=1.1, microbatch=50. time esplicito 72:00:00 (partition infinite).
# Resume-safe via job RDS. Lanciato in background; harness ri-invoca a fine job.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)   # codice del BRANCH (prompt Stadio 2 EN, D3)
  library(jsonlite)
  library(fs)
})

cfg         <- dgx_config()
OUTPUT_DIR  <- "analysis/p4-output"
INPUT_V2_S2 <- "analysis/input/archs4-human-stage2-input-v2.jsonl"
GOLD_CSV    <- "analysis/p4-output/f2-eval-gold.csv"
SMOKE_INPUT <- "analysis/input/p4-f3-stage2-smoke-input.jsonl"
SLUG        <- "f3-stage2-smoke"
SUBMIT_TIME <- "72:00:00"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(INPUT_V2_S2), file.exists(GOLD_CSV))

# === GATE pre-submit: il prompt Stadio 2 del branch e' in inglese (D3)? ===
# Se fallisce, il bundle spedirebbe un prompt diverso da quello validato.
# Il testo EN non dipende dal model arg (usato altrove nella funzione); passo
# il modello di produzione solo per soddisfare la firma.
s2_prompt <- simulomicsr:::.stage2_system_prompt(
  "mistralai/Mistral-Small-3.2-24B-Instruct-2506")
if (!grepl("RNA-seq experimental design", s2_prompt, fixed = TRUE) ||
    !grepl("replicate_group", s2_prompt, fixed = TRUE)) {
  stop("Prompt Stadio 2 del branch non riconosciuto come EN (D3). ",
       "Verifica devtools::load_all e branch attivo.")
}
cat("GATE pre-submit OK: prompt Stadio 2 EN (D3) attivo.\n")

# === Costruzione sottoinsieme: 72 record degli studi gold ===
g     <- read.csv(GOLD_CSV, stringsAsFactors = FALSE)
gser  <- unique(g$series)
lines <- readLines(INPUT_V2_S2, warn = FALSE)
ser   <- vapply(lines, function(L) fromJSON(L, simplifyVector = FALSE)$series_id,
                character(1L))
sel   <- ser %in% gser
writeLines(lines[sel], SMOKE_INPUT)
cat(sprintf("Smoke input: %d record (su %d studi gold) -> %s\n",
            sum(sel), length(gser), SMOKE_INPUT))
stopifnot(sum(sel) > 0L)

# === Helper DGX (resume-safe, verbatim da p4-fase-f2-eval-run.R) ===
.sacct_final_state <- function(job) {
  cmd <- paste0("sacct -j ", job$slurm_job_id,
                " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(job$config, cmd),
                  error = function(e) list(stdout = ""))
  s <- trimws(res$stdout %||% ""); if (!nzchar(s)) "TERMINATED" else s
}
poll <- function(job, lbl, poll_sec = 60L, max_polls = 720L) {
  for (i in seq_len(max_polls)) {
    st <- dgx_p4_status(job); state <- st$slurm_state
    if (identical(state, "TERMINATED")) { state <- .sacct_final_state(job); st$slurm_state <- state }
    cat(sprintf("  [%s] %s %s\n", format(Sys.time(), "%H:%M:%S"), lbl, state))
    if (state %in% c("COMPLETED", "FAILED", "TIMEOUT", "CANCELLED", "NODE_FAIL", "OUT_OF_MEMORY"))
      return(st)
    Sys.sleep(poll_sec)
  }
  cli::cli_abort("timeout {lbl}")
}
find_job <- function(slug) {
  f <- list.files(OUTPUT_DIR, pattern = paste0(".*-", slug, "-.*-job\\.rds$"), full.names = TRUE)
  if (length(f) == 0L) NULL else f[which.max(file.info(f)$mtime)]
}

# === Submit / resume stage2 ===
ex <- find_job(SLUG)
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
preds2 <- file.path(OUTPUT_DIR, job$run_id, "predictions.jsonl")
stopifnot(file.exists(preds2))

# === EVAL: schema + accuracy binaria vs gold 756 ===
p2 <- jsonlite::stream_in(file(preds2), verbose = FALSE, simplifyVector = FALSE)
schema2 <- mean(vapply(p2, function(r) !is.null(r$parsed_json), logical(1L)))

s2r <- list()
for (rec in p2) {
  pj <- rec$parsed_json
  if (is.null(pj) || is.null(pj$replicate_groups)) next
  for (rg in pj$replicate_groups) {
    role <- as.character(rg$primary_role %||% NA_character_)
    for (sid in as.character(rg$sample_ids %||% character(0))) s2r[[sid]] <- role
  }
}
g$pred_role   <- vapply(g$geo, function(x) { v <- s2r[[x]]; if (is.null(v)) NA_character_ else v }, character(1L))
g$pred_binary <- design_role_to_binary(g$pred_role)
bm <- eval_binary_accuracy(g$gold_binary, g$pred_binary)

cat(sprintf("\n=== F3 STAGE2 SMOKE (n_gold=%d, %d studi) ===\n", nrow(g), length(gser)))
cat(sprintf("schema s2 = %.2f%%\n", 100 * schema2))
cat(sprintf("Binary accuracy: %.2f%% (n_eval=%d) | sens=%.1f%% spec=%.1f%% f1=%.3f\n",
            100 * bm$accuracy, bm$n, 100 * bm$sensitivity, 100 * bm$specificity, bm$f1))
cat("Confusion (gold x pred):\n"); print(table(gold = g$gold_binary, pred = g$pred_binary, useNA = "ifany"))

n_unpred <- sum(!is.na(g$gold_binary) & is.na(g$pred_binary))
cat(sprintf("Campioni gold senza predizione (coverage gap): %d\n", n_unpred))

saveRDS(list(g = g, bm = bm, schema2 = schema2, preds2 = preds2, run_id = job$run_id),
        file.path(OUTPUT_DIR, paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ"), "-f3-stage2-smoke-eval.rds")))
cat("\n=== F3 STAGE2 SMOKE COMPLETE ===\n")
