# analysis/audit/2026-07-06-name-cleanup-smoke-submit.R
# Smoke gate name-cleanup (path batch DGX) — BUILD + SUBMIT.
# Costruisce il bundle name_cleanup dal gold e lo sottomette alla DGX.
# Lo stato (job + gold con expected_id + candidates) è salvato per l'eval.
suppressMessages(devtools::load_all("."))
library(cli)

gold <- utils::read.csv("analysis/audit/name-cleanup-gold.csv", stringsAsFactors = FALSE)
cli_alert_info("Gold: {nrow(gold)} righe ({sum(!gold$is_canary)} mislabel + {sum(gold$is_canary)} canary)")

# expected_id per riga (risoluzione deterministica del canonical atteso)
env <- simulomicsr:::.load_ontology_dicts()
gold$expected_id <- vapply(seq_len(nrow(gold)), function(i) {
  r <- simulomicsr:::.resolve_canonical_to_id(gold$expected_canonical[i], gold$kind[i], env)
  r$resolved_id %||% NA_character_
}, character(1))
stopifnot(all(!is.na(gold$expected_id)))  # gold già validato: tutti STRONG

# candidates + member_metadata per il builder input jsonl
cand <- tibble::tibble(cluster_id = gold$record_id, name = gold$current_label,
                       kind = gold$kind, k = 1L, top_theme = NA_character_,
                       role = ifelse(gold$is_canary, "canary", "candidate"))
member <- setNames(as.list(gold$member_metadata), gold$record_id)

jsonl <- "analysis/audit/name-cleanup-smoke-input.jsonl"
simulomicsr:::.build_name_cleanup_input_jsonl(cand, member, jsonl)
cli_alert_success("Input jsonl scritto: {jsonl} ({nrow(cand)} record)")

# bundle stage name_cleanup + submit DGX (path batch)
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(jsonl, stage = "name_cleanup", config = cfg)
cli_alert_success("Bundle {bundle$run_id} ({bundle$record_count} record, stage {bundle$stage})")

job <- dgx_p4_submit(bundle, time = "02:00:00", config = cfg)
cli_alert_success("SUBMIT OK — run_id {job$run_id} slurm_job {job$slurm_job_id}")

saveRDS(list(job = job, gold = gold, cand = cand, bundle = bundle),
        "analysis/audit/name-cleanup-smoke-state.rds")
cli_alert_info("Stato salvato: analysis/audit/name-cleanup-smoke-state.rds")
cli_alert_info("Poll: dgx_p4_status(readRDS('analysis/audit/name-cleanup-smoke-state.rds')$job)")
