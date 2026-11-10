# PROVA DA BUTTARE
# S12r, Task 9-10: aiuti comuni all'ingresso e alla corsa della prova del lettore dello studio (v0).
# Base: analysis/audit/2026-11-08-S12p-prova/aiuti.R (funzioni copiate; i nomi dei cancelli sono quelli di
# 00-previsioni.md di questa cartella: K4 al posto di K2). Si legge con source() dopo devtools::load_all(".").
# Nessun file in R/, nessun test: questo materiale non entra nel pacchetto.
suppressPackageStartupMessages({ library(jsonlite); library(fs) })
DIR <- "analysis/audit/2026-11-09-lettore-studio"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
SEME <- 20261109L
for (d in c(LOG, JOBS)) fs::dir_create(d)
cfg <- dgx_config(nodelist = "poddgx02")  # solo poddgx02: poddgx01 e' vietato dal PI
stopifnot(identical(cfg$nodelist, "poddgx02"))
ENV_JOB <- c(VLLM_BATCH_INVARIANT = "1", HF_HUB_OFFLINE = "1")

# Il modello della prova, con la revisione fissata nella cache del progetto (come in S12p).
MODELLI <- list(
  mistral = list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506",
                 llm_extra = list(revision = "95a6d26c4bfb886c58daf9d3f7332c857cb27b43",
                                  tokenizer_revision = "95a6d26c4bfb886c58daf9d3f7332c857cb27b43"))
)

# K5: la prova lavora solo sugli studi di sviluppo. Uno studio di giudizio ferma lo script.
DIVISIONE <- utils::read.delim(file.path(DIR, "30-divisione.tsv"), stringsAsFactors = FALSE)
solo_sviluppo <- function(gse) {
  parte <- DIVISIONE$parte[match(gse, DIVISIONE$gse)]
  fuori <- gse[is.na(parte) | parte != "sviluppo"]
  if (length(fuori) > 0L) stop(sprintf("K5: %d studi non di sviluppo, lo script si ferma", length(fuori)), call. = FALSE)
  invisible(gse)
}
studi_sviluppo <- function() {
  g <- sort(DIVISIONE$gse[DIVISIONE$parte == "sviluppo"]); stopifnot(length(g) == 47L, !anyDuplicated(g)); g
}

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
      partiti <- !grepl("^None", m[, 4]); if (any(m[partiti, 4] != "poddgx02")) { cancella(jobs); ferma("CANCELLO K4: job fuori da poddgx02: %s", paste(m[partiti & m[, 4] != "poddgx02", 1], collapse = " ")) }
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

# K4: le variabili d'ambiente arrivate davvero al container.
raccogli <- function(j) {
  d <- ssh_ripeti(function() dgx_p4_collect(j))
  p <- file.path("analysis/p4-output", j$run_id, "container-env.txt"); e <- if (file.exists(p)) readLines(p) else character()
  if (!all(c("VLLM_BATCH_INVARIANT=1", "HF_HUB_OFFLINE=1") %in% e)) ferma("CANCELLO K4: variabili assenti in %s", j$run_id)
  scrivi("cancello K4: VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1 in %s", j$run_id); d
}
