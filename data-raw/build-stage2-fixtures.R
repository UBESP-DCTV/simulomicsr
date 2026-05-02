# Build fixture mini Stadio 2: 15 GSE stratificati per design_kind e casi limite.
#
# Selezione approvata utente 2026-05-02 (estensione da 3 a 15 GSE):
#
# BASE (3 GSE — Task 10, cache gia` calda):
#   - GSE145028 (n=12, knockdown_panel       — NCI-H1963 + shRNA)
#   - GSE145941 (n=8,  treatment_vs_untreated — irradiazione 0Gy/10Gy)
#   - GSE191240 (n=9,  pathogen_or_aggregate_exposure — HUVEC + A.fumigatus)
#
# ROUND 2 — diversita` di design (5 GSE nuovi):
#   - GSE155528 (n=12, dose_response          — C4-2 + R1881)
#   - GSE200037 (n=12, differentiation_course — iPSC microglia)
#   - GSE104149 (n=12, case_control + time + multi-donor — BCG + monocyte)
#   - GSE106966 (n=12, factorial              — HEK293T + WT/CRAF- + serum/EGF)
#   - GSE114781 (n=12, time_course            — HEK293T + transcription block)
#
# ROUND 3 — casi limite (7 GSE nuovi):
#   - GSE57494  (n=40, LARGE N + factorial    — CD14+CD16+ + IFNg + LPS + multi-donor)
#   - GSE143441 (n=30, LARGE N + tumor + drug — MCF7 + EtOH + 4sU)
#   - GSE128771 (n=4,  mediated_effect        — AML + Dox-inducible CBFB-MYH11 KD)
#   - GSE101708 (n=9,  tumor + drug + disease_vs_normal conflict — HCT116 + DMSO/largazole)
#   - GSE102908 (n=12, factorial cancer       — SCCOHT1 + SMARCA4 LoF + OTX015 time)
#   - GSE106716 (n=8,  factorial 2x2          — OVISE + SYK-WT/KO + EGF)
#   - GSE100261 (n=5,  metadata povero        — string "treatment: control")
#
# Source: full xlsx (NON P2 dev set, che ha 1 sample/GSE).
# Idempotente: cache LLM riusa i risultati esistenti.
# ~30 sample con cache calda (base 3 GSE), ~125 fresh per 12 GSE nuovi.
#
# Run: source("data-raw/build-stage2-fixtures.R")
# Pre-req: OPENAI_API_KEY in .Renviron.local

library(simulomicsr)
library(here)
library(dplyr)

`%||%` <- function(x, y) if (is.null(x)) y else x

candidate_gse <- c(
  # Base 3 (Task 10, cache gia` calda)
  "GSE145028",  # n=12  knockdown_panel
  "GSE145941",  # n=8   treatment_vs_untreated
  "GSE191240",  # n=9   pathogen_or_aggregate_exposure

  # Round 2 -- diversita` di design (5 nuovi)
  "GSE155528",  # n=12  dose_response
  "GSE200037",  # n=12  differentiation_course
  "GSE104149",  # n=12  case_control + time + multi-donor
  "GSE106966",  # n=12  factorial
  "GSE114781",  # n=12  time_course

  # Round 3 -- casi limite (7 nuovi)
  "GSE57494",   # n=40  LARGE N + factorial
  "GSE143441",  # n=30  LARGE N + tumor + drug
  "GSE128771",  # n=4   mediated_effect
  "GSE101708",  # n=9   tumor + drug + disease_vs_normal conflict
  "GSE102908",  # n=12  factorial cancer
  "GSE106716",  # n=8   factorial 2x2
  "GSE100261"   # n=5   metadata povero
)

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
    res <- classify_sample(
      sample_string = rows$string[[i]],
      geo_accession = rows$geo_accession[[i]],
      series_id = rows$series_id[[i]],
      provider = "openai", model = "gpt-5.5",
      cache = cache
    )
    res$value
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
