#!/usr/bin/env Rscript
# p4-stage2-eval-final.R --- Eval finale di α stage2 cs25 vs mini-gold v5.
#
# 1. Merge dei 3 result α stage2 (main + rescue1 + rescue2, versioni
#    *-recovered.rds con heuristic patch applicato) in alpha-stage2-cs25-final.rds.
# 2. Eval binary accuracy (control/treated) e design_kind contro mini-gold v5.
# 3. Salva analysis/p4-output/alpha-stage2-cs25-eval.rds.

suppressPackageStartupMessages({
  library(jsonlite)
  devtools::load_all(".", quiet = TRUE)
})

stopifnot(getwd() == "/home/user/simulomicsr")

# ----------------------------------------------------------------------------
# 1. Merge 3 result -> canonical
# ----------------------------------------------------------------------------
main <- readRDS("analysis/p4-output/alpha-stage2-cs25-safe-result-recovered.rds")
res1 <- readRDS("analysis/p4-output/alpha-stage2-cs25-rescue-result-recovered.rds")
res2 <- readRDS("analysis/p4-output/alpha-stage2-cs25-rescue2-result-recovered.rds")

cat("=== Source counts ===\n")
cat(sprintf("  main:    %4d valid + %4d errors\n",
            nrow(main$predictions), nrow(main$errors)))
cat(sprintf("  rescue1: %4d valid + %4d errors\n",
            nrow(res1$predictions), nrow(res1$errors)))
cat(sprintf("  rescue2: %4d valid + %4d errors\n",
            nrow(res2$predictions), nrow(res2$errors)))

# Merge: i records di main$errors che sono valid in res1$predictions sono stati
# recuperati. Ogni record_id deve apparire UNA volta nel canonical.
add_source <- function(df, src) {
  if (nrow(df) == 0) return(df)
  df$source <- src
  df
}

main$predictions <- add_source(main$predictions, "primary")
main$errors      <- add_source(main$errors,      "primary")
res1$predictions <- add_source(res1$predictions, "rescue_8192")
res1$errors      <- add_source(res1$errors,      "rescue_8192")
res2$predictions <- add_source(res2$predictions, "rescue_32k")
res2$errors      <- add_source(res2$errors,      "rescue_32k")

# Per ogni record_id, prendi il "miglior" risultato (priorita: rescue2 > rescue1 > main).
# Logica: i rescue contengono SOLO i record che erano errors nei prev. Quindi
# l'ultimo che lo contiene VALID e' la fonte canonical.

bind_safe <- function(...) {
  dfs <- list(...)
  dfs <- dfs[vapply(dfs, function(d) !is.null(d) && nrow(d) > 0, logical(1))]
  if (length(dfs) == 0) return(NULL)
  # Allinea colonne
  all_cols <- unique(unlist(lapply(dfs, colnames)))
  dfs <- lapply(dfs, function(d) {
    for (cn in setdiff(all_cols, colnames(d))) {
      d[[cn]] <- if (cn == "applied_patches") vector("list", nrow(d)) else NA
    }
    d[, all_cols, drop = FALSE]
  })
  do.call(rbind, dfs)
}

all_pred <- bind_safe(main$predictions, res1$predictions, res2$predictions)
all_err  <- bind_safe(main$errors,      res1$errors,      res2$errors)

# Per ogni record_id, mantieni la entry da source piu' "ultima" tra i predictions.
# Per gli errors, mantieni la entry rimasta dopo che NON e' apparsa in alcun predictions successivo.
priority <- c(primary = 1, rescue_8192 = 2, rescue_32k = 3)
all_pred$priority <- priority[all_pred$source]
all_pred <- all_pred[order(all_pred$record_id, -all_pred$priority), ]
all_pred_canonical <- all_pred[!duplicated(all_pred$record_id), ]
all_pred_canonical$priority <- NULL

# Errors canonical = record_id mai apparsi in predictions canonical
err_remaining <- all_err[!all_err$record_id %in% all_pred_canonical$record_id, ]
err_remaining <- err_remaining[!duplicated(err_remaining$record_id, fromLast = TRUE), ]

stopifnot(length(intersect(all_pred_canonical$record_id, err_remaining$record_id)) == 0)
total_canonical <- nrow(all_pred_canonical) + nrow(err_remaining)

cat(sprintf("\n=== Canonical merge ===\n"))
cat(sprintf("  predictions: %d (validity %.3f%%)\n",
            nrow(all_pred_canonical),
            100 * nrow(all_pred_canonical) / total_canonical))
cat(sprintf("  errors:      %d\n", nrow(err_remaining)))
cat(sprintf("  total:       %d / 8546\n", total_canonical))

# Source breakdown
cat("\n=== Source breakdown predictions canonical ===\n")
print(table(all_pred_canonical$source))

