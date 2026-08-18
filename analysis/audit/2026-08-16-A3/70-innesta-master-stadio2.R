#!/usr/bin/env Rscript
# =============================================================================
# A3 — innesto del master Stadio 2
#
# Sostituisce nel master completo i SOLI studi di A3, lasciando gli altri
# byte-identici.
#
# ⚠️ UNA SCELTA, DICHIARATA. Gli studi FUORI da A3 restano com'erano, difetti
# compresi: `GSE9135` (lo studio fantasma nato dal `series_id` ri-emesso dal
# modello) resta nel master, perche' GSE91395 non e' in A3. Applicare qui anche
# il fix del `series_id` introdurrebbe una SECONDA variabile e A3 misurerebbe
# due cose insieme. Il fix vale per il re-run vero, non per il metro.
#
# Uso:
#   Rscript analysis/audit/2026-08-16-A3/70-innesta-master-stadio2.R
# =============================================================================

MASTER  <- Sys.getenv("MASTER",  "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
NUOVO   <- Sys.getenv("NUOVO",   "analysis/p4-output/A3-stage2-master-parziale.jsonl")
A3      <- Sys.getenv("A3_LIST", "analysis/audit/2026-08-16-A3/A3-studi.txt")
OUT     <- Sys.getenv("OUT",     "analysis/p4-output/A3-stage2-master-innestato.jsonl")
stopifnot(file.exists(MASTER), file.exists(NUOVO), file.exists(A3))

# ⚠️ Nel master `series_id` e' uno SCALARE (`"series_id":"GSE100007"`), non un
# array: la prima versione cercava le parentesi quadre e non mordeva su nessuna
# riga. Il caso di accettazione «l'estrazione ha morso» l'ha fermata prima
# dell'innesto -- e' li' apposta. Non-greedy, perche' `series_id` compare anche
# dentro i sotto-oggetti.
sid <- function(x) sub('^.*?"series_id":"([^"]+)".*$', "\\1", x, perl = TRUE)

old <- readLines(MASTER, warn = FALSE)
new <- readLines(NUOVO,  warn = FALSE)
a3  <- readLines(A3)
o_s <- sid(old); n_s <- sid(new)
cat(sprintf("master: %d studi | nuovo: %d studi | A3: %d studi\n",
            length(old), length(new), length(a3)))

cat("\n== casi di accettazione, PRIMA di scrivere ==\n")
ok <- TRUE
chk <- function(n, e, d) { cat(sprintf("  [%s] %-54s %s\n", if (isTRUE(e)) "OK" else "FALLITO", n, d)); if (!isTRUE(e)) ok <<- FALSE }
chk("negativo: l'estrazione della series ha morso",
    !any(o_s == old) && !any(n_s == new), "0 righe non riconosciute")
chk("positivo: il nuovo copre esattamente A3",
    setequal(n_s, a3), sprintf("%d/%d", length(intersect(n_s, a3)), length(a3)))
chk("negativo: nessuno studio duplicato nel nuovo",
    !anyDuplicated(n_s), sprintf("%d duplicati", sum(duplicated(n_s))))
chk("negativo: ogni studio nuovo esiste gia' nel master",
    all(n_s %in% o_s), sprintf("%d assenti", sum(!n_s %in% o_s)))
if (!ok) stop("CASI DI ACCETTAZIONE FALLITI: non innesto.")

pos <- match(n_s, o_s)
merged <- old
merged[pos] <- new

cat("\n== controlli dopo l'innesto ==\n")
chk("positivo: stesso numero di studi",
    length(merged) == length(old), sprintf("%d == %d", length(merged), length(old)))
chk("positivo: stesse series, stesso ordine",
    identical(sid(merged), o_s), "invariate")
fuori <- setdiff(seq_along(old), pos)
chk("negativo: gli studi FUORI da A3 sono byte-identici",
    identical(merged[fuori], old[fuori]), sprintf("%d intatti", length(fuori)))
n_cam <- sum(merged[pos] != old[pos])
cat(sprintf("  studi di A3 col record CAMBIATO: %d / %d (%.1f%%)\n",
            n_cam, length(pos), 100 * n_cam / length(pos)))
if (!ok) stop("CONTROLLI FALLITI: non scrivo.")

writeLines(merged, OUT)
cat("\nscritto:", OUT, "\n")
cat("sha256 :", digest::digest(file = OUT, algo = "sha256"), "\n")
