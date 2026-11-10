#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 23-lancia.R — S12r2: le corse del lettore v1 sui 47 studi di sviluppo, una dopo l'altra, su poddgx02.
#
# Corse (00-previsioni.md): M due volte, M0 una volta, G1 due volte, G2 due volte. Stessa vista per tutti
# (60-viste-v0.jsonl, byte-identica a S12r), stesso prompt (21-prompt-v1.md), stesso schema (20-schema-v1.json),
# temperature 0, uscite strutturate, max_model_len 65536, max_tokens 24576, vLLM 0.20.2.
#   M   mistralai/Mistral-Small-3.2-24B-Instruct-2506, repetition_penalty 1,1, 4 worker da 1 GPU
#   M0  lo stesso, senza repetition_penalty in generation.json (controllo)
#   G1  mistralai/Mistral-Small-4-119B-2603, ragionamento spento (reasoning_effort = none), 2 worker da 2 GPU
#   G2  Qwen/Qwen3.5-122B-A10B, ragionamento spento (enable_thinking = false), 1 worker da 4 GPU
#
# Cancello K4, per ogni corsa: nodo poddgx02 e /home montato (srun breve); prompt e schema del bundle uguali per
# SHA-256 ai file committati in HEAD; i 47 testi del bundle uguali alla vista v0; generation.json quello atteso
# (modello, revisione, temperatura, repetition_penalty, chat_template_kwargs); VLLM_BATCH_INVARIANT=1 e
# HF_HUB_OFFLINE=1 lette da container-env.txt (solo quelle due righe: il file porta il token di Hugging Face);
# uscite congelate con SHA-256 (23-uscite-sha256.txt) prima di ogni misura. Nessuna misura qui.
# K5: solo studi di sviluppo (solo_sviluppo() ferma tutto il resto).
#
# Uso (run detached, poi verifica SID == PID). CORSE = elenco delle corse, separato da virgole:
#   CORSE=M-corsa1,M-corsa2,M0-corsa1 setsid nohup Rscript analysis/audit/2026-11-10-S12r2-prova-ripetuta/23-lancia.R \
#     >> analysis/audit/2026-11-10-S12r2-prova-ripetuta/log/lancia.out 2>&1 < /dev/null &
# Una corsa gia' inviata si riprende (jobs/<corsa>.rds); una corsa fallita ferma lo script: si legge la causa nel
# log, si sposta il file .rds in jobs/falliti/ e si rilancia (al massimo due tentativi per un modello grande).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")   # cfg (solo poddgx02), ENV_JOB, attendi(), raccogli(), K5
S12R <- DIR                                                   # la cartella di S12r: vista e divisione
DIR <- "analysis/audit/2026-11-10-S12r2-prova-ripetuta"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
for (d in c(LOG, JOBS)) fs::dir_create(d)
USCITE <- "analysis/p4-output/S12r2-lettore-v1"; fs::dir_create(USCITE)
INGRESSO <- "analysis/input/S12r2-lettore-v1-ingresso.jsonl"
INGRESSO_S12R_SHA <- "867f9787295b1df129bd6695aad908e5f7b9b16627691e8972c9301570296247"   # 63-out.txt di S12r
F_PROMPT <- file.path(DIR, "21-prompt-v1.md"); F_SCHEMA <- file.path(DIR, "20-schema-v1.json")
F_VISTE <- file.path(S12R, "60-viste-v0.jsonl")
VISTE_SHA <- "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"
MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 24576L; GPU_MEM <- 0.95   # 0.95: con 0.9 Mistral 3.2 non parte a 65536 (S12r)
REV_M <- "95a6d26c4bfb886c58daf9d3f7332c857cb27b43"
REV_G1 <- "a11f36bebf709121056b1dbcc943d1c6afbe494d"
REV_G2 <- "dc4d348443bc740c68e2d77492492c11606384d5"
MODELLI <- list(
  M  = list(modello = list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
                           llm_extra = list(revision = REV_M, tokenizer_revision = REV_M)),
            rp = 1.1, tp = 1L, kwargs = NULL, tempo = "04:00:00"),
  M0 = list(modello = list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
                           llm_extra = list(revision = REV_M, tokenizer_revision = REV_M)),
            rp = NULL, tp = 1L, kwargs = NULL, tempo = "04:00:00"),
  G1 = list(modello = list(model_id = "mistralai/Mistral-Small-4-119B-2603", tensor_parallel_size = 2L,
                           llm_extra = list(revision = REV_G1, tokenizer_revision = REV_G1),
                           chat_template_kwargs = list(reasoning_effort = "none")),
            rp = 1.1, tp = 2L, kwargs = list(reasoning_effort = "none"), tempo = "08:00:00"),
  G2 = list(modello = list(model_id = "Qwen/Qwen3.5-122B-A10B", tokenizer_mode = "auto", config_format = "auto",
                           load_format = "auto", tensor_parallel_size = 4L,
                           llm_extra = list(revision = REV_G2, tokenizer_revision = REV_G2),
                           chat_template_kwargs = list(enable_thinking = FALSE)),
            rp = 1.1, tp = 4L, kwargs = list(enable_thinking = FALSE), tempo = "08:00:00")
)
CORSE <- strsplit(Sys.getenv("CORSE", ""), ",", fixed = TRUE)[[1]]
AMMESSE <- c("M-corsa1", "M-corsa2", "M0-corsa1", "G1-corsa1", "G1-corsa2", "G2-corsa1", "G2-corsa2")
if (!length(CORSE) || !all(CORSE %in% AMMESSE)) stop("CORSE deve elencare corse fra: ", paste(AMMESSE, collapse = ", "), call. = FALSE)

