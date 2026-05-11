# analysis/p4-beta-build-minigold-formatB.R
# Per i 100 sample di p35c-minigold-reviewed-v5.csv, ricostruisci `string` in format B.
# Richiede: title + source_name_ch1 per ogni sample, fetched da GEO via Entrez API.
#
# Nota: usa devtools::load_all() invece di library(simulomicsr) perché il pacchetto
# non è installato nell'ambiente corrente (renv out-of-sync), ma load_all() funziona.

devtools::load_all(quiet = TRUE)
library(rentrez)
library(readr)

stopifnot(nzchar(Sys.getenv("NCBI_API_KEY")))
rentrez::set_entrez_key(Sys.getenv("NCBI_API_KEY"))

mg <- read.csv("inst/extdata/p35c-minigold-reviewed-v5.csv", stringsAsFactors = FALSE)
cat("Mini-gold v5:", nrow(mg), "sample\n")

# Fetch per ogni sample (GSM) title + source_name via Entrez gds db (sample-level).
# Se il fetch fallisce o non trova nulla, ritorna NA — build_sample_string_format_B gestisce NA.
fetch_sample_meta <- function(gsm) {
  tryCatch({
    s <- entrez_search(db = "gds", term = paste0(gsm, "[Accession]"))
    if (length(s$ids) == 0) return(list(title = NA_character_, source = NA_character_))
    # Sample UIDs in gds iniziano con 3 (GSM), serie iniziano con 2 (GSE)
    uid <- s$ids[grepl("^3[0-9]+$", s$ids)][1]
    if (is.na(uid)) uid <- s$ids[1]
    info <- entrez_summary(db = "gds", id = uid)
    # Nel record GDS livello-GSM: `title` = titolo sample, `summary` = source_name_ch1.
    # Il campo API `sourcename` è vuoto per i record GSM; `summary` contiene il valore corretto
    # (verificato: corrisponde a "Source name" nel record GEO SOFT).
    list(
      title  = info$title   %||% NA_character_,
      source = info$summary %||% NA_character_
    )
  }, error = function(e) {
    warning(sprintf("Fetch fallito per %s: %s", gsm, conditionMessage(e)))
    list(title = NA_character_, source = NA_character_)
  })
}

mg$title           <- NA_character_
mg$source_name_ch1 <- NA_character_

t_start <- proc.time()["elapsed"]
for (i in seq_len(nrow(mg))) {
  meta <- fetch_sample_meta(mg$geo_accession[i])
  mg$title[i]           <- meta$title
  mg$source_name_ch1[i] <- meta$source
  cat(sprintf("[%d/%d] %s | title: %s\n", i, nrow(mg), mg$geo_accession[i],
              substr(meta$title %||% "(NA)", 1, 50)))
}
t_elapsed <- proc.time()["elapsed"] - t_start
cat(sprintf("\nFetch completato in %.1f secondi (%.1f min)\n", t_elapsed, t_elapsed / 60))

# Riepilogo NA
n_na_title  <- sum(is.na(mg$title))
n_na_source <- sum(is.na(mg$source_name_ch1))
cat(sprintf("NA title: %d / %d | NA source_name_ch1: %d / %d\n",
            n_na_title, nrow(mg), n_na_source, nrow(mg)))

# Costruisci stringa format B: "title: <title>, source: <source>, <characteristics_ch1>"
# La colonna `string` nel mini-gold corrisponde a characteristics_ch1.
mg$string_formatB <- mapply(
  simulomicsr:::build_sample_string_format_B,
  mg$title, mg$source_name_ch1, mg$string,
  USE.NAMES = FALSE
)

# Salva CSV esteso
out_path <- "inst/extdata/p35c-minigold-reviewed-v5-formatB.csv"
write.csv(mg, out_path, row.names = FALSE)
cat("Salvato:", out_path, "\n")
cat("Colonne nel file di output:", paste(colnames(mg), collapse = ", "), "\n")
cat("\nnchar(string_formatB) summary:\n")
print(summary(nchar(mg$string_formatB)))
