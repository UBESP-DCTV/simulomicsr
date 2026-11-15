#!/usr/bin/env Rscript
# 23-lancia.R — il secondo lettore: i modelli locali candidati leggono i 47 studi di sviluppo nella forma B0
# (prompt v2 e schema delle uscite a elenco chiuso, uno per studio), su poddgx02. Base: 23-lancia.R della terza
# prova (S12r3) e la lista MODELLI della prova ripetuta (S12r2).
#
# Che cosa resta uguale alla terza prova: la vista (60-viste-v0.jsonl), il prompt (21-prompt-v2.md), il generatore
# dello schema (10-schema-per-studio.R), l'ingresso (stessa impronta SHA-256), temperature 0, uscite strutturate,
# max_model_len 65536, max_tokens 24576, gpu_memory_utilization 0,95, contenitore vLLM 0.20.2.
# Che cosa cambia: il modello. Ogni candidato ha due corse: `rp11` (repetition_penalty 1,1, come Mistral) e
# `rp0` (senza il parametro). I candidati con il ragionamento lo hanno spento (chat_template_kwargs).
# `rp11r` e `rp0r` sono le repliche: si lanciano solo per i candidati che la regola di 00-previsioni.md ammette.
#
# Cancello K4, per ogni corsa: nodo poddgx02 e /home montato; prompt, generatore, vista e questo script uguali ai
# file committati in HEAD; ingresso uguale byte per byte a quello della terza prova; generation.json quello atteso;
# le variabili d'ambiente chieste lette in container-env.txt (il file porta il token di Hugging Face: non si
# stampa e non si committa); ogni worker dichiara «schema per record: N/N»; uscite congelate con SHA-256.
# K5: solo studi di sviluppo.
#
# Uso (run detached, poi verifica SID == PID):
#   CORSE=QW-rp11,QW-rp0 setsid nohup Rscript analysis/audit/2026-11-15-secondo-lettore/23-lancia.R \
#     >> analysis/audit/2026-11-15-secondo-lettore/log/lancia.out 2>&1 < /dev/null &
# Una corsa gia' inviata si riprende (jobs/<corsa>.rds). Una corsa fallita ferma lo script: si legge la causa nel
# log, si sposta il file .rds in jobs/falliti/ e si scrive il tentativo in 23-tentativi.md. Al massimo due
# tentativi per candidato, con un solo cambio fra il primo e il secondo.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")   # cfg (solo poddgx02), ENV_JOB, attendi(), raccogli(), K5
S12R <- DIR                                                   # la cartella di S12r: vista e divisione
R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"         # la terza prova: prompt v2, generatore, adattatore
DIR <- "analysis/audit/2026-11-15-secondo-lettore"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
for (d in c(LOG, JOBS)) fs::dir_create(d)
source(file.path(R3, "10-schema-per-studio.R"))               # schema_studio(), schema_json()
USCITE <- "analysis/p4-output/secondo-lettore-B0"; fs::dir_create(USCITE)
INGRESSO <- "analysis/input/secondo-lettore-B0-ingresso.jsonl"
INGRESSO_R3_SHA <- "36285df303bceb3585adb153de6ce7d1537d6464b7074ce7c56cee003e8c7cba"   # 23-out.txt della terza prova
F_PROMPT <- file.path(R3, "21-prompt-v2.md"); F_GENERATORE <- file.path(R3, "10-schema-per-studio.R")
F_ADATTATORE <- file.path(R3, "22-adattatore-v2.R"); F_LANCIO <- file.path(DIR, "23-lancia.R")
F_VISTE <- file.path(S12R, "60-viste-v0.jsonl")
VISTE_SHA <- "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"
MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 24576L; GPU_MEM <- 0.95   # 0.95: con 0.9 Mistral 3.2 non parte a 65536 (S12r)
# I candidati. tp = GPU per motore (il job ha 4 GPU: 4 worker da 1 GPU, o 2 worker da 2 GPU).
#  QW  Qwen3-30B-A3B-Instruct-2507: 56,8 GiB di pesi, cache KV di 6 GiB a 65.536 token: 1 GPU. Senza ragionamento.
#  GR  granite-4.2-30b: 54,6 GiB di pesi, cache KV di 16 GiB a 65.536 token: 2 GPU. Ragionamento spento.
#  GE  gemma-4-31B-it: 2 GPU come nella prova cieca (S12p, job 470088); ragionamento spento (e' il default).
rev <- function(r) list(revision = r, tokenizer_revision = r)
hf <- function(id, r, tp, extra = list(), kw = NULL) c(list(model_id = id, tokenizer_mode = "auto", config_format = "auto",
  load_format = "auto", tensor_parallel_size = tp, llm_extra = c(rev(r), extra)), if (!is.null(kw)) list(chat_template_kwargs = kw))
