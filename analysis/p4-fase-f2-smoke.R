#!/usr/bin/env Rscript
# p4-fase-f2-smoke.R --- RED ALERT FASE F2-smoke: 100-sample gate DGX
#
# Scopo (sessione 9): validare il rebuild Stage 0 v2 + i prompt nuovi
# (D1b molecule_hint Stadio 1 + D3 traduzione EN Stadio 2) su uno smoke da
# 100 sample PRIMA del fullrun F2 (sessione 10, validate-before-fullrun).
#
# Due track (decisione utente 2026-05-28: "entrambi"):
#   TRACK 1 - mini-gold (accuracy gate):
#     100 sample fissi da p35c-minigold-reviewed-v5-formatB.csv (con gold).
#     end-to-end stage1 -> stage2 -> accuracy binaria vs design_role_gold_v3.
#     NB: il mini-gold NON ha molecule_ch1 -> il prompt la omette
#     (prompts.py:49). Quindi l'accuracy NON testa l'effetto molecule_hint;
#     testa che i prompt nuovi (resto D1b + EN stage2) non degradino l'accuracy.
#   TRACK 2 - bacino v2 (schema/distribution gate):
#     100 random stratificati per quartile nchar(string) dal nuovo bacino
#     archs4-human-stage1-input-v2.jsonl (508.037 record), CON molecule_ch1.
#     end-to-end stage1 -> stage2 -> schema validity + design_kind distribution.
#     Questo e' l'unico track che vede il materiale reale del fullrun F2 +
#     l'effetto reale di molecule_hint.
#
# Gate criteri:
#   - schema_s1 >= 99% (target 100%), entrambi i track
#   - schema_s2 >= 99%, entrambi i track
#   - accuracy binaria mini-gold >= 96.7% baseline (STOP se < 93%)
#   - design_kind bacino v2 sana (case_control + treatment_vs_* presenti)
#
# Config pipeline INVARIATA (uniformity: temp=0, rep_pen=1.1, microbatch=50,
# stage2 tiered_max_tokens). time esplicito 72:00:00 (partition infinite).
#
# Esecuzione: end-to-end sequenziale (s2 dipende da s1). Resume-safe via
# job RDS. Lanciato in background; l'harness ri-invoca a completamento.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)   # codice del BRANCH (prompt D1b + runtime py)
  library(jsonlite)
  library(fs)
})

# === Setup ===
cfg        <- dgx_config()
RUN_BASE   <- format(Sys.time(), "%Y%m%dT%H%M%SZ")
OUTPUT_DIR <- "analysis/p4-output"
INPUT_V2   <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
MINIGOLD   <- "inst/extdata/p35c-minigold-reviewed-v5-formatB.csv"
N_BACINO   <- 100L
SEED_STRAT <- 42L
SUBMIT_TIME <- "72:00:00"   # esplicito dal plan (feedback_dgx_respect_plan_time)
fs::dir_create(OUTPUT_DIR, recurse = TRUE)
fs::dir_create("analysis/input", recurse = TRUE)
fs::dir_create("analysis/audit", recurse = TRUE)

# === GATE pre-submit: il prompt Stadio 1 del branch include molecule_hint? ===
# Se questo fallisce, il bundle spedirebbe il prompt VECCHIO -> smoke invalido.
prompts_py <- system.file("dgx", "python", "prompts.py", package = "simulomicsr")
stopifnot(nzchar(prompts_py))
py_src <- paste(readLines(prompts_py, warn = FALSE), collapse = "\n")
if (!grepl("molecule_hint", py_src, fixed = TRUE)) {
  stop("prompts.py del branch NON contiene 'molecule_hint': bundle userebbe ",
       "il prompt pre-D1b. Verifica devtools::load_all e il branch attivo.")
}
cat("GATE pre-submit OK: prompts.py include molecule_hint (D1b attivo).\n")

