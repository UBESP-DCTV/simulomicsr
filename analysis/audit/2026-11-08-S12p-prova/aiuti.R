# S12p: aiuti comuni a smoke e lancio pieno (base: analysis/audit/2026-11-05-S14-re-run-modello/50-catena.R).
# Si legge con source() dopo pkgload::load_all(".").
suppressPackageStartupMessages({ library(jsonlite); library(fs) })
DIR <- "analysis/audit/2026-11-08-S12p-prova"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs"); ST <- file.path(DIR, "stato")
S12 <- "analysis/audit/2026-11-07-S12-stadio2b-disegno"
INGR <- file.path(S12, "28-ingressi-1903.jsonl.gz")
IN_TUTTI <- "analysis/input/S12p-stage2b-1903.jsonl"
SEME <- 20261108L
for (d in c(LOG, JOBS, ST)) fs::dir_create(d)
cfg <- dgx_config(nodelist = "poddgx02")  # solo poddgx02: poddgx01 e' vietato dal PI
stopifnot(identical(cfg$nodelist, "poddgx02"))

# I tre modelli della prova, con la revisione fissata nella cache del progetto. Con HF_HUB_OFFLINE=1 il job non
# va in rete: la revisione esplicita serve perche' lo scaricamento a revisione fissata non scrive refs/main.
MODELLI <- list(
  mistral = list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
                 llm_extra = list(revision = "95a6d26c4bfb886c58daf9d3f7332c857cb27b43",
                                  tokenizer_revision = "95a6d26c4bfb886c58daf9d3f7332c857cb27b43")),
  magistral = list(model_id = "mistralai/Magistral-Small-2509", tokenizer_mode = "mistral",
                   config_format = "mistral", load_format = "mistral",
                   llm_extra = list(revision = "a31cc96ab10cf19bc42c628fedf1e359e0853c49",
                                    tokenizer_revision = "a31cc96ab10cf19bc42c628fedf1e359e0853c49")),
  # Gemma 4 31B (62,6 GB di pesi) non lascia su una H100 i 15,8 GiB di cache per 32.768 token (job 470088): il
  # modello si divide su 2 GPU, 2 worker per job. La modalita' batch invariant fissa NCCL in modo deterministico.
  gemma = list(model_id = "google/gemma-4-31B-it", tokenizer_mode = "auto", config_format = "auto",
               load_format = "auto", tensor_parallel_size = 2L,
               llm_extra = list(revision = "842da3794eaa0b77d5f08bae87a17459d91ff475",
                                tokenizer_revision = "842da3794eaa0b77d5f08bae87a17459d91ff475",
                                limit_mm_per_prompt = list(image = 0L, video = 0L)))
)
CAMPI_MODELLO <- c("model_id", "tokenizer_mode", "config_format", "load_format", "dtype",
                   "gpu_memory_utilization", "tensor_parallel_size", "llm_extra")
ENV_JOB <- c(VLLM_BATCH_INVARIANT = "1", HF_HUB_OFFLINE = "1")

scrivi <- function(...) { msg <- sprintf("[%s] %s", format(Sys.time(), "%m-%d %H:%M:%S"), sprintf(...)); cat(msg, "\n", sep = ""); cat(msg, "\n", sep = "", file = file.path(LOG, "catena.log"), append = TRUE); flush.console() }
ferma <- function(...) { scrivi("FERMO: %s", sprintf(...)); stop(sprintf(...), call. = FALSE) }
ssh_ripeti <- function(fun) { for (i in 1:30) { r <- tryCatch(fun(), error = function(e) e); if (!inherits(r, "error")) return(r); scrivi("ssh in errore (%d): %s", i, conditionMessage(r)); Sys.sleep(60) }; ferma("ssh non risponde da 30 minuti") }
id_job <- function(jobs) vapply(jobs, function(j) as.character(j$slurm_job_id), character(1), USE.NAMES = FALSE)
stati_sacct <- function(jobs) {
  ids <- id_job(jobs)
  for (i in 1:60) {
    r <- tryCatch(.dgx_ssh(cfg, sprintf("sacct -X -n -P -j %s -o JobID,State,Elapsed,NodeList", paste(ids, collapse = ","))), error = function(e) NULL)
    righe <- if (is.null(r)) character(0) else grep("[|]", strsplit(r$stdout, "\n")[[1]], value = TRUE)
    m <- do.call(rbind, strsplit(righe, "|", fixed = TRUE))
    if (!is.null(m) && ncol(m) == 4L && all(ids %in% m[, 1])) {
      m <- m[match(ids, m[, 1]), , drop = FALSE]
      partiti <- !grepl("^None", m[, 4]); if (any(m[partiti, 4] != "poddgx02")) { cancella(jobs); ferma("CANCELLO K2: job fuori da poddgx02: %s", paste(m[partiti & m[, 4] != "poddgx02", 1], collapse = " ")) }
      return(m)
    }
    scrivi("sacct senza risposta completa (%d), riprovo fra un minuto", i); Sys.sleep(60)
  }
  ferma("sacct non risponde da un'ora")
}
cancella <- function(jobs) { ssh_ripeti(function() .dgx_ssh(cfg, sprintf("scancel %s", paste(id_job(jobs), collapse = " ")))); scrivi("tolti dalla coda %d job", length(jobs)) }
FINE <- "^(COMPLETED|FAILED|CANCELLED|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY|PREEMPTED|BOOT_FAIL|DEADLINE)"
attendi <- function(jobs, ogni = 120L) {
  repeat {
    m <- stati_sacct(jobs); st <- sub(" .*$", "", m[, 2]); male <- grepl(FINE, st) & st != "COMPLETED"
    if (any(male)) ferma("job non completati: %s (%s)", paste(m[male, 1], collapse = " "), paste(st[male], collapse = " "))
    if (all(st == "COMPLETED")) break
    scrivi("job: %s", paste(names(table(st)), table(st), collapse = ", ")); Sys.sleep(ogni)
  }
  for (i in seq_len(nrow(m))) scrivi("slurm %s: %s %s %s", m[i, 1], m[i, 2], m[i, 3], m[i, 4])
  invisible(m)
}

