#!/usr/bin/env Rscript
# RED ALERT FASE A1 (extra) — investigare i 64 studi "mixed" (frac_sc 10-99%)
#
# Obiettivo: capire se i sample SC dentro studi mixed sono:
#   (a) submitter mistake (sample SC isolati in studio bulk),
#   (b) studio multi-modality dichiarato (bulk + SC paralleli),
#   (c) altro.
#
# Approccio: per ogni studio mixed mostriamo n_sc / n_total + title /
# source_name_ch1 di 2 sample SC e 2 sample bulk per ispezione manuale.

suppressMessages({ library(rhdf5) })

h5_path  <- "analysis/input/human_gene_v2.5.h5"
ser_tsv  <- "analysis/audit/A1-single-cell-series-breakdown.tsv"
out_tsv  <- "analysis/audit/A1b-mixed-studies-detail.tsv"

stopifnot(file.exists(h5_path), file.exists(ser_tsv))

ser <- read.table(ser_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                  quote = "")
mixed <- ser[ser$frac_sc < 1.0 & ser$n_sc > 0, ]
mixed <- mixed[order(-mixed$frac_sc, -mixed$n_sc), ]
cat(sprintf("[A1b] studi mixed (frac_sc 0<x<1): %d\n", nrow(mixed)))
cat(sprintf("  1-10%%   : %d\n", sum(mixed$frac_sc <  0.10)))
cat(sprintf("  10-50%%  : %d\n", sum(mixed$frac_sc >= 0.10 & mixed$frac_sc < 0.50)))
cat(sprintf("  50-99%%  : %d\n", sum(mixed$frac_sc >= 0.50 & mixed$frac_sc < 1.0)))

# Carico campi H5 necessari per ispezione (solo i sample dei series mixed)
cat("[A1b] reading H5 fields (geo_accession, series_id, library_source, title, source_name_ch1) ...\n")
h5_geo    <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_series <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_libsrc <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_source"))
h5_title  <- as.character(rhdf5::h5read(h5_path, "meta/samples/title"))
h5_src    <- as.character(rhdf5::h5read(h5_path, "meta/samples/source_name_ch1"))
rhdf5::H5close()

sc_norm <- tolower(trimws(h5_libsrc))
is_sc <- sc_norm %in% c("transcriptomic single cell", "genomic single cell")

mask <- h5_series %in% mixed$series_id
df <- data.frame(
  geo = h5_geo[mask],
  series = h5_series[mask],
  libsrc = h5_libsrc[mask],
  is_sc = is_sc[mask],
  title = h5_title[mask],
  src = h5_src[mask],
  stringsAsFactors = FALSE
)
cat(sprintf("[A1b] sample dei %d studi mixed: %d totali\n", nrow(mixed), nrow(df)))

# Per ogni studio: take 2 SC + 2 bulk e mostra title + src
inspect <- do.call(rbind, lapply(seq_len(nrow(mixed)), function(i) {
  s <- mixed$series_id[i]
  dd <- df[df$series == s, ]
  sc <- dd[dd$is_sc, , drop = FALSE]
  bk <- dd[!dd$is_sc, , drop = FALSE]
  take_sc <- head(sc, 2)
  take_bk <- head(bk, 2)
  out <- rbind(take_sc, take_bk)
  out$role <- c(rep("SC", nrow(take_sc)), rep("BULK", nrow(take_bk)))
  out$n_sc <- mixed$n_sc[i]
  out$n_total <- mixed$n_total[i]
  out$frac_sc <- mixed$frac_sc[i]
  out
}))
inspect <- inspect[, c("series", "n_sc", "n_total", "frac_sc", "role",
                       "geo", "libsrc", "title", "src")]
write.table(inspect, out_tsv, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("[A1b] dettaglio per ispezione: %s\n", out_tsv))

cat("\n[A1b] === 64 studi mixed (ordinati per frac_sc desc) ===\n")
print(mixed[, c("series_id", "n_sc", "n_total", "frac_sc")], row.names = FALSE)
