#!/usr/bin/env Rscript
# 40-lancia.R — la prova piccola su tutto ARCHS4: i due lettori locali leggono, nella forma B0 (prompt v2 e schema
# delle uscite a elenco chiuso, uno per studio), i due ingressi della prova, su poddgx02.
# Base: analysis/audit/2026-11-15-lettori-su-gemma/40-lancia.R (stesso codice per bundle, cancello K4, raccolta e
# congelamento; cambiano gli ingressi e i nomi delle corse).
#
# Che cosa resta uguale a ieri: il prompt (21-prompt-v2.md), il generatore dello schema (10-schema-per-studio.R),
# temperature 0, uscite strutturate, max_model_len 65536, max_tokens 24576, gpu_memory_utilization 0,95, contenitore
# vLLM 0.20.2, VLLM_BATCH_INVARIANT=1, i due modelli con le stesse revisioni e gli stessi parametri delle corse
# `M-rp11` (Mistral-Small 3.2, repetition_penalty 1,1, 4 lavoratori da 1 GPU) e `GE-rp0` (Gemma-4-31B senza
# repetition_penalty, 2 lavoratori da 2 GPU, enable_thinking FALSE).
# Che cosa cambia: gli studi. Due ingressi scritti da 21-ingresso.R (impronte in 21-ingresso-sha256-prova.txt):
#   `casuale`  500 studi nuovi estratti a caso (quelli con una vista e almeno una colonna non costante);
#   `coda`     i 40 studi nuovi piu' grandi e 50 studi aperti di Gemma gia' letti ieri (le righe dell'ingresso di ieri).
# Corse: `M-rp11-casuale`, `M-rp11-coda`, `GE-rp0-casuale`, `GE-rp0-coda`. Ogni job chiede 4 GPU: due job insieme
# usano le 8 GPU di poddgx02, gli altri due aspettano in coda.
#
# Cancello K4, per ogni corsa: nodo poddgx02 e /home montato; prompt, generatore, carta, elenco, programmi e impronte
# uguali ai file committati in HEAD; ingresso con l'impronta scritta da 21-ingresso.R; negli ingressi nessuno studio
# di giudizio, di sviluppo o chiuso di Gemma (K5); generation.json quello atteso; le variabili d'ambiente lette in
# container-env.txt (il file porta il token di Hugging Face: non si stampa e non si committa); ogni worker dichiara
# «schema per record: N/N»; uscite congelate con SHA-256. Cancello K3: ogni studio mandato ha una riga nell'uscita.
#
# Uso (run detached, poi verifica SID == PID):
#   CORSE=M-rp11-casuale,GE-rp0-casuale,M-rp11-coda,GE-rp0-coda setsid nohup Rscript \
#     analysis/audit/2026-11-16-archs4-intero/40-lancia.R >> analysis/audit/2026-11-16-archs4-intero/log/lancia.out 2>&1 < /dev/null &
# Una corsa gia' inviata si riprende (jobs/<corsa>.rds). Una corsa fallita ferma lo script.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")   # cfg (solo poddgx02), ENV_JOB, attendi(), raccogli()
S12R <- DIR
R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"
DIR <- "analysis/audit/2026-11-16-archs4-intero"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
for (d in c(LOG, JOBS)) fs::dir_create(d)
USCITE <- "analysis/p4-output/archs4-intero-prova-B0"; fs::dir_create(USCITE)
F_ING <- c(casuale = "analysis/input/archs4-b0-ingresso-prova-casuale.jsonl", coda = "analysis/input/archs4-b0-ingresso-prova-coda.jsonl")
F_PROMPT <- file.path(R3, "21-prompt-v2.md"); F_GENERATORE <- file.path(R3, "10-schema-per-studio.R")
F_LANCIO <- file.path(DIR, "40-lancia.R"); F_ELENCO <- file.path(DIR, "10-elenco.csv"); F_SHA_IN <- file.path(DIR, "21-ingresso-sha256-prova.txt")
MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 24576L; GPU_MEM <- 0.95
rev <- function(r) list(revision = r, tokenizer_revision = r)
hf <- function(id, r, tp, extra = list(), kw = NULL) c(list(model_id = id, tokenizer_mode = "auto", config_format = "auto",
  load_format = "auto", tensor_parallel_size = tp, llm_extra = c(rev(r), extra)), if (!is.null(kw)) list(chat_template_kwargs = kw))