OUT <- file.path(DIR, "23-out.txt")
nota <- function(...) { scrivi(...); cat(sprintf(...), "\n", sep = "", file = OUT, append = TRUE) }
sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))
sha_head <- function(f) {
  tmp <- tempfile(); on.exit(unlink(tmp))
  if (system2("git", c("show", paste0("HEAD:", f)), stdout = tmp, stderr = FALSE) != 0L) ferma("CANCELLO K4: %s non e' in HEAD", f)
  sha(tmp)
}
if (!file.exists(OUT)) cat("23-lancia.R  PROVA DA BUTTARE\n", file = OUT)
nota("inizio %s, HEAD %s, corse: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
     system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), paste(CORSE, collapse = ", "))

# ---- 1. l'ingresso: record_id + testo, dalla vista v0 congelata (gli stessi byte di S12r) ----
viste <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
id <- vapply(viste, `[[`, "", "record_id"); testo <- vapply(viste, `[[`, "", "testo")
solo_sviluppo(id); stopifnot(identical(id, studi_sviluppo()))
if (sha(F_VISTE) != VISTE_SHA) ferma("CANCELLO K4: la vista non e' quella di S12r")
for (f in c(F_PROMPT, F_SCHEMA, F_VISTE)) if (sha(f) != sha_head(f)) ferma("CANCELLO K4: %s diverso dal file committato", f)
SHA_PROMPT <- sha_head(F_PROMPT); SHA_SCHEMA <- sha_head(F_SCHEMA)
nota("file committati: prompt %s, schema %s, viste %s", SHA_PROMPT, SHA_SCHEMA, sha_head(F_VISTE))
righe <- vapply(seq_along(id), function(i) as.character(toJSON(list(record_id = id[i], testo = testo[i]), auto_unbox = TRUE)), "")
con <- file(INGRESSO, "wb"); writeLines(enc2utf8(righe), con, useBytes = TRUE); close(con)
if (sha(INGRESSO) != INGRESSO_S12R_SHA) ferma("CANCELLO K4: l'ingresso non ha i byte dell'ingresso di S12r (%s)", sha(INGRESSO))
nota("ingresso %s: %d studi, SHA-256 %s (uguale all'ingresso di S12r)", INGRESSO, length(id), sha(INGRESSO))

