#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 23-lancia.R — S12r4: le corse delle forme dell'uscita (10-forme.R) sui 47 studi di sviluppo, su poddgx02.
# Base: 23-lancia.R di S12r3, senza cambi alla configurazione.
#
# Una corsa = una forma su tutti i 47 studi. Il nome della corsa e' il nome della forma (B0, RA1, A0, ...);
# la seconda corsa di B0 e della forma finale si chiama `B0-corsa2` e `FIN-corsa2`. Una sola configurazione
# (00-previsioni.md): mistralai/Mistral-Small-3.2-24B-Instruct-2506, revisione fissata, temperature 0,
# repetition_penalty 1,1, uscite strutturate, max_model_len 65536, max_tokens 24576, vLLM 0.20.2, 4 worker da
# 1 GPU. Vista 60-viste-v0.jsonl. Il prompt della forma (21-prompt-<forma>.md) e' il messaggio di sistema. Lo
# schema delle uscite sta NEL RECORD (campo `schema`), uno per studio, da schema_forma(): anche nelle forme del
# lato A, dove lo schema e' uguale per tutti gli studi. Lo schema.json del bundle non si usa.
#
# Cancello sul bundle, per ogni corsa: nodo poddgx02 e /home montato (srun breve); 10-forme.R, questo script, la
# vista, il generatore di S12r3, lo schema v1 e i due prompt di partenza uguali ai file committati in HEAD; il
# prompt del bundle uguale al file committato e a prompt_forma(); l'ingresso del bundle uguale byte per byte
# all'ingresso scritto qui, i 47 testi uguali alla vista e i 47 schemi uguali a schema_forma(); per B0 l'ingresso
# ha lo stesso SHA-256 dell'ingresso delle corse di S12r3; generation.json quello atteso; nessun max_tokens nel
# record; VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1 lette da container-env.txt (solo quelle due righe: il file
# porta il token di Hugging Face, non si stampa e non si committa); ogni worker dichiara «schema per record: N/N».
# Le uscite si congelano con lo SHA-256 (23-uscite-sha256/<corsa>.txt) prima di ogni misura. Nessuna misura qui.
# Solo studi di sviluppo (solo_sviluppo() ferma tutto il resto).
#
# Uso (run detached, poi verifica SID == PID). Due processi con elenchi diversi usano le 8 GPU di poddgx02:
#   CORSE=B0,B0-corsa2 setsid nohup Rscript analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/23-lancia.R \
#     >> analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/log/lancia-1.out 2>&1 < /dev/null &
# Una corsa gia' inviata si riprende (jobs/<corsa>.rds); una corsa gia' congelata si salta; una corsa fallita ferma
# lo script: si legge la causa nel log, si sposta il file .rds in jobs/falliti/ e si rilancia una volta (dopo due
# fallimenti della stessa corsa STOP).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")   # cfg (solo poddgx02), ENV_JOB, attendi(), raccogli(), K5
S12R <- DIR
DIR <- "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
source(file.path(DIR, "10-forme.R"))                          # FORME (con FIN se 30-forma-finale.txt esiste), schema_forma(), prompt_forma()
USCITE <- "analysis/p4-output/S12r4-forme"; INGRESSI <- "analysis/input/S12r4-forme"; IMPRONTE <- file.path(DIR, "23-uscite-sha256")
for (d in c(LOG, JOBS, USCITE, INGRESSI, IMPRONTE)) fs::dir_create(d)
F_VISTE <- file.path(S12R, "60-viste-v0.jsonl")
VISTE_SHA <- "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"
INGRESSO_R3_SHA <- "36285df303bceb3585adb153de6ce7d1537d6464b7074ce7c56cee003e8c7cba"   # 23-out.txt di S12r3
MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 24576L; GPU_MEM <- 0.95
REV_M <- "95a6d26c4bfb886c58daf9d3f7332c857cb27b43"
MODELLO <- list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506", llm_extra = list(revision = REV_M, tokenizer_revision = REV_M))
RP <- 1.1; TEMPO <- "04:00:00"
CORSE <- strsplit(Sys.getenv("CORSE", ""), ",", fixed = TRUE)[[1]]
forma_di <- function(corsa) sub("-corsa2$", "", corsa)
AMMESSE <- c(names(FORME), intersect(c("B0-corsa2", "FIN-corsa2"), paste0(names(FORME), "-corsa2")))
if (!length(CORSE) || !all(CORSE %in% AMMESSE) || anyDuplicated(CORSE)) stop("CORSE deve elencare corse fra: ", paste(AMMESSE, collapse = ", "), call. = FALSE)