REV_M <- "95a6d26c4bfb886c58daf9d3f7332c857cb27b43"
MODELLI <- list(
  # M: come nella terza prova (nessun campo in piu': 4 worker da 1 GPU, formato Mistral di default)
  M  = list(modello = list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506", llm_extra = rev(REV_M)), tp = 1L, kwargs = NULL),
  QW = list(modello = hf("Qwen/Qwen3-30B-A3B-Instruct-2507", "0d7cf23991f47feeb3a57ecb4c9cee8ea4a17bfe", 1L), tp = 1L, kwargs = NULL),
  GR = list(modello = hf("ibm-granite/granite-4.2-30b", "9e668ce1c538387ef24d3644e9b0606647762636", 2L, kw = list(enable_thinking = FALSE)),
            tp = 2L, kwargs = list(enable_thinking = FALSE)),
  GE = list(modello = hf("google/gemma-4-31B-it", "842da3794eaa0b77d5f08bae87a17459d91ff475", 2L,
                         extra = list(limit_mm_per_prompt = list(image = 0L, video = 0L)), kw = list(enable_thinking = FALSE)),
            tp = 2L, kwargs = list(enable_thinking = FALSE)))
RP_DI <- c(rp11 = 1.1, rp0 = NA, rp11r = 1.1, rp0r = NA); TEMPO <- "72:00:00"
uguale_lista <- function(a, b) identical(as.character(toJSON(a, auto_unbox = TRUE)), as.character(toJSON(b, auto_unbox = TRUE)))
CORSE <- strsplit(Sys.getenv("CORSE", ""), ",", fixed = TRUE)[[1]]
AMMESSE <- as.vector(outer(c("M-rp11", "GE-rp0"), names(F_ING), paste, sep = "-"))
# una corsa = <modello>-<repetition_penalty>-<pezzo>
parti <- function(corsa) { x <- strsplit(corsa, "-", fixed = TRUE)[[1]]; list(cod = x[1], rp = x[2], pezzo = x[3]) }
if (!length(CORSE) || !all(CORSE %in% AMMESSE)) stop("CORSE deve elencare corse fra: ", paste(AMMESSE, collapse = ", "), call. = FALSE)

OUT <- file.path(DIR, "40-out.txt")
nota <- function(...) { scrivi(...); cat(sprintf(...), "\n", sep = "", file = OUT, append = TRUE) }
sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))
sha_head <- function(f) {
  tmp <- tempfile(); on.exit(unlink(tmp))
  if (system2("git", c("show", paste0("HEAD:", f)), stdout = tmp, stderr = FALSE) != 0L) ferma("CANCELLO K4: %s non e' in HEAD", f)
  sha(tmp)
}
if (!file.exists(OUT)) cat("40-lancia.R  prova piccola su tutto ARCHS4: i due lettori locali, forma B0\n", file = OUT)
nota("inizio %s, HEAD %s, corse: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
     system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), paste(CORSE, collapse = ", "))

# ---- 1. gli ingressi: quelli di 21-ingresso.R; nessuno studio di giudizio, di sviluppo o chiuso di Gemma ----
for (f in c(F_PROMPT, F_GENERATORE, F_LANCIO, F_ELENCO, F_SHA_IN, file.path(DIR, c("00-previsioni.md", "20-vista-tutti.R", "21-ingresso.R"))))
  if (sha(f) != sha_head(f)) ferma("CANCELLO K4: %s diverso dal file committato", f)