MODELLI <- list(
  QW = list(modello = hf("Qwen/Qwen3-30B-A3B-Instruct-2507", "0d7cf23991f47feeb3a57ecb4c9cee8ea4a17bfe", 1L), tp = 1L, kwargs = NULL),
  GR = list(modello = hf("ibm-granite/granite-4.2-30b", "9e668ce1c538387ef24d3644e9b0606647762636", 2L, kw = list(enable_thinking = FALSE)),
            tp = 2L, kwargs = list(enable_thinking = FALSE)),
  GE = list(modello = hf("google/gemma-4-31B-it", "842da3794eaa0b77d5f08bae87a17459d91ff475", 2L,
                         extra = list(limit_mm_per_prompt = list(image = 0L, video = 0L)), kw = list(enable_thinking = FALSE)),
            tp = 2L, kwargs = list(enable_thinking = FALSE)))
# rp11r e rp0r: la replica della corsa con lo stesso nome senza «r» (stessi parametri), per la ripetibilita'.
RP_DI <- c(rp11 = 1.1, rp0 = NA, rp11r = 1.1, rp0r = NA); TEMPO <- "06:00:00"
# SENZA_BI: candidati da lanciare senza VLLM_BATCH_INVARIANT (solo come secondo tentativo, scritto in 23-tentativi.md)
SENZA_BI <- strsplit(Sys.getenv("SENZA_BI", ""), ",", fixed = TRUE)[[1]]
env_di <- function(cod) if (cod %in% SENZA_BI) c(HF_HUB_OFFLINE = "1") else ENV_JOB
uguale_lista <- function(a, b) identical(as.character(toJSON(a, auto_unbox = TRUE)), as.character(toJSON(b, auto_unbox = TRUE)))
CORSE <- strsplit(Sys.getenv("CORSE", ""), ",", fixed = TRUE)[[1]]
AMMESSE <- as.vector(outer(names(MODELLI), names(RP_DI), paste, sep = "-"))
if (!length(CORSE) || !all(CORSE %in% AMMESSE)) stop("CORSE deve elencare corse fra: ", paste(AMMESSE, collapse = ", "), call. = FALSE)

OUT <- file.path(DIR, "23-out.txt")
nota <- function(...) { scrivi(...); cat(sprintf(...), "\n", sep = "", file = OUT, append = TRUE) }
sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))
sha_testo <- function(x) digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE)
sha_head <- function(f) {
  tmp <- tempfile(); on.exit(unlink(tmp))
  if (system2("git", c("show", paste0("HEAD:", f)), stdout = tmp, stderr = FALSE) != 0L) ferma("CANCELLO K4: %s non e' in HEAD", f)
  sha(tmp)
}
if (!file.exists(OUT)) cat("23-lancia.R  secondo lettore\n", file = OUT)
nota("inizio %s, HEAD %s, corse: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
     system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), paste(CORSE, collapse = ", "))

# ---- 1. l'ingresso: record_id + testo (la vista v0 congelata) + schema (uno per studio, dal generatore) ----
viste <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
id <- vapply(viste, `[[`, "", "record_id"); testo <- vapply(viste, `[[`, "", "testo")
solo_sviluppo(id); stopifnot(identical(id, studi_sviluppo()))
if (sha(F_VISTE) != VISTE_SHA) ferma("CANCELLO K4: la vista non e' quella di S12r")
for (f in c(F_PROMPT, F_GENERATORE, F_ADATTATORE, F_LANCIO, F_VISTE)) if (sha(f) != sha_head(f)) ferma("CANCELLO K4: %s diverso dal file committato", f)
SHA_PROMPT <- sha_head(F_PROMPT)
nota("file committati: prompt %s, generatore %s, adattatore %s, viste %s", SHA_PROMPT, sha_head(F_GENERATORE), sha_head(F_ADATTATORE), sha_head(F_VISTE))
schemi <- vapply(viste, schema_json, "")                      # il testo JSON dello schema di ogni studio
righe <- vapply(seq_along(id), function(i) as.character(toJSON(list(record_id = id[i], testo = testo[i], schema = schema_studio(viste[[i]])),
                                                                auto_unbox = TRUE, null = "null")), "")