# Save canonical merged
final <- list(
  predictions = all_pred_canonical,
  errors      = err_remaining,
  summary     = list(
    total_records      = total_canonical,
    valid              = nrow(all_pred_canonical),
    invalid            = nrow(err_remaining),
    schema_validity    = nrow(all_pred_canonical) / total_canonical,
    by_source          = table(all_pred_canonical$source),
    merged_at          = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
)
saveRDS(final, "analysis/p4-output/alpha-stage2-cs25-final.rds")
cat("\n[saved] analysis/p4-output/alpha-stage2-cs25-final.rds\n")

# ----------------------------------------------------------------------------
# 2. Eval mini-gold v5
# ----------------------------------------------------------------------------
mg <- read.csv("inst/extdata/p35c-minigold-reviewed-v5.csv", stringsAsFactors = FALSE)
cat(sprintf("\n=== Mini-gold v5: %d samples in %d GSE ===\n",
            nrow(mg), length(unique(mg$series_id))))

preds <- final$predictions

# Estrai series_id canonical da parsed_json. Bug fix 2026-05-10: per record
# chunked, parsed_json$series_id e' stato sovrascritto col record_id (es.
# "GSE183194#1of2") da dgx_p4_collect() che passava `series_id = rid` a
# parse_stage2_response(). Strip del suffix "#NofM" qui per ottenere il
# canonical series_id (compatibile col mini-gold v5).
preds$series_canonical <- vapply(preds$parsed_json, function(p) {
  sid <- p$series_id %||% NA_character_
  sub("#.*$", "", sid)
}, character(1))

# Lookup function: per ogni geo_accession + series, trova il primary_role
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

mg$primary_role_pred <- NA_character_
mg$design_kind_pred  <- NA_character_
for (i in seq_len(nrow(mg))) {
  out <- predict_role_for_gsm(mg$geo_accession[i], mg$series_id[i])
  mg$primary_role_pred[i] <- out[["role"]]
  mg$design_kind_pred[i]  <- out[["design_kind"]]
}

mg$pred_binary <- design_role_to_binary(mg$primary_role_pred)
mg$gold_binary <- mg$design_role_gold

cat("\n=== Coverage ===\n")
cat(sprintf("Samples con prediction (role non-NA): %d / %d (%.0f%%)\n",
            sum(!is.na(mg$pred_binary)), nrow(mg),
            100 * mean(!is.na(mg$pred_binary))))

# 3. Binary accuracy
cat("\n=== Binary accuracy (control/treated) ===\n")
all_acc <- eval_binary_accuracy(mg$gold_binary, mg$pred_binary)
cat(sprintf("Overall: n=%d, accuracy=%.3f, sensitivity=%.3f, specificity=%.3f, f1=%.3f\n",
            all_acc$n, all_acc$accuracy %||% NA, all_acc$sensitivity %||% NA,
            all_acc$specificity %||% NA, all_acc$f1 %||% NA))

cat("\nPer tier:\n")
for (t in unique(mg$tier)) {
  ix <- mg$tier == t
  acc_t <- eval_binary_accuracy(mg$gold_binary[ix], mg$pred_binary[ix])
  cat(sprintf("  %-4s : n=%d, accuracy=%.3f\n",
              t, acc_t$n, acc_t$accuracy %||% NA))
}

# 4. design_kind accuracy per-GSE
cat("\n=== design_kind exact match per GSE ===\n")
gse_dk <- aggregate(design_kind_gold ~ series_id, data = mg, FUN = function(x) x[1])
gse_dk$design_kind_pred <- vapply(gse_dk$series_id, function(g) {
  rows <- which(preds$series_canonical == g)
  if (length(rows) == 0L) return(NA_character_)
  dks <- vapply(rows, function(r) preds$parsed_json[[r]]$design_kind %||% NA_character_,
                character(1))
  dks <- dks[!is.na(dks)]
  if (length(dks) == 0L) return(NA_character_)
  names(sort(table(dks), decreasing = TRUE))[1L]
}, character(1))
gse_dk$match <- gse_dk$design_kind_gold == gse_dk$design_kind_pred &
                !is.na(gse_dk$design_kind_pred)
cat(sprintf("design_kind match: %d / %d (%.0f%%)\n",
            sum(gse_dk$match, na.rm = TRUE), nrow(gse_dk),
            100 * mean(gse_dk$match, na.rm = TRUE)))
print(gse_dk)

# 5. Salva eval object
eval_out <- list(
  canonical_summary = final$summary,
  minigold_table    = mg,
  binary_overall    = all_acc,
  binary_per_tier   = lapply(setNames(unique(mg$tier), unique(mg$tier)),
                              function(t) eval_binary_accuracy(
                                mg$gold_binary[mg$tier == t],
                                mg$pred_binary[mg$tier == t]
                              )),
  design_kind_per_gse = gse_dk
)
saveRDS(eval_out, "analysis/p4-output/alpha-stage2-cs25-eval.rds")
cat("\n[saved] analysis/p4-output/alpha-stage2-cs25-eval.rds\n")

# 6. Acceptance check Task 22
cat("\n=== Acceptance check Plan Task 22 ===\n")
cat(sprintf("Schema validity rate: %.2f%% (req >= 95%%) -> %s\n",
            100 * final$summary$schema_validity,
            ifelse(final$summary$schema_validity >= 0.95, "PASS ✓", "FAIL ✗")))
cat(sprintf("Binary accuracy:      %.2f%% (target >= 95%%, fallback [80, 95) investigativo)\n",
            100 * (all_acc$accuracy %||% 0)))
acc_val <- all_acc$accuracy %||% 0
band <- if (acc_val >= 0.95) {
  "TARGET ✓"
} else if (acc_val >= 0.80) {
  "INVESTIGATIVO"
} else {
  "DEBUG"
}
cat(sprintf("                       -> %s\n", band))

# Coverage diagnostic: sample senza prediction (role NA)
cat("\n=== Coverage diagnostic: sample senza prediction ===\n")
no_pred <- mg[is.na(mg$pred_binary), ]
if (nrow(no_pred) > 0) {
  miss_by_gse <- table(no_pred$series_id)
  cat("Samples senza prediction per GSE:\n")
  print(miss_by_gse)
  cat("\nRagioni possibili:\n")
  for (gse in names(miss_by_gse)) {
    in_canon_pred <- gse %in% preds$series_canonical
    in_canon_err  <- any(grepl(paste0("^", gse, "(#|$)"), final$errors$record_id))
    n_chunks_pred <- sum(preds$series_canonical == gse, na.rm = TRUE)
    cat(sprintf("  %s: in_predictions=%s (%d chunks), in_errors=%s\n",
                gse, in_canon_pred, n_chunks_pred, in_canon_err))
  }
}