SHA_PROMPT <- sha_head(F_PROMPT); SHA_ING <- vapply(F_ING, sha, "")
if (!identical(sprintf("%s  %s", SHA_ING, F_ING), readLines(F_SHA_IN))) ferma("CANCELLO K4: gli ingressi non hanno le impronte di 21-ingresso-sha256-prova.txt")
el <- utils::read.csv(F_ELENCO, stringsAsFactors = FALSE)
ID_ING <- lapply(F_ING, function(f) sub('^\\{"record_id":"(GSE[0-9]+)".*$', "\\1", readLines(f, warn = FALSE, encoding = "UTF-8")))
for (k in names(ID_ING)) {
  id <- ID_ING[[k]]; cl <- el$classe[match(id, el$gse)]; pr <- el$prova[match(id, el$gse)]
  ok <- if (k == "casuale") cl == "nuovo" & pr == "casuale" else (cl == "nuovo" & pr == "grandi") | (cl == "gemma_aperta" & pr == "controllo")
  if (anyDuplicated(id) || !all(grepl("^GSE[0-9]+$", id)) || anyNA(cl) || !all(ok) || any(id %in% DIVISIONE$gse))
    ferma("CANCELLO K5: l'ingresso %s contiene studi di giudizio, di sviluppo, chiusi di Gemma o fuori dalla prova, o righe doppie", k)
  nota("ingresso %s: %s, %d studi (%s), %.1f MB, SHA-256 %s", k, F_ING[[k]], length(id),
       paste(names(table(pr)), table(pr), collapse = ", "), file.size(F_ING[[k]]) / 1e6, SHA_ING[[k]])
}
if (length(intersect(ID_ING$casuale, ID_ING$coda))) ferma("CANCELLO K5: uno studio sta in tutti e due gli ingressi")
nota("file committati: prompt %s, generatore %s", SHA_PROMPT, sha_head(F_GENERATORE))

# ---- 2. il nodo: /home/u0044 montato su poddgx02 (sinfo = idle non basta) ----
monta <- ssh_ripeti(function() .dgx_ssh(cfg, sprintf(
  "srun --partition=%s --account=%s --nodelist=poddgx02 --time=00:03:00 --cpus-per-task=1 --mem=1G bash -c 'hostname; test -d %s/bundles && test -d %s/runs && echo MONTATO'",
  cfg$partition, cfg$account, cfg$remote_root, cfg$remote_root)))
if (!grepl("poddgx02", monta$stdout, fixed = TRUE) || !grepl("MONTATO", monta$stdout, fixed = TRUE))
  ferma("CANCELLO K4: /home non montato su poddgx02 o nodo sbagliato: %s", gsub("\n", " ", monta$stdout))
nota("mount: %s", gsub("\n", " ", trimws(monta$stdout)))

