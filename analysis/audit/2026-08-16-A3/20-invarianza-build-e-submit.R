#!/usr/bin/env Rscript
# =============================================================================
# PROVA DELLA BATCH-INVARIANZA A COMPOSIZIONE DI SHARD DIVERSA
#
# LA DOMANDA. `VLLM_BATCH_INVARIANT=1` e' stata misurata il 2026-08-09 su 5 giri
# degli STESSI record, e ha dato 100% di identita'. Ma -- lo dichiara la misura
# stessa -- in tutti quei giri i record erano serviti dallo STESSO worker con lo
# STESSO shard. Non e' mai stato provato che la flag tenga quando cambia
# l'insieme dei record del job.
#
# PERCHE' CONTA QUI, e non e' una nota a margine. Il runtime divide i record fra
# i worker con `shard_round_robin` (record i -> worker i %% n_workers) e per lo
# Stadio 1 usa `MICROBATCH = None`, cioe' UNA sola chiamata con l'intero shard.
# Quindi lo shard -- e con lui il batch -- dipende da QUANTI record ha il job e
# da dove cade ciascun record nella lista. A3 rigenera 86.898 record; il re-run
# completo ne fa 508.037 in blocchi da 10.000. Sono job di dimensione diversa:
# se la flag non tiene fra job diversi, il movimento misurato da A3 mescola il
# rumore del modello con l'effetto della dimensione del job, e A3 non misura
# piu' quello che dice di misurare.
#
# IL DISEGNO. Gli stessi N record, due volte:
#   A) da soli in un job di N
#   B) mescolati in un job di N + M
# Cambia solo la composizione dello shard. Si confrontano i N record condivisi.
#
# CASI DI ACCETTAZIONE (in 21-invarianza-confronta.R):
#   positivo : con la flag, i N record condivisi sono byte-identici
#   negativo : SENZA la flag gli stessi N devono DIFFERIRE -- se no il
#              confronto non e' in grado di vedere nulla e il positivo passa
#              per costruzione
#   negativo : un record alterato di proposito deve far fallire il confronto
#
# Uso (GATED: sottomette al DGX):
#   Rscript analysis/audit/2026-08-16-A3/20-invarianza-build-e-submit.R
# Variabili: N_SHARED (default 1000), N_PAD (default 4000), STAGE (stage1)
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))

N_SHARED <- as.integer(Sys.getenv("N_SHARED", "1000"))
N_PAD    <- as.integer(Sys.getenv("N_PAD",    "4000"))
STAGE    <- Sys.getenv("STAGE", "stage1")
SRC      <- Sys.getenv("SRC", "analysis/input/A3-stage1-input.jsonl")
OUT_DIR  <- Sys.getenv("OUT_DIR", "analysis/audit/2026-08-16-A3")
DRY      <- nzchar(Sys.getenv("DRY_RUN"))

stopifnot(file.exists(SRC))
lines <- readLines(SRC, warn = FALSE)
stopifnot(length(lines) >= N_SHARED + N_PAD)

# Selezione deterministica: nessun Math.random, nessuna sorpresa fra due giri.
idx_shared <- seq_len(N_SHARED)
idx_pad    <- N_SHARED + seq_len(N_PAD)
shared <- lines[idx_shared]
pad    <- lines[idx_pad]

# Job A: i soli condivisi.
# Job B: condivisi + riempimento, RIMESCOLATI con seme fisso.
#
# ⚠️ Il primo disegno interlacciava in modo uniforme (1 condiviso ogni 4 di
# riempimento) e la guardia in fondo l'ha bocciato: con passo 5 e 4 worker,
# 5 %% 4 == 1 == il passo del job A, quindi OGNI record condiviso restava sullo
# STESSO worker. Il test sarebbe sembrato serio e non avrebbe provato nulla --
# esattamente il difetto che va a cercare nella misura del 9 agosto.
# Un rimescolamento con seme fisso e' deterministico (ri-eseguibile) e rompe la
# congruenza.
set.seed(20260816L)
mix <- sample(c(shared, pad))
stopifnot(length(mix) == length(shared) + length(pad))

rid <- function(x) sub('^.*"record_id":"([^"]+)".*$', "\\1", x)
ids_shared <- rid(shared)
stopifnot(!anyDuplicated(ids_shared))
pos_in_B <- match(ids_shared, rid(mix))
stopifnot(!any(is.na(pos_in_B)))

# Il test vale solo se il worker cambia per una parte consistente dei record.
n_workers <- 4L
w_A <- (idx_shared - 1L) %% n_workers
w_B <- (pos_in_B  - 1L) %% n_workers
frac_worker_cambiato <- mean(w_A != w_B)
cat(sprintf("record condivisi: %d | job A: %d record | job B: %d record\n",
            N_SHARED, length(shared), length(mix)))
cat(sprintf("worker DIVERSO fra A e B per il %.1f%% dei record condivisi\n",
            100 * frac_worker_cambiato))
if (frac_worker_cambiato < 0.5)
  stop("Il disegno non cambia abbastanza la composizione: il test proverebbe poco. Cambiare l'interlacciamento.")

dir.create(file.path(OUT_DIR, "invarianza"), recursive = TRUE, showWarnings = FALSE)
pA <- file.path(OUT_DIR, "invarianza", "jobA.jsonl")
pB <- file.path(OUT_DIR, "invarianza", "jobB.jsonl")
writeLines(shared, pA)
writeLines(mix, pB)
writeLines(ids_shared, file.path(OUT_DIR, "invarianza", "record-condivisi.txt"))
cat("scritti:", pA, pB, "\n")

if (DRY) { cat("\nDRY_RUN: mi fermo prima di costruire i bundle.\n"); quit(save = "no") }

cfg <- dgx_config()
submit_one <- function(path, slug, flag) {
  b <- dgx_p4_build_bundle(path, stage = STAGE, config = cfg,
                           metadata = list(slug = slug))
  env <- if (flag) c(VLLM_BATCH_INVARIANT = "1") else NULL
  j <- dgx_p4_submit(b, time = "04:00:00", env = env)
  cat(sprintf("  %-22s run_id=%s slurm=%s\n", slug, j$run_id, j$slurm_job_id))
  j
}

cat("\n== sottomissione (4 job) ==\n")
jobs <- list(
  A_flag   = submit_one(pA, "inv-A-flag",   TRUE),
  B_flag   = submit_one(pB, "inv-B-flag",   TRUE),
  A_noflag = submit_one(pA, "inv-A-noflag", FALSE),
  B_noflag = submit_one(pB, "inv-B-noflag", FALSE)
)
saveRDS(jobs, file.path(OUT_DIR, "invarianza", "jobs.rds"))
cat("\njob salvati in", file.path(OUT_DIR, "invarianza", "jobs.rds"), "\n")
