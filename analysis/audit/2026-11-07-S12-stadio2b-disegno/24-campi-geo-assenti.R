#!/usr/bin/env Rscript
# 24-campi-geo-assenti.R — S12: sceglie 40 studi a caso (seme 20261107) fra
# quelli dei 1.903 confronti e scrive i loro GSM per 24-campi-geo-assenti.py.
OUT <- "analysis/audit/2026-11-07-S12-stadio2b-disegno"
x <- lapply(readLines(gzfile(file.path(OUT, "20-ingressi-1903.jsonl.gz")), encoding = "UTF-8"), jsonlite::fromJSON)
st <- vapply(x, `[[`, "", "study_id")
gsm <- tapply(seq_along(x), st, function(i) sort(unique(unlist(lapply(x[i], function(r) c(r$gsm_t, r$gsm_c))))))
set.seed(20261107)
scelti <- sort(sample(names(gsm), 40))
cat("studi nei 1.903:", length(gsm), "; scelti:", length(scelti), "\n")
jsonlite::write_json(lapply(gsm[scelti], identity), file.path(OUT, "24-studi-scelti.json"))