# Il testo d'ingresso congelato, una riga per confronto: record_id e testo, nient'altro va al runner.
ingressi <- function() {
  l <- readLines(gzfile(INGR), warn = FALSE, encoding = "UTF-8")
  r <- lapply(l, fromJSON, simplifyVector = FALSE)
  data.frame(record_id = vapply(r, `[[`, "", "record_id"), testo = vapply(r, `[[`, "", "testo"),
             token_stimati = vapply(r, function(x) as.numeric(x$token_stimati), 0),
             completo = vapply(r, function(x) isTRUE(x$completo), TRUE), stringsAsFactors = FALSE)
}
scrivi_ingresso <- function(df, path) {
  righe <- vapply(seq_len(nrow(df)), function(i) as.character(toJSON(list(record_id = df$record_id[i], testo = df$testo[i]), auto_unbox = TRUE)), "")
  con <- file(path, open = "w", encoding = "UTF-8"); writeLines(righe, con, useBytes = TRUE); close(con); invisible(path)
}

# K1: prompt, schema e testo del bundle identici agli oggetti congelati.
controlla_bundle <- function(b, df, versione_prompt = "v1") {
  pp <- fs::path(b$bundle_dir, "prompt.txt"); p <- readChar(pp, fs::file_info(pp)$size, useBytes = TRUE); Encoding(p) <- "UTF-8"
  if (!identical(p, .s2b_prompt_sistema(versione_prompt))) ferma("CANCELLO K1: prompt del bundle %s diverso da .s2b_prompt_sistema(%s)", b$run_id, versione_prompt)
  sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))
  imp <- read.table(file.path(S12, "91-sha256.txt"), col.names = c("sha", "file"), stringsAsFactors = FALSE)
  if (sha(fs::path(b$bundle_dir, "schema.json")) != imp$sha[imp$file == "inst/schemas/comparison_check.stage2b.v1.json"]) ferma("CANCELLO K1: schema del bundle %s diverso dalle impronte", b$run_id)
  r <- lapply(readLines(fs::path(b$bundle_dir, "input.jsonl"), warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
  id <- vapply(r, `[[`, "", "record_id"); tx <- vapply(r, `[[`, "", "testo")
  if (!identical(tx, df$testo[match(id, df$record_id)]) || anyNA(match(id, df$record_id))) ferma("CANCELLO K1: testo del bundle %s diverso dall'ingresso congelato", b$run_id)
  scrivi("cancello K1: bundle %s, prompt, schema e %d testi identici", b$run_id, length(id))
}

invia <- function(p, slug, modello, df, time = "72:00:00", gen_over = NULL, versione_prompt = "v1") {
  f <- file.path(JOBS, paste0(slug, ".rds")); if (file.exists(f)) return(readRDS(f))
  b <- dgx_p4_build_bundle(p, stage = "stage2b", config = cfg, metadata = list(slug = slug), modello = modello, versione_prompt = versione_prompt)
  if (!is.null(gen_over)) { gp <- fs::path(b$bundle_dir, "generation.json"); g <- read_json(gp); for (n in names(gen_over)) g[[n]] <- gen_over[[n]]; .dgx_write_generation_json(g, gp) }
  controlla_bundle(b, df, versione_prompt)
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = time, env = ENV_JOB))
  saveRDS(j, f); scrivi("inviato %s slurm=%s run_id=%s", slug, j$slurm_job_id, j$run_id); j
}

# K2: le variabili d'ambiente arrivate davvero al container.
raccogli <- function(j) {
  d <- ssh_ripeti(function() dgx_p4_collect(j))
  p <- file.path("analysis/p4-output", j$run_id, "container-env.txt"); e <- if (file.exists(p)) readLines(p) else character()
  if (!all(c("VLLM_BATCH_INVARIANT=1", "HF_HUB_OFFLINE=1") %in% e)) ferma("CANCELLO K2: variabili assenti in %s", j$run_id)
  scrivi("cancello K2: VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1 in %s", j$run_id); d
}

