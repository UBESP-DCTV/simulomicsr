#!/usr/bin/env Rscript
# La concentrazione massima di un farmaco ha senso solo se l'unita' e' una sola: lo controllo dai metadati dei campioni di Tahoe.
suppressPackageStartupMessages({library(arrow); library(data.table)})
s <- as.data.table(read_parquet("/mnt/wwn-0x5000039d58caca35/lincs-meta/level5/tahoe100m-meta/sample_metadata.parquet"))
cat("colonne:", names(s), "\n"); cat("campioni:", nrow(s), "\n")
if ("concentration_unit" %in% names(s)) print(s[, .N, by = concentration_unit])
v <- grep("drugname_drugconc", names(s), value = TRUE)[1]
x <- s[[v]]; u <- regmatches(x, regexpr("'[a-zA-Zµ]+'\\)\\]$", x)); print(table(u)); print(head(unique(x), 3))
cat("righe con piu' di un farmaco:", sum(lengths(regmatches(x, gregexpr("\\), \\(", x))) > 0L), "\n")
