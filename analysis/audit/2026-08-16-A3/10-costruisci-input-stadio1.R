#!/usr/bin/env Rscript
# =============================================================================
# A3 — costruzione dell'input Stadio 1 ristretto al sottoinsieme
#
# Estrae dall'input di produzione le SOLE righe degli studi di A3, senza
# toccarle: il file prodotto e' un sottoinsieme di righe IDENTICHE, non
# rigenerate. Cosi' l'unica variabile fra il run vecchio e il nuovo resta il
# modello, che e' il punto della misura.
#
# Uso:
#   Rscript analysis/audit/2026-08-16-A3/10-costruisci-input-stadio1.R
# =============================================================================

A3_LIST  <- Sys.getenv("A3_LIST", "analysis/audit/2026-08-16-A3/A3-studi.txt")
S1_INPUT <- Sys.getenv("S1_INPUT", "analysis/input/archs4-human-stage1-input-v2.jsonl")
OUT      <- Sys.getenv("OUT", "analysis/input/A3-stage1-input.jsonl")

stopifnot(file.exists(A3_LIST), file.exists(S1_INPUT))

a3 <- readLines(A3_LIST)
cat(sprintf("studi A3: %d\n", length(a3)))

lines <- readLines(S1_INPUT, warn = FALSE)
cat(sprintf("righe input produzione: %d\n", length(lines)))

# series_id estratto dal testo della riga: e' un campo scalare, sempre presente
sid <- sub('^.*"series_id":"([^"]+)".*$', "\\1", lines)
stopifnot(!any(sid == lines))  # se la sostituzione non ha morso, sid == lines

keep <- sid %in% a3
sub_lines <- lines[keep]

cat(sprintf("righe estratte: %d (%.2f%%)\n",
            length(sub_lines), 100 * length(sub_lines) / length(lines)))

# --- CASI DI ACCETTAZIONE ----------------------------------------------------
cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(nome, esito, dettaglio) {
  cat(sprintf("  [%s] %-56s %s\n", if (isTRUE(esito)) "OK" else "FALLITO", nome, dettaglio))
  if (!isTRUE(esito)) ok <<- FALSE
}

sid_sub <- sid[keep]
# POSITIVO: ogni studio di A3 con almeno una riga e' rappresentato
studi_presenti <- length(unique(sid_sub))
chk("positivo: tutti gli studi di A3 hanno righe", studi_presenti == length(a3),
    sprintf("%d/%d", studi_presenti, length(a3)))

# NEGATIVO: nessuna riga di uno studio FUORI da A3 e' finita dentro
fuori <- sum(!sid_sub %in% a3)
chk("negativo: nessuna riga di studi fuori da A3", fuori == 0L,
    sprintf("%d intrusi", fuori))

# NEGATIVO: le righe estratte sono IDENTICHE all'originale (non rigenerate).
# Confronto diretto su un campione: se una sola differisse, il sottoinsieme
# introdurrebbe una seconda variabile oltre al modello.
idx <- which(keep)
camp <- idx[seq(1L, length(idx), length.out = min(500L, length(idx)))]
identiche <- all(lines[camp] == sub_lines[match(camp, idx)])
chk("negativo: righe byte-identiche all'input di produzione", identiche,
    sprintf("%d controllate", length(camp)))

# NEGATIVO: il sottoinsieme e' strettamente piu' piccolo del totale
chk("negativo: sottoinsieme < input intero", length(sub_lines) < length(lines),
    sprintf("%d < %d", length(sub_lines), length(lines)))

if (!ok) stop("CASI DI ACCETTAZIONE FALLITI.")

writeLines(sub_lines, OUT)
sha <- digest::digest(file = OUT, algo = "sha256")
cat("\n== scritto ==\n")
cat("  ", OUT, sprintf("(%d righe)\n", length(sub_lines)))
cat("   sha256:", sha, "\n")
