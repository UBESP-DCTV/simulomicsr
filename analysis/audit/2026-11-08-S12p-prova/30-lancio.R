#!/usr/bin/env Rscript
# S12p, lancio pieno: i 1.903 confronti con tre modelli su poddgx02, cascata di recupero, uscite finali con SHA-256.
# NON apre il riferimento dei 193: il conto e' 40-conto.R, dopo il commit delle impronte.
# Uso: setsid nohup Rscript analysis/audit/2026-11-08-S12p-prova/30-lancio.R >> analysis/audit/2026-11-08-S12p-prova/log/lancio.out 2>&1 < /dev/null &
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
USCITE <- "analysis/p4-output/S12p-uscite"; fs::dir_create(USCITE)
passo <- function(nome, expr) {
  f <- file.path(ST, paste0(nome, ".done"))
  if (file.exists(f)) { scrivi("passo %s gia' fatto", nome); return(invisible(NULL)) }
  scrivi("INIZIO %s", nome); t0 <- Sys.time(); force(expr)
  writeLines(format(Sys.time()), f); scrivi("FINE %s (%.1f min)", nome, as.numeric(difftime(Sys.time(), t0, units = "mins")))
}

df <- ingressi()
if (nrow(df) != 1903L || anyDuplicated(df$record_id)) ferma("ingresso: attesi 1.903 confronti distinti")
if (!file.exists(IN_TUTTI)) scrivi_ingresso(df, IN_TUTTI)
smoke <- readLines(file.path(DIR, "20-smoke-confronti.txt"))
job_smoke <- lapply(names(MODELLI), function(m) readRDS(file.path(JOBS, paste0("s12p-smoke-", m, ".rds")))); names(job_smoke) <- names(MODELLI)

# ---- 1. i tre modelli sui 1.903 -----------------------------------------------------------------------------
jobs <- lapply(names(MODELLI), function(m) invia(IN_TUTTI, paste0("s12p-", m), MODELLI[[m]], df))
names(jobs) <- names(MODELLI)
passo("attesa", { m <- attendi(jobs, 300L); writeLines(apply(m, 1, paste, collapse = " "), file.path(DIR, "30-sacct-pieno.txt")) })

# ---- 2. raccolta, validazione, cascata di recupero per modello ----------------------------------------------
REP <- c(1.2, 1.3, 1.4)
for (k in names(MODELLI)) passo(paste0("recupero-", k), {
  raccogli(jobs[[k]]); r <- righe_run(jobs[[k]]$run_id); r$giro <- 0L; r$valida <- valida(r$raw)
  if (anyDuplicated(r$record_id) || !setequal(r$record_id, df$record_id)) ferma("CANCELLO K3: %s, righe %d, distinte %d, attese 1.903", k, nrow(r), length(unique(r$record_id)))
  tutte <- r
  for (g in seq_along(REP)) {
    dafare <- r$record_id[is.na(r$saltato) & !r$valida]
    scrivi("[%s] giro di recupero %d (repetition_penalty %.1f): %d confronti", k, g, REP[g], length(dafare))
    if (!length(dafare)) break
    p <- sprintf("analysis/input/S12p-stage2b-%s-recupero%d.jsonl", k, g); scrivi_ingresso(df[match(dafare, df$record_id), ], p)
    jr <- invia(p, sprintf("s12p-%s-recupero%d", k, g), MODELLI[[k]], df, gen_over = list(repetition_penalty = REP[g]))
    attendi(list(jr), 120L); raccogli(jr); rr <- righe_run(jr$run_id); rr$giro <- g; rr$valida <- valida(rr$raw)
    if (!setequal(rr$record_id, dafare)) ferma("CANCELLO K3: %s, recupero %d con righe diverse da quelle chieste", k, g)
    tutte <- rbind(tutte, rr)
    i <- match(rr$record_id, r$record_id); r[i, ] <- rr[, names(r)]
    scrivi("[%s] giro %d: valide %d su %d", k, g, sum(rr$valida), nrow(rr))
  }
  saveRDS(tutte, file.path(USCITE, paste0(k, "-tutti-i-giri.rds")))
  # uscita finale: una riga per confronto, l'ultimo giro fatto (il primo valido, perche' un valido non si rifa').
  fin <- r[match(df$record_id, r$record_id), ]
  righe <- vapply(seq_len(nrow(fin)), function(i) as.character(toJSON(as.list(fin[i, ]), auto_unbox = TRUE, na = "null", digits = NA)), "")
  con <- file(file.path(USCITE, paste0(k, ".jsonl")), open = "w", encoding = "UTF-8"); writeLines(righe, con, useBytes = TRUE); close(con)
  scrivi("[%s] finale: valide %d, non valide %d, oltre il limite %d", k, sum(fin$valida), sum(is.na(fin$saltato) & !fin$valida), sum(!is.na(fin$saltato)))
})

# ---- 3. cancelli K3, K4 e impronte --------------------------------------------------------------------------
passo("cancelli", {
  out <- character()
  for (k in names(MODELLI)) {
    fin <- lapply(readLines(file.path(USCITE, paste0(k, ".jsonl")), encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
    id <- vapply(fin, `[[`, "", "record_id")
    out <- c(out, sprintf("K3 [%s]: confronti %d, distinti %d, uguali ai 1.903: %s", k, length(id), length(unique(id)), setequal(id, df$record_id) && length(id) == 1903L))
    base <- righe_run(jobs[[k]]$run_id); sm <- righe_run(job_smoke[[k]]$run_id)
    b <- base[match(smoke, base$record_id), ]; s <- sm[match(smoke, sm$record_id), ]
    out <- c(out, sprintf("K4 [%s]: uscite dello smoke identiche nel run pieno: %d su %d", k, sum(b$raw == s$raw & is.na(b$saltato) == is.na(s$saltato)), length(smoke)))
    gen <- is.na(base$saltato)
    out <- c(out, sprintf("K4 [%s]: token del prompt contati = vLLM: %d su %d generati", k, sum(base$n_prompt[gen] == base$n_prompt_vllm[gen], na.rm = TRUE), sum(gen)))
  }
  sh <- vapply(fs::dir_ls(USCITE), function(f) digest::digest(file = f, algo = "sha256"), "")
  writeLines(sprintf("%s  %s", sh, names(sh)), file.path(DIR, "40-uscite-sha256.txt"))
  writeLines(out, file.path(DIR, "30-cancelli.txt")); for (l in out) scrivi("%s", l)
})
scrivi("LANCIO FINITO: committa 40-uscite-sha256.txt prima di scrivere ed eseguire il conto")
