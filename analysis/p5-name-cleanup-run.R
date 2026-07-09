# analysis/p5-name-cleanup-run.R --- name-cleanup RUN PIENO (path batch DGX, T13).
# Costruisce l'input dai cluster VERI del triage (125 candidati + canary),
# submitta il bundle stage name_cleanup alla DGX, e (in un secondo passo, dopo
# il COMPLETED) fa collect -> assemble side-table -> misura-B.
#
# Prerequisito: un nodo DGX che SCRIVA i log slurm (2026-07-06: poddgx02 rotto,
#   0:53 zero-log; provare poddgx01/03 o dgx_config(nodelist=NULL/altro nodo)).
#
# Uso:
#   Rscript analysis/p5-name-cleanup-run.R triage   # genera il triage CSV da STAGE3 (.build_suspect_triage)
#   Rscript analysis/p5-name-cleanup-run.R submit    # build input + submit
#   Rscript analysis/p5-name-cleanup-run.R eval      # collect + assemble (dopo COMPLETED)
#
# TRIAGE/STAGE3/STAGE2 sono configurabili via env var (default = v7, per
# retrocompat col batch T13 gia' girato); per il ciclo v9 impostare STAGE3 alla
# dir Stadio 3 v9-final e TRIAGE al path del triage v9 generato dall'azione
# `triage` sui cluster v9-pre.
suppressMessages(devtools::load_all("."))
library(cli)
ACTION <- (commandArgs(trailingOnly = TRUE)[1] %||% "submit")

