#!/usr/bin/env Rscript
# RED ALERT FASE A1 — conta sample che cadono col filtro `library_source`
#
# Obiettivo: sui 879.167 GSM del master rescued, quanti sono etichettati
# da ARCHS4 v2.5 come single-cell tramite `library_source`?
# Output:
#   - tabella valori distinti `library_source` (sul subset rescued)
#   - count single-cell (transcriptomic|genomic single cell)
#   - breakdown per studio (frac_sc per series_id)
#   - lista GSM single-cell salvata in analysis/audit/A1-single-cell-by-library-source.tsv

suppressMessages({
  library(rhdf5)
  library(jsonlite)
})

h5_path     <- "analysis/input/human_gene_v2.5.h5"
master_path <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
out_log     <- "analysis/audit/A1-single-cell-by-library-source.tsv"
out_series  <- "analysis/audit/A1-single-cell-series-breakdown.tsv"

stopifnot(file.exists(h5_path), file.exists(master_path))

cat("[A1] reading master JSONL (geo_accession only) ...\n")
# stream-parse for memory: master JSONL ha 879k record × ~10 campi.
# Estraggo solo geo_accession + series_id via jq-style minimal parse.
master_lines <- readLines(master_path, warn = FALSE)
cat(sprintf("[A1] master records: %d\n", length(master_lines)))

# Parse minimo: estraggo "record_id" (top-level) da ogni riga JSON.
# Nota: `geo_accession` non e' top-level nel master rescued: e' annidato
# dentro `raw_output` (string escaped). `record_id` e' la chiave GSM
# canonica del master, presente in 879167/879167 record.
parse_rid <- function(line) {
  m <- regmatches(line, regexpr('"record_id"\\s*:\\s*"[^"]+"', line))
  if (length(m) == 0) return(NA_character_)
  sub('.*"record_id"\\s*:\\s*"([^"]+)".*', "\\1", m)
}
rescued_gsm <- vapply(master_lines, parse_rid, character(1L), USE.NAMES = FALSE)
rm(master_lines); gc(verbose = FALSE)

stopifnot(!anyNA(rescued_gsm))
cat(sprintf("[A1] unique rescued GSMs: %d\n", length(unique(rescued_gsm))))

cat("[A1] reading H5 meta/samples (geo_accession, series_id, library_source, organism, library_strategy) ...\n")
h5_geo    <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_series <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_libsrc <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_source"))
h5_org    <- as.character(rhdf5::h5read(h5_path, "meta/samples/organism_ch1"))
h5_libstr <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_strategy"))
rhdf5::H5close()

cat(sprintf("[A1] H5 total samples: %d\n", length(h5_geo)))

# Subset H5 ai GSM nel master rescued
idx <- match(rescued_gsm, h5_geo)
miss <- sum(is.na(idx))
cat(sprintf("[A1] GSM rescued not found in H5: %d (atteso 0)\n", miss))
if (miss > 0L) stop("GSM rescued mismatch with H5; investigate.")

sub_series <- h5_series[idx]
sub_libsrc <- h5_libsrc[idx]
sub_org    <- h5_org[idx]
sub_libstr <- h5_libstr[idx]

cat("\n[A1] === Distribuzione library_source sui 879.167 rescued ===\n")
tab <- sort(table(sub_libsrc, useNA = "ifany"), decreasing = TRUE)
print(tab)

cat("\n[A1] === Sanity: organism/library_strategy sui rescued ===\n")
cat("organism_ch1 unique:\n"); print(table(sub_org, useNA = "ifany"))
cat("\nlibrary_strategy unique:\n"); print(table(sub_libstr, useNA = "ifany"))

# Definizione single-cell esplicita (case-insensitive, trimming)
sc_norm <- tolower(trimws(sub_libsrc))
is_sc <- sc_norm %in% c("transcriptomic single cell", "genomic single cell")

n_sc <- sum(is_sc)
cat(sprintf("\n[A1] === SC count by library_source: %d / %d (%.2f%%) ===\n",
            n_sc, length(is_sc), 100 * n_sc / length(is_sc)))
cat(sprintf("  transcriptomic single cell: %d\n",
            sum(sc_norm == "transcriptomic single cell")))
cat(sprintf("  genomic single cell       : %d\n",
            sum(sc_norm == "genomic single cell")))

# Log GSM single-cell + series_id
log_df <- data.frame(
  geo_accession = rescued_gsm[is_sc],
  series_id     = sub_series[is_sc],
  library_source = sub_libsrc[is_sc],
  stringsAsFactors = FALSE
)
write.table(log_df, out_log, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("\n[A1] log GSM SC scritto in: %s (%d righe)\n", out_log, nrow(log_df)))

# Distribuzione per studio: frac single-cell per series_id
all_df <- data.frame(
  geo_accession = rescued_gsm,
  series_id     = sub_series,
  is_sc         = is_sc,
  stringsAsFactors = FALSE
)
by_series <- aggregate(cbind(n_total = !is.na(geo_accession),
                              n_sc    = is_sc) ~ series_id,
                       data = all_df, FUN = sum)
by_series$frac_sc <- by_series$n_sc / by_series$n_total
by_series_sc <- by_series[by_series$n_sc > 0, ]
by_series_sc <- by_series_sc[order(-by_series_sc$frac_sc, -by_series_sc$n_sc), ]
write.table(by_series_sc, out_series, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("[A1] breakdown per series scritto in: %s (%d studi con almeno 1 SC)\n",
            out_series, nrow(by_series_sc)))

cat("\n[A1] === Breakdown studi col SC: distribuzione frac_sc ===\n")
buckets <- cut(by_series_sc$frac_sc,
               breaks = c(-Inf, 0.01, 0.10, 0.50, 0.99, 1.0001),
               labels = c("0%", "1-10%", "10-50%", "50-99%", "100%"),
               right = TRUE, include.lowest = TRUE)
print(table(buckets))

cat("\n[A1] DONE\n")
