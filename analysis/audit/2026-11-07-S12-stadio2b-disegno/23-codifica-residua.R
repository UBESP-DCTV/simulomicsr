#!/usr/bin/env Rscript
# 23-codifica-residua.R — S12: quanti ingressi dei 1.903 conservano tracce di
# codifica UTF-8 doppia dopo la riparazione (stringhe con codifica mista, che la
# riparazione per stringa intera non tocca). Marcatori: «Ã» o «Â» seguiti da un
# carattere U+0080-U+00BF, oppure «â» seguito da U+0080-U+009F.
OUT <- "analysis/audit/2026-11-07-S12-stadio2b-disegno"
x <- lapply(readLines(gzfile(file.path(OUT, "20-ingressi-1903.jsonl.gz")), encoding = "UTF-8"), jsonlite::fromJSON)
marc <- "Ã[\u0080-¿]|Â[\u0080-¿]|â[\u0080-\u009f]"
testi <- vapply(x, `[[`, "", "testo")
con <- grepl(marc, testi, perl = TRUE)
cat("ingressi con marcatori di codifica doppia residua:", sum(con), "su", length(testi), "\n")
righe <- unlist(lapply(testi[con], function(t) grep(marc, strsplit(t, "\n", fixed = TRUE)[[1]], value = TRUE, perl = TRUE)))
campo <- sub("^(T[0-9]+ |C[0-9]+ )?\\[([a-z_]+)\\].*$", "\\2", righe)
cat("righe con marcatori, per campo:\n"); print(table(campo))
cat("righe con marcatori nei campi che descrivono il campione (title, source_name, characteristics):",
    sum(campo %in% c("title", "source_name", "characteristics")), "\n")

# Controllo positivo: gli stessi marcatori sui testi H5 dei campioni, prima e
# dopo la riparazione (la regola deve vederli prima, e non dopo).
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
ns <- asNamespace("simulomicsr")
X <- readRDS(file.path(OUT, "20-campi-h5-campioni.rds"))
cat("\ncontrollo positivo, stringhe con marcatori sui", nrow(X), "campioni:\n")
for (f in c("title", "source_name_ch1", "characteristics_ch1", "extract_protocol_ch1", "data_processing")) {
  prima <- sum(grepl(marc, ns$.s2b_norm_spazi(X[[f]]), perl = TRUE))
  dopo <- sum(grepl(marc, ns$.s2b_norm_testo(X[[f]]), perl = TRUE))
  cat(sprintf("  %-22s prima %5d  dopo %5d\n", f, prima, dopo))
}
