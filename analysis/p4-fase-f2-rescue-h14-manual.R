#!/usr/bin/env Rscript
# p4-fase-f2-rescue-h14-manual.R --- RED ALERT FASE F2 rescue H1.4 (manual):
# curation dei 2 residui GSE157354 non recuperabili automaticamente (flood
# whitespace resistente fino a rep_pen=1.4).
#
# Metodo (paper-grade, no invenzione): si rispecchia il parsed_json del gemello
# GSM4763009 (stesso studio, recuperato in H1.3), cambiando SOLO i campi che
# variano legittimamente tra sample dello stesso studio: geo_accession e la
# duration (growth time days -> value_raw + value_hours). Validato contro lo
# schema sample_facts.stage1.v3 prima dell'iniezione.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite)
})

H13     <- "analysis/p4-output/p4-fase-f2-rescue-h13-predictions.jsonl"
OUT     <- "analysis/p4-output/p4-fase-f2-rescue-manual-predictions.jsonl"
SCHEMA  <- "inst/schemas/sample_facts.stage1.v3.json"
TEMPLATE_ID <- "GSM4763009"

# campi che variano: GSM -> (value_raw, value_hours)
TARGETS <- list(
  GSM4762990 = list(value_raw = "1 days", value_hours = 24L),
  GSM4763017 = list(value_raw = "8 days", value_hours = 192L)
)

# Carica il parsed_json del gemello template
tmpl <- NULL
con <- file(H13, "r")
repeat {
  L <- readLines(con, n = 1L, warn = FALSE); if (!length(L)) break
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (identical(rec$record_id, TEMPLATE_ID) && !is.null(rec$parsed_json)) {
    tmpl <- rec$parsed_json; break
  }
}
close(con)
stopifnot(!is.null(tmpl))
cat(sprintf("Template gemello: %s (duration gemello: %s / %sh)\n", TEMPLATE_ID,
            tmpl$perturbations[[1]]$duration$value_raw,
            tmpl$perturbations[[1]]$duration$value_hours))

validator <- compile_schema(SCHEMA)
out <- file(OUT, "w"); n_ok <- 0L
for (gsm in names(TARGETS)) {
  pj <- tmpl
  pj$geo_accession <- gsm
  pj$perturbations[[1]]$duration$value_raw   <- TARGETS[[gsm]]$value_raw
  pj$perturbations[[1]]$duration$value_hours <- TARGETS[[gsm]]$value_hours

  v <- validate_json(pj, validator)
  if (!isTRUE(v$valid)) {
    cat(sprintf("FAIL schema %s:\n", gsm)); print(utils::head(v$errors, 10)); stop("schema invalido")
  }
  cat(sprintf("OK schema %s (duration %s / %sh)\n", gsm,
              pj$perturbations[[1]]$duration$value_raw,
              pj$perturbations[[1]]$duration$value_hours))

  rec <- list(
    record_id    = gsm,
    raw_output   = sprintf("MANUAL_CURATION mirror=%s (RED_ALERT F2 H1.4)", TEMPLATE_ID),
    parsed_json  = pj,
    valid_schema = TRUE,
    worker_id    = "manual",
    ts           = "2026-05-29"
  )
  writeLines(jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null", na = "null"), out)
  n_ok <- n_ok + 1L
}
close(out)
cat(sprintf("\nScritti %d record curati validati -> %s\n", n_ok, OUT))
stopifnot(n_ok == length(TARGETS))
