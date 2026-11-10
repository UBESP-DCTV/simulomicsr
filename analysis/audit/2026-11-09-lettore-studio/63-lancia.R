#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 63-lancia.R — S12r, Task 10, passi 1 e 2: due corse uguali del lettore v0 sui 47 studi di sviluppo.
#
# Che cosa fa:
#   1. scrive l'ingresso del job (record_id + testo) dalle viste congelate 60-viste-v0.jsonl;
#   2. costruisce il bundle con lo stadio `stage2b` di dgx_p4_build_bundle() (il runner manda `testo` cosi'
#      com'e', non taglia il prompt e conta i token prima), poi NELLA CARTELLA DEL BUNDLE sostituisce prompt.txt
#      con i byte di 62-prompt-v0.md e schema.json con 61-schema-v0.json, e in generation.json mette
#      max_model_len = 65536 e max_tokens = 16384 (limite del prompt: 49.152 token) e gpu_memory_utilization = 0.95
#      (con 0.9 il motore non parte: vedi GPU_MEM);
#   3. cancello K4 prima dell'invio: i due file del bundle hanno lo SHA-256 dei file committati in HEAD, i testi
#      del bundle sono quelli delle viste, il nodo e' poddgx02 e /home/u0044 e' montato sul nodo (srun breve);
#   4. invia due job uno dopo l'altro (corsa1, corsa2), 4 GPU di poddgx02, con VLLM_BATCH_INVARIANT=1 e
#      HF_HUB_OFFLINE=1; raccoglie; legge le due variabili da container-env.txt (K4);
#   5. congela le uscite: analysis/p4-output/S12r-lettore-v0/corsa{1,2}.jsonl e 63-uscite-sha256.txt.
# Nessuna misura qui: le uscite si congelano e si committano prima (passo 2 del Task 10).
#
# K5: lo script lavora solo sugli studi di sviluppo (solo_sviluppo() ferma tutto il resto).
# Uso (run detached, poi verifica SID == PID):
#   setsid nohup Rscript analysis/audit/2026-11-09-lettore-studio/63-lancia.R \
#     >> analysis/audit/2026-11-09-lettore-studio/log/lancia.out 2>&1 < /dev/null &
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")
USCITE <- "analysis/p4-output/S12r-lettore-v0"; fs::dir_create(USCITE)
INGRESSO <- "analysis/input/S12r-lettore-v0-ingresso.jsonl"
F_PROMPT <- file.path(DIR, "62-prompt-v0.md"); F_SCHEMA <- file.path(DIR, "61-schema-v0.json"); F_VISTE <- file.path(DIR, "60-viste-v0.jsonl")
MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 16384L
# Primo invio (slurm 476592, 2026-11-10) fallito all'avvio del motore: con gpu_memory_utilization 0.9 una H100
# lascia 8,36 GiB alla cache KV e max_model_len 65536 ne chiede 10,0 ("estimated maximum model length is 54768").
# 0.95 aggiunge circa 4 GiB (attesi ~12,3). Cambia solo la memoria riservata, non il testo generato.
GPU_MEM <- 0.95
OUT <- file.path(DIR, "63-out.txt")
nota <- function(...) { scrivi(...); cat(sprintf(...), "\n", sep = "", file = OUT, append = TRUE) }
sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))
# SHA-256 del file come sta in HEAD (git show): il file di lavoro deve essere quello committato.
sha_head <- function(f) {
  tmp <- tempfile(); on.exit(unlink(tmp))
  if (system2("git", c("show", paste0("HEAD:", f)), stdout = tmp, stderr = FALSE) != 0L) ferma("CANCELLO K4: %s non e' in HEAD", f)
  sha(tmp)
}

