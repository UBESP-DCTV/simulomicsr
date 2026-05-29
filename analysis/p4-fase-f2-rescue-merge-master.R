#!/usr/bin/env Rscript
# p4-fase-f2-rescue-merge-master.R --- RED ALERT FASE F2: merge finale del
# master Stadio 1 v2 con i recuperati della cascade rescue.
#
# Sostituisce nel master le righe fail (parsed_json null) con le predizioni
# recuperate, taggate `rescue_source`:
#   - H1   (rep_pen=1.2)  -> "h1_rep12_maxtok4096"
#   - H1.2 (rep_pen=1.3)  -> "h12_rep13_maxtok8192"
# I residui finali (ancora null dopo H1.2) restano invariati nel master.
# Output: p4-fase-f2-stage1-master-predictions-rescued.jsonl.

suppressPackageStartupMessages({ library(jsonlite) })

MASTER   <- "analysis/p4-output/p4-fase-f2-stage1-master-predictions.jsonl"
H1       <- "analysis/p4-output/p4-fase-f2-rescue-h1-predictions.jsonl"
H12      <- "analysis/p4-output/p4-fase-f2-rescue-h12-predictions.jsonl"
H13      <- "analysis/p4-output/p4-fase-f2-rescue-h13-predictions.jsonl"
MANUAL   <- "analysis/p4-output/p4-fase-f2-rescue-manual-predictions.jsonl"
OUT      <- "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl"
EXPECTED <- 508037L

stopifnot(file.exists(MASTER), file.exists(H1), file.exists(H12),
          file.exists(H13), file.exists(MANUAL))

# Costruisce lookup rid -> riga taggata, solo per i recuperati (parsed_json
# non-null). H1.2 ha precedenza su H1 (gira sui residui di H1, nessun conflitto
# coi 1317 gia' recuperati ma la precedenza e' esplicita e sicura).
build_recovered <- function(path, source_tag, env) {
  con <- file(path, "r"); n <- 0L
  repeat {
    L <- readLines(con, n = 1L, warn = FALSE)
    if (!length(L)) break
    rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
    if (is.null(rec$parsed_json)) next            # ancora fail: non recuperato
    rec$rescue_source <- source_tag
    assign(rec$record_id,
           jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null", na = "null"),
           envir = env)
    n <- n + 1L
  }
  close(con); n
}

rec_env <- new.env(parent = emptyenv())
n_h1  <- build_recovered(H1,  "h1_rep12_maxtok4096",  rec_env)
# H1.2 poi H1.3 sovrascrivono (precedenza) per i loro recuperati: ognuno gira
# sui residui dello stadio precedente, quindi nessun conflitto effettivo.
n_h12 <- build_recovered(H12, "h12_rep13_maxtok8192", rec_env)
n_h13 <- build_recovered(H13, "h13_rep14_maxtok8192", rec_env)
# H1.4 manual curation (2 residui GSE157354 mirror del gemello GSM4763009)
n_man <- build_recovered(MANUAL, "manual_curation_2026-05-29", rec_env)
n_lookup <- length(ls(rec_env))
cat(sprintf("Recuperati: H1=%d, H1.2=%d, H1.3=%d, manual=%d, lookup unico=%d\n",
            n_h1, n_h12, n_h13, n_man, n_lookup))

# Stream master: regex per record_id (veloce), sostituisce se recuperato.
con <- file(MASTER, "r"); out <- file(OUT, "w")
n_in <- 0L; n_repl <- 0L
repeat {
  ls_ <- readLines(con, n = 50000L, warn = FALSE)
  if (length(ls_) == 0L) break
  ids <- sub('.*"record_id"[[:space:]]*:[[:space:]]*"([^"]+)".*', "\\1", ls_)
  for (i in seq_along(ls_)) {
    rid <- ids[i]
    if (exists(rid, envir = rec_env, inherits = FALSE)) {
      writeLines(get(rid, envir = rec_env), out); n_repl <- n_repl + 1L
    } else {
      writeLines(ls_[i], out)
    }
  }
  n_in <- n_in + length(ls_)
}
close(con); close(out)

cat(sprintf("Righe master: %d (atteso %d), sostituite: %d\n",
            n_in, EXPECTED, n_repl))
stopifnot(n_in == EXPECTED, n_repl == n_lookup)

# Validazione finale: residui null
n_null <- as.integer(system2("grep",
  c("-cE", shQuote('"parsed_json"[[:space:]]*:[[:space:]]*null'), shQuote(OUT)),
  stdout = TRUE))
n_valid <- EXPECTED - n_null
cat(sprintf("\nMaster rescued: %s\n  validi %d / %d = %.4f%%\n  residui null %d (%.4f%%)\n",
            OUT, n_valid, EXPECTED, 100 * n_valid / EXPECTED,
            n_null, 100 * n_null / EXPECTED))
cat("OK merge rescued\n")
