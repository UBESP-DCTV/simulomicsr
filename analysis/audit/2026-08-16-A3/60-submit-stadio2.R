#!/usr/bin/env Rscript
# =============================================================================
# A3 — Stadio 2 sui soli studi del sottoinsieme (GATED: tocca il DGX)
#
# Configurazione IDENTICA al fullrun v3 (`p4-fase-f4-stage2-fullrun-v3.R`):
# `tiered_max_tokens = TRUE`, nient'altro toccato. Piu' la flag.
# Non si cambia una leva mentre se ne misura un'altra.
#
# Uso:
#   DRY_RUN=1 Rscript analysis/audit/2026-08-16-A3/60-submit-stadio2.R
#   Rscript analysis/audit/2026-08-16-A3/60-submit-stadio2.R
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))

IN   <- Sys.getenv("A3_S2_INPUT", "analysis/input/A3-stage2-input.jsonl")
A3   <- Sys.getenv("A3_LIST", "analysis/audit/2026-08-16-A3/A3-studi.txt")
OUT  <- Sys.getenv("OUT", "analysis/input/A3-stage2-subset.jsonl")
DRY  <- nzchar(Sys.getenv("DRY_RUN"))
stopifnot(file.exists(IN), file.exists(A3))

a3 <- readLines(A3)
lines <- readLines(IN, warn = FALSE)
sid <- sub('^.*"series_id":"([^"]+)".*$', "\\1", lines)
stopifnot(!any(sid == lines))
sel <- lines[sid %in% a3]

cat(sprintf("input Stadio 2: %d record, %d studi\n", length(lines), length(unique(sid))))
cat(sprintf("sottoinsieme A3: %d record, %d studi\n",
            length(sel), length(unique(sid[sid %in% a3]))))

cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(n, e, d) { cat(sprintf("  [%s] %-50s %s\n", if (isTRUE(e)) "OK" else "FALLITO", n, d)); if (!isTRUE(e)) ok <<- FALSE }
chk("positivo: tutti gli studi di A3 sono rappresentati",
    length(unique(sid[sid %in% a3])) == length(a3),
    sprintf("%d/%d", length(unique(sid[sid %in% a3])), length(a3)))
chk("negativo: nessuno studio fuori da A3",
    all(sub('^.*"series_id":"([^"]+)".*$', "\\1", sel) %in% a3), "0 intrusi")
chk("negativo: il sottoinsieme e' piu' piccolo dell'intero",
    length(sel) < length(lines), sprintf("%d < %d", length(sel), length(lines)))
if (!ok) stop("CASI DI ACCETTAZIONE FALLITI.")

writeLines(sel, OUT)
cat("\nscritto:", OUT, "\n")
if (DRY) { cat("DRY_RUN: mi fermo prima di sottomettere.\n"); quit(save = "no") }

b <- dgx_p4_build_bundle(OUT, stage = "stage2", config = dgx_config(),
                         metadata = list(slug = "a3-s2"),
                         tiered_max_tokens = TRUE)
j <- dgx_p4_submit(b, time = "24:00:00", env = c(VLLM_BATCH_INVARIANT = "1"))
saveRDS(j, "analysis/audit/2026-08-16-A3/job-s2.rds")
cat(sprintf("\nslurm=%s run_id=%s\n", j$slurm_job_id, j$run_id))