TRIAGE   <- Sys.getenv("TRIAGE", "analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv")
STAGE3   <- Sys.getenv("STAGE3", "analysis/p4-output/20260703T113045Z-stage3-v7-364547a7")
STAGE2   <- Sys.getenv("STAGE2", "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
S1_INPUT <- "analysis/input/archs4-human-stage1-input.jsonl"   # geo_accession -> string
JSONL    <- "analysis/audit/name-cleanup-run-input.jsonl"
STATE    <- "analysis/p4-output/name-cleanup-run-state.rds"
SIDE_RDS <- "analysis/p4-output/name-cleanup-side-table-v1.rds"
FRAG_CSV <- "analysis/p4-output/name-cleanup-fragmentation-v1.csv"

if (ACTION == "triage") {
  # Guard: impedisci il clobber accidentale del CSV di riferimento se TRIAGE
  # non e' esplicitamente impostato via env var.
  if (TRIAGE == "analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv") {
    cli_abort(
      "Azione 'triage': TRIAGE non esplicitamente impostato (valore default). \\
      Non posso sovrascrivere il CSV di riferimento {.file {TRIAGE}}. \\
      Per generare il triage v9, impostare TRIAGE a un path v9-specifico \\
      (es. {.code TRIAGE=analysis/audit/2026-07-09-stage4-popB-coherence-triage-v9.csv}) \\
      e STAGE3 alla dir Stadio 3 v9-final (non ai default). Poi ri-lanciare."
    )
  }

  cli_h1("Name-cleanup — genera triage v9 dai cluster (.build_suspect_triage)")
  cl <- load_stage3(STAGE3)$clusters
  tr <- simulomicsr:::.build_suspect_triage(cl)
  # scrivi solo le righe azionabili (candidate + canary); le skip (cls=vehicle/none,
  # role=NA) le scarterebbe comunque .load_name_cleanup_candidates.
  tr_out <- tr[!is.na(tr$role) & tr$cls != "vehicle/none", , drop = FALSE]
  utils::write.csv(tr_out, TRIAGE, row.names = FALSE)
  cli_alert_success("Triage v9: {nrow(tr_out)} righe azionabili ({sum(tr_out$role=='candidate')} candidate + {sum(tr_out$role=='canary')} canary) su {nrow(cl)} cluster -> {TRIAGE}")

} else if (ACTION == "submit") {
  cli_h1("Name-cleanup RUN — build input + submit")
  cand <- simulomicsr:::.load_name_cleanup_candidates(TRIAGE)
  cli_alert_info("Candidati: {nrow(cand)} ({sum(cand$role=='candidate')} candidate + {sum(cand$role=='canary')} canary)")

  s3 <- load_stage3(STAGE3)
  # current_ids = ID ontologico (agent_id) ESTRATTO dall'anchor_key, NON
  # l'anchor_key completo (kind|ID|tissue|...): .apply_name_cleanup_policy
  # confronta l'ID corrente col resolved_id ontologico che il resolver
  # produce; passare l'anchor_key intero rende identical() sempre FALSE ->
  # noop mai raggiunto -> override/flag_review gonfiati. level/mode dal cluster_id.
  ak_full <- setNames(s3$clusters$anchor_key, s3$clusters$cluster_id)[cand$cluster_id]
  ak_lvl  <- as.integer(sub("^[a-z]+_L([0-9])_.*$", "\\1", cand$cluster_id))
  ak_mode <- sub("^([a-z]+)_L[0-9]_.*$", "\\1", cand$cluster_id)
  current_ids <- setNames(vapply(seq_along(ak_full), function(i)
    extract_anchor_summary(ak_full[i], level = ak_lvl[i], mode = ak_mode[i])$agent_id %||% NA_character_,
    character(1)), cand$cluster_id)

  source("analysis/audit/_gsm-lookup-helper.R")
  rec_env <- build_record_gsm_lookup(STAGE2)

  # gsm_text: solo i GSM membri dei cluster candidati (subset dello Stadio 1 input)
  cli_alert_info("Raccolgo i GSM membri dei candidati...")
  member_gsms <- unique(unlist(lapply(cand$cluster_id, function(cid) {
    recs <- s3$assignments$record_id[s3$assignments$cluster_id == cid]
    unlist(lapply(recs, function(r) get0(r, envir = rec_env, inherits = FALSE)), use.names = FALSE)
  }), use.names = FALSE))
  cli_alert_info("GSM membri distinti: {length(member_gsms)}")

  cli_alert_info("Stream Stadio 1 input per gsm_text (subset)...")
  want <- new.env(hash = TRUE, parent = emptyenv()); for (g in member_gsms) assign(g, TRUE, envir = want)
  gsm_text <- character(0)
  con <- file(S1_INPUT, "r"); on.exit(close(con), add = TRUE)
  repeat {
    ln <- readLines(con, n = 20000L, warn = FALSE); if (!length(ln)) break
    for (l in ln) {
      j <- tryCatch(jsonlite::fromJSON(l, simplifyVector = TRUE), error = function(e) NULL)
      if (is.null(j) || is.null(j$geo_accession)) next
      ga <- as.character(j$geo_accession)
      if (exists(ga, envir = want, inherits = FALSE)) gsm_text[ga] <- as.character(j$string %||% "")
    }
  }
  cli_alert_success("gsm_text raccolti: {length(gsm_text)}/{length(member_gsms)}")

  member <- simulomicsr:::.build_cluster_member_metadata(cand$cluster_id, s3$assignments, rec_env, gsm_text)
  simulomicsr:::.build_name_cleanup_input_jsonl(cand, member, JSONL)
  cli_alert_success("Input jsonl: {JSONL} ({nrow(cand)} record)")

  cfg <- dgx_config()
  bundle <- dgx_p4_build_bundle(JSONL, stage = "name_cleanup", config = cfg)
  job <- dgx_p4_submit(bundle, time = "04:00:00", config = cfg)
  saveRDS(list(job = job, cand = cand, current_ids = current_ids, s3_clusters = s3$clusters), STATE)
  cli_alert_success("SUBMIT OK — run_id {job$run_id} slurm {job$slurm_job_id}. Stato: {STATE}")

} else if (ACTION == "eval") {
  cli_h1("Name-cleanup RUN — collect + assemble")
  st <- readRDS(STATE)
  res <- dgx_p4_collect(st$job)
  predictions_by_id <- setNames(res$predictions$parsed_json, res$predictions$record_id)
  cli_alert_info("Predictions: {nrow(res$predictions)} (valid_schema {sum(res$predictions$valid_schema)})")

  env <- simulomicsr:::.load_ontology_dicts()
  side <- simulomicsr:::.assemble_side_table_from_predictions(st$cand, st$current_ids, predictions_by_id, env)
  saveRDS(side, SIDE_RDS)

  k_by <- setNames(st$s3_clusters$k, st$s3_clusters$cluster_id)
  fr <- simulomicsr:::.measure_fragmentation(side, k_by)
  utils::write.csv(fr, FRAG_CSV, row.names = FALSE)

  cli_h2("Riepilogo side-table")
  cli_dl(list(
    "override"    = sum(side$action == "override"),
    "flag_review" = sum(side$action == "flag_review"),
    "noop"        = sum(side$action == "noop"),
    "keep"        = sum(side$action == "keep"),
    "frammenti (entita' con >=2 cluster)" = nrow(fr),
    "max k_merged_est" = if (nrow(fr)) max(fr$k_merged_est) else 0L
  ))
  cli_alert_success("Side-table: {SIDE_RDS} | frammentazione: {FRAG_CSV}")
  cli_alert_info("Prossimo: review umana del diff (override before->after) + finding + closeout.")
} else {
  cli_abort("Azione sconosciuta: {ACTION}. Usa 'triage', 'submit' o 'eval'.")
}