if (!file.exists(OUT)) cat("63-lancia.R  PROVA DA BUTTARE\n", file = OUT)
nota("inizio %s, HEAD %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE))

# ---- 1. l'ingresso: record_id + testo, dalle viste congelate ----
viste <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
id <- vapply(viste, `[[`, "", "record_id"); testo <- vapply(viste, `[[`, "", "testo")
solo_sviluppo(id); stopifnot(identical(id, studi_sviluppo()))
for (f in c(F_PROMPT, F_SCHEMA, F_VISTE)) if (sha(f) != sha_head(f)) ferma("CANCELLO K4: %s diverso dal file committato", f)
SHA_PROMPT <- sha_head(F_PROMPT); SHA_SCHEMA <- sha_head(F_SCHEMA)
nota("file committati: prompt %s, schema %s, viste %s", SHA_PROMPT, SHA_SCHEMA, sha_head(F_VISTE))
righe <- vapply(seq_along(id), function(i) as.character(toJSON(list(record_id = id[i], testo = testo[i]), auto_unbox = TRUE)), "")
con <- file(INGRESSO, "wb"); writeLines(enc2utf8(righe), con, useBytes = TRUE); close(con)
nota("ingresso %s: %d studi, SHA-256 %s", INGRESSO, length(id), sha(INGRESSO))

# ---- 3a. il nodo: /home/u0044 montato su poddgx02 (sinfo = idle non basta) ----
monta <- ssh_ripeti(function() .dgx_ssh(cfg, sprintf(
  "srun --partition=%s --account=%s --nodelist=poddgx02 --time=00:03:00 --cpus-per-task=1 --mem=1G bash -c 'hostname; test -d %s/bundles && test -d %s/runs && echo MONTATO'",
  cfg$partition, cfg$account, cfg$remote_root, cfg$remote_root)))
if (!grepl("poddgx02", monta$stdout, fixed = TRUE) || !grepl("MONTATO", monta$stdout, fixed = TRUE))
  ferma("CANCELLO K4: /home non montato su poddgx02 o nodo sbagliato: %s", gsub("\n", " ", monta$stdout))
nota("mount: %s", gsub("\n", " ", trimws(monta$stdout)))

# ---- 2 e 3b. bundle con prompt e schema v0, e il cancello K4 sul bundle ----
invia <- function(slug) {
  f <- file.path(JOBS, paste0(slug, ".rds")); if (file.exists(f)) { scrivi("%s: job gia' inviato, riprendo", slug); return(readRDS(f)) }
  b <- dgx_p4_build_bundle(INGRESSO, stage = "stage2b", config = cfg, metadata = list(slug = slug, prova = "S12r lettore v0"),
                           modello = MODELLI$mistral)
  bd <- b$bundle_dir
  file.copy(F_PROMPT, fs::path(bd, "prompt.txt"), overwrite = TRUE); file.copy(F_SCHEMA, fs::path(bd, "schema.json"), overwrite = TRUE)
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- MAX_MODEL_LEN; g$max_tokens <- MAX_TOKENS; g$gpu_memory_utilization <- GPU_MEM; .dgx_write_generation_json(g, gp)
  # il manifesto dice il vero: schema e prompt sono quelli della prova, non quelli dello Stadio 2b
  mp <- fs::path(bd, "manifest.json"); m <- read_json(mp)
  m$schema_file <- "61-schema-v0.json (prova S12r)"; m$schema_version <- "factor_table.v0"; m$prompt_version <- "lettore-v0"
  write_json(m, mp, auto_unbox = TRUE, pretty = TRUE)
  # K4 sul bundle: prompt e schema uguali ai file committati, testi uguali alle viste, configurazione attesa
  if (sha(fs::path(bd, "prompt.txt")) != SHA_PROMPT) ferma("CANCELLO K4: prompt.txt del bundle %s diverso dal file committato", b$run_id)
  if (sha(fs::path(bd, "schema.json")) != SHA_SCHEMA) ferma("CANCELLO K4: schema.json del bundle %s diverso dal file committato", b$run_id)
  r <- lapply(readLines(fs::path(bd, "input.jsonl"), warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
  if (!identical(vapply(r, `[[`, "", "record_id"), id) || !identical(vapply(r, `[[`, "", "testo"), testo))
    ferma("CANCELLO K4: i testi del bundle %s non sono quelli delle viste", b$run_id)
  g <- read_json(gp)
  if (!identical(as.integer(g$max_model_len), MAX_MODEL_LEN) || !identical(as.integer(g$max_tokens), MAX_TOKENS) ||
      !identical(g$model_id, MODELLI$mistral$model_id) || !identical(as.numeric(g$temperature), 0) ||
      !identical(as.numeric(g$repetition_penalty), 1.1) || !identical(as.numeric(g$gpu_memory_utilization), GPU_MEM) ||
      isTRUE(g$disable_guided_decoding))
    ferma("CANCELLO K4: generation.json del bundle %s non e' quello atteso", b$run_id)
  nota("%s: bundle %s, prompt e schema uguali ai file committati, %d testi uguali alle viste; generation.json: %s",
       slug, b$run_id, length(r), as.character(toJSON(g, auto_unbox = TRUE)))
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = "04:00:00", env = ENV_JOB))
  saveRDS(j, f); nota("%s: inviato, slurm %s, run_id %s", slug, j$slurm_job_id, j$run_id); j
}

# ---- 4. due corse uguali, una dopo l'altra ----
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
  if (anyDuplicated(d$record_id) || !setequal(d$record_id, id)) ferma("corsa %s: righe %d, studi distinti %d, attesi %d", run_id, nrow(d), length(unique(d$record_id)), length(id))
  d[match(id, d$record_id), ]
}
corse <- list()
for (slug in c("corsa1", "corsa2")) {
  j <- invia(paste0("s12r-lettore-v0-", slug)); m <- attendi(list(j), 120L); raccogli(j)
  nota("%s: slurm %s %s, durata %s, nodo %s; container-env.txt: VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1", slug, m[1, 1], m[1, 2], m[1, 3], m[1, 4])
  d <- leggi_corsa(j$run_id); d$run_id <- j$run_id; corse[[slug]] <- d
  rr <- vapply(seq_len(nrow(d)), function(i) as.character(toJSON(as.list(d[i, ]), auto_unbox = TRUE, na = "null", digits = NA)), "")
  con <- file(file.path(USCITE, paste0(slug, ".jsonl")), "wb"); writeLines(enc2utf8(rr), con, useBytes = TRUE); close(con)
  gen <- is.na(d$saltato)
  nota("%s: studi %d, mandati al modello %d, oltre il contesto %d; fine stop %d, fine length %d; token contati = token di vLLM %d su %d; token del prompt mediana %.0f massimo %.0f; token dell'uscita mediana %.0f massimo %.0f",
       slug, nrow(d), sum(gen), sum(!gen), sum(d$fine == "stop", na.rm = TRUE), sum(d$fine == "length", na.rm = TRUE),
       sum(d$n_prompt[gen] == d$n_prompt_vllm[gen], na.rm = TRUE), sum(gen),
       stats::median(d$n_prompt, na.rm = TRUE), max(d$n_prompt, na.rm = TRUE), stats::median(d$n_out[gen]), max(d$n_out[gen]))
  lg <- list.files(file.path("analysis/p4-output", j$run_id), pattern = "^slurm-.*[.]out$", full.names = TRUE)
  for (x in grep("generazione completata", unlist(lapply(lg, readLines, warn = FALSE)), value = TRUE)) nota("%s: %s", slug, x)
}

# ---- 5. congela le uscite ----
cartelle <- c(USCITE, file.path("analysis/p4-output", vapply(corse, function(d) d$run_id[1], "")))
files <- sort(unlist(lapply(cartelle, function(d) list.files(d, full.names = TRUE))))
writeLines(sprintf("%s  %s", vapply(files, sha, ""), files), file.path(DIR, "63-uscite-sha256.txt"))
nota("uscite congelate: %d file in 63-uscite-sha256.txt (cartelle: %s)", length(files), paste(cartelle, collapse = ", "))
nota("LANCIO FINITO %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
