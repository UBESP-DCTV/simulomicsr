#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 12-prova-compilazione.R — S12r3, misura senza modello, seconda parte: vLLM 0.20.2 compila gli schemi generati?
#
# Che cosa prova: i 47 schemi generati da 10-schema-per-studio.R (uno per studio di sviluppo) passano alle uscite
# strutturate di vLLM 0.20.2 col tokenizer di Mistral-Small 3.2, nella configurazione delle corse (4 worker da 1
# GPU, uno schema diverso per ogni record). NESSUN TESTO DI STUDIO VA AL MODELLO: il messaggio dei 47 record e'
# una frase neutra che chiede una tabella senza fattori, con max_tokens 1024 (96 nelle forme 1 e 2). Lo schema
# ammette `factors: []`: l'uscita attesa ha il `series_id` giusto, zero fattori e la tupla `columns` completa. Cosi' nessuna uscita vera esiste prima del deposito delle
# previsioni. Un 48esimo record e' lo studio finto GSE0 (lo stesso del controllo positivo dell'adattatore): il
# messaggio detta che cosa scrivere, e l'uscita deve portare le tuple complete, nell'ordine dello schema.
#
# Uso: Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/12-prova-compilazione.R  (pochi minuti: non serve setsid)
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")   # cfg (solo poddgx02), ENV_JOB, attendi(), raccogli(), K5
S12R <- DIR
DIR <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
for (d in c(LOG, JOBS)) fs::dir_create(d)
source(file.path(DIR, "10-schema-per-studio.R"))
OUT <- file.path(DIR, "12-out.txt")
nota <- function(...) { scrivi(...); cat(sprintf(...), "\n", sep = "", file = OUT, append = TRUE) }
INGRESSO <- "analysis/input/S12r3-prova-compilazione-ingresso.jsonl"
REV_M <- "95a6d26c4bfb886c58daf9d3f7332c857cb27b43"
MODELLO <- list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506", llm_extra = list(revision = REV_M, tokenizer_revision = REV_M))
F_VISTE <- file.path(S12R, "60-viste-v0.jsonl")
stopifnot(identical(unname(tools::sha256sum(F_VISTE)), "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"))
viste <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
id <- vapply(viste, `[[`, "", "record_id"); solo_sviluppo(id); stopifnot(identical(id, studi_sviluppo()))

NEUTRO <- "This is a test of the output format. There is no study and there are no samples. Write a table with zero factors and zero items in not_understood. Give the role uninformative to every column."
SISTEMA <- "You write one JSON object. Follow the instruction of the user."
g0 <- sprintf("GSM%d", 1:12); col <- function(x) as.list(stats::setNames(x, g0))
finto <- list(record_id = "GSE0", campioni = as.list(g0), colonne = list("disease", "stage", "agent", "sex", "title"),
              tabella = list(disease = col(rep(c("healthy", "IBD", "IBD"), each = 4)), stage = col(rep(c("", "II", "III"), each = 4)),
                             agent = col(rep(c("none", "none", "Dex", "Dex"), 3)), sex = col(rep(c("F", "M", "F", "NA"), 3)),
                             title = col(sprintf("sample %d", 1:12))))
TESTO_FINTO <- paste(
  "This is a test of the output format with an invented table of 12 samples.",
  "Columns: disease (values: healthy, IBD), stage (values: empty, II, III), agent (values: none, Dex), sex (values: F, M, NA), title (sample 1 to sample 12).",
  "Write exactly three factors.",
  "Factor 1: name disease, type state, levels healthy and IBD, baseline healthy, assignment from the column disease.",
  "Factor 2: name stage, type state, levels II and III, no baseline, assignment from the column stage; the empty value has the level 'not applicable'.",
  "Factor 3: name compound, type perturbation, levels vehicle and dexamethasone, baseline vehicle, assignment from the column agent.",
  "Columns: disease, stage and agent have the role factor; sex is a subject column of kind sex with the missing value NA; title is a replicate column.", sep = "\n")
