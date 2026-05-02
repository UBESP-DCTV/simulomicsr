# Build fixture mini Stadio 2: 3 GSE stratificati per design_kind.
# 3 GSE confermati con utente 2026-05-02:
#   - GSE145028 (n=12, knockdown_panel — shRNA non-targeting / targeting)
#   - GSE145941 (n=8,  treatment_vs_untreated — 10 Gy irradiation vs 0 Gy)
#   - GSE191240 (n=9,  treatment_vs_untreated — A. fumigatus stim su HUVEC)
#
# Source: full xlsx (NON P2 dev set, che ha 1 sample/GSE).
# Idempotente: cache LLM riusa i risultati esistenti.
#
# Run: source("data-raw/build-stage2-fixtures.R")
# Pre-req: OPENAI_API_KEY in .Renviron.local

library(simulomicsr)
library(here)
library(dplyr)

`%||%` <- function(x, y) if (is.null(x)) y else x

candidate_gse <- c("GSE145028", "GSE145941", "GSE191240")

samples <- simulomicsr:::read_samples_input(
  here("data-raw", "relevant_sample_classified.xlsx")
)

cache <- simulomicsr:::cache_init(here("analysis", "cache"), namespace = "stage1")
out_dir <- here("inst", "extdata", "stage2-fixtures-mini")
geo_cache_dir <- file.path(out_dir, ".geo-cache")
fs::dir_create(out_dir, recurse = TRUE)
fs::dir_create(geo_cache_dir, recurse = TRUE)

for (gse in candidate_gse) {
  rows <- samples %>% filter(series_id == gse)
  if (nrow(rows) < 2L) {
    message("skipping ", gse, " (n_samples=", nrow(rows), ")")
    next
  }
  message("=== ", gse, " (n=", nrow(rows), ") ===")
  facts_list <- lapply(seq_len(nrow(rows)), function(i) {
    classify_sample(
      sample_string = rows$string[[i]],
      geo_accession = rows$geo_accession[[i]],
      series_id = rows$series_id[[i]],
      provider = "openai", model = "gpt-5.5",
      cache = cache
    )
  })
  validity <- vapply(facts_list, function(f) is.null(f$.invalid_reason), logical(1))
  message("  validated: ", sum(validity), "/", nrow(rows))

  if (sum(validity) / nrow(rows) < 0.80) {
    stop(sprintf(
      "ESCALATE: validity rate %.1f%% < 80%% per %s — regressione schema?",
      100 * sum(validity) / nrow(rows), gse
    ))
  }

  facts_list <- facts_list[validity]

  facts_path <- fs::path(out_dir, paste0(gse, "-sample-facts.json"))
  jsonlite::write_json(facts_list, facts_path, auto_unbox = TRUE,
                       null = "null", pretty = TRUE)
  message("  wrote ", facts_path)

  summary_obj <- tryCatch(
    fetch_study_summary(gse, cache_dir = geo_cache_dir),
    error = function(e) {
      message("  fetch_study_summary failed for ", gse, ": ", conditionMessage(e))
      list(series_id = gse, title = "(unfetched)", summary = "(unfetched)",
           overall_design = NA_character_)
    }
  )
  summary_path <- fs::path(out_dir, paste0(gse, "-study-summary.json"))
  jsonlite::write_json(summary_obj, summary_path, auto_unbox = TRUE,
                       null = "null", pretty = TRUE)
  message("  wrote ", summary_path)
}

message("=== DONE ===")
message("Files in ", out_dir, ":")
invisible(lapply(list.files(out_dir, full.names = TRUE, pattern = "\\.json$"),
                 function(f) message("  ", basename(f), " (", file.size(f), " bytes)")))
