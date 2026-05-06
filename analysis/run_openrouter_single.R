# Run un singolo modello OpenRouter su 50 GSE.
# Uso: OPENROUTER_MODEL=<id> OPENROUTER_LABEL=<label> Rscript --vanilla run_openrouter_single.R
# Output: openrouter_<label>_p35c.rds
# Salvataggio incrementale ogni 5 GSE; resume se file esiste.

readRenviron("../.Renviron.local")
suppressPackageStartupMessages({
  devtools::load_all("..", quiet = TRUE)
  library(targets)
})

MODEL <- Sys.getenv("OPENROUTER_MODEL", unset = "")
LABEL <- Sys.getenv("OPENROUTER_LABEL", unset = "")
if (!nzchar(MODEL) || !nzchar(LABEL)) {
  stop("OPENROUTER_MODEL e OPENROUTER_LABEL devono essere impostati.")
}

OUT_FILE <- sprintf("openrouter_%s_p35c.rds", LABEL)

cat("=== Single-model run ===\n")
cat("Model:", MODEL, "\n")
cat("Label:", LABEL, "\n")
cat("Output:", OUT_FILE, "\n")
cat("Inizio:", format(Sys.time()), "\n\n")

sids   <- tar_read(curated_p35c_gse)
sf_all <- tar_read(sample_facts_p35a_validated)
sums   <- tar_read(study_summaries_p35c)
names(sums) <- sids

cache <- cache_init("cache", namespace = "stage2")

sf_by_gse <- split(sf_all, vapply(sf_all,
  function(s) s$series_id %||% NA_character_, character(1)))

out <- if (file.exists(OUT_FILE)) {
  cat("Resume from existing", OUT_FILE, "\n")
  readRDS(OUT_FILE)
} else list()

for (i in seq_along(sids)) {
  sid <- sids[i]
  if (!is.null(out[[sid]])) next
  sf <- sf_by_gse[[sid]] %||% list()
  if (length(sf) == 0L) next
  summary_obj <- sums[[sid]] %||% list(title = "", summary = "", overall_design = "")

  t0 <- Sys.time()
  res <- tryCatch(
    classify_study(series_id = sid, sample_facts_list = sf,
                   study_summary = summary_obj,
                   provider = "openrouter", model = MODEL, cache = cache),
    error = function(e) list(.invalid_reason = "error",
                              .invalid_detail = conditionMessage(e))
  )
  out[[sid]] <- res
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  invalid <- !is.null(res$.invalid_reason)
  cat(sprintf("[%d/%d] %s in %.1fs %s\n",
              i, length(sids), sid, dt,
              if (invalid) paste("INVALID:", res$.invalid_reason) else "OK"))
  if (i %% 5L == 0L) saveRDS(out, OUT_FILE)
}
saveRDS(out, OUT_FILE)
cat("\n=== FINE ", LABEL, " ===\n", sep="")
cat("GSE:", length(out), "/", length(sids), "\n")
cat("Ora:", format(Sys.time()), "\n")
