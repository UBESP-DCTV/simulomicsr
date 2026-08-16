#!/usr/bin/env Rscript
# =============================================================================
# A3 — innesto delle predizioni nuove nel master Stadio 1
#
# Sostituisce nel master i SOLI record del sottoinsieme A3, lasciando gli altri
# byte-identici. Il master risultante e' il corpus MISTO su cui A3 misura: e'
# dichiarato nel documento delle previsioni, non e' un effetto collaterale.
#
# CASI DI ACCETTAZIONE:
#   positivo : il master nuovo ha lo stesso numero di record di quello vecchio
#   positivo : ogni record di A3 e' stato sostituito
#   negativo : NESSUN record fuori da A3 e' cambiato (byte a byte)
#   negativo : nessun record_id duplicato, nessuno perso
#   negativo : se le predizioni nuove non coprono tutto A3, si FERMA (un
#              innesto parziale misurerebbe una terza cosa, non dichiarata)
#
# Uso:
#   NUOVE=<predictions.jsonl del run A3> \
#   Rscript analysis/audit/2026-08-16-A3/30-innesta-master-stadio1.R
# =============================================================================

MASTER <- Sys.getenv("MASTER",
  "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl")
NUOVE  <- Sys.getenv("NUOVE", "")
A3     <- Sys.getenv("A3_LIST", "analysis/audit/2026-08-16-A3/A3-studi.txt")
S1_IN  <- Sys.getenv("S1_INPUT", "analysis/input/archs4-human-stage1-input-v2.jsonl")
OUT    <- Sys.getenv("OUT", "analysis/p4-output/A3-stage1-master-innestato.jsonl")

stopifnot(file.exists(MASTER), file.exists(A3), file.exists(S1_IN))
if (!nzchar(NUOVE) || !file.exists(NUOVE))
  stop("Serve NUOVE=<path predictions.jsonl del run A3>.")

rid <- function(x) sub('^.*"record_id": ?"([^"]+)".*$', "\\1", x)

cat("Leggo il master...\n")
old <- readLines(MASTER, warn = FALSE)
old_id <- rid(old)
stopifnot(!any(old_id == old))
cat(sprintf("  master: %d record\n", length(old)))

cat("Leggo le predizioni nuove...\n")
new <- readLines(NUOVE, warn = FALSE)
new_id <- rid(new)
stopifnot(!any(new_id == new))
cat(sprintf("  nuove : %d record\n", length(new)))

# quali GSM appartengono ad A3 (dall'input, che e' l'autorita' sulla series)
a3 <- readLines(A3)
in_lines <- readLines(S1_IN, warn = FALSE)
in_rid <- sub('^.*"record_id":"([^"]+)".*$', "\\1", in_lines)
in_sid <- sub('^.*"series_id":"([^"]+)".*$', "\\1", in_lines)
gsm_a3 <- in_rid[in_sid %in% a3]
rm(in_lines); invisible(gc())
cat(sprintf("  GSM attesi in A3: %d\n", length(gsm_a3)))

# --- casi di accettazione, PRIMA di scrivere ---------------------------------
cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(nome, esito, dett) {
  cat(sprintf("  [%s] %-56s %s\n", if (isTRUE(esito)) "OK" else "FALLITO", nome, dett))
  if (!isTRUE(esito)) ok <<- FALSE
}

mancanti <- setdiff(gsm_a3, new_id)
chk("negativo: le predizioni nuove coprono TUTTO A3",
    length(mancanti) == 0L, sprintf("%d mancanti", length(mancanti)))
intrusi <- setdiff(new_id, gsm_a3)
chk("negativo: nessuna predizione fuori da A3",
    length(intrusi) == 0L, sprintf("%d intrusi", length(intrusi)))
chk("negativo: nessun record_id duplicato nelle nuove",
    !anyDuplicated(new_id), sprintf("%d duplicati", sum(duplicated(new_id))))
if (!ok) stop("CASI DI ACCETTAZIONE FALLITI: non innesto nulla.")

# --- innesto -----------------------------------------------------------------
pos <- match(new_id, old_id)
if (any(is.na(pos)))
  stop(sprintf("%d record nuovi non esistono nel master: da dove vengono?",
               sum(is.na(pos))))
merged <- old
merged[pos] <- new

# --- controlli DOPO l'innesto ------------------------------------------------
cat("\n== controlli dopo l'innesto ==\n")
chk("positivo: stesso numero di record",
    length(merged) == length(old), sprintf("%d == %d", length(merged), length(old)))
chk("positivo: stessi record_id, stesso ordine",
    identical(rid(merged), old_id), "invariati")
fuori <- setdiff(seq_along(old), pos)
chk("negativo: i record FUORI da A3 sono byte-identici",
    identical(merged[fuori], old[fuori]),
    sprintf("%d record intatti", length(fuori)))
# ⚠️ NON confrontare le righe intere: contengono `ts` e `worker_id`, che
# cambiano SEMPRE. La prima stesura lo faceva e stampava «100,0% dei record
# cambiati» -- un numero che sembra un risultato e misura l'orologio. Il
# confronto giusto e' su `raw_output`, cioe' su quello che il modello ha detto.
estrai_raw <- function(x) sub('^.*"raw_output": ?"(.*)", ?"record_id".*$', "\\1", x)
raw_v <- estrai_raw(old[pos]); raw_n <- estrai_raw(merged[pos])
if (all(raw_v == old[pos])) {
  cat("  ⚠️ estrazione di raw_output fallita: non riporto una percentuale.\n")
} else {
  n_cambiati <- sum(raw_v != raw_n)
  cat(sprintf("  record di A3 col RAW_OUTPUT cambiato: %d / %d (%.1f%%)\n",
              n_cambiati, length(pos), 100 * n_cambiati / length(pos)))
  cat(sprintf("  (riferimento: 2026-08-09, due giri senza flag, identici nel 40,4%%)\n"))
}
if (!ok) stop("CONTROLLI FALLITI dopo l'innesto: non scrivo.")

writeLines(merged, OUT)
cat("\nscritto:", OUT, "\n")
cat("sha256 :", digest::digest(file = OUT, algo = "sha256"), "\n")
