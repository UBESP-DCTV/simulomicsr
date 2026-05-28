#!/usr/bin/env Rscript
# p4-fase-f2-smoke-counterproof-IT.R --- CONTROPROVA root-cause F2-smoke
#
# Ipotesi (systematic-debugging Fase 3): il calo accuracy mini-gold
# 98% (beta GATE #1, prompt Stadio 2 IT) -> 92.93% (F2-smoke, prompt
# Stadio 2 EN, D3) e' causato dal prompt Stadio 2 in INGLESE.
#
# Esperimento a VARIABILE SINGOLA:
#   - stage1 preds: RIUSATE identiche da F2-smoke (D1b+D4 attivi, EN stage1)
#     run_id 20260528T202554Z-f2-smoke-minigold-s1-80bedb
#   - stage2 input: RIUSATO identico (prompt-independent)
#   - UNICA differenza vs F2-smoke EN: .stage2_system_prompt() ora IT
#     (working tree reverted a 0e20495^). Tutto il resto invariato.
#
# Verdetto:
#   - se accuracy -> ~98% e i 5 GSM regrediti tornano 'treated'
#     => prompt Stadio 2 EN (D3) e' causa radice CONFERMATA.
#   - se accuracy resta ~93% => causa NON e' il prompt Stadio 2 (sarebbe
#     upstream stage1 D1b/D4) => ipotesi smentita, investigare stage1.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)   # working tree: stage2 prompt IT (reverted)
  library(jsonlite); library(fs)
})

cfg        <- dgx_config()
OUTPUT_DIR <- "analysis/p4-output"
MINIGOLD   <- "inst/extdata/p35c-minigold-reviewed-v5-formatB.csv"
INPUT_S2   <- "analysis/input/p4-f2-smoke-minigold-stage2-input.jsonl"  # riuso identico
EN_S2_PREDS<- "analysis/p4-output/20260528T202817Z-f2-smoke-minigold-s2-0c2407/predictions.jsonl"
REGRESSED  <- c("GSM5553041","GSM5553062","GSM5553064","GSM5553066","GSM6050371")
SUBMIT_TIME<- "72:00:00"
stopifnot(file.exists(INPUT_S2), file.exists(EN_S2_PREDS))

# GATE: confermo che il bundle spedira' il prompt Stadio 2 IT
p_now <- simulomicsr:::.stage2_system_prompt("mistralai/Mistral-Small-3.2-24B-Instruct-2506")
if (!grepl("REGOLA 1", p_now, fixed = TRUE) || grepl("You are an expert", p_now, fixed = TRUE))
  stop("Prompt Stadio 2 NON e' IT: revert non applicato. STOP controprova.")
cat("GATE OK: .stage2_system_prompt() e' IT (REGOLA 1 presente, no 'You are an expert').\n")