# lo schema dentro il record e' lo stesso oggetto di schema_json(): si rilegge dalla riga e si riscrive
stopifnot(identical(vapply(righe, function(r) as.character(toJSON(fromJSON(r, simplifyVector = FALSE)$schema, auto_unbox = TRUE, null = "null")), "", USE.NAMES = FALSE),
                    vapply(schemi, function(s) as.character(toJSON(fromJSON(s, simplifyVector = FALSE), auto_unbox = TRUE, null = "null")), "", USE.NAMES = FALSE)))
con <- file(INGRESSO, "wb"); writeLines(enc2utf8(righe), con, useBytes = TRUE); close(con)
SHA_INGRESSO <- sha(INGRESSO)
if (SHA_INGRESSO != INGRESSO_R3_SHA) ferma("CANCELLO K4: l'ingresso non e' quello della terza prova (%s)", SHA_INGRESSO)
F_SCHEMI <- file.path(DIR, "23-schemi-sha256.csv")
tab_schemi <- data.frame(studio = id, schema_sha256 = vapply(schemi, sha_testo, "", USE.NAMES = FALSE), schema_caratteri = nchar(schemi, "chars"))
if (file.exists(F_SCHEMI)) {
  prima <- utils::read.csv(F_SCHEMI, stringsAsFactors = FALSE)
  if (!identical(prima$studio, tab_schemi$studio) || !identical(prima$schema_sha256, tab_schemi$schema_sha256)) ferma("CANCELLO K4: gli schemi generati adesso non sono quelli della corsa precedente (%s)", F_SCHEMI)
} else utils::write.csv(tab_schemi, F_SCHEMI, row.names = FALSE)
nota("ingresso %s: %d studi, %.1f MB, SHA-256 %s; schemi: uno per studio, impronte in %s", INGRESSO, length(id), file.size(INGRESSO) / 1e6, SHA_INGRESSO, F_SCHEMI)

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
  cod <- sub("-.*$", "", corsa); mo <- MODELLI[[cod]]; rp <- RP_DI[[sub("^.*-", "", corsa)]]
  b <- dgx_p4_build_bundle(INGRESSO, stage = "stage2b", config = cfg,
                           metadata = list(slug = paste0("secondo-lettore-b0-", tolower(corsa)), prova = "secondo lettore, forma B0"), modello = mo$modello)
  bd <- b$bundle_dir
  file.copy(F_PROMPT, fs::path(bd, "prompt.txt"), overwrite = TRUE)
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- MAX_MODEL_LEN; g$max_tokens <- MAX_TOKENS; g$gpu_memory_utilization <- GPU_MEM
  if (is.na(rp)) g$repetition_penalty <- NULL else g$repetition_penalty <- rp   # rp0: il campo non c'e'
  .dgx_write_generation_json(g, gp)
  mp <- fs::path(bd, "manifest.json"); m <- read_json(mp)
  m$schema_file <- "nel record: 10-schema-per-studio.R (terza prova)"; m$schema_version <- "factor_table.v2"; m$prompt_version <- "lettore-v2"
  write_json(m, mp, auto_unbox = TRUE, pretty = TRUE)
  if (sha(fs::path(bd, "prompt.txt")) != SHA_PROMPT) ferma("CANCELLO K4: prompt.txt del bundle %s diverso dal file committato", b$run_id)
  if (sha(fs::path(bd, "input.jsonl")) != SHA_INGRESSO) ferma("CANCELLO K4: input.jsonl del bundle %s diverso dall'ingresso", b$run_id)
  r <- lapply(readLines(fs::path(bd, "input.jsonl"), warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
  if (!identical(vapply(r, `[[`, "", "record_id"), id) || !identical(vapply(r, `[[`, "", "testo"), testo))
    ferma("CANCELLO K4: i testi del bundle %s non sono quelli delle viste", b$run_id)
  # i 47 schemi del bundle sono quelli che il generatore produce adesso dalla vista
  dal_bundle <- vapply(r, function(x) as.character(toJSON(x$schema, auto_unbox = TRUE, null = "null")), "")
  adesso <- vapply(viste, function(v) as.character(toJSON(fromJSON(schema_json(v), simplifyVector = FALSE), auto_unbox = TRUE, null = "null")), "")
  if (!identical(dal_bundle, adesso)) ferma("CANCELLO K4: gli schemi del bundle %s non sono quelli del generatore", b$run_id)
  if (any(vapply(r, function(x) !is.null(x$max_tokens), NA))) ferma("CANCELLO K4: un record del bundle %s porta il suo max_tokens", b$run_id)
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
  nota("%s: bundle %s, prompt uguale al file committato, ingresso uguale byte per byte, %d testi uguali alle viste, %d schemi uguali a quelli del generatore; generation.json: %s",
       corsa, b$run_id, length(r), length(dal_bundle), as.character(toJSON(g, auto_unbox = TRUE)))
  e <- env_di(cod)
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = TEMPO, env = e))
  saveRDS(j, f); nota("%s: inviato, slurm %s, run_id %s, ambiente chiesto: %s", corsa, j$slurm_job_id, j$run_id,
                      paste0(names(e), "=", e, collapse = " ")); j
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

