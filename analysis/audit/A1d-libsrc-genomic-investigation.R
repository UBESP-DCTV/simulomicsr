#!/usr/bin/env Rscript
# RED ALERT FASE A1 (extra) — investigare i 634 sample con library_source="genomic"
#
# Domande:
#   - perche' un sample marcato `library_strategy=RNA-Seq` ha
#     `library_source=genomic`? (incompatibile per definizione GEO)
#   - sono concentrati o sparsi? errori submitter o categoria sistemica?
#   - che protocollo (extract_protocol_ch1) dichiarano?
#
# Output:
#   - analysis/audit/A1d-libsrc-genomic-detail.tsv (tutti i 634)
#   - stampa concentrazione per series + pattern title + 20 esempi residui

suppressMessages({ library(rhdf5) })

h5_path <- "analysis/input/human_gene_v2.5.h5"
master  <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
out_tsv <- "analysis/audit/A1d-libsrc-genomic-detail.tsv"

cat("[A1d] reading H5 meta/samples ...\n")
h5_geo   <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_ser   <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_lib   <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_source"))
h5_libsel<- as.character(rhdf5::h5read(h5_path, "meta/samples/library_selection"))
h5_title <- as.character(rhdf5::h5read(h5_path, "meta/samples/title"))
h5_src   <- as.character(rhdf5::h5read(h5_path, "meta/samples/source_name_ch1"))
h5_ext   <- as.character(rhdf5::h5read(h5_path, "meta/samples/extract_protocol_ch1"))
h5_mol   <- as.character(rhdf5::h5read(h5_path, "meta/samples/molecule_ch1"))
rhdf5::H5close()

cat("[A1d] loading rescued GSM list ...\n")
lines <- readLines(master, warn = FALSE)
parse_rid <- function(x) {
  m <- regmatches(x, regexpr('"record_id"\\s*:\\s*"[^"]+"', x))
  sub('.*"record_id"\\s*:\\s*"([^"]+)".*', "\\1", m)
}
rescued <- vapply(lines, parse_rid, character(1L), USE.NAMES = FALSE)
rm(lines); gc(verbose = FALSE)

mask <- (h5_geo %in% rescued) & (tolower(trimws(h5_lib)) == "genomic")
cat(sprintf("[A1d] sample con library_source=\"genomic\" sui 879167 rescued: %d\n", sum(mask)))

df <- data.frame(
  geo    = h5_geo[mask],
  series = h5_ser[mask],
  libsrc = h5_lib[mask],
  libsel = h5_libsel[mask],
  mol    = h5_mol[mask],
  title  = h5_title[mask],
  src    = h5_src[mask],
  ext    = h5_ext[mask],
  stringsAsFactors = FALSE
)
df <- df[order(df$series, df$geo), ]
write.table(df, out_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

cat("\n[A1d] === Concentrazione per series ===\n")
by_ser <- sort(table(df$series), decreasing = TRUE)
cat(sprintf("studi coinvolti: %d\n", length(by_ser)))
cat("top 20 studi per n sample 'genomic':\n")
print(head(by_ser, 20))
cat("\nistogramma buckets (n sample/studio):\n")
print(table(cut(as.integer(by_ser),
                breaks = c(0,1,2,5,10,20,50,100,Inf),
                labels = c("1","2","3-5","6-10","11-20","21-50","51-100",">100"))))

cat("\n[A1d] === molecule_ch1 (RNA vs DNA?) ===\n")
print(sort(table(df$mol, useNA = "ifany"), decreasing = TRUE))

cat("\n[A1d] === library_selection ===\n")
print(sort(table(df$libsel, useNA = "ifany"), decreasing = TRUE))

cat("\n[A1d] === Tag [..] in title (top 20) ===\n")
tags <- regmatches(df$title, gregexpr("\\[[^]]+\\]", df$title))
tags_flat <- unlist(tags)
print(head(sort(table(tags_flat), decreasing = TRUE), 20))

cat("\n[A1d] === Keyword scan in title/source/extract_protocol ===\n")
patterns <- list(
  ATAC      = "(?i)\\bATAC[- ]?seq\\b|\\bATAC\\b",
  ChIP      = "(?i)\\bChIP[- ]?seq\\b|\\bChIP\\b",
  WGBS_Bisulfite = "(?i)bisulfite|WGBS|RRBS|methyl",
  DamID     = "(?i)DamID",
  HiC       = "(?i)Hi[- ]?C\\b",
  CUTRUN    = "(?i)CUT&RUN|CUT&Tag|CUTandRUN|CUT-RUN",
  scATAC    = "(?i)scATAC|snATAC",
  Ribo      = "(?i)Ribo[- ]?seq|RPF\\b",
  CLIP      = "(?i)CLIP[- ]?seq|iCLIP|eCLIP|PAR-?CLIP|RIP[- ]?seq",
  gDNA      = "(?i)\\bgDNA\\b|genomic DNA|whole genome",
  SLAMseq   = "(?i)SLAM[- ]?seq|TT[- ]?seq|4sU",
  PolyA_se  = "(?i)polyA|poly\\(A\\)|poly A"
)
for (nm in names(patterns)) {
  hit <- grepl(patterns[[nm]], df$title) |
         grepl(patterns[[nm]], df$src) |
         grepl(patterns[[nm]], df$ext)
  cat(sprintf("  %-18s : %d\n", nm, sum(hit)))
}

cat("\n[A1d] === 25 esempi random (per ispezione) ===\n")
set.seed(2)
ex <- df[sample(seq_len(nrow(df)), min(25, nrow(df))), ]
for (i in seq_len(nrow(ex))) {
  cat(sprintf("\n[%s | %s | libsel=%s | mol=%s]\n  title: %s\n  src  : %s\n  ext  : %s\n",
              ex$geo[i], ex$series[i], ex$libsel[i], ex$mol[i],
              substr(ex$title[i], 1, 160),
              substr(ex$src[i], 1, 160),
              substr(ex$ext[i], 1, 220)))
}

cat("\n[A1d] DONE\n")
