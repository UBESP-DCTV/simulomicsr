#!/usr/bin/env Rscript
# La circolarita' sulle 194: serie in comune, piattaforme, citazioni nel testo dei campioni.
# Il testo e' quello dei campioni (titolo, sorgente, caratteristiche). Il riassunto della serie GEO non c'e'.
source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
gse <- sort(unique(unlist(d$studies_in_cluster)))
cat("studi distinti nelle 194:", length(gse), "; conformi a GSE:", all(grepl("^GSE[0-9]+$", gse)), "\n")
lincs <- c("GSE92742","GSE70138","GSE106127","GSE5258","GSE92743","GSE101406","GSE114949","GSE68427")
alt <- c(sciplex = "GSE139944", panacea = "GSE186341", drugseq = "GSE176150")
cat("serie LINCS in comune:", length(intersect(gse, lincs)), intersect(gse, lincs), "\n")
cat("controllo positivo, aggiungo", gse[1], ":", length(intersect(gse, c(lincs, gse[1]))), "\n")
cat("serie alternative in comune:", intersect(gse, alt), "\n")
meta <- as.data.table(readRDS(path.expand("~/.cache/R/simulomicsr/archs4-metadata-551065e6.rds")))
cat("serie L1000/LINCS presenti in ARCHS4 (tutto il bacino):", intersect(lincs, unique(meta$series_id)), "\n")
cat("serie alternative presenti in ARCHS4:", intersect(alt, unique(meta$series_id)), "\n")
gpl <- sort(unique(unlist(d$gpl_platforms))); cat("GPL nelle 194:", gpl, "\n")
cat("GPL L1000 in comune:", intersect(gpl, c("GPL20573","GPL22664","GPL15540")), "\n")
f <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
tmp <- tempfile()
re <- "LINCS|L1000|Connectivity Map|connectivity map|CMap|clue\\.io|BRD-[AK][0-9]{8}"
system(sprintf("grep -E '%s' %s > %s", re, f, tmp))
x <- if (file.size(tmp) > 0) rbindlist(lapply(readLines(tmp), function(l) { j <- jsonlite::fromJSON(l); data.table(gsm = j$geo_accession, gse = j$series_id, s = j$string) }), fill = TRUE) else data.table()
x[, marca := regmatches(s, regexpr(re, s))]
cat("\ncampioni del bacino con una citazione:", nrow(x), "; studi:", uniqueN(x$gse), "\n")
print(x[, .(campioni = .N, studi = uniqueN(gse)), by = marca])
set_194 <- gse
y <- x[x$gse %in% set_194]
cat("\nstudi delle 194 con una citazione:", uniqueN(y$gse), "su", length(set_194), "\n")
print(as.data.frame(y[, .(campioni = .N, marca = paste(unique(marca), collapse = "|"), esempio = substr(s[1], 1, 150)), by = gse]), right = FALSE)
g <- d[, .(gse = unlist(studies_in_cluster)), by = .(cluster_id, nome = contrast_entity_label)]
print(as.data.frame(g[gse %in% y$gse]), right = FALSE)
fwrite(y, file.path(OUT6, "30-citazioni-nelle-194.csv"))
# controllo positivo 4(c): la ricerca nel testo vede la parola di controllo
k <- system(sprintf("grep -c CRISPR %s", f), intern = TRUE)
tmp2 <- tempfile(); system(sprintf("grep CRISPR %s > %s", f, tmp2))
s2 <- rbindlist(lapply(readLines(tmp2), function(l) { j <- jsonlite::fromJSON(l); data.table(gse = j$series_id) }))
cat("\ncontrollo: campioni con CRISPR nel bacino:", k, "; studi delle 194 con CRISPR:", uniqueN(s2$gse[s2$gse %in% set_194]), "\n")
