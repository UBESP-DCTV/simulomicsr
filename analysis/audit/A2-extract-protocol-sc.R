#!/usr/bin/env Rscript
# RED ALERT FASE A2 — sample SC mascherati come library_source=transcriptomic,
# intercettati via parsing extract_protocol_ch1.
#
# Bacino: i 850.225 sample che hanno SUPERATO A1
#   (library_source == "transcriptomic" & rescued).
#
# Output:
#   - tabella catch per pattern (gruppo K kit-specific vs gruppo S semantica)
#   - lista GSM marcati + pattern matched in analysis/audit/A2-sc-by-extract-protocol.tsv
#   - 20 esempi random per validazione manuale (kit + semantica + estremi)

suppressMessages({ library(rhdf5) })

h5_path <- "analysis/input/human_gene_v2.5.h5"
master  <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
out_tsv <- "analysis/audit/A2-sc-by-extract-protocol.tsv"

cat("[A2] reading H5 meta/samples ...\n")
h5_geo   <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_ser   <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_lib   <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_source"))
h5_title <- as.character(rhdf5::h5read(h5_path, "meta/samples/title"))
h5_src   <- as.character(rhdf5::h5read(h5_path, "meta/samples/source_name_ch1"))
h5_ext   <- as.character(rhdf5::h5read(h5_path, "meta/samples/extract_protocol_ch1"))
rhdf5::H5close()

cat("[A2] loading rescued GSM list ...\n")
lines <- readLines(master, warn = FALSE)
parse_rid <- function(x) {
  m <- regmatches(x, regexpr('"record_id"\\s*:\\s*"[^"]+"', x))
  sub('.*"record_id"\\s*:\\s*"([^"]+)".*', "\\1", m)
}
rescued <- vapply(lines, parse_rid, character(1L), USE.NAMES = FALSE)
rm(lines); gc(verbose = FALSE)

# Bacino A2: rescued AND library_source == "transcriptomic" (cioe' superato A1)
mask <- (h5_geo %in% rescued) &
        (tolower(trimws(h5_lib)) == "transcriptomic")
cat(sprintf("[A2] bacino A2 (rescued AND libsrc==transcriptomic): %d\n", sum(mask)))

df <- data.frame(
  geo    = h5_geo[mask],
  series = h5_ser[mask],
  title  = h5_title[mask],
  src    = h5_src[mask],
  ext    = h5_ext[mask],
  stringsAsFactors = FALSE
)
rm(h5_geo, h5_ser, h5_lib, h5_title, h5_src, h5_ext); gc(verbose = FALSE)

# ============================================================
# Pattern definition (lista approvata 2026-05-26, doc in RED_ALERT.md A2)
# ============================================================

# Gruppo K: kit/platform specifici, alta confidenza.
# Note 2026-05-26: 10x_Chromium e SmartSeq ristretti per evitare false
# positive da context buffer (10x SDS buffer, 10x SSC) e da protocollo
# bulk Smart-3SEQ (Foley 2019, 3'-tag RNA-seq).
patterns_K <- c(
  # 10x: richiede contesto Genomics / Chromium / chip per evitare match
  # con "10x diluted", "10x buffer", "10x SSC" e simili.
  "10x_Chromium"        = "(?i)\\b10[xX]\\s*Genomics\\b|\\bChromium\\b|\\b10[xX]\\s*chip\\b|\\b10[xX]\\s*chromium\\b",
  # SmartSeq: solo SmartSeq / SmartSeq2 / SmartSeq3 (SC, Picelli 2014/2018);
  # esclude esplicitamente Smart-3SEQ (bulk 3'-tag Foley 2019).
  "SmartSeq"            = "(?i)(?<!3-)(?<!3)\\bSmart[- ]?Seq[23]?\\b",
  "Fluidigm_C1"         = "(?i)Fluidigm|\\bC1 chip\\b|\\bC1 IFC\\b",
  "ICELL8"              = "(?i)ICELL8",
  "Drop-seq_inDrop"     = "(?i)Drop[- ]?seq|inDrop",
  "CEL-seq_MARS-seq"    = "(?i)CEL[- ]?seq|MARS[- ]?seq",
  "Seq-Well"            = "(?i)Seq[- ]?Well",
  "BD_Rhapsody"         = "(?i)BD\\s*Rhapsody|Rhapsody",
  "Digital_microfluid"  = "(?i)Digital microfluidic",
  "CellPlex"            = "(?i)CellPlex|3'\\s*CellPlex",
  "CellTag"             = "(?i)CellTag",
  "Multi-seq"           = "(?i)Multi[- ]?seq",
  "snDrop"              = "(?i)snDrop"
)

