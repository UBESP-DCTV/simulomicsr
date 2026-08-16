#!/usr/bin/env Rscript
# =============================================================================
# A3 — Stadio 1: raccolta dei 9 blocchi e unione
#
# ⚠️ Un bundle di troppo, da NON raccogliere: la prima sottomissione si e'
# interrotta per un reset ssh dopo aver COSTRUITO il bundle di chunk-04 senza
# sottometterlo (`...092453Z-a3-s1-chunk-04-cb35b6`). Il chunk-04 vero e'
# `...092734Z-...-3f2456`. I run_id sono elencati esplicitamente qui sotto: una
# raccolta "tutti i bundle che assomigliano a a3-s1" prenderebbe anche quello e
# darebbe un merge con un blocco vuoto, senza fallire.
#
# Uso:
#   Rscript analysis/audit/2026-08-16-A3/45-raccogli-e-unisci-stadio1.R
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))

RUN_IDS <- c(
  "20260816T092435Z-a3-s1-chunk-00-008371",
  "20260816T092440Z-a3-s1-chunk-01-885178",
  "20260816T092445Z-a3-s1-chunk-02-619897",
  "20260816T092449Z-a3-s1-chunk-03-af1cfc",
  "20260816T092734Z-a3-s1-chunk-04-3f2456",
  "20260816T092929Z-a3-s1-chunk-05-e4d9f2",
  "20260816T093125Z-a3-s1-chunk-06-118273",
  "20260816T093320Z-a3-s1-chunk-07-fc1be3",
  "20260816T093516Z-a3-s1-chunk-08-c81121")
OUT   <- Sys.getenv("OUT", "analysis/p4-output/A3-stage1-predictions.jsonl")
INPUT <- Sys.getenv("A3_INPUT", "analysis/input/A3-stage1-input.jsonl")

cfg <- dgx_config()
mk_job <- function(rid) structure(
  list(run_id = rid, slurm_job_id = NA_character_, stage = "stage1",
       bundle_dir = file.path("analysis/p4-bundles", rid),
       rendered_slurm = NA_character_, submitted_at = NA_character_,
       config = cfg), class = "simulomicsr_dgx_job")

righe <- character(0); n_err <- 0L
for (rid in RUN_IDS) {
  d <- dgx_p4_collect(mk_job(rid))
  p <- file.path(d$run_dir, "predictions.jsonl")
  stopifnot(file.exists(p))
  l <- readLines(p, warn = FALSE)
  ne <- if (is.null(d$errors)) 0L else nrow(d$errors)
  n_err <- n_err + ne
  cat(sprintf("  %-42s %6d righe, %d errori di schema\n", sub("^.{16}", "", rid), length(l), ne))
  righe <- c(righe, l)
}
cat(sprintf("\ntotale raccolto: %d righe, %d errori di schema\n", length(righe), n_err))

# --- casi di accettazione ----------------------------------------------------
rid_out <- sub('^.*"record_id": ?"([^"]+)".*$', "\\1", righe)
attesi  <- sub('^.*"record_id":"([^"]+)".*$', "\\1",
               readLines(INPUT, warn = FALSE))
cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(n, e, d) { cat(sprintf("  [%s] %-52s %s\n", if (isTRUE(e)) "OK" else "FALLITO", n, d)); if (!isTRUE(e)) ok <<- FALSE }

chk("positivo: copertura completa dell'input A3",
    length(setdiff(attesi, rid_out)) == 0L,
    sprintf("%d/%d, mancanti %d", length(intersect(attesi, rid_out)),
            length(attesi), length(setdiff(attesi, rid_out))))
chk("negativo: nessun record fuori dall'input A3",
    length(setdiff(rid_out, attesi)) == 0L,
    sprintf("%d estranei", length(setdiff(rid_out, attesi))))
chk("negativo: nessun record_id duplicato (blocchi disgiunti)",
    !anyDuplicated(rid_out), sprintf("%d duplicati", sum(duplicated(rid_out))))
chk("negativo: nessun blocco vuoto",
    length(righe) > 0L && !any(!nzchar(righe)), sprintf("%d righe vuote", sum(!nzchar(righe))))

if (!ok) stop("CASI DI ACCETTAZIONE FALLITI: non scrivo il merge.")
writeLines(righe, OUT)
cat("\nscritto:", OUT, sprintf("(%d righe)\n", length(righe)))
cat("sha256 :", digest::digest(file = OUT, algo = "sha256"), "\n")