# Le righe grezze del runner (anche over_limit), con la validazione sullo schema.
SCHEMA <- system.file("schemas/comparison_check.stage2b.v1.json", package = "simulomicsr")
# compile_schema()/validate_json() del pacchetto (R/validate.R), come chiede la spec §7: una stringa grezza va al
# validatore cosi' com'e'.
valida <- function(raw) {
  v <- compile_schema(SCHEMA)
  vapply(raw, function(x) if (is.na(x) || !nzchar(x)) FALSE else isTRUE(tryCatch(validate_json(x, v)$valid, error = function(e) FALSE)), logical(1), USE.NAMES = FALSE)
}
righe_run <- function(run_id) {
  l <- readLines(file.path("analysis/p4-output", run_id, "predictions.jsonl"), warn = FALSE, encoding = "UTF-8")
  r <- lapply(l, fromJSON, simplifyVector = FALSE)
  g <- function(x, n, def) { v <- x[[n]]; if (is.null(v)) def else v }
  data.frame(record_id = vapply(r, g, "", "record_id", NA_character_),
             raw = vapply(r, g, "", "raw_output", NA_character_),
             saltato = vapply(r, g, "", "skipped", NA_character_),
             n_prompt = vapply(r, function(x) as.numeric(g(x, "n_prompt_tokens", NA)), 0),
             n_prompt_vllm = vapply(r, function(x) as.numeric(g(x, "n_prompt_tokens_vllm", NA)), 0),
             n_out = vapply(r, function(x) as.numeric(g(x, "n_output_tokens", NA)), 0),
             fine = vapply(r, g, "", "finish_reason", NA_character_),
             # primo indice in cui i token del template e quelli di vLLM divergono (NA se uguali o non registrato)
             diff_pos = vapply(r, function(x) { d <- x$prompt_diff; if (is.null(d)) NA_real_ else as.numeric(d$pos) }, 0),
             diff_vllm = vapply(r, function(x) { d <- x$prompt_diff; if (is.null(d)) NA_character_ else paste(unlist(d$b), collapse = " ") }, ""),
             stringsAsFactors = FALSE)
}

# ---- esiti della regola dello Stadio 2b, senza riferimento ----------------------------------------------------
# Per ogni confronto: la lista (solo se valida sullo schema), la tecnica dell'H5 calcolata dal codice, l'ingresso
# completo (non oltre il limite) -> stage2b_decide(). Diagnostica: assi not_stated e citazioni trovate nel testo.
H5_CAMPI <- function() readRDS(file.path(S12, "20-campi-h5-campioni.rds"))
TENUTI <- function() readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
citazioni <- function(x) {
  out <- character()
  vai <- function(v, nome) {
    if (is.list(v)) { nn <- names(v); for (i in seq_along(v)) vai(v[[i]], if (is.null(nn)) nome else nn[i]) }
    else if (!is.null(nome) && startsWith(nome, "evidence") && is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)) out <<- c(out, v)
  }
  vai(x, NULL); out
}
esiti_di <- function(fin, df, h5 = H5_CAMPI(), ten = TENUTI()) {
  ok <- valida(fin$raw)
  rows <- lapply(seq_len(nrow(fin)), function(i) {
    rid <- fin$record_id[i]; t <- ten[ten$record_id == rid, ]
    if (nrow(t) != 1L) ferma("confronto %s: %d righe nell'elenco dei tenuti", rid, nrow(t))
    gt <- strsplit(t$gsm_t, ",")[[1]]; gc <- strsplit(t$gsm_c, ",")[[1]]
    tec <- .s2b_tecnica_h5(h5[match(gt, h5$geo_accession), ], h5[match(gc, h5$geo_accession), ])
    ck <- if (ok[i]) fromJSON(fin$raw[i], simplifyVector = FALSE) else NULL
    d <- stage2b_decide(ck, tecnica_h5 = tec, ingresso_completo = is.na(fin$saltato[i]))
    ns <- if (is.null(ck)) NA_integer_ else sum(vapply(ck$axes, function(a) identical(.s2b_chr(a$relation), "not_stated"), TRUE))
    cit <- if (is.null(ck)) character() else citazioni(ck)
    tx <- df$testo[match(rid, df$record_id)]
    data.frame(record_id = rid, valida = ok[i], completo = is.na(fin$saltato[i]), passa = d$passa,
               motivi = paste(d$motivi, collapse = " "), avvisi = paste(d$avvisi, collapse = " "),
               differenza = d$differenza, entita_isolata = paste(d$entita_isolata, collapse = " | "),
               assi_not_stated = ns, n_citazioni = length(cit),
               citazioni_trovate = sum(vapply(cit, function(q) grepl(q, tx, fixed = TRUE), TRUE)),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}
