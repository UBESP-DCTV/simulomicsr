# Standalone script per run OpenRouter 50 GSE × N modelli
# Uso: cd analysis && Rscript --vanilla run_openrouter_p35c.R
# Output: openrouter_outputs_p35c.rds + log incrementale

readRenviron("../.Renviron.local")
suppressPackageStartupMessages({
  devtools::load_all("..", quiet = TRUE)
  library(targets)
})

# Modelli da configurare via env var, default 4 modelli "round 1"
MODELS_ENV <- Sys.getenv("OPENROUTER_MODELS", unset = "round1")
specs <- if (MODELS_ENV == "round5") {
  # round 5: BIG open-weights models (per self-host su DGX H100)
  # Coppie ultima/penultima per famiglia + replica mistral-small-3.2.
  list(
    list(provider = "openrouter", model = "mistralai/mistral-small-3.2-24b-instruct", label = "mistral_sm_32_replica"),
    list(provider = "openrouter", model = "qwen/qwen3.6-max-preview",                 label = "qwen36max"),
    list(provider = "openrouter", model = "qwen/qwen3-max",                           label = "qwen3max"),
    list(provider = "openrouter", model = "deepseek/deepseek-v4-pro",                 label = "deepseek_v4_pro"),
    list(provider = "openrouter", model = "deepseek/deepseek-v3.2-speciale",          label = "deepseek_v32_sp"),
    list(provider = "openrouter", model = "meta-llama/llama-4-maverick",              label = "llama4_maverick"),
    list(provider = "openrouter", model = "meta-llama/llama-3.3-70b-instruct",        label = "llama33_70b"),
    list(provider = "openrouter", model = "nousresearch/hermes-3-llama-3.1-405b",     label = "hermes_405b")
  )
} else if (MODELS_ENV == "round4") {
  # round 4: modelli BIG (top-tier) ultima vs penultima versione per famiglia
  # + replica mistral-small-3.2 per anti-variance check
  list(
    list(provider = "openrouter", model = "mistralai/mistral-small-3.2-24b-instruct", label = "mistral_sm_32_replica"),
    list(provider = "openrouter", model = "anthropic/claude-opus-4.7",                label = "opus_4_7"),
    list(provider = "openrouter", model = "anthropic/claude-opus-4.6",                label = "opus_4_6"),
    list(provider = "openrouter", model = "qwen/qwen3.6-max-preview",                 label = "qwen36max"),
    list(provider = "openrouter", model = "qwen/qwen3-max",                           label = "qwen3max"),
    list(provider = "openrouter", model = "google/gemini-2.5-pro",                    label = "gemini25pro"),
    list(provider = "openrouter", model = "x-ai/grok-4.3",                            label = "grok4_3"),
    list(provider = "openrouter", model = "x-ai/grok-4.20",                           label = "grok4_20"),
    list(provider = "openrouter", model = "mistralai/mistral-large-2512",             label = "mistral_large_2512")
  )
} else if (MODELS_ENV == "round3") {
  # round 3: gemini-flash-latest fixato (tilde alias) + mistral-small-2603 nuovo
  list(
    list(provider = "openrouter", model = "~google/gemini-flash-latest",              label = "gemini_flash_latest"),
    list(provider = "openrouter", model = "mistralai/mistral-small-2603",             label = "mistral_sm_2603")
  )
} else if (MODELS_ENV == "round2") {
  list(
    list(provider = "openrouter", model = "qwen/qwen3.6-flash",                       label = "qwen36flash"),
    list(provider = "openrouter", model = "deepseek/deepseek-v4-flash",               label = "deepseek_v4_flash"),
    list(provider = "openrouter", model = "google/gemini-flash-latest",               label = "gemini_flash_latest"),
    list(provider = "openrouter", model = "mistralai/mistral-medium-3-5",             label = "mistral_med35")
  )
} else {
  list(
    list(provider = "openrouter", model = "google/gemini-2.5-flash",                  label = "gemini25flash"),
    list(provider = "openrouter", model = "qwen/qwen3-30b-a3b-instruct-2507",         label = "qwen3_30b"),
    list(provider = "openrouter", model = "deepseek/deepseek-chat-v3.1",              label = "deepseek_v3_1"),
    list(provider = "openrouter", model = "mistralai/mistral-small-3.2-24b-instruct", label = "mistral_sm")
  )
}

OUT_FILE <- if (MODELS_ENV == "round5") {
  "openrouter_outputs_round5_p35c.rds"
} else if (MODELS_ENV == "round4") {
  "openrouter_outputs_round4_p35c.rds"
} else if (MODELS_ENV == "round3") {
  "openrouter_outputs_round3_p35c.rds"
} else if (MODELS_ENV == "round2") {
  "openrouter_outputs_round2_p35c.rds"
} else {
  "openrouter_outputs_p35c.rds"
}

cat("=== OpenRouter run ===\n")
cat("Round:", MODELS_ENV, "\n")
cat("Modelli:", paste(vapply(specs, function(s) s$label, character(1)),
                      collapse = ", "), "\n")
cat("Output file:", OUT_FILE, "\n")
cat("Inizio:", format(Sys.time()), "\n\n")

sids   <- tar_read(curated_p35c_gse)
sf_all <- tar_read(sample_facts_p35a_validated)
sums   <- tar_read(study_summaries_p35c)
names(sums) <- sids

cat("Sids:", length(sids), "Sample_facts:", length(sf_all), "\n\n")

cache <- cache_init("cache", namespace = "stage2")

sf_by_gse <- split(sf_all, vapply(sf_all,
  function(s) s$series_id %||% NA_character_, character(1)))

# Resume: se OUT_FILE esiste, carica e continua dai sid mancanti
out <- if (file.exists(OUT_FILE)) {
  cat("Resume from existing", OUT_FILE, "\n")
  readRDS(OUT_FILE)
} else list()

for (i in seq_along(sids)) {
  sid <- sids[i]
  if (!is.null(out[[sid]])) {
    cat(sprintf("[%d/%d] %s SKIP (already done)\n", i, length(sids), sid))
    next
  }
  sf <- sf_by_gse[[sid]] %||% list()
  if (length(sf) == 0L) {
    cat(sprintf("[%d/%d] %s SKIP (no sample_facts)\n", i, length(sids), sid))
    next
  }
  summary_obj <- sums[[sid]] %||%
    list(title = "", summary = "", overall_design = "")

  t0 <- Sys.time()
  res <- tryCatch(
    multi_classify_study(
      series_id = sid, sample_facts_list = sf,
      study_summary = summary_obj, model_specs = specs, cache = cache
    ),
    error = function(e) {
      cat(sprintf("[%d/%d] %s ERROR: %s\n", i, length(sids), sid,
                  conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(res)) {
    out[[sid]] <- res
    invalid <- vapply(res, function(d) !is.null(d$.invalid_reason), logical(1))
    cat(sprintf("[%d/%d] %s done in %.1fs (%d/%d invalid)\n",
                i, length(sids), sid,
                as.numeric(difftime(Sys.time(), t0, units = "secs")),
                sum(invalid), length(invalid)))
    # Salvataggio incrementale ogni 5 GSE
    if (i %% 5L == 0L) saveRDS(out, OUT_FILE)
  }
}

saveRDS(out, OUT_FILE)
cat("\n=== FINE ===\n")
cat("Salvato in:", OUT_FILE, "\n")
cat("GSE classificati:", length(out), "/", length(sids), "\n")
cat("Ora:", format(Sys.time()), "\n")
