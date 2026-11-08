#!/usr/bin/env Rscript
# S12p, smoke: 20 confronti per ciascuno dei tre modelli (00-previsioni.md). Poi STOP: il lancio pieno e' un altro script.
# Uso: setsid nohup Rscript analysis/audit/2026-11-08-S12p-prova/20-smoke.R >> analysis/audit/2026-11-08-S12p-prova/log/smoke.out 2>&1 < /dev/null &
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")

df <- ingressi()
if (nrow(df) != 1903L || anyDuplicated(df$record_id)) ferma("ingresso: attesi 1.903 confronti distinti")
if (!file.exists(IN_TUTTI)) scrivi_ingresso(df, IN_TUTTI)

# Scelta dello smoke: 18 a caso (seme), il piu' lungo entro il limite stimato, l'unico oltre il limite stimato.
oltre <- df$record_id[!df$completo]; if (length(oltre) != 1L) ferma("attesi 1 confronto oltre il limite stimato, trovati %d", length(oltre))
dentro <- df[df$completo, ]; lungo <- dentro$record_id[which.max(dentro$token_stimati)]
set.seed(SEME); caso <- sample(setdiff(dentro$record_id, lungo), 18L)
# Aggiunto dopo il primo smoke (fermato): con il conteggio vero dei token (25-token-1903.tsv) il piu' lungo entro il
# limite stimato e' oltre il limite vero. Per provare la memoria sul prompt piu' lungo che va al modello si aggiunge
# il piu' lungo entro il limite vero per tutti e tre i modelli: 21 confronti.
TOK <- read.delim(file.path(DIR, "25-token-1903.tsv"), stringsAsFactors = FALSE); LIM <- .S2B_MAX_MODEL_LEN - .S2B_RISERVA_RISPOSTA
amm <- Reduce(intersect, lapply(split(TOK, TOK$modello), function(x) x$record_id[x$n_token <= LIM]))
tm <- TOK[TOK$modello == "mistral" & TOK$record_id %in% amm, ]; lungo_vero <- tm$record_id[which.max(tm$n_token)]
scelti <- c(caso, lungo, oltre, lungo_vero)
writeLines(scelti, file.path(DIR, "20-smoke-confronti.txt"))
P_SMOKE <- "analysis/input/S12p-stage2b-smoke21.jsonl"; scrivi_ingresso(df[match(scelti, df$record_id), ], P_SMOKE)
scrivi("smoke: %d confronti (18 a caso, il piu' lungo stimato %s, oltre il limite stimato %s, il piu' lungo vero %s)", length(scelti), lungo, oltre, lungo_vero)

jobs <- lapply(names(MODELLI), function(m) invia(P_SMOKE, paste0("s12p-smoke-", m), MODELLI[[m]], df, time = "72:00:00"))
names(jobs) <- names(MODELLI)
m <- attendi(jobs, 60L)

out <- c(sprintf("smoke S12p, %s", format(Sys.time(), "%Y-%m-%d %H:%M")))
gens <- list()
for (k in names(jobs)) {
  d <- raccogli(jobs[[k]]); r <- righe_run(jobs[[k]]$run_id)
  gens[[k]] <- read_json(file.path("analysis/p4-bundles", jobs[[k]]$run_id, "generation.json"))
  gen <- !is.na(r$fine) | (is.na(r$saltato) & nzchar(r$raw))
  ok <- valida(r$raw)
  out <- c(out, sprintf("[%s] slurm %s, %s, %s", k, jobs[[k]]$slurm_job_id, m[match(jobs[[k]]$slurm_job_id, m[, 1]), 3], m[match(jobs[[k]]$slurm_job_id, m[, 1]), 4]),
           sprintf("[%s] righe %d su %d; oltre il limite %d (%s); generate %d; valide sullo schema %d; motivo di fine: %s", k, nrow(r), length(scelti),
                   sum(!is.na(r$saltato)), paste(sprintf("%s=%s", r$record_id[!is.na(r$saltato)], r$n_prompt[!is.na(r$saltato)]), collapse = " "),
                   sum(gen), sum(ok), paste(names(table(r$fine)), table(r$fine), collapse = " ")),
           sprintf("[%s] token del prompt contati = vLLM: %d su %d", k, sum(r$n_prompt[gen] == r$n_prompt_vllm[gen], na.rm = TRUE), sum(gen)),
           sprintf("[%s] token del prompt contati nel job = conteggio su CPU (25-token-1903.tsv): %d su %d", k,
                   sum(r$n_prompt == TOK$n_token[TOK$modello == k][match(r$record_id, TOK$record_id[TOK$modello == k])], na.rm = TRUE), nrow(r)),
           sprintf("[%s] token del prompt, mediana %.0f, massimo %.0f; token d'uscita, mediana %.0f, massimo %.0f", k,
                   median(r$n_prompt, na.rm = TRUE), max(r$n_prompt, na.rm = TRUE), median(r$n_out, na.rm = TRUE), max(r$n_out, na.rm = TRUE)))
  # rapporto caratteri / token sul prompt (sistema + testo), per la stima della spec
  tx <- df$testo[match(r$record_id, df$record_id)]; ch <- nchar(tx) + nchar(.s2b_prompt_sistema())
  out <- c(out, sprintf("[%s] caratteri per token del prompt: mediana %.2f, minimo %.2f", k, median(ch / r$n_prompt, na.rm = TRUE), min(ch / r$n_prompt, na.rm = TRUE)))
  if (any(!ok & gen)) out <- c(out, sprintf("[%s] non valide: %s", k, paste(r$record_id[!ok & gen], collapse = " ")))
  if (sum(!duplicated(r$record_id)) != length(scelti) || !setequal(r$record_id, scelti)) out <- c(out, sprintf("[%s] COPERTURA: righe diverse dai 20 scelti", k))
}
# K2: generation.json uguale fra i modelli a meno dei campi del modello.
js <- function(g) as.character(toJSON(g[setdiff(sort(names(g)), CAMPI_MODELLO)], auto_unbox = TRUE, digits = NA))
out <- c(out, sprintf("cancello K2: generation.json uguale fra i tre modelli a meno dei campi del modello: %s", length(unique(vapply(gens, js, ""))) == 1L))
writeLines(out, file.path(DIR, "20-smoke-out.txt")); for (l in out) scrivi("%s", l)
scrivi("SMOKE FINITO")
