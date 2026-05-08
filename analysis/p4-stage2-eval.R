#!/usr/bin/env Rscript
# p4-stage2-eval.R --- Eval di alpha stage2 vs mini-gold v5 (Task 22 step 22.4).
#
# Run dopo che dgx_p4_collect() ha popolato analysis/p4-output/<run_id>/.
# Salva analysis/p4-output/alpha-stage2-result.rds (oggetto canonico) e
# stampa un riassunto delle metriche di acceptance del plan Task 22.
#
# Stato 2026-05-08: skeleton non ancora eseguito (Task 22 PARKED).
# Include post-hoc schema validation (necessaria con disable_guided_decoding).
# Eseguibile su predictions parziali (1340/6652) per pre-eval dei chunk gia'
# generati nei job 19801-19803.

suppressPackageStartupMessages({
  devtools::load_all(".")  # picks up new prompts.py changes irrelevant here
  library(jsonlite)
})

JOB_RDS <- "analysis/p4-bundles/alpha-stage2-job.rds"
stopifnot(file.exists(JOB_RDS))
job <- readRDS(JOB_RDS)

# 1) Collect remote predictions (idempotent rsync + parse)
cfg <- dgx_config()
result <- dgx_p4_collect(job)
saveRDS(result, "analysis/p4-output/alpha-stage2-result.rds")

cat("=== Collect summary ===\n")
print(result$summary)
cat("Predictions rows (parse-OK):", nrow(result$predictions),
    "  Errors rows:", nrow(result$errors), "\n")

# 1b) Post-hoc schema validation. dgx_p4_collect's `valid_schema` only
# tracks JSON parsability (true if json.loads success). Without guided
# decoding (alpha 2026-05-08), the parsed JSON may violate schema (missing
# required, wrong enum, etc.) — re-validate against stage2.v2 strict schema.
schema_path <- system.file("schemas", "study_design.stage2.v2.json",
                           package = "simulomicsr")
validator <- compile_schema(schema_path)

result$predictions$schema_v2_valid <- vapply(result$predictions$parsed_json,
  function(p) {
    if (is.null(p)) return(FALSE)
    res <- tryCatch(validate_json(p, validator), error = function(e) NULL)
    isTRUE(res$valid)
  }, logical(1))

n_parse_ok <- nrow(result$predictions)
n_schema_ok <- sum(result$predictions$schema_v2_valid)
n_total <- nrow(result$predictions) + nrow(result$errors)

cat(sprintf("Parse-OK rate:      %d/%d = %.2f%%\n",
            n_parse_ok, n_total, 100 * n_parse_ok / n_total))
cat(sprintf("Strict schema rate: %d/%d = %.2f%%\n",
            n_schema_ok, n_total, 100 * n_schema_ok / n_total))

valid_rate <- n_schema_ok / n_total

# Filter for downstream analysis to strict-schema-valid rows only
preds <- result$predictions[result$predictions$schema_v2_valid, , drop = FALSE]
cat("Strict-valid predictions for downstream eval:", nrow(preds), "\n")

# 2) Mini-gold v5: 100 sample-level entries spanning 16 GSE
mg_path <- system.file("extdata", "p35c-minigold-reviewed-v5.csv",
                       package = "simulomicsr")
mg <- read.csv(mg_path, stringsAsFactors = FALSE)
cat("\nMini-gold v5: ", nrow(mg), " samples in ",
    length(unique(mg$series_id)), " GSE\n", sep = "")

# 3) Per ogni sample del mini-gold, lookup in predictions del suo series_id
#    (potrebbe esserci 1 record o N chunk). All'interno del record, cerca
#    quale replicate_group contiene il geo_accession e prendi primary_role.
# Helper: estrai (record_id, series_id_canonical) e parsed_json
preds$series_canonical <- vapply(preds$parsed_json, function(p) {
  p$series_id %||% NA_character_
}, character(1))

