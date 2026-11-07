#!/usr/bin/env Rscript
# 21-taglio-e-codifica.R — S12: spiega la previsione P2 (stringhe alla lunghezza
# massima) e prepara il confronto con GEO in rete (22-confronto-geo.py).
# Per i cinque campi di testo: alla lunghezza massima quante stringhe, quante
# distinte, quante serie, e la fine del testo; i picchi di stringhe DISTINTE a
# una stessa lunghezza; le stringhe che finiscono con «...». Poi sceglie i
# campioni da confrontare con GEO (seme 20261107).
# Uso: Rscript analysis/audit/2026-11-07-S12-stadio2b-disegno/21-taglio-e-codifica.R > .../21-out.txt 2>&1
OUT <- "analysis/audit/2026-11-07-S12-stadio2b-disegno"
H5 <- "analysis/input/human_gene_v2.5.h5"
campi <- c("geo_accession", "series_id", "title", "source_name_ch1", "characteristics_ch1",
           "extract_protocol_ch1", "data_processing")
M <- lapply(stats::setNames(campi, campi), function(k) as.character(rhdf5::h5read(H5, paste0("meta/samples/", k))))
rhdf5::h5closeAll()
for (f in campi[-(1:2)]) {
  b <- nchar(M[[f]], type = "bytes"); mx <- max(b); w <- which(b == mx)
  cat(sprintf("%-22s max %5d byte: %2d stringhe, %d distinte, %d serie; fine: %s\n", f, mx, length(w),
              length(unique(M[[f]][w])), length(unique(M$series_id[w])),
              substring(M[[f]][w[1]], nchar(M[[f]][w[1]]) - 59)))
  dd <- !duplicated(M[[f]]); tb <- table(b[dd]); L <- as.integer(names(tb)); n <- as.integer(tb)
  picco <- vapply(seq_along(L), function(i) {
    if (L[i] < 200 || n[i] < 20) return(FALSE)
    vic <- n[abs(L - L[i]) <= 10 & L != L[i]]; n[i] > 10 * max(1, stats::median(vic)) }, TRUE)
  for (Lp in L[picco]) {
    wp <- which(b == Lp & dd)
    cat(sprintf("   picco a %d byte: %d stringhe distinte da %d serie; fini: %s\n", Lp, length(wp),
                length(unique(M$series_id[wp])),
                paste(head(unique(substring(M[[f]][wp], nchar(M[[f]][wp]) - 30)), 3), collapse = " | ")))
  }
  cat(sprintf("   stringhe che finiscono con '...': %d\n", sum(grepl("\\.\\.\\.$", M[[f]]))))
}
usati <- readRDS(file.path(OUT, "20-campi-h5-campioni.rds"))$geo_accession
cat("\nsource_name con '...' fra i campioni dei 1.903:", sum(M$geo_accession[grepl("\\.\\.\\.$", M$source_name_ch1)] %in% usati), "\n")
cat("data_processing con '...' fra i campioni dei 1.903:", sum(M$geo_accession[grepl("\\.\\.\\.$", M$data_processing)] %in% usati), "su", length(usati), "\n")
set.seed(20261107)
w_src <- which(grepl("\\.\\.\\.$", M$source_name_ch1))
w_dp <- sample(which(grepl("\\.\\.\\.$", M$data_processing)), 6)
w_max <- c(which.max(nchar(M$extract_protocol_ch1, type = "bytes")), which.max(nchar(M$data_processing, type = "bytes")))
w <- c(w_max, w_src, w_dp)
sel <- data.frame(gsm = M$geo_accession[w],
                  quale = c("protocollo_max", "processing_max", rep("source_puntini", length(w_src)), rep("processing_puntini", length(w_dp))),
                  source = M$source_name_ch1[w], extract = M$extract_protocol_ch1[w], processing = M$data_processing[w])
jsonlite::write_json(sel, file.path(OUT, "21-campioni-per-geo.json"))
cat("campioni scelti per il confronto con GEO:", nrow(sel), "\n")
