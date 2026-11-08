#!/usr/bin/env Rscript
# S12p: dove nasce il token in piu' che vLLM conta nel prompt di Gemma (smoke: +1 in 19 confronti su 19).
# Tre confronti dello smoke, il runner registra il primo punto in cui i token del template e quelli di vLLM divergono.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
df <- ingressi(); sc <- readLines(file.path(DIR, "20-smoke-confronti.txt"))[1:3]
p <- "analysis/input/S12p-stage2b-gemma-token3.jsonl"; scrivi_ingresso(df[match(sc, df$record_id), ], p)
j <- invia(p, "s12p-gemma-token", MODELLI$gemma, df); attendi(list(j), 60L); raccogli(j)
l <- readLines(file.path("analysis/p4-output", j$run_id, "predictions.jsonl"), warn = FALSE)
out <- vapply(l, function(x) { r <- fromJSON(x, simplifyVector = FALSE); d <- r$prompt_diff
  sprintf("%s: template %s, vLLM %s, primo indice diverso %s, template %s, vLLM %s", r$record_id, r$n_prompt_tokens, r$n_prompt_tokens_vllm,
          if (is.null(d)) "nessuno" else d$pos, paste(unlist(d$a), collapse = " "), paste(unlist(d$b), collapse = " ")) }, "", USE.NAMES = FALSE)
writeLines(out, file.path(DIR, "21-gemma-token-out.txt")); for (o in out) scrivi("%s", o)
