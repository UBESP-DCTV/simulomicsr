#!/usr/bin/env Rscript
# A2b coda — sui 514 sample SmartSeq + 546 sample single_cell_literal NON
# coperti dai top 30 cluster, scan keyword di alarm per intercettare FP.

suppressMessages({ library(rhdf5) })
set.seed(42)

h5_path <- "analysis/input/human_gene_v2.5.h5"
master  <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"

cat("[A2b-tail] reading H5 + master ...\n")
h5_geo   <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_ser   <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_lib   <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_source"))
h5_title <- as.character(rhdf5::h5read(h5_path, "meta/samples/title"))
h5_src   <- as.character(rhdf5::h5read(h5_path, "meta/samples/source_name_ch1"))
h5_ext   <- as.character(rhdf5::h5read(h5_path, "meta/samples/extract_protocol_ch1"))
rhdf5::H5close()

lines <- readLines(master, warn = FALSE)
parse_rid <- function(x) {
  m <- regmatches(x, regexpr('"record_id"\\s*:\\s*"[^"]+"', x))
  sub('.*"record_id"\\s*:\\s*"([^"]+)".*', "\\1", m)
}
rescued <- vapply(lines, parse_rid, character(1L), USE.NAMES = FALSE)
rm(lines); gc(verbose = FALSE)

mask <- (h5_geo %in% rescued) & (tolower(trimws(h5_lib)) == "transcriptomic")
df <- data.frame(
  geo = h5_geo[mask], series = h5_ser[mask],
  title = h5_title[mask], src = h5_src[mask], ext = h5_ext[mask],
  stringsAsFactors = FALSE
)
rm(h5_geo, h5_ser, h5_lib, h5_title, h5_src, h5_ext); gc(verbose = FALSE)
target_text <- paste(df$ext, df$title, df$src, sep = " || ")

extract_context <- function(pat, text, window = 80) {
  m <- regexpr(pat, text, perl = TRUE)
  out <- rep(NA_character_, length(text))
  hit <- m > 0
  s <- pmax(1L, m[hit] - window)
  e <- pmin(nchar(text[hit]), m[hit] + attr(m, "match.length")[hit] + window)
  out[hit] <- substring(text[hit], s, e)
  out
}
normalize_snippet <- function(x) {
  x <- tolower(x); x <- gsub("[[:punct:]\\s]+", " ", x, perl = TRUE)
  x <- gsub("\\s+", " ", x); trimws(x)
}

# Alarm keyword: contesti che suggeriscono bulk-low-input / pool / bulk-after-dissociation
alarm_kw <- "(?i)stranded total RNA|stranded mRNA|bulk RNA|bulk[- ]rnaseq|bulk[- ]seq|not.{0,15}single|did not perform single|pooled.{0,40}cells|from.{0,5}pool|comparison.{0,20}single cell|control.{0,20}bulk"

scan_pattern <- function(pattern_name, regex_pat, N = 1000) {
  hit <- grepl(regex_pat, target_text, perl = TRUE)
  ix <- which(hit)
  samp <- sample(ix, min(N, length(ix)))
  ctx <- extract_context(regex_pat, target_text[samp], window = 80)
  norm <- normalize_snippet(ctx)
  t_top <- head(sort(table(norm), decreasing = TRUE), 30)
  in_top <- norm %in% names(t_top)
  tail_ix <- which(!in_top)
  cat(sprintf("\n[A2b-tail] === %s ===\n", pattern_name))
  cat(sprintf("  N sample            : %d\n", length(samp)))
  cat(sprintf("  copertura top 30    : %d (%.1f%%)\n", sum(in_top), 100 * sum(in_top) / length(samp)))
  cat(sprintf("  coda (non in top30) : %d\n", length(tail_ix)))

  # Scan alarm keyword sul TESTO PIENO ext+title+src dei sample della coda
  tail_text <- target_text[samp[tail_ix]]
  alarm_hit <- grepl(alarm_kw, tail_text, perl = TRUE)
  cat(sprintf("  alarm keyword in coda: %d / %d\n", sum(alarm_hit), length(tail_ix)))

  if (sum(alarm_hit) > 0) {
    cat("\n  -- candidati FP (mostro fino a 20):\n")
    show_ix <- tail_ix[alarm_hit]
    for (j in head(show_ix, 20)) {
      cat(sprintf("\n  [%s | %s]\n    context: %s\n    title  : %s\n    ext    : %s\n",
                  df$geo[samp[j]], df$series[samp[j]],
                  substr(ctx[j], 1, 200),
                  substr(df$title[samp[j]], 1, 130),
                  substr(df$ext[samp[j]], 1, 250)))
    }
  }
  invisible(NULL)
}

scan_pattern("SmartSeq", "(?i)(?<!3-)(?<!3)\\bSmart[- ]?Seq[23]?\\b")
scan_pattern("single_cell_literal", "(?i)\\bsingle[- ]?cell\\b")

cat("\n[A2b-tail] DONE\n")