# K4 per una corsa senza VLLM_BATCH_INVARIANT: le variabili chieste ci sono e quella tolta non c'e'.
raccogli_senza_bi <- function(j, env) {
  d <- ssh_ripeti(function() dgx_p4_collect(j))
  p <- file.path("analysis/p4-output", j$run_id, "container-env.txt"); e <- if (file.exists(p)) readLines(p) else character()
  if (!all(paste0(names(env), "=", env) %in% e)) ferma("CANCELLO K4: variabili assenti in %s", j$run_id)
  if (any(grepl("^VLLM_BATCH_INVARIANT=", e))) ferma("CANCELLO K4: VLLM_BATCH_INVARIANT presente in %s", j$run_id)
  scrivi("cancello K4: %s in %s, VLLM_BATCH_INVARIANT assente", paste0(names(env), "=", env, collapse = " "), j$run_id); d
}
# ---- 4. le corse: prima si inviano tutte (stanno in coda insieme), poi si raccolgono una per volta ----
# Un job che non finisce COMPLETED ferma lo script (attendi()): le altre corse restano in coda e si riprendono.
for (corsa in CORSE) if (!file.exists(file.path(USCITE, paste0(corsa, ".jsonl")))) invia(corsa)
for (corsa in CORSE) {
  uscita <- file.path(USCITE, paste0(corsa, ".jsonl")); cod <- sub("-.*$", "", corsa); e <- env_di(cod)
  if (file.exists(uscita)) { scrivi("%s: uscita gia' congelata, salto", corsa); next }
  j <- invia(corsa); m <- attendi(list(j), 300L); if (cod %in% SENZA_BI) raccogli_senza_bi(j, e) else raccogli(j)
  nota("%s: slurm %s %s, durata %s, nodo %s; container-env.txt: %s", corsa, m[1, 1], m[1, 2], m[1, 3], m[1, 4],
       paste0(names(e), "=", e, collapse = " e "))
  lg <- unlist(lapply(list.files(file.path("analysis/p4-output", j$run_id), pattern = "^slurm-.*[.]out$", full.names = TRUE), readLines, warn = FALSE))
  # ogni worker dichiara «schema per record: N/N»: tutti i record col proprio schema, nessuno con lo schema del bundle
  sr <- regmatches(lg, regexec("schema per record: ([0-9]+)/([0-9]+) record", lg)); sr <- sr[lengths(sr) == 3L]
  n_suo <- sum(as.integer(vapply(sr, `[`, "", 2))); n_tot <- sum(as.integer(vapply(sr, `[`, "", 3)))
  d <- leggi_corsa(j$run_id); d$run_id <- j$run_id
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
  nota("%s: uscite congelate, %d file in 23-uscite-sha256.txt", corsa, congela())
}
nota("LANCIO FINITO %s (%s)", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), paste(CORSE, collapse = ", "))
