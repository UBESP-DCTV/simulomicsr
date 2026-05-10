#!/usr/bin/env Rscript
# phase2-vllm-upgrade.R --- ADR-0010 Phase 2 smoke 4-GPU mini500-cs25.
#
# Submette UNO dei 3 config A/B di Phase 2 dell'ADR-0010 vLLM upgrade
# evaluation. Eseguire i 3 in ordine, controllare l'esito di ognuno prima
# di passare al successivo (workflow validate-before-fullrun).
#
# Uso (sequenziale):
#   Rscript analysis/p4-smoke/phase2-vllm-upgrade.R --config 2a
#   # poll/eval, se H1+H2+H3 baseline OK procede:
#   Rscript analysis/p4-smoke/phase2-vllm-upgrade.R --config 2b
#   # poll/eval W1, poi:
#   Rscript analysis/p4-smoke/phase2-vllm-upgrade.R --config 2c
#
# Tutti e 3 i config usano lo stesso input (data-raw/p4-stage2-mini500-cs25.jsonl,
# 500 record cs25 — uguale a T5h baseline 0.10.0 per comparabilita').
# Tutti girano su 4 GPU su poddgx02. SLURM time = 02:00:00 (T5h 2a baseline
# tier 4-GPU = ~30 min, lasciamo margine 4x per safe-mode).
#
# Configs:
#   2a — baseline status quo: safe-mode + disable_guided_decoding=true
#         (uguale a config 0.10.0, traslato su v0.20.2). Verifica HARD gate.
#   2b — outlines strict: safe-mode + disable_guided_decoding=false
#         (forza StructuredOutputsParams, backend auto = xgrammar->outlines).
#         Verifica W1 (schema validity 100%).
#   2c — concurrency restored: max_num_seqs=4 + microbatch=50 + free-gen
#         (rimuove safe-mode, mantiene disable_guided_decoding=true per
#         isolare la variabile concurrency dalla variabile outlines).
#         Verifica W2 (deadlock-free + throughput +20%).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

parse_cli <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  out <- list(config = NULL)
  i <- 1L
  while (i <= length(args)) {
    k <- sub("^--", "", args[i])
    if (i + 1L > length(args)) stop("Manca valore per --", k)
    out[[k]] <- args[i + 1L]
    i <- i + 2L
  }
  out
}

opts <- parse_cli()
if (is.null(opts$config) || !opts$config %in% c("2a", "2b", "2c", "2d", "2e")) {
  stop("--config deve essere uno tra: 2a, 2b, 2c, 2d, 2e")
}

# Mapping config -> (slug, gen_overrides)
# Note: i campi che lasciamo NULL/null in JSON cadono sul default p4-defaults.yml
# letto da run_p4_vllm.py via gen.get(..., default).
config_specs <- list(
  `2a` = list(
    slug = "p2-2a-baseline-safemode",
    overrides = list(),  # nessun override = usa p4-defaults.yml as-is
    desc = "BASELINE safe-mode + disable_guided (status quo 0.10.0 traslato)"
  ),
  `2b` = list(
    slug = "p2-2b-outlines-strict",
    overrides = list(
      disable_guided_decoding = FALSE
    ),
    desc = "OUTLINES strict-schema (W1 test): backend auto = xgrammar->outlines fallback"
  ),
  `2c` = list(
    slug = "p2-2c-concurrency",
    overrides = list(
      max_num_seqs = 4L,
      microbatch = 50L
      # disable_guided_decoding rimane true (default yaml) per isolare W2
    ),
    desc = "CONCURRENCY restored (W2 test): max_num_seqs=4 + microbatch=50, free-gen"
  ),
  # Bonus configs per Phase 5 cleanup tuning (post-gate ADR-0010).
  # Misurano se push oltre max_num_seqs=4 funziona safe + dato perf per
  # scegliere default β.
  `2d` = list(
    slug = "p2-2d-concurrency6",
    overrides = list(
      max_num_seqs = 6L,
      microbatch = 50L
    ),
    desc = "BONUS concurrency=6: push oltre 2c, KV pressure check su XL tier"
  ),
  `2e` = list(
    slug = "p2-2e-combo-outlines-conc4",
    overrides = list(
      max_num_seqs = 4L,
      microbatch = 50L,
      disable_guided_decoding = FALSE
    ),
    desc = "BONUS combo outlines+concurrency4: la combinazione target per beta"
  )
)

spec <- config_specs[[opts$config]]
overrides_json <- if (length(spec$overrides) > 0L) {
  jsonlite::toJSON(spec$overrides, auto_unbox = TRUE)
} else {
  "{}"
}

cat("=== Phase 2 ADR-0010 vLLM upgrade smoke ===\n")
cat("Config:    ", opts$config, "\n")
cat("Slug:      ", spec$slug, "\n")
cat("Desc:      ", spec$desc, "\n")
cat("Overrides: ", overrides_json, "\n")
cat("Input:     ", "data-raw/p4-stage2-mini500-cs25.jsonl (500 record cs25)\n")
cat("Workers:   ", "4 (data-parallel su 4 GPU poddgx02)\n")
cat("Time:      ", "02:00:00\n\n")

# Delego al runner esistente — passing slug + overrides + workers/gpus
runner <- "analysis/p4-smoke/run-smoke-stage2.R"
stopifnot(file.exists(runner))

sys_call <- c(
  "--slug", spec$slug,
  "--workers", "4",
  "--gpus", "4",
  "--cpus", "32",
  "--mem", "200G",
  "--time", "02:00:00",
  "--input", "data-raw/p4-stage2-mini500-cs25.jsonl",
  # shQuote difensivo: system2 args passano via sh -c, le " del JSON
  # vengono strippate dalla shell. shQuote('{"k":false}') protegge.
  "--gen-overrides", shQuote(overrides_json),
  "--nodelist", "poddgx02",
  "--tiered", "TRUE"  # ADR-0011 tier strategy: status quo alpha
)

cat("Invoking:\n  Rscript ", runner, " ", paste(sys_call, collapse = " "), "\n\n", sep = "")

# Esegui il runner come subprocess (eredita Renviron / renv libpath)
status <- system2(
  "Rscript",
  args = c(runner, sys_call),
  env = character(),
  wait = TRUE
)

if (status != 0L) {
  stop("run-smoke-stage2.R ha ritornato status non-zero: ", status)
}

cat("\n=== Phase 2 config ", opts$config, " submitted ===\n", sep = "")
cat("Prossimo passo: poll del SLURM job.\n")
cat("Quando completa, valuta:\n")
if (opts$config == "2a") {
  cat("  HARD gate: schema_validity >= 98%? deadlock? worker 4/4?\n")
  cat("  Se HARD PASS: prosegui con --config 2b\n")
  cat("  Se HARD FAIL: STOP, ADR-0010 outcome FAIL.\n")
} else if (opts$config == "2b") {
  cat("  W1: schema_validity = 100%? (vs 99.84% baseline alpha)\n")
  cat("  Quando hai il numero, prosegui con --config 2c\n")
} else {
  cat("  W2: 4/4 worker complete senza stall? throughput >= +20% vs 2a?\n")
  cat("  Quando hai i numeri di tutti e 3, applica decision matrix ADR-0010.\n")
}