# ---- 2. il nodo: /home/u0044 montato su poddgx02 (sinfo = idle non basta) ----
monta <- ssh_ripeti(function() .dgx_ssh(cfg, sprintf(
  "srun --partition=%s --account=%s --nodelist=poddgx02 --time=00:03:00 --cpus-per-task=1 --mem=1G bash -c 'hostname; test -d %s/bundles && test -d %s/runs && echo MONTATO'",
  cfg$partition, cfg$account, cfg$remote_root, cfg$remote_root)))
if (!grepl("poddgx02", monta$stdout, fixed = TRUE) || !grepl("MONTATO", monta$stdout, fixed = TRUE))
  ferma("CANCELLO K4: /home non montato su poddgx02 o nodo sbagliato: %s", gsub("\n", " ", monta$stdout))
nota("mount: %s", gsub("\n", " ", trimws(monta$stdout)))

# ---- 3. bundle con prompt e schema v1, e il cancello K4 sul bundle ----
uguale_lista <- function(a, b) identical(as.character(toJSON(a, auto_unbox = TRUE)), as.character(toJSON(b, auto_unbox = TRUE)))
invia <- function(corsa) {
  f <- file.path(JOBS, paste0(corsa, ".rds")); if (file.exists(f)) { scrivi("%s: job gia' inviato, riprendo", corsa); return(readRDS(f)) }
  cod <- sub("-.*$", "", corsa); mo <- MODELLI[[cod]]
  b <- dgx_p4_build_bundle(INGRESSO, stage = "stage2b", config = cfg,
                           metadata = list(slug = paste0("s12r2-lettore-v1-", corsa), prova = "S12r2 lettore v1"), modello = mo$modello)
  bd <- b$bundle_dir
  file.copy(F_PROMPT, fs::path(bd, "prompt.txt"), overwrite = TRUE); file.copy(F_SCHEMA, fs::path(bd, "schema.json"), overwrite = TRUE)
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- MAX_MODEL_LEN; g$max_tokens <- MAX_TOKENS; g$gpu_memory_utilization <- GPU_MEM
  if (is.null(mo$rp)) g$repetition_penalty <- NULL       # M0: il campo non c'e', il runner non passa il parametro
  .dgx_write_generation_json(g, gp)
  mp <- fs::path(bd, "manifest.json"); m <- read_json(mp)
  m$schema_file <- "20-schema-v1.json (prova S12r2)"; m$schema_version <- "factor_table.v1"; m$prompt_version <- "lettore-v1"
  write_json(m, mp, auto_unbox = TRUE, pretty = TRUE)
  if (sha(fs::path(bd, "prompt.txt")) != SHA_PROMPT) ferma("CANCELLO K4: prompt.txt del bundle %s diverso dal file committato", b$run_id)
  if (sha(fs::path(bd, "schema.json")) != SHA_SCHEMA) ferma("CANCELLO K4: schema.json del bundle %s diverso dal file committato", b$run_id)
  r <- lapply(readLines(fs::path(bd, "input.jsonl"), warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
  if (!identical(vapply(r, `[[`, "", "record_id"), id) || !identical(vapply(r, `[[`, "", "testo"), testo))
    ferma("CANCELLO K4: i testi del bundle %s non sono quelli delle viste", b$run_id)
  g <- read_json(gp)
  rp_ok <- if (is.null(mo$rp)) !("repetition_penalty" %in% names(g)) else identical(as.numeric(g$repetition_penalty), mo$rp)
  kw_ok <- if (is.null(mo$kwargs)) !("chat_template_kwargs" %in% names(g)) else uguale_lista(g$chat_template_kwargs, mo$kwargs)
  tp_g <- if (is.null(g$tensor_parallel_size)) 1L else as.integer(g$tensor_parallel_size)
  if (!identical(as.integer(g$max_model_len), MAX_MODEL_LEN) || !identical(as.integer(g$max_tokens), MAX_TOKENS) ||
      !identical(g$model_id, mo$modello$model_id) || !identical(as.numeric(g$temperature), 0) || !rp_ok || !kw_ok ||
      !identical(tp_g, mo$tp) || !identical(g$llm_extra$revision, mo$modello$llm_extra$revision) ||
      !identical(g$llm_extra$tokenizer_revision, mo$modello$llm_extra$revision) ||
      !identical(as.numeric(g$gpu_memory_utilization), GPU_MEM) || isTRUE(g$disable_guided_decoding))
    ferma("CANCELLO K4: generation.json del bundle %s non e' quello atteso", b$run_id)
  nota("%s: bundle %s, prompt e schema uguali ai file committati, %d testi uguali alle viste; generation.json: %s",
       corsa, b$run_id, length(r), as.character(toJSON(g, auto_unbox = TRUE)))
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = mo$tempo, env = ENV_JOB))
  saveRDS(j, f); nota("%s: inviato, slurm %s, run_id %s", corsa, j$slurm_job_id, j$run_id); j
}

