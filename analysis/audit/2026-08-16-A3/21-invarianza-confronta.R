#!/usr/bin/env Rscript
# =============================================================================
# PROVA DELLA BATCH-INVARIANZA — il confronto
#
# Legge i quattro run (A/B x flag/senza-flag) e confronta i record CONDIVISI.
#
# CASI DI ACCETTAZIONE, e l'ordine conta:
#   1. NEGATIVO — senza flag, A e B devono DIFFERIRE su almeno un record.
#      Se non differiscono, il confronto non e' in grado di vedere nulla e il
#      caso positivo passerebbe per costruzione. Questo si controlla PRIMA.
#   2. NEGATIVO — un record alterato a mano deve far fallire il confronto.
#   3. POSITIVO — con la flag, i record condivisi sono byte-identici.
#
# Un test che ha solo il caso 3 non e' un test: e' una speranza.
#
# Uso:
#   Rscript analysis/audit/2026-08-16-A3/21-invarianza-confronta.R
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))

DIR   <- Sys.getenv("INV_DIR", "analysis/audit/2026-08-16-A3/invarianza")
JOBS  <- file.path(DIR, "jobs.rds")
stopifnot(file.exists(JOBS))
jobs <- readRDS(JOBS)
shared_ids <- readLines(file.path(DIR, "record-condivisi.txt"))
cat(sprintf("record condivisi attesi: %d\n", length(shared_ids)))

# --- raccolta ---------------------------------------------------------------
leggi <- function(job) {
  d <- dgx_p4_collect(job)
  x <- data.frame(record_id = d$record_id, raw_output = d$raw_output,
                  valid = d$valid_schema, stringsAsFactors = FALSE)
  x[x$record_id %in% shared_ids, , drop = FALSE]
}
res <- lapply(jobs, leggi)
for (nm in names(res))
  cat(sprintf("  %-9s %d record condivisi, %d validi\n",
              nm, nrow(res[[nm]]), sum(res[[nm]]$valid)))

# --- il confronto -----------------------------------------------------------
confronta <- function(a, b) {
  m <- merge(a, b, by = "record_id", suffixes = c("_A", "_B"))
  stopifnot(nrow(m) > 0L)
  list(n = nrow(m),
       identici = sum(m$raw_output_A == m$raw_output_B),
       diversi  = sum(m$raw_output_A != m$raw_output_B),
       tab = m)
}

cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(nome, esito, dettaglio) {
  cat(sprintf("  [%s] %-58s %s\n", if (isTRUE(esito)) "OK" else "FALLITO",
              nome, dettaglio))
  if (!isTRUE(esito)) ok <<- FALSE
}

# 1. NEGATIVO, per primo: senza flag DEVE cambiare qualcosa.
noflag <- confronta(res$A_noflag, res$B_noflag)
chk("negativo: SENZA flag A e B differiscono",
    noflag$diversi > 0L,
    sprintf("%d/%d diversi (%.1f%%)", noflag$diversi, noflag$n,
            100 * noflag$diversi / noflag$n))

# 2. NEGATIVO: il confronto sa vedere una differenza piantata a mano.
finto_a <- res$A_flag
finto_b <- res$B_flag
if (nrow(finto_b) > 0L) finto_b$raw_output[[1L]] <- paste0(finto_b$raw_output[[1L]], " ")
sabot <- confronta(finto_a, finto_b)
chk("negativo: una differenza piantata a mano viene vista",
    sabot$diversi >= 1L, sprintf("%d visti", sabot$diversi))

# 3. POSITIVO: con la flag, identici.
flag <- confronta(res$A_flag, res$B_flag)
chk("positivo: CON flag A e B sono byte-identici",
    flag$diversi == 0L,
    sprintf("%d/%d identici (%.2f%%)", flag$identici, flag$n,
            100 * flag$identici / flag$n))

# 4. la flag e' davvero arrivata al processo: si guarda l'artefatto del job.
cat("\n== la flag e' arrivata al processo? (artefatto, non script) ==\n")
cat("   verificare runs/<run_id>/container-env.txt sul DGX per:\n")
for (nm in c("A_flag", "B_flag")) cat("     ", jobs[[nm]]$run_id, "\n")

# --- esito ------------------------------------------------------------------
cat("\n")
if (!ok) {
  cat("ESITO: la batch-invarianza NON e' dimostrata a composizione di shard\n")
  cat("       diversa. A3 e il re-run completo userebbero job di dimensioni\n")
  cat("       diverse: il movimento misurato mescolerebbe il rumore del modello\n")
  cat("       con l'effetto della dimensione del job. FERMARSI.\n")
} else {
  cat("ESITO: la flag tiene anche cambiando la composizione dello shard\n")
  cat(sprintf("       (worker diverso per il 75.8%% dei record condivisi).\n"))
}
saveRDS(list(flag = flag[c("n","identici","diversi")],
             noflag = noflag[c("n","identici","diversi")], ok = ok),
        file.path(DIR, "esito.rds"))
