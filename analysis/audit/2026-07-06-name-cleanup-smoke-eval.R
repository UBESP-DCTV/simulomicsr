# analysis/audit/2026-07-06-name-cleanup-smoke-eval.R
# Smoke gate name-cleanup (path batch DGX) — COLLECT + EVAL.
# Da lanciare dopo che il job DGX è COMPLETED.
suppressMessages(devtools::load_all("."))
library(cli)

st <- readRDS("analysis/audit/name-cleanup-smoke-state.rds")
gold <- st$gold; cand <- st$cand

cli_h2("Collect predictions dalla DGX")
res <- dgx_p4_collect(st$job)
preds <- res$predictions
cli_alert_info("Predictions collezionate: {nrow(preds)} (valid_schema {sum(preds$valid_schema)})")

# predictions_by_id: record_id -> parsed_json (list canonical_name/kind/confidence/evidence)
predictions_by_id <- setNames(preds$parsed_json, preds$record_id)

# current_ids: risolvi la label ATTUALE (sbagliata per i mislabel, giusta per i canary)
env <- simulomicsr:::.load_ontology_dicts()
current_ids <- vapply(seq_len(nrow(gold)), function(i) {
  r <- simulomicsr:::.resolve_canonical_to_id(gold$current_label[i], gold$kind[i], env)
  r$resolved_id %||% NA_character_
}, character(1))
names(current_ids) <- gold$record_id

side <- simulomicsr:::.assemble_side_table_from_predictions(cand, current_ids, predictions_by_id, env)
side <- merge(side, gold[, c("record_id","expected_id","is_canary","expected_canonical")],
              by.x = "cluster_id", by.y = "record_id", all.x = TRUE)
side$correct <- !is.na(side$new_id) & side$new_id == side$expected_id

cli_h2("Side-table smoke")
print(side[, c("cluster_id","old_label","llm_proposed_name","new_id","expected_id","action","correct")],
      row.names = FALSE)

# --- Metriche ---
mis <- side[!side$is_canary, ]; can <- side[side$is_canary, ]
recall  <- mean(mis$correct)                                   # mislabel recuperati
ov      <- mis[mis$action == "override", ]
precision <- if (nrow(ov)) mean(ov$correct) else NA_real_      # override corretti / override
false_alarm <- mean(can$action == "flag_review")              # canary "cambiati" (0 atteso)
noop_canary <- mean(can$action == "noop")

cli_h2("METRICHE SMOKE")
cli_dl(list(
  "Mislabel (n)"          = nrow(mis),
  "  Recall (recuperati)" = sprintf("%.1f%% (%d/%d)", 100*recall, sum(mis$correct), nrow(mis)),
  "  Override (n)"        = nrow(ov),
  "  Precision (override giusti)" = if (is.na(precision)) "n/a" else sprintf("%.1f%%", 100*precision),
  "Canary (n)"            = nrow(can),
  "  False alarm (flag_review)"  = sprintf("%.1f%% (%d/%d)", 100*false_alarm, sum(can$action=="flag_review"), nrow(can)),
  "  Noop (concordi)"     = sprintf("%.1f%%", 100*noop_canary)
))
gate_ok <- recall >= 0.7 && false_alarm == 0
cli_alert_success(if (gate_ok) "GATE PASS (recall>=70% + 0 canary false alarm)" else "GATE DA RIVEDERE")

saveRDS(side, "analysis/audit/name-cleanup-smoke-sidetable.rds")
utils::write.csv(side, "analysis/audit/name-cleanup-smoke-sidetable.csv", row.names = FALSE)