OUT <- file.path(DIR, "23-out.txt")
nota <- function(...) { scrivi(...); cat(sprintf(...), "\n", sep = "", file = OUT, append = TRUE) }
sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))
sha_testo <- function(x) digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE)
sha_head <- function(f) {
  tmp <- tempfile(); on.exit(unlink(tmp))
  if (system2("git", c("show", paste0("HEAD:", f)), stdout = tmp, stderr = FALSE) != 0L) ferma("CANCELLO: %s non e' in HEAD", f)
  sha(tmp)
}
if (!file.exists(OUT)) cat("23-lancia.R  PROVA DA BUTTARE\n", file = OUT)
HEAD <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)
nota("inizio %s, HEAD %s, corse: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), HEAD, paste(CORSE, collapse = ", "))

# ---- 1. la vista e i file committati ----
viste <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
id <- vapply(viste, `[[`, "", "record_id"); testo <- vapply(viste, `[[`, "", "testo")
solo_sviluppo(id); stopifnot(identical(id, studi_sviluppo()), length(id) == 47L)
if (sha(F_VISTE) != VISTE_SHA) ferma("CANCELLO: la vista non e' quella di S12r")
F_FISSI <- c(file.path(DIR, "10-forme.R"), file.path(DIR, "23-lancia.R"), file.path(DIR, "00-previsioni.md"), F_VISTE,
             file.path(R3, "10-schema-per-studio.R"), F_SCHEMA_V1, unname(F_PROMPT), if (file.exists(F_FIN)) F_FIN)
for (f in F_FISSI) if (sha(f) != sha_head(f)) ferma("CANCELLO: %s diverso dal file committato", f)
js1 <- function(x) as.character(toJSON(x, auto_unbox = TRUE, null = "null"))

# ---- 2. il nodo: /home/u0044 montato su poddgx02 (sinfo = idle non basta) ----
monta <- ssh_ripeti(function() .dgx_ssh(cfg, sprintf(
  "srun --partition=%s --account=%s --nodelist=poddgx02 --time=00:03:00 --cpus-per-task=1 --mem=1G bash -c 'hostname; test -d %s/bundles && test -d %s/runs && echo MONTATO'",
  cfg$partition, cfg$account, cfg$remote_root, cfg$remote_root)))
if (!grepl("poddgx02", monta$stdout, fixed = TRUE) || !grepl("MONTATO", monta$stdout, fixed = TRUE))
  ferma("CANCELLO: /home non montato su poddgx02 o nodo sbagliato: %s", gsub("\n", " ", monta$stdout))
nota("mount: %s", gsub("\n", " ", trimws(monta$stdout)))

# ---- 3. ingresso e bundle di una corsa, col cancello sul bundle ----
prepara <- function(nome) {                                    # l'ingresso e il prompt della FORMA (uguali per le due corse)
  f_p <- f_prompt_forma(nome); f_i <- file.path(INGRESSI, paste0(nome, ".jsonl"))
  if (!file.exists(f_p) || sha(f_p) != sha_head(f_p)) ferma("CANCELLO: %s manca o e' diverso dal file committato", f_p)
  if (!identical(sha(f_p), digest::digest(charToRaw(prompt_forma(nome)), algo = "sha256", serialize = FALSE))) ferma("CANCELLO: %s non e' prompt_forma(%s)", f_p, nome)
  schemi <- vapply(viste, function(v) js1(schema_forma(v, nome)), "")
  righe <- vapply(seq_along(id), function(i) js1(list(record_id = id[i], testo = testo[i], schema = schema_forma(viste[[i]], nome))), "")
  tmp <- paste0(f_i, ".tmp-", Sys.getpid()); con <- file(tmp, "wb"); writeLines(enc2utf8(righe), con, useBytes = TRUE); close(con)
  if (file.exists(f_i) && sha(f_i) != sha(tmp)) ferma("CANCELLO: l'ingresso %s scritto adesso non e' quello gia' su disco", f_i)
  file.rename(tmp, f_i)
  if (nome == "B0" && sha(f_i) != INGRESSO_R3_SHA) ferma("CANCELLO: l'ingresso di B0 non e' l'ingresso delle corse di S12r3")
  list(f_prompt = f_p, sha_prompt = sha(f_p), f_ingresso = f_i, sha_ingresso = sha(f_i), schemi = schemi)
}
invia <- function(corsa) {
  f <- file.path(JOBS, paste0(corsa, ".rds")); if (file.exists(f)) { scrivi("%s: job gia' inviato, riprendo", corsa); return(readRDS(f)) }
  nome <- forma_di(corsa); p <- prepara(nome)
  b <- dgx_p4_build_bundle(p$f_ingresso, stage = "stage2b", config = cfg,
                           metadata = list(slug = paste0("s12r4-", tolower(corsa)), prova = paste("S12r4 forma", nome)), modello = MODELLO)
  bd <- b$bundle_dir
  file.copy(p$f_prompt, fs::path(bd, "prompt.txt"), overwrite = TRUE)
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- MAX_MODEL_LEN; g$max_tokens <- MAX_TOKENS; g$gpu_memory_utilization <- GPU_MEM
  .dgx_write_generation_json(g, gp)
  mp <- fs::path(bd, "manifest.json"); m <- read_json(mp)
  m$schema_file <- "nel record: 10-forme.R (prova S12r4)"; m$schema_version <- paste0("S12r4-", nome); m$prompt_version <- paste0("S12r4-", nome)
  write_json(m, mp, auto_unbox = TRUE, pretty = TRUE)
  if (sha(fs::path(bd, "prompt.txt")) != p$sha_prompt) ferma("CANCELLO: prompt.txt del bundle %s diverso dal file committato", b$run_id)
  if (sha(fs::path(bd, "input.jsonl")) != p$sha_ingresso) ferma("CANCELLO: input.jsonl del bundle %s diverso dall'ingresso", b$run_id)
  r <- lapply(readLines(fs::path(bd, "input.jsonl"), warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
  if (!identical(vapply(r, `[[`, "", "record_id"), id) || !identical(vapply(r, `[[`, "", "testo"), testo))
    ferma("CANCELLO: i testi del bundle %s non sono quelli delle viste", b$run_id)
  dal_bundle <- vapply(r, function(x) js1(x$schema), "")
  adesso <- vapply(p$schemi, function(s) js1(fromJSON(s, simplifyVector = FALSE)), "", USE.NAMES = FALSE)
  if (!identical(dal_bundle, adesso)) ferma("CANCELLO: gli schemi del bundle %s non sono quelli di schema_forma(%s)", b$run_id, nome)
  if (any(vapply(r, function(x) !is.null(x$max_tokens), NA))) ferma("CANCELLO: un record del bundle %s porta il suo max_tokens", b$run_id)
  g <- read_json(gp)
  tp_g <- if (is.null(g$tensor_parallel_size)) 1L else as.integer(g$tensor_parallel_size)
  if (!identical(as.integer(g$max_model_len), MAX_MODEL_LEN) || !identical(as.integer(g$max_tokens), MAX_TOKENS) ||
      !identical(g$model_id, MODELLO$model_id) || !identical(as.numeric(g$temperature), 0) || !identical(as.numeric(g$repetition_penalty), RP) ||
      "chat_template_kwargs" %in% names(g) || !identical(tp_g, 1L) || !identical(g$llm_extra$revision, REV_M) ||
      !identical(g$llm_extra$tokenizer_revision, REV_M) || !identical(as.numeric(g$gpu_memory_utilization), GPU_MEM) || isTRUE(g$disable_guided_decoding))
    ferma("CANCELLO: generation.json del bundle %s non e' quello atteso", b$run_id)
  nota("%s: forma %s (lato %s, cambi: %s); bundle %s; prompt %s SHA-256 %s; ingresso %s SHA-256 %s, %.1f MB; %d testi uguali alle viste, %d schemi uguali a schema_forma(), impronta degli schemi %s; generation.json: %s",
       corsa, nome, FORME[[nome]]$lato, if (length(FORME[[nome]]$cambi)) paste(FORME[[nome]]$cambi, collapse = "+") else "nessuno", b$run_id,
       basename(p$f_prompt), p$sha_prompt, p$f_ingresso, p$sha_ingresso, file.size(p$f_ingresso) / 1e6, length(r), length(dal_bundle),
       sha_testo(paste(p$schemi, collapse = "\n")), js1(g))
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = TEMPO, env = ENV_JOB))
  j$corsa <- corsa; j$forma <- nome; j$head <- HEAD; j$sha_prompt <- p$sha_prompt; j$sha_ingresso <- p$sha_ingresso
  saveRDS(j, f); nota("%s: inviato, slurm %s, run_id %s, ambiente chiesto: %s", corsa, j$slurm_job_id, j$run_id,
                      paste0(names(ENV_JOB), "=", ENV_JOB, collapse = " ")); j
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
  if (anyDuplicated(d$record_id) || !all(d$record_id %in% id)) ferma("corsa %s: righe %d, studi distinti %d", run_id, nrow(d), length(unique(d$record_id)))
  d
}
congela <- function(corsa, run_id) {                           # una lista di impronte per corsa: due processi non si pestano
  d <- file.path("analysis/p4-output", run_id)
  files <- sort(c(file.path(USCITE, paste0(corsa, ".jsonl")), setdiff(list.files(d, full.names = TRUE), file.path(d, "container-env.txt"))))   # porta il token: non si tocca
  writeLines(sprintf("%s  %s", vapply(files, sha, ""), files), file.path(IMPRONTE, paste0(corsa, ".txt")))
  length(files)
}

# ---- 4. le corse, una dopo l'altra; ogni uscita si congela appena raccolta ----
for (corsa in CORSE) {
  uscita <- file.path(USCITE, paste0(corsa, ".jsonl"))
  if (file.exists(uscita)) { scrivi("%s: uscita gia' congelata, salto", corsa); next }
  j <- invia(corsa); m <- attendi(list(j), 60L); raccogli(j)
  nota("%s: slurm %s %s, durata %s, nodo %s; container-env.txt: %s", corsa, m[1, 1], m[1, 2], m[1, 3], m[1, 4],
       paste0(names(ENV_JOB), "=", ENV_JOB, collapse = " e "))
  lg <- unlist(lapply(list.files(file.path("analysis/p4-output", j$run_id), pattern = "^slurm-.*[.]out$", full.names = TRUE), readLines, warn = FALSE))
  sr <- regmatches(lg, regexec("schema per record: ([0-9]+)/([0-9]+) record", lg)); sr <- sr[lengths(sr) == 3L]
  n_suo <- sum(as.integer(vapply(sr, `[`, "", 2))); n_tot <- sum(as.integer(vapply(sr, `[`, "", 3)))
  d <- leggi_corsa(j$run_id); d$run_id <- j$run_id
  gen <- is.na(d$saltato)
  if (!length(sr) || n_suo != n_tot || n_suo < sum(gen)) ferma("CANCELLO: %s, schema per record %d/%d, studi mandati al modello %d", corsa, n_suo, n_tot, sum(gen))
  nota("%s: schema per record %d/%d (dai log dei worker)", corsa, n_suo, n_tot)
  rr <- vapply(seq_len(nrow(d)), function(i) as.character(toJSON(as.list(d[i, ]), auto_unbox = TRUE, na = "null", digits = NA)), "")
  con <- file(uscita, "wb"); writeLines(enc2utf8(rr), con, useBytes = TRUE); close(con)
  nota("%s: studi %d su %d, mandati al modello %d, oltre il contesto %d; fine stop %d, fine length %d; token contati = token di vLLM %d su %d; token del prompt mediana %.0f massimo %.0f; token dell'uscita mediana %.0f massimo %.0f",
       corsa, nrow(d), length(id), sum(gen), sum(!gen), sum(d$fine == "stop", na.rm = TRUE), sum(d$fine == "length", na.rm = TRUE),
       sum(d$n_prompt[gen] == d$n_prompt_vllm[gen], na.rm = TRUE), sum(gen),
       stats::median(d$n_prompt, na.rm = TRUE), max(d$n_prompt, na.rm = TRUE), stats::median(d$n_out[gen]), max(d$n_out[gen]))
  for (x in grep("generazione completata", lg, value = TRUE)) nota("%s: %s", corsa, x)
  nota("%s: uscite congelate, %d file in %s", corsa, congela(corsa, j$run_id), file.path(IMPRONTE, paste0(corsa, ".txt")))
}
nota("LANCIO FINITO %s (%s)", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), paste(CORSE, collapse = ", "))