# Gruppo S: semantica single-cell, da validare per false positive.
# Underscore-aware (fix paper-grade 2026-05-26): catch su single_cell, scRNA_seq,
# sn_RNA, ecc. La vecchia regex `\bsingle[- ]?cell\b` perdeva ~3.668 SC FN per
# via di underscore (perl `_` e' word-char → no boundary). Dettagli ultrathink:
# Bug 2 nella sessione 4 RED_ALERT, prima del rerun A2 corretto.
patterns_S <- c(
  "single_cell_literal" = "(?i)(^|[^a-z0-9])single[- _]?cell(?![a-z0-9])",
  "single_nucle"        = "(?i)(^|[^a-z0-9])single[- _]?nucle[ari]+(?![a-z0-9])",
  "snRNA"               = "(?i)(^|[^a-z0-9])sn[- _]?RNA(-?seq[23]?)?(?![a-z0-9])|(^|[^a-z0-9])Nuc[- _]?seq(?![a-z0-9])",
  "scRNA"               = "(?i)(^|[^a-z0-9])sc[- _]?RNA(-?seq[23]?)?(?![a-z0-9])"
)

# Search target: extract_protocol_ch1 + title + source_name_ch1
target_text <- paste(df$ext, df$title, df$src, sep = " || ")

cat("\n[A2] === Hit per pattern Gruppo K (kit-specific) ===\n")
hits_K <- matrix(FALSE, nrow = nrow(df), ncol = length(patterns_K))
colnames(hits_K) <- names(patterns_K)
for (nm in names(patterns_K)) {
  hits_K[, nm] <- grepl(patterns_K[[nm]], target_text, perl = TRUE)
  cat(sprintf("  %-22s : %7d\n", nm, sum(hits_K[, nm])))
}

cat("\n[A2] === Hit per pattern Gruppo S (semantica) ===\n")
hits_S <- matrix(FALSE, nrow = nrow(df), ncol = length(patterns_S))
colnames(hits_S) <- names(patterns_S)
for (nm in names(patterns_S)) {
  hits_S[, nm] <- grepl(patterns_S[[nm]], target_text, perl = TRUE)
  cat(sprintf("  %-22s : %7d\n", nm, sum(hits_S[, nm])))
}

any_K <- rowSums(hits_K) > 0
any_S <- rowSums(hits_S) > 0
any_either <- any_K | any_S

cat(sprintf("\n[A2] === UNION (qualunque pattern matcha) ===\n"))
cat(sprintf("  Solo K (kit-specific)   : %d\n", sum(any_K & !any_S)))
cat(sprintf("  Solo S (semantica)      : %d\n", sum(any_S & !any_K)))
cat(sprintf("  K + S (entrambi)        : %d\n", sum(any_K & any_S)))
cat(sprintf("  Totale catch (K OR S)   : %d / %d (%.2f%%)\n",
            sum(any_either), nrow(df),
            100 * sum(any_either) / nrow(df)))

# ============================================================
# Title-based rescue (post-validazione A2b 2026-05-26): sample che
# matchano regex SC ma il cui title contiene esplicitamente "bulk"
# (es. "Sample-83 (Total Bulk RNA-seq)", "Bulk_RNA-Seq_NSCLC", "iPS2 (bulk)")
# sono studi multi-modality dove il sample specifico e' bulk-low-input.
# Razionale FPR cluster validation: ~70-80% dei FP osservati avevano
# title con "bulk" esplicito.
# ============================================================
# Underscore-aware (fix paper-grade 2026-05-26): rescue corretto su title con
# underscore-form (es. `Bulk_RNA-Seq_NSCLC_12_TIL`, `Bulk_24h_C1`). Vecchia
# regex `\bbulk\b` perdeva ~1.517 sample bulk-low-input multi-modality che
# erano stati droppati a torto da A2 baseline.
title_bulk_rescue <- grepl("(?i)(^|[^a-z0-9])bulk([^a-z0-9]|$)|(^|[^a-z0-9])bulkRNA(?![a-z0-9])", df$title, perl = TRUE)
rescued_mask <- any_either & title_bulk_rescue
drop_mask    <- any_either & !title_bulk_rescue

cat(sprintf("\n[A2] === Title-based rescue (\"bulk\" in title) ===\n"))
cat(sprintf("  rescued (any_either AND title bulk): %d\n", sum(rescued_mask)))
cat(sprintf("  drop finale post-rescue            : %d / %d (%.2f%%)\n",
            sum(drop_mask), nrow(df),
            100 * sum(drop_mask) / nrow(df)))

# Salva GSM marcati con quali pattern hanno matchato + rescue flag
patterns_matched <- vapply(seq_len(nrow(df)), function(i) {
  k <- names(patterns_K)[hits_K[i, ]]
  s <- names(patterns_S)[hits_S[i, ]]
  paste(c(k, s), collapse = ";")
}, character(1L))