rec <- function(i, testo, sch, mt) as.character(toJSON(list(record_id = i, testo = testo, schema = sch, max_tokens = mt), auto_unbox = TRUE, null = "null"))
righe <- c(vapply(viste, function(v) rec(v$record_id, NEUTRO, schema_studio(v), 1024L), ""), rec("GSE0", TESTO_FINTO, schema_studio(finto), 2048L))
con <- file(INGRESSO, "wb"); writeLines(enc2utf8(righe), con, useBytes = TRUE); close(con)
if (!file.exists(OUT)) cat("12-prova-compilazione.R  PROVA DA BUTTARE\n", file = OUT)
nota("inizio %s, HEAD %s; ingresso %s: %d record (47 studi di sviluppo col messaggio neutro + GSE0 finto), %.1f MB",
     format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE),
     INGRESSO, length(righe), file.size(INGRESSO) / 1e6)

monta <- ssh_ripeti(function() .dgx_ssh(cfg, sprintf(
  "srun --partition=%s --account=%s --nodelist=poddgx02 --time=00:03:00 --cpus-per-task=1 --mem=1G bash -c 'hostname; test -d %s/bundles && test -d %s/runs && echo MONTATO'",
  cfg$partition, cfg$account, cfg$remote_root, cfg$remote_root)))
if (!grepl("poddgx02", monta$stdout, fixed = TRUE) || !grepl("MONTATO", monta$stdout, fixed = TRUE)) ferma("/home non montato su poddgx02: %s", gsub("\n", " ", monta$stdout))
nota("mount: %s", gsub("\n", " ", trimws(monta$stdout)))

f <- file.path(JOBS, "prova-compilazione-forma3.rds")   # forme 1 e 2: jobs/prova-compilazione.rds, -forma2.rds
if (file.exists(f)) j <- readRDS(f) else {
  b <- dgx_p4_build_bundle(INGRESSO, stage = "stage2b", config = cfg,
                           metadata = list(slug = "s12r3-prova-compilazione", prova = "S12r3 compilazione degli schemi"), modello = MODELLO)
  bd <- b$bundle_dir
  writeLines(SISTEMA, fs::path(bd, "prompt.txt"))
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- 65536L; g$max_tokens <- 24576L; g$gpu_memory_utilization <- 0.95
  .dgx_write_generation_json(g, gp)
  nota("bundle %s; generation.json: %s", b$run_id, as.character(toJSON(read_json(gp), auto_unbox = TRUE)))
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = "01:00:00", env = ENV_JOB)); saveRDS(j, f)
  nota("inviato: slurm %s, run_id %s", j$slurm_job_id, j$run_id)
}
m <- attendi(list(j), 60L); raccogli(j)
nota("slurm %s %s, durata %s, nodo %s", m[1, 1], m[1, 2], m[1, 3], m[1, 4])

# ---- Secondo job: il vincolo vale davvero? (controllo positivo dello schema a elenco chiuso) ----------------
# Lo stesso studio finto GSE0, ma il messaggio chiede un'uscita che lo schema NON ammette: un nome di colonna
# che non esiste, un valore solo, un valore inventato. Se la grammatica vincola, l'uscita porta lo stesso una
# colonna dell'elenco e tutte le voci della colonna, nell'ordine dello schema.
TESTO_CONTRO <- paste(
  "This is a test of the output format with an invented table of 12 samples.",
  "Columns: disease (values: healthy, IBD), stage (values: empty, II, III), agent (values: none, Dex), sex (values: F, M, NA), title (sample 1 to sample 12).",
  "Write exactly one factor: name stage, type state, levels II and III, no baseline.",
  "In the assignment, write the column name as 'Stage (grade)'. Write only one entry in values: the value 'grade 3' with the level III. Do not write any other entry.",
  "Columns: write only one entry, for the column 'gender', with role subject and the missing value 'unknown'.", sep = "\n")