predict_role_for_gsm <- function(gsm, gse_canonical) {
  rows <- which(preds$series_canonical == gse_canonical)
  if (length(rows) == 0L) return(c(role = NA_character_, design_kind = NA_character_,
                                   group_label = NA_character_))
  for (r in rows) {
    pj <- preds$parsed_json[[r]]
    rgs <- pj$replicate_groups
    if (is.null(rgs) || length(rgs) == 0L) next
    for (g in rgs) {
      sids <- g$sample_ids
      if (!is.null(sids) && gsm %in% unlist(sids)) {
        return(c(
          role        = g$primary_role %||% NA_character_,
          design_kind = pj$design_kind %||% NA_character_,
          group_label = g$label_human %||% NA_character_
        ))
      }
    }
  }
  c(role = NA_character_, design_kind = NA_character_, group_label = NA_character_)
}

mg$primary_role_pred <- NA_character_
mg$design_kind_pred  <- NA_character_
mg$group_label_pred  <- NA_character_

for (i in seq_len(nrow(mg))) {
  out <- predict_role_for_gsm(mg$geo_accession[i], mg$series_id[i])
  mg$primary_role_pred[i] <- out[["role"]]
  mg$design_kind_pred[i]  <- out[["design_kind"]]
  mg$group_label_pred[i]  <- out[["group_label"]]
}

mg$pred_binary <- design_role_to_binary(mg$primary_role_pred)
mg$gold_binary <- mg$design_role_gold  # gia' "treated"/"control"

# 4) Coverage check
cat("\n=== Coverage ===\n")
cat("Samples with prediction (role non-NA):",
    sum(!is.na(mg$pred_binary)), "/", nrow(mg), "\n")
cat("Per tier:\n")
print(addmargins(table(
  tier = mg$tier,
  has_pred = !is.na(mg$pred_binary)
)))

# 5) Binary accuracy
cat("\n=== Binary accuracy (control/treated) ===\n")
all_acc <- eval_binary_accuracy(mg$gold_binary, mg$pred_binary)
cat("Overall:\n")
print(all_acc[c("n", "accuracy", "sensitivity", "specificity", "f1")])

cat("\nPer tier:\n")
for (t in c("easy", "hard")) {
  ix <- mg$tier == t
  acc_t <- eval_binary_accuracy(mg$gold_binary[ix], mg$pred_binary[ix])
  cat(sprintf("  %-4s : n=%d, accuracy=%.3f\n", t, acc_t$n,
              acc_t$accuracy %||% NA_real_))
}

# 6) design_kind accuracy (per-GSE)
cat("\n=== design_kind accuracy (per-GSE) ===\n")
gse_dk <- aggregate(design_kind_gold ~ series_id, data = mg, FUN = function(x) x[1])
gse_dk$design_kind_pred <- vapply(gse_dk$series_id, function(g) {
  rows <- which(preds$series_canonical == g)
  if (length(rows) == 0L) return(NA_character_)
  # If chunked, pick most-frequent design_kind across chunks (mode)
  dks <- vapply(rows, function(r) preds$parsed_json[[r]]$design_kind %||% NA_character_,
                character(1))
  dks <- dks[!is.na(dks)]
  if (length(dks) == 0L) return(NA_character_)
  names(sort(table(dks), decreasing = TRUE))[1L]
}, character(1))
gse_dk$match <- gse_dk$design_kind_gold == gse_dk$design_kind_pred &
  !is.na(gse_dk$design_kind_pred)
cat("design_kind exact match per GSE:",
    sum(gse_dk$match, na.rm = TRUE), "/", nrow(gse_dk), "\n")
print(gse_dk)

# 7) Salva eval object
eval_out <- list(
  collect_summary = result$summary,
  schema_valid_rate = valid_rate,
  minigold_eval = list(
    samples_table  = mg,
    overall_acc    = all_acc,
    per_gse_design = gse_dk
  )
)
saveRDS(eval_out, "analysis/p4-output/alpha-stage2-eval.rds")

cat("\n=== Acceptance check (Task 22 plan) ===\n")
cat(sprintf("Schema valid rate: %.2f%% (req >= 95%%) -> %s\n",
            100 * valid_rate, ifelse(valid_rate >= 0.95, "PASS", "FAIL")))
cat(sprintf("Binary accuracy:   %.2f%% (target >= 95%%, fallback investigativo [80%%, 95%%))\n",
            100 * (all_acc$accuracy %||% 0)))
