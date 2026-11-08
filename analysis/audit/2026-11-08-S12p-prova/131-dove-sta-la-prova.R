#!/usr/bin/env Rscript
# S12p, quinta parte, analisi DESCRITTIVA dopo il calcolo (non nelle previsioni): la previsione D5 (classe D sotto il
# 25%) e' smentita, e la classe D mescola tre cose: prova nel titolo (lo Stadio 1 lo legge), prova in descrizione o
# protocolli (nessun passo li legge), strumento cieco. Per i 280 difetti della seconda lettura, ogni citazione del
# lettore si cerca nei campi GEO dei campioni dei due bracci; per i 193, la colonna `fonte` di S11.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/131-dove-sta-la-prova.R > analysis/audit/2026-11-08-S12p-prova/131-out.txt 2>&1
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(jsonlite))
DIR <- "analysis/audit/2026-11-08-S12p-prova"; S12 <- "analysis/audit/2026-11-07-S12-stadio2b-disegno"
R <- read.csv(file.path(DIR, "130-diagnosi.csv"), stringsAsFactors = FALSE)
P <- read.csv(file.path(DIR, "94-difetti-finali.csv"), stringsAsFactors = FALSE)
rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)
ten <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
h5 <- readRDS(file.path(S12, "20-campi-h5-campioni.rds"))
geo <- lapply(readLines(gzfile(file.path(S12, "27-campi-geo-campioni.jsonl.gz")), encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
names(geo) <- vapply(geo, `[[`, "", "gsm")
LETTI <- c("title", "source_name_ch1", "characteristics_ch1")          # i campi che lo Stadio 1 legge
norm <- function(x) { x <- .s2b_norm_testo(ifelse(is.na(x) | is.null(x), "", as.character(x))); gsub("\\s+", " ", tolower(trimws(x))) }
campi_di <- function(g) {
  h <- h5[h5$geo_accession == g, ]; out <- list()
  if (nrow(h)) for (k in setdiff(names(h), "geo_accession")) out[[k]] <- norm(h[[k]][1])
  r <- geo[[g]]; if (!is.null(r)) for (k in setdiff(names(r), c("gsm", "study_id", "file")) ) if (!startsWith(k, "n_righe")) out[[paste0("geo_", k)]] <- norm(paste(unlist(r[[k]]), collapse = " "))
  out
}
pezzi <- function(cit) {
  s <- unlist(strsplit(cit, " \\|\\| |\\.\\.\\.|…"))
  s <- gsub("\\[[^]]*\\]", " ", s); s <- sub("^\\s*[TC][0-9]+\\s+", "", s); s <- norm(s)
  unique(s[nchar(s) >= 4])
}
dove <- function(rid, cit) {
  t <- ten[ten$record_id == rid, ]; gs <- c(strsplit(t$gsm_t, ",")[[1]], strsplit(t$gsm_c, ",")[[1]])
  C <- lapply(gs, campi_di); trovati <- character()
  for (p in pezzi(cit)) for (cc in C) for (k in names(cc)) if (grepl(p, cc[[k]], fixed = TRUE)) trovati <- c(trovati, sub("^geo_", "", k))
  trovati <- unique(trovati)
  if (!length(trovati)) "non trovata" else if (any(trovati %in% LETTI)) "in un campo letto dallo Stadio 1" else "solo in campi non letti"
}
d <- R[R$record_id %in% P$record_id, ]
d$prova <- vapply(d$record_id, function(r) dove(r, P$citazioni2[P$record_id == r]), "")
d$campi_non_letti <- vapply(d$record_id, function(r) {
  t <- ten[ten$record_id == r, ]; gs <- c(strsplit(t$gsm_t, ",")[[1]], strsplit(t$gsm_c, ",")[[1]]); C <- lapply(gs, campi_di); tr <- character()
  for (p in pezzi(P$citazioni2[P$record_id == r])) for (cc in C) for (k in names(cc)) if (grepl(p, cc[[k]], fixed = TRUE)) tr <- c(tr, sub("^geo_", "", k))
  paste(sort(unique(tr)), collapse = " ") }, "")
cat("== i 280: dove sta la citazione del lettore, per classe ==\n"); print(table(d$classe, d$prova))
cat("\n== i 280 in classe D: campi in cui sta la citazione ==\n")
print(sort(table(unlist(strsplit(d$campi_non_letti[d$classe == "D"], " "))), decreasing = TRUE))
b <- R[R$record_id %in% rif$record_id, ]; b$fonte <- rif$fonte[match(b$record_id, rif$record_id)]
cat("\n== i 193: fonte del lettore di S11 per classe ==\n"); print(table(b$classe, b$fonte))
write.csv(d[, c("record_id", "classe", "tipi", "prova", "campi_non_letti")], file.path(DIR, "131-dove-sta-la-prova.csv"), row.names = FALSE)
cat("FINITO\n")