# === Helper DGX (copiate verbatim da p4-beta-gate1/gate2, resume-safe) ===
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
    cat(sprintf("  [%s] poll %d/%d %s slurm_state=%s\n",
                format(Sys.time(), "%H:%M:%S"), i, max_polls, stage_label, state))
    if (state %in% c("COMPLETED", "FAILED", "TIMEOUT",
                     "CANCELLED", "NODE_FAIL", "OUT_OF_MEMORY")) {
      return(st)
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

# === Funzione generica per un track end-to-end stage1 -> stage2 ===
# input_s1_path: JSONL stage1 gia' scritto. slug_pref: prefisso slug.
# Ritorna list(preds1_path, preds2_path, t_s1_min, t_s2_min, n_in).
run_track <- function(track, input_s1_path, slug_pref) {
  cat(sprintf("\n========== TRACK %s ==========\n", track))
  n_in <- length(readLines(input_s1_path, warn = FALSE))
  cat(sprintf("Stage1 input: %s (%d record)\n", input_s1_path, n_in))

  # --- STAGE 1 ---
  slug1 <- paste0(slug_pref, "-s1")
  ex1 <- .find_existing_job(slug1)
  if (!is.null(ex1)) {
    job1 <- readRDS(ex1)
    cat(sprintf("Resume stage1: %s (slurm=%s)\n", ex1, job1$slurm_job_id))
  } else {
    b1 <- dgx_p4_build_bundle(input_jsonl = input_s1_path, stage = "stage1",
                              config = cfg, metadata = list(slug = slug1))
    job1 <- dgx_p4_submit(b1, time = SUBMIT_TIME)
    saveRDS(job1, file.path(OUTPUT_DIR, paste0(job1$run_id, "-job.rds")))
    cat(sprintf("Stage1 submitted: slurm=%s run_id=%s\n",
                job1$slurm_job_id, job1$run_id))
  }
  t0 <- Sys.time()
  st1 <- poll_until_done(job1, paste0(track, "/s1"))
  t_s1 <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  if (st1$slurm_state != "COMPLETED")
    cli::cli_abort("Track {track} stage1 fallita: {st1$slurm_state}")
  dgx_p4_collect(job1, dest = OUTPUT_DIR)
  preds1 <- file.path(OUTPUT_DIR, job1$run_id, "predictions.jsonl")
  stopifnot(file.exists(preds1))

  # --- STAGE 2 INPUT BUILD ---
  input_s2 <- file.path("analysis/input",
                        sprintf("p4-f2-smoke-%s-stage2-input.jsonl", track))
  Sys.setenv(STAGE1_PREDS_PATH = preds1, OUT_JSONL = input_s2, CHUNK_SIZE = "50")
  source("analysis/p4-beta-stage2-build-input.R", local = new.env())
  stopifnot(file.exists(input_s2))

  # --- STAGE 2 ---
  slug2 <- paste0(slug_pref, "-s2")
  ex2 <- .find_existing_job(slug2)
  if (!is.null(ex2)) {
    job2 <- readRDS(ex2)
    cat(sprintf("Resume stage2: %s (slurm=%s)\n", ex2, job2$slurm_job_id))
  } else {
    b2 <- dgx_p4_build_bundle(input_jsonl = input_s2, stage = "stage2",
                              config = cfg, metadata = list(slug = slug2),
                              tiered_max_tokens = TRUE)
    job2 <- dgx_p4_submit(b2, time = SUBMIT_TIME)
    saveRDS(job2, file.path(OUTPUT_DIR, paste0(job2$run_id, "-job.rds")))
    cat(sprintf("Stage2 submitted: slurm=%s run_id=%s\n",
                job2$slurm_job_id, job2$run_id))
  }
  t0 <- Sys.time()
  st2 <- poll_until_done(job2, paste0(track, "/s2"))
  t_s2 <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  if (st2$slurm_state != "COMPLETED")
    cli::cli_abort("Track {track} stage2 fallita: {st2$slurm_state}")
  dgx_p4_collect(job2, dest = OUTPUT_DIR)
  preds2 <- file.path(OUTPUT_DIR, job2$run_id, "predictions.jsonl")
  stopifnot(file.exists(preds2))

  list(preds1_path = preds1, preds2_path = preds2,
       t_s1_min = t_s1, t_s2_min = t_s2, n_in = n_in,
       run_id_s1 = job1$run_id, run_id_s2 = job2$run_id)
}

# === Costruzione input TRACK 1 (mini-gold) ===
mg <- read.csv(MINIGOLD, stringsAsFactors = FALSE)
stopifnot(nrow(mg) == 100L,
          all(c("geo_accession", "series_id", "string_formatB",
                "design_role_gold_v3_original") %in% names(mg)))
input_mg <- "analysis/input/p4-f2-smoke-minigold-stage1-input.jsonl"
df_mg <- data.frame(
  record_id        = mg$geo_accession,
  geo_accession    = mg$geo_accession,
  series_id        = mg$series_id,
  string           = mg$string_formatB,
  library_strategy = "RNA-Seq",
  organism         = "Homo sapiens",
  stringsAsFactors = FALSE
)
con <- file(input_mg, "w"); jsonlite::stream_out(df_mg, con, verbose = FALSE); close(con)
cat(sprintf("TRACK minigold input scritto: %d record\n", nrow(df_mg)))

# === Costruzione input TRACK 2 (bacino v2 stratificato per nchar) ===
input_bac <- "analysis/input/p4-f2-smoke-bacinov2-stage1-input.jsonl"
cat("Caricamento jsonl-v2 per stratificazione...\n")
recs <- jsonlite::stream_in(file(INPUT_V2), verbose = FALSE, simplifyVector = TRUE)
cat(sprintf("Caricati %d record dal bacino v2\n", nrow(recs)))
# molecule_ch1 DEVE essere presente nel bacino v2 (F1 lo preserva)
stopifnot("molecule_ch1" %in% names(recs))
nch <- nchar(recs$string)
q   <- quantile(nch, c(0, 0.25, 0.5, 0.75, 1))
stratum <- cut(nch, breaks = q, include.lowest = TRUE, labels = paste0("Q", 1:4))
set.seed(SEED_STRAT)
per_stratum <- as.integer(N_BACINO / 4L)
sample_idx <- unlist(lapply(levels(stratum), function(s) {
  pool <- which(stratum == s)
  sample(pool, min(per_stratum, length(pool)))
}))
cat(sprintf("nchar quartili: Q1=%d Q2=%d Q3=%d Q4=%d Q5=%d\n",
            q[1], q[2], q[3], q[4], q[5]))
cat("Conteggi per stratum:\n"); print(table(stratum[sample_idx]))
# Subset CON molecule_ch1 (fix vs gate2 beta che lo ometteva)
keep_cols <- c("record_id", "geo_accession", "series_id", "string",
               "library_strategy", "organism", "molecule_ch1")
bac <- recs[sample_idx, keep_cols]
# Sanity: molecule_ch1 deve arrivare all'LLM su una quota ragionevole
stopifnot(nrow(bac) == length(sample_idx),
          all(keep_cols %in% names(bac)))
n_mol <- sum(!is.na(bac$molecule_ch1) & nzchar(bac$molecule_ch1))
cat(sprintf("molecule_ch1 non-NA nel subset bacino: %d / %d\n", n_mol, nrow(bac)))
con <- file(input_bac, "w"); jsonlite::stream_out(bac, con, verbose = FALSE); close(con)
cat(sprintf("TRACK bacinov2 input scritto: %d record\n", nrow(bac)))

# === Esecuzione dei due track ===
res_mg  <- run_track("minigold",  input_mg,  "f2-smoke-minigold")
res_bac <- run_track("bacinov2",  input_bac, "f2-smoke-bacinov2")

# === EVAL TRACK 1 (mini-gold): accuracy binaria ===
cat("\n=== EVAL TRACK 1 (mini-gold): accuracy ===\n")
p1_mg <- jsonlite::stream_in(file(res_mg$preds1_path), verbose = FALSE, simplifyVector = FALSE)
p2_mg <- jsonlite::stream_in(file(res_mg$preds2_path), verbose = FALSE, simplifyVector = FALSE)
schema_s1_mg <- mean(vapply(p1_mg, function(r) !is.null(r$parsed_json), logical(1L)))
schema_s2_mg <- mean(vapply(p2_mg, function(r) !is.null(r$parsed_json), logical(1L)))

sample_to_role <- list()
for (rec in p2_mg) {
  pj <- rec$parsed_json
  if (is.null(pj) || is.null(pj$replicate_groups)) next
  for (rg in pj$replicate_groups) {
    role <- as.character(rg$primary_role %||% NA_character_)
    for (sid in as.character(rg$sample_ids %||% character(0))) sample_to_role[[sid]] <- role
  }
}
mg$primary_role_pred <- vapply(mg$geo_accession, function(g) {
  v <- sample_to_role[[as.character(g)]]; if (is.null(v)) NA_character_ else v
}, character(1L))
mg$gold_binary <- design_role_to_binary(mg$design_role_gold_v3_original)
mg$pred_binary <- design_role_to_binary(mg$primary_role_pred)
n_eval  <- sum(!is.na(mg$gold_binary) & !is.na(mg$pred_binary))
n_corr  <- sum(mg$gold_binary == mg$pred_binary, na.rm = TRUE)
acc_mg  <- if (n_eval > 0) n_corr / n_eval else NA_real_
bin_metrics <- eval_binary_accuracy(mg$gold_binary, mg$pred_binary)
cat(sprintf("schema s1=%.2f%% s2=%.2f%% | accuracy=%.2f%% (%d/%d) sens=%.1f%% spec=%.1f%%\n",
            100*schema_s1_mg, 100*schema_s2_mg, 100*acc_mg, n_corr, n_eval,
            100*bin_metrics$sensitivity, 100*bin_metrics$specificity))

# === EVAL TRACK 2 (bacino v2): schema + design_kind ===
cat("\n=== EVAL TRACK 2 (bacino v2): schema + design_kind ===\n")
p1_bac <- jsonlite::stream_in(file(res_bac$preds1_path), verbose = FALSE, simplifyVector = FALSE)
p2_bac <- jsonlite::stream_in(file(res_bac$preds2_path), verbose = FALSE, simplifyVector = FALSE)
schema_s1_bac <- mean(vapply(p1_bac, function(r) !is.null(r$parsed_json), logical(1L)))
schema_s2_bac <- mean(vapply(p2_bac, function(r) !is.null(r$parsed_json), logical(1L)))
all_dk <- vapply(p2_bac, function(r) {
  v <- r$parsed_json$design_kind
  if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)
}, character(1L))
dk_dist <- as.data.frame(table(design_kind = all_dk, useNA = "ifany"), stringsAsFactors = FALSE)
dk_dist <- dk_dist[order(-dk_dist$Freq), ]
cat(sprintf("schema s1=%.2f%% s2=%.2f%%\n", 100*schema_s1_bac, 100*schema_s2_bac))
cat("Distribuzione design_kind:\n"); print(dk_dist)

