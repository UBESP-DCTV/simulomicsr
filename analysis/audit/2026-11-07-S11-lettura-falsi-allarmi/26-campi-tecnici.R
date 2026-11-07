#!/usr/bin/env Rscript
# analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/26-campi-tecnici.R
# Decisione del PI del 2026-11-07, dopo il riassunto: una differenza solo tecnica fra i bracci e' un errore.
# Estrae i campi tecnici GEO (H5 ARCHS4 v2.5) dei campioni degli studi dei 1.903 confronti.
# Rscript SENZA --vanilla.
D  <- "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi"
H5 <- "analysis/input/human_gene_v2.5.h5"
g  <- utils::read.csv(file.path(D, "20-gruppi.csv"), stringsAsFactors = FALSE)
gsm <- unique(unlist(strsplit(g$gsm, ",", fixed = TRUE)))
campi <- c("geo_accession", "instrument_model", "library_selection", "library_source", "library_strategy",
           "molecule_ch1", "platform_id", "extract_protocol_ch1", "data_processing")
m <- lapply(stats::setNames(campi, campi), function(x) as.character(rhdf5::h5read(H5, paste0("meta/samples/", x))))
rhdf5::h5closeAll()
i <- match(gsm, m$geo_accession)
out <- as.data.frame(lapply(m[-1], function(v) v[i]), stringsAsFactors = FALSE); out <- cbind(gsm = gsm, out)
con <- gzfile(file.path(D, "26-campi-tecnici.csv.gz"), "w"); utils::write.csv(out, con, row.names = FALSE); close(con)
cat(sprintf("campioni %d | trovati %d\n", length(gsm), sum(!is.na(i))))