leggi_corsa <- function(run_id) {
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
  # K3 si giudica nella misura: qui si ferma solo una riga doppia o uno studio estraneo
  if (anyDuplicated(d$record_id) || !all(d$record_id %in% id)) ferma("corsa %s: righe %d, studi distinti %d", run_id, nrow(d), length(unique(d$record_id)))
  d
}
congela <- function() {
  fatti <- list.files(USCITE, pattern = "[.]jsonl$", full.names = TRUE)
  run <- vapply(sub("[.]jsonl$", "", basename(fatti)), function(k) readRDS(file.path(JOBS, paste0(k, ".rds")))$run_id, "")
  files <- sort(c(fatti, unlist(lapply(file.path("analysis/p4-output", run), function(d) {
    setdiff(list.files(d, full.names = TRUE), file.path(d, "container-env.txt"))   # porta il token: non si tocca
  }))))
  writeLines(sprintf("%s  %s", vapply(files, sha, ""), files), file.path(DIR, "23-uscite-sha256.txt"))
  length(files)
}

# ---- 4. le corse, una dopo l'altra; ogni uscita si congela appena raccolta ----
for (corsa in CORSE) {
  uscita <- file.path(USCITE, paste0(corsa, ".jsonl"))
  if (file.exists(uscita)) { scrivi("%s: uscita gia' congelata, salto", corsa); next }
  j <- invia(corsa); m <- attendi(list(j), 120L); raccogli(j)
  nota("%s: slurm %s %s, durata %s, nodo %s; container-env.txt: VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1", corsa, m[1, 1], m[1, 2], m[1, 3], m[1, 4])
  d <- leggi_corsa(j$run_id); d$run_id <- j$run_id
  rr <- vapply(seq_len(nrow(d)), function(i) as.character(toJSON(as.list(d[i, ]), auto_unbox = TRUE, na = "null", digits = NA)), "")
  con <- file(uscita, "wb"); writeLines(enc2utf8(rr), con, useBytes = TRUE); close(con)
  gen <- is.na(d$saltato)
  nota("%s: studi %d su %d, mandati al modello %d, oltre il contesto %d; fine stop %d, fine length %d; token contati = token di vLLM %d su %d; token del prompt mediana %.0f massimo %.0f; token dell'uscita mediana %.0f massimo %.0f",
       corsa, nrow(d), length(id), sum(gen), sum(!gen), sum(d$fine == "stop", na.rm = TRUE), sum(d$fine == "length", na.rm = TRUE),
       sum(d$n_prompt[gen] == d$n_prompt_vllm[gen], na.rm = TRUE), sum(gen),
       stats::median(d$n_prompt, na.rm = TRUE), max(d$n_prompt, na.rm = TRUE), stats::median(d$n_out[gen]), max(d$n_out[gen]))
  lg <- unlist(lapply(list.files(file.path("analysis/p4-output", j$run_id), pattern = "^slurm-.*[.]out$", full.names = TRUE), readLines, warn = FALSE))
  for (x in grep("generazione completata|chat_template_kwargs|tensor_parallel_size=", lg, value = TRUE)) nota("%s: %s", corsa, x)
  nota("%s: uscite congelate, %d file in 23-uscite-sha256.txt", corsa, congela())
}
nota("LANCIO FINITO %s (%s)", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), paste(CORSE, collapse = ", "))