.sacct_final_state <- function(job) {
  cmd <- paste0("sacct -j ", job$slurm_job_id, " --format=State -n -P 2>/dev/null | head -1")
  res <- tryCatch(simulomicsr:::.dgx_ssh(job$config, cmd), error = function(e) list(stdout = ""))
  state <- trimws(res$stdout %||% ""); if (!nzchar(state)) "TERMINATED" else state
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

# === Submit stage2 IT (riuso input identico) ===
slug2 <- "f2-smoke-minigold-IT-s2"
ex2 <- .find_existing_job(slug2)
if (!is.null(ex2)) {
  job2 <- readRDS(ex2); cat(sprintf("Resume: %s\n", ex2))
} else {
  b2 <- dgx_p4_build_bundle(input_jsonl = INPUT_S2, stage = "stage2", config = cfg,
                            metadata = list(slug = slug2), tiered_max_tokens = TRUE)
  # verifica che il prompt.txt del bundle sia IT
  bp <- readLines(file.path(b2$bundle_dir, "prompt.txt"), warn = FALSE)
  stopifnot(any(grepl("REGOLA 1", bp, fixed = TRUE)), !any(grepl("You are an expert", bp, fixed = TRUE)))
  cat("Bundle prompt.txt confermato IT.\n")
  job2 <- dgx_p4_submit(b2, time = SUBMIT_TIME)
  saveRDS(job2, file.path(OUTPUT_DIR, paste0(job2$run_id, "-job.rds")))
  cat(sprintf("Submitted IT-s2: slurm=%s run_id=%s\n", job2$slurm_job_id, job2$run_id))
}
st2 <- poll_until_done(job2, "IT-s2")
if (st2$slurm_state != "COMPLETED") cli::cli_abort("IT-s2 fallita: {st2$slurm_state}")
dgx_p4_collect(job2, dest = OUTPUT_DIR)
it_preds <- file.path(OUTPUT_DIR, job2$run_id, "predictions.jsonl")
stopifnot(file.exists(it_preds))

# === Eval helper: da predictions stage2 -> accuracy binaria vs gold ===
mg <- read.csv(MINIGOLD, stringsAsFactors = FALSE)
eval_preds <- function(path, label) {
  p2 <- jsonlite::stream_in(file(path), verbose = FALSE, simplifyVector = FALSE)
  schema <- mean(vapply(p2, function(r) !is.null(r$parsed_json), logical(1L)))
  s2r <- list()
  for (rec in p2) {
    pj <- rec$parsed_json; if (is.null(pj) || is.null(pj$replicate_groups)) next
    for (rg in pj$replicate_groups) {
      role <- as.character(rg$primary_role %||% NA_character_)
      for (sid in as.character(rg$sample_ids %||% character(0))) s2r[[sid]] <- role
    }
  }
  pred <- vapply(mg$geo_accession, function(g) { v <- s2r[[as.character(g)]]; if (is.null(v)) NA_character_ else v }, character(1L))
  gold_b <- design_role_to_binary(mg$design_role_gold_v3_original)
  pred_b <- design_role_to_binary(pred)
  n_eval <- sum(!is.na(gold_b) & !is.na(pred_b)); n_corr <- sum(gold_b == pred_b, na.rm = TRUE)
  acc <- if (n_eval > 0) n_corr / n_eval else NA_real_
  list(label = label, schema = schema, acc = acc, n_eval = n_eval, n_corr = n_corr,
       role = setNames(pred, mg$geo_accession), pred_b = setNames(pred_b, mg$geo_accession),
       gold_b = setNames(gold_b, mg$geo_accession))
}
en <- eval_preds(EN_S2_PREDS, "EN (F2-smoke)")
it <- eval_preds(it_preds,    "IT (controprova)")

cat("\n=== CONFRONTO EN vs IT (stessa stage1, stesso input s2) ===\n")
cat(sprintf("EN: schema %.1f%% | accuracy %.2f%% (%d/%d)\n", 100*en$schema, 100*en$acc, en$n_corr, en$n_eval))
cat(sprintf("IT: schema %.1f%% | accuracy %.2f%% (%d/%d)\n", 100*it$schema, 100*it$acc, it$n_corr, it$n_eval))

cat("\n=== I 5 GSM regrediti: primary_role EN vs IT (gold = treated) ===\n")
for (g in REGRESSED) {
  cat(sprintf("  %s: gold_bin=%s | EN role=%s (bin=%s) | IT role=%s (bin=%s)\n",
              g, en$gold_b[[g]], en$role[[g]], en$pred_b[[g]], it$role[[g]], it$pred_b[[g]]))
}

# quanti dei 5 tornano corretti in IT
fixed5 <- sum(vapply(REGRESSED, function(g) !is.na(it$pred_b[[g]]) && !is.na(it$gold_b[[g]]) &&
                       it$pred_b[[g]] == it$gold_b[[g]], logical(1L)))
cat(sprintf("\nDei 5 GSM regrediti, corretti in IT: %d/5\n", fixed5))

# === Verdetto ===
cat("\n=== VERDETTO CONTROPROVA ===\n")
if (!is.na(it$acc) && it$acc >= 0.967 && fixed5 >= 4) {
  cat(sprintf("CONFERMATO: IT recupera accuracy %.2f%% (>=96.7%%) e %d/5 GSM tornano corretti.\n", 100*it$acc, fixed5))
  cat("=> Causa radice = prompt Stadio 2 in INGLESE (D3). Revert a IT giustificato.\n")
} else if (!is.na(it$acc) && it$acc <= en$acc + 0.01) {
  cat(sprintf("SMENTITO: IT accuracy %.2f%% ~ EN %.2f%%. Il prompt Stadio 2 NON e' la causa.\n", 100*it$acc, 100*en$acc))
  cat("=> Investigare upstream: stage1 D1b/D4 hanno cambiato i fatti in ingresso a Stadio 2.\n")
} else {
  cat(sprintf("PARZIALE: IT %.2f%% vs EN %.2f%%, %d/5 GSM corretti. Interpretare con utente.\n",
              100*it$acc, 100*en$acc, fixed5))
}

saveRDS(list(en = en, it = it, fixed5 = fixed5, it_run_id = job2$run_id),
        file.path(OUTPUT_DIR, paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ"), "-f2-counterproof-IT-eval.rds")))
cat("\n=== CONTROPROVA COMPLETE ===\n")
