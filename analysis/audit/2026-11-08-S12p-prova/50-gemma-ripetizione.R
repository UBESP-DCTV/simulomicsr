#!/usr/bin/env Rscript
# S12p: quanto cambia Gemma fra due esecuzioni identiche (cancello K4 fallito: 15 uscite dello smoke su 21 identiche).
# Seconda esecuzione sui 1.903 con lo stesso bundle; confronto delle uscite grezze e dei verdetti della regola con la
# prima esecuzione (job 470093, prima della cascata). Il conto si fa sulla prima esecuzione: questa misura solo la
# variabilita'.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
df <- ingressi()
j2 <- invia(IN_TUTTI, "s12p-gemma-ripetizione", MODELLI$gemma, df); attendi(list(j2), 300L); raccogli(j2)
a <- righe_run(readRDS(file.path(JOBS, "s12p-gemma.rds"))$run_id); b <- righe_run(j2$run_id)
b <- b[match(a$record_id, b$record_id), ]
ea <- esiti_di(a, df); eb <- esiti_di(b, df)
rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)
dif <- a$record_id %in% rif$record_id
gen <- is.na(a$saltato)
out <- c(sprintf("uscite grezze identiche: %d su %d generate", sum(a$raw[gen] == b$raw[gen]), sum(gen)),
         sprintf("liste valide: prima %d, seconda %d", sum(valida(a$raw)), sum(valida(b$raw))),
         sprintf("verdetto della regola uguale (passa / non passa): %d su %d", sum(ea$passa == eb$passa), nrow(ea)),
         sprintf("motivi uguali: %d su %d", sum(ea$motivi == eb$motivi), nrow(ea)),
         sprintf("verdetti che cambiano fra i difettosi: %d su %d; fra i puliti: %d su %d", sum(ea$passa != eb$passa & dif), sum(dif), sum(ea$passa != eb$passa & !dif), sum(!dif)),
         sprintf("prima esecuzione, senza cascata: presi %d, falsi allarmi %d", sum(!ea$passa & dif), sum(!ea$passa & !dif)),
         sprintf("seconda esecuzione, senza cascata: presi %d, falsi allarmi %d", sum(!eb$passa & dif), sum(!eb$passa & !dif)))
writeLines(out, file.path(DIR, "50-gemma-ripetizione-out.txt")); for (o in out) scrivi("%s", o)
