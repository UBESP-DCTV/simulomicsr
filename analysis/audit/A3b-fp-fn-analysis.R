#!/usr/bin/env Rscript
# A3b — analisi FP / FN della singlecellprobability ARCHS4 contro segnali
# ortogonali (regex A2, title-bulk rescue). Manual inspection di 50 random
# > 0.5 (candidati FP/SC-residual) + 50 random 0.3-0.5 (candidati FN ML).

suppressMessages({ library(rhdf5) })
set.seed(42)

h5_path     <- "analysis/input/human_gene_v2.5.h5"
a3_tsv      <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
a2_drop_tsv <- "analysis/audit/A2-sc-by-extract-protocol.tsv"
a2_resc_tsv <- "analysis/audit/A2-rescued-by-title-bulk.tsv"

cat("[A3b] load ...\n")
a3 <- read.delim(a3_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                 quote = "", fill = TRUE, comment.char = "")
a2_drop <- read.delim(a2_drop_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                      quote = "", fill = TRUE, comment.char = "")
a2_resc <- read.delim(a2_resc_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                      quote = "", fill = TRUE, comment.char = "")
cat(sprintf("[A3b] A3 rows: %d, A2 drop: %d, A2 rescued: %d\n",
            nrow(a3), nrow(a2_drop), nrow(a2_resc)))

# Solo i sopravvissuti lib_size
a3_pass <- a3[a3$passed_libsize_500k == "TRUE", ]
cat(sprintf("[A3b] post lib_size: %d\n", nrow(a3_pass)))

# Cross-tab con A2 signals
a3_pass$in_a2_rescue <- a3_pass$geo %in% a2_resc$geo
# I sample in A3 NON dovrebbero essere in A2 drop list (escluso per construction)
sanity_overlap <- sum(a3_pass$geo %in% a2_drop$geo)
cat(sprintf("[A3b] sanity: A3 ∩ A2-drop = %d (atteso 0)\n", sanity_overlap))

# ============================================================
# Cross-tab scprob bucket × A2 signal
# ============================================================
cat("\n[A3b] === Cross-tab scprob × A2 title-bulk rescue ===\n")
a3_pass$scprob_bucket <- cut(a3_pass$singlecellprobability,
  breaks = c(-Inf, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0001),
  labels = c("<=0.1", "0.1-0.3", "0.3-0.5", "0.5-0.7", "0.7-0.9", ">0.9"),
  right = TRUE, include.lowest = TRUE)
print(table(scprob = a3_pass$scprob_bucket,
            a2_rescued = a3_pass$in_a2_rescue))

# scprob distribution sui 870 rescued: bulk veri o no?
cat("\n[A3b] === scprob distribution sui 870 title-bulk rescued ===\n")
resc_scprob <- a3_pass$singlecellprobability[a3_pass$in_a2_rescue]
cat(sprintf("n rescued in A3 pass: %d / 870\n", length(resc_scprob)))
print(summary(resc_scprob))
cat(sprintf("rescued con scprob > 0.5: %d (%.2f%%)\n",
            sum(resc_scprob > 0.5), 100*mean(resc_scprob > 0.5)))
cat(sprintf("rescued con scprob > 0.9: %d (%.2f%%)\n",
            sum(resc_scprob > 0.9), 100*mean(resc_scprob > 0.9)))

# ============================================================
# Carica H5 fields per ispezione manuale
# ============================================================
cat("\n[A3b] reading H5 metadata for inspection ...\n")
h5_geo   <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_title <- as.character(rhdf5::h5read(h5_path, "meta/samples/title"))
h5_src   <- as.character(rhdf5::h5read(h5_path, "meta/samples/source_name_ch1"))
h5_ext   <- as.character(rhdf5::h5read(h5_path, "meta/samples/extract_protocol_ch1"))
rhdf5::H5close()

m_idx <- match(a3_pass$geo, h5_geo)
a3_pass$title <- h5_title[m_idx]
a3_pass$src   <- h5_src[m_idx]
a3_pass$ext   <- h5_ext[m_idx]
rm(h5_geo, h5_title, h5_src, h5_ext); gc(verbose = FALSE)

# ============================================================
# Candidati FP (scprob > 0.5)
# ============================================================
high <- a3_pass[a3_pass$singlecellprobability > 0.5, ]
cat(sprintf("\n[A3b] === Candidati 'high' (scprob > 0.5): %d ===\n", nrow(high)))
cat(sprintf("di cui in A2 title-bulk rescue: %d\n", sum(high$in_a2_rescue)))

set.seed(42)
samp_high <- high[sample(nrow(high), 50), ]
cat("\n[A3b] === 50 RANDOM scprob > 0.5 (manual TP/FP check) ===\n")
for (i in seq_len(nrow(samp_high))) {
  flag <- ifelse(samp_high$in_a2_rescue[i], " [A2-RESC]", "")
  cat(sprintf("\n#%d [%s | %s | scprob=%.3f | libsize=%.1fM]%s\n  title: %s\n  src  : %s\n  ext  : %s\n",
              i, samp_high$geo[i], samp_high$series[i],
              samp_high$singlecellprobability[i],
              samp_high$lib_size[i]/1e6, flag,
              substr(samp_high$title[i], 1, 140),
              substr(samp_high$src[i], 1, 140),
              substr(samp_high$ext[i], 1, 220)))
}

# ============================================================
# Candidati FN (scprob 0.3-0.5)
# ============================================================
mid <- a3_pass[a3_pass$singlecellprobability > 0.3 & a3_pass$singlecellprobability <= 0.5, ]
cat(sprintf("\n\n[A3b] === Candidati 'mid' (scprob 0.3-0.5): %d ===\n", nrow(mid)))

set.seed(42)
samp_mid <- mid[sample(nrow(mid), 50), ]
cat("\n[A3b] === 50 RANDOM scprob 0.3-0.5 (FN-leaning manual check) ===\n")
for (i in seq_len(nrow(samp_mid))) {
  flag <- ifelse(samp_mid$in_a2_rescue[i], " [A2-RESC]", "")
  cat(sprintf("\n#%d [%s | %s | scprob=%.3f | libsize=%.1fM]%s\n  title: %s\n  src  : %s\n  ext  : %s\n",
              i, samp_mid$geo[i], samp_mid$series[i],
              samp_mid$singlecellprobability[i],
              samp_mid$lib_size[i]/1e6, flag,
              substr(samp_mid$title[i], 1, 140),
              substr(samp_mid$src[i], 1, 140),
              substr(samp_mid$ext[i], 1, 220)))
}

# Save dataframes for downstream
saveRDS(list(high = high, samp_high = samp_high,
             mid = mid, samp_mid = samp_mid),
        "analysis/audit/A3b-inspection-dfs.rds")

cat("\n[A3b] DONE\n")