# ---- 3. bundle col prompt v2 e lo schema nel record, e il cancello K4 sul bundle ----
invia <- function(corsa) {
  f <- file.path(JOBS, paste0(corsa, ".rds")); if (file.exists(f)) { scrivi("%s: job gia' inviato, riprendo", corsa); return(readRDS(f)) }
  p <- parti(corsa); mo <- MODELLI[[p$cod]]; rp <- RP_DI[[p$rp]]; INGRESSO <- F_ING[[p$pezzo]]; SHA_INGRESSO <- SHA_ING[[p$pezzo]]
  b <- dgx_p4_build_bundle(INGRESSO, stage = "stage2b", config = cfg,
                           metadata = list(slug = paste0("archs4-prova-b0-", tolower(corsa)), prova = "prova piccola su tutto ARCHS4, forma B0"),
                           modello = mo$modello)
  bd <- b$bundle_dir
  file.copy(F_PROMPT, fs::path(bd, "prompt.txt"), overwrite = TRUE)
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- MAX_MODEL_LEN; g$max_tokens <- MAX_TOKENS; g$gpu_memory_utilization <- GPU_MEM
  if (is.na(rp)) g$repetition_penalty <- NULL else g$repetition_penalty <- rp
  .dgx_write_generation_json(g, gp)
  mp <- fs::path(bd, "manifest.json"); m <- read_json(mp)
  m$schema_file <- "nel record: 10-schema-per-studio.R (terza prova)"; m$schema_version <- "factor_table.v2"; m$prompt_version <- "lettore-v2"
  write_json(m, mp, auto_unbox = TRUE, pretty = TRUE)
  if (sha(fs::path(bd, "prompt.txt")) != SHA_PROMPT) ferma("CANCELLO K4: prompt.txt del bundle %s diverso dal file committato", b$run_id)
  if (sha(fs::path(bd, "input.jsonl")) != SHA_INGRESSO) ferma("CANCELLO K4: input.jsonl del bundle %s diverso dall'ingresso", b$run_id)
  g <- read_json(gp)
  tp_g <- if (is.null(g$tensor_parallel_size)) 1L else as.integer(g$tensor_parallel_size)
  rp_ok <- if (is.na(rp)) !("repetition_penalty" %in% names(g)) else identical(as.numeric(g$repetition_penalty), rp)
  kw_ok <- if (is.null(mo$kwargs)) !("chat_template_kwargs" %in% names(g)) else uguale_lista(g$chat_template_kwargs, mo$kwargs)
  if (!identical(as.integer(g$max_model_len), MAX_MODEL_LEN) || !identical(as.integer(g$max_tokens), MAX_TOKENS) ||
      !identical(g$model_id, mo$modello$model_id) || !identical(as.numeric(g$temperature), 0) || !rp_ok || !kw_ok ||
      !identical(tp_g, mo$tp) || !identical(g$llm_extra$revision, mo$modello$llm_extra$revision) ||
      !identical(g$llm_extra$tokenizer_revision, mo$modello$llm_extra$revision) ||
      !identical(as.numeric(g$gpu_memory_utilization), GPU_MEM) || isTRUE(g$disable_guided_decoding))
    ferma("CANCELLO K4: generation.json del bundle %s non e' quello atteso", b$run_id)
  nota("%s: bundle %s, prompt uguale al file committato, ingresso uguale byte per byte; generation.json: %s",
       corsa, b$run_id, as.character(toJSON(g, auto_unbox = TRUE)))
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = TEMPO, env = ENV_JOB))
  saveRDS(j, f); nota("%s: inviato, slurm %s, run_id %s, ambiente chiesto: %s", corsa, j$slurm_job_id, j$run_id,
                      paste0(names(ENV_JOB), "=", ENV_JOB, collapse = " ")); j
}

leggi_corsa <- function(run_id, id) {
  l <- readLines(file.path("analysis/p4-output", run_id, "predictions.jsonl"), warn = FALSE, encoding = "UTF-8")
  r <- lapply(l, fromJSON, simplifyVector = FALSE)
  g <- function(x, n, def) { v <- x[[n]]; if (is.null(v)) def else v }
  d <- data.frame(record_id = vapply(r, g, "", "record_id", NA_character_),
                  raw = vapply(r, g, "", "raw_output", NA_character_),
                  saltato = vapply(r, g, "", "skipped", NA_character_),
                  n_prompt = vapply(r, function(x) as.numeric(g(x, "n_prompt_tokens", NA)), 0),
                  n_prompt_vllm = vapply(r, function(x) as.numeric(g(x, "n_prompt_tokens_vllm", NA)), 0),
                  n_out = vapply(r, function(x) as.numeric(g(x, "n_output_tokens", NA)), 0),
                  fine = vapply(r, g, "", "finish_reason", NA_character_),
                  ts = vapply(r, g, "", "ts", NA_character_),
                  worker = vapply(r, function(x) as.numeric(g(x, "worker_id", NA)), 0), stringsAsFactors = FALSE)
  if (anyDuplicated(d$record_id) || !all(d$record_id %in% id)) ferma("corsa %s: righe %d, studi distinti %d", run_id, nrow(d), length(unique(d$record_id)))
  d
}
congela <- function() {
  fatti <- list.files(USCITE, pattern = "[.]jsonl$", full.names = TRUE)
  run <- vapply(sub("[.]jsonl$", "", basename(fatti)), function(k) readRDS(file.path(JOBS, paste0(k, ".rds")))$run_id, "")
  files <- sort(c(fatti, unlist(lapply(file.path("analysis/p4-output", run), function(d) {
    setdiff(list.files(d, full.names = TRUE), file.path(d, "container-env.txt"))   # porta il token: non si tocca
  }))))
  writeLines(sprintf("%s  %s", vapply(files, sha, ""), files), file.path(DIR, "40-uscite-sha256.txt"))
  length(files)
}

