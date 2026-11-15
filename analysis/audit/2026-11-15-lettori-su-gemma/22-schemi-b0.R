# 22-schemi-b0.R — lo schema delle uscite della forma B0 per ogni studio di Gemma, e l'ingresso del lettore per la
# parte APERTA. Nessun modello gira qui e nessun disegno di Gemma si legge qui.
#
# Il generatore e' quello della terza prova (analysis/audit/2026-11-11-S12r3-elenco-chiuso/10-schema-per-studio.R),
# senza cambi. Controllo positivo: sui 47 studi di sviluppo gli schemi generati adesso hanno le impronte SHA-256
# scritte dal lancio del secondo lettore (analysis/audit/2026-11-15-secondo-lettore/23-schemi-sha256.csv).
#
# Per ogni studio con una vista (analysis/input/gemma-viste-v0.jsonl):
#   - senza colonne non costanti: lo schema non si puo' generare; lo studio non va al modello (motivo
#     `nessuna_colonna_variabile`) e si conta;
#   - token stimati dell'ingresso = (caratteri della vista + caratteri del prompt v2) / 2,29. Il limite vero lo
#     applica il lavoratore sul DGX con i token contati: ingresso + max_tokens (24.576) oltre max_model_len (65.536)
#     vuol dire `oltre_contesto`, cioe' ingresso oltre 40.960 token. Qui si segnala soltanto, niente si taglia;
#   - la grandezza dello schema in caratteri (nella terza prova il massimo era 222.556) e il numero di voci.
# Ingresso scritto: una riga {record_id, testo, schema} per ogni studio APERTO (21-divisione.csv) con almeno una
# colonna non costante, in ordine di numero GEO. Gli studi CHIUSI non entrano nell'ingresso.
#
#   Rscript analysis/audit/2026-11-15-lettori-su-gemma/22-schemi-b0.R > .../22-out.txt 2>&1     (SENZA --vanilla)
# Uscite: 22-per-studio.csv, analysis/input/gemma-b0-ingresso-aperta.jsonl, 22-ingresso-sha256.txt.
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(jsonlite) })
DIR <- "analysis/audit/2026-11-15-lettori-su-gemma"; R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"
source(file.path(R3, "10-schema-per-studio.R"))     # schema_studio(), schema_json(), valori_colonna()
source(file.path(DIR, "21-divisione.R"))            # parte_gemma()
F_VISTE <- "analysis/input/gemma-viste-v0.jsonl"; F_INGRESSO <- "analysis/input/gemma-b0-ingresso-aperta.jsonl"
CAR_PER_TOKEN <- 2.29; MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 24576L; LIMITE_INGRESSO <- MAX_MODEL_LEN - MAX_TOKENS
sha_testo <- function(x) digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE)
leggi_viste <- function(f) lapply(readLines(f, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
prompt <- paste(readLines(file.path(R3, "21-prompt-v2.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
cat("22-schemi-b0.R ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "; caratteri del prompt v2:", nchar(prompt), "\n")

# ---- controllo positivo: i 47 studi di sviluppo -------------------------------------------------------------
sv <- leggi_viste("analysis/audit/2026-11-09-lettore-studio/60-viste-v0.jsonl")
noti <- utils::read.csv("analysis/audit/2026-11-15-secondo-lettore/23-schemi-sha256.csv", stringsAsFactors = FALSE)
adesso <- vapply(sv, function(v) sha_testo(schema_json(v)), "")
stopifnot(identical(vapply(sv, `[[`, "", "record_id"), noti$studio), identical(unname(adesso), noti$schema_sha256))
cat("controllo positivo: 47 schemi di sviluppo su 47 con l'impronta del lancio del secondo lettore\n")
rm(sv)

# ---- gli studi di Gemma -------------------------------------------------------------------------------------
viste <- leggi_viste(F_VISTE); id <- vapply(viste, `[[`, "", "record_id")
div <- utils::read.csv(file.path(DIR, "21-divisione.csv"), stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(id), all(id %in% div$gse), identical(div$parte, unname(parte_gemma(div$gse))))
parte <- div$parte[match(id, div$gse)]
cat(sprintf("viste: %d studi (parte aperta %d, parte chiusa %d); studi dell'elenco senza una vista: %d\n",
            length(id), sum(parte == "aperta"), sum(parte == "chiusa"), sum(!div$gse %in% id)))
con <- file(F_INGRESSO, "wb"); n_scritti <- 0L
per <- do.call(rbind, lapply(seq_along(viste), function(i) {
  v <- viste[[i]]; colonne <- as.character(unlist(v$colonne)); n_col <- length(colonne)
  tok <- ceiling((nchar(v$testo) + nchar(prompt)) / CAR_PER_TOKEN)
  r <- data.frame(gse = id[i], parte = parte[i], campioni = length(unlist(v$campioni)), colonne_non_costanti = n_col,
                  valori_distinti = NA_integer_, valori_max_per_colonna = NA_integer_, schema_caratteri = NA_integer_, schema_sha256 = NA_character_,
                  token_stimati = tok, oltre_contesto_stimato = as.integer(tok > LIMITE_INGRESSO),
                  esito = if (n_col == 0L) "nessuna_colonna_variabile" else "al_modello", stringsAsFactors = FALSE)
  if (n_col > 0L) {
    nv <- vapply(colonne, function(k) length(valori_colonna(v, k)), 1L)
    s <- schema_studio(v); sj <- as.character(toJSON(s, auto_unbox = TRUE, null = "null"))
    r$valori_distinti <- sum(nv); r$valori_max_per_colonna <- max(nv); r$schema_caratteri <- nchar(sj); r$schema_sha256 <- sha_testo(sj)
    if (parte[i] == "aperta") {
      writeLines(enc2utf8(as.character(toJSON(list(record_id = id[i], testo = v$testo, schema = s), auto_unbox = TRUE, null = "null"))), con, useBytes = TRUE)
      n_scritti <<- n_scritti + 1L
    }
  }
  r
}))
close(con)
utils::write.csv(per, file.path(DIR, "22-per-studio.csv"), row.names = FALSE, na = "")
# rilettura dell'ingresso: solo studi aperti, uno per riga, schema uguale a quello contato
rl <- readLines(F_INGRESSO, warn = FALSE, encoding = "UTF-8")
id_in <- sub('^\\{"record_id":"(GSE[0-9]+)".*$', "\\1", rl)
att <- per$gse[per$parte == "aperta" & per$esito == "al_modello"]
stopifnot(length(rl) == n_scritti, identical(id_in, att), !any(id_in %in% div$gse[div$parte == "chiusa"]))
set.seed(20261115L); prova <- sample(seq_along(rl), min(50L, length(rl)))
stopifnot(all(vapply(prova, function(i) {
  x <- fromJSON(rl[i], simplifyVector = FALSE)
  identical(sha_testo(as.character(toJSON(x$schema, auto_unbox = TRUE, null = "null"))), per$schema_sha256[match(x$record_id, per$gse)]) &&
    identical(x$testo, viste[[match(x$record_id, id)]]$testo)
}, NA)))
sha_in <- unname(digest::digest(file = F_INGRESSO, algo = "sha256"))
writeLines(sprintf("%s  %s", sha_in, F_INGRESSO), file.path(DIR, "22-ingresso-sha256.txt"))

q <- function(x) paste(format(stats::quantile(x, c(0, .25, .5, .75, .95, .99, 1), na.rm = TRUE, names = FALSE), big.mark = ".", decimal.mark = ",", scientific = FALSE), collapse = " | ")
for (p in c("aperta", "chiusa")) {
  d <- per[per$parte == p, ]
  cat(sprintf("\nParte %s: %d studi con la vista; al modello %d; senza colonne non costanti %d; oltre il contesto (stima) %d\n",
              p, nrow(d), sum(d$esito == "al_modello"), sum(d$esito != "al_modello"), sum(d$oltre_contesto_stimato == 1L & d$esito == "al_modello")))
  cat("  quantili (minimo | 25% | mediana | 75% | 95% | 99% | massimo)\n")
  cat("  token stimati dell'ingresso:   ", q(d$token_stimati), "\n")
  cat("  caratteri dello schema:        ", q(d$schema_caratteri), "\n")
  cat("  valori distinti (tutte le colonne):", q(d$valori_distinti), "\n")
  cat("  studi con lo schema oltre 222.556 caratteri (il massimo della terza prova):", sum(d$schema_caratteri > 222556L, na.rm = TRUE), "\n")
}
cat(sprintf("\ningresso %s: %d studi aperti, %.1f MB, SHA-256 %s\n", F_INGRESSO, length(rl), file.size(F_INGRESSO) / 1e6, sha_in))
cat("riletti 50 record a caso (seme 20261115): schema e testo uguali a quelli contati\n")
