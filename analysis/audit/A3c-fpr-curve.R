#!/usr/bin/env Rscript
# A3c — curva FPR proxy vs soglia singlecellprobability (0.5 ... 0.95).
#
# Strategia:
#   1. Pattern BULK_LOW_INPUT regex automatic derivato dai 18 FP manuali
#      scprob>0.5 di A3b (QuantSeq, TM3'seq, ScreenSeq, LCM, FFPE,
#      RiboSeq, EV/exoRNA, swab, EdgeSeq, CAGE, PAXgene, PicoPure, ...).
#   2. Apply su tutti i 508.685 sample post-lib_size del bacino A3.
#   3. Per ogni soglia th: frac_bulk_proxy = sample con scprob>th E bulk regex.
#   4. Manual validation 50 random per 3 bin chiave:
#      [0.5-0.6), [0.7-0.8), >=0.9 — confronto proxy vs manual.
#   5. Output: TSV curve, PNG plot, log manual.

suppressMessages({ library(rhdf5) })
set.seed(42)

h5_path <- "analysis/input/human_gene_v2.5.h5"
a3_tsv  <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
out_curve_tsv <- "analysis/audit/A3c-fpr-curve.tsv"
out_curve_png <- "analysis/audit/A3c-fpr-curve.png"
out_manual    <- "analysis/audit/A3c-manual-bin-samples.tsv"

cat("[A3c] load A3 TSV ...\n")
a3 <- read.delim(a3_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                 quote = "", fill = TRUE, comment.char = "")
a3 <- a3[a3$passed_libsize_500k == "TRUE", ]
cat(sprintf("[A3c] post lib_size: %d\n", nrow(a3)))

cat("[A3c] reading H5 metadata for bulk-pattern check ...\n")
h5_geo   <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_title <- as.character(rhdf5::h5read(h5_path, "meta/samples/title"))
h5_src   <- as.character(rhdf5::h5read(h5_path, "meta/samples/source_name_ch1"))
h5_ext   <- as.character(rhdf5::h5read(h5_path, "meta/samples/extract_protocol_ch1"))
rhdf5::H5close()

m_idx <- match(a3$geo, h5_geo)
a3$title <- h5_title[m_idx]
a3$src   <- h5_src[m_idx]
a3$ext   <- h5_ext[m_idx]
rm(h5_geo, h5_title, h5_src, h5_ext); gc(verbose = FALSE)

# ============================================================
# Pattern BULK_LOW_INPUT (derivato dai 18 FP manuali scprob>0.5)
# Match su extract_protocol_ch1 || title || source_name_ch1
# ============================================================
# Underscore-aware (fix paper-grade 2026-05-26): pattern allargati per
# catturare anche varianti con underscore (es. `10_cell`, `16_cell`,
# `Ribo_seq`, `Smart_3SEQ`). Impatto sulla soglia A5=0.9 secondario (retta
# da 18 manual GT), ma allineamento doveroso con i pattern S corretti.
patterns_bulk <- c(
  QuantSeq      = "(?i)QuantSeq",
  TM3seq        = "(?i)TM3['_ -]?seq|TM[- _]?3[- _]?SEQ",
  ScreenSeq     = "(?i)ScreenSeq|Evotec",
  LCM_10cell    = "(?i)laser capture microdissection|(^|[^a-z0-9])10[- _]?cell(?![a-z0-9])|(^|[^a-z0-9])LCM(?![a-z0-9])",
  FFPE          = "(?i)FFPE",
  RiboSeq       = "(?i)Ribo[- _]?seq|ribosome profiling|(^|[^a-z0-9])RPF(?![a-z0-9])",
  EV_exoRNA     = "(?i)exoRNeasy|extracellular vesic|(^|[^a-z0-9])EVs?(?![a-z0-9])|exosom|cell[- _]?free RNA|cfRNA",
  swab_COVID    = "(?i)(^|[^a-z0-9])swab(?![a-z0-9])|oronasophar|nasopharyng",
  EdgeSeq       = "(?i)HTG EdgeSeq|EdgeSeq",
  CAGE          = "(?i)(^|[^a-z0-9])CAGE(?![a-z0-9])|nAnT[- _]?iCAGE",
  PAXgene       = "(?i)PAXgene",
  PicoPure      = "(?i)PicoPure",
  SMARTer_Pico  = "(?i)SMARTer\\s+Stranded\\s+Total\\s+RNA",
  Smart3SEQ     = "(?i)Smart[- _]?3SEQ",
  Lexogen_3mRNA = "(?i)Lexogen.*Quant|Lexogen 3'",
  HTGseq        = "(?i)(^|[^a-z0-9])HTG(?![a-z0-9])",
  NASCseq       = "(?i)NASC[- _]?seq",  # incluso ma e' SC in realta; flag separato per audit
  spatial_trans = "(?i)spatial transcript",
  embryo_blastomere = "(?i)blastomere|whole[- _]?embryo|(^|[^a-z0-9])16[- _]?cell(?![a-z0-9])|(^|[^a-z0-9])8[- _]?cell.*embryo"
)