df$any_K <- any_K
df$any_S <- any_S
df$title_bulk_rescue <- title_bulk_rescue
df$patterns_matched <- patterns_matched
# TSV finale: solo i sample da droppare (post-rescue)
keep_df <- df[drop_mask, c("geo", "series", "any_K", "any_S",
                           "patterns_matched", "title", "src", "ext")]
write.table(keep_df, out_tsv, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("\n[A2] log GSM SC (post-rescue) scritto in: %s (%d righe)\n",
            out_tsv, nrow(keep_df)))

# TSV rescued (audit-trail)
rescued_df <- df[rescued_mask, c("geo", "series", "any_K", "any_S",
                                  "patterns_matched", "title", "src", "ext")]
write.table(rescued_df, "analysis/audit/A2-rescued-by-title-bulk.tsv",
            sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("[A2] rescued GSM (audit trail) scritto in: analysis/audit/A2-rescued-by-title-bulk.tsv (%d righe)\n",
            nrow(rescued_df)))

# Validazione: 20 esempi random dei rescued, per verifica false rescue
cat("\n[A2] === 20 esempi random RESCUED (sanity false-rescue check) ===\n")
if (nrow(rescued_df) > 0) {
  set.seed(7)
  ex <- rescued_df[sample(seq_len(nrow(rescued_df)), min(20, nrow(rescued_df))), ]
  for (i in seq_len(nrow(ex))) {
    cat(sprintf("\n[%s | %s | patterns=%s]\n  title: %s\n  src  : %s\n  ext  : %s\n",
                ex$geo[i], ex$series[i], ex$patterns_matched[i],
                substr(ex$title[i], 1, 150),
                substr(ex$src[i], 1, 150),
                substr(ex$ext[i], 1, 220)))
  }
}

# Random esempi per validazione manuale
cat("\n[A2] === 10 esempi gruppo K (kit-specific) ===\n")
ix_K <- which(any_K & !any_S)
set.seed(11)
if (length(ix_K) > 0) {
  pick <- sample(ix_K, min(10, length(ix_K)))
  for (i in pick) {
    cat(sprintf("\n[%s | %s | patterns=%s]\n  title: %s\n  src  : %s\n  ext  : %s\n",
                df$geo[i], df$series[i], df$patterns_matched[i],
                substr(df$title[i], 1, 150),
                substr(df$src[i], 1, 150),
                substr(df$ext[i], 1, 250)))
  }
}

cat("\n[A2] === 10 esempi gruppo S only (semantica, SOSPETTI false positive) ===\n")
ix_S <- which(any_S & !any_K)
set.seed(11)
if (length(ix_S) > 0) {
  pick <- sample(ix_S, min(10, length(ix_S)))
  for (i in pick) {
    cat(sprintf("\n[%s | %s | patterns=%s]\n  title: %s\n  src  : %s\n  ext  : %s\n",
                df$geo[i], df$series[i], df$patterns_matched[i],
                substr(df$title[i], 1, 150),
                substr(df$src[i], 1, 150),
                substr(df$ext[i], 1, 250)))
  }
}

# Breakdown studio: concentrato o sparso?
cat("\n[A2] === Concentrazione hit per series ===\n")
by_ser <- aggregate(any_either ~ series, data = df, FUN = sum)
colnames(by_ser)[2] <- "n_sc_catch"
by_ser <- by_ser[by_ser$n_sc_catch > 0, ]
total_per_ser <- aggregate(geo ~ series, data = df, FUN = length)
colnames(total_per_ser)[2] <- "n_total"
m <- merge(by_ser, total_per_ser, by = "series")
m$frac_catch <- m$n_sc_catch / m$n_total
cat(sprintf("studi con almeno 1 catch: %d\n", nrow(m)))
cat("istogramma frac_catch per studio:\n")
print(table(cut(m$frac_catch,
                breaks = c(-Inf, 0.01, 0.10, 0.50, 0.99, 1.0001),
                labels = c("0%", "1-10%", "10-50%", "50-99%", "100%"),
                right = TRUE, include.lowest = TRUE)))

# Sovrapposizione con A1 (sanity: il bacino esclude gia' A1 per construction)
cat("\n[A2] sanity: overlap con A1 (deve essere 0, escluso per construction)\n")
sc_A1 <- read.table("analysis/audit/A1-single-cell-by-library-source.tsv",
                    sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                    quote = "")
ovl <- sum(keep_df$geo %in% sc_A1$geo_accession)
cat(sprintf("  overlap GSM con A1 catch list: %d (atteso 0)\n", ovl))

cat("\n[A2] DONE\n")
