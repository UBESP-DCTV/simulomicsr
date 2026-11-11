#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 23-lancia.R — S12r3: le due corse del lettore v2 (schema delle uscite a elenco chiuso) sui 47 studi di
# sviluppo, una dopo l'altra, su poddgx02. Base: 23-lancia.R di S12r2 e 12-prova-compilazione.R.
#
# Una sola configurazione (00-previsioni.md): mistralai/Mistral-Small-3.2-24B-Instruct-2506, revisione fissata,
# temperature 0, repetition_penalty 1,1, uscite strutturate, max_model_len 65536, max_tokens 24576, vLLM 0.20.2,
# 4 worker da 1 GPU. Stessa vista di S12r e S12r2 (60-viste-v0.jsonl). Prompt 21-prompt-v2.md (messaggio di
# sistema). Lo schema delle uscite sta NEL RECORD (campo `schema`), uno per studio, generato da
# 10-schema-per-studio.R dalla vista: lo schema.json del bundle non si usa (il runner lo dice nel log:
# «schema per record: N/N»).
#
# Cancello K4, per ogni corsa: nodo poddgx02 e /home montato (srun breve); prompt del bundle uguale per SHA-256
# al file committato in HEAD; generatore, adattatore e questo script uguali ai file committati in HEAD; l'ingresso
# del bundle uguale byte per byte all'ingresso scritto qui, e in piu' i 47 testi uguali alla vista v0 e i 47
# schemi uguali a quelli che il generatore produce adesso dalla vista; generation.json quello atteso (modello,
# revisione, temperatura, repetition_penalty); VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1 lette da
# container-env.txt (solo quelle due righe: il file porta il token di Hugging Face, non si stampa e non si
# committa); ogni worker dichiara che tutti i suoi record portano il proprio schema; uscite congelate con
# SHA-256 (23-uscite-sha256.txt) prima di ogni misura. Nessuna misura qui.
# K5: solo studi di sviluppo (solo_sviluppo() ferma tutto il resto).
#
# Uso (run detached, poi verifica SID == PID):
#   CORSE=M-corsa1,M-corsa2 setsid nohup Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/23-lancia.R \
#     >> analysis/audit/2026-11-11-S12r3-elenco-chiuso/log/lancia.out 2>&1 < /dev/null &
# Una corsa gia' inviata si riprende (jobs/<corsa>.rds); una corsa fallita ferma lo script: si legge la causa nel
# log, si sposta il file .rds in jobs/falliti/ e si rilancia una volta (no whack-a-mole: dopo due fallimenti STOP).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")   # cfg (solo poddgx02), ENV_JOB, attendi(), raccogli(), K5
S12R <- DIR                                                   # la cartella di S12r: vista e divisione
DIR <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
for (d in c(LOG, JOBS)) fs::dir_create(d)
source(file.path(DIR, "10-schema-per-studio.R"))              # schema_studio(), schema_json()
USCITE <- "analysis/p4-output/S12r3-lettore-v2"; fs::dir_create(USCITE)
INGRESSO <- "analysis/input/S12r3-lettore-v2-ingresso.jsonl"
F_PROMPT <- file.path(DIR, "21-prompt-v2.md"); F_GENERATORE <- file.path(DIR, "10-schema-per-studio.R")
F_ADATTATORE <- file.path(DIR, "22-adattatore-v2.R"); F_LANCIO <- file.path(DIR, "23-lancia.R")
F_VISTE <- file.path(S12R, "60-viste-v0.jsonl")
VISTE_SHA <- "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"
MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 24576L; GPU_MEM <- 0.95   # 0.95: con 0.9 Mistral 3.2 non parte a 65536 (S12r)
REV_M <- "95a6d26c4bfb886c58daf9d3f7332c857cb27b43"
MODELLO <- list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506", llm_extra = list(revision = REV_M, tokenizer_revision = REV_M))
RP <- 1.1; TEMPO <- "04:00:00"
CORSE <- strsplit(Sys.getenv("CORSE", ""), ",", fixed = TRUE)[[1]]
AMMESSE <- c("M-corsa1", "M-corsa2")
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
if (!file.exists(OUT)) cat("23-lancia.R  PROVA DA BUTTARE\n", file = OUT)
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
  b <- dgx_p4_build_bundle(INGRESSO, stage = "stage2b", config = cfg,
                           metadata = list(slug = paste0("s12r3-lettore-v2-", corsa), prova = "S12r3 lettore v2, schema a elenco chiuso"), modello = MODELLO)
  bd <- b$bundle_dir
  file.copy(F_PROMPT, fs::path(bd, "prompt.txt"), overwrite = TRUE)
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- MAX_MODEL_LEN; g$max_tokens <- MAX_TOKENS; g$gpu_memory_utilization <- GPU_MEM
  .dgx_write_generation_json(g, gp)
  mp <- fs::path(bd, "manifest.json"); m <- read_json(mp)
  m$schema_file <- "nel record: 10-schema-per-studio.R (prova S12r3)"; m$schema_version <- "factor_table.v2"; m$prompt_version <- "lettore-v2"
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
  if (!identical(as.integer(g$max_model_len), MAX_MODEL_LEN) || !identical(as.integer(g$max_tokens), MAX_TOKENS) ||
      !identical(g$model_id, MODELLO$model_id) || !identical(as.numeric(g$temperature), 0) || !identical(as.numeric(g$repetition_penalty), RP) ||
      "chat_template_kwargs" %in% names(g) || !identical(tp_g, 1L) || !identical(g$llm_extra$revision, REV_M) ||
      !identical(g$llm_extra$tokenizer_revision, REV_M) || !identical(as.numeric(g$gpu_memory_utilization), GPU_MEM) || isTRUE(g$disable_guided_decoding))
    ferma("CANCELLO K4: generation.json del bundle %s non e' quello atteso", b$run_id)
  nota("%s: bundle %s, prompt uguale al file committato, ingresso uguale byte per byte, %d testi uguali alle viste, %d schemi uguali a quelli del generatore; generation.json: %s",
       corsa, b$run_id, length(r), length(dal_bundle), as.character(toJSON(g, auto_unbox = TRUE)))
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = TEMPO, env = ENV_JOB))
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
  nota("%s: slurm %s %s, durata %s, nodo %s; container-env.txt: %s", corsa, m[1, 1], m[1, 2], m[1, 3], m[1, 4],
       paste0(names(ENV_JOB), "=", ENV_JOB, collapse = " e "))
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
  for (x in grep("generazione completata", lg, value = TRUE)) nota("%s: %s", corsa, x)
  nota("%s: uscite congelate, %d file in 23-uscite-sha256.txt", corsa, congela())
}
nota("LANCIO FINITO %s (%s)", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), paste(CORSE, collapse = ", "))
