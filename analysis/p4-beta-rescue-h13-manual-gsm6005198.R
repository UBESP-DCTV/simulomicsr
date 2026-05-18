#!/usr/bin/env Rscript
# p4-beta-rescue-h13-manual-gsm6005198.R --- manual curation single-record
# rescue per GSM6005198 (B-ALL cell line 697 in co-coltura con hTERT-BMSC).
# Whitespace flood pathology non risolto da H1.2 (rep_pen=1.3,
# max_tokens=8192). Curated by lucavd + Claude 2026-05-18.

suppressPackageStartupMessages({
  library(jsonlite)
})

MASTER <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
TARGET <- "GSM6005198"
OUT    <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued-v2.jsonl"

# Curated classification (interpretazione bio: B-cell precursor ALL cell
# line 697 / CVCL_0079 con translocation naturale TCF3-PBX1, in co-coltura
# con stromal feeder hTERT-BMSC; sample = non-adherent fraction).
curated_parsed <- list(
  geo_accession = "GSM6005198",
  series_id     = "GSE200039",
  organism      = "Homo sapiens",
  host_organism = NA,
  cell_context = list(
    cell_type_or_line_raw           = "697",
    cell_line_cellosaurus_candidate = "CVCL_0079",
    tissue                          = NA,
    tissue_segment                  = NA,
    passage_or_state                = "non-adherent fraction",
    context_kind                    = "co_culture",
    developmental_stage             = NA,
    cell_state                      = NA,
    subcellular_fraction            = NA,
    engineered_modifications        = list(),
    co_culture_partners = list(list(
      cell_type       = "hTERT-immortalized bone marrow stromal cell",
      source_organism = "Homo sapiens",
      modifications   = list("hTERT_immortalization"),
      role            = "stromal"
    )),
    sort_markers               = list(),
    cell_composition_estimates = list()
  ),
  disease_state = list(
    term_raw          = "B-cell precursor acute lymphoblastic leukemia",
    mesh_id_candidate = "D015464",
    status            = "disease_model"
  ),
  perturbations = list(list(
    kind             = "none",
    agent_raw        = NA,
    agent_normalized = list(
      type           = "none",
      id_database    = NA,
      id             = NA,
      preferred_name = NA,
      collection     = NA
    ),
    dose     = list(value_raw = NA, value_numeric = NA, unit = NA),
    duration = list(value_raw = NA, value_hours = NA, is_zero_timepoint = FALSE),
    phase                = NA,
    temporal_order       = NA,
    is_negative_control  = FALSE,
    mediated_effect      = NA
  )),
  technical_treatments = list(),
  patient_metadata     = NA,
  extraction = list(
    schema_version = "stage1.v3",
    model          = "manual_curation_2026-05-18",
    confidence     = 0.95,
    ambiguity_flags = list("cell_line_ambiguous", "protocol_only_no_perturbation"),
    raw_input_hash = "sha256:fafac5983f469f4f8fbc8c9639bd63c1cf5afb0b6b2ab1f4140fd56b0836de98"
  )
)

curated_raw <- jsonlite::toJSON(curated_parsed, auto_unbox = TRUE,
                                 null = "null", na = "null", pretty = FALSE)

# Validate against schema before injecting
schema_path <- "inst/schemas/sample_facts.stage1.v3.json"
validator <- jsonvalidate::json_validator(schema_path, engine = "ajv")
ok <- validator(curated_raw, verbose = TRUE)
if (!isTRUE(ok)) {
  cat("VALIDATION ERRORS:\n")
  print(attr(ok, "errors"))
  stop("Curated classification fails schema validation. Fix prima di inject.")
}
cat("Curated classification validates against schema.stage1.v3 ✓\n")

# Inject into master in-place
con_in  <- file(MASTER, "r")
con_out <- file(OUT, "w")
n_total <- 0L; n_replaced <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (rec$record_id == TARGET) {
    rec$raw_output    <- as.character(curated_raw)
    rec$parsed_json   <- curated_parsed
    rec$rescue_source <- "manual_curation_2026-05-18"
    n_replaced <- n_replaced + 1L
  }
  writeLines(as.character(jsonlite::toJSON(rec, auto_unbox = TRUE,
                                            null = "null", na = "null")),
             con_out)
}
close(con_in); close(con_out)
stopifnot(n_replaced == 1L)
cat(sprintf("Master replaced: %d total records, %d manually curated\n",
            n_total, n_replaced))

# Verify validity post-injection
con <- file(OUT, "r")
n_total <- 0L; n_valid <- 0L
while (TRUE) {
  L <- readLines(con, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(rec$parsed_json) && !is.null(rec$parsed_json$series_id))
    n_valid <- n_valid + 1L
}
close(con)
cat(sprintf("Schema validity post-manual: %d/%d = %.5f%%\n",
            n_valid, n_total, 100*n_valid/n_total))

file.rename(OUT, MASTER)
cat(sprintf("Master file replaced: %s\n", MASTER))