# === Salvataggio eval RDS ===
eval_rds <- file.path(OUTPUT_DIR, paste0(RUN_BASE, "-p4-f2-smoke-eval.rds"))
saveRDS(list(
  run_base = RUN_BASE,
  minigold = list(res = res_mg, schema_s1 = schema_s1_mg, schema_s2 = schema_s2_mg,
                  accuracy = acc_mg, n_eval = n_eval, n_correct = n_corr,
                  bin_metrics = bin_metrics, mg = mg),
  bacinov2 = list(res = res_bac, schema_s1 = schema_s1_bac, schema_s2 = schema_s2_bac,
                  dk_dist = dk_dist, n_molecule_nonNA = n_mol)
), eval_rds)
cat("\nEval RDS:", eval_rds, "\n")

# === Sintesi markdown F2-smoke-eval.md ===
md <- c(
  "# F2-smoke eval --- 100-sample gate (RED ALERT FASE F2, sessione 9)",
  "",
  sprintf("> Data: %s. Branch p5-llm-anchor-classification-audit.", RUN_BASE),
  "> Config invariata (temp=0, rep_pen=1.1, microbatch=50, s2 tiered_max_tokens).",
  "> Prompt: D1b molecule_hint (Stadio 1) + D3 EN (Stadio 2). load_all branch.",
  "",
  "## Track 1 --- mini-gold (accuracy gate)",
  sprintf("- Schema validity: s1 %.2f%%, s2 %.2f%%", 100*schema_s1_mg, 100*schema_s2_mg),
  sprintf("- Accuracy binaria: **%.2f%%** (%d/%d evaluable)", 100*acc_mg, n_corr, n_eval),
  sprintf("- Sensitivity %.1f%% / Specificity %.1f%%",
          100*bin_metrics$sensitivity, 100*bin_metrics$specificity),
  sprintf("- Baseline alpha cs50 = 96.7%%. Soglia STOP = 93%%."),
  sprintf("- run_id s1=%s s2=%s", res_mg$run_id_s1, res_mg$run_id_s2),
  "- Limite: mini-gold NON ha molecule_ch1 -> accuracy non testa molecule_hint.",
  "",
  "## Track 2 --- bacino v2 (schema/distribution gate)",
  sprintf("- 100 random stratificati nchar dal jsonl-v2 (508.037), seed=%d", SEED_STRAT),
  sprintf("- molecule_ch1 non-NA: %d / %d", n_mol, N_BACINO),
  sprintf("- Schema validity: s1 %.2f%%, s2 %.2f%%", 100*schema_s1_bac, 100*schema_s2_bac),
  sprintf("- run_id s1=%s s2=%s", res_bac$run_id_s1, res_bac$run_id_s2),
  "- design_kind distribution:",
  paste0("  - ", dk_dist$design_kind, ": ", dk_dist$Freq),
  ""
)

