#!/usr/bin/env Rscript
# Aggiorna A3-libsize-scprob-bacino.tsv (29 MB) sul delta A2 vs OLD:
# - aggiunge 1167 sample ora rescued (lib_size letto da H5 mirato)
# - rimuove 325 sample nuovi catch dal bacino A3
#
# NO full slab scan (3 ore). Letture mirate via index = list(idx_geo, NULL).
# Riferimento: ultrathink regex audit, sessione 4 RED_ALERT.

suppressMessages({ library(rhdf5) })

h5_path  <- "analysis/input/human_gene_v2.5.h5"
in_tsv   <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
out_tsv  <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
backup   <- "analysis/audit/A3-libsize-scprob-bacino.OLD.tsv"
rescued  <- readLines("analysis/audit/A2-delta-rescued_now.txt")
catched  <- readLines("analysis/audit/A2-delta-catch_now.txt")

cat(sprintf("[A3-upd] rescued ora nel bacino: %d\n", length(rescued)))
cat(sprintf("[A3-upd] catch ora fuori bacino: %d\n", length(catched)))

# Backup
file.copy(in_tsv, backup, overwrite = TRUE)
cat(sprintf("[A3-upd] backup: %s\n", backup))

# Carico bacino A3 esistente
a3 <- read.delim(in_tsv, sep="\t", header=TRUE, stringsAsFactors=FALSE,
                  quote="", fill=TRUE, comment.char="")
cat(sprintf("[A3-upd] bacino A3 OLD: %d sample\n", nrow(a3)))

# Step 1: rimuovo i nuovi catch
n_before <- nrow(a3)
a3 <- a3[!(a3$geo %in% catched), , drop = FALSE]
cat(sprintf("[A3-upd] rimossi nuovi catch: %d -> %d sample\n", n_before, nrow(a3)))

# Step 2: leggo lib_size + scprob H5 per i sample rescued (lettura mirata).
cat("[A3-upd] reading H5 geo_accession + series_id + singlecellprobability ...\n")
h5_geo    <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_ser    <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_scprob <- as.numeric(rhdf5::h5read(h5_path, "meta/samples/singlecellprobability"))
H5close()

idx_rescued <- match(rescued, h5_geo)
miss <- sum(is.na(idx_rescued))
if (miss > 0) {
  cat(sprintf("[A3-upd] WARN: %d rescued GSM non trovati in H5 (escludo)\n", miss))
  rescued    <- rescued[!is.na(idx_rescued)]
  idx_rescued <- idx_rescued[!is.na(idx_rescued)]
}

# Lib_size per i rescued via slab MICRO (singolo h5read con index sorted)
cat(sprintf("[A3-upd] H5 expression read mirato (n=%d sample) ...\n", length(idx_rescued)))
t_start <- Sys.time()
ord <- order(idx_rescued)
idx_sorted <- idx_rescued[ord]
m <- rhdf5::h5read(h5_path, "data/expression",
                    index = list(idx_sorted, NULL))
lib_size_sorted <- rowSums(m)
H5close()
rm(m); gc(verbose = FALSE)
lib_size_rescued <- numeric(length(idx_rescued))
lib_size_rescued[ord] <- lib_size_sorted
el <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
cat(sprintf("[A3-upd] H5 expression read wall: %.1f sec\n", el))

# Step 3: append rescued con lib_size + scprob
LIBSIZE_MIN <- 500000L
add_df <- data.frame(
  geo = rescued,
  series = h5_ser[idx_rescued],
  lib_size = lib_size_rescued,
  singlecellprobability = h5_scprob[idx_rescued],
  passed_libsize_500k = lib_size_rescued >= LIBSIZE_MIN,
  stringsAsFactors = FALSE
)
a3 <- rbind(a3, add_df)
cat(sprintf("[A3-upd] bacino A3 NEW: %d sample (delta %+d)\n",
            nrow(a3), nrow(a3) - n_before))

# Step 4: salvataggio
write.table(a3, out_tsv, sep="\t", row.names=FALSE, quote=FALSE)
cat(sprintf("[A3-upd] TSV scritto: %s\n", out_tsv))

# Step 5: distribuzione lib_size + scprob aggiornata per la sintesi
cat("\n[A3-upd] === lib_size sui sample bacino A3 NEW ===\n")
cat(sprintf("  total bacino : %d\n", nrow(a3)))
cat(sprintf("  >= 500k      : %d (%.2f%%)\n",
            sum(a3$passed_libsize_500k),
            100 * mean(a3$passed_libsize_500k)))
cat(sprintf("  < 500k       : %d (%.2f%%)\n",
            sum(!a3$passed_libsize_500k),
            100 * mean(!a3$passed_libsize_500k)))

passed <- a3$passed_libsize_500k
sc_passed <- a3$singlecellprobability[passed]
cat(sprintf("\n[A3-upd] === singlecellprobability sui %d sopravvissuti ===\n",
            sum(passed)))
for (th in c(0.3, 0.5, 0.7, 0.9, 0.95)) {
  n_above <- sum(sc_passed >= th, na.rm = TRUE)
  cat(sprintf("    >= %.2f : %7d (%.3f%%)\n",
              th, n_above, 100 * n_above / sum(!is.na(sc_passed))))
}
cat(sprintf("    NA count: %d\n", sum(is.na(sc_passed))))

# Step 6: drop A3 + lib_size = numeri per ADR-0019 / sintesi
n_libsize_drop <- sum(!a3$passed_libsize_500k)
n_scprob_drop  <- sum(a3$singlecellprobability >= 0.9, na.rm = TRUE)
n_both         <- sum(!a3$passed_libsize_500k & a3$singlecellprobability >= 0.9, na.rm = TRUE)
cat(sprintf("\n[A3-upd] === drop A3 + lib_size sul nuovo bacino ===\n"))
cat(sprintf("  D4 lib_size<500k drop                       : %d\n", n_libsize_drop))
cat(sprintf("  D3 scprob>=0.9 drop (su passed_libsize)     : %d\n",
            sum(a3$singlecellprobability[passed] >= 0.9, na.rm = TRUE)))
