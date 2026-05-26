#!/usr/bin/env Rscript
# RED ALERT FASE A1 (extra) — investigare i 293 sample con library_source="other"
#
# Domande:
#   - sono concentrati in pochi studi (ancillary library SC tipo HTO/BCR/ADT)
#     o spalmati su molti?
#   - che title/source_name_ch1/extract_protocol_ch1 hanno?
#   - sono "single-cell ancillary" mascherati o sono altri tipi di library
#     (es. small-RNA, custom library)?
#
# Output:
#   - analysis/audit/A1c-libsrc-other-detail.tsv (tutti i 293 sample)
#   - stampa concentrazione per series + top pattern title

suppressMessages({ library(rhdf5) })

h5_path <- "analysis/input/human_gene_v2.5.h5"
master  <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
out_tsv <- "analysis/audit/A1c-libsrc-other-detail.tsv"

cat("[A1c] reading H5 meta/samples ...\n")
h5_geo   <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_ser   <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_lib   <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_source"))
h5_title <- as.character(rhdf5::h5read(h5_path, "meta/samples/title"))
h5_src   <- as.character(rhdf5::h5read(h5_path, "meta/samples/source_name_ch1"))
h5_ext   <- as.character(rhdf5::h5read(h5_path, "meta/samples/extract_protocol_ch1"))
rhdf5::H5close()

# Restrict to rescued GSMs (879167)
cat("[A1c] loading rescued GSM list ...\n")
lines <- readLines(master, warn = FALSE)
parse_rid <- function(x) {
  m <- regmatches(x, regexpr('"record_id"\\s*:\\s*"[^"]+"', x))
  sub('.*"record_id"\\s*:\\s*"([^"]+)".*', "\\1", m)
}
rescued <- vapply(lines, parse_rid, character(1L), USE.NAMES = FALSE)
rm(lines); gc(verbose = FALSE)

mask_rescued <- h5_geo %in% rescued
mask_other   <- tolower(trimws(h5_lib)) == "other"
mask <- mask_rescued & mask_other

cat(sprintf("[A1c] sample con library_source=\"other\" sui 879167 rescued: %d\n", sum(mask)))

df <- data.frame(
  geo    = h5_geo[mask],
  series = h5_ser[mask],
  libsrc = h5_lib[mask],
  title  = h5_title[mask],
  src    = h5_src[mask],
  ext    = h5_ext[mask],
  stringsAsFactors = FALSE
)
df <- df[order(df$series, df$geo), ]
write.table(df, out_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

cat("\n[A1c] === Concentrazione per series ===\n")
by_ser <- sort(table(df$series), decreasing = TRUE)
cat(sprintf("studi coinvolti: %d\n", length(by_ser)))
cat("top 15 studi per n sample 'other':\n")
print(head(by_ser, 15))
cat(sprintf("\ndistribuzione n_sample per studio: mediana=%g  max=%d  min=%d\n",
            median(by_ser), max(by_ser), min(by_ser)))
cat("istogramma buckets:\n")
print(table(cut(as.integer(by_ser),
                breaks = c(0,1,2,5,10,20,50,Inf),
                labels = c("1","2","3-5","6-10","11-20","21-50",">50"))))

cat("\n[A1c] === Pattern title (top 25 prefissi/keyword) ===\n")
# Estrai parole/tag tra parentesi quadre (es. "[snRNA-seq]", "[HTO]", "[ADT]", "[BCR]")
tags <- regmatches(df$title, gregexpr("\\[[^]]+\\]", df$title))
tags_flat <- unlist(tags)
cat("tags [..]:\n")
print(head(sort(table(tags_flat), decreasing = TRUE), 25))

# Keywords single-cell ancillary
kw_sc_anc <- c("HTO","ADT","CITE","BCR","TCR","CSP","Multi-?seq","HASH","CMO","sgRNA",
               "GuideSeq","CRISPR","feature","FB ","hashtag","hash tag","antibody")
kw_pat <- paste0("(?i)", paste(kw_sc_anc, collapse = "|"))
df$is_sc_ancillary <- grepl(kw_pat, df$title, perl = TRUE) |
                       grepl(kw_pat, df$ext, perl = TRUE)
cat(sprintf("\nsample con keyword SC ancillary in title/extract_protocol: %d / %d\n",
            sum(df$is_sc_ancillary), nrow(df)))

cat("\n[A1c] === 20 esempi NON-SC-ancillary (per capire residuo) ===\n")
non_anc <- df[!df$is_sc_ancillary, ]
if (nrow(non_anc) > 0) {
  set.seed(1)
  ex <- non_anc[sample(seq_len(nrow(non_anc)), min(20, nrow(non_anc))), ]
  for (i in seq_len(nrow(ex))) {
    cat(sprintf("\n[%s | %s]\n  title : %s\n  src   : %s\n  ext   : %s\n",
                ex$geo[i], ex$series[i],
                substr(ex$title[i], 1, 160),
                substr(ex$src[i], 1, 160),
                substr(ex$ext[i], 1, 220)))
  }
}

cat("\n[A1c] === 10 esempi SC-ancillary (sanity check) ===\n")
anc <- df[df$is_sc_ancillary, ]
if (nrow(anc) > 0) {
  set.seed(1)
  ex <- anc[sample(seq_len(nrow(anc)), min(10, nrow(anc))), ]
  for (i in seq_len(nrow(ex))) {
    cat(sprintf("\n[%s | %s]\n  title : %s\n  src   : %s\n",
                ex$geo[i], ex$series[i],
                substr(ex$title[i], 1, 160),
                substr(ex$src[i], 1, 160)))
  }
}
cat("\n[A1c] DONE\n")