# ---- 4. le corse: prima si inviano tutte, poi si raccolgono una per volta ----
for (corsa in CORSE) if (!file.exists(file.path(USCITE, paste0(corsa, ".jsonl")))) invia(corsa)
for (corsa in CORSE) {
  uscita <- file.path(USCITE, paste0(corsa, ".jsonl"))
  if (file.exists(uscita)) { scrivi("%s: uscita gia' congelata, salto", corsa); next }
  j <- invia(corsa); m <- attendi(list(j), 600L); raccogli(j)
  nota("%s: slurm %s %s, durata %s, nodo %s; container-env.txt: %s", corsa, m[1, 1], m[1, 2], m[1, 3], m[1, 4],
       paste0(names(ENV_JOB), "=", ENV_JOB, collapse = " e "))
  lg <- unlist(lapply(list.files(file.path("analysis/p4-output", j$run_id), pattern = "^slurm-.*[.]out$", full.names = TRUE), readLines, warn = FALSE))
  sr <- regmatches(lg, regexec("schema per record: ([0-9]+)/([0-9]+) record", lg)); sr <- sr[lengths(sr) == 3L]
  n_suo <- sum(as.integer(vapply(sr, `[`, "", 2))); n_tot <- sum(as.integer(vapply(sr, `[`, "", 3)))
  id <- ID_ING[[parti(corsa)$pezzo]]
  d <- leggi_corsa(j$run_id, id); d$run_id <- j$run_id
  if (nrow(d) != length(id)) ferma("CANCELLO K3: %s, righe nell'uscita %d, studi mandati %d", corsa, nrow(d), length(id))
  gen <- is.na(d$saltato)
  if (!length(sr) || n_suo != n_tot || n_suo < sum(gen)) ferma("CANCELLO K4: %s, schema per record %d/%d, studi mandati al modello %d", corsa, n_suo, n_tot, sum(gen))
  nota("%s: schema per record %d/%d (dai log dei worker)", corsa, n_suo, n_tot)
  rr <- vapply(seq_len(nrow(d)), function(i) as.character(toJSON(as.list(d[i, ]), auto_unbox = TRUE, na = "null", digits = NA)), "")
  con <- file(uscita, "wb"); writeLines(enc2utf8(rr), con, useBytes = TRUE); close(con)
  nota("%s: studi %d su %d, mandati al modello %d, oltre il contesto %d; fine stop %d, fine length %d; token contati = token di vLLM %d su %d; token del prompt mediana %.0f massimo %.0f; token dell'uscita mediana %.0f massimo %.0f",
       corsa, nrow(d), length(id), sum(gen), sum(!gen), sum(d$fine == "stop", na.rm = TRUE), sum(d$fine == "length", na.rm = TRUE),
       sum(d$n_prompt[gen] == d$n_prompt_vllm[gen], na.rm = TRUE), sum(gen),
       stats::median(d$n_prompt, na.rm = TRUE), max(d$n_prompt, na.rm = TRUE), stats::median(d$n_out[gen]), max(d$n_out[gen]))
  for (x in grep("generazione completata|chat_template_kwargs|tensor_parallel_size=", lg, value = TRUE)) nota("%s: %s", corsa, x)
  nota("%s: uscite congelate, %d file in 40-uscite-sha256.txt", corsa, congela())
}
nota("LANCIO FINITO %s (%s)", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), paste(CORSE, collapse = ", "))
