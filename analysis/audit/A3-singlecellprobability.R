#!/usr/bin/env Rscript
# RED ALERT FASE A3 — distribuzione singlecellprobability sui sopravvissuti A1+A2,
# applicando filtro lib_size >= 500.000 (stesso QC Stadio 4).
#
# Strategia: scansione H5 /data/expression in slab da 5000 sample × tutti i geni,
# rowSums per ottenere lib_size sample-level, poi filtro bacino A3 + lib_size +
# singlecellprobability summary.

suppressMessages({ library(rhdf5) })

h5_path     <- "analysis/input/human_gene_v2.5.h5"
master      <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
a2_drop_tsv <- "analysis/audit/A2-sc-by-extract-protocol.tsv"
out_tsv     <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
out_png     <- "analysis/audit/A3-scprob-distribution.png"

SLAB <- 5000L
LIBSIZE_MIN <- 500000L

t_start <- Sys.time()

# ============================================================
# Step 1: bacino A3 = rescued ∩ libsrc=transcriptomic ∩ NOT in drop A2
# ============================================================
cat("[A3] step 1: build bacino A3 ...\n")

# Master rescued GSM
lines <- readLines(master, warn = FALSE)
parse_rid <- function(x) {
  m <- regmatches(x, regexpr('"record_id"\\s*:\\s*"[^"]+"', x))
  sub('.*"record_id"\\s*:\\s*"([^"]+)".*', "\\1", m)
}
rescued <- vapply(lines, parse_rid, character(1L), USE.NAMES = FALSE)
rm(lines); gc(verbose = FALSE)

# A2 drop list
a2_drop <- read.delim(a2_drop_tsv, sep = "\t", header = TRUE,
                       stringsAsFactors = FALSE, quote = "",
                       fill = TRUE, comment.char = "")$geo
cat(sprintf("[A3] rescued: %d, A2 drop: %d\n", length(rescued), length(a2_drop)))

# H5 metadata
h5_geo    <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_ser    <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_lib    <- as.character(rhdf5::h5read(h5_path, "meta/samples/library_source"))
h5_scprob <- as.numeric(rhdf5::h5read(h5_path, "meta/samples/singlecellprobability"))
rhdf5::H5close()

mask_bacino <- (h5_geo %in% rescued) &
               (tolower(trimws(h5_lib)) == "transcriptomic") &
               (!(h5_geo %in% a2_drop))
cat(sprintf("[A3] bacino A3 (rescued AND libsrc==trans AND NOT in A2 drop): %d\n", sum(mask_bacino)))

# Mappa H5 idx → bacino flag
idx_bacino <- which(mask_bacino)

# ============================================================
# Step 2: lib_size per ogni sample del bacino via slab scan H5
# ============================================================
cat(sprintf("[A3] step 2: lib_size scan in slab da %d sample ...\n", SLAB))

N <- length(h5_geo)
n_slabs <- ceiling(N / SLAB)
lib_size <- numeric(N)  # vettore allineato a h5_geo
lib_size[] <- NA_real_

# Performance note: H5 read CONTIGUO (index=list(i0:i1, NULL)) e' ~10x piu'
# veloce del random-access (index=list(<sparse_idx>, NULL)). Leggiamo tutto
# lo slab anche se solo ~62% dei sample sono nel bacino A3: la penalty I/O
# e' marginale rispetto al guadagno di lettura contigua.
for (k in seq_len(n_slabs)) {
  i0 <- (k - 1L) * SLAB + 1L
  i1 <- min(k * SLAB, N)
  m <- rhdf5::h5read(h5_path, "data/expression",
                      index = list(i0:i1, NULL))
  lib_size[i0:i1] <- rowSums(m)
  rm(m); if (k %% 10L == 0L) gc(verbose = FALSE)
  if (k %% 20L == 0L || k == n_slabs) {
    el <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
    cat(sprintf("[A3] slab %d / %d done (%.1f min wall, ~%.0f%% progress)\n",
                k, n_slabs, el/60, 100 * k / n_slabs))
  }
}
rhdf5::H5close()

el_total <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
cat(sprintf("\n[A3] lib_size scan complete. Wall: %.1f min\n", el_total/60))

# ============================================================
# Step 3: filtri lib_size + summary singlecellprobability
# ============================================================
bac_libsize <- lib_size[idx_bacino]
bac_scprob  <- h5_scprob[idx_bacino]
bac_geo     <- h5_geo[idx_bacino]
bac_ser     <- h5_ser[idx_bacino]

stopifnot(!anyNA(bac_libsize))

cat("\n[A3] === lib_size sui sample bacino A3 ===\n")
cat(sprintf("  total bacino : %d\n", length(bac_libsize)))
cat(sprintf("  >= 500k      : %d (%.2f%%)\n",
            sum(bac_libsize >= LIBSIZE_MIN),
            100 * mean(bac_libsize >= LIBSIZE_MIN)))
cat(sprintf("  < 500k       : %d (%.2f%%)\n",
            sum(bac_libsize < LIBSIZE_MIN),
            100 * mean(bac_libsize < LIBSIZE_MIN)))
cat(sprintf("  summary lib_size:\n"))
print(summary(bac_libsize))

passed <- bac_libsize >= LIBSIZE_MIN
sc_passed <- bac_scprob[passed]

cat(sprintf("\n[A3] === singlecellprobability sui %d sopravvissuti ===\n", sum(passed)))
cat("  summary:\n")
print(summary(sc_passed))
cat("\n  threshold counts:\n")
for (th in c(0.1, 0.2, 0.3, 0.5, 0.7, 0.9)) {
  n_above <- sum(sc_passed > th, na.rm = TRUE)
  cat(sprintf("    > %.1f : %7d (%.2f%%)\n",
              th, n_above, 100 * n_above / sum(!is.na(sc_passed))))
}
cat(sprintf("  NA count: %d\n", sum(is.na(sc_passed))))

# Salva TSV bacino con tutti i campi audit-relevant
df <- data.frame(
  geo = bac_geo, series = bac_ser,
  lib_size = bac_libsize, singlecellprobability = bac_scprob,
  passed_libsize_500k = passed,
  stringsAsFactors = FALSE
)
write.table(df, out_tsv, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("\n[A3] TSV scritto: %s (%d righe)\n", out_tsv, nrow(df)))

# ============================================================
# Step 4: istogramma PNG
# ============================================================
cat("[A3] step 4: plot ...\n")
png(out_png, width = 1200, height = 700, res = 110)
par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
hist(sc_passed,
     breaks = 50, col = "steelblue", border = "white",
     main = sprintf("singlecellprobability\n(bacino A3 ∩ lib_size>=500k, n=%d)", sum(passed)),
     xlab = "singlecellprobability (ARCHS4 ML)",
     ylab = "count")
abline(v = c(0.3, 0.5, 0.7, 0.9), col = "red", lty = 2)
hist(log10(bac_libsize + 1),
     breaks = 50, col = "darkgreen", border = "white",
     main = sprintf("log10(lib_size+1)\n(bacino A3, n=%d)", length(bac_libsize)),
     xlab = "log10(lib_size + 1)",
     ylab = "count")
abline(v = log10(LIBSIZE_MIN + 1), col = "red", lty = 2)
dev.off()
cat(sprintf("[A3] PNG: %s\n", out_png))

cat("\n[A3] DONE\n")
