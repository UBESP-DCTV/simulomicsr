#!/usr/bin/env Rscript
# S12p, quarta parte B: Mistral con il prompt v2 (inst/prompts/stage2b-v2.md) sui 1.903, stessa configurazione, schema,
# regola e cascata della prova. Uscite e esiti in analysis/p4-output/S12p-uscite-v2/. Attese: 00-previsioni-monte.md.
# Uso: setsid nohup Rscript analysis/audit/2026-11-08-S12p-prova/110-lancio-v2.R >> .../log/lancio-v2.out 2>&1 < /dev/null &
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
USCITE <- "analysis/p4-output/S12p-uscite-v2"; fs::dir_create(USCITE); V <- "v2"; k <- "mistral"
df <- ingressi(); if (nrow(df) != 1903L) ferma("ingresso: attesi 1.903 confronti")
j <- invia(IN_TUTTI, "s12p-v2-mistral", MODELLI[[k]], df, versione_prompt = V)
attendi(list(j), 300L); raccogli(j)
r <- righe_run(j$run_id); r$giro <- 0L; r$valida <- valida(r$raw)
if (anyDuplicated(r$record_id) || !setequal(r$record_id, df$record_id)) ferma("CANCELLO K3: righe %d, distinte %d", nrow(r), length(unique(r$record_id)))
for (g in seq_along(c(1.2, 1.3, 1.4))) {
  rep <- c(1.2, 1.3, 1.4)[g]; dafare <- r$record_id[is.na(r$saltato) & !r$valida]
  scrivi("[v2] giro di recupero %d (repetition_penalty %.1f): %d confronti", g, rep, length(dafare)); if (!length(dafare)) break
  p <- sprintf("analysis/input/S12p-stage2b-v2-mistral-recupero%d.jsonl", g); scrivi_ingresso(df[match(dafare, df$record_id), ], p)
  jr <- invia(p, sprintf("s12p-v2-mistral-recupero%d", g), MODELLI[[k]], df, gen_over = list(repetition_penalty = rep), versione_prompt = V)
  attendi(list(jr), 120L); raccogli(jr); rr <- righe_run(jr$run_id); rr$giro <- g; rr$valida <- valida(rr$raw)
  r[match(rr$record_id, r$record_id), ] <- rr[, names(r)]
}
fin <- r[match(df$record_id, r$record_id), ]
righe <- vapply(seq_len(nrow(fin)), function(i) as.character(toJSON(as.list(fin[i, ]), auto_unbox = TRUE, na = "null", digits = NA)), "")
con <- file(file.path(USCITE, "mistral.jsonl"), open = "w", encoding = "UTF-8"); writeLines(righe, con, useBytes = TRUE); close(con)
e <- esiti_di(fin, df); write.table(e, file.path(USCITE, "mistral-esiti.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
sh <- vapply(fs::dir_ls(USCITE), function(f) digest::digest(file = f, algo = "sha256"), "")
writeLines(sprintf("%s  %s", sh, names(sh)), file.path(DIR, "110-uscite-v2-sha256.txt"))
gen <- is.na(fin$saltato)
scrivi("[v2] finale: valide %d, non valide %d, oltre il limite %d; token contati = vLLM %d su %d; passano %d su 1.903",
       sum(fin$valida), sum(gen & !fin$valida), sum(!gen), sum(fin$n_prompt[gen] == fin$n_prompt_vllm[gen], na.rm = TRUE), sum(gen), sum(e$passa))
scrivi("LANCIO V2 FINITO")