INGRESSO2 <- "analysis/input/S12r3-prova-vincolo-ingresso.jsonl"
con <- file(INGRESSO2, "wb"); writeLines(enc2utf8(rec("GSE0-contro", TESTO_CONTRO, schema_studio(finto), 2048L)), con, useBytes = TRUE); close(con)
f2 <- file.path(JOBS, "prova-vincolo-forma3.rds")
if (file.exists(f2)) j2 <- readRDS(f2) else {
  b <- dgx_p4_build_bundle(INGRESSO2, stage = "stage2b", config = cfg,
                           metadata = list(slug = "s12r3-prova-vincolo", prova = "S12r3 il vincolo dello schema"), modello = MODELLO)
  bd <- b$bundle_dir
  writeLines(SISTEMA, fs::path(bd, "prompt.txt"))
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- 65536L; g$max_tokens <- 24576L; g$gpu_memory_utilization <- 0.95
  .dgx_write_generation_json(g, gp)
  j2 <- ssh_ripeti(function() dgx_p4_submit(b, time = "01:00:00", env = ENV_JOB)); saveRDS(j2, f2)
  nota("vincolo: inviato slurm %s, run_id %s", j2$slurm_job_id, j2$run_id)
}
m2 <- attendi(list(j2), 60L); raccogli(j2)
nota("vincolo: slurm %s %s, durata %s, nodo %s", m2[1, 1], m2[1, 2], m2[1, 3], m2[1, 4])

# ---- Controllo automatico delle uscite (forma 3) ------------------------------------------------------------
leggi <- function(j) { p <- file.path("analysis/p4-output", j$run_id, "predictions.jsonl")
  if (!file.exists(p)) p <- list.files(file.path("analysis/p4-output", j$run_id), pattern = "predictions.*jsonl$", full.names = TRUE, recursive = TRUE)[1]
  lapply(readLines(p, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE) }
pr <- leggi(j); pr <- stats::setNames(pr, vapply(pr, `[[`, "", "record_id"))
tutte <- c(stats::setNames(viste, id), list(GSE0 = finto))
esito <- do.call(rbind, lapply(names(tutte), function(i) {
  v <- tutte[[i]]; x <- pr[[i]]; u <- tryCatch(fromJSON(x$raw_output, simplifyVector = FALSE), error = function(e) NULL)
  cc <- as.character(unlist(v$colonne))
  data.frame(studio = i, fine = x$finish_reason %||% NA, token = x$n_output_tokens %||% NA, json_valido = !is.null(u),
             series_id = !is.null(u) && identical(u$series_id, i), fattori = if (is.null(u)) NA else length(u$factors),
             colonne_complete = !is.null(u) && identical(vapply(u$columns, function(k) k$column, ""), cc),
             non_soggetto_pulite = !is.null(u) && all(vapply(u$columns, function(k) k$role == "subject" || (identical(k$subject_kind, "") && !length(k$missing_values)), NA)))
}))
utils::write.csv(esito, file.path(DIR, "12-esito-forma3.csv"), row.names = FALSE)
s47 <- esito[esito$studio != "GSE0", ]
nota("FORMA 3, compilazione: fine stop %d/48; 47 studi: JSON valido %d, series_id giusto %d, zero fattori %d, tupla columns completa e in ordine %d, colonne non soggetto pulite %d; token massimo %d",
     sum(esito$fine == "stop"), sum(s47$json_valido), sum(s47$series_id), sum(s47$fattori == 0L), sum(s47$colonne_complete), sum(s47$non_soggetto_pulite), max(s47$token))
g <- esito[esito$studio == "GSE0", ]
nota("FORMA 3, GSE0: fine %s, %d token, %d fattori, tupla columns completa %s", g$fine, g$token, g$fattori, g$colonne_complete)
pv <- leggi(j2)[[1]]; uv <- fromJSON(pv$raw_output, simplifyVector = FALSE)
nota("FORMA 3, vincolo: fine %s, %d token; colonna del fattore '%s', voci %d (attese 3: '', II, III); columns: %s",
     pv$finish_reason, pv$n_output_tokens, uv$factors[[1]]$assignment$column, length(uv$factors[[1]]$assignment$values),
     paste(vapply(uv$columns, function(k) sprintf("%s=%s", k$column, k$role), ""), collapse = ", "))
