#!/usr/bin/env Rscript
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/21-metadati-geo.R
# Titolo, sorgente e caratteristiche GEO (H5 ARCHS4 v2.5) dei campioni degli studi dei 1.903 confronti.
# Rscript SENZA --vanilla.
# Uso: Rscript analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/21-metadati-geo.R
D  <- "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi"
H5 <- "analysis/input/human_gene_v2.5.h5"
g  <- utils::read.csv(file.path(D, "20-gruppi.csv"), stringsAsFactors = FALSE)
gsm <- unique(unlist(strsplit(g$gsm, ",", fixed = TRUE)))
campi <- c("geo_accession", "title", "source_name_ch1", "characteristics_ch1", "series_id")
m <- lapply(stats::setNames(campi, campi), function(x) as.character(rhdf5::h5read(H5, paste0("meta/samples/", x))))
rhdf5::h5closeAll()
i <- match(gsm, m$geo_accession)
cat(sprintf("campioni chiesti %d | trovati nell'H5 %d\n", length(gsm), sum(!is.na(i))))
out <- data.frame(gsm = gsm, title = m$title[i], source = m$source_name_ch1[i],
                  characteristics = m$characteristics_ch1[i], series = m$series_id[i], stringsAsFactors = FALSE)
con <- gzfile(file.path(D, "21-metadati-geo.csv.gz"), "w")
utils::write.csv(out, con, row.names = FALSE); close(con)
cat("scritto 21-metadati-geo.csv.gz\n")