target_text <- paste(a3$ext, a3$title, a3$src, sep = " || ")

cat("\n[A3c] === Pattern BULK_LOW_INPUT hit counts ===\n")
hits_bulk <- matrix(FALSE, nrow = nrow(a3), ncol = length(patterns_bulk))
colnames(hits_bulk) <- names(patterns_bulk)
for (nm in names(patterns_bulk)) {
  hits_bulk[, nm] <- grepl(patterns_bulk[[nm]], target_text, perl = TRUE)
  cat(sprintf("  %-20s : %7d\n", nm, sum(hits_bulk[, nm])))
}
any_bulk <- rowSums(hits_bulk) > 0
cat(sprintf("\n  any BULK match (union)  : %d / %d (%.2f%%)\n",
            sum(any_bulk), nrow(a3), 100*mean(any_bulk)))

a3$bulk_proxy <- any_bulk

# ============================================================
# Curva FPR proxy
# ============================================================
thresholds <- seq(0.50, 0.95, by = 0.05)
curve_df <- data.frame(
  threshold = thresholds,
  n_above   = NA_integer_,
  n_bulk_proxy = NA_integer_,
  frac_bulk_proxy = NA_real_,
  stringsAsFactors = FALSE
)
for (i in seq_along(thresholds)) {
  th <- thresholds[i]
  above <- a3$singlecellprobability > th
  curve_df$n_above[i]      <- sum(above)
  curve_df$n_bulk_proxy[i] <- sum(above & a3$bulk_proxy)
  curve_df$frac_bulk_proxy[i] <- ifelse(sum(above) == 0L, NA_real_,
                                         sum(above & a3$bulk_proxy) / sum(above))
}
write.table(curve_df, out_curve_tsv, sep = "\t", row.names = FALSE, quote = FALSE)
cat("\n[A3c] === Curva FPR proxy ===\n")
print(curve_df, row.names = FALSE)

# ============================================================
# Manual validation 50 random per 3 bin chiave
# ============================================================
bins <- list(
  "0.5-0.6" = a3$singlecellprobability > 0.5 & a3$singlecellprobability <= 0.6,
  "0.7-0.8" = a3$singlecellprobability > 0.7 & a3$singlecellprobability <= 0.8,
  ">=0.9"   = a3$singlecellprobability >= 0.9
)
manual_rows <- list()
for (bin_name in names(bins)) {
  ix <- which(bins[[bin_name]])
  N <- min(50, length(ix))
  cat(sprintf("\n[A3c] === manual bin %s, n_available=%d, sampling=%d ===\n",
              bin_name, length(ix), N))
  if (N == 0) next
  samp <- sample(ix, N)
  df <- a3[samp, c("geo", "series", "singlecellprobability", "lib_size",
                    "bulk_proxy", "title", "src", "ext")]
  df$bin <- bin_name
  manual_rows[[bin_name]] <- df
  # Print
  for (k in seq_len(nrow(df))) {
    bp <- ifelse(df$bulk_proxy[k], " [PROXY-BULK]", "")
    cat(sprintf("\n#%d [%s | %s | scprob=%.3f | libsize=%.1fM]%s\n  title: %s\n  src  : %s\n  ext  : %s\n",
                k, df$geo[k], df$series[k], df$singlecellprobability[k],
                df$lib_size[k]/1e6, bp,
                substr(df$title[k], 1, 140),
                substr(df$src[k], 1, 140),
                substr(df$ext[k], 1, 220)))
  }
}
manual_df <- do.call(rbind, manual_rows)
write.table(manual_df, out_manual, sep = "\t", row.names = FALSE, quote = FALSE)

# ============================================================
# Plot
# ============================================================
png(out_curve_png, width = 1000, height = 700, res = 110)
par(mar = c(4, 5, 3, 1))
plot(curve_df$threshold, 100 * curve_df$frac_bulk_proxy,
     type = "b", pch = 19, col = "darkred", lwd = 2,
     xlab = "singlecellprobability threshold",
     ylab = "% bulk_proxy among scprob > threshold (FPR proxy)",
     main = sprintf("A3c — FPR proxy curve (n bacino A3 post lib_size = %d)", nrow(a3)),
     ylim = c(0, max(50, max(100 * curve_df$frac_bulk_proxy, na.rm = TRUE) * 1.2)))
grid()
# Annotazioni
for (i in seq_along(thresholds)) {
  text(curve_df$threshold[i], 100 * curve_df$frac_bulk_proxy[i] + 1.5,
       sprintf("%d", curve_df$n_above[i]), cex = 0.7, col = "darkblue")
}
mtext("blue: n sample drop a quella soglia", side = 3, line = 0.3, cex = 0.85)
abline(h = c(5, 10, 20), col = "gray70", lty = 3)
dev.off()
cat(sprintf("\n[A3c] PNG: %s\n", out_curve_png))

cat("\n[A3c] DONE\n")
