#!/usr/bin/env Rscript
# RED ALERT FASE A2 (validation extra) — FPR cluster-based dei pattern
# volumetrici SmartSeq + single_cell_literal.
#
# Strategia: 1000 random per pattern, estrai contesto match (±80 char),
# normalizza (lowercase + strip punct + collapse spaces), cluster exact-match,
# top cluster ordinati per dimensione. Manual TP/FP classification fatta a
# voce in CLAUDE.md / commit message; questo script produce solo la tabella
# cluster + esempi per il review.

suppressMessages({ library(rhdf5) })

set.seed(42)  # riproducibilita'

h5_path <- "analysis/input/human_gene_v2.5.h5"
master  <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
out_smartseq <- "analysis/audit/A2b-SmartSeq-clusters.tsv"
out_sclit    <- "analysis/audit/A2b-single_cell_literal-clusters.tsv"

# ============================================================
# Re-genera il bacino A2 (rescued AND library_source=transcriptomic)
# ============================================================
cat("[A2b] reading H5 + master ...\n")
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

# ============================================================
# Helpers
# ============================================================
extract_context <- function(pat, text, window = 80) {
  # ritorna stringa di contesto attorno alla prima occorrenza pattern,
  # NA se nessuna occorrenza
  m <- regexpr(pat, text, perl = TRUE)
  out <- rep(NA_character_, length(text))
  hit <- m > 0
  s <- pmax(1L, m[hit] - window)
  e <- pmin(nchar(text[hit]), m[hit] + attr(m, "match.length")[hit] + window)
  out[hit] <- substring(text[hit], s, e)
  out
}

normalize_snippet <- function(x) {
  x <- tolower(x)
  x <- gsub("[[:punct:]\\s]+", " ", x, perl = TRUE)
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)
  x
}

wilson_ci <- function(k, n, conf = 0.95) {
  if (n == 0) return(c(0, 0))
  z <- qnorm(1 - (1 - conf) / 2)
  p <- k / n
  denom <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / denom
  half <- (z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / denom
  c(lo = max(0, centre - half), hi = min(1, centre + half))
}

# ============================================================
# Validazione SmartSeq
# ============================================================
pat_smartseq <- "(?i)(?<!3-)(?<!3)\\bSmart[- ]?Seq[23]?\\b"
hit_smart <- grepl(pat_smartseq, target_text, perl = TRUE)
cat(sprintf("\n[A2b] SmartSeq hit totali: %d\n", sum(hit_smart)))

ix_smart <- which(hit_smart)
N <- min(1000L, length(ix_smart))
samp_smart <- sample(ix_smart, N)
ctx_smart <- extract_context(pat_smartseq, target_text[samp_smart], window = 80)
norm_smart <- normalize_snippet(ctx_smart)

t_smart <- sort(table(norm_smart), decreasing = TRUE)
cat(sprintf("[A2b] SmartSeq N=%d random, cluster distinct: %d\n", N, length(t_smart)))
cat(sprintf("[A2b] top 30 cluster coprono %d / %d (%.1f%%) della validation\n",
            sum(head(t_smart, 30)), N, 100 * sum(head(t_smart, 30)) / N))

# Salva top 50 cluster con 1 esempio non-normalizzato per cluster
top50 <- head(t_smart, 50)
out <- data.frame(
  rank = seq_along(top50),
  size = as.integer(top50),
  normalized = names(top50),
  example_raw = NA_character_,
  example_geo = NA_character_,
  example_series = NA_character_,
  stringsAsFactors = FALSE
)
for (i in seq_along(top50)) {
  ix <- which(norm_smart == names(top50)[i])[1]
  out$example_raw[i] <- substr(ctx_smart[ix], 1, 200)
  out$example_geo[i] <- df$geo[samp_smart[ix]]
  out$example_series[i] <- df$series[samp_smart[ix]]
}
write.table(out, out_smartseq, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("[A2b] SmartSeq top50 clusters scritti in: %s\n", out_smartseq))

cat("\n[A2b] === SmartSeq: top 30 cluster ===\n")
for (i in seq_len(min(30, nrow(out)))) {
  cat(sprintf("\n#%d  size=%d  GSE=%s  GSM=%s\n  %s\n",
              out$rank[i], out$size[i], out$example_series[i],
              out$example_geo[i], out$example_raw[i]))
}

# ============================================================
# Validazione single_cell_literal
# ============================================================
pat_sclit <- "(?i)\\bsingle[- ]?cell\\b"
hit_sclit <- grepl(pat_sclit, target_text, perl = TRUE)
cat(sprintf("\n\n[A2b] single_cell_literal hit totali: %d\n", sum(hit_sclit)))

ix_sclit <- which(hit_sclit)
N <- min(1000L, length(ix_sclit))
samp_sclit <- sample(ix_sclit, N)
ctx_sclit <- extract_context(pat_sclit, target_text[samp_sclit], window = 80)
norm_sclit <- normalize_snippet(ctx_sclit)

t_sclit <- sort(table(norm_sclit), decreasing = TRUE)
cat(sprintf("[A2b] single_cell_literal N=%d random, cluster distinct: %d\n", N, length(t_sclit)))
cat(sprintf("[A2b] top 30 cluster coprono %d / %d (%.1f%%) della validation\n",
            sum(head(t_sclit, 30)), N, 100 * sum(head(t_sclit, 30)) / N))

top50 <- head(t_sclit, 50)
out <- data.frame(
  rank = seq_along(top50),
  size = as.integer(top50),
  normalized = names(top50),
  example_raw = NA_character_,
  example_geo = NA_character_,
  example_series = NA_character_,
  stringsAsFactors = FALSE
)
for (i in seq_along(top50)) {
  ix <- which(norm_sclit == names(top50)[i])[1]
  out$example_raw[i] <- substr(ctx_sclit[ix], 1, 200)
  out$example_geo[i] <- df$geo[samp_sclit[ix]]
  out$example_series[i] <- df$series[samp_sclit[ix]]
}
write.table(out, out_sclit, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("[A2b] single_cell_literal top50 clusters scritti in: %s\n", out_sclit))

cat("\n[A2b] === single_cell_literal: top 30 cluster ===\n")
for (i in seq_len(min(30, nrow(out)))) {
  cat(sprintf("\n#%d  size=%d  GSE=%s  GSM=%s\n  %s\n",
              out$rank[i], out$size[i], out$example_series[i],
              out$example_geo[i], out$example_raw[i]))
}

cat("\n[A2b] DONE — TP/FP classification cluster-by-cluster nel turno successivo.\n")