# === GATE DECISION ===
schema_ok <- min(schema_s1_mg, schema_s2_mg, schema_s1_bac, schema_s2_bac) >= 0.99
acc_pass  <- !is.na(acc_mg) && acc_mg >= 0.967
acc_stop  <- !is.na(acc_mg) && acc_mg < 0.93
cat("\n=== F2-SMOKE GATE DECISION ===\n")
if (acc_stop) {
  verdict <- sprintf("STOP: accuracy %.2f%% < 93%% -> revisione prompt D1b necessaria.", 100*acc_mg)
} else if (schema_ok && acc_pass) {
  verdict <- sprintf("PASS: schema >=99%% (min %.2f%%), accuracy %.2f%% >= 96.7%%.",
                     100*min(schema_s1_mg, schema_s2_mg, schema_s1_bac, schema_s2_bac), 100*acc_mg)
} else {
  verdict <- sprintf("BORDERLINE: schema_ok=%s accuracy=%.2f%% (>=93%% ma <96.7%% o schema <99%%). Decisione utente.",
                     schema_ok, 100*acc_mg)
}
cat(verdict, "\n")
md <- c(md, "## Verdetto gate", paste0("- ", verdict), "",
        "Gate pre-F2-fullrun: questo risultato + decisione utente esplicita.")
writeLines(md, "analysis/audit/F2-smoke-eval.md")
cat("\nSintesi scritta: analysis/audit/F2-smoke-eval.md\n")
cat("\n=== F2-SMOKE COMPLETE ===\n")
